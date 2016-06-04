
#Installations
Pkg.clone("https://github.com/Lytol/Mongo.jl")

#Types
export CloudGraphConfiguration, CloudGraph
#Functions
export open, close, add_vertex!, add_vertex!, make_edge, add_edge!
export cloudVertex2ExVertex, exVertex2CloudVertex
using Graphs;
using Neo4j;
using Mongo;

type CloudVertex
  packed::Array{UInt8}
  properties::Dict{AbstractString, Any}
  bigData::BigData
  neo4jNodeId::Int
  isValidNeoNodeId::Bool
  exVertexId::Int
  isValidExVertex::Bool
end

type BigData
  isRetrieved::Bool
  isAvailable::Bool
  isExistingOnServer::Bool
  mongoKey::Base.Random.UUID
  data::Any
end

type CloudEdge {

}

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

type MongoDbInstance
  connection::Mongo.MongoClient
end

# A CloudGraph instance
type CloudGraph
  configuration::CloudGraphConfiguration
  neo4j::Neo4jInstance
  #mongo::MongoDbInstance
end

import Base.connect
# --- CloudGraph initialization ---
function connect(configuration::CloudGraphConfiguration)
  neoConn = Neo4j.Connection(configuration.neo4jHost, configuration.neo4jPort);
  neo4j = Neo4jInstance(neoConn, Neo4j.getgraph(neoConn));

  return CloudGraph(configuration, neo4j);
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
  end
  if("packed" in propNames) #We have protobuf stuff to save in the node.
    packed = vertex.attributes["packed"];
    pB = PipeBuffer();
    writeproto(pB, packed);
    packedData = pB.data; #UInt8 array.
  end
  #2. Transfer everything else to properties
  for (k,v) in vertex.attributes
    if(k != "bigData" && k != "packed")
      cgvProperties[k] = v;
    end
  end
  #3. Encode the packed data and big data.
  return CloudVertex3(packedData, cgvProperties, bigData, -1, false, -1, false);
end

function cloudVertex2ExVertex(vertex::CloudVertex)

end

# --- Graphs.jl overloads ---

function add_vertex!(cg::CloudGraph, vertex::ExVertex)
  add_vertex(cg, ExVertex2CloudVertex(vertex));
end

function add_vertex!(cg::CloudGraph, vertex::CloudVertex)

end

function make_edge(cg::CloudGraph, vertexSrc::ExVertex, vertexDst::ExVertex)

end

function make_edge(cg::CloudGraph, vertexSrc::CloudVertex, vertexDst::CloudVertex)

end

function add_edge!(cg::CloudGraph, edge::ExEdge)

end
