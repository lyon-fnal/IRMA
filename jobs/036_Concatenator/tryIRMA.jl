using Revise
using IRMA
using HDF5
using ProgressLogging

fileName = joinpath(ENV["CSCRATCH"], "irmaData2", "2C", "irmaData_14019265_0_2C.h5")

f = h5open(fileName, "r")

energyDS = f["ReconEastClusters/energy"]

dse = IRMA.DataSetEntry(energyDS)
IRMA.addFileToDataSetEntry(dse, fileName, length(energyDS))

d = Dict()
d[dse.name] = dse

# Try another file
fileName2 = joinpath(ENV["CSCRATCH"], "irmaData2", "2C", "irmaData_14019217_0_2C.h5")

f2 = h5open(fileName2, "r")
energyDS2 = f["/ReconEastClusters/energy"]

IRMA.addFileToDataSetEntry(dse, fileName2, length(energyDS2))

dse

displayDataSetEntries(d)

# Let's try a whole lot


using JLD2

# Let's try a whole lot
using Glob
fileNames = glob("*.h5", joinpath(ENV["CSCRATCH"], "irmaData2", "2C"))

function analyzeInputFiles(groups, inDataSets, inFiles)
    structureVisitor = makeGetStructureVisitor(groups, inDataSets)
    @progress for fileName in inFiles
        h5open(fileName, "r") do inH5
            visitH5Contents(fileName, inH5, structureVisitor)
        end
    end
end

groups = Vector{String}()
inDataSets = Dict()

analyzeInputFiles(groups, inDataSets, fileNames)
inDataSets
displayDataSetEntries(inDataSets)