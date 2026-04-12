# GitHub Project Management Setup

## ✅ Connected to NuForce Project Board

**Project:** [nuforce](https://github.com/orgs/nuforce/projects/8)  
**Repository:** [platform](https://github.com/nuforce/platform)  
**Setup Date:** April 11, 2026

## 📊 Project Board Configuration

### Workflow States
- **Backlog** → Issue created, not yet groomed
- **Ready** → Requirements clear, ready for development  
- **In Progress** → Developer assigned, work started
- **In Review** → PR opened and linked
- **Done** → PR merged, issue closed

### Priority Levels
- **P0** → Critical (production down, security, blocks release)
- **P1** → High (milestone blocker, important fix)
- **P2** → Medium (scheduled work, standard priority)

### Size Estimates
- **XS** (1 pt) → < 2 hours
- **S** (2 pts) → 2-4 hours  
- **M** (3 pts) → 4-8 hours
- **L** (5 pts) → 1-2 days
- **XL** (8 pts) → 2-5 days

## 🏷️ Label Taxonomy (42 labels created)

### Type Labels
- `type:epic` `type:feature` `type:task` `type:bug` `type:chore` `type:spike`

### Domain Labels - Platform
- `domain:api` - Laravel backend API and services
- `domain:mobile` - Flutter mobile application  
- `domain:webapp` - Next.js web application dashboard
- `domain:website` - Nuxt marketing website
- `domain:platform` - Platform-wide configuration
- `domain:infra` - Infrastructure, CI/CD, deployment

### Domain Labels - Business
- `domain:auth` - Authentication and authorization
- `domain:scheduling` - Job scheduling and work orders
- `domain:payments` - Payment processing and invoicing
- `domain:tracking` - GPS and material tracking
- `domain:workforce` - Employee and field worker management

### Component Labels
- `component:api` `component:service` `component:model` `component:ui` `component:test` `component:config`

### Repository Labels
- `repo:platform` `repo:api` `repo:mobile` `repo:webapp` `repo:website`

### Signal Labels
- `needs:triage` `needs:design` `needs:clarity` `needs:review` 
- `blocked` `security` `breaking-change` `performance` `tech-debt`

### Size & Resolution Labels
- `size:xs` through `size:xl`
- `resolution:duplicate` `resolution:wontfix` `resolution:stale` `resolution:by-design`

## 👥 Team Members
- **johnefemer** - Project lead and setup
- **tanvirahmed2707** - Development team

## 🛠️ Tech Stack Integration

The project management system is configured to understand your multi-repository platform:

### API Repository (Laravel 10 + PHP 8.3)
- Test command: `./vendor/bin/phpunit`
- Lint command: `./vendor/bin/phpcs`  
- Build: `composer install && docker-compose up -d`

### Web App Repository (Next.js 14 + React)
- Test command: `npm test`
- Lint command: `npm run lint`
- Build: `npm install && npm run build`

### Mobile App Repository (Flutter 3.27.1)
- Test command: `flutter test`
- Lint command: `flutter analyze`
- Build: `flutter pub get && flutter build`

### Website Repository (Nuxt 3 + Vue 3)
- Test command: `npm run test`
- Lint command: `npm run lint`
- Build: `npm install && npm run build`

## 📝 Usage Examples

### Create Epic with Sub-Issues
```bash
# AI will break down large features into structured epics
"Create epic for user authentication overhaul"
```

### Create Bug Report
```bash
# AI will use bug template with reproduction steps
"Create bug - login page blank on Safari after deploy"
```

### Sprint Planning
```bash  
# AI will review Ready items, calculate velocity, propose sprint
"Plan next sprint for the team"
```

### Triage Backlog
```bash
# AI will suggest priorities, sizes, and labels
"Triage all unprocessed issues"
```

## 📈 Project Health Monitoring

The AI project manager can now:
- Create rich, structured issues with complete context
- Estimate work based on codebase complexity
- Move issues through workflow states automatically  
- Generate standup reports and progress summaries
- Track epic progress and completion percentages
- Identify blocked items and suggest re-prioritization

## 🔄 Next Steps

1. **Create Issues**: Start creating structured issues for your backlog
2. **Sprint Planning**: Use AI to plan your next development sprint  
3. **Team Onboarding**: Share this setup with your development team
4. **Integration**: Configure CI/CD to update project board automatically

---

*This setup enables invisible AI project management - keeping GitHub Projects in perfect sync with actual development work.*