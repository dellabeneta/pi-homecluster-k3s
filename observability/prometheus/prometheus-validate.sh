#!/bin/bash
# Validador do prometheus.yml.
# Verifica via SSH se o serviço está ativo no control plane e, a partir desta
# máquina, se a API responde e se cada node_exporter está sendo coletado (up).
# Deve ser executado da raiz do projeto.

# ==========================================
# Variaveis
# ==========================================

INVENTORY="inventory.yml"
CONTROLPLANE=$(grep -A1 'controlplane:' "$INVENTORY" | grep 'ansible_host:' | awk '{print $2}' | head -1)
HOSTNAMES=$(grep 'hostname:' "$INVENTORY" | awk '{print $2}')
KEY="$HOME/.ssh/id_ed25519"
PORT=9090
API="http://$CONTROLPLANE:$PORT/api/v1"
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
# Validar Prometheus
# ==========================================

echo ""
echo "========================================"
echo "  Validacao Prometheus"
echo "========================================"

echo ""
echo "--- Control Plane: $CONTROLPLANE ---"

SERVICE=$(ssh_run $CONTROLPLANE "systemctl is-active prometheus")
check "Servico prometheus ativo" "$SERVICE" "active"

ENABLED=$(ssh_run $CONTROLPLANE "systemctl is-enabled prometheus")
check "Servico habilitado no boot" "$ENABLED" "enabled"

CONFIG=$(ssh_run $CONTROLPLANE "sudo promtool check config /etc/prometheus/prometheus.yml 2>&1")
check "Configuracao valida (promtool)" "$CONFIG" "SUCCESS"

READY=$(curl -s --max-time 5 "http://$CONTROLPLANE:$PORT/-/ready")
check "API acessivel pela rede" "$READY" "Ready"

# ==========================================
# Validar targets
# ==========================================

echo ""
echo "--- Targets (job node) ---"

for NAME in $HOSTNAMES; do
    UP=$(curl -s --max-time 5 -G "$API/query" --data-urlencode "query=up{job=\"node\",instance=\"$NAME\"}")
    check "node_exporter $NAME coletado (up=1)" "$UP" '"value":\[[0-9.]*,"1"\]'
done

# ==========================================
# Consulta real
# ==========================================

echo ""
echo "--- Temperatura atual (PromQL) ---"
curl -s --max-time 5 -G "$API/query" --data-urlencode 'query=node_thermal_zone_temp' \
    | grep -o '"instance":"[^"]*"\|"value":\[[0-9.]*,"[0-9.]*"\]' \
    | paste - - | sed -E 's/"instance":"([^"]*)".*,"([0-9.]*)"\]/  \1: \2 °C/'

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
