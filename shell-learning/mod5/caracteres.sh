#!/usr/bin/env bash

# sempre começa com "\033", digito especial do Bash que significa ESC, para coloração
# depois coloca o "["
# depois o numero selecionado qualquer ex: "10"
# o final é com "m" minisculo

# para o comando echo identificar os digitos como cores tem que inicilizar com "-e", ex: "echo -e"

# ex: echo -e "\033[36mJuca (imprime juca em ciano)

### Interpolar mais opções são separados por ";" ex: "echo -e "\033[36;1mJuca"
### outro ex: "echo -e "\033[36;5mJuca"

# ------------------------------- VARIÁVEIS ----------------------------------------- #
CHAVE_DEBUG=0
NIVEL_DEBUG=0

ROXO="\033[35;1m"  # Roxo/negrito
CIANO="\033[36;1m" # Ciano/negrito
# ------------------------------------------------------------------------ #

# ------------------------------- FUNCÕES ----------------------------------------- #
Debugar() {
  [ $1 -le $NIVEL_DEBUG ] && echo -e "${2} Debug $* -----"
}

# $1 para o programa
# $2 para função

function Soma() {
  local total=0

  for i in $(seq 1 25); do
    Debugar 1 "${ROXO}" "Entrei no for com valor: $i"
    total=$(($total + $i))
    Debugar 2 "${CIANO}" "Depois da soma: $total"
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
