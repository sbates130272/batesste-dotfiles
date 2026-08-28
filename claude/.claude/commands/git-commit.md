Look at the staged diff (`git diff --cached`) and draft a conventional commit message for the changes.

Write the message to /tmp/$(basename $(git rev-parse --show-toplevel))-commit-msg.txt.

Then end your response with the exact copy-pasteable command the user should run, substituting the real repo name:

```
git commit -s -S -F /tmp/<actual-repo-name>-commit-msg.txt
```

Do not run the commit. Do not use --no-gpg-sign or --no-verify.

$ARGUMENTS
