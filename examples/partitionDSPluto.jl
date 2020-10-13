### A Pluto.jl notebook ###
# v0.12.3

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 11f45404-0d02-11eb-00d4-07fa6580cd90
begin
	using Pkg
	Pkg.activate(".")
	
	using IRMA
	using Plots
	using PlutoUI
end

# ╔═╡ dde229ca-0d01-11eb-3980-3f84d5e35f98
md"""
# partitionDS

Partition a dataset into pieces for handling by multiple MPI ranks
"""

# ╔═╡ d1a55946-0d03-11eb-132a-833a2faddfa3


# ╔═╡ 3222eb32-0d02-11eb-0f7d-5317b9f32085
# Play with 1 million rows and 64 MPI ranks
r1 = partitionDS(1_000_000, 64)

# ╔═╡ a989871c-0d02-11eb-1c95-3fb8aea47e05
l = length.(r1)

# ╔═╡ b9370d7e-0d02-11eb-2866-a9010575fb23
1_000_000/64

# ╔═╡ c065e930-0d02-11eb-1755-0bec993ccab6
# Let's try 96 ranks
r2 = partitionDS(1_000_000, 96)

# ╔═╡ f13f6022-0d02-11eb-1a78-2fb456ea4ebe
l2 = length.(r2)

# ╔═╡ f64386ae-0d02-11eb-18a2-af704fad3c58
histogram(l2, legend = nothing)

# ╔═╡ e594df28-0d03-11eb-2797-13aa60e97545
@bind nRanks Slider(1:200)

# ╔═╡ 131e3b6e-0d03-11eb-3328-fdf27990bc76
r3 = partitionDS(1_000_000, nRanks) ; l3=length.(r3)

# ╔═╡ 2e115a00-0d03-11eb-2df0-85300b691246
histogram(l3, legend=nothing, xlab="Length of partitions for $nRanks ranks")

# ╔═╡ 37b846f8-0d04-11eb-0d9c-ff030427a349
with_terminal() do
	versioninfo(verbose=true)
end

# ╔═╡ Cell order:
# ╠═dde229ca-0d01-11eb-3980-3f84d5e35f98
# ╠═11f45404-0d02-11eb-00d4-07fa6580cd90
# ╠═d1a55946-0d03-11eb-132a-833a2faddfa3
# ╠═3222eb32-0d02-11eb-0f7d-5317b9f32085
# ╠═a989871c-0d02-11eb-1c95-3fb8aea47e05
# ╠═b9370d7e-0d02-11eb-2866-a9010575fb23
# ╠═c065e930-0d02-11eb-1755-0bec993ccab6
# ╠═f13f6022-0d02-11eb-1a78-2fb456ea4ebe
# ╠═f64386ae-0d02-11eb-18a2-af704fad3c58
# ╠═e594df28-0d03-11eb-2797-13aa60e97545
# ╠═131e3b6e-0d03-11eb-3328-fdf27990bc76
# ╠═2e115a00-0d03-11eb-2df0-85300b691246
# ╠═37b846f8-0d04-11eb-0d9c-ff030427a349
