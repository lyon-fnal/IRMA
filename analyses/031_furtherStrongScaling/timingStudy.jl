### A Pluto.jl notebook ###
# v0.12.17

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

# ╔═╡ 7502e30a-2b9b-11eb-39bb-69503dc11b71
begin
	using IRMA, JLD2, FileIO, Glob, Chain
	# Chain is pre-release - see https://github.com/jkrumbiegel/Chain.jl
end

# ╔═╡ 65996120-2ba8-11eb-0aac-d79dea1c016d
using Statistics, DataFrames, CategoricalArrays, NaturalSort, ThreadsX

# ╔═╡ 4e2b9ad4-2bb8-11eb-25c2-4525c723eef8
using PlutoUI

# ╔═╡ 896856e2-2bc1-11eb-236f-7991e4bd3078
begin
    using Plots
    using StatsPlots
    gr()
end

# ╔═╡ a57da1ca-2bb7-11eb-2171-33e1b086afe6
# Wide screen
html"""<style>
main {
	max-width: 1100px;
}</style>
"""

# ╔═╡ 1e15f640-2b9b-11eb-3e35-a1de91609aef
begin
    import Pkg
    Pkg.activate(".")
 
end

# ╔═╡ 648ae8f8-3ff8-11eb-3dc2-8f3fb64a3d74
Pkg.status()

# ╔═╡ 85f34826-2b9b-11eb-32f1-0dd72aa845ee
# If Julia was started with -t auto, then we can do multi-threading
Threads.nthreads()

# ╔═╡ 8cfced8c-2ba7-11eb-25df-5b25fdf0ec9b
begin
	const mpio_path = expanduser(
		"~/Development/gm2/data/025_furtherStrongScaling/tenNodes_2C_mpio")
	const noCl_path = expanduser(
		"~/Development/gm2/data/025_furtherStrongScaling/2C_noCollective")
end;

# ╔═╡ a860d49e-2ba7-11eb-1c0f-27c7690212f5
begin
	mpio_files = glob("*.jld2", mpio_path) 
	noCl_files = glob("*.jld2", noCl_path) 
end;

# ╔═╡ 72614d64-2ba8-11eb-1e01-d32b58c6afc6
# The files are now self-describing. Let's look at one of them
data = load(mpio_files[4])

# ╔═╡ 92613386-2ba8-11eb-273d-a5a247d5282f
data["globalLog"]

# ╔═╡ 01ddb492-2bbf-11eb-3241-65d33948d8a7
data["allRankLogs"][1]

# ╔═╡ b5af958a-2ba8-11eb-3d7e-5d2aca803f86
mpio_files[4]

# ╔═╡ ae8ad178-2bb7-11eb-3aea-bf8aca6f8697
# Let's look at the histograms from this file
ac = data["allCalibratedHists"];

# ╔═╡ d621c2ca-2bb7-11eb-3789-d15b5fe39d1a
# So we have the problem that we have an array of arrays...
# ac[rank][cal]
(length(ac), length(ac[6]))

# ╔═╡ fd49a228-2bb7-11eb-154c-09c8ce925f88
ac[5][5]

# ╔═╡ 11a02206-2bb8-11eb-284b-c510f9200644
# We want to reduce across the ranks, leaving 24 total histograms (one for each calorimeter) - this is hard to do
# Here is a way to reconstruct an "inverse" array
function mergeHistos1(h)
	hInv = [ [ h[r][c] for r in eachindex(h) ] for c in eachindex(h[1]) ] # Make hInv[cal][rank]
	reduce.(merge, hInv)
end

# ╔═╡ a064df3c-2bba-11eb-1728-e3166f6ad280
acAll = @time mergeHistos1(ac)

# ╔═╡ ab1039a6-2bba-11eb-26a2-6d24d8fe5dcb
with_terminal() do
	@time mergeHistos1(ac)
end
# It's really fast - let's not try to multi-thread it

# ╔═╡ a9f1bca0-2bbc-11eb-0dfa-0f7a3f3fe6d0
md"""
## Timings
"""

