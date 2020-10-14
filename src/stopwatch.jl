# StopWatch - a type for recording MPI time

"""
    StopWatch

    StopWatch is an object that keeps track of MPI.Wtime when asked. 

    At construction time, the "start" time is recorded.
    Call `stamp(sw, stamp)` to record the current MPI.Wtime and label
                            it with "stamp"

    Call `asNamedTuple(sw)` for transferring to other MPI ranks. The 
    resulting NamedTuple with be `isbits` type.
"""
mutable struct StopWatch
    stamps::Array{String,1}
    timeAt::Array{Float64,1}
end

"""
    StopWatch()

    Create a StopWatch. The "start" entry will automatically be made
    and the MPI.Wtime will be filled in.
"""
StopWatch() = StopWatch(["start"], [MPI.Wtime()])

"""
    StopWatch(nt::NamedTuple)

    Create a StopWatch from a previously filled named tuple
"""
function StopWatch(nt::NamedTuple)
    StopWatch(string.(keys(nt)), values(nt))
end

"""
    stamp(sw::StopWatch, stamp::String)

    For a `StopWatch` `sw`, record the MPI time and the stamp.

    It returns the elapsed time from the previous stamp.
"""
function stamp(sw::StopWatch, stamp::String)
    push!(sw.timeAt, MPI.Wtime())
    push!(sw.stamps, stamp)
    return sw.timeAt[end] - sw.timeAt[end-1]
end

"""
    asNamedTuple(sw::StopWatch)

    Convert `sw` into a `NamedTuple` for MPI transport.
"""
function asNamedTuple(sw::StopWatch)
    (; zip(Symbol.(sw.stamps), sw.timeAt)...)
end
    
