# Check the histograms

using JLD2
using OnlineStats

cd("jobs/033_SharedMemory")
@load "sharedMem.jld2"

h
hr
h_array[1:10]
hr_array[1:10]

hr.edges
h.edges

ha = reduce(merge, allGathered)

hr
ha
hr.out
ha.out

hr == ha
hr == hash

 