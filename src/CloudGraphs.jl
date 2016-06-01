
#Installations
Pkg.clone("https://github.com/Lytol/Mongo.jl")

#Types
export CloudGraphConfiguration, CloudGraph
#Functions
export open, close, add_vertex!, add_vertex!, make_edge, add_edge!

using Graphs;
using Neo4j;
using Mongo;

type CloudVertex {
  # id = {}
  # labels = List{Any}
  # properties = Dict{Any, Any} {
  #   latestEstimate = [0,0,0],
  #   age = Int64,
  #   payload = IOBuffer, #Protobuf - either IOBuffer or PipeBuffer
  #   bigDataMongoKey = Guid,
  # }
}

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
function exVertex2CloudVertex(vertex:ExVertex)
  #1. Get the special attributes - payload, etc.
  #2. Transfer everything else to properties
  #3. Encode the payload.
end

function cloudVertex2ExVertex(vertex:CloudVertex)

end

# --- Graphs.jl overloads ---

function add_vertex!(cg:CloudGraph, vertex:ExVertex)
  add_vertex(cg, ExVertex2CloudVertex(vertex));
end

function add_vertex!(cg:CloudGraph, vertex:CloudVertex)

end

function make_edge(cg:CloudGraph, vertexSrc:ExVertex, vertexDst:ExVertex)

end

function make_edge(cg:CloudGraph, vertexSrc:CloudVertex, vertexDst:CloudVertex)

end

function add_edge!(cg:CloudGraph, edge:ExEdge)

end
