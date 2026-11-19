# Relatório Técnico Unificado

## 1. Introdução e escopo

Este relatório consolida a reformulação segura da infraestrutura do laboratório
SaaS multi-tenant do Grupo 7. O ambiente usa Ubuntu Server, servidores Nginx e
PostgreSQL, firewall iptables, OpenSSH, GPG e verificação periódica de
integridade SHA-256.

O escopo é proteger os serviços e os dados do segmento. O desenvolvimento do
produto SaaS não integra o trabalho. O ambiente fictício serve para produzir
tráfego, configurar controles e reunir evidências.

## 2. Cenário e justificatividade

O SaaS opera dados compartilhados por vários tenants e permite administração
remota e implantação por SSH. A separação operacional depende de identidades
nominais, origem controlada, privilégio mínimo e regras explícitas de rede.

O primeiro vetor selecionado é o abuso de credenciais válidas e privilégios
administrativos ou de deploy. O segundo é o comprometimento da cadeia de
suprimentos e do pipeline de implantação. A justificativa e o descarte de
varredura, DDoS e exposição direta do banco estão em
[relatório de ameaças](../ameacas/relatorio-ameacas.md) e
[decisão dos vetores](../ameacas/decisao-vetores.md).

## 3. Topologia do laboratório

O servidor `srv-saas` possui uma interface WAN e uma interface LAN. A
`estacao-admin` pertence à LAN administrativa. O `cliente-externo` realiza
testes no lado WAN.

- WAN: valores observados em `config/lab.env`;
- LAN: rede definida em `LAN_REDE`;
- SSH administrativo: porta definida em `PORTA_SSH`;
- HTTP: porta definida em `PORTA_HTTP`;
- HTTPS: porta definida em `PORTA_HTTPS`;
- PostgreSQL: porta definida em `PORTA_DB`, vinculada à LAN.

A versão detalhada da topologia está em
[laboratorio.md](../arquitetura/laboratorio.md) e
[rede.md](../arquitetura/rede.md).

## 4. Relatório de ameaças

A análise considera Confidencialidade, Integridade, Disponibilidade e
rastreabilidade. O primeiro vetor pode permitir acesso a dados e ações em
produtos de vários tenants. O segundo pode introduzir software ou configuração
alterados por meio de pacotes, repositórios, artefatos ou conta de deploy.

Os controles propostos devem ser associados somente à implementação efetiva.
Parâmetros armazenados em `config/lab.env` não são controles ativos até serem
aplicados por scripts e confirmados na VM.

## 5. Política de Segurança da Informação

O capítulo da PSI define responsabilidades de administradores, equipe de deploy
e gestão. Contas nominais, privilégio mínimo, segregação de tenants, revisão
periódica, registros de auditoria, proteção de evidências, uso aceitável,
conformidade e sanções estão em
[capitulo-psi.md](../psi/capitulo-psi.md).

Os índices de rastreabilidade usam identificadores PSI-AC, PSI-AU, PSI-UA e
PSI-CS. Elementos que ainda dependem da aplicação ou da evidência permanecem
indicados no próprio documento.

## 6. Rede e roteamento

O servidor usa Netplan para atribuir endereços LAN e WAN persistentes, instalar
a rota estática e configurar resolvedores. O encaminhamento IPv4 é necessário
porque o servidor atua como gateway no laboratório.

O script `scripts/aplica-rede.sh` lê os parâmetros de `config/lab.env`, valida
a entrada e cria uma configuração renderizada no sistema. O procedimento exige
uso do console local da VM porque `netplan try` pode reverter uma alteração.

Os serviços simulados são Nginx e PostgreSQL. O PostgreSQL deve ficar vinculado
ao endereço LAN e aceitar autenticação SCRAM-SHA-256 somente da rede
administrativa.

## 7. Firewall com iptables

O firewall usa somente iptables e módulos nativos do netfilter. A política
padrão é DROP em INPUT e FORWARD, enquanto OUTPUT permanece ACCEPT.

A configuração é construída nesta ordem:

1. limpeza das tabelas filter, nat e mangle;
2. políticas padrões;
3. loopback, INVALID e ESTABLISHED,RELATED;
4. flags TCP inválidas e detecção por recent;
5. limites por origem para SSH e por endereço para HTTP e HTTPS;
6. liberações explícitas dos serviços;
7. encaminhamento, registro limitado e NAT;
8. persistência em arquivo e unidade systemd.

Os comandos exatos, identificadores, finalidade, vetor mitigado e teste estão
na [matriz de regras](../firewall/matriz-de-regras.md).

