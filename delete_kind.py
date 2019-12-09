from google.cloud import datastore
import sys
args = sys.argv
kind = args[1]

client = datastore.Client()
query = client.query(kind=kind)
query.keys_only()
keys = list([entity.key for entity in query.fetch()])
client.delete_multi(keys=keys)
print("delete entities of " + kind)

query = client.query(kind=kind)
print(list(query.fetch()))
