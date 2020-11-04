# Stopwatch - a type for recording MPI time

function getTime()
    if  MPI.Initialized()
        return MPI.Wtime() 
    else 
        @debug "Using time() instead of MPI.Wtime()"
        return time()
    end
end

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
Stopwatch() = Stopwatch(["start"], [getTime()])

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
    push!(sw.timeAt, getTime())
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
    
"""
    rankTimings(arrayOfNamedTuples)

    Process an array of named tuples (e.g. from MPI ranks from `asNamedTuple`
    that was gathered and saved) turning them into an array of NamedTuples 
    of timing differences for each step.
"""
function rankTimings(a)
    # Get the list of timings, dropping the first one
    theKeys = @pipe a[1] |> keys(_) |> Iterators.rest(_, 2) |> collect

    # Make an empty Named tuple with the correct structure
    timeDiffs = (; zip(theKeys,
                       [Float64[] for _ in eachindex(theKeys)]
                   )...
    )

    # We're going to transpose the data from an array of ranks to
    # an array of timings
    for aRank in a      # Loop over the ranks
        tdiffs = aRank |> collect |> diff
        for i in eachindex(theKeys)
            push!(timeDiffs[i], tdiffs[i])
        end
    end
    timeDiffs # Return the naned tuple
end

"""
    rankTotalTime(arrayOfNamedTuples)

    Return an array for the total time of each ranks
"""
function rankTotalTime(a)
    totalTime=Float64[]
    for aRank in a
        push!(totalTime, aRank[end]-aRank[1])
    end
    totalTime
end