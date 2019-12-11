from google.cloud import datastore
import sys
args = sys.argv
kind = args[1]
batch_size = 400

client = datastore.Client()

#key = client.key(kind)
#entity = datastore.Entity(key)
#client.put(entity)

#query = client.query(kind=kind)
#print(list(query.fetch()))


while True:
  query = client.query(kind=kind)
  query.keys_only()
  keys = list([entity.key for entity in query.fetch(limit=50000)])
  if len(keys) == 0:
    break
  
  key_chunks = [keys[i:i + batch_size] for i in range(0, len(keys), batch_size)]
  for kcs in key_chunks:
      print("delete chunk")
      client.delete_multi(keys=kcs)
  
  print("delete entities of " + str(len(keys)))
  
query = client.query(kind=kind)
print(list(query.fetch()))
