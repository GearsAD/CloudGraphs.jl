# Testing of the CloudGraph types
Pkg.add("Images")

include("CloudGraphs.jl")
using Base.Test;
using Graphs;
using Images, TestImages;

# Creating a connection
configuration = CloudGraphConfiguration("localhost", 7474, false, "", "", "localhost", 27017, false, "", "");
cloudGraph = connect(configuration);

# Creating a local test graph.
localGraph = graph(ExVertex[], ExEdge{ExVertex}[])
vertex = add_vertex!(localGraph, "TestVertex")
#Make an ExVertex that may be encoded into
fieldnames(vertex)
