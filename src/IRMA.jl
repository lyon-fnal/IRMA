module IRMA

using OnlineStats, OnlineStatsBase
using StaticArrays
import Base: merge
import Distributed: splitrange

export
    SHist, nobs, value, Hist, merge, mergeStatsCollectionWithSHist, 
    partitionDS

include("shist.jl")
include("partitionDS.jl")

end # module
