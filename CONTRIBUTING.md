# Contributing

Thanks for contributing.

## Principles

- Keep changes practical and composable.
- Prefer small, reviewable pull requests.
- Preserve compatibility with Claude Code workflows.

## Repository Structure

- `skills\` contains Claude Code skills (each skill is a directory with `SKILL.md`).
- `agents\` contains agent persona markdown (21 council + 17 academy).
- `commands\` contains slash command prompt files and the shared deliberation engine.
- `scripts\` and `hooks\` contain PowerShell automation used by this setup.
- `workspaces\` contains project-specific context templates.
- `templates\` contains project initialization templates.

## Pull Requests

- Explain why the change exists.
- Include before/after behavior when relevant.
- Update docs when behavior changes (especially `README.md` and `ARCHITECTURE.md`).

## Ways to Contribute

- **Onboarding feedback:** if you ran the installer for the first time, report what was confusing or brittle.
- **Docs:** clarify adoption paths, presets/flags, or third-party attribution.
- **Skills/agents/commands:** fix incorrect guidance, tighten triggers, or add concise examples.
- **Installer hardening:** improve conflict handling, manifest uninstall behavior, and dry-run correctness.
- **Windows improvements:** better notification handling, symlink detection, PowerShell compatibility.

## Workflow

- Create a branch from `main`.
- Open (or reference) a GitHub issue that explains what you're changing and why.
- Open a pull request.
- Keep changes focused (small PRs merge faster).
- Link the issue in the PR description (e.g. `Closes #123` or `Refs #123`) so the rationale is easy to find later.

## Local Validation

Run these checks before opening a PR:

```powershell
# PowerShell syntax checking
@('Install.ps1') + @(Get-ChildItem hooks\*.ps1) + @(Get-ChildItem scripts\*.ps1) | ForEach-Object {
    $path = if ($_ -is [string]) { $_ } else { $_.FullName }
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $path, [ref]$null, [ref]$errors
    )
    if ($errors) { Write-Error "$path has syntax errors: $errors" }
    else { Write-Host "OK: $path" }
}

# JSON validation
Get-Content settings.json | ConvertFrom-Json | Out-Null
Get-Content hooks.json | ConvertFrom-Json | Out-Null

# Installer smoke test (safe, isolated)
$env:CLAUDE_DIR = "$env:TEMP\claude-test"
.\Install.ps1 -Preset skills -ConflictPolicy fail
.\Install.ps1 -Uninstall
Remove-Item $env:CLAUDE_DIR -Recurse -Force -ErrorAction SilentlyContinue
$env:CLAUDE_DIR = $null
```

## Documentation Expectations

- Prefer minimal-diff edits.
- Keep paths and commands copy/pasteable.
- Avoid introducing non-ASCII characters unless the file already uses them.
