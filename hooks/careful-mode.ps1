#===============================================================================
# Careful Mode Hook (PreToolUse, opt-in)
# Blocks destructive shell commands while /careful is on.
#
# Usage:  careful-mode.ps1 enable | disable | status | check
#   enable/disable/status  called by the /careful command
#   check                  called by the PreToolUse hook (JSON on stdin)
#
# Fires on: PreToolUse / Bash|PowerShell (only if registered in settings.json;
#           see README "Opt-in safety hooks")
# Exits:    0 = allow, 2 = block (stderr reason is fed to Claude)
#
# Port of upstream my-claude-setup hooks/careful-mode.sh. Unlike the bash
# original, `check` reads the hook payload from stdin (Claude Code does not
# set TOOL_NAME/TOOL_INPUT env vars) and writes the block reason to stderr.
#===============================================================================

param([string]$Mode = '')

$claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$stateFile = Join-Path $claudeDir '.careful-mode'

# Destructive patterns (case-insensitive regex). The first block mirrors
# upstream; the second adds Windows/PowerShell equivalents.
$blockedPatterns = @(
    'rm -rf'
    'rm -r /'
    'DROP TABLE'
    'DROP DATABASE'
    'TRUNCATE TABLE'
    'git push --force'
    'git push -f '
    'git reset --hard'
    'kubectl delete'
    'terraform destroy'
    'docker system prune -a'
    # Windows / PowerShell
    'Remove-Item\b(?=.*-Recurse)(?=.*-Force)'
    '\b(rd|rmdir)\s+/s\b'
    'Format-Volume'
    'Clear-Disk'
)

switch ($Mode) {
    'enable' {
        $null = New-Item -ItemType Directory -Force -Path $claudeDir
        Set-Content -Path $stateFile -Value '' -NoNewline
        Write-Output 'careful-mode: enabled'
        exit 0
    }
    'disable' {
        Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
        Write-Output 'careful-mode: disabled'
        exit 0
    }
    'status' {
        if (Test-Path $stateFile) { Write-Output 'careful-mode: on' } else { Write-Output 'careful-mode: off' }
        exit 0
    }
    'check' {
        # Fast path: not in careful mode.
        if (-not (Test-Path $stateFile)) { exit 0 }

        $rawInput = [Console]::In.ReadToEnd()
        if (-not $rawInput) { exit 0 }
        try { $inputObj = $rawInput | ConvertFrom-Json } catch { exit 0 }

        if ($inputObj.tool_name -notin @('Bash', 'PowerShell')) { exit 0 }
        $command = [string]$inputObj.tool_input.command
        if (-not $command) { exit 0 }

        foreach ($pattern in $blockedPatterns) {
            if ($command -match "(?i)$pattern") {
                # Allow --dry-run variants
                if ($command -match '(?i)--dry-run') { exit 0 }
                [Console]::Error.WriteLine("BLOCKED by /careful: command matches destructive pattern '$pattern'.")
                [Console]::Error.WriteLine("Use /careful off to disable, or use --dry-run first.")
                exit 2
            }
        }
        exit 0
    }
    default {
        Write-Output 'Usage: careful-mode.ps1 {enable|disable|status|check}'
        exit 1
    }
}
