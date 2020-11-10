### A Pluto.jl notebook ###
# v0.12.7

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

# ╔═╡ 0eb38a88-1fb0-11eb-22c7-67df7708cc1a
# Activate environment
begin
	import Pkg
	Pkg.activate(".")
	using Revise
end

# ╔═╡ 87d6720e-1fb0-11eb-181f-ddd8dd4c126b
using IRMA, JLD2, FileIO, Glob, Pipe, Format

# ╔═╡ 17ae39f6-1fb2-11eb-2cac-ab48c77304ce
# Load the Pickle package (https://github.com/chengchingwen/Pickle.jl)
# Note that if we do `using Pickle` we'll get an annoying shadow for FileIO.load
using Pickle: store, stores

# ╔═╡ ea808044-1fd7-11eb-337a-4d1c284bf117
begin
	using Plots
	using StatsPlots
end

# ╔═╡ 8f1f0f28-1fd8-11eb-1f5a-41314f5d7fc7
using PlutoUI

# ╔═╡ 70fb7972-22bb-11eb-0ef7-270590a973dc
using StatsBase

# ╔═╡ 63c3acfa-1faf-11eb-02ee-d502c7095761
md"""
# Plots for JamesS

Put histograms into a python pickle file for James Stapleton.
"""

# ╔═╡ 94695622-1faf-11eb-1c81-7905182aa851
md"""
## Code
"""

# ╔═╡ a2c2cf00-1faf-11eb-0714-1d1df849983f
# Wide screen
html"""<style>
main {
	max-width: 1100px;
}</style>
"""

# ╔═╡ 91a3e3c0-1fb0-11eb-3702-8962c8267fac
const datapath = "/Users/lyon/Development/gm2/data/023_energyByCal"

# ╔═╡ be855f4a-1fb0-11eb-3b4a-e1b786a1b531
# Load one of the files
histoFile = joinpath(datapath, "results", "histos_10x32_2D.jld2")

# ╔═╡ d2ed758c-1fb0-11eb-2be7-c9169fa2a50c
data = load(histoFile)

# ╔═╡ b43c189e-1fb0-11eb-3b53-ab6751b5c410
allHistos = data["allHistos"]

# ╔═╡ 0e2bdbb4-1fb1-11eb-1a4a-affa28e8d206
size(allHistos), size(allHistos[1])

# ╔═╡ 1b0bca2e-1fb1-11eb-1fb5-1f9d7ae21484
md"""
`allHistos` has all of the histograms from all of the ranks. Each rank makes 24 histograms (one for each calorimeter) - that's the inner array. There are 320 ranks - that's the outer array. We want to merge the 24 histograms across the ranks. We need to invert the nesting. That is convert the array of 320 elements and each element with 24 histograms to an array with 24 elements and each element with 320 histograms.
"""

# ╔═╡ 46f7cb38-1fb1-11eb-01a2-7d584b21eaf2
allHistosInv = [ [ allHistos[r][c] for r in eachindex(allHistos) ] for c in eachindex(allHistos[1]) ]

# ╔═╡ 5c377e3a-1fb1-11eb-0a95-69c92021152c
md"""
Now it's easy to do the `reduce` and `merge`
"""

# ╔═╡ 8e96e834-1fb1-11eb-2ee1-df2323a6ff19
rh = reduce.(merge, allHistosInv)

# ╔═╡ bb52bcc2-1fb1-11eb-28cb-77822a7ac61d
# Check the sum of the observations
@pipe [ nobs(anRh) for anRh in rh ] |> sum |> format(_, commas=true)

# ╔═╡ 5cf2a51a-1fb2-11eb-1bc4-89a927084d81
# Make a dictionary ... first of the histogram contents
d = Dict{Any}{Any}("bin_counts_cal$i" => h.counts for (i,h) in enumerate(rh))

# ╔═╡ 3852ff36-1fb5-11eb-04c3-971743f1e5b7
# Add edges, nbins, and bin_width
begin
	e = rh[1].edges |> collect
	d["edges"] = e
	d["nbins"] = length(rh[1].counts)
	d["bin_width"] = e[2] - e[1]
end;

# ╔═╡ 2f1c8844-1fb6-11eb-24e3-ff992eb7358f
d

# ╔═╡ 870a9062-1fb5-11eb-0c20-3d71fbc92a62
md"""
Make the python pickle file.
"""

# ╔═╡ fdeffea2-1fb4-11eb-3f29-075b96bde8e4
store("2D.pkl", d)

