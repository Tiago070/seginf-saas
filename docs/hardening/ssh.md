# Hardening do SSH

## Objetivo

Esta configuração restringe o acesso privilegiado ao servidor aos usuários
nominais e à conta de deploy autorizados, pela rede administrativa definida no
laboratório. O objetivo não é apenas alterar a porta: é associar identidade,
chave criptográfica, origem de rede e registro de autenticação.

## Parâmetros do escopo R2.5

| Diretiva | Valor | Risco mitigado |
|---|---|---|
| `Port` | Valor de `PORTA_SSH` em `config/lab.env` | Evita manter o serviço na porta padrão; não substitui autenticação nem firewall. |
| `PermitRootLogin` | `no` | Impede autenticação SSH direta como `root` e favorece rastreabilidade por conta nominal. |
| `PasswordAuthentication` | `no` | Impede que a senha seja usada pelo método de autenticação SSH por senha. |
| `KbdInteractiveAuthentication` | `no` | Desativa autenticação interativa por PAM, para que ela não contorne a exigência de chave. |
| `PubkeyAuthentication` | `yes` | Habilita autenticação baseada em chave pública, exigida para o acesso nominal. |
| `AuthenticationMethods` | `publickey` | Exige que a autenticação da sessão seja concluída por chave pública. |
| `AllowUsers` | Contas nominais e `deploy`, restritos à origem definida em `LAN_REDE` e, opcionalmente, `DEPLOY_ORIGEM` | Recusa contas não autorizadas e origens fora da política. |

O modelo contém somente esses parâmetros. Os controles complementares citados
no plano do projeto foram omitidos para manter a configuração no mínimo
necessário ao requisito R2.5.

## Formato de `AllowUsers`

O modelo gera entradas no formato `usuario@origem`. Cada administrador declarado
em `USUARIOS_ADMIN` recebe uma entrada com `LAN_REDE`. A conta
`USUARIO_DEPLOY` recebe a entrada em `LAN_REDE` e uma segunda entrada em
`DEPLOY_ORIGEM`, caso uma origem seja definida.

Exemplo somente ilustrativo, não substituto de `config/lab.env`:

```text
AllowUsers tiago@10.10.10.0/24 luanna@10.10.10.0/24 felipe@10.10.10.0/24 deploy@10.10.10.0/24
```

As entradas reais devem ser geradas pelo script a partir de `LAN_REDE`,
`USUARIOS_ADMIN`, `USUARIO_DEPLOY` e `DEPLOY_ORIGEM`. A conta administrativa
`deploy` não deve ser usada por uma pessoa no lugar de uma conta nominal.

## Por que uma porta diferente não é controle suficiente

Alterar `Port` reduz varreduras automatizadas contra 22, mas não impede um
atacante que identifique a porta por varredura ou que já possua uma credencial
válida. O controle eficaz combina porta restrita, `AllowUsers`, autenticação por
chave, bloqueio de senha, firewall e registros detalhados.

Uma tentativa sem chave não resolve apenas porque a porta mudou. Os parâmetros `PasswordAuthentication no` e
`KbdInteractiveAuthentication no` desativam autenticação por senha.
`AuthenticationMethods publickey` exige que a sessão use uma chave pública.
`AllowUsers` restringe usuários e origens; o firewall complementa essa regra na
rede.

## Geração de chave Ed25519

Cada administrador deve gerar uma chave Ed25519 no próprio dispositivo:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/saas_<usuario> -C "saas-<usuario>"
```

Substitua `<usuario>` pelo nome nominal real. Proteja a chave privada com uma
senha forte e nunca registre a chave privada no Git. Confirme a impressão
digital antes de instalar:

```bash
ssh-keygen -lf ~/.ssh/saas_<usuario>.pub
```

Envie somente o arquivo público:

```text
infra/sshd/chaves-publicas/<usuario>.pub
```

Cada arquivo público deve conter uma linha Ed25519. O script aborta antes de
criar contas, alterar `authorized_keys` ou substituir a configuração se qualquer
usuário de `AllowUsers` não tiver uma chave pública válida.

A chave privada da estação administrativa continua no dispositivo do usuário.
O arquivo público pode ser versionado, mas não substitui a conferência da
impressão digital e da identidade que o gerou.

## Processo de aplicação

Mantém-se uma sessão SSH atual aberta até que uma segunda sessão seja testada.
A aplicação remove `ssh.socket`, caso esteja habilitado ou ativo, e mantém
`ssh.service` ativo no modo tradicional. Isso é necessário porque o socket pode
controlar a porta antes que a diretiva `Port` do drop-in seja lida.

Antes da aplicação, consulte o estado atual:

```bash
systemctl is-enabled ssh.socket
systemctl is-enabled ssh.service
ss -tlnp | grep ssh
sudo sshd -t
```

Execute pelo console ou com uma sessão de recuperação disponível:

```bash
cd <CAMINHO_DO_REPOSITORIO>
sudo bash scripts/hardening-ssh.sh
```

O script verifica todas as chaves públicas antes da alteração. Em seguida, cria
as contas ausentes, instala `authorized_keys` com permissões `700` no diretório
`.ssh` e `600` no arquivo, renderiza o drop-in com prefixo `00`, valida
`sshd -t`, reinicia o serviço e confirma as portas. A aplicação substitui o
`authorized_keys` das contas indicadas pelas chaves do projeto.

## Por que o caso `ssh.socket`

Ubuntu 24.04 e versões posteriores podem iniciar o SSH por `ssh.socket`, em vez
de iniciá-lo diretamente pelo `ssh.service`. Nesse modo, o sistema pode escutar
a porta padrão antes de o processo `sshd` aplicar a diretiva `Port`.

Por isso, o script desabilita `ssh.socket` quando ele está ativo ou habilitado e habilita
`ssh.service`. Essa escolha faz a diretiva `Port ${PORTA_SSH}` ser usada pela
execução tradicional. O script não altera sockets de outros serviços.

## Confirmação e reversão

Confirme a configuração efetiva:

```bash
sudo ss -tlnp | grep ssh
sudo sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|authenticationmethods|allowusers) '
```

Teste por uma segunda sessão:

```bash
ssh -i ~/.ssh/saas_<usuario> -p "$(source config/lab.env; printf '%s' "$PORTA_SSH")" <usuario>@<IP_LAN_SERVIDOR>
```

Os testes negativos devem ser confirmados por cliente e por `/var/log/auth.log`:

```bash
ssh -p "$(source config/lab.env; printf '%s' "$PORTA_SSH")" root@<IP_SERVIDOR>
ssh -o BatchMode=yes -o PreferredAuthentications=password -o PubkeyAuthentication=no -p "$(source config/lab.env; printf '%s' "$PORTA_SSH")" <usuario>@<IP_SERVIDOR>
ssh -p 22 <usuario>@<IP_SERVIDOR>
```

Confirme também no servidor que `sshd -T` mostra os parâmetros esperados e que
`ss -tlnp` não apresenta um listener na porta 22. Registre a tentativa como root
no cliente e a linha correspondente em `/var/log/auth.log`.

Para restaurar o último backup:

```bash
sudo bash scripts/hardening-ssh.sh --reverter
sudo sshd -t
sudo ss -tlnp | grep ssh
```
