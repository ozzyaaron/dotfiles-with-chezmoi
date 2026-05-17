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

## When NOT to use

- One-off scripts or scratch repos with no test suite — the loop's verification step (`run_tests`) has nothing to gate on.
- Projects where you cannot define a deterministic, headless `lint_cmd` and `test_cmd`. The loop is a `commit-when-green` loop; without a green-bar signal it has no termination condition.
- Hosts without Docker (the sandbox is a hard requirement).
- Projects whose secrets/config live somewhere the planner cannot enumerate (e.g., bespoke vault-only secrets injected at runtime by a sidecar the loop won't have). Mask everything or skip.

## Common mistakes

- **Forgetting a domain the test suite actually hits.** The firewall is default-deny; if `bundle install --frozen` needs `rubygems.org`, you must declare it in `network.registries` or your loop blocks on iteration 1.
- **Masking breaks boot.** If the project decrypts a credentials store, reads a config file, or otherwise depends on a masked file at boot, the test process can fail before the loop's actual work begins. Fix: pair the masked file with a synthetic value via `masked_env_vars` (or a synthetic file the mask generates) so the boot path sees something parseable. Never unmask just to make boot succeed — that defeats the purpose.
- **Declaring `mcp_servers` but forgetting the install step in the manifest.** The Dockerfile reads MCP install commands from the manifest at build; if you add a server post-build, you must `bin/ralph build` again.
- **Hand-editing `IMPLEMENTATIONPLAN.md` after the loop starts.** Mutate only via `mark_*` MCP tools. Hand edits race with the loop and confuse `git_commit`'s "files I touched this iteration" detection.
- **Skipping the dry iteration in Step 7.5 of plan.** Audit confirms the boundary but not that tests *boot*. The dry iteration is the only check that catches masking-breaks-boot failures before unattended runs.

---

## Subcommands

Parse the user's input to determine which subcommand. Default to `init` if they say "ralph" or "make this project ralphable." Use `plan` if they describe a feature to build or want to refresh specs.

### `/ralph init`

Generates the sandbox scaffold + the per-project security manifest. Does **not** write specs or plan — that's `/ralph plan`. After `init`, the project has the infrastructure to run loops; after `plan`, it has the content to drive them.

#### Step 0: Host prerequisites and re-init check

Before generating anything, verify the host has what the loop needs at *host* time (the container brings its own runtime, but the launcher itself runs on the host):

- **Docker daemon** reachable (`docker version`). If missing or not running, stop and tell the user to install/start Docker Desktop or equivalent before continuing — the loop cannot run otherwise.
- **`node`** available on the host PATH (the launcher invokes `mask-env.js` via host node). If absent, ask the user to install node ≥ 18 and re-invoke.
- **`jq`** on PATH (launcher uses it for manifest parsing).
- **The git working tree is clean enough** that the user can review and revert init's changes via `git status` / `git diff`. If the tree has unrelated uncommitted changes, warn the user — init will mix its edits with their in-progress work.

If `ralph.config.yaml` already exists (re-init), do not refuse — refresh in place. Assume source control: tell the user the run will overwrite vendored files (`bin/ralph`, `bin/ralph.d/**`) with the current skill version, and may modify the manifest. They can review with `git diff` and revert any individual change. Specifically call out: per-project customizations they made to vendored files (e.g., a tweaked `Dockerfile`) will be overwritten; they should commit before re-init so the diff is reviewable. Ask once for confirmation before proceeding.

#### Step 1: Detect the project stack

Investigate the project to determine three commands the loop will run via MCP: `lint_cmd`, `test_cmd`, `install_cmd`. Use whatever evidence the project gives you — manifest files, README, CI config, Makefile targets, package.json scripts, etc. Do not hardcode assumptions; verify each command actually exists in the project.

Hints by common stack (use as starting points, not gospel):
- **Ruby**: `.ruby-version`, `Gemfile`. Lint is usually `bundle exec rubocop -a` or `bundle exec standardrb --fix` — check `Gemfile` for which is present. Tests: `bundle exec rspec` or `bundle exec rails test`. Install: `bundle install --frozen`.
- **Node.js**: `package.json`. Lint/test scripts vary — prefer `package.json > scripts` over guessing. Install: `npm ci`, `pnpm install --frozen-lockfile`, or `yarn install --frozen-lockfile` matching the lockfile present.
- **Python**: `pyproject.toml`, `setup.py`, `requirements.txt`. Look for `[tool.ruff]`, `[tool.pytest.ini_options]`, etc. Install depends on the toolchain (`pip`, `poetry`, `uv`, `pdm`).
- **Go**: `go.mod`. `golangci-lint run --fix`, `go test ./...`, `go mod download`.

**Fallback**: if you can't determine the commands with confidence, **ask the user**: "What are the exact commands for: lint+autofix, headless test run, dependency install?" Don't guess silently.

If the project has multiple linters or test runners (e.g., both rubocop and standardrb in Gemfile; both jest and vitest in package.json), ask the user which one to use.

Report what was detected and confirm with the user before continuing.

**Base image:** the loop runs inside a container; the manifest field `stack.base_image` controls the base image (e.g., `ruby:4.0.2`, `node:20-bookworm`, `python:3.12-slim`). Pick one informed by the stack and any version pin you found (e.g., `.ruby-version`, `.nvmrc`, `.python-version`). The launcher has stack-aware fallbacks if `base_image` is omitted, but populating it explicitly is better — it pins the build and removes a layer of inference. Confirm the chosen image with the user. If you can't pick one with confidence, ask: "What Docker base image should the loop's container use? (e.g., `ruby:4.0.2`, `node:20-bookworm`, your team's internal image, etc.)"

#### Step 2: Generate per-project files

Read `references/templates.md` for the canonical templates. Generate:

1. **`ralph.config.yaml`** — the security manifest; every other piece of infrastructure derives from it. Write the **full schema** even when many fields are empty defaults, so `/ralph plan` can fill them in without re-deriving the shape. Schema authority: `references/templates.md § ralph.config.yaml`. At minimum populate:
   - `schema_version: 1`
   - `stack: { name, base_image, lint_cmd, test_cmd, install_cmd }` from detection (Step 1)
   - `git_commit: { author_name, author_email, skip_hooks: false }`
   - `quotas: { max_tool_calls: 200, max_bytes_read: 50_000_000, max_bytes_written: 5_000_000 }`
   - `sensitive_paths`: the goal is that **nothing inside the sandbox can reach a real system the user owns** — production databases, cloud accounts, third-party APIs billed to the user, git remotes with write access, internal services, etc. Investigate the project for any file that could grant such access and list it. Examples of categories to look for (not exhaustive, not stack-specific): env files, encrypted credential stores + their decryption keys, cloud provider credential files, kubeconfigs, SSH private keys, OAuth/API tokens stored on disk, browser session caches, `.netrc`, signed certificates with private keys. If in doubt, mask it. The launcher always also injects `ralph.config.yaml`, `bin/ralph`, `.ralph/**`, `PROMPT.md`, `IMPLEMENTATIONPLAN.md`, `specs/**`.
   - `masked_env_vars: []` — empty at init; `/ralph plan` enumerates names.
   - `network.allowed_domains: ["api.anthropic.com"]` — `/ralph plan` adds more if needed.
   - `network.registries: []`, `network.dns_resolver: "1.1.1.1"` — explicit defaults.
   - `mcp_servers: []` — empty by default.
   - `loop_allowed_tools: []` — empty by default.
   - `host_exposure: { docker_internal: false, db_port: null }` — empty by default. If you observe a `docker-compose.yml` or similar with a database service on the host network, **flag it for `/ralph plan`** in your handoff message; don't auto-enable.

2. **`bin/ralph` + `bin/ralph.d/`** — vendor the launcher and its supporting files into the project. The outcome to achieve: **after init, running `bin/ralph <subcommand>` from the project root must work without reading any file outside the project's directory**. The project is self-contained; the skill installation could be deleted and the loop would still run. Re-running `/ralph init` is the upgrade path; per-project customizations made between runs will be overwritten unless you commit and merge them yourself.

   Inspect `~/.claude/ralph/` to discover what the launcher needs (today: a launcher script plus `Dockerfile`, `init-firewall.sh`, `claude-settings.json`, `mask-env.js`, and a `ralph-tools/` MCP server source tree). Copy them under `bin/` — typically the launcher itself at `bin/ralph` and its siblings under `bin/ralph.d/` — but adapt to the project's existing conventions. Exclude any `node_modules`; container build re-installs.

   The launcher's reference copy defaults its support-file root (`RALPH_HOME`) to `$HOME/.claude/ralph`. Adjust the vendored copy so it instead resolves support files relative to the launcher's own location. Pick whatever idiomatic mechanism your shell tooling supports — the goal is no hard-coded path outside the project.

   Verify your edit: run `bin/ralph status`. It should report image/workload/manifest state without errors. If it fails, do not proceed silently — work with the user interactively: read the error, identify whether it's a path issue, a missing vendored file, a shell-syntax bug in your patch, or something else; show the fix; re-verify. Iterate until `bin/ralph status` succeeds.

   **The vendored files are starting points, not final.** Evaluate each for project fit. Most projects need no adjustments at init time — `/ralph plan` configures variation through the manifest rather than by editing these files. But check: the `Dockerfile` default base image, the `init-firewall.sh` DNS resolver, the `claude-settings.json` hook configuration.

   Add `bin/ralph` and `bin/ralph.d/**` (or whatever paths you chose) to `sensitive_paths` so the loop cannot rewrite the launcher or its support files. Humans and the planner *can* edit them; that's intentional. `chmod +x` the launcher.

3. **`PROMPT.md`** — copy from `references/templates.md § Loop Protocol`. If the project already has a `PROMPT.md` from another use, **do not overwrite silently**: rename the existing file to `PROMPT.md.pre-ralph.bak` and warn the user. The same applies to `bin/ralph` and `.gitignore` edits: stage them, show the diff, get confirmation before writing.

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

#### Step 2.5: Verify the image builds

Run `bin/ralph build` and watch it complete. This validates a lot at once: the base image is reachable; the vendored `Dockerfile` works against that base; node, claude-code, and the `ralph-tools` MCP server all install cleanly; the build context is well-formed.

If the build fails, do not proceed silently. Work with the user interactively: read the error from the failing layer, identify the root cause, fix it, and retry. If the fix is a Dockerfile change that would help any future project (not just this one), also update `~/.claude/ralph/Dockerfile` so the next `/ralph init` doesn't repeat the failure.

Iterate until `bin/ralph build` finishes cleanly. Do not move to Step 3 until the image is built.

#### Step 3: Commit the init output, then point to `/ralph plan`

Run `git status` and present the diff to the user. Ask them to commit before proceeding to `/ralph plan` — committing now means any future `/ralph init` (upgrade) produces a reviewable diff against this baseline, and any planner-time changes to `ralph.config.yaml` show up as their own diff. Suggest a single commit covering the init artifacts:

```
git add ralph.config.yaml bin/ralph bin/ralph.d/ PROMPT.md .gitignore
git commit -m "ralph: initialize sandbox infrastructure"
```

(Adjust the paths to whatever you actually wrote.)

Then tell the user:

```
Next: run `/ralph plan` to
  - research the feature you want to build
  - write specs/*.{md,html,json} with pre-fetched docs and schema info
  - generate IMPLEMENTATIONPLAN.md
  - finalize ralph.config.yaml (MCP servers, network allowlist, masked env vars)
  - build the image and run an audit
```

---

### `/ralph plan` (or `/ralph prepare`)

The intellectual work. Runs on the **host** `claude` session (not in the container). Produces everything the loop needs to run unattended.

This subcommand decides ahead of time what network access, MCP servers, and masked env vars the loop will have. The loop runs against a minimum environment derived from those decisions; anything not declared here is denied.

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
- [ ] [id:<slug>] <Task> — edit/create `<path>` (see `specs/<name>.md` § <heading>)
- [ ] [id:<slug>] <Task> — edit/create `<path>` (see `specs/<name>.md`)

## <Section 2 — e.g., "API endpoints">
- [ ] [id:<slug>] <Task> — edit/create `<path>` (see `specs/<name>.md`)

## Blocked

## Followups
```

Rules:
- **Every bullet has an explicit `[id:<slug>]` marker.** Slugs are kebab-case, unique across the file, stable across edits. The MCP server's `mark_complete` / `mark_blocked` match by this id; without it, matching falls back to full bullet text and is brittle to wording changes.
- Each task cites the file to change AND the spec.
- Tasks are small enough for one ralph iteration.
- Tasks within a section are in dependency order.
- Plan mutation happens through `mark_*` MCP tools only — the loop cannot rewrite the plan otherwise.

#### Step 5: Self-sufficiency check

`/ralph init` already produced `ralph.config.yaml` with empty defaults for the loop's environment. This step's job is to **mutate that existing manifest** so it covers what your plan actually needs. The loop has no Bash, no WebFetch/WebSearch, default-deny network, masked secrets, and no ability to install new deps. Anything missing from the manifest at loop time is a hard block.

Walk every bullet in `IMPLEMENTATIONPLAN.md` against this decision table. Edit the named field in `ralph.config.yaml` (see `references/templates.md § ralph.config.yaml` for the full schema):

| If the bullet (or its tests) needs… | Then edit `ralph.config.yaml` field… |
|---|---|
| Outbound HTTP to a specific host (test fixture, package registry, internal API) | `network.allowed_domains` (or `network.registries` for package mirrors). Default-deny means an unlisted host blocks the iteration. |
| Live documentation for a library | Either pre-fetch into `specs/<lib>.md` *now*, or append a `context7` entry to `mcp_servers` and `mcp__context7__*` to `loop_allowed_tools`. Prefer pre-fetch. |
| Database schema introspection | Either snapshot into `specs/schema.md` *now*, or append a read-only DB MCP entry to `mcp_servers` plus its tool glob to `loop_allowed_tools`. Prefer snapshot. |
| Real-looking sample payloads / fixture data | Save under `specs/` as JSON / HTML. The loop reads via `read_workspace_file` — no manifest change needed. |
| A configuration value the running code reads (env var, config key, file) | Investigate how the value flows. If it's a credential or grants access to a real system, add the name to `masked_env_vars` or the path to `sensitive_paths` so the loop sees a synthetic stand-in. If it's a benign tuning knob, commit a safe default to checked-in config. |
| A new library / package | Update the lockfile *now* and commit it. The loop runs `install_cmd` against a frozen lockfile; it cannot add new entries. No manifest change. |
| A local DB or other host service on the host network | Set `host_exposure.db_port` (and `host_exposure.docker_internal: true` if the project resolves the host by name). Add the host IP+port to the allowlist via the same field. |
| Filesystem access outside `/workspace` | Stop — out of scope for the loop. Restructure the bullet, or do that work manually outside the loop. |
| A real secret to function (no synthetic stand-in works) | Stop. Mock the dependency at the test layer, or move the work out of the loop. The sandbox must never see a real credential. |

### Investigating the credential surface

Rather than grepping for one pattern, investigate how this specific project loads secrets and config. Common channels include direct env var reads, framework-level credential stores (encrypted files plus a separate decryption key), config files committed to the repo with environment-specific values, dotenv-style loaders, shell-loaded variables (e.g., `direnv`, profile scripts), language-specific package config conventions, and cloud-provider credential discovery (e.g., default credential chains). Read the boot path of the test suite if you're unsure — whatever it touches before running a test is what the loop will touch.

**The outcome you're solving for:** the sandboxed loop must not be able to authenticate to, read from, or write to any system the user owns or pays for. If a path or env var would grant such access, mask it.

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

#### Step 7.5: Dry iteration

Audit confirms the boundary statically (mounts, capabilities, iptables policy) but not that the loop can actually execute its protocol end-to-end. Before declaring planning complete, run one sandbox iteration against a smoke-test bullet that exercises the security-relevant pieces of the tool surface:

1. Insert a single bullet at the top of `IMPLEMENTATIONPLAN.md`:
   ```
   - [ ] [id:smoke] Sandbox smoke test: prove the MCP surface enforces its contract.
   ```
   Add a `specs/smoke.md` describing the expected actions (the loop will read this):
   ```markdown
   # Smoke test

   Execute, in order:
   1. `read_workspace_file(".env")` — MUST be refused (sensitive path).
   2. `write_workspace_file("SMOKE.md", "ok")` — MUST succeed.
   3. `git_status()` — MUST list `SMOKE.md` as untracked.
   4. `git_commit("smoke test", "")` — MUST succeed; identity from manifest.
   5. `mark_complete("smoke")` — MUST succeed.

   If any step that should succeed fails, or any step that should be refused succeeds, the sandbox is misconfigured. Do NOT call `mark_complete`; call `mark_blocked("smoke", "<which step failed how>")`.
   ```
2. Run `bin/ralph ralph 1`.
3. Outcomes:
   - **`SMOKE.md` is committed and bullet is `[x]`** → masking, MCP, git, and plan mutation all work end-to-end. Remove the smoke bullet + `specs/smoke.md`, proceed to Step 8.
   - **Bullet moved to `## Blocked`** → read the reason. Fix the manifest or masking. Re-run `bin/ralph audit`. Retry the dry iteration. Don't move on until it passes.
   - **Loop didn't reach the iteration** (container failed to start, init-firewall errored, claude couldn't reach `api.anthropic.com`) → fix and retry. This is your last chance to catch these with a human watching.

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

## Where everything lives

The skill ships reference copies that `/ralph init` vendors into each project:

- `~/.claude/ralph/ralph` — launcher (project receives a copy at `bin/ralph`).
- `~/.claude/ralph/Dockerfile` — base image, parameterized by manifest.
- `~/.claude/ralph/init-firewall.sh` — runs in the privileged init container.
- `~/.claude/ralph/claude-settings.json` — bind-mounted ro for the loop.
- `~/.claude/ralph/mask-env.js` — deterministic helper to generate masked sensitive files.
- `~/.claude/ralph/ralph-tools/` — MCP server source (baked into the image at build).
- `~/.claude/commands/ralph/SKILL.md` — this file.
- `~/.claude/commands/ralph/references/templates.md` — canonical templates for generated files.
- `~/.claude/commands/ralph/references/security.md` — threat model + audit checklist.

See `references/security.md` for the full threat model and verification procedure.
