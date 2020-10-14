# Stopwatch - a type for recording MPI time

"""
    Stopwatch

    Stopwatch is an object that keeps track of MPI.Wtime when asked. 

    At construction time, the "start" time is recorded.
    Call `stamp(sw, stamp)` to record the current MPI.Wtime and label
                            it with "stamp"

    Call `asNamedTuple(sw)` for transferring to other MPI ranks. The 
    resulting NamedTuple with be `isbits` type.
"""
mutable struct Stopwatch
    stamps::Array{String,1}
    timeAt::Array{Float64,1}
end

"""
    Stopwatch()

    Create a Stopwatch. The "start" entry will automatically be made
    and the MPI.Wtime will be filled in.
"""
Stopwatch() = Stopwatch(["start"], [MPI.Wtime()])

"""
    Stopwatch(nt::NamedTuple)

    Create a Stopwatch from a previously filled named tuple
"""
function Stopwatch(nt::NamedTuple)
    Stopwatch(string.(keys(nt)), values(nt))
end

"""
    stamp(sw::Stopwatch, stamp::String)

    For a `Stopwatch` `sw`, record the MPI time and the stamp.

    It returns the elapsed time from the previous stamp.
"""
function stamp(sw::Stopwatch, stamp::String)
    push!(sw.timeAt, MPI.Wtime())
    push!(sw.stamps, stamp)
    return sw.timeAt[end] - sw.timeAt[end-1]
end

"""
    asNamedTuple(sw::Stopwatch)

    Convert `sw` into a `NamedTuple` for MPI transport.
"""
function asNamedTuple(sw::Stopwatch)
    (; zip(Symbol.(sw.stamps), sw.timeAt)...)
end
    
