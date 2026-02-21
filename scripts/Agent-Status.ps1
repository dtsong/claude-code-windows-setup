#Requires -Version 5.1
<#
.SYNOPSIS
    Show status of all agent worktrees
.DESCRIPTION
    Lists all agent worktrees for the current repository, showing branch, task,
    status, and last commit time.
.PARAMETER Verbose
    Show recent commits for each worktree
.EXAMPLE
    .\Agent-Status.ps1
    .\Agent-Status.ps1 -Verbose
#>
param(
    [switch]$Verbose
)

# Get repo root and name
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    Write-Error "Not in a git repository"
    exit 1
}

$RepoName = Split-Path $RepoRoot -Leaf
$WorktreeBase = Join-Path $env:USERPROFILE ".claude-worktrees\$RepoName"

# Check if worktree directory exists
if (-not (Test-Path $WorktreeBase)) {
    Write-Host "No worktrees found for $RepoName"
    Write-Host ""
    Write-Host "Use /launch to start working on a task"
    exit 0
}

$Now = Get-Date

function Get-RelativeTime {
    param([datetime]$Timestamp)
    $diff = $Now - $Timestamp

    if ($diff.TotalSeconds -lt 60) { return 'just now' }
    elseif ($diff.TotalMinutes -lt 60) { return "$([int]$diff.TotalMinutes) min ago" }
    elseif ($diff.TotalHours -lt 24) { return "$([int]$diff.TotalHours) hours ago" }
    else { return "$([int]$diff.TotalDays) days ago" }
}

function Get-WorktreeStatus {
    param($WorktreePath, [datetime]$LastCommitTime)
    $diff = $Now - $LastCommitTime

    # Check for completion marker
    $lastSubject = git -C $WorktreePath log -1 --pretty=%s 2>$null
    if ($lastSubject -match 'Task complete:') {
        return 'Complete'
    }

    # Check if stale (no commits in 2+ hours)
    if ($diff.TotalHours -gt 2) {
        return 'Stale'
    }

    return 'Working'
}

# Header
Write-Host ""
Write-Host "Active Worktrees for ${RepoName}:"
Write-Host ""

$CompleteBranches = @()

# List all worktrees
$worktrees = Get-ChildItem -Path $WorktreeBase -Directory -ErrorAction SilentlyContinue
foreach ($worktree in $worktrees) {
    $branch = $worktree.Name

    # Get task from .claude-task file
    $taskFile = Join-Path $worktree.FullName '.claude-task'
    if (Test-Path $taskFile) {
        $taskContent = Get-Content $taskFile -Raw
        # Extract task (first non-empty line after "# Current Task")
        if ($taskContent -match '# Current Task\r?\n\r?\n(.+)') {
            $task = $Matches[1].Trim()
        }
        else {
            $task = 'Unknown task'
        }
    }
    else {
        $task = 'Unknown task'
    }

    # Truncate task for display
    if ($task.Length -gt 35) { $task = $task.Substring(0, 32) + '...' }

    # Get last commit time
    $lastCommitEpoch = git -C $worktree.FullName log -1 --pretty=%ct 2>$null
    if ($lastCommitEpoch) {
        $lastCommitTime = (Get-Date '1970-01-01').AddSeconds([long]$lastCommitEpoch)
        $lastCommitRel = Get-RelativeTime $lastCommitTime
    }
    else {
        $lastCommitTime = Get-Date '2000-01-01'
        $lastCommitRel = 'unknown'
    }

    # Determine status
    $status = Get-WorktreeStatus -WorktreePath $worktree.FullName -LastCommitTime $lastCommitTime

    # Track complete branches
    if ($status -eq 'Complete') { $CompleteBranches += $branch }

    # Status indicator
    $indicator = switch ($status) {
        'Working'  { '[WORKING]' }
        'Complete' { '[DONE]   ' }
        'Stale'    { '[STALE]  ' }
        default    { '[?]      ' }
    }

    # Print row
    Write-Host ('{0} {1,-20} {2,-35} {3,-10} {4}' -f $indicator, $branch, $task, $status, $lastCommitRel)

    # Verbose: show recent commits
    if ($Verbose) {
        Write-Host "   Recent commits:"
        $logs = git -C $worktree.FullName log -3 --pretty="   - %s (%cr)" 2>$null
        if ($logs) { $logs | ForEach-Object { Write-Host $_ } }
        else { Write-Host "   (no commits)" }
        Write-Host ""
    }
}

# Summary
Write-Host ""
if ($CompleteBranches.Count -gt 0) {
    Write-Host "Ready to merge: $($CompleteBranches -join ', ')"
    Write-Host ""
}

Write-Host "Quick actions:"
Write-Host "  /merge <branch>    - Merge completed work"
Write-Host "  /launch `"task`"     - Start new agent"
