# mpi - Helper functions for MPI

"""deserializeArray(a, s)
    When you use MPI.Gather, you get one long array with all of the contents from the ranks mushed together.
    They need to be separated and deserialized.

    Returns an array of deserialized objects

    a is the array of data all mushed together
    s is an array of the data size for each rank

"""
function deserializeArray(a, s)
    startAt=1
    out = []
    for endAt in s
        push!(out, MPI.deserialize(a[startAt:startAt+endAt-1]))
        startAt += endAt
    end
    return out
end

"""mpiGatherSerialized(obj, isroot, root, comm)

    Serializes the object, determines the size, calls MPI.Gather on the sizes,
    calls MPI.Gather on the serialized data, deserializes the data.

    Returns an array of deserialized data from all of the ranks. Only the root rank
    gets the full gathered array

    obj is the object to serialize and send
    isroot is a boolean which is true if this rank is the root rank
    root is the root rank id
    comm is the MPI communicator
"""
function mpiGatherSerialized(obj, isroot, root, comm)
    s = MPI.serialize(obj)
    allSLen = MPI.Gather(length(s), root, comm)
    allS    = MPI.Gather(s, root, comm)
    allData = nothing
    if isroot
        allData = deserializeArray(allS, allSLen)
    end
    return allData
end

"""mpiAllgatherSerialized(obj, comm)

    Serializes the object, determines the size, calls MPI.Allgather on the sizes,
    calls MPI.Gather on the serialized data, deserializes the data.

    Returns an array of deserialized data from all of the ranks.
    All of the ranks get the full data in an array.

    obj is the object to serialize and send
    comm is the MPI communicator
"""
function mpiAllgatherSerialized(obj, comm)
    s = MPI.serialize(obj)
    allSLen = MPI.Allgather(length(s), comm)
    allS    = MPI.Allgather(s, comm)
    return deserializeArray(allS, allSLen)
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
    Determines the MPI configuration of this rank, in three spaces

    - Global space - space of all ranks
    - Node space - The space of ranks on a particular node
    - Among Node Roots space - The space of node-root ranks

    This function determines,
    * The global rank number (myRank)
    * The number of global ranks (nprocs)
    * The # of the root rank in global space (rootRank)
    * True if this rank is global root (isRoot)

    * The number of ranks on this node (nprocsOnNode)
    * The node-space rank number (myRankOnNode)
    * The # of the root rank in node-space (rootRankOnNode)
    * True if this rank is a root rank in node-space (isRootOnNode)

    * The number of nodes in use (nNodes)
    * The # of the node this rank is on (myNode)
    * If this rank is a node root rank, # of rank within that space (myRankAmongNodeRoots)
    * If this rank is a node root rank, the # of ranks in that space (nprocsAmongNodeRoots)

    For the last two, disregard if this rank is not a node root rank (they are the values
       in the Among Node non-root ranks, which isn't all that useful)

    Returns a Named Tuple of information above along with the commOnNode communicator
"""
function rankConfig(comm, rootRank=0)
    nprocs = MPI.Comm_size(comm)
    myRank = MPI.Comm_rank(comm)
    isRoot = myRank == rootRank

    # Make an inter-node communicator - commOnNode is for communicating between ranks on the same node
    commOnNode = MPI.Comm_split_type(comm, MPI.MPI_COMM_TYPE_SHARED, myRank)
    nprocsOnNode = MPI.Comm_size(commOnNode)
    myRankOnNode = MPI.Comm_rank(commOnNode)
    rootRankOnNode = rootRank  # Typically zero
    isRootOnNode = myRankOnNode == rootRankOnNode

    # Make a communicator where the rootRankOnNode ranks are together and the non-rootRankOnNode ranks are together
    #    In pratice we'll ignore the latter
    # See https://wgropp.cs.illinois.edu/bib/talks/tdata/2018/nodecart-final.pdf
    color = isRootOnNode ? 0 : 1
    commAmongNodeRoots = MPI.Comm_split(comm, color, myRank)
    myRankAmongNodeRoots = MPI.Comm_rank(commAmongNodeRoots)
    nprocsAmongNodeRoots = MPI.Comm_size(commAmongNodeRoots)

    # Now, each rootOnNode rank tells the other ranks on its node the rank# of the rootOnNode rank.
    # Effectively, this is the "node id #" and tells a rank which node it is on
    # Furthermore, the number of processes is the number of nodes
    myNode = MPI.bcast(myRankAmongNodeRoots, rootRankOnNode, commOnNode)
    nNodes = MPI.bcast(nprocsAmongNodeRoots, rootRankOnNode, commOnNode)

    # See https://github.com/JuliaLang/julia/blob/3f912edf0318dfb44956551ec7bbb56e9fd6fc50/NEWS.md fourth bullet
    # Return commOnNode separately so it doesn't ruin the isbits-ness of the returned named Tuple
    return (; nprocs, myRank, rootRank, isRoot, nprocsOnNode, myRankOnNode, rootRankOnNode,
              isRootOnNode, nNodes, myNode, myRankAmongNodeRoots, nprocsAmongNodeRoots), commOnNode, commAmongNodeRoots
end