# ╔═╡ 26f0d070-2bbe-11eb-20f7-377f50f69b56
function dataFrameFromHistoFile(fileName::String)
	data = load(fileName)
	gl = data["globalLog"]  # Dictionary
	rl = data["allRankLogs"]    # Array of dictionaries
	at = rankTimings(data["allTimings"])
	
	# Turning the nNodes and nTasks into ints is not really useful, and it makes for unecessarily spaced out plots. 
	# Let's make them categories!
	# nNodes = parse(Int, gl[:nnodes])
	# nTasks = parse(Int, gl[:ntasks])
	nNodes = gl[:nnodes]
	nTasks = gl[:ntasks]
	
	nRanks = length(rl)
	
	df = DataFrame(nNodes=categorical(fill(nNodes, nRanks)), 
		           nTasks=categorical(fill(nTasks, nRanks)), rank=0:nRanks-1, nRows=[r.len for r in rl])
	df = hcat(df, DataFrame(at))  # Convert the named tuple to data frame
	df = hcat(df, DataFrame(totalTime=rankTotalTime(data["allTimings"])))

	return df
end

# ╔═╡ 7afe88da-2bbf-11eb-0244-1d7e4dcb3a76
df = let
	
	# Load the noCollective jobs
	dfsNoCal = ThreadsX.map(dataFrameFromHistoFile, noCl_files)  # About x2 speedup 
	dfNoCal = vcat(dfsNoCal...)
	jobTypeNoCal = categorical(fill("noCollective", nrow(dfNoCal)))
	
	# Load the mpio jobs
	dfsMpio = ThreadsX.map(dataFrameFromHistoFile, mpio_files)
	dfMpio = vcat(dfsMpio...)
	jobTypeMpio = categorical(fill("mpio", nrow(dfMpio)))
	
	# Merge them
	df = vcat(dfNoCal, dfMpio)
	
	# Add the jobType
	jobType = vcat(jobTypeNoCal, jobTypeMpio)
	insertcols!(df, 1, :jobType=>jobType)
	
	# Sort the nNodes and nTasks levels numerically (not the default lexically)
	levels!(df.nNodes, sort(levels(df.nNodes), lt=natural))
	levels!(df.nTasks, sort(levels(df.nTasks), lt=natural))
	
	# Sort
	sort!(df, [:jobType, :nNodes, :nTasks, :rank])
	
	# Add a total read time column
	transform!(df, r"^read" => (+) => :totalRead)
	
	df
end

# ╔═╡ 1f7f6e5e-2c8a-11eb-1037-213f762294c9
# Let's compare noCollective and MPIO - I have a full suite with 10 jobs
#tenDf = filter(r -> r.nNodes == "10", df)

# ╔═╡ bdac4c8e-2bc0-11eb-0938-071a527bbdb9
gdf = groupby(df, [:jobType,:nNodes,:nTasks]);

# ╔═╡ 08cdcba4-2bc4-11eb-0d97-6b87cfd1c53b
keys(gdf)[12]

# ╔═╡ 9640f970-2d4a-11eb-3464-ab6f4a58e760
keys(gdf)

# ╔═╡ a64bef82-2bc1-11eb-07e8-b306bc335682
# Make plots for a group
function plotsForRun(df)
    cols = 5:ncol(df)  # Don't plot numNodes and rank columns
    p = []
    for i in cols
        yaxis = i==5 ? "# rows read" : "seconds"
        push!(p, scatter(df.rank, df[!, i], legend=nothing, title=names(df)[i], xaxis="Rank", yaxis=yaxis,
                         xticks=0:32:20*32, titlefontsize=11, xguidefontsize=8, markersize=2))
    end
    p
end

# ╔═╡ daa0e6b8-2c8a-11eb-2c84-af526426f9b7
# Build up the selection list for the UI element
selList = [ string(k) => "$(v.jobType) $(v.nNodes)x$(v.nTasks)" for (k,v) in enumerate(keys(gdf))]

# ╔═╡ 419601e0-2f64-11eb-3c81-33f541a9a481
keyInt(e) = parse(Int, e)

# ╔═╡ 4e22de7e-2bc4-11eb-027c-f57b24df3834
function makeTitle(e)
	theKey = keys(gdf)[keyInt(e)]
	theKeyTitle = "$(theKey.nNodes) x $(theKey.nTasks) with $(string(theKey.jobType))"
end

