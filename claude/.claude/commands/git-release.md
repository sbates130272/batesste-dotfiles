Prepare a new tag release for the current repository. Do not run any commands yourself — only show the user the commands to run.

## Step 1: Gather context

Run these read-only commands to understand the repo state:

```
gh auth status
git fetch --tags
git tag --sort=-version:refname | head -20
git log $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD --oneline
gh workflow list
cat .github/workflows/*.yml 2>/dev/null || ls .github/workflows/ 2>/dev/null
```

## Step 2: Check release workflow

Review the GitHub Actions workflows to determine:
- Whether a release workflow exists and what triggers it (push tag, workflow_dispatch, etc.)
- Whether it expects a specific tag format (e.g. `vX.Y.Z`, `vX.Y.Z-rc.N`)
- Any release asset build steps that depend on the tag name

If no release workflow exists, note this clearly and warn the user that pushing a tag alone may not publish a GitHub Release.

## Step 3: Propose the tag

If the user provided a tag in `$ARGUMENTS`, use that. Otherwise, inspect the commit log since the last tag and propose a semver tag following these guidelines:
- **patch** bump (`vX.Y.Z+1`): only fixes, docs, chores, or trivial changes
- **minor** bump (`vX.Y+1.0`): new features or meaningful additions, no breaking changes
- **major** bump (`vX+1.0.0`): breaking changes, API removals, or incompatible behaviour

State your reasoning (e.g. "3 fix commits since v1.2.1 → proposing v1.2.2").

## Step 4: Show the commands

End your response with the exact copy-pasteable commands the user should run, substituting real values:

```
# Create and push the signed tag
git tag -s vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

If the repo's release workflow uses `workflow_dispatch` instead of a tag push, show that command instead:

```
gh workflow run <workflow-file> --field version=vX.Y.Z
```

Do not run any of these commands. Do not push, tag, or trigger workflows yourself.

$ARGUMENTS
