### A Pluto.jl notebook ###
# v0.12.6

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

# ╔═╡ 917ff9d8-1d76-11eb-1af0-351d5813d0b7
# Activate the environment
begin
	import Pkg
	Pkg.activate(".")
	using Revise
end

# ╔═╡ a11c923e-1d76-11eb-0af5-83e938fcff90
using IRMA, JLD2, FileIO, Glob, Pipe

# ╔═╡ f2da6b1e-1d76-11eb-0435-8dc16feb5c8a
using DataFrames

# ╔═╡ 50257d22-1d77-11eb-0fb2-9570ba4ff787
using PlutoDataTable

# ╔═╡ a743fbf6-1d77-11eb-3114-c58d7b04c30a
begin
	using Plots
	using StatsPlots
	gr()
end

# ╔═╡ bafe471e-1d77-11eb-2f1a-f3fdfb8443fe
using PlutoUI

# ╔═╡ 2f2dcba8-1e04-11eb-284d-0370759e352a
using Statistics

# ╔═╡ 84df14fe-1d8d-11eb-01dc-891d76596eb4
using CSV

# ╔═╡ f2e153e2-1e03-11eb-3642-8bf0e7348539
md"""
Again, we see that some nodes are faster than others for reading. 
"""

# ╔═╡ fe855f90-1e03-11eb-3ccc-cf0a6095334a
md"""
Here's a box and whisker plot of total MPI time...
"""

# ╔═╡ 178d47dc-1e04-11eb-2ae7-4de3ea3c36b9
md"""
Let's just look at the reading time and see if that scales appropriately. 
"""

# ╔═╡ 5dec95ea-1e0c-11eb-1cfa-276a78b71109
md"""
There's a bit of variation. Look at the plots in the Code section to see why.

Let's now concentrate on seeing if the reading time scales. We'll take the mean read time for each run...
"""

# ╔═╡ 4692bef6-1e48-11eb-1fa6-0174114f71cb
md"""
We can also look at reducing the number of ranks per node to see if there's any significant i/o contention. Here is the read time for 5 nodes but varying the number of ranks per node.
"""

# ╔═╡ 983b49a8-1e48-11eb-0d91-3158ba41d2fc
md"""
Let's calculate the fraction of time in contention; that is the difference between the measured read time and the expected time divided by the measured read time.
"""

# ╔═╡ d088a212-1e55-11eb-2657-d9e89d853243
md"""
## Conclusions

These results are improved and more stable by using `PackageCompiler.jl`. Things that I conclude from this study.

* Use `PackageCompiler.jl`
* 32 tasks per node seems to involve significant i/o contention
* Configuring a large number of nodes takes a signifcant amount of time. 
"""

# ╔═╡ 79e0f08e-1d76-11eb-1a11-1bddf98596ca
md"""
## Code
"""

# ╔═╡ 80b90388-1d76-11eb-230f-99e2ee4af207
# Wide screen
html"""<style>
main {
    max-width: 1100px;
}
"""

# ╔═╡ b1aaaf82-1d76-11eb-06c4-45f42d8dcda9
const datapath = "/Users//lyon/Development/gm2/data/003_StrongScaling_pkgc/"

# ╔═╡ c37d747e-1d76-11eb-3e08-bf3a3aa53185
histoFiles32 = @pipe glob("histos_*32.jld2", datapath) |> basename.(_)

# ╔═╡ e82f0cc4-1d76-11eb-2672-7f3a9c82e1f7
md"""
### Timing information
"""

# ╔═╡ 0380bbb2-1d77-11eb-0ec4-3b3569531417
# Extract number of nodes
function extractNNodesFromFileName(fileName::String)
	m = match(r"histos_(\d+)x32", fileName)
	@pipe m.captures[1] |> parse(Int, _)
end

# ╔═╡ 2f89abba-1d77-11eb-158a-b166fe4afb0f
extractNNodesFromFileName.(histoFiles32)

