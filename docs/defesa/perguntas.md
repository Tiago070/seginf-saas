# Banco de perguntas de defesa

## Rede e arquitetura

1. Por que o servidor possui interfaces LAN e WAN?
2. Qual é a diferença entre rota conectada e rota estática?
3. O que é próximo salto?
4. Por que o servidor precisa habilitar encaminhamento IPv4?

## Ameaças e PSI

1. Por que foram escolhidos abuso de credenciais e cadeia de suprimentos?
2. Que pilares CID são afetados por cada vetor?
3. Qual diretriz da PSI corresponde a cada controle técnico?
4. Como a PSI trata um alerta de integridade em `/etc/shadow`?

## Firewall

1. Por que usar política DROP em INPUT e FORWARD?
2. Qual cadeia processa tráfego destinado ao servidor?
3. Qual cadeia processa tráfego LAN para WAN?
4. Por que DROP não REJECT neste projeto?
5. Por que `ESTABLISHED,RELATED` é necessário?
6. Como a regra SSH reduz força bruta?
7. Como o módulo recent identifica varredura?
8. Como o firewall reduz exposição do PostgreSQL pela WAN?

## SSH

1. Por que mudar a porta não é controle suficiente?
2. O que `PermitRootLogin no` impede?
3. Por que `PasswordAuthentication no` não basta sem
   `AuthenticationMethods publickey`?
4. O que `AllowUsers` restringe que o firewall não restringe?
5. Por que `ssh.socket` pode interferir na porta configurada?
6. Por que manter uma segunda sessão durante a aplicação?

## Hardening do sistema

1. O que é superfície de ataque?
2. Por que ajustar permissões pontualmente em vez de recursivamente?
3. Por que o TCP Wrapper pode não se aplicar ao Ubuntu atual?
4. Como atualizar e confirmar que não há pacotes pendentes?

## GPG

1. O que cifra garante?
2. O que assinatura garante?
3. Por que combinar cifra assimétrica e assinatura?
4. Por que verificar impressão digital por canal independente?
5. Por que chaves privadas não podem entrar no repositório?

## Integridade

1. SHA-256 prova integridade ou autenticidade?
2. O que impede um invasor com root de recalcular a linha de base?
3. Por que proteger `/etc/shadow` e revisar alertas?
4. Como atualizar o baseline após mudança legítima?
5. Por que SHA-256 é preferível a MD5 para este teste?
