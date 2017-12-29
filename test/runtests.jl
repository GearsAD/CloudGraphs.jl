using CloudGraphs
using Base.Test

@test isdefined(:CloudGraphs) == true
@test typeof(CloudGraphs) == Module

#include("QuickPackProtoTest.jl")

include("CloudGraphs.jl")

# Big data tests
if !haskey(ENV, "TRAVIS_OS_NAME")
    include("BigData.jl")
else
  print("[TEST] NOTE: Testing in Travis, skipping the Mongo bigData test for the moment...")
end
