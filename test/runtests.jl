using IRMA

using Test
using OnlineStats: Hist

@testset "SHist" begin

    h = fit!(Hist(-5:0.2:5), randn(1000))

    sh = SHist(h)

    @test sh isa SHist
    @test isbits(sh)   # This is the important one
    @test sh.counts == h.counts
    @test sh.out == h.out
    @test sh.edges == h.edges

    hh = Hist(sh)

    @test hh isa OnlineStats.Hist
    @test hh.counts == h.counts
    @test hh.out == h.out
    @test hh.edges == h.edges

end