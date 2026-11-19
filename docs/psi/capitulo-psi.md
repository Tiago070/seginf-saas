# Capítulo da Política de Segurança da Informação

## 1. Objetivo

Estabelecer regras obrigatórias para proteger a confidencialidade, integridade,
disponibilidade e rastreabilidade das informações da plataforma SaaS
multi-tenant. As regras abrangem contas administrativas, contas de deploy,
acesso por SSH, dados armazenados em bancos relacionais, dispositivos dos
administradores, registros de segurança e procedimentos de implantação.

As diretrizes desta PSI devem ser interpretadas em conjunto com a topologia,
o firewall, a configuração do SSH, o hardening do sistema operacional, a
gestão de chaves GPG e a verificação de integridade documentadas no repositório.

## 2. Escopo

A PSI aplica-se ao `srv-saas`, à estação administrativa, ao processo de deploy,
às contas administrativas nominais, às contas de serviço, aos dados dos tenants,
aos bancos relacionais, aos scripts de implantação e às evidências de segurança.

A PSI aplica-se a todas as pessoas com acesso ao ambiente de laboratório ou de
produção, incluindo integrantes da equipe, administradores, operadores de deploy
e gestores responsáveis pela autorização de acessos.

## 3. Definições

- **Administrador:** pessoa autorizada a executar tarefas privilegiadas no
  servidor ou nos serviços relacionados.
- **Conta administrativa nominal:** conta individual associada a uma pessoa
  identificável. Contas compartilhadas não são permitidas.
- **Conta de deploy:** conta ou identidade técnica usada exclusivamente para
  publicar ou implantar software e configurações.
- **Tenant:** cliente ou unidade lógica cujos dados e configurações devem ser
  isolados dos demais clientes.
- **Acesso privilegiado:** acesso que permite alterar sistemas, configurações,
  contas, dados ou registros de segurança.
- **Ambiente de produção:** ambiente em que os serviços SaaS e os dados dos
  tenants estão disponíveis para uso operacional.
- **Alerta de integridade:** indicação de que um arquivo crítico, uma regra
  persistente ou outro objeto protegido foi alterado, não pôde ser verificado
  ou deixou de corresponder ao baseline aprovado.

## 4. Responsabilidades

### 4.1 Administradores

Os administradores devem utilizar suas contas nominais, aplicar privilégio
mínimo, registrar as operações realizadas e respeitar os procedimentos de
alteração aprovados.

Os administradores não devem compartilhar senhas ou chaves privadas, usar a
conta de outra pessoa ou conceder acesso além da necessidade operacional.

### 4.2 Equipe de deploy

A equipe de deploy deve utilizar uma identidade específica, revisar as alterações
antes da implantação e registrar a versão ou o hash do artefato aplicado.

A equipe de deploy não deve usar uma conta administrativa nominal como conta
automática de publicação nem armazenar credenciais em scripts, evidências ou
repositórios.

### 4.3 Gestão

A gestão deve autorizar acessos privilegiados, aprovar alterações relevantes,
designar responsáveis pela revisão de registros e determinar a aplicação de
sanções em caso de uso indevido.

A gestão deve solicitar revisão periódica das contas, das chaves e das
autorizações, inclusive após desligamento, perda de dispositivo ou suspeita de
comprometimento.

## 5. Controle de acesso

### 5.1 Contas nominais e privilégio mínimo

**PSI-AC-01.** Todo acesso administrativo deve ser vinculado a uma conta nominal.
Contas compartilhadas não podem ser criadas ou utilizadas.

**PSI-AC-02.** O usuário deve receber somente os privilégios necessários à sua
função. A conta de deploy não deve possuir privilégios administrativos além dos
necessários à publicação autorizada.

**PSI-AC-03.** O acesso direto com a conta root deve ser bloqueado. As atividades
administrativas devem ser realizadas por uma conta nominal com elevação
controlada.

**PSI-AC-04.** A gestão deve desativar o acesso de uma pessoa no prazo definido
em procedimento interno imediatamente após desligamento, mudança de função ou
notificação de comprometimento.

### 5.2 Segregação entre tenants

**PSI-AC-05.** O acesso operacional deve ser limitado ao tenant ou aos tenants
necessários ao trabalho autorizado.

**PSI-AC-06.** Administradores não devem consultar, alterar ou exportar dados de
outro tenant sem autorização formal. Cópias locais devem ser limitadas ao
necessário e protegidas contra divulgação.

**PSI-AC-07.** A aplicação e o banco não devem confiar em uma rede ou usuário
como autorização suficiente para acessar dados de todos os tenants. Os controles
devem considerar identidade, função e escopo de dados.

### 5.3 Acesso privilegiado e SSH

**PSI-AC-08.** O SSH deve usar a porta configurada no laboratório e aceitar
somente origens administrativas autorizadas.

**PSI-AC-09.** O SSH deve exigir chave pública autenticada por chave privada
protegida. A autenticação por senha não deve ser usada para administração.

**PSI-AC-10.** O login direto de root não deve ser permitido. A lista de contas
autorizadas deve ser explicitamente registrada na configuração do SSH.

