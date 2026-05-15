# Ralph Security Model — Threat Model & Verification

This document is the authoritative description of what the ralph sandbox defends against, how, and how to verify it. The planner reads this as a checklist during `/ralph plan`; the human reads it when reviewing `.ralph/audit.md`.

## Trust boundaries

**Trusted:**
- The host OS, the Docker daemon, the host kernel (Docker-on-Mac VM kernel boundary is the deepest line we draw).
- The user's host `claude` session during planning — interactive, user-supervised.
- The skill's `~/.claude/ralph/ralph` launcher script (installed via the skill).
- The `ralph-tools` MCP server binary baked into the image at build time.

**Untrusted:**
- The in-container claude session running the loop.
- Anything the in-container claude writes — including the plan file, audit report, manifest file in workspace, or its own commits — when those artifacts are subsequently read by anything outside the loop.
- The planner LLM itself when reading untrusted inputs (READMEs, third-party docs, MCP responses). Mitigation: the planner never reads real secret values; the human reviews the audit before any unattended run.

**Irreducible trust assumption:**
- **Workspace content read by the loop is sent to Anthropic via the API.** This is intrinsic to running an LLM in the loop. The planner controls what enters the workspace (via masked overlays), so project owners can bound it — but a leaked secret in a non-masked file IS exfiltrated to Anthropic by design.

## Threats addressed

| # | Threat | Defense |
|---|---|---|
| 1 | LLM calls `Bash` and runs arbitrary commands | `--tools ""` strips ALL built-in tools. `permissions.deny` in settings.json is defense-in-depth. |
| 2 | Compromised gem/npm package executes postinstall in the container | No outbound to package registries by default; `install_cmd` runs only via `install_dependencies` MCP tool which the LLM only calls when the manifest permits |
| 3 | LLM exfils data via WebFetch to attacker server | `--tools ""` removes WebFetch; firewall blocks non-allowlisted hosts |
| 4 | LLM reads `.env`/`master.key` and sends to Anthropic | Sensitive files are bind-overlaid with masked content. Real values never enter the container. |
| 5 | LLM force-pushes / amends / rewrites git history | `git_commit` MCP tool refuses amend/force/push. No general git access. |
| 6 | LLM rewrites bin/ralph or ralph.config.yaml to weaken the boundary | `sensitive_paths` includes both. `write_workspace_file` refuses. The MCP server reads its config from a ro-mounted `/etc/ralph/config.yaml`, not from the workspace. |
| 7 | LLM marks plan bullet `[x]` without doing the work | `IMPLEMENTATIONPLAN.md` is in `sensitive_paths`. The only path to mutate is `mark_*` MCP tools which validate transitions. |
| 8 | LLM falsifies the audit report | Audit lives in `.ralph/` which is `sensitive_paths`. `.ralph/last-audit.json` stamps a manifest sha256 the launcher re-checks. |
| 9 | Sandbox-to-host prompt-injection via BLOCKED auto-launch | The auto-launch path is removed entirely. Loop exits cleanly. |
| 10 | Loop persists across rebuilds via writable hook volume | Hooks/settings bind-mounted ro from `/etc/claude-defaults/`; no persistent volume. |
| 11 | Container escape via NET_ADMIN/sudo | Workload container has `--cap-drop=ALL`, `--security-opt=no-new-privileges`, no sudo. Firewall runs in a separate privileged init container that exits to `sleep`. |
| 12 | DNS-based bypass of network allowlist | DNS pinned to a single resolver (UDP/53 to that IP only). Loop can't change `/etc/resolv.conf` (read-only root). |
| 13 | Outbound SSH (22) exfil | Default policy: TCP/22 dropped. |
| 14 | LLM symlinks `/workspace/x → /etc/passwd` and reads x | `read_workspace_file` resolves the path and rejects if it escapes `/workspace`. `apply_patch` rejects diff entries creating symlinks. |
| 15 | LLM writes attacker code into a future-iteration's input | `PROMPT.md`, `IMPLEMENTATIONPLAN.md`, `specs/**` are all in `sensitive_paths`. |
| 16 | Runaway loop forks until host OOMs | Container has `--memory=4g --pids-limit=1024 --cpus=2`. Per-iteration `quotas` cap tool calls and bytes. |
| 17 | OAuth token leaks to test subprocess env | `subprocess.js` strips `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_API_KEY`, etc. before spawning lint/test/install. |
| 18 | String-grep sentinel terminates loop incorrectly when assistant echoes a sentinel string | Sentinels are structured MCP tool calls (`mark_complete`, `mark_blocked`, `mark_all_done`); no string matching. |
| 19 | Planner LLM leaks real secrets to Anthropic when generating masked variants | The planner LLM only enumerates env var *names*; a deterministic `bin/ralph mask-env` script reads real files and writes fakes. The LLM never reads secret values. |
| 20 | Compromise persists across container restarts via writable volume | Removed all writable volumes for ralph state. All persistent state lives on the host workspace (auditable) or in tmpfs (ephemeral). |

