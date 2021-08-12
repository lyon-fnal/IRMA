using IRMA
using Test

include("test_shist.jl")
include("test_stopwatch.jl")

println("Next tests take awhile")
include("test_partitionDS.jl")
