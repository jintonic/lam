FROM python:3.11-slim
RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*
COPY git-memfs-server.py /app/git-memfs-server.py
CMD ["python", "/app/git-memfs-server.py"]