# ╔═╡ 800d45de-2bc2-11eb-08de-a5bb15dc371d
md"""
$(@bind e Select(selList))
"""

# ╔═╡ 7ebf8e44-2f64-11eb-3d46-e90d05ea44fd
md"""
### Plots for $(makeTitle(e)) 
"""

# ╔═╡ b5f8edb4-2bc1-11eb-2093-150d3393b2b2
plot(plotsForRun(gdf[keyInt(e)])..., size=(1000,900), layout=(5,3))

# ╔═╡ fd63d1a2-2cf7-11eb-352e-cb7b5cc26a68
cticks(ctg::CategoricalArray) = (1:length(levels(ctg)), levels(ctg))

# ╔═╡ cf7c0b44-2bc4-11eb-3458-5589d261ec8e
let
	p1 = @df filter(r->r.jobType == "noCollective" && r.nNodes == "10", df) boxplot(levelcode.(:nTasks), :totalRead, 
		                            title="Read time No Collective (10 nodes)", fillalpha=0.2,
                                    xticks=cticks(:nTasks), xaxis="Number of ranks/node (nonlinear scale)", 
									yaxis="read time (s)", legend=nothing)
	
	p2 = @df filter(r->r.jobType == "mpio" && r.nNodes == "10", df) boxplot(levelcode.(:nTasks), :totalRead,
		                            title="Read time MPIO (10 nodes)", fillalpha=0.2,
									xticks=cticks(:nTasks),
                                    xaxis="Number of ranks/node (nonlinear scale)", yaxis="read time (s)", 
									legend=nothing, color=:orange)
	
	plot(p1, p2, layout=(2,1), ylim=(60, 170) , size=(800,800))
end

# ╔═╡ 2e9716a0-2daa-11eb-1044-c920689abccc
""" idealScaling(df, col)

	Make an ideal scaling line for column `col` (symbol) in the dataframe `df`.
	Returns a vector with the scaling that you can then add to the dataframe or keep separate

	The scaling starts at the largest value in col for a jobType and nNodes and goes within that line
"""
function addIdealScaling!(df, col::Symbol)
	
	# Group the dataframe by jobtype and number of nodes
	dfg = groupby(df, [:jobType, :nNodes])
	
	# Find the maximum value of col within each group
	idealValsGroups = []
	for aGroup in dfg
		# Determine the maximum value in the group
		(maxVal,idx) = findmax(aGroup[!, col])
		maxRank = @chain aGroup[idx, :nTasks] begin
					get
					parse(Int, _)
		end
		push!(idealValsGroups, @. maxVal / (parse(Int, get(aGroup[!, :nTasks])) / maxRank))
	end
	idealVals = vcat(idealValsGroups...)
	
	newColName = Symbol( "ideal_" * string(col) )
	insertcols!(df, newColName => idealVals)
	df
end

# ╔═╡ 0c7a892c-2c8e-11eb-2603-ff46f8259ee9
# Let's collect median time and maxTime and construct the total number of processes
begin
	dfc = combine(gdf, :readCaloDataSet => median, :readCaloDataSet => maximum, :filledHistograms => median, :filledHistograms => maximum)
	transform!(dfc, [:nNodes, :nTasks] => ( (n,t) -> categorical(string.(@. parse(Int,string(n)) * parse(Int,string(t))))) => :nProcs)
	levels!(dfc.nProcs, sort(levels(dfc.nProcs), lt=natural))
	
	# Add some ideal scaling lines
	addIdealScaling!(dfc, :filledHistograms_median)
	
end                

# ╔═╡ c8aba650-2c8d-11eb-36de-f76febfa3b52
let
	p1 = @df dfc plot(levelcode.(:nTasks), :readCaloDataSet_median, title="Median total read time (s)", 
									line=2, group=(:nNodes, :jobType), marker=(:dot), xticks=cticks(:nTasks),
                                    xaxis="Number of ranks/node (nonlinear scale)", yaxis="Median read time (s)",size=(800,600))
	
	p2 = @df dfc plot(levelcode.(:nTasks), :readCaloDataSet_maximum, title="Maximum total read time (s)", 
									line=2, group=(:nNodes, :jobType), marker=(:dot), xticks=cticks(:nTasks),
									xaxis="Number of ranks/node (nonlinear scale)", yaxis="Maximum read time (s)",size=(800,600))
	
	plot(p1, p2, layout=(2,1), legend=:outerright, ylim=(0, 60), size=(1000,800))
