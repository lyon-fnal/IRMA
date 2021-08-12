# testReduce2.jl
# Patterned after https://github.com/JuliaParallel/MPI.jl/blob/1fd7c095cb0c3ae7151970d18d44d662fdd21d77/test/test_reduce.jl
using Test
using MPI

#using DoubleFloats

MPI.Init()

comm = MPI.COMM_WORLD
sz = MPI.Comm_size(comm)
rank = MPI.Comm_rank(comm)

root = sz-1
isroot = rank == root

operators = [MPI.SUM, +, (x,y) -> 2x+y-x]

for T = [Int]
    for dims = [1, 2, 3]
        send_arr = Array(zeros(T, Tuple(500 for i in 1:dims)))
        send_arr[:] .= 1:length(send_arr)
        @debug "AL $rank $(length(send_arr))"

        opnum = 1
        for op in operators

            @debug "A $rank OP $opnum"
            opnum += 1
            # Non allocating version
            recv_arr = Array{T}(undef, size(send_arr))
            @time MPI.Reduce!(send_arr, recv_arr, length(send_arr), op, root, MPI.COMM_WORLD)
            if isroot
                @test recv_arr == sz .* send_arr
                #@debug "B $rank $recv_arr"
            end

            @debug "D $rank"
        end
    end
end

@debug "E $rank"

MPI.Barrier( MPI.COMM_WORLD )

GC.gc()
MPI.Finalize()
@test MPI.Finalized()