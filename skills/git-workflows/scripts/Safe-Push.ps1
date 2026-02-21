# Safe Push Script
# Performs pre-push checks before pushing

param(
    [switch]$Force,
    [switch]$SetUpstream
)

$ErrorActionPreference = 'Stop'

$ForceFlag = ""
if ($Force) {
    $ForceFlag = "--force-with-lease"
}

# Check if we're in a git repo
$inRepo = git rev-parse --is-inside-work-tree 2>$null
if (-not $inRepo) {
    Write-Host "Not a git repository" -ForegroundColor Red
    exit 1
}

$Branch = git branch --show-current

Write-Host "Pre-push checks for $Branch"
Write-Host "=========================="
Write-Host ""

# Check 1: Protected branches
if ($Branch -eq "main" -or $Branch -eq "master") {
    Write-Host "Warning: Pushing to protected branch '$Branch'" -ForegroundColor Yellow
    if ($ForceFlag) {
        Write-Host "Force push to $Branch is not allowed" -ForegroundColor Red
        exit 1
    }
}

# Check 2: Uncommitted changes
git diff --quiet 2>$null
$hasDiff = $LASTEXITCODE -ne 0
git diff --cached --quiet 2>$null
$hasCachedDiff = $LASTEXITCODE -ne 0

if ($hasDiff -or $hasCachedDiff) {
    Write-Host "Warning: You have uncommitted changes" -ForegroundColor Yellow
    git status --short
    Write-Host ""
}

# Check 3: Check upstream
$Upstream = git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null
$PushCmd = ""

if (-not $Upstream) {
    Write-Host "No upstream tracking branch" -ForegroundColor Yellow
    if ($SetUpstream) {
        Write-Host "Will set upstream to origin/$Branch"
        $PushCmd = "set-upstream"
    }
    else {
        Write-Host "Use -SetUpstream flag to set upstream, or run:"
        Write-Host "  git push -u origin $Branch"
        exit 1
    }
}
else {
    Write-Host "Tracking: " -ForegroundColor Green -NoNewline
    Write-Host $Upstream

    # Fetch to check for remote changes
    Write-Host "Fetching remote..."
    git fetch --quiet

    # Check if we're behind
    $Behind = git rev-list --count "HEAD..@{u}" 2>$null
    if (-not $Behind) { $Behind = "0" }
    $Behind = [int]$Behind

    if ($Behind -gt 0) {
        Write-Host "Remote has $Behind commits not in local" -ForegroundColor Red
        if (-not $ForceFlag) {
            Write-Host "Pull first or use -Force flag"
            exit 1
        }
        else {
            Write-Host "Force push will overwrite these commits" -ForegroundColor Yellow
        }
    }

    $PushCmd = "normal"
}

# Check 4: Commits to push
$Ahead = git rev-list --count "@{u}..HEAD" 2>$null
if (-not $Ahead) {
    $Ahead = git rev-list --count HEAD 2>$null
}
if (-not $Ahead) { $Ahead = "0" }
$Ahead = [int]$Ahead

if ($Ahead -eq 0) {
    Write-Host "No commits to push" -ForegroundColor Green
    exit 0
}

Write-Host "Commits to push: $Ahead" -ForegroundColor Cyan
$logOutput = git log --oneline "@{u}..HEAD" 2>$null
if (-not $logOutput) {
    $logOutput = git log --oneline -$Ahead
}
$logOutput | ForEach-Object { Write-Host $_ }

Write-Host ""
Write-Host "All checks passed. Pushing..." -ForegroundColor Green
Write-Host ""

# Execute push
if ($PushCmd -eq "set-upstream") {
    git push -u origin $Branch
}
elseif ($ForceFlag) {
    git push $ForceFlag
}
else {
    git push
}

Write-Host ""
Write-Host "Push successful!" -ForegroundColor Green