end

# ╔═╡ 10a37394-2d9d-11eb-287f-51782719f6b0
let
	p1 = @df dfc plot(levelcode.(:nProcs), :totalRead_median, title="Median total read time (s)", 
									line=2, group=(:nNodes, :jobType), marker=(:dot), xticks=cticks(:nProcs),
                                    xaxis="Number of processes (nonlinear scale)", yaxis="Median read time (s)",size=(800,600))
	
	p2 = @df dfc plot(levelcode.(:nProcs), :totalRead_maximum, title="Maximum total read time (s)", 
									line=2, group=(:nNodes, :jobType), marker=(:dot), xticks=cticks(:nProcs),
									xaxis="Number of processes (nonlinear scale)", yaxis="Maximum read time (s)",size=(800,600))
	
	plot(p1, p2, layout=(2,1), legend=:outerright, ylim=(60, 170), size=(1000,800))
end

# ╔═╡ 2cffac5c-2cf2-11eb-0fdc-d7fce2f81d89
let
	p1 = @df filter(r->r.jobType == "noCollective" && r.nNodes == "10", df) boxplot(levelcode.(:nTasks), :filledHistograms, 
		                            title="Histogran fill time with no collective (10 nodes)", fillalpha=0.2, xticks=cticks(:nTasks),
                                    xaxis="Number of ranks/node (nonlinear scale)", yaxis="Fill time (s)", legend=nothing)
	
	p2 = @df filter(r->r.jobType == "mpio" && r.nNodes == "10", df) boxplot(levelcode.(:nTasks), :filledHistograms, 
									title="Histogran fill time with mpio (10 nodes)", 
									fillalpha=0.2, xticks=cticks(:nTasks),
                                    xaxis="Number of ranks/node (nonlinear scale)", yaxis="Fill time (s)", 
		                            legend=nothing, color=:orange)
	
	plot(p1, p2, layout=(2,1), size=(800,800), ylim=(0, 300))
end

# ╔═╡ 91b488e4-2d41-11eb-1b2f-01fa8e8aefcb
let
	p1 = @df dfc plot(levelcode.(:nTasks), :filledHistograms_median, title="Median histograms fill time (s)", 
									line=2, group=(:nNodes, :jobType), marker=(:dot), xticks=cticks(:nTasks),
                                    xaxis="Number of ranks/node (nonlinear scale)", yaxis="Median fill time (s)",size=(800,600))
	
	@df dfc plot!(levelcode.(:nTasks), :ideal_filledHistograms_median, title="Median histograms fill time", 
									line=5, group=(:nNodes, :jobType), xticks=cticks(:nProcs), alpha=0.2)
	
	p2 = @df dfc plot(levelcode.(:nTasks), :filledHistograms_maximum, title="Maximum histograms fill time (s)", 
									line=2, group=(:nNodes, :jobType), marker=(:dot), xticks=cticks(:nTasks),
									xaxis="Number of ranks/node (nonlinear scale)", yaxis="Maximum fill time (s)",size=(800,600))
	
	plot(p1, p2, layout=(2,1), legend=:topright, ylim=(0, 300))
end
# The node 10 curves are on top of each other, as we expect.

# ╔═╡ 190a3394-2d5a-11eb-31c2-138d70ec07fb
let
	ytickVals = [5, 10, 25, 50, 100, 200, 400] ; ytickLabels = string.(ytickVals) ; yticks=(ytickVals, ytickLabels)
	
	p1 = @df dfc plot(levelcode.(:nProcs), :filledHistograms_median, title="Median histograms fill time", 
									line=2, group=(:nNodes, :jobType), marker=(:dot), xticks=cticks(:nProcs), 
	                                ylim=(1, 400))
	
	@df dfc plot!(levelcode.(:nProcs), :ideal_filledHistograms_median, title="Median histograms fill time", 
									line=5, group=(:nNodes, :jobType), xticks=cticks(:nProcs), alpha=0.1, 
									label="")
                                    
	
	p2 = @df dfc plot(levelcode.(:nProcs), :filledHistograms_maximum, title="Maximum histograms fill time", 
									line=2, group=(:nNodes, :jobType), marker=(:dot), xticks=cticks(:nProcs),
									xaxis="Number of processes (nonlinear scale)", ylim=(4,400))
	
	plot(p1, p2, layout=(2,1), legend=:outerright, size=(1000,600),
				               xaxis="Number of processes (nonlinear scale)", yaxis="Fill time (s) [log]",
	                           yscale=:log10, yformatter=:plain, yticks=yticks)
							   
