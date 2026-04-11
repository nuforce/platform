# nuforce-rebase

**Purpose:** Pull the latest upstream changes for the platform repo and every configured submodule, rebasing safely onto the tracked branch for each repository.

**Usage:** Invoke when the user runs `/nuforce-rebase`, `@nuforce-rebase`, or asks to rebase the platform and all submodules.

---

## Agent instructions

### 0. Safety checks

1. Run the command from the platform repository root.
2. Do not try to force through dirty working trees or rebase conflicts.
3. If the script reports uncommitted changes or a conflict, stop immediately and report the blocker to the user.

### 1. Run the rebase workflow

Execute:

```bash
./scripts/nuforce-rebase.sh
```

### 2. Report the result

If the script succeeds:

1. Run:

```bash
git status --short
git submodule status
```

2. Summarize:
   - which repositories were updated
   - whether any submodule pointers changed in the platform repo
   - whether the user should commit the updated submodule references

### 3. Branch mapping

The script reads tracked branches from `.gitmodules`:

- `api` -> `main`
- `mobile-app` -> `main`
- `web-app` -> `release`
- `website` -> `main`

### 4. Troubleshooting

- Dirty repo: commit or stash changes first, then rerun `/nuforce-rebase`
- Detached submodule HEAD: the script checks out the tracked branch before rebasing
- Rebase conflict: resolve manually inside the affected repo, then rerun the command
