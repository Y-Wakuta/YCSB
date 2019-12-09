#!/bin/bash

set -e

workload_name=workload_10_contents
#workload_name=workloads/workload_30_contents
workload=workloads/$workload_name
threads=2
dir="./result_datastore"
w=`echo $workload  | tr -s '/' ' '`
echo $w
file=$dir/bench_datastore_result_${workload_name}_$threads.txt

mkdir -p $dir

echo "=loading======================================" > $file
./bin/ycsb load googledatastore -P $workload -P ../googledatastore.properties -threads $threads >> $file

echo "=running======================================" >> $file
./bin/ycsb run googledatastore -P $workload -P ../googledatastore.properties -threads $threads >> $file
