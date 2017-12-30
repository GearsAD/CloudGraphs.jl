#Functions
export save_BigData!, read_BigData!, update_NeoBigData!, read_MongoData

include("CommonStructs.jl")

# --- Internal utility methods ---

"""
    _saveBigDataElement!(cg, vertex, bDE)

Insert or update the actual data payload into Mongo as required. Does not update Neo4j.
"""
function _saveBigDataElement!(cg::CloudGraph, bDE::BigDataElement)::Void
  saveTime = string(Dates.now(Dates.UTC));

  #Check if the key exists...
  isNew = true;
  if(bDE.id != "")
    numNodes = count(cg.mongo.cgBindataCollection, ("cgId" => bDE.id)); #NOT the oid, this is another indexable list
    isNew = numNodes == 0;
  end
  if(isNew)
    # @show "Writing big data $(bDE.data)"
    # Insert the node
    m_oid = insert(cg.mongo.cgBindataCollection, ("cgId" =>  bDE.id, "sourceName" => bDE.sourceName, "description" => bDE.description, "data" => bDE.data, "mimeType" => bDE.mimeType, "neoNodeId" => bDE.neoNodeId, "lastSavedTimestamp" => saveTime))
    info("Inserted big data to mongo id = $(m_oid) for cgId = $bDE.id")
  else
    # Update the node
    m_oid = update(cg.mongo.cgBindataCollection, ("cgId" => bDE.id), set("sourceName" => bDE.sourceName, "description" => bDE.description, "data" => bDE.data, "mimeType" => bDE.mimeType, "neoNodeId" => bDE.neoNodeId, "lastSavedTimestamp" => saveTime))
    info("Updated big data to mongo id (result=$(m_oid)) (key $(bDE.id))")
  end
  return(nothing)
end

"""
    update_NeoBigData!(cg, vertex)

Update the bigData dictionary elements in Neo4j. Does not insert or read from Mongo.
"""
function update_NeoBigData!(cg::CloudGraph, vertex::CloudVertex)::Void
  savedSets = Vector{savedSets = BigDataRawType}();
  for elem in vertex.bigData.dataElements
    # keep big data separate during Neo4j updates and remerge at end
    push!(savedSets, elem.data);
    elem.data = Dict{String, Any}();
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
  return(nothing)
end

function save_BigData!(cg::CloudGraph, vertex::CloudVertex)::Void
  #Write to Mongo
  for bDE in vertex.bigData.dataElements
    _saveBigDataElement!(cg, bDE);
  end

  #Now update the Neo4j node.
  update_NeoBigData!(cg, vertex)
  return(nothing)
end

function read_MongoData(cg::CloudGraph, id::String)::BigDataRawType
  numNodes = count(cg.mongo.cgBindataCollection, ("cgId" => id));
  if(numNodes != 1)
      error("The query for $(id) returned $(numNodes) values, expected 1 result for this element!");
  end
  results = first(find(cg.mongo.cgBindataCollection, ("cgId" => id)))
  #Have it, now parse it until we have a native binary or dictionary datatype.
  # If new type, convert back to dictionary
  if(typeof(results["data"]) == BSONObject)
    testOutput = dict(results["data"]);
    return convert(Dict{String, Any}, testOutput) #From {Any, Any} to a more comfortable stronger type
  else
    return results["data"];
  end
end

function read_BigData!(cg::CloudGraph, vertex::CloudVertex)::BigData
  if(vertex.bigData.isExistingOnServer == false)
    error("The data does not exist on the server. 'isExistingOnServer' is false. Have you saved with set_BigData!()");
  end
  for bDE in vertex.bigData.dataElements
      #TODO: Handle the different source types.
      bDE.data = read_MongoData(cg, bDE.id)
  end
  vertex.bigData.isRetrieved = true
  return(vertex.bigData)
end

function delete_BigData!(cg::CloudGraph, vertex::CloudVertex)::Void
  if(vertex.bigData.isExistingOnServer == false)
    error("The data does not exist on the server. 'isExistingOnServer' is false. Have you saved with set_BigData!()");
  end
  # Update structure now so if it fails midway and we save again it still writes a new set of keys.
  vertex.bigData.isExistingOnServer = false
  # Delete the data.
  for bDE in vertex.bigData.dataElements
    numNodes = count(cg.mongo.cgBindataCollection, ("cgId" => bDE.id));
    info("delete_BigData! - The query for $(mongoId) returned $(numNodes) value(s).");
    if(numNodes > 0)
      delete(cg.mongo.cgBindataCollection, ("cgId" => bDE.id));
    end
  end
  return(nothing)
end