**PSI-AC-11.** As novas conexões SSH devem estar sujeitas a limite de taxa no
firewall para reduzir tentativas automatizadas e ataques de força bruta.

### 5.4 Gestão de chaves SSH e GPG

**PSI-AC-12.** Cada integrante deve possuir uma chave SSH própria. Chaves privadas
não podem ser compartilhadas, enviadas ao repositório ou copiada para evidências.

**PSI-AC-13.** O responsável pela chave deve protegê-la com dispositivo seguro,
senha ou mecanismo equivalente e revogá-la ou substituí-la após perda, troca de
responsabilidade ou suspeita de uso indevido.

**PSI-AC-14.** Arquivos de configuração sensíveis devem ser criptografados antes
da transferência. As chaves públicas GPG podem ser distribuídas no repositório;
as chaves privadas e os certificados de revogação não podem ser publicados.

**PSI-AC-15.** Antes da distribuição de uma chave GPG, o administrador deve
confirmar sua identidade e impressão digital por canal previamente confiável.

### 5.5 Revisão periódica

**PSI-AC-16.** A gestão deve revisar contas privilegiadas, contas de deploy,
chaves SSH, chaves GPG e autorizações em período definido no procedimento
operacional.

**PSI-AC-17.** A revisão deve registrar a identidade do responsável, a data, as
contas consideradas, os desvios encontrados e as ações corretivas. Contas sem
responsável nominal devem ser desativadas.

## 6. Auditoria e integridade

**PSI-AU-01.** O sistema deve registrar autenticações, recusas de autenticação,
alterações administrativas relevantes, comandos ou ações privilegiadas
disponibilizadas pelo mecanismo de auditoria e eventos de serviço.

**PSI-AU-02.** Os registros devem indicar data e hora, conta nominal, origem
aproximada do acesso, ação realizada e resultado. Logs não devem registrar
senhas, chaves privadas ou valores secretos.

**PSI-AU-03.** Os registros devem ser retidos pelo período definido pela gestão
e pela legislação aplicável. Até que esse período seja formalmente definido,
deve prevalecer o prazo registrado em procedimento operacional aprovado.

**PSI-AU-04.** Os registros devem ser protegidos contra alteração e exclusão
por usuários comuns. Somente contas autorizadas devem poder configurar o
armazenamento e revisar os registros.

**PSI-AU-05.** Os arquivos críticos, incluindo `/etc/passwd`, `/etc/shadow` e
as regras persistentes do firewall, devem ser comparados periodicamente com um
baseline autorizado por meio de verificação de integridade.

**PSI-AU-06.** Toda divergência do baseline deve gerar alerta visual ou em log.
O responsável pela operação deve iniciar contenção, registrar o ocorrido,
determinar a causa e restaurar somente uma versão conhecida e validada.

**PSI-AU-07.** O tratamento de um alerta de integridade deve preservar evidências
antes da alteração ou restauração, exceto quando a continuidade imediata exigir
medida de segurança. A alteração não deve ser removida silenciosamente.

**PSI-AU-08.** A gestão e os administradores devem revisar os registros em
periodicidade definida no procedimento operacional. Eventos suspeitos devem ser
investigados e escalados conforme o impacto.

**PSI-AU-09.** Logs usados em auditoria não devem ser reutilizados para testar
novos controles se contiverem dados pessoais ou secretos sem autorização.

## 7. Uso aceitável

**PSI-UA-01.** A conta administrativa e a conta de deploy devem ser usadas
somente para atividades relacionadas ao laboratório, à operação do SaaS e à
manutenção dos serviços autorizados.

**PSI-UA-02.** O ambiente de produção não deve ser usado para testes destrutivos,
varreduras não autorizadas, demonstrações pessoais ou treinamento sem aprovação.

**PSI-UA-03.** Credenciais não devem ser reutilizadas entre contas ou ambientes,
publicadas no repositório, inseridas em capturas ou registradas em documentação
e chamadas de comando.

**PSI-UA-04.** O administrador deve usar somente dispositivos gerenciados,
atualizados e protegidos por bloqueio de tela. Dispositivos particulares só
devem acessar o ambiente quando expressamente autorizados.

**PSI-UA-05.** É proibido desativar firewall, SSH, auditoria, verificação de
integridade ou outros controles para facilitar uma atividade não aprovada.

**PSI-UA-06.** É proibido alterar dados de tenants, regras de isolamento,
credenciais, configurações de rede ou scripts de deploy fora do procedimento de
mudança aprovado.

**PSI-UA-07.** É proibido compartilhar contas, chaves privadas, certificados de
revogação, tokens, senhas ou arquivos cifrados com destinatário não autorizado.

**PSI-UA-08.** Todo uso suspeito deve ser comunicado à gestão e ao responsável
pela segurança. A pessoa não deve apagar registros ou modificar evidências para
encobrir uma ação.

## 8. Conformidade e sanções

**PSI-CS-01.** Incidentes de não conformidade devem ser registrados, analisados
quanto ao impacto, atribuídos a um responsável pela correção e acompanhados até
a conclusão.

