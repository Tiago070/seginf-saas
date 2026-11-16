# Guia de estilo

## Cabeçalho obrigatório para scripts Bash

Todo script Bash deve começar com um cabeçalho no formato abaixo. Preencha os campos sem deixar informações inventadas; quando ainda não houver definição, use `DEFINIR`.

```bash
#!/usr/bin/env bash
# Nome: DEFINIR
# Finalidade: DEFINIR
# Autor: DEFINIR
# Data: DEFINIR
# Requisitos: DEFINIR
# Uso: DEFINIR
# Requisito do trabalho atendido: DEFINIR (por exemplo, R2.2)
# Fonte externa: nenhuma
```

## Comentários

- Escreva comentários em português.
- Explique o porquê da decisão ou ação, não apenas o que o comando faz.
- Use um comentário por bloco lógico.
- Descreva os parâmetros de cada função.

## Convenções de nomes

- Escreva variáveis de configuração em `MAIÚSCULAS`.
- Escreva funções e variáveis locais em minúsculas, com palavras separadas por underscore.

## Boas práticas de Bash

- Use `set -euo pipefail` para detectar erros, variáveis não definidas e falhas em pipelines.
- Coloque variáveis entre aspas quando usadas em comandos ou expansões.
- Verifique se o script está sendo executado como `root` quando a operação exigir privilégios administrativos.

## Formato de commits

Use `tipo(escopo): descrição`, com uma descrição curta em português. Tipos aceitos: `feat`, `fix`, `docs`, `test` e `chore`. Escopos aceitos: `rede`, `firewall`, `ssh`, `so`, `gpg`, `integridade`, `ameacas`, `psi`, `relatorio` e `repo`.

Exemplos:

- `feat(rede): documenta os parâmetros do laboratório`
- `fix(firewall): corrige a ordem das regras`
- `docs(ssh): registra as decisões de acesso`
- `test(so): valida as configurações do sistema`
- `chore(repo): cria a estrutura inicial`
- `feat(gpg): adiciona instruções de uso`
- `fix(integridade): ajusta a verificação do baseline`
- `docs(ameacas): registra os vetores definidos`
- `docs(psi): organiza o capítulo da política`
- `docs(relatorio): atualiza a estrutura do documento`
