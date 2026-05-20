#!/usr/bin/env bash
set -euo pipefail

# OpenCode Bootstrap Script
# Replicates a full OpenCode configuration: plugins, MCPs, skills, AGENTS.md

OPENCODE_CONFIG="${HOME}/.config/opencode"
OPENCODE_LOCAL="${HOME}/.opencode"
MCP_DIR="${HOME}/.config/mcp"

echo "=== OpenCode Bootstrap ==="
echo ""

# --- Collect API keys ---
echo "--- API Keys (press Enter to skip/disable an MCP) ---"
read -rp "GitHub Personal Access Token [optional]: " GITHUB_TOKEN
read -rp "Gmail email [optional]: " GMAIL_EMAIL
read -rsp "Gmail App Password [optional]: " GMAIL_APP_PASSWORD
echo ""
read -rsp "21st.dev Magic API Key [optional]: " MAGIC_API_KEY
echo ""
read -rp "OpenCode Quota Workspace ID [optional]: " QUOTA_WORKSPACE_ID
echo ""

# --- Create directories ---
mkdir -p "${OPENCODE_CONFIG}/skills"
mkdir -p "${OPENCODE_CONFIG}/opencode-quota"
mkdir -p "${OPENCODE_LOCAL}/plugins"
mkdir -p "${OPENCODE_LOCAL}/skills"
mkdir -p "${MCP_DIR}"

# --- Build MCP config (only enabled servers) ---
MCP_ENTRIES='    "filesystem": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "'"${HOME}"'"]
    },
    "puppeteer": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "-y", "@modelcontextprotocol/server-puppeteer"]
    }'

if [ -n "${MEMORY_FILE_PATH:-}" ]; then
  MCP_ENTRIES="${MCP_ENTRIES},
    \"memory\": {
      \"type\": \"local\",
      \"enabled\": true,
      \"command\": [\"npx\", \"-y\", \"@modelcontextprotocol/server-memory\"],
      \"environment\": {
        \"MEMORY_FILE_PATH\": \"${MEMORY_FILE_PATH}\"
      }
    }"
fi

if [ -n "$GITHUB_TOKEN" ]; then
  MCP_ENTRIES="${MCP_ENTRIES},
    \"github\": {
      \"type\": \"local\",
      \"enabled\": true,
      \"command\": [\"npx\", \"-y\", \"@modelcontextprotocol/server-github\"],
      \"environment\": {
        \"GITHUB_PERSONAL_ACCESS_TOKEN\": \"${GITHUB_TOKEN}\"
      }
    }"
fi

if [ -n "$GMAIL_EMAIL" ] && [ -n "$GMAIL_APP_PASSWORD" ]; then
  MCP_ENTRIES="${MCP_ENTRIES},
    \"gmail\": {
      \"type\": \"local\",
      \"enabled\": true,
      \"command\": [\"npx\", \"-y\", \"gmail-mcp-imap\"],
      \"environment\": {
        \"GMAIL_EMAIL\": \"${GMAIL_EMAIL}\",
        \"GMAIL_APP_PASSWORD\": \"${GMAIL_APP_PASSWORD}\"
      }
    }"
fi

if [ -n "$MAGIC_API_KEY" ]; then
  MCP_ENTRIES="${MCP_ENTRIES},
    \"magic\": {
      \"type\": \"local\",
      \"enabled\": true,
      \"command\": [\"npx\", \"-y\", \"@21st-dev/magic@latest\"],
      \"environment\": {
        \"API_KEY\": \"${MAGIC_API_KEY}\"
      }
    }"
fi

# --- Write main opencode.json ---
cat > "${OPENCODE_CONFIG}/opencode.json" << OCFGEOF
{
  "\$schema": "https://opencode.ai/config.json",
  "plugin": [
    "opencode-agent-skills",
    "background-agents",
    "btw-opencode",
    "@tarquinen/opencode-dcp@latest",
    "superpowers@git+https://github.com/obra/superpowers.git",
    "@slkiser/opencode-quota"
  ],
  "mcp": {
${MCP_ENTRIES}
  }
}
OCFGEOF

echo "[OK] Wrote ${OPENCODE_CONFIG}/opencode.json"

# --- Write local opencode.json (graphify plugin) ---
cat > "${OPENCODE_LOCAL}/opencode.json" << LOCFGEOF
{
  "\$schema": "https://opencode.ai/config.json",
  "plugin": [
    ".opencode/plugins/graphify.js"
  ]
}
LOCFGEOF

echo "[OK] Wrote ${OPENCODE_LOCAL}/opencode.json"

