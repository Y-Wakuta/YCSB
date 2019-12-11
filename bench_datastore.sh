#!/bin/bash

set -e

workload_name_10_100k=workload_10_contents_100k_ops
workload_name_10_300k=workload_10_contents_300k_ops
workload_name_30_100k=workload_30_contents_100k_ops
workload_name_30_300k=workload_30_contents_300k_ops
warm_up_workload_name=workload_10_contents_splitted

dir="./result_datastore_100_threads_12_11"
threads=100

function bench_datastore(){
  workload_name=$1
  workload=workloads/$workload_name
  file=$dir/bench_datastore_result_${workload_name}_$threads.txt
  
  mkdir -p $dir
  echo "clear entities"
  python3 delete_kind.py usertable
  sleep 30
  
  echo "=loading======================================" > $file
  ./bin/ycsb load googledatastore -P $workload -P ../googledatastore.properties -threads $threads >> $file 2>&1
  
  sleep 10
  echo "=running======================================" >> $file
  ./bin/ycsb run googledatastore -P $workload -P ../googledatastore.properties -threads $threads >> $file 2>&1
}

function bench_for_workload(){
  workload_name=$1
  bench_datastore $workload_name
}

bench_for_workload $workload_name_10_100k
bench_for_workload $workload_name_10_300k
bench_for_workload $workload_name_30_100k
bench_for_workload $workload_name_30_300k
