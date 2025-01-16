#!/usr/bin/env bash
#
# lista_usuarios.sh - Extrai usuários do /etc/passwd
#
# Site:       https://siteteste.com.br
# Autor:      Reinaldo P Jr
# Manutenção: Reinaldo P Jr
#
# ------------------------------------------------------------------------ #
#  Este programa irá extrair usuários do /etc/passwd havendo a possibilidade de colocar
#  maiúsculo e em ordem alfabética
#
#  Exemplos:
#      $ ./lista_usuarios.sh -s -m
#      Neste exemplo ficará em maiúsculo e em ordem alfabética.
# ------------------------------------------------------------------------ #
# Histórico:
#
#   v1.0 xx/xx/xxxx, Juca:
#     - Adicionado -s, -h & -v
#   v1.1 xx/xx/xxxx, Juca:
#     - Trocado IF pelo CASE
#   v1.2 xx/xx/xxxx, Juca:
#     -
#     -
# ------------------------------------------------------------------------ #
# Testado em:
#   bash 4.4.19

# ------------------------------- VARIÁVEIS ----------------------------------------- #

USUARIOS="$(cat /etc/passwd | cut -d : -f 1)"
MENSAGEM_USO="
  $(basename $0) - [OPÇÕES]

    -h - Menu de ajuda
    -v - Versão
    -s - Ordernar a saída
    -m - Coloca em maiúsculo
"

VERSAO="v1.2"
CHAVE_ORDENA=0
CHAVE_MAIUSCULO=0
# ------------------------------------------------------------------------ #

# ------------------------------- EXECUÇÃO ----------------------------------------- #

case "$1" in
  -h) echo "$MENSAGEM_USO" && exit 0 ;;
  -v) echo "$VERSAO" && exit 0       ;;
  -s) CHAVE_ORDENA=1                 ;;
  -m) CHAVE_MAIUSCULO=1              ;;
   *) echo "$USUARIOS"               ;;
esac

[ $CHAVE_ORDENA -eq 1 ] && echo "$USUARIOS" | sort
[ $CHAVE_MAIUSCULO -eq 1 ] && echo "$USUARIOS" | tr [a-z] [A-Z]
# ------------------------------------------------------------------------ #

# 0 desabilitado, 1 habilitado
# tr substitui tudo de [a-z] para [A-Z]
