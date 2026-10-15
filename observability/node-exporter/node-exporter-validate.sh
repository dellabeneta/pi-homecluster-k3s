#!/bin/bash
# Validador do node-exporter.yml.
# Verifica via SSH se o serviço está ativo e, a partir desta máquina,
# se o endpoint /metrics responde pela rede (como o Prometheus fará).
# Deve ser executado da raiz do projeto.

# ==========================================
# Variaveis
# ==========================================

INVENTORY="inventory.yml"
NODES=$(grep 'ansible_host:' "$INVENTORY" | awk '{print $2}')
KEY="$HOME/.ssh/id_ed25519"
PORT=9100
PASS=0
FAIL=0

# ==========================================
# Funcoes
# ==========================================

ssh_run() {
    ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
        -i $KEY k3s@$1 "$2" 2>/dev/null
}

check() {
    DESC=$1
    RESULT=$2
    EXPECTED=$3

    if echo "$RESULT" | grep -q "$EXPECTED"; then
        echo "  ✅ $DESC"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $DESC"
        echo "     Esperado: $EXPECTED"
        echo "     Obtido:   $RESULT"
        FAIL=$((FAIL + 1))
    fi
}

# ==========================================
# Validar nodes
# ==========================================

echo ""
echo "========================================"
echo "  Validacao node_exporter"
echo "========================================"

for NODE in $NODES; do
    echo ""
    echo "--- Node: $NODE ---"

    SERVICE=$(ssh_run $NODE "systemctl is-active node_exporter")
    check "Servico node_exporter ativo" "$SERVICE" "active"

    ENABLED=$(ssh_run $NODE "systemctl is-enabled node_exporter")
    check "Servico habilitado no boot" "$ENABLED" "enabled"

    METRICS=$(curl -s --max-time 5 "http://$NODE:$PORT/metrics")
    check "Endpoint /metrics acessivel pela rede" "$METRICS" "node_exporter_build_info"
    check "Metricas de CPU" "$METRICS" "node_cpu_seconds_total"
    check "Metricas de memoria" "$METRICS" "node_memory_MemAvailable_bytes"
    check "Metricas de temperatura" "$METRICS" "node_thermal_zone_temp"
    check "Metricas de servicos systemd" "$METRICS" "node_systemd_unit_state"
done

# ==========================================
# Resultado
# ==========================================

echo ""
echo "========================================"
echo "  Resultado Final"
echo "========================================"
echo "  ✅ Passou: $PASS"
echo "  ❌ Falhou: $FAIL"
echo "========================================"
echo ""

[ $FAIL -eq 0 ] && exit 0 || exit 1
