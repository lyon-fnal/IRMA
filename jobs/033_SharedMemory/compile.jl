# compile.jl precompile_file.jl output.so
#
#  Make precompile_file.jl by doing a short run with --trace-compile=precompile_file.jl

using Pkg
Pkg.activate(".")

using PackageCompiler

println("Compiling with $(ARGS[1]) to $(ARGS[2])")

pkgs = Symbol[]
append!(pkgs,
        [Symbol(v.name) for v in values(Pkg.dependencies()) if v.is_direct_dep && v.name != "PackageCompiler"])

startTime = time()
PackageCompiler.create_sysimage(pkgs,
                                sysimage_path = ARGS[2],
                                precompile_statements_file=ARGS[1])
tot_secs = Int(floor(time() - startTime))
@info "System image built in $tot_secs seconds"

# Run with julia ... --sysimage energyByCal.so ...