# ╔═╡ 3b5c10c2-1d77-11eb-33cd-232b777b8cca
# Read histos_nx32.jld2 file and return a dataframe
function dataFrameFromRankData(fileName::String, extractFcn)
	numNodes = extractFcn(fileName)
	data = load(joinpath(datapath, fileName))  # Load the JLD2 file
	rt = rankTimings(data["allTimings"])       # Extract the rank timings
	rl = data["allRankLogs"]                   # Get the log info
											   # Number of rows processed	
	
	numRanks = length(rl)                      # How many ranks?
	
	# Construct the DataFrame by columns
	df = DataFrame(numNodes=fill(numNodes, numRanks), rank=0:numRanks-1, 
		           numRows=[r.len for r in rl])
	df = hcat(df, DataFrame(rt))     # Convert the named tuple of timings to DataFrame
	df = hcat(df, DataFrame(totalTime=rankTotalTime(data["allTimings"])))
	return df
end

# ╔═╡ 579bb3a0-1d77-11eb-2242-5b3301216485
# Make dataframe from all of the files
df = let
	df = vcat( dataFrameFromRankData.(histoFiles32, extractNNodesFromFileName)...);
	sort!(df)
	df
end;

# ╔═╡ 6c852922-1d77-11eb-2eef-d32e163a84bd
gdf = groupby(df, :numNodes);

# ╔═╡ 92a70b66-1d77-11eb-31d5-dbb06521237a
theNumNodes = [ k[1] for k in keys(gdf) ]

# ╔═╡ 9da1bf52-1d77-11eb-062f-f7765794f9ed
# Make plots for a group
function plotsForRun(df)
	cols = 3:ncol(df)  # Don't plot numNodes and rank columns
	p = []
	for i in cols
		yaxis = i==3 ? "# rows read" : "seconds"
		push!(p, scatter(df.rank, df[i], legend=nothing, title=names(df)[i], xaxis="Rank", yaxis=yaxis,
				         xticks=0:32:20*32, titlefontsize=11, xguidefontsize=8, markersize=2))
	end
	p
end

# ╔═╡ c6d5df28-1d77-11eb-256e-89d9034841a7
@bind e Slider(1:length(gdf))

# ╔═╡ e5614e9a-1d77-11eb-36ea-b955f4178bac
md"""
### Plots for run with $(theNumNodes[e]) nodes (32 ranks per node)
"""

# ╔═╡ d065be66-1d77-11eb-069e-7bc2bdb60950
plot(plotsForRun(gdf[e])..., size=(1000,700), layout=(5,2))

# ╔═╡ 2e8480da-1d79-11eb-05a5-4d6d94574b9c
strongScalingPlot = @df df boxplot(:numNodes, :totalTime, legend=nothing, title="Strong Scaling Study (one plot)", 
				    	            xaxis="Number of nodes", yaxis="Total time(s)", size=(800,600))

# ╔═╡ 11cf637a-1e04-11eb-317e-f7cd97e24dec
strongScalingPlot

# ╔═╡ 526193cc-1d7f-11eb-2dbd-311a4fe3d103
totalMPITimes = combine(gdf, :totalTime => maximum)

# ╔═╡ 70482446-1d7f-11eb-2a92-ad846c8c2de5
maxMPITimesPlot = @df totalMPITimes scatter(:numNodes, :totalTime_maximum, legend=nothing, 
	xaxis="Number of nodes", yaxis="Maximum total time", ylim=(0, 50))

# ╔═╡ 287549f0-1e04-11eb-0bb1-177fabe30c11
md"""
Let's look at the read time scaling. Determine the average read time 
"""

# ╔═╡ 3adf5d06-1e04-11eb-23ca-9bd92ca49c85
dataSetReadTimePlot = @df df boxplot(:numNodes, :readDataSet, legend=nothing, title="Dataset read time", 
				    	            xaxis="Number of nodes", yaxis="read time (s)", size=(800,600))

# ╔═╡ 215d1d6e-1e04-11eb-2da0-3bbf185df079
dataSetReadTimePlot

# ╔═╡ afc6e0f2-1e05-11eb-04b6-41873f33a2a9
begin
	maxMeanReadTimes = combine(gdf, :readDataSet => maximum, :readDataSet => mean)
	transform!(maxMeanReadTimes, [:numNodes, :readDataSet_mean] => ( (n, t) -> t[1] ./ (n ./ n[1]) ) => :expectedFromMean)
end

# ╔═╡ f56bd370-1e47-11eb-17b1-4158ffd26cc6
md"""
The expected time is anchored at the 2 node run. So a four node run should be twice as fast if the scaling were perfect. And what we see is pretty close. $maxMeanReadTimes
"""

