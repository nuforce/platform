# Working with Git Submodules

This NuForce360 platform repository uses git submodules to organize the codebase into separate repositories while maintaining a unified development environment.

## 📁 Submodule Structure

| Submodule | Repository | Branch | Purpose |
|-----------|------------|--------|---------|
| `api/` | [nuforce-api](https://github.com/nuforce/nuforce-api) | main | Laravel 10 + PHP 8.3 backend API |
| `mobile-app/` | [nuforce-flutter](https://github.com/nuforce/nuforce-flutter) | main | Flutter 3.27.1 mobile application |
| `web-app/` | [nuforce-web-app](https://github.com/nuforce/nuforce-web-app) | release | Next.js 14 + React web application |
| `website/` | [nuforce-nuxt](https://github.com/nuforce/nuforce-nuxt) | main | Nuxt 3 + Vue 3 marketing website |

## 🚀 Getting Started

### Clone the Platform (First Time)

```bash
# Clone the platform repository with all submodules
git clone --recursive https://github.com/nuforce/platform.git
cd platform

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
git submodule update api
```

## 🔄 Working with Submodules

### Making Changes in a Submodule

```bash
# Navigate to submodule directory
cd api

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
cd api
git pull origin main
cd ..

# Commit the submodule update in platform
git add api
git commit -m "Update API submodule to latest"
git push
```

### Creating New Branches

```bash
# Create platform feature branch
git checkout -b platform/new-feature

# Create corresponding branches in relevant submodules
cd api
git checkout -b feature/api-changes
cd ../web-app
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
git submodule update --remote api

# Update and merge (instead of detached HEAD)
git submodule update --remote --merge
```

### Advanced Operations

```bash
# Execute command in all submodules
git submodule foreach 'git status'
git submodule foreach 'git pull origin main'

# Reset submodule to committed version
git submodule update --init api

# Remove submodule (if needed)
git submodule deinit api
git rm api
```

## 🔧 Development Workflow

### 1. Feature Development

```bash
# 1. Create platform feature branch
git checkout -b platform/user-authentication

# 2. Create feature branches in relevant submodules
cd api && git checkout -b feature/auth-endpoints
cd ../web-app && git checkout -b feature/auth-ui
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
cd api
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
git submodule set-url api https://github.com/nuforce/nuforce-api.git
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
- [Individual Repository READMEs](api/README.md) - Component-specific documentation