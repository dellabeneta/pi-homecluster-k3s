# Observability

Stack de observabilidade dos nodes do cluster: **node_exporter + Prometheus + Grafana**, com alertas no Telegram. Tudo roda direto nos hosts como serviço systemd, fora do K3s, para continuar funcionando mesmo se o cluster cair.

| Componente | Versão | Onde roda | Porta | Papel |
| :--- | :--- | :--- | :--- | :--- |
| node_exporter | 1.12.1 | Todos os nodes | 9100 | Expõe as métricas de cada host |
| Prometheus | 3.15.0 | Control plane | 9090 | Busca as métricas a cada 15s e armazena |
| Grafana | 13.2.3 | Control plane | 3000 | Dashboards e alertas |

## Pré-requisito: credenciais do Telegram

O bot do Telegram fica num Ansible Vault criptografado em `grafana/vars/telegram_vault.yml`. A senha do vault fica no arquivo `.vault_pass` na raiz do projeto, fora do git.

Para criar do zero (novo bot ou senha perdida):

```bash
openssl rand -base64 32 > .vault_pass
```

```bash
ansible-vault create observability/grafana/vars/telegram_vault.yml --vault-password-file .vault_pass
```

Conteúdo do vault:

```yaml
telegram_bot_token: "TOKEN_DO_BOT"
telegram_chat_id: "CHAT_ID"
```

> [!IMPORTANT]
> Guarde uma cópia do `.vault_pass` em local seguro. Sem ele, o vault não pode ser lido.

## Instalação

Execute a partir da raiz do projeto, nesta ordem. Cada componente tem um script de validação que pode ser executado logo depois.

| Ordem | Componente | Comando | Validação |
| :--- | :--- | :--- | :--- |
| **Passo 1** | node_exporter | `ansible-playbook -i inventory.yml observability/node-exporter/node-exporter.yml` | `./observability/node-exporter/node-exporter-validate.sh` |
| **Passo 2** | Prometheus | `ansible-playbook -i inventory.yml observability/prometheus/prometheus.yml` | `./observability/prometheus/prometheus-validate.sh` |
| **Passo 3** | Grafana | `ansible-playbook -i inventory.yml observability/grafana/grafana.yml --vault-password-file .vault_pass` | `./observability/grafana/grafana-validate.sh` |

Todos os playbooks aceitam `--check --diff` para simular sem alterar nada, e podem ser executados novamente sem efeito colateral.

## Acesso

| Endereço | Uso |
| :--- | :--- |
| `https://grafana.dellabeneta.com` | Grafana pela internet, via Cloudflare Tunnel + Access |
| `http://<ip-do-controlplane>:3000` | Grafana na rede local |
| `http://<ip-do-controlplane>:9090` | Interface do Prometheus (targets e consultas PromQL) |

No primeiro login do Grafana o usuário é `admin` / `admin`, e a troca de senha é obrigatória.

| Dashboard | Conteúdo |
| :--- | :--- |
| **Overview** (página inicial) | Tabela consolidada dos nodes (status, CPU, RAM, disco, temperatura, rede, uptime, Cloudflare Tunnel) e gráficos de CPU, RAM, rede, disco e temperatura |
| **Node Exporter Full** | Visão detalhada de um node por vez. Clicar no nome do host no Overview abre este dashboard já filtrado |

## Alertas

Enviados ao Telegram pelo bot configurado no vault. Critical repete a cada 1h enquanto não resolver, warning a cada 6h, e ambos avisam quando resolvem.

| Severidade | Alerta | Condição | Tempo |
| :--- | :--- | :--- | :--- |
| 🔴 critical | Node down | node_exporter não responde | 2 min |
| 🔴 critical | K3s service down | `k3s` ou `k3s-agent` inativo | 2 min |
| 🔴 critical | Cloudflare Tunnel down | `cloudflared` inativo | 2 min |
| 🔴 critical | Root filesystem read-only | `/` remontado como somente leitura (sinal de cartão SD falhando) | 1 min |
| 🔴 critical | Temperature critical | Acima de 75°C | 5 min |
| 🔴 critical | Disk almost full | Acima de 90% | 5 min |
| 🔴 critical | RAM almost exhausted | Acima de 90% | 5 min |
| 🟡 warning | Temperature high | Entre 65°C e 75°C | 10 min |
| 🟡 warning | CPU usage high | Acima de 85% | 15 min |
| 🟡 warning | RAM usage high | Entre 80% e 90% | 15 min |
| 🟡 warning | Disk filling up | Entre 80% e 90% | 5 min |
| 🟡 warning | Clock not synchronized | NTP fora de sincronia | 10 min |
| 🟡 warning | Node rebooted | Uptime menor que 10 min | Imediato |

## Manutenção

| Tarefa | Como |
| :--- | :--- |
| Atualizar versões | Trocar a variável de versão no topo do playbook (`node_exporter_version`, `prometheus_version`, `grafana_version`) e executar de novo. O Grafana fica em hold no APT, então um `apt upgrade` não o atualiza sozinho |
| Alterar dashboards | Editar o JSON em `grafana/dashboards/` e executar o playbook do Grafana. Os dashboards são provisionados como arquivo e não podem ser salvos pela interface: o repositório é a fonte da verdade |
| Alterar alertas | Editar `grafana/alerting/rules.yml` (regras), `policies.yml` (repetição) ou `templates.yml` (formato da mensagem) e executar o playbook do Grafana |
| Novo node | Adicionar ao `inventory.yml` e executar os playbooks do node_exporter e do Prometheus. Os targets são gerados a partir do inventário |

| Detalhe | Valor |
| :--- | :--- |
| Retenção do Prometheus | 15 dias ou 2 GB, o que vier primeiro, para proteger o cartão SD |
| Plugins do Grafana | Apenas o Prometheus fica ativo. Os demais estão desligados em `grafana_disabled_plugins` para economizar RAM |
| Limitação | O Grafana roda no control plane: se ele cair, nenhum alerta é enviado |