# ╔═╡ 346dbc7c-1e06-11eb-1d42-557bcc22d4b1
readTimePlot = @df maxMeanReadTimes scatter(:numNodes, [:readDataSet_mean :expectedFromMean], 
										xaxis="Number of nodes", yaxis="Read time (s)")

# ╔═╡ e0fd25c2-1e47-11eb-20f8-63a20147461f
readTimePlot

# ╔═╡ a0ac30e4-1e06-11eb-2d4d-e1f1aefa1cf3
md"""
So there does seem to be a litle bit of contention for large number of nodes).
"""

# ╔═╡ 0c83c85e-1d80-11eb-3b22-37ad8ccda65d
md"""
## Examine Fewer tasks per node
"""

# ╔═╡ 56250cfc-1d80-11eb-2806-e94f2ba001d7
const histoFiles5 =  @pipe glob("histos_5x*.jld2", datapath) |> basename.(_)

# ╔═╡ 774f753e-1d80-11eb-39b2-afa1789d8540
# Extract number of nodes
function extractNTasksFromFileName(fileName::String)
	m = match(r"histos_5x(\d+)", fileName)
	@pipe m.captures[1] |> parse(Int, _)
end

# ╔═╡ ad549e0a-1d82-11eb-084c-41b7155c142d
extractNTasksFromFileName.(histoFiles5)

# ╔═╡ cb5dedc8-1d82-11eb-0c6c-855bc7714822
# Make dataframe from all of the files
df5 = let
	df = vcat( dataFrameFromRankData.(histoFiles5, extractNTasksFromFileName)...);
	rename!(df, :numNodes => :numTasks)
	sort!(df)
	df
end;

# ╔═╡ c3b0bda4-1d83-11eb-2f44-5bb5173cd478
gdf5 = groupby(df5, :numTasks);

# ╔═╡ 40be76c4-1d84-11eb-2346-e910f1cead97
strongScalingPlot5 = @df df5 boxplot(:numTasks, :totalTime, legend=nothing, title="Strong Scaling Study with 5 nodes (one plot)", 
				    	            xaxis="Number of tasks", yaxis="Total time (s)", size=(800,600))

# ╔═╡ 3ffe022e-1d8c-11eb-2ba1-7159cf6f2fa9
total5MPITimes = combine(gdf5, :totalTime => maximum)

