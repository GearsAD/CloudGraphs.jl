module CloudGraphs

import Graphs: add_edge!, add_vertex!

using Graphs;
using Neo4j;
using Mongo;
using LibBSON;
using ProtoBuf;
using JSON;

# extending methods

#Types
export CloudGraphConfiguration, CloudGraph, CloudVertex, CloudEdge, BigData, BigDataElement
#Functions
export connect, disconnect, add_vertex!, get_vertex, update_vertex!, delete_vertex!
export add_edge!, delete_edge!, get_edge
export save_BigData!, read_BigData
export get_neighbors
export cloudVertex2ExVertex, exVertex2CloudVertex
export registerPackedType!

type BigDataElement
  description:: AbstractString
  data:: Vector{UInt8}
  mongoKey:: AbstractString
  BigDataElement(desc::AbstractString, data::Vector{UInt8}) = new(desc, data, "")
  BigDataElement(desc::AbstractString, data::Vector{UInt8}, mongoKey::AbstractString) = new(desc, data, mongoKey)
end

type BigData
  isRetrieved::Bool
  isAvailable::Bool
  isExistingOnServer::Bool
  lastSavedTimestamp::AbstractString #UTC DateTime.
  dataElements::Vector{BigDataElement}
  # This is just for local use, and is not saved directly into the graph.
  BigData() = new(false, false, false, "[N/A]", Vector{BigDataElement}())
  BigData{T <: AbstractString}(isRetrieved::Bool, isAvailable::Bool, isExistingOnServer::Bool, lastSavedTimestamp::T, data::Vector{BigDataElement}) = new(isRetrieved, isAvailable, isExistingOnServer, lastSavedTimestamp, data)
end

type CloudVertex
  packed::Any
  properties::Dict{AbstractString, Any} # UTF8String
  bigData::BigData
  neo4jNodeId::Int
  neo4jNode::Union{Void,Neo4j.Node}
  labels::Vector{AbstractString}
  isValidNeoNodeId::Bool
  exVertexId::Int
  isValidExVertex::Bool
  CloudVertex() = new(Union, Dict{UTF8String, Any}(), BigData(), -1, nothing, Vector{AbstractString}(), false, -1, false)
  CloudVertex{T <: AbstractString}(packed, properties, bigData, neo4jNodeId, neo4jNode, isValidNeoNodeId, exVertexId, isValidExVertex; labels::Vector{T}=Vector{String}()) = new(packed, properties, bigData, neo4jNodeId, neo4jNode, labels, isValidNeoNodeId, exVertexId, isValidExVertex)
end

# A single configuration type for a CloudGraph instance.
type CloudGraphConfiguration
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

type Neo4jInstance
  connection::Neo4j.Connection
  graph::Neo4j.Graph
end

type MongoDbInstance
  client::Mongo.MongoClient
  cgBindataCollection::MongoCollection
end

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
  mongo::MongoDbInstance
  packedPackedDataTypes::Dict{AbstractString, PackedType}
  packedOriginalDataTypes::Dict{AbstractString, PackedType}
  CloudGraph(configuration, neo4j, mongo) = new(configuration, neo4j, mongo, Dict{AbstractString, PackedType}(), Dict{AbstractString, PackedType}())
  CloudGraph(configuration, neo4j, mongo, packedDataTypes, originalDataTypes) = new(configuration, neo4j, mongo, packedDataTypes, originalDataTypes)
end

type CloudEdge
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

import Base.connect
# --- CloudGraph initialization ---
function connect(configuration::CloudGraphConfiguration)
  neoConn = Neo4j.Connection(configuration.neo4jHost, port=configuration.neo4jPort, user=configuration.neo4jUsername, password=configuration.neo4jPassword);
  neo4j = Neo4jInstance(neoConn, Neo4j.getgraph(neoConn));

  mongoClient = Mongo.MongoClient(configuration.mongoHost, configuration.mongoPort);
  cgBindataCollection = Mongo.MongoCollection(mongoClient, "CloudGraphs", "bindata");
  mongoInstance = MongoDbInstance(mongoClient, cgBindataCollection);

  return CloudGraph(configuration, neo4j, mongoInstance);
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
    bigData = BigData();
  end
  if haskey(vertex.attributes, "data") #("data" in propNames) #We have protobuf stuff to save in the node.
    packed = vertex.attributes["data"];
  else
    packed = "";
  end
  #2. Transfer everything else to properties
  for (k,v) in vertex.attributes
    if(k != "bigData" && k != "data")
      cgvProperties[k] = v;
    end
  end
  #3. Encode the packed data and big data.
  return CloudVertex(packed, cgvProperties, bigData, -1, nothing, false, vertex.index, false);
