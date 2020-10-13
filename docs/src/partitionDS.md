# Partitioning a DataSet

When reading a dataset with multiple MPI ranks, the dataset must be partitioned amongst the ranks. Given the length of the dataset and the number of MPI ranks, `partitionDS` will determine start and end indices for each MPI rank such that the number of elements per rank are as equal as possible.

Note that `partitionDS` is really a wrapper around [Distributed.splitrange](https://github.com/JuliaLang/julia/blob/539f3ce943f59dec8aff3f2238b083f1b27f41e5/stdlib/Distributed/src/macros.jl#L245-L261).

```@repl
using IRMA
partitionDS(1_000_000, 64)
```

See an example [Pluto Notebook](https://github.com/lyon-fnal/IRMA/blob/lyon-fnal/issue1/examples/partitionDSPluto.jl) and a [static version](assets/examples/partitionDSPluto.jl.html).
