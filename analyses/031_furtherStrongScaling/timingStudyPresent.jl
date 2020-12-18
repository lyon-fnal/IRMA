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

# ╔═╡ d5cb4316-4028-11eb-340e-19e4116c4105
using IRMA, JLD2, FileIO, Glob, Chain, PlutoUI

# ╔═╡ 0453712c-4029-11eb-214d-8b00ff6fde65
using Statistics, DataFrames, CategoricalArrays, NaturalSort, ThreadsX

# ╔═╡ 91bdf7b6-402a-11eb-0cc1-17462ed1dede
begin
	using Plots, StatsPlots
	gr()
end

# ╔═╡ f247e40a-4027-11eb-3746-d5b070890cd7
md"""
# Muon g-2

![](https://news.fnal.gov/wp-content/uploads/2019/03/muon-g-2-17-0188-20.hr_-1024x684.jpg)
"""

# ╔═╡ 31ff23d8-4028-11eb-1e34-c94e8566eada
md"""
# Calorimeters

![](https://ars.els-cdn.com/content/image/1-s2.0-S0168900219310824-gr1.jpg)
![](https://ars.els-cdn.com/content/image/1-s2.0-S0168900215014060-gr1.jpg)
"""

# ╔═╡ ede61202-4029-11eb-2e2e-296b034a1fcf
md"""
# Jobs
Ran jobs with $n$ nodes and $m$ tasks (ranks) per node on native Cori Haswell (debug queue). 

Data were spread evenly among ranks and read in.

Some jobs with 4 nodes used collective i/o (MPIO) for reads. Others used non-collective i/o.

Timings are obtained with comparing `MPI_Wtime` before and after function call. 

Coded in [Julia](https://julialang.org) using [MPI.jl](https://github.com/JuliaParallel/MPI.jl) and [HDF5.jl](https://github.com/JuliaIO/HDF5.jl) (this notebook is run by [Pluto.jl](https://github.com/fonsp/Pluto.jl)).
"""

# ╔═╡ b8600e56-402d-11eb-1511-a95313717404
md"""
# Collective vs non-Collective I/O
"""

# ╔═╡ 63bb6fa2-4033-11eb-172a-77930ed3d813
md"""
## Energy Dataset
"""

# ╔═╡ 7cc52222-4033-11eb-23b0-053daf8a7d57
md"""
## Time Dataset
"""

# ╔═╡ a35c7976-4033-11eb-32db-fb4fc7342a8f
md"""
## Calorimeter index dataset
"""

# ╔═╡ cb257066-4033-11eb-15f6-e198a2f1a9e7
md"""
## Total read time
"""

# ╔═╡ c0376d86-4028-11eb-25cc-298c16e79635
md"""
# Code
"""

# ╔═╡ baffc404-402c-11eb-0b18-27f984b63ee1
# Wide screen
html"""<style>
main {
	max-width: 1100px;
}</style>
"""

# ╔═╡ 34a2c458-4034-11eb-3ec3-434058547662
br = HTML("<br>")

# ╔═╡ bfa30ebe-4019-11eb-052b-254a135892bb
md"""
# Muon g-2 data and HDF5 I/O

Adam Lyon (FNAL)
2020-12-17
$(html"<button onclick=present()>Present</button>")

$br

Goal: Run g-2 histogram generating code at NERSC for drastic speed improvement.

- Convert *needed* g-2 data to HDF5 on FermiGrid
- Move files to HPC (NERSC)
- Concatenate into large "era" files
- Process into Histograms for analysis and fitting

"""

# ╔═╡ aab15f6e-4021-11eb-0255-8bf8071e81a1
md"""
# Data Characteristics

Storing 10 columns of data: $(HTML("<br/>"))
`run, subrun, event, bunchNum, caloIndex, islandIndex, time, energy, x, y`

For `irmaData_2C_merged.h5` each column has 22,921,764,790 (23B) rows. All data stored with deflate(6) and shuffle. Chunksize 1MB (262,144 chunks). Floats are single precision.
 
$br

|    Column   | Type  | Compression factor |
|:-----------:|-------|-------------|
| run         | int   | 1000        |
| subrun      | int   | 1002        |
| event       | int   | 829         |
| bunchNum    | int   | 866         |
| caloIndex   | int   | 167         |
| islandIndex | int   | 4.5         |
| time        | float | 1.4         |
| energy      | float | 1.23        |
| x           | float | 1.23        |
| y           | float | 1.3         |


"""

