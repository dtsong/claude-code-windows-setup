#!/usr/bin/env bash
# Pre-commit hook: verify required documentation files exist.

rc=0
for f in README.md CLAUDE.md ARCHITECTURE.md CONTRIBUTING.md CHANGELOG.md; do
    if [ ! -f "$f" ]; then
        echo "Missing required file: $f"
        rc=1
    fi
done
exit $rc
