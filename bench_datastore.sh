#!/bin/bash

set -e

workload_name_10_100k=workload_10_contents_100k_ops
workload_name_10_300k=workload_10_contents_300k_ops
workload_name_30_100k=workload_30_contents_100k_ops
workload_name_30_300k=workload_30_contents_300k_ops
warm_up_workload_name=workload_10_contents_splitted

dir="./result_datastore_mode_with_warmup"

function warmup(){
   warm_up_workload=workloads/$1
   echo "warmup 1======================================"
  ./bin/ycsb load googledatastore -P $warm_up_workload -P ../googledatastore.properties
  sleep 150
   echo "warmup 2======================================"
  ./bin/ycsb load googledatastore -P $warm_up_workload -P ../googledatastore.properties
  sleep 150
   echo "warmup 3======================================"
  ./bin/ycsb load googledatastore -P $warm_up_workload -P ../googledatastore.properties -threads 2
  sleep 150
   echo "warmup 4======================================"
  ./bin/ycsb load googledatastore -P $warm_up_workload -P ../googledatastore.properties -threads 4
  sleep 150
   echo "warmup 5======================================"
  ./bin/ycsb load googledatastore -P $warm_up_workload -P ../googledatastore.properties -threads 8
  sleep 150
  ./bin/ycsb load googledatastore -P $warm_up_workload -P ../googledatastore.properties -threads 8
  sleep 150
}

function bench_datastore(){
  threads=$1
  workload_name=$2
  workload=workloads/$workload_name
  file=$dir/bench_datastore_result_${workload_name}_$threads.txt
  
  mkdir -p $dir
  #echo "clear entities"
  #python3 delete_kind.py usertable
  #sleep 30
  
  echo "=loading======================================" > $file
  ./bin/ycsb load googledatastore -P $workload -P ../googledatastore.properties -threads $threads >> $file 2>&1
  
  sleep 30
  echo "=running======================================" >> $file
  ./bin/ycsb run googledatastore -P $workload -P ../googledatastore.properties -threads $threads >> $file 2>&1
}

function bench_for_workload(){
  workload_name=$1
  bench_datastore 2 $workload_name
  bench_datastore 4 $workload_name
  bench_datastore 8 $workload_name
}

warmup $warm_up_workload_name
echo "= warmup done ================================================"
bench_for_workload $workload_name_10_100k
bench_for_workload $workload_name_10_300k
bench_for_workload $workload_name_30_100k
bench_for_workload $workload_name_30_300k
