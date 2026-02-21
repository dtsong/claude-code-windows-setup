#===============================================================================
# Notification Hook
# Runs when Claude Code needs user input (permission prompt or idle)
#
# Native Windows only — no WSL/macOS/Linux branches needed.
#
# Identifies which agent/terminal needs attention using:
# 1. CLAUDE_AGENT_NAME env var (user-defined)
# 2. Git branch name (for worktree setups)
# 3. Agent number from directory name (e.g., project-agent-3)
# 4. Project directory name (fallback)
#===============================================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir '_helpers.ps1')

$agentId = Get-AgentId
$title = "Claude Code [$agentId]"
$message = 'Needs your input!'

Write-NotificationLog -AgentId $agentId -Message 'Notification'
Send-ToastNotification -Title $title -Message $message -SoundName 'Exclamation'

exit 0
