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
| `18-R2.6-pre-reaplicacao-final.txt` | R2.6 | `sudo bash scripts/hardening-so.sh --aplicar` | Estado imediatamente anterior à reaplicação final, após atualização do kernel; inventário de portas, serviços, pacotes, permissões e atualizações | Tiago | 20/11/2026 UTC |
| `19-R2.6-depois-hardening-so.txt` | R2.6 | `sudo bash scripts/hardening-so.sh --aplicar` | Relatório após a reaplicação final, com permissões verificadas e sem atualizações listadas | Tiago | 20/11/2026 UTC |
| `20-R2.6-inventario-inicial.txt` | R2.6 | `sudo bash scripts/hardening-so.sh --relatorio` | Linha de base anterior à primeira aplicação, com `open-iscsi.service` habilitado, permissões iniciais e atualizações pendentes | Tiago | 20/11/2026 UTC |
| `21-R3.1-E3-E4-GPG.png` | R3.1, E3, E4 | `gpg --armor --output .\gpg\chaves-publicas\grupo7-publicas.asc --export-options export-local-sigs --export tiago luanna felipe`; `gpg --encrypt`; `gpg --decrypt` | Exportação pública do grupo, cifragem e decifragem do arquivo fictício | Tiago e Luanna | 20/11/2026 |
| `22-R3.1-assinaturas-GPG.txt` | R3.1, E3 | `gpg --list-sigs`; `gpg --check-sigs` | Três chaves públicas, cada uma com assinatura de outro integrante; nove assinaturas válidas | Tiago | 20/11/2026 |
| `23-R3.2-agendamento-integridade.png` | R3.2, E2 | `sudo bash /opt/seginf-saas/scripts/verifica-integridade.sh --check`; `--instalar-agendamento`; `systemctl is-active cron.service`; `sudo cat /etc/cron.d/saas-integridade` | Linha de base sem divergências, cron ativo e agendamento de cinco em cinco minutos usando cópia protegida por root | Tiago | 20/11/2026 |
| `24-R3.2-execucao-periodica-integridade.png` | R3.2, E2, E4 | `sudo tail -n 5 /var/log/saas-integridade.log`; `sudo journalctl -t saas-integridade -n 5 --no-pager` | Execuções periódicas registradas no log local e no journal, com verificações sem divergências | Tiago | 20/11/2026 UTC |
| `25-R3.2-teste-conta-integridade.png` | R3.2, E2, E4 | `sudo useradd`; `sudo bash /opt/seginf-saas/scripts/verifica-integridade.sh --check`; `sudo userdel`; `--atualizar`; `--check` | Criação da conta produziu divergência com código 2; remoção e atualização retornaram o estado OK | Tiago | 20/11/2026 |
| `26-R3.2-teste-shadow-integridade.png` | R3.2, E2, E4 | `sudo passwd teste_integridade`; `sudo bash /opt/seginf-saas/scripts/verifica-integridade.sh --check` | Alteração controlada da senha em `/etc/shadow` detectada como divergência com código 2 | Tiago | 20/11/2026 UTC |
| `27-R3.2-restauracao-conta-integridade.png` | R3.2, E2, E4 | `sudo userdel teste_integridade`; `sudo bash /opt/seginf-saas/scripts/verifica-integridade.sh --atualizar`; `--check`; `getent passwd` | Remoção da conta e atualização da linha de base restauraram o estado OK | Tiago | 20/11/2026 |
| `28-R3.2-teste-firewall-integridade.png` | R3.2, E2, E4 | `sudo tee -a /etc/iptables/saas-firewall.rules`; `sudo bash /opt/seginf-saas/scripts/verifica-integridade.sh --check` | Alteração controlada no arquivo persistido do firewall detectada como divergência com código 2 | Tiago | 20/11/2026 UTC |
| `29-R3.2-restauracao-firewall-integridade.png` | R3.2, E2, E4 | `sudo cp -a /root/saas-firewall.rules.pre-teste /etc/iptables/saas-firewall.rules`; `--atualizar`; `--check` | Arquivo restaurado, linha de base atualizada e estado OK confirmado | Tiago | 20/11/2026 UTC |
| `30-R2.5-ssh-config-efetiva.png` | R2.5 | `sudo sshd -t`; `sudo sshd -T`; `sudo ss -tlnp | grep 22022`; `ssh -p 22022 ... root@10.0.2.3` | Sintaxe válida, `PermitRootLogin no`, `AllowUsers`, listener em 22022 e início da tentativa SSH como root | Tiago | 20/11/2026 UTC |
| `31-R2.5-ssh-root-bloqueado.png` | R2.5, E4 | `ssh -p 22022 root@10.0.2.3`; `sudo tail -n 20 /var/log/auth.log` | Cliente mostrou `Permission denied`; servidor registrou `root not allowed because not listed in AllowUsers` | Tiago | 20/11/2026 UTC |
| `32-R2.2-R2.3-R2.4-R2.5-nmap-depois-firewall.png` | R2.2, R2.3, R2.4, R2.5, E4 | `nmap -Pn -p 80,443,5432,22022 10.0.2.3`; `date` | Depois do firewall, HTTP e HTTPS estavam abertas, PostgreSQL fechado na WAN e SSH aberto na porta 22022 | Tiago | 20/11/2026 UTC |
| `33-R2.5-ssh-chave-tiago.png` | R2.5, E4 | `ssh -p 22022 tiago@10.10.10.1`; `whoami`; `hostname`; `date` | Conta nominal autenticada por chave na porta 22022; sessão confirmou `tiago` no host `srv-saas` | Tiago | 20/11/2026 UTC |
| `34-R2.2-R2.5-R2.6-persistencia-pos-reinicio.png` | R2.2, R2.5, R2.6 | `sudo bash scripts/firewall.sh --status`; `systemctl is-active ssh nginx postgresql cron`; `sudo ss -tlnp` | Regras persistentes, serviços ativos e listeners de SSH restaurados após reinício | Tiago | 20/11/2026 UTC |
| `35-R3.2-persistencia-pos-reinicio.png` | R3.2, E2 | `sudo bash /opt/seginf-saas/scripts/verifica-integridade.sh --check`; `systemctl is-active cron`; `sudo ss -tlnp` | Integridade sem divergência, cron ativo e listener SSH confirmado após reinício | Tiago | 20/11/2026 UTC |
| `gpg/chaves-publicas/grupo7-publicas.asc` | E3 | `gpg --armor --output .\gpg\chaves-publicas\grupo7-publicas.asc --export` | Exportação combinada das chaves públicas do grupo | Tiago | 20/11/2026 |
| `gpg/exemplo/credenciais-exemplo.env.gpg` | R3.1, E4 | `gpg --encrypt --recipient luanna .\gpg\exemplo\credenciais-exemplo.env` | Arquivo de exemplo cifrado para a Luanna, que o decifrou com a própria chave | Tiago e Luanna | 20/11/2026 |

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
O relatório 20 é a linha de base anterior à primeira aplicação do hardening do
SO. Os relatórios 18 e 19 foram gerados antes e depois de uma reaplicação
idempotente, após a instalação do kernel `7.0.0-44`; o relatório 18 não
substitui a linha de base inicial. O relatório 19 não lista pacotes atualizáveis.
As saídas pós-reinicialização de `uname -r`, `systemctl --failed` e
`systemctl is-enabled open-iscsi.service` foram confirmadas no console, mas não
foram salvas como capturas.
