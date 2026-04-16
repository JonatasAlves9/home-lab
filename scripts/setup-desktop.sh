#!/bin/bash
# =============================================================================
# setup-desktop.sh — Configuração inicial do Desktop (Nó 2)
#
# Execute este script UMA VEZ após instalar o Ubuntu Server 24.04.
# Não execute como root — o script pedirá sudo quando necessário.
# Ao final, perguntará se deseja reiniciar para aplicar o ROCm.
#
# Uso: bash setup-desktop.sh
# =============================================================================

set -euo pipefail

# --- Cores para output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()   { echo -e "${YELLOW}[AVISO]${NC} $*"; }
error()  { echo -e "${RED}[ERRO]${NC} $*" >&2; }
header() { echo -e "\n${BLUE}=== $* ===${NC}"; }

# --- Verificar que não está rodando como root ---
if [[ "$EUID" -eq 0 ]]; then
    error "Não execute este script como root (sem sudo)."
    error "Execute como usuário normal: bash setup-desktop.sh"
    exit 1
fi

USUARIO_ATUAL="$USER"
log "Iniciando setup do Desktop para o usuário: $USUARIO_ATUAL"

# =============================================================================
# 1. Verificar pré-requisitos
# =============================================================================
header "Verificando pré-requisitos"

if ! command -v sudo &>/dev/null; then
    error "sudo não está disponível. Instale e configure o sudo primeiro."
    exit 1
fi

# Detectar interface de rede principal
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [[ -z "$INTERFACE" ]]; then
    error "Não foi possível detectar a interface de rede principal."
    error "Verifique com: ip route show default"
    exit 1
fi
log "Interface de rede detectada: $INTERFACE"

# =============================================================================
# 2. Atualizar o sistema
# =============================================================================
header "Atualizando sistema"
sudo apt update && sudo apt upgrade -y
log "Sistema atualizado"

# =============================================================================
# 3. Instalar Docker via script oficial
# =============================================================================
header "Instalando Docker"
if command -v docker &>/dev/null; then
    warn "Docker já está instalado: $(docker --version)"
else
    curl -fsSL https://get.docker.com | sh
    log "Docker instalado: $(docker --version)"
fi

# =============================================================================
# 4. Adicionar usuário ao grupo docker
# =============================================================================
header "Configurando permissões do Docker"
if groups "$USUARIO_ATUAL" | grep -q docker; then
    warn "Usuário $USUARIO_ATUAL já está no grupo docker"
else
    sudo usermod -aG docker "$USUARIO_ATUAL"
    log "Usuário $USUARIO_ATUAL adicionado ao grupo docker"
fi

# =============================================================================
# 5. Instalar utilitários adicionais
# =============================================================================
header "Instalando utilitários"
sudo apt install -y \
    ethtool \          # Ferramenta para configurar Wake on LAN na interface
    nfs-kernel-server \ # Servidor NFS para compartilhar arquivos com o Notebook
    curl \
    git \
    htop
log "Utilitários instalados"

# =============================================================================
# 6. Instalar ROCm (suporte a GPU AMD)
# =============================================================================
header "Instalando ROCm (AMD GPU)"
warn "Esta etapa pode demorar vários minutos..."

# Adicionar repositório AMD ROCm
if [[ ! -f /etc/apt/sources.list.d/amdgpu.list ]]; then
    # Script oficial de instalação do ROCm para Ubuntu
    wget -q -O /tmp/amdgpu-install.deb \
        https://repo.radeon.com/amdgpu-install/6.3/ubuntu/noble/amdgpu-install_6.3.60300-1_all.deb
    sudo apt install -y /tmp/amdgpu-install.deb
    sudo apt update
fi

# Instalar driver AMD e ROCm
sudo amdgpu-install --usecase=rocm --no-32 -y
log "ROCm instalado"

# =============================================================================
# 7. Adicionar usuário aos grupos de GPU
# =============================================================================
header "Configurando grupos de GPU"
for grupo in render video; do
    if groups "$USUARIO_ATUAL" | grep -q "$grupo"; then
        warn "Usuário já está no grupo $grupo"
    else
        sudo usermod -aG "$grupo" "$USUARIO_ATUAL"
        log "Usuário adicionado ao grupo $grupo"
    fi
done

# =============================================================================
# 8. Configurar Wake on LAN como serviço systemd
# =============================================================================
header "Configurando Wake on LAN"

# Habilitar WoL na interface via ethtool
sudo ethtool -s "$INTERFACE" wol g || warn "Falha ao habilitar WoL via ethtool (verifique se a placa suporta)"

# Criar serviço systemd para persistir WoL após reinicialização
WOL_SERVICE="/etc/systemd/system/wol.service"
sudo tee "$WOL_SERVICE" > /dev/null << EOF
[Unit]
Description=Habilitar Wake on LAN na interface $INTERFACE
# IMPORTANTE: Se a interface mudar de nome, atualize este arquivo e o After=
After=network.target

[Service]
Type=oneshot
# Habilita o WoL com pacotes Magic Packet (opção 'g')
ExecStart=/sbin/ethtool -s $INTERFACE wol g
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable wol.service
sudo systemctl start wol.service
log "Serviço wol.service criado e habilitado para a interface $INTERFACE"

# =============================================================================
# 9. Criar diretório para HD externo
# =============================================================================
header "Criando diretórios de mídia"
sudo mkdir -p /mnt/hd-externo/{filmes,series,downloads}
sudo chown -R "$USUARIO_ATUAL":"$USUARIO_ATUAL" /mnt/hd-externo
log "Diretório /mnt/hd-externo criado"

# =============================================================================
# Finalização e instruções de reinicialização
# =============================================================================
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Setup do Desktop concluído!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "${YELLOW}IMPORTANTE — Antes de reiniciar:${NC}"
echo ""
echo -e "  1. Acesse a BIOS do seu computador e habilite Wake on LAN:"
echo -e "     - Procure por: 'Wake on LAN', 'Power On By PCI-E/PCI'"
echo -e "     - Em configurações de energia: desabilite 'ErP Ready'"
echo ""
echo -e "  2. Verifique se a interface de rede detectada é a correta:"
echo -e "     Interface atual: ${BLUE}$INTERFACE${NC}"
echo -e "     Se estiver errada: ${BLUE}sudo nano $WOL_SERVICE${NC}"
echo ""
echo -e "Próximos passos após reiniciar:"
echo ""
echo -e "  ${YELLOW}1.${NC} Clone o repositório e configure o ambiente:"
echo -e "     ${BLUE}cd ~/homelab/desktop${NC}"
echo -e "     ${BLUE}cp .env.example .env${NC}"
echo ""
echo -e "  ${YELLOW}2.${NC} Suba os serviços principais:"
echo -e "     ${BLUE}docker compose up -d${NC}"
echo ""
echo -e "  ${YELLOW}3.${NC} Para usar a GPU Stack:"
echo -e "     ${BLUE}cd gpu-stack && docker compose up -d${NC}"
echo ""

# Perguntar se deseja reiniciar agora
echo -ne "${YELLOW}Deseja reiniciar agora para aplicar as mudanças do ROCm? [s/N]: ${NC}"
read -r resposta

if [[ "$resposta" =~ ^[Ss]$ ]]; then
    log "Reiniciando o sistema em 5 segundos..."
    sleep 5
    sudo reboot
else
    warn "Reinicie manualmente quando estiver pronto: sudo reboot"
fi
