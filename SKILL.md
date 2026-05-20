---
name: opencode-bootstrap
description: Use when setting up a new OpenCode instance from scratch, replicating an existing configuration, installing plugins/skills/MCP servers, configuring auto-loading rules in AGENTS.md, or migrating an OpenCode setup to a new machine (Windows, Linux, macOS)
---

# OpenCode Bootstrap

## Overview

Automates the replication of a full OpenCode environment: plugins, skills, MCP servers, API-key prompts, AGENTS.md rules, and optional sub-configs (quota, DCP, TUI, local graphify plugin).

## Usage

```bash
opencode ask "Bootstrap my OpenCode setup from the opencode-bootstrap skill"
```

The agent will:
1. Detect the OS (Windows/Linux/macOS)
2. Prompt for API keys (GitHub, Gmail, Magic, OpenCode-quota)
3. Write `opencode.json` with all plugins + MCPs
4. Install skills
5. Write `AGENTS.md` with auto-loading rules
6. Optionally set up DCP, TUI, quota configs and local graphify plugin

## OS Detection & Paths

| OS | Config Root |
|----|-------------|
| **Windows** | `%USERPROFILE%\.config\opencode\` |
| **Linux/macOS** | `~/.config/opencode/` |

The local directory `~/.opencode/` is `%USERPROFILE%\.opencode\` on Windows.

## What Gets Installed

### Plugins (6)
| Plugin | Source |
|--------|--------|
| `opencode-agent-skills` | npm (joshuadavidthomas) |
| `background-agents` | npm |
| `btw-opencode` | npm |
| `@tarquinen/opencode-dcp@latest` | npm |
| `superpowers@git+https://github.com/obra/superpowers.git` | git |
| `@slkiser/opencode-quota` | npm |

### MCP Servers (6)
| Server | Package | Needs API Key |
|--------|---------|---------------|
| filesystem | `@modelcontextprotocol/server-filesystem` | No |
| puppeteer | `@modelcontextprotocol/server-puppeteer` | No |
| memory | `@modelcontextprotocol/server-memory` | No |
| github | `@modelcontextprotocol/server-github` | **Yes** (GitHub PAT) |
| gmail | `gmail-mcp-imap` | **Yes** (app password) |
| magic | `@21st-dev/magic@latest` | **Yes** (API key) |

### Skills (8+)
Installed from config skills directory:
- `output-skill` — Always active, prevents truncation
- `impeccable` — Full frontend design
- `minimalist-skill` — Editorial/minimalist UI
- `brutalist-skill` — Technical/terminal UI
- `frontend-slides` — HTML presentations
- `playwright-skill` — Browser automation
- `ui-ux-pro-max` — Design research
- `graphify` — Knowledge graph from code/docs

Plus optional taste-skill sub-skills (brandkit, imagegen-*).

## API Key Collection

| Variable | MCP | How to get |
|----------|-----|------------|
| `GITHUB_PERSONAL_ACCESS_TOKEN` | github | https://github.com/settings/tokens (repo, issues scope) |
| `GMAIL_EMAIL` | gmail | Your Gmail address |
| `GMAIL_APP_PASSWORD` | gmail | https://myaccount.google.com/apppasswords |
| `MAGIC_API_KEY` | magic (21st-dev) | https://21st.dev settings |
| `OPENCODE_QUOTA_WORKSPACE_ID` | quota plugin | From existing quota config |
| `OPENCODE_QUOTA_AUTH` | quota plugin | From existing quota config |

If an API key is not provided, disable that MCP server.

## Step-by-step

### 1. Create config directory & structure
```
.config/opencode/
├── opencode.json
├── AGENTS.MD
├── tui.json
├── dcp.jsonc
├── package.json
├── skills/           # Copied from source
└── opencode-quota/
    └── opencode-go.json
.opencode/
├── opencode.json
├── plugins/
│   └── graphify.js
└── skills/           # Copied from source
```

Root is `%USERPROFILE%` on Windows, `~` on Linux/macOS.

### 2. Write opencode.json
- Add all 6 plugins to the `"plugin"` array
- Add all 6 MCP servers with their `type`, `command`, and `environment`
- Use user-provided API keys (never hardcode)
- Skip or disable MCPs when the user declines to provide keys

On Windows, the filesystem MCP path uses forward slashes in JSON:
```json
"command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "C:/Users/username"]
```

### 3. Install skills
Copy the skills directory from a reference/backup:
```bash
# Linux/macOS
rsync -av user@old-machine:.config/opencode/skills/ ~/.config/opencode/skills/

# Windows (PowerShell)
Copy-Item -Recurse "$source\.config\opencode\skills\*" "$env:USERPROFILE\.config\opencode\skills\"
```

### 4. Write AGENTS.md
The AGENTS.md contains auto-loading rules (in French, adapt as needed):
```markdown
# Global Rules

## Auto-loading des skills
### Toujours actif
- `output-skill`

### Design / UI
- Créer/modifier une interface → `impeccable`
- Design minimaliste/éditorial → `minimalist-skill` + `impeccable`
- Design brutaliste/technique → `brutalist-skill` + `impeccable`
- Présentation/slides → `frontend-slides`
- Recherche design/inspiration → `ui-ux-pro-max`

### Testing / Browser
- Tester une page web → `playwright-skill`

### Never auto-load
- Deleted skills
```

On Windows, omit privileged command rules (`pkexec`/`sudo`).

### 5. Optional sub-configs
- **DCP**: Write `dcp.jsonc` with the DCP schema
- **TUI**: Write `tui.json` with `@slkiser/opencode-quota` plugin
- **Quota**: Write `opencode-quota/opencode-go.json` (needs workspace ID + auth cookie)
- **Graphify plugin**: Write `.opencode/plugins/graphify.js`
- **Graphify project configs**: Write `.opencode/opencode.json` per project

### 6. Install npm dependencies
```bash
npm install @opencode-ai/plugin unique-names-generator
```

## Companion Scripts

| Script | OS | Path |
|--------|----|------|
| `bootstrap.ps1` | Windows | Companion to this skill |
| `bootstrap.sh` | Linux/macOS | Companion to this skill |

Run the appropriate one after providing API keys.

## Common Issues

| Problem | Fix |
|---------|-----|
| MCP server fails to start | Check the API key is valid; ensure Node.js is installed and `npx` works |
| Plugin not found | Add to `opencode.json` `"plugin"` array or run `opencode plugin add <name>` |
| Skill not auto-loading | Verify the skill directory exists under skills/ and AGENTS.md has the auto-load rule |
| `npx` not found on Windows | Install Node.js from https://nodejs.org |
| Graphify not injecting | Check that `graphify-out/graph.json` exists in the project |
| JSON parse error | Make sure paths in JSON use forward slashes even on Windows |

## Verification

```bash
opencode ask "Check my OpenCode setup is complete"
```
