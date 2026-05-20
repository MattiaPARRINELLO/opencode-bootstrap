#Requires -Version 5.1
<#
.SYNOPSIS
    OpenCode Bootstrap Script for Windows
.DESCRIPTION
    Replicates a full OpenCode configuration: plugins, MCPs, skills, AGENTS.md.
    Run this in PowerShell after installing opencode and Node.js.
#>

$ErrorActionPreference = "Stop"

$ConfigRoot  = "$env:USERPROFILE\.config\opencode"
$LocalRoot   = "$env:USERPROFILE\.opencode"
$McpDir      = "$env:USERPROFILE\.config\mcp"

Write-Host "=== OpenCode Bootstrap (Windows) ===" -ForegroundColor Cyan
Write-Host ""

# --- Collect API keys ---
Write-Host "--- API Keys (press Enter to skip/disable an MCP) ---" -ForegroundColor Yellow
$githubToken     = Read-Host "GitHub Personal Access Token [optional]"
$gmailEmail      = Read-Host "Gmail email [optional]"
$gmailAppPass    = Read-Host -AsSecureString "Gmail App Password [optional]"; $gmailAppPassText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($gmailAppPass))
$magicApiKey     = Read-Host -AsSecureString "21st.dev Magic API Key [optional]"; $magicApiKeyText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($magicApiKey))
$quotaWorkspace  = Read-Host "OpenCode Quota Workspace ID [optional]"
Write-Host ""

# --- Create directories ---
@(
    "$ConfigRoot\skills",
    "$ConfigRoot\opencode-quota",
    "$LocalRoot\plugins",
    "$LocalRoot\skills",
    $McpDir
) | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

# Normalise home path for JSON (use forward slashes)
$homeJson = $env:USERPROFILE -replace '\\', '/'

# --- Build MCP config entries ---
$mcpEntries = @"
    "filesystem": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "$homeJson"]
    },
    "puppeteer": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "-y", "@modelcontextprotocol/server-puppeteer"]
    }
"@

if ($env:MEMORY_FILE_PATH) {
    $memPath = $env:MEMORY_FILE_PATH -replace '\\', '/'
    $mcpEntries += @",
    "memory": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "-y", "@modelcontextprotocol/server-memory"],
      "environment": {
        "MEMORY_FILE_PATH": "$memPath"
      }
    }
"@
}

if ($githubToken) {
    $mcpEntries += @",
    "github": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
      "environment": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "$githubToken"
      }
    }
"@
}

if ($gmailEmail -and $gmailAppPassText) {
    $mcpEntries += @",
    "gmail": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "-y", "gmail-mcp-imap"],
      "environment": {
        "GMAIL_EMAIL": "$gmailEmail",
        "GMAIL_APP_PASSWORD": "$gmailAppPassText"
      }
    }
"@
}

if ($magicApiKeyText) {
    $mcpEntries += @",
    "magic": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "-y", "@21st-dev/magic@latest"],
      "environment": {
        "API_KEY": "$magicApiKeyText"
      }
    }
"@
}

# --- Write main opencode.json ---
$mainConfig = @"
{
  "`$schema": "https://opencode.ai/config.json",
  "plugin": [
    "opencode-agent-skills",
    "background-agents",
    "btw-opencode",
    "@tarquinen/opencode-dcp@latest",
    "superpowers@git+https://github.com/obra/superpowers.git",
    "@slkiser/opencode-quota"
  ],
  "mcp": {
$mcpEntries
  }
}
"@

Set-Content -Path "$ConfigRoot\opencode.json" -Value $mainConfig -Encoding UTF8
Write-Host "[OK] Wrote $ConfigRoot\opencode.json" -ForegroundColor Green

# --- Write local opencode.json (graphify plugin) ---
$localConfig = @"
{
  "`$schema": "https://opencode.ai/config.json",
  "plugin": [
    ".opencode/plugins/graphify.js"
  ]
}
"@

Set-Content -Path "$LocalRoot\opencode.json" -Value $localConfig -Encoding UTF8
Write-Host "[OK] Wrote $LocalRoot\opencode.json" -ForegroundColor Green

# --- Write graphify plugin ---
$graphifyPlugin = @'
// graphify OpenCode plugin - Windows compatible
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
'@

