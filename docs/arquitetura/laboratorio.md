# Laboratório virtual

## Visão geral

O laboratório usa três máquinas virtuais no VirtualBox. O `srv-saas` tem duas
interfaces porque atua como servidor dos serviços do segmento e como gateway
com firewall entre a WAN e a LAN. A interface WAN conecta o servidor à rede
externa e permite atualizações. A interface LAN conecta a estação administrativa
à rede interna, sem acesso direto à WAN. Para demonstrar a rota estática sem
criar uma quarta VM, `estacao-admin` também atuará como roteador entre `lan-saas`
e uma segunda rede interna chamada `lan-ci`. O `cliente-externo` fica na WAN
para testes a partir desse lado.

Use `config/lab.env` como fonte dos parâmetros do laboratório. Valores que
dependem do computador, da equipe ou que ainda não foram acordados permanecem
como `DEFINIR` até serem confirmados. Os endereços temporários da LAN indicados
neste documento servem somente à configuração inicial e não persistem após
reinicialização.

## Máquinas virtuais

| Máquina | Função | Sistema operacional | Recursos | Adaptadores e redes virtuais |
|---|---|---|---|---|
| `srv-saas` | Servidor dos serviços SaaS, gateway e firewall entre WAN e LAN | Ubuntu Server 26.04.1 LTS de `config/lab.env` | CPU: 1; memória: 2 GB; disco: 25 GB | Adaptador 1: `wan-saas`, Rede NAT. Adaptador 2: `lan-saas`, Rede Interna |
| `cliente-externo` | Cliente de testes no lado externo | Linux com Nmap; Ubuntu 26.04.1 LTS | CPU: 1; memória: 2 GB; disco: 25 GB | Adaptador 1: `wan-saas`, Rede NAT |
| `estacao-admin` | Estação administrativa e roteador para `lan-ci` | Ubuntu Server 26.04.1 LTS | CPU: 1; memória: 2 GB; disco: 25 GB | Adaptador 1: `lan-saas`, Rede Interna. Adaptador 2: `lan-ci`, Rede Interna, a configurar |

A versão Ubuntu 26.04.1 LTS foi confirmada nas três VMs em 17/11/2026 e está
registrada em `config/lab.env`.

Na tabela de redes do VirtualBox, configure `wan-saas` como uma Rede NAT e
`lan-saas` e `lan-ci` como Redes Internas. `lan-ci` é a rede de destino atrás
do roteador `estacao-admin`. Registre em `config/lab.env` os parâmetros
definitivos acordados, inclusive interfaces, IPs e gateway WAN. Não use valores
de exemplo como se fossem os valores definitivos.

## Criação e configuração inicial

1. Confirme a versão instalada do VirtualBox e os recursos disponíveis no
   computador. Registre a versão e os valores escolhidos de CPU, memória e disco
   na tabela acima.
2. No gerenciador de redes do VirtualBox, crie a rede NAT `wan-saas`. Habilite o
   DHCP nessa rede para a configuração inicial e confirme que as VMs conectadas
   conseguem receber endereço. O endereço da rede e as opções DHCP dependem da
   máquina: CONFERIR.
3. Crie as Redes Internas `lan-saas` e `lan-ci`. Elas não precisam de DHCP:
   os endereços temporários serão configurados manualmente.
4. Crie a VM `srv-saas` com a versão Ubuntu Server indicada por
   `UBUNTU_VERSAO` em `config/lab.env`. Atribua recursos conforme o passo 1 e
   configure dois adaptadores: o primeiro em `wan-saas` e o segundo em
   `lan-saas`.
5. Crie `cliente-externo` com Linux e Nmap. Conecte seu único adaptador a
   `wan-saas`.
6. Crie `estacao-admin` com o sistema operacional acordado pela equipe.
   Conecte o Adaptador 1 a `lan-saas`. Habilite o Adaptador 2, selecione
   **Rede Interna** e informe `lan-ci`.
7. Instale os sistemas operacionais e confirme no VirtualBox que cada adaptador
   está habilitado e conectado à rede indicada. No servidor, identifique as
   interfaces com `ip -br addr`. Associe os nomes observados a `IFACE_WAN` e
   `IFACE_LAN` em `config/lab.env`; os nomes dependem da instalação.
8. No servidor, use `ip -br addr` para localizar o endereço recebido por DHCP
   na interface WAN e `ip route` para localizar a rota `default` e seu gateway
   (`via`). Registre os dados observados em `WAN_IP_SERVIDOR`, `WAN_REDE` e
   `WAN_GATEWAY` em `config/lab.env`. Não suponha que o gateway seja sempre o
   mesmo entre máquinas.
