When asked to clean up or audit GitHub Actions workflows in this repo, apply the following conventions and produce a review document.

## Naming convention

### Display name (`name:` field)

Pattern: `rocm-aic - [Self Hosted - ] <Descriptive Name>`

- Prefix every workflow with `rocm-aic - ` so GitHub's Actions tab groups them clearly.
- Add `Self Hosted - ` for any workflow whose jobs run on `[self-hosted, rocm-aic-cicd]` runners.
- Use plain English titles — no abbreviations like "AIC", no vendor prefixes like "AMD".
- Normalise compound words: "Spell Check" not "Spellcheck", "Dist Build Fast" not "Dist Build (fast)".

Examples:

```
rocm-aic - Self Hosted - Dist Build
rocm-aic - Self Hosted - Nightly Smoke Test
rocm-aic - Self Hosted - Accuracy Test
rocm-aic - Lint Check
rocm-aic - Nightly Patch Validation
```

### Filename

Derived mechanically from the display name: lowercase, spaces replaced with `-`, ` - ` replaced with `-`, `.yml` suffix.

Pattern: `rocm-aic[-self-hosted]-<descriptive-name>.yml`

Examples:

```
rocm-aic - Self Hosted - Dist Build          → rocm-aic-self-hosted-dist-build.yml
rocm-aic - Self Hosted - Nightly Smoke Test  → rocm-aic-self-hosted-nightly-smoke-test.yml
rocm-aic - Self Hosted - Accuracy Test       → rocm-aic-self-hosted-accuracy-test.yml
rocm-aic - Lint Check                        → rocm-aic-lint-check.yml
rocm-aic - Nightly Patch Validation          → rocm-aic-nightly-patch-validation.yml
```

When renaming, update `workflow_run: workflows:` entries in any downstream files — GitHub matches by display name, not filename.

## Runner pinning

- Never use `ubuntu-latest`. Pin to `ubuntu-24.04` to prevent silent runner migrations.
- Keep action versions current: `actions/checkout@v5`, `actions/upload-artifact@v6`, `actions/download-artifact@v7`. Check for Node.js deprecation warnings after any upgrade cycle.

## Trigger review

- `workflow_run` chains are capped at **three levels** by GitHub. The nightly chain is: Dist Build (schedule) → Smoke Test → [Tiny Test | Accuracy Test | Cliff Test] (parallel). Do not add a fourth level.
- PR slash commands: `/run-ci` fires the full multi-arch gate; `/run-ci-fast` fires the single-arch gate; `/run-ci-accuracy` fires the full gate with an accuracy stage appended.
- When a nightly workflow and its manual counterpart run the same script, merge them into one file with both triggers rather than maintaining two files.

## Review document

Generate `github-workflow-cleanup.md` (gitignored) in the repo root with a markdown table:

```
| Workflow | File | Runner | Trigger(s) | Description | Last Status | Last Run |
```

Populate Last Status and Last Run from `gh run list --workflow <file> --limit 1`. Include a status key legend and a Notes section for any recurring failures or cancellations. Keep one row per workflow file; sort self-hosted workflows first, then github-hosted alphabetically.
