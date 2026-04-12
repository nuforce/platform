# NuForce Dev Container Setup for Ona

> Remote development environment plan for the NuForce360 platform on [Ona](https://ona.com).

**Date:** April 12, 2026
**Status:** Implemented — devcontainer files created, Ona projects deployed
**Author:** NuForce Platform Team

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture Decision](#2-architecture-decision)
3. [Infrastructure & Server Map](#3-infrastructure--server-map)
4. [Project 1 — API (Laravel)](#4-project-1--api-laravel)
5. [Project 2 — Web App (Next.js)](#5-project-2--web-app-nextjs)
6. [Project 3 — Website (Nuxt)](#6-project-3--website-nuxt)
7. [Project 4 — Mobile App (Flutter)](#7-project-4--mobile-app-flutter)
8. [Secret Management Strategy](#8-secret-management-strategy)
9. [Database Strategy — Remote Mode](#9-database-strategy--remote-mode)
10. [Ona Environment Classes](#10-ona-environment-classes)
11. [Prebuilds](#11-prebuilds)
12. [Implementation Checklist](#12-implementation-checklist)

---

## 1. Overview

The NuForce360 platform consists of four repositories managed as git submodules:

| Component | Stack | Repository | Default Branch |
|-----------|-------|------------|----------------|
| API | Laravel 10 + PHP 8.3 | `nuforce/nuforce-api` | `main` |
| Web App | Next.js 14 + React 18 | `nuforce/nuforce-web-app` | `release` |
| Mobile App | Flutter 3.27.1 + Dart | `nuforce/nuforce-flutter` | `main` |
| Website | Nuxt 3 + Vue 3 | `nuforce/nuforce-nuxt` | `main` |

All four frontends connect to a single API backend. The API depends on MySQL, Redis, and various AWS services (S3, SQS, SES). We already have production and staging servers running on AWS EC2 with Docker containers.

### Goal

Create **four separate Ona projects** — one per repository — each with its own Dev Container optimized for that stack. All environments connect to **remote hosted databases** (staging/backroad servers) rather than running local database containers.

---

## 2. Architecture Decision

### Approach: Separate Dev Containers per Repository + Remote Database

```
Ona Organization: nuforce
├── Project: nuforce-api          → Multi-container (PHP app + Redis sidecar)
├── Project: nuforce-web-app      → Single container (Node 20)
├── Project: nuforce-website      → Single container (Node 20)
└── Project: nuforce-mobile       → Single container (Flutter + Android SDK)
```

### Why separate containers (not monolithic)

- Each stack has vastly different tooling needs (PHP 8.3 vs Node 20 vs Flutter SDK)
- Developers typically work on one component at a time
- Smaller images = faster Ona environment startup
- Different resource sizing per project (Flutter needs more RAM than a Nuxt dev server)
- Each submodule has its own repository, branch, and CI/CD pipeline

### Why remote database (not local containers)

- The API server at `3.82.84.202` and backroad server at `52.3.253.243` already host MySQL, Redis, and supporting services
- No need to seed or maintain a local database dump
- Realistic data for development and testing
- `connect.sh` script already provides SSH access to all servers
- `bootstrap-secrets.sh` syncs env vars from AWS SSM Parameter Store
- Lighter dev containers — no MySQL 8.0 sidecar eating 2 GB RAM

---

## 3. Infrastructure & Server Map

From `api/scripts/connect.sh`, the available servers are:

| Server | IP | Purpose | Key Services |
|--------|----|---------|-------------|
| **api** | `3.82.84.202` | Production API | MySQL, Redis, API containers |
| **staging** | `44.200.165.247` | Staging API | MySQL, Redis, API containers |
| **backroad** | `52.3.253.243` | Supporting services | MySQL, Redis, OpenSearch, ClickHouse, monitoring |
| **agenthost** | `54.82.211.103` | AI agent host | Agent services |

### Connectivity from Ona Dev Containers

Ona environments run in isolated Linux VMs with internet access. The dev containers will connect to remote databases over the public internet, secured by:

1. Database credentials stored as Ona project secrets (never in code)
2. SSH tunnels via `connect.sh` for admin access if needed
3. Firewall rules on EC2 security groups allowing Ona's IP ranges (or using SSH tunnels)

**Important:** If the EC2 security groups restrict MySQL port 3306 to specific IPs, you need to either:
- Allowlist Ona's egress IP ranges (check Ona docs for static IPs)
- Use an SSH tunnel as a `postStartCommand` in the dev container
- Use a VPN or AWS SSM Session Manager port forwarding

---

## 4. Project 1 — API (Laravel)

The API is the most complex environment. It needs PHP 8.3, Composer, Node.js (for Vite asset build), and connectivity to MySQL + Redis.

### File Structure

```
api/
├── .devcontainer/
│   ├── devcontainer.json
│   ├── docker-compose.yml
│   ├── Dockerfile.dev
│   └── scripts/
│       ├── post-create.sh
│       └── post-start.sh
├── .ona/
│   └── automations.yaml
├── Dockerfile                  ← existing production Dockerfile (unchanged)
├── docker-compose.yml          ← existing production compose (unchanged)
├── env_file.example            ← reference for all env vars
└── scripts/
    ├── connect.sh              ← SSH to servers
    ├── check-env.sh            ← validate environment
    └── bootstrap-secrets.sh    ← sync secrets from AWS SSM
```

### `api/.devcontainer/Dockerfile.dev`

Dev-only image — NOT the production Dockerfile. Includes Xdebug, mysql-client, and development tools.

```dockerfile
FROM serversideup/php:8.3-cli

USER root

RUN apt-get update && apt-get install -y \
    nodejs npm \
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev libwebp-dev \
    default-mysql-client redis-tools \
    curl wget git unzip ssh-client \
    && rm -rf /var/lib/apt/lists/*

RUN install-php-extensions \
    curl exif intl bcmath pdo_mysql redis zip xdebug

RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) gd

RUN npm install -g npm@latest

WORKDIR /workspaces/api
CMD ["sleep", "infinity"]
```

### `api/.devcontainer/docker-compose.yml`

Multi-container: PHP app + local Redis sidecar. MySQL is remote.

```yaml
services:
  app:
    build:
      context: ..
      dockerfile: .devcontainer/Dockerfile.dev
    volumes:
      - ..:/workspaces/api:cached
    network_mode: host
    command: sleep infinity

  redis:
    image: redis:7-alpine
    network_mode: host
    command: >
      redis-server
      --appendonly yes
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru

  mailhog:
    image: mailhog/mailhog:latest
    network_mode: host
```

**Why include a local Redis:** Redis is lightweight (~50 MB RAM) and needed for sessions/cache. Running it locally avoids round-trip latency to the remote server for every cache hit. MySQL stays remote because it holds the actual data.

**Why include MailHog:** Prevents dev emails from leaking to real recipients. The API `MAIL_MAILER` is set to `smtp` pointing at `localhost:1025`.

### `api/.devcontainer/devcontainer.json`

```json
{
  "name": "NuForce API",
  "dockerComposeFile": "docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspaces/api",

  "features": {
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/aws-cli:1": {}
  },

  "forwardPorts": [8001, 6379, 1025, 8025],

  "postCreateCommand": ".devcontainer/scripts/post-create.sh",
  "postStartCommand": ".devcontainer/scripts/post-start.sh",

  "customizations": {
    "vscode": {
      "extensions": [
        "bmewburn.vscode-intelephense-client",
        "onecentlin.laravel-blade",
        "shufo.vscode-blade-formatter",
        "EditorConfig.EditorConfig",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "ms-azuretools.vscode-docker",
        "xdebug.php-debug"
      ],
      "settings": {
        "php.validate.executablePath": "/usr/local/bin/php",
        "editor.formatOnSave": true
      }
    }
  }
}
```

### `api/.devcontainer/scripts/post-create.sh`

Runs once when the container is first created.

```bash
#!/bin/bash
set -e

echo "=== NuForce API — Post-Create Setup ==="

# Create .env from template if missing
if [ ! -f .env ]; then
    cp env_file.example .env
    echo "Created .env from env_file.example"
fi

# Install PHP dependencies
composer install --no-interaction --optimize-autoloader

# Generate app key if placeholder
if grep -q "CHANGE_THIS_TO_REAL_APP_KEY" .env; then
    php artisan key:generate
fi

# Install Node dependencies and build frontend assets
npm ci
npm run build

# Run migrations against remote database
php artisan migrate --force

echo "=== Post-Create Complete ==="
```

### `api/.devcontainer/scripts/post-start.sh`

Runs every time the environment starts or resumes.

```bash
#!/bin/bash
echo "=== NuForce API — Post-Start ==="
echo "Redis:   localhost:6379"
echo "MailHog: http://localhost:8025"
echo "API:     http://localhost:8001 (start with: php artisan serve --port=8001)"
```

### `api/.ona/automations.yaml`

```yaml
services:
  api-server:
    name: Laravel Dev Server
    description: PHP artisan serve on port 8001
    commands:
      start: php artisan serve --host=0.0.0.0 --port=8001
      ready: curl -sf http://localhost:8001/health > /dev/null
    triggeredBy:
      - postDevcontainerStart

  queue-worker:
    name: Queue Worker
    description: Process queued jobs
    commands:
      start: php artisan queue:listen redis --tries=3
    triggeredBy:
      - manual

  vite-dev:
    name: Vite Dev Server
    description: Hot-reload for Blade/Vite assets
    commands:
      start: npm run dev
      ready: curl -sf http://localhost:5173 > /dev/null
    triggeredBy:
      - manual

tasks:
  migrate:
    name: Run Migrations
    command: php artisan migrate --force
    triggeredBy:
      - manual

  seed:
    name: Fresh Seed
    command: php artisan migrate:fresh --seed
    triggeredBy:
      - manual

  test:
    name: PHPUnit Tests
    command: ./vendor/bin/phpunit
    triggeredBy:
      - manual

  lint:
    name: PHP CodeSniffer
    command: ./vendor/bin/phpcs
    triggeredBy:
      - manual

  check-env:
    name: Validate Environment
    command: ./scripts/check-env.sh
    triggeredBy:
      - manual

  bootstrap-secrets:
    name: Pull Secrets from SSM
    description: Sync env file with AWS SSM Parameter Store
    command: ./scripts/bootstrap-secrets.sh pull --file .env
    triggeredBy:
      - manual
```

---

## 5. Project 2 — Web App (Next.js)

The web app only needs Node.js 20. It already has a `.devcontainer/` directory that we enhance.

### File Structure

```
web-app/
├── .devcontainer/
│   ├── devcontainer.json      ← update existing
│   ├── Dockerfile             ← update existing
│   └── README.md              ← update existing
├── .ona/
│   └── automations.yaml       ← new
├── .env.example               ← existing reference
└── Dockerfile                 ← existing production Dockerfile (unchanged)
```

### `web-app/.devcontainer/devcontainer.json` (updated)

```json
{
  "name": "NuForce Web App",
  "build": {
    "dockerfile": "Dockerfile"
  },

  "features": {
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },

  "forwardPorts": [4200],

  "postCreateCommand": "npm ci && cp -n .env.example .env.local 2>/dev/null || true",

  "customizations": {
    "vscode": {
      "extensions": [
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "bradlc.vscode-tailwindcss",
        "ms-vscode.vscode-typescript-next"
      ],
      "settings": {
        "editor.formatOnSave": true,
        "editor.defaultFormatter": "esbenp.prettier-vscode"
      }
    }
  }
}
```

### `web-app/.devcontainer/Dockerfile` (updated)

```dockerfile
FROM mcr.microsoft.com/devcontainers/typescript-node:1-20-bookworm

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends git curl \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1

EXPOSE 4200
CMD ["sleep", "infinity"]
```

### `web-app/.ona/automations.yaml`

```yaml
services:
  dev-server:
    name: Next.js Dev Server
    description: Development server on port 4200
    commands:
      start: npm run dev
      ready: curl -sf http://localhost:4200 > /dev/null
    triggeredBy:
      - postDevcontainerStart

tasks:
  build:
    name: Production Build
    command: npm run build
    triggeredBy:
      - manual

  test:
    name: Run Tests
    command: npm test
    triggeredBy:
      - manual

  lint:
    name: ESLint
    command: npm run lint
    triggeredBy:
      - manual
```

### Environment Variables (from `.env.example`)

The web app needs these key variables configured as Ona project secrets:

| Variable | Dev Default | Notes |
|----------|-------------|-------|
| `NEXT_PUBLIC_API_URL` | `https://hq.nuforce360.com` | Point to staging for dev |
| `NEXT_PUBLIC_APP_URL` | `https://app.nuforce360.com` | |
| `NEXT_PUBLIC_STRIPE_CLIENT_ID` | (test key) | Stripe Connect OAuth |
| `SENTRY_AUTH_TOKEN` | (project token) | Source map upload |
| `NEXT_PUBLIC_SENTRY_DSN` | (DSN string) | Client error tracking |
| `NODE_ENV` | `development` | |

---

## 6. Project 3 — Website (Nuxt)

The marketing website is the simplest environment — Nuxt 3 with a single env var pointing to the API.

### File Structure

```
website/
├── .devcontainer/
│   ├── devcontainer.json      ← new
│   └── Dockerfile             ← new
├── .ona/
│   └── automations.yaml       ← new
├── .env.example               ← existing
└── Dockerfile                 ← existing production Dockerfile (unchanged)
```

### `website/.devcontainer/Dockerfile`

```dockerfile
FROM mcr.microsoft.com/devcontainers/javascript-node:1-20-bookworm

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends git curl \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=development
EXPOSE 3000
CMD ["sleep", "infinity"]
```

### `website/.devcontainer/devcontainer.json`

```json
{
  "name": "NuForce Website",
  "build": {
    "dockerfile": "Dockerfile"
  },

  "features": {
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },

  "forwardPorts": [3000],

  "postCreateCommand": "npm install && cp -n .env.example .env 2>/dev/null || true",

  "customizations": {
    "vscode": {
      "extensions": [
        "Vue.volar",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "bradlc.vscode-tailwindcss"
      ],
      "settings": {
        "editor.formatOnSave": true
      }
    }
  }
}
```

### `website/.ona/automations.yaml`

```yaml
services:
  dev-server:
    name: Nuxt Dev Server
    description: Development server on port 3000
    commands:
      start: npm run dev
      ready: curl -sf http://localhost:3000 > /dev/null
    triggeredBy:
      - postDevcontainerStart

tasks:
  build:
    name: Production Build
    command: npm run build
    triggeredBy:
      - manual

  generate:
    name: Static Generate
    command: npm run generate
    triggeredBy:
      - manual

  lint:
    name: ESLint
    command: npm run lint
    triggeredBy:
      - manual
```

### Environment Variables (from `.env.example`)

| Variable | Dev Default | Notes |
|----------|-------------|-------|
| `NUXT_PUBLIC_API_BASE_URL` | `https://hq.nuforce360.com/api` | Point to staging |

---

## 7. Project 4 — Mobile App (Flutter)

Flutter in a cloud dev container works for **code editing, analysis, testing, and building APK/IPA artifacts**. You cannot run iOS/Android emulators inside Ona — use `flutter run -d web-server` for visual preview or connect a physical device.

### File Structure

```
mobile-app/
├── .devcontainer/
│   ├── devcontainer.json      ← new
│   └── Dockerfile             ← new
├── .ona/
│   └── automations.yaml       ← new
└── pubspec.yaml               ← existing
```

### `mobile-app/.devcontainer/Dockerfile`

```dockerfile
FROM mcr.microsoft.com/devcontainers/base:ubuntu

USER root

# System dependencies for Flutter
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa \
    clang cmake ninja-build pkg-config libgtk-3-dev \
    liblzma-dev libstdc++-12-dev \
    openjdk-17-jdk \
    chromium-browser \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK
ENV FLUTTER_HOME=/opt/flutter
ENV ANDROID_HOME=/opt/android-sdk
ENV CHROME_EXECUTABLE=/usr/bin/chromium-browser
ENV PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

RUN git clone https://github.com/flutter/flutter.git -b 3.27.1 --depth 1 $FLUTTER_HOME \
    && flutter precache \
    && flutter config --no-analytics \
    && dart --disable-analytics

# Android SDK (for building APKs)
RUN mkdir -p $ANDROID_HOME/cmdline-tools \
    && curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o /tmp/cmdline-tools.zip \
    && unzip /tmp/cmdline-tools.zip -d $ANDROID_HOME/cmdline-tools \
    && mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip \
    && yes | sdkmanager --licenses > /dev/null 2>&1 \
    && sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

WORKDIR /workspaces/mobile-app
CMD ["sleep", "infinity"]
```

### `mobile-app/.devcontainer/devcontainer.json`

```json
{
  "name": "NuForce Mobile (Flutter)",
  "build": {
    "dockerfile": "Dockerfile"
  },

  "features": {
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },

  "forwardPorts": [8080, 9100],

  "postCreateCommand": "flutter pub get && flutter doctor -v",

  "customizations": {
    "vscode": {
      "extensions": [
        "Dart-Code.dart-code",
        "Dart-Code.flutter",
        "Nash.awesome-flutter-snippets",
        "alexisvt.flutter-snippets"
      ],
      "settings": {
        "dart.flutterSdkPath": "/opt/flutter"
      }
    }
  }
}
```

### `mobile-app/.ona/automations.yaml`

```yaml
tasks:
  doctor:
    name: Flutter Doctor
    command: flutter doctor -v
    triggeredBy:
      - manual

  test:
    name: Run Tests
    command: flutter test
    triggeredBy:
      - manual

  analyze:
    name: Static Analysis
    command: flutter analyze
    triggeredBy:
      - manual

  build-apk:
    name: Build APK
    command: flutter build apk --release
    triggeredBy:
      - manual

  build-web:
    name: Build Web
    command: flutter build web
    triggeredBy:
      - manual

services:
  web-preview:
    name: Flutter Web Preview
    description: Run Flutter app in web mode for visual testing
    commands:
      start: flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
      ready: curl -sf http://localhost:8080 > /dev/null
    triggeredBy:
      - manual
```

### Flutter API Configuration

The Flutter app uses hardcoded URLs in `lib/app/utils/url.dart`:

```dart
static String baseUrl = hq;
static const String hq = 'https://hq.nuforce360.com/api';
```

The `baseUrl` can be overridden at runtime via `SharedPreferences` (the sign-in page has a base URL field). For dev containers, no env file changes are needed — the app will use the production API by default or developers can switch to staging in the app settings.

**No Ona project secrets required** for the Flutter app beyond `GITHUB_TOKEN` for private package access (if any).

---

## 8. Secret Management Strategy

### Tier 1: Ona Organization Secrets

Shared across all four projects. Set these in Ona Organization Settings → Secrets.

| Secret Name | Type | Source |
|-------------|------|--------|
| `GITHUB_TOKEN` | env var | GitHub PAT for private repo access (submodule cloning) |

### Tier 2: Ona Project Secrets — API

Derived from `api/env_file.example`. Every `CHANGE_THIS_*` placeholder and real credential goes here.

**Application:**

| Secret | Type | env_file.example Section |
|--------|------|--------------------------|
| `APP_KEY` | env var | `base64:...` (generated) |
| `APP_ENV` | env var | `local` |
| `APP_DEBUG` | env var | `true` |
| `APP_URL` | env var | `http://localhost:8001` |
| `FRONTEND_APP_URL` | env var | `https://app.nuforce360.com` |

**Database (Remote — staging/backroad):**

| Secret | Type | env_file.example Section |
|--------|------|--------------------------|
| `DB_HOST` | env var | Staging MySQL IP or hostname |
| `DB_PORT` | env var | `3306` |
| `DB_DATABASE` | env var | `nuforcedb` |
| `DB_USERNAME` | env var | DB username |
| `DB_PASSWORD` | env var | DB password |

**Redis (Local sidecar):**

| Secret | Type | env_file.example Section |
|--------|------|--------------------------|
| `REDIS_HOST` | env var | `127.0.0.1` |
| `REDIS_PORT` | env var | `6379` |
| `REDIS_PASSWORD` | env var | (empty — local dev Redis has no password) |

**Email (MailHog local):**

| Secret | Type | env_file.example Section |
|--------|------|--------------------------|
| `MAIL_MAILER` | env var | `smtp` |
| `MAIL_HOST` | env var | `127.0.0.1` |
| `MAIL_PORT` | env var | `1025` |

**AWS Services:**

| Secret | Type | env_file.example Section |
|--------|------|--------------------------|
| `AWS_ACCESS_KEY_ID` | env var | Dev/staging AWS key |
| `AWS_SECRET_ACCESS_KEY` | env var | Dev/staging AWS secret |
| `AWS_DEFAULT_REGION` | env var | `us-east-1` |
| `AWS_BUCKET` | env var | `nuforcefiles` |

**Authentication:**

| Secret | Type | env_file.example Section |
|--------|------|--------------------------|
| `JWT_SECRET` | env var | Generated secret |
| `JWT_ALGO` | env var | `HS256` |
| `WORKOS_API_KEY` | env var | WorkOS API key |
| `WORKOS_CLIENT_ID` | env var | WorkOS client ID |

**Payments:**

| Secret | Type | env_file.example Section |
|--------|------|--------------------------|
| `STRIPE_KEY` | env var | Test-mode publishable key |
| `STRIPE_SECRET` | env var | Test-mode secret key |
| `STRIPE_CLIENT_ID` | env var | Test-mode Connect client ID |
| `STRIPE_WEBHOOK_SECRET` | env var | Test webhook secret |

**Broadcasting:**

| Secret | Type | env_file.example Section |
|--------|------|--------------------------|
| `PUSHER_APP_ID` | env var | Pusher app ID |
| `PUSHER_APP_KEY` | env var | Pusher app key |
| `PUSHER_APP_SECRET` | env var | Pusher app secret |

**Monitoring:**

| Secret | Type | env_file.example Section |
|--------|------|--------------------------|
| `BUGSNAG_API_KEY` | env var | Bugsnag API key |

**Third-party:**

| Secret | Type | env_file.example Section |
|--------|------|--------------------------|
| `GOOGLE_MAPS_API_KEY` | env var | Google Maps key |
| `TWILIO_ACCOUNT_SID` | env var | Twilio SID |
| `TWILIO_AUTH_TOKEN` | env var | Twilio token |
| `FIREBASE_PROJECT_ID` | env var | `nuforce-pro` |

**Queue:**

| Secret | Type | env_file.example Section |
|--------|------|--------------------------|
| `QUEUE_CONNECTION` | env var | `sync` (local dev) or `redis` |
| `CACHE_DRIVER` | env var | `redis` |
| `SESSION_DRIVER` | env var | `redis` |

> **Shortcut:** Instead of manually creating 40+ secrets in Ona, use `bootstrap-secrets.sh` to pull from AWS SSM into `.env` as the `postCreateCommand`. The script reads from the `/nuforce/local` or `/nuforce/staging` SSM namespace and merges into the local env file. This means you only need the AWS credentials as Ona secrets and the script handles the rest.

### Tier 2: Ona Project Secrets — Web App

Derived from `web-app/.env.example`:

| Secret | Type | .env.example Reference |
|--------|------|------------------------|
| `NEXT_PUBLIC_API_URL` | env var | `https://hq.nuforce360.com` or staging URL |
| `NEXT_PUBLIC_APP_URL` | env var | `https://app.nuforce360.com` |
| `NEXT_PUBLIC_STRIPE_CLIENT_ID` | env var | Test-mode Stripe Connect ID |
| `NEXT_PUBLIC_STRIPE_OAUTH_REDIRECT_ORIGIN` | env var | API origin for Stripe OAuth |
| `SENTRY_AUTH_TOKEN` | env var | Sentry token for source maps |
| `NEXT_PUBLIC_SENTRY_DSN` | env var | Sentry DSN |
| `SENTRY_ORG` | env var | `nuforce-inc` |
| `SENTRY_PROJECT` | env var | `nuforce-web-app` |
| `NEXT_PUBLIC_MIXPANEL_TOKEN` | env var | Mixpanel project token |
| `NEXT_PUBLIC_GA_MEASUREMENT_ID` | env var | Google Analytics ID |
| `NODE_ENV` | env var | `development` |

### Tier 2: Ona Project Secrets — Website

Derived from `website/.env.example`:

| Secret | Type | .env.example Reference |
|--------|------|------------------------|
| `NUXT_PUBLIC_API_BASE_URL` | env var | `https://hq.nuforce360.com/api` or staging |

### Tier 2: Ona Project Secrets — Mobile App

The Flutter app uses hardcoded URLs and constants — no `.env` file. Only organizational secrets (like `GITHUB_TOKEN`) are needed.

---

## 9. Database Strategy — Remote Mode

All dev containers connect to remotely hosted databases. No local MySQL container.

### Connection Flow

```
Ona Dev Container (app service)
    │
    ├─ MySQL ──→ Remote EC2 (staging: 44.200.165.247 or backroad: 52.3.253.243)
    ├─ Redis ──→ Local sidecar (127.0.0.1:6379) — low-latency cache
    └─ Mail  ──→ Local MailHog (127.0.0.1:1025) — catches all outbound email
```

### Security Group Configuration

The remote MySQL server's AWS security group must allow inbound TCP 3306 from the Ona environment. Options:

**Option A — Open to Ona IP ranges (simplest):**
Add Ona's static egress IPs to the EC2 security group for port 3306. Check [Ona documentation](https://ona.com/docs) for their IP ranges.

**Option B — SSH tunnel (most secure):**
Add an SSH tunnel in `post-start.sh`:

```bash
ssh -i ~/.ssh/nuforce-aws-key1.pem -fNL 3306:localhost:3306 ubuntu@44.200.165.247
```

Then set `DB_HOST=127.0.0.1` in the env. This requires the SSH key as an Ona file secret.

**Option C — AWS SSM Session Manager port forwarding:**

```bash
aws ssm start-session \
  --target i-0abc123def456 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3306"],"localPortNumber":["3306"]}'
```

**Recommended:** Option A for development simplicity. Option B for stricter environments.

### `bootstrap-secrets.sh` Integration

Instead of manually creating dozens of Ona secrets, configure only the AWS credentials as Ona project secrets, then have the `postCreateCommand` pull the full env from SSM:

```bash
# In post-create.sh
./scripts/bootstrap-secrets.sh new --file .env --env staging
```

This creates `.env` from `env_file.example` and merges values from the `/nuforce/staging` SSM namespace — populating database credentials, API keys, and all other secrets automatically.

---

## 10. Ona Environment Classes

Configure each project with appropriate compute resources:

| Project | Environment Class | CPU | RAM | Disk | Rationale |
|---------|------------------|-----|-----|------|-----------|
| nuforce-api | Regular | 4 cores | 8 GB | 30 GB | PHP + Composer + Node + Redis sidecar + MailHog |
| nuforce-web-app | Small | 2 cores | 4 GB | 20 GB | Node.js dev server only |
| nuforce-website | Small | 2 cores | 4 GB | 15 GB | Node.js dev server only |
| nuforce-mobile | Large | 4 cores | 8 GB | 50 GB | Flutter SDK + Android SDK + Chromium |

---

## 11. Prebuilds

Enable prebuilds on each Ona project to speed up environment startup. Dependencies are installed during the prebuild so developers get a warm image.

### API Prebuild

```yaml
# In api/.ona/automations.yaml — add to tasks section
tasks:
  prebuild-deps:
    name: Install Dependencies
    command: |
      composer install --no-interaction --optimize-autoloader
      npm ci
      npm run build
    triggeredBy:
      - prebuild
```

### Web App Prebuild

```yaml
tasks:
  prebuild-deps:
    name: Install Dependencies
    command: npm ci
    triggeredBy:
      - prebuild
```

### Website Prebuild

```yaml
tasks:
  prebuild-deps:
    name: Install Dependencies
    command: npm install
    triggeredBy:
      - prebuild
```

### Mobile App Prebuild

```yaml
tasks:
  prebuild-deps:
    name: Install Dependencies
    command: flutter pub get
    triggeredBy:
      - prebuild
```

Configure prebuilds to run on push to each repository's default branch (`main` or `release`).

---

## 12. Implementation Checklist

### Phase 1 — API Dev Container (Week 1–2)

- [ ] Create `api/.devcontainer/Dockerfile.dev`
- [ ] Create `api/.devcontainer/docker-compose.yml` (app + Redis + MailHog)
- [ ] Create `api/.devcontainer/devcontainer.json`
- [ ] Create `api/.devcontainer/scripts/post-create.sh`
- [ ] Create `api/.devcontainer/scripts/post-start.sh`
- [ ] Create `api/.ona/automations.yaml`
- [ ] Test locally with VS Code Dev Containers extension
- [ ] Create Ona project for `nuforce/nuforce-api` repo
- [ ] Configure Ona project secrets (AWS credentials at minimum, or full env)
- [ ] Configure EC2 security group for remote MySQL access from Ona
- [ ] Test `bootstrap-secrets.sh pull` works inside the container
- [ ] Test `check-env.sh` validates all connections
- [ ] Enable prebuilds on `main` branch
- [ ] Document any Ona-specific quirks or workarounds

### Phase 2 — Web App + Website Dev Containers (Week 2–3)

- [ ] Update `web-app/.devcontainer/devcontainer.json`
- [ ] Update `web-app/.devcontainer/Dockerfile`
- [ ] Create `web-app/.ona/automations.yaml`
- [ ] Create `website/.devcontainer/devcontainer.json`
- [ ] Create `website/.devcontainer/Dockerfile`
- [ ] Create `website/.ona/automations.yaml`
- [ ] Create Ona projects for both repositories
- [ ] Configure Ona project secrets for API URL and Sentry
- [ ] Test both dev servers start and connect to remote API
- [ ] Enable prebuilds

### Phase 3 — Flutter Dev Container (Week 3–4)

- [ ] Create `mobile-app/.devcontainer/Dockerfile`
- [ ] Create `mobile-app/.devcontainer/devcontainer.json`
- [ ] Create `mobile-app/.ona/automations.yaml`
- [ ] Create Ona project for `nuforce/nuforce-flutter` repo
- [ ] Test `flutter doctor`, `flutter test`, `flutter analyze` inside container
- [ ] Test `flutter run -d web-server` for visual preview
- [ ] Test `flutter build apk --release` for artifact generation
- [ ] Enable prebuilds

### Phase 4 — Polish & Onboarding (Week 4)

- [ ] Write developer onboarding guide for Ona
- [ ] Configure Ona organization-level shared secrets
- [ ] Set recommended editors for each project
- [ ] Run full end-to-end test: create environment → run dev server → make a code change → commit
- [ ] Update platform README with Ona dev container instructions
- [ ] Share with team, gather feedback, iterate

---

## Appendix A — Ona Project Configuration Summary

When creating each project in the Ona dashboard:

| Setting | nuforce-api | nuforce-web-app | nuforce-website | nuforce-mobile |
|---------|-------------|-----------------|-----------------|----------------|
| Repository | `nuforce/nuforce-api` | `nuforce/nuforce-web-app` | `nuforce/nuforce-nuxt` | `nuforce/nuforce-flutter` |
| Branch | `main` | `release` | `main` | `main` |
| Dev Container path | `.devcontainer/devcontainer.json` | `.devcontainer/devcontainer.json` | `.devcontainer/devcontainer.json` | `.devcontainer/devcontainer.json` |
| Automations file | `.ona/automations.yaml` | `.ona/automations.yaml` | `.ona/automations.yaml` | `.ona/automations.yaml` |
| Environment class | Regular (4 CPU, 8 GB) | Small (2 CPU, 4 GB) | Small (2 CPU, 4 GB) | Large (4 CPU, 8 GB) |
| Prebuilds | On push to `main` | On push to `release` | On push to `main` | On push to `main` |

## Appendix B — Port Allocation

| Port | Service | Project |
|------|---------|---------|
| 8001 | Laravel dev server (`artisan serve`) | API |
| 5173 | Vite HMR (asset hot-reload) | API |
| 6379 | Redis (local sidecar) | API |
| 1025 | MailHog SMTP | API |
| 8025 | MailHog Web UI | API |
| 4200 | Next.js dev server | Web App |
| 3000 | Nuxt dev server | Website |
| 8080 | Flutter web preview | Mobile |
| 9100 | Dart DevTools | Mobile |

## Appendix C — Reference Files

| File | Purpose |
|------|---------|
| `api/env_file.example` | Complete list of all API environment variables |
| `api/scripts/connect.sh` | SSH to EC2 servers (api, staging, backroad, agenthost) |
| `api/scripts/check-env.sh` | Validate environment connectivity and configuration |
| `api/scripts/bootstrap-secrets.sh` | Bidirectional sync between local env and AWS SSM |
| `api/docker/services/compose-services.yml` | Local infrastructure services (for reference) |
| `api/Dockerfile` | Production Dockerfile (builds via GitHub Actions → AWS ECR) |
| `web-app/.env.example` | Web app environment variable reference |
| `website/.env.example` | Website environment variable reference |
