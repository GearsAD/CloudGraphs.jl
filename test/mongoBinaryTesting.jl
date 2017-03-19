using Base.Test
using Mongo

# Setup everything.
include("CloudGraphSetup.jl")


# function localscope(N=1000000)
data = ("testId" => Array(UInt8, 10), "description" => "DESCRIPTION")
# Use this for image. ObjectId("58af67255d7625647859fa71") THIS KEY :)
@time m_oid = insert(cloudGraph.mongo.cgBindataCollection, data)

myFavouriteKey = first(find(cloudGraph.mongo.cgBindataCollection, ("_id" => eq(m_oid))));
