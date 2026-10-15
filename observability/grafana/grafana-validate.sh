#!/bin/bash
# Validador do grafana.yml.
# Verifica via SSH se o serviço está ativo e se o provisioning (datasource e
# dashboard) foi carregado sem erros, e a partir desta máquina se a interface
# responde pela rede.
# Deve ser executado da raiz do projeto.

# ==========================================
# Variaveis
# ==========================================

INVENTORY="inventory.yml"
CONTROLPLANE=$(grep -A1 'controlplane:' "$INVENTORY" | grep 'ansible_host:' | awk '{print $2}' | head -1)
KEY="$HOME/.ssh/id_ed25519"
PORT=3000
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
# Validar Grafana
# ==========================================

echo ""
echo "========================================"
echo "  Validacao Grafana"
echo "========================================"

echo ""
echo "--- Control Plane: $CONTROLPLANE ---"

SERVICE=$(ssh_run $CONTROLPLANE "systemctl is-active grafana-server")
check "Servico grafana-server ativo" "$SERVICE" "active"

ENABLED=$(ssh_run $CONTROLPLANE "systemctl is-enabled grafana-server")
check "Servico habilitado no boot" "$ENABLED" "enabled"

HOLD=$(ssh_run $CONTROLPLANE "apt-mark showhold")
check "Pacote grafana em hold" "$HOLD" "grafana"

HEALTH=$(curl -s --max-time 5 "http://$CONTROLPLANE:$PORT/api/health")
check "Interface acessivel pela rede" "$HEALTH" '"database": *"ok"'

# ==========================================
# Validar provisioning
# ==========================================

echo ""
echo "--- Provisioning ---"

DATASOURCE=$(ssh_run $CONTROLPLANE "sudo grep -c 'url: http://localhost:9090' /etc/grafana/provisioning/datasources/prometheus.yml")
check "Datasource Prometheus provisionado" "$DATASOURCE" "^1$"

DASHBOARD=$(ssh_run $CONTROLPLANE "test -s /var/lib/grafana/dashboards/node-exporter-full.json && echo presente")
check "Dashboard Node Exporter Full presente" "$DASHBOARD" "presente"

ERRORS=$(ssh_run $CONTROLPLANE "sudo journalctl -u grafana-server -b --no-pager | grep -ci 'level=error.*provisioning'")
check "Sem erros de provisioning no log" "$ERRORS" "^0$"

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
echo "  Acesse: http://$CONTROLPLANE:$PORT"
echo ""

[ $FAIL -eq 0 ] && exit 0 || exit 1
