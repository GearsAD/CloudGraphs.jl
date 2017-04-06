using LibBSON, Mongo
test = Dict("t" => "a Value", "a" => 5.1)
mongoClient = Mongo.MongoClient("localhost", 27017)
mcoll = Mongo.MongoCollection(mongoClient, "CloudGraphs", "test");
mongoId = insert(mcoll, ("neoNodeId" => 0, "val" => test, "description" => "bDE.description", "lastSavedTimestamp" => "saveTime"))
results = first(find(mcoll, ("_id" => eq(mongoId))));
output = dict(results)
@show output
