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
#   v1.0 03/10/2018, Juca:
# ------------------------------------------------------------------------ #
# Testado em:
#   bash 4.4.19

# ------------------------------- VARIÁVEIS ----------------------------------------- #

USUARIOS="$(cat /etc/passwd | cut -d : -f 1)"
MENSAGEM_USO="
  $0 - [OPÇÕES]

  -h - Menu de ajuda
  -v - Versão
  -s - Ordernar a saída
"

VERSAO="v1.0"
# ------------------------------------------------------------------------ #

# ------------------------------- TESTES ----------------------------------------- #

# ------------------------------------------------------------------------ #

# ------------------------------- FUNÇÕES ----------------------------------------- #

# ------------------------------------------------------------------------ #

# ------------------------------- EXECUÇÃO ----------------------------------------- #

echo "$USUARIOS"
# ------------------------------------------------------------------------ #
