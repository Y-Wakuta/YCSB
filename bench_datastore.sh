#!/bin/bash

set -e

workload_name_10_100k=workload_10_contents_100k_ops
workload_name_10_300k=workload_10_contents_300k_ops
workload_name_30_100k=workload_30_contents_100k_ops
workload_name_30_300k=workload_30_contents_300k_ops
dir="./result_datastore"

function bench_bigtable(){
  threads=$1
  workload_name=$2
  workload=workloads/$workload_name
  file=$dir/bench_datastore_result_${workload_name}_$threads.txt
  
  mkdir -p $dir
  echo "clear entities"
  python3 delete_kind.py
  sleep 15
  
  echo "=loading======================================" > $file
  ./bin/ycsb load googledatastore -P $workload -P ../googledatastore.properties -threads $threads >> $file
  
  echo "=running======================================" >> $file
  ./bin/ycsb run googledatastore -P $workload -P ../googledatastore.properties -threads $threads >> $file
}

function bench_for_workload(){
  workload_name=$1
  bench_datastore 2 $workload_name
  bench_datastore 4 $workload_name
  bench_datastore 8 $workload_name
}

bench_for_workload $workload_name_10_100k
bench_for_workload $workload_name_10_300k
bench_for_workload $workload_name_30_100k
bench_for_workload $workload_name_30_300k
