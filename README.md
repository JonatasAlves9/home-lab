# Home Lab — Infrastructure as Code

Repositório de configuração completa para um home lab de dois nós com Docker.

---

## Arquitetura

```
                        ┌─────────────────────────────────────────┐
                        │              Rede Local (LAN)            │
                        │                                          │
  ┌───────────────────┐ │  ┌──────────────────────────────────────┐│
  │   Notebook (Nó 1) │ │  │          Desktop (Nó 2)              ││
  │  i5 8ª gen, 8GB   │─┼─▶│  i5-9400F, 32GB, GPU AMD RX 5500XT  ││
  │  256GB SSD        │ │  │  Ligado sob demanda via Wake on LAN  ││
  │  Sempre ligado    │ │  └──────────────────────────────────────┘│
  │                   │ │                                          │
  │  Serviços 24/7:   │ │  Serviços sob demanda:                  │
  │  • Homepage       │ │  • Jellyfin (mídia)                     │
  │  • Nextcloud      │ │  • Sonarr / Radarr (automação)          │
  │  • Gitea          │ │  • qBittorrent (downloads)              │
  │  • Vaultwarden    │ │  • Grafana / Prometheus (métricas)      │
  │  • Pi-hole        │ │  • n8n (automação de fluxos)            │
  │  • Uptime Kuma    │ │  • GPU Stack (Ollama + Open WebUI)      │
  │  • FreshRSS       │ │                                          │
  │  • Plane          │ │                                          │
  │  • Tailscale      │ │                                          │
  └───────────────────┘ └──────────────────────────────────────────┘
```

O Notebook funciona como nó primário, sempre disponível. O Desktop é ligado remotamente
via Wake on LAN quando necessário (heavy workloads, mídia, IA local) e pode ser desligado
automaticamente pelo script `noturno.sh`.

---

## Pré-requisitos

- Ubuntu Server 24.04 LTS em ambos os nós
- Docker e Docker Compose (instalados pelos scripts de setup)
- Git para clonar este repositório
- Acesso à rede local (mesma sub-rede para WoL funcionar)
- BIOS do Desktop com Wake on LAN habilitado

---

## Início Rápido

### 1. Clonar o repositório

```bash
git clone <url-do-repo> ~/homelab
cd ~/homelab
```

### 2. Configurar o Notebook (Nó 1)

```bash
# Executar script de setup (apenas uma vez)
bash scripts/setup-notebook.sh

# Copiar e editar o arquivo de ambiente
cp notebook/.env.example notebook/.env
nano notebook/.env

# Subir os serviços
cd notebook
docker compose up -d
```

### 3. Configurar o Desktop (Nó 2)

```bash
# Executar script de setup (apenas uma vez)
bash scripts/setup-desktop.sh

# Copiar e editar o arquivo de ambiente
cp desktop/.env.example desktop/.env

# Subir os serviços principais
cd desktop
docker compose up -d

# Subir a GPU Stack manualmente quando necessário
cd desktop/gpu-stack
docker compose up -d
```

---

## Configuração do arquivo `.env`

### Notebook (`notebook/.env`)

Copie `notebook/.env.example` para `notebook/.env` e preencha:

| Variável | Descrição |
|---|---|
| `NEXTCLOUD_ADMIN_USER` | Usuário admin do Nextcloud |
| `NEXTCLOUD_ADMIN_PASSWORD` | Senha do admin do Nextcloud |
| `PIHOLE_PASSWORD` | Senha da interface web do Pi-hole |
| `TS_AUTHKEY` | Chave de autenticação do Tailscale |
| `DESKTOP_MAC` | Endereço MAC do Desktop para Wake on LAN |
| `DESKTOP_IP` | Endereço IP local do Desktop |

### Desktop (`desktop/.env`)

Copie `desktop/.env.example` para `desktop/.env`. Os valores padrão (`PUID=1000`, `PGID=1000`, `TZ=America/Recife`) geralmente não precisam ser alterados.

---

## Tabela de Portas e URLs

### Notebook (sempre disponível)

| Serviço | Porta | URL | Descrição |
|---|---|---|---|
| Homepage | 3000 | `http://notebook:3000` | Dashboard principal |
| Nextcloud | 8080 | `http://notebook:8080` | Armazenamento em nuvem |
| Gitea | 3001 | `http://notebook:3001` | Git self-hosted |
| Gitea SSH | 222 | `ssh://notebook:222` | SSH para repositórios |
| Vaultwarden | 8081 | `http://notebook:8081` | Gerenciador de senhas |
| Pi-hole | 8082 | `http://notebook:8082` | Bloqueio de anúncios / DNS |
| Uptime Kuma | 3002 | `http://notebook:3002` | Monitor de uptime |
| FreshRSS | 8083 | `http://notebook:8083` | Leitor de RSS |
| Firefly III | 8085 | `http://notebook:8085` | Gerenciador de finanças |
| Plane | 8086 | `http://notebook:8086` | Gerenciador de projetos/issues |

### Desktop (sob demanda)

