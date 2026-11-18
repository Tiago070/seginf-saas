# Decisão dos vetores de ameaça

## 1. Vetores selecionados

Foram selecionados dois vetores por serem coerentes com o segmento SaaS
multi-tenant, com a arquitetura adotada e com o estágio de implantação definido
no projeto:

1. **Abuso de credenciais válidas e de acesso administrativo ou de deploy:** o
   ambiente concentra identidades privilegiadas em uma estação administrativa,
   em SSH e em processos de publicação.
2. **Comprometimento da cadeia de suprimentos de software e do pipeline de
   deploy:** o servidor recebe pacotes, atualizações, configurações e artefatos
   que podem alterar o estado da plataforma.

O primeiro vetor foi escolhido porque credenciais válidas permitem burlar
controles técnicos projetados para ameaças externas e operar como atividade
administrativa legítima. Em uma plataforma multi-tenant, esse acesso pode atingir
dados ou configurações de vários clientes. A existência de SSH e de deploy torna
o vetor diretamente relacionado à topologia e às funções de operação.

O segundo vetor foi escolhido porque o sistema depende de software de terceiros,
repositórios de pacotes, scripts próprios e uma sequência de implantação via
SSH. Uma alteração introduzida antes da implantação pode ser replicada nos
componentes ou tenants afetados. O apoio específico do resumo executivo da
CrowdStrike sobre confiança em fornecedores, software legítimo e atualizações
está indicado no plano do projeto para as páginas 2 e 3 e permanece a conferir
[CONFERIR: págs. 2 e 3]. As medidas de GPG e SHA-256 são previstas em etapas
posteriores, não controles já ativos.

O resumo executivo da CrowdStrike 2026 traz, segundo os dados fornecidos para
este trabalho, abuso de contas válidas em 35% dos incidentes na nuvem (pág. 5)
[CONFERIR: pág. 5] e 82% das detecções sem malware (pág. 3) [CONFERIR: pág. 3].
As orientações de autenticação da Cartilha de Segurança para Internet são
pertinentes ao primeiro vetor (CERT.br, [s.d.]). A Aula 01 é apontada no plano
como material sobre força bruta (GONÇALVES, 2026, Aula 01, pág. [CONFERIR]).

## 2. Vetores considerados e descartados

### 2.1 Varredura de portas

A varredura foi considerada, mas descartada como vetor principal. Ela é uma
técnica de reconhecimento utilizada para identificar serviços expostos e constitui
atividade relevante para testes de firewall e Nmap. Porém, a varredura por si só
não executa alteração nem comprometimento.

No projeto, a varredura será tratada como técnica de validação dos requisitos
R2.2, R2.3 e R2.4, por meio do registro da linha de base e da redução da
superfície exposta. Ela pode apoiar os vetores selecionados, mas não representa
um objeto principal de ataque em um SaaS multi-tenant.

### 2.2 Ataques DDoS

Ataques de Negação de Serviço Distribuída foram considerados devido ao risco
direto à disponibilidade. Contudo, o laboratório não dispõe de infraestrutura
de mitigação em escala, provedores transitórios ou métricas de capacidade real,
elementos necessários para uma análise técnica completa desse vetor.

Nesse contexto, DDoS é tratado como necessidade operacional periférica e será
limitado à configuração de rate limiting definida pelo requisito R2.4. Não foi
selecionado como vetor principal porque o trabalho deve analisar ameaças
específicas da identidade e da cadeia de implantação, e não apenas o volume de
tráfego.

### 2.3 Exposição direta do banco de dados

A exposição indevida do banco de dados foi considerada e parcialmente descartada
como vetor independente. Ela permanece relevante porque PostgreSQL guarda dados
relacionais utilizados pela plataforma. Entretanto, a ameaça já é tratada como
parte da proteção do perímetro e da redução da superfície de ataque.

A configuração existente vincula PostgreSQL ao endereço LAN, restringe o
`pg_hba.conf` à rede local e usa autenticação SCRAM-SHA-256. Como risco
principal, a exposição é tratada como condição de acesso aos dados relacionada
a credenciais ou configuração incorreta, e não como um terceiro vetor
independente neste recorte. O vínculo LAN e a autenticação SCRAM-SHA-256 já
estão implementados por `scripts/instala-servicos.sh` e registrados em
`evidencias/15-R2.1-postgresql-pg-hba.png`. A proteção por firewall ainda depende
da Etapa 5 e permanece pendente.

## 3. Critérios da decisão

Os vetores selecionados atendem aos seguintes critérios:

- possuem relação direta com o contexto SaaS multi-tenant;
- exploram caminhos presentes na arquitetura: SSH, identidades privilegiadas,
  bancos relacionais e cadeia de implantação;
- permitem medidas preventivas verificáveis no repositório;
- possuem evidências que podem ser produzidas em etapas posteriores;
- são sustentados pelas diretrizes do NIC.br e do CERT.br e pelo resumo executivo
  da CrowdStrike 2026.

Os vetores descartados não foram considerados irrelevantes. Eles foram
reposicionados como técnicas de validação, requisito de disponibilidade ou
condição de exposição associada a um vetor principal.

## 4. Referências

CENTRO DE ESTUDOS, RESPOSTA E TRATAMENTO DE INCIDENTES DE SEGURANÇA NO BRASIL
(CERT.br). **Cartilha de Segurança para Internet**. São Paulo: Comitê Gestor da
Internet no Brasil, [s.d.]. Disponível em: https://cartilha.cert.br/.

CROWDSTRIKE. **Relatório Global de Ameaças 2026**: resumo executivo. [S.l.]:
CrowdStrike, 2026. Material da disciplina.

GONÇALVES, Roitier Campos. **Aulas 01 a 10 de Segurança da Informação**
(fundamentos, roteamento, hardening, firewall e criptografia com GPG). Ceres:
Instituto Federal Goiano, 2026. Material da disciplina.
