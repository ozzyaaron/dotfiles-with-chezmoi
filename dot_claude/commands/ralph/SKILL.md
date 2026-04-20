---
name: ralph
description: "Set up sandboxed Claude Code ralph loops for Ruby/Rails projects. Makes a project 'ralphable' by generating Docker sandbox infrastructure (Dockerfile, firewall, launcher script), loop protocol (PROMPT.md), specs (specs/*.md), and implementation plans (IMPLEMENTATIONPLAN.md). Use this skill when the user mentions: ralph, ralph loop, sandbox, sandboxed loop, autonomous loop, ralphable, IMPLEMENTATIONPLAN, implementation plan for ralph, or wants to set up unattended Claude Code development loops. Also triggers for /ralph, /ralph init, /ralph prepare. This skill handles the FULL scaffolding — not just stubs."
---

# Ralph — Sandboxed Claude Code Loop Setup

Ralph loops run Claude Code autonomously inside a sandboxed Docker container with a network firewall, iterating through an implementation plan until all tasks are complete or a blocker is hit.

This skill makes any Ruby/Rails project "ralphable" by generating all the infrastructure needed to run these loops safely.

## Subcommands

Parse the user's input to determine which subcommand they want. Default to `init` if they just say "ralph" or "make this project ralphable." Use `prepare` if they mention specs, planning, or a feature they want to build.

### `/ralph init`

Generate the full sandbox infrastructure for the current project.

**Step 1: Detect the project stack**

Read the project root to identify:
- **Ruby version**: Read `.ruby-version`
- **Framework**: Rails if `config/routes.rb` exists
- **Database**: Check `docker-compose.yml`, `config/database.yml` for postgres, mysql, sqlite
- **Existing Docker setup**: Check for `Dockerfile`, `docker-compose.yml`

Report what you found to the user before generating files.

**Step 2: Generate files**

Generate these files by reading the reference templates and customizing for the detected stack. Read `references/templates.md` for the complete file templates — it contains production-quality versions of every file, with `{{PLACEHOLDER}}` markers for the parts you customize per-project.

Files to generate:

1. **`docker/ralph/Dockerfile`** — Read `references/templates.md` § Dockerfile. Set `RUBY_VERSION` from `.ruby-version`. Include Ruby/Rails system packages (`libpq-dev`, `libyaml-dev`, `libvips`, etc. based on what the project uses).

2. **`docker/ralph/init-firewall.sh`** — Read `references/templates.md` § Firewall. Includes `rubygems.org` and `index.rubygems.org` in the domain whitelist. Scan config files for any project-specific external API domains to add.

3. **`docker/ralph/rtk-rewrite.sh`** — Copy verbatim from `references/templates.md` § RTK Hook. Identical across all projects.

4. **`docker/ralph/claude-settings.json`** — Copy verbatim from `references/templates.md` § Claude Settings. Identical across projects.

5. **`bin/ralph`** — Read `references/templates.md` § Launcher. Customize:
   - `IMAGE` derived from project directory name (shared across worktrees)
   - `NAME` and volume names auto-suffixed with a hash of `$ROOT` (worktree-safe)
   - Volume names derived from project name
   - Dep install: `bundle install --quiet`
   - Dep volume: `/workspace/vendor/bundle`
   - Dep env: `BUNDLE_PATH=/workspace/vendor/bundle`

6. **`PROMPT.md`** — Read `references/templates.md` § Loop Protocol. Set:
   - Lint command: detect from `.rubocop.yml` → `bundle exec rubocop -a`, or `bundle exec standardrb --fix` if using standard
   - Test command: detect from `.rspec` → `bundle exec rspec`, or `bundle exec rails test` if using minitest
   - Model name: use the model currently powering this session for the commit trailer

7. **`.gitignore` additions** — Append `log/ralph.jsonl` and `log/*.log` if not already present.

**Step 3: Make executable**

Run `chmod +x bin/ralph docker/ralph/init-firewall.sh docker/ralph/rtk-rewrite.sh`.

**Step 4: Report**

Tell the user what was generated and give them the quickstart:
```
# One-time: generate a long-lived token
claude setup-token
# Store it in .env as CLAUDE_CODE_OAUTH_TOKEN=<token>

# Then:
op run --env-file=.env -- bin/ralph build
op run --env-file=.env -- bin/ralph up
op run --env-file=.env -- bin/ralph ralph 10
```

---

### `/ralph prepare`

Research the codebase, write detailed specs, and generate an implementation plan. This is the intellectual work — understanding the problem, making design decisions, and breaking the work into concrete steps the ralph loop can execute.

**Step 1: Understand the feature**

Ask the user to describe the feature if they haven't already. Get enough detail to understand:
- What the feature does
- Constraints and edge cases
- What's in scope vs. out of scope

**Step 2: Analyze the codebase**

Read relevant files to understand:
- Existing patterns and conventions
- Where new code should go
- What existing code needs to change
- What tests exist and how they're structured
- Data models, API surfaces, and dependencies involved

**Step 3: Write specs to `specs/*.md`**

Create one or more spec files under `specs/`. Each spec covers a logical area of the feature. Use a slug filename (e.g., `specs/notification-delivery.md`, `specs/api-endpoints.md`).

Spec structure:
```markdown
# <Spec Title>

## Goal

<What this part of the feature accomplishes>

## Constraints

- <Hard requirements, performance targets, compatibility needs>

## Design

<The actual design — data models, API shapes, flow diagrams, algorithm choices>
<Include code snippets for key interfaces/signatures where helpful>

## Edge Cases

- <Scenario> — <how it's handled>

## Out of Scope

- <Things explicitly not covered>
```

Rules for specs:
- Be specific and concrete — name tables, columns, methods, routes
- Reference existing source files that need to change (cite paths)
- Make design decisions here so the loop doesn't have to improvise
- Multiple specs are fine — split by logical boundary (e.g., data layer vs. API vs. UI)

**Step 4: Generate `IMPLEMENTATIONPLAN.md`**

Structure:
```markdown
# <Feature Name>

## <Section 1 — e.g., "Database layer">
- [ ] <Task description> — edit/create `<path>` (see `specs/<relevant-spec>.md`)
- [ ] <Task description> — edit/create `<path>` (see `specs/<relevant-spec>.md` § <heading>)

## <Section 2 — e.g., "API endpoints">
- [ ] <Task description> — edit/create `<path>` (see `specs/<relevant-spec>.md`)

## Blocked

## Followups
```

Rules:
- Tasks within a section are in dependency order (earlier tasks unblock later ones)
- Each task cites both the source file to change AND the spec section for lookup
- Tasks are small enough for one ralph iteration (one focused change + tests)
- Include a `## Blocked` section (initially empty — the loop populates it)
- Include a `## Followups` section (initially empty — for scope-creep notes)

**Step 5: Customize `PROMPT.md`**

Read the existing `PROMPT.md` (generated by `/ralph init`). Update it with project-specific details discovered during analysis:

- Files that should never be touched (credentials, generated code, vendored assets)
- External APIs or services the loop needs to interact with
- Project-specific coding conventions not captured by linter config
- Special test setup steps (e.g., "run `bin/rails db:test:prepare` before specs")
- Environment-specific notes (e.g., "use `SolidQueue` not Sidekiq for async jobs")

Keep the core loop protocol intact (choose → implement → verify → mark → commit). Only add/modify a `## Project-Specific Notes` section at the end.

**Step 6: Report**

Tell the user what specs were written and show the implementation plan summary. Ask if anything needs adjustment before running the loop.