end

# ╔═╡ Cell order:
# ╠═a57da1ca-2bb7-11eb-2171-33e1b086afe6
# ╠═1e15f640-2b9b-11eb-3e35-a1de91609aef
# ╠═648ae8f8-3ff8-11eb-3dc2-8f3fb64a3d74
# ╠═7502e30a-2b9b-11eb-39bb-69503dc11b71
# ╠═85f34826-2b9b-11eb-32f1-0dd72aa845ee
# ╠═8cfced8c-2ba7-11eb-25df-5b25fdf0ec9b
# ╠═a860d49e-2ba7-11eb-1c0f-27c7690212f5
# ╠═65996120-2ba8-11eb-0aac-d79dea1c016d
# ╠═72614d64-2ba8-11eb-1e01-d32b58c6afc6
# ╠═92613386-2ba8-11eb-273d-a5a247d5282f
# ╠═01ddb492-2bbf-11eb-3241-65d33948d8a7
# ╠═b5af958a-2ba8-11eb-3d7e-5d2aca803f86
# ╠═ae8ad178-2bb7-11eb-3aea-bf8aca6f8697
# ╠═d621c2ca-2bb7-11eb-3789-d15b5fe39d1a
# ╠═fd49a228-2bb7-11eb-154c-09c8ce925f88
# ╠═4e2b9ad4-2bb8-11eb-25c2-4525c723eef8
# ╠═11a02206-2bb8-11eb-284b-c510f9200644
# ╠═a064df3c-2bba-11eb-1728-e3166f6ad280
# ╠═ab1039a6-2bba-11eb-26a2-6d24d8fe5dcb
# ╠═a9f1bca0-2bbc-11eb-0dfa-0f7a3f3fe6d0
# ╠═26f0d070-2bbe-11eb-20f7-377f50f69b56
# ╠═7afe88da-2bbf-11eb-0244-1d7e4dcb3a76
# ╠═1f7f6e5e-2c8a-11eb-1037-213f762294c9
# ╠═bdac4c8e-2bc0-11eb-0938-071a527bbdb9
# ╠═08cdcba4-2bc4-11eb-0d97-6b87cfd1c53b
# ╠═9640f970-2d4a-11eb-3464-ab6f4a58e760
# ╠═896856e2-2bc1-11eb-236f-7991e4bd3078
# ╠═a64bef82-2bc1-11eb-07e8-b306bc335682
# ╠═daa0e6b8-2c8a-11eb-2c84-af526426f9b7
# ╠═419601e0-2f64-11eb-3c81-33f541a9a481
# ╠═4e22de7e-2bc4-11eb-027c-f57b24df3834
# ╠═800d45de-2bc2-11eb-08de-a5bb15dc371d
# ╟─7ebf8e44-2f64-11eb-3d46-e90d05ea44fd
# ╠═b5f8edb4-2bc1-11eb-2093-150d3393b2b2
# ╠═fd63d1a2-2cf7-11eb-352e-cb7b5cc26a68
# ╠═cf7c0b44-2bc4-11eb-3458-5589d261ec8e
# ╠═2e9716a0-2daa-11eb-1044-c920689abccc
# ╠═0c7a892c-2c8e-11eb-2603-ff46f8259ee9
# ╠═c8aba650-2c8d-11eb-36de-f76febfa3b52
# ╠═10a37394-2d9d-11eb-287f-51782719f6b0
# ╠═2cffac5c-2cf2-11eb-0fdc-d7fce2f81d89
# ╠═91b488e4-2d41-11eb-1b2f-01fa8e8aefcb
# ╠═190a3394-2d5a-11eb-31c2-138d70ec07fb
