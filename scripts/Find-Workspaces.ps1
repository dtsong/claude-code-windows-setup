#Requires -Version 5.1
<#
.SYNOPSIS
    Discover running Claude instances and their workspaces
.DESCRIPTION
    Scans Claude session files to find active workspaces, their branches,
    and git status.
.PARAMETER Json
    Output results as JSON
.PARAMETER ActiveOnly
    Only show workspaces active within the last 2 hours
.EXAMPLE
    .\Find-Workspaces.ps1
    .\Find-Workspaces.ps1 -Json -ActiveOnly
#>
param(
    [switch]$Json,
    [switch]$ActiveOnly
)

$ErrorActionPreference = 'Stop'

$ClaudeDir = Join-Path $env:USERPROFILE '.claude'

function Get-ActiveSessions {
    $todosDir = Join-Path $ClaudeDir 'todos'
    if (-not (Test-Path $todosDir)) { return @() }

    $sessionIds = Get-ChildItem -Path $todosDir -Filter '*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 30 |
        ForEach-Object {
            $_.BaseName -replace '-agent.*', ''
        } |
        Sort-Object -Unique

    return $sessionIds
}

function Get-SessionInfo {
    param([string]$SessionId)

    $projectsDir = Join-Path $ClaudeDir 'projects'
    if (-not (Test-Path $projectsDir)) { return $null }

    $sessionFile = Get-ChildItem -Path $projectsDir -Filter "${SessionId}.jsonl" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $sessionFile) { return $null }

    $content = Get-Content $sessionFile.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $null }

    $cwd = $null
    $gitBranch = $null
    $slug = $null

    # Extract fields from JSONL (last occurrence wins)
    if ($content -match '"cwd":"([^"]*)"') { $cwd = $Matches[1] }
    if ($content -match '"gitBranch":"([^"]*)"') { $gitBranch = $Matches[1] }
    if ($content -match '"slug":"([^"]*)"') { $slug = $Matches[1] }

    $lastActivity = $sessionFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm')

    return @{
        SessionId    = $SessionId
        Cwd          = $cwd
        Branch       = $gitBranch
        LastActivity = $lastActivity
        Slug         = $slug
        SessionFile  = $sessionFile.FullName
    }
}

function Get-GitStatus {
    param([string]$Workspace)

    if (-not (Test-Path $Workspace)) { return $null }

    $gitDir = git -C $Workspace rev-parse --git-dir 2>$null
    if (-not $gitDir) { return $null }

    $currentBranch = git -C $Workspace branch --show-current 2>$null
    $changes = (git -C $Workspace status --porcelain 2>$null | Measure-Object).Count
    $ahead = git -C $Workspace rev-list --count '@{u}..HEAD' 2>$null
    if (-not $ahead) { $ahead = 0 }
    $behind = git -C $Workspace rev-list --count 'HEAD..@{u}' 2>$null
    if (-not $behind) { $behind = 0 }

    return @{
        Branch  = $currentBranch
        Changes = [int]$changes
        Ahead   = [int]$ahead
        Behind  = [int]$behind
    }
}

function Test-SessionActive {
    param([string]$SessionId)

    $todoFile = Join-Path $ClaudeDir "todos\${SessionId}-agent-${SessionId}.json"
    if (Test-Path $todoFile) {
        $modTime = (Get-Item $todoFile).LastWriteTime
        $age = (Get-Date) - $modTime
        return $age.TotalHours -lt 2
    }
    return $false
}

# Main
$sessions = Get-ActiveSessions
$workspaces = @()
$count = 0

foreach ($sessionId in $sessions) {
    if (-not $sessionId) { continue }

    $info = Get-SessionInfo $sessionId
    if (-not $info -or -not $info.Cwd -or -not (Test-Path $info.Cwd)) { continue }

    $isActive = Test-SessionActive $sessionId
    if ($ActiveOnly -and -not $isActive) { continue }

    $gitInfo = Get-GitStatus $info.Cwd
    $displayBranch = if ($gitInfo) { $gitInfo.Branch } else { $info.Branch }
    $changes = if ($gitInfo) { $gitInfo.Changes } else { 0 }
    $ahead = if ($gitInfo) { $gitInfo.Ahead } else { 0 }
    $behind = if ($gitInfo) { $gitInfo.Behind } else { 0 }

    $count++

    $workspaces += @{
        Id           = $count
        SessionId    = $info.SessionId
        Workspace    = $info.Cwd
        Branch       = $displayBranch
        Slug         = $info.Slug
        LastActivity = $info.LastActivity
        GitChanges   = $changes
        Ahead        = $ahead
        Behind       = $behind
        Active       = $isActive
    }
}

if ($Json) {
    $output = @{
        workspaces = $workspaces
        total      = $count
    }
    $output | ConvertTo-Json -Depth 5
}
else {
    Write-Host "=== Active Claude Workspaces ==="
    Write-Host ""

    foreach ($ws in $workspaces) {
        $activeMarker = if ($ws.Active) { ' [ACTIVE]' } else { '' }
        Write-Host "[$($ws.Id)] $($ws.Slug)$activeMarker"
        Write-Host "    Workspace: $($ws.Workspace)"
        Write-Host "    Branch: $($ws.Branch)"
        Write-Host "    Last: $($ws.LastActivity)"
        if ($ws.GitChanges -ne 0) { Write-Host "    Changes: $($ws.GitChanges) uncommitted files" }
        if ($ws.Ahead -ne 0) { Write-Host "    Ahead: $($ws.Ahead) commits" }
        Write-Host ""
    }

    Write-Host "Found $count workspace(s)"
}