# ╔═╡ 8e7dcf4e-1fb5-11eb-0105-198180ecc704
md"""
Here's how you would read it in python...

```python
import pickle
d = pickle.load( open("2D.pkl", "rb") )
do_something_with( d["bin_counts_cal7"] )
```
"""

# ╔═╡ cffbfb38-1fb7-11eb-2dcf-736f67378d9b
md"""
## Functions

Wrap up the above into a function

Need to do

```julia
using JLD2, FileIO
using Pickle: store
```
"""

# ╔═╡ e9b043e0-1fd5-11eb-00c2-a350360e1dd4
function makeMergedHistograms(allHistos)
	allHistosInv = [ [ allHistos[r][c] for r in eachindex(allHistos) ] for c in eachindex(allHistos[1]) ]  # Invert it
	rh = reduce.(merge, allHistosInv)  # The merged histograms
	rh
end

# ╔═╡ d5486290-1fb7-11eb-249d-61ea61e48d64
function jld2ToPickle(jld2File, outputFileName)
	data = load(jld2File)
	allHistos = data["allHistos"]  # Get the histograms
	rh = makeMergedHistograms(allHistos)

	# Construct the histogram
	d = Dict{Any}{Any}("bin_counts_cal$i" => h.counts for (i,h) in enumerate(rh))  # Counts first

	# Add edges, nBins and bin width
	e = rh[1].edges |> collect
	d["edges"] = e
	d["nbins"] = length(rh[1].counts)
	d["bin_width"] = e[2] - e[1]

	# Store it
	store(outputFileName, d)
end

# ╔═╡ 13c3da9a-1fb9-11eb-0008-97b682d9b569
jld2ToPickle( joinpath(datapath, "results", "histos_10x32_2D.jld2"), "2D.pkl")

# ╔═╡ 4b1819b4-1fbd-11eb-2826-657846bfcdd3
jld2ToPickle( joinpath(datapath, "results", "histos_10x32_2E.jld2"), "2E.pkl")

# ╔═╡ 7afbc38e-1fd5-11eb-3e53-d7e36925d098
md"""
## Examine the plots
"""

# ╔═╡ 83cf986e-1fd5-11eb-0520-8590cb09e256
begin
	allHistos_2D = load( joinpath(datapath, "results", "histos_10x32_2D.jld2"), "allHistos" )
	allHistos_2E = load( joinpath(datapath, "results", "histos_10x32_2E.jld2"), "allHistos" )
end

# ╔═╡ d5364e2c-1fd6-11eb-0c1f-415ddfbfa450
begin
	rh_2D = makeMergedHistograms(allHistos_2D)
	rh_2E = makeMergedHistograms(allHistos_2E)
end

# ╔═╡ fbf45a9a-1fd6-11eb-29ba-ef4fb829feb8
@pipe [ nobs(anRh) for anRh in rh_2D ] |> sum |> format(_, commas=true)

# ╔═╡ 0e192b2e-1fd7-11eb-0362-fb6f225ea6ea
@pipe [ nobs(anRh) for anRh in rh_2E ] |> sum |> format(_, commas=true)

# ╔═╡ 939d6a8c-1fd8-11eb-3b45-43b91e663c41
@bind cal2D Slider(1:length(rh_2D))

# ╔═╡ 6658dcac-1fd8-11eb-1c4c-cd76052fbd3f
plot(rh_2D[cal2D], legend=nothing, xaxis="Energy [MeV]", title="Energy for calorimeter $cal2D", alpha=0.2)

# ╔═╡ 004b1458-1fd9-11eb-1c60-97ae1124edf5
@bind cal2E Slider(1:length(rh_2E))

# ╔═╡ 15b3ce00-1fd9-11eb-28f9-edf57fa9a610
plot(rh_2D[cal2E], legend=nothing, xaxis="Energy [MeV]", title="Energy for calorimeter $cal2E")

# ╔═╡ 29c4b60c-1fd9-11eb-2ecf-8b12bf73d0cb
@bind cal Slider(1:length(rh_2E))

# ╔═╡ 336c692a-1fd9-11eb-2e10-63fce8e0bf8c
begin
	p1 = plot(rh_2D[cal], legend=nothing, xaxis="Energy [MeV]", title="2D Energy for calorimeter $cal", xlim=(0,4000), alpha=0.2)
	p2 = plot(rh_2E[cal], legend=nothing, xaxis="Energy [MeV]", title="2E Energy for calorimeter $cal", xlim=(0,4000), alpha=0.2)
	plot(p1, p2, size=(1000,700))
