Clean up stale remote-tracking refs and local branches whose upstream is gone. Do not pull or fast-forward anything. Do not delete the current branch even if its upstream is gone.

Run these steps in order:

1. `git fetch --all` — update all remote-tracking refs (no merge)
2. For each remote listed by `git remote`: run `git remote prune <remote>` — remove stale remote-tracking refs
3. Identify gone-upstream local branches: `git branch -vv | grep ': gone]'`
4. Get the current branch: `git branch --show-current`
5. For each gone branch that is NOT the current branch: `git branch -D <name>`
6. Report which branches were deleted and which (if any) were skipped because they are the current branch.
