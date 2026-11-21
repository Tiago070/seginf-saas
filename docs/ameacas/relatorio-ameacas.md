# Relatório de ameaças

## 1. Contexto do segmento

O ambiente analisado é uma plataforma de **Software como Serviço (SaaS)
multi-tenant**, na qual clientes compartilham uma plataforma e podem compartilhar
infraestrutura, aplicação e bancos relacionais. O servidor Ubuntu é responsável
pelos serviços da plataforma, pelo encaminhamento entre rede externa e rede
interna e pela hospedagem de um banco PostgreSQL. A administração remota e os
deploys são realizados por SSH na porta definida pelo projeto.

O relatório considera ameaças que podem comprometer a separação entre tenants,
as credenciais administrativas, a disponibilidade dos serviços e a integridade
de software implantado em produção. A análise adota os pilares de
Confidencialidade, Integridade e Disponibilidade (CID), além da rastreabilidade
das ações realizadas por administradores e processos de deploy. As medidas são
relacionadas aos controles que já existem no laboratório; quando a implementação
depende de uma etapa futura, isso é indicado sem tratar o controle como ativo.

Os dados do Relatório Global de Ameaças CrowdStrike 2026 usados nesta análise
devem ser conferidos no original antes da entrega final. Conforme o material
fornecido para conferência, o resumo executivo menciona 82% das detecções sem
malware (pág. 3) [CONFERIR: pág. 3] e abuso de contas válidas em 35% dos
incidentes na nuvem (pág. 5) [CONFERIR: pág. 5]. Esses valores não devem ser
citados como confirmados até a conferência das páginas correspondentes.

## 2. Vetor de ameaça 1: abuso de credenciais válidas e privilégios administrativos ou de deploy

### 2.1 Descrição

O primeiro vetor compreende o uso legítimo de credenciais, chaves, tokens ou
contas que foram comprometidas, reutilizadas ou concedidas de forma excessiva.
Ele inclui credenciais de usuários privilegiados, contas administrativas do
servidor, chaves SSH e credenciais usadas por processos de deploy. A relevância
decorre do acesso concedido pela identidade; o atacante não depende
necessariamente de exploração técnica para executar ações autorizadas.

O vetor é pertinente às orientações de autenticação e proteção de contas
disponíveis na Cartilha de Segurança para Internet (CERT.br, [s.d.]). A Aula 01
da disciplina também é indicada no plano como fonte sobre força bruta
(GONÇALVES, 2026, Aula 01, pág. [CONFERIR]). No resumo executivo da CrowdStrike
2026, os dados fornecidos para este trabalho mencionam abuso de contas válidas
em incidentes na nuvem (pág. 5) [CONFERIR: pág. 5].

### 2.2 Cadeia do ataque

1. Ocorre coleta, vazamento, reutilização ou comprometimento de uma senha,
   chave privada, token ou sessão administrativa; a obtenção também pode
   resultar de tentativas de força bruta bem-sucedidas.
2. O atacante utiliza a identidade válida para acessar o serviço SSH ou uma
   conta administrativa de deploy.
3. Após entrar, ele tenta ampliar privilégios, acessar arquivos privilegiados,
   obter credenciais armazenadas ou alterar configurações do servidor.
4. O acesso pode ser usado para consultar ou modificar dados relacionais,
   executar ações em mais de um tenant ou publicar uma alteração não autorizada.
5. A ação maliciosa pode ser confundida com atividade operacional legítima,
   dificultando a detecção sem registro e revisão adequada.

### 2.3 Pilares CID afetados

- **Confidencialidade:** credenciais válidas podem expor dados de tenants,
  arquivos de configuração e informações armazenadas no PostgreSQL.
- **Integridade:** um usuário privilegiado ou processo de deploy pode alterar
  configurações, dados e conteúdo aplicado em produção.
- **Disponibilidade:** ações indevidas podem interromper serviços, remover
  dados ou impedir o acesso legítimo à aplicação e ao banco.
- **Rastreabilidade:** alterações não atribuídas a uma identidade ou aprovação
  podem impedir a reconstrução do incidente.

### 2.4 Medidas preventivas

- Restringir o login SSH a contas administrativas explicitamente autorizadas.
- Bloquear login direto de root e autenticação por senha, admitindo apenas
  autenticação por chave pública.
- Utilizar chave dedicada a cada operador e a uma conta própria de deploy,
  com revogação rápida diante de perda ou desligamento.
