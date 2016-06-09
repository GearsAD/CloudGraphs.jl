using Base.Test;
using Graphs;
using ProtoBuf;
using JSON;

# Importing src for now
#include("C:\\Users\\GearsAD\\.julia\\v0.4\\CloudGraphs\\src\\CloudGraphs.jl")
using CloudGraphs;

# Creating a connection
configuration = CloudGraphs.CloudGraphConfiguration("localhost", 7474, false, "", "", "localhost", 27017, false, "", "");
cloudGraph = connect(configuration);

# Creating a local test graph.
localGraph = graph(ExVertex[], ExEdge{ExVertex}[]);
#Make an ExVertex that may be encoded
v = make_vertex(localGraph, "TestVertex");
vertex = Graphs.add_vertex!(localGraph, v);
# Make a big data test structure.
type PackedDataTest
  matrix::Array{Float64, 2}
  string::ASCIIString
  boolmatrix::BitArray{2}
end
packed = PackedDataTest(rand(10,10), "This is a test string", trues(10,10));
vertex.attributes["packed"] = packed;
vertex.attributes["age"] = 64;
vertex.attributes["latestEstimate"] = [0.0,0.0,0.0];
bigData = CloudGraphs.BigData(true, true, false, rand(10, 10, 10));
vertex.attributes["bigData"] = bigData;

# Now encoding the structure to CloudGraphs vertex
cloudVertex = CloudGraphs.exVertex2CloudVertex(vertex);

CloudGraphs.add_vertex!(cloudGraph, cloudVertex);
