#Requires -Version 5.1
<#
.SYNOPSIS
    Launch multi-agent Claude Code workspace
.DESCRIPTION
    Launches a planner agent and multiple feature agents in Windows Terminal tabs.
.PARAMETER Workspace
    Path to the workspace directory. If not provided, extracts from task-board.md
.PARAMETER PlannerOnly
    Only launch the planner agent
.PARAMETER FeatureCount
    Number of feature agents to launch (default: 3)
.PARAMETER PlannerTask
    Task ID for planner to claim (default: plan-001)
.EXAMPLE
    .\Launch-Workspace.ps1 -Workspace "C:\Projects\my-app"
    .\Launch-Workspace.ps1 -PlannerOnly -PlannerTask "plan-002"
#>
param(
    [string]$Workspace,
    [switch]$PlannerOnly,
    [int]$FeatureCount = 3,
    [string]$PlannerTask = 'plan-001'
)

$ErrorActionPreference = 'Stop'

$SharedDir = Join-Path $env:USERPROFILE '.claude\agent-context\shared'
$BoardFile = Join-Path $SharedDir 'task-board.md'
$ContextFile = Join-Path $SharedDir 'AGENT_CONTEXT.md'

function Write-Info { param($Msg) Write-Host "[INFO] $Msg" -ForegroundColor Green }
function Write-Warn { param($Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Err { param($Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Get-WorkspaceFromBoard {
    if (Test-Path $BoardFile) {
        $content = Get-Content $BoardFile -Raw
        if ($content -match 'project_path:\s*"([^"]+)"') {
            return $Matches[1]
        }
    }
    return $null
}

function Get-AvailableTasks {
    if (-not (Test-Path $BoardFile)) { return @() }

    $content = Get-Content $BoardFile -Raw
    $tasks = @()
    $currentId = $null
    $currentPriority = 'medium'

    foreach ($line in (Get-Content $BoardFile)) {
        if ($line -match '^\s+-\s+id:\s*"([^"]+)"') {
            $currentId = $Matches[1]
        }
        if ($line -match 'priority:\s*(\w+)') {
            $currentPriority = $Matches[1]
        }
        if ($line -match 'status:\s*available' -and $currentId) {
            $prioNum = switch ($currentPriority) {
                'high'   { 1 }
                'medium' { 2 }
                default  { 3 }
            }
            $tasks += [PSCustomObject]@{ Priority = $prioNum; Id = $currentId }
            $currentId = $null
        }
    }

    return ($tasks | Sort-Object Priority | ForEach-Object { $_.Id })
}

# Main
Write-Info "Multi-Agent Workspace Launcher"
Write-Host ""

# Get workspace
if (-not $Workspace) {
    $Workspace = Get-WorkspaceFromBoard
    if (-not $Workspace) {
        Write-Err "No workspace provided and couldn't extract from task board"
        Write-Err "Usage: Launch-Workspace.ps1 -Workspace <path>"
        exit 1
    }
    Write-Info "Using workspace from task board: $Workspace"
}

# Validate workspace
if (-not (Test-Path $Workspace -PathType Container)) {
    Write-Err "Workspace does not exist: $Workspace"
    exit 1
}

# Get available tasks
$availableTasks = Get-AvailableTasks

# Show config
Write-Host ""
Write-Info "Launch Configuration:"
Write-Host "  Workspace: $Workspace"
Write-Host "  Planner Task: $PlannerTask"
if ($PlannerOnly) {
    Write-Host "  Mode: Planner Only"
}
else {
    Write-Host "  Feature Agents: $FeatureCount"
    Write-Host "  Available Tasks: $(if ($availableTasks) { $availableTasks -join ', ' } else { 'none' })"
}
Write-Host ""

# Planner prompt
$plannerPrompt = @"
You are the PLANNER AGENT for this multi-agent workspace. STARTUP SEQUENCE: 1. Read the shared context: cat ~/.claude/agent-context/shared/AGENT_CONTEXT.md 2. Read the project context: cat ${Workspace}/CLAUDE.md 3. View task board: /task-board 4. Claim your task: /claim-task ${PlannerTask} YOUR ROLE: Macro planning, architecture decisions, break down features into subtasks for the feature agents.
"@

Write-Info "Launching agents..."

# Launch Planner in Windows Terminal
wt new-tab --title "Claude: Planner" -d $Workspace cmd /c "pwsh -NoProfile -Command `"claude --dangerously-skip-permissions '$($plannerPrompt -replace "'","''")'`""

if (-not $PlannerOnly) {
    Start-Sleep -Seconds 1

    # Launch Feature Agents
    foreach ($i in 1..$FeatureCount) {
        $taskId = if ($i -le $availableTasks.Count) { $availableTasks[$i - 1] } else { $null }
        $claimCmd = if ($taskId) { "/claim-task $taskId" } else { "/task-board  -- then claim an available task" }

        $featurePrompt = @"
You are FEATURE AGENT #${i} for this multi-agent workspace. STARTUP SEQUENCE: 1. Read shared context: cat ~/.claude/agent-context/shared/AGENT_CONTEXT.md 2. View task board: /task-board 3. Claim task: ${claimCmd} YOUR ROLE: Implement your claimed task following existing patterns. Run /complete-task when done.
"@

        wt new-tab --title "Claude: Feature $i" -d $Workspace cmd /c "pwsh -NoProfile -Command `"claude --dangerously-skip-permissions '$($featurePrompt -replace "'","''")'`""
        Start-Sleep -Seconds 1
    }
}

Write-Host ""
Write-Info "Launch complete!"
Write-Host ""
Write-Host "Windows opened:"
Write-Host "  - Tab: Planner Agent (claiming $PlannerTask)"
if (-not $PlannerOnly) {
    Write-Host "  - Tabs: Feature Agents ($FeatureCount tabs)"
}
Write-Host ""
Write-Host "Give agents ~10 seconds to initialize, then they'll start working."
