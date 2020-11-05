# Energy cluster plots by calorimeter

using MPI
using HDF5
using JLD2
using OnlineStats
using IRMA

# MPI boilerplate
MPI.Init()

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
MPI.Barrier(comm)

# Choose the input file...
#   Logic here is so that I don't have to remember to change this if I'm on my Mac.
#   Strangely, there is no Mac environment variable that says "Darwin" (the shell
#   seems to fill in $OSTYPE on the Mac, but it's not a real environment variable).
#   So we'll just make this decision based on my Home area. Kinda stupid.
const fileName = if ENV["HOME"] == "/Users/lyon"  # Am I on my Mac
                    joinpath("/Users/lyon/Development/gm2/data", "irmaData_36488193_0.h5")  # My mac
                else
                    joinpath(ENV["CSCRATCH"], "irmaData", "irma_2D.h5")   # Cori CSCRATDH
                    #joinpath(ENV["DW_PERSISTENT_STRIPED_irma"], "irma_2D.h5")  # Cori burst buffer
                end

# Constants
const nCalos = 24

# Setup Logging and timing
const rankLog = Dict()
const sw = Stopwatch()

# Open the file
h5open(fileName, "r", comm, info, dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE) do f
    stamp(sw, "openedFile")

    # open the datasets
    energyDS = f["/ReconEastClusters/energy", dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE]
    timeDS   = f["/ReconEastClusters/time", dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE]
    caloDS   = f["/ReconEastClusters/caloIndex", dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE]
    stamp(sw, "openedDataSet")

    # How many rows to process? We can override with the NALLROWS environment variable
    nAllRows = haskey(ENV, "NALLROWS") ? parse(Int64, ENV["NALLROWS"]) : length(energyDS)
    isroot && @debug "There are $(nAllRows/1e9) billion rows"

    # Partition the file
    ranges = partitionDS(nAllRows, nprocs)
    myRange = ranges[myrank+1]   # myrank starts at 0

    # Record what we're doing
    rankLog[:start] = first(myRange)
    rankLog[:end]   = last(myRange)
    rankLog[:len]   = length(myRange)
    @debug "Part for $myrank is $(rankLog[:start]) : $(rankLog[:end]) ; length of $(rankLog[:len])"
    stamp(sw, "determineRanges")

    # Read the data
    energyData = energyDS[1, myRange]
    stamp(sw, "readEnergyDataSet")

    timeData   = timeDS[1, myRange]
    stamp(sw, "readTimeDataSet")

    caloData   = caloDS[1, myRange]
    stamp(sw, "readCaloDataSet")

    @debug "$myrank Read data"

    # Do the time calibration (1 timeData = 1.25ns; And convert to microseconds
    # TODO Put the time calibration into IRMA
    analysisTime = @. timeData * 1.25 / 1000.0

    # Apply the energy correction based on calorimeter ID #
    analysisEnergy = energyData .* eCal[ caloData ]
    stamp(sw, "calibrated")

    # Make histograms of energy for each calorimeter # with cuts
    bins = range( Float32(0), stop=Float32(10_000), length=500)
    hists =  [fit!(Hist(bins), @. analysisEnergy[ (caloData == aCalo) & (analysisTime >= 22.0) ]) for aCalo in 1:nCalos ]
    stamp(sw, "filledHistograms")

    # Reducing the histograms is very slow - instead just Gather them all up
    allHistos = IRMA.mpiGatherSerialized(hists, isroot, root, comm)
    stamp(sw, "gatheredAllHistograms")

    allRankLogs = MPI.Gather( (; rankLog...), root, comm)
    stamp(sw, "gatheredRankLogs")

    allTimings = MPI.Gather( asNamedTuple(sw), root, comm)
    stamp(sw, "gatheredTimings")

    if isroot
        nnodes = ntasks = 1
        cscratch = ".."
        if haskey(ENV, "SLURM_NNODES")
            nnodes = ENV["SLURM_NNODES"]
            ntasks = ENV["SLURM_NTASKS_PER_NODE"]
            cscratch = ENV["CSCRATCH"]
        end

        outPath = joinpath(cscratch, "023_energyByCal", "histos_$(nnodes)x$(ntasks).jld2")

        # Write out results
        @save outPath  allHistos allRankLogs allTimings

        writeTime = MPI.Wtime() - sw.timeAt[end]
        println("Time to write is $writeTime s")
    end
end

stamp(sw, "done")
totalTime = sw.timeAt[end] - sw.timeAt[1]
println("Total time for $myrank is $totalTime s")

@info "$myrank is done"

# Later on, to reduce the gathered histograms, do
# m = [ [ allHistos[r][c] for r in eachindex(allHistos) ] for c in eachindex(allHistos[1]) ]
# rh = reduce.(merge, m)