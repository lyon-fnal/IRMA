# Partition a dataset 

"""
    partitionDS(dsLength, nRanks)

    Given the length of a dataset (or anything, really), determine and return partitions over 
    nRanks MPI ranks that are as close to the same size as possible. This is really just a wrapper 
    around Distributed.splitrange with some added error checking to produce nice messages. 
"""
function partitionDS(dsLength::Int, nRanks::Int)
    dsLength <= 0 && throw( DomainError(dsLength, "Must have at least one element") )
    nRanks <= 0 && throw( DomainError(nRanks, "Must have at least one rank"))
    !(dsLength >= nRanks) && throw( DomainError(dsLength, "Must have more elements than ranks"))

    splitrange(1, Int(dsLength), Int(nRanks))
end
