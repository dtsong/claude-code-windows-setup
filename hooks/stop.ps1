#===============================================================================
# Stop Hook
# Runs when Claude Code finishes responding
#
# Native Windows only — no WSL/macOS/Linux branches needed.
#
# Identifies which agent/terminal completed using:
# 1. CLAUDE_AGENT_NAME env var (user-defined)
# 2. Git branch name (for worktree setups)
# 3. Agent number from directory name (e.g., project-agent-3)
# 4. Project directory name (fallback)
#===============================================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir '_helpers.ps1')

$agentId = Get-AgentId
$title = "Claude Code [$agentId]"
$message = 'Task complete!'

Write-NotificationLog -AgentId $agentId -Message 'Task complete'
Send-ToastNotification -Title $title -Message $message -SoundName 'Asterisk'

exit 0
