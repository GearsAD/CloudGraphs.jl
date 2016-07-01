module CloudGraphs

using Graphs;
using Neo4j;
# using Mongo;
using ProtoBuf;
using JSON;

#Types
export CloudGraphConfiguration, CloudGraph, CloudVertex, BigData
#Functions
export connect, disconnect, add_vertex!, get_vertex, update_vertex!, delete_vertex!
export add_edge!, update_edge!, delete_edge!
export cloudVertex2ExVertex, exVertex2CloudVertex
export registerPackedType!

type BigData
  isRetrieved::Bool
  isAvailable::Bool
  isExistingOnServer::Bool
  mongoKey::AbstractString
  data::Any
  BigData() = new(false, false, false, Void)
  BigData(isRetrieved::Bool, isAvailable::Bool, isExistingOnServer::Bool, data) = new(isRetrieved, isAvailable, isExistingOnServer, string(Base.Random.uuid4()), data)
  BigData(isRetrieved::Bool, isAvailable::Bool, isExistingOnServer::Bool, mongoKey::AbstractString, data) = new(isRetrieved, isAvailable, isExistingOnServer, mongoKey, data)
end

type CloudVertex
  packed::Any
  properties::Dict{UTF8String, Any} #AbstractString
  bigData::BigData
  neo4jNodeId::Int
  neo4jNode::Union{Void,Neo4j.Node}
  isValidNeoNodeId::Bool
  exVertexId::Int
  isValidExVertex::Bool
  CloudVertex() = new(Union, Dict{UTF8String, Any}(), BigData(), -1, nothing, false, -1, false)
  CloudVertex(packed, properties, bigData, neo4jNodeId, neo4jNode, isValidNeoNodeId, exVertexId, isValidExVertex) = new(packed, properties, bigData, neo4jNodeId, neo4jNode, isValidNeoNodeId, exVertexId, isValidExVertex)
end

# A single configuration type for a CloudGraph instance.
type CloudGraphConfiguration
  neo4jHost::UTF8String
  neo4jPort::Int
  neo4jIsUsingCredentials::Bool
  neo4jUsername::UTF8String
  neo4jPassword::UTF8String
  mongoHost::UTF8String
  mongoPort::Int
  mongoIsUsingCredentials::Bool
  mongoUsername::UTF8String
  mongoPassword::UTF8String
end

type Neo4jInstance
  connection::Neo4j.Connection
  graph::Neo4j.Graph
end

# type MongoDbInstance
#   connection::Mongo.MongoClient
# end

type PackedType
  originalType::Type
  packingType::Type
  encodingFunction::Union{Function, Union}
  decodingFunction::Union{Function, Union}
end

# A CloudGraph instance
type CloudGraph
  configuration::CloudGraphConfiguration
  neo4j::Neo4jInstance
  #mongo::MongoDbInstance
  packedPackedDataTypes::Dict{AbstractString, PackedType}
  packedOriginalDataTypes::Dict{AbstractString, PackedType}
  CloudGraph(configuration, neo4j) = new(configuration, neo4j, Dict{AbstractString, PackedType}(), Dict{AbstractString, PackedType}())
  CloudGraph(configuration, neo4j, packedDataTypes, originalDataTypes) = new(configuration, neo4j, packedDataTypes, originalDataTypes)
end

type CloudEdge
  neo4jEdgeId::Int
  neo4jSourceVertexId::Int
  neo4jDestVertexId::Int
  properties::Dict{UTF8String, Any} #AbstractString
  CloudEdge(cg::CloudGraph, vertexSrc::CloudVertex, vertexDst::CloudVertex; props=Dict{UTF8String, Any}) = new()
end

import Base.connect
# --- CloudGraph initialization ---
function connect(configuration::CloudGraphConfiguration)
  neoConn = Neo4j.Connection(configuration.neo4jHost, configuration.neo4jPort);
  neo4j = Neo4jInstance(neoConn, Neo4j.getgraph(neoConn));

  return CloudGraph(configuration, neo4j);
end

# Register a type with an optional converter.
function registerPackedType!(cloudGraph::CloudGraph, originalType::DataType, packedType::DataType; encodingConverter::Union{Function, Union}=Union{}, decodingConverter::Union{Function, Union}=Union{})
  newPackedType = PackedType(originalType, packedType, encodingConverter, decodingConverter);
  cloudGraph.packedPackedDataTypes[string(packedType)] = newPackedType;
  cloudGraph.packedOriginalDataTypes[string(originalType)] = newPackedType;
  nothing;
end

# --- CloudGraph shutdown ---
function disconnect(cloudGraph::CloudGraph)

end

# --- Common conversion functions ---
function exVertex2CloudVertex(vertex::ExVertex)
  cgvProperties = Dict{AbstractString, Any}();

  #1. Get the special attributes - payload, etc.
  propNames = keys(vertex.attributes);
  if("bigData" in propNames) #We have big data to save.
    bigData = vertex.attributes["bigData"];
  else
    bigData = BigData(false, false, false, Base.Random.uuid4(), 0);
  end
  if haskey(vertex.attributes, "packed") #("packed" in propNames) #We have protobuf stuff to save in the node.
    packed = vertex.attributes["packed"];
  else
    packed = "";
  end
  #2. Transfer everything else to properties
  for (k,v) in vertex.attributes
    if(k != "bigData" && k != "packed")
      cgvProperties[k] = v;
    end
  end
  #3. Encode the packed data and big data.
  return CloudVertex(packed, cgvProperties, bigData, -1, nothing, false, -1, false);
