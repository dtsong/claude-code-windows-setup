#===============================================================================
# Freeze Mode Hook (PreToolUse, opt-in)
# Blocks Edit/Write/MultiEdit to files matching frozen patterns.
#
# Usage:  freeze-mode.ps1 enable "<pattern>" | disable | status | check
#   enable/disable/status  called by the /freeze command
#   check                  called by the PreToolUse hook (JSON on stdin)
#
# Patterns are PowerShell wildcards (* ? [..]), matched case-insensitively
# against the file name AND the path (forward slashes) relative to the
# project root, so both '*.lock' and 'src/core/**' work.
#
# Fires on: PreToolUse / Edit|Write|MultiEdit (only if registered in
#           settings.json; see README "Opt-in safety hooks")
# Exits:    0 = allow, 2 = block (stderr reason is fed to Claude)
#
# Port of upstream my-claude-setup hooks/freeze-mode.sh. Unlike the bash
# original, `check` reads the hook payload from stdin, matches relative paths
# (the original compared basenames only), and writes to stderr.
#===============================================================================

param(
    [string]$Mode = '',
    [string]$Pattern = ''
)

$claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$stateFile = Join-Path $claudeDir '.freeze-patterns'

switch ($Mode) {
    'enable' {
        if (-not $Pattern) {
            Write-Output "Pattern required. Usage: freeze-mode.ps1 enable '<pattern>'"
            exit 1
        }
        $null = New-Item -ItemType Directory -Force -Path $claudeDir
        Add-Content -Path $stateFile -Value $Pattern
        Write-Output "freeze-mode: pattern '$Pattern' added"
        exit 0
    }
    'disable' {
        Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
        Write-Output 'freeze-mode: all patterns cleared'
        exit 0
    }
    'status' {
        if (Test-Path $stateFile) {
            Write-Output 'freeze-mode: frozen patterns:'
            Get-Content $stateFile | Where-Object { $_ } | ForEach-Object { Write-Output "  $_" }
        } else {
            Write-Output 'freeze-mode: off'
        }
        exit 0
    }
    'check' {
        # Fast path: nothing frozen.
        if (-not (Test-Path $stateFile)) { exit 0 }

        $rawInput = [Console]::In.ReadToEnd()
        if (-not $rawInput) { exit 0 }
        try { $inputObj = $rawInput | ConvertFrom-Json } catch { exit 0 }

        if ($inputObj.tool_name -notin @('Edit', 'Write', 'MultiEdit')) { exit 0 }
        $filePath = [string]$inputObj.tool_input.file_path
        if (-not $filePath) { exit 0 }

        # Candidate names to match: file name, path relative to project root, full path.
        $root = if ($inputObj.cwd) { [string]$inputObj.cwd } else { $PWD.Path }
        try {
            $gitRoot = & git -C $root rev-parse --show-toplevel 2>$null
            if ($gitRoot) { $root = $gitRoot }
        } catch { }
        $full = $filePath -replace '\\', '/'
        $rootNorm = ($root -replace '\\', '/').TrimEnd('/')
        $relative = $full
        if ($full.StartsWith("$rootNorm/", [System.StringComparison]::OrdinalIgnoreCase)) {
            $relative = $full.Substring($rootNorm.Length + 1)
        }
        $name = Split-Path $filePath -Leaf

        foreach ($p in Get-Content $stateFile) {
            if (-not $p) { continue }
            $pat = ($p.Trim() -replace '\\', '/') -replace '^\./', ''
            if ($name -like $pat -or $relative -like $pat -or $full -like $pat) {
                [Console]::Error.WriteLine("BLOCKED by /freeze: '$relative' matches frozen pattern '$p'.")
                [Console]::Error.WriteLine("Run /freeze off to unfreeze.")
                exit 2
            }
        }
        exit 0
    }
    default {
        Write-Output 'Usage: freeze-mode.ps1 {enable <pattern>|disable|status|check}'
        exit 1
    }
}