end

# ╔═╡ e02833d4-22b2-11eb-0283-7f2ddd2b9deb
md"""
### Make nicer plots

You can get rid of the lines with `linecolor=:match` or `linecolor=:transparent`.
"""

# ╔═╡ e40a702c-22b2-11eb-284f-0747c31cf941
plot(rh_2D[4], legend=nothing, xaxis="Energy [MeV]", title="Energy for calorimeter $cal2D", linecolor=:match)

# ╔═╡ 1807b9dc-22b3-11eb-0fec-b74f565981b2
md"""
`stephist` is an "open" histogram, but the recipie in `OnlineStats` can't do that. So let's write a little function. See [code in OnlineStats.jl](https://github.com/joshday/OnlineStats.jl/blob/master/src/viz/recipes.jl#L117).

Here's the recipe in `OnlineStats.jl/src/viz/recipes`...

```julia
#-----------------------------------------------------------------------# Histograms
@recipe function f(o::HistogramStat; normalize=true)
    e, c = edges(o), counts(o)
    inds = findfirst(x -> x > 0, c):findlast(x -> x > 0, c)
    normalize --> normalize
    Histogram(e[vcat(inds, inds[end] + 1)], c[inds], _closed(o))
end

_closed(o::Hist) = o.left ? :left : :right 
_closed(o) = :left
```

`counts and edges` are [unexported functions](https://github.com/joshday/OnlineStats.jl/blob/872f9ff514163477faabd79ec2d4899b518c587e/src/stats/histograms.jl#L83) in `OnlineStats.jl/src/stats/histograms.jl`.

`Histogram` is a type defined in `StatsBase.jl` (which `OnlineStats` uses). See [constructor](https://github.com/JuliaStats/StatsBase.jl/blob/d5e6fbc4077160e95c7f46efa1bb69261784d9fb/src/hist.jl#L189). The constructor takes the edges and the weights (and a closed flag).
"""

# ╔═╡ 4b541e3e-22b3-11eb-1ef9-41429012e324
function stephistM(o; normalize=true, kwargs...)
	e, c = o.edges, o.counts
	
	# Find the range of indices that have counts > 0
	inds = findfirst(x -> x > 0, c):findlast(x -> x > 0, c)	# This is a range
	einds = vcat(inds, inds[end]+1)  # Go to one more edge to capture the last bin; remember, length(e) = length(c)+1
		
	closed = o.left ? :left : :right
	
	h = Histogram(e[einds], c[inds], closed)	
end

# ╔═╡ 0b971f9c-22b5-11eb-2423-6162f5929ab2
plot( stephistM(rh_2D[4]) )

# ╔═╡ afe8600a-22bb-11eb-1812-4346c80cdbe9
h  = stephistM(rh_2D[4])

# ╔═╡ 6cc1f7dc-22bb-11eb-1fae-392e2bbf2a55
plot(h, seriestype=:step)

# ╔═╡ 69173c96-22bb-11eb-22b4-9d897a4758e8
h2 = fit!(Hist(-5:0.2:5), randn(1000))

# ╔═╡ 53c94960-22bb-11eb-2fff-6fd73f7be93e
plot(h2, seriestype=:barbins)

# ╔═╡ c4d93fd6-22ff-11eb-0fa0-098d81c98766
gr()

# ╔═╡ c85e9ff2-22ff-11eb-08a2-239eecfe833a
plot(h2, seriestype=:stepbins, legend=nothing, linewidth=3, yminorticks=10)

# ╔═╡ 3720130c-2301-11eb-3d47-af5ff9bc0a10
yticks=[10^x for x =0:7]

# ╔═╡ e6248272-22ff-11eb-2263-0978822d90e6
begin
	plot(rh_2D[1], seriestype=:stepbins, label="calo01", xlim=(0,6200), ylim=(1,5e7), yscale=:log10,
	                xlabel="E [MeV]", ylabel="Counts per 20.0 MeV bin", title="Energy",
	                size=(600,400), yticks=(yticks), minorticks=10, framestyle=:semi)
	plot!(rh_2D[7], seriestype=:stepbins, label="calo07")
	plot!(rh_2D[11], seriestype=:stepbins, label="calo11")
	plot!(rh_2D[16],  seriestype=:stepbins, label="calo16")
	plot!(rh_2D[17],  seriestype=:stepbins, label="calo17")
	plot!(rh_2D[24],  seriestype=:stepbins, label="calo24")
end