# --- Write graphify plugin ---
cat > "${OPENCODE_LOCAL}/plugins/graphify.js" << PLUGINEOF
// graphify OpenCode plugin
// Injects a knowledge graph reminder before bash tool calls when the graph exists.
import { existsSync } from "fs";
import { join } from "path";

export const GraphifyPlugin = async ({ directory }) => {
  let reminded = false;

  return {
    "tool.execute.before": async (input, output) => {
      if (reminded) return;
      if (!existsSync(join(directory, "graphify-out", "graph.json"))) return;

      if (input.tool === "bash") {
        output.args.command =
          'echo "[graphify] Knowledge graph available. Read graphify-out/GRAPH_REPORT.md for god nodes and architecture context before searching files." && ' +
          output.args.command;
        reminded = true;
      }
    },
  };
};
PLUGINEOF

echo "[OK] Wrote ${OPENCODE_LOCAL}/plugins/graphify.js"

# --- Write AGENTS.md ---
cat > "${OPENCODE_CONFIG}/AGENTS.MD" << AGENTSEOF
# Global Rules

## Commandes privilégiées
Toujours utiliser \`pkexec\` à la place de \`sudo\` pour toutes les commandes
nécessitant des privilèges élevés sur ce système Linux/Mac.

## Auto-loading des skills

Les skills suivants doivent être chargés AUTOMATIQUEMENT quand le contexte le nécessite,
sans attendre que l'utilisateur le demande :

### Toujours actif (meta-skill)
- \`output-skill\` — Empêche la troncature du code et les réponses incomplètes.

### Design / UI (chargement contextuel automatique)
- Créer ou modifier une interface → charge \`impeccable\` puis exécute /impeccable craft
- Design minimaliste/éditorial (Notion, Linear, documentation) → \`minimalist-skill\` + \`impeccable\`
- Design brutaliste/technique (terminal, blueprint, data-heavy) → \`brutalist-skill\` + \`impeccable\`
- Présentation/slides → \`frontend-slides\`
- Recherche design/inspiration → \`ui-ux-pro-max\`

### Testing / Browser
- Tester une page web ou automatiser le navigateur → \`playwright-skill\`

### Ne JAMAIS charger automatiquement
- Les skills supprimés n'existent plus. Ne pas tenter de les charger.
AGENTSEOF

echo "[OK] Wrote ${OPENCODE_CONFIG}/AGENTS.MD"

# --- Write DCP config ---
cat > "${OPENCODE_CONFIG}/dcp.jsonc" << DCPEOF
{
  "\$schema": "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json"
}
DCPEOF

echo "[OK] Wrote ${OPENCODE_CONFIG}/dcp.jsonc"

# --- Write TUI config ---
cat > "${OPENCODE_CONFIG}/tui.json" << TUIEOF
{
  "\$schema": "https://opencode.ai/tui.json",
  "plugin": ["@slkiser/opencode-quota"]
}
TUIEOF

echo "[OK] Wrote ${OPENCODE_CONFIG}/tui.json"

# --- Write quota config (if workspace ID provided) ---
if [ -n "$QUOTA_WORKSPACE_ID" ]; then
  cat > "${OPENCODE_CONFIG}/opencode-quota/opencode-go.json" << QUOTAEOF
{
  "workspace_id": "${QUOTA_WORKSPACE_ID}"
}
QUOTAEOF
  echo "[OK] Wrote quota config (auth cookie must be added manually)"
fi

# --- Write package.json for global config ---
cat > "${OPENCODE_CONFIG}/package.json" << PKGEOF
{
  "dependencies": {
    "@opencode-ai/plugin": "1.14.20",
    "unique-names-generator": "^4.7.1"
  }
}
PKGEOF

echo "[OK] Wrote ${OPENCODE_CONFIG}/package.json"

# --- Skill copy instructions ---
echo ""
echo "=== SKILL INSTALLATION ==="
echo ""
echo "Skills must be copied from your reference machine or cloned from source."
echo "Expected directories:"
echo "  ${OPENCODE_CONFIG}/skills/  (8+ skills)"
echo "  ${OPENCODE_LOCAL}/skills/   (taste-skill, impeccable, playwright)"
echo ""
echo "To copy from an existing installation:"
echo "  rsync -av user@old-machine:.config/opencode/skills/ ${OPENCODE_CONFIG}/skills/"
echo "  rsync -av user@old-machine:.opencode/skills/ ${OPENCODE_LOCAL}/skills/"
echo ""
echo "=== VERIFICATION ==="
echo ""
echo "Run: opencode ask 'Check my OpenCode setup is complete'"
echo ""
echo "=== DONE ==="
