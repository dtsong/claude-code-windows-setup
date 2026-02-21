Create a commit, push to remote, and open a pull request for the current changes.

First, gather context about the current state:
```bash
git status
git diff --stat
git branch --show-current
git log -3 --oneline
```

Then follow these steps:
1. Review the changes and create a clear, descriptive commit message following conventional commits format (feat:, fix:, docs:, refactor:, test:, chore:)
2. Stage all changes with `git add -A`
3. Commit with the descriptive message
4. Push to the current branch (create upstream tracking if needed with `git push -u origin <branch>`)
5. Create a PR using `gh pr create --fill` or with a custom title/body if the changes warrant more description

If there are no changes to commit, let me know.
If we're on main/master, suggest creating a feature branch first.