end

function cloudVertex2ExVertex(vertex::CloudVertex)
  # create an ExVertex
  vert = Graphs.ExVertex(vertex.exVertexId, vertex.properties["label"])
  vert.attributes = Graphs.AttributeDict()
  vert.attributes = vertex.properties

  # populate the data container
  vert.attributes["data"] = vertex.packed
  return vert
end

# --- Internal utility methods ---

# Until we can do Bindata.
function _uint8ArrayToString(arr::Vector{UInt8})
  sMap = "[" * chop(mapreduce(x->x*",", *, map(x -> hex(x,2), arr))) * "]";
  return(sMap);
end

# Until we can do Bindata.
function _stringToUint8Array(packedString::AbstractString)
  ss = split(packedString[2:end-1],',')
  # @show(ss)
  aa = Vector{UInt8}(length(ss))
  @inbounds @simd for i in 1:length(aa)
    #TODO: Possible optimization here by doing multiple elements at once.
    # @show(ss[i])
    aa[i]=hex2bytes(ss[i])[1]
  end
  return(aa)
end

function _saveBigDataElement!(cg::CloudGraph, vertex::CloudVertex, bDE::BigDataElement)
  stringArray = _uint8ArrayToString(bDE.data);
  #Check if the key exists...
  isNew = true;
  if(bDE.mongoKey != "")
    numNodes = count(cg.mongo.cgBindataCollection, ("_id" => BSONOID(bDE.mongoKey)));
    isNew = numNodes == 0;
  end
  if(isNew)
    # Insert the node
    m_oid = insert(cg.mongo.cgBindataCollection, ("neoNodeId" => vertex.neo4jNodeId, "val" => stringArray, "description" => bDE.description))
    @show "Inserted big data to mongo id = $(m_oid)"
    #Update local instance
    bDE.mongoKey = string(m_oid);
  else
    # Update the node
    m_oid = update(cg.mongo.cgBindataCollection, ("_id" => BSONOID(bDE.mongoKey)), set("neoNodeId" => vertex.neo4jNodeId, "val" => stringArray, "description" => bDE.description))
    @show "Updated big data to mongo id (result=$(m_oid)) (key $(bDE.mongoKey))"
  end
end

function save_BigData!(cg::CloudGraph, vertex::CloudVertex)
  #Write to Mongo
  for(bDE in vertex.bigData.dataElements)
    _saveBigDataElement!(cg, vertex, bDE);
  end

  #Now update the Neo4j node.
  savedSets = Vector{Vector{UInt8}}();
  for elem in vertex.bigData.dataElements
    push!(savedSets, elem.data);
    elem.data = Vector{UInt8}();
  end
  vertex.bigData.isExistingOnServer = true;
  vertex.bigData.lastSavedTimestamp = string(Dates.now(Dates.UTC));

  # Get the json bigData prop.
  bdProp = json(vertex.bigData);
  # Now put the data back
  i = 1;
  for elem in vertex.bigData.dataElements
    elem.data = savedSets[i];
    i = i +1;
  end

  #Update the bigdata property
  setnodeproperty(vertex.neo4jNode, "bigData", bdProp);
end

function read_BigData!(cg::CloudGraph, vertex::CloudVertex)
  if(vertex.bigData.isExistingOnServer == false)
    error("The data does not exist on the server. 'isExistingOnServer' is false. Have you saved with set_BigData!()");
  end
  for bDE in vertex.bigData.dataElements
    mongoId = BSONOID(bDE.mongoKey);
    numNodes = count(cg.mongo.cgBindataCollection, ("_id" => mongoId));
    if(numNodes != 1)
      error("The query for $(mongoId) returned $(numNodes) values, expected a 1-to-1 mapping!");
    end
    results = first(find(cg.mongo.cgBindataCollection, ("_id" => eq(mongoId))));
    #Have it, now parse it until we have a native binary datatype.
    bDE.data = _stringToUint8Array(results["val"]);
  end
  return(vertex.bigData)
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
    packingtypedef = cg.packedOriginalDataTypes[typeOriginalRegName].packingType
    packedType = cg.packedOriginalDataTypes[typeOriginalRegName].encodingFunction(packingtypedef, vertex.packed);
    ProtoBuf.writeproto(pB, packedType); # vertex.packed
    typeKey = string(typeof(packedType));
  else
  end
  props["data"] = pB.data;
  props["packedType"] = typeKey;

  # Big data
  # Write it.
  # Clear the underlying data in the Neo4j dataset and serialize the big data.
  savedSets = Vector{Vector{UInt8}}();
  for elem in vertex.bigData.dataElements
    push!(savedSets, elem.data);
    elem.data = Vector{UInt8}();
  end
  props["bigData"] = json(vertex.bigData);
  # Now put it back
  i = 1;
  for elem in vertex.bigData.dataElements
    elem.data = savedSets[i];
    i = i +1;
  end

  props["exVertexId"] = vertex.exVertexId

  return props;
