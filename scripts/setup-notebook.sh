#!/bin/bash
# =============================================================================
# setup-notebook.sh — Configuração inicial do Notebook (Nó 1)
#
# Execute este script UMA VEZ após instalar o Ubuntu Server 24.04.
# Não execute como root — o script pedirá sudo quando necessário.
#
# Uso: bash setup-notebook.sh
# =============================================================================

set -euo pipefail

# --- Cores para output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

log()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()   { echo -e "${YELLOW}[AVISO]${NC} $*"; }
error()  { echo -e "${RED}[ERRO]${NC} $*" >&2; }
header() { echo -e "\n${BLUE}=== $* ===${NC}"; }

# --- Verificar que não está rodando como root ---
if [[ "$EUID" -eq 0 ]]; then
    error "Não execute este script como root (sem sudo)."
    error "Execute como usuário normal: bash setup-notebook.sh"
    exit 1
fi

USUARIO_ATUAL="$USER"
log "Iniciando setup do Notebook para o usuário: $USUARIO_ATUAL"

# =============================================================================
# 1. Atualizar o sistema
# =============================================================================
header "Atualizando sistema"
sudo apt update && sudo apt upgrade -y
log "Sistema atualizado"

# =============================================================================
# 2. Instalar Docker via script oficial
# =============================================================================
header "Instalando Docker"
if command -v docker &>/dev/null; then
    warn "Docker já está instalado: $(docker --version)"
else
    curl -fsSL https://get.docker.com | sh
    log "Docker instalado: $(docker --version)"
fi

# =============================================================================
# 3. Adicionar usuário ao grupo docker
# =============================================================================
header "Configurando permissões do Docker"
if groups "$USUARIO_ATUAL" | grep -q docker; then
    warn "Usuário $USUARIO_ATUAL já está no grupo docker"
else
    sudo usermod -aG docker "$USUARIO_ATUAL"
    log "Usuário $USUARIO_ATUAL adicionado ao grupo docker"
    warn "As permissões entrarão em vigor no próximo login"
fi

# =============================================================================
# 4. Instalar utilitários adicionais
# =============================================================================
header "Instalando utilitários"
sudo apt install -y \
    wakeonlan \    # Enviar pacotes Magic Packet para ligar o Desktop
    nfs-common \   # Montar sistemas de arquivos NFS do Desktop
    curl \
    git \
    htop
log "Utilitários instalados"

# =============================================================================
# 5. Criar diretório para dados locais
# =============================================================================
header "Criando diretórios"
sudo mkdir -p /mnt/dados
sudo chown "$USUARIO_ATUAL":"$USUARIO_ATUAL" /mnt/dados
log "Diretório /mnt/dados criado"

# =============================================================================
# 6. Habilitar e iniciar SSH
# =============================================================================
header "Configurando SSH"
sudo systemctl enable ssh
sudo systemctl start ssh
log "SSH habilitado e iniciado"

# =============================================================================
# 7. Instalar Tailscale via script oficial
# =============================================================================
header "Instalando Tailscale"
if command -v tailscale &>/dev/null; then
    warn "Tailscale já está instalado"
else
    curl -fsSL https://tailscale.com/install.sh | sh
    log "Tailscale instalado"
fi

# =============================================================================
# Próximos passos
# =============================================================================
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Setup do Notebook concluído!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "Próximos passos:"
echo ""
echo -e "  ${YELLOW}1.${NC} Faça logout e login novamente para ativar o grupo docker:"
echo -e "     ${BLUE}exit${NC}"
echo ""
echo -e "  ${YELLOW}2.${NC} Clone o repositório e configure o ambiente:"
echo -e "     ${BLUE}cd ~/homelab/notebook${NC}"
echo -e "     ${BLUE}cp .env.example .env${NC}"
echo -e "     ${BLUE}nano .env${NC}  # preencha todas as variáveis"
echo ""
echo -e "  ${YELLOW}3.${NC} Suba os serviços:"
echo -e "     ${BLUE}docker compose up -d${NC}"
echo ""
echo -e "  ${YELLOW}4.${NC} Autentique o Tailscale:"
echo -e "     ${BLUE}docker exec tailscale tailscale up --authkey=\$TS_AUTHKEY${NC}"
echo ""
echo -e "  ${YELLOW}5.${NC} Verifique se todos os serviços subiram:"
echo -e "     ${BLUE}docker compose ps${NC}"
echo ""
