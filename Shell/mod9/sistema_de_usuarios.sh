#!/usr/bin/env bash
#
# sistema_de_usuarios.sh - Sistema para gerenciamento de usuários
#
# Site:       https://seusite.com.br
# Autor:      Reinaldo P Jr
# Manutenção: Reinaldo P Jr
#
# ------------------------------------------------------------------------ #
#  Este programa faz todas as funções de gerenciamento de usuários, como:
#  inserir, deletar, alterar.
#
#  Exemplos:
#      $ source sistema_de_usuarios.sh
#      $ ListaUsuarios
# ------------------------------------------------------------------------ #
# Histórico:
#
#   v1.0 xx/xx/xxxx, Reinaldo:
#       - Tratamento de erros com relação ao arquivo do banco de dados
#       - Lista usuários
# ------------------------------------------------------------------------ #
# Testado em:
#   bash 5.2.37
# ------------------------------------------------------------------------ #

# ------------------------------- VARIÁVEIS ----------------------------------------- #
ARQUIVO_BANCO_DE_DADOS="banco_de_dados.txt"
SEPARADOR=-
TEMP=temp.$$ # tempo de execução
VERDE="\033[32;1m"
VERMELHO="\033[31;1m"

# ------------------------------------------------------------------------ #

# ------------------------------- TESTES ----------------------------------------- #
[ ! -e "$ARQUIVO_BANCO_DE_DADOS" ] && echo "ERRO. Arquivo não existe" && exit 1                                          # Verifica se existe
[ ! -r "$ARQUIVO_BANCO_DE_DADOS" ] && echo "ERRO. Você não tem permissão de leitura. Finalizando programa." && exit 1    # Verifica se permissão de escrita
[ ! -w "$ARQUIVO_BANCO_DE_DADOS" ] && echo "ERRO. Arquivo não tem permissão de escrita. Finalizando programa." && exit 1 # Verifica se existe
# ------------------------------------------------------------------------ #

# ------------------------------- FUNÇÕES ----------------------------------------- #
MostraUsuariosNaTela() {
  local id="$(echo $linha | cut -d $SEPARADOR -f 1)"
  local nome="$(echo $linha | cut -d $SEPARADOR -f 2)"
  local email="$(echo $linha | cut -d $SEPARADOR -f 3)"

  echo -e "${VERDE}ID: ${VERMELHO}$id"
  echo -e "${VERDE}NOME: ${VERMELHO}$nome"
  echo -e "${VERDE}E-MAIL: ${VERMELHO}$email"
}

ListaUsuarios() {
  while read -r linha; do
    [ "$(echo $linha | cut -c1)" = "#" ] && continue # comentado ignora
    [ ! "$linha" ] && continue                       # linha em branco ignora

    MostraUsuariosNaTela "$linha"
  done <"$ARQUIVO_BANCO_DE_DADOS"
}

ValidaExistenciaUsuario() {
  grep -i -q "$1$SEPARADOR" "$ARQUIVO_BANCO_DE_DADOS"
}

InseriUsuario() {
  local nome="$(echo $1 | cut -d $SEPARADOR -f 2)"

  if ValidaExistenciaUsuario "$nome"; then
    echo "ERRO! Usuário já existe. Teste novamente."
  else
    echo "$*" >>"$ARQUIVO_BANCO_DE_DADOS"
    echo -e "${VERDE}Usuário cadastro com Sucesso!"
  fi
}

RemoveUsuario() {
  ValidaExistenciaUsuario "$1" || return

  grep -i -v "$1$SEPARADOR" "$ARQUIVO_BANCO_DE_DADOS" >"$TEMP"
  mv "$TEMP" "$ARQUIVO_BANCO_DE_DADOS"

  echo -e "${VERMELHO}Usuário removido com sucesso."
}

OrdenaLista() {
  sort "$ARQUIVO_BANCO_DE_DADOS" >"$TEMP"
  mv "$TEMP" "$ARQUIVO_BANCO_DE_DADOS"
}
# ------------------------------------------------------------------------ #

# ------------------------------- EXECUÇÃO ----------------------------------------- #

# ------------------------------------------------------------------------ #
