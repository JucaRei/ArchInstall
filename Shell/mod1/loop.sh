#!/usr/bin/env bash

echo "====== For 1"

for (( i = 0; i < 10; i++ )); do
  echo $i
done

# for (( i = 1; i <= 10; i++ )); do
#   echo $i
# done

echo "====== For 2 (seq)"
for i in $(seq 10); do
  echo $i
done


echo "====== For 3 (array)"
Frutas=(
'Laranja'
'Ameixa'
'Abacaxi'
'Melancia'
'Jabuticaba'
)
for i in "${Frutas[@]}"; do   # @ todo o array;  [0] pega o item na posição 0 do array
  echo "$i"
done

echo "====== While"
contador=0
while [[ $contador -lt ${#Frutas[@]} ]]; do
  # echo "$contador:" "$Frutas"
  echo "$contador:"
  contador=$(($contador + 1))
  # Frutas=$(($Frutas + 1))
done
