using Neo4j
using Mongo

#Types
export CloudGraphConfiguration, CloudGraph, CloudVertex, CloudEdge
export BigData, BigDataElement
export BigDataRawType

_mongoDefaultDb = "CloudGraphs"
_mongoDefaultCollection = "bindata"

# Type aliases
BigDataRawType = Union{Vector{UInt8}, Dict{String, Any}, String}

mutable struct BigDataElement
    sourceName::String
    sourceId::String
    sourceParams::Dict{String, Any}
    id::String
    description::String
    data::BigDataRawType
    mimeType::String
    neoNodeId::Int
    lastSavedTimestamp::String #UTC DateTime.
    BigDataElement(id::String, desc::String, data::BigDataRawType, neoNodeId::Int; sourceName::String="Mongo", sourceId::String=string(Base.Random.uuid4()), sourceParams::Dict{String, Any}=Dict{String, Any}(), mimeType::String="application/octet-stream", lastSavedTimestamp::String=string(now(Dates.UTC))) = begin
        return new(sourceName, sourceId, sourceParams, id, desc, data, mimeType, neoNodeId, lastSavedTimestamp)
    end
    BigDataElement{T <: String}(dd::Dict{T,Any}, version::String) = begin
        if(version == "1")
            return new("Mongo", dd["mongoKey"], Dict{String, Any}(), dd["mongoKey"], dd["description"], dd["data"], "application/octet-stream", dd["neoNodeId"], dd["lastSavedTimestamp"])
        elseif(version == "2")
            return new(dd["sourceName"], dd["sourceId"], dd["sourceParams"], dd["id"], dd["description"], dd["data"], dd["mimeType"], dd["neoNodeId"], dd["lastSavedTimestamp"])
        else
            error("BigDataElement version '$version' is not supported.")
        end
    end
end

mutable struct BigData
  isRetrieved::Bool
  isAvailable::Bool
  isExistingOnServer::Bool
  lastSavedTimestamp::String #UTC DateTime.
  version::String
  dataElements::Vector{BigDataElement}
  # This is just for local use, and is not saved directly into the graph.
  BigData() = new(false, false, false, "[N/A]", "2", Vector{BigDataElement}())
  BigData(isRetrieved::Bool, isAvailable::Bool, isExistingOnServer::Bool, lastSavedTimestamp::String, version::String, data::Vector{BigDataElement}) = new(isRetrieved, isAvailable, isExistingOnServer, lastSavedTimestamp, version, data)
  BigData(jsonStr::String) = begin
      dd = JSON.parse(jsonStr)
      bDE = BigDataElement[]
      for (k,v) in dd["dataElements"]
         push!(bDE, BigDataElement(v[1],Vector{UInt8}(),v[2]) )
      end
      version = haskey(dd, "version") ? dd["version"] : "1"
      new(dd["isRetrieved"],dd["isAvailable"],dd["isExistingOnServer"],dd["lastSavedTimestamp"], version, bDE)
    end
end

mutable struct CloudVertex
  packed::Any
  properties::Dict{AbstractString, Any} # UTF8String
  bigData::BigData
  neo4jNodeId::Int
  neo4jNode::Union{Void,Neo4j.Node}
  labels::Vector{AbstractString}
  isValidNeoNodeId::Bool
  exVertexId::Int
  isValidExVertex::Bool
  CloudVertex() = new(Union, Dict{AbstractString, Any}(), BigData(), -1, nothing, Vector{AbstractString}(), false, -1, false)
  CloudVertex{T <: AbstractString}(packed, properties, bigData::BigData, neo4jNodeId, neo4jNode, isValidNeoNodeId, exVertexId, isValidExVertex; labels::Vector{T}=Vector{String}()) = new(packed, properties, bigData, neo4jNodeId, neo4jNode, labels, isValidNeoNodeId, exVertexId, isValidExVertex)
  CloudVertex{T <: AbstractString}(packed, properties, bigData::T, neo4jNodeId, neo4jNode, isValidNeoNodeId, exVertexId, isValidExVertex; labels::Vector{T}=Vector{String}()) = new(packed, properties, BigData(bigData), neo4jNodeId, neo4jNode, labels, isValidNeoNodeId, exVertexId, isValidExVertex)
end

# A single configuration type for a CloudGraph instance.
struct CloudGraphConfiguration
  neo4jHost::AbstractString # UTF8String
  neo4jPort::Int
  neo4jUsername::AbstractString # UTF8String
  neo4jPassword::AbstractString # UTF8String
  mongoHost::AbstractString # UTF8String
  mongoPort::Int
  mongoIsUsingCredentials::Bool
  mongoUsername::AbstractString # UTF8String
  mongoPassword::AbstractString # UTF8String
end

mutable struct Neo4jInstance
  connection::Neo4j.Connection
  graph::Neo4j.Graph
end

mutable struct MongoDbInstance
  client::Mongo.MongoClient
  cgBindataCollection::MongoCollection
end

mutable struct PackedType
  originalType::Type
  packingType::Type
  encodingFunction::Union{Function, Void}
  decodingFunction::Union{Function, Void}
end

# A CloudGraph instance
mutable struct CloudGraph
  configuration::CloudGraphConfiguration
  neo4j::Neo4jInstance
  mongo::MongoDbInstance
  packedPackedDataTypes::Dict{AbstractString, PackedType}
  packedOriginalDataTypes::Dict{AbstractString, PackedType}
  CloudGraph(configuration, neo4j, mongo) = new(configuration, neo4j, mongo, Dict{AbstractString, PackedType}(), Dict{AbstractString, PackedType}())
  CloudGraph(configuration, neo4j, mongo, packedDataTypes, originalDataTypes) = new(configuration, neo4j, mongo, packedDataTypes, originalDataTypes)
end

mutable struct CloudEdge
  neo4jEdgeId::Int
  neo4jEdge::Union{Void,Neo4j.Relationship}
  edgeType::AbstractString #UTF8String
  neo4jSourceVertexId::Int
  SourceVertex::Union{Void,CloudGraphs.CloudVertex}  #neo4jSourceVertex::Union{Void,Neo4j.Node}
  neo4jDestVertexId::Int
  DestVertex::Union{Void,CloudGraphs.CloudVertex}  #neo4jDestVertex::Union{Void,Neo4j.Node}
  properties::Dict{AbstractString, Any} # UTF8String
  CloudEdge() = new(-1, nothing, "", -1, nothing, -1, nothing, Dict{AbstractString, Any}())
  # UTF8String
  CloudEdge{T <: AbstractString}(vertexSrc::CloudVertex, vertexDest::CloudVertex, edgeType::T; props::Dict{T, Any}=Dict{T, Any}()) = new(
    -1, nothing, string(edgeType), # utf8(edgeType)
    vertexSrc.neo4jNodeId,
    vertexSrc, #.neo4jNode,
    vertexDest.neo4jNodeId,
    vertexDest, #.neo4jNode,
    props)
end
