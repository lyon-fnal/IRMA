# Test to see how much memnory we can allocate on a Haswell node

using MPI
MPI.Init()

const info = MPI.Info()
const comm = MPI.COMM_WORLD

const nprocs = MPI.Comm_size(comm)
const myrank = MPI.Comm_rank(comm)
const root = 0
const isroot = myrank == root

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

println("Before")
win, shared_arr =
        mpi_shared_array(comm, Float64, (16_250_000_000,))

println("Filling")

# Fill a GB at a time
fillWith = ones(125_000_000)
for i in 1:length(shared_arr) ÷ length(fillWith)
    println(i)
    blockStart = (i-1)*length(fillWith) + 1
    blockEnd   = blockStart + length(fillWith) - 1
    shared_arr[blockStart:blockEnd] = fillWith  # Copy
end

println(sizeof(shared_arr))
println("After")

MPI.free(win)
MPI.Finalize()
