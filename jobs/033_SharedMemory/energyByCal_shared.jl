# Energy by calorimeter with shared memory

using MPI
MPI.Init()  # Only the primary thread will issue MPI calls

using IRMA
const sw = Stopwatch()

using HDF5

using OnlineStats
using DataFrames
using JLD2
using Chain
using Distributed: splitrange
using ArgParse

const bytesInGB = 1024^3

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

const nCalos = 24

const rankLog = Dict()


""" maybeTime(doTime, ex)

    If doTime is true, then run ex with @time in front. Otherwise, just run ex

    @maybeTime isRoot doLongFunction()

    if isRoot is true, then @time will be run
"""
macro maybeTime(doTime, ex)
    quote
        if $(esc(doTime))
            @time $(esc(ex))
        else
            $(esc(ex))
        end
    end
end

function parse_commandLine()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--nrows", "-n"
        help = "Number of rows to process (default is all)"
        arg_type = Int
        default = 0
        "--nReaders", "-r"
        help = "Number of ranks on each node for reading the input"
        arg_type = Int
        default = 6
        "--notes"
            help = "Any notes to put in the globalLog"
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

""" mpi_shared_array(node_comm, Type, size; owner_rank)

    From https://github.com/JuliaParallel/MPI.jl/blob/master/test/test_shared_win.jl

    Create a shared array, allocated by process with rank `owner_rank` on the
    node_comm provided (i.e. when `MPI.Comm_rank(node_comm) == owner_rank`). Assumes all
    processes on the node_comm are on the same node, or, more precisely that they
    can create/access a shared mem block between them.
    usage:
    nrows, ncols = 100, 11
    const arr = mpi_shared_array(MPI.COMM_WORLD, Int, (nrows, nworkers_node), owner_rank=0)
"""
function mpi_shared_array(node_comm::MPI.Comm, ::Type{T}, sz::Tuple{Vararg{Int}}; owner_rank=0) where T
    node_rank = MPI.Comm_rank(node_comm)
    len_to_alloc = MPI.Comm_rank(node_comm) == owner_rank ? prod(sz) : 0

    @debug "$node_rank is allocating $len_to_alloc"
    win, bufptr = MPI.Win_allocate_shared(T, len_to_alloc, node_comm)

    if node_rank != owner_rank
        len, sizofT, bufvoidptr = MPI.Win_shared_query(win, owner_rank)
        bufptr = convert(Ptr{T}, bufvoidptr)
    end
    win, unsafe_wrap(Array, bufptr, sz)
end

""" rankConfig(comm)

    Determine the configuration of this rank regarding the node it is on.
    Returns a Named Tuple of information
"""
function rankConfig(comm)
    nprocs = MPI.Comm_size(comm)
    myRank = MPI.Comm_rank(comm)
    rootRank = 0
    isRoot = myRank == rootRank

    # Make an inter-node communicator
    commOnNode = MPI.Comm_split_type(comm, MPI.MPI_COMM_TYPE_SHARED, myRank)
    nprocsOnNode = MPI.Comm_size(commOnNode)
    myRankOnNode = MPI.Comm_rank(commOnNode)
    rootRankOnNode = 0
    isRootOnNode = myRankOnNode == rootRankOnNode

    # Make a communicator where the rootRankOnNode ranks are together and the non-rootRankOnNode ranks are together
    #    In pratice we'll ignore the latter
    # See https://wgropp.cs.illinois.edu/bib/talks/tdata/2018/nodecart-final.pdf
    color = isRootOnNode ? 0 : 1
    commAmongNodeRoots = MPI.Comm_split(comm, color, myRank)
    myRankAmongNodeRoots = MPI.Comm_rank(commAmongNodeRoots)
    nprocsAmongNodeRoots = MPI.Comm_size(commAmongNodeRoots)

    # Now each rootOnNode rank tells the other ranks on the node their rank # among the other roots.
    # This is the "node id #" tells a rank which node it is on
    # Furthermore, the number of processes is the number of nodes
    nNodes = MPI.bcast(nprocsAmongNodeRoots, rootRankOnNode, commOnNode)
    myNode = MPI.bcast(myRankAmongNodeRoots, rootRankOnNode, commOnNode)

    # See https://github.com/JuliaLang/julia/blob/3f912edf0318dfb44956551ec7bbb56e9fd6fc50/NEWS.md fourth bullet
    # Return commOnNode separately so it doesn't ruin the isbits-ness of the returned named Tuple
    return (; nprocs, myRank, rootRank, isRoot, nprocsOnNode, myRankOnNode, rootRankOnNode,
              isRootOnNode, nNodes, myNode, myRankAmongNodeRoots, nprocsAmongNodeRoots), commOnNode
