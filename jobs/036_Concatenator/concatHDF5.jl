# Concatenate HDF5 files
#
using MPI 
MPI.Init()

using IRMA
const sw = Stopwatch()

using HDF5
using Distributed: splitrange
using JLD2
using ArgParse

const rankLog = Dict()  # Stuff we want to log
const bytesInGB = 1024^3

const chunkSize = Int(1024 * 1024 / sizeof(Int32))

# Structure for tracking datasets
mutable struct DataSetEntry
    name::String
    type::Type
    size::Int64
    filePlaces::Dict
    DataSetEntry(anObject) = new(HDF5.name(anObject), eltype(anObject), 0, Dict())
end

function addSizeToDataSetEntry(e::DataSetEntry, fileName::String, size)
    startAt = e.size + 1
    endAt   = startAt + size - 1
    e.filePlaces[fileName] = (startAt, endAt)
    e.size += size
end

struct MemoryLayout
    dataSetName::String
    startAt::Int64
    endAt::Int64
end

"""visitH5Contents(inH5, isMine, visitor)

    Walk the contents of an H5 file, visiting each group and
    dataset in the hierarchy.

    inH5 is the opened HDF5 file object or group object to walk

    This functions will walk within HDF5 file and group objects and will
    recursively dive into a hierarchy of groups. The visted object is passed
    to the visitor function (it must handle whatever object is passed in)
"""
function visitH5Contents(fileName::String, inH5::Union{HDF5.File, HDF5.Group}, visitor)
    for anObject in inH5
        visitor(anObject, fileName)           # Process this object
        if typeof(anObject) == HDF5.Group   # If this object is a group then walk inside
            visitH5Contents(fileName, anObject, visitor)
        end
    end
end

"""makeGetStructureVisitor(groups, datasets)
    Populate groups and datasets structures with this object

    If this object is a group, add the name to the groups list if it is not there
    If this object is a dataset, and if it is the first time we've seen it, then add this dataset to the DataSetEntry structure.
     then, everytime we see this dataset, we'll add the size to the structure and a mapping to the input file
"""
function makeGetStructureVisitor(groups, datasets)
    function theVisitor(anObject, fileName)
        objectName = HDF5.name(anObject)
        if typeof(anObject) == HDF5.Group  # If group, keep track
            if ! (objectName in groups)
               push!(groups, objectName)
            end
        elseif typeof(anObject) == HDF5.Dataset  # If dataset, add up length
            if ! (haskey(datasets, objectName))
                datasets[objectName] = DataSetEntry(anObject)
            end
            addSizeToDataSetEntry(datasets[objectName], fileName, length(anObject))
        else
            @error "Unknown HDF5 type of $(typeof(anObject))"
        end
    end
end

"""analyzeInputFiles(groups, inDataSets, inFiles)
    Update groups and inDataSets by analyzing input files.
    groups an inDataSets are left updated.
"""
function analyzeInputFiles(groups, inDataSets, inFiles, pv)
    structureVisitor = makeGetStructureVisitor(groups, inDataSets)
    for fileName in inFiles
        h5open(fileName, "r"; pv...) do inH5
            visitH5Contents(fileName, inH5, structureVisitor)
        end
    end
end

"""displayStructure(inDataSets)
"""
function displayStructure(inDataSets)
    allBytes = 0
    for (k,v) in inDataSets
        totalBytes = sizeof(v.type) * v.size
        allBytes += totalBytes
        println("Dataset $k has $(v.size) rows and needs $(Base.format_bytes(totalBytes)) total")
    end
    println("A total of $(Base.format_bytes(allBytes)) will be required")
end

"""layoutMemory(inDataSets, rc)
    Determine the layout of memory an datasets

    Here is the algorithm...
    Only RootOnNode ranks participate in this exercise

    * Determine the free memory (times the memory usage factor) on each machine and spread that around
    * Loop over datasets
        - Determine the total size for the dataset
        - Loop over the nodes
            o How many rows will fit on this node (out of what's left to fit)
            o If there are rows that will fit, then claim that memory and record the dataset, range of rows, and node # in the layout structure
            o If there are rows that will not fit, advance to the next node and set current memory used to zero - go back through the Loop. If there's no
               next node, then error outFile

    Implications:
        Each node may need multiple shared arrays if more than one dataset can fit on the node
"""
function layoutMemory(inDataSets, rc, commAmongNodeRoots, memUsage, nodeMemoryLayout)

    # Only the node roots participate in this
    if rc.isRootOnNode

        # We need to know the memory that this node has and share that with the other ranks
        # participating
        nodeMemory = MPI.Allgather(Sys.free_memory()*memUsage, commAmongNodeRoots)
        rc.myRankAmongNodeRoots == 0 && @debug "nodeMemory" nodeMemory

        # Now we can layout the memory
        currentNode = 1
        memoryLeft = nodeMemory[currentNode]

        for (k,v) in inDataSets
            rowsLeftToFit = v.size
            sizeOfRow = sizeof(v.type)
            startingRow = 1

            while rowsLeftToFit > 0
                # How many rows will fit on this node?
                nRowsThatFit  = min(rowsLeftToFit, memoryLeft ÷ sizeOfRow)
                rowsLeftToFit -= nRowsThatFit

                # Will rows fit on this node?
                if nRowsThatFit > 0
                    memoryLeft -= nRowsThatFit * sizeOfRow

                    if length(nodeMemoryLayout) < currentNode
                        push!(nodeMemoryLayout, [])
                    end

                    endingRow = startingRow + nRowsThatFit - 1

                    push!(nodeMemoryLayout[currentNode], MemoryLayout(k, startingRow, endingRow))

                    startingRow += nRowsThatFit
                end

                # Are there still rows from this dataset that we need to fit?
                if rowsLeftToFit > 0
                    # We've exhausted this node - advance to the next one
                    currentNode += 1
                    @assert currentNode <= rc.nNodes "Not enough nodes!"
                    memoryLeft = nodeMemory[currentNode]
                end
            end  # While rowsLeftToFit > 0

            # We now advance to the next dataset

        end # For over datasets

        # Display what we got
        if rc.myRankAmongNodeRoots == 0
            @debug "NodeMemoryLayout" nodeMemoryLayout
            @debug "$(length(nodeMemoryLayout)) nodes are needed"
        end

    end # If RootOnNode

