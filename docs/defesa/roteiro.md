# Roteiro da apresentação

## Objetivo

Apresentar a justificativa, demonstrar os controles implementados e permitir
que cada integrante responda sobre qualquer módulo do trabalho.

## Sequência sugerida

1. Tiago apresenta cenário, topologia, rede e justificativa dos vetores.
2. Luanna apresenta PSI, firewall, SSH e hardening do sistema.
3. Felipe apresenta GPG, integridade SHA-256, relatório e evidências.
4. Todos participam da demonstração das evidências obrigatórias.
5. O professor realiza arguição individual por código e documentação.

## Demonstração prioritária

- topologia e diferenciação entre LAN e WAN;
- comparação Nmap antes e depois do firewall;
- políticas DROP e regras persistentes;
- configuração efetiva do SSH e tentativa como root;
- assinaturas GPG e decifragem do arquivo fictício;
- detecção de alteração por SHA-256;
- reinicialização e persistência dos controles.

## Plano B

Caso uma VM falhe, usar capturas existentes ou gravações já aprovadas pelo
grupo. Não apresentar capturas sem data, host e comando visível como evidência
completa.

O console local do `srv-saas` e os snapshots anteriores são o plano de
recuperação para firewall e SSH. Não usar um snapshot que apague evidências
coletadas sem primeiro copiá-las para o repositório.
