#!/usr/bin/env bash

# egrep = grep extendido ou grep -E

# Filtrar quantos digitos eu tenho em uma linha
egrep "^.{50,}$" /etc/passwd # comece com qualquer coisa e que tenha de 50 digitos, para mais e termina com qualquer coisa.

echo -e "\033[35;1m"
egrep "^.{50,60}$" /etc/passwd # comece com qualquer coisa e que tenha de 50 a 60 digitos, para mais e termina com qualquer coisa.

echo -e "\033[32;1m"
grep -E "^.{80,}$" /etc/passwd

echo -e "\033[36;1m"
grep -E "juca|root" /etc/passwd # operando or
