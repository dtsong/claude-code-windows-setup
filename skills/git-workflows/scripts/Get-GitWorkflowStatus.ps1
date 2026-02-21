# Git Workflow Status Script
# Shows comprehensive status for git workflows

$ErrorActionPreference = 'Stop'

# Check if we're in a git repo
$inRepo = git rev-parse --is-inside-work-tree 2>$null
if (-not $inRepo) {
    Write-Host "Not a git repository" -ForegroundColor Red
    exit 1
}

Write-Host "Git Workflow Status"
Write-Host "==================="
Write-Host ""

# Current branch
$CurrentBranch = git branch --show-current
Write-Host "Current branch: " -ForegroundColor Blue -NoNewline
Write-Host $CurrentBranch

# Check for uncommitted changes
git diff --quiet 2>$null
$hasDiff = $LASTEXITCODE -ne 0
git diff --cached --quiet 2>$null
$hasCachedDiff = $LASTEXITCODE -ne 0

if ($hasDiff -or $hasCachedDiff) {
    Write-Host "Uncommitted changes:" -ForegroundColor Yellow
    git status --short
    Write-Host ""
}

# Check for untracked files
$UntrackedFiles = git ls-files --others --exclude-standard
$UntrackedCount = 0
if ($UntrackedFiles) {
    if ($UntrackedFiles -is [array]) {
        $UntrackedCount = $UntrackedFiles.Count
    }
    else {
        $UntrackedCount = 1
    }
}
if ($UntrackedCount -gt 0) {
    Write-Host "Untracked files: $UntrackedCount" -ForegroundColor Yellow
}

# Check upstream status
$Upstream = git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null
if ($Upstream) {
    Write-Host "Tracking: " -ForegroundColor Blue -NoNewline
    Write-Host $Upstream

    # Fetch to get accurate counts
    git fetch --quiet 2>$null

    $Ahead = git rev-list --count "@{u}..HEAD" 2>$null
    if (-not $Ahead) { $Ahead = "0" }
    $Behind = git rev-list --count "HEAD..@{u}" 2>$null
    if (-not $Behind) { $Behind = "0" }
    $Ahead = [int]$Ahead
    $Behind = [int]$Behind

    if ($Ahead -gt 0) {
        Write-Host "Ahead: $Ahead commits" -ForegroundColor Green
    }
    if ($Behind -gt 0) {
        Write-Host "Behind: $Behind commits" -ForegroundColor Yellow
    }
    if ($Ahead -eq 0 -and $Behind -eq 0) {
        Write-Host "Up to date" -ForegroundColor Green
    }
}
else {
    Write-Host "No upstream tracking branch" -ForegroundColor Yellow
}

Write-Host ""

# Check for in-progress operations
$GitDir = git rev-parse --git-dir 2>$null
if ($GitDir) {
    if ((Test-Path "$GitDir/rebase-merge") -or (Test-Path "$GitDir/rebase-apply")) {
        Write-Host "Rebase in progress" -ForegroundColor Red
        Write-Host "  Run: git rebase --continue, --skip, or --abort"
    }

    if (Test-Path "$GitDir/MERGE_HEAD") {
        Write-Host "Merge in progress" -ForegroundColor Red
        Write-Host "  Run: git merge --continue or --abort"
    }

    if (Test-Path "$GitDir/CHERRY_PICK_HEAD") {
        Write-Host "Cherry-pick in progress" -ForegroundColor Red
        Write-Host "  Run: git cherry-pick --continue or --abort"
    }
}

# Check stash
$StashList = git stash list 2>$null
$StashCount = 0
if ($StashList) {
    if ($StashList -is [array]) {
        $StashCount = $StashList.Count
    }
    else {
        $StashCount = 1
    }
}
if ($StashCount -gt 0) {
    Write-Host "Stashes: $StashCount" -ForegroundColor Blue
}

Write-Host ""

# Show recent commits
Write-Host "Recent commits:" -ForegroundColor Blue
git log --oneline -5

Write-Host ""
Write-Host "Quick actions:"
Write-Host "  /git-sync    - Fetch remote changes"
Write-Host "  /git-pull    - Pull changes"
Write-Host "  /git-push    - Push commits"
Write-Host "  /git-stash   - Manage stashes"
