# LAM - Long-term AI Memory

LLMs are stateless. Every new request is independent of previous ones unless context is explicitly provided. The context window, i.e. the maximum amount of information that the LLM can consider at one time, is limited (for example, 128K tokens in Gemini 3 Pro High). To overcome these limitations, all major LLM providers utilize background processes to consolidate conversation history into summaries. These summaries are the RAM of LLMs. And the entire conversation history is the hard drive of LLMs. These providers also have algorithms to consolidate user input (e.g. chat messages, input files, etc.), user-provided preferences and constraints, summaries in the RAM, and some of the recent conversation history into a context window. The whole system together gives the illusion of long-term memory for LLMs.

[Mem0] provides similar functionality but separate from any major LLM provider's ecosystem. It is a client-side framework and runs on the same computer as the client. It is written in TypeScript. It has a CLI, an ADE, and a Code IDE. It is not tied to any particular LLM provider. It can be connected to any LLM provider through an API proxy server. But its memory management process is like a black box.

[Letta] provides similar functionality as Mem0, but in a different way. It is a server-side framework and runs on a remote server. It can be connected to any LLM provider through an API proxy server. Its memory management is done through git controlled Markdown files. Its consolidation process is recorded as git commit logs, which is transparent and traceable.

This repository contains configurations and documentation of a [Letta] [API] proxy [server] in a [Docker] container on [Hetzner] that manages AI memory using [MemFS] over [git] and [PostgreSQL] with [pgvector]:

- **[MemFS] via [git]**: RAM, stores the AI's core "identity"—persona, learned preferences, behavioral rules, and project-specific knowledge.
- **[PostgreSQL] with [pgvector]**: hard disk, stores operational metadata, including agent configurations, message history, and vector embeddings ([pgvector]) for semantic search.

The server can be accessed by [Antigravity] through an [MCP] server, the official Letta [ADE], the Letta Code [CLI], but not by the Letta Code [Desktop], which uses the official Letta [API] server. Note that the [ADE] and [Desktop] app are not using the [MemFS] yet. Instead, they store "block memory" (which will be deprecated in the future) using the official Letta server. Only Letta Code [CLI] provides the full [MemFS] functionality.

Note that Letta Code [CLI] is not only a client. It also contains a server component written in TypeScript. This self-hosted API proxy server is written in python instead. [Letta] documentation talks about running a remote environment so that one can use his phone to connect to an agent running on that remote environment. This is accomplished by launch a server through the Letta Code CLI, not a standalone self-hosted API proxy server like this. This sounds very useful, but is in practice very limiting. It only allow 3 agents created on the cloud to use the remote Letta Code server for calculation.

## Files

- [compose.yaml](compose.yaml): the Docker [compose] file to start 3 services:
  - a [Letta] API proxy server to connect to AI model providers (e.g. OpenAI, Ollama, Google).
  - a [Git] server to handle [MemFS] memory storage.
  - a [PostgreSQL] server for the [Letta] server, including [pgvector] extension for vector storage.
- [letta](letta)
  - [database/init.sql](letta/database/init.sql): a SQL script to [enable the vector extension][pgvector] for [PostgreSQL]. The script is executed automatically when a new [PostgreSQL] database is created.
  - [git](letta/git): Files to build the Docker image of the [Git] server to handle [MemFS] memory storage.
    - [Dockerfile](letta/git/Dockerfile): Dockerfile to build the image
    - [git-memfs-server.py](letta/git/git-memfs-server.py): Git-based MemFS server implementation
  - [cli/statusline.py](letta/cli/statusline.py): a Python script to show token usage in Letta [CLI].
- [backup.sh](backup.sh): back up the [PostgreSQL] database to \*.qsl.gz files; also pushes MemFS of all agents to their GitHub repositories if runs in the client side.
- [restore.sh](restore.sh): restore the [PostgreSQL] database from the latest zipped backup file; also pulls latest MemFS from GitHub repositories.

## Deployment

First, log into [Hetzner] server, `git clone` this repo, cd into the working dir, and then run `docker compose up -d` to start all services. The `healthcheck` and `depends_on` settings ensure services are started in the correct order. `healthcheck` also helps report malfunctions of services within 5 minutes. Run `docker compose down` to stop all services if no longer needed. Otherwise, the services will be restarted automatically whenever Docker restarts due to the `unless-stopped` setting in `compose.yaml`.

Second, install Letta [CLI] in the client side (e.g. your personal computer), and then add the following to `~/.zshrc` or `~/.bashrc`.

```bash
# point Letta CLI to the remote Letta server
export LETTA_BASE_URL="http://hetzner_ip:8283"
# use the server password from .env file
export LETTA_API_KEY="${LETTA_PASSWORD}(in .env)"
# git clone MemFS repo for each agent on the server to ~/.letta/agents/agent-ID/memory
export LETTA_MEMFS_LOCAL=1
# point Letta CLI to the remote Letta git server for MemFS
export LETTA_MEMFS_BASE_URL="http://hetzner_ip:8285"
```

Then run `letta` in a new terminal and a project folder. Letta [CLI] will prompt you to create an agent. Choose [gemini-flash-lite-latest] as the default model for the agent as it permits 500 peak requests per day (PRD). Other models are too limiting. Metadata of the agent will be saved in the [PostgreSQL] database on the server.