# ╔═╡ 7a7ff770-1d6b-11eb-1cc7-d9fbaa1ba60a
md"""
# Strong Scaling Study with PackageCompiler

Adam Lyon, Muon g-2 IRMA Analysis, Fermilab @ Home, November 2020

This notebook examines strong scaling properties of Julia IRMA jobs making just one plot. See the `strongScaling.jl` notebook for background. For this notebook, the [PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl) was run to compile functions needed by the job. Doing so improved the Julia startup time significantly. 

This notebook answers issue [Analyze results from Strong Scaling jobs #18](https://github.com/lyon-fnal/IRMA/issues/18) and code may be found in [PR #20](https://github.com/lyon-fnal/IRMA/pull/20). This file is [IRMA/analyses/018\_StrongScaling/StrongScaling\_pkgc.jl](https://github.com/lyon-fnal/IRMA/blob/lyon-fnal/issue18/analyses/018_StrongScaling/strongScaling_pkgc.jl).

## What is this notebook?

This is a [Pluto.jl](https://github.com/fonsp/Pluto.jl/blob/master/README.md) notebook and the code here is written in [Julia](https://julialang.org). This is like a Jupyter notebook, but with important differences. The most important difference is that the results appear *above* the code. Another important difference is that Pluto.jl notebooks are *reactive*. This means that unlike Jupyter notebooks, Pluto.jl notebooks are always in a consistent state. The notebook keeps track of the cell-to-cell dependencies and when a cell changes, the dependent cells update at the same time. This means that while you are looking at a static html representation of the notebook, you can be assured that the notebook is consistent and up-to-date. You'll see that some results have a little triangle next to them. Clicking on that will open an expanded view of the results. 

The organization of this notebook is that the main results are replicated at the top, with discussion, in the *Results* section. The plots are stored in variables which you can see below the plot. You can look in the *Code* section, which has all code for this notebook, to see how the plot was made.


## Introduction

This notebook examines strong scaling properties of my Julia IRMA jobs that make one plot of energy of clusters. Nearly all of the runs used the maximum 32 physical cores on each node (tasks). I ran with $(join(theNumNodes, ", ", ", and ")) nodes. To look for conflicts between tasks on nodes, I ran 5 nodes with $(join(total5MPITimes[:numTasks], ", ", ", and ")) tasks.

On 11/2, I ran [IRMA/jobs/003_StrongScaling/strongScalingJob.jl](https://github.com/lyon-fnal/IRMA/blob/master/jobs/003_StrongScaling/strongScalingJob.jl) that was compiled by `PackageCompiler.jl` from commit [823ce57] (https://github.com/lyon-fnal/IRMA/commit/823ce576cb0aeda92fd16cdc0e30e2e0a3e75ca0) of `master` ([PR #22](https://github.com/lyon-fnal/IRMA/pull/22)). See [this comment](https://github.com/lyon-fnal/IRMA/issues/3#issuecomment-720786838) in issue #3.

I ran over era 2D data, which amounted to approximately 16B rows. The total HDF5 file size is 250 GB.

[PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl) (see [documentation](https://julialang.github.io/PackageCompiler.jl/dev/)) allows for precompilation of functions that are actually used by the Julia script. A shared object (`.so`) file is loaded at Julia start time. Using `PackageCompiler.jl` significantly improves the time it takes to load packages and functions do not need to be JIT compiled, speeding up the code. In MPI environment, using `PackageCompiler.jl` is ideal to avoid each rank doing its own JIT compilation. The downside of `PackageCompiler.jl` is that the compiled code in the shared object file is fixed, and so if you update packages to new versions, you may have a mistmatch. But given that the environment is pretty carefully controlled, this isn't much of a problem.

This notebook is an update to a previous analysis Pluto notebook at [IRMA/analyses/018_StrongScaling/StrongScaling.jl](https://github.com/lyon-fnal/IRMA/blob/lyon-fnal/issue18/analyses/018_StrongScaling/strongScaling.jl). That analysis did not use `PackageCompiler.jl` and there seemed to be significant time loading packages and compiling. This notebook using `PackageCompiler.jl` shows signficant stability and improvement in timings. 

There are occaisonal anomalies. I did a 10 node job that took an extremely long time, running it again produced more normal looking timings. 

## Results

There are several types of results.

### Histogram comparison

This was done in the previous notebook without `PackageCompiler.jl`. I did not re-run this analysis. 

### MPI Timing information

I record the time in the job with an IRMA [Stopwatch](https://lyon-fnal.github.io/IRMA/dev/stopwatch/). The stopwatch uses `MPI.Wtime` under the hood. The times are recorded as follows.

| Label | Meaning |
|:------|:--------|
| start | After packages are loaded, functions are defined, and `MPI.Init` call
| openedFile | After the `h5open` statement|
| openedDataSet | After the energy dataset is opened (but no data read yet) |
| determineRanges | After the ranges to examine are determined with [partitionDS](https://lyon-fnal.github.io/IRMA/dev/partitionDS/)|
| readDataSet | After the dataset is read (this reads the actual data for the rank) |
| makeHistogram | After the data is histogrammed |
| gatheredHistograms | After all the histograms have been gathered to the root rank |
| reducedHistograms | After the histograms have been reduced to the root rank |
| gatherRankLogs | After the rank's log info has been gathered to the root rank |

Timing of anything before `start` is not recorded.

Let's look at the timing plots. Note that you can see all the [timing plots](#timingPlots) in the Code section. Some representative plots will be reproduced here.

Here is a run using **three** nodes (and 32 ranks per node). 

$(plot(plotsForRun(gdf[2])..., size=(1000,700), layout=(5,2)))

Each rank reads about 175,375,305 rows (or one more). These timings are slightly better than without `PackageCompiler.jl` (package loading is not shown here). 

And here's **ten** nodes...

$(plot(plotsForRun(gdf[7])..., size=(1000,700), layout=(5,2)))

"""

# ╔═╡ cdbfe924-1d8c-11eb-1470-31a7e6a5ad2f
transform!(total5MPITimes, [:numTasks, :totalTime_maximum] => ( (n, t) -> t[1] ./ (n./n[1])) => :expected)

