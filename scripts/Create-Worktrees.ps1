#Requires -Version 5.1
<#
.SYNOPSIS
    Create git worktrees for parallel Claude Code agents
.DESCRIPTION
    Creates multiple git worktrees so you can run parallel Claude Code agents.
.PARAMETER NumAgents
    Number of agent worktrees to create (default: 5)
.PARAMETER BaseName
    Base name for branches and directories (default: agent)
.EXAMPLE
    .\Create-Worktrees.ps1 -NumAgents 5 -BaseName agent
    Creates: ..\project-agent-1, ..\project-agent-2, etc.
#>
param(
    [int]$NumAgents = 5,
    [string]$BaseName = 'agent'
)

$ErrorActionPreference = 'Stop'

# Check if we're in a git repository
$gitDir = git rev-parse --git-dir 2>$null
if (-not $gitDir) {
    Write-Error "Not in a git repository"
    exit 1
}

$RepoRoot = git rev-parse --show-toplevel
$RepoName = Split-Path $RepoRoot -Leaf
$ParentDir = Split-Path $RepoRoot -Parent

Write-Host "Creating $NumAgents worktrees for parallel Claude Code agents..."
Write-Host ""

foreach ($i in 1..$NumAgents) {
    $WorktreeDir = Join-Path $ParentDir "${RepoName}-${BaseName}-${i}"
    $BranchName = "${BaseName}-${i}"

    if (Test-Path $WorktreeDir) {
        Write-Host "[WARNING] Worktree $WorktreeDir already exists, skipping"
    }
    else {
        # Create branch if it doesn't exist
        $branchExists = git show-ref --verify --quiet "refs/heads/${BranchName}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            git branch $BranchName 2>$null
        }

        git worktree add $WorktreeDir $BranchName 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Created worktree: $WorktreeDir (branch: $BranchName)"
        }
        else {
            # If branch exists, try alternative approaches
            git worktree add $WorktreeDir -b $BranchName 2>$null
            if ($LASTEXITCODE -ne 0) {
                git worktree add $WorktreeDir $BranchName 2>$null
            }
            Write-Host "[OK] Created worktree: $WorktreeDir"
        }
    }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Worktrees created! To run $NumAgents parallel agents:"
Write-Host "=========================================="
Write-Host ""
foreach ($i in 1..$NumAgents) {
    Write-Host "  Terminal ${i}: cd $(Join-Path $ParentDir "${RepoName}-${BaseName}-${i}") && claude"
}
Write-Host ""
Write-Host "=========================================="
Write-Host "To remove all worktrees later:"
Write-Host "=========================================="
Write-Host "  git worktree list"
Write-Host "  git worktree remove <path>"
