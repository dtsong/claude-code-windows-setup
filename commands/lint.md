Run linting and fix any auto-fixable issues.

First, detect the project type:
```bash
ls package.json pyproject.toml setup.py Cargo.toml go.mod 2>/dev/null
```

Then run the appropriate linter:
- Node.js: `npm run lint` or `npx eslint . --fix`
- Python: `ruff check --fix .` or `black .`
- Go: `go fmt ./...` and `go vet ./...`
- Rust: `cargo fmt` and `cargo clippy`

Report any issues that couldn't be auto-fixed.
