# Testing of the CloudGraph types
Pkg.add("Images")

include("CloudGraphs.jl")
using Base.Test;
using Graphs;
using Images, TestImages;
using ProtoBuf;

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
packed = PackedDataTest(rand(1000,1000), "This is a test string", trues(1000,1000));
vertex.attributes["packed"] = packed;
vertex.attributes["age"] = 64;
vertex.attributes["latestEstimate"] = [0.0,0.0,0.0];
bigData = BigData(true, true, false, Base.Random.uuid4(), rand(100, 100, 100));
vertex.attributes["bigData"] = bigData;

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

# Now encoding the structure to CloudGraphs vertex
cloudVertex = exVertex2CloudVertex(vertex)
