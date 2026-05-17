# ChangeLog

## Antigravity and MCP Server

The repo started as a Mac only project. The services are running in Docker Desktop on Mac. A MCP service was included in `compose.yaml` for the local Antigravity to connect to.

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

This MCP service has been removed from `compose.yaml` after the server has been deployed to Hetzner. Everything MCP can do is now provided by Letta CLI.

### Letta ADE and Caddy Server

One can use the cloud based Letta ADE (<https://app.letta.com>) to configure or to chat with the already created agents on Hetzner.

However, the Letta server on Hetzner receives connections through HTTP instead of HTTPS. If one wants to use <https://app.letta.com> to connect to it, one can run a caddy server as a reverse proxy as described in the Letta documentation: <https://docs.letta.com/guides/docker/#connecting-the-ade-to-your-server> to direct connections to an HTTPS endpoint to the Letta server listening through HTTP. This HTTPS endpoint is obtained by setting an A record `letta.physino.xyz` to point to the Hetzner server.

With this setting, after logging into <https://app.letta.com>, click "Default Project", choose "Manage Project", then click "Connect to a server" button for the first time. Insert <https://letta.physino.xyz> in the field for the server URL, and the password from `.env` (as `LETTA_PASSWORD`) into the password field, then save. Select "Self-hosted servers" tab, select the server you have connected before, click "View agents" button, select the agent you have created, then you can start using it or configure it further (e.g. add tools, set model, etc.).

**NOTE**: the memory blocks in ADE are an old implementation and are not part of the MemFS system, and display different data from what is stored in the MemFS. This renders it useless as a UI to interact with the agents on a phone. The Caddy server was then removed.
