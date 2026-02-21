#===============================================================================
# Shared Helper Functions
# Used by notify.ps1 and stop.ps1 for agent identification and notifications.
#
# Functions:
#   Get-AgentId             - Identify the current agent/terminal
#   Send-ToastNotification  - Show a Windows toast/balloon notification
#   Write-NotificationLog   - Append entry to notifications.log
#===============================================================================

function Get-AgentId {
    # 1. User-defined agent name (best for multi-tab without worktrees)
    if ($env:CLAUDE_AGENT_NAME) {
        return $env:CLAUDE_AGENT_NAME
    }

    $projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $PWD.Path }

    # 2. Git branch (works great with worktrees)
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitDir = Join-Path $projectDir '.git'
        if ((Test-Path $gitDir)) {
            try {
                $branch = & git -C $projectDir branch --show-current 2>$null
                if ($branch -and $branch -ne 'main' -and $branch -ne 'master') {
                    return $branch
                }
            } catch { }
        }
    }

    $projectName = Split-Path $projectDir -Leaf

    # 3. Extract agent number from directory name (e.g., project-agent-3)
    if ($projectName -match '-(\d+)$') {
        return "Agent $($Matches[1])"
    }

    # 4. Fallback to project name
    return $projectName
}

function Send-ToastNotification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$SoundName = 'Exclamation'
    )

    # Play sound first
    try {
        [System.Media.SystemSounds]::$SoundName.Play()
    } catch { }

    # Method 1: Windows Toast Notification (Windows 10+)
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $escapedTitle = [System.Security.SecurityElement]::Escape($Title)
        $escapedMsg = [System.Security.SecurityElement]::Escape($Message)

        $template = @"
<toast><visual><binding template="ToastText02"><text id="1">$escapedTitle</text><text id="2">$escapedMsg</text></binding></visual></toast>
"@

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show($toast)
        return
    } catch { }

    # Method 2: Balloon notification (older Windows)
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $balloon = New-Object System.Windows.Forms.NotifyIcon
        $balloon.Icon = [System.Drawing.SystemIcons]::Information
        $balloon.BalloonTipIcon = 'Info'
        $balloon.BalloonTipTitle = $Title
        $balloon.BalloonTipText = $Message
        $balloon.Visible = $true
        $balloon.ShowBalloonTip(5000)
        Start-Sleep -Milliseconds 5100
        $balloon.Dispose()
        return
    } catch { }

    # Method 3: Double sound as last resort
    try {
        [System.Media.SystemSounds]::$SoundName.Play()
        Start-Sleep -Milliseconds 300
        [System.Media.SystemSounds]::$SoundName.Play()
    } catch { }
}

function Write-NotificationLog {
    param(
        [string]$AgentId,
        [string]$Message
    )

    $logDir = Join-Path $env:USERPROFILE '.claude' 'logs'
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'HH:mm:ss'
    $projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $PWD.Path }
    $projectName = Split-Path $projectDir -Leaf
    $entry = "[$timestamp] [$AgentId] $Message from: $projectName"

    $logFile = Join-Path $logDir 'notifications.log'
    Add-Content -Path $logFile -Value $entry
}
