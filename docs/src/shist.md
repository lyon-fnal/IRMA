# Static Histograms

`OnlineStats.Hist` histograms are used extensively in IRMA analysis code. Because `Hist` uses dynamic arrays, it is not a Julia [isbitstype](https://docs.julialang.org/en/v1/base/base/#Base.isbitstype). This means that you must serialize/deserialize histograms if you want to pass them between MPI ranks. A `SHist` or Static Histogram uses a `SVector` from [StaticArrays.jl](https://github.com/JuliaArrays/StaticArrays.jl), making an `isbitstype`. Therefore, you do not need to use serialization with MPI.

## Construction and conversion

You can create an `SHist` from a `Hist` with the constructor.

```@repl shist
using IRMA
using OnlineStats
h = fit!(Hist(-5:0.2:5), randn(1_000))
sh = SHist(h)
```

Note that an `SHist` is immutable. If you want to do anything real with it, you need to change it back into a `Hist`.

```@repl shist
hh = Hist(sh)
```

The conversions are very fast (~300 ns).

If you have a `Series` of histograms you can also go back and forth with the following...

```@repl shist
s1 = Series(Hist(-5:0.2:5), Hist(-10:0.1:10)) ; fit!(s1, randn(1000))
sh1 = Series(SHist.(s1.stats)...)
ss1 = Series(Hist.(sh1.stats)...)
```

Named groups are also possible.

```@repl shist
s2 = Series(h1=Hist(-5:0.2:5), h2=Hist(-10:0.1:10)) ; fit!(s2, randn(1000))
sh2 = Series((; zip(keys(s2.stats), SHist.(values(s2.stats)))...))
```

`Series` is the only collection type that is implemented. Note that there is no way to make a `FTSeries` `isbits` (due to the function objects), so you'll have to construct a different object from its parts.

## Merging

Functions are provided to handle merging Static Histograms and their collections. Note that since they are immutable, there is no `merge!` method. The merge
occurs by converting to a `Hist`, doing the merge, and then converting back to a `SHist`.

```@repl shist
s1 = fit!(Hist(-5:0.2:5), randn(1000)) ; sh1 = SHist(s1)
s2 = fit!(Hist(-5:0.2:5), randn(1000)) ; sh2 = SHist(s2)

shm = merge(sh1, sh2)
```

For `Series`, we have to use a special function, `mergeStatsCollectionWithSHist`.

```@repl shist
ser1   = Series(h1=Hist(-5:0.2:5), h2=Hist(-10:0.2:10)) ; fit!(ser1,  randn(1_000));
sher1  = Series((; zip(keys(ser1.stats), SHist.(values(ser1.stats)))... ))

ser2 = Series(h1=Hist(-5:0.2:5), h2=Hist(-10:0.2:10)) ; fit!(ser2, randn(1_000));
sher2 = Series((; zip(keys(ser2.stats), SHist.(values(ser2.stats)))... ))

sherm = mergeStatsCollectionWithSHist(sher1, sher2)
```
