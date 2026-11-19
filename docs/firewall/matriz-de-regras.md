# Matriz de regras do firewall

Os comandos desta matriz são gerados por `scripts/firewall.sh`. Os valores
variáveis são lidos de `config/lab.env`; esta tabela não substitui a execução
do script nem fixa valores repetidos no código. A ameaça mitigada identifica o
vetor do relatório de ameaças relacionado a cada controle.

## Tabelas e políticas

| ID | Tabela | Chain | Comando exato | Finalidade | Ameaça mitigada | Teste | Resultado esperado |
|---|---|---|---|---|---|---|---|
| FW-001 | filter | sistema | `sysctl -w net.ipv4.ip_forward=1` | Habilitar o encaminhamento necessário ao servidor gateway | Cadeia de suprimentos e exposição indevida do tráfego | `sysctl net.ipv4.ip_forward` | Valor `1` |
| FW-002 | filter | INPUT | `iptables -P INPUT DROP` | Bloquear entradas não explicitamente autorizadas | Abuso de credenciais válidas | `iptables -S INPUT` | Política `DROP` |
| FW-003 | filter | FORWARD | `iptables -P FORWARD DROP` | Bloquear encaminhamento não explicitamente autorizado | Vazamento entre redes e exposição de serviços | `iptables -S FORWARD` | Política `DROP` |
| FW-004 | filter | OUTPUT | `iptables -P OUTPUT ACCEPT` | Preservar saída de atualizações e serviços sem bloquear o diagnóstico | Cadeia de suprimentos, ausência de acesso aos repositórios | `iptables -S OUTPUT` | Política `ACCEPT` |
| FW-005 | filter | INPUT | `iptables -F; iptables -X; iptables -Z` | Limpar regras antigas, cadeias auxiliares e contadores antes de reconstruir | Evitar duplicação e regras contraditórias | `iptables -S` | Sem regras antigas duplicadas |
| FW-006 | nat | todas | `iptables -t nat -F; iptables -t nat -X; iptables -t nat -Z` | Limpar regras antigas de NAT antes de aplicar o mascaramento | Evitar encaminhamento não previsto | `iptables -t nat -S` | Sem regras NAT antigas |
| FW-007 | mangle | todas | `iptables -t mangle -F; iptables -t mangle -X; iptables -t mangle -Z` | Limpar alterações antigas de pacote | Evitar regras de pacote não previstas | `iptables -t mangle -S` | Sem regras mangle antigas |

## Estado básico e tráfego válido

| ID | Tabela | Chain | Comando exato | Finalidade | Ameaça mitigada | Teste | Resultado esperado |
|---|---|---|---|---|---|---|---|
| FW-010 | filter | INPUT | `iptables -A INPUT -i lo -j ACCEPT` | Permitir comunicação local necessária aos serviços e ao sistema | Interrupção de serviços locais | `iptables -S INPUT` | Regra `-i lo -j ACCEPT` presente |
| FW-011 | filter | FORWARD | `iptables -A FORWARD -i lo -j ACCEPT` | Permitir o tráfego local que atravessa o encaminhamento | Interrupção de processos locais | `iptables -S FORWARD` | Regra `-i lo -j ACCEPT` presente |
| FW-012 | filter | INPUT | `iptables -A INPUT -m conntrack --ctstate INVALID -j DROP` | Descartar estados que não pertencem a uma conexão conhecida | Variações malformadas e evasão de firewall | Enviar pacote TCP inválido no teste controlado | Pacote descartado sem resposta |
| FW-013 | filter | FORWARD | `iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP` | Impedir encaminhamento de conexões inválidas | Tráfego malformado entre redes | Teste controlado de pacote INVALID | Pacote não encaminhado |
| FW-014 | filter | INPUT | `iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT` | Manter respostas às conexões já autorizadas | Interrupção de sessões válidas | Repetir HTTP ou SSH autorizado | Conexões continuam operantes |
| FW-015 | filter | FORWARD | `iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT` | Preservar respostas legítimas encaminhadas da LAN | Perda de disponibilidade da LAN | Consultar tráfego da LAN pela saída | Respostas retornam à LAN |

## Detecção de varredura e flags TCP inválidas

