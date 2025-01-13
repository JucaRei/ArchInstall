#!/usr/bin/env bash

##############################
### Estruturas de Condição ###
##############################

MinhaFuncao() {
  variavel=$1
  if test "$variavel" -gt 10; then
    echo "é maior que 10"
  elif test "$variavel" -eq 10; then
    echo "é igual à 10"
  else
    echo "é menor que 10"
  fi
}
MinhaFuncao $1

# ./condicional 3
# ./condicional 10
# ./condicional 19

# Substituir o test pelo []
MinhaFuncao2() {
  variavel=$1
  if [ "$variavel" -gt 10 ]; then
    echo "é maior que 10"
  elif [ "$variavel" -eq 10 ]; then
    echo "é igual à 10"
  else
    echo "é menor que 10"
  fi
}
MinhaFuncao2 $1

# Substituir o test pelo [[]], também funciona, o mais recomendado
# supressão maior
MinhaFuncao3() {
  variavel=$1
  if [[ "$variavel" -gt 10 ]]; then
    echo "é maior que 10"
  elif [[ "$variavel" -eq 10 ]]; then
    echo "é igual à 10"
  else
    echo "é menor que 10"
  fi
}
MinhaFuncao3 $1

### Case ###
function MinhaFuncao4() {
  case $1 in
  10) echo "é 10" ;; # sempre ;;
  9) echo "é 9" ;;
  7 | 8) echo "é 7 ou 8" ;;
  *) echo "é menor que 6 ou maior que 10" ;;
  esac
}
MinhaFuncao4 $1
