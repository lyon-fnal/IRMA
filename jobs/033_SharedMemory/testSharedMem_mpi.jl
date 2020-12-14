# Testing shared memory with MPI

using MPI
MPI.Init()  # Only the primary thread will issue MPI calls

using OnlineStats
using JLD2
using Random
using Distributed
using IRMA
const sw = Stopwatch()

const sarrayGB = 50  # Size of the shared array in GB
const nRanksOnNodeForFilling = 6   # Number of the ranks on the node that will fill the memory
const bytesInGB = 1024^3


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

""" loadSharedArray!(shared_arr, myrankOnNode, nprocsLoading, myrank)

    Load this rank's part of the shared array with a Gaussian with mean offset by the global
    rank number.
"""
function loadSharedArray!(shared_arr, myrankOnNode, nprocsLoading, myrank)
    # Split up the array to the ranks
    fullSize = length(shared_arr)
    ranges = splitrange(1, fullSize, nprocsLoading)
    myRange = ranges[myrankOnNode+1]


    @debug "Filling $myrank:$myrankOnNode Fullsize=$fullSize myRange=$myRange len(myRange)=$(length(myRange))"

    # See https://bkamins.github.io/julialang/2020/11/20/rand.html for speeding up random number generation

    #  The below allocates A LOT (once for the randn array, again for the (myrank*10) and again for the output
    #fakeData = randn(MersenneTwister(), length(myRange)) .+ (myrank*10)  # Gaussian shifted by my rank number

    # Better to do this... Only allocates the size of fakeData
    fakeData = randn(MersenneTwister(), length(myRange))
    broadcast!(+, fakeData, fakeData, myrank*10)

    @debug "$myrank fake data is $(length(fakeData))"
    shared_arr[myRange] = fakeData   # Don't do .= - that allocates a little
end

function processInRank(shared_arr, bins, myrankOnNode, nprocsOnNode, myrank)

    # What's my part to histogram?
    fullSize = length(shared_arr)
    ranges = splitrange(1, fullSize, nprocsOnNode)
    myRange = ranges[myrankOnNode+1]

    @debug "Processing $myrank:$myrankOnNode Fullsize=$fullSize myRange=$myRange"

    return fit!(Hist(bins), @view shared_arr[myRange])

end

function main()
    stamp(sw, "inMain")

    # Determine Global MPI info
    info = MPI.Info()
    comm = MPI.COMM_WORLD

    nprocs = MPI.Comm_size(comm)
    myrank = MPI.Comm_rank(comm)
    rootRank = 0
    isRoot = myrank == rootRank

    @debug "MEM inMain $myrank $(Sys.free_memory()/bytesInGB)"

    # Make a communicator for each node
    # Maybe try MPI_COMM_TYPE_NUMA
    commOnNode = MPI.Comm_split_type(comm, MPI.MPI_COMM_TYPE_SHARED, myrank)
    nprocsOnNode = MPI.Comm_size(commOnNode)
    myrankOnNode = MPI.Comm_rank(commOnNode)
    isRootRankOnNode = 0
    isRootOnNode = myrankOnNode == isRootRankOnNode

    

    @debug "I am $(myrank) out of $(nprocs) and on $(gethostname()) I'm $(myrankOnNode) out of $(nprocsOnNode) with $(Threads.nthreads()) threads"

    # Make the shared memory array - make it baseSize * (# of ranks on this node)
    stamp(sw, "beforeAllocate")
    sarrayT = Float64
    sarrayRows = sarrayGB * bytesInGB ÷ sizeof(sarrayT)
    win, shared_arr =
        mpi_shared_array(commOnNode, sarrayT, (sarrayRows,) )
    stamp(sw, "allocated")

    @debug "MEM allocated $myrank $(Sys.free_memory()/1024/1024/1024)"

    #MPI.Barrier(MPI.COMM_WORLD)
    #stamp(sw, "synced1")

    if myrankOnNode < nRanksOnNodeForFilling
        loadSharedArray!(shared_arr, myrankOnNode, nRanksOnNodeForFilling, myrank)
        GC.gc()  # Delete any new memory we allocated (this doesn't happen by itself?)
    end
    stamp(sw, "loaded")
    @debug "MEM loaded $myrank $(Sys.free_memory()/bytesInGB)"

    # Synchronize all of the ranks on the node
    MPI.Barrier(comm)
    stamp(sw, "synced2")

    @debug "$myrank Processing"
    bins = range(0.0, stop=200.0, length=201)

    @time h = processInRank(shared_arr, bins, myrankOnNode, nprocsOnNode, myrank)
    stamp(sw, "processed")

    # Turn the histogram into an array
    h_array = vcat(h.out, h.counts)

    # Reduce
    hr_array = MPI.Reduce(h_array, MPI.SUM, rootRank, comm)
    stamp(sw, "reduced")

    allGathered = mpiGatherSerialized(h, isRoot, rootRank, comm)

    allTimings = MPI.Gather( asNamedTuple(sw), rootRank, comm)
    stamp(sw, "gatheredTimings")

    @debug "MEM loaded $myrank $(Sys.free_memory()/bytesInGB)"

    # Turn this back into a histogram
    if isRoot
        hr = Hist(h.edges, left=h.left, closed=h.closed)
        hr.out .= @view hr_array[1:2]
        hr.counts .= @view hr_array[3:end]

        @save "sharedMem.jld2" h h_array hr_array hr allTimings allGathered
    end

    stamp(sw, "WroteJld2")

    MPI.free(win)
    MPI.Finalize()

end

main()