O projeto usa DROP em vez de REJECT para não confirmar a existência de portas ou
reduzir o efeito informativo contra varredura. As regras permanecem persistidas
em `/etc/iptables/saas-firewall.rules` e são restauradas pela unidade
`saas-firewall.service`.

## 8. Hardening do SSH

A configuração aplicada pelo script `scripts/hardening-ssh.sh` associa contas
nominais e conta de deploy a chaves públicas. A diretiva `AllowUsers` combina
usuário e origem de rede.

Os parâmetros efetivamente implementados são documentados em
[hardening/ssh.md](../hardening/ssh.md). Eles incluem porta configurada,
bloqueio de root, autenticação exclusiva por chave pública, desativação de
senha e autenticação interativa.

O script verifica todas as chaves públicas antes de alterar o sistema. Ele cria
backup, renderiza o drop-in com prefixo `00`, valida `sshd -t`, alterna o
Ubuntu do modo socket para o serviço tradicional quando necessário e confirma
os listeners.

Mudar a porta não substitui firewall, chave ou controle de usuário. A aplicação
precisa manter uma segunda sessão SSH ou o console local até o teste positivo
ser concluído.

## 9. Hardening do sistema operacional

O script `scripts/hardening-so.sh` gera inventários antes e depois, ajusta
permissões pontuais e aplica somente pacotes ou serviços previamente aprovados
em `config/lab.env`.

Os procedimentos não usam remoção recursiva. Técnicas antigas são avaliadas
contra o Ubuntu instalado: TCP Wrappers, `securetty` e desativação de
`ctrl-alt-del.target` são registradas como aplicáveis ou não aplicáveis conforme
o estado real da VM.

As aprovações, relatórios e técnicas avaliadas estão em
[hardening/so.md](../hardening/so.md).

## 10. Gestão de chaves GPG

O requisito exige um par GPG por integrante, assinaturas cruzadas após
conferência de impressão digital e troca cifrada de um arquivo fictício.

O procedimento está em [gpg.md](../criptografia/gpg.md). Algoritmo, tamanho,
validade e endereços dos integrantes ainda dependem da decisão humana e não
devem ser presumidos.

Somente chaves públicas podem ser versionadas. Chaves privadas e frases-senha
devem permanecer nos dispositivos dos integrantes.

## 11. Verificação de integridade

O script `scripts/verifica-integridade.sh` cria e compara o SHA-256 de:

- `/etc/passwd`;
- `/etc/shadow`;
- arquivo persistente das regras do iptables.

As alterações controladas são confirmadas por alerta no terminal, arquivo de
log e `logger`. A linha de base é protegida por permissões root e pode ser
atualizada somente após motivo aprovado. Quem obtém acesso root também pode
alterar o baseline, portanto a linha de base não prova autenticidade por si
mesma.

O procedimento completo está em
[integridade.md](../integridade/integridade.md).

## 12. Testes e evidências

Os testes estáticos existentes estão em `tests/` e precisam ser executados nas
VMs. Eles não substituem a coleta manual das capturas exigidas.

As quatro evidências obrigatórias são:

1. Nmap antes e depois do firewall;
2. tentativa SSH como root recusada;
3. decifragem e verificação GPG;
4. detecção automática de alteração SHA-256.

A convenção e o índice estão em [evidencias/README.md](../../evidencias/README.md).

## 13. Conclusão

Os scripts e documentos existentes formam a base técnica do trabalho. A
conclusão depende da aplicação nas VMs, da decisão e execução das chaves GPG,
da revisão do hardening do SO e da coleta das quatro evidências com data, host
e comando visíveis.

Nenhum requisito deve ser marcado como concluído antes dessa validação real.

## Referências

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. **ABNT NBR ISO/IEC 27001:2022**:
segurança da informação, segurança cibernética e proteção à privacidade:
sistemas de gestão da segurança da informação: requisitos. Rio de Janeiro:
ABNT, 2022.

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. **ABNT NBR ISO/IEC 27002:2022**:
segurança da informação, segurança cibernética e proteção à privacidade:
controles de segurança da informação. Rio de Janeiro: ABNT, 2022.

CENTRO DE ESTUDOS, RESPOSTA E TRATAMENTO DE INCIDENTES DE SEGURANÇA NO BRASIL
(CERT.br). **Cartilha de Segurança para Internet**. São Paulo: Comitê Gestor da
Internet no Brasil, [s.d.]. Disponível em: https://cartilha.cert.br/.

CROWDSTRIKE. **Relatório Global de Ameaças 2026**: resumo executivo.
[S.l.]: CrowdStrike, 2026. Material da disciplina.

GONÇALVES, Roitier Campos. **Aulas 01 a 10 de Segurança da Informação**.
Ceres: Instituto Federal Goiano, 2026. Material da disciplina.
