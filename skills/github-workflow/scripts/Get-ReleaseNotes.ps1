# Release Notes Generator Script
# Generates changelog from merged PRs and commits

param(
    [string]$SinceTag = "",
    [string]$UntilTag = "HEAD"
)

$ErrorActionPreference = 'Stop'

if (-not $SinceTag) {
    $SinceTag = git describe --tags --abbrev=0 2>$null
}

if (-not $SinceTag) {
    Write-Host "No previous tag found. Generating notes for all commits."
    $SinceTag = git rev-list --max-parents=0 HEAD
}

Write-Host "Release Notes"
Write-Host "============="
Write-Host "From: $SinceTag"
Write-Host "To: $UntilTag"
Write-Host ""

# Count commits
$CommitCount = git rev-list --count "$SinceTag..$UntilTag"
Write-Host "Commits: $CommitCount"
Write-Host ""

# Categorize by conventional commit type
$Range = "$SinceTag..$UntilTag"
$AllMessages = git log $Range --format="%s" 2>$null
if (-not $AllMessages) { $AllMessages = @() }
if ($AllMessages -is [string]) { $AllMessages = @($AllMessages) }

Write-Host "## Features" -ForegroundColor Blue
$feats = $AllMessages | Where-Object { $_ -match "^feat(\(.*\))?:" }
if ($feats) {
    foreach ($msg in $feats) {
        $cleaned = $msg -replace "^feat(\(.*\))?: ", ""
        Write-Host "- $cleaned"
    }
}
else {
    Write-Host "None"
}
Write-Host ""

Write-Host "## Bug Fixes" -ForegroundColor Blue
$fixes = $AllMessages | Where-Object { $_ -match "^fix(\(.*\))?:" }
if ($fixes) {
    foreach ($msg in $fixes) {
        $cleaned = $msg -replace "^fix(\(.*\))?: ", ""
        Write-Host "- $cleaned"
    }
}
else {
    Write-Host "None"
}
Write-Host ""

Write-Host "## Documentation" -ForegroundColor Blue
$docs = $AllMessages | Where-Object { $_ -match "^docs(\(.*\))?:" }
if ($docs) {
    foreach ($msg in $docs) {
        $cleaned = $msg -replace "^docs(\(.*\))?: ", ""
        Write-Host "- $cleaned"
    }
}
else {
    Write-Host "None"
}
Write-Host ""

Write-Host "## Performance" -ForegroundColor Blue
$perfs = $AllMessages | Where-Object { $_ -match "^perf(\(.*\))?:" }
if ($perfs) {
    foreach ($msg in $perfs) {
        $cleaned = $msg -replace "^perf(\(.*\))?: ", ""
        Write-Host "- $cleaned"
    }
}
else {
    Write-Host "None"
}
Write-Host ""

Write-Host "## Other Changes" -ForegroundColor Blue
$others = $AllMessages | Where-Object { $_ -notmatch "^(feat|fix|docs|perf|refactor|test|chore)(\(.*\))?:" }
if ($others) {
    $others | Select-Object -First 10 | ForEach-Object { Write-Host "- $_" }
}
else {
    Write-Host "None"
}
Write-Host ""

# Contributors
Write-Host "## Contributors" -ForegroundColor Blue
$authors = git log $Range --format="%an" 2>$null
if ($authors) {
    if ($authors -is [string]) { $authors = @($authors) }
    $authors | Sort-Object -Unique | Select-Object -First 20 | ForEach-Object { Write-Host "- @$_" }
}
Write-Host ""

Write-Host "---"
Write-Host "Full diff: $SinceTag...$UntilTag"
