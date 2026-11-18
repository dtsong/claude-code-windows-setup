---
name: freeze
description: "Freeze files matching a pattern — blocks Edit/Write/MultiEdit to matched files via an opt-in PreToolUse hook. Use when files should not be modified (e.g., during review, or to protect config files). Invoke /freeze '*.config.js' to enable, /freeze off to disable."
---

# /freeze — File Modification Guard

Blocks Edit, Write and MultiEdit tool calls to files matching a user-specified pattern.

## Activation

When invoked with a pattern (e.g., `/freeze '*.config.js'`):
1. Run: `pwsh -NoProfile -File "$HOME/.claude/hooks/freeze-mode.ps1" enable "<pattern>"`
2. Check that `~/.claude/settings.json` registers `freeze-mode.ps1 check` under `PreToolUse`. If it does not, tell the user: "Freeze is recorded but NOT enforced: the opt-in hook is not registered. See the README section 'Opt-in safety hooks'."
3. Otherwise confirm: "Freeze mode ON — files matching `<pattern>` are protected."

When invoked with `status`: run `pwsh -NoProfile -File "$HOME/.claude/hooks/freeze-mode.ps1" status` and show the frozen patterns.

## Deactivation

When invoked with `off`:
1. Run: `pwsh -NoProfile -File "$HOME/.claude/hooks/freeze-mode.ps1" disable`
2. Confirm: "Freeze mode OFF — all files are writable."

## Examples

- `/freeze '*.lock'` — protect lockfiles
- `/freeze 'src/core/**'` — protect core module
- `/freeze '.env*'` — protect environment files
- `/freeze off` — remove all freezes

## Behavior

- Patterns are PowerShell wildcards, case-insensitive, matched against the file name and the path relative to the project root
- Frozen files return an error: "BLOCKED by /freeze … Run /freeze off to unfreeze."
- Multiple `/freeze` calls are additive (patterns stack)
- Does not block Read operations — only Edit, Write and MultiEdit
- State persists across sessions until `/freeze off`
