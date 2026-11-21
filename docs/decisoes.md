# Registro de decisões

| Data | Decisão | Alternativas consideradas | Justificativa | Quem decidiu |
|---|---|---|---|---|
| 20/11/2026 | Hipervisor: VirtualBox | Hipervisores compatíveis disponíveis no laboratório, sem outra opção instalada e verificada | VirtualBox é o ambiente efetivamente usado nas três VMs | Grupo |
| 09/11/2026 | Banco de dados: PostgreSQL, porta 5432 | MySQL | Banco e porta definidos pelo grupo. | Grupo |
| 18/11/2026 | Dois vetores de ameaça: abuso de credenciais válidas e privilégios administrativos/deploy; comprometimento da cadeia de suprimentos e do pipeline de deploy | Varredura de portas, DDoS e exposição direta do banco | Vetores selecionados por relação direta com identidade, SSH, deploy, banco e SaaS multi-tenant | Grupo |
| 20/11/2026 | Chaves GPG: Ed25519 para assinatura com subchave CV25519 para cifra, validade de 12 meses | RSA de 3072 ou 4096 bits | Escolha do grupo, compatível com as versões do GnuPG usadas no laboratório | Grupo, decisão reportada por Tiago |
| 20/11/2026 | Armazenamento de chaves GPG: centralizado na máquina Windows do Tiago | Cada integrante mantém sua chave no próprio dispositivo | A equipe aprovou a centralização; cada titular digita sua própria frase-senha. O risco de concentração está registrado em `docs/criptografia/gpg.md` | Grupo, decisão reportada por Tiago |
| 09/11/2026 | Porta SSH: 22022 | Porta padrão 22 | Porta definida pelo grupo para reduzir exposição a tentativas automatizadas na porta padrão | Grupo |
