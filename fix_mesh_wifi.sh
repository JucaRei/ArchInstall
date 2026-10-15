#!/bin/bash
set -e

echo "=========================================================="
echo "    Correção de Wi-Fi Broadcom (wl) em Rede Mesh"
echo "=========================================================="

# 1. Configuração global do NetworkManager para Broadcom + Mesh
echo "[1/5] Configurando NetworkManager para desativar MAC aleatório e Powersave..."
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/99-broadcom-mesh.conf << 'EOF'
[device]
wifi.scan-rand-mac-address=no

[connection]
wifi.powersave=2
wifi.cloned-mac-address=permanent
EOF

# 2. Configurando domínio regulatório
echo "[2/5] Ajustando domínio regulatório para Brasil (BR)..."
sudo iw reg set BR 2>/dev/null || true

# 3. Ajustando conexões NetworkManager (desativando PMF / 802.11w que quebra o driver 'wl')
echo "[3/5] Ajustando conexões 'juca 5g' e 'juca 2g' (Desativando PMF/WPA3 e MAC randomization)..."
for conn in "juca 5g" "juca 2g"; do
    if nmcli connection show "$conn" &>/dev/null; then
        echo " -> Modificando conexão: $conn"
        nmcli connection modify "$conn" 802-11-wireless-security.pmf disable
        nmcli connection modify "$conn" 802-11-wireless.mac-address-randomization never
        nmcli connection modify "$conn" 802-11-wireless.powersave disable
    fi
done

# 4. Reiniciando o NetworkManager para aplicar o arquivo .conf
echo "[4/5] Reiniciando NetworkManager..."
sudo systemctl restart NetworkManager
sleep 3

# 5. Tentando conectar na rede juca 2g primeiro e depois juca 5g
echo "[5/5] Testando conexão..."
nmcli device wifi rescan 2>/dev/null || true
sleep 2

echo "--- Tentando conectar em 'juca 2g' ---"
if nmcli connection up "juca 2g"; then
    echo "✅ SUCESSO: Conectado ao Wi-Fi 'juca 2g'!"
    nmcli device status
    ip addr show dev wlp2s0
    exit 0
fi

echo "--- Falhou juca 2g, tentando 'juca 5g' ---"
if nmcli connection up "juca 5g"; then
    echo "✅ SUCESSO: Conectado ao Wi-Fi 'juca 5g'!"
    nmcli device status
    ip addr show dev wlp2s0
    exit 0
fi

echo "⚠️ Não foi possível conectar automaticamente. Verifique os logs com: journalctl -u NetworkManager -n 30 --no-pager"
