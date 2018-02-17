# Setup everything using the common setup.
include("CloudGraphSetup.jl")

# And check that if we encode and decode this type, it's exactly the same.
# Make a packed data test structure.
fullType = DataTest(rand(10,10), "This is a test string", rand(Int32,10,10));
typePackedRegName = string(PackedDataTest);
typeOriginalRegName = string(DataTest);
# Now lets encode and decode to see.
println("Encoding...")
testPackedType = cloudGraph.packedOriginalDataTypes[typeOriginalRegName].encodingFunction(PackedDataTest, fullType);
println("Decoding...")
testFullType = cloudGraph.packedPackedDataTypes[typePackedRegName].decodingFunction(DataTest, testPackedType);
@test json(testFullType) == json(fullType)
println("Success!")

# Creating a local test graph.
print("[TEST] Creating a CloudVertex from an ExVertex...")
localGraph = graph(ExVertex[], ExEdge{ExVertex}[]);
#Make an ExVertex that may be encoded
v = make_vertex(localGraph, "TestVertex");
vertex = Graphs.add_vertex!(localGraph, v);
vertex.attributes["data"] = fullType;
vertex.attributes["age"] = 64;
vertex.attributes["latestEstimate"] = [0.0,0.0,0.0];
bigData = CloudGraphs.BigData();
testElementLegacy = CloudGraphs.BigDataElement("TestElement1", "Performance test dataset legacy.", rand(UInt8,100), -1); #Data element
testElementDict = CloudGraphs.BigDataElement("TestElement2", "Performance test dataset new dict type.", Dict{String, Any}("testString"=>"Test String", "randUint8"=>rand(UInt8,100)), -1); #Data element
append!(bigData.dataElements, [testElementLegacy, testElementDict]);
vertex.attributes["bigData"] = bigData;
# Now encoding the structure to CloudGraphs vertex
cloudVertex = CloudGraphs.exVertex2CloudVertex(vertex);
println("Success!");

print("[TEST] Adding a vertex...")
CloudGraphs.add_vertex!(cloudGraph, cloudVertex);
println("Success!")

# if !haskey(ENV, "TRAVIS_OS_NAME")
print("[TEST] Checking the big data is persisted...")
cloudVertexRet = CloudGraphs.get_vertex(cloudGraph, cloudVertex.neo4jNode.id, true) # fullType not required
@test length(cloudVertexRet.bigData.dataElements) == 2
@test cloudVertexRet.bigData.dataElements[1].data == cloudVertex.bigData.dataElements[1].data
@test json(cloudVertexRet.bigData.dataElements[2].data) == json(cloudVertex.bigData.dataElements[2].data)
@test cloudVertexRet.bigData.isRetrieved == true
println("Success!")
# else
#   print("[TEST] NOTE: Testing in Travis, skipping the Mongo bigData test for the moment...")
# end

print("[TEST] Testing update method...")
cloudVertexRet.bigData.dataElements[1].description = "Updated!"
cloudVertexRet.bigData.dataElements[1].data = zeros(UInt8,100)
update_vertex!(cloudGraph, cloudVertexRet, true)
cloudVertexRet2 = CloudGraphs.get_vertex(cloudGraph, cloudVertex.neo4jNode.id, true) # fullType not required
@test cloudVertexRet.bigData.dataElements[1].data != cloudVertex.bigData.dataElements[1].data
println("Success!")

print("[TEST] Testing delete method...")
delete_vertex!(cloudGraph, cloudVertex)
println("Success!")

print("[TEST] Checking that we get a representative error when big data can't be retrieved...")
cloudVertexRet.bigData.dataElements[1].id = "DoesntExist"
@test_throws ErrorException CloudGraphs.read_BigData!(cloudGraph, cloudVertexRet)
println("Success!")

# Saving an image as binary
fid = open(dirname(Base.source_path()) * "/IMG_1407.JPG","r")
imgBytes = read(fid)
close(fid)