- Aplicar privilégio mínimo, separando funções administrativas e de deploy.
- Centralizar registros de autenticação e alteração, com revisão periódica.
- Proteger credenciais de banco e secrets em arquivos ou cofres apropriados,
  com permissões restritas e sem armazenamento em repositórios ou evidências.
- Restringir o PostgreSQL à rede LAN e utilizar autenticação SCRAM-SHA-256,
  impedindo exposição direta pela WAN.
- Aplicar rate limiting às novas conexões SSH e restringir a origem de acesso
  pelo firewall.
- Revisar periodicamente os registros de autenticação e as permissões
  administrativas.

## 3. Vetor de ameaça 2: comprometimento da cadeia de suprimentos de software e do pipeline de deploy

### 3.1 Descrição

O segundo vetor abrange alterações maliciosas ou não confiáveis introduzidas
antes ou durante a implantação. Exemplos incluem pacote de sistema alterado,
dependência maliciosa, artefato substituído, commit não autorizado, chave de
assinatura comprometida ou instrução de deploy manipulada. O impacto pode se
propagar para todos os componentes que recebem o artefato afetado.

Esse vetor combina riscos sobre software, origem das versões e integridade da
implantação. A Cartilha de Segurança para Internet inclui orientação para
manter programas atualizados (CERT.br, [s.d.]). A relação entre confiança em
fornecedores, software legítimo e mecanismos de atualização é indicada no plano
do projeto como ponto de apoio no resumo executivo da CrowdStrike 2026; deve
ser confirmada nas páginas 2 e 3 [CONFERIR: págs. 2 e 3]. O mesmo resumo
informa, conforme dado fornecido para este trabalho, 82% das detecções sem
malware (pág. 3) [CONFERIR: pág. 3]. A verificação desse dado no original é
necessária antes da entrega final.

### 3.2 Cadeia do ataque

1. O agente malicioso compromete um repositório de pacotes, dependência,
   artefato de build, commit ou conta usada pelo pipeline.
2. Um componente ou atualização alterado entra no sistema por meio do gerenciador
   de pacotes ou do processo de deploy.
3. A implantação via SSH ou o procedimento automatizado envia o conteúdo ao
   servidor sem uma validação criptográfica independente.
4. O software alterado é executado com privilégios de serviço, administrativo ou
   de deploy.
5. A alteração pode propagar-se aos tenants, aos dados relacionais, às
   configurações ou às implantações seguintes.

### 3.3 Pilares CID afetados

- **Confidencialidade:** o software comprometido pode capturar credenciais,
  secrets ou dados acessíveis aos serviços.
- **Integridade:** o artefato substituído altera diretamente o conteúdo ou o
  comportamento autorizado da plataforma.
- **Disponibilidade:** uma atualização malformada ou maliciosa pode indisponibilizar
  serviços em toda a plataforma.
- **Rastreabilidade:** ausência de assinatura, hash e registro impede identificar
  a versão exata implantada e o responsável pela aprovação.

### 3.4 Medidas preventivas

- Obter pacotes e ferramentas apenas dos repositórios oficiais configurados pelo
  Ubuntu e manter o sistema atualizado.
- Revisar dependências, commits e alterações antes da implantação.
- Separar permissões de build e deploy, usando uma identidade específica e não
  compartilhada.
- Assinar artefatos e configurações sensíveis com GPG e validar a assinatura
  antes da implantação.
- Verificar SHA-256 dos arquivos críticos e das regras persistentes, com
  comparação contra baseline aprovado e alerta em caso de divergência.
- Restringir o acesso ao pipeline e às chaves de assinatura.
- Registrar o hash, a versão, o responsável e a aprovação de cada implantação.
- Aplicar restauração por snapshot ou procedimento testado após detectar
  alteração não autorizada.

## 4. Matriz de vetores, controles e evidências

Os parâmetros `PORTA_SSH` e `USUARIO_DEPLOY` em `config/lab.env` registram
valores planejados, mas não aplicam configuração ao `sshd` nem restringem uma
conta em execução. Da mesma forma, as medidas futuras abaixo não são descritas
como controles já implantados.