end

function divideProcessing(lenMyNodeRange, myRankOnNode, nprocsOnNode, rankLog)

    # Divide the rows on the node amongst all the ranks on the node
     rangesToProcess = splitrange(1, lenMyNodeRange, nprocsOnNode)
     myRangeToProcess = rangesToProcess[myRankOnNode + 1]
     rankLog[:processStart] = first(myRangeToProcess)
     rankLog[:processEnd]   = last(myRangeToProcess)
     rankLog[:processLen]   = length(myRangeToProcess)

     return myRangeToProcess
end

function processData(myRangeToProcess, energySA, timeSA, caloSA, doTime)

    # Get my views of the data
    myEnergy = @view energySA[myRangeToProcess]
    myTime   = @view timeSA[myRangeToProcess]
    myCalo   = @view caloSA[myRangeToProcess]

    # Set bins
    eBins = range(Float32(0), stop=Float32(10_000), length=501)
    tBins = range(Float32(0), stop=Float32(1_000), length=201)

    doTime && @info "My range is $(length(myRangeToProcess))"

    # nt = processWithArrays(myEnergy, myTime, myCalo, doTime)
    return processWithDataFrames(myEnergy, myTime, myCalo, eBins, tBins, doTime)

end

function processWithArrays(myEnergy, myTime, myCalo, eBins, tBins, doTime)
    @maybeTime doTime broadcast!(*, myTime, myTime, Float32(1.25 / 1000.0))

    # Histogram uncalibrated energy
    @maybeTime doTime uncalibratedEHists = @views [fit!(Hist(eBins), @. myEnergy[ (myCalo == aCalo) & (myTime >= 22.0) ]) for aCalo in 1:nCalos ]

    # Apply the energy calibration
    @maybeTime doTime broadcast!(*, myEnergy, myEnergy, eCal[myCalo])

    # Histogram calibrated energy
    @maybeTime doTime calibratedEHists = @views [fit!(Hist(eBins), @. myEnergy[ (myCalo == aCalo) & (myTime >= 22.0) ]) for aCalo in 1:nCalos ]

    # Histogram the time
    @maybeTime doTime timeHists = @views [fit!(Hist(tBins), @. myTime[ (myCalo == aCalo)]) for aCalo in 1:nCalos ]

    return (; uncalibratedEHists, calibratedEHists, timeHists)
end

function processWithDataFrames(myEnergy, myTime, myCalo, eBins, tBins, doTime)

    # Calibrate the time (this is fast and uses no memory)
    @maybeTime doTime broadcast!(*, myTime, myTime, Float32(1.25 / 1000.0))

    @maybeTime doTime df = DataFrame(energy=myEnergy, time=myTime, calo=myCalo, copycols=false)

    # Make a calibrated energy column
    @maybeTime doTime transform!(df, [:energy, :calo] => ByRow( (e, c) -> e * eCal[c] ) => :enregyC)

    # Histogram energy and time without time cut
    @maybeTime doTime h_noTimeCut = @chain df begin
        groupby(_, :cal, sort=true)
        combine(_, :time   => (t->fit!(Hist(tBins), t)) => :timeH,
                   :energy => (e->fit!(Hist(eBins), e)) => :energyH)
    end

    # Now filter by time
    @maybeTime doTime h_timeCut = @chain df begin
        filter(:t => <=(22.0), _,)
        groupby(_, :cal, sort=true)
        combine(_, :energy => (e->fit!(Hist(eBins), e)) => :energyH)
    end

    doTime && @info h_noTimeCut
    doTime && @info h_timeCut
