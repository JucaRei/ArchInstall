#!/usr/bin/env bash

###########################
### tipos de loop Until ###
###########################
contador=20
until [$contador -lt 10]; do
  echo contador $contador
  let contador-=1
done
