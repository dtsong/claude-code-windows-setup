---
name: careful
description: "Activate safety mode — blocks destructive commands (rm -rf, DROP TABLE, git push --force, kubectl delete, Remove-Item -Recurse -Force) via an opt-in PreToolUse hook. Use when working in production environments or sensitive codebases. Invoke /careful to enable, /careful off to disable."
---

# /careful — Destructive Command Guard

Turns on a PreToolUse hook that blocks dangerous Bash and PowerShell commands before execution.

## Activation

When invoked without arguments:
1. Run: `pwsh -NoProfile -File "$HOME/.claude/hooks/careful-mode.ps1" enable`
2. Check that `~/.claude/settings.json` registers `careful-mode.ps1 check` under `PreToolUse`. If it does not, tell the user: "Careful mode is recorded but NOT enforced: the opt-in hook is not registered. See the README section 'Opt-in safety hooks'."
3. Otherwise confirm: "Careful mode ON — destructive commands will be blocked."

## Deactivation

When invoked with `off`:
1. Run: `pwsh -NoProfile -File "$HOME/.claude/hooks/careful-mode.ps1" disable`
2. Confirm: "Careful mode OFF."

## What Gets Blocked

The hook intercepts Bash and PowerShell tool calls and blocks commands matching:
- `rm -rf`, `rm -r /` — recursive deletion
- `DROP TABLE`, `DROP DATABASE`, `TRUNCATE TABLE` — database destruction
- `git push --force`, `git push -f` — force push
- `git reset --hard` — hard reset
- `kubectl delete` — Kubernetes resource deletion
- `terraform destroy` — infrastructure destruction
- `docker system prune -a` — full Docker cleanup
- `Remove-Item … -Recurse … -Force`, `rd /s`, `rmdir /s`, `Format-Volume`, `Clear-Disk` — Windows equivalents

## Behavior

- Blocked commands return an error message explaining why
- The user is prompted to confirm or use a safer alternative
- Does not block `--dry-run` variants of dangerous commands
- State persists across sessions until `/careful off`
