var documenterSearchIndex = {"docs":
[{"location":"shist/#Static-Histograms","page":"Static Histograms","title":"Static Histograms","text":"","category":"section"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"OnlineStats.Hist histograms are used extensively in IRMA analysis code. Because Hist uses dynamic arrays, it is not a Julia isbitstype. This means that you must serialize/deserialize histograms if you want to pass them between MPI ranks. A SHist or Static Histogram uses a SVector from StaticArrays.jl, making an isbitstype. Therefore, you do not need to use serialization with MPI.","category":"page"},{"location":"shist/#Construction-and-conversion","page":"Static Histograms","title":"Construction and conversion","text":"","category":"section"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"You can create an SHist from a Hist with the constructor.","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"using IRMA\nusing OnlineStats\nh = fit!(Hist(-5:0.2:5), randn(1_000))\nsh = SHist(h)","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"Note that an SHist is immutable. If you want to do anything real with it, you need to change it back into a Hist.","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"hh = Hist(sh)","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"The conversions are very fast (~300 ns).","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"If you have a Series of histograms you can also go back and forth with the following...","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"s1 = Series(Hist(-5:0.2:5), Hist(-10:0.1:10)) ; fit!(s1, randn(1000))\nsh1 = Series(SHist.(s1.stats)...)\nss1 = Series(Hist.(sh1.stats)...)","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"Named groups are also possible.","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"s2 = Series(h1=Hist(-5:0.2:5), h2=Hist(-10:0.1:10)) ; fit!(s2, randn(1000))\nsh2 = Series((; zip(keys(s2.stats), SHist.(values(s2.stats)))...))","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"Series is the only collection type that is implemented. Note that there is no way to make a FTSeries isbits (due to the function objects), so you'll have to construct a different object from its parts.","category":"page"},{"location":"shist/#Merging","page":"Static Histograms","title":"Merging","text":"","category":"section"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"Functions are provided to handle merging Static Histograms and their collections. Note that since they are immutable, there is no merge! method. The merge occurs by converting to a Hist, doing the merge, and then converting back to a SHist.","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"s1 = fit!(Hist(-5:0.2:5), randn(1000)) ; sh1 = SHist(s1)\ns2 = fit!(Hist(-5:0.2:5), randn(1000)) ; sh2 = SHist(s2)\n\nshm = merge(sh1, sh2)","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"For Series, we have to use a special function, mergeStatsCollectionWithSHist.","category":"page"},{"location":"shist/","page":"Static Histograms","title":"Static Histograms","text":"ser1   = Series(h1=Hist(-5:0.2:5), h2=Hist(-10:0.2:10)) ; fit!(ser1,  randn(1_000));\nsher1  = Series((; zip(keys(ser1.stats), SHist.(values(ser1.stats)))... ))\n\nser2 = Series(h1=Hist(-5:0.2:5), h2=Hist(-10:0.2:10)) ; fit!(ser2, randn(1_000));\nsher2 = Series((; zip(keys(ser2.stats), SHist.(values(ser2.stats)))... ))\n\nsherm = mergeStatsCollectionWithSHist(sher1, sher2)","category":"page"},{"location":"api/#API","page":"API","title":"API","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"","category":"page"},{"location":"api/","page":"API","title":"API","text":"Modules = [IRMA]\nOrder = [:function, :type]","category":"page"},{"location":"api/#IRMA.mergeStatsCollectionWithSHist-Tuple{OnlineStatsBase.Series,OnlineStatsBase.Series}","page":"API","title":"IRMA.mergeStatsCollectionWithSHist","text":"mergeStatsCollectionWithSHist(s1::Series, s2::Series)\n\nBecause Static Histograms are immutable, we cannot use the standard `OnlineStats.merge` \n    function (actually, it is `OnlineStatsBase.merge`) because the underlying function \n    is `merge!`.\n\n\n\n\n\n","category":"method"},{"location":"api/#IRMA.partitionDS-Tuple{Int64,Int64}","page":"API","title":"IRMA.partitionDS","text":"partitionDS(dsLength, nRanks)\n\nGiven the length of a dataset (or anything, really), determine and return partitions over \nnRanks MPI ranks that are as close to the same size as possible. This is really just a wrapper \naround Distributed.splitrange with some added error checking to produce nice messages.\n\n\n\n\n\n","category":"method"},{"location":"api/#IRMA.SHist-Tuple{Hist}","page":"API","title":"IRMA.SHist","text":"SHist(h::Hist)\n\nCreate a SHist (Static Histogram) from an already filled Hist. \n\nNote that the SHist is immutable.\n\n\n\n\n\n","category":"method"},{"location":"api/#OnlineStats.Hist-Tuple{SHist}","page":"API","title":"OnlineStats.Hist","text":"Hist(sh::SHist)\n\nCreate an OnlineStats.Hist from a SHist\n\n\n\n\n\n","category":"method"},{"location":"#IRMA.jl-Documentation","page":"IRMA.jl Documentation","title":"IRMA.jl Documentation","text":"","category":"section"},{"location":"","page":"IRMA.jl Documentation","title":"IRMA.jl Documentation","text":"IRMA supports the Muon g-2 IRMA analysis with Julia code.","category":"page"},{"location":"partitionDS/#Partitioning-a-DataSet","page":"Partitioning a DataSet","title":"Partitioning a DataSet","text":"","category":"section"},{"location":"partitionDS/","page":"Partitioning a DataSet","title":"Partitioning a DataSet","text":"When reading a dataset with multiple MPI ranks, the dataset must be partitioned amongst the ranks. Given the length of the dataset and the number of MPI ranks, partitionDS will determine start and end indices for each MPI rank such that the number of elements per rank are as equal as possible.","category":"page"},{"location":"partitionDS/","page":"Partitioning a DataSet","title":"Partitioning a DataSet","text":"Note that partitionDS is really a wrapper around Distributed.splitrange.","category":"page"},{"location":"partitionDS/","page":"Partitioning a DataSet","title":"Partitioning a DataSet","text":"using IRMA\npartitionDS(1_000_000, 64)","category":"page"},{"location":"partitionDS/","page":"Partitioning a DataSet","title":"Partitioning a DataSet","text":"See an example Pluto Notebook and a static version.","category":"page"}]
}