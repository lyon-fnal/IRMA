# Check that NamedTuples work for MPI.Gather
# This answers issue 6 https://github.com/lyon-fnal/IRMA/issues/6
using MPI

# -- MPI boilerplate --
MPI.Init()
using IRMA

const info = MPI.Info()
const comm = MPI.COMM_WORLD

const nprocs = MPI.Comm_size(comm)
const myrank = MPI.Comm_rank(comm)
const root = 0
const isroot = myrank == root

function go()

    # Make a NamedTuple with some data
    nt = (myrank=myrank, nprocs=nprocs)
    @show nt

    allNT = MPI.Gather(nt, root, comm)
    if isroot
        @show allNT
    end

end

go()