#!/usr/bin/env bash

ARQUIVO_DE_CONFIGURACAO="configuracao.cf"
MENSAGEM="Mensagem de teste."
USAR_MAIUSCULAS=
USAR_CORES=
VERMELHO="\033[31;1m"

eval $(./parser.sh $ARQUIVO_DE_CONFIGURACAO)

[ "$(echo $CONF_USAR_MAIUSCULAS)" = "1" ] && USAR_MAIUSCULAS="1"
[ "$(echo $CONF_USAR_CORES)" = "1" ] && USAR_CORES="1"

[ "$USAR_MAIUSCULAS" = "1" ] && MENSAGEM="$(echo $MENSAGEM | tr a-z A-Z)"
[ "$USAR_CORES" = "1" ] && MENSAGEM="$(echo -e ${VERMELHO}$MENSAGEM)"

echo -e "$MENSAGEM"
