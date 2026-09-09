#!/usr/bin/env bash

###########################
### tipos de loop While ###
###########################
# contador=20
# while [$contador -lt 10]; do
#   echo O valor do contador=$contador
#   ((contador = contador + 1))
# done

_INPUT_STRING="Olá"
# while [[ "$_INPUT_STRING" != "tchau" ]]; do
#   echo "Você deseja ficar aqui ?"
#   read _INPUT_STRING

#   if [[ $_INPUT_STRING == 'tchau' ]]; then
#     echo "Você disse Tchau"
#   else
#     echo "Você ainda deseja ficar aqui"
#   fi
# done

==================================================
while :; do
  echo "Você deseja ficar aqui ?"
  read _INPUT_STRING

  if [[ $_INPUT_STRING != 'tchau' ]]; then
    continue
  else
    break
    # exit 0
  fi
done
