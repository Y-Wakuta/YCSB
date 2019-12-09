#!/bin/bash

set -e

## localhost
#project_id=dummy
#instance_id=dummydummy
#credential=dummy

## gcp
project_id=m3-ai-team-dev
instance_id=<instance_id>
credential=$GOOGLE_APPLICATION_CREDENTIALS

table=usertable
cf=cf
dir="./result_bigtable"
workload_name_10_100k=workload_10_contents_100k_ops
workload_name_10_300k=workload_10_contents_300k_ops
workload_name_30_100k=workload_30_contents_100k_ops
workload_name_30_300k=workload_30_contents_300k_ops

## install cbt
#gcloud components update
#gcloud components install cbt

## setup bigtable
#gcloud beta emulators bigtable start &
#sleep 5
#$(gcloud beta emulators bigtable env-init)
 
function bench_bigtable(){
  threads=$1
  workload_name=$2
  workload=workloads/$workload_name
  file="$dir/bench_bigtable_result_${workload_name}_$threads.txt"

  cbt -project $project_id -instance $instance_id -creds $credential deletefamily $table $cf 
  cbt -project $project_id -instance $instance_id -creds $credential createfamily $table $cf 
  sleep 15

  echo "=loading======================================" > $file
  ./bin/ycsb load googlebigtable -p columnfamily=$cf -p google.bigtable.project.id=$project_id -p google.bigtable.instance.id=$instance_id -P $workload -threads $threads >> $file
  
  echo "=running======================================" >> $file
  ./bin/ycsb run googlebigtable -p columnfamily=$cf -p google.bigtable.project.id=$project_id -p google.bigtable.instance.id=$instance_id -P $workload -threads $threads >> $file
}

rm -rf $dir
mkdir $dir
#cbt -project $project_id -instance $instance_id -creds $credential deletetable $table
cbt -project $project_id -instance $instance_id -creds $credential createtable $table
cbt -project $project_id -instance $instance_id -creds $credential createfamily $table $cf 

function bench_for_workload(){
  workload_name=$1
  bench_bigtable 2 $workload_name
  bench_bigtable 4 $workload_name
  bench_bigtable 8 $workload_name
}

bench_for_workload $workload_name_10_100k
bench_for_workload $workload_name_10_300k
bench_for_workload $workload_name_30_100k
bench_for_workload $workload_name_30_300k


