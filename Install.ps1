#Requires -Version 5.1
<#
.SYNOPSIS
    Install this repository into a user's Claude Code config.
.DESCRIPTION
    Default behavior is intentionally minimal and safe:
    - installs skills only
    - does NOT replace ~/.claude/settings.json, ~/.claude/hooks.json, or ~/.claude/CLAUDE.md unless explicitly requested
    - does NOT overwrite regular files/directories (conflict policy defaults to fail)
#>
[CmdletBinding()]
param(
    [ValidateSet('skills', 'core', 'full')]
    [string]$Preset = 'skills',

    [ValidateSet('fail', 'skip')]
    [string]$ConflictPolicy = 'fail',

    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$ListSkills,

    [string]$Skills = '',

    [switch]$WithSettings,
    [switch]$WithHooksJson,
    [switch]$WithHooksScripts,
    [switch]$WithClaudeMd
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$ManagedDir = Join-Path $ClaudeDir '.managed'
$ManifestPath = Join-Path $ManagedDir 'claude-code-windows-setup.json'
$script:ManifestCache = $null

# --- Symlink capability detection ---
$UseCopy = $false
try {
    $testTarget = Join-Path $env:TEMP 'claude_symlink_test_target.tmp'
    $testLink = Join-Path $env:TEMP 'claude_symlink_test_link.tmp'
    Set-Content -Path $testTarget -Value 'test' -Force
    # Remove stale test link if present
    if (Test-Path $testLink) { Remove-Item $testLink -Force }
    $null = New-Item -ItemType SymbolicLink -Path $testLink -Target $testTarget -ErrorAction Stop
    Remove-Item $testLink -Force
    Remove-Item $testTarget -Force
}
catch {
    $UseCopy = $true
    # Clean up on failure
    if (Test-Path $testTarget) { Remove-Item $testTarget -Force -ErrorAction SilentlyContinue }
    if (Test-Path $testLink) { Remove-Item $testLink -Force -ErrorAction SilentlyContinue }
}

# --- Helper functions ---

function Write-Die {
    param([string]$Message)
    Write-Error "Error: $Message"
    exit 1
}

function Test-ManagedLink {
    param(
        [string]$LinkPath,
        [string]$ExpectedTarget
    )

    if (-not (Test-Path $LinkPath)) { return $false }

    $item = Get-Item $LinkPath -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $false }
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        $resolved = $item.Target
        # On PS 5.1, .Target may be an array
        if ($resolved -is [array]) { $resolved = $resolved[0] }
        return ($resolved -eq $ExpectedTarget)
    }
    return $false
}

function Test-ManagedItem {
    param([string]$Path)
    if (-not (Test-Path $ManifestPath)) { return $false }
    if ($null -eq $script:ManifestCache) {
        try { $script:ManifestCache = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json }
        catch { $script:ManifestCache = $null; return $false }
    }
    if ($null -eq $script:ManifestCache -or $null -eq $script:ManifestCache.items) { return $false }
    foreach ($item in $script:ManifestCache.items) {
        if ($item.path -eq $Path) { return $true }
    }
    return $false
}

function Get-SkillPacks {
    $skillsDir = Join-Path $RepoDir 'skills'
    if (-not (Test-Path $skillsDir -PathType Container)) {
        Write-Die "Missing skills directory: $skillsDir"
    }

    $packs = @()
    foreach ($d in Get-ChildItem -Path $skillsDir -Directory) {
        if ($d.Name -eq 'skills') { continue }
        $packs += $d.Name
    }
    return $packs
}

function Show-SkillPacks {
    Write-Host 'Available skill packs'
    $packs = Get-SkillPacks
    if ($packs.Count -eq 0) {
        Write-Host '(none)'
    }
    else {
        foreach ($p in $packs) {
            Write-Host "- $p"
        }
    }
}

function Split-Csv {
    param([string]$Csv)
    $items = $Csv -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    return @($items)
}