| Serviço | Porta | URL | Descrição |
|---|---|---|---|
| Jellyfin | 8096 | `http://desktop:8096` | Servidor de mídia |
| Sonarr | 8989 | `http://desktop:8989` | Automação de séries |
| Radarr | 7878 | `http://desktop:7878` | Automação de filmes |
| qBittorrent | 8090 | `http://desktop:8090` | Cliente BitTorrent |
| Grafana | 3003 | `http://desktop:3003` | Dashboards de métricas |
| Prometheus | 9090 | `http://desktop:9090` | Coleta de métricas |
| n8n | 5678 | `http://desktop:5678` | Automação de fluxos |
| Webhook GPU | 5000 | `http://desktop:5000` | Controle da GPU Stack |

### GPU Stack (Desktop)

| Serviço | Porta | URL | Descrição |
|---|---|---|---|
| Ollama | 11434 | `http://desktop:11434` | LLM local (ROCm/AMD) |
| Open WebUI | 3004 | `http://desktop:3004` | Interface web para Ollama |

---

## Wake on LAN

O Desktop pode ser ligado remotamente a partir do Notebook.

### Pré-requisitos
1. BIOS com opção "Wake on LAN" ou "Power on by PCI/PCIe" habilitada
2. `wakeonlan` instalado no Notebook (instalado pelo `setup-notebook.sh`)
3. Serviço `wol.service` ativo no Desktop (configurado pelo `setup-desktop.sh`)

### Ligar o Desktop manualmente

```bash
# A partir do Notebook
wakeonlan AA:BB:CC:DD:EE:FF   # substituir pelo MAC do Desktop
```

### Via script noturno (automatizado)

```bash
# Editar variáveis no topo do script
nano scripts/noturno.sh

# Executar manualmente para teste
bash scripts/noturno.sh

# Agendar via cron (ex: às 03:00 todos os dias)
crontab -e
# Adicionar: 0 3 * * * /home/user/homelab/scripts/noturno.sh
```

---

## GPU Stack

O stack de GPU (Ollama + Open WebUI) usa o AMD ROCm e **não sobe automaticamente** para economizar recursos. Ele pode ser controlado de três formas:

### Manualmente via terminal (no Desktop)

```bash
# Subir
cd ~/homelab/desktop/gpu-stack
docker compose up -d

# Derrubar
docker compose down
```

### Via webhook HTTP (de qualquer lugar da rede)

```bash
# Ligar GPU Stack
curl http://desktop:5000/gpu/start

# Desligar GPU Stack (e o Desktop)
curl http://desktop:5000/gpu/stop

# Ver status
curl http://desktop:5000/status
```

### Via Homepage

O dashboard exibe o status da GPU Stack e tem links rápidos para ligar/desligar.

---

## Tailscale (Acesso Remoto)

O Tailscale fornece VPN mesh para acesso seguro de qualquer lugar.

```bash
# Após subir o container, autenticar:
docker exec tailscale tailscale up --authkey=$TS_AUTHKEY
```

Após autenticado, todos os serviços do Notebook ficam acessíveis via IP do Tailscale, mesmo fora da rede local.

---

## Troubleshooting

### Container não sobe

```bash
# Verificar logs do serviço com problema
docker compose logs -f <nome-do-servico>

# Verificar se a porta já está em uso
sudo ss -tlnp | grep <porta>

# Verificar permissões de volumes
ls -la /var/lib/docker/volumes/
```

### Wake on LAN não funciona

1. **Verificar se o WoL está habilitado na BIOS** — procurar por "Wake on LAN", "Power On By PCI-E", "ErP Ready" (deve estar desabilitado)
2. **Verificar se o serviço wol.service está ativo no Desktop:**
   ```bash
   systemctl status wol.service
   ```
3. **Verificar o nome correto da interface de rede:**
   ```bash
   ip link show
   # Substituir enp3s0 pelo nome correto em wol.service
   ```
4. **Verificar se o pacote está chegando** (instalar wireshark/tcpdump no Desktop antes de desligar e monitorar):
   ```bash
   sudo tcpdump -i enp3s0 ether broadcast
   ```

### GPU não reconhecida pelo Docker

```bash
# Verificar se o ROCm foi instalado corretamente
rocm-smi

# Verificar se o usuário está nos grupos corretos
groups $USER
# Deve mostrar: render video

# Verificar se os devices existem
ls -la /dev/kfd /dev/dri/

# Testar GPU no container Ollama
docker exec ollama ollama run llama3.2 "teste"
```

### NFS não monta

```bash
# Verificar se o servidor NFS está ativo (Desktop)
systemctl status nfs-kernel-server

# Verificar exports
cat /etc/exports
showmount -e localhost

# No cliente (Notebook), tentar montar manualmente
sudo mount -t nfs desktop:/mnt/hd-externo /mnt/hd-externo

# Ver erros detalhados
sudo dmesg | tail -20
```

### Pi-hole conflito de porta 53

Se outro serviço DNS estiver usando a porta 53:
```bash
# Verificar systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Editar /etc/resolv.conf apontando para o Pi-hole
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
```

---

## Estrutura do Repositório

```
homelab/
├── .gitignore
├── README.md
├── notebook/
│   ├── .env.example
│   ├── docker-compose.yml
│   └── config/
│       └── homepage/
│           ├── services.yaml
│           ├── widgets.yaml
│           └── settings.yaml
├── desktop/
│   ├── .env.example
│   ├── docker-compose.yml
│   └── gpu-stack/
│       ├── docker-compose.yml
│       └── webhook/
│           ├── webhook.py
│           └── Dockerfile
└── scripts/
    ├── setup-notebook.sh
    ├── setup-desktop.sh
    ├── noturno.sh
    └── wol.service
```
