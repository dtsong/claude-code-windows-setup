#!/usr/bin/env bash
# Pre-commit hook: validate PowerShell syntax via pwsh parser.
# Skips gracefully if pwsh is not installed.

if ! command -v pwsh &>/dev/null; then
    echo "pwsh not found, skipping PowerShell syntax check"
    exit 0
fi

rc=0
for f in "$@"; do
    errors=$(pwsh -NoProfile -Command "
        \$errors = \$null
        [System.Management.Automation.Language.Parser]::ParseFile('$f', [ref]\$null, [ref]\$errors) | Out-Null
        if (\$errors) { \$errors | ForEach-Object { Write-Output \$_ }; exit 1 }
    " 2>&1)
    if [ $? -ne 0 ]; then
        echo "Parse errors in $f:"
        echo "$errors"
        rc=1
    fi
done
exit $rc
