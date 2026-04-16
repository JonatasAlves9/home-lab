# =============================================================================
# Dockerfile — Webhook de controle do GPU Stack
# Base leve com Python 3.11 e Flask
# =============================================================================

FROM python:3.11-slim

# Instalar dependências do sistema necessárias para o Docker CLI dentro do container
RUN apt-get update && apt-get install -y --no-install-recommends \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Instalar Flask
RUN pip install --no-cache-dir flask

# Criar diretório de trabalho
WORKDIR /app

# Copiar o script do webhook
COPY webhook.py .

# Porta exposta pelo serviço
EXPOSE 5000

# Comando de inicialização
CMD ["python", "webhook.py"]
