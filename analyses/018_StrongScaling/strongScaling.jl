### A Pluto.jl notebook ###
# v0.12.4

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

# ╔═╡ b36dfae6-14a1-11eb-3dde-57dcaa1b2e1c
# Activate the environment
begin
	import Pkg
	Pkg.activate(".")  # Activate the correct environment
	using Revise
end

# ╔═╡ ef60a404-155f-11eb-346c-79e1bd961a08
# Load initial packags to read the results
using IRMA, JLD2, FileIO, Glob, Pipe

# ╔═╡ 4f745172-156f-11eb-1154-cba14ab2ae06
using OnlineStats

# ╔═╡ fbb294e4-14f4-11eb-0d6a-a5124fadc20f
begin
	using Plots, Measures, StatsPlots
	gr()
end

# ╔═╡ 9eac5e44-1803-11eb-05d7-b38082b77dfa
using StatsBase

# ╔═╡ b5d0b0c4-1570-11eb-3b8b-e502b346560a
using Test

# ╔═╡ a0880064-1575-11eb-0042-e37e09af1a72
using PlutoUI

# ╔═╡ 431a6bca-1577-11eb-0b37-5dcb9872f1c0
# For what it's worth, can we get a single value out of the total time (mean and sd)?
using Statistics

# ╔═╡ be0314cc-1579-11eb-25e1-4704668da772
using DataFrames

# ╔═╡ c2ae74d2-15b3-11eb-35e2-815ef0cd2565
using PlutoDataTable  # Nice prototype DataFrame viewer from https://github.com/mthelm85/PlutoDataTable.jl
                      # They need to work on the number of significant figures

# ╔═╡ ee61bde0-17bc-11eb-2f8e-33a062b5dfd4
using CSV

# ╔═╡ 406a9370-14a0-11eb-069d-113287d17309
md"""
# Strong Scaling Study

Adam Lyon, Muon g-2 IRMA Analysis, Fermilab, October 2020

This notebook examines strong scaling properties of Julia IRMA jobs making just one plot. I ran jobs with 2,3,4,5,6,7,8,9,10,12,15 and 20 nodes and always with 32 tasks per node. If I examine the timings of a part of the Julia run that includes opening and reading the HDF5 input file, creating the histogram, and running `MPI.Reduce` and `MPI.Gather`, I see expected strong scaling. The jobs get faster with more nodes as each task has less of the file to read. If I examine the total elapsed time reported by the batch system, then the scaling is less clear. It almost appears that more nodes make Julia run more slowly. Speculation suggests that perhaps there is contention for loading packages. Next steps could be to try [PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl) to make a Julia "app" with fast startup time. 

This notebook answers issue [Analyze results from Strong Scaling jobs #18](https://github.com/lyon-fnal/IRMA/issues/18) and code may be found in (future PR). This file is (future file). 

## What is this notebook?

This is a [Pluto.jl](https://github.com/fonsp/Pluto.jl/blob/master/README.md) notebook and the code here is written in [Julia](https://julialang.org). This is like a Jupyter notebook, but with important differences. The most important difference is that the results appear *above* the code. Another important difference is that Pluto.jl notebooks are *reactive*. This means that unlike Jupyter notebooks, Pluto.jl notebooks are always in a consistent state. The notebook keeps track of the cell-to-cell dependencies and when a cell changes, the dependent cells update at the same time. This means that while you are looking at a static html representation of the notebook, you can be assured that the notebook is consistent and up-to-date. You'll see that some results have a little triangle next to them. Clicking on that will open an expanded view of the results. 

The organization of this notebook is that the main results are replicated at the top, with discussion, in the *Results* section. The plots are stored in variables which you can see below the plot. You can look in the *Code* section, which has all code for this notebook, to see how the plot was made.

## Introduction 

This notebook examines strong scaling properties of my Julia IRMA jobs that make one plot. 

On 10/22, I ran [IRMA/jobs/003_StrongScaling/strongScalingJob.jl](https://github.com/lyon-fnal/IRMA/blob/master/jobs/003_StrongScaling/strongScalingJob.jl) from commit 82b715b answering issue [#3](https://github.com/lyon-fnal/IRMA/issues/3). This job reads in the cluster energy data from Muon g-2 era 2D and makes a plot of that energy for all clusters. The data is split evenly among all the MPI ranks. I've tried 2 nodes through 10 nodes. I always choose 32 tasks per node (advice from Marc Paterno). I ran the jobs in the debug queue.

On 10/25 I ran three more jobs with 12, 15 and 20 nodes (still 32 tasks per node) respectively. These jobs ran in the regular queue. Note that I ran the 12 node job twice, the first time it ran I got a strange error, I think due to the `CSCRATCH` filesystem crashing (It's been a bad month for Cori). The second time I tried it, it ran fine. I ran these jobs in the regular queue, because the debug queue was very full. 

All jobs ran on Haswell. Data came from `CSCRATCH`. 

I recorded MPI timings from the Julia run. I also dumped SLURM accounting information for analysis. 

## Results

There are several types of results. 

### Histogram comparison

Each rank makes a histogram of cluster energy. All of these histograms are sent to the root rank with `MPI.Gather` and saved in the output file. Furthermore, I "reduce" the histogram by merging them into one with `MPI.Reduce`. See [Histogram Comparison](#histoComp) in the Code section where I compare these histograms to be sure that the reduced one is correct. Note that I'm using a [static histogram](https://lyon-fnal.github.io/IRMA/dev/shist/) defined in the [IRMA.jl](https://github.com/lyon-fnal/IRMA) package that MPI can manipulate directory without the need for serialization/deserialization. See the comparison in Code (see above). The tests worked fine. 

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

Here is the run using **two** nodes (and 32 ranks per node).

"""

