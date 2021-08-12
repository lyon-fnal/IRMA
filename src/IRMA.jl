module IRMA

using OnlineStats, OnlineStatsBase
using StaticArrays
using Pipe
using MPI
using HDF5
using Format
using JLD2
import ProgressLogging
import Glob
import Base: merge
import Distributed: splitrange


export
    SHist, nobs, value, Hist, merge, mergeStatsCollectionWithSHist,
    partitionDS, Stopwatch, stamp, asNamedTuple, rankTimings, rankTotalTime,
    mpiGatherSerialized, mpi_shared_array, rankConfig,
    DataSetEntry, visitH5Contents, makeGetStructureVisitor, displayDataSetEntries, analyzeInputFiles,
    DataSetEntryDict, chooseDataSets, layoutMemoryWholeFiles

include("shist.jl")
include("partitionDS.jl")
include("stopwatch.jl")
include("mpi.jl")
include("hdf5tools.jl")


end # module
