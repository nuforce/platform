# NuForce platform

This folder is the `nuforce/platform` repo. Each app is a git submodule with its own remote, branches, PRs and CLAUDE.md or AGENTS.md. Read the one inside the repo you are changing.

This repo is **public**. Never commit secrets, `.env` files, keys, customer data or internal hostnames here.

## Submodules

| Folder | GitHub | Stack | Tracked branch | Old name |
|---|---|---|---|---|
| `nuforce-api` | nuforce/nuforce-api | Laravel, PHP 8.3 | main | `api` |
| `nuforce-web-app` | nuforce/nuforce-web-app | Next.js | release | `web-app` |
| `nuforce-flutter` | nuforce/nuforce-flutter | Flutter | main | `mobile-app` |
| `nuforce-admin` | nuforce/nuforce-admin | Vite, React | main | `admin-app` |
| `nuforce-nuxt` | nuforce/nuforce-nuxt | Nuxt (marketing site and help) | main | `website` |
| `nuforce-ai-engine` | nuforce/nuforce-ai-engine | Node, TypeScript | main | none |

Older docs, RFCs and memory notes use the old names. Read `api/...` as `nuforce-api/...`, `web-app/...` as `nuforce-web-app/...`, and so on.

## Working here

- Code changes happen inside a submodule, committed and pushed there. The platform repo only records which commit each submodule is on.
- After submodules move forward, commit the new pointers here: `git add nuforce-api && git commit -m "Bump nuforce-api"`.
- `./scripts/nuforce-rebase.sh` (or `/nuforce-rebase`) pulls platform and every submodule onto its tracked branch.
- A change that spans repos gets one branch per repo with the same name, and one PR per repo.

## Toolchain

`.envrc` (direnv) puts the project tools on PATH inside this folder only:

- PHP 8.3 from the Homebrew `php@8.3` keg (production is `serversideup/php:8.3-fpm-nginx`), with the `redis` extension.
- Composer and AWS CLI v2 in `.tools/bin` (gitignored, local to this checkout).
- `AWS_PROFILE=nuforce`.

Claude Code's Bash tool does not run the direnv hook. Load the environment first in each command: `eval "$(direnv export bash)"`.
