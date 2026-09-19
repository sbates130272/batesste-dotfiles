Take a long series of commits on the current branch and reorganise them into 2–3 larger, logically grouped commits that produce an identical end state. The resulting history must be a clean rebase on top of the current upstream tip with no functional change to the code.

1. Verify preconditions:
   - `git branch --show-current` — must not be the default branch (main/master); stop if it is.
   - `git status --short` — must be clean; stop if there are uncommitted changes.
   - Identify the merge base: `git merge-base HEAD origin/main` (or the detected default branch).

2. Enumerate the commits to reorganise:
   `git log --oneline <merge-base>..HEAD`
   If there are fewer than 4 commits, warn the user that squashing may not be worth it and ask whether to proceed.

3. Analyse the diff to understand logical groupings:
   `git diff <merge-base>..HEAD --stat`
   Read the file paths and commit messages to identify 2–3 natural groups (e.g. by subsystem, concern, or feature area). Reason about the groupings explicitly and present them to the user before doing anything destructive.

4. Confirm with the user:
   Present the proposed grouping as a numbered list:
   - Group 1: <proposed commit subject> — files/commits included
   - Group 2: <proposed commit subject> — files/commits included
   - Group 3 (if needed): <proposed commit subject> — files/commits included
   Stop here and wait for the user to approve or adjust the groupings. Do not proceed until confirmed.

5. Record the pre-rebase tip for safety:
   `git rev-parse HEAD` — save this SHA and report it so the user can recover with `git reset --hard <sha>` if anything goes wrong.

6. Perform the rebase interactively using the git sequence editor approach:
   - Build a rebase todo by writing a GIT_SEQUENCE_EDITOR script that rewrites the pick/squash/reword lines according to the approved grouping.
   - Run: `GIT_SEQUENCE_EDITOR="<script>" git rebase -i <merge-base>`
   - Each group becomes one `pick` (the first commit of the group) followed by `squash` lines for the rest.

7. After the rebase completes, rewrite each group's commit message to a clean conventional-style subject + body:
   - Use `git commit --amend` on each commit as the rebase pauses, or supply messages via the sequence editor.
   - Each message must be signed off: include `Signed-off-by:` from `git config user.name` / `git config user.email`.
   - Append `Co-Authored-By: Claude <noreply@anthropic.com>` to each message.

8. Verify the end state is identical:
   `git diff <original-tip> HEAD`
   If this diff is non-empty, stop immediately and report the discrepancy. Do not push.

9. Report the final log:
   `git log --oneline <merge-base>..HEAD`
   Confirm the branch is a clean rebase on `origin/main` with the agreed number of commits.

10. Do not push. Remind the user that force-push will be required (`git push --force-with-lease`) and to confirm before doing so, since this rewrites published history if the branch was already pushed.