# ╔═╡ Cell order:
# ╟─63c3acfa-1faf-11eb-02ee-d502c7095761
# ╟─94695622-1faf-11eb-1c81-7905182aa851
# ╠═a2c2cf00-1faf-11eb-0714-1d1df849983f
# ╠═0eb38a88-1fb0-11eb-22c7-67df7708cc1a
# ╠═87d6720e-1fb0-11eb-181f-ddd8dd4c126b
# ╠═91a3e3c0-1fb0-11eb-3702-8962c8267fac
# ╠═be855f4a-1fb0-11eb-3b4a-e1b786a1b531
# ╠═d2ed758c-1fb0-11eb-2be7-c9169fa2a50c
# ╠═b43c189e-1fb0-11eb-3b53-ab6751b5c410
# ╠═0e2bdbb4-1fb1-11eb-1a4a-affa28e8d206
# ╟─1b0bca2e-1fb1-11eb-1fb5-1f9d7ae21484
# ╠═46f7cb38-1fb1-11eb-01a2-7d584b21eaf2
# ╟─5c377e3a-1fb1-11eb-0a95-69c92021152c
# ╠═8e96e834-1fb1-11eb-2ee1-df2323a6ff19
# ╠═bb52bcc2-1fb1-11eb-28cb-77822a7ac61d
# ╠═17ae39f6-1fb2-11eb-2cac-ab48c77304ce
# ╠═5cf2a51a-1fb2-11eb-1bc4-89a927084d81
# ╠═3852ff36-1fb5-11eb-04c3-971743f1e5b7
# ╠═2f1c8844-1fb6-11eb-24e3-ff992eb7358f
# ╟─870a9062-1fb5-11eb-0c20-3d71fbc92a62
# ╠═fdeffea2-1fb4-11eb-3f29-075b96bde8e4
# ╟─8e7dcf4e-1fb5-11eb-0105-198180ecc704
# ╟─cffbfb38-1fb7-11eb-2dcf-736f67378d9b
# ╠═e9b043e0-1fd5-11eb-00c2-a350360e1dd4
# ╠═d5486290-1fb7-11eb-249d-61ea61e48d64
# ╠═13c3da9a-1fb9-11eb-0008-97b682d9b569
# ╠═4b1819b4-1fbd-11eb-2826-657846bfcdd3
# ╟─7afbc38e-1fd5-11eb-3e53-d7e36925d098
# ╠═83cf986e-1fd5-11eb-0520-8590cb09e256
# ╠═d5364e2c-1fd6-11eb-0c1f-415ddfbfa450
# ╠═fbf45a9a-1fd6-11eb-29ba-ef4fb829feb8
# ╠═0e192b2e-1fd7-11eb-0362-fb6f225ea6ea
# ╠═ea808044-1fd7-11eb-337a-4d1c284bf117
# ╠═8f1f0f28-1fd8-11eb-1f5a-41314f5d7fc7
# ╠═939d6a8c-1fd8-11eb-3b45-43b91e663c41
# ╠═6658dcac-1fd8-11eb-1c4c-cd76052fbd3f
# ╠═004b1458-1fd9-11eb-1c60-97ae1124edf5
# ╠═15b3ce00-1fd9-11eb-28f9-edf57fa9a610
# ╠═29c4b60c-1fd9-11eb-2ecf-8b12bf73d0cb
# ╠═336c692a-1fd9-11eb-2e10-63fce8e0bf8c
# ╟─e02833d4-22b2-11eb-0283-7f2ddd2b9deb
# ╠═e40a702c-22b2-11eb-284f-0747c31cf941
# ╟─1807b9dc-22b3-11eb-0fec-b74f565981b2
# ╠═4b541e3e-22b3-11eb-1ef9-41429012e324
# ╠═0b971f9c-22b5-11eb-2423-6162f5929ab2
# ╠═70fb7972-22bb-11eb-0ef7-270590a973dc
# ╠═afe8600a-22bb-11eb-1812-4346c80cdbe9
# ╠═6cc1f7dc-22bb-11eb-1fae-392e2bbf2a55
# ╠═69173c96-22bb-11eb-22b4-9d897a4758e8
# ╠═53c94960-22bb-11eb-2fff-6fd73f7be93e
# ╠═c4d93fd6-22ff-11eb-0fa0-098d81c98766
# ╠═c85e9ff2-22ff-11eb-08a2-239eecfe833a
# ╠═3720130c-2301-11eb-3d47-af5ff9bc0a10
# ╠═e6248272-22ff-11eb-2263-0978822d90e6
