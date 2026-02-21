# Claude Code Setup for Windows

A portable Claude Code configuration system -- 38 agents, 100+ skills, 8 deliberation modes, session persistence, lifecycle hooks, and a permissions system optimized for Windows native PowerShell development. Based on [Boris Cherney's workflow](https://www.linkedin.com/posts/boris-cherny-3a8b2513_im-boris-and-i-created-claude-code-lots-activity-7337184857029169152-WUZB/) (creator of Claude Code).

## Features

- **Multi-agent deliberation** -- `/council` and `/academy` assemble 3-7 specialized agents to deliberate on design decisions
- **38 agent personas** -- 21 Council + 17 Academy, each with distinct cognitive lens and skills
- **100+ structured skills** -- organized across 20 council departments + standalone packs
- **Windows notifications** -- toast notifications identifying which agent needs attention
- **5 parallel agents** -- using git worktrees with agent identification
- **Auto-formatting** hooks for multiple languages
- **Pre-approved permissions** -- 76 safe commands pre-allowed, 9 dangerous commands denied
- **Session persistence** -- `/handover` + auto-compaction hooks preserve context
- **Issue-driven execution** -- `/looper`, `/implement`, `/ralf` for GitHub workflow automation
- **Project scaffolding** -- Python, TypeScript, Terraform, MCP server templates
- **Workspace context** -- project-specific configs auto-load based on git remote

## Prerequisites

- Windows 10 or later
- PowerShell 5.1+ (ships with Windows 10/11)
- [Claude Code](https://claude.com/claude-code) CLI
- Git (for workspace auto-detection and worktrees)

> **Recommended upgrade:** PowerShell 7+ provides better performance and cross-platform support. Install with: `winget install Microsoft.PowerShell`

## Quick Start

```powershell
# Clone this repo
git clone https://github.com/dtsong/claude-code-windows-setup.git
cd claude-code-windows-setup

# Allow script execution (one-time)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Safe default: install skills only
.\Install.ps1

# Adopt more of the setup
.\Install.ps1 -Preset core        # + commands + agents
.\Install.ps1 -Preset full        # + scripts + hooks + workspaces + templates

# Opt-in to config files
.\Install.ps1 -WithSettings       # Link settings.json (hooks + permissions)
.\Install.ps1 -WithHooksJson      # Link hooks.json (PreCompact hook only)
```

The installer links selected content into `~\.claude\` using symlinks when possible, falling back to file copies otherwise.

> **Note on symlinks:** Windows requires Developer Mode enabled or elevated privileges to create symlinks. If symlinks are unavailable, the installer automatically falls back to copying files. Everything works the same either way.

**No additional dependencies required!** Notifications use built-in Windows APIs.

Useful commands:

```powershell
.\Install.ps1 -ListSkills                    # See available skill packs
.\Install.ps1 -Skills git-status,workflow     # Install specific skills
.\Install.ps1 -DryRun                        # Preview without changes
.\Install.ps1 -Uninstall                     # Clean removal
```

## What You Get

### Multi-Agent Deliberation

`/council` and `/academy` assemble 3-7 specialized agents from a roster of 16 to deliberate on design decisions. These agents explore your codebase independently, write position statements, challenge each other's recommendations, and converge on a unified design document with explicit trade-off resolution.

Eight modes control depth and involvement:

| Mode | Flag | What It Does |
|------|------|--------------|
| **Brainstorm** | `--brainstorm` | 30-second gut check from Architect, Advocate, Skeptic |
| **Quick** | `--quick` | Fast sketch -- skip interview, 1 deliberation round |
| **Standard** | *(default)* | Full workflow -- interview, 3 rounds, design doc + PRD |
| **Deep** | `--deep` | Standard + mandatory deep audit pass |
| **Auto** | `--auto` | Hands-off -- no approval touchpoints |
| **Guided** | `--guided` | Tight control -- user approval at every phase |
| **Meeting** | `--meet` | Discussion only -- no action plan produced |
| **Audit** | `--audit` | Direct codebase audit against best practices |

`/brainstorm "idea"` is a shortcut for `--brainstorm` mode.

### The 20 Agents

Each agent brings a distinct cognitive lens. Sessions use 3-7 agents selected for relevance.

| Agent | Lens Color | Focus Area |
|-------|-----------|------------|
| Architect | Blue | System design, data models, APIs, integration patterns |
| Advocate | Green | User experience, product thinking, accessibility |
| Skeptic | Red | Risk assessment, security, devil's advocate |
| Craftsman | Purple | Testing strategy, DX, code quality, patterns |
| Scout | Cyan | Research, precedent, external knowledge |
| Strategist | Gold | Business value, scope, MVP, prioritization |
| Operator | Orange | DevOps, deployment, infrastructure, monitoring |
| Chronicler | Ivory | Documentation, knowledge architecture, onboarding |
| Guardian | Silver | Compliance, governance, privacy |
| Tuner | Amber | Performance, scalability, optimization |
| Alchemist | Indigo | Data engineering, data science, ML workflows |
| Pathfinder | Coral | Mobile, cross-platform, native apps |
| Artisan | Rose | Visual design, design systems, motion |
| Herald | Bronze | Growth, monetization, onboarding, retention |
| Sentinel | Titanium | IoT, embedded, edge, device protocols |
| Oracle | Violet | AI/LLM integration, RAG, prompt engineering |
| Cipher | Obsidian | Cryptographic engineering, protocol security, post-quantum |
| Forge | Graphite | Microarchitecture, silicon design, RTL security |
| Prover | Pearl | Formal methods, mathematical verification, invariants |
| Warden | Slate | OS kernel security, process isolation, HW/SW boundary |

The **Steward** (Platinum) serves as the conductor persona -- always active, never spawned as a separate agent.

The **Academy** theme mirrors the full roster with Fire Emblem class names (Sage, Troubadour, Thief, etc.), house tensions, support conversations, and class promotion mechanics.

### Issue-Driven Execution

| Command | What It Does |
|---------|-------------|
| `/looper` | Implement GitHub issues into PRs with dependency ordering, quality gate retry loops, and checkpoint/resume |
| `/implement` | Implement one or more GitHub issues and create PRs |
| `/ralf` | Autonomous execution loop with PRD-based planning |
| `/roadmap-executor` | Full workflow from roadmap document to GitHub issues to PRs |
| `/create-issues` | Generate GitHub issues from a roadmap document |

### Project Scaffolding

| Command | Stack |
|---------|-------|
| `/new-python` | uv, ruff, FastAPI, pytest, pre-commit |
| `/new-typescript` | pnpm, Next.js 14+, Vitest, Prettier, shadcn/ui |
| `/new-terraform` | tflint, tfsec, terraform-docs, native test framework |
| `/new-mcp-server` | TypeScript MCP SDK, Zod, pnpm, Vitest |

### Session Persistence

`/handover` saves session knowledge -- decisions, pitfalls, and next steps -- as a markdown document that the next session picks up automatically. A `PreCompact` hook auto-generates handovers before context window compaction so you never lose session state.

### Workspace Context

Workspaces are project-specific context configs that auto-load based on git remote name. Drop a config in `workspaces\<repo-name>\` and it's injected into every session working in that repo -- infrastructure maps, team conventions, deployment notes.

### Windows-Specific Features

#### Agent Identification

When running multiple agents, notifications identify which agent needs attention:

```
Claude Code [Frontend]    <-- Custom name via CLAUDE_AGENT_NAME env var
Claude Code [agent-1]     <-- Git branch name (best for worktrees)
Claude Code [Agent 3]     <-- Extracted from directory name
Claude Code [my-project]  <-- Project directory name fallback
```

#### Running 5 Parallel Agents

```powershell
cd your-project
~\.claude\scripts\Create-Worktrees.ps1 -Count 5

# Creates:
# ..\your-project-agent-1\
# ..\your-project-agent-2\
# ..\your-project-agent-3\
# ..\your-project-agent-4\
# ..\your-project-agent-5\
```

Open 5 terminal tabs (Windows Terminal recommended) and run `claude` in each worktree.

#### Setting Custom Agent Names

For multiple Claude sessions in the same project (without worktrees):

```powershell
# Terminal 1
$env:CLAUDE_AGENT_NAME = "Frontend"
claude

# Terminal 2
$env:CLAUDE_AGENT_NAME = "Backend"
claude
```

### Permissions

Pre-approved safe commands reduce permission prompts without using `--dangerously-skip-permissions`:

- **76 allowed patterns**: package managers, git, file utilities, build tools, formatters, test runners
- **9 deny patterns**: destructive commands (`rm -rf /`, `sudo rm`, `mkfs`, etc.)

### Hooks

| Event | Script | What Happens |
|-------|--------|-------------|
| `Notification` | `notify.ps1` | Desktop notification when Claude needs input |
| `Stop` | `stop.ps1` | Notification when Claude completes |
| `PostToolUse` | `format.ps1` | Auto-format after Write/Edit (Prettier, Black, gofmt, etc.) |
| `PostToolUse` | `acceptance-gate.ps1` | Quality gate on task completion |
| `PreCompact` | `pre-compact-handover.ps1` | Auto-save session context before compaction |

## Command Reference

### Deliberation

| Command | Description |
|---------|-------------|
| `/council [--mode] "idea"` | Multi-agent deliberation (Council theme) |
| `/academy [--mode] "idea"` | Multi-agent deliberation (Academy theme) |
| `/brainstorm "idea"` | Quick 3-agent gut check |

### Project Setup

| Command | Description |
|---------|-------------|
| `/new-python` | Python + FastAPI project |
| `/new-typescript` | TypeScript + Next.js project |
| `/new-terraform` | Terraform module |
| `/new-mcp-server` | MCP server (TypeScript) |

### Workflow

| Command | Description |
|---------|-------------|
| `/looper` | Issue-to-PR with retry loops |
| `/implement` | Implement GitHub issues |
| `/ralf` | Autonomous PRD executor |
| `/roadmap-executor` | Roadmap to issues to PRs |
| `/create-issues` | Generate issues from roadmap |

### Session Management

| Command | Description |
|---------|-------------|
| `/handover` | Save session context for next session |
| `/ops` | Operations control center |
| `/g` | Git porcelain |

### Git Workflows

| Command | Description |
|---------|-------------|
| `/commit-push-pr` | Stage, commit, push, and create a PR |
| `/commit` | Quick local commit |
| `/test` | Auto-detect and run project tests |
| `/lint` | Run linter with auto-fix |
| `/review` | Review current git changes |
| `/simplify` | Refactor and simplify recent changes |
| `/diagnose` | Diagnose UI/CSS bugs against component map |
| `/fix` | Apply and verify a fix from a diagnosis |
| `/map` | Map a route's component tree |
| `/qa` | Full frontend QA pipeline |

## Directory Layout

```
claude-code-windows-setup/
├── Install.ps1             # PowerShell installer with presets and symlink detection
├── settings.json           # Merged settings (env + hooks + permissions)
├── hooks.json              # Standalone PreCompact hook
├── agents/                 # 38 agent persona files (21 council + 17 academy)
├── commands/               # 26 slash commands + shared engine
│   ├── _council-engine.md  # Shared deliberation engine (~1200 lines)
│   ├── council.md          # Council theme layer
│   ├── academy.md          # Academy theme layer
│   └── *.md                # Individual commands
├── skills/                 # 100+ structured skill templates
│   ├── council/            # 20 departments x 2-3 skills each
│   ├── academy/            # Academy theme skills
│   └── */                  # 15 standalone skill packs
├── hooks/                  # Lifecycle hook scripts (.ps1)
│   ├── _helpers.ps1        # Shared helper functions
│   ├── notify.ps1          # Notification hook
│   ├── stop.ps1            # Completion notification hook
│   ├── format.ps1          # Auto-format hook
│   ├── acceptance-gate.ps1 # Quality gate hook
│   └── pre-compact-handover.ps1  # Auto-save before compaction
├── scripts/                # Utility scripts (Verb-Noun.ps1 naming)
│   ├── Create-Worktrees.ps1
│   ├── Init-Project.ps1
│   ├── Launch-Agent.ps1
│   ├── Run-Agent.ps1
│   ├── Send-AgentBroadcast.ps1
│   ├── Get-AgentStatus.ps1
│   ├── Find-Workspaces.ps1
│   ├── Start-Workspace.ps1
│   ├── Send-Completion.ps1
│   └── Show-TaskBoard.ps1
├── workspaces/             # Project-specific context configs
├── templates/              # Project initialization templates
├── ARCHITECTURE.md         # Technical reference
├── CONTRIBUTING.md         # Contributor guide
├── CHANGELOG.md            # Version history
└── LICENSE
```

## Customization

### Level 1: Use As-Is

Just run `.\Install.ps1 -Preset full`. You get everything.

### Level 2: Selective Install

```powershell
.\Install.ps1 -Skills git-status,github-workflow,workflow   # Specific skills
.\Install.ps1 -Preset core                                   # Commands + agents, no scripts
```

### Level 3: Personalize

- Add workspace configs in `workspaces\<your-repo-name>\` for project-specific context
- Edit `settings.json` to change env vars or hook timeouts
- Create project-specific `CLAUDE.md` files using `templates\CLAUDE.md` as a starting point

### Level 4: Extend the System

See [ARCHITECTURE.md](ARCHITECTURE.md) for details on:
- Adding new agents (persona file + department + skills + roster entry)
- Creating commands (markdown prompt templates with frontmatter)
- Building skills (structured templates with process steps and quality checks)
- Adding themes (supply 14 extension points to the shared engine)

## Windows Terminal Setup

For the best multi-agent experience, configure Windows Terminal to open 5 PowerShell tabs on startup:

```json
{
  "startupActions": "new-tab -p \"PowerShell\" ; new-tab -p \"PowerShell\" ; new-tab -p \"PowerShell\" ; new-tab -p \"PowerShell\" ; new-tab -p \"PowerShell\""
}
```

## Troubleshooting

### Execution Policy Error

If you see "running scripts is disabled on this system", run:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

This only needs to be done once per user account.

### Symlinks Not Working

Windows requires one of the following for symlink creation:
1. **Developer Mode** enabled (Settings > Privacy & Security > For Developers)
2. **Run as Administrator**

If neither is available, the installer automatically falls back to copying files. No functionality is lost.

### Notifications Not Working

The hooks use Windows Toast Notifications (built-in on Windows 10+). Test manually:

```powershell
pwsh -NoProfile -File ~\.claude\hooks\notify.ps1
```

### Hooks Not Running

1. Verify hook files exist: `Get-ChildItem ~\.claude\hooks\`
2. Check JSON syntax: `Get-Content ~\.claude\settings.json | ConvertFrom-Json`
3. Restart Claude Code after changing settings

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Start with onboarding feedback if you're a first-time user.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Boris Cherney](https://www.linkedin.com/in/boris-cherny-3a8b2513/) for sharing his Claude Code workflow
- The [Claude Code team](https://github.com/anthropics/claude-code) at Anthropic
- [claude-code-wsl-setup](https://github.com/dtsong/claude-code-wsl-setup) -- the WSL/Linux original this port is based on
