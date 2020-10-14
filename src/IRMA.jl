module IRMA

using OnlineStats, OnlineStatsBase
using StaticArrays
using MPI
import Base: merge
import Distributed: splitrange

export
    SHist, nobs, value, Hist, merge, mergeStatsCollectionWithSHist, 
    partitionDS, StopWatch, stamp, asNamedTuple

include("shist.jl")
include("partitionDS.jl")
include("stopwatch.jl")

end # module