# ╔═╡ ed679ac8-4033-11eb-1b00-85de7e7182e5
md"""
# My conclusions

$br

**Ideal configuration seems to be 20 nodes and 6 ranks per node.**

$br 

Things to try
- Increasing chunk size (262,144 are a lot of chunks; maybe aim for around 10,000?)
- Removing shuffle from the floats
- Changing compression
- Removing compression?
- I/O profiling (is `Darshan` worthwhile?)
"""

# ╔═╡ cb47eebc-4028-11eb-1783-cb905d0f2b19
begin
	import Pkg
	Pkg.activate(".")
end

# ╔═╡ e63b2cae-4028-11eb-004d-135fb009e507
# Define file locations
begin
	const mpio_path = expanduser(
		"~/Development/gm2/data/025_furtherStrongScaling/tenNodes_2C_mpio")
	const noCl_path = expanduser(
		"~/Development/gm2/data/025_furtherStrongScaling/2C_noCollective")
end;

# ╔═╡ eeb69844-4028-11eb-2fd6-17129590808b
begin
	const mpio_files = glob("*.jld2", mpio_path) 
	const noCl_files = glob("*.jld2", noCl_path) 
end;

# ╔═╡ 14795120-4029-11eb-1750-9348051564db
Threads.nthreads()

# ╔═╡ 28782bd6-4029-11eb-18c3-5b42a85857b3
function dataFrameFromHistoFile(fileName::String)
	data = load(fileName)
	gl = data["globalLog"]  # Dictionary
	rl = data["allRankLogs"]    # Array of dictionaries
	at = rankTimings(data["allTimings"])
	
	# Turning the nNodes and nTasks into ints is not really useful, 
	# and it makes for unecessarily spaced out plots. 
	# Let's make them categories!
	nNodes = gl[:nnodes]
	nTasks = gl[:ntasks]
	
	nRanks = length(rl)
	
	df = DataFrame(nNodes=categorical(fill(nNodes, nRanks)), 
		           nTasks=categorical(fill(nTasks, nRanks)), 
		           rank=0:nRanks-1, nRows=[r.len for r in rl])
	df = hcat(df, DataFrame(at))  # Convert the named tuple to data frame

	# Add a total read time column
	transform!(df, r"^read" => (+) => :readTotal)
	
	# Determine the total time
	df = hcat(df, DataFrame(totalTime=rankTotalTime(data["allTimings"])))

	return df
end

# ╔═╡ 5d7ade40-4029-11eb-1b95-9f323fc77bdc
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
		
	df
end

# ╔═╡ c952dc94-4029-11eb-0956-99cc2c630cdc
# Group 
gdf = groupby(df, [:jobType, :nNodes, :nTasks]);

# ╔═╡ ca561bd0-402a-11eb-1c33-7590b68c7437
# Make plots for a group
function plotsForRun(df)
    cols = 5:ncol(df)  # Don't plot numNodes and rank columns
    p = []
    for i in cols
        yaxis = i==5 ? "# rows read" : "seconds"
        push!(p, scatter(df.rank, df[!, i], legend=nothing, 
				 title=names(df)[i], xaxis="Rank", yaxis=yaxis,
                 xticks=0:32:20*32, titlefontsize=11, xguidefontsize=8, 
				 markersize=2))
    end
    p
end

# ╔═╡ ec2592a4-402a-11eb-2a94-6d7744e89b4f
# Make the list for the selection box
const selList = [ string(k) => "$(v.jobType) $(v.nNodes)x$(v.nTasks)"
	                                      for (k,v) in enumerate(keys(gdf))]

