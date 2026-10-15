#!/bin/sh

WORKERS="192.168.18.242 192.168.18.244"
MASTER="192.168.18.240"
USER="k3s"

echo "Iniciando desligamento gracefully..."

# 1. Para o Grafana no control plane (evita alertas de serviço parado durante o desligamento)
echo "Parando Grafana em $MASTER..."
ssh "$USER@$MASTER" "sudo systemctl stop grafana-server"

# 2. Para o Prometheus no control plane (grava o banco de métricas no SD de forma limpa)
echo "Parando Prometheus em $MASTER..."
ssh "$USER@$MASTER" "sudo systemctl stop prometheus && sync"

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
