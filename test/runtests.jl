using CloudGraphs
using Test

@test isdefined(:CloudGraphs)
@test typeof(CloudGraphs) == Module

#include("QuickPackProtoTest.jl")

include("CloudGraphs.jl")

# Big data tests
if !haskey(ENV, "TRAVIS_OS_NAME")
    include("BigData.jl")
else
  print("[TEST] NOTE: Testing in Travis, skipping the Mongo bigData test for the moment...")
end

# Return the true exit status from FactCheck
# FactCheck.exitstatus()
