---
allowed-tools: Bash(./scripts/nuforce-rebase.sh:*), Bash(git status:*), Bash(git submodule status:*), Bash(pwd:*)
description: Pull the latest upstream changes for the platform repo and all submodules, rebasing onto the configured tracked branches
---

## Context

- Working directory: !`pwd`
- Platform status: !`git status --short`
- Submodule status: !`git submodule status`

## Your task

1. Run the platform rebase workflow:

```bash
./scripts/nuforce-rebase.sh
```

2. If the script reports:
   - a dirty working tree
   - a missing submodule checkout
   - a checkout failure
   - a rebase conflict

   stop immediately and report the exact blocker to the user. Do not try to force the rebase through with additional git commands.

3. If the script succeeds, run:

```bash
git status --short
git submodule status
```

4. Summarize:
   - which repositories were rebased
   - whether the platform repo now has updated submodule pointers
   - whether the user should create a follow-up commit for the new submodule SHAs

## Notes

- The script reads branch mappings from `.gitmodules`
- The current mappings are `api -> main`, `mobile-app -> main`, `web-app -> release`, and `website -> main`
- This command must be run from the platform repository root
