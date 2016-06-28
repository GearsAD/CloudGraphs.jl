using CloudGraphs
using Base.Test

@test isdefined(:CloudGraphs) == true
@test typeof(CloudGraphs) == Module

include("QuickPackProtoTest.jl")

include("CloudGraphs.jl")