# ╔═╡ 5ebefb64-180f-11eb-2f52-b71025782dda
md"""
First, you see that each rank read 263,062,959 rows, or one less. Just opening the file took over 5 seconds, with the root rank taking a little bit longer. Reading the dataset itself takes the majority of the time. The spread of times over ranks is rather interesting. Some ranks took a bit longer to make the histograms. Some ranks were signficantly slower in the `MPI.Gather`, though the structure perhaps shows some clever consolidating in MPI. Reducing the histograms involves every other rank taking about a second longer than the others. Gathering the rank logs is very fast. You see all of this structure in the total MPI time. 

Let's look at **ten** nodes
"""

# ╔═╡ 6e848914-1810-11eb-1a5b-7998a1bc5ed2
md"""
There's quite a bit of structure in these plots. Note that for `readDataSet`, where the data is actually read in, some nodes seem appear to be faster than others.  Given that the reading is fast, but its time still dominates, the structure of the `reducedHistograms` becomes clear in the total time. 

Here are **twenty** nodes
"""

# ╔═╡ e8c4e2dc-1810-11eb-1ac7-d5afc4ba45b4
md"""
Here is a box plot of the total time vs. number of nodes...
"""

# ╔═╡ 3dfc2368-1812-11eb-1398-a39ac22c1df0
md"""
Since the job is as fast as the slowest rank, let's determine the maxium total time. We can then also determine the predicted cost of the job.
"""

# ╔═╡ 7c11899a-1812-11eb-13c7-fb3f79420e0c
md"""
### Information from the batch system

The above, however, is not the whole story, it seems. I can also get timing information from the batch system with the `sacct` command. I've done this for the jobs run here. This plot,
"""

# ╔═╡ c33b001c-1812-11eb-3941-43652ad5462b
md"""
compares the MPI total time (green points) to the total time the batch system reported for the Julia `srun` step (orange points). The elapsed time for the entire batch job is shown in the blue points. For 6 nodes, the Julia time is longer than the total batch time - that seems nonsensical.

There is a very large discrepancy between the MPI total time and the total Julia and batch time. Furthermore, the total Julia/Batch time for 12, 15 and 20 nodes is markedly higher. That may be due to running in the `regular` queue, though I can't think of a good reason for this. 

The significant difference between the batch times and the MPI time must be Julia startup, package loading and initializing MPI. I don't have specific timings for those steps. Further investigation is required. 

Let's look at the costs for these jobs as computed from the `sacct` data. They match the cost data in IRIS.
"""

# ╔═╡ 0212a640-1814-11eb-1dc8-710a549d22b9
md"""
Let's look at other information from the accounting data.

Here is the maximum RSS reported by a task in MB.
"""

# ╔═╡ 4a6276e6-1814-11eb-3c00-73b032f64d2e
md"""
Here is the maximum VM size. Note that the scale is GB. This looks almost reasonsble, except for the big dip for 15 nodes.
"""

# ╔═╡ 835ce67a-1814-11eb-2625-97b7f548d836
md"""
We can look at the maximum bytes read (note scale is MB)...
"""

# ╔═╡ 95a757fc-1814-11eb-352e-5d219e060c88
md"""
and maximum bytes written. (not scale is KB)...
"""

# ╔═╡ bd2a63c8-1814-11eb-30d3-bd719d9bf8dd
md"""
## Conclusions  

It is clear that there is a significant fraction of the Julia run that I am not including in my MPI timing. When I look at the scaling of timing reported by the batch system, the scaling is nonsensical, especially for the 12, 15 and 20 node runs. Could that be due to running them in the regular queue instead of the debug queue? How much time does it take to start Julia, load packages and initialize MPI? Could there be contention for disk when Julia is starting and packages are loaded?

## Next steps

Try to add timing information for loading packages and initializing MPI. Perhaps try [PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl) to speed up loading. Run everything in the debug queue. 
"""

# ╔═╡ aa8b39c0-14a1-11eb-2ef4-5f154b707400
md"""
## Code
"""

# ╔═╡ c6ca90ea-155f-11eb-3c12-ad3c58e5fb55
# Make the screen wide
html"""<style>
main {
    max-width: 1100px;
}
"""

# ╔═╡ 498d7116-14a5-11eb-0785-ad596c074cba
const datapath = "/Users/lyon/Development/gm2/data/003_StrongScaling/"