# ╔═╡ a12136a2-1d8c-11eb-2ddc-c1ba25d0f839
max5MPITimesPlot = @df total5MPITimes scatter(:numTasks, [:totalTime_maximum :expected], 
	xaxis="Number of tasks", yaxis="Maximum total time", ylim=(0, 200))

# ╔═╡ b2e8b0ea-1e07-11eb-1cd7-b1ddde1de568
md"""
Let's look at the read times...
"""

# ╔═╡ 60b38d6e-1e08-11eb-17f8-b146ffe0fe42
begin
	maxMean5ReadTimes = combine(gdf5, :readDataSet => maximum, :readDataSet => mean)
	transform!(maxMean5ReadTimes, [:numTasks, :readDataSet_mean] => ( (n, t) -> t[1] ./ (n ./ n[1]) ) => :expectedFromMean)
	transform!(maxMean5ReadTimes, [:readDataSet_mean, :expectedFromMean] => (-) => :diff )
	transform!(maxMean5ReadTimes, [:diff, :readDataSet_mean] => ( (d, r) -> d./r * 100) => :diffPerc )
end

# ╔═╡ 19761aa4-1e4a-11eb-1094-6b7d3e2b1ad4
md"""
So the above plot suggests that fewer ranks per node is more efficient. When we ask for 32 nodes, we are possibly wasting about 30% of the read time in i/o contention. Here's a table,...

$maxMean5ReadTimes

Remember, there are always 5 nodes in the job. 
"""

# ╔═╡ 04440aec-1e0b-11eb-2aa4-e7d737a4e252
max5ReadTimesPlot = @df maxMean5ReadTimes scatter(:numTasks, [:readDataSet_mean :expectedFromMean], 
	xaxis="Number of tasks", yaxis="Read time time (s)")

# ╔═╡ 7ba0096e-1e48-11eb-3062-49a3d2991d8b
max5ReadTimesPlot

# ╔═╡ cd806a5c-1e08-11eb-117a-b537392348e8
md"""
This actually looks nice - very efficient.

Trying it as a log plot...
"""

# ╔═╡ a3bebb9a-1e08-11eb-3b00-3f82147e3fa3
max5ReadTimesLogPlot = @df maxMean5ReadTimes scatter(:numTasks, [:readDataSet_mean :expectedFromMean], 
	xaxis="Number of tasks", yaxis="Read time time (s)", yscale=:log10, yticks=(1:15:180, 1:15:180))

# ╔═╡ 4ecd3f3e-1e0b-11eb-0255-3b88c6846981
md"""
Plot the difference...
"""

# ╔═╡ 41ee8584-1e0b-11eb-3cbf-e749dcceb519
max5ReadTimesDiffPlot = @df maxMean5ReadTimes scatter(:numTasks, :diffPerc, legend=nothing,
            										  xaxis="Number of tasks", yaxis="Percentage of time in contention (%)")

# ╔═╡ 9d746b5c-1e48-11eb-1f8c-156345ab99cf
max5ReadTimesDiffPlot

# ╔═╡ 792d7826-1d8d-11eb-2385-0b26b46c0f48
md"""
## Examine accounting information
"""

# ╔═╡ 88501c1e-1d8d-11eb-2fc6-7f6145b4fbe7
sacct = CSV.File(joinpath(datapath, "003_pkgc.csv")) |> DataFrame

# ╔═╡ e1e2d014-1d8d-11eb-15aa-ed687f9ec093
slurmLogFiles = @pipe glob("slurm-*.out", datapath) |> basename.(_)

# ╔═╡ 48ec2ab2-1d8e-11eb-08a2-93b5fafec096
function jobIdFromSlurmLogName(fn)
	m = match(r"slurm-(\d+)", fn)
	m.captures[1]
end

# ╔═╡ 52e4c718-1d8e-11eb-17f8-a57ffd7d1289
slurmIds = jobIdFromSlurmLogName.(slurmLogFiles)

# ╔═╡ 6f551184-1d8e-11eb-3f08-e708fa476fd8
# Select out the jobIds that we care about
function selectDesiredJobIds(jobIds)
	sacctM = filter(:JobID => j -> occursin.(jobIds, j) |> any, sacct)
	
	# And don't care about the batch or extern jobs (not sure what they are)
	filter!(:JobName => jn -> jn != "batch" && jn != "extern", sacctM)
	
	sacctM
