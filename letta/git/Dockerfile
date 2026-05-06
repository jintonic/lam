# https://hub.docker.com/r/letta/letta uses Python-3.11
FROM python:3.11-slim
# git for MemFS, curl to check service health
RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*
# https://github.com/Corykidios/local_letta_memfs_magic
COPY git-memfs-server.py /app/git-memfs-server.py
# server listening on port 8285
CMD ["python", "/app/git-memfs-server.py"]
