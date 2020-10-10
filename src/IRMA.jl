module IRMA

using OnlineStats, StaticArrays


import OnlineStats: Hist, nobs, value

export
    SHist, nobs, value, Hist

include("shist.jl")

end # module