# ╔═╡ 00da17e6-14a6-11eb-1b60-c9f662572085
histoFiles = @pipe glob("*.jld2", datapath) |> basename.(_)

# ╔═╡ eeb2de64-156e-11eb-1372-1fc46f69a47a
md"""
### One file plots

Get our footting by looking at one results file. 
"""

# ╔═╡ 470075be-14a6-11eb-378b-23fca6496348
# Load in one results file
d = load(joinpath(datapath, "histos_9x32.jld2"))

# ╔═╡ 4d06e004-1570-11eb-36eb-59a086d35dbf
# What's in the file?
keys(d)

# ╔═╡ 57a514b6-180b-11eb-3886-65a0f60af854
html"""<a id="histoComp">Histogram Comparison</a>"""

# ╔═╡ 171e5f10-156f-11eb-075f-817e25e83c41
md"""
Let's look at the histogram information. We have a set of histograms and we have the reduced histogram. They should match. 
"""

# ╔═╡ 2aad16f0-156f-11eb-3751-1b3c58fcf061
allHistos = d["allHistos"]

# ╔═╡ 5a1d937e-156f-11eb-3df2-cd55c8b8abd2
length(allHistos)  # We should have one histogram per rank

# ╔═╡ 5d8c73fe-156f-11eb-1d2a-d5c8bee8a9c3
# Convert our static histograms into Online histograms so we can merge them
allHistsO = Hist.(allHistos)

# ╔═╡ 81994d80-156f-11eb-1568-dd9adf3e573e
# How many histograms have what entries?
nobs.(allHistsO) |> countmap

# ╔═╡ d95cd744-156f-11eb-084c-bb729b7267ed
plot( plot(allHistsO[1]), plot(allHistsO[20]), legend=nothing)

# ╔═╡ 19e3621a-1570-11eb-37ba-6f027bbeee93
# Reduce all of the separate histograms into one
allHistsOS = reduce(merge, allHistsO)

# ╔═╡ 3570cc5c-1570-11eb-17dd-1dee70995a4f
# Compare with the one reduced by MPI
oneHist = d["oneHisto"]

# ╔═╡ 57e58d18-1570-11eb-255e-1dfefb42204f
# Compare the histogram we just got by reduce to the one made by MPI.Reduce
with_terminal() do
	@testset "MPI Reduced Histogram is correct" begin
		@test nobs(oneHist) == nobs(allHistsOS)
		@test all( oneHist.counts .== allHistsOS.counts )
		@test all( oneHist.out .== allHistsOS.out )
	end
end

# ╔═╡ 1fca08ae-1571-11eb-3c34-db5bff78225b
plot( Hist(oneHist), legend=nothing, linealpha=0.0 )

# ╔═╡ a594641e-1571-11eb-2d95-17597bafd987
length(oneHist.counts) # the number of bins

# ╔═╡ fb9964f6-1571-11eb-38ee-ff0a37fd1b4a
md"""
### Let's look at timing information
"""

# ╔═╡ 7e41321e-14f1-11eb-39a0-d1b216e33462
# Look at the timing information
rt = rankTimings(d["allTimings"])

# ╔═╡ 856ccf30-14f3-11eb-293d-8172519d1965
function timingPlotsForRun(timings)
	p = []
	for (k, v) in pairs(timings)
		push!(p, scatter(v, legend=nothing, title=k, xaxis="Rank", yaxis="Seconds",
				         xticks=0:32:20*32, titlefontsize=11, xguidefontsize=8))
	end
	p
end

# ╔═╡ ad69e592-14f3-11eb-11bc-1d25cc268342
h2x32 = plot(timingPlotsForRun(rt)..., size=(1000,800))

# ╔═╡ d12d4280-14f6-11eb-0f2f-89a9acb621d2
# Get the sum
rtSum = rankTotalTime(d["allTimings"])

# ╔═╡ fc0c5188-14f8-11eb-36e0-e584c02cbc0f
scatter(rtSum, legend=nothing, yaxis="total time (seconds)", xaxis="rank", xticks=0:32:20*32)

# ╔═╡ 2465ca36-1573-11eb-1260-7b9f805e91a3
# Get the log information
rankLogs = d["allRankLogs"]

# ╔═╡ 37924274-1573-11eb-31e3-09d6d740f6a1
scatter( [x.len for x in rankLogs], legend=nothing, xaxis="rank", yaxis="Number of rows", xticks=0:32:20*32)

# ╔═╡ a7240894-1577-11eb-2286-21c6187bfb91
( mean(rtSum), std(rtSum) )

# ╔═╡ 03039904-1578-11eb-210d-fddde77525a6
md"""
### DataFrame all the things

Let's look at all of the output files and put the data into a DataFrame
"""

# ╔═╡ c2bcea2e-1579-11eb-1502-359c5e639136
histoFiles

# ╔═╡ 14fead68-157a-11eb-2778-f3d18f6a0063
# Extract number of nodes from histogram file name
function extractNNodesFromFileName(fileName::String)
	m = match(r"histos_(\d+)x", fileName)
	@pipe m.captures[1] |> parse(Int, _)
end

