# Make a OnlineStats.Hist type but with StaticArrays. This make a histogram type that is an `isbitstype`

struct SHist{T,R <: StepRangeLen, N} <: OnlineStats.HistogramStat{T}
    edges::R
    counts::StaticArrays.SVector{N, Int}  # Note this is immutable
    out::StaticArrays.SVector{2, Int}     # Immutable
    left::Bool
    closed::Bool
    function SHist(edges::R, counts, out, left, closed, T::Type=eltype(edges), N=length(edges)-1) where {R <: StepRangeLen}
        new{T,R,N}(edges, counts, out, left, closed)
    end
end

"""
    SHist(h::Hist)

    Create a SHist (Static Histogram) from an already filled Hist. 

    Note that the SHist is immutable. 
"""
SHist(h::OnlineStats.Hist) = SHist(h.edges, h.counts, h.out, h.left, h.closed)


"""
    Hist(sh::SHist)

    Create an OnlineStats.Hist from a SHist
"""
function OnlineStats.Hist(sh::SHist)
    oh = OnlineStats.Hist(sh.edges, left=sh.left, closed=sh.closed)
    oh.counts .= sh.counts  # Remember oh is immutable, so need to do in-place replacement
    oh.out .= sh.out
    oh
end

# For viewing
OnlineStats.nobs(h::SHist) = sum(h.counts) + sum(h.out)
OnlineStats.value(h::SHist) = (x=h.edges, y=h.counts)

# For reducing (can't do merge! since SHists are immutable [and MPI wants merge])
function Base.merge(s1::SHist, s2::SHist)
    merge(Hist(s1), Hist(s2)) |> SHist
end


# This is the underlying function that actually does the merge. We need the leading underscore because otherwise
# this function won't be called. 
function _mergeStatsCollectionWithSHist(s1::OnlineStatsBase.StatCollection, s2::OnlineStatsBase.StatCollection)
    map(merge, s1.stats, s2.stats)
end

"""
    mergeStatsCollectionWithSHist(s1::Series, s2::Series)

    Because Static Histograms are immutable, we cannot use the standard `OnlineStats.merge` 
        function (actually, it is `OnlineStatsBase.merge`) because the underlying function 
        is `merge!`. 
"""
function mergeStatsCollectionWithSHist(s1::Series, s2::Series)
   _mergeStatsCollectionWithSHist(s1, s2) |> Series
end