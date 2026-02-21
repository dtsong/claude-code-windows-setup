Run the project's test suite and report results.

First, detect the project type and find the appropriate test command:
```bash
ls package.json pyproject.toml setup.py Cargo.toml go.mod Makefile 2>/dev/null
```

Then run the appropriate test command:
- Node.js: `npm test` or `yarn test` or `pnpm test`
- Python: `pytest` or `python -m pytest`
- Go: `go test ./...`
- Rust: `cargo test`
- Make: `make test`

Report the results clearly. If tests fail, analyze the failures and suggest fixes.
