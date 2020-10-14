# Test StopWatch

@testset "StopWatch" begin
    sw = StopWatch()

    @test sw.stamps == ["start"]

    sleep(0.3)
    stamp(sw, "A")
    @test sw.stamps == ["start", "A"]
    @test sw.timeAt[2] - sw.timeAt[1] > 0.2

    sleep(0.3)
    stamp(sw, "B")
    @test sw.stamps == ["start", "A", "B"] 
    @test sw.timeAt[3] - sw.timeAt[2] > 0.2

    nt = asNamedTuple(sw)
    @test (string.(keys(nt)) .== sw.stamps) |> all
    @test (values(nt) .== sw.timeAt) |> all
end