end

# Setup global rank in MPI    # Get MPI Info
info = MPI.Info()
comm = MPI.COMM_WORLD

gbFree() = Sys.free_memory() / bytesInGB

function parse_commandLine()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--analyzeOnly", "-a"
            help = "Only analyze input files; do not write"
            action = :store_true
        "--layoutOnly", "-l"
            help = "Only analyze input files and layout memory; do not write"
            action = :store_true
        "--collectiveRead", "-c"
            help = "Do reads collectively"
            action = :store_true
        "--memUsage", "-m"
            help = "Memory usage factor (what fraction of node free memory to use); default=0.8"
            arg_type = Float64
            default = 0.8
        "--nReaders", "-r"
            help = "Number of ranks on each node for reading the inputs"
            arg_type = Int
            default = 6
        "--nWriters", "-w"
            help = "Number of ranks on each node for writing the output"
            arg_type = Int
            default = 6
        "--nFiles", "-n"
            help = "Number of input files to process (0=all)"
            arg_type = Int
            default = 0
        "tomlFile"
            help = "TOML with info on how to write datasets"
            required = true
        "outFile"
            help = "Output HDF5 file"
            required = true
        "inFiles"
            nargs = '*'
            help = "List of files to concatenate"
            required = true
    end

    return parse_args(s)
end

function main()
    stamp(sw, "InMain")
    rankLog[:memStart] = gbFree()

    # Get MPI Info for ranks on node
    rc, commOnNode, commAmongNodeRoots = IRMA.rankConfig(comm)

    # Save this info away
    merge!(rankLog, pairs(rc))  # pairs turns a named tuple into a dictionary

    # Parse the command line
    pa = parse_commandLine()

    # Determine the files to read
    inFiles = pa["inFiles"]
    nFiles  = pa["nFiles"] == 0 ? length(inFiles) : min(pa["nFiles"], length(inFiles))
    if nFiles < length(inFiles)  # Truncate the input file list if necessary
        inFiles = inFiles[1:nFiles]
    end

    if rc.isRoot
        @debug("Reading $(length(inFiles)) files")
    end

    # Setup MPIO if necessary
    let fileprop = create_property(HDF5.H5P_FILE_ACCESS)
        HDF5.h5p_set_fapl_mpio(fileprop, comm, info)   # fapl is the file access property list
        h5comm, h5info = HDF5.h5p_get_fapl_mpio(fileprop)
        @assert MPI.Comm_compare(comm, h5comm) == MPI.CONGRUENT
    end

    # Set read MPI details
    if pa["collectiveRead"]
        pv = (; fapl_mpio=(comm, info), dxpl_mpio=HDF5.H5FD_MPIO_COLLECTIVE)
    else
        pv = (; fapl_mpio=(comm, info), dxpl_mpio=HDF5.H5FD_MPIO_INDEPENDENT)
    end

    # -- We follow three steps...
    # 1. Analyze in the input files and determine groups, datasets and sizes
    # 2. Load up memory with the data
    # 3. Create the output structure
    # 4. Write it!

    groups = Vector{String}()  # Keep track of HDF5 groups
    inDataSets = Dict()        # Keep track of HDF5 datasets

    # Step 1 - analyze input file structure
    analyzeInputFiles(groups, inDataSets, inFiles, pv)

    # Display the output
    rc.isRoot && displayStructure(inDataSets)
    rc.isRoot && @debug "inDataSets" inDataSets

    # If we just want to analyze, we stop here
    if pa["analyzeOnly"] return end

    # Layout the node memory
    nodeMemoryLayout = []  # This will be filled by layoutMemory
    layoutMemory(inDataSets, rc, commAmongNodeRoots, pa["memUsage"], nodeMemoryLayout)

    # If we just want to layout the memory, we stop here
    if pa["layoutOnly"] return end

    # Step 2 -- Load up the memory with data


end

main()
MPI.Finalize()