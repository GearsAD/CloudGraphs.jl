using Base: Test
# using FactCheck # to be deprecated
using Graphs
using ProtoBuf
using JSON
using CloudGraphs
using LibBSON

import Base: convert

# Have we loaded the library?
@test isdefined(:CloudGraphs) == true
@test typeof(CloudGraphs) == Module

function testgetfnctype(x...)
  @show x
  error("CloudGraphSetup.jl:testgetfnctype(x...)  not implemented yet")
end

# Creating a connection
@testset "[TEST] Connecting to the local CloudGraphs instance (Neo4j and Mongo)..." begin

configuration = CloudGraphs.CloudGraphConfiguration("localhost", 7474, "neo4j", "marine", "localhost", 27017, false, "", "");
# TODO replicate IIF.encodePackedType
cloudGraph = connect(configuration, encodePackedType, getpackedtype, decodePackedType);
# cloudGraph = connect(configuration, IncrementalInference.encodePackedType, Caesar.getpackedtype, IncrementalInference.decodePackedType);
println("Success!");

end

# Testing type registration
mutable struct DataTest
  matrix::Array{Float64, 2}
  string::AbstractString #ASCIIString
  boolmatrix::Array{Int32,2}
  DataTest() = new()
  DataTest(m,s,b) = new(m,s,b)
end
mutable struct PackedDataTest
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

function convert(::Type{PackedDataTest}, d::DataTest) # encoder
  return PackedDataTest(d)
end
function convert(T::Type{DataTest}, d::PackedDataTest) # decoder
  r1 = d.matrows
  c1 = floor(Int,length(d.vecmat)/r1)
  M1 = reshape(d.vecmat,r1,c1)
  r2 = d.matrows
  c2 = floor(Int,length(d.boolvecmat)/r2)
  M2 = reshape(d.boolvecmat,r2,c2)
  return DataTest(M1,d.string,M2)
end

# println("[TEST] Registering a packed type and testing the Protobuf encoding/decoding...");
# Let's register a packed type.
# CloudGraphs.registerPackedType!(cloudGraph, DataTest, PackedDataTest, encodingConverter=convert, decodingConverter=convert);
# println("Registered types = $(cloudGraph.packedPackedDataTypes)");
# println("Registered types = $(cloudGraph.packedOriginalDataTypes)");
# @test length(cloudGraph.packedPackedDataTypes) > 0
# @test length(cloudGraph.packedOriginalDataTypes) > 0