# ╔═╡ 701a2bf8-157a-11eb-266b-e78aabb27330
extractNNodesFromFileName.(histoFiles)

# ╔═╡ 91eb525e-157a-11eb-1a79-818c3ae8b42a
# Read in histos_nx32.jld2 file and return a dataframe
function dataFrameFromRankData(fileName::String)
	numNodes = extractNNodesFromFileName(fileName)
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

# ╔═╡ 4b335b72-1804-11eb-27a6-4f845d7a819b
md"""
Try processing one file...
"""

# ╔═╡ b0b3f712-15b2-11eb-2238-612d3b209598
dfOne = dataFrameFromRankData(histoFiles[2]);

# ╔═╡ f35f498a-15b3-11eb-26db-49d25348dc52
data_table(dfOne)

# ╔═╡ 52488e6e-1804-11eb-3a1c-993e25d773fd
md"""
Now process all of the files...
"""

# ╔═╡ 038ab1a6-15b5-11eb-1adb-093514d8c3ce
# Make a dataframe from all of the files (note the splat operator)
begin
	df = vcat( dataFrameFromRankData.(histoFiles)... );
	sort!(df)
end;

# ╔═╡ 31146e34-15b6-11eb-21e6-49af27395193
data_table(df)

# ╔═╡ 65f67318-15b6-11eb-3357-8d2254e326e3
# Group the dataframes by number of nodes
gdf = groupby(df, :numNodes);

# ╔═╡ 9ff58936-15b7-11eb-3954-b58825211888
theNumNodes = [k[1] for k in keys(gdf)]

# ╔═╡ d53afd5c-15b6-11eb-2543-6794ac45e366
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

# ╔═╡ 3d170482-180f-11eb-3cb7-ddf2ff03cbdc
plot(plotsForRun(gdf[1])..., size=(1000,700), layout=(5,2))

# ╔═╡ 28a44380-1810-11eb-3f34-79e96d39fe69
plot(plotsForRun(gdf[9])..., size=(1000,700), layout=(5,2))

# ╔═╡ b9fc6260-1810-11eb-0d6e-71168149b821
plot(plotsForRun(gdf[12])..., size=(1000,700), layout=(5,2))

# ╔═╡ 7a4a61a6-1626-11eb-3420-33505a62562b
md"""
With the slider below, you can choose which run to view. Note that this is a little glitchy - if not all of the plots appear, then adjust the slider and go back.
"""

# ╔═╡ df9f71d0-180e-11eb-1028-bda3a80294a6
html"""<a id="timingPlots">Timing plots of ranks</a>"""

# ╔═╡ 1a606e0e-15bb-11eb-2bc3-d15ce693a99d
@bind e Slider(1:length(gdf))

# ╔═╡ 315cadc8-15bb-11eb-270e-954f77341c83
md"""
### Plots for run with $(theNumNodes[e]) nodes (32 ranks per node)
"""

# ╔═╡ d5984e66-15b7-11eb-0110-45315ebd865d
plot(plotsForRun(gdf[e])..., size=(1000,700), layout=(5,2))

# ╔═╡ 710f60a0-1804-11eb-3bbb-d1c3f0bc231b
md"""
Plot the scaling...
"""

# ╔═╡ 29006b92-15bd-11eb-094f-b5fc7c703025
strongScalingPlot = @df df boxplot(:numNodes, :totalTime, legend=nothing, title="Strong Scaling Study (one plot)", 
				    	            xaxis="Number of nodes", yaxis="Total time(s)", size=(800,600))

# ╔═╡ faa926a2-1810-11eb-1ecd-a9550bad50cc
strongScalingPlot

# ╔═╡ 7b51af52-1804-11eb-0eb7-37bac5c36cb8
md"""
Determine the maximium total time for each run, because the job is only as fast as the slowest rank.
"""

# ╔═╡ 1aea84c4-17d0-11eb-0b87-8bb59a23e4c1
totalMPITimes = combine(gdf, :totalTime => maximum)

# ╔═╡ 66fc9f8c-17d0-11eb-0276-0d8fcf5b7374
maxMPITimesPlot = @df totalMPITimes scatter(:numNodes, :totalTime_maximum, legend=nothing, xaxis="Number of nodes", yaxis="Maximum total time")

# ╔═╡ 165610cc-1627-11eb-344f-57ac2a655cfc
# Add the cost (nubmer of nodes * hours * 140)  - Here are four different ways to do this

# Remember how this works...
# transform(df, old_columns => function => new_columns)

# Function accepts selected columns as arguments (note broadcasting)
dfa = DataFrames.transform(df, [:numNodes, :totalTime] => ( (n,t) -> (140/60/60)n .* t) => :cost);

# Function accepts elements from selected columns as arguments and implicitly loops over rows (note no broadcasting)
#dfa = DataFrames.transform(df, [:numNodes, :totalTime] => ByRow( (x,y) -> (140/60/60)x * y ) => :cost);

# Function accepts a Named Tuple containing selected columns (note broadcasting)
#dfa = DataFrames.transform(df, AsTable([:numNodes, :totalTime]) => (t -> (140/60/60)t.numNodes .* t.totalTime) => :cost);

