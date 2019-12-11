#!/bin/bash

set -e

host=https://dynamodb.ap-northeast-1.amazonaws.com
threads=100
property_file=./dynamodb/conf/dynamodb.properties
table=usertable
dir='result_dynamo_100_threads_12_11'

function bench_dynamo(){
  sleep 15
  workload_name=$1
  workload=workloads/$workload_name
  file=$dir/bench_dynamo_result_${workload_name}_$threads.txt
  echo "= evaluation in $threads"
  echo "= setup db ======================================"
  aws dynamodb delete-table --table-name $table --endpoint-url $host
  aws dynamodb list-tables --endpoint-url $host
  aws dynamodb create-table --table-name $table --attribute-definitions AttributeName=firstname,AttributeType=S --key-schema AttributeName=firstname,KeyType=HASH --billing-mode=PAY_PER_REQUEST --endpoint-url $host
  aws dynamodb list-tables --endpoint-url $host
  sleep 30
  
  echo "=loading======================================" > $file
  ./bin/ycsb load dynamodb -P $workload -P $property_file -threads $threads >> $file 2>&1
  sleep 30
  echo "=running======================================" >> $file
  ./bin/ycsb run dynamodb -P $workload -P $property_file -threads $threads >> $file 2>&1
}

mkdir -p $dir
bench_dynamo workload_10_contents_100k_ops
bench_dynamo workload_10_contents_300k_ops
bench_dynamo workload_30_contents_100k_ops
bench_dynamo workload_30_contents_300k_ops