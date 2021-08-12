# hdf5tools - helper functions for dealing with HDF5 files

"""
    DataSetEntry is an object that represents an HDF5 dataset that can be in many files
"""
mutable struct DataSetEntry # Records information about HDF5 datasets in files
    name::String    # Name of dataset
    type::Type      # Element type
    elBytes::Int    # Size of that type in bytes
    files::Vector{String} # Files contributing to this dataset
    nRows::Vector{Int}    # Rows from the fileNameS
    nBytes::Vector{Int}   # Number of bytes from the file

    DataSetEntry(x) = new(HDF5.name(x), eltype(x), sizeof(eltype(x)), String[], Int[], Int[])
end

# Add pretty printing
function Base.show(io::IO, dse::DataSetEntry)
    print(io,
         "DataSetEntry: $(dse.name){$(dse.type)} has $(format(sum(dse.nRows), commas=true)) rows from $(length(dse.files)) files and needs $(Base.format_bytes(sum(dse.nBytes))) of memory")
end

"""
    Add a file to the DataSetEntry - This will also record what row numbers should come from this file
"""
function addFileToDataSetEntry(e::DataSetEntry, fileName::String, nRows::Int)
    push!(e.files, fileName)
    push!(e.nRows, nRows)
    push!(e.nBytes, e.elBytes*nRows)
end

# Make a "typedef" for a dictionary of these
DataSetEntryDict = Dict{String, DataSetEntry}

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
            addFileToDataSetEntry(datasets[objectName], fileName, length(anObject))
        else
            @error "Unknown HDF5 type of $(typeof(anObject))"
        end
    end
end


"""
    displayDataSetEntries(inDataSets::Dict)
    Print info about DataSetEntry objects in dictionary.
"""
function displayDataSetEntries(inDataSets::Dict)
    allBytes = 0
    for (k,v) in inDataSets
        allBytes += sum(v.nBytes)
        println(v)
    end
    println("A total of $(Base.format_bytes(allBytes)) will be required")
end

"""
    analyzeInputFiles(inFiles::Vector{String}, groups, inDataSets)

    Fill groups and inFiles from a vector of file names to be read and analyzed.

    A good way to get a list of file names is to use Glob.glob(path).
"""
function analyzeInputFiles(inFiles::Vector{String}, groups::Vector{String}, inDataSets::DataSetEntryDict)
    structureVisitor = makeGetStructureVisitor(groups, inDataSets)
    ProgressLogging.@progress name="Analyzing files" for fileName in inFiles
        h5open(fileName, "r") do inH5
            visitH5Contents(fileName, inH5, structureVisitor)
        end
    end
end

"""
    analyzeInputFiles(path, groups, inDataSets)

    Fill groups and inFiles from a vector of file names to be read and analyzed.
"""
analyzeInputFiles(path::String, groups::Vector{String}, inDataSets::DataSetEntryDict) =
                               analyzeInputFiles(Glob.glob("*.h5", path), groups, inDataSets)

"""
    analyzeInputFiles(path, outFileName="out.jld2")

    Analyze input files and write dataset data to a jld2 file.
    Use this one for a "CLI like" experience. For example

    analyzeInputFiles( joinpath(ENV["CSCRATCH"], "irmaData2", "2C"), "2C_analyze.jld2")
"""
function analyzeInputFiles(path::String, outFileName="out.jld2")
    groups = Vector{String}()
    dataSets = DataSetEntryDict()
    analyzeInputFiles(path, groups, dataSets)
    @save outFileName groups dataSets
end

"""
    chooseDataSets(inDataSets, selectThese=[], group="")

    Choose the datasets to use from the file. You need the DataSetEntry dictionary (`inDataSets`), a
    string vector (`selectThese`) of the dataset names you want. If many come from the same group, you can
    set `group` to that group name and relative names in `selectThese` (if there is an absolute path in `selectThese`,
    then the group name won't be applied).

    A vector of the matching DataSetEntry elements will be returned. 
"""
function chooseDataSets(inDataSets::DataSetEntryDict,
                            selectThese::Vector{String}=Vector{String}(), group::String="")
    # Figure out what datasets to get and validate them
    if length(selectThese) > 0

        if group != ""
            # Must be absolute
            group[1] != '/' && error("group must start with '/'")

            # Must not end in "/"
            group[end] == '/' && error("group must not end in '/'")

            # Add the group to non-absolute dataset names
            selectThese = map(x -> x[1] != '/' ? group * "/" * x : x, selectThese)
        end

        # Validate the dataset names
        goodDS = selectThese .∈ (keys(inDataSets),)   # See help for `in` for this trick

        # Are they all good?
        if ! all(goodDS)
            # We have a failure
            error("Could not find $(selectThese[ .! goodDS ]) in DataSet names")
        end

    else
        # If we didnt' select any datasets, do them all
        selectThese = collect(keys(inDataSets))
    end

    # Filter out the datasets we want
    dsDict = filter(x -> x.first ∈ selectThese, inDataSets)
    collect(values(dsDict))
end

struct NodeMemoryLayoutByFile
    fileNames::Vector{String}
    bytesUsed::Int
end

# Add pretty printing
Base.show(io::IO, l::NodeMemoryLayoutByFile) =
    print(io, "NodeMemoryLayoutByFile: $(length(l.fileNames)) files using $(Base.format_bytes(l.bytesUsed))")

function layoutMemoryWholeFiles(ds::Vector{DataSetEntry}, gbPerNode::Int=100)
    bytesPerNode = gbPerNode*1024^3

    # Fit the files to the node
    nodeLayout = Vector{NodeMemoryLayoutByFile}()
    currentFile = 1
    bytesUsed = 0
    filesForNode = String[]

    # Guess how many files we'll needs
    nFiles = length(ds[1].files)

    ProgressLogging.@withprogress name="Determine memory layout" begin

        while true
            ProgressLogging.@logprogress currentFile/nFiles

            theFile = ds[1].files[currentFile]

            # Are all of the files the same?
            allFiles = [ aDS.files[currentFile] for aDS ∈ ds ]
            ! all(theFile .== allFiles) && error("File structure mismatch")

            # How much memory?
            bytesForThisFile = sum( [ aDS.nBytes[currentFile] for aDS ∈ ds] )

            # Will it fit?
            if bytesUsed + bytesForThisFile <= bytesPerNode

                # Yep - record and try the next file
                bytesUsed += bytesForThisFile
                push!(filesForNode, theFile)
                currentFile += 1
                if currentFile > nFiles
                    # We've run out of files - push what we have and break out
                    push!(nodeLayout, NodeMemoryLayoutByFile(filesForNode, bytesUsed))
                    break
                end

            else
                # This file won't fit!
                # Close out the previous node
                length(filesForNode) == 0 && error("$(theFile) is too big for one node")
                push!(nodeLayout, NodeMemoryLayoutByFile(filesForNode, bytesUsed))

                # Reset for the next node
                filesForNode = String[]
                bytesUsed = 0

                # Try this file again on the new node
            end #if
        end #while
    end # @withprogress

    nodeLayout
end