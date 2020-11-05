module IRMA

using OnlineStats, OnlineStatsBase
using StaticArrays
using Pipe
using MPI
import Base: merge
import Distributed: splitrange

export
    SHist, nobs, value, Hist, merge, mergeStatsCollectionWithSHist,
    partitionDS, Stopwatch, stamp, asNamedTuple, rankTimings, rankTotalTime,
    mpiGatherSerialized

include("shist.jl")
include("partitionDS.jl")
include("stopwatch.jl")
include("mpi.jl")

end # module
