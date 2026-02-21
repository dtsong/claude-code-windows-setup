# Changelog

## [1.0.0] - 2026-02-21

Initial release -- Windows native PowerShell port of claude-code-wsl-setup.

### Added
- Install.ps1 PowerShell installer with presets, symlink capability detection, and manifest-based uninstall
- 5 hook scripts ported to PowerShell + 1 shared helper
- 10 utility scripts ported to PowerShell with Verb-Noun naming
- 6 skill-level scripts ported to PowerShell
- Windows-adapted settings.json and hooks.json
- Full documentation for Windows users
- CI validation workflow for PowerShell syntax checking

### Carried Forward (unchanged from claude-code-wsl-setup)
- 38 agent personas (21 Council + 17 Academy)
- 26 slash commands including shared deliberation engine
- 184+ skill templates across 20 departments + standalone packs
- Workspace context system
- Project templates
