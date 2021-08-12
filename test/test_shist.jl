using OnlineStats: Hist, fit!, Series

@testset "SHist Construction" begin    
    h = fit!(Hist(-5:0.2:5), randn(1000))
    sh = SHist(h)
    hh = Hist(sh)

    @testset "HistToSHist" begin
        @test sh isa SHist
        @test isbits(sh)   # This is the important one
        @test sh.counts == h.counts
        @test sh.out == h.out
        @test sh.edges == h.edges
    end

    @testset "SHistToHist" begin
        @test hh isa Hist
        @test hh.counts == h.counts
        @test hh.out == h.out
        @test hh.edges == h.edges
    end
end

@testset "SHist merging" begin
    h1 = fit!(Hist(-5:0.2:5), randn(1000))
    sh1 = SHist(h1)

    h2 = fit!(Hist(-5:0.2:5), randn(1000))
    sh2 = SHist(h2)

    hm  = merge(h1, h2)
    shm = merge(sh1, sh2)

    @test shm.counts == hm.counts
    @test isbits(shm)
end

@testset "SHist Series" begin
    
    # Try named tuple
    ser1   = Series(h1=Hist(-5:0.2:5), h2=Hist(-10:0.2:10))
    fit!(ser1,  randn(1_000))
    sher1  = Series((; zip(keys(ser1.stats), SHist.(values(ser1.stats)))... ))

    @test sher1.stats.h1.counts == ser1.stats.h1.counts
    @test sher1.stats.h1.out    == ser1.stats.h1.out

    ser2 = Series(h1=Hist(-5:0.2:5), h2=Hist(-10:0.2:10))
    fit!(ser2, randn(1_000))
    sher2 = Series((; zip(keys(ser2.stats), SHist.(values(ser2.stats)))... ))

    @test isbits(sher1)
    @test isbits(sher2)

    serm  = merge(ser1, ser2)
    sherm = mergeStatsCollectionWithSHist(sher1, sher2)

    @test isbits(sherm)
    @test serm.stats.h1.counts == sherm.stats.h1.counts
    @test serm.stats.h2.counts == sherm.stats.h2.counts
end