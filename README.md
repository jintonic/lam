# LAM - Long-term AI Memory

This repository contains configurations and documentation of a self-hosted [Letta] [API] proxy [server] running in a [Docker] container that saves AI's memory using [MemFS] over [git], and uses [PostgreSQL] for metadata. The database is backed up to [OneDrive].

- **[MemFS] (via [git])**: Stores the AI's core "identity"—persona, learned preferences, behavioral rules, and project-specific knowledge.
- **[PostgreSQL]**: Stores operational metadata, including agent configurations, message history, and vector embeddings ([pgvector]) for semantic search.

The server can be accessed via [API] by other programs, including [Antigravity] through an [MCP] server, and the official Letta [ADE].

## Files

- [compose.yaml](compose.yaml): the Docker [compose] file to start 5 services:
  - a [Letta] API proxy server to connect to AI model providers (e.g. OpenAI, Ollama, Google).
  - a [Git] server to handle [MemFS] memory storage.
  - a [Redis] server to prevent [Git] and [Letta] accessing the same [MemFS] storage at the same time.
  - a [PostgreSQL] server for the [Letta] server, including [pgvector] extension for vector storage.
  - a [MCP] server for [Antigravity] to interact with the [Letta] server.
- [letta](letta)
  - [database/init.sql](letta/database/init.sql): a SQL script to [enable the vector extension][pgvector] for [PostgreSQL]. The script is executed automatically when a new [PostgreSQL] database is created.
  - [git](letta/git): Files to build the Docker image of the [Git] server to handle [MemFS] memory storage.
- [backupDB.sh](backupDB.sh): back up the [PostgreSQL] database to OneDrive, zipped.
- [restoreDB.sh](restoreDB.sh): restore the [PostgreSQL] database from the latest zipped backup file.

## Quick Start

First, run `docker compose up -d` to start all services. The `healthcheck` and `depends_on` settings ensure services are started in the correct order. `healthcheck` also helps report malfunctions of services within 5 minutes. Run `docker compose down` to stop all services if no longer needed. Otherwise, the services will be restarted automatically whenever Docker Desktop starts due to the `restart` setting.

Second, install Letta [CLI], add the following to `~/.zshrc` or `~/.bashrc`.

```bash
# point Letta CLI to the local Letta server
export LETTA_BASE_URL="http://localhost:8283"
# fake API key to satisfy Letta CLI's initialization check
export LETTA_API_KEY="local-dev-no-auth"
# git clone MemFS repo for each agent on the server to ~/.letta/agents/agent-ID/memory
export LETTA_MEMFS_LOCAL=1
# point Letta CLI to the local Letta server for MemFS
export LETTA_MEMFS_BASE_URL="http://localhost:8283"
```

Then run `letta` in a new terminal and a project folder. Letta [CLI] will prompt you to create an agent. Choose [gemini-flash-lite-latest] as the default model for the agent as it permits 500 peak requests per day (PRD). Other models are too limiting.

Inside Letta CLI, run `/init` to initialize the memory of the agent by letting the agent scan your project folder. This will create `~/.letta/agents/agent-ID/memory` and trigger the server's git-memfs to create a git repo for the agent to store its memory in MemFS.

One can then use `/remember` to help the agent update its memory. The contents of `~/.letta/agents/agent-ID/memory` is synced with the git repo on the server, can be visualized using the `/palace` command inside Letta [CLI]. The `/ade` command opens an [ADE] in a browser, but its contents are not synced well with the [CLI], hence is less useful.

Note that the "Create an agent" button on the Letta [ADE] currently has the provider name "zai" hard-coded that doesn't exist in the self-hosted Letta server, hence cannot be used. Agents should be created via the [CLI].

However, one can still use the [ADE] to configure an already created agent. In this case, after logging into <https://app.letta.com>, click "Default Project", choose "Manage Project", then click "Connect to a server" button for the first time. Insert <http://localhost:8283> in the field for the server URL, and the password from `.env` (as `LETTA_PASSWORD`) into the password field, then save. Select "Self-hosted servers" tab, select the server you have connected before, click "View agents" button, select the agent you have created, then you can start using it or configure it further (e.g. add tools, set model, etc.). **NOTE**: the memory blocks in [ADE] are not synced with the [CLI].

## Documentation

### Secrets and Environment Variables

Environment variables used by the services are listed in `.env`, which is git ignored; random keys inside the file are generated using `openssl rand -base64 32`.

### Antigravity and MCP server

The following `~/.gemini/antigravity/mcp_config.json` tells Antigravity how to use the Letta MCP server:

```json
{
  "mcpServers": {
    "letta-native": {
      "command": "docker",
      "args": [
        "exec",
        "-i",
        "-e",
        "TRANSPORT=stdio",
        "-e",
        "RUST_LOG=error",
        "letta-mcp",
        "letta-server"
      ]
    }
  }
}
```

It can be created by clicking "..." at the top-right corner in the Antigravity UI, then "MCP Servers", click "Manage MCP servers", then click "View raw config", then paste the above json into the text area and save.

### Labels for Letta Core Memory

There can be many labeled blocks in Letta Core Memory. Two important ones are

- **persona**: the persona of the agent created in Letta, which is used to configure the agent's behavior
- **human**: information of the human user

### Shell Environment Used by Agents

Agents inside Letta [CLI] uses `~/.zshenv` on a Mac to initialize their shell environments. Make sure that the `$PATH` environment variable is set up correctly there. Otherwise, the agents may not be able to find the tools they need.

### Local LLM

```sh
brew install ollama
ollama serve
ollama pull llama3.1:8b
ollama pull mxbai-embed-large
ollama list
```

The following environment variables should be given to the [Letta] server to use the local [Ollama] server in [compose.yaml](compose.yaml):

- `OPENAI_API_KEY`: not used, set to a dummy value
- `OLLAMA_BASE_URL`: http://host.docker.internal:11434/v1, according to <https://docs.letta.com/letta-code/docker#using-letta-code-with-local-llm-inference>

### Restoration & Migration

The system supports a two-layered restoration process to migrate agents to new environments:

1. **Database Restoration (`./restore.sh`)**: Restores the PostgreSQL database from OneDrive backups. This is critical as it contains the unique `AGENT_ID` registered to the server, which serves as the primary key for the system.
2. **Memory Restoration (`./restore.sh <agent_name>`)**: Configures the local agent's MemFS repository to sync with your GitHub backup (`jintonic/<agent_name>.git`) and pulls the latest memory files.

[server]: https://docs.letta.com/letta-code/docker
[API]: https://docs.letta.com/guides/get-started/intro
[Gemini]: https://gemini.google.com
[Letta]: https://letta.com
[Docker]: https://www.docker.com
[git]: https://git-scm.com/
[MemFS]: https://memfs.org/
[PostgreSQL]: https://www.postgresql.org
[OneDrive]: https://www.microsoft.com/en-us/microsoft-365/onedrive/overview
[Antigravity]: https://antigravity.google.com
[MCP]: https://modelcontextprotocol.io
[pgvector]: https://github.com/pgvector/pgvector#getting-started
[compose]: https://docs.docker.com/compose
[ADE]: https://app.letta.com
[Redis]: https://redis.io
[CLI]: https://docs.letta.com/letta-code/cli
[gemini-flash-lite-latest]: https://aistudio.google.com/rate-limit
[Ollama]: https://ollama.com
