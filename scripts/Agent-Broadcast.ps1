#Requires -Version 5.1
<#
.SYNOPSIS
    Broadcast and receive agent notifications
.DESCRIPTION
    Manages broadcast messages between Claude Code agents for coordination.
.PARAMETER Command
    The subcommand to run: send, list, list-new, count-new, show, mark-synced,
    last-sync, cleanup, summary, help
.PARAMETER Args
    Additional arguments for the subcommand
.EXAMPLE
    .\Agent-Broadcast.ps1 send task_completed agent-1 feat-001 "Login feature" "Implemented OAuth"
    .\Agent-Broadcast.ps1 list-new
    .\Agent-Broadcast.ps1 summary
#>
param(
    [string]$Command = 'help',
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'

$SharedDir = Join-Path $env:USERPROFILE '.claude\agent-context\shared'
$BroadcastsDir = Join-Path $SharedDir 'broadcasts'
$SyncFile = Join-Path $env:USERPROFILE '.claude\agent-context\.last_sync'

if (-not (Test-Path $BroadcastsDir)) {
    New-Item -ItemType Directory -Path $BroadcastsDir -Force | Out-Null
}

function Send-Broadcast {
    param($Type, $AgentId, $TaskId, $TaskTitle, $Message)

    if (-not $Type -or -not $AgentId) {
        Write-Host "Usage: Agent-Broadcast.ps1 send <type> <agent_id> <task_id> <task_title> <message>"
        return
    }

    $timestamp = Get-Date -Format 'o'
    $safeTimestamp = $timestamp -replace ':', '-'
    $filename = "${safeTimestamp}-${AgentId}.md"
    $filepath = Join-Path $BroadcastsDir $filename

    @"
---
type: "$Type"
agent_id: "$AgentId"
task_id: "$TaskId"
task_title: "$TaskTitle"
timestamp: "$timestamp"
---

## ${Type}: $TaskTitle

**Agent:** $AgentId
**Task:** $TaskId
**Time:** $timestamp

### Details
$Message
"@ | Set-Content -Path $filepath -Encoding UTF8

    Write-Host $filepath
}

function Get-AllBroadcasts {
    if ((Test-Path $BroadcastsDir) -and (Get-ChildItem -Path $BroadcastsDir -Filter '*.md' -ErrorAction SilentlyContinue)) {
        Get-ChildItem -Path $BroadcastsDir -Filter '*.md' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 20 |
            ForEach-Object { $_.FullName }
    }
    else {
        Write-Host "No broadcasts found"
    }
}

function Get-NewBroadcasts {
    if (Test-Path $SyncFile) {
        $syncTime = (Get-Item $SyncFile).LastWriteTime
        $newFiles = Get-ChildItem -Path $BroadcastsDir -Filter '*.md' -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $syncTime } |
            Sort-Object LastWriteTime -Descending
        if ($newFiles) {
            $newFiles | ForEach-Object { $_.FullName }
        }
        else {
            Write-Host "No new broadcasts since last sync"
        }
    }
    else {
        # No sync file, show last 10
        Get-ChildItem -Path $BroadcastsDir -Filter '*.md' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10 |
            ForEach-Object { $_.FullName }
    }
}

function Get-NewCount {
    if (Test-Path $SyncFile) {
        $syncTime = (Get-Item $SyncFile).LastWriteTime
        $count = (Get-ChildItem -Path $BroadcastsDir -Filter '*.md' -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $syncTime }).Count
        Write-Host $count
    }
    else {
        $count = (Get-ChildItem -Path $BroadcastsDir -Filter '*.md' -ErrorAction SilentlyContinue).Count
        Write-Host $count
    }
}

function Show-Broadcast {
    param($File)

    if (-not $File) {
        Write-Host "Usage: Agent-Broadcast.ps1 show <filename>"
        return
    }

    if (Test-Path $File) {
        Get-Content $File
    }
    elseif (Test-Path (Join-Path $BroadcastsDir $File)) {
        Get-Content (Join-Path $BroadcastsDir $File)
    }
    else {
        Write-Host "Broadcast not found: $File"
    }
}

function Set-Synced {
    if (-not (Test-Path (Split-Path $SyncFile -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $SyncFile -Parent) -Force | Out-Null
    }
    # Touch the sync file
    if (Test-Path $SyncFile) {
        (Get-Item $SyncFile).LastWriteTime = Get-Date
    }
    else {
        New-Item -ItemType File -Path $SyncFile -Force | Out-Null
    }
    $syncTime = Get-Date -Format 'o'
    Write-Host "Sync time updated: $syncTime"
}

function Get-LastSync {
    if (Test-Path $SyncFile) {
        (Get-Item $SyncFile).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    }
    else {
        Write-Host "Never synced"
    }
}

function Remove-OldBroadcasts {
    param([int]$Days = 7)

    $cutoff = (Get-Date).AddDays(-$Days)
    $oldFiles = Get-ChildItem -Path $BroadcastsDir -Filter '*.md' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }

    if ($oldFiles) {
        $count = $oldFiles.Count
        $oldFiles | Remove-Item -Force
        Write-Host "Cleaned up $count broadcasts older than $Days days"
    }
    else {
        Write-Host "No broadcasts older than $Days days"
    }
}

function Show-Summary {
    $totalCount = (Get-ChildItem -Path $BroadcastsDir -Filter '*.md' -ErrorAction SilentlyContinue).Count
    Write-Host "=== Broadcast Summary ==="
    Write-Host "Total broadcasts: $totalCount"
    Write-Host "New since sync: $(Get-NewCount)"
    Write-Host "Last sync: $(Get-LastSync)"
    Write-Host ""
    Write-Host "Recent broadcasts:"
    Get-AllBroadcasts | Select-Object -First 5
}

function Show-Help {
    Write-Host @"
Agent-Broadcast.ps1 - Broadcast notifications between agents

Commands:
  send <type> <agent_id> <task_id> <title> <message>
                            - Send a broadcast notification
  list                      - List all broadcasts
  list-new                  - List broadcasts since last sync
  count-new                 - Count new broadcasts
  show <file>               - Show a broadcast's contents
  mark-synced               - Mark current time as synced
  last-sync                 - Show last sync time
  cleanup [days]            - Remove broadcasts older than N days (default: 7)
  summary                   - Show broadcast summary

Broadcast Types:
  task_completed  - A task was completed
  task_blocked    - A task hit a blocker
  task_unblocked  - A blocked task is now available
  agent_status    - Agent status update

Directory: $BroadcastsDir
"@
}

switch ($Command) {
    'send'        { Send-Broadcast $Args[0] $Args[1] $Args[2] $Args[3] $Args[4] }
    'list'        { Get-AllBroadcasts }
    'list-new'    { Get-NewBroadcasts }
    'count-new'   { Get-NewCount }
    'show'        { Show-Broadcast $Args[0] }
    'mark-synced' { Set-Synced }
    'last-sync'   { Get-LastSync }
    'cleanup'     { $d = if ($Args[0]) { [int]$Args[0] } else { 7 }; Remove-OldBroadcasts -Days $d }
    'summary'     { Show-Summary }
    default       { Show-Help }
}
