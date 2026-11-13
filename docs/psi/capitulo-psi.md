## 4. Diretrizes

### 4.1 Controle de acesso

**4.1.1** Cada administrador usa uma conta própria, com o seu nome. Não é permitido compartilhar conta.

**4.1.2** Cada pessoa recebe só o acesso que precisa para o seu trabalho (privilégio mínimo).

**4.1.3** O banco de dados só é acessado pela rede interna (LAN), para que os dados de um cliente não fiquem expostos para a internet.

**4.1.4** O acesso privilegiado ao servidor é feito por SSH, só com chave. Entrar com senha ou direto como root é proibido.

**4.1.5** Só as contas autorizadas podem entrar por SSH, e a conta de deploy é usada somente para o deploy.

**4.1.6** Os acessos são revisados periodicamente, e quem não precisa mais de um acesso o perde.

### 4.2 Auditoria

**4.2.1** As tentativas de login são registradas nos logs de autenticação do servidor.

**4.2.2** Os logs são guardados por [definir o prazo com o grupo].

**4.2.3** Os logs só podem ser alterados por quem tem permissão para isso, para proteger o registro contra alteração.

**4.2.4** Os arquivos `/etc/passwd`, `/etc/shadow` e as regras salvas do firewall são conferidos periodicamente com SHA-256.

**4.2.5** Quando há um alerta de alteração, a equipe investiga. Se a mudança foi legítima, a conferência é atualizada. Se não foi, é tratada como incidente.

### 4.3 Uso aceitável

**4.3.1** O ambiente de produção é usado só para atividades autorizadas.

**4.3.2** Senhas, chaves privadas e tokens são pessoais e não são compartilhados nem ## 4. Diretrizes

### 4.1 Controle de acesso

**4.1.1** Cada administrador usa uma conta própria, com o seu nome. Não é permitido compartilhar conta.

**4.1.2** Cada pessoa recebe só o acesso que precisa para o seu trabalho (privilégio mínimo).

**4.1.3** O banco de dados só é acessado pela rede interna (LAN), para que os dados de um cliente não fiquem expostos para a internet.

**4.1.4** O acesso privilegiado ao servidor é feito por SSH, só com chave. Entrar com senha ou direto como root é proibido.

**4.1.5** Só as contas autorizadas podem entrar por SSH, e a conta de deploy é usada somente para o deploy.

**4.1.6** Os acessos são revisados periodicamente, e quem não precisa mais de um acesso o perde.

### 4.2 Auditoria

**4.2.1** As tentativas de login são registradas nos logs de autenticação do servidor.

**4.2.2** Os logs são guardados por [definir o prazo com o grupo].

**4.2.3** Os logs só podem ser alterados por quem tem permissão para isso, para proteger o registro contra alteração.

**4.2.4** Os arquivos `/etc/passwd`, `/etc/shadow` e as regras salvas do firewall são conferidos periodicamente com SHA-256.

**4.2.5** Quando há um alerta de alteração, a equipe investiga. Se a mudança foi legítima, a conferência é atualizada. Se não foi, é tratada como incidente.

### 4.3 Uso aceitável

**4.3.1** O ambiente de produção é usado só para atividades autorizadas.

**4.3.2** Senhas, chaves privadas e tokens são pessoais e não são compartilhados nem colocados no repositório Git.

**4.3.3** Arquivos sensíveis são trocados entre administradores de forma criptografada, com GPG.

**4.3.4** Quem descumprir estas regras pode ter o acesso ao ambiente suspenso ou removido.

## 5. Rastreabilidade: diretriz → controle

| Diretriz | Controle técnico ou procedimento | Onde está |
|---|---|---|
| 4.1.1 | Conta nominal por integrante | Etapa 6 |
| 4.1.2 | Permissões ajustadas | Etapa 7 |
| 4.1.3 | Regra do firewall: banco (5432) só pela LAN | Etapa 5 |
| 4.1.4 | `PasswordAuthentication no`, `PermitRootLogin no`, `PubkeyAuthentication yes` | Etapa 6 |
| 4.1.5 | `AllowUsers` com as contas nominais e `deploy` | Etapa 6 |
| 4.1.6 | Procedimento de revisão de acessos | Procedimento |
| 4.2.1 | Registro de autenticação em `/var/log/auth.log` | Etapa 6 |
| 4.2.2 | Procedimento de retenção | Procedimento |
| 4.2.3 | Permissões em `/var/log/` | Etapa 7 |
| 4.2.4 | `verifica-integridade.sh` com SHA-256 e execução agendada | Etapa 9 |
| 4.2.5 | Atualização da linha de base e tratamento do alerta | Etapa 9 |
| 4.3.1 | Procedimento de uso do ambiente | Procedimento |
| 4.3.2 | Conferência de `git diff --cached` antes do commit | Etapa 8 |
| 4.3.3 | Chaves GPG e arquivo cifrado | Etapa 8 |
| 4.3.4 | Sanção prevista na política | Procedimento |

## Referências

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. **ABNT NBR ISO/IEC 27001:2022**: segurança da informação, segurança cibernética e proteção à privacidade: sistemas de gestão da segurança da informação: requisitos. Rio de Janeiro: ABNT, 2022.

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. **ABNT NBR ISO/IEC 27002:2022**: segurança da informação, segurança cibernética e proteção à privacidade: controles decolocados no repositório Git.

**4.3.3** Arquivos sensíveis são trocados entre administradores de forma criptografada, com GPG.

**4.3.4** Quem descumprir estas regras pode ter o acesso ao ambiente suspenso ou removido.

## 5. Rastreabilidade: diretriz → controle

| Diretriz | Controle técnico ou procedimento | Onde está |
|---|---|---|
| 4.1.1 | Conta nominal por integrante | Etapa 6 |
| 4.1.2 | Permissões ajustadas | Etapa 7 |
| 4.1.3 | Regra do firewall: banco (5432) só pela LAN | Etapa 5 |
| 4.1.4 | `PasswordAuthentication no`, `PermitRootLogin no`, `PubkeyAuthentication yes` | Etapa 6 |
| 4.1.5 | `AllowUsers` com as contas nominais e `deploy` | Etapa 6 |
| 4.1.6 | Procedimento de revisão de acessos | Procedimento |
| 4.2.1 | Registro de autenticação em `/var/log/auth.log` | Etapa 6 |
| 4.2.2 | Procedimento de retenção | Procedimento |
| 4.2.3 | Permissões em `/var/log/` | Etapa 7 |
| 4.2.4 | `verifica-integridade.sh` com SHA-256 e execução agendada | Etapa 9 |
| 4.2.5 | Atualização da linha de base e tratamento do alerta | Etapa 9 |
| 4.3.1 | Procedimento de uso do ambiente | Procedimento |
| 4.3.2 | Conferência de `git diff --cached` antes do commit | Etapa 8 |
| 4.3.3 | Chaves GPG e arquivo cifrado | Etapa 8 |
| 4.3.4 | Sanção prevista na política | Procedimento |

## Referências

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. **ABNT NBR ISO/IEC 27001:2022**: segurança da informação, segurança cibernética e proteção à privacidade: sistemas de gestão da segurança da informação: requisitos. Rio de Janeiro: ABNT, 2022.

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. **ABNT NBR ISO/IEC 27002:2022**: segurança da informação, segurança cibernética e proteção à privacidade: controles de