using RandomizedPropertyTest
# See https://gitlab.com/quf/randomizedpropertytest.jl for RandomizedPropertyTest.jl info

# Partition a dataset
@testset "Partition dataset" begin
    
    # Want to have a function like 
    # ranges = partitionDS(dataSetLength, nRanks)
    # Then ranges[i+1] is the range for the ith rank (e.g. 1:100) [remember, ranks start at 0]
    # Note that there's a function that kind of does this already ... Distributed.splitrange. 
    # Wrap this so we don't get strange errors

    # More ranks than elements should throw
    @test_throws DomainError partitionDS(100, 101)

    # Zero elements should throw
    @test_throws DomainError partitionDS(0, 100)

    # Zero ranks should throw
    @test_throws DomainError partitionDS(100, 0)

    # If we have one rank, then that rank gets the whole thing (default n = 10^4)
    @test @quickcheck (partitionDS(l, 1)) == [1:l] (l :: Range{Int64, 1, 1_000_000})

    # So long as the length of the dataset is larger than the number of ranks, 
    # the length of the partition list is the number of ranks
    @test @quickcheck (partitionDS(1_000_000, n) |> length == n) (n :: Range{Int64, 1, 1_000_000}) 

    # If we can split evenly, then each rank gets the same number of elements
    r = partitionDS(1_000_000, 100)
    @test all(length.(r) .== length(r[1]))

    # Need a test in case things are uneven
end