**PSI-CS-02.** Violações podem resultar em suspensão temporária de acesso,
revogação de chaves, reassessment das responsabilidades e aplicação das
sanções previstas em normas internas da organização ou em instrumentos
contratuais aplicáveis.

**PSI-CS-03.** Nenhuma pessoa deve se considerar autorizada por ausência de
verificação técnica. O uso indevido continua sujeito à revisão administrativa
mesmo quando o controle não detectar a ação imediatamente.

## 9. Rastreabilidade

| Diretriz | Controle técnico ou procedimento | Arquivo do repositório | Situação |
|---|---|---|---|
| PSI-AC-01, PSI-AC-02, PSI-AC-12 | Contas nominais e conta de deploy com privilégio mínimo | [PREENCHER após Etapas 4 e 6]: `infra/sshd/`, configuração efetiva e política de contas | Pendente |
| PSI-AC-03, PSI-AC-08, PSI-AC-09, PSI-AC-10 | Bloqueio de root, chave pública, `AllowUsers` e porta de SSH definida | [PREENCHER após Etapa 6]: configuração do `sshd_config` | Pendente |
| PSI-AC-05, PSI-AC-06, PSI-AC-07 | Restrição de dados por tenant e princípio de privilégio mínimo | [PREENCHER após Etapas 4 e 6]: procedimento e controle aplicado no banco | Pendente |
| PSI-AC-11 | Rate limiting de novas conexões SSH | [PREENCHER após Etapa 5]: `scripts/firewall.sh` e regras persistentes | Pendente |
| PSI-AC-13, PSI-AC-14, PSI-AC-15 | Gestão de chaves SSH e GPG, revogação e troca segura | [PREENCHER após Etapa 8]: `gpg/chaves-publicas/` e `gpg/exemplo/` | Pendente |
| PSI-AC-16, PSI-AC-17 | Revisão periódica de contas, chaves e autorizações | [PREENCHER após Etapa 4]: procedimento desta PSI | Pendente nesta etapa; revisão operacional futura |
| PSI-AU-01, PSI-AU-02 | Registro de autenticação e origem das operações | [PREENCHER após Etapas 6 e 7]: configuração de SSH e auditoria do sistema | Pendente |
| PSI-AU-03, PSI-AU-04 | Retenção, proteção e revisão dos registros | [PREENCHER após Etapa 7]: configuração de logs e permissões | Pendente |
| PSI-AU-05, PSI-AU-06, PSI-AU-07 | Verificação SHA-256 e resposta a alteração | [PREENCHER após Etapa 9]: `scripts/verifica-integridade.sh` e baseline | Pendente |
| PSI-AU-08, PSI-AU-09 | Revisão periódica e tratamento seguro de evidências | [PREENCHER após Etapas 7 e 10]: procedimento e `evidencias/README.md` | Pendente |
| PSI-UA-01, PSI-UA-02 | Uso restrito do ambiente e proibição de testes não autorizados | Este capítulo da PSI | Implementado documentalmente |
| PSI-UA-03, PSI-UA-04, PSI-UA-07 | Proteção de credenciais e dispositivos autorizados | [PREENCHER após Etapa 8]: procedimento de GPG e gestão de dispositivos | Pendente |
| PSI-UA-05 | Políticas e controles não devem ser desativados | [PREENCHER após Etapas 5, 6, 7 e 9]: scripts e configurações persistentes | Pendente |
| PSI-UA-06, PSI-UA-08 | Procedimentos de mudança, resposta e comunicação | [PREENCHER após Etapa 10]: testes e procedimento de incidente | Pendente |
| PSI-CS-01, PSI-CS-02, PSI-CS-03 | Registro de desvios e aplicação de sanções | Este capítulo da PSI | Implementado documentalmente |
| Restrição do PostgreSQL à LAN | Bind no endereço LAN e regra SCRAM-SHA-256 | `scripts/instala-servicos.sh`; `config/lab.env` | Implementado no laboratório |
| Evidência da restrição do PostgreSQL | Arquivo `pg_hba.conf` confirmado pelo laboratório | `evidencias/15-R2.1-postgresql-pg-hba.png` | Evidência disponível |
| Rede estática e rotas persistentes | Configuração Netplan e encaminhamento IPv4 | `scripts/aplica-rede.sh`; `infra/netplan/01-netcfg.yaml.tmpl`; `config/lab.env` | Implementado no laboratório |

## 10. Referências

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. **ABNT NBR ISO/IEC 27001:2022**:
segurança da informação, segurança cibernética e proteção à privacidade:
sistemas de gestão da segurança da informação: requisitos. Rio de Janeiro:
ABNT, 2022.

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. **ABNT NBR ISO/IEC 27002:2022**:
segurança da informação, segurança cibernética e proteção à privacidade:
controles de segurança da informação. Rio de Janeiro: ABNT, 2022.

GONÇALVES, Roitier Campos. **Aulas 01 a 10 de Segurança da Informação**
(fundamentos, roteamento, hardening, firewall e criptografia com GPG). Ceres:
Instituto Federal Goiano, 2026. Material da disciplina.
