#!/usr/bin/env python3
"""
git-memfs-server.py — Local git HTTP smart protocol server for Letta MemFS.
Serves bare git repos via git http-backend so Letta Code can clone/push/pull
against your own machine instead of Letta Cloud.
"""
import os, subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse

PORT = 8285
MEMFS_BASE = Path.home() / ".letta" / "memfs" / "repository"
DEFAULT_ORG = "default-org"

def find_or_create_repo(agent_id, org_id):
    repo = MEMFS_BASE / org_id / agent_id / "repo.git"
    if not repo.exists():
        if MEMFS_BASE.exists():
            for org_dir in MEMFS_BASE.iterdir():
                candidate = org_dir / agent_id / "repo.git"
                if candidate.exists():
                    return candidate
        repo.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "--bare", str(repo)], check=True, capture_output=True)
        subprocess.run(["git", "-C", str(repo), "config", "http.receivepack", "true"],
                       check=True, capture_output=True)
        print(f"[git-memfs] Created bare repo at {repo}", flush=True)
    return repo

class GitHTTPHandler(BaseHTTPRequestHandler):
    def _read_body(self):
        te = self.headers.get("Transfer-Encoding", "")
        if "chunked" in te.lower():
            body = b""
            while True:
                size_line = self.rfile.readline().strip()
                if not size_line: break
                try: chunk_size = int(size_line, 16)
                except ValueError: break
                if chunk_size == 0:
                    self.rfile.readline()
                    break
                body += self.rfile.read(chunk_size)
                self.rfile.readline()
            return body
        else:
            n = int(self.headers.get("Content-Length", 0) or 0)
            return self.rfile.read(n) if n > 0 else b""

    def _parse_path(self):
        parsed = urlparse(self.path)
        parts = parsed.path.strip("/").split("/")
        if len(parts) < 3 or parts[0] != "git": return None, None, None
        agent_id = parts[1]
        git_op = "/" + "/".join(parts[3:]) if len(parts) > 3 else "/"
        return agent_id, git_op, parsed.query or ""

    def _run_backend(self):
        agent_id, git_op, query = self._parse_path()
        if agent_id is None:
            self.send_error(400, "Expected /git/{agent_id}/state.git/...")
            return
        org_id = self.headers.get("X-Organization-Id", DEFAULT_ORG)
        repo_path = find_or_create_repo(agent_id, org_id)
        body = self._read_body()
        project_root = str(repo_path.parent).replace("\\", "/")
        env = {**os.environ,
            "GIT_HTTP_EXPORT_ALL": "1",
            "GIT_PROJECT_ROOT": project_root,
            "PATH_INFO": "/repo.git" + git_op,
            "QUERY_STRING": query,
            "REQUEST_METHOD": self.command,
            "CONTENT_TYPE": self.headers.get("Content-Type", ""),
            "CONTENT_LENGTH": str(len(body)),
            "HTTP_GIT_PROTOCOL": self.headers.get("Git-Protocol", ""),
            "REMOTE_ADDR": "127.0.0.1", "REMOTE_USER": "",
            "SERVER_NAME": "localhost", "SERVER_PORT": str(PORT),
            "SERVER_PROTOCOL": "HTTP/1.1"}
        result = subprocess.run(["git", "http-backend"], input=body,
                                capture_output=True, env=env)
        if result.returncode != 0:
            print(f"[git-memfs] error: {result.stderr.decode(errors='replace')}", flush=True)
            self.send_error(500); return
        raw = result.stdout
        for sep in [b"\r\n\r\n", b"\n\n"]:
            pos = raw.find(sep)
            if pos != -1: break
        else:
            self.send_error(502); return
        header_block = raw[:pos].decode(errors="replace")
        body_out = raw[pos + len(sep):]
        status = 200
        headers = []
        for line in header_block.splitlines():
            if ":" in line:
                k, _, v = line.partition(":"); k, v = k.strip(), v.strip()
                if k.lower() == "status":
                    try: status = int(v.split()[0])
                    except ValueError: pass
                else: headers.append((k, v))
        self.send_response(status)
        for k, v in headers: self.send_header(k, v)
        self.send_header("Content-Length", str(len(body_out)))
        self.end_headers()
        self.wfile.write(body_out)

    def do_GET(self): self._run_backend()
    def do_POST(self): self._run_backend()
    def log_message(self, fmt, *args):
        print(f"[git-memfs] {self.address_string()} — {fmt % args}", flush=True)

if __name__ == "__main__":
    MEMFS_BASE.mkdir(parents=True, exist_ok=True)
    print(f"[git-memfs] Starting on http://0.0.0.0:{PORT}", flush=True)
    HTTPServer(("0.0.0.0", PORT), GitHTTPHandler).serve_forever()