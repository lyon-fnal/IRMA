# Energy cluster plots by calorimeter

using MPI

MPI.Init()

using HDF5

using IRMA
const sw = Stopwatch()

using JLD2
using OnlineStats
using ArgParse

const info = MPI.Info()
const comm = MPI.COMM_WORLD

const nprocs = MPI.Comm_size(comm)
const myrank = MPI.Comm_rank(comm)
const root = 0
const isroot = myrank == root

# Do the energy calibration
# TODO Put the energy calibration into IRMA
const EnergyCal_run1 = Float32[
    1628.9, 1505.9, 1559.4, 1564.9, 1368.8, 1516.9, 1543.8, 1533.0,
    1518.1, 1551.7, 1582.6, 1610.8, 1604.2, 1566.5, 1528.0, 1487.0,
    1520.0, 1588.2, 1554.9, 1525.5, 1455.7, 1474.9, 1522.5, 1548.1]
const EnergyCal_run2 = Float32[
    1845.34, 1956.21, 1852.62, 1882.91, 2075.44, 1919.23, 1885.50, 1900.13,
    1893.89, 1889.55, 1880.18, 1906.99, 1920.32, 1910.87, 1913.59, 1963.29,
    1973.80, 1931.09, 1932.92, 1943.34, 1976.45, 1964.30, 1928.10, 1933.15]

# Calculate the full energy correction factor for each calorimeter
const eCal =  @. Float32(1700.0^2) / EnergyCal_run1  / EnergyCal_run2

@debug "I am rank $myrank of $nprocs"

# Constants
const nCalos = 24

# Setup Logging and timing
const rankLog = Dict()

function parse_commandLine()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--nrows", "-n"
            help = "Number of rows to process (default is all)"
            arg_type = Int
            default = 0
        "--notes"
            help = "Any notes to put in the globalLog"
            arg_type = String
            default = ""
        "--collective"
            help = "Turn on collective MPI-IO"
            action = :store_true
        "--outPrefix"
            help = "Prefix for the output file name"
            arg_type = String
            default = ""
        "inFile"
            help = "Input HDF5 file"
            required = true
        "outPath"
            help = "Path to where the output file should go"
            required = true
    end

    return parse_args(s)
end