end

function main()
    stamp(sw, "inMain")
    rankLog[:memStart] = Sys.free_memory() / bytesInGB

    # Determine Global MPI info
    info = MPI.Info()
    comm = MPI.COMM_WORLD

    nNodes = parse(Int, ENV["SLURM_NNODES"])
    nTasks = parse(Int, ENV["SLURM_NTASKS_PER_NODE"])

    # Determine the rank configuration - we need this to figure out what part of the file to load
    rc, commOnNode = rankConfig(comm)

    myRank = rc.myRank  # for convenience
    @assert nNodes == rc.nNodes

    rankLog[:nprocs] = rc.nprocs
    rankLog[:myRank] = rc.myRank
    rankLog[:nprocsOnNode] = rc.nprocsOnNode
    rankLog[:myRankOnNode] = rc.myRankOnNode
    rankLog[:nNodes] = rc.nNodes
    rankLog[:myNode] = rc.myNode

    @debug "I am $myRank out of $(rc.nprocs) and on $(gethostname()) I'm $(rc.myRankOnNode) out of $(rc.nprocsOnNode) on the node. Furthermore, I am on node $(rc.myNode) out of $(rc.nNodes) nodes"
    stamp(sw, "determinedRankConfiguration")

    # Process the command line arguments
    parsed_args = parse_commandLine()
    fileName = parsed_args["inFile"]
    outPath  = parsed_args["outPath"]
    nrows    = parsed_args["nrows"]
    nReaders = parsed_args["nReaders"]
    notes    = parsed_args["notes"]

    # Make sure we don't have too many readers
    if nReaders > rc.nprocsOnNode
        nReaders = rc.nprocsOnNode
    end
    stamp(sw, "readCLArgs")

    # Load in the data from the HDF5 file
    f = h5open(fileName, "r")
    stamp(sw, "openedFile")

    # How many rows to allocate?
    # open the datasets
    energyDS = f["/ReconEastClusters/energy"]
    timeDS   = f["/ReconEastClusters/time"]
    caloDS   = f["/ReconEastClusters/caloIndex"]
    @assert length(energyDS) == length(timeDS) == length(caloDS)
    stamp(sw, "openedDataSet")

    # How many rows to process? We can override with the nrows CL argument
    nAllRows = nrows > 0 ? nrows : length(energyDS)
    rc.isRoot && @debug "There are $(nAllRows / 1e9) billion rows"

    # Split datasets among nodes
    rangesForNodes = splitrange(1, nAllRows, rc.nNodes)  # each entry is the range in the file to read for this whole node
    myNodeRange = rangesForNodes[rc.myNode + 1]
    lenMyNodeRange = length(myNodeRange)   # Will need this for processing

    # Make shared memory array on this node
    energyWin, energySA = mpi_shared_array(commOnNode, eltype(energyDS), (lenMyNodeRange,), owner_rank=rc.rootRankOnNode)
    timeWin,     timeSA = mpi_shared_array(commOnNode, eltype(timeDS),   (lenMyNodeRange,), owner_rank=rc.rootRankOnNode)
    caloWin,     caloSA = mpi_shared_array(commOnNode, eltype(caloDS),   (lenMyNodeRange,), owner_rank=rc.rootRankOnNode)
    rankLog[:memAllocated] = Sys.free_memory() / bytesInGB
    stamp(sw, "allocatedSharedMemory")

    # Am I a reading rank?
    if rc.myRankOnNode < nReaders

        # What part of this node's range do I read?
        rangesForReading = splitrange(myNodeRange[1], myNodeRange[end], nReaders)

        # What part of this node's shared memory am I filling?
        rangesForFilling = splitrange(1, lenMyNodeRange, nReaders)
        @assert all(length.(rangesForReading) .== length.(rangesForFilling))  # These better agree

        # Read from rangesForReading[rank#] into rangesForFilling[rank#]
        myRangeToRead = rangesForReading[rc.myRankOnNode + 1]
        myRangeToFill = rangesForFilling[rc.myRankOnNode + 1]
        @debug "$myRank/$(rc.myRankOnNode) reading $myRangeToRead and filling $myRangeToFill"

        rankLog[:isReader]  = true
        rankLog[:readStart] = first(myRangeToRead)
        rankLog[:readEnd]   = last(myRangeToRead)
        rankLog[:fillStart] = first(myRangeToFill)
        rankLog[:fillEnd]   = last(myRangeToFill)
        rankLog[:lenRead]   = length(myRangeToRead)

        stamp(sw, "determinedReadRanges")

        # Do the read
        energySA[myRangeToFill] = energyDS[myRangeToRead]
        stamp(sw, "readEnergyDS")

        timeSA[myRangeToFill] = timeDS[myRangeToRead]
        stamp(sw, "readTimeDS")

        caloSA[myRangeToFill] = caloDS[myRangeToRead]
        stamp(sw, "readCaloDS")

    else
        # The rankLog and the Stopwatch need to have the same entries or else the Gathers will fail
        rankLog[:isReader]  = false
        rankLog[:readStart] = rankLog[:readEnd] = rankLog[:fillStart] = rankLog[:fillEnd] = rankLog[:lenRead] = 0
        stamp(sw, "determinedReadRanges")
        stamp(sw, "readEnergyDS")
        stamp(sw, "readTimeDS")
        stamp(sw, "readCaloDS")
    end

    rankLog[:memLoaded] = Sys.free_memory() / bytesInGB

    close(f)  # Close the input file

    GC.gc()
    rankLog[:memLoadedGC] = Sys.free_memory() / bytesInGB
    stamp(sw, "memoryLoaded")

    # Synchronize all of the ranks on the node
    MPI.Barrier(comm)
    stamp(sw, "syncBeforeProcessing")

    @debug "$myRank Processing"
    bins = range(Float32(0), stop=Float32(10_000), length=501)

    # ---- Processing
    myRangeToProcess = divideProcessing(lenMyNodeRange, rc.myRankOnNode, rc.nprocsOnNode, rankLog)
    @maybeTime rc.isRoot processData(myRangeToProcess, energySA, timeSA, caloSA, rc.isRoot)

    rankLog[:afterProcessing] = Sys.free_memory() / bytesInGB

    # # Turn the histogram into an array
    # h_array = vcat(h.out, h.counts)

    # # Reduce
    # hr_array = MPI.Reduce(h_array, MPI.SUM, rc.rootRank, comm)
    # stamp(sw, "reduced")

    rankLog[:memDone] = Sys.free_memory() / bytesInGB

    # Gather all the things
    # allGathered = mpiGatherSerialized(h, rc.isRoot, rc.rootRank, comm)
    allRankLogs = MPI.Gather((; rankLog...), rc.rootRank, comm)
    allTimings = MPI.Gather(asNamedTuple(sw), rc.rootRank, comm)

    stamp(sw, "Gathered")

    @debug "MEM Done $myRank $(Sys.free_memory() / bytesInGB)"

    # Turn this back into a histogram
    if rc.isRoot
        # hr = Hist(h.edges, left=h.left, closed=h.closed)
        # hr.out .= @view hr_array[1:2]
        # hr.counts .= @view hr_array[3:end]

        jobid = ENV["SLURM_JOBID"]

        globalLog = Dict()
        globalLog[:fileName] = fileName
        globalLog[:ntasks] = nTasks
        globalLog[:slurmId] = jobid
        globalLog[:nRows] = nAllRows
        globalLog[:nReaders] = nReaders
        globalLog[:notes] = notes

        @debug "$myRank Ready to write"
        outFile = joinpath(outPath, "out_$(jobid).jld2")
        @save outFile allTimings allRankLogs globalLog
        @debug "$myRank wrote"
    end

    stamp(sw, "WroteJld2")

    MPI.free(energyWin)
    MPI.free(timeWin)
    MPI.free(caloWin)

    @debug "$myRank DONE"
    MPI.Finalize()

end

main()
