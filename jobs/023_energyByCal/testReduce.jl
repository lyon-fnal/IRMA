using MPI
using OnlineStats

struct Serialized
    s::Array{UInt8,1}
end

# MPI boilerplate
MPI.Init()


const info = MPI.Info()
const comm = MPI.COMM_WORLD

const nprocs = MPI.Comm_size(comm)
const myrank = MPI.Comm_rank(comm)
const root = 0
const isroot = myrank == root

function addem(a1, a2)
    @debug "addem A $myrank $a1 $a2"
    #s1 = MPI.deserialize(a1)
    #s2 = MPI.deserialize(a2)
    #@debug "addem B $myrank $s1 $s2"
    #sm = merge(s1, s2)
    #sms = MPI.serialize(sm)
    a1
end

bins = range( Float32(0), stop=Float32(10_000), length=500)
a = fit!(Hist(bins), Float32.(rand(10000)))
@debug "$myrank $a"

if isroot
    MPI.Reduce!(Ref(a), Ref{typeof(a)}(), 1, addem, root, comm)
else
    MPI.Reduce!(Ref(a), nothing, 1, addem, root, comm)
end

MPI.Barrier( MPI.COMM_WORLD )

GC.gc()
MPI.Finalize()