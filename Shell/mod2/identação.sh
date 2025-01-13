#!/usr/bin/env bash

PARAMETRO=1

if [ $PARAMETRO -gt 0 ]
then
  if [ $PARAMETRO -gt 1 ] # Valida numero 1?
  then
    if [ $PARAMETRO -gt 2 ]
    then
      echo "oi"
    fi
  fi
fi