function Get-LinksForPreset {
    param([string]$PresetName)

    $links = [System.Collections.ArrayList]::new()

    # Base directories
    $null = $links.Add("DIR::$ClaudeDir")
    $null = $links.Add("DIR::$(Join-Path $ClaudeDir 'skills')")

    switch ($PresetName) {
        'skills' { }
        'core' {
            $null = $links.Add("DIR::$(Join-Path $ClaudeDir 'commands')")
            $null = $links.Add("DIR::$(Join-Path $ClaudeDir 'agents')")
        }
        'full' {
            $null = $links.Add("DIR::$(Join-Path $ClaudeDir 'commands')")
            $null = $links.Add("DIR::$(Join-Path $ClaudeDir 'agents')")
            $null = $links.Add("DIR::$(Join-Path $ClaudeDir 'scripts')")
            $null = $links.Add("DIR::$(Join-Path $ClaudeDir 'hooks')")
            $null = $links.Add("DIR::$(Join-Path $ClaudeDir 'workspaces')")
            $null = $links.Add("DIR::$(Join-Path $ClaudeDir 'templates')")
        }
        default {
            Write-Die "Unknown preset: $PresetName"
        }
    }

    # Skill packs
    $skillPacks = @()
    if ($Skills -ne '') {
        $skillPacks = Split-Csv $Skills
    }
    else {
        $skillPacks = Get-SkillPacks
    }

    foreach ($pack in $skillPacks) {
        $packDir = Join-Path $RepoDir "skills\$pack"
        if (-not (Test-Path $packDir -PathType Container)) {
            Write-Die "Unknown skill pack: $pack (expected directory: skills\$pack)"
        }
        $null = $links.Add("LINK::$packDir::$(Join-Path $ClaudeDir "skills\$pack")")
    }

    # Commands / agents for core/full
    if ($PresetName -eq 'core' -or $PresetName -eq 'full') {
        $commandsDir = Join-Path $RepoDir 'commands'
        if (Test-Path $commandsDir) {
            foreach ($f in Get-ChildItem -Path $commandsDir -Filter '*.md' -File) {
                $null = $links.Add("LINK::$($f.FullName)::$(Join-Path $ClaudeDir "commands\$($f.Name)")")
            }
        }
        $agentsDir = Join-Path $RepoDir 'agents'
        if (Test-Path $agentsDir) {
            foreach ($f in Get-ChildItem -Path $agentsDir -Filter '*.md' -File) {
                $null = $links.Add("LINK::$($f.FullName)::$(Join-Path $ClaudeDir "agents\$($f.Name)")")
            }
        }
    }

    # Full preset extras
    if ($PresetName -eq 'full') {
        $scriptsDir = Join-Path $RepoDir 'scripts'
        if (Test-Path $scriptsDir) {
            foreach ($f in Get-ChildItem -Path $scriptsDir -Filter '*.ps1' -File) {
                $null = $links.Add("LINK::$($f.FullName)::$(Join-Path $ClaudeDir "scripts\$($f.Name)")")
            }
        }
        $hooksDir = Join-Path $RepoDir 'hooks'
        if (Test-Path $hooksDir) {
            foreach ($f in Get-ChildItem -Path $hooksDir -Filter '*.ps1' -File) {
                $null = $links.Add("LINK::$($f.FullName)::$(Join-Path $ClaudeDir "hooks\$($f.Name)")")
            }
        }
        $workspacesDir = Join-Path $RepoDir 'workspaces'
        if (Test-Path $workspacesDir) {
            foreach ($w in Get-ChildItem -Path $workspacesDir) {
                $null = $links.Add("LINK::$($w.FullName)::$(Join-Path $ClaudeDir "workspaces\$($w.Name)")")
            }
        }
        $templatesDir = Join-Path $RepoDir 'templates'
        if (Test-Path $templatesDir) {
            foreach ($t in Get-ChildItem -Path $templatesDir) {
                $null = $links.Add("LINK::$($t.FullName)::$(Join-Path $ClaudeDir "templates\$($t.Name)")")
            }
        }
    }

    # Explicit opt-ins
    if ($WithSettings) {
        $null = $links.Add("LINK::$(Join-Path $RepoDir 'settings.json')::$(Join-Path $ClaudeDir 'settings.json')")
    }
    if ($WithHooksJson) {
        $null = $links.Add("LINK::$(Join-Path $RepoDir 'hooks.json')::$(Join-Path $ClaudeDir 'hooks.json')")
    }
    if ($WithHooksScripts -and $PresetName -ne 'full') {
        $null = $links.Add("DIR::$(Join-Path $ClaudeDir 'hooks')")
        $hooksDir = Join-Path $RepoDir 'hooks'
        if (Test-Path $hooksDir) {
            foreach ($f in Get-ChildItem -Path $hooksDir -Filter '*.ps1' -File) {
                $null = $links.Add("LINK::$($f.FullName)::$(Join-Path $ClaudeDir "hooks\$($f.Name)")")
            }
        }
    }
    if ($WithClaudeMd) {
        $null = $links.Add("LINK::$(Join-Path $RepoDir 'CLAUDE.md')::$(Join-Path $ClaudeDir 'CLAUDE.md')")
    }

    return $links.ToArray()
}

