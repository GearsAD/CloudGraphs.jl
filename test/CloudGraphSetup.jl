using Base.Test;
using Graphs;
using ProtoBuf;
using JSON;
using CloudGraphs;

# Have we loaded the library?
@test isdefined(:CloudGraphs) == true
@test typeof(CloudGraphs) == Module

# Creating a connection
print("[TEST] Connecting to the local CloudGraphs instance (Neo4j and Mongo)...");
configuration = CloudGraphs.CloudGraphConfiguration("localhost", 7474, "neo4j", "neo5j", "localhost", 27017, false, "", "");
cloudGraph = connect(configuration);
println("Success!");

# Testing type registration
type DataTest
  matrix::Array{Float64, 2}
  string::AbstractString #ASCIIString
  boolmatrix::Array{Int32,2}
  DataTest() = new()
  DataTest(m,s,b) = new(m,s,b)
end
type PackedDataTest
  vecmat::Vector{Float64}
  matrows::Int64
  string::AbstractString #ASCIIString
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

function encoder(::Type{PackedDataTest}, d::DataTest)
  return PackedDataTest(d)
end
function decoder(T::Type{DataTest}, d::PackedDataTest)
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
