# IRMA.jl Documentation

This package supports the Muon g-2 IRMA analysis.

## Static Histograms

We use `OnlineStats.Hist` extensively in IRMA analysis code. Because `Hist` uses dynamic arrays, it is not an [isbitstype](https://docs.julialang.org/en/v1/base/base/#Base.isbitstype). This means that you must serialize/deserialize the instance if you want to pass it between MPI ranks. A `SHist` or Static Histogram uses a `SVector` from [StaticArrays.jl](https://github.com/JuliaArrays/StaticArrays.jl), making an `isbitstype` and one does not need to use serialization with MPI.

You can create an `SHist` from a `Hist` with the constructor.

```@example
using IRMA # hide
using OnlineStats # hide
h = fit!(Hist(-5:0.2:5), randn(1_000))
sh = SHist(h)
```

Note that an `SHist` is immutable. If you want to do anything real with it, you need to change it back into a `Hist`.

```@example
using IRMA # hide
using OnlineStats # hide
h = fit!(Hist(-5:0.2:5), randn(1_000)) # hide
sh = SHist(h) # hide
hh = Hist(sh)
```

## API

```@autodocs
Modules = [IRMA]
Order = [:function, :type]
```