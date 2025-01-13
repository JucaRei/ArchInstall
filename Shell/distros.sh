#!/usr/bin/env bash
while true; do
  distros=$(dialog --stdout --title "Escolha sua Distro" --menu "Qual sua distro preferida" 0 0 0 \
    1 "NixOS" \
    2 "Debian" \
    3 "Archlinux" \
    4 "Gentoo" \
    5 "Ubuntu" \
    0 "Sair")

  [ $? -ne 0 ] && echo "Cancelou ou Apertou ESC." && break

  case "$distros" in
  1)
    dialog --stdout --msgbox "Essa é a MELHOR distro!" 5 30
    break
    ;;
  2)
    dialog --title "Debian" --infobox "Essa é a mais estável!" 5 30
    break
    ;;
  3)
    dialog --title "Gentoo" --infobox "Você é sadomasoquista???!" 5 25
    break
    ;;
  4)
    dialog --title "NixOS" --infobox "É boa mas tem uma curva de aprendizado bem maior, que as outras." 5 30

    if [ $? = 0 ]; then
      dialog --title "NixOS é bom" --infobox '\nSabia!' 0 0
    else
      dialog --title "NixOS é ruim?" --infobox '\nNão!' 0 0
    fi
    break
    ;;

  5)
    dialog --title 'Ubuntu' --timebox '\nVou gravar' 0 0
    break
    ;;
  0)
    echo "Você escolheu Sair."
    break
    ;;

  esac
done
