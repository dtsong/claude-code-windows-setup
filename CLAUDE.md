# Claude Code Setup - Project Guide

This repository contains a portable Claude Code configuration system -- 38 agent personas, 100+ structured skills, multi-agent deliberation, session persistence, lifecycle hooks, and a permissions system optimized for Windows native PowerShell development.

## Quick Install (For New Users)

If the user wants to install this setup, run:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\Install.ps1 -Preset full -WithSettings -WithHooksJson
```

For a minimal install (skills only):

```powershell
.\Install.ps1
```

## What This Project Does

This setup enables:
- **38 agent personas** (21 Council + 17 Academy) for multi-agent deliberation
- **100+ structured skills** across 20 council departments + standalone packs
- **8 deliberation modes** from quick brainstorm to deep audit
- **Windows toast notifications** identifying which agent needs attention
- **Auto-formatting hooks** for code changes
- **Pre-approved permissions** for 76 common safe commands
- **Session persistence** via `/handover` and auto-compaction hooks
- **Issue-driven execution** via `/looper`, `/implement`, `/ralf`
- **Project scaffolding** via `/new-python`, `/new-typescript`, `/new-terraform`, `/new-mcp-server`
- **Workspace context** auto-loading based on git remote
- **Git worktree helpers** for parallel development

## Project Structure

```
claude-code-windows-setup/
├── Install.ps1             # PowerShell installer (presets: skills/core/full)
├── settings.json           # Merged settings: env + hooks + permissions
├── hooks.json              # Standalone PreCompact hook config
├── agents/                 # 38 agent personas (21 council + 17 academy)
│   ├── council-architect.md
│   ├── council-advocate.md
│   ├── ...                 # 19 more council agents
│   ├── academy-sage.md
│   └── ...                 # 16 more academy agents
├── commands/               # 26 slash commands + shared engine
│   ├── _council-engine.md  # Shared deliberation engine (~1200 lines)
│   ├── council.md          # Council theme layer
│   ├── academy.md          # Academy theme layer
│   ├── brainstorm.md       # Quick 3-agent gut check
│   ├── looper.md           # Issue-to-PR with retry loops
│   ├── implement.md        # Implement GitHub issues
│   ├── ralf.md             # Autonomous PRD executor
│   ├── handover.md         # Session knowledge transfer
│   ├── g.md                # Git porcelain
│   ├── ops.md              # Operations center
│   ├── new-python.md       # Python project scaffolding
│   ├── new-typescript.md   # TypeScript project scaffolding
│   ├── new-terraform.md    # Terraform module scaffolding
│   ├── new-mcp-server.md   # MCP server scaffolding
│   ├── commit-push-pr.md   # Git commit -> push -> PR workflow
│   ├── commit.md           # Quick commit
│   ├── test.md             # Run project tests
│   ├── lint.md             # Run linter
│   ├── review.md           # Review changes
│   ├── simplify.md         # Refactor/simplify code
│   ├── diagnose.md         # Diagnose UI/CSS bugs
│   ├── fix.md              # Apply and verify fixes
│   ├── map.md              # Map route component trees
│   └── qa.md               # Full frontend QA pipeline
├── skills/                 # 100+ structured skill templates
│   ├── council/            # 20 departments x 2-3 skills each
│   ├── academy/            # Academy theme skills
│   ├── git-workflows/      # Git operations
│   ├── github-workflow/    # GitHub interactions
│   ├── language-conventions/ # Python, TypeScript, Terraform refs
│   ├── terraform-skill/    # Terraform best practices
│   ├── dbt-skill/          # dbt data engineering
│   ├── tdd/                # Test-driven development
│   ├── frontend-qa/        # Frontend QA pipeline (4 sub-skills)
│   └── ...                 # 7 more standalone skill packs
├── hooks/                  # Lifecycle hook scripts (.ps1)
│   ├── _helpers.ps1        # Shared helper functions
│   ├── notify.ps1          # Notification when Claude needs input
│   ├── stop.ps1            # Notification when Claude completes
│   ├── format.ps1          # Auto-format code after edits
│   ├── acceptance-gate.ps1 # Quality gate for task completion
│   └── pre-compact-handover.ps1  # Auto-save before compaction
├── scripts/                # Utility scripts (Verb-Noun.ps1 naming)
│   ├── Create-Worktrees.ps1
│   ├── Init-Project.ps1
│   ├── Launch-Agent.ps1
│   ├── Run-Agent.ps1
│   ├── Agent-Broadcast.ps1
│   ├── Agent-Status.ps1
│   ├── Find-Workspaces.ps1
│   ├── Launch-Workspace.ps1
│   ├── Notify-Complete.ps1
│   └── Task-Board.ps1
├── workspaces/             # Project-specific context templates
│   ├── FORMAT.md
│   ├── _example/
│   └── _full-stack/
├── templates/              # Project initialization templates
│   ├── CLAUDE.md
│   └── project-settings.json
├── ARCHITECTURE.md         # Technical reference
├── CONTRIBUTING.md         # Contributor guide
├── CHANGELOG.md
├── README.md
└── LICENSE
```

## Key Commands

```powershell
# Install (symlink-based, incremental)
.\Install.ps1                           # Skills only (safe default)
.\Install.ps1 -Preset core             # + commands + agents
.\Install.ps1 -Preset full             # + scripts + hooks + workspaces + templates
.\Install.ps1 -WithSettings            # Also link settings.json
.\Install.ps1 -WithHooksJson           # Also link hooks.json
.\Install.ps1 -DryRun                  # Preview what would be installed
.\Install.ps1 -Uninstall               # Remove all managed symlinks/copies

