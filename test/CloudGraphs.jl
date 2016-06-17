using Base.Test;
using Graphs;
using ProtoBuf;
using JSON;
using CloudGraphs;
# For a representative packed structure

# Creating a connection
configuration = CloudGraphs.CloudGraphConfiguration("localhost", 7474, false, "", "", "localhost", 27017, false, "", "");
cloudGraph = connect(configuration);

# Testing type registration
type DataTest
  matrix::Array{Float64, 2}
  string::ASCIIString
  boolmatrix::BitArray{2}
  DataTest() = new()
  DataTest(m,s,b) = new(m,s,b)
end
type PackedDataTest
  vecmat::Vector{Float64}
  matrows::Int64
  string::ASCIIString
  boolvecmat::BitArray{1}
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
# Let's register a packed type.
CloudGraph.registerPackedType!(cloudGraph, PackedDataTest, encoder, decoder);
# And check that if we encode and decode this type, it's exactly the same.
# Make a packed data test structure.
fullType = DataTest(rand(10,10), "This is a test string", trues(10,10));
typeRegName = string(typeof(fullType));
# Now lets encode and decode to see.
testPackedType = cloudGraph.packedDataTypes[typeRegName].encodingFunction(fullType);
testFullType = cloudGraph.packedDataTypes[typeRegName].decodingFunction(testPackedType);
@test json(testFullType) == json(fullType)

# Creating a local test graph.
# localGraph = graph(ExVertex[], ExEdge{ExVertex}[]);
#Make an ExVertex that may be encoded
# v = make_vertex(localGraph, "TestVertex");
# vertex = Graphs.add_vertex!(localGraph, v);
# vertex.attributes["packed"] = fullType;
# vertex.attributes["age"] = 64;
# vertex.attributes["latestEstimate"] = [0.0,0.0,0.0];
# bigData = CloudGraphs.BigData(true, true, false, rand(10, 10, 10));
# vertex.attributes["bigData"] = bigData;

# Now encoding the structure to CloudGraphs vertex
# cloudVertex = CloudGraphs.exVertex2CloudVertex(vertex);

# CloudGraphs.add_vertex!(cloudGraph, cloudVertex);

# Get the node from Neo4j.
# cloudVertexRet = CloudGraphs.get_vertex(cloudGraph, cloudVertex.neo4jNode.id, packed, false)
# Check that all the important bits match using string comparisons of the JSON form of the structures
# @test json(cloudVertex.packed) == json(cloudVertexRet.packed)
#@test json(cloudVertex.bigData) == json(cloudVertexRet.bigData)
# @test json(cloudVertex.properties) == json(cloudVertexRet.properties)
# @test cloudVertex.neo4jNodeId == cloudVertexRet.neo4jNodeId
# @test json(cloudVertex.neo4jNode) == json(cloudVertexRet.neo4jNode)
