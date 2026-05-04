# LAM - Long-term AI Memory

The web-based chat interface of [Gemini] keeps chat history only for 18 months. In contrast, [Letta] keeps chat history (and memories) indefinitely using local storage.

This repository contains configurations and documentations for a [Letta] server running in a [Docker] container that saves long-term memory to a [PostgreSQL] database, which is backed up to [OneDrive].
It can also be used by agents in [Antigravity] through a [MCP] server, which provides tools to interact with the Letta server.

## Contents

- [compose.yaml](compose.yaml): the Docker [compose] file to start three services:
  - a self-hosted [Letta] server,
  - a [PostgreSQL] server for the [Letta] server to store its memories, and
  - a [MCP] server for [Antigravity] to interact with the Letta server.
- [initdb.d/init.sql](initdb.d/init.sql): a SQL script to [enable the vector extension][pgvector] for [PostgreSQL]. The script is executed automatically when a new [PostgreSQL] database is created.
- [backup.sh](backup.sh): dump the database to OneDrive, zipped.

## Quick Start

First, run `docker compose up -d` to start all services. The `healthcheck` and `depends_on` settings ensure services are started in the correct order. `healthcheck` also helps report malfunctions of services within 5 minutes. Run `docker compose down` to stop all services if no longer needed. Otherwise, the services will be restarted automatically whenever Docker Desktop starts due to the `restart` setting.

Second, ask Antigravity to verify the connection and set up an agent for you. You can give a multi-step instruction like: "Test the Letta MCP connection, check if there are any existing agents, and if not, create a new agent named [Name] with [Persona]."

Note that the "Create an agent" button on the Letta [ADE] currently has the provider name "zai" hard-coded that doesn't exist in the self-hosted Letta server. Creating the agent via Antigravity bypasses this issue and allows you to set up your agents using natural language.

Third, go to <https://app.letta.com>, click "Default Project", choose "Manage Project", then click "Connect to a server" button for the first time. Insert <http://localhost:8283> in the field for the server URL, and the password from `.env` (as `LETTA_PASSWORD`) into the password field, then save.

Finally, select "Self-hosted servers" tab, select the server you have connected before, click "View agents" button, select the agent you have created, then you can start using it or configure it further (e.g. add tools, set model, etc.).

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

[Gemini]: https://gemini.google.com
[Letta]: https://letta.com
[Docker]: https://www.docker.com
[PostgreSQL]: https://www.postgresql.org
[OneDrive]: https://www.microsoft.com/en-us/microsoft-365/onedrive/overview
[Antigravity]: https://antigravity.google.com
[MCP]: https://modelcontextprotocol.io
[pgvector]: https://github.com/pgvector/pgvector#getting-started
[compose]: https://docs.docker.com/compose
[ADE]: https://app.letta.com
