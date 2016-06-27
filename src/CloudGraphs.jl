module CloudGraphs

using Graphs;
using Neo4j;
# using Mongo;
using ProtoBuf;
using JSON;

#Types
export CloudGraphConfiguration, CloudGraph, CloudVertex, BigData
#Functions
export open, close, add_vertex!, get_vertex, make_edge, add_edge!
export cloudVertex2ExVertex, exVertex2CloudVertex
export registerPackedType!

type BigData
  isRetrieved::Bool
  isAvailable::Bool
  isExistingOnServer::Bool
  mongoKey::AbstractString
  data::Any
  BigData(isRetrieved, isAvailable, isExistingOnServer, data) = new(isRetrieved, isAvailable, isExistingOnServer, string(Base.Random.uuid4()), data)
  BigData(isRetrieved, isAvailable, isExistingOnServer, mongoKey, data) = new(isRetrieved, isAvailable, isExistingOnServer, mongoKey, data)
end

type CloudVertex
  packed::Any
  properties::Dict{AbstractString, Any}
  bigData::BigData
  neo4jNodeId::Int
  neo4jNode::Union{Void,Neo4j.Node}
  isValidNeoNodeId::Bool
  exVertexId::Int
  isValidExVertex::Bool
end

type CloudEdge

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
  if("packed" in propNames) #We have protobuf stuff to save in the node.
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

# --- Graphs.jl overloads ---

function write_BigData(cg::CloudGraph, vertex::CloudVertex)

end

function read_BigData!(vertex::CloudVertex)
end

function add_vertex!(cg::CloudGraph, vertex::ExVertex)
  add_vertex!(cg, exVertex2CloudVertex(vertex));
end

function add_vertex!(cg::CloudGraph, vertex::CloudVertex)
  try
    props = deepcopy(vertex.properties);
    # Packed information
    pB = PipeBuffer();
    ProtoBuf.writeproto(pB, vertex.packed);
    typeKey = string(typeof(vertex.packed));
    if(haskey(cg.packedConverters, typeKey))
      ProtoBuf.writeproto(pB, vertex.packed);
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
    vertex.neo4jNode = Neo4j.createnode(cg.neo4j.graph, props);
    vertex.neo4jNodeId = vertex.neo4jNode.id;
    return vertex.neo4jNode;
  catch e
    rethrow(e);
    return false;
  end
end

# Retrieve a vertex and decompress it into a CloudVertex
function get_vertex(cg::CloudGraph, neoNodeId::Int, packedDataTypeExample, retrieveBigData::Bool)
  try
    neoNode = Neo4j.getnode(cg.neo4j.graph, neoNodeId);

    # Get the node properties.
    props = neoNode.data; #Neo4j.getnodeproperties(neoNode);

    # Unpack the packed data using an interim UInt8[].
    pData = convert(Array{UInt8}, props["packed"]);
    pB = PipeBuffer(pData);
    packed = readproto(pB, packedDataTypeExample);

    # Big data
    bDS = JSON.parse(props["bigData"]);
    bigData = BigData(bDS["isRetrieved"], bDS["isAvailable"], bDS["isExistingOnServer"], bDS["mongoKey"], 0);
    #bigData = BigData(bDS["isRetrieved"], bDS["isAvailable"], bDS["isExistingOnServer"],  0);

    # Now delete these out the props leaving the rest as general properties
    delete!(props, "packed");
    delete!(props, "bigData");

    # Build a CloudGraph node.
    return CloudVertex(packed, props, bigData, neoNodeId, neoNode, true, -1, false);
  catch e
    rethrow(e);
  end
end

function make_edge(cg::CloudGraph, vertexSrc::ExVertex, vertexDst::ExVertex)

end

function make_edge(cg::CloudGraph, vertexSrc::CloudVertex, vertexDst::CloudVertex)

end

function add_edge!(cg::CloudGraph, edge::ExEdge)

end

end
