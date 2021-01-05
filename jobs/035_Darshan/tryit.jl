@info "A"
using HDF5
@info "B"
using MPI

@info "C"
using Libdl

@info "D"
MPI.Init()
const comm = MPI.COMM_WORLD
const info = MPI.Info()


@info "HI"

@show Libdl.dllist()

@info "E"
f = joinpath(ENV["CSCRATCH"], "irmaData2/merged/irmaData_2C_merged.h5")

@info "F"
h = h5open(f, "r", comm, info, dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE)

@info "G"
xds = h["ReconEastClusters/x", dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE]

@info "H"
@show length(xds)

@info "J"
x = xds[20_921_764_790:22_921_764_790]
    
@info "K"

close(xds)

close(h)