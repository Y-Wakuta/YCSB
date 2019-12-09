#!/bin/bash

set -e

## localhost
project_id=dummy
instance_id=dummydummy
credential=dummy

## gcp
#project_id=<project_id>
#instance_id=<instance_id>
#credential=<credential>

table=usertable
cf=cf
dir="./result_bigtable"
workload_name=workload_10_contents
workload=workloads/$workload_name

## install cbt
#gcloud components update
#gcloud components install cbt

## setup bigtable
#gcloud beta emulators bigtable start &
#sleep 5
#$(gcloud beta emulators bigtable env-init)
 
function bench_bigtable(){
  threads=$1
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
cbt -project $project_id -instance $instance_id -creds $credential createfamily $table $cf | echo
bench_bigtable 2
bench_bigtable 4
bench_bigtable 8
