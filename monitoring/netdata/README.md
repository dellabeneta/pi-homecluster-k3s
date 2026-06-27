# Netdata — Monitoramento do Cluster

Monitoramento do cluster K3s via Netdata, implementado na arquitetura **Parent-Child**:

- **Control Plane** → Parent: recebe métricas de todos os nodes, armazena em disco (`dbengine`), expõe o dashboard na rede local na porta `19999`
- **Workers** → Children: coletam e streamam métricas em tempo real para o parent, sem escrita em disco (`ram`)

Notificações de alerta via **Telegram**.

---

## Pré-requisitos

- Cluster K3s provisionado (passos 1–3 do README principal)
- Bot do Telegram criado via `@BotFather` com token e chat_id em mãos

---

## Configuração do Vault

As credenciais do Telegram são armazenadas criptografadas via Ansible Vault. Para configurar pela primeira vez:

**1. Criar o arquivo de senha do vault** (fica fora do git):

```bash
openssl rand -base64 32 > .vault_pass
```

**2. Criar o arquivo de variáveis criptografado:**

```bash
ansible-vault create playbooks/vars/netdata_vault.yml --vault-password-file .vault_pass
```

Insira o conteúdo abaixo e salve:

```yaml
telegram_bot_token: "SEU_TOKEN_AQUI"
telegram_chat_id: "SEU_CHAT_ID_AQUI"
```

---

## Instalação

```bash
ansible-playbook -i inventory.yml playbooks/netdata.yml --vault-password-file .vault_pass
```

Ao final da execução, três mensagens de teste chegam no Telegram confirmando que o canal de notificação está operacional.

---

## Rollback

Para remover completamente o Netdata de todos os nodes:

```bash
ansible-playbook -i inventory.yml playbooks/netdata-rollback.yml
```

---

## Dashboard

Acesse o dashboard no browser após a instalação:

```
http://<IP_DO_CONTROL_PLANE>:19999
```

O dashboard exibe métricas em tempo real dos 3 nodes consolidadas em uma única interface.

---

## Alertas ativos

| Métrica | Warning | Critical |
| :--- | :--- | :--- |
| CPU | 75% | 85% |
| RAM | 80% | 90% |
| Disco | 80% | 95% |
| Temperatura | 50°C | 70°C |

---

## Observações

- `dbengine` com limite de 512MB no control plane — histórico de aproximadamente 2–4 dias
- Workers em `mode = ram` — sem escrita em cartão SD
- Dashboard restrito à rede local — não exposto externamente
- Alertas de CPU e RAM são nativos do Netdata; alerta de temperatura é customizado