end

# ╔═╡ 7f67f328-1d8e-11eb-1319-77ac3f18a103
sacctM = selectDesiredJobIds(slurmIds)

# ╔═╡ f93a3e40-1d8e-11eb-2829-a94282707dee
# Split the table into Julia and total info
function splitIntoJuliaAndTotal(df)
	filter!([:NNodes, :JobID] => (n, j) -> n != 5 || occursin("35817716", j), df) # Remove 5 x less than 32 tasks
	totalInfo = filter(:JobName => jn -> jn != "julia", df)
	juliaInfo = filter(:JobName => jn -> jn == "julia", df)
	return totalInfo, juliaInfo
end

# ╔═╡ 6fa87670-1d8f-11eb-26de-b3e5e5606a95
totalInfo, juliaInfo = splitIntoJuliaAndTotal(sacctM);

# ╔═╡ 8952dfdc-1d8f-11eb-2e87-dbd47c96db67
runTimesPlot = begin
	@df totalInfo scatter(:NNodes, :ElapsedRaw, label="Total batch time", xaxis="Number of nodes", yaxis="Time (s)")
	@df juliaInfo scatter!(:NNodes, :ElapsedRaw, ylim=(0, 80), label="total julia time")
	@df totalMPITimes scatter!(:numNodes, :totalTime_maximum, label="MPI julia time")
end

# ╔═╡ a04fdc2e-1e4a-11eb-24c3-ff5f8bace154
md"""
### Accounting Information

We can extract accounting information from the SLURM batch system to see how long the jobs took. 

$runTimesPlot

The total batch time is the total wall clock time for the job. The total Julia time is how much time the `srun julia ...` command took within the batch script. The MPI Julia time is the amount of time that was recorded within MPI. Note that the latter does not include the time it took to start Julia and load packages as well as the time to write the results to disk. 

The difference between the total batch and julia times are likely due to setting up the requested number of nodes. This time appears to be significant when requesting a large number of nodes. The total Julia time shape is puzzling, though it appears it is most efficient around six or seven nodes. Not clear why it increases and why it appears to turn over before twenty nodes. 
"""

