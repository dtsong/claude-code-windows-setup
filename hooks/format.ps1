#===============================================================================
# PostToolUse Format Hook
# Auto-formats code after Claude makes edits
#
# Supports: JavaScript, TypeScript, Python, Go, Rust, Ruby, Shell
#===============================================================================

# Exit early if no file paths provided
if (-not $env:CLAUDE_FILE_PATHS) {
    exit 0
}

# Process each file
foreach ($file in ($env:CLAUDE_FILE_PATHS -split '\s+')) {
    if (-not (Test-Path $file -PathType Leaf)) {
        continue
    }

    $ext = [System.IO.Path]::GetExtension($file).ToLower()

    switch -Wildcard ($ext) {
        # JavaScript/TypeScript/Web files - use Prettier
        { $_ -in '.js','.jsx','.ts','.tsx','.json','.md','.css','.scss','.less','.html','.vue','.svelte' } {
            if (Get-Command prettier -ErrorAction SilentlyContinue) {
                & prettier --write $file 2>$null
            }
            break
        }

        # Python files - use Black or autopep8
        '.py' {
            if (Get-Command black -ErrorAction SilentlyContinue) {
                & black --quiet $file 2>$null
            } elseif (Get-Command autopep8 -ErrorAction SilentlyContinue) {
                & autopep8 --in-place $file 2>$null
            }
            break
        }

        # Go files - use gofmt
        '.go' {
            if (Get-Command gofmt -ErrorAction SilentlyContinue) {
                & gofmt -w $file 2>$null
            }
            break
        }

        # Rust files - use rustfmt
        '.rs' {
            if (Get-Command rustfmt -ErrorAction SilentlyContinue) {
                & rustfmt $file 2>$null
            }
            break
        }

        # Ruby files - use rubocop
        '.rb' {
            if (Get-Command rubocop -ErrorAction SilentlyContinue) {
                & rubocop --autocorrect --silent $file 2>$null
            }
            break
        }

        # Shell scripts - use shfmt
        { $_ -in '.sh','.bash' } {
            if (Get-Command shfmt -ErrorAction SilentlyContinue) {
                & shfmt -w $file 2>$null
            }
            break
        }
    }
}

exit 0