# Function accepts a named tuple containing elements from selected columns (note no broadcasting)
#dfa = DataFrames.transform(df, AsTable([:numNodes, :totalTime]) => ByRow(t -> (140/60/60)t.numNodes * t.totalTime) => :cost);

# ╔═╡ 99802f1a-174d-11eb-2f9d-5bac1aead9dd
data_table(select(dfa, [1,12,13]))

# ╔═╡ 9d481f96-1751-11eb-2660-7db6ea172c2f
strongScalingCostPlot = @df dfa boxplot(:numNodes, :cost, legend=nothing, title="Strong Scaling Study (one plot)", 
 						  	             xaxis="Number of nodes", yaxis="Cost (NERSC Units)", size=(800,600))

# ╔═╡ 5f14b570-1811-11eb-2fb0-d722ffdd7829
md"""
Do this for the maximum times
"""

# ╔═╡ 63d95a02-1811-11eb-2a2b-97da3dd5a706
transform!(totalMPITimes, AsTable(:) => (t -> (140.0/60/60)t.numNodes .* t.totalTime_maximum) => :cost)

# ╔═╡ a7d882fa-1811-11eb-3a37-351621c4e545
costMPIPlot = @df totalMPITimes scatter(:numNodes, [:totalTime_maximum :cost], label=["Total time (s)" "Cost (NERSC Units)"], 
	               xaxis="Number of nodes", yaxis="seconds or NERSC units")

# ╔═╡ 4dd16826-1811-11eb-25dc-3d8aecae4419
 costMPIPlot

# ╔═╡ 56c4634e-17b3-11eb-0c6c-4545c1aa5c67
md"""
### Examine accounting information

Examining the raw timing information from within MPI is not the whole story. Let's look at the Cori accounting information. I can do that by running `~/bin/sacct_csv` in my NERSC directory. I've copied the output here.
"""

# ╔═╡ 014d22c8-17bd-11eb-2514-9d765222e7bc
sacct = CSV.File(joinpath(datapath, "sacct.csv")) |> DataFrame
# Note that there are extraneous jobs in this file

# ╔═╡ 6d6b773e-17c7-11eb-31cc-17f23a6f4410
md"""
We can pull the job IDs from the log files...
"""

# ╔═╡ 78026900-17c7-11eb-2cbf-d5d8242de89c
slurmLogFiles = @pipe glob("slurm*.out", datapath) |> basename.(_)

# ╔═╡ a23a3482-17c7-11eb-3bf3-b5fb47d0b4e2
function jobIdFromSlurmLogName(fn)
	m = match(r"slurm-(\d+)[_]", fn)
	m.captures[1]
end

# ╔═╡ cbc4a1b6-17c7-11eb-07f7-c3286d80af40
slurmIds = jobIdFromSlurmLogName.(slurmLogFiles)

# ╔═╡ 33b85bdc-17c8-11eb-091f-b5f1188d2538
# Select out the jobIds that we care about
begin
	sacctM = filter(:JobID => j -> occursin.(slurmIds, j) |> any, sacct)
	
	# And don't care about the batch or extern jobs (not sure what they are)
	filter!(:JobName => jn -> jn != "batch" && jn != "extern", sacctM)
end

# ╔═╡ 10bf9aa8-17ca-11eb-3d2c-519fa0745aa4
data_table(sacctM; items_per_page=40)

# ╔═╡ f759ebb2-17ca-11eb-0672-1d5e4f78d791
# Split this up into Julia info and batch info
begin
	batchInfo = filter(:JobName => jn -> jn != "julia", sacctM)
	juliaInfo = filter(:JobName => jn -> jn == "julia", sacctM)
end

# ╔═╡ ef41bed4-17cd-11eb-2b92-69ec50165d3f
batchInfo

# ╔═╡ b254f75e-17cb-11eb-2ddd-c950293c10a0
# Add CPU time per rank
transform!(juliaInfo, [:CPUTimeRAW, :NCPUS] => ((c,n) -> c ./ n) => :CPUTimePerRank)

# ╔═╡ 555de22e-1805-11eb-08db-8706119416cf
md"""
So the elapsed time is exactly the CPU seconds per task
"""

# ╔═╡ fa2bca96-17cb-11eb-226e-9d5e24ef7e7e
select(juliaInfo, [:ElapsedRaw, :CPUTimePerRank])
# So the elapsed time is the same as the CPU time per rank?

# ╔═╡ 6cdd1280-1805-11eb-3ce4-913b667142a4
md"""
Here's the total elapsed time. This looks goofy.
"""

# ╔═╡ 7060ead2-17cc-11eb-24c6-ada977f5648a
# Let's make some plots
totalBatchTimePlot = @df batchInfo scatter(:NNodes, :ElapsedRaw, legend=nothing, 
											title="Total batch time", xaxis="# of nodes", yaxis="Elaspsed time (s)")

# ╔═╡ 10b466fc-17ce-11eb-24b1-7fc9501056c4
transform!(batchInfo, [:NNodes, :ElapsedRaw] => ( (n, e) -> (140.0/60/60)n .* e) => :cost)

