# Observability

Stack de observabilidade do cluster: **node_exporter + Prometheus + Grafana**.

| Componente | Pasta | Papel |
| :--- | :--- | :--- |
| node_exporter | `node-exporter/` | Coleta métricas de cada host (CPU, RAM, disco, rede, temperatura) e expõe na porta `9100` |
| Prometheus | `prometheus/` | Faz o scrape dos exporters e armazena as séries temporais |
| Grafana | `grafana/` | Dashboards sobre os dados do Prometheus |

Os playbooks são executados a partir da raiz do projeto:

```bash
ansible-playbook -i inventory.yml observability/<componente>/<playbook>.yml
```
