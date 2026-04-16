FROM python:3.11-slim
RUN apt-get update && apt-get install -y wakeonlan iputils-ping && pip install flask
WORKDIR /app
COPY wol.py .
EXPOSE 5001
CMD ["python", "wol.py"]
