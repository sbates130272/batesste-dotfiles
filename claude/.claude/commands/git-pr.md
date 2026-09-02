Generate a proposed PR title and description for the current branch.

1. Determine the default remote branch using the same detection order as git-main:
   - `git symbolic-ref refs/remotes/origin/HEAD`
   - `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`
   - Fall back to `origin/main` or `origin/master`.

2. Get all commits on the current branch beyond that base:
   `git log --oneline <base>..HEAD`
   If there are no commits, stop and report that the branch is not ahead of the base.

3. Get the full diff to understand what changed:
   `git diff <base>..HEAD --stat`

4. Derive the repo name: `basename $(git rev-parse --show-toplevel)`

5. Synthesise a PR title (one line, under 70 characters, conventional style matching the repo's commit history) and write it to the session window.

6. Synthesise a PR description covering:
   - What changed and why (1–3 bullet points, inferred from the commits and diff)
   - Any non-obvious context or caveats
   Keep it concise — this is a personal dotfiles repo, not a team project.

7. Write the description to `/tmp/<repo-name>-pr-description.txt` and show the copy-pasteable command to create the PR:

```
gh pr create --title "<title>" --body-file /tmp/<repo-name>-pr-description.txt
```

Do not create the PR. Do not push the branch.