Set-Content -Path "$LocalRoot\plugins\graphify.js" -Value $graphifyPlugin -Encoding UTF8
Write-Host "[OK] Wrote $LocalRoot\plugins\graphify.js" -ForegroundColor Green

# --- Write AGENTS.md (no pkexec on Windows) ---
$agentsMd = @"
# Global Rules

## Auto-loading des skills

Les skills suivants doivent être chargés AUTOMATIQUEMENT quand le contexte le nécessite,
sans attendre que l'utilisateur le demande :

### Toujours actif (meta-skill)
- `output-skill` — Empêche la troncature du code et les réponses incomplètes.

### Design / UI (chargement contextuel automatique)
- Créer ou modifier une interface → charge `impeccable` puis exécute /impeccable craft
- Design minimaliste/éditorial (Notion, Linear, documentation) → `minimalist-skill` + `impeccable`
- Design brutaliste/technique (terminal, blueprint, data-heavy) → `brutalist-skill` + `impeccable`
- Présentation/slides → `frontend-slides`
- Recherche design/inspiration → `ui-ux-pro-max`

### Testing / Browser
- Tester une page web ou automatiser le navigateur → `playwright-skill`

### Ne JAMAIS charger automatiquement
- Les skills supprimés n'existent plus. Ne pas tenter de les charger.
"@

Set-Content -Path "$ConfigRoot\AGENTS.MD" -Value $agentsMd -Encoding UTF8
Write-Host "[OK] Wrote $ConfigRoot\AGENTS.MD" -ForegroundColor Green

# --- Write DCP config ---
$dcpConfig = @'
{
  "$schema": "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json"
}
'@

Set-Content -Path "$ConfigRoot\dcp.jsonc" -Value $dcpConfig -Encoding UTF8
Write-Host "[OK] Wrote $ConfigRoot\dcp.jsonc" -ForegroundColor Green

# --- Write TUI config ---
$tuiConfig = @'
{
  "$schema": "https://opencode.ai/tui.json",
  "plugin": ["@slkiser/opencode-quota"]
}
'@

Set-Content -Path "$ConfigRoot\tui.json" -Value $tuiConfig -Encoding UTF8
Write-Host "[OK] Wrote $ConfigRoot\tui.json" -ForegroundColor Green

# --- Write quota config ---
if ($quotaWorkspace) {
    $quotaConfig = @"
{
  "workspace_id": "$quotaWorkspace"
}
"@
    Set-Content -Path "$ConfigRoot\opencode-quota\opencode-go.json" -Value $quotaConfig -Encoding UTF8
    Write-Host "[OK] Wrote quota config (auth cookie must be added manually)" -ForegroundColor Green
}

# --- Write package.json ---
$packageJson = @'
{
  "dependencies": {
    "@opencode-ai/plugin": "1.14.20",
    "unique-names-generator": "^4.7.1"
  }
}
'@

Set-Content -Path "$ConfigRoot\package.json" -Value $packageJson -Encoding UTF8
Write-Host "[OK] Wrote $ConfigRoot\package.json" -ForegroundColor Green

# --- Skill copy instructions ---
Write-Host ""
Write-Host "=== SKILL INSTALLATION ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Skills must be copied from your reference machine or cloned from source."
Write-Host "Expected directories:"
Write-Host "  $ConfigRoot\skills\  (8+ skills)"
Write-Host "  $LocalRoot\skills\   (taste-skill, impeccable, playwright)"
Write-Host ""
Write-Host "To copy from an existing installation:"
Write-Host "  Copy-Item -Recurse ""source\.config\opencode\skills\*"" ""$ConfigRoot\skills\"""
Write-Host ""

# --- npx package cache note ---
Write-Host "=== NOTE ===" -ForegroundColor Yellow
Write-Host "The first time opencode starts, npx will download all MCP packages."
Write-Host "This requires a working internet connection and may take a few minutes."
Write-Host ""

# --- Verification ---
Write-Host "=== DONE ===" -ForegroundColor Cyan
Write-Host "Run: opencode ask 'Check my OpenCode setup is complete'" -ForegroundColor Green
Write-Host ""
