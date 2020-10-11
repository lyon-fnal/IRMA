using IRMA

using Test
using OnlineStats: Hist, fit!

@testset "SHist" begin

    
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