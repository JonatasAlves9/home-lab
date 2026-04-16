#!/bin/bash
# =============================================================================
# noturno.sh — Automação noturna: ligar Desktop, disparar Sonarr, desligar
#
# Fluxo:
#   1. Lê MAC/IP do Desktop do arquivo .env do Notebook
#   2. Envia Wake on LAN
#   3. Aguarda o Desktop responder (polling SSH, timeout 5 min)
#   4. Aguarda serviços Docker subirem
#   5. Dispara busca por novos episódios no Sonarr
#   6. Aguarda 90 minutos para downloads terminarem
#   7. Desliga o Desktop via SSH
#
# Agendar via cron (às 03:00 todo dia):
#   0 3 * * * /home/usuario/homelab/scripts/noturno.sh
#
# Log: /var/log/homelab-noturno.log
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuração — ajuste conforme necessário
# =============================================================================

# Diretório raiz do homelab (ajuste se clonou em outro lugar)
HOMELAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Arquivo .env do Notebook com DESKTOP_MAC e DESKTOP_IP
ENV_FILE="$HOMELAB_DIR/notebook/.env"

# API Key do Sonarr (encontre em: Sonarr > Settings > General)
# Defina como variável de ambiente ou edite aqui
SONARR_API_KEY="${SONARR_API_KEY:-}"

# Arquivo de log
LOG_FILE="/var/log/homelab-noturno.log"

# Tempo máximo de espera pelo boot do Desktop (em segundos)
TIMEOUT_BOOT=300  # 5 minutos

# Tempo de espera antes de desligar (em segundos)
TEMPO_DOWNLOADS=5400  # 90 minutos

# =============================================================================
# Funções
# =============================================================================

# Log com timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Verifica se uma variável está definida e não vazia
requer_var() {
    local var_nome="$1"
    local var_valor="${!var_nome:-}"
    if [[ -z "$var_valor" ]]; then
        log "ERRO: Variável $var_nome não está definida"
        exit 1
    fi
}

# =============================================================================
# 1. Carregar variáveis do .env
# =============================================================================
log "=== Iniciando rotina noturna ==="

if [[ ! -f "$ENV_FILE" ]]; then
    log "ERRO: Arquivo $ENV_FILE não encontrado"
    log "Crie o arquivo com: cp notebook/.env.example notebook/.env"
    exit 1
fi

# Carrega apenas as variáveis relevantes do .env (ignora comentários e linhas vazias)
while IFS='=' read -r chave valor; do
    # Ignorar comentários e linhas vazias
    [[ "$chave" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$chave" ]] && continue
    # Remover espaços e exportar
    chave="${chave// /}"
    valor="${valor// /}"
    export "$chave=$valor"
done < <(grep -v '^#' "$ENV_FILE" | grep -v '^$')

requer_var "DESKTOP_MAC"
requer_var "DESKTOP_IP"

log "Desktop MAC: $DESKTOP_MAC"
log "Desktop IP:  $DESKTOP_IP"

# =============================================================================
# 2. Enviar Wake on LAN
# =============================================================================
log "Enviando pacote Wake on LAN para $DESKTOP_MAC..."

if ! command -v wakeonlan &>/dev/null; then
    log "ERRO: wakeonlan não está instalado. Execute: sudo apt install wakeonlan"
    exit 1
fi

wakeonlan "$DESKTOP_MAC"
log "Pacote WoL enviado"

# =============================================================================
# 3. Aguardar o Desktop responder via SSH (polling, timeout 5 min)
# =============================================================================
log "Aguardando Desktop bootar (timeout: ${TIMEOUT_BOOT}s)..."
sleep 60  # Aguarda tempo mínimo de boot antes de começar a verificar

inicio=$(date +%s)
while true; do
    agora=$(date +%s)
    decorrido=$((agora - inicio))

    if [[ $decorrido -gt $TIMEOUT_BOOT ]]; then
        log "ERRO: Desktop não respondeu em ${TIMEOUT_BOOT}s. Abortando."
        exit 1
    fi

    # Tenta conexão SSH sem verificação de host (modo não interativo)
    if ssh -o ConnectTimeout=5 \
           -o StrictHostKeyChecking=no \
           -o BatchMode=yes \
           "$DESKTOP_IP" "echo ok" &>/dev/null; then
        log "Desktop respondendo via SSH após ${decorrido}s"
        break
    fi

    log "Desktop ainda não está disponível (${decorrido}s / ${TIMEOUT_BOOT}s)..."
    sleep 15
done

# =============================================================================
# 4. Aguardar serviços Docker subirem
# =============================================================================
log "Aguardando serviços Docker iniciarem..."
sleep 30  # Tempo para o docker daemon e containers subirem

# Verifica se o Docker está rodando no Desktop
if ssh -o StrictHostKeyChecking=no "$DESKTOP_IP" "docker ps" &>/dev/null; then
    log "Docker está ativo no Desktop"
    containers=$(ssh -o StrictHostKeyChecking=no "$DESKTOP_IP" "docker ps --format '{{.Names}}'" 2>/dev/null)
    log "Containers em execução: $(echo "$containers" | tr '\n' ', ')"
else
    log "AVISO: Docker não parece estar rodando — continuando mesmo assim"
fi

# =============================================================================
# 5. Disparar busca no Sonarr via API
# =============================================================================
if [[ -z "$SONARR_API_KEY" ]]; then
    log "AVISO: SONARR_API_KEY não definida — pulando busca no Sonarr"
    log "Defina: export SONARR_API_KEY=sua-chave-aqui"
else
    log "Disparando busca por novos episódios no Sonarr..."

    sonarr_url="http://${DESKTOP_IP}:8989/api/v3/command"
    resposta=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$sonarr_url" \
        -H "X-Api-Key: $SONARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"name": "MissingEpisodeSearch", "monitored": true}')

    if [[ "$resposta" == "201" ]]; then
        log "Busca no Sonarr disparada com sucesso (HTTP $resposta)"
    else
        log "AVISO: Sonarr retornou HTTP $resposta — verifique se está rodando"
    fi
fi

# =============================================================================
# 6. Aguardar downloads terminarem
# =============================================================================
log "Aguardando $((TEMPO_DOWNLOADS / 60)) minutos para downloads completarem..."
sleep "$TEMPO_DOWNLOADS"

# =============================================================================
# 7. Desligar o Desktop via SSH
# =============================================================================
log "Enviando comando de desligamento ao Desktop..."
ssh -o StrictHostKeyChecking=no "$DESKTOP_IP" "sudo shutdown now" || true

log "=== Rotina noturna finalizada ==="