9. Aplique os endereços temporários da LAN descritos a seguir e execute os
   testes da seção [Verificação](#verificação).
10. Configure a rota estática temporária usando a seção
    [Roteador para a rota estática](#roteador-para-a-rota-estática) e teste-a.
11. Crie o snapshot `base-limpa` de cada VM. Depois da Etapa 2 do README, crie
    no servidor o snapshot `pre-firewall`, antes de instalar ou aplicar as
    regras de firewall.

### Endereços temporários da LAN

Os endereços abaixo são voláteis. Eles desaparecem ao reiniciar a VM; não
representam a configuração estática final da Etapa 2. Depois de montar a pasta
compartilhada, carregue `config/lab.env` no shell e confirme que `IFACE_LAN`
contém o nome observado com `ip -br addr`. Substitua o caminho antes de executar:

```bash
source "<CAMINHO_DO_REPOSITORIO>/config/lab.env"
```

No `srv-saas`:

```bash
sudo ip addr replace 10.10.10.1/24 dev "$IFACE_LAN"
```

Na `estacao-admin`:

```bash
sudo ip addr add "$LAN_IP_ESTACAO_ADMIN/24" dev "$IFACE_LAN_ESTACAO_ADMIN"
```

O endereço temporário do servidor corresponde a `LAN_IP_SERVIDOR` em
`config/lab.env`. O endereço temporário e a interface da estação estão em
`LAN_IP_ESTACAO_ADMIN` e `IFACE_LAN_ESTACAO_ADMIN`. Confirme na Etapa 2 se esses
endereços serão mantidos na configuração estática. Antes de repetir o comando,
confira `ip -br addr`; se o endereço já aparecer, não tente adicioná-lo de novo.

Para descobrir o endereço WAN e o gateway recebidos por DHCP no servidor:

```bash
ip -br addr
ip route
```

Na saída de `ip -br addr`, procure o endereço da interface WAN. Em `ip route`,
procure a rota que começa com `default`; o endereço após `via` é o gateway.
Confirme também que a interface indicada após `dev` é a WAN. Registre os valores
observados em `config/lab.env`.

## Estado observado da rede

Saídas enviadas em 17/11/2026:

| Máquina | Interface e endereço IPv4 observado | Rotas observadas | Situação |
|---|---|---|---|
| `srv-saas` | `enp0s3`: `10.0.2.3/24`; `enp0s8`: `10.10.10.1/24` | Rota padrão via `10.0.2.1` por `enp0s3`; rota conectada `10.10.10.0/24` por `enp0s8` | WAN por DHCP e endereço temporário aplicado na LAN |
| `cliente-externo` | `enp0s3`: `10.0.2.4/24` | Rota padrão via `10.0.2.1` por `enp0s3` | WAN recebeu endereço por DHCP na mesma faixa observada no servidor |
| `estacao-admin` | `enp0s3`: `10.10.10.10/24` | Rota conectada `10.10.10.0/24` por `enp0s3`; sem rota padrão, conforme esperado para a LAN isolada | Endereço temporário aplicado na LAN |

Com base na ordem dos adaptadores definida para o servidor, `enp0s3` foi
registrada como WAN e `enp0s8` como LAN em `config/lab.env`. Confirme em
**Configurações > Rede** do VirtualBox que o Adaptador 1 do servidor está em
`wan-saas` e o Adaptador 2 em `lan-saas` antes de usar esses nomes. Os endereços
WAN registrados também são observações DHCP temporárias, não a configuração
estática final da Etapa 2.

A equipe escolheu usar `estacao-admin` como roteador, sem criar uma quarta VM.
Por isso, `ROTA_ESTATICA_REDE` e `ROTA_ESTATICA_VIA` já estão definidos em
`config/lab.env`. A interface `IFACE_REDE_ROTEADA` foi identificada como
`enp0s8` e registrada no arquivo; confirme novamente com `ip -br addr` se os
adaptadores forem alterados.

As capturas de endereços e rotas, assim como os pings de teste, estão no índice
de [evidências](../../evidencias/README.md). Os pings registrados confirmam a
conectividade da estação ao servidor pela LAN, do cliente externo ao servidor
pela WAN e do servidor ao gateway WAN. A evidência 11 também registra a
resolução de `archive.ubuntu.com` e a conclusão de `sudo apt update` no
servidor, confirmando DNS e acesso à Internet. A saída mostra repositórios da
suíte `resolute`. Tiago confirmou Ubuntu 26.04.1 LTS nas três VMs, e a versão
foi alinhada entre esta documentação e `config/lab.env`.

Nas capturas do servidor e da estação, o comando `ip addr add` foi repetido
depois que o endereço já estava configurado. A mensagem `Address already
assigned` é esperada nessa situação; confira com `ip -br addr` e não repita a
adição enquanto o endereço já estiver presente.

## Roteador para a rota estática

`estacao-admin` será o próximo salto `10.10.10.2` para a rede
`10.10.20.0/24`. O Adaptador 1 continua em `lan-saas`, onde a estação também
mantém seu endereço administrativo `10.10.10.10/24`. O Adaptador 2 conecta
`estacao-admin` à rede isolada `lan-ci`, onde o roteador terá o endereço
`10.10.20.1/24`. Assim, não é necessário criar uma quarta VM.

### Conectar a segunda rede no VirtualBox

1. Desligue `estacao-admin` pelo sistema operacional.
2. No VirtualBox Manager, selecione `estacao-admin` e abra
   **Configurações > Rede > Adaptador 2**.
3. Marque **Habilitar Placa de Rede**, selecione **Rede Interna**, informe
   `lan-ci` no campo **Nome** e marque **Cabo conectado**.
4. Confirme que o Adaptador 1 continua em **Rede Interna**, com o nome
   `lan-saas`, e clique em **OK**.
5. Inicie `estacao-admin`. No terminal, execute `ip -br addr` e identifique a
   interface nova, ainda sem endereço IPv4. Registre o nome em
   `IFACE_REDE_ROTEADA` no `config/lab.env`. Não suponha que o nome será
   `enp0s8`; confirme a saída da VM.

### Configurar endereços e encaminhamento temporários

Os comandos abaixo só valem até reiniciar as VMs. Carregue o `config/lab.env`
em cada terminal a partir da pasta compartilhada do repositório.

Na `estacao-admin`, confira primeiro `ip -br addr`. Se
`10.10.10.10/24` não aparecer em `IFACE_LAN_ESTACAO_ADMIN`, restaure-o com:

```bash
sudo ip addr add "$LAN_IP_ESTACAO_ADMIN/24" dev "$IFACE_LAN_ESTACAO_ADMIN"
```

Adicione o endereço de próximo salto à mesma interface. Use `ip addr add` para
manter `10.10.10.10/24` e `10.10.10.2/24` simultaneamente; `replace` poderia
substituir o endereço administrativo. Se `10.10.10.2/24` já aparecer, pule
esse primeiro comando:

```bash
sudo ip addr add "$ROTA_ESTATICA_VIA/24" dev "$IFACE_LAN_ESTACAO_ADMIN"
```

Atribua o endereço da rede `lan-ci` à segunda interface e habilite o
encaminhamento IPv4:

```bash
sudo ip addr replace "$IP_ROTEADOR_REDE_ROTEADA/24" dev "$IFACE_REDE_ROTEADA"
sudo sysctl -w net.ipv4.ip_forward=1
sysctl net.ipv4.ip_forward
```

O último comando deve mostrar `net.ipv4.ip_forward = 1`. Esse encaminhamento
permite que a estação roteie pacotes entre as duas redes, em vez de apenas
responder pelo endereço local.

No `srv-saas`, instale a rota para `lan-ci` via o endereço da estação na
`lan-saas`:

```bash
sudo ip route replace "$ROTA_ESTATICA_REDE" via "$ROTA_ESTATICA_VIA" dev "$IFACE_LAN"
ip route
ip route get "$IP_ROTEADOR_REDE_ROTEADA"
ping -c 4 "$IP_ROTEADOR_REDE_ROTEADA"
```

Em `ip route`, confirme uma rota para `10.10.20.0/24` via `10.10.10.2`. A
consulta `ip route get` também deve indicar esse próximo salto e a interface
LAN do servidor. O ping para `10.10.20.1` confirma o caminho até a interface do
roteador na rede `lan-ci`. Como ainda não há uma VM cliente conectada a
`lan-ci`, esse teste não comprova comunicação com um host atrás do roteador.

Na captura de teste enviada, a rota via `10.10.10.2` está instalada, a entrada
de vizinhança do próximo salto ficou `REACHABLE`, e os pings para `10.10.10.2`
e `10.10.20.1` receberam quatro respostas. Isso confirma a conectividade
temporária até as interfaces do roteador. A captura está listada como evidência
preliminar porque não mostra a data.

Esses comandos são voláteis. Na Etapa 2, persista os endereços e a rota com
Netplan e o encaminhamento com uma configuração de `sysctl`, depois de
confirmar os nomes das interfaces. Não aplique o firewall antes de validar a
configuração e criar o snapshot `pre-firewall`.

## Pasta compartilhada do VirtualBox

Configure uma pasta compartilhada apontando para o repositório no computador
host. O nome da pasta compartilhada e o caminho do repositório variam por
integrante: DEFINIR. A pasta deve estar acessível pelo VirtualBox na VM que será
usada para editar ou executar os arquivos.

Na VM Linux, instale os utilitários de convidado do VirtualBox:

```bash
sudo apt update
sudo apt install virtualbox-guest-utils
```

Adicione a conta que usará o compartilhamento ao grupo `vboxsf` e inicie uma
nova sessão para que a associação ao grupo tenha efeito:

```bash
sudo usermod -aG vboxsf "$USER"
```

Crie o ponto de montagem escolhido e monte a pasta compartilhada. Substitua os
marcadores pelo nome cadastrado no VirtualBox e pelo caminho definido na VM:

```bash
sudo mkdir -p "<PONTO_DE_MONTAGEM>"
sudo mount -t vboxsf -o fmode=755 "<NOME_COMPARTILHADO>" "<PONTO_DE_MONTAGEM>"
```

O atributo do Git em `.gitattributes` força LF nos arquivos listados. Confira
que scripts e configurações continuam com LF ao editar ou copiar arquivos no
Windows: finais de linha CRLF em scripts Bash podem impedir sua execução no
Linux.

## Verificação

Execute `ip -br addr` e `ip route` em cada máquina e registre a saída como
evidência da Etapa 1. Confira que as interfaces e rotas correspondem aos
adaptadores configurados.

Faça os testes de conectividade:

| Origem | Comando | Resultado esperado |
|---|---|---|
| `cliente-externo` | `ping -c 4 "$WAN_IP_SERVIDOR"` | Resposta do endereço WAN do servidor, sem perda de pacotes na rede local do laboratório |
| `estacao-admin` | `ping -c 4 10.10.10.1` | Resposta do endereço LAN temporário do servidor, sem perda de pacotes |
| `srv-saas` | `ping -c 4 "$WAN_GATEWAY"` | Resposta do gateway identificado por DHCP |
| `srv-saas` | `ping -c 4 DEFINIR_DESTINO_CONFIRMADO` | Resposta de um destino externo confirmado pela equipe; destino: CONFERIR |

Carregue `config/lab.env` nos shells usados para executar os comandos que
referenciam suas variáveis. Substitua `DEFINIR_DESTINO_CONFIRMADO` por um nome ou
endereço externo confirmado pela equipe. Se um teste falhar, confira primeiro a
rede atribuída ao adaptador, o endereço e a rota com `ip -br addr` e `ip route`.
O acesso do servidor à Internet e a comunicação entre os lados são critérios de
aceite da Etapa 1.

## Snapshots

Em 17/11/2026, foi confirmada a existência do snapshot `base-limpa` nas três
VMs. O procedimento abaixo serve para recriá-lo caso seja necessário.

- `base-limpa`: crie um snapshot de cada VM depois de instalar o sistema
  operacional, configurar os adaptadores e validar a conectividade básica.
  No VirtualBox Manager, desligue cada VM normalmente pelo sistema convidado,
  selecione a VM, abra a área **Snapshots/Instantâneos** e clique em
  **Tirar snapshot** ou no ícone de câmera. Dê o nome `base-limpa`, inclua na
  descrição o estado do laboratório e repita para as três VMs. Se a sua versão
  não mostrar essa área, use o menu **Máquina > Tirar snapshot**. Desligar a VM
  normalmente antes do snapshot evita salvar uma sessão em execução; como os
  endereços LAN desta etapa são voláteis, reaplique-os após restaurar ou
  reiniciar as VMs.
- `pre-firewall`: depois da Etapa 2 do README, crie no `srv-saas` um snapshot
  antes de aplicar qualquer regra de firewall. Desligue o servidor normalmente,
  selecione-o no VirtualBox Manager e crie o snapshot pelo mesmo fluxo, com o
  nome `pre-firewall`. Ele preserva a configuração de rede e os serviços antes
  do firewall.

## Recuperação pelo console

O console é a janela local da VM no VirtualBox, não uma sessão SSH. Ele continua
disponível mesmo se uma rota, o SSH ou uma regra de firewall bloquear o acesso
pela rede.

1. No VirtualBox Manager, selecione a VM e clique em **Mostrar** para abrir sua
   janela. Se estiver desligada, clique primeiro em **Iniciar**.
2. Na tela de login da própria VM, entre com a conta administrativa criada na
   instalação. Digite a senha mesmo que os caracteres não apareçam na tela.
3. Após entrar, execute `ip -br addr` e `ip route` para diagnosticar endereços
   e rotas. Corrija pelo console a configuração de rede ou firewall responsável
   pelo bloqueio. Não é necessário habilitar SSH para usar o console.
4. Se não conseguir recuperar a VM, desligue-a pelo VirtualBox Manager e abra a
   área **Snapshots/Instantâneos**. Selecione `base-limpa` para retornar ao
   estado inicial ou `pre-firewall` para retornar ao estado anterior ao
   firewall, e escolha **Restaurar**. A restauração descarta as alterações
   posteriores ao snapshot; confirme a ação somente se esse descarte for
   aceitável.

Os nomes das contas e credenciais são definidos por cada integrante e não devem
ser registrados neste documento.