# ╔═╡ 69368eba-402b-11eb-1572-bd26be244522
md"""
# Timings

$(@bind e Select(selList))
"""

# ╔═╡ 0472a37e-402b-11eb-16aa-d1f54de3535c
# Some helper functions
begin
	keyInt(e) = parse(Int, e)
	
	function makeTitle(e)
		theKey = keys(gdf)[keyInt(e)]
		theKeyTitle = "$(theKey.nNodes) x $(theKey.nTasks) with $(string(theKey.jobType))"
	end
	
	cticks(ctg::CategoricalArray) = (1:length(levels(ctg)), levels(ctg))
end

# ╔═╡ f11c05ca-402c-11eb-0d7c-11bda08eb943
plot(plotsForRun(gdf[keyInt(e)])..., size=(1000,900), layout=(5,3))

# ╔═╡ c56aaafc-402d-11eb-1065-59426edb6437
let
	p1 = @df filter(r->r.jobType == "noCollective" && r.nNodes == "10", df) boxplot(levelcode.(:nTasks), :readTotal, 
		                            title="Read time No Collective (10 nodes)", fillalpha=0.2,
                                    xticks=cticks(:nTasks), xaxis="Number of ranks/node (nonlinear scale)", 
									yaxis="read time (s)", legend=nothing)
	
	p2 = @df filter(r->r.jobType == "mpio" && r.nNodes == "10", df) boxplot(levelcode.(:nTasks), :readTotal,
		                            title="Read time MPIO (10 nodes)", fillalpha=0.2,
									xticks=cticks(:nTasks),
                                    xaxis="Number of ranks/node (nonlinear scale)", yaxis="read time (s)", 
									legend=nothing, color=:orange)
	
	plot(p1, p2, layout=(2,1), ylim=(60, 170) , size=(800,800))
end

# ╔═╡ 9dd8f49e-402d-11eb-1bc4-d1a2bf901b0a
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

# ╔═╡ 09141b32-4031-11eb-11e8-61afc5c7fdc7


# ╔═╡ 0ffb3e12-4031-11eb-0fc9-7116581b5bbb
readCols = names(gdf, r"read")

# ╔═╡ 352d2a4a-402e-11eb-169f-db685f0d8aa6
# Let's collect median time and maxTime and construct the total number of processes
begin
	dfc = combine(gdf, [:readEnergyDataSet, :readTimeDataSet, :readCaloDataSet, :readTotal, :filledHistograms] .=> median,
   				 	   [:readEnergyDataSet, :readTimeDataSet, :readCaloDataSet, :readTotal, :filledHistograms] .=> maximum)
	transform!(dfc, [:nNodes, :nTasks] => ( (n,t) -> categorical(string.(@. parse(Int,string(n)) * parse(Int,string(t))))) => :nProcs)
	levels!(dfc.nProcs, sort(levels(dfc.nProcs), lt=natural))
	
	# Add some ideal scaling lines
	addIdealScaling!(dfc, :filledHistograms_median)
end 

# ╔═╡ a4ba655a-4031-11eb-155e-0dd5fec38861
# Plot median and maximum of column
function plotMedianAndMax(c)
	
	if c == "total"
		colName = "readTotal"
	else
		colName = "read"*c*"DataSet"
	end
	
	cMedianTime  = Symbol(colName*"_median")
	cMaximumTime = Symbol(colName*"_maximum")
	@show cMedianTime
	
	p1 = @df dfc plot(levelcode.(:nTasks), dfc[!, cMedianTime], title="Median $c read time (s)", 
									line=2, group=(:nNodes, :jobType), marker=(:dot), xticks=cticks(:nTasks),
                                    xaxis="Number of ranks/node (nonlinear scale)", yaxis="Median read time (s)",size=(800,600))
	
	p2 = @df dfc plot(levelcode.(:nTasks), dfc[!, cMaximumTime], title="Maximum $c read time (s)", 
									line=2, group=(:nNodes, :jobType), marker=(:dot), xticks=cticks(:nTasks),
									xaxis="Number of ranks/node (nonlinear scale)", yaxis="Maximum read time (s)",size=(800,600))
	
	plot(p1, p2, layout=(2,1), legend=:outerright, size=(1000,800))
