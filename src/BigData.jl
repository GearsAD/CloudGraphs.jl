
export BigData, BigDataElement
#Functions
export save_BigData!, read_BigData!, update_NeoBigData!, read_MongoData

# Type aliases
BigDataRawType = Union{Vector{UInt8}, Dict{String, Any}}

type BigDataElement
    id::String
    sourceName::String
    description::String
    data::BigDataRawType
    mimeType::String
    neoNodeId::Int
    lastSavedTimestamp::String #UTC DateTime.
    BigDataElement(sourceName::String, desc::String, data::BigDataRawType, neoNodeId::Int; id::String=string(Base.Random.uuid4()), mimeType::String="application/octet-stream", lastSavedTimestamp::String=string(now(Dates.UTC))) = new(key, sourceName, desc, data, neoNodeId, mimeType, lastSavedTimestamp)
    BigDataElement{T <: String}(dd::Dict{T,Any}) = new(dd["id"], dd["sourceName"], dd["description"], dd["data"], dd["mimeType"], dd["neoNodeId"], dd["lastSavedTimestamp"])
end

type BigData
  isRetrieved::Bool
  isAvailable::Bool
  isExistingOnServer::Bool
  lastSavedTimestamp::AbstractString #UTC DateTime.
  dataElements::Vector{BigDataElement}
  # This is just for local use, and is not saved directly into the graph.
  BigData() = new(false, false, false, "[N/A]", Vector{BigDataElement}())
  BigData(isRetrieved::Bool, isAvailable::Bool, isExistingOnServer::Bool, lastSavedTimestamp::AbstractString, data::Vector{BigDataElement}) = new(isRetrieved, isAvailable, isExistingOnServer, lastSavedTimestamp, data)
  BigData(str::AbstractString) = begin
      dd = JSON.parse(str)
      bDE = BigDataElement[]
      for (k,v) in dd["dataElements"]
         push!( bDE, BigDataElement(v[1],Vector{UInt8}(),v[2]) )
      end
      new(dd["isRetrieved"],dd["isAvailable"],dd["isExistingOnServer"],dd["lastSavedTimestamp"], bDE)
    end
end

# --- Internal utility methods ---

function _validateBigDataElementTypes(bDE::BigDataElement)
end

"""
    \_saveBigDataElement!(cg, vertex, bDE)

Insert or update the actual data payload into Mongo as required. Does not update Neo4j.
"""
function _saveBigDataElement!(cg::CloudGraph, vertex::CloudVertex, bDE::BigDataElement)
  saveTime = string(Dates.now(Dates.UTC));

  #Check if the key exists...
  isNew = true;
  if(bDE.key != "")
    numNodes = count(cg.mongo.cgBindataCollection, ("cgId" => BSONOID(bDE.id))); #NOT the oid, this is another indexable list
    isNew = numNodes == 0;
  end
  if(isNew)
    # @show "Writing big data $(bDE.data)"
    # Insert the node
    m_oid = insert(cg.mongo.cgBindataCollection, ("cgId" => bDE.id, "neoNodeId" => vertex.neo4jNodeId, "val" => bDE.data, "description" => bDE.description, "lastSavedTimestamp" => saveTime))
    @show "Inserted big data to mongo id = $(m_oid)"
    #Update local instance
    bDE.key = string(m_oid);
  else
    # Update the node
    m_oid = update(cg.mongo.cgBindataCollection, ("_id" => BSONOID(bDE.key)), set("neoNodeId" => vertex.neo4jNodeId, "val" => bDE.data, "description" => bDE.description, "lastSavedTimestamp" => saveTime))
    @show "Updated big data to mongo id (result=$(m_oid)) (key $(bDE.key))"
  end
end

"""
    update_NeoBigData!(cg, vertex)

Update the bigData dictionary elements in Neo4j. Does not insert or read from Mongo.
"""
function update_NeoBigData!(cg::CloudGraph, vertex::CloudVertex)
  savedSets = Vector{savedSets = Union{Vector{UInt8}, Dict{AbstractString, Any}}}();
  for elem in vertex.bigData.dataElements
    # keep big data separate during Neo4j updates and remerge at end
    push!(savedSets, elem.data);
    elem.data = Dict{AbstractString, Any}();
  end
  vertex.bigData.isExistingOnServer = true;
  vertex.bigData.lastSavedTimestamp = string(Dates.now(Dates.UTC));

  # Get the json bigData prop.
  bdProp = json(vertex.bigData);
  # Now put the data back
  i = 0;
  for elem in vertex.bigData.dataElements
    i += 1;
    elem.data = savedSets[i];
  end

  #Update the bigdata property
  setnodeproperty(vertex.neo4jNode, "bigData", bdProp);
end

function save_BigData!(cg::CloudGraph, vertex::CloudVertex)
  #Write to Mongo
  for bDE in vertex.bigData.dataElements
    _saveBigDataElement!(cg, vertex, bDE);
  end

  #Now update the Neo4j node.
  update_NeoBigData!(cg, vertex)
end

function read_MongoData(cg::CloudGraph, key::AbstractString)
  mongoId = BSONOID(key);
  numNodes = count(cg.mongo.cgBindataCollection, ("_id" => eq(mongoId)));
  if(numNodes != 1)
    error("The query for $(mongoId) returned $(numNodes) values, expected 1 result for this element!");
  end
  findres = find(cg.mongo.cgBindataCollection, ("_id" => eq(mongoId)))
  results = first(findres)
  #Have it, now parse it until we have a native binary or dictionary datatype.
  # If new type, convert back to dictionary
  data = []
  if(typeof(results["val"]) == BSONObject)
    testOutput = dict(results["val"]);
    data = convert(Dict{AbstractString, Any}, testOutput) #From {Any, Any} to a more comfortable stronger type
  else
    data = results["val"];
  end
  return data
end

function read_BigData!(cg::CloudGraph, vertex::CloudVertex)
  if(vertex.bigData.isExistingOnServer == false)
    error("The data does not exist on the server. 'isExistingOnServer' is false. Have you saved with set_BigData!()");
  end
  for bDE in vertex.bigData.dataElements
    bDE.data = read_MongoData(cg, bDE.key)
  end
  return(vertex.bigData)
end

function delete_BigData!(cg::CloudGraph, vertex::CloudVertex)
  if(vertex.bigData.isExistingOnServer == false)
    error("The data does not exist on the server. 'isExistingOnServer' is false. Have you saved with set_BigData!()");
  end
  # Update structure now so if it fails midway and we save again it still writes a new set of keys.
  vertex.bigData.isExistingOnServer = false
  # Delete the data.
  for bDE in vertex.bigData.dataElements
    mongoId = BSONOID(bDE.key);
    numNodes = count(cg.mongo.cgBindataCollection, ("_id" => eq(mongoId)));
    info("delete_BigData! - The query for $(mongoId) returned $(numNodes) value(s).");
    if(numNodes > 0)
      delete(cg.mongo.cgBindataCollection, ("_id" => eq(mongoId)));
    end
  end
end
