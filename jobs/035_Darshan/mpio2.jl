using MPI
using HDF5
using Test
using Distributed: splitrange

@testset "mpio" begin

MPI.Init()

info = MPI.Info()
comm = MPI.COMM_WORLD

nprocs = MPI.Comm_size(comm)
myrank = MPI.Comm_rank(comm)

@test HDF5.has_parallel()

let fileprop = create_property(HDF5.H5P_FILE_ACCESS)
    HDF5.h5p_set_fapl_mpio(fileprop, comm, info)
    h5comm, h5info = HDF5.h5p_get_fapl_mpio(fileprop)

    # check that the two communicators point to the same group
    if isdefined(MPI, :Comm_compare)  # requires recent MPI.jl version
        @test MPI.Comm_compare(comm, h5comm) === MPI.CONGRUENT
    end
end

# open file in parallel and write dataset
fn = MPI.bcast("/global/cscratch1/sd/lyon/035_Darshan/foo2.h5", 0, comm)
A = 1:100
r = splitrange(1,100, nprocs)
myr = r[myrank+1]
h5open(fn, "w", comm, info) do f
    @test isopen(f)
    g = create_group(f, "mygroup")
    #dset = create_dataset(g, "B", datatype(Int64), ((10,),(-1,)), chunk=(2,), dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE)
    # Can't have extensible non-chunked DS
    dset = create_dataset(g, "B", datatype(Int64), ((100,)), dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE)
    # Need to do the trick that I do in my concatenator of resizing
    # @info "A"
    # HDF5.set_extent_dims(dset, (100,))
    # @info "B"
    dset[myr] = A[myr]
    @info "C"
end

#pv = (;)
pv = (; fapl_mpio=(comm, info), dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE)

MPI.Barrier(comm)
h5open(fn; pv...) do f  # default: opened in read mode, with default MPI.Info()
    @test isopen(f)
    @test keys(f) == ["mygroup"]

    # B = read(f, "mygroup/B", dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE)
    # @show B
    # @test !isempty(B)
    # @test A == vec(B[:, myrank + 1])

    #B = f["mygroup/B"; pv...]  # This line makes a non-collective read
    B = getindex(f, "mygroup/B"; pv...)
    @show B
    @test !isempty(B)
    @show size(B)
    @test A[myr] == B[myr]   # This line makes a collective read
end

# The below won't show up in MPI-IO in darshan since it's not opened with MPIO
# MPI.Barrier(comm)
# h5open(fn) do f  # default: opened in read mode, with default MPI.Info()
#     @test isopen(f)
#     @test keys(f) == ["mygroup"]

#     B = f["mygroup/B"]
#     @test !isempty(B)
#     @test A == vec(B[:, myrank + 1])
# end

#MPI.Barrier(comm)

#B = h5read(fn, "mygroup/B", fapl_mpio=(comm, info), dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE)
#@test A == vec(B[:, myrank + 1])

#MPI.Barrier(comm)

#B = h5read(fn, "mygroup/B", (:, myrank + 1), fapl_mpio=(comm, info), dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE)
#@test A == vec(B)

# we need to close HDF5 and finalize the info object before finalizing MPI
finalize(info)
HDF5.h5_close()

MPI.Barrier(MPI.COMM_WORLD)

MPI.Finalize()

end # testset mpio