Inside Letta CLI, run `/init` to initialize the memory of the agent by letting the agent scan your project folder. A bare git repo will be created in `/root/.letta/memfs/repository/default-org/agent-ID/` on the server, and then cloned to `~/.letta/agents/agent-ID/memory` on the client side. Changes on the client side will be automatically pushed to the server's git repo. Set a GitHub repo for each agent as another remote on the client side so that the memory can be backed up to GitHub.

One can also use `/remember` in the [CLI] to help the agent update its memory. The contents of `~/.letta/agents/agent-ID/memory` can be visualized using the `/palace` and `/memory` command inside Letta [CLI]. The `/ade` command opens an [ADE] in a browser. As mentioned before, it doesn't use [MemFS], hence is not very useful. Note that the "Create an agent" button on the Letta [ADE] currently has the provider name "zai" hard-coded that doesn't exist in the self-hosted Letta server, hence cannot be used. Agents should be created via the [CLI].

## Backup

Three things need to be backed up:

1. The configuration of the system, which is saved as this git repo.
2. The [PostgreSQL] database on the server. This is done once per week by a cron job running [backup.sh](backup.sh).
3. The [MemFS] system. Their repositories in the server's `/root/.letta/memfs/repository/` directory are bare git repos, which are hard to back up. But their client side working folders can be synced to their second remote on GitHub by running [backup.sh](backup.sh) on the client side after each working session.

## Restore

### Restore the client

Given a running server, deploying the client on a new laptop is easy. Just follow the second step described in [Deployment](#Deployment) to install Letta [CLI] and set the environment variables and environment variables. Upon running `letta`, all memories will be copied from the server to the client side, including [MemFS] memory. However, one still need to run [restore.sh](restore.sh) on the client side to connect the local [MemFS] to the GitHub remote, or it cannot be backed up to GitHub. After this initial setup, all memories can be backed up to GitHub by running [backup.sh](backup.sh) on the client side after each working session.

### Restore the server

Deploy the system in a new server follows the same procedure as described in the first paragraph of [Deployment](#Deployment). Then restore the [PostgreSQL] database from the latest zipped backup file copied from the old server using [restore.sh](restore.sh) on the new server.

Direct an old client to the new server, call each agent so that their local [MemFS] repo is connected to the bare repo on the new server. Then run [restore.sh](restore.sh) on the client side to make sure that the local [MemFS] gets the latest version from GitHub instead of been overwritten by the version on the server, which is empty at this moment. Letta Code CLI will automatically sync the local [MemFS] to the new server.

## Implementation Details

### Secrets and Environment Variables

Environment variables used by the services are listed in `.env`, which is git ignored. It is backed up in macOS password app manually. Random keys inside the file are generated using `openssl rand -base64 32`.

### Labels for Letta Core Memory

The concept of "labelled blocks in core memory" is replaced by [MemFS](https://docs.letta.com/concepts/memfs) in the self-hosted server, but still exists in the official Letta cloud [ADE].

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

### Token & Context Mechanics

#### Token Estimation

A reliable rule of thumb for English is 1,000 tokens ~ 750 words. However, technical content like C++ code or LaTeX is "denser" and can consume 2–3x more tokens due to symbols and indentation.

#### Context Composition

In Letta, your "Input Context" is the sum of:

- System Prompt (Who the agent is).
- Core Memory/MemFS (Pinned files like persona.md).
- Chat History (The sliding window of recent messages).
- Current Prompt + @Attachments (The new data you just provided).

#### Optimization Strategies

The "Summarize & Clear" Loop: Periodically asking the agent to summarize the conversation into a MemFS file and then clearing the history is the most effective way to reduce token usage and filter out noise. This keeps the agent focused while preserving the "essence" of the work in a searchable format. However, this should eventually be an obsolete strategy once Letta handles the context management in a more sophisticated way.

#### Google Gemini Billing & Limits

- **TPM Reset**: The Tokens Per Minute (TPM) limit is a rolling window. If you hit the ceiling (e.g., 250K for Flash Lite), you typically only need to wait 1–5 minutes for the "bucket" to empty.
- **Privacy via Billing**: Attaching billing information is a "privacy toggle." Once a billing account is linked, your data is governed by Paid Tier terms (not used for training), even if your actual monthly usage stays within the $0.00 free limit.
- **Priority**: Google prioritizes paid requests over free requests when the server is under heavy load. I can feel clearly the increase in response speed after I deposited a small amount of money to my Google AI Studio account.

#### Technical Verification

One can verify exactly what is being sent (and check for "token bloat") by running Letta with the --debug flag and inspecting the log of the container in Docker Desktop.

### MemFS as PIM (Personal Information Management) System

It is a great way for me to organize my ideas in Markdown format with the help of AI. My current project stays in the `system/` folder, once I finish it, I will instruct AI to move it out of `system/` folder so that I can start a new project in `system/` folder. As time goes by, my knowledge in that specific domain will be preserved in the MemFS, and I can access it through AI instead of manual grepping. The writing and organization is completely taken over by AI. MemFS is a new approach to PIM.

[Mem0]: https://mem0.ai
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
[CLI]: https://docs.letta.com/letta-code/cli
[gemini-flash-lite-latest]: https://aistudio.google.com/rate-limit
[Ollama]: https://ollama.com
[Hetzner]: https://hetzner.com
[Desktop]: https://docs.letta.com/letta-code/desktop-app
