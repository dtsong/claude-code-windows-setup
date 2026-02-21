# Activity Summary Script
# Shows recent repository activity

param(
    [string]$Since = "1 day ago"
)

$ErrorActionPreference = 'Stop'

Write-Host "Repository Activity"
Write-Host "==================="
Write-Host "Period: Since $Since"
Write-Host ""

# Get date in ISO format for gh queries
$SinceDate = (Get-Date).AddDays(-1).ToString("yyyy-MM-ddTHH:mm:ssZ")

# Recent commits
Write-Host "Recent Commits" -ForegroundColor Blue
$RecentCommits = git log --since="$Since" --oneline 2>$null
$CommitCount = 0
if ($RecentCommits) {
    if ($RecentCommits -is [array]) { $CommitCount = $RecentCommits.Count }
    else { $CommitCount = 1 }
}
Write-Host "  Total: $CommitCount"
if ($CommitCount -gt 0) {
    Write-Host "  Latest:"
    $LatestCommits = git log --since="$Since" --format="    %h %s (%an)" 2>$null
    if ($LatestCommits) {
        if ($LatestCommits -is [string]) { $LatestCommits = @($LatestCommits) }
        $LatestCommits | Select-Object -First 5 | ForEach-Object { Write-Host $_ }
    }
}
Write-Host ""

# Check if gh is available and authenticated
$ghAvailable = $false
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh auth status 2>$null
    if ($LASTEXITCODE -eq 0) {
        $ghAvailable = $true
    }
}

if ($ghAvailable) {
    # Merged PRs
    Write-Host "Merged Pull Requests" -ForegroundColor Blue
    $MergedJson = gh pr list --state merged --json number,title,mergedAt,author 2>$null
    $MergedPRs = @()
    if ($MergedJson) {
        $AllMerged = $MergedJson | ConvertFrom-Json
        $MergedPRs = @($AllMerged | Where-Object { $_.mergedAt -gt $SinceDate })
    }
    Write-Host "  Total: $($MergedPRs.Count)"
    if ($MergedPRs.Count -gt 0) {
        $MergedPRs | Select-Object -First 5 | ForEach-Object {
            Write-Host "  #$($_.number) $($_.title) (@$($_.author.login))"
        }
    }
    Write-Host ""

    # Opened issues
    Write-Host "New Issues" -ForegroundColor Blue
    $IssuesJson = gh issue list --state all --json number,title,createdAt 2>$null
    $NewIssues = @()
    if ($IssuesJson) {
        $AllIssues = $IssuesJson | ConvertFrom-Json
        $NewIssues = @($AllIssues | Where-Object { $_.createdAt -gt $SinceDate })
    }
    Write-Host "  Total: $($NewIssues.Count)"
    if ($NewIssues.Count -gt 0) {
        $NewIssues | Select-Object -First 5 | ForEach-Object {
            Write-Host "  #$($_.number) $($_.title)"
        }
    }
    Write-Host ""
}
else {
    Write-Host "(GitHub CLI not available - showing git data only)"
}

# Contributors
Write-Host "Active Contributors" -ForegroundColor Blue
$Authors = git log --since="$Since" --format='%an' 2>$null
if ($Authors) {
    if ($Authors -is [string]) { $Authors = @($Authors) }
    $Authors | Group-Object | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count) commits"
    }
}
