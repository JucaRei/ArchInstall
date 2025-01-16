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
DefinirParametros() {
  local parametro="$(echo $1 | cut -d = -f 1)" #  coluna 1, = é o delimitador
  local valor="$(echo $1 | cut -d = -f 2)"     #  coluna 2

  case "$parametro" in
  USAR_CORES) USAR_CORES=$valor ;;
  USAR_MAIUSCULAS) USAR_MAIUSCULAS=$valor ;;
  esac
}
# ------------------------------------------------------------------------------------ #

# ------------------------------- EXECUÇÃO ------------------------------------------- #
while read -r linha; do
  [ "$(echo $linha | cut -c1)" = "#" ] && continue # Remove a linha com jogo da velha (comentado)
  [ ! "$linha" ] && continue                       # Verifica se não tem alguma coisa na linha
  DefinirParametros "$linha"                       # Para cade interação defini os parâmetros
done <"$ARQUIVO_DE_CONFIGURACAO"

[ $USAR_MAIUSCULAS -eq 1 ] && MENSAGEM="$(echo -e $MENSAGEM | tr [a-z] [A-Z])" # Validar
[ $USAR_CORES -eq 1 ] && MENSAGEM="$(echo -e ${VERDE}$MENSAGEM)"               # Validar

echo "$MENSAGEM"
# ------------------------------------------------------------------------------------ #
