#Requires -Version 5.1
<#
.SYNOPSIS
    OpenCode Bootstrap Script for Windows
.DESCRIPTION
    Replicates a full OpenCode configuration: plugins, MCPs, skills, AGENTS.md.
    Run this in PowerShell after installing opencode and Node.js.
#>

$ErrorActionPreference = "Stop"

$ConfigRoot = "$env:USERPROFILE\.config\opencode"
$LocalRoot  = "$env:USERPROFILE\.opencode"

Write-Host "=== OpenCode Bootstrap (Windows) ===" -ForegroundColor Cyan
Write-Host ""

# --- Collect API keys (blank = skip that MCP) ---
Write-Host "--- API Keys (press Enter to skip/disable an MCP) ---" -ForegroundColor Yellow
$githubToken    = Read-Host "GitHub Personal Access Token [optional]"
$gmailEmail     = Read-Host "Gmail email [optional]"
$gmailAppPass   = Read-Host "Gmail App Password [optional]"
$magicApiKey    = Read-Host "21st.dev Magic API Key [optional]"
$quotaWsId      = Read-Host "OpenCode Quota Workspace ID [optional]"
Write-Host ""

# --- Create directories ---
foreach ($dir in @(
    "$ConfigRoot\skills",
    "$ConfigRoot\opencode-quota",
    "$LocalRoot\plugins",
    "$LocalRoot\skills"
)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# --- Build MCP config as a hashtable ---
$mcp = @{}

$mcp["filesystem"] = @{
    type    = "local"
    enabled = $true
    command = @("npx", "-y", "@modelcontextprotocol/server-filesystem", $env:USERPROFILE -replace '\\', '/')
}

$mcp["puppeteer"] = @{
    type    = "local"
    enabled = $true
    command = @("npx", "-y", "@modelcontextprotocol/server-puppeteer")
}

if ($env:MEMORY_FILE_PATH) {
    $mcp["memory"] = @{
        type    = "local"
        enabled = $true
        command = @("npx", "-y", "@modelcontextprotocol/server-memory")
        environment = @{
            MEMORY_FILE_PATH = $env:MEMORY_FILE_PATH -replace '\\', '/'
        }
    }
}

if ($githubToken) {
    $mcp["github"] = @{
        type    = "local"
        enabled = $true
        command = @("npx", "-y", "@modelcontextprotocol/server-github")
        environment = @{
            GITHUB_PERSONAL_ACCESS_TOKEN = $githubToken
        }
    }
}

if ($gmailEmail -and $gmailAppPass) {
    $mcp["gmail"] = @{
        type    = "local"
        enabled = $true
        command = @("npx", "-y", "gmail-mcp-imap")
        environment = @{
            GMAIL_EMAIL         = $gmailEmail
            GMAIL_APP_PASSWORD  = $gmailAppPass
        }
    }
}

if ($magicApiKey) {
    $mcp["magic"] = @{
        type    = "local"
        enabled = $true
        command = @("npx", "-y", "@21st-dev/magic@latest")
        environment = @{
            API_KEY = $magicApiKey
        }
    }
}

# --- Write main opencode.json ---
$config = @{
    '$schema' = "https://opencode.ai/config.json"
    plugin = @(
        "opencode-agent-skills",
        "background-agents",
        "btw-opencode",
        "@tarquinen/opencode-dcp@latest",
        "superpowers@git+https://github.com/obra/superpowers.git",
        "@slkiser/opencode-quota"
    )
    mcp = $mcp
}

$configJson = $config | ConvertTo-Json -Depth 5
Set-Content -Path "$ConfigRoot\opencode.json" -Value $configJson -Encoding UTF8
Write-Host "[OK] $ConfigRoot\opencode.json" -ForegroundColor Green

# --- Write local opencode.json (graphify plugin) ---
$localConfig = @{
    '$schema' = "https://opencode.ai/config.json"
    plugin = @(".opencode/plugins/graphify.js")
}

$localConfig | ConvertTo-Json -Depth 3 | Set-Content -Path "$LocalRoot\opencode.json" -Encoding UTF8
Write-Host "[OK] $LocalRoot\opencode.json" -ForegroundColor Green

# --- Write graphify plugin ---
@'
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
'@ | Set-Content -Path "$LocalRoot\plugins\graphify.js" -Encoding UTF8

Write-Host "[OK] $LocalRoot\plugins\graphify.js" -ForegroundColor Green

# --- Write AGENTS.md ---
@"
# Global Rules

## Auto-loading des skills

Les skills suivants doivent être chargés automatiquement :

### Toujours actif
- \`output-skill\` — Empêche la troncature du code.

### Design / UI
- Créer ou modifier une interface → \`impeccable\`
- Design minimaliste/éditorial → \`minimalist-skill\` + \`impeccable\`
- Design brutaliste/technique → \`brutalist-skill\` + \`impeccable\`
- Présentation/slides → \`frontend-slides\`
- Recherche design → \`ui-ux-pro-max\`

### Testing / Browser
- Tester une page web → \`playwright-skill\`

### Ne JAMAIS charger
- Les skills supprimés.
"@ | Set-Content -Path "$ConfigRoot\AGENTS.MD" -Encoding UTF8

Write-Host "[OK] $ConfigRoot\AGENTS.MD" -ForegroundColor Green

# --- Write DCP config ---
@'
{
  "$schema": "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json"
}
'@ | Set-Content -Path "$ConfigRoot\dcp.jsonc" -Encoding UTF8

Write-Host "[OK] $ConfigRoot\dcp.jsonc" -ForegroundColor Green

# --- Write TUI config ---
@'
{
  "$schema": "https://opencode.ai/tui.json",
  "plugin": ["@slkiser/opencode-quota"]
}
'@ | Set-Content -Path "$ConfigRoot\tui.json" -Encoding UTF8

Write-Host "[OK] $ConfigRoot\tui.json" -ForegroundColor Green

# --- Write quota config ---
if ($quotaWsId) {
    @{
        workspace_id = $quotaWsId
    } | ConvertTo-Json | Set-Content -Path "$ConfigRoot\opencode-quota\opencode-go.json" -Encoding UTF8
    Write-Host "[OK] Quota config (auth cookie to add manually)" -ForegroundColor Green
}

# --- Write package.json ---
@'
{
  "dependencies": {
    "@opencode-ai/plugin": "1.14.20",
    "unique-names-generator": "^4.7.1"
  }
}
'@ | Set-Content -Path "$ConfigRoot\package.json" -Encoding UTF8

Write-Host "[OK] $ConfigRoot\package.json" -ForegroundColor Green

# --- Instructions ---
Write-Host ""
Write-Host "=== SKILL INSTALLATION ===" -ForegroundColor Cyan
Write-Host "Copy skills from your reference machine:"
Write-Host "  Copy-Item -Recurse ""source\.config\opencode\skills\*"" ""$ConfigRoot\skills\"""
Write-Host "  Copy-Item -Recurse ""source\.opencode\skills\*"" ""$LocalRoot\skills\"""
Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Cyan
Write-Host "Run: opencode ask 'Check my OpenCode setup is complete'" -ForegroundColor Green
