# energyCalOne.jl

using HDF5
using JLD2
using OnlineStats
using DataFrames
using IRMA

# Do the energy calibration
# TODO Put the energy calibration into IRMA
const EnergyCal_run1 = Float32[
    1628.9, 1505.9, 1559.4, 1564.9, 1368.8, 1516.9, 1543.8, 1533.0,
    1518.1, 1551.7, 1582.6, 1610.8, 1604.2, 1566.5, 1528.0, 1487.0,
    1520.0, 1588.2, 1554.9, 1525.5, 1455.7, 1474.9, 1522.5, 1548.1]
const EnergyCal_run2 = Float32[
    1845.34, 1956.21, 1852.62, 1882.91, 2075.44, 1919.23, 1885.50, 1900.13,
    1893.89, 1889.55, 1880.18, 1906.99, 1920.32, 1910.87, 1913.59, 1963.29,
    1973.80, 1931.09, 1932.92, 1943.34, 1976.45, 1964.30, 1928.10, 1933.15]

# Calculate the full energy correction factor for each calorimeter
const eCal =  @. Float32(1700.0^2) / EnergyCal_run1  / EnergyCal_run2

# Choose the input file...
#   Logic here is so that I don't have to remember to change this if I'm on my Mac.
#   Strangely, there is no Mac environment variable that says "Darwin" (the shell
#   seems to fill in $OSTYPE on the Mac, but it's not a real environment variable).
#   So we'll just make this decision based on my Home area. Kinda stupid.
const fileName = if ENV["HOME"] == "/Users/lyon"  # Am I on my Mac
                    joinpath("/Users/lyon/Development/gm2/data", "irmaData_36488193_0.h5")  # My mac
                else
                    joinpath(ENV["CSCRATCH"], "irmaData", "irma_2D.h5")   # Cori CSCRATDH
                    #joinpath(ENV["DW_PERSISTENT_STRIPED_irma"], "irma_2D.h5")  # Cori burst buffer
                end

# Constants
const nCalos = 24

# Open the file
f = h5open(fileName, "r")

# open the datasets
energyDS = f["/ReconEastClusters/energy"]
timeDS   = f["/ReconEastClusters/time"]
caloDS   = f["/ReconEastClusters/caloIndex"]

# How many rows to process? We can override with the NALLROWS environment variable
nAllRows = haskey(ENV, "NALLROWS") ? parse(Int64, ENV["NALLROWS"]) : length(energyDS)

# Partition the file
ranges = partitionDS(nAllRows, 1)
myRange = ranges[1]   # myrank starts at 0

# Read the data
energyData = energyDS[1, myRange]
timeData   = timeDS[1, myRange]
caloData   = caloDS[1, myRange]

# Do the time calibration (1 timeData = 1.25ns; And convert to microseconds
# TODO Put the time calibration into IRMA
analysisTime = @. timeData * 1.25 / 1000.0

# Apply the energy correction based on calorimeter ID #
analysisEnergy = energyData .* eCal[ caloData ]

# Make histograms of energy for each calorimeter # with cuts
bins = range( Float32(0), stop=Float32(10_000), length=500)
hists =  [fit!(Hist(bins), @. analysisEnergy[ (caloData == aCalo) & (analysisTime >= 22.0) ]) for aCalo in 1:nCalos ]
shists = SHist.(hists)