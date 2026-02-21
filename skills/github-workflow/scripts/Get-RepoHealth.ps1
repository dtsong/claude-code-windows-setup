# Repository Health Check Script
# Generates a health report for the repository

$ErrorActionPreference = 'Stop'

# Check if gh is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "GitHub CLI (gh) is required" -ForegroundColor Red
    exit 1
}

# Check if authenticated
gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not authenticated with GitHub CLI" -ForegroundColor Red
    Write-Host "Run: gh auth login"
    exit 1
}

Write-Host "Repository Health Report"
Write-Host "========================"
Write-Host ""

# Get repo info
$Repo = gh repo view --json nameWithOwner -q '.nameWithOwner'
Write-Host "Repository: " -ForegroundColor Blue -NoNewline
Write-Host $Repo
Write-Host ""

# Issues stats
Write-Host "Issues" -ForegroundColor Blue
$OpenIssuesJson = gh issue list --state open --json number
$OpenIssues = ($OpenIssuesJson | ConvertFrom-Json).Count
$ClosedIssuesJson = gh issue list --state closed --limit 100 --json number
$ClosedIssues = ($ClosedIssuesJson | ConvertFrom-Json).Count
Write-Host "  Open: $OpenIssues"
Write-Host "  Recently closed: $ClosedIssues"

# Unlabeled issues
$UnlabeledJson = gh issue list --state open --label "" --json number
$Unlabeled = ($UnlabeledJson | ConvertFrom-Json).Count
if ($Unlabeled -gt 0) {
    Write-Host "  Unlabeled: $Unlabeled" -ForegroundColor Yellow
}

Write-Host ""

# PR stats
Write-Host "Pull Requests" -ForegroundColor Blue
$OpenPRsJson = gh pr list --state open --json number
$OpenPRs = ($OpenPRsJson | ConvertFrom-Json).Count
$MergedPRsJson = gh pr list --state merged --limit 100 --json number
$MergedPRs = ($MergedPRsJson | ConvertFrom-Json).Count
Write-Host "  Open: $OpenPRs"
Write-Host "  Recently merged: $MergedPRs"

# PRs needing attention
$NeedsReview = 0
try {
    $ReviewJson = gh pr list --search "review:required" --json number
    $NeedsReview = ($ReviewJson | ConvertFrom-Json).Count
}
catch {
    $NeedsReview = 0
}
if ($NeedsReview -gt 0) {
    Write-Host "  Needs review: $NeedsReview" -ForegroundColor Yellow
}

Write-Host ""

# Branch stats
Write-Host "Branches" -ForegroundColor Blue
$LocalBranches = git branch
$LocalCount = 0
if ($LocalBranches) {
    if ($LocalBranches -is [array]) { $LocalCount = $LocalBranches.Count }
    else { $LocalCount = 1 }
}
$RemoteBranches = git branch -r
$RemoteCount = 0
if ($RemoteBranches) {
    if ($RemoteBranches -is [array]) { $RemoteCount = $RemoteBranches.Count }
    else { $RemoteCount = 1 }
}
Write-Host "  Local: $LocalCount"
Write-Host "  Remote: $RemoteCount"

# Stale branches
Write-Host "  Oldest branches:"
$StaleBranches = git for-each-ref --sort=committerdate --format='%(refname:short) %(committerdate:relative)' refs/heads/
if ($StaleBranches) {
    if ($StaleBranches -is [string]) { $StaleBranches = @($StaleBranches) }
    $StaleBranches | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" }
}

Write-Host ""

# Recent activity
Write-Host "Recent Activity (7 days)" -ForegroundColor Blue
$WeekAgo = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
$RecentCommits = git log --since="$WeekAgo" --oneline 2>$null
$CommitCount = 0
if ($RecentCommits) {
    if ($RecentCommits -is [array]) { $CommitCount = $RecentCommits.Count }
    else { $CommitCount = 1 }
}
Write-Host "  Commits: $CommitCount"

# Contributors this week
Write-Host "  Top contributors:"
$WeekAuthors = git log --since="$WeekAgo" --format='%an' 2>$null
if ($WeekAuthors) {
    if ($WeekAuthors -is [string]) { $WeekAuthors = @($WeekAuthors) }
    $WeekAuthors | Group-Object | Sort-Object Count -Descending | Select-Object -First 3 | ForEach-Object {
        Write-Host "    $($_.Count) $($_.Name)"
    }
}

Write-Host ""

# Health score calculation
$Score = 100

if ($Unlabeled -gt 5) {
    $Score = $Score - 10
}
if ($OpenIssues -gt 50) {
    $Score = $Score - 10
}
if ($OpenPRs -gt 10) {
    $Score = $Score - 5
}

Write-Host "Health Score: " -ForegroundColor Blue -NoNewline
Write-Host "$Score/100"

if ($Score -ge 90) {
    Write-Host "Excellent! Repository is well maintained." -ForegroundColor Green
}
elseif ($Score -ge 70) {
    Write-Host "Good, but some items need attention." -ForegroundColor Yellow
}
else {
    Write-Host "Needs attention. Consider triaging issues and PRs." -ForegroundColor Red
}
