#!/usr/bin/bash
OLA="Olá, Mundo!"
echo $OLA

##############
### ARRAYS ###
##############
mundo=("Shell Script" "Bash" "GNU" "Linux" "Debian")
#           0           1     2     3       4

declare -a mundo # builtin do bash, o -a aponta para o nome do array

echo $mundo
echo ${mundo}
echo ${mundo[1]}
echo "O array mundo possui ${#mundo[@]} elemento(s)" # aspas duplas
echo ${mundo[*]}
echo ${mundo[@]:2}   # a partir do elemento 2
echo ${mundo[@]:1:3} # entre o elemento 1 e 3

###############
### Funções ###
###############

# Forma 1
# funcao() {
#   #instruções
# }

# Forma 2
# function funcao() {
#   #instruções
# }

# Chamando Função
MinhaFuncao() {
  echo "Essa é minha função"
}

MinhaFuncao

# Passando parâmetro para funções em Shell
function MinhaFuncao2() {
  echo "Desenvolvo em $2 $1" # aspas simples não exibem o conteúdo da variável especial
}
MinhaFuncao2 $1 $2
MinhaFuncao2 $2 $1
# rode ./variaveis Script Shell

MinhaFuncao3() {
  echo "Todos os parâmetros que você passou: $@"
}
MinhaFuncao3 $@              #os parametros passados
MinhaFuncao3 "$# parâmetros" #conta os parâmetros que foram passados
MinhaFuncao3 $?              #dentro da função infor se ouve erro ou não, se a saída dessa variável for diferente de 0(zero), houve erro.
# rode ./variaveis Script Shell Bash

MinhaFuncao4() {
  echo "Isso será exibido"
  return # informa o fim da função
  echo "Isso não será exibido, pois foi após o return"
}
MinhaFuncao4
# rode ./variaveis

MinhaFuncao5() {
  OLA2="Olá, mundo!"                          # mesmo na função ela é global
  local OLA3="Olá, mundo!!! (Variável local)" # agora ela só funciona dentro da função
  echo "Isso será exibido"
  echo $OLA3
  echo
  return # informa o fim da função
  echo "Isso não será exibido, pois foi após o return"
}
MinhaFuncao5 $@
echo $OLA2 # será exibida fora da função
echo $OLA3 # sem saída

### Constantes diferente das variáveis, ela não muda de valor
declare -r constante='sempre igual.'
echo $constante # saída: sempre igual.
constante="mude"
echo $constante #saída: a variável permite somente leitura

# Para apagar uma função, ou uma constante, também usa-se unset e o nome da função ou constante.
# unset $constante

cd() {
  echo "Essa função tem o nome do comando cd e o parâmetro é $1"
}

cd "Sim funciona"
echo "Chamando o comando builtin do Shell"
builtin cd ..
ls

### Condições em Shell Script
# test 1 = 1; echo $?
# test [1=1]; echo $?

##############################
### Estruturas de Condição ###
##############################
variavel=8
if test "$variavel" -gt 10; then
  echo "é maior que 10"
else
  echo "é menor que 10"
fi
