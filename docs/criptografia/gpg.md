# Gestão de chaves GPG

## Objetivo e decisão pendente

Cada integrante deve possuir um par de chaves GPG, conferir as impressões
digitais dos demais por um canal independente, assinar as chaves conferidas e
trocar um arquivo de configuração fictício cifrado e assinado.

O algoritmo, o tamanho e a validade ainda estão como `DEFINIR` em
`docs/decisoes.md`. O grupo deve registrar a escolha e justificativa antes de
gerar as chaves. A aula apresenta DSA e ElGamal; alternativas atuais incluem
Ed25519 com subchave de cifra compatível ou RSA com tamanho adequado. Não
misture algoritmos sem justificar a compatibilidade com a versão de GnuPG usada
nas VMs.

## Geração, conferência e exportação

Em cada dispositivo pessoal, cada integrante executa:

```bash
gpg --full-generate-key
gpg --list-keys --with-fingerprint <EMAIL_DO_INTEGRANTE>
gpg --armor --export <EMAIL_DO_INTEGRANTE> > gpg/chaves-publicas/<usuario>.asc
```

Escolha o algoritmo e a validade já registrados em `docs/decisoes.md`, associe
a identidade real do integrante e proteja a chave privada com uma frase-senha.
Chaves privadas e frases-senha ficam fora do repositório. Somente as
exportações públicas `.asc` podem ser versionadas.

Cada integrante importa as chaves públicas dos demais e compara a impressão
digital completa por chamada de voz ou outro canal independente:

```bash
gpg --import gpg/chaves-publicas/<usuario>.asc
gpg --fingerprint <EMAIL_DO_OUTRO_INTEGRANTE>
gpg --sign-key <EMAIL_DO_OUTRO_INTEGRANTE>
```

Depois das assinaturas, exporte novamente as chaves públicas assinadas e
compartilhe-as pelo repositório. A opção `export-local-sigs` inclui as
assinaturas locais na exportação:

```bash
gpg --armor --export-options export-local-sigs --export <EMAIL_DO_INTEGRANTE> \
  > gpg/chaves-publicas/<usuario>-assinada.asc
```

Ao final, exporte as três chaves públicas do grupo:

```bash
gpg --armor --export-options export-local-sigs --export \
  <EMAIL_TIAGO> <EMAIL_LUANNA> <EMAIL_FELIPE> \
  > gpg/chaves-publicas/grupo7-publicas.asc
gpg --list-sigs
```

## Cifragem, assinatura e troca

O arquivo `gpg/exemplo/credenciais-exemplo.env` contém somente valores
explicitamente fictícios. Depois de confirmar que a chave pública do destinatário
foi conferida:

```bash
gpg --output gpg/exemplo/credenciais-exemplo.env.gpg \
  --encrypt --sign --recipient <EMAIL_DO_DESTINATARIO> \
  gpg/exemplo/credenciais-exemplo.env
```

Transfira o arquivo cifrado ao destinatário pela porta SSH configurada:

```bash
scp -P "$(source config/lab.env; printf '%s' "$PORTA_SSH")" \
  gpg/exemplo/credenciais-exemplo.env.gpg \
  <usuario>@<IP_LAN_SERVIDOR>:/tmp/
```

O destinatário decifra e confere a assinatura:

```bash
gpg --output /tmp/credenciais-exemplo-decifrado.env \
  --decrypt /tmp/credenciais-exemplo.env.gpg
```

O comando deve indicar o resultado da verificação da assinatura. Para testar
uma assinatura destacada separadamente:

```bash
gpg --armor --detach-sign \
  --output gpg/exemplo/credenciais-exemplo.env.asc \
  gpg/exemplo/credenciais-exemplo.env
gpg --verify gpg/exemplo/credenciais-exemplo.env.asc \
  gpg/exemplo/credenciais-exemplo.env
```

Uma tentativa de decifrar com uma identidade sem a chave privada do destinatário
deve falhar. Registre a mensagem de falha sem exportar ou exibir qualquer chave
privada.

## Evidências e segurança

Registre a exportação pública do grupo, `gpg --list-sigs`, a impressão digital
conferida, a decifragem e a verificação de assinatura. A captura não deve
mostrar frases-senha nem material privado. O arquivo de exemplo é fictício e
não pode conter credenciais usadas em qualquer sistema.
