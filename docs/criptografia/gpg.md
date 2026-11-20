# Gestão de chaves GPG

## Objetivo e decisão registrada

Cada integrante deve possuir um par de chaves GPG, conferir as impressões
digitais dos demais por um canal independente, assinar as chaves conferidas e
trocar um arquivo de configuração fictício cifrado.

O grupo decidiu usar Ed25519 para assinatura, uma subchave CV25519 para cifra
e validade de 12 meses. A decisão e as alternativas consideradas estão em
`docs/decisoes.md`. Na máquina Windows centralizada, o GnuPG 2.5.24 lista as
curvas `cv25519` e `ed25519` em `gpg --with-colons --list-config curve`. Se o
fluxo passar a usar outro dispositivo, confira a compatibilidade antes de gerar
chaves nele. A aula apresenta DSA e ElGamal; a escolha do grupo é diferente.
Para a chave criada em 20/11/2026, o GnuPG informou expiração em 15/11/2027.
O grupo aceitou essa data exibida como validade de 12 meses.

O grupo também aprovou centralizar os pares na máquina Windows do Tiago. Isso
concentra o armazenamento e aumenta o impacto de um comprometimento dessa
máquina. Cada integrante deve digitar pessoalmente uma frase-senha distinta
para sua própria chave, sem revelá-la aos demais. As chaves privadas permanecem
no perfil local do GnuPG e nunca são exportadas para o repositório.

## Geração, assinatura e exportação

Cada integrante gera e usa sua própria chave na máquina Windows centralizada,
digitando pessoalmente sua frase-senha. Para cada integrante, execute:

```powershell
gpg --full-generate-key
```

No menu, escolha ECC para assinatura e cifra e a curva Curve 25519. Informe a
validade `12m`, a identidade real do titular e a frase-senha definida e digitada
por ele. Não envie identidades ou frases-senha pelo chat. A chave principal
deve aparecer como Ed25519 e a subchave como CV25519.

Depois que os três pares existirem, cada chave deve receber uma assinatura de
outro integrante. Para reduzir operações, cada titular assina uma chave
atribuída pela equipe, após conferir a impressão digital com o titular da
chave. Use a impressão digital completa para identificar assinante e chave:

```powershell
gpg --local-user FPR_ASSINANTE --sign-key FPR_ASSINADO
```

Substitua `FPR_ASSINANTE` e `FPR_ASSINADO` pelas impressões digitais completas,
sem os sinais `<` e `>`. Confira as assinaturas e exporte uma única cópia
pública do grupo:

```powershell
gpg --list-sigs
gpg --check-sigs
gpg --armor --output .\gpg\chaves-publicas\grupo7-publicas.asc --export-options export-local-sigs --export FPR_TIAGO FPR_LUANNA FPR_FELIPE
```

Substitua os nomes `FPR_TIAGO`, `FPR_LUANNA` e `FPR_FELIPE` pelas impressões
digitais completas, sem os sinais `<` e `>`.

## Cifragem e decifragem

O arquivo `gpg/exemplo/credenciais-exemplo.env` contém somente valores
explicitamente fictícios. Cifre-o para um destinatário do grupo:

```powershell
gpg --output .\gpg\exemplo\credenciais-exemplo.env.gpg --encrypt --recipient FPR_DESTINATARIO .\gpg\exemplo\credenciais-exemplo.env
```

Substitua `FPR_DESTINATARIO` pela impressão digital completa do destinatário,
sem os sinais `<` e `>`. Entregue o arquivo cifrado ao destinatário na máquina
centralizada. Ele digita a própria frase-senha e decifra o arquivo:

```powershell
gpg --decrypt .\gpg\exemplo\credenciais-exemplo.env.gpg
```

O arquivo cifrado é o artefato de troca. Não use credenciais reais nem substitua
os valores fictícios por segredos de qualquer serviço.

## Evidências e segurança

Registre a exportação pública do grupo, `gpg --list-sigs` e a decifragem do
arquivo fictício. As capturas não devem mostrar frases-senha nem material
privado. Somente chaves públicas podem ser exportadas para o repositório.
