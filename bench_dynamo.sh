#!/bin/bash

set -e

# run dynamodb
# java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar -sharedDb
#host=http://localhost:8000
host=https://dynamodb.ap-northeast-1.amazonaws.com

property_file=./dynamodb/conf/dynamodb.properties
table=usertable
workload_name=workload_10_contents
workload=workloads/$workload_name
dir=result_dynamo

function bench_dynamo(){
  sleep 15
  threads=$1
  file=$dir/bench_dynamo_result_${workload_name}_$threads.txt
  echo "= evaluation in $threads"
  echo "= setup db ======================================"
  aws dynamodb delete-table --table-name $table --endpoint-url $host
  sleep 5
  aws dynamodb list-tables --endpoint-url $host
  aws dynamodb create-table --table-name $table --attribute-definitions AttributeName=firstname,AttributeType=S --key-schema AttributeName=firstname,KeyType=HASH --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 --endpoint-url $host
  
  echo "=loading======================================" > $file
  ./bin/ycsb load dynamodb -P $workload -P $property_file -threads $threads >> $file
  echo "=running======================================" >> $file
  ./bin/ycsb run dynamodb -P $workload -P $property_file -threads $threads >> $file
}

mkdir -p $dir
#aws dynamodb create-table --table-name $table --attribute-definitions AttributeName=firstname,AttributeType=S --key-schema AttributeName=firstname,KeyType=HASH --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 --endpoint-url $host
bench_dynamo 2
bench_dynamo 4
bench_dynamo 8
