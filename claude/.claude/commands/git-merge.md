Merge the open PR associated with the current branch if all checks have passed, then sync to main.

1. Get the current branch: `git branch --show-current`
   If it is the default branch (main/master), stop and report there is nothing to merge.

2. Find an open PR for this branch:
   `gh pr list --head <branch> --state open --json number,title,url,mergeable,mergeStateStatus,statusCheckRollup`
   If no open PR exists, stop and report that no open PR was found for this branch.

3. Report the PR number, title, and URL.

4. Check mergeability:
   - `mergeable` must be `MERGEABLE` (not `CONFLICTING` or `UNKNOWN`)
   - `mergeStateStatus` must be `CLEAN` (not `BLOCKED`, `DIRTY`, or `UNSTABLE`)
   - All entries in `statusCheckRollup` must have `status: COMPLETED` and `conclusion: SUCCESS` (skip neutral conclusions)
   If any check is still running (QUEUED or IN_PROGRESS), stop and report which checks are pending.
   If any check failed, stop and report which checks failed.
   If there are merge conflicts, stop and report that the branch has conflicts with the base.

5. If all checks pass and the branch is mergeable, merge using squash:
   `gh pr merge <number> --squash --delete-branch`

6. Report the merge outcome.

7. Run the git-main skill to sync the local repo to main and clean up stale branches.