end

function neoNode2CloudVertex(cg::CloudGraph, neoNode::Neo4j.Node)
  # Get the node properties.
  props = neoNode.data;

  # Unpack the packed data using an interim UInt8[].
  if !haskey(props, "data")
    error("dont have data field in neoNode id=$(neoNode.id)")
  end
  pData = convert(Array{UInt8}, props["data"]);
  pB = PipeBuffer(pData);

  typePackedRegName = props["packedType"];

  packed = readproto(pB, cg.packedPackedDataTypes[typePackedRegName].packingType() );
  origtypedef = cg.packedPackedDataTypes[typePackedRegName].originalType
  recvOrigType = cg.packedPackedDataTypes[typePackedRegName].decodingFunction(origtypedef, packed);

  # Big data
  jsonBD = props["bigData"];
  bDS = JSON.parse(jsonBD);
  # new addition of the timestamp.
  # TODO [GearsAD] : Remove this in the future as all nodes should have it.
  ts = haskey(bDS, "lastSavedTimestamp") ? bDS["lastSavedTimestamp"] : "[N/A]";
  bigData = BigData(bDS["isRetrieved"], bDS["isAvailable"], bDS["isExistingOnServer"], ts, Vector{BigDataElement}());
  # TODO: Remove the haskey again in the future once all nodes are up to date.
  if(haskey(bDS, "dataElements"))
    for bDE in bDS["dataElements"]
      elem = BigDataElement(bDE["description"], Vector{UInt8}(), bDE["mongoKey"])
      push!(bigData.dataElements, elem);
    end
  end

  labels = convert(Vector{AbstractString}, Neo4j.getnodelabels(neoNode));
  if(length(labels) == 0)
    labels = Vector{AbstractString}();
  end

  # Now delete these out the props leaving the rest as general properties
  delete!(props, "data");
  delete!(props, "packedType");
  delete!(props, "bigData");
  exvid = props["exVertexId"]
  delete!(props, "exVertexId")

  # Build a CloudGraph node.
  return CloudVertex(recvOrigType, props, bigData, neoNode.metadata["id"], neoNode, true, exvid, false; labels=labels);
end

# --- Graphs.jl overloads ---

function add_vertex!(cg::CloudGraph, vertex::ExVertex)
  add_vertex!(cg, exVertex2CloudVertex(vertex));
end

function add_vertex!(cg::CloudGraph, vertex::CloudVertex)
  try
    props = cloudVertex2NeoProps(cg, vertex)
    vertex.neo4jNode = Neo4j.createnode(cg.neo4j.graph, props);
    #Set the labels
    if(length(vertex.labels) > 0)
      Neo4j.addnodelabels(vertex.neo4jNode, vertex.labels);
    end
    #Update the Neo4j info.
    vertex.neo4jNodeId = vertex.neo4jNode.id;
    vertex.isValidNeoNodeId = true
    # make sure original struct gets the new bits of data it should have -- rather show than hide?
    # for ky in ["data"; "packedType"]  vertex.properties[ky] = props[ky] end
    return vertex.neo4jNode;
  catch e
    rethrow(e);
    return false;
  end
end

# Deprecating the native GetData calls for BigData.
function get_vertex(cg::CloudGraph, neoNodeId::Int, retrieveBigData::Bool)
  cgVertex = get_vertex(cg, neoNodeId)
  if(retrieveBigData && cgVertex.bigData.isExistingOnServer)
    read_BigData!(cg, cgVertex);
  end
  return(cgVertex)
end

# Retrieve a vertex and decompress it into a CloudVertex
function get_vertex(cg::CloudGraph, neoNodeId::Int)
  try
    neoNode = Neo4j.getnode(cg.neo4j.graph, neoNodeId);
    return(neoNode2CloudVertex(cg, neoNode))
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

    # Update the labels
    Neo4j.updatenodelabels(vertex.neo4jNode, vertex.labels);
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
  vertex.isValidNeoNodeId = false;
  nothing;
