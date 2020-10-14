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
