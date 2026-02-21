#===============================================================================
# Acceptance Gate Hook (PostToolUse)
# Blocks task completion when acceptance criteria are unverified.
#
# Fires on: TaskUpdate (to completed)
# Reads: acceptance-contract.md from active session or .claude/prd/
# Exits: 0 = allow, non-zero = block
#===============================================================================

$ErrorActionPreference = 'Stop'

# Read and parse hook input from stdin (JSON with tool_name, tool_input, etc.)
$rawInput = [Console]::In.ReadToEnd()
if (-not $rawInput) {
    exit 0
}

$inputObj = $rawInput | ConvertFrom-Json

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

# Find the active acceptance contract
$contract = $null

# Check active council sessions
$councilPath = Join-Path $workspace '.claude' 'council' 'sessions'
if (Test-Path $councilPath) {
    $sessionDirs = Get-ChildItem -Path $councilPath -Directory
    foreach ($dir in $sessionDirs) {
        $candidate = Join-Path $dir.FullName 'acceptance-contract.md'
        if (Test-Path $candidate -PathType Leaf) {
            $contract = $candidate
        }
    }
}

# Check active academy sessions
if (-not $contract) {
    $academyPath = Join-Path $workspace '.claude' 'academy' 'sessions'
    if (Test-Path $academyPath) {
        $sessionDirs = Get-ChildItem -Path $academyPath -Directory
        foreach ($dir in $sessionDirs) {
            $candidate = Join-Path $dir.FullName 'acceptance-contract.md'
            if (Test-Path $candidate -PathType Leaf) {
                $contract = $candidate
            }
        }
    }
}

# Check .claude/prd/ contracts
if (-not $contract) {
    $prdPath = Join-Path $workspace '.claude' 'prd'
    if (Test-Path $prdPath) {
        $prdFiles = Get-ChildItem -Path $prdPath -Filter 'contract-*.md' -File
        if ($prdFiles) {
            $contract = $prdFiles[0].FullName
        }
    }
}

# Check root .claude/ contract
if (-not $contract) {
    $rootContract = Join-Path $workspace '.claude' 'acceptance-contract.md'
    if (Test-Path $rootContract -PathType Leaf) {
        $contract = $rootContract
    }
}

# No contract found -- nothing to enforce
if (-not $contract) {
    exit 0
}

# Parse contract for unverified criteria using Select-String
$pending = @(Select-String -Path $contract -Pattern '\| pending \|' -SimpleMatch -ErrorAction SilentlyContinue).Count
$failed = @(Select-String -Path $contract -Pattern '\| failed \|' -SimpleMatch -ErrorAction SilentlyContinue).Count
$pendingManual = @(Select-String -Path $contract -Pattern '\| pending-manual \|' -SimpleMatch -ErrorAction SilentlyContinue).Count
$verified = @(Select-String -Path $contract -Pattern '\| verified \|' -SimpleMatch -ErrorAction SilentlyContinue).Count

$unverified = $pending + $failed

if ($unverified -gt 0) {
    $total = $verified + $pending + $failed + $pendingManual

    Write-Output "BLOCKED: Acceptance contract has unverified criteria."
    Write-Output ""
    Write-Output "  Contract: $contract"
    Write-Output "  Verified: $verified/$total"
    Write-Output "  Pending:  $pending"
    Write-Output "  Failed:   $failed"
    if ($pendingManual -gt 0) {
        Write-Output "  Manual:   $pendingManual (allowed)"
    }
    Write-Output ""
    Write-Output "Unverified criteria:"

    $lines = Select-String -Path $contract -Pattern '\| pending \||\| failed \|' -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        $parts = $line.Line -split '\|'
        if ($parts.Count -ge 5) {
            $id = $parts[1].Trim()
            $criterion = $parts[2].Trim()
            $statusVal = $parts[4].Trim()
            Write-Output "  - ${id}: $criterion [$statusVal]"
        }
    }

    Write-Output ""
    Write-Output "Resolve all criteria before marking work as complete."
    exit 1
}

# All criteria verified (or pending-manual) -- allow completion
exit 0