# After installation:
~\.claude\scripts\Init-Project.ps1 -Path C:\path\to\project
~\.claude\scripts\Create-Worktrees.ps1 -Count 5
```

## Node.js on Windows

This project does not require Node.js, but Claude Code itself does. Recommended approaches:

1. **Direct install:** Download from https://nodejs.org (simplest)
2. **nvm-windows:** Install [nvm-windows](https://github.com/coreybutler/nvm-windows) for version management
3. **winget:** `winget install OpenJS.NodeJS.LTS`

## Development Guidelines

### When modifying hooks (`hooks\*.ps1`):
- Keep them fast (under 10 seconds)
- Always exit with code 0 for success
- Use the shared `_helpers.ps1` for common functions like agent identification
- Hooks are invoked via `pwsh -NoProfile -File <script>`

### When modifying the installer:
- The installer must be idempotent (safe to run multiple times)
- Symlink capability is detected via test creation (not WSL detection)
- Test with `$env:CLAUDE_DIR = "$env:TEMP\test-claude"; .\Install.ps1 -Preset full`
- Verify uninstall: `.\Install.ps1 -Uninstall`

### When adding new slash commands:
- Place in `commands\` directory with `.md` extension
- Include YAML frontmatter with `description` and optional `argument-hint`
- Keep commands focused on a single workflow

### When modifying agents or skills:
- Agent files require YAML frontmatter (`name`, `description`, `model`)
- Skill files follow: Purpose, Inputs, Process, Output Format, Quality Checks
- See [ARCHITECTURE.md](ARCHITECTURE.md) for full schema

### When modifying the deliberation engine:
- All workflow logic lives in `commands\_council-engine.md`
- Theme files (`council.md`, `academy.md`) supply 14 configuration variables
- Do not duplicate engine logic in theme files

## Testing Changes

```powershell
# PowerShell syntax check
Get-ChildItem *.ps1, hooks\*.ps1, scripts\*.ps1 | ForEach-Object {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errors)
    if ($errors) { Write-Error "$($_.Name): $errors" }
}

# JSON validation
Get-Content settings.json | ConvertFrom-Json
Get-Content hooks.json | ConvertFrom-Json

# Installer smoke test (isolated)
$env:CLAUDE_DIR = "$env:TEMP\claude-test"
.\Install.ps1 -Preset skills -ConflictPolicy fail
.\Install.ps1 -Uninstall
```

## No External Dependencies

This project uses only built-in Windows APIs for notifications:
- Windows 10+: `Windows.UI.Notifications` (built-in)

Do NOT add dependencies on external PowerShell modules like BurntToast.

## Skill Governance Directive

All skills in this repository must comply with the Skill Governance Specification.

### Token Budgets (Hard Limits)

- Coordinator SKILL.md: <=800 tokens (~600 words)
- Specialist / Standalone SKILL.md: <=2,000 tokens (~1,500 words)
- Reference files: <=1,500 tokens (~1,100 words)
- Maximum simultaneous context load: <=5,000 tokens

### Architecture Rules

- Coordinators contain ONLY: classification logic, skill registry, load directive, handoff protocol
- Load one specialist at a time -- never pre-load multiple specialists
- Checklists >10 items go in reference files, loaded conditionally
- Eval cases and templates live outside skill directories
- No cross-references between specialist skills -- use handoff protocol

### Writing Rules

- Procedure steps use imperative sentences -- no explanatory prose
- Decision points as inline conditionals -- no nested sub-sections
- One compact output example per skill -- no redundant schema descriptions
- Reference files are pure content -- no preamble or meta-instructions

### Enforcement

Pre-commit hooks validate: token budgets, frontmatter, reference integrity,
cross-skill isolation, and suite context load ceiling.

Full spec: see Skill Governance sections in `CLAUDE.md`

## Reference

Based on Boris Cherney's workflow: https://www.linkedin.com/posts/boris-cherny-3a8b2513_im-boris-and-i-created-claude-code-lots-activity-7337184857029169152-WUZB/
