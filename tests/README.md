# Testes e evidências

Execute os testes somente nas VMs do laboratório e registre data, host,
usuário, comando e resultado. Não execute os testes contra sistemas de terceiros.

## Verificações automatizadas de baixo impacto

No `srv-saas`, depois de aplicar o SSH e inicializar a linha de base:

```bash
date --iso-8601=seconds
sudo bash tests/testes-servidor.sh
```

No `estacao-admin`, com a chave privada pessoal em `~/.ssh/saas_<usuario>`:

```bash
date --iso-8601=seconds
bash tests/testes-lan.sh
```

No `cliente-externo`:

```bash
date --iso-8601=seconds
bash tests/testes-externos.sh
```

Os scripts verificam somente configuração efetiva e conectividade das portas
do laboratório. Eles não automatizam força bruta, inundação de pacotes nem
varreduras com flags anômalas.

## Evidências obrigatórias do trabalho

1. **R2.5, root recusado:** no `estacao-admin`, carregue os valores e tente
   entrar como root:

   ```bash
   source config/lab.env
   ssh -p "$PORTA_SSH" "root@$LAN_IP_SERVIDOR"
   ```

   Confirme que não abre sessão. No `srv-saas`, execute
   `sudo grep -i 'root\|not allowed' /var/log/auth.log | tail -n 10` e capture
   a linha correspondente. Se o sistema não mantiver `auth.log`, registre a
   saída de `sudo journalctl -u ssh -n 40 --no-pager` e resolva a diferença
   com o critério definido pelo grupo antes de marcar a evidência como pronta.
2. **R2.5, senha recusada:** no `estacao-admin`, carregue a configuração e
   execute:

   ```bash
   source config/lab.env
   primeiro_usuario="${USUARIOS_ADMIN%%,*}"
   ssh -o BatchMode=yes -o PreferredAuthentications=password \
     -o PubkeyAuthentication=no -p "$PORTA_SSH" \
     "${primeiro_usuario}@$LAN_IP_SERVIDOR"
   ```

   Esperado: autenticação negada sem prompt de senha.
3. **R2.5, usuário fora de `AllowUsers`:** tente uma conta local válida não
   listada, por exemplo `nobody`, e guarde a recusa do cliente e a linha de
   autenticação no servidor. Não crie uma conta permanente só para esse teste.
4. **R2.5, listener e configuração:** no servidor, capture
   `sudo sshd -t`, `sudo ss -tlnp | grep ssh` e
   `sudo sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|authenticationmethods|allowusers) '`.
   A nova porta deve aparecer e a porta 22 não deve ter listener.
5. **R2.1/R2.2, Nmap antes e depois:** use a mesma linha de comando e o mesmo
   alvo controlado em `cliente-externo`, limitando a verificação às portas do
   laboratório, por exemplo:

   ```bash
   nmap -Pn -p 80,443,5432 10.0.2.3
   ```

   Essa é a mesma linha registrada na evidência anterior ao firewall. Compare
   os resultados sem executar a varredura contra outro endereço.
6. **R3.1, cifragem:** no dispositivo do destinatário, capture a decifragem do
   arquivo fictício e a indicação de assinatura válida. Uma tentativa sem a
   chave privada correspondente deve falhar.
7. **R3.2, integridade:** inicialize a linha de base, crie a conta de teste
   indicada em `docs/integridade/integridade.md`, execute `--check` e capture
   o alerta e o código de saída `2`. Remova a conta, atualize a linha de base
   com motivo e confirme o resultado `OK`. Para provar o agendamento, confirme
   `systemctl is-active cron.service`, confira o arquivo configurado em
   `ARQUIVO_CRON_INTEGRIDADE` e registre uma execução posterior com
   `sudo journalctl -t saas-integridade --since "10 minutes ago"`.
8. **R2.6, hardening do SO:** guarde os relatórios `antes-*.txt` e
   `depois-*.txt`, confira as permissões e atualizações, reinicie a VM e
   capture `systemctl --failed`, portas em escuta e disponibilidade de SSH,
   Nginx e PostgreSQL.

Depois de produzir cada evidência, acrescente-a ao índice
`evidencias/README.md`. Não marque um requisito como concluído antes de
registrar a evidência correspondente.
