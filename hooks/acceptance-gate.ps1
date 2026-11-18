#===============================================================================
# Acceptance Gate Hook (PreToolUse)
# Blocks task completion when acceptance criteria are unverified.
#
# Fires on: PreToolUse / TaskUpdate (to completed)
# Reads: acceptance-contract.md from active session or .claude/prd/
# Exits: 0 = allow, 2 = block (deny the tool; stderr reason is fed to Claude).
#        PreToolUse + exit 2 prevents the TaskUpdate from running; any other
#        non-zero is a non-blocking error, so the block message MUST go to
#        stderr with exit 2 -- never stdout with exit 1.
#===============================================================================

$ErrorActionPreference = 'Stop'

# Read and parse hook input from stdin (JSON with tool_name, tool_input, etc.)
$rawInput = [Console]::In.ReadToEnd()
if (-not $rawInput) {
    exit 0
}

try {
    $inputObj = $rawInput | ConvertFrom-Json
} catch {
    exit 0
}

$toolName = $inputObj.tool_name
$toolInput = $inputObj.tool_input

# Only gate on TaskUpdate -> completed
if ($toolName -ne 'TaskUpdate') {
    exit 0
}

$status = $null
if ($toolInput) {
    $status = $toolInput.status
}
if ($status -ne 'completed') {
    exit 0
}

# Find workspace root
$workspace = $PWD.Path
try {
    $gitRoot = & git rev-parse --show-toplevel 2>$null
    if ($gitRoot) { $workspace = $gitRoot }
} catch { }

# Sessions older than this (no contract activity) are treated as abandoned and
# not enforced -- a stale session must never block a newer one. Override via env.
$staleHours = 72
if ($env:ACCEPTANCE_GATE_STALE_HOURS -and ($env:ACCEPTANCE_GATE_STALE_HOURS -as [int])) {
    $staleHours = [int]$env:ACCEPTANCE_GATE_STALE_HOURS
}

# Gather every candidate contract across known locations.
$claudeDir = Join-Path $workspace '.claude'
$candidates = @()
foreach ($sessionsRoot in @('council', 'academy')) {
    $sessionsPath = Join-Path $claudeDir $sessionsRoot 'sessions'
    if (Test-Path $sessionsPath) {
        $candidates += Get-ChildItem -Path $sessionsPath -Directory |
            ForEach-Object { Join-Path $_.FullName 'acceptance-contract.md' } |
            Where-Object { Test-Path $_ -PathType Leaf } |
            ForEach-Object { Get-Item $_ }
    }
}
$prdPath = Join-Path $claudeDir 'prd'
if (Test-Path $prdPath) {
    $candidates += Get-ChildItem -Path $prdPath -Filter 'contract-*.md' -File
}
$rootContract = Join-Path $claudeDir 'acceptance-contract.md'
if (Test-Path $rootContract -PathType Leaf) {
    $candidates += Get-Item $rootContract
}

# No contract found -- nothing to enforce
if ($candidates.Count -eq 0) {
    exit 0
}

# Enforce the MOST RECENTLY MODIFIED contract (the active session). Selecting by
# mtime -- not directory/alphabetical order -- is what stops a dead session from
# blocking live work in the same repo.
$newest = $candidates | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
$contract = $newest.FullName

# Staleness guard: an active contract not touched within $staleHours is treated
# as an abandoned session and does not block.
$ageHours = ((Get-Date).ToUniversalTime() - $newest.LastWriteTimeUtc).TotalHours
if ($ageHours -ge $staleHours) {
    exit 0
}

# Parse contract for unverified criteria. -SimpleMatch takes the pattern
# literally, so it must not contain regex escapes.
$pending = @(Select-String -Path $contract -Pattern '| pending |' -SimpleMatch -ErrorAction SilentlyContinue).Count
$failed = @(Select-String -Path $contract -Pattern '| failed |' -SimpleMatch -ErrorAction SilentlyContinue).Count
$pendingManual = @(Select-String -Path $contract -Pattern '| pending-manual |' -SimpleMatch -ErrorAction SilentlyContinue).Count
$verified = @(Select-String -Path $contract -Pattern '| verified |' -SimpleMatch -ErrorAction SilentlyContinue).Count

$unverified = $pending + $failed

if ($unverified -gt 0) {
    $total = $verified + $pending + $failed + $pendingManual

    # Block message goes to stderr: PreToolUse + exit 2 denies the tool and
    # surfaces stderr to Claude. stdout here would be ignored by the harness.
    $msg = [System.Collections.Generic.List[string]]::new()
    $msg.Add("BLOCKED: Acceptance contract has unverified criteria.")
    $msg.Add("")
    $msg.Add("  Contract: $contract")
    $msg.Add("  Verified: $verified/$total")
    $msg.Add("  Pending:  $pending")
    $msg.Add("  Failed:   $failed")
    if ($pendingManual -gt 0) {
        $msg.Add("  Manual:   $pendingManual (allowed)")
    }
    $msg.Add("")
    $msg.Add("Unverified criteria:")

    $lines = Select-String -Path $contract -Pattern '\| (pending|failed) \|' -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        $parts = $line.Line -split '\|'
        if ($parts.Count -ge 5) {
            $id = $parts[1].Trim()
            $criterion = $parts[2].Trim()
            $statusVal = $parts[4].Trim()
            $msg.Add("  - ${id}: $criterion [$statusVal]")
        }
    }

    $msg.Add("")
    $msg.Add("Resolve all criteria before marking work as complete.")
    [Console]::Error.WriteLine(($msg -join [Environment]::NewLine))
    exit 2
}

# All criteria verified (or pending-manual) -- allow completion
exit 0