function Get-Conflicts {
    $plan = Get-LinksForPreset $Preset
    $conflicts = @()

    foreach ($entry in $plan) {
        $kind = $entry.Split('::')[0]

        if ($kind -eq 'DIR') {
            $dirPath = $entry.Substring(5)  # len('DIR::') = 5
            if ((Test-Path $dirPath) -and -not (Test-Path $dirPath -PathType Container)) {
                $conflicts += $dirPath
            }
            continue
        }

        if ($kind -eq 'LINK') {
            $parts = $entry.Split('::')
            $targetPath = $parts[$parts.Count - 1]
            if (Test-Path $targetPath) {
                $item = Get-Item $targetPath -Force -ErrorAction SilentlyContinue
                if ($null -ne $item -and -not ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                    if (-not (Test-ManagedItem -Path $targetPath)) {
                        $conflicts += $targetPath
                    }
                }
            }
            continue
        }
    }

    if ($conflicts.Count -eq 0) {
        return $true
    }

    Write-Host 'Detected install path conflicts:'
    foreach ($c in $conflicts) {
        Write-Host "- $c"
    }
    Write-Host ''
    Write-Host 'Conflicts happen when files/directories already exist and are not symlinks.'
    Write-Host 'Recommended: move or remove conflicting paths, then rerun Install.ps1'

    if ($ConflictPolicy -eq 'fail') {
        Write-Host ''
        Write-Host 'Aborting install due to conflict policy: fail'
        Write-Host 'To proceed without replacing conflicting paths, rerun with:'
        Write-Host '  .\Install.ps1 -ConflictPolicy skip'
        return $false
    }

    Write-Host ''
    Write-Host 'Continuing with conflict policy: skip'
    Write-Host 'Only non-conflicting paths will be linked.'
    return $true
}

function Write-Manifest {
    param(
        [string]$PresetName,
        [string[]]$InstalledPairs
    )

    if (-not (Test-Path $ManagedDir)) {
        $null = New-Item -ItemType Directory -Path $ManagedDir -Force
    }

    $items = @()
    foreach ($pair in $InstalledPairs) {
        $sepIdx = $pair.IndexOf('::')
        if ($sepIdx -ge 0) {
            $src = $pair.Substring(0, $sepIdx)
            $dst = $pair.Substring($sepIdx + 2)
            $items += @{ source = $src; path = $dst }
        }
    }

    $data = [ordered]@{
        version      = 1
        repo_dir     = $RepoDir
        preset       = $PresetName
        installed_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        items        = $items
    }

    $json = ConvertTo-Json -InputObject $data -Depth 4
    Set-Content -Path $ManifestPath -Value $json -Encoding UTF8
}

