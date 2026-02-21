#Requires -Version 5.1
<#
.SYNOPSIS
    Send completion notification for agent tasks
.DESCRIPTION
    Sends a Windows toast notification when a Claude agent completes its task.
    Uses the Send-ToastNotification helper from hooks/_helpers.ps1.
.PARAMETER Branch
    Branch name that completed (default: unknown)
.PARAMETER Summary
    Brief summary of what was completed (default: Task completed)
.EXAMPLE
    .\Notify-Complete.ps1 -Branch "fix/login" -Summary "Fixed OAuth redirect"
#>
param(
    [string]$Branch = 'unknown',
    [string]$Summary = 'Task completed'
)

# Dot-source the helpers for Send-ToastNotification
$helpersPath = Join-Path $PSScriptRoot '..\hooks\_helpers.ps1'
if (Test-Path $helpersPath) {
    . $helpersPath
}

# Send Windows toast notification
if (Get-Command Send-ToastNotification -ErrorAction SilentlyContinue) {
    Send-ToastNotification -Title 'Claude Agent Complete' -Message "${Branch}: $Summary"
}
else {
    # Fallback: use Windows built-in notification API (no external modules)
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
            [Windows.UI.Notifications.ToastTemplateType]::ToastText02
        )
        $textNodes = $template.GetElementsByTagName('text')
        $textNodes.Item(0).AppendChild($template.CreateTextNode('Claude Agent Complete')) | Out-Null
        $textNodes.Item(1).AppendChild($template.CreateTextNode("${Branch}: $Summary")) | Out-Null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code')
        $notifier.Show($toast)
    }
    catch {
        # Last resort: console output only
        Write-Host "NOTIFICATION: Claude Agent Complete - ${Branch}: $Summary"
    }
}

Write-Host "Notification sent: $Branch - $Summary"
