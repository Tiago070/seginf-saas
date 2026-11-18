# Índice de evidências
Esta pasta reunirá as evidências do projeto, nomeadas conforme o requisito atendido.
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

As capturas 01 a 03 são preliminares e foram mantidas apenas para histórico.
As capturas 04 a 09 mostram os comandos, o prompt com usuário e host e a data.
A captura 11 confirma acesso do servidor à Internet e resolução DNS.
Ela mostra a suíte de repositórios `resolute`; a versão Ubuntu 26.04.1 LTS foi
confirmada nas três VMs e registrada em `config/lab.env`.
A captura 10 também é preliminar por não exibir a data; refaça-a com `date`
visível para atender integralmente à convenção de evidências.
