# Testing of the CloudGraph types

include("../src/CloudGraphs.jl")
using Base.Test;
using Graphs;
using ProtoBuf;
using JSON;

# Creating a connection
configuration = CloudGraphConfiguration("localhost", 7474, false, "", "", "localhost", 27017, false, "", "");
cloudGraph = connect(configuration);

# Creating a local test graph.
localGraph = graph(ExVertex[], ExEdge{ExVertex}[]);
#Make an ExVertex that may be encoded
vertex = add_vertex!(localGraph, "TestVertex");
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
bigData = BigData(true, true, false, Base.Random.uuid4(), rand(100, 100, 100));
vertex.attributes["bigData"] = bigData;

# Now encoding the structure to CloudGraphs vertex
cloudVertex = exVertex2CloudVertex(vertex);

# Let's save this node
add_vertex!(cloudGraph, cloudVertex);
