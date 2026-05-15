---
name: ralph
description: "Set up sandboxed Claude Code ralph loops for any project (Ruby/Node/Python/Go/etc.). Makes a project 'ralphable' by generating hardened Docker sandbox infrastructure (Dockerfile, firewall, audited MCP tool surface, masked sensitive files, launcher) plus the loop protocol (PROMPT.md), specs (specs/*), implementation plan (IMPLEMENTATIONPLAN.md), and per-project security manifest (ralph.config.yaml). The loop runs unattended with no Bash, no built-in tools, and a narrow network allowlist — secure-by-design. Use when the user mentions: ralph, ralph loop, sandbox, sandboxed loop, autonomous loop, ralphable, IMPLEMENTATIONPLAN, implementation plan for ralph, or wants to set up unattended Claude Code development loops. Also triggers for /ralph, /ralph init, /ralph plan, /ralph prepare."
---

# Ralph — Secure-by-Design Sandboxed Loop Setup

Ralph loops run Claude Code autonomously inside a Docker sandbox with:

- **No Bash, no Edit/Write/Read, no WebFetch/WebSearch.** The loop sees only an audited MCP tool surface (`ralph_tools`) — typed verbs like `run_tests`, `git_commit`, `write_workspace_file`. Built-in tools are stripped via `--tools ""`.
- **Default-deny network.** Outbound traffic is blocked except for `api.anthropic.com` plus a per-project allowlist the planner declares.
- **No host filesystem.** The loop sees a sandboxed copy of the workspace with sensitive files (`.env`, `master.key`, etc.) replaced by masked variants. The host's real files are never inside the container.
- **Hardened container.** No NOPASSWD sudo, no NET_ADMIN/NET_RAW on the workload container, `--read-only` root, `no-new-privileges`, dropped caps, resource limits.
- **No host LLM escape.** The previously dangerous "press y to launch host claude on BLOCKED" path is removed. The loop exits cleanly and the human reads the Blocked section.

This skill makes any project ralphable by generating the infrastructure described below.

---

## Subcommands

Parse the user's input to determine which subcommand. Default to `init` if they say "ralph" or "make this project ralphable." Use `plan` if they describe a feature to build or want to refresh specs.

### `/ralph init`

Generates the sandbox scaffold + the per-project security manifest. Does **not** write specs or plan — that's `/ralph plan`. After `init`, the project has the infrastructure to run loops; after `plan`, it has the content to drive them.

#### Step 1: Detect the project stack