## Threats NOT addressed (residual risk)

- **Workspace content reaches Anthropic.** Any file the LLM reads via `read_workspace_file` is sent up. If a project commits secrets into a non-masked path, those secrets are exfiltrated by design. Mitigation: keep secrets in `.env`/credentials files that are in `sensitive_paths`.
- **Compromise of the ralph-tools MCP server binary itself.** Pinned + checksummed by the planner at image build. If the upstream is compromised between releases, this design has no defense.
- **Compromise of Claude Code or upstream Anthropic.** Out of scope.
- **Compromise of the host kernel / Docker daemon.** Mitigations require hypervisor isolation (e.g., Firecracker, Apple Virtualization.framework) which is out of v1 scope.
- **Pre-commit hooks installed by a compromised project dependency.** The hook runs inside the container, which is heavily bounded, but it does run. Mitigation: set `git_commit.skip_hooks: true` in the manifest to bypass project hooks entirely (at the cost of skipping legitimate ones).
- **Resource exhaustion on the host's docker storage.** A loop that writes many files within `max_bytes_written` quota can still consume host disk. Mitigation: a tmpfs-backed workspace, but that conflicts with persistence — deferred.

## Verification — what to look for in `.ralph/audit.md`

After running `bin/ralph audit`, the report at `.ralph/audit.md` must show:

**Mounts section:**
- `/workspace` mounted from `<project>/.ralph/sandbox-workspace`
- `/etc/ralph/config.yaml` mounted ro
- `/etc/ralph/masked` mounted ro
- `/etc/ralph/mcp.json` mounted ro
- `/etc/claude-defaults/settings.json` mounted ro
- No mount for parent `.git`, no mount for `host.docker.internal`-related paths

**Container capabilities section:**
- `Caps added: <empty>; dropped: ALL`
- `ReadonlyRootfs=true`
- `SecurityOpt=[no-new-privileges]`
- `Memory=4294967296 PidsLimit=1024`

**Env section:**
- No entries with raw token values; everything visible is either masked or a non-credential variable
- `CLAUDE_CONFIG_DIR=/home/ralph/.claude` present
- `CLAUDE_CODE_OAUTH_TOKEN=<masked>` or `ANTHROPIC_API_KEY=<masked>` present (auth must be configured; the audit just confirms it's not in cleartext)

**Network policy section:**
- iptables-save output ends with `-P INPUT DROP / -P OUTPUT DROP`
- `ipset list allowed-domains` includes only the IPs for `api.anthropic.com` plus the manifest's declared domains

**Active probes section:**
- `example.com (should fail): ok (denied)`
- `api.anthropic.com (should succeed): ok (reachable)`

**Sensitive files section:**
- `.env` content begins with `KEY=M...` or fake URLs — NOT a real connection string or API key
- `config/master.key` is `00000000…` not the real key

If any of these checks reads wrong, fix the manifest and re-audit. Do not start the loop.

## What to do when the audit gate fails

The launcher refuses `bin/ralph ralph` if:
- No `.ralph/last-audit.json` exists (no audit has ever run).
- The manifest's current sha256 differs from the audited one (manifest was edited since the audit).

To unblock: run `bin/ralph audit` and re-review `.ralph/audit.md`.

This is intentional friction. The audit is a human gate; any manifest change has to be re-confirmed by the human, not by the planner LLM alone.
