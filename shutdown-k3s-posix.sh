#!/bin/sh

WORKERS="192.168.18.242 192.168.18.244"
MASTER="192.168.18.240"
USER="k3s"

echo "Iniciando desligamento gracefully..."

# 1. Para o Netdata nos workers (encerra o streaming antes do parent)
for node in $WORKERS; do
  echo "Parando Netdata em $node..."
  ssh "$USER@$node" "sudo systemctl stop netdata"
done

# 2. Para o Netdata no control plane (parent)
echo "Parando Netdata em $MASTER..."
ssh "$USER@$MASTER" "sudo systemctl stop netdata"

# 3. Encerra os agentes k3s dos Workers
for node in $WORKERS; do
  echo "Parando k3s-agent em $node..."
  ssh "$USER@$node" "sudo systemctl stop k3s-agent && sync"
done

# 4. Encerra o k3s do Control Plane
echo "Parando k3s server em $MASTER..."
ssh "$USER@$MASTER" "sudo systemctl stop k3s && sync"

# 5. Desliga as PIs
ALL_NODES="$WORKERS $MASTER"
for node in $ALL_NODES; do
  echo "Desligando $node..."
  ssh "$USER@$node" "sudo shutdown -h now"
done