| ID | Tabela | Chain | Comando exato | Finalidade | Ameaça mitigada | Teste | Resultado esperado |
|---|---|---|---|---|---|---|---|
| FW-020 | filter | INPUT | `iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP` | Bloquear TCP NULL | Varredura de portas | Nmap tipo NULL contra o servidor | Pacotes sem resposta aplicável |
| FW-021 | filter | INPUT | `iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP` | Bloquear TCP XMAS | Varredura de portas | Nmap tipo XMAS contra o servidor | Pacotes descartados |
| FW-022 | filter | INPUT | `iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP` | Bloquear combinação impossível SYN+FIN | Varredura evasiva | Enviar SYN+FIN no ambiente de teste | Pacote descartado |
| FW-023 | filter | INPUT | `iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP` | Bloquear combinação impossível SYN+RST | Varredura evasiva | Enviar SYN+RST no ambiente de teste | Pacote descartado |
| FW-024 | filter | INPUT | `iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m multiport ! --dports 80,443,22022,5432 -m recent --name SCAN --set` | Registrar origens que tentam portas não liberadas | Varredura de portas | Executar Nmap em portas fora da lista | Origem registrada na lista SCAN |
| FW-025 | filter | INPUT | `iptables -A INPUT -m recent --name SCAN --rcheck --seconds 600 --hitcount 5 --rsource -j DROP` | Descartar uma origem com cinco ou mais registros em uma janela de 600 segundos | Varredura coordenada de portas | Repetir tentativas em pelo menos cinco portas | Origem descartada por 600 segundos |

## Limitação de taxa

| ID | Tabela | Chain | Comando exato | Finalidade | Ameaça mitigada | Teste | Resultado esperado |
|---|---|---|---|---|---|---|---|
| FW-030 | filter | INPUT | `iptables -A INPUT -p tcp --dport 22022 -s 10.10.10.0/24 -m conntrack --ctstate NEW -m recent --name SSH --update --seconds 60 --hitcount 4 --rsource -j DROP` | Bloquear a origem da LAN após três novas conexões na janela de 60 segundos | Abuso de credenciais válidas e força bruta | Abrir quatro novas conexões SSH rápidas pela LAN | Quarta ocorrência e seguintes descartadas |
| FW-031 | filter | INPUT | `iptables -A INPUT -p tcp --dport 22022 -s 10.10.10.0/24 -m conntrack --ctstate NEW -m recent --name SSH --set --rsource -j ACCEPT` | Registrar e aceitar novas conexões SSH autorizadas pela LAN antes do limite | Administração legítima | `ssh -p 22022 usuario@10.10.10.1` | Conexão autorizada enquanto estiver abaixo do limite |
| FW-032 | filter | INPUT | `iptables -A INPUT -p tcp --dport 22022 -s DEPLOY_ORIGEM -m conntrack --ctstate NEW -m recent --name SSH --update --seconds 60 --hitcount 4 --rsource -j DROP` | Aplicar o mesmo limite à origem opcional de deploy | Abuso de credenciais de deploy | Abrir conexões rápidas da origem definida | Quarta ocorrência e seguintes descartadas |
| FW-033 | filter | INPUT | `iptables -A INPUT -p tcp --dport 22022 -s DEPLOY_ORIGEM -m conntrack --ctstate NEW -m recent --name SSH --set --rsource -j ACCEPT` | Registrar e aceitar a origem opcional de deploy | Administração e deploy autorizado | `ssh -p 22022 usuario@10.10.10.1` | Conexão autorizada enquanto estiver abaixo do limite |
| FW-034 | filter | INPUT | `iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m hashlimit --hashlimit-name saas_http_per_ip --hashlimit-mode srcip --hashlimit-above 20/m --hashlimit-burst 40 -j DROP` | Limitar novas conexões HTTP por endereço IP | DDoS e disponibilidade | Gerar novas conexões HTTP acima da taxa | Excesso descartado |
| FW-035 | filter | INPUT | `iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -m hashlimit --hashlimit-name saas_https_per_ip --hashlimit-mode srcip --hashlimit-above 20/m --hashlimit-burst 40 -j DROP` | Limitar novas conexões HTTPS por endereço IP | DDoS e disponibilidade | Gerar novas conexões HTTPS acima da taxa | Excesso descartado |
| FW-036 | filter | INPUT | `iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 5 -j ACCEPT` | Permitir diagnóstico ICMP dentro de uma taxa controlada | DDoS e varredura ICMP | `ping -c 10` no laboratório | Primeiras respostas dentro do limite |
| FW-037 | filter | INPUT | `iptables -A INPUT -p icmp --icmp-type echo-request -j DROP` | Descartar excesso ICMP | DDoS e varredura ICMP | Continuar ping acima da rajada | Excesso descartado |

## Serviços autorizados

| ID | Tabela | Chain | Comando exato | Finalidade | Ameaça mitigada | Teste | Resultado esperado |
|---|---|---|---|---|---|---|---|
| FW-040 | filter | INPUT | `iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT` | Liberar o redirecionamento HTTP | Disponibilidade do serviço público | `curl -I http://10.10.10.1:80` | Resposta HTTP válida |
| FW-041 | filter | INPUT | `iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT` | Liberar o serviço HTTPS público | Disponibilidade do SaaS | `curl -k -I https://10.10.10.1:443` | Resposta HTTPS válida |
| FW-042 | filter | INPUT | `iptables -A INPUT -p tcp --dport 5432 -s 10.10.10.0/24 -m conntrack --ctstate NEW -j ACCEPT` | Permitir PostgreSQL somente pela LAN | Exposição direta do banco | `nc -vz 10.10.10.1 5432` pela LAN | Conexão autorizada pela LAN |
| FW-043 | filter | INPUT | Nenhuma regra `--dport 22` é inserida; a política final `DROP` descarta a porta | Garantir que a porta SSH padrão não seja aceita | Abuso de credenciais válidas | `nmap -Pn -p 22 SERVIDOR_WAN` | Porta fechada |

