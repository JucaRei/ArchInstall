#!/usr/bin/env bash

#########################
### tipos de loop FOR ###
#########################

##########################################
# for ((i = 0; i < 10; i++)); do
#   echo $i
# done

for runlevel in 0 1 2 3 4; do
  mkdir rc${runlevel}.d
  # rm -r rc${runlevel}.d
  echo $runlevel
done

##########################################
# for i in {2..8}; do
#   echo $i
# done

for runlevel in {0..4}; do
  # mkdir rc${runlevel}.d
  rm -r rc${runlevel}.d
  echo $runlevel
done

##########################################
# for i in $(seq 2 8); do
#   echo $i
# done

for runlevel in $(seq 0 4); do
  mkdir rc${runlevel}.d
  echo $runlevel
done

for runlevel in $(seq 0 4); do
  rm -r rc${runlevel}.d
  echo $runlevel
done