# ╔═╡ 4c11f692-17ce-11eb-293a-9f3237374eb8
batchJobCostPlot = @df batchInfo scatter(:NNodes, :cost, legend=nothing, title="Job cost", xaxis="# of nodes", yaxis="Cost (NERSC units)")

# ╔═╡ 883611d6-1813-11eb-231c-1f0fa6b3dfd4
batchJobCostPlot

# ╔═╡ 8143cf5c-1805-11eb-33cf-873667bb8560
md"""
Look at how long Julia itself took
"""

# ╔═╡ 77516526-17cf-11eb-07b6-31e0e8e01420
# How long did Julia take?
juliaElapsedTimePlot = @df juliaInfo scatter(:NNodes, :ElapsedRaw, legend=nothing, 
	                                         title="Julia Elapsed Time", xaxis="# of nodes", yaxis="Elapsed time (s)")
# Very much follows the batch elapsed time

# ╔═╡ f988f09a-17cf-11eb-29d6-ada88d16c84f
md"""
So, Julia is taking significantly more time than what I recorded in MPI
"""

# ╔═╡ 82b5d572-17d0-11eb-095f-d74db102eab6
begin
	timingComparisonPlot = 
		@df batchInfo scatter(:NNodes, :ElapsedRaw, label="Total Batch Time")
	@df juliaInfo scatter!(:NNodes, :ElapsedRaw, label="Total Julia time")
	@df totalMPITimes scatter!(:numNodes, :totalTime_maximum, label="MPI Julia time",
							   xaxis="# of nodes", yaxis="Elapsed time (s)",legend=:right)
end;
# Something is really goofy here. Is this julia startup and loading libraries?

# ╔═╡ be18ba70-1812-11eb-249c-e7fcd15b6fc8
timingComparisonPlot

# ╔═╡ e2e8a9d2-1806-11eb-2169-251c0cf55778
timingComparisonPlot

# ╔═╡ b81f0930-1805-11eb-2dc9-bd7a3380fdb5
md"""
So there's a lot going on that's not accounted for in my MPI timing.
"""

# ╔═╡ fa4cc80c-17d0-11eb-33f1-530ee3b26e3e
# Let's look at memory and stuff
names(juliaInfo)

# ╔═╡ 3d2cee0a-17d3-11eb-1c81-c17879abd2d1
data_table(juliaInfo, items_per_page=20 )

# ╔═╡ caa4c0c0-1805-11eb-2d01-832d391b03ba
md"""
Here's a function to read in things like "100K", "150.6M", "2.5G" and output a Float in Megabytes.
"""

# ╔═╡ 43869070-17d1-11eb-3744-610c832933d5
# Parse a string with "K", "M", "G" and return megabytes
function parseMemoryToMB(mem)
	m = match(r"(\d+\.?\d*)([KMG])", mem)
	v = @pipe m.captures[1] |> parse(Float64, _)
	s = m.captures[2]
	if s == "K"
		v /= 1024
	elseif s == "G"
		v *= 1024
	end
	v
end

# ╔═╡ e581c5f2-1805-11eb-0e23-65346f049dd1
md"""
Write some tests...
"""

# ╔═╡ 9a13c644-17d4-11eb-33ae-5b330c1f7637
with_terminal() do
	@testset "Test parseMemoryToMB" begin
		@test parseMemoryToMB("100K") == 100/1024
		@test parseMemoryToMB("100.9K") == 100.9/1024
		@test parseMemoryToMB("100.9M") == 100.9
		@test parseMemoryToMB("100.9G") == 100.9*1024
	end
end

# ╔═╡ 52bb085e-17d2-11eb-3e2d-e50b7ee4edfd
maxVmsizePlot = @df juliaInfo scatter(:NNodes, parseMemoryToMB.(:MaxVMSize)./1024, 
	                                legend=nothing, xaxis="# nodes", yaxis="Max VMSize (GB)")

# ╔═╡ 5512aa1e-1814-11eb-259e-c9eb19306f36
maxVmsizePlot

# ╔═╡ 98cac44e-17d2-11eb-08e5-27058446fcb4
maxRSSPlot = @df juliaInfo scatter(:NNodes, parseMemoryToMB.(:MaxRSS), legend=nothing, xaxis="# nodes", yaxis="Max RSS (MB)")

# ╔═╡ 0e9e4d56-1814-11eb-0f89-c74505de2e3e
maxRSSPlot

# ╔═╡ adccf4e4-17d2-11eb-213f-6df6bb96199b
maxDiskReadPlot = @df juliaInfo scatter(:NNodes, parseMemoryToMB.(:MaxDiskRead), legend=nothing, xaxis="# nodes", yaxis="Max MB read off disk")

# ╔═╡ 8f3b9e7a-1814-11eb-0fc5-852ea7737742
maxDiskReadPlot

# ╔═╡ f94cf10a-17d2-11eb-0843-9fc4cb642d8d
maxDiskWrite = @df juliaInfo scatter(:NNodes, parseMemoryToMB.(:MaxDiskWrite).*1024, 
	                                 legend=nothing, xaxis="# nodes", yaxis="Max KB written to disk")

