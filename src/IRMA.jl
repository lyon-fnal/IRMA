module IRMA

using OnlineStats, OnlineStatsBase
using StaticArrays
import Base: merge

export
    SHist, nobs, value, Hist, merge, mergeStatsCollectionWithSHist

include("shist.jl")

end # module