end


function add_edge!(cg::CloudGraph, edge::CloudEdge)
  if(edge.SourceVertex.neo4jNode == nothing)
    error("There isn't a valid source Neo4j in this CloudEdge.");
  end
  if(edge.DestVertex.neo4jNode == nothing)
    error("There isn't a valid destination Neo4j in this CloudEdge.");
  end

  retrel = Neo4j.createrel(edge.SourceVertex.neo4jNode, edge.DestVertex.neo4jNode, edge.edgeType; props=edge.properties );
  edge.neo4jEdge = retrel;
  edge.neo4jEdgeId = retrel.id

  # add destid to sourcevert and visa versa
  if haskey(edge.SourceVertex.properties, "neighborVertexIDs")
    # push!(edge.SourceVertex.properties["neighborVertexIDs"], edge.DestVertex.neo4jNodeId)
    edge.SourceVertex.properties["neighborVertexIDs"] = union(edge.SourceVertex.properties["neighborVertexIDs"], [edge.DestVertex.neo4jNodeId])
  else
    edge.SourceVertex.properties["neighborVertexIDs"] = Array{Int64,1}([edge.DestVertex.neo4jNodeId])
  end
  if haskey(edge.DestVertex.properties, "neighborVertexIDs")
    # push!(edge.DestVertex.properties["neighborVertexIDs"], edge.SourceVertex.neo4jNodeId)
    edge.DestVertex.properties["neighborVertexIDs"] = union(edge.DestVertex.properties["neighborVertexIDs"], [edge.SourceVertex.neo4jNodeId])
  else
    edge.DestVertex.properties["neighborVertexIDs"] = Array{Int64,1}([edge.SourceVertex.neo4jNodeId])
  end

  update_vertex!(cg, edge.SourceVertex)
  update_vertex!(cg, edge.DestVertex)

  retrel
end

function get_edge(cg::CloudGraph, neoEdgeId::Int)
  try
    neoEdge = Neo4j.getrel(cg.neo4j.graph, neoEdgeId);
    startid = parse(Int,split(neoEdge.relstart,'/')[end])
    endid = parse(Int,split(neoEdge.relend,'/')[end])
    cloudVert1 = CloudGraphs.get_vertex(cg, startid, false)
    cloudVert2 = CloudGraphs.get_vertex(cg, endid, false)
    # Get the node properties.
    # props = neoEdge.data; # TODO
    edge = CloudGraphs.CloudEdge(cloudVert1, cloudVert2, neoEdge.reltype);
    edge.neo4jEdgeId = neoEdge.id
    edge.neo4jEdge = neoEdge

    return edge
  catch e
    rethrow(e);
  end
end

#function update_edge!()
#end

function delete_edge!(cg::CloudGraph, edge::CloudEdge)
  if(edge.SourceVertex == nothing)
    error("There isn't a valid source Neo4j in this CloudEdge.");
  end
  if(edge.DestVertex == nothing)
    error("There isn't a valid destination Neo4j in this CloudEdge.");
  end

  Neo4j.deleterel(edge.neo4jEdge)
  edge.neo4jEdge = nothing;
  edge.neo4jEdgeId = -1;
  # Remove from either nodes.
  edge.SourceVertex.properties["neighborVertexIDs"] = edge.SourceVertex.properties["neighborVertexIDs"][edge.SourceVertex.properties["neighborVertexIDs"] .!= edge.DestVertex.neo4jNodeId];
  edge.DestVertex.properties["neighborVertexIDs"] = edge.DestVertex.properties["neighborVertexIDs"][edge.DestVertex.properties["neighborVertexIDs"] .!= edge.SourceVertex.neo4jNodeId];
  # Update the vertices
  update_vertex!(cg, edge.SourceVertex);
  update_vertex!(cg, edge.DestVertex);

  nothing;
end

function get_neighbors(cg::CloudGraph, vert::CloudVertex; incoming::Bool=true, outgoing::Bool=true)
  if(vert.neo4jNode == nothing)
    error("The provided vertex does not have it's associated Neo4j Node (vertex.neo4jNode) - please perform a get_vertex to get the complete structure first.")
  end

  neo4jNeighbors = Neo4j.getneighbors(vert.neo4jNode, incoming=incoming, outgoing=outgoing)

  neighbors = CloudVertex[]
  for neoNeighbor in neo4jNeighbors
    push!(neighbors, neoNode2CloudVertex(cg, neoNeighbor))
  end
  return(neighbors)
end

end #module
