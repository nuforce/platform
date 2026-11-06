# Working with Git Submodules

This NuForce360 platform repository uses git submodules to organize the codebase into separate repositories while maintaining a unified development environment.

## 📁 Submodule Structure

| Submodule | Repository | Branch | Purpose |
|-----------|------------|--------|---------|
| `nuforce-api/` | [nuforce-api](https://github.com/nuforce/nuforce-api) | main | Laravel 10 + PHP 8.3 backend API |
| `nuforce-flutter/` | [nuforce-flutter](https://github.com/nuforce/nuforce-flutter) | main | Flutter 3.27.1 mobile application |
| `nuforce-web-app/` | [nuforce-web-app](https://github.com/nuforce/nuforce-web-app) | release | Next.js 14 + React web application |
| `nuforce-nuxt/` | [nuforce-nuxt](https://github.com/nuforce/nuforce-nuxt) | main | Nuxt 3 + Vue 3 marketing website |
| `nuforce-admin/` | [nuforce-admin](https://github.com/nuforce/nuforce-admin) | main | Vite + React internal admin app |
| `nuforce-ai-engine/` | [nuforce-ai-engine](https://github.com/nuforce/nuforce-ai-engine) | main | Node + TypeScript AI engine |

## 🚀 Getting Started

### Clone the Platform (First Time)

```bash
# Clone the platform repository with all submodules
git clone --recursive https://github.com/nuforce/platform.git nuforce-workspace
cd nuforce-workspace

# Or if you already cloned without --recursive
git submodule init
git submodule update
```

### Pull Latest Changes

```bash
# Pull platform changes and update all submodules
git pull
git submodule update --recursive

# Or update specific submodule
git submodule update nuforce-api
```

## 🔄 Working with Submodules

### Making Changes in a Submodule

```bash
# Navigate to submodule directory
cd nuforce-api

# Work normally - create branch, make changes, commit
git checkout -b feature/new-feature
# ... make changes ...
git add .
git commit -m "Add new feature"
git push origin feature/new-feature

# Return to platform root
cd ..
```

### Updating Platform to Use Latest Submodule

```bash
# Update submodule to latest commit
cd nuforce-api
git pull origin main
cd ..

# Commit the submodule update in platform
git add nuforce-api
git commit -m "Update API submodule to latest"
git push
```

### Creating New Branches

```bash
# Create platform feature branch
git checkout -b platform/new-feature

# Create corresponding branches in relevant submodules
cd nuforce-api
git checkout -b feature/api-changes
cd ../nuforce-web-app
git checkout -b feature/web-changes
cd ..

# Commit platform branch with submodule branch references
git add .
git commit -m "Create feature branches for platform/new-feature"
```

## 📋 Common Commands

### Status and Information

```bash
# Check status of all submodules
git submodule status

# Show submodule information
git submodule

# Check for changes in submodules
git diff --submodule
```

### Updating Submodules

```bash
# Update all submodules to latest remote
git submodule update --remote

# Update specific submodule to latest
git submodule update --remote nuforce-api

# Update and merge (instead of detached HEAD)
git submodule update --remote --merge
```

### Rebase All Repositories

Use the platform rebase workflow when you want the root repository and every submodule aligned to the latest tracked upstream branch:

```bash
./scripts/nuforce-rebase.sh
```

This workflow:

- Pulls the current platform branch with rebase
- Reads tracked submodule branches from `.gitmodules`
- Checks out the tracked branch if a submodule is in detached HEAD state
- Pulls the tracked branch when already on it
- Rebases feature branches onto the latest tracked upstream branch otherwise

Tracked branches:

- `nuforce-api` -> `main`
- `nuforce-flutter` -> `main`
- `nuforce-web-app` -> `release`
- `nuforce-nuxt` -> `main`
- `nuforce-admin` -> `main`
- `nuforce-ai-engine` -> `main`

Agent shortcuts:

- **Cursor:** `/nuforce-rebase`
- **Claude:** `/nuforce-rebase`

### Advanced Operations

```bash
# Execute command in all submodules
git submodule foreach 'git status'
git submodule foreach 'git pull origin main'

# Reset submodule to committed version
git submodule update --init nuforce-api

# Remove submodule (if needed)
git submodule deinit nuforce-api
git rm nuforce-api
```

## 🔧 Development Workflow

### 1. Feature Development

```bash
# 1. Create platform feature branch
git checkout -b platform/user-authentication

# 2. Create feature branches in relevant submodules
cd nuforce-api && git checkout -b feature/auth-endpoints
cd ../nuforce-web-app && git checkout -b feature/auth-ui
cd ..

# 3. Develop in each submodule independently
# 4. Test integration across components
# 5. Push submodule branches first
# 6. Update platform to reference new commits
# 7. Push platform branch
```

### 2. Code Reviews

- **Submodule PRs**: Create PRs in individual repositories
- **Platform PR**: Create PR for platform changes (usually submodule updates)
- **Integration Testing**: Test complete platform with all changes

### 3. Deployment

```bash
# 1. Ensure all submodule branches are merged and deployed
# 2. Update platform submodules to production commits
git submodule update --remote
git add .
git commit -m "Update all submodules to production versions"

# 3. Deploy platform
git push origin main
```

## ⚠️ Important Notes

### Detached HEAD State

When you run `git submodule update`, submodules are in "detached HEAD" state. To make changes:

```bash
cd nuforce-api
git checkout main  # or your working branch
# ... make changes ...
```

### Submodule Commits

- Each submodule points to a specific commit (not branch)
- Platform tracks exact commit hashes in `.gitmodules`
- Always commit submodule updates in platform repo

### Synchronization

- Keep submodule branches synchronized across the team
- Use same branch names across related submodules when possible
- Update platform frequently to avoid conflicts

## 🆘 Troubleshooting

### Submodule Out of Sync

```bash
# Reset to platform's committed version
git submodule update --init --force

# Update to latest remote
git submodule update --remote
```

### Permission Issues

```bash
# Check submodule URLs
git submodule status

# Update URL if needed
git submodule set-url nuforce-api https://github.com/nuforce/nuforce-api.git
```

### Merge Conflicts in .gitmodules

```bash
# Manual resolution required
git mergetool .gitmodules
git submodule update --init
```

---

## 📚 Resources

- [Git Submodules Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [Platform README](README.md) - Platform overview and setup
- [Individual Repository READMEs](nuforce-api/README.md) - Component-specific documentation