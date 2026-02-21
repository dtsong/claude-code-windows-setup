#Requires -Version 5.1
<#
.SYNOPSIS
    Launch Claude agent(s) in a worktree
.DESCRIPTION
    Creates a git worktree for the given branch, writes a task file, and launches
    one or more Claude agents in new Windows Terminal tabs.
.PARAMETER Task
    The task description for the agent
.PARAMETER Branch
    The branch name to work on
.PARAMETER NumAgents
    Number of agents to launch (default: 1)
.PARAMETER KeepOpen
    Keep terminal window open after task completes
.EXAMPLE
    .\Launch-Agent.ps1 -Task "Fix login bug" -Branch "fix/login" -NumAgents 2
#>
param(
    [Parameter(Mandatory)]
    [string]$Task,

    [Parameter(Mandatory)]
    [string]$Branch,

    [int]$NumAgents = 1,

    [switch]$KeepOpen
)

$ErrorActionPreference = 'Stop'

# Get the repo root and name
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    Write-Error "Not in a git repository"
    exit 1
}

$RepoName = Split-Path $RepoRoot -Leaf
$WorktreeBase = Join-Path $env:USERPROFILE ".claude-worktrees\$RepoName"
$SafeBranch = $Branch -replace '/', '-'
$WorktreePath = Join-Path $WorktreeBase $SafeBranch

# Create worktree base directory
if (-not (Test-Path $WorktreeBase)) {
    New-Item -ItemType Directory -Path $WorktreeBase -Force | Out-Null
}

# Check if branch/worktree already exists
if (Test-Path $WorktreePath) {
    Write-Host "Worktree already exists: $WorktreePath"
    Write-Host "Resuming work on existing branch..."
}
else {
    Write-Host "Creating worktree: $WorktreePath"
    git worktree add -b $Branch $WorktreePath 2>$null
    if ($LASTEXITCODE -ne 0) {
        git worktree add $WorktreePath $Branch 2>$null
        if ($LASTEXITCODE -ne 0) {
            git worktree add -b $Branch $WorktreePath
        }
    }
}

# Create agent prompt file for the task
$PromptFile = Join-Path $WorktreePath '.claude-task'
@"
# Current Task

$Task

## Instructions

1. Read CLAUDE.md for project context
2. Plan your approach using TodoWrite
3. Implement the solution
4. **REQUIRED: Run ``npm run build`` and fix ALL errors before completing**
5. Run ``npm run test:ci`` if tests exist
6. Commit your work with clear, descriptive commit messages
7. When done, make a final commit with message: "Task complete: <brief summary>"

## Quality Gates

- Build MUST pass before marking complete
- No TypeScript errors
- No unhandled console errors

## Branch

Working on: $Branch
"@ | Set-Content -Path $PromptFile -Encoding UTF8

# Path to wrapper script
$RunAgentScript = Join-Path $env:USERPROFILE '.claude\scripts\Run-Agent.ps1'
$KeepOpenFlag = if ($KeepOpen) { '-KeepOpen' } else { '' }

# Launch agent(s)
Write-Host ""
Write-Host "Launching $NumAgents agent(s)..."
Write-Host ""

foreach ($i in 1..$NumAgents) {
    $agentSuffix = if ($NumAgents -gt 1) { " (Agent $i)" } else { '' }
    $title = "Claude: ${Branch}${agentSuffix}"

    # Launch in new Windows Terminal tab
    wt new-tab --title $title -d $WorktreePath cmd /c "pwsh -NoProfile -File `"$RunAgentScript`" `"$WorktreePath`" `"$Branch`" $KeepOpenFlag"

    if ($NumAgents -gt 1) {
        Start-Sleep -Seconds 1  # Stagger launches
    }
}

Write-Host "Branch: $Branch"
Write-Host "Worktree: $WorktreePath"
Write-Host "Task file: $PromptFile"
Write-Host ""
Write-Host "Agent(s) launched! Use:"
Write-Host "  /status              - Check progress"
Write-Host "  /merge $Branch   - Merge when complete"