Ask the user (or detect from project markers) which stack this is. Examples:
- **Ruby/Rails**: `.ruby-version` or `Gemfile` present. `lint_cmd: "bundle exec rubocop -a"` (or `bundle exec standardrb --fix` if standard is in Gemfile). `test_cmd: "bundle exec rspec"` (or `bundle exec rails test` if minitest only). `install_cmd: "bundle install --frozen"`.
- **Node.js**: `package.json` present. `lint_cmd: "npm run lint"` (or whatever the project defines). `test_cmd: "npm test"`. `install_cmd: "npm ci"`.
- **Python**: `pyproject.toml`, `setup.py`, or `requirements.txt`. `lint_cmd: "ruff check --fix"` (or whatever's configured). `test_cmd: "pytest"`. `install_cmd: "pip install -r requirements.txt"` or `poetry install --no-root` etc.
- **Go**: `go.mod`. `lint_cmd: "golangci-lint run --fix"`. `test_cmd: "go test ./..."`. `install_cmd: "go mod download"`.

Report what was detected. Confirm with the user before continuing.

#### Step 2: Generate per-project files

Read `references/templates.md` for the canonical templates. Generate:

1. **`ralph.config.yaml`** — the security manifest. The CENTERPIECE of the new design; everything else derives from it. Use the schema documented in `references/templates.md § ralph.config.yaml`. Mandatory fields:
   - `schema_version: 1`
   - `stack: { lint_cmd, test_cmd, install_cmd }` from detection
   - `git_commit: { author_name, author_email }`
   - `quotas: { max_tool_calls: 200, max_bytes_read: 50_000_000, max_bytes_written: 5_000_000 }` (sensible defaults)
   - `sensitive_paths`: a sensible default for the stack (e.g., `.env`, `config/master.key`, `config/credentials*.yml.enc` for Rails; `.env.local` for Node/Python; etc.) — the launcher always also injects `ralph.config.yaml`, `bin/ralph`, `.ralph/**`, `PROMPT.md`, `IMPLEMENTATIONPLAN.md`, `specs/**`.
   - `network.allowed_domains: ["api.anthropic.com"]` — the loop's default network floor; `/ralph plan` will add more if the implementation needs them.
   - `mcp_servers: []` — empty by default; `/ralph plan` may add `context7`, `postgres-readonly`, etc.

2. **`bin/ralph`** — a one-line shim:
   ```bash
   #!/usr/bin/env bash
   exec "${RALPH_HOME:-$HOME/.claude/ralph}/ralph" "$@"
   ```
   Note that `bin/ralph` is in `sensitive_paths` — the loop cannot rewrite it.

3. **`PROMPT.md`** — copy from `references/templates.md § Loop Protocol`. Customize the project-specific notes section if the stack has quirks (e.g., "Rails: schema is in `db/schema.rb`, not migrations").

4. **`.gitignore` additions**:
   ```
   log/ralph.jsonl
   .ralph/sandbox-workspace/
   .ralph/masked/
   .ralph/last-audit.json
   .ralph/firewall-input.txt
   .ralph/mcp.json
   .ralph/build-context/
   ```
   (The audit report `.ralph/audit.md` IS committed so the team can review it. Everything else is per-machine state.)

5. `chmod +x bin/ralph`.

#### Step 3: Tell the user the next step

```
Run `/ralph plan` to:
  - Research the feature you want to build
  - Write specs/*.{md,html,json} with pre-fetched docs and schema info
  - Generate IMPLEMENTATIONPLAN.md
  - Finalize ralph.config.yaml (MCP servers, network allowlist, masked env vars)
  - Build the image and run an audit
```

---

### `/ralph plan` (or `/ralph prepare`)

The intellectual work. Runs on the **host** `claude` session (not in the container). Produces everything the loop needs to run unattended.

This subcommand is the security boundary in the new design: the planner decides ahead of time what network access, MCP servers, and masked env vars the loop needs. The loop runs against a minimum environment derived from those decisions.

#### Step 1: Understand the feature

Ask the user (if they haven't already described it). Capture:
- What the feature does
- Constraints, edge cases
- What's in scope vs. out of scope

#### Step 2: Analyze the codebase

Read:
- Existing patterns and conventions
- Where new code goes; what changes
- Data models, API surfaces, dependencies
- Tests and how they're structured

Importantly: **enumerate every external dependency the implementation will need**, including:
- Libraries the loop must look up docs for → pre-fetch via context7 into `specs/`
- Database schema info → snapshot via `mcp__postgres__query` into `specs/`
- API endpoints / sample payloads → save into `specs/`
- Configuration knobs → describe in specs

The loop has **no WebFetch**. If a bullet would need fresh docs, you must pre-fetch them now.

#### Step 3: Write specs (markdown, HTML, or JSON — whichever's simplest per artifact)

Create `specs/*.{md,html,json}`. Each spec covers a logical area. Use slug filenames.

```markdown
# <Spec Title>

## Goal
<What this part of the feature accomplishes>

## Constraints
- <Hard requirements, perf targets, compatibility>

## Design
<Data models, API shapes, flow diagrams, algorithm choices, code snippets>

## Edge Cases
- <Scenario> — <how it's handled>

## Out of Scope
- <Things not covered>

## Pre-fetched references
- <Library docs, schema snapshots, sample payloads — inline or linked to another spec>
```

HTML is fine for fetched doc pages or tables. JSON is fine for structured inputs.

Specs are in `sensitive_paths`; the loop reads them via the MCP `read_workspace_file` tool but cannot edit them.

#### Step 4: Generate `IMPLEMENTATIONPLAN.md`

```markdown
# <Feature Name>

## <Section 1 — e.g., "Database layer">
- [ ] <Task> — edit/create `<path>` (see `specs/<name>.md` § <heading>)
- [ ] <Task> — edit/create `<path>` (see `specs/<name>.md`)

## <Section 2 — e.g., "API endpoints">
- [ ] <Task> — edit/create `<path>` (see `specs/<name>.md`)

## Blocked

## Followups
```

Rules:
- Each task cites the file to change AND the spec.
- Tasks are small enough for one ralph iteration.
- Tasks within a section are in dependency order.
- Plan mutation happens through `mark_*` MCP tools only — the loop cannot rewrite the plan otherwise.

#### Step 5: Self-sufficiency check (the new step)

For each bullet, walk through what the loop would need to complete it:

- **Network access?** Note every external host the test/lint/install commands or the project's runtime code touches. If anything beyond `api.anthropic.com` is needed, add it to `ralph.config.yaml > network.allowed_domains`.
- **MCP servers?** If a bullet would benefit from live library docs, add `context7`. If it touches the database in any non-trivial way, add `postgres-readonly` (and note that `RALPH_POSTGRES_DSN` must be set with a read-only role). If the planner already pre-fetched everything into `specs/`, you don't need these MCPs.
- **Env vars?** Grep the source for `ENV[`, `process.env.`, `os.getenv`, etc. Add referenced names to `masked_env_vars` so the test process sees a masked value with the right key.
- **External dependencies?** If a bullet requires a new gem/npm/pip package, add it to `install_cmd` deps (commit the lockfile change) so `bundle install --frozen` etc. has everything pre-installed. The loop does NOT install new deps.
- **Unmaskable inputs?** If a bullet truly needs a real secret (e.g., calling Stripe in tests with a real-looking key), record that as a planning concern — usually the right answer is to mock the dependency in tests and skip touching production credentials.

If the check surfaces something missing, **fix the manifest or pre-fetch the content now**. Don't punt to the loop.

#### Step 6: Generate masked sensitive files

Run:
```bash
bin/ralph mask-env
```
This deterministic helper (no LLM) reads the real `.env` etc. from host disk and writes masked variants to `$ROOT/.ralph/masked/`. **You should not read the real `.env` yourself** — let the helper do it.

#### Step 7: Build the image and audit

```bash
bin/ralph build
bin/ralph up
bin/ralph audit > /dev/null   # also writes .ralph/audit.md
```

The audit will:
- Confirm only the declared domains are reachable (probes example.com → fails, api.anthropic.com → succeeds)
- Confirm sensitive paths in `/workspace/.env` etc. contain masked content
- Confirm the container has no NET_ADMIN, runs read-only, has no-new-privileges, etc.
- Stamp `.ralph/last-audit.json` with the manifest's sha256

#### Step 8: Have the human review `.ralph/audit.md`

Print the audit summary and tell the user to open `.ralph/audit.md` and confirm the boundary matches their intent. **This is a required gate, not a self-check.** Reason: the planner LLM is itself hijackable (poisoned README in a dep, malicious MCP response) and could write a permissive manifest while claiming everything is locked down.

Once the human signs off, the manifest is locked in: any subsequent edit to `ralph.config.yaml` invalidates the audit, and `bin/ralph ralph` will refuse to start until `bin/ralph audit` is re-run.

---

## Running the loop

After `/ralph plan` finishes and the audit is reviewed, the user runs:

```bash
bin/ralph ralph 10              # up to 10 iterations
bin/ralph ralph --budget 5      # until cumulative cost hits $5
bin/ralph progress              # show plan completion
```

No `--allowed-tools`, no `--dangerously-skip-permissions`, no manual MCP selection. Everything derives from the manifest.

---

## Loop termination conditions

The loop terminates when:
- The LLM calls `mark_all_done()` (no `- [ ]` bullets remain in the plan).
- The LLM calls `mark_blocked()` (a bullet can't be completed; reason recorded).
- The configured iteration count is reached.
- The configured cost budget is reached.
- Per-iteration quotas (`max_tool_calls`, `max_bytes_read`, `max_bytes_written`) exceed their cap — the iteration terminates with `mark_blocked: quota exhausted`.

There is **no auto-relaunch of host `claude`** when the loop blocks. The Blocked section is printed and the loop exits.

---

## What changed from the old skill

For users coming from the old Ruby-specific ralph skill:

- **Stack-agnostic.** No longer assumes Ruby/Rails; works with Node, Python, Go, anything.
- **No Bash in the loop.** The MCP `ralph_tools` is the only tool surface. The loop can't `gem install evil-gem` or `curl evil.com`.
- **`ralph.config.yaml` replaces ad-hoc per-project `bin/ralph` customizations.** Lint/test/install commands live in the manifest, not in the launcher.
- **Default-deny egress.** The firewall starts with just `api.anthropic.com`; everything else is opt-in.
- **Sensitive files are masked at host-mount level.** The loop sees fake `.env` content with real variable names. The real file never enters the container.
- **`bin/ralph plan` is gone.** Planning runs on the host `claude` session, not in the container. This is much more capable (full tool surface) and avoids the BLOCKED-resume host-claude escape.
- **`bin/ralph audit` is required.** No loop run without a current audit on record.
- **Worktree support is dropped in v1.** Require regular `.git`-directory repos.

See `references/security.md` for the full threat model and verification procedure.

## Where everything lives

- `~/.claude/ralph/ralph` — the launcher (authoritative; project's `bin/ralph` is a shim).
- `~/.claude/ralph/Dockerfile` — base image, parameterized by manifest.
- `~/.claude/ralph/init-firewall.sh` — runs in the init container.
- `~/.claude/ralph/claude-settings.json` — bind-mounted ro for the loop.
- `~/.claude/ralph/mask-env.js` — deterministic helper to generate masked sensitive files.
- `~/.claude/ralph/ralph-tools/` — the MCP server source (baked into the image at build).
- `~/.claude/commands/ralph/SKILL.md` — this file.
- `~/.claude/commands/ralph/references/templates.md` — canonical templates for generated files.
- `~/.claude/commands/ralph/references/security.md` — threat model + audit checklist.