## Encaminhamento e NAT

| ID | Tabela | Chain | Comando exato | Finalidade | Ameaça mitigada | Teste | Resultado esperado |
|---|---|---|---|---|---|---|---|
| FW-050 | filter | FORWARD | `iptables -A FORWARD -s LAN_REDE -o IFACE_WAN -m conntrack --ctstate NEW -j ACCEPT` | Permitir novas conexões da LAN para destinos pela WAN | Disponibilidade controlada da LAN | Testar saída da LAN pelo gateway | Conexão prevista disponível |
| FW-051 | filter | FORWARD | `iptables -A FORWARD -i IFACE_WAN -d LAN_REDE -m conntrack --ctstate NEW -m limit --limit LOG_LIMIT --limit-burst LOG_BURST -j LOG --log-prefix "FW-FORWARD-DROP "` | Registrar tentativas WAN para LAN antes do descarte | Movimento lateral e acesso indevido | Gerar tentativa WAN para LAN | Registro limitado com prefixo |
| FW-052 | filter | FORWARD | `iptables -A FORWARD -i IFACE_WAN -d LAN_REDE -m conntrack --ctstate NEW -j DROP` | Impedir início de conexões WAN para LAN | Exposição de banco e rede interna | Conectar ao banco pela WAN | Conexão recusada |
| FW-053 | nat | POSTROUTING | `iptables -t nat -A POSTROUTING -s LAN_REDE -o IFACE_WAN -j MASQUERADE` | Substituir origem da LAN ao sair pela WAN | Rastreamento e segmentação da rede interna | Consultar saída pela WAN | Acesso NAT disponível |

## Registro final e persistência

| ID | Tabela | Chain | Comando exato | Finalidade | Ameaça mitigada | Teste | Resultado esperado |
|---|---|---|---|---|---|---|---|
| FW-060 | filter | INPUT | `iptables -A INPUT -m limit --limit LOG_LIMIT --limit-burst LOG_BURST -j LOG --log-prefix "FW-INPUT-DROP "` | Registrar entradas descartadas sem inundar os logs | Varredura e força bruta | Gerar pacote não permitido | Log limitado com prefixo |
| FW-061 | filtro persistente | sistema | `iptables-save > ARQUIVO_REGRAS_IPTABLES` | Salvar regras em arquivo protegido | Perda de regras após reinício | `sudo stat -c '%a %n' ARQUIVO_REGRAS_IPTABLES` | Arquivo existente com modo `600` |
| FW-062 | systemd | boot | `ExecStart=/sbin/iptables-restore /etc/iptables/saas-firewall.rules` | Restaurar as regras no boot | Disponibilidade e continuidade da política | Reiniciar o servidor e executar `iptables -S` | Políticas e regras restauradas |

## Por que a ordem importa

As regras são aplicadas do caso mais geral ao caso específico. Loopback e
tráfego `ESTABLISHED,RELATED` aparecem antes das liberações para preservar
conectividade legítima e impedir que respostas válidas sejam descartadas.
`INVALID` precede a cadeia de serviços, pois não corresponde a uma sessão
confiável.

As varreduras são verificadas antes das portas autorizadas. Isso permite
registrar uma origem que tenta uma porta não liberada e descartá-la depois de
atingir o limite. Os limites SSH são aplicados antes da liberação da porta
especificada, evitando que uma origem seja aceita sem passar pela taxa.

Na cadeia de entrada, os serviços HTTP e HTTPS são liberados de qualquer origem,
conforme a arquitetura pública. SSH é limitado à LAN e à origem opcional de
deploy. PostgreSQL é limitado à LAN. O DROP final não aparece como regra de
aceite porque a política `DROP` já descarta o restante.

As regras de encaminhamento permitem somente tráfego NEW da LAN pela interface
WAN. Tentativas WAN para LAN são registradas e descartadas. NAT ocorre somente
para a faixa LAN pela interface WAN.

## DROP versus REJECT

Este projeto usa `DROP`, não `REJECT`, na política INPUT e FORWARD. A opção
reduz a informação devolvida ao cliente sobre o estado das portas e dificulta
varreduras que dependem de respostas imediatas. Também evita que um atacante
receba confirmação direta de que o host está ativo ou que uma porta existe.

Na WAN, `DROP` impede confirmação externa excessiva. Na LAN, `REJECT` não é
usado nas regras de banco ou encaminhamento porque poderia revelar regras e
endereços internos. Aplicações legítimas dependem de `ESTABLISHED,RELATED`
para receber respostas às conexões já autorizadas.
