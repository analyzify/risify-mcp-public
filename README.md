# risify-mcp

A Model Context Protocol (MCP) server for the Risify GraphQL API. Helps AI assistants search the schema and write correct GraphQL queries and mutations.

## Install

### macOS / Linux

```bash
curl -sL https://raw.githubusercontent.com/analyzify/risify-mcp-public/main/install.sh | sh
```

This auto-detects your OS and architecture, downloads the latest binary, and installs it to `/usr/local/bin`.

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/analyzify/risify-mcp-public/main/install.ps1 | iex
```

This downloads the latest Windows binary and installs it to `%LOCALAPPDATA%\risify-mcp`, automatically adding it to your PATH.

**Supported platforms:** macOS (Intel/Apple Silicon), Linux (amd64/arm64), Windows (amd64/arm64)

### Manual install

Download the binary for your platform from the [Releases](https://github.com/analyzify/risify-mcp-public/releases/latest) page, extract it, and place it somewhere in your `$PATH`.

### Verify

```bash
risify-mcp version
```

On Windows, you can also use: `risify-mcp.exe version`

## Configuration

Add to your MCP client configuration:

**Claude Code** (`.claude/settings.json`):

```json
{
  "mcpServers": {
    "risify": {
      "command": "risify-mcp",
      "args": ["serve"],
      "env": {
        "RISIFY_USER_ID": "your-user-id",
        "RISIFY_API_KEY": "your-api-key"
      }
    }
  }
}
```

**Claude Desktop** (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "risify": {
      "command": "risify-mcp",
      "args": ["serve"],
      "env": {
        "RISIFY_USER_ID": "your-user-id",
        "RISIFY_API_KEY": "your-api-key"
      }
    }
  }
}
```

**Cursor / VS Code** (MCP settings):

```json
{
  "risify": {
    "command": "risify-mcp",
    "args": ["serve"],
    "env": {
      "RISIFY_USER_ID": "your-user-id",
      "RISIFY_API_KEY": "your-api-key"
    }
  }
}
```

> Without env vars, the server works in schema-only mode (search + full schema tools).

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `RISIFY_USER_ID` | yes | — | Your Risify user ID |
| `RISIFY_API_KEY` | yes | — | Your Risify API key |
| `RISIFY_API_URL` | no | Production API | GraphQL endpoint URL (override for custom environments) |

## Testing

After installation, verify everything works:

### 1. Public route (no auth needed)

```bash
risify-mcp query '{ ping }'
```

Expected:

```json
{
  "data": {
    "ping": "pong"
  }
}
```

### 2. Authenticated route

Set your credentials and test the `me` query:

```bash
RISIFY_USER_ID="your-user-id" \
RISIFY_API_KEY="your-api-key" \
  risify-mcp query '{ me { id email firstName lastName shopName } }'
```

Expected (with valid credentials):

```json
{
  "data": {
    "me": {
      "id": "...",
      "email": "...",
      "firstName": "...",
      "lastName": "...",
      "shopName": "..."
    }
  }
}
```

### 3. Schema search (offline)

```bash
risify-mcp search audit
risify-mcp search product --filter queries
risify-mcp search recommendation --filter mutations
```

## CLI Commands

```bash
risify-mcp serve                                    # Start MCP server (stdio)
risify-mcp serve --transport sse --addr :8080       # Start MCP server (SSE HTTP)
risify-mcp search audit                             # Search schema for "audit"
risify-mcp search product --filter queries          # Search queries only
risify-mcp query '{ ping }'                         # Execute a query
risify-mcp version                                  # Print version
```

## MCP Tools

| Tool | Description |
|------|-------------|
| `introspect_schema` | Search the schema for types, queries, and mutations by name |
| `graphql_schema_full` | Returns the complete schema in SDL format |
| `execute_graphql` | Execute a GraphQL query/mutation against the live API |

## Uninstall

### macOS / Linux

```bash
sudo rm /usr/local/bin/risify-mcp
```

### Windows (PowerShell)

```powershell
Remove-Item "$env:LOCALAPPDATA\risify-mcp" -Recurse -Force
```

After removal, you may also want to remove `%LOCALAPPDATA%\risify-mcp` from your PATH environment variable via System Settings.
