#!/usr/bin/env bash

# ^ = todas as frase/linha que comecem com ex: ^a
# $ = final de uma frase/linha, tudo que termina ex: $h
# ^[] = uma lista de tudo que começa com ex: ^[ bc ] (tudo que começa com b ou c)
# []$ = uma lista de tudo que termina com ex: ^[ bc ] (tudo que termina com b ou c)
# ^[^] = o circunflexo dentro de uma lista significa negação, ex : ^[^bc] (tudo que começa, que não seja b ou c)

################
### Exemplos ###
################
echo -e "\033[31;1mcat com pipe e grep:"
echo "================================="
cat /etc/passwd | grep "^m" /etc/passwd
echo ""

echo -e "\033[33;4mSomente com grep:"
echo "================================="
grep "^m" /etc/passwd # (faz o mesmo e aloca menos recursos)
echo ""
grep "^ni" /etc/passwd
echo ""

echo -e "\033[35;4mTudo que termina com:"
grep "h$" /etc/passwd
echo ""
grep "^r.*h$" /etc/passwd # (comece no ^r que tenha qualquer ponto no asterisco .* e termine com h (h$))
echo ""
grep "^j.*h$" /etc/passwd # (comece no ^j que tenha qualquer ponto no asterisco .* e termine com h (h$))
echo ""
grep "^m[ae]" /etc/passwd # (comece no ^m e que o segundo digito seja a ou e )
echo ""
grep "^m[^a]" /etc/passwd # (comece no ^m e que o segundo digito não seja a )
grep "^m[^e]" /etc/passwd # (comece no ^m e que o segundo digito não seja e )
echo ""
grep "^.[a]" /etc/passwd # (tudo que comece com qualquer coisa ^. , mas que o segundo digito seja obrigatoriamente o a )
