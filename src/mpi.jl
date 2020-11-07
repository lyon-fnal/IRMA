# mpi - Helper functions for MPI

"""deserializeArray(a, s)
    When you use MPI.Gather, you get one long array with all of the contents from the ranks mushed together.
    They need to be separated and deserialized.

    Returns an array of deserialized objects

    a is the array of data all mushed together
    s is an array of the data size for each rank

"""
function deserializeArray(a, s)
    startAt=1
    out = []
    for endAt in s
        push!(out, MPI.deserialize(a[startAt:startAt+endAt-1]))
        startAt += endAt
    end
    return out
end

"""mpiGatherSerialized(obj, isroot, root, comm)

    Serializes the object, determines the size, calls MPI.Allgather on the sizes,
    calls MPI.Allgather on the serialized data, deserializes the data.

    Returns an array of deserialized data from all of the ranks

    obj is the object to serialize and send
    isroot is a boolean which is true if this rank is the root rank
    root is the root rank id
    comm is the MPI communicator
"""
function mpiGatherSerialized(obj, isroot, root, comm)
    s = MPI.serialize(obj)
    allSLen = MPI.Gather(length(s), root, comm)
    allS    = MPI.Gather(s, root, comm)
    allData = nothing
    if isroot
        allData = deserializeArray(allS, allSLen)
    end
    return allData
end