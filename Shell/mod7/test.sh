#!/usr/bin/env bash

lynx -source https://lxer.com/ | grep blurb >titulos.txt
tail -n 1 titulos.txt
tail -n 1 titulos.txt | sed 's/<div.*line">//' # pega tudo desde <div com qualquer coisa, ate o final com line

tail -n 1 titulos.txt | sed 's/<div.*line">//' | sed 's/<\/span.*//'
# ou
tail -n 1 titulos.txt | sed 's/<div.*line">//;s/<\/span.*//' # adicione o ; e reutiliza/concatena a outra expressão

cat titulos.txt | sed 's/<div.*line">//;s/<\/span.*//'