| Vetor | Medida | Controle implementado ou pendente (arquivo do repositório) | Requisito | Evidência |
|---|---|---|---|---|
| Credenciais válidas e privilégios administrativos/deploy | Restringir o PostgreSQL à LAN e exigir autenticação SCRAM-SHA-256 | `scripts/instala-servicos.sh` configura `listen_addresses` no IP LAN e regra SCRAM em `pg_hba.conf`; controle implementado | R1.1, R2.1 e R2.3 | `evidencias/15-R2.1-postgresql-pg-hba.png` |
| Credenciais válidas e privilégios administrativos/deploy | Manter a senha local de demonstração fora do repositório e restringir sua leitura à conta root | `scripts/instala-servicos.sh` gera a senha e a guarda em `/root/.saas-db-senha` com modo `600`; controle implementado | R1.1 | Evidência operacional: `sudo stat -c '%a %U:%G %n' /root/.saas-db-senha`, sem exibir o conteúdo |
| Credenciais válidas e privilégios administrativos/deploy | Restringir contas SSH, bloquear root e exigir chave pública | `scripts/hardening-ssh.sh`, `infra/sshd/00-saas-hardening.conf.tmpl` e a configuração efetiva aplicam porta 22022, `AllowUsers` e chave pública; controle implementado | R1.1 e R2.5 | `evidencias/30-R2.5-ssh-config-efetiva.png`, `31-R2.5-ssh-root-bloqueado.png`, `33-R2.5-ssh-chave-tiago.png` |
| Credenciais válidas e privilégios administrativos/deploy | Limitar novas conexões SSH e suas origens | `scripts/firewall.sh` aplica política DROP, origem da LAN e limite de novas conexões SSH; controle implementado | R1.1, R2.2, R2.3 e R2.4 | `evidencias/16-R2.2-R2.3-R2.4-firewall-iptables-S.png`, `32-R2.2-R2.3-R2.4-R2.5-nmap-depois-firewall.png` |
| Credenciais válidas e privilégios administrativos/deploy | Revisar registros de autenticação e permissões administrativas | O capítulo da PSI define responsabilidades e revisão; `infra/sshd/` e `/var/log/auth.log` fornecem o registro operacional; controle parcialmente automatizado | R1.1 e R1.2 | `docs/psi/capitulo-psi.md`, `evidencias/31-R2.5-ssh-root-bloqueado.png` |
| Cadeia de suprimentos e pipeline de deploy | Atualizar o índice de pacotes antes da instalação dos serviços | `scripts/instala-servicos.sh` executa `apt-get update`; procedimento implementado, mas não comprova a integridade do pipeline nem de artefatos específicos | R1.1 e R2.6 | `evidencias/11-etapa1-srv-saas-internet-apt-update.png` |
| Cadeia de suprimentos e pipeline de deploy | Assinar artefatos e validar a assinatura antes da implantação | `gpg/chaves-publicas/grupo7-publicas.asc` reúne as chaves públicas, com assinaturas cruzadas localmente verificadas; controle implementado para identidade GPG | R1.1 e R3.1 | `evidencias/21-R3.1-E3-E4-GPG.png`, `22-R3.1-assinaturas-GPG.txt` |
| Cadeia de suprimentos e pipeline de deploy | Calcular e validar hashes de arquivos críticos e regras de firewall | `scripts/verifica-integridade.sh` calcula SHA-256 e gera alerta e log; controle implementado | R1.1 e R3.2 | `evidencias/23-R3.2-agendamento-integridade.png` a `29-R3.2-restauracao-firewall-integridade.png` |
| Cadeia de suprimentos e pipeline de deploy | Revisar dependências, restringir a conta de deploy e registrar aprovações | `infra/sshd/` restringe usuários, enquanto a PSI define revisão periódica; controle parcialmente operacional | R1.1, R1.2 e R2.5 | `docs/psi/capitulo-psi.md`, `evidencias/30-R2.5-ssh-config-efetiva.png` |
| Cadeia de suprimentos e pipeline de deploy | Restaurar o serviço a partir de uma versão conhecida após alteração indevida | A cópia do firewall foi restaurada e a linha de base foi atualizada após teste autorizado; procedimento implementado | R1.1 | `evidencias/28-R3.2-teste-firewall-integridade.png`, `29-R3.2-restauracao-firewall-integridade.png` |

## 5. Referências

CENTRO DE ESTUDOS, RESPOSTA E TRATAMENTO DE INCIDENTES DE SEGURANÇA NO BRASIL
(CERT.br). **Cartilha de Segurança para Internet**. São Paulo: Comitê Gestor da
Internet no Brasil, [s.d.]. Disponível em: https://cartilha.cert.br/.

CROWDSTRIKE. **Relatório Global de Ameaças 2026**: resumo executivo. [S.l.]:
CrowdStrike, 2026. Material da disciplina.

GONÇALVES, Roitier Campos. **Aulas 01 a 10 de Segurança da Informação**
(fundamentos, roteamento, hardening, firewall e criptografia com GPG). Ceres:
Instituto Federal Goiano, 2026. Material da disciplina.
