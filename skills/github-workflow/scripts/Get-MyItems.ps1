# My Items Script
# Shows GitHub items assigned to or involving the current user

$ErrorActionPreference = 'Stop'

# Check if gh is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "GitHub CLI (gh) is required" -ForegroundColor Red
    exit 1
}

# Get current user
$User = gh api user --jq '.login'
Write-Host "My GitHub Items (@$User)"
Write-Host "========================="
Write-Host ""

# Assigned issues
Write-Host "Assigned Issues" -ForegroundColor Blue
$IssuesJson = gh issue list --assignee @me --state open --json number,title,labels,createdAt
$Issues = @()
if ($IssuesJson) {
    $Issues = @($IssuesJson | ConvertFrom-Json)
}
$IssueCount = $Issues.Count

if ($IssueCount -eq 0) {
    Write-Host "  No issues assigned"
}
else {
    $Issues | Select-Object -First 10 | ForEach-Object {
        Write-Host "  #$($_.number) $($_.title)"
    }
    if ($IssueCount -gt 10) {
        $Remaining = $IssueCount - 10
        Write-Host "  ... and $Remaining more"
    }
}
Write-Host ""

# My PRs
Write-Host "My Pull Requests" -ForegroundColor Blue
$PRsJson = gh pr list --author @me --state open --json number,title,reviewDecision,statusCheckRollup
$PRs = @()
if ($PRsJson) {
    $PRs = @($PRsJson | ConvertFrom-Json)
}
$PRCount = $PRs.Count

if ($PRCount -eq 0) {
    Write-Host "  No open PRs"
}
else {
    $PRs | Select-Object -First 10 | ForEach-Object {
        $decision = $_.reviewDecision
        if (-not $decision) { $decision = "pending" }
        Write-Host "  #$($_.number) $($_.title) [$decision]"
    }
}
Write-Host ""

# Reviews requested
Write-Host "Reviews Requested" -ForegroundColor Blue
$Reviews = @()
try {
    $ReviewsJson = gh pr list --search "review-requested:@me" --json number,title,author
    if ($ReviewsJson) {
        $Reviews = @($ReviewsJson | ConvertFrom-Json)
    }
}
catch {
    $Reviews = @()
}
$ReviewCount = $Reviews.Count

if ($ReviewCount -eq 0) {
    Write-Host "  No reviews requested"
}
else {
    $Reviews | Select-Object -First 10 | ForEach-Object {
        Write-Host "  #$($_.number) $($_.title) by @$($_.author.login)"
    }
}
Write-Host ""

# Summary
Write-Host "Summary" -ForegroundColor Blue
Write-Host "  Issues assigned: $IssueCount"
Write-Host "  PRs authored: $PRCount"
Write-Host "  Reviews pending: $ReviewCount"
