#!/usr/bin/env bash
# ------------------------------- VARIÁVEIS ----------------------------------------- #
CHAVE_DEBUG=0
NIVEL_DEBUG=0
# ------------------------------------------------------------------------ #

# ------------------------------- FUNCÕES ----------------------------------------- #
Debugar() {
  [ $1 -le $NIVEL_DEBUG ] && echo "Debug $* -----"
}

# $1 para o programa
# $2 para função

function Soma() {
  local total=0

  for i in $(seq 1 25); do
    Debugar 1 "Entrei no for com valor: $i"
    total=$(($total + $i))
    Debugar 2 "Depois da soma: $total"
  done

  # echo $total
}
# ------------------------------------------------------------------------ #

case "$1" in
  -d) [ $2 ] && NIVEL_DEBUG=$2 ;; # valida se existe algo na variavel $2
  0*) Soma ;;
esac

Soma
# ------------------------------- EXECUÇÃO ----------------------------------------- #
# Soma
# ------------------------------------------------------------------------ #

# bash -x -v ./debug_3.sh

# Criando uma função para debugar
