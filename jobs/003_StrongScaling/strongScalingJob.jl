# Strong scaling study by making one plot

using MPI
using HDF5
using JLD2
using OnlineStats
using IRMA

@debug "Begin"

# MPI boilerplate
MPI.Init()

const info = MPI.Info()
const comm = MPI.COMM_WORLD

const nprocs = MPI.Comm_size(comm)
const myrank = MPI.Comm_rank(comm)
const root = 0
const isroot = myrank == root

@debug "I am rank $myrank of $nprocs"
MPI.Barrier(comm)

# Choose the input file
const fileName = if ENV["OSTYPE"] == "linux"
                    joinpath(ENV["CSCRATCH"], "irmaData", "irma_2D.h5")   # Cori CSCRATDH
                    #joinpath(ENV["DW_PERSISTENT_STRIPED_irma"], "irma_2D.h5")  # Cori burst buffer
                else
                    joinpath("/Users/lyon/Development/gm2/data", "irmaData_36488193_0.h5")  # My mac
                end

function histogramEnergy(energyData)
    # Note that the data is Float32, so the histogram edges must be Float32
    bins = range(Float32(0), stop=Float32(5000), length=201)
    fit!(Hist(bins), energyData)
end

# Setup logging and timing
const rankLog = Dict()
const sw = Stopwatch()

# Open the file
h5open(fileName, "r", comm, info, dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE) do f
    stamp(sw, "openedFile")

    # pen the dataset
    energyDS = f["/ReconEastClusters/energy", dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE]
    stamp(sw, "openedDataSet")

    # Read in all the rows unless overriden by environment variable
    nAllRows = haskey(ENV, "NALLROWS") ? parse(Int64, ENV["NALLROWS"]) : length(energyDS)
    isroot && @debug "There are $(nAllRows/1e9) billion rows"

    # Partition the file
    ranges = partitionDS(nAllRows, nprocs)

    myRange = ranges[myrank+1]   # myrank starts at 0

    # Record what we got
    rankLog[:start] = first(myRange)
    rankLog[:end]   = last(myRange)
    rankLog[:len]   = length(myRange)
    @debug "Part for $myrank is $(rankLog[:start]) : $(rankLog[:end]) ; length of $(rankLog[:len])"
    stamp(sw, "determineRanges")

    # Read the data
    energyData = energyDS[1, myRange]
    stamp(sw, "readDataSet")
    @debug "$myrank Read data"

    # Make the histogram
    o = histogramEnergy(energyData)
    stamp(sw, "madeHistogram")

    # Gather the histograms
    allHistos = MPI.Gather(SHist(o), root, comm)
    stamp(sw, "gatheredHistograms")

    oneHisto = MPI.Reduce(SHist(o), merge, root, comm)
    stamp(sw, "reducedHistograms")

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

        outPath = joinpath(cscratch, "003_StrongScaling", "histos_$(nnodes)x$(ntasks).jld2")

        # Write out results
        @save outPath allHistos oneHisto allRankLogs allTimings

        writeTime = MPI.Wtime() - sw.timeAt[end]
        println("Time to write is $writeTime s")
    end
end

stamp(sw, "done")
totalTime = sw.timeAt[end] - sw.timeAt[1]
println("Total time for $myrank is $totalTime s")

@info "$myrank is done"
