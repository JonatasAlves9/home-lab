#!/usr/bin/env python3
"""
Webhook de controle do GPU Stack (Ollama + Open WebUI).

Expõe endpoints HTTP para subir, derrubar e verificar o status
do docker-compose da GPU Stack sem precisar de acesso SSH.

Endpoints:
  GET /gpu/start  — sobe o GPU Stack (não bloqueante)
  GET /gpu/stop   — derruba o GPU Stack e desliga o sistema
  GET /status     — retorna se os containers estão rodando
  GET /health     — health check simples para o Homepage
"""

import json
import subprocess
from flask import Flask, jsonify

app = Flask(__name__)

# Caminho para o docker-compose.yml do GPU Stack dentro do container
GPU_COMPOSE_FILE = "/opt/gpu-stack/docker-compose.yml"


@app.route("/gpu/start")
def gpu_start():
    """Sobe o GPU Stack (Ollama + Open WebUI) de forma não bloqueante."""
    try:
        # Popen não bloqueia — o container sobe em background
        subprocess.Popen(
            ["docker", "compose", "-f", GPU_COMPOSE_FILE, "up", "-d"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return jsonify({"status": "starting", "message": "GPU Stack sendo iniciado"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/gpu/stop")
def gpu_stop():
    """Derruba o GPU Stack e depois desliga o sistema."""
    try:
        # Derruba os containers do GPU Stack
        subprocess.Popen(
            ["docker", "compose", "-f", GPU_COMPOSE_FILE, "down"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        # Agenda o desligamento do sistema (não bloqueante)
        subprocess.Popen(
            ["sudo", "shutdown", "now"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return jsonify({"status": "stopping", "message": "GPU Stack sendo desligado e sistema encerrando"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/status")
def status():
    """Verifica se os containers do GPU Stack estão rodando."""
    try:
        result = subprocess.run(
            ["docker", "compose", "-f", GPU_COMPOSE_FILE, "ps", "--format", "json"],
            capture_output=True,
            text=True,
            timeout=10,
        )

        containers = []
        running = False

        if result.returncode == 0 and result.stdout.strip():
            # O output pode ser múltiplas linhas JSON (uma por container)
            for line in result.stdout.strip().splitlines():
                try:
                    container = json.loads(line)
                    containers.append(container.get("Name", ""))
                    # Considera rodando se ao menos um container está up
                    if container.get("State") == "running":
                        running = True
                except json.JSONDecodeError:
                    continue

        return jsonify({
            "running": running,
            "containers": containers,
        })
    except subprocess.TimeoutExpired:
        return jsonify({"status": "error", "message": "Timeout ao verificar status"}), 504
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/health")
def health():
    """Health check simples — usado pelo Homepage para verificar se o webhook está ativo."""
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
