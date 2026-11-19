# Hardening do sistema operacional

## Escopo

O procedimento cobre permissões pontuais, inventário de portas, serviços e
pacotes, remoção somente de itens revisados pela equipe e atualização do
Ubuntu. O script não altera permissões recursivamente, não remove dependências
automaticamente e não desativa serviços que sustentam SSH, firewall, logs,
Nginx ou PostgreSQL.

## Execução

No console do `srv-saas`, com a pasta do repositório montada:

```bash
sudo bash scripts/hardening-so.sh --relatorio
```

O relatório somente consulta o sistema e salva o resultado em
`/var/log/saas-hardening/`. Revise as listas de pacotes e serviços instalados.
Somente depois de decidir, preencha `SO_PACOTES_REMOVER` e
`SO_SERVICOS_DESATIVAR` em `config/lab.env`. Valores vazios significam que
nenhum pacote ou serviço foi aprovado para remoção ou desativação.

Faça um snapshot antes de aplicar alterações. Depois execute:

```bash
sudo bash scripts/hardening-so.sh --aplicar
```

O script pede confirmação quando há itens nas listas, ajusta somente os
arquivos descritos abaixo, remove os pacotes aprovados, desativa os serviços
aprovados e executa `apt-get update` e `apt-get upgrade`. Ele não foi executado
contra a VM neste repositório. Reinicie o servidor e valide os serviços antes
de registrar o aceite.

## Permissões aplicadas

| Caminho | Modo | Proprietário | Justificativa |
|---|---:|---|---|
| `/etc/passwd` | `644` | `root:root` | Permite leitura de contas sem permitir alteração por usuários comuns. |
| `/etc/group` | `644` | `root:root` | Permite consulta de grupos; alterações ficam restritas a root. |
| `/etc/shadow` | `640` | `root:shadow` | Restringe a leitura dos hashes de senha ao root e ao grupo de sistema. |
| `/etc/gshadow` | `640` | `root:shadow` | Restringe a leitura dos dados protegidos de grupos. |
| `/etc/sudoers` | `440` | `root:root` | Permite leitura pelo mecanismo sudo e impede escrita comum. |
| `/etc/ssh/sshd_config` | `600` | `root:root` | Restringe a leitura e a escrita da configuração SSH ao root. |
| `/etc/crontab` | `644` | `root:root` | Mantém leitura das tarefas e restringe sua alteração ao root. |
| `/var/log/auth.log`, se presente | `640` | `syslog:adm` | Restringe a leitura dos registros de autenticação. |

O relatório também registra as permissões de `/etc` e `/var/log`. O script não
altera esses diretórios recursivamente. Se um arquivo não existir, ele é
registrado no relatório e ignorado.

## Inventário e técnicas avaliadas

O relatório registra `ss -tlnp`, serviços habilitados, pacotes instalados e
permissões dos arquivos críticos antes e depois. Também registra:

| Técnica | Critério de avaliação |
|---|---|
| TCP Wrappers | `ldd /usr/sbin/sshd`; se `libwrap` não aparecer, registrar como não aplicável ao SSH instalado. |
| `/etc/securetty` | Registrar presença ou ausência; não criar o arquivo se não existir. |
| Bloqueio de `ctrl-alt-del.target` | Registrar o estado atual. Não mascarar sem decisão e teste de recuperação. |
| Senha de root | Registrar o estado com `passwd -S root`; o acesso SSH direto de root é tratado na Etapa 6. |

Não há senha no GRUB nesta etapa, pois é um diferencial opcional e pode impedir
a inicialização se configurado incorretamente.

## Evidências

Guarde os relatórios `antes-*.txt` e `depois-*.txt`, a saída do comando `stat`
dos caminhos acima e o resultado de `apt-get -s upgrade` sem linhas `Inst`.
Após reiniciar, capture `ss -tlnp`, `systemctl --failed` e a disponibilidade
dos serviços usados no laboratório.
