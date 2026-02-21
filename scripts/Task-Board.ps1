#Requires -Version 5.1
<#
.SYNOPSIS
    Task board operations for multi-agent coordination
.DESCRIPTION
    Manages a shared task board for coordinating multiple Claude Code agents.
    Supports creating, claiming, completing, and listing tasks.
.PARAMETER Command
    The subcommand: init, reset, show, add-task, list-available, list-claimed,
    acquire-lock, release-lock, check-stale, help
.PARAMETER Arguments
    Additional arguments for the subcommand
.EXAMPLE
    .\Task-Board.ps1 init my-board "C:\Projects\my-app"
    .\Task-Board.ps1 add-task feat-001 "Add login page" high
    .\Task-Board.ps1 list-available
#>
param(
    [string]$Command = 'help',
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'

$SharedDir = Join-Path $env:USERPROFILE '.claude\agent-context\shared'
$BoardFile = Join-Path $SharedDir 'task-board.md'
$LockFile = Join-Path $SharedDir 'claims.lock'

# Ensure shared directory exists
if (-not (Test-Path $SharedDir)) {
    New-Item -ItemType Directory -Path $SharedDir -Force | Out-Null
}
$broadcastsDir = Join-Path $SharedDir 'broadcasts'
if (-not (Test-Path $broadcastsDir)) {
    New-Item -ItemType Directory -Path $broadcastsDir -Force | Out-Null
}

function Invoke-AcquireLock {
    param([string]$AgentId = 'unknown')

    $maxAttempts = 3
    $lockTimeout = 30

    for ($attempt = 0; $attempt -lt $maxAttempts; $attempt++) {
        if (Test-Path $LockFile) {
            $lockAge = ((Get-Date) - (Get-Item $LockFile).LastWriteTime).TotalSeconds
            if ($lockAge -gt $lockTimeout) {
                Remove-Item $LockFile -Force
            }
            else {
                $attempt++
                Write-Host "Lock held by another agent, waiting... (attempt $($attempt)/$maxAttempts)" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                continue
            }
        }

        # Try to acquire lock
        $tempLock = [IO.Path]::GetTempFileName()
        "$AgentId|$(Get-Date -Format 'o')" | Set-Content $tempLock -Encoding UTF8
        try {
            Move-Item $tempLock $LockFile -Force
            Write-Host "Lock acquired"
            return
        }
        catch {
            Remove-Item $tempLock -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
    }

    Write-Error "Failed to acquire lock after $maxAttempts attempts"
}

function Invoke-ReleaseLock {
    if (Test-Path $LockFile) {
        Remove-Item $LockFile -Force
        Write-Host "Lock released"
    }
}

function Invoke-CheckStale {
    param([int]$TimeoutHours = 4)

    Write-Host "Checking for claims older than ${TimeoutHours}h..."

    if (-not (Test-Path $BoardFile)) {
        Write-Host "No task board found"
        return
    }

    $content = Get-Content $BoardFile -Raw
    # Find claimed tasks
    $inClaimed = $false
    foreach ($line in (Get-Content $BoardFile)) {
        if ($line -match 'status:\s*claimed') { $inClaimed = $true }
        if ($inClaimed -and $line -match '^\s+-\s+id:\s*"([^"]+)"') {
            Write-Host $Matches[1]
            $inClaimed = $false
        }
    }
}

function Invoke-InitBoard {
    param([string]$BoardId, [string]$ProjectPath)

    if (-not $BoardId -or -not $ProjectPath) {
        Write-Host "Usage: Task-Board.ps1 init <board_id> <project_path>"
        return
    }

    if (Test-Path $BoardFile) {
        Write-Host "Task board already exists at $BoardFile"
        Write-Host "Use 'Task-Board.ps1 reset' to create a new one"
        return
    }

    $timestamp = Get-Date -Format 'o'

    @"
---
board_id: "$BoardId"
created: "$timestamp"
updated: "$timestamp"
project_path: "$ProjectPath"

settings:
  auto_archive_completed: true
  claim_timeout_hours: 4
  require_workspace_match: false

active_agents: []

tasks: []

completed: []
---

## Task Board: $BoardId

### How to Use
- Run ``/task-board`` to view available tasks
- Run ``/claim-task <task-id>`` to claim a task
- Run ``/complete-task`` to mark your current task done
- Run ``/sync-agents`` to see what other agents are doing

### Recent Activity
- $timestamp - Task board created for $ProjectPath
"@ | Set-Content -Path $BoardFile -Encoding UTF8

    Write-Host "Task board created at $BoardFile"
}

function Invoke-ResetBoard {
    if (Test-Path $BoardFile) {
        $backupName = "$BoardFile.backup.$([long](Get-Date -UFormat '%s'))"
        Move-Item $BoardFile $backupName
        Write-Host "Backed up existing board to $backupName"
    }
    Write-Host "Board reset. Run 'init' to create a new one."
}

function Invoke-ShowBoard {
    if (-not (Test-Path $BoardFile)) {
        Write-Host "No task board found. Run: Task-Board.ps1 init <board_id> <project_path>"
        return
    }
    Get-Content $BoardFile
}

function Invoke-AddTask {
    param([string]$TaskId, [string]$Title, [string]$Priority = 'medium', [string]$Description = '')

    if (-not $TaskId -or -not $Title) {
        Write-Host "Usage: Task-Board.ps1 add-task <task_id> <title> [priority] [description]"
        return
    }

    if (-not (Test-Path $BoardFile)) {
        Write-Host "No task board found. Run init first."
        return
    }

    $timestamp = Get-Date -Format 'o'

    $taskBlock = @"

  - id: "$TaskId"
    title: "$Title"
    description: "$Description"
    priority: $Priority
    status: available
    dependencies: []
    created: "$timestamp"
"@

    $content = Get-Content $BoardFile -Raw

    # Replace empty tasks array
    if ($content -match 'tasks: \[\]') {
        $content = $content -replace 'tasks: \[\]', "tasks:$taskBlock"
    }
    else {
        # Insert before completed section
        $content = $content -replace '(\r?\n)(completed:)', "$taskBlock`$1`$2"
    }

    # Update timestamp
    $content = $content -replace 'updated: "[^"]*"', "updated: `"$timestamp`""

    $content | Set-Content -Path $BoardFile -Encoding UTF8 -NoNewline

    Write-Host "Task $TaskId added to board"
}

function Invoke-ListAvailable {
    if (-not (Test-Path $BoardFile)) {
        Write-Host "No task board found"
        return
    }

    Write-Host "Available tasks:"
    $currentId = $null
    $currentTitle = $null
    foreach ($line in (Get-Content $BoardFile)) {
        if ($line -match '^\s+-\s+id:\s*"([^"]+)"') { $currentId = $Matches[1] }
        if ($line -match 'title:\s*"([^"]+)"') { $currentTitle = $Matches[1] }
        if ($line -match 'status:\s*available' -and $currentId) {
            Write-Host "  ${currentId}: $currentTitle"
            $currentId = $null
            $currentTitle = $null
        }
    }
}

function Invoke-ListClaimed {
    if (-not (Test-Path $BoardFile)) {
        Write-Host "No task board found"
        return
    }

    Write-Host "Claimed tasks:"
    $currentId = $null
    $currentTitle = $null
    foreach ($line in (Get-Content $BoardFile)) {
        if ($line -match '^\s+-\s+id:\s*"([^"]+)"') { $currentId = $Matches[1] }
        if ($line -match 'title:\s*"([^"]+)"') { $currentTitle = $Matches[1] }
        if ($line -match 'status:\s*claimed' -and $currentId) {
            Write-Host "  ${currentId}: $currentTitle"
            $currentId = $null
            $currentTitle = $null
        }
    }
}

function Show-Help {
    Write-Host @"
Task-Board.ps1 - Task board operations for multi-agent coordination

Commands:
  acquire-lock [agent_id]    - Acquire the claims lock
  release-lock               - Release the claims lock
  check-stale [hours]        - Check for stale claims (default: 4h)
  init <board_id> <path>     - Initialize a new task board
  reset                      - Reset the task board (backs up existing)
  show                       - Display the task board
  add-task <id> <title> [priority] [desc] - Add a task
  list-available             - List available tasks
  list-claimed               - List claimed tasks

Files:
  Task Board: $BoardFile
  Lock File:  $LockFile
  Broadcasts: $SharedDir\broadcasts\
"@
}

switch ($Command) {
    'acquire-lock'   { Invoke-AcquireLock ($Arguments[0]) }
    'release-lock'   { Invoke-ReleaseLock }
    'check-stale'    { $h = if ($Arguments[0]) { [int]$Arguments[0] } else { 4 }; Invoke-CheckStale $h }
    'init'           { Invoke-InitBoard $Arguments[0] $Arguments[1] }
    'reset'          { Invoke-ResetBoard }
    'show'           { Invoke-ShowBoard }
    'add-task'       { Invoke-AddTask $Arguments[0] $Arguments[1] $Arguments[2] $Arguments[3] }
    'list-available' { Invoke-ListAvailable }
    'list-claimed'   { Invoke-ListClaimed }
    default          { Show-Help }
}
