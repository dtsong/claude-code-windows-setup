#===============================================================================
# Pre-Compact Handover Hook
# Auto-save session context before compaction.
# Fires on PreCompact hook to preserve decisions and context.
#
# Requires: claude CLI in PATH (uses `claude -p` for summarization;
#           falls back to a minimal template if unavailable)
#===============================================================================

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Read JSON from stdin
$rawInput = [Console]::In.ReadToEnd()
if (-not $rawInput) {
    exit 0
}

$inputObj = $rawInput | ConvertFrom-Json

$transcriptPath = $inputObj.transcript_path
$cwd = $inputObj.cwd
$trigger = $inputObj.trigger

# Only fire on auto-compaction, not manual /compact
if ($trigger -ne 'auto') {
    exit 0
}

# Validate transcript exists
if (-not $transcriptPath -or -not (Test-Path $transcriptPath -PathType Leaf)) {
    exit 0
}

# Determine workspace root
$workspace = $cwd
try {
    $gitRoot = & git -C $cwd rev-parse --show-toplevel 2>$null
    if ($gitRoot) {
        $workspace = $gitRoot
    }
} catch { }

# Build output path
$timestamp = Get-Date -Format 'yyyy-MM-dd-HHmm'
$outDir = Join-Path $workspace 'memory'
$outFile = Join-Path $outDir "HANDOVER-${timestamp}-auto.md"

# Debounce: skip if file already exists for this minute
if (Test-Path $outFile) {
    exit 0
}

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# Gather session context
$branch = 'unknown'
try {
    $branchResult = & git -C $workspace branch --show-current 2>$null
    if ($branchResult) { $branch = $branchResult }
} catch { }

$recentCommits = 'none'
try {
    $commitsResult = & git -C $workspace log --oneline -5 2>$null
    if ($commitsResult) { $recentCommits = $commitsResult -join "`n" }
} catch { }

# Extract last 500 lines of transcript (most recent context)
$transcriptTail = Get-Content -Path $transcriptPath -Tail 500 -ErrorAction SilentlyContinue
$transcriptText = $transcriptTail -join "`n"

# Build the summarization prompt
$dateStr = Get-Date -Format 'yyyy-MM-dd'
$prompt = @"
You are summarizing a Claude Code session transcript for handover to a future session. The transcript is JSONL format piped via stdin.

Write a concise handover document in markdown. Include these sections:

# Auto-Handover -- $dateStr
## Session Summary (2-3 sentences)
## What Was Done (bulleted changes)
## Key Decisions Made (with rationale -- most important section)
## Pitfalls & Gotchas (errors, dead ends)
## Open Questions (unresolved items)
## Next Steps (ordered priority)

Context:
- Branch: $branch
- Recent commits: $recentCommits

Rules:
- Target 40-80 lines
- Focus on DECISIONS and RATIONALE, not just actions
- If the session was trivial, say so briefly
- Do NOT include the raw transcript -- only your synthesis
"@

# Use claude -p with sonnet to summarize the session
$summary = $null
try {
    $summary = $transcriptText | & claude -p --model sonnet $prompt 2>$null
    if ($summary -is [array]) {
        $summary = $summary -join "`n"
    }
} catch { }

# If claude -p failed or returned empty, create a minimal fallback
if (-not $summary) {
    $summary = @"
# Auto-Handover -- $timestamp

## Session Summary
Auto-compaction triggered but summary generation failed. Check transcript for details.

## Session Context
- **Branch**: $branch
- **Transcript**: $transcriptPath
- **Recent commits**:
$recentCommits
"@
}

# Write the handover file
$summary | Out-File -FilePath $outFile -Encoding UTF8

# Report to user via stderr
[Console]::Error.WriteLine("Auto-handover saved: memory/HANDOVER-${timestamp}-auto.md")

exit 0
