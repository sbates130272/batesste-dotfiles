The user has committed changes and pushed to a remote-tracked branch. Monitor the PR associated with that branch and report check status every 120 seconds until all checks complete or a failure is detected.

1. Identify the current branch and remote:
   - `git branch --show-current` — get the local branch name
   - `git rev-parse --abbrev-ref --symbolic-full-name @{u}` — get the upstream (e.g. `origin/feat/foo`)
   If there is no upstream tracking branch, stop and report the branch has no remote tracking ref.

2. Determine which GitHub account to use:
   - Get the remote URL: `git remote get-url origin`
   - If the remote URL contains `ROCm`, `ROCmSoftwarePlatform`, or `amd-staging`, use account `stebates_amdeng`.
   - Otherwise use account `sbates130272`.
   - Switch to the selected account: `gh auth switch -u <account>`
   - Confirm the switch: `gh auth status`

3. Find the open PR for this branch:
   `gh pr list --head <branch> --state open --json number,title,url,statusCheckRollup`
   If no open PR exists, stop and report that no open PR was found. Remind the user to open one with `/git-pr`.

4. Report the PR number, title, and URL.

5. Poll loop — repeat every 120 seconds until done:

   a. Fetch current check status:
      `gh pr view <number> --json statusCheckRollup,state,mergeable,mergeStateStatus`

   b. Report a summary table of checks with columns: Check Name, Status, Conclusion.

   c. Evaluate overall state:
      - If `state` is not `OPEN`, report the PR was closed or merged and stop.
      - If any check has `status` not in {COMPLETED, SUCCESS, NEUTRAL}: report which checks are still running and wait 120 seconds before re-polling.
      - If any check has `conclusion` of `FAILURE` or `CANCELLED`: report failure details and stop — do not continue polling.
      - If all checks are COMPLETED with SUCCESS or NEUTRAL conclusion AND `mergeable` is `MERGEABLE` AND `mergeStateStatus` is `CLEAN`: report the PR is ready to merge and stop.

   d. Before each re-poll, print the wall-clock time of the next check and wait 120 seconds.

6. At the end of polling, remind the user they can run `/git-merge` to merge the PR if all checks passed.