function main()

    stamp(sw, "inMain")

    parsed_args = parse_commandLine()
    fileName  = parsed_args["inFile"]
    outPath   = parsed_args["outPath"]
    nrows     = parsed_args["nrows"]
    notes     = parsed_args["notes"]
    do_mpio   = parsed_args["collective"]
    outPrefix = parsed_args["outPrefix"]

    if do_mpio
        @info "Collective MPI-IO is on"
        let fileprop = create_property(HDF5.H5P_FILE_ACCESS)
            HDF5.h5p_set_fapl_mpio(fileprop, comm, info)   # fapl is the file access property list
            h5comm, h5info = HDF5.h5p_get_fapl_mpio(fileprop)

            @assert MPI.Comm_compare(comm, h5comm) == MPI.CONGRUENT
        end
    end

    my_h5open(f::Function, fname::String) = begin
        if do_mpio
            @info "h5open collective"
            return h5open(f, fname, "r", comm, info, dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE)
        else
            @info "h5open non-collective"
            return h5open(f, fname, "r")
        end
    end

    stamp(sw, "beforeOpen")
    # Open the file
    my_h5open(fileName) do f
        stamp(sw, "openedFile")

        # open the datasets
        if do_mpio
            # I think I need to switch to explicit h5reads to get real collective reads
            # see https://github.com/JuliaIO/HDF5.jl/blob/aafbeafd916d0ab96eab36035cc6d156245d9223/test/mpio.jl#L58
            @info "h5get collective"
            energyDS = f["/ReconEastClusters/energy",    fapl_mpio=(comm, info), dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE]
            timeDS   = f["/ReconEastClusters/time",      fapl_mpio=(comm, info), dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE]
            caloDS   = f["/ReconEastClusters/caloIndex", fapl_mpio=(comm, info), dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE]
        else
            @info "h5get nonm-collective"
            energyDS = f["/ReconEastClusters/energy"]
            timeDS   = f["/ReconEastClusters/time"]
            caloDS   = f["/ReconEastClusters/caloIndex"]
        end
        stamp(sw, "openedDataSet")

        # How many rows to process? We can override with the NALLROWS environment variable
        nAllRows = nrows > 0 ? nrows : length(energyDS)
        isroot && @debug "There are $(nAllRows/1e9) billion rows"

        # Partition the file
        ranges = partitionDS(nAllRows, nprocs)
        myRange = ranges[myrank+1]   # myrank starts at 0

        # Record what we're doing
        rankLog[:start] = first(myRange)
        rankLog[:end]   = last(myRange)
        rankLog[:len]   = length(myRange)
        isroot && @debug "Part for $myrank is $(rankLog[:start]) : $(rankLog[:end]) ; length of $(rankLog[:len])"
        stamp(sw, "determineRanges")

        # Read the data
        energyData = energyDS[myRange]
        stamp(sw, "readEnergyDataSet")

        timeData   = timeDS[myRange]
        stamp(sw, "readTimeDataSet")

        caloData   = caloDS[myRange]
        stamp(sw, "readCaloDataSet")

        isroot && @debug "$myrank Read data"

        # Do the time calibration (1 timeData = 1.25ns; And convert to microseconds
        # TODO Put the time calibration into IRMA
        analysisTime = @. timeData * Float32(1.25 / 1000.0)

        # Apply the energy correction based on calorimeter ID #
        analysisEnergy = energyData .* eCal[ caloData ]
        stamp(sw, "calibrated")

        # Make histograms of energy for each calorimeter # with cuts
        # Note the length is nBins+1
        bins = range( Float32(0), stop=Float32(10_000), length=501)
        calibratedHists    =  [fit!(Hist(bins), @. analysisEnergy[ (caloData == aCalo) & (analysisTime >= 22.0) ]) for aCalo in 1:nCalos ]
        uncalibratedHists =  [fit!(Hist(bins), @. energyData[ (caloData == aCalo) & (analysisTime >= 22.0) ]) for aCalo in 1:nCalos ]

        timeBins = range( Float32(0), stop=Float32(1_000), length=201)
        timeHists         =  [fit!(Hist(timeBins), @. analysisTime[ (caloData == aCalo)]) for aCalo in 1:nCalos ]

        stamp(sw, "filledHistograms")

        # Reducing the histograms is very slow - instead just Gather them all up
        allCalibratedHists   = IRMA.mpiGatherSerialized(calibratedHists, isroot, root, comm)
        allUncalibratedHists = IRMA.mpiGatherSerialized(uncalibratedHists, isroot, root, comm)
        allTimeHists         = IRMA.mpiGatherSerialized(timeHists, isroot, root, comm)
        stamp(sw, "gatheredAllHistograms")

        allRankLogs = MPI.Gather( (; rankLog...), root, comm)
        stamp(sw, "gatheredRankLogs")

        allTimings = MPI.Gather( asNamedTuple(sw), root, comm)
        stamp(sw, "gatheredTimings")

        if isroot
            nnodes = ntasks = 1   # If on my Mac

            globalLog = Dict()

            if haskey(ENV, "SLURM_NNODES")   # If on Cori
                nnodes = ENV["SLURM_NNODES"]
                ntasks = ENV["SLURM_NTASKS_PER_NODE"]

                globalLog[:fileName] = fileName
                globalLog[:nnodes] = nnodes
                globalLog[:ntasks] = ntasks
                globalLog[:slurmId] = ENV["SLURM_JOBID"]
                globalLog[:notes] = notes
            end
            globalLog[:nAllRows] = nAllRows

            outFile = joinpath(outPath, "histos$(outPrefix)_$(nnodes)x$(ntasks).jld2")

            # Write out results
            @save outFile  allCalibratedHists allUncalibratedHists allTimeHists allRankLogs allTimings globalLog
            @debug "$myrank Wrote output to $outFile"

            writeTime = MPI.Wtime() - sw.timeAt[end]
            println("Time to write is $writeTime s")
        end
    end

    stamp(sw, "done")
    totalTime = sw.timeAt[end] - sw.timeAt[1]
    println("Total time for $myrank is $totalTime s")

end

main()

@info "$myrank is done"

# Later on, to reduce the gathered histograms, do
# m = [ [ allHistos[r][c] for r in eachindex(allHistos) ] for c in eachindex(allHistos[1]) ]
# rh = reduce.(merge, m)