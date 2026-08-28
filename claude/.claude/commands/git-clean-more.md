First, run the git-clean skill to fetch all remotes, prune stale remote-tracking refs, and delete local branches whose upstream is gone (skipping the current branch).

Then, for each remaining remote branch (from `git branch -r`), assess whether it is a candidate for deletion and make a recommendation. For each branch:

1. Skip HEAD refs and the default branch (main/master).
2. Check if it has been fully merged into the default branch: `git branch -r --merged <default>`.
3. Check the date of its last commit: `git log -1 --format="%ar by %an" <branch>`.
4. If available, check for an associated open or merged PR using `gh pr list --head <branch-name> --state all --json number,state,title`.

Present a table with columns: Branch, Last Commit, Merged?, PR, Recommendation.
Recommendation should be one of:
- **Delete** — fully merged, no open PR
- **Keep** — has an open PR or is not merged
- **Review** — merged PR exists but branch is recent; user should confirm

Do not delete any remote branches. Only report and recommend.
