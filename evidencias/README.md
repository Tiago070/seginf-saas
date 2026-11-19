# Índice de evidências
Esta pasta reúne as evidências do projeto, nomeadas conforme o requisito atendido.
As capturas devem mostrar host, usuário, data e comando executado.
Registre uma linha no índice para cada evidência produzida.

| Arquivo | Requisito | Comando | O que prova | Quem executou | Data |
|---|---|---|---|---|---|
| `01-etapa1-srv-saas-ip-addr-route.png` | Etapa 1 | `ip -br addr`; `ip route` | Captura preliminar, substituída pela evidência 04 | Tiago | 17/11/2026, não visível na captura |
| `02-etapa1-cliente-externo-ip-addr-route.png` | Etapa 1 | `ip -br addr`; `ip route` | Captura preliminar, substituída pela evidência 05 | Tiago | 17/11/2026, não visível na captura |
| `03-etapa1-estacao-admin-ip-addr-route.png` | Etapa 1 | `ip -br addr`; `ip route` | Captura preliminar, substituída pela evidência 06 | Tiago | 17/11/2026, não visível na captura |
| `04-etapa1-srv-saas-ip-addr-route.png` | Etapa 1 | `ip -br addr`; `ip route`; `date` | Endereços WAN/LAN e rotas do servidor. O comando de adicionar o IP informa que ele já estava atribuído | Tiago | 17/11/2026 |
| `05-etapa1-cliente-externo-ip-addr-route.png` | Etapa 1 | `ip -br addr`; `ip route`; `date` | Endereço WAN e rota padrão do cliente externo | Tiago | 17/11/2026 |
| `06-etapa1-estacao-admin-ip-addr-route.png` | Etapa 1 | `ip -br addr`; `ip route`; `date` | Endereço LAN e rota conectada da estação. O comando de adicionar o IP informa que ele já estava atribuído | Tiago | 17/11/2026 |
| `07-etapa1-srv-saas-ping-gateway.png` | Etapa 1 | `ping -c 4 10.0.2.1`; `date` | Conectividade do servidor com o gateway WAN, quatro respostas recebidas | Tiago | 17/11/2026 |
| `08-etapa1-estacao-admin-ping-srv-saas.png` | Etapa 1 | `ping -c 4 10.10.10.1`; `date` | Conectividade da estação com o servidor pela LAN, quatro respostas recebidas | Tiago | 17/11/2026 |
| `09-etapa1-cliente-externo-ping-srv-saas.png` | Etapa 1 | `ping -c 4 10.0.2.3`; `date` | Conectividade do cliente externo com o servidor pela WAN, quatro respostas recebidas | Tiago | 17/11/2026 |
| `10-etapa2-r2.1-rota-estatica-temporaria.png` | R2.1 | `ip route`; `ip neigh show 10.10.10.2`; `ping -c 4 10.10.10.2`; `ping -c 4 10.10.20.1` | Rota temporária via `10.10.10.2`, vizinhança alcançável e ping até a interface do roteador em `lan-ci` | Tiago | Data não visível na captura |
| `11-etapa1-srv-saas-internet-apt-update.png` | Etapa 1 | `getent hosts archive.ubuntu.com`; `sudo apt update`; `date` | Resolução DNS e atualização dos índices dos repositórios concluídas no servidor | Tiago | 18/11/2026 UTC |
| `12-R2.1-rede-persistente.png` | R2.1 | `ip -br addr`; `ip route`; `sysctl net.ipv4.ip_forward`; `date` | Endereços WAN e LAN, rotas default e estática e encaminhamento IPv4 após reinício | Tiago | 18/11/2026 UTC |
| `13-R2.1-servicos-https-wan.png` | R2.1 | `curl -I http://10.0.2.3`; `curl -k -I https://10.0.2.3`; `date` | Acesso externo ao Nginx, redirecionamento HTTP 301 para HTTPS e resposta HTTPS 200 | Tiago | 18/11/2026 UTC |
| `14-R2.1-nmap-antes-firewall.png` | R2.1, E4 | `nmap -Pn -p 80,443,5432 10.0.2.3`; `date` | Linha de base antes do firewall: HTTP e HTTPS abertos, PostgreSQL fechado na WAN | Tiago | 18/11/2026 UTC |
| `15-R2.1-postgresql-pg-hba.png` | R2.1 | `sudo -u postgres psql -d postgres -c "SELECT line_number, type, database, user_name, address, auth_method, error FROM pg_hba_file_rules;"`; `date` | Regra de host para `saas_demo` restrita a `10.10.10.0/24` com `scram-sha-256`; sem erro reportado | Tiago | 18/11/2026 UTC |
| `16-R2.2-R2.3-R2.4-firewall-iptables-S.png` | R2.2, R2.3, R2.4 | `sudo iptables -S`; `sudo iptables -t nat -S`; `sudo iptables -t mangle -S` | Políticas DROP em INPUT e FORWARD, fluxo de estado, bloqueios TCP inválidos, varredura recent, limites SSH e web, serviços autorizados, encaminhamento LAN e MASQUERADE | Tiago | 19/11/2026, data não visível na captura |
| `17-R2.2-R2.3-R2.4-firewall-status-persistencia.png` | R2.2, R2.3, R2.4 | `sudo bash scripts/firewall.sh --aplicar`; `sudo bash scripts/firewall.sh --status` | Aplicação de regras idempotente, status efetivo e persistência em `/etc/iptables/saas-firewall.rules` com permissão `600` | Tiago | 19/11/2026, data não visível na captura |

As capturas 01 a 03 são preliminares e foram mantidas apenas para histórico.
As capturas 04 a 09 mostram os comandos, o prompt com usuário e host e a data.
A captura 11 confirma acesso do servidor à Internet e resolução DNS.
Ela mostra a suíte de repositórios `resolute`; a versão Ubuntu 26.04.1 LTS foi
confirmada nas três VMs e registrada em `config/lab.env`.
A captura 10 também é preliminar por não exibir a data; refaça-a com `date`
visível para atender integralmente à convenção de evidências.
As capturas 12 a 15 registram os testes da Etapa 2 após a configuração
persistente, a partir do cliente externo e no PostgreSQL. A captura 14 é a
linha de base Nmap exigida antes do firewall.
As capturas 16 e 17 registram o firewall após a aplicação. A captura 16
confirma as políticas DROP, as regras de estado, de varredura, de taxa, de
serviços, de encaminhamento e de NAT. A captura 17 confirma a execução do script
e o arquivo persistente com permissão 600. Para atender integralmente à convenção
de evidências, repita as duas capturas com `date` visível.
