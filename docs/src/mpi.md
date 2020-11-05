# MPI helper functions

This IRMA package contains some helper functions for MPI.

`mpiGatherSerialized` will serialize an object and do an MPI Gather operation on it. For example,

```julia

allHistos = mpiGatherSerialized(hists, isroot, root, comm)
if isroot
    # Do something with allHistos
end
```
