Sync the local repo to the main upstream branch and clean up stale branches.

1. Run `git fetch --all` to update all remote-tracking refs.

2. Determine the default branch by checking (in order):
   - `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `refs/remotes/origin/main`)
   - If that fails, inspect remote info: `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`
   - Fall back to whichever of `origin/main` or `origin/master` exists.
   Report which branch was detected.

3. Find the local branch tracking that remote branch:
   - `git branch -vv` to identify the local branch whose upstream matches the detected remote default.
   If no local tracking branch exists, create one: `git checkout --track origin/<default>`.

4. Switch to that local branch (`git checkout <branch>`).

5. Run `git pull` to fast-forward it to the remote tip. If the pull would require a merge (non-fast-forward), stop and report — do not merge.

6. Run the git-clean-more skill to prune stale remote-tracking refs, delete merged local branches, and report on remaining remote branches.