# ╔═╡ Cell order:
# ╟─7a7ff770-1d6b-11eb-1cc7-d9fbaa1ba60a
# ╟─f2e153e2-1e03-11eb-3642-8bf0e7348539
# ╟─fe855f90-1e03-11eb-3ccc-cf0a6095334a
# ╠═11cf637a-1e04-11eb-317e-f7cd97e24dec
# ╟─178d47dc-1e04-11eb-2ae7-4de3ea3c36b9
# ╠═215d1d6e-1e04-11eb-2da0-3bbf185df079
# ╟─5dec95ea-1e0c-11eb-1cfa-276a78b71109
# ╠═e0fd25c2-1e47-11eb-20f8-63a20147461f
# ╟─f56bd370-1e47-11eb-17b1-4158ffd26cc6
# ╟─4692bef6-1e48-11eb-1fa6-0174114f71cb
# ╠═7ba0096e-1e48-11eb-3062-49a3d2991d8b
# ╟─983b49a8-1e48-11eb-0d91-3158ba41d2fc
# ╠═9d746b5c-1e48-11eb-1f8c-156345ab99cf
# ╟─19761aa4-1e4a-11eb-1094-6b7d3e2b1ad4
# ╟─a04fdc2e-1e4a-11eb-24c3-ff5f8bace154
# ╟─d088a212-1e55-11eb-2657-d9e89d853243
# ╠═79e0f08e-1d76-11eb-1a11-1bddf98596ca
# ╠═80b90388-1d76-11eb-230f-99e2ee4af207
# ╠═917ff9d8-1d76-11eb-1af0-351d5813d0b7
# ╠═a11c923e-1d76-11eb-0af5-83e938fcff90
# ╠═b1aaaf82-1d76-11eb-06c4-45f42d8dcda9
# ╠═c37d747e-1d76-11eb-3e08-bf3a3aa53185
# ╟─e82f0cc4-1d76-11eb-2672-7f3a9c82e1f7
# ╠═f2da6b1e-1d76-11eb-0435-8dc16feb5c8a
# ╠═0380bbb2-1d77-11eb-0ec4-3b3569531417
# ╠═2f89abba-1d77-11eb-158a-b166fe4afb0f
# ╠═3b5c10c2-1d77-11eb-33cd-232b777b8cca
# ╠═50257d22-1d77-11eb-0fb2-9570ba4ff787
# ╠═579bb3a0-1d77-11eb-2242-5b3301216485
# ╠═6c852922-1d77-11eb-2eef-d32e163a84bd
# ╠═92a70b66-1d77-11eb-31d5-dbb06521237a
# ╠═a743fbf6-1d77-11eb-3114-c58d7b04c30a
# ╠═9da1bf52-1d77-11eb-062f-f7765794f9ed
# ╠═bafe471e-1d77-11eb-2f1a-f3fdfb8443fe
# ╠═c6d5df28-1d77-11eb-256e-89d9034841a7
# ╠═e5614e9a-1d77-11eb-36ea-b955f4178bac
# ╠═d065be66-1d77-11eb-069e-7bc2bdb60950
# ╠═2e8480da-1d79-11eb-05a5-4d6d94574b9c
# ╠═526193cc-1d7f-11eb-2dbd-311a4fe3d103
# ╠═70482446-1d7f-11eb-2a92-ad846c8c2de5
# ╟─287549f0-1e04-11eb-0bb1-177fabe30c11
# ╠═3adf5d06-1e04-11eb-23ca-9bd92ca49c85
# ╠═2f2dcba8-1e04-11eb-284d-0370759e352a
# ╠═afc6e0f2-1e05-11eb-04b6-41873f33a2a9
# ╠═346dbc7c-1e06-11eb-1d42-557bcc22d4b1
# ╟─a0ac30e4-1e06-11eb-2d4d-e1f1aefa1cf3
# ╟─0c83c85e-1d80-11eb-3b22-37ad8ccda65d
# ╠═56250cfc-1d80-11eb-2806-e94f2ba001d7
# ╠═774f753e-1d80-11eb-39b2-afa1789d8540
# ╠═ad549e0a-1d82-11eb-084c-41b7155c142d
# ╠═cb5dedc8-1d82-11eb-0c6c-855bc7714822
# ╠═c3b0bda4-1d83-11eb-2f44-5bb5173cd478
# ╠═40be76c4-1d84-11eb-2346-e910f1cead97
# ╠═3ffe022e-1d8c-11eb-2ba1-7159cf6f2fa9
# ╠═cdbfe924-1d8c-11eb-1470-31a7e6a5ad2f
# ╠═a12136a2-1d8c-11eb-2ddc-c1ba25d0f839
# ╟─b2e8b0ea-1e07-11eb-1cd7-b1ddde1de568
# ╠═60b38d6e-1e08-11eb-17f8-b146ffe0fe42
# ╠═04440aec-1e0b-11eb-2aa4-e7d737a4e252
# ╟─cd806a5c-1e08-11eb-117a-b537392348e8
# ╠═a3bebb9a-1e08-11eb-3b00-3f82147e3fa3
# ╟─4ecd3f3e-1e0b-11eb-0255-3b88c6846981
# ╠═41ee8584-1e0b-11eb-3cbf-e749dcceb519
# ╠═792d7826-1d8d-11eb-2385-0b26b46c0f48
# ╠═84df14fe-1d8d-11eb-01dc-891d76596eb4
# ╠═88501c1e-1d8d-11eb-2fc6-7f6145b4fbe7
# ╠═e1e2d014-1d8d-11eb-15aa-ed687f9ec093
# ╠═48ec2ab2-1d8e-11eb-08a2-93b5fafec096
# ╠═52e4c718-1d8e-11eb-17f8-a57ffd7d1289
# ╠═6f551184-1d8e-11eb-3f08-e708fa476fd8
# ╠═7f67f328-1d8e-11eb-1319-77ac3f18a103
# ╠═f93a3e40-1d8e-11eb-2829-a94282707dee
# ╠═6fa87670-1d8f-11eb-26de-b3e5e5606a95
# ╠═8952dfdc-1d8f-11eb-2e87-dbd47c96db67
