# compile.jl
# Make strongScaling.so with PackageCompiler
# Assumes that strongScalingJob_precompile.jl already exists. If it doesn't, run a short one CPU job
# (setting NALLROWS) with --trace-compile=strongScalingJob_precompile.jl

using Pkg
Pkg.activate(".")

using PackageCompiler

pkgs = Symbol[]
append!(pkgs,
        [Symbol(v.name) for v in values(Pkg.dependencies()) if v.is_direct_dep && v.name != "PackageCompiler"])

startTime = time()
PackageCompiler.create_sysimage(pkgs,
                                sysimage_path = "strongScalingJob.so",
                                precompile_statements_file="strongScalingJob_precompile.jl")
tot_secs = Int(floor(time() - startTime))
@info "System image built in $tot_secs seconds"

# Run with julia ... --sysimage strongScalingJob.so ...