function Install-Setup {
    $conflictResult = Get-Conflicts
    if ($conflictResult -eq $false -and $ConflictPolicy -ne 'skip') {
        exit 1
    }

    $plan = Get-LinksForPreset $Preset

    Write-Host "Install target: $ClaudeDir"
    Write-Host "Preset: $Preset"
    if ($Skills -ne '') {
        Write-Host "Skills: $Skills"
    }
    else {
        Write-Host 'Skills: (all)'
    }

    if ($DryRun) {
        Write-Host ''
        Write-Host 'Dry run: planned actions'
    }

    $installedPairs = @()

    foreach ($entry in $plan) {
        $kind = $entry.Split('::')[0]

        if ($kind -eq 'DIR') {
            $dirPath = $entry.Substring(5)
            if ($DryRun) {
                Write-Host "  mkdir $dirPath"
            }
            else {
                if (-not (Test-Path $dirPath)) {
                    $null = New-Item -ItemType Directory -Path $dirPath -Force
                }
            }
            continue
        }

        if ($kind -eq 'LINK') {
            # Parse LINK::source::destination
            $remainder = $entry.Substring(6)  # len('LINK::') = 6
            $lastSep = $remainder.LastIndexOf('::')
            $src = $remainder.Substring(0, $lastSep)
            $dst = $remainder.Substring($lastSep + 2)

            # Check for conflicts
            if (Test-Path $dst) {
                $existingItem = Get-Item $dst -Force -ErrorAction SilentlyContinue
                $isSymlink = $false
                if ($null -ne $existingItem) {
                    $isSymlink = [bool]($existingItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
                }
                if (-not $isSymlink) {
                    if (Test-ManagedItem -Path $dst) {
                        Write-Host "  replacing previously installed: $dst"
                    }
                    elseif ($ConflictPolicy -eq 'skip') {
                        Write-Host "  conflict: $dst exists and is not a symlink (skipped)"
                        continue
                    }
                    else {
                        Write-Die "Conflict: $dst exists and is not a symlink"
                    }
                }
            }

            if ($DryRun) {
                if ($UseCopy) {
                    Write-Host "  copy $src -> $dst"
                }
                else {
                    Write-Host "  link $src -> $dst"
                }
            }
            else {
                $dstParent = Split-Path -Parent $dst
                if (-not (Test-Path $dstParent)) {
                    $null = New-Item -ItemType Directory -Path $dstParent -Force
                }

                # Remove existing symlink before creating new one
                if (Test-Path $dst) {
                    Remove-Item $dst -Force -Recurse
                }

                if ($UseCopy) {
                    Copy-Item -Path $src -Destination $dst -Recurse -Force
                }
                else {
                    $null = New-Item -ItemType SymbolicLink -Path $dst -Target $src
                }
            }
            $installedPairs += "$src::$dst"
            continue
        }
    }

    if ($DryRun) {
        Write-Host ''
        Write-Host 'Dry run complete. No changes made.'
        return
    }

    # Write manifest for safe uninstall
    Write-Manifest -PresetName $Preset -InstalledPairs $installedPairs

    Write-Host ''
    Write-Host "Done. Installed $($installedPairs.Count) link(s)."
    Write-Host 'Tip: rerun with -Preset core or -Preset full to adopt more of the setup.'
}

function Uninstall-Setup {
    Write-Host "Uninstall target: $ClaudeDir"

    $removed = 0

    # Preferred path: remove only what is recorded in the manifest
    if (Test-Path $ManifestPath) {
        $manifestData = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
        foreach ($item in $manifestData.items) {
            $path = $item.path
            if ([string]::IsNullOrEmpty($path)) { continue }

            if (Test-Path $path) {
                $fileItem = Get-Item $path -Force -ErrorAction SilentlyContinue
                if ($null -ne $fileItem -and ($fileItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                    Remove-Item $path -Force
                    Write-Host "  removed $path"
                    $removed++

                    # Best-effort cleanup of empty parent dirs
                    $parentDir = Split-Path -Parent $path
                    try {
                        $children = @(Get-ChildItem -Path $parentDir -Force -ErrorAction SilentlyContinue)
                        if ($children.Count -eq 0) {
                            Remove-Item $parentDir -Force -ErrorAction SilentlyContinue
                        }
                    }
                    catch { }
                }
            }
        }

        Remove-Item $ManifestPath -Force
        try {
            $children = @(Get-ChildItem -Path $ManagedDir -Force -ErrorAction SilentlyContinue)
            if ($children.Count -eq 0) {
                Remove-Item $ManagedDir -Force -ErrorAction SilentlyContinue
            }
        }
        catch { }
    }

    # Legacy cleanup: previous versions symlinked top-level directories
    $legacyItems = @(
        'CLAUDE.md', 'settings.json', 'hooks.json',
        'commands', 'skills', 'agents', 'scripts',
        'hooks', 'workspaces', 'templates'
    )
    foreach ($legacy in $legacyItems) {
        $target = Join-Path $ClaudeDir $legacy
        $expected = Join-Path $RepoDir $legacy
        if (Test-ManagedLink -LinkPath $target -ExpectedTarget $expected) {
            Remove-Item $target -Force
            Write-Host "  removed legacy $target"
            $removed++
        }
    }

    if ($removed -eq 0) {
        Write-Host '  No managed symlinks found - nothing to remove.'
    }
    else {
        Write-Host "Done. Removed $removed symlink(s)."
    }
}

# --- Main ---

if ($ListSkills) {
    Show-SkillPacks
    exit 0
}

if ($Uninstall) {
    Uninstall-Setup
    exit 0
}

Install-Setup