end


# ╔═╡ 6a03b3e2-4033-11eb-176a-db0026f25c57
plotMedianAndMax("Energy")

# ╔═╡ 96cd29a8-4033-11eb-234b-adf2fcff7906
plotMedianAndMax("Time")

# ╔═╡ ac71cd04-4033-11eb-26eb-9f4284e5dd5c
plotMedianAndMax("Calo")

# ╔═╡ d23baa98-4033-11eb-1d7a-c1ed199db7a6
plotMedianAndMax("total")

# ╔═╡ c9026eb0-4092-11eb-2959-5b9c530c2548
@save "timingStudyPresent.jld2" df gdf dfc

# ╔═╡ Cell order:
# ╟─bfa30ebe-4019-11eb-052b-254a135892bb
# ╟─f247e40a-4027-11eb-3746-d5b070890cd7
# ╟─31ff23d8-4028-11eb-1e34-c94e8566eada
# ╟─aab15f6e-4021-11eb-0255-8bf8071e81a1
# ╟─ede61202-4029-11eb-2e2e-296b034a1fcf
# ╟─69368eba-402b-11eb-1572-bd26be244522
# ╟─f11c05ca-402c-11eb-0d7c-11bda08eb943
# ╟─b8600e56-402d-11eb-1511-a95313717404
# ╟─c56aaafc-402d-11eb-1065-59426edb6437
# ╟─63bb6fa2-4033-11eb-172a-77930ed3d813
# ╟─6a03b3e2-4033-11eb-176a-db0026f25c57
# ╟─7cc52222-4033-11eb-23b0-053daf8a7d57
# ╟─96cd29a8-4033-11eb-234b-adf2fcff7906
# ╟─a35c7976-4033-11eb-32db-fb4fc7342a8f
# ╟─ac71cd04-4033-11eb-26eb-9f4284e5dd5c
# ╟─cb257066-4033-11eb-15f6-e198a2f1a9e7
# ╟─d23baa98-4033-11eb-1d7a-c1ed199db7a6
# ╟─ed679ac8-4033-11eb-1b00-85de7e7182e5
# ╟─c0376d86-4028-11eb-25cc-298c16e79635
# ╠═baffc404-402c-11eb-0b18-27f984b63ee1
# ╠═34a2c458-4034-11eb-3ec3-434058547662
# ╠═cb47eebc-4028-11eb-1783-cb905d0f2b19
# ╠═d5cb4316-4028-11eb-340e-19e4116c4105
# ╠═e63b2cae-4028-11eb-004d-135fb009e507
# ╠═eeb69844-4028-11eb-2fd6-17129590808b
# ╠═0453712c-4029-11eb-214d-8b00ff6fde65
# ╠═14795120-4029-11eb-1750-9348051564db
# ╠═28782bd6-4029-11eb-18c3-5b42a85857b3
# ╠═5d7ade40-4029-11eb-1b95-9f323fc77bdc
# ╠═c952dc94-4029-11eb-0956-99cc2c630cdc
# ╠═91bdf7b6-402a-11eb-0cc1-17462ed1dede
# ╠═ca561bd0-402a-11eb-1c33-7590b68c7437
# ╠═ec2592a4-402a-11eb-2a94-6d7744e89b4f
# ╠═0472a37e-402b-11eb-16aa-d1f54de3535c
# ╠═9dd8f49e-402d-11eb-1bc4-d1a2bf901b0a
# ╠═09141b32-4031-11eb-11e8-61afc5c7fdc7
# ╠═0ffb3e12-4031-11eb-0fc9-7116581b5bbb
# ╠═352d2a4a-402e-11eb-169f-db685f0d8aa6
# ╠═a4ba655a-4031-11eb-155e-0dd5fec38861
# ╠═c9026eb0-4092-11eb-2959-5b9c530c2548
