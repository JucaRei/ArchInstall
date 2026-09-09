#!/usr/bin/env bash

# Variáveis Globais em maiusculo
NOME="Reinaldo
Ponce
Jr" # string sempre com aspas

NUMERO_1=25
NUMERO_2=44
TOTAL=$((NUMERO_1 + NUMERO_2)) # Calculo sempre cifrão $ e dois parenteses (())

echo "$NOME" # variavel sempre com aspas
echo $TOTAL

SAIDA_CAT="$(cat /etc/passwd | grep juca)"
echo "$SAIDA_CAT"

echo "--------------------------------------------------------------------------"

echo "Parâmetro 1: $1"
echo "Parâmetro 2: $2"

echo "Todos os Parâmetros: $@"
echo "Todos os Parâmetros: $*"

echo "Quantos Parâmetros? $#"

echo "Saída do ultimo comando: $?" # 0 = foi executado, 1 = erro

echo "PID: $$" # cada vez executado ele cria um novo PID, aqui ele mostra o numero do PID criado

echo $0 # buscar o nome do script que está executando