# ╔═╡ 2f409828-1814-11eb-3a65-812103b81ceb
maxDiskWrite

# ╔═╡ Cell order:
# ╟─406a9370-14a0-11eb-069d-113287d17309
# ╠═3d170482-180f-11eb-3cb7-ddf2ff03cbdc
# ╟─5ebefb64-180f-11eb-2f52-b71025782dda
# ╠═28a44380-1810-11eb-3f34-79e96d39fe69
# ╟─6e848914-1810-11eb-1a5b-7998a1bc5ed2
# ╠═b9fc6260-1810-11eb-0d6e-71168149b821
# ╟─e8c4e2dc-1810-11eb-1ac7-d5afc4ba45b4
# ╠═faa926a2-1810-11eb-1ecd-a9550bad50cc
# ╟─3dfc2368-1812-11eb-1398-a39ac22c1df0
# ╠═4dd16826-1811-11eb-25dc-3d8aecae4419
# ╟─7c11899a-1812-11eb-13c7-fb3f79420e0c
# ╠═be18ba70-1812-11eb-249c-e7fcd15b6fc8
# ╟─c33b001c-1812-11eb-3941-43652ad5462b
# ╠═883611d6-1813-11eb-231c-1f0fa6b3dfd4
# ╟─0212a640-1814-11eb-1dc8-710a549d22b9
# ╠═0e9e4d56-1814-11eb-0f89-c74505de2e3e
# ╟─4a6276e6-1814-11eb-3c00-73b032f64d2e
# ╠═5512aa1e-1814-11eb-259e-c9eb19306f36
# ╟─835ce67a-1814-11eb-2625-97b7f548d836
# ╠═8f3b9e7a-1814-11eb-0fc5-852ea7737742
# ╟─95a757fc-1814-11eb-352e-5d219e060c88
# ╠═2f409828-1814-11eb-3a65-812103b81ceb
# ╟─bd2a63c8-1814-11eb-30d3-bd719d9bf8dd
# ╟─aa8b39c0-14a1-11eb-2ef4-5f154b707400
# ╠═c6ca90ea-155f-11eb-3c12-ad3c58e5fb55
# ╠═b36dfae6-14a1-11eb-3dde-57dcaa1b2e1c
# ╠═ef60a404-155f-11eb-346c-79e1bd961a08
# ╠═498d7116-14a5-11eb-0785-ad596c074cba
# ╠═00da17e6-14a6-11eb-1b60-c9f662572085
# ╟─eeb2de64-156e-11eb-1372-1fc46f69a47a
# ╠═470075be-14a6-11eb-378b-23fca6496348
# ╠═4d06e004-1570-11eb-36eb-59a086d35dbf
# ╟─57a514b6-180b-11eb-3886-65a0f60af854
# ╟─171e5f10-156f-11eb-075f-817e25e83c41
# ╠═2aad16f0-156f-11eb-3751-1b3c58fcf061
# ╠═4f745172-156f-11eb-1154-cba14ab2ae06
# ╠═5a1d937e-156f-11eb-3df2-cd55c8b8abd2
# ╠═5d8c73fe-156f-11eb-1d2a-d5c8bee8a9c3
# ╠═fbb294e4-14f4-11eb-0d6a-a5124fadc20f
# ╠═9eac5e44-1803-11eb-05d7-b38082b77dfa
# ╠═81994d80-156f-11eb-1568-dd9adf3e573e
# ╠═d95cd744-156f-11eb-084c-bb729b7267ed
# ╠═19e3621a-1570-11eb-37ba-6f027bbeee93
# ╠═3570cc5c-1570-11eb-17dd-1dee70995a4f
# ╠═b5d0b0c4-1570-11eb-3b8b-e502b346560a
# ╠═a0880064-1575-11eb-0042-e37e09af1a72
# ╠═57e58d18-1570-11eb-255e-1dfefb42204f
# ╠═1fca08ae-1571-11eb-3c34-db5bff78225b
# ╠═a594641e-1571-11eb-2d95-17597bafd987
# ╟─fb9964f6-1571-11eb-38ee-ff0a37fd1b4a
# ╠═7e41321e-14f1-11eb-39a0-d1b216e33462
# ╠═856ccf30-14f3-11eb-293d-8172519d1965
# ╠═ad69e592-14f3-11eb-11bc-1d25cc268342
# ╠═d12d4280-14f6-11eb-0f2f-89a9acb621d2
# ╠═fc0c5188-14f8-11eb-36e0-e584c02cbc0f
# ╠═2465ca36-1573-11eb-1260-7b9f805e91a3
# ╠═37924274-1573-11eb-31e3-09d6d740f6a1
# ╠═431a6bca-1577-11eb-0b37-5dcb9872f1c0
# ╠═a7240894-1577-11eb-2286-21c6187bfb91
# ╟─03039904-1578-11eb-210d-fddde77525a6
# ╠═be0314cc-1579-11eb-25e1-4704668da772
# ╠═c2bcea2e-1579-11eb-1502-359c5e639136
# ╠═14fead68-157a-11eb-2778-f3d18f6a0063
# ╠═701a2bf8-157a-11eb-266b-e78aabb27330
# ╠═91eb525e-157a-11eb-1a79-818c3ae8b42a
# ╟─4b335b72-1804-11eb-27a6-4f845d7a819b
# ╠═b0b3f712-15b2-11eb-2238-612d3b209598
# ╠═c2ae74d2-15b3-11eb-35e2-815ef0cd2565
# ╠═f35f498a-15b3-11eb-26db-49d25348dc52
# ╟─52488e6e-1804-11eb-3a1c-993e25d773fd
# ╠═038ab1a6-15b5-11eb-1adb-093514d8c3ce
# ╠═31146e34-15b6-11eb-21e6-49af27395193
# ╠═65f67318-15b6-11eb-3357-8d2254e326e3
# ╠═9ff58936-15b7-11eb-3954-b58825211888
# ╠═d53afd5c-15b6-11eb-2543-6794ac45e366
# ╟─7a4a61a6-1626-11eb-3420-33505a62562b
# ╟─df9f71d0-180e-11eb-1028-bda3a80294a6
# ╠═1a606e0e-15bb-11eb-2bc3-d15ce693a99d
# ╟─315cadc8-15bb-11eb-270e-954f77341c83
# ╠═d5984e66-15b7-11eb-0110-45315ebd865d
# ╟─710f60a0-1804-11eb-3bbb-d1c3f0bc231b
# ╠═29006b92-15bd-11eb-094f-b5fc7c703025
# ╟─7b51af52-1804-11eb-0eb7-37bac5c36cb8
# ╠═1aea84c4-17d0-11eb-0b87-8bb59a23e4c1
# ╠═66fc9f8c-17d0-11eb-0276-0d8fcf5b7374
# ╠═165610cc-1627-11eb-344f-57ac2a655cfc
# ╠═99802f1a-174d-11eb-2f9d-5bac1aead9dd
# ╠═9d481f96-1751-11eb-2660-7db6ea172c2f
# ╟─5f14b570-1811-11eb-2fb0-d722ffdd7829
# ╠═63d95a02-1811-11eb-2a2b-97da3dd5a706
# ╠═a7d882fa-1811-11eb-3a37-351621c4e545
# ╟─56c4634e-17b3-11eb-0c6c-4545c1aa5c67
# ╠═ee61bde0-17bc-11eb-2f8e-33a062b5dfd4
# ╠═014d22c8-17bd-11eb-2514-9d765222e7bc
# ╟─6d6b773e-17c7-11eb-31cc-17f23a6f4410
# ╠═78026900-17c7-11eb-2cbf-d5d8242de89c
# ╠═a23a3482-17c7-11eb-3bf3-b5fb47d0b4e2
# ╠═cbc4a1b6-17c7-11eb-07f7-c3286d80af40
# ╠═33b85bdc-17c8-11eb-091f-b5f1188d2538
# ╠═10bf9aa8-17ca-11eb-3d2c-519fa0745aa4
# ╠═f759ebb2-17ca-11eb-0672-1d5e4f78d791
# ╠═ef41bed4-17cd-11eb-2b92-69ec50165d3f
# ╠═b254f75e-17cb-11eb-2ddd-c950293c10a0
# ╟─555de22e-1805-11eb-08db-8706119416cf
# ╠═fa2bca96-17cb-11eb-226e-9d5e24ef7e7e
# ╟─6cdd1280-1805-11eb-3ce4-913b667142a4
# ╠═7060ead2-17cc-11eb-24c6-ada977f5648a
# ╠═10b466fc-17ce-11eb-24b1-7fc9501056c4
# ╠═4c11f692-17ce-11eb-293a-9f3237374eb8
# ╟─8143cf5c-1805-11eb-33cf-873667bb8560
# ╠═77516526-17cf-11eb-07b6-31e0e8e01420
# ╟─f988f09a-17cf-11eb-29d6-ada88d16c84f
# ╠═82b5d572-17d0-11eb-095f-d74db102eab6
# ╠═e2e8a9d2-1806-11eb-2169-251c0cf55778
# ╟─b81f0930-1805-11eb-2dc9-bd7a3380fdb5
# ╠═fa4cc80c-17d0-11eb-33f1-530ee3b26e3e
# ╠═3d2cee0a-17d3-11eb-1c81-c17879abd2d1
# ╟─caa4c0c0-1805-11eb-2d01-832d391b03ba
# ╠═43869070-17d1-11eb-3744-610c832933d5
# ╟─e581c5f2-1805-11eb-0e23-65346f049dd1
# ╠═9a13c644-17d4-11eb-33ae-5b330c1f7637
# ╠═52bb085e-17d2-11eb-3e2d-e50b7ee4edfd
# ╠═98cac44e-17d2-11eb-08e5-27058446fcb4
# ╠═adccf4e4-17d2-11eb-213f-6df6bb96199b
# ╠═f94cf10a-17d2-11eb-0843-9fc4cb642d8d
