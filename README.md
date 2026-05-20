# OpenCode Bootstrap

Replication complète d'une configuration OpenCode : plugins, MCPs, skills et règles AGENTS.md en moins de 5 minutes.

## Utilisation

```powershell
# 1. Cloner
git clone https://github.com/MattiaPARRINELLO/opencode-bootstrap.git

# 2. Lancer le script selon ton OS
cd opencode-bootstrap

# Windows :
.\bootstrap.ps1

# Linux / macOS :
chmod +x bootstrap.sh && ./bootstrap.sh

# 3. Copier les skills depuis la machine source (optionnel)
# Voir les instructions affichées par le script
```

## Contenu

| Fichier | Description |
|---------|-------------|
| `bootstrap.ps1` | Script PowerShell pour Windows |
| `bootstrap.sh` | Script Bash pour Linux / macOS |
| `SKILL.md` | Skill OpenCode pour guider l'agent automatiquement |

## Ce qui est installé

- **6 plugins** : opencode-agent-skills, background-agents, btw-opencode, DCP, superpowers, quota
- **6 MCP servers** : filesystem, puppeteer, memory, github (token), gmail (app password), magic (21st.dev)
- **8+ skills** : output-skill, impeccable, minimalist, brutalist, frontend-slides, playwright, ui-ux-pro-max, graphify
- **AGENTS.md** : règles d'auto-loading des skills

Les API keys sont demandées interactivement. Si une clé n'est pas fournie, le MCP correspondant est ignoré.
