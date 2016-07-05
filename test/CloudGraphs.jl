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

println("[TEST] Registering a packed type and testing the Protobuf encoding/decoding...");
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
println("Encoding...")
testPackedType = cloudGraph.packedOriginalDataTypes[typeOriginalRegName].encodingFunction(fullType);
println("Decoding...")
testFullType = cloudGraph.packedPackedDataTypes[typePackedRegName].decodingFunction(testPackedType);
@test json(testFullType) == json(fullType)
println("Success!")

# Creating a local test graph.
print("[TEST] Creating a CloudVertex from an ExVertex...")
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
println("Success!");

print("[TEST] Adding a vertex...")
CloudGraphs.add_vertex!(cloudGraph, cloudVertex);
println("Success!")

# Get the node from Neo4j.
print("[TEST] Retrieving a node from CloudGraph...")
cloudVertexRet = CloudGraphs.get_vertex(cloudGraph, cloudVertex.neo4jNode.id, false) # fullType not required
# Check that all the important bits match using string comparisons of the JSON form of the structures
@test json(cloudVertex.packed) == json(cloudVertexRet.packed)
#@test json(cloudVertex.bigData) == json(cloudVertexRet.bigData)
@show "Expected = ", json(cloudVertex.properties)
@show "Received = ", json(cloudVertexRet.properties)
@test json(cloudVertex.properties) == json(cloudVertexRet.properties)
@test cloudVertex.neo4jNodeId == cloudVertexRet.neo4jNodeId
@test cloudVertexRet.neo4jNode != Void
println("Success!")

print("[TEST] Testing the update method...")
cloudVertex.properties["age"] = 100;
cloudVertex.properties["latestEstimate"] = [5.0, 5.0, 5.0];
CloudGraphs.update_vertex!(cloudGraph, cloudVertex);
# Let's retrieve it and see if it is updated.
cloudVertexRet = CloudGraphs.get_vertex(cloudGraph, cloudVertex.neo4jNode.id, false)
# And check that it matches
@show json(cloudVertexRet.properties);
@test json(cloudVertex.properties) == json(cloudVertexRet.properties);
println("Success!")

print("[TEST] Deleting a CloudGraph vertex...")
CloudGraphs.delete_vertex!(cloudGraph, cloudVertex);
println("Success!")

print("[TEST] Negative testing for double deletions...")
# Testing a double-delete
try
  CloudGraphs.delete_vertex!(cloudGraph, cloudVertex);
  @test false
catch
  print("Success!")
end
# Testing the deletion of an apparently existing node
try
  CloudGraphs.delete_vertex!(cloudGraph, cloudVertexRet);
  @test false
catch
  print("Success!")
end

print("[TEST] Making an edge...")
# Create two vertices
cloudVert1 = deepcopy(cloudVertex);
cloudVert1.properties["name"] = "Sam's Vertex 1";
cloudVert2 = deepcopy(cloudVertex);
cloudVert2.properties["name"] = "Sam's Vertex 2";
CloudGraphs.add_vertex!(cloudGraph, cloudVert1);
CloudGraphs.add_vertex!(cloudGraph, cloudVert2);

# Create an edge and add it to the graph.
# Test props
props = Dict{UTF8String, Any}(utf8("Test") => 8);
edge = CloudGraphs.CloudEdge(cloudVert1, cloudVert2, "DEPENDENCE");
CloudGraphs.add_edge!(cloudGraph, edge);
@test edge.neo4jEdge != nothing
@test edge.neo4jEdgeId != -1
println("Success!")

print("[TEST] Get edge from graph")
gotedge = CloudGraphs.get_edge(cloudGraph, edge.neo4jEdgeId)
@test typeof(gotedge) == CloudGraphs.CloudEdge
@test edge.neo4jEdgeId == gotedge.neo4jEdgeId
@test gotedge.neo4jEdge != edge.neo4jEdge
@test edge.edgeType == gotedge.edgeType
@test edge.neo4jSourceVertexId == gotedge.neo4jSourceVertexId
@test edge.neo4jDestVertexId == gotedge.neo4jDestVertexId
@test edge.properties == gotedge.properties

function testCloudGraphsNodeCompares(a::Neo4j.Node, b::Neo4j.Node)
  @test a.paged_traverse == b.paged_traverse
  @test a.labels == b.labels
  @test a.outgoing_relationships == b.outgoing_relationships
  @test a.traverse == b.traverse
  @test a.all_typed_relationships == b.all_typed_relationships
  @test a.all_relationships == b.all_relationships
  @test a.property == b.property
  @test a.self == b.self
  @test a.outgoing_typed_relationships == b.outgoing_typed_relationships
  @test a.properties == b.properties
  @test a.incoming_relationships == b.incoming_relationships
  @test a.incoming_typed_relationships == b.incoming_typed_relationships
  @test a.id == b.id
  # ignore packed data
  # @test a.data == b.data
  nothing
end

testCloudGraphsNodeCompares(edge.DestVertex.neo4jNode, gotedge.DestVertex.neo4jNode)
testCloudGraphsNodeCompares(edge.SourceVertex.neo4jNode, gotedge.SourceVertex.neo4jNode)

  # edge.neo4jSourceVertex.data
  # gotedge.neo4jSourceVertex.data


@test   json(edge.SourceVertex.packed) == json(gotedge.SourceVertex.packed)
@test   edge.SourceVertex.properties == gotedge.SourceVertex.properties
  #@test  edge.SourceVertex.bigData == gotedge.SourceVertex.bigData
@test   edge.SourceVertex.neo4jNodeId == gotedge.SourceVertex.neo4jNodeId
# @test   edge.SourceVertex.neo4jNode == gotedge.SourceVertex.neo4jNode
@test   edge.SourceVertex.isValidNeoNodeId == gotedge.SourceVertex.isValidNeoNodeId
# @test   edge.SourceVertex.exVertexId == gotedge.SourceVertex.exVertexId
@test   edge.SourceVertex.isValidExVertex == gotedge.SourceVertex.isValidExVertex

#failing here
# @test edge.SourceVertex == gotedge.SourceVertex
# @test edge.DestVertex == gotedge.DestVertex

# @test json(edge) == json(gotedge)
println("Success!")

print("[TEST] Finding all neighbors of a vertex...")
neighs = CloudGraphs.get_neighbors(cloudGraph, cloudVert1)
@test length(neighs) == 1
@test neighs[1].neo4jNodeId == cloudVert2.neo4jNodeId
println("Success!")

print("[TEST] Deleting an edge...")
CloudGraphs.delete_edge!(cloudGraph, edge)
neighs = CloudGraphs.get_neighbors(cloudGraph, cloudVert1)
@test length(neighs) == 0
@test edge.neo4jEdgeId == -1
@test edge.neo4jEdge == Void
println("Success!")
