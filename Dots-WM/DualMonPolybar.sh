#!/bin/sh
# termina qualquer instância do programa que esteja rodando
pkill polybar

# variável guarda a quantidade de monitores
MONS=$(polybar --list-monitors | wc -l)

# caso tenha dois, execute as duas barras
# A bar1 é a barra com mais informações. Ela irá para o monitor
# externo (HDMI1) caso ele esteja conectado.
if [[ "$MONS" == "2" ]]; then
  MON1=HDMI-1-0 polybar --reload bar1 &
  MON2=eDP1 polybar --reload bar2 &
else
  MON1=eDP1 polybar --reload bar1 &
fi
