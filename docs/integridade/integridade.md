# Verificação de integridade SHA-256

## Arquivos monitorados

O script compara os hashes dos caminhos definidos por `ARQUIVO_PASSWD`,
`ARQUIVO_SHADOW` e `ARQUIVO_REGRAS_IPTABLES` em `config/lab.env`. Os dois
primeiros apontam para `/etc/passwd` e `/etc/shadow`. SHA-256 detecta alterações
no conteúdo, mas não prova autenticidade: um administrador com privilégio
suficiente pode alterar os arquivos e recalcular a linha de base.

## Inicialização e verificação

Execute no console do `srv-saas`, depois de aplicar e persistir o firewall:

```bash
sudo bash scripts/verifica-integridade.sh --init
sudo bash scripts/verifica-integridade.sh --check
sudo bash scripts/verifica-integridade.sh --instalar-agendamento
```

A linha de base fica em
`DIR_BASELINE_INTEGRIDADE/baseline.sha256`, que por padrão aponta para
`/var/lib/saas-integridade/baseline.sha256`. O diretório usa modo `700` e o
arquivo usa modo `600`, ambos pertencentes a root. Cada execução registra o
resultado em `/var/log/saas-integridade.log` e no journal via `logger`.
Divergência produz alerta e código de saída `2`.

O agendamento usa cron e o intervalo configurado em
`INTEGRIDADE_INTERVALO_MINUTOS`. O caminho absoluto do script é gravado em
`/etc/cron.d/saas-integridade`. A pasta do repositório precisa estar montada
para que a execução periódica encontre o script e `config/lab.env`.

## Mudanças legítimas

Uma mudança autorizada que altere um arquivo monitorado exige revisão e
atualização explícita da linha de base. Registre o motivo:

```bash
sudo bash scripts/verifica-integridade.sh --atualizar "MOTIVO DA MUDANCA APROVADA"
```

Não atualize a linha de base para silenciar uma divergência que ainda não foi
investigada. Restrinja o acesso root e preserve os registros de alteração fora
do arquivo de baseline quando houver necessidade de auditoria.

## Testes controlados

Faça estes testes apenas no laboratório e remova a conta de teste ao terminar.

1. Crie uma conta de teste e detecte alterações nos arquivos de contas:

   ```bash
   sudo useradd --system --no-create-home --shell /usr/sbin/nologin teste_integridade
   sudo bash scripts/verifica-integridade.sh --check
   printf 'codigo=%s\n' "$?"
   ```

   Esperado: alerta de divergência e código `2`, indicando alteração em
   `/etc/passwd` e `/etc/shadow`.

2. Atualize a linha de base enquanto a conta temporária existe. Em seguida,
   altere somente a senha de teste para provocar uma alteração em `/etc/shadow`:

   ```bash
   sudo bash scripts/verifica-integridade.sh --atualizar "Conta temporaria criada para teste"
   sudo passwd teste_integridade
   sudo bash scripts/verifica-integridade.sh --check
   printf 'codigo=%s\n' "$?"
   sudo userdel teste_integridade
   sudo bash scripts/verifica-integridade.sh --check
   printf 'codigo=%s\n' "$?"
   ```

   Informe uma senha descartável e não a reutilize. Esperado: a primeira
   verificação detecta a alteração de `/etc/shadow`; a segunda detecta a
   remoção da conta. Depois de confirmar a remoção, atualize a linha de base e
   confirme `OK`:

   ```bash
   sudo bash scripts/verifica-integridade.sh --atualizar "Remocao da conta de teste"
   sudo bash scripts/verifica-integridade.sh --check
   ```

3. Faça uma alteração controlada no arquivo salvo do firewall, verifique a
   divergência e restaure a cópia original:

   ```bash
   sudo cp -a /etc/iptables/saas-firewall.rules /root/saas-firewall.rules.pre-teste
   printf '# teste controlado de integridade\n' | sudo tee -a /etc/iptables/saas-firewall.rules
   sudo bash scripts/verifica-integridade.sh --check
   sudo cp -a /root/saas-firewall.rules.pre-teste /etc/iptables/saas-firewall.rules
   sudo bash scripts/verifica-integridade.sh --atualizar "Restauracao apos teste controlado"
   sudo bash scripts/verifica-integridade.sh --check
   ```

   Esperado: alerta antes da restauração e `OK` depois da restauração e da
   atualização autorizada.

Para inspecionar eventos, use `sudo tail -n 20 /var/log/saas-integridade.log`
e `sudo journalctl -t saas-integridade -n 20 --no-pager`.
