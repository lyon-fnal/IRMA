# Testing shared memory with MPI

using MPI
MPI.Init_thread(MPI.THREAD_SINGLE)  # Only the primary thread will issue MPI calls

using Random
using IRMA
using OnlineStats
using ThreadsX

const baseSize = 800_000_000  # Base size of the shared array
                              # Actual size will be baseSize * (# ranks on node)

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
    win, bufptr = MPI.Win_allocate_shared(T, len_to_alloc, node_comm)

    if node_rank != owner_rank
        len, sizofT, bufvoidptr = MPI.Win_shared_query(win, owner_rank)
        bufptr = convert(Ptr{T}, bufvoidptr)
    end
    win, unsafe_wrap(Array, bufptr, sz)
end

""" loadSharedArray!(shared_arr, myrankOnNode, nprocsOnNode, myrank)

    Load this rank's part of the shared array with a Gaussian with mean offset by the global
    rank number.
"""
function loadSharedArray!(shared_arr, myrankOnNode, nprocsOnNode, myrank)
    # Split up the array to the ranks
    fullSize = length(shared_arr)
    ranges = partitionDS(fullSize, nprocsOnNode)
    myRange = ranges[myrankOnNode+1]

    @debug "$myrank:$myrankOnNode Fullsize=$fullSize myRange=$myRange"

    # See https://bkamins.github.io/julialang/2020/11/20/rand.html for speeding up random number generation
    fakeData = randn(MersenneTwister(), length(myRange)) .+ (myrank*10)  # Gaussian shifted by my rank number
    shared_arr[myRange] = fakeData
end

function processSingleThreaded(shared_arr, bins)
    fit!(Hist(bins), shared_arr)
end

function processMultiThreadedA(shared_arr, bins)
    ThreadsX.reduce(Hist(bins), shared_arr)
end

function processMultiThreadedB(shared_arr, bins)
    nThreads = Threads.nthreads()
    myThreadId = Threads.threadid()
    hists = fill(Hist(bins), nThreads)
    ranges = partitionDS(length(shared_arr), nThreads)

    Threads.@threads for t in 1:nThreads
        fit!( hists[ t ], @view shared_arr[ranges[t]])
    end

    return hists
end

function main()

    # Determine Global MPI info
    info = MPI.Info()
    comm = MPI.COMM_WORLD

    nprocs = MPI.Comm_size(comm)
    myrank = MPI.Comm_rank(comm)
    isRoot = myrank == 0

    # The primary thread can do MPI calls
    @assert MPI.Is_thread_main()

    # Make a communicator for each node
    # Maybe try MPI_COMM_TYPE_NUMA
    commOnNode = MPI.Comm_split_type(comm, MPI.MPI_COMM_TYPE_SHARED, myrank)
    nprocsOnNode = MPI.Comm_size(commOnNode)
    myrankOnNode = MPI.Comm_rank(commOnNode)
    isRootOnNode = myrankOnNode == 0

    @debug "I am $(myrank) out of $(nprocs) and on $(gethostname()) I'm $(myrankOnNode) out of $(nprocsOnNode) with $(Threads.nthreads()) threads"

    # Make the shared memory array - make it baseSize * (# of ranks on this node)
    win, shared_arr =
        mpi_shared_array(commOnNode, Float64, (baseSize*nprocsOnNode,))

    loadSharedArray!(shared_arr, myrankOnNode, nprocsOnNode, myrank)

    # Synchronize all of the ranks on the node
    MPI.Barrier(commOnNode)

    if isRootOnNode
        @debug "$myrank Processing"
        bins = range(0.0, stop=200.0, length=201)

        @time h1 = processSingleThreaded(shared_arr, bins)
        @time h2 = processMultiThreadedA(shared_arr, bins)
        @time h3 = processMultiThreadedB(shared_arr, bins)
    end

    MPI.free(win)
    MPI.Finalize()

end

main()
