# Tips for doing stuff

This page includes tips that I want to remember.

## Running with MPI and HDF5

As of October 14, 2020, you must use the master branch of HDF5.jl. So,

```julia
] add HDF5#master
```

Remember to build and test accordingly.

Before running a job, everything should be instantiated and pre-compiled by Julia. You can do this easily from the command line
with,

```bash
julia --project -e 'using Pkg; pkg"instantiate"'
julia --project -e 'using Pkg; pkg"precompile"'
```

Note that `--project` activates the environment for the current directory.

## Saving information from ranks

You may want to collect information from MPI ranks and write that out
at the end of the job. The best way to do that is through a `NamedTuple`,
since `MPI.Gather` can deal with that type directly (so long as the contents
are `isbitstype`). The problem with `NamedTuple` is that it is immutable,
so you can't grow it as the code executes.

You can use a dictionary as a convenient way to collect information and then
convert that to a `NamedTuple` before gathering and writing. The keys must be
symbols. For example,

```@example
rankLog = Dict()
# ...do stuff...
rankLog[:startIndex] = 4
rankLog[:endIndex]  = 100
# ...
rankLog[:nPassed] = 289
rankLog[:meanWeight] = 5.667
# ...
nt = (; rankLog...)    # Convert to Named tuple
```

Note that for a dictionary, the order of input is not maintained.

Of course, you can also just make the NamedTuple directly (and then
the order is set by the construction).

```@example
nt = (startIndex=4, endIndex=100, nPassed=289, meanWeight=5.667)
```
