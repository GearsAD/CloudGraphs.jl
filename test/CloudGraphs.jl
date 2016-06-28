using Base.Test;
using Graphs;
using ProtoBuf;
using JSON;
using CloudGraphs;
# For a representative packed structure

# Creating a connection
print("[TEST] Connecting to the local CloudGraphs instance (Neo4j and Mongo)...");
configuration = CloudGraphs.CloudGraphConfiguration("localhost", 7474, false, "", "", "localhost", 27017, false, "", "");
cloudGraph = connect(configuration);
println("Success!");

# Testing type registration
type DataTest
  matrix::Array{Float64, 2}
  string::ASCIIString
  boolmatrix::Array{Int32,2}
  DataTest() = new()
  DataTest(m,s,b) = new(m,s,b)
end
type PackedDataTest
  vecmat::Vector{Float64}
  matrows::Int64
  string::ASCIIString
  boolvecmat::Array{Int32,1}
  boolmatrows::Int64
  PackedDataTest() = new()
  PackedDataTest(m,i1,s,b,i2) = new(m[:],i1,s,b[:],i2)
  PackedDataTest(d::DataTest) = new(d.matrix[:],
                                  size(d.matrix,1),
                                  d.string,
                                  d.boolmatrix[:],
                                  size(d.boolmatrix,1))
end

function encoder(d::DataTest)
  return PackedDataTest(d)
end
function decoder(d::PackedDataTest)
  r1 = d.matrows
  c1 = floor(Int,length(d.vecmat)/r1)
  M1 = reshape(d.vecmat,r1,c1)
  r2 = d.matrows
  c2 = floor(Int,length(d.boolvecmat)/r2)
  M2 = reshape(d.boolvecmat,r2,c2)
  return DataTest(M1,d.string,M2)
end

print("[TEST] Registering a packed type...");
# Let's register a packed type.
CloudGraphs.registerPackedType!(cloudGraph, DataTest, PackedDataTest, encodingConverter=encoder, decodingConverter=decoder);
println("Registered types = $(cloudGraph.packedPackedDataTypes)");
println("Registered types = $(cloudGraph.packedOriginalDataTypes)");
@test length(cloudGraph.packedPackedDataTypes) > 0
@test length(cloudGraph.packedOriginalDataTypes) > 0
# And check that if we encode and decode this type, it's exactly the same.
# Make a packed data test structure.
fullType = DataTest(rand(10,10), "This is a test string", rand(Int32,10,10));
typePackedRegName = string(PackedDataTest);
typeOriginalRegName = string(DataTest);
# Now lets encode and decode to see.
testPackedType = cloudGraph.packedOriginalDataTypes[typeOriginalRegName].encodingFunction(fullType);
testFullType = cloudGraph.packedPackedDataTypes[typePackedRegName].decodingFunction(testPackedType);
@test json(testFullType) == json(fullType)

# Creating a local test graph.
localGraph = graph(ExVertex[], ExEdge{ExVertex}[]);
#Make an ExVertex that may be encoded
v = make_vertex(localGraph, "TestVertex");
vertex = Graphs.add_vertex!(localGraph, v);
vertex.attributes["packed"] = fullType;
vertex.attributes["age"] = 64;
vertex.attributes["latestEstimate"] = [0.0,0.0,0.0];
bigData = CloudGraphs.BigData(true, true, false, rand(10, 10, 10));
vertex.attributes["bigData"] = bigData;

# Now encoding the structure to CloudGraphs vertex
cloudVertex = CloudGraphs.exVertex2CloudVertex(vertex);

CloudGraphs.add_vertex!(cloudGraph, cloudVertex);

# Get the node from Neo4j.
cloudVertexRet = CloudGraphs.get_vertex(cloudGraph, cloudVertex.neo4jNode.id, false) # fullType not required


# Check that all the important bits match using string comparisons of the JSON form of the structures
@test json(cloudVertex.packed) == json(cloudVertexRet.packed)
#@test json(cloudVertex.bigData) == json(cloudVertexRet.bigData)
# @test json(cloudVertex.properties) == json(cloudVertexRet.properties)
# @test cloudVertex.neo4jNodeId == cloudVertexRet.neo4jNodeId
# @test json(cloudVertex.neo4jNode) == json(cloudVertexRet.neo4jNode)











#
