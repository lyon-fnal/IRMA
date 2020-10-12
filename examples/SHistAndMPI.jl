# Try MPI with Static histograms
# Run with
# mpiexec -n 4 julia SHistAndMPI.jl    

using OnlineStats
using IRMA
using MPI

# -- MPI boilerplate --
MPI.Init()

const info = MPI.Info()
const comm = MPI.COMM_WORLD

const nprocs = MPI.Comm_size(comm)
const myrank = MPI.Comm_rank(comm)
const root = 0
const isroot = myrank == root

function go()

    # Make a series of histograms in each rank and gather them all to the root
    ser = Series(h1=Hist(-5:0.2:5), h2=Hist(-10:0.1:10))
    fit!(ser, randn(1_000_000))
    sher = Series((; zip(keys(ser.stats), SHist.(values(ser.stats)))... ))

    allSH = MPI.Gather(sher, root, comm)

    if isroot
        @show length(allSH)
        for i in eachindex(allSH)
            @show i
            @show  allSH[i].stats.h1
            @show  allSH[i].stats.h2
        end
    end

    MPI.Barrier(comm)

    # Make a histogram in each rank and reduce them to the root
    h = fit!(Hist(-15:.3:15), randn(1_000_000))
    sumH = MPI.Reduce(SHist(h), merge, root, comm)

    if isroot
        @show sumH
    end

    MPI.Barrier(comm)

    # Make a series of histograms and reduce them to the root
    sherH = MPI.Reduce(sher, mergeStatsCollectionWithSHist, root, comm)  # Use the Series we made before
    if isroot
        @show sherH
    end
end

go()