end

function cloudVertex2ExVertex(vertex::CloudVertex)

end

# --- Internal utility methods ---

function write_BigData(cg::CloudGraph, vertex::CloudVertex)

end

function read_BigData!(vertex::CloudVertex)
end

function cloudVertex2NeoProps(cg::CloudGraph, vertex::CloudVertex)
  props = deepcopy(vertex.properties);
  # Packed information
  pB = PipeBuffer();
  # ProtoBuf.writeproto(pB, vertex.packed);
  typeKey="NoType"
  # @show string(typeof(vertex.packed))
  # @show keys(cg.packedOriginalDataTypes)
  if(haskey(cg.packedOriginalDataTypes, string(typeof(vertex.packed)) ) ) # @GearsAD check, it was cg.convertTypes

    typeOriginalRegName = string(typeof(vertex.packed));
    packedType = cg.packedOriginalDataTypes[typeOriginalRegName].encodingFunction(vertex.packed);

    ProtoBuf.writeproto(pB, packedType); # vertex.packed
    typeKey = string(typeof(packedType));
  else
  end
  props["packed"] = pB.data;
  props["packedType"] = typeKey;

  # Big data
  # Write it.
  # write_BigData(cg, vertex);
  # Clear the underlying data in the Neo4j dataset and serialize the big data.
  saved = vertex.bigData.data;
  vertex.bigData.data = Vector{UInt8}();
  props["bigData"] = json(vertex.bigData);
  vertex.bigData.data = saved;

  # @show props["packedType"]
  # @show size(props["packed"])
  return props;
end

# function neoNode2CloudVertex(props::)
# end

# --- Graphs.jl overloads ---

function add_vertex!(cg::CloudGraph, vertex::ExVertex)
  add_vertex!(cg, exVertex2CloudVertex(vertex));
end

function add_vertex!(cg::CloudGraph, vertex::CloudVertex)
  try
    vertex.neo4jNode = Neo4j.createnode(cg.neo4j.graph, cloudVertex2NeoProps(cg, vertex));
    vertex.neo4jNodeId = vertex.neo4jNode.id;
    return vertex.neo4jNode;
  catch e
    rethrow(e);
    return false;
  end
end

# Retrieve a vertex and decompress it into a CloudVertex
function get_vertex(cg::CloudGraph, neoNodeId::Int, retrieveBigData::Bool)
  try
    neoNode = Neo4j.getnode(cg.neo4j.graph, neoNodeId);

    # Get the node properties.
    props = neoNode.data; #Neo4j.getnodeproperties(neoNode);

    # Unpack the packed data using an interim UInt8[].
    pData = convert(Array{UInt8}, props["packed"]);
    pB = PipeBuffer(pData);
    @show props["packedType"]

    typePackedRegName = props["packedType"];

    packed = readproto(pB, cg.packedPackedDataTypes[typePackedRegName].packingType() );
    recvOrigType = cg.packedPackedDataTypes[typePackedRegName].decodingFunction(packed);

    # Big data
    bDS = JSON.parse(props["bigData"]);
    bigData = BigData(bDS["isRetrieved"], bDS["isAvailable"], bDS["isExistingOnServer"], bDS["mongoKey"], 0);
    #bigData = BigData(bDS["isRetrieved"], bDS["isAvailable"], bDS["isExistingOnServer"],  0);

    # Now delete these out the props leaving the rest as general properties
    delete!(props, "packed");
    delete!(props, "packedType");
    delete!(props, "bigData");

    # Build a CloudGraph node.
    # TODO -- GearsAD please check that we want recvOrigType vs packed as first argument
    return CloudVertex(recvOrigType, props, bigData, neoNodeId, neoNode, true, -1, false);
  catch e
    rethrow(e);
  end
end

function update_vertex!(cg::CloudGraph, vertex::CloudVertex)
  try
    if(vertex.neo4jNode == nothing)
      error("There isn't a Neo4j Node associated with this CloudVertex. You might want to call add_vertex instead of update_vertex.");
    end

    props = cloudVertex2NeoProps(cg, vertex);
    Neo4j.updatenodeproperties(vertex.neo4jNode, props);
  catch e
    rethrow(e);
  end
end

function delete_vertex!(cg::CloudGraph, vertex::CloudVertex)
  if(vertex.neo4jNode == nothing)
    error("There isn't a Neo4j Node associated with this CloudVertex.");
  end

  warn("Still need to add the Mongo deletion to the call here...");

  Neo4j.deletenode(vertex.neo4jNode);

  vertex.neo4jNode = nothing;
  vertex.neo4jNodeId = -1;
end

function add_edge!(cg::CloudGraph, edge::CloudEdge)

end

function update_edge!()
end

function delete_edge!()
end

end #module
