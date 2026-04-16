FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && curl -fsSL https://get.docker.com | sh \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask

WORKDIR /app
COPY webhook.py .
EXPOSE 5000
CMD ["python", "webhook.py"]