#Requires -Version 5.1
<#
.SYNOPSIS
    Initialize Claude Code configuration for a project
.DESCRIPTION
    Sets up .claude directory, copies CLAUDE.md template and project settings.
.PARAMETER ProjectDir
    Path to the project directory (default: current directory)
.EXAMPLE
    .\Init-Project.ps1 -ProjectDir "C:\Projects\my-app"
#>
param(
    [string]$ProjectDir = '.'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ProjectDir -PathType Container)) {
    Write-Error "Directory $ProjectDir does not exist"
    exit 1
}

Push-Location $ProjectDir
try {
    Write-Host "Initializing Claude Code configuration in $(Get-Location)..."
    Write-Host ""

    # Create .claude directory
    if (-not (Test-Path '.claude\commands')) {
        New-Item -ItemType Directory -Path '.claude\commands' -Force | Out-Null
    }

    # Copy CLAUDE.md template if it doesn't exist
    if (-not (Test-Path 'CLAUDE.md')) {
        $templatePath = Join-Path $env:USERPROFILE '.claude\templates\CLAUDE.md'
        if (Test-Path $templatePath) {
            Copy-Item $templatePath -Destination '.\CLAUDE.md'
            Write-Host "[OK] Created CLAUDE.md (remember to customize it!)"
        }
        else {
            Write-Host "[WARNING] CLAUDE.md template not found, skipping"
        }
    }
    else {
        Write-Host "[WARNING] CLAUDE.md already exists, skipping"
    }

    # Copy project settings template if it doesn't exist
    if (-not (Test-Path '.claude\settings.json')) {
        $settingsTemplate = Join-Path $env:USERPROFILE '.claude\templates\project-settings.json'
        if (Test-Path $settingsTemplate) {
            Copy-Item $settingsTemplate -Destination '.claude\settings.json'
            Write-Host "[OK] Created .claude\settings.json"
        }
        else {
            Write-Host "[WARNING] Project settings template not found, skipping"
        }
    }
    else {
        Write-Host "[WARNING] .claude\settings.json already exists, skipping"
    }

    Write-Host ""
    Write-Host "Project initialized! Next steps:"
    Write-Host "  1. Edit CLAUDE.md to describe your project"
    Write-Host "  2. Edit .claude\settings.json to add project-specific permissions"
    Write-Host "  3. Add project-specific commands to .claude\commands\"
    Write-Host "  4. Run 'claude' to start coding!"
}
finally {
    Pop-Location
}
