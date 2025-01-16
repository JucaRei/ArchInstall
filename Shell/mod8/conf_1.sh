#!/usr/bin/env bash
# ------------------------------------------------------------------------------------ #

# ------------------------------- VARIÁVEIS ------------------------------------------ #
ARQUIVO_DE_CONFIGURACAO="configuracao.cf"
USAR_CORES=
USAR_MAIUSCULAS=
MENSAGEM="Mensagem de teste"

VERDE="\033[32;1m"
VERMELHO="\033[31;1m"
# ------------------------------------------------------------------------------------ #

# ------------------------------- TESTES --------------------------------------------- #
[ ! -r "$ARQUIVO_DE_CONFIGURACAO" ] && echo "Você não tem accesso de leitura, finalizando programa." && exit 1
# ------------------------------------------------------------------------------------ #

# ------------------------------- FUNÇÔES -------------------------------------------- #

# ------------------------------------------------------------------------------------ #

# ------------------------------- EXECUÇÃO ------------------------------------------- #
while read -r linha; do
  [ "$(echo $linha | cut -c1)" = "#" ] && continue # Remove a linha com jogo da velha (comentado)
  [ ! "$linha" ] && continue                       # Verifica se não tem alguma coisa na linha
  echo "$linha"                                    # Mostra cade linha do arquivo
done <"$ARQUIVO_DE_CONFIGURACAO"
# ------------------------------------------------------------------------------------ #
