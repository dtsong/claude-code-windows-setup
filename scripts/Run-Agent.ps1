#Requires -Version 5.1
<#
.SYNOPSIS
    Wrapper script for running Claude agents with lifecycle management
.DESCRIPTION
    Runs claude with an initial prompt, sends notification on completion,
    auto-closes terminal after "Task complete:" commit unless KeepOpen is set.
.PARAMETER WorktreePath
    Path to the git worktree
.PARAMETER Branch
    Branch name being worked on
.PARAMETER KeepOpen
    Keep window open after task completes
#>
param(
    [Parameter(Mandatory)]
    [string]$WorktreePath,

    [Parameter(Mandatory)]
    [string]$Branch,

    [switch]$KeepOpen
)

$ErrorActionPreference = 'Stop'

if (-not $WorktreePath -or -not $Branch) {
    Write-Host "Usage: Run-Agent.ps1 -WorktreePath <path> -Branch <name> [-KeepOpen]"
    exit 1
}

Set-Location $WorktreePath

Write-Host "=== Agent: $Branch ==="
Write-Host "Worktree: $WorktreePath"
Write-Host "Keep open: $KeepOpen"
Write-Host ""

# Initial prompt for the agent
$InitialPrompt = "Read the .claude-task file and complete the task described there. Follow the instructions carefully. Remember to run 'npm run build' before marking the task complete."

# Run claude
claude --dangerously-skip-permissions $InitialPrompt
$ExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "=== Agent exited with code $ExitCode ==="

# Check if task was completed successfully
$LastCommit = git log -1 --format='%s' 2>$null
if (-not $LastCommit) { $LastCommit = '' }

if ($LastCommit -match 'Task complete:') {
    Write-Host "Task completed successfully!"

    # Extract task summary from commit message
    $Summary = $LastCommit -replace 'Task complete:\s*', ''

    # Send notification
    $NotifyScript = Join-Path $env:USERPROFILE '.claude\scripts\Notify-Complete.ps1'
    if (Test-Path $NotifyScript) {
        & $NotifyScript -Branch $Branch -Summary $Summary
    }

    if (-not $KeepOpen) {
        Write-Host ""
        Write-Host "Window closing in 5 seconds..."
        Write-Host "(Use -KeepOpen flag to prevent auto-close)"
        Start-Sleep -Seconds 5
        exit 0
    }
    else {
        Write-Host ""
        Write-Host "Window staying open (-KeepOpen flag set)"
    }
}
else {
    Write-Host ""
    Write-Host "Agent exited without 'Task complete:' commit."
    Write-Host "Last commit: $LastCommit"
    Write-Host ""
    Write-Host "Window will stay open for debugging."
    Write-Host "Check git status and logs to understand what happened."
}

# If we get here, keep the shell open
Write-Host ""
Read-Host "Press Enter to close this window..."
