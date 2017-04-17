using Base.Test
using Mongo
using LibBSON

# Setup everything.
include("CloudGraphSetupLiljon.jl")


# function localscope(N=1000000)
# data = ("testId" => Array(UInt8, 10), "description" => "DESCRIPTION")
# Use this for image. ObjectId("58af67255d7625647859fa71") THIS KEY :)
# @time m_oid = insert(cloudGraph.mongo.cgBindataCollection, data)

myImageKey = first(find(cloudGraph.mongo.cgBindataCollection, ("_id" => eq(BSONOID("58af67255d7625647859fa71")))));

# Write to drive
fOut = open("/home/gearsad/test.png", "w")
write(myImageKey["val"])
fOut.close()
