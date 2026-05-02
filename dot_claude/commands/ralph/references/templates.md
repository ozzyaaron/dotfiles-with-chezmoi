# Ralph Template Reference

Complete, production-quality templates for every file `/ralph init` generates. Replace `{{PLACEHOLDER}}` markers with project-specific values. Copy sections marked "verbatim" without changes.

## Table of Contents

1. [Dockerfile](#dockerfile)
2. [Firewall (init-firewall.sh)](#firewall)
3. [RTK Hook (rtk-rewrite.sh)](#rtk-hook) — verbatim
4. [Claude Settings (claude-settings.json)](#claude-settings) — verbatim
5. [Baked Skills (docker/ralph/skills/)](#baked-skills)
6. [MCP Configuration (.mcp.json)](#mcp-configuration)
7. [Launcher (bin/ralph)](#launcher)
8. [Loop Protocol — Build Mode (PROMPT.md)](#loop-protocol)
9. [Loop Protocol — Plan Mode (PROMPT_plan.md)](#loop-protocol--plan-mode)

---

## Dockerfile

Read `.ruby-version` for the Ruby version. Customize system packages based on what the project uses (check Gemfile for pg, sqlite3, vips, etc.).

```dockerfile
ARG RUBY_VERSION={{RUBY_VERSION}}
FROM ruby:${RUBY_VERSION}

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

# Base tooling + firewall deps + Node 20 (for Claude Code CLI).
RUN apt-get update && apt-get install -y --no-install-recommends \
    less \
    git \
    procps \
    sudo \
    fzf \
    zsh \
    man-db \
    unzip \
    gnupg2 \
    gh \
    iptables \
    ipset \
    iproute2 \
    dnsutils \
    aggregate \
    jq \
    nano \
    vim \
    ca-certificates \
    curl \
    build-essential \
    libffi-dev \
    libyaml-dev \
{{SYSTEM_PACKAGES}}
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG USERNAME=ralph
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /usr/bin/zsh ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# Persist shell history across container restarts.
RUN mkdir /commandhistory && \
    touch /commandhistory/.bash_history && \
    chown -R ${USERNAME}:${USERNAME} /commandhistory

# npm global dir owned by non-root user.
RUN mkdir -p /usr/local/share/npm-global && \
    chown -R ${USERNAME}:${USERNAME} /usr/local/share

# Workspace + Claude config dir owned by non-root user.
RUN mkdir -p /workspace /home/${USERNAME}/.claude && \
    chown -R ${USERNAME}:${USERNAME} /workspace /home/${USERNAME}/.claude

ENV DEVCONTAINER=true
WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL -o /tmp/git-delta.deb "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    dpkg -i /tmp/git-delta.deb && \
    rm /tmp/git-delta.deb

# rtk — CLI proxy that minimizes LLM token consumption.
ARG RTK_VERSION=0.37.0
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
      arm64) RTK_TRIPLE=aarch64-unknown-linux-gnu ;; \
      amd64) RTK_TRIPLE=x86_64-unknown-linux-musl ;; \
      *)     echo "Unsupported arch: $ARCH"; exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/rtk.tar.gz "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-${RTK_TRIPLE}.tar.gz" && \
    tar -xzf /tmp/rtk.tar.gz -C /tmp && \
    install -m 0755 /tmp/rtk /usr/local/bin/rtk && \
    rm -rf /tmp/rtk /tmp/rtk.tar.gz

# Claude Code defaults baked into /etc so volume mount doesn't shadow them.
RUN mkdir -p /etc/claude-defaults/hooks /etc/claude-defaults/skills
COPY rtk-rewrite.sh /etc/claude-defaults/hooks/rtk-rewrite.sh
COPY claude-settings.json /etc/claude-defaults/settings.json
COPY skills/ /etc/claude-defaults/skills/
RUN chmod 0755 /etc/claude-defaults/hooks/rtk-rewrite.sh

# Firewall script (runs as root via sudo at container start).
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh && \
    echo "${USERNAME} ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/${USERNAME}-firewall && \
    chmod 0440 /etc/sudoers.d/${USERNAME}-firewall

# Update rubygems + reinstall bundler as root, before dropping privileges.
RUN gem update --system --no-document && gem install -N bundler

USER ${USERNAME}

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
ENV SHELL=/bin/zsh
ENV EDITOR=nano
ENV VISUAL=nano

ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(curl -fsSL https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git \
    -p fzf \
    -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
    -a "source /usr/share/doc/fzf/examples/completion.zsh" \
    -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    -x

RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Bundler config: keep gems in /workspace/vendor/bundle (the volume-mounted dir).
ENV BUNDLE_PATH=/workspace/vendor/bundle
```

### System packages to include based on project Gemfile

- `pg` gem → `libpq-dev`
- `sqlite3` gem → `sqlite3 libsqlite3-dev`
- `image_processing` or `vips` gem → `libvips`
- `mysql2` gem → `default-libmysqlclient-dev`
- Always include `libffi-dev libyaml-dev` (Ruby needs these)

---

## Firewall

Customize `{{PROJECT_EXTRA_DOMAINS}}` with any project-specific external API domains found in config files. Leave empty if none found.

```bash
#!/bin/bash
# Restrict outbound network to a small allowlist of hosts.
# Adapted from anthropics/claude-code reference devcontainer.

set -euo pipefail
IFS=$'\n\t'

# Preserve Docker's internal DNS NAT rules before flushing.
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# DNS, SSH, loopback always allowed.
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT  -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT  -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net

echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ] || ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi
while read -r cidr; do
    [[ "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]] || { echo "Bad GitHub CIDR: $cidr"; exit 1; }
    ipset add -exist allowed-domains "$cidr"
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Domains the sandbox needs to reach.
DOMAINS=(
    "rubygems.org"
    "index.rubygems.org"
    "objects.githubusercontent.com"
    "registry.npmjs.org"
    "deb.nodesource.com"
    "api.anthropic.com"
    "statsig.anthropic.com"
    "sentry.io"
    "statsig.com"
    "context7.com"
    "api.context7.com"
    "mcp.context7.com"
{{PROJECT_EXTRA_DOMAINS}}
)

# Extra domains from env var, space separated.
if [ -n "${RALPH_EXTRA_DOMAINS:-}" ]; then
    for d in $RALPH_EXTRA_DOMAINS; do
        DOMAINS+=("$d")
    done
fi

for domain in "${DOMAINS[@]}"; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "WARNING: Failed to resolve $domain (skipping)"
        continue
    fi
    while read -r ip; do
        [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || { echo "Bad IP for $domain: $ip"; continue; }
        ipset add -exist allowed-domains "$ip"
    done < <(echo "$ips")
done

# Allow traffic to the Docker host network (so sidecar DBs stay reachable).
HOST_IP=$(ip route | grep default | cut -d" " -f3)
[ -n "$HOST_IP" ] || { echo "ERROR: Failed to detect host IP"; exit 1; }
HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network: $HOST_NETWORK"
iptables -A INPUT  -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configuration complete; verifying..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: example.com reachable — firewall not enforcing"
    exit 1
fi
if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: api.github.com unreachable — firewall too restrictive"
    exit 1
fi
echo "Firewall verified."
```

---

## RTK Hook

**Copy verbatim** — identical across all projects.

```bash
#!/usr/bin/env bash
# rtk-hook-version: 3
# RTK Claude Code hook — rewrites commands to use rtk for token savings.
# Requires: rtk >= 0.23.0, jq

if ! command -v jq &>/dev/null; then
  echo "[rtk] WARNING: jq is not installed." >&2
  exit 0
fi

if ! command -v rtk &>/dev/null; then
  echo "[rtk] WARNING: rtk is not installed or not in PATH." >&2
  exit 0
fi

RTK_VERSION=$(rtk --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -n "$RTK_VERSION" ]; then
  MAJOR=$(echo "$RTK_VERSION" | cut -d. -f1)
  MINOR=$(echo "$RTK_VERSION" | cut -d. -f2)
  if [ "$MAJOR" -eq 0 ] && [ "$MINOR" -lt 23 ]; then
    echo "[rtk] WARNING: rtk $RTK_VERSION is too old (need >= 0.23.0)." >&2
    exit 0
  fi
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

REWRITTEN=$(rtk rewrite "$CMD" 2>/dev/null)
EXIT_CODE=$?

case $EXIT_CODE in
  0) [ "$CMD" = "$REWRITTEN" ] && exit 0 ;;
  1) exit 0 ;;
  2) exit 0 ;;
  3) ;;
  *) exit 0 ;;
esac

ORIGINAL_INPUT=$(echo "$INPUT" | jq -c '.tool_input')
UPDATED_INPUT=$(echo "$ORIGINAL_INPUT" | jq --arg cmd "$REWRITTEN" '.command = $cmd')

if [ "$EXIT_CODE" -eq 3 ]; then
  jq -n --argjson updated "$UPDATED_INPUT" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":$updated}}'
else
  jq -n --argjson updated "$UPDATED_INPUT" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"RTK auto-rewrite","updatedInput":$updated}}'
fi
```

---

## Claude Settings

**Copy verbatim** — wires the rtk hook. Identical across projects.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/home/ralph/.claude/hooks/rtk-rewrite.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Baked Skills

A curated, narrow set of Claude Code skills baked into the sandbox image at `/etc/claude-defaults/skills/` and seeded into `/home/ralph/.claude/skills/` on container start. The host's full skill set is intentionally NOT mounted — most of it is planning/review/orchestration that fights the autonomous loop's structure.

Currently baked:
- **`caveman/SKILL.md`** — terse output mode. Direct token savings per iteration. Source: `caveman:caveman` plugin.
- **`caveman-commit/SKILL.md`** — conventional-commits message generator with caveman-style brevity. Source: `caveman:caveman-commit` plugin.

### How `/ralph init` populates `docker/ralph/skills/`

The skill files are copied verbatim from the host's installed plugin marketplace into the sandbox build context. On the host, locate them at:

- `~/.claude/plugins/marketplaces/caveman/skills/caveman/SKILL.md`
- `~/.claude/plugins/marketplaces/caveman/skills/caveman-commit/SKILL.md`

Copy each into:

- `docker/ralph/skills/caveman/SKILL.md`
- `docker/ralph/skills/caveman-commit/SKILL.md`

If the host doesn't have caveman installed, `/ralph init` should report that and skip the skill bake step (Dockerfile's `COPY skills/` will then copy an empty dir, which `cmd_up`'s seed loop tolerates).

The Dockerfile `COPY skills/ /etc/claude-defaults/skills/` (already in the Dockerfile template) bakes them at image build. The launcher's `cmd_up` seed loop copies any baked skill that doesn't already exist in `/home/ralph/.claude/skills/` — so adding a skill later means rebuilding the image and restarting the container.

### Adding more skills later

Drop a new directory under `docker/ralph/skills/<skill-name>/` containing `SKILL.md` (and any references it needs), rebuild (`bin/ralph build`), and restart (`bin/ralph down && bin/ralph up`). Keep the bake list narrow — every loaded skill consumes context tokens per iteration.

---

## MCP Configuration

Generated as `.mcp.json` at the project root. Project-scoped MCP config so Claude Code loads it on every session in this repo (sandboxed and host).

Two servers, second is **conditional** on the project using Postgres:

1. **context7** — always included. Up-to-date library/framework documentation lookup. Lets the loop check current API surfaces instead of guessing from training data.
2. **postgres** — included when the project uses Postgres (detected via `pg` gem in `Gemfile` or `postgres` service in `docker-compose.yml`). Schema-aware queries, table introspection, sample data — reduces "I assumed `users.email` was unique" hallucinations.

### Base template (context7 only)

If the project does NOT use Postgres, ship just this:

```json
{
  "mcpServers": {
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
```

### With Postgres

If the project uses Postgres, include the postgres server too:

```json
{
  "mcpServers": {
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "${RALPH_POSTGRES_DSN}"]
    }
  }
}
```

`${RALPH_POSTGRES_DSN}` is a Claude Code env-var expansion. The launcher forwards `RALPH_POSTGRES_DSN` from host environment into the container at `up` time. **Use a read-only role** (or at minimum a non-prod DB) — the loop can issue arbitrary queries.

Recommended DSN shape, pointing at the host's docker-compose Postgres:

```
postgres://ralph_ro:<password>@host.docker.internal:5432/<db_name>
```

To create the read-only role:

```sql
CREATE ROLE ralph_ro WITH LOGIN PASSWORD '...';
GRANT CONNECT ON DATABASE <db_name> TO ralph_ro;
GRANT USAGE ON SCHEMA public TO ralph_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ralph_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ralph_ro;
```

Tools exposed:
- `mcp__context7__resolve-library-id` / `mcp__context7__get-library-docs` — library docs.
- `mcp__postgres__query` — read-only SQL queries against the configured DSN. Schema introspection via `information_schema` queries.

The container has Node 20 + npm; firewall already allows `registry.npmjs.org` (npm), `context7.com` / `api.context7.com` (doc backend), and the host network range (Postgres on the docker-compose host). No extra setup beyond setting `RALPH_POSTGRES_DSN` in your `.env`.

---

## Launcher

The `bin/ralph` script. Replace these placeholders:
- `{{PROJECT_SLUG}}` — lowercase project name safe for Docker (e.g., `my-rails-app`)

```bash
#!/usr/bin/env bash
# Manage the sandboxed Docker container for ralph loops.
#
# Usage:
#   bin/ralph build              # (re)build the image
#   bin/ralph up                 # start the container + init firewall
#   bin/ralph exec ...           # run a command in the container
#   bin/ralph claude ...         # shorthand: exec claude --dangerously-skip-permissions
#   bin/ralph ralph [N] [--budget USD]  # loop N iterations or until budget
#   bin/ralph plan               # one-shot: regenerate IMPLEMENTATIONPLAN.md from specs
#   bin/ralph rtk ...            # run rtk inside the container
#   bin/ralph rtk-reset          # wipe rtk stats DB
#   bin/ralph progress           # show IMPLEMENTATIONPLAN.md progress
#   bin/ralph shell              # interactive zsh
#   bin/ralph logs               # tail container logs
#   bin/ralph down               # stop and remove (volumes survive)
#   bin/ralph status             # show image/container state
#
# Auth: export CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY before `up`.
# Preferred: op run --env-file=.env -- bin/ralph up
#
# Ctrl+C cleanly stops the ralph loop.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="{{PROJECT_SLUG}}-sandbox:latest"

# Unique suffix per worktree so parallel worktrees get their own containers.
# The image is shared (same Dockerfile), but container + volumes are per-root.
WORKTREE_HASH="$(printf '%s' "$ROOT" | shasum | cut -c1-8)"
NAME="{{PROJECT_SLUG}}-sandbox-${WORKTREE_HASH}"
BUNDLE_VOL="{{PROJECT_SLUG}}-bundle-${WORKTREE_HASH}"
CLAUDE_VOL="{{PROJECT_SLUG}}-claude-${WORKTREE_HASH}"
HISTORY_VOL="{{PROJECT_SLUG}}-history-${WORKTREE_HASH}"
RTK_VOL="{{PROJECT_SLUG}}-rtk-${WORKTREE_HASH}"

# Git worktree support: mount parent .git so git works inside container.
GIT_EXTRA_MOUNT=""
if [ -f "$ROOT/.git" ]; then
  PARENT_GITDIR="$(sed -n 's/^gitdir: //p' "$ROOT/.git")"
  PARENT_DOTGIT="${PARENT_GITDIR%/worktrees/*}"
  if [ -d "$PARENT_DOTGIT" ]; then
    GIT_EXTRA_MOUNT="-v $PARENT_DOTGIT:$PARENT_DOTGIT:rw"
  fi
fi

container_exists() { docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; }
container_running() { docker ps --format '{{.Names}}' | grep -qx "$NAME"; }
image_exists() { docker image inspect "$IMAGE" >/dev/null 2>&1; }

cmd_build() {
  docker build -t "$IMAGE" "$ROOT/docker/ralph"
}

cmd_up() {
  image_exists || cmd_build
  if container_running; then
    echo "Container $NAME already running."
    return 0
  fi
  if container_exists; then
    docker start "$NAME" >/dev/null
  else
    local -a auth_args=()
    local oauth_token api_key
    oauth_token=$(printf %s "${CLAUDE_CODE_OAUTH_TOKEN:-}" | tr -d '[:space:]')
    api_key=$(printf %s "${ANTHROPIC_API_KEY:-}" | tr -d '[:space:]')
    [ -n "$oauth_token" ] && auth_args+=(-e "CLAUDE_CODE_OAUTH_TOKEN=$oauth_token")
    [ -n "$api_key" ]     && auth_args+=(-e "ANTHROPIC_API_KEY=$api_key")

    if [ ${#auth_args[@]} -eq 0 ]; then
      echo "WARNING: No CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY set." >&2
    fi

    local -a mcp_args=()
    [ -n "${RALPH_POSTGRES_DSN:-}" ] && mcp_args+=(-e "RALPH_POSTGRES_DSN=${RALPH_POSTGRES_DSN}")

    local -a git_args=()
    [ -n "$GIT_EXTRA_MOUNT" ] && read -r -a git_args <<<"$GIT_EXTRA_MOUNT"

    docker run -d \
      --name "$NAME" \
      --cap-add=NET_ADMIN --cap-add=NET_RAW \
      --add-host=host.docker.internal:host-gateway \
      -v "$ROOT:/workspace" \
      "${git_args[@]}" \
      -v "$BUNDLE_VOL:/workspace/vendor/bundle" \
      -v "$CLAUDE_VOL:/home/ralph/.claude" \
      -v "$HISTORY_VOL:/commandhistory" \
      -v "$RTK_VOL:/home/ralph/.local/share/rtk" \
      -e CLAUDE_CONFIG_DIR=/home/ralph/.claude \
      -e BUNDLE_PATH=/workspace/vendor/bundle \
      -e "RALPH_EXTRA_DOMAINS=${RALPH_EXTRA_DOMAINS:-}" \
      "${auth_args[@]}" \
      "${mcp_args[@]}" \
      -w /workspace \
      "$IMAGE" \
      sleep infinity >/dev/null
  fi
  echo "Container up. Initializing firewall..."
  docker exec -u root "$NAME" /usr/local/bin/init-firewall.sh
  docker exec "$NAME" bash -lc 'sudo chown -R ralph:ralph /workspace/vendor/bundle /home/ralph/.local/share/rtk 2>/dev/null; bundle install --quiet' || true
  docker exec "$NAME" bash -lc 'git config --global --add safe.directory /workspace'
  if [ -n "$GIT_EXTRA_MOUNT" ]; then
    docker exec "$NAME" bash -lc "git config --global --add safe.directory $PARENT_DOTGIT"
  fi
  docker exec "$NAME" bash -lc '
    set -e
    mkdir -p /home/ralph/.claude/hooks /home/ralph/.claude/skills
    [ -f /home/ralph/.claude/hooks/rtk-rewrite.sh ] \
      || cp /etc/claude-defaults/hooks/rtk-rewrite.sh /home/ralph/.claude/hooks/rtk-rewrite.sh
    [ -f /home/ralph/.claude/settings.json ] && [ -s /home/ralph/.claude/settings.json ] \
      && [ "$(cat /home/ralph/.claude/settings.json)" != "{}" ] \
      || cp /etc/claude-defaults/settings.json /home/ralph/.claude/settings.json
    chmod 0755 /home/ralph/.claude/hooks/rtk-rewrite.sh
    if [ -d /etc/claude-defaults/skills ]; then
      for skill in /etc/claude-defaults/skills/*/; do
        [ -d "$skill" ] || continue
        name=$(basename "$skill")
        [ -d "/home/ralph/.claude/skills/$name" ] || cp -r "$skill" "/home/ralph/.claude/skills/$name"
      done
    fi
  ' || true
  echo "Sandbox ready."
}

ensure_running() {
  container_running || { echo "Container not running. Run: bin/ralph up" >&2; exit 1; }
}

exec_flags() {
  local flags="-i"
  [ -t 0 ] && [ -t 1 ] && flags="-it"
  echo "$flags"
}

cmd_exec() {
  ensure_running
  docker exec $(exec_flags) "$NAME" "$@"
}

cmd_claude() {
  ensure_running
  local inject=false
  for arg in "$@"; do [[ "$arg" == "-p" ]] && inject=true; done
  if $inject && [ -t 0 ] && [ -f "$ROOT/PROMPT.md" ]; then
    docker exec -i "$NAME" claude --dangerously-skip-permissions "$@" < "$ROOT/PROMPT.md"
  else
    docker exec $(exec_flags) "$NAME" claude --dangerously-skip-permissions "$@"
  fi
}

cmd_ralph() {
  ensure_running
  local max_iter=0 budget=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --budget) budget="$2"; shift 2 ;;
      *)        max_iter="$1"; shift ;;
    esac
  done

  [ -f "$ROOT/PROMPT.md" ] || { echo "No PROMPT.md in $ROOT" >&2; exit 1; }
  mkdir -p "$ROOT/log"

  local intro="Starting ralph loop"
  [ "$max_iter" -gt 0 ] 2>/dev/null && intro="$intro (max $max_iter iter)"
  [ "$(printf '%s' "$budget" | tr -d .0)" != "" ] 2>/dev/null && intro="$intro (budget \$$budget)"
  echo "$intro. Ctrl+C to stop."
  trap 'echo "Stopping."; exit 0' INT TERM

  local iter=0 total_cost=0 total_in=0 total_out=0 total_cache_read=0
  while :; do
    iter=$((iter + 1))
    if [ "$max_iter" -gt 0 ] 2>/dev/null && [ "$iter" -gt "$max_iter" ]; then
      echo "Reached max $max_iter iterations. Stopping."
      break
    fi
    echo
    echo "=== iteration $iter at $(date +%H:%M:%S) ==="
    local log_offset
    log_offset=$(cat "$ROOT/log/ralph.jsonl" 2>/dev/null | wc -c || echo 0)
    docker exec -i "$NAME" claude --dangerously-skip-permissions -p \
      --output-format=stream-json --verbose < "$ROOT/PROMPT.md" \
      | tee -a "$ROOT/log/ralph.jsonl" \
      | ralph_filter \
      || break

    local stats
    stats=$(tail -n 200 "$ROOT/log/ralph.jsonl" | grep '"type":"result"' | tail -n1 | python3 -c '
import sys, json
try:
    e = json.loads(sys.stdin.read())
    u = e.get("usage") or {}
    print(e.get("total_cost_usd", 0) or 0)
    print(u.get("input_tokens", 0) or 0)
    print(u.get("output_tokens", 0) or 0)
    print(u.get("cache_read_input_tokens", 0) or 0)
except Exception:
    print(0); print(0); print(0); print(0)
' 2>/dev/null)
    local iter_cost iter_in iter_out iter_cache
    { read -r iter_cost; read -r iter_in; read -r iter_out; read -r iter_cache; } <<<"$stats"
    total_cost=$(python3 -c "print(round(${total_cost} + ${iter_cost:-0}, 4))")
    total_in=$((total_in + ${iter_in:-0}))
    total_out=$((total_out + ${iter_out:-0}))
    total_cache_read=$((total_cache_read + ${iter_cache:-0}))
    printf '  iter: cost=$%.4f  in=%s  out=%s  cache_read=%s\n' \
      "${iter_cost:-0}" "${iter_in:-0}" "${iter_out:-0}" "${iter_cache:-0}"
    printf '  cumulative: cost=$%.4f  in=%s  out=%s  cache_read=%s\n' \
      "$total_cost" "$total_in" "$total_out" "$total_cache_read"

    local sentinel
    sentinel=$(tail -c "+$((log_offset + 1))" "$ROOT/log/ralph.jsonl" 2>/dev/null | python3 -c '
import sys, json, re
pat = re.compile(r"^(ALL DONE|COMPLETE|BLOCKED:.*)$", re.M)
hit = ""
for line in sys.stdin:
    try: ev = json.loads(line)
    except: continue
    texts = []
    if ev.get("type") == "assistant":
        for b in ev.get("message", {}).get("content", []):
            if b.get("type") == "text":
                texts.append(b.get("text", ""))
    elif ev.get("type") == "result":
        texts.append(ev.get("result") or "")
    for t in texts:
        m = pat.search(t)
        if m: hit = m.group(1)
print(hit)
' 2>/dev/null)
    if [ -n "$sentinel" ]; then
      echo "  sentinel: $sentinel"
      echo "Loop finished: $sentinel"
      if [[ "$sentinel" == BLOCKED:* ]] && [ -f "$ROOT/IMPLEMENTATIONPLAN.md" ]; then
        local blocked_section
        blocked_section=$(awk '
          /^## Blocked/ { in_section=1; print; next }
          in_section && /^## / { exit }
          in_section { print }
        ' "$ROOT/IMPLEMENTATIONPLAN.md")
        if [ -n "$blocked_section" ]; then
          echo
          echo "--- To unblock, resolve the following: ---"
          printf '%s\n' "$blocked_section"
          echo "-------------------------------------------"
          if [ -t 0 ] && [ -t 1 ] && command -v claude >/dev/null 2>&1; then
            echo
            read -r -p "Launch interactive claude on the host to help resolve? [y/N] " reply
            if [[ "$reply" =~ ^[Yy]$ ]]; then
              echo "Starting host claude (unsandboxed)."
              echo
              exec claude "Help me unblock the ralph loop. The \`## Blocked\` section of IMPLEMENTATIONPLAN.md lists the items needing external input — read it and walk me through resolving each one."
            fi
          fi
        fi
      fi
      break
    fi

    if [ "$(printf '%s' "$budget" | tr -d .0)" != "" ] 2>/dev/null; then
      if python3 -c "import sys; sys.exit(0 if float('$total_cost') >= float('$budget') else 1)"; then
        echo "Reached budget \$$budget (cumulative \$$total_cost). Stopping."
        break
      fi
    fi
  done
}

ralph_filter() {
  python3 -c '
import sys, json
for line in sys.stdin:
    try:
        ev = json.loads(line)
    except Exception:
        continue
    t = ev.get("type")
    if t == "assistant":
        for block in ev.get("message", {}).get("content", []):
            if block.get("type") == "text":
                for text_line in block.get("text", "").splitlines():
                    if text_line.startswith("CHOSEN:"):
                        print("  " + text_line, flush=True)
            elif block.get("type") == "tool_use":
                name = block.get("name", "?")
                inp = block.get("input", {})
                detail = ""
                if name == "Bash":
                    detail = " " + (inp.get("description") or (inp.get("command","")[:60]))
                elif name in ("Read","Edit","Write","Glob"):
                    detail = " " + (inp.get("file_path") or inp.get("pattern",""))
                elif name == "Grep":
                    detail = " " + inp.get("pattern","")
                print(f"  \u2192 {name}{detail}", flush=True)
    elif t == "result":
        r = (ev.get("result") or "").strip().splitlines()
        if r:
            print("  result: " + r[0][:200], flush=True)
'
}

cmd_plan() {
  ensure_running
  [ -f "$ROOT/PROMPT_plan.md" ] || { echo "No PROMPT_plan.md in $ROOT" >&2; exit 1; }
  if [ ! -d "$ROOT/specs" ] || [ -z "$(ls -A "$ROOT/specs" 2>/dev/null)" ]; then
    echo "No specs/ directory or it is empty. Plan mode needs specs to plan from." >&2
    exit 1
  fi
  mkdir -p "$ROOT/log"
  echo "Running plan iteration. Ctrl+C to stop."
  trap 'echo "Stopping."; exit 0' INT TERM
  docker exec -i "$NAME" claude --dangerously-skip-permissions -p \
    --output-format=stream-json --verbose < "$ROOT/PROMPT_plan.md" \
    | tee -a "$ROOT/log/ralph.jsonl" \
    | ralph_filter
}

cmd_rtk() {
  ensure_running
  docker exec $(exec_flags) "$NAME" rtk "$@"
}

cmd_rtk_reset() {
  ensure_running
  docker exec "$NAME" rm -f /home/ralph/.local/share/rtk/history.db
  echo "rtk stats reset."
}

cmd_progress() {
  local plan="$ROOT/IMPLEMENTATIONPLAN.md"
  [ -f "$plan" ] || { echo "No IMPLEMENTATIONPLAN.md" >&2; exit 1; }
  python3 - "$plan" <<'PY'
import re, sys
lines = open(sys.argv[1]).read().splitlines()
section = None
sections = []
total_done = total_all = 0
for line in lines:
    m = re.match(r'^## (.+)$', line)
    if m:
        section = m.group(1).strip()
        sections.append([section, 0, 0])
        continue
    if re.match(r'^- \[[ x]\]', line):
        sections[-1][2] += 1
        total_all += 1
        if line.startswith('- [x]'):
            sections[-1][1] += 1
            total_done += 1
width = max((len(s[0]) for s in sections), default=0)
for title, done, total in sections:
    if total == 0: continue
    bar_len = 20
    filled = int(bar_len * done / total)
    bar = '\u2588' * filled + '\u2591' * (bar_len - filled)
    print(f"  {title.ljust(width)}  [{bar}]  {done}/{total}")
pct = (100 * total_done // total_all) if total_all else 0
print(f"\n  total: {total_done}/{total_all}  ({pct}%)")
PY
}

cmd_shell() {
  ensure_running
  docker exec -it "$NAME" zsh
}

cmd_logs() { docker logs -f "$NAME"; }

cmd_down() {
  if container_exists; then
    docker rm -f "$NAME" >/dev/null
    echo "Removed $NAME."
  else
    echo "No container to remove."
  fi
}

cmd_status() {
  printf 'image:     %s\n' "$(image_exists && echo present || echo missing)"
  printf 'container: %s\n' "$(container_running && echo running || (container_exists && echo stopped || echo absent))"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  build)    cmd_build "$@" ;;
  up)       cmd_up "$@" ;;
  exec)     cmd_exec "$@" ;;
  claude)   cmd_claude "$@" ;;
  ralph)    cmd_ralph "$@" ;;
  plan)     cmd_plan "$@" ;;
  rtk)      cmd_rtk "$@" ;;
  rtk-reset) cmd_rtk_reset "$@" ;;
  progress) cmd_progress "$@" ;;
  shell)    cmd_shell "$@" ;;
  logs)     cmd_logs "$@" ;;
  down)     cmd_down "$@" ;;
  status)   cmd_status "$@" ;;
  ""|-h|--help|help)
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)
    echo "Unknown command: $cmd" >&2; exit 2 ;;
esac
```

---

## Loop Protocol

The `PROMPT.md` that drives each ralph iteration. Replace:
- `{{LINT_CMD}}` — detect from project: `bundle exec rubocop -a` if `.rubocop.yml` exists, `bundle exec standardrb --fix` if using standard, else skip
- `{{TEST_CMD}}` — detect from project: prefer `bundle exec rspec` (check for `.rspec`, `spec/` dir, or `rspec-rails` in Gemfile); fall back to `bundle exec rails test` only if minitest and no RSpec present
- `{{MODEL_NAME}}` — the model currently powering the session (e.g., `Claude Opus 4.6`)

```markdown
# Ralph loop

You are one iteration of a loop. Pick the single most important unblocked task from `IMPLEMENTATIONPLAN.md`, implement it completely, commit, and exit. The loop re-invokes you for the next task.

Design specs live in `specs/*.md`. Each bullet in the implementation plan cites the relevant spec and section — read it before implementing.

## Step 1: Choose the task

Read `IMPLEMENTATIONPLAN.md` in full. Then:

1. Collect all `- [ ]` bullets.
2. If there are none, print `ALL DONE` on its own line and exit.
3. Re-evaluate blockers from scratch this iteration — do NOT trust any existing `## Blocked` section in `IMPLEMENTATIONPLAN.md`; it may be stale from a previous run. A bullet is **blocked** if you cannot complete it now — because it needs information, access, or a capability you don't currently have (credentials, network reachability, physical hardware, an artifact from an earlier unchecked bullet, etc.). Determine this by probing current state, not by reading prior blocker notes: attempt to read the missing input, reach the host, import the dependency — whatever the bullet implies. If the probe succeeds, it's not blocked, regardless of what the `## Blocked` section says. If every previously listed blocker now probes clean, rewrite that section accordingly as part of this iteration.
4. From the remaining unblocked bullets, pick the **most important** one:
   - Prefer foundational utilities that unblock many later bullets.
   - Within a section, top-to-bottom order is fine — the plan is already written in dependency order.
   - Prefer completing an in-progress section over jumping to a new one.
5. **Terminal blocked states** — if there are no unblocked bullets left, your **final message** MUST be exactly one of the sentinel lines below and nothing else (no preamble, no summary, no explanation — the loop driver greps for these literal prefixes at start-of-line):
   - Every remaining bullet is blocked on something you don't have (missing credentials, unreachable resource, missing capability): first ensure a `## Blocked` heading at the top of `IMPLEMENTATIONPLAN.md` lists each blocker concretely so a human can resolve it, then your final message is exactly: `BLOCKED: external input required — see IMPLEMENTATIONPLAN.md ## Blocked`
   - Every remaining bullet is dependency-blocked (waiting on an earlier unchecked bullet that itself can't be picked): final message exactly `BLOCKED: dependency cycle — <bullets>` (do not edit the plan).
   - `IMPLEMENTATIONPLAN.md` missing or contains no bullets: final message exactly `BLOCKED: plan missing or empty`.
   - All bullets are `- [x]`: final message exactly `ALL DONE`.

   Do NOT paraphrase. Do NOT add context around the sentinel. The sentinel line is the entire response.
6. **Announce the choice.** Before doing any other work, emit a single line of text in this exact format so the loop's output filter can surface it:

   `CHOSEN: <the bullet text, with the leading "- [ ]" and the trailing " — edit/create <path>" citation stripped>`

## Step 2: Implement

- Read the spec file(s) in `specs/` cited in the bullet **before writing any code**. The spec is authoritative — it contains the design decisions, data models, and interface shapes. Do not improvise or deviate from it.
- If the bullet cites a specific section (e.g., `specs/foo.md § Heading`), read at least that section.
- **Don't assume not implemented.** Before writing new code, grep the codebase to confirm the functionality doesn't already exist. The plan was written from a snapshot; reality may have moved.
- **Don't guess library APIs.** If the bullet uses a gem, library, or framework method you're not 100% sure of, look it up via context7 (`mcp__context7__resolve-library-id` → `mcp__context7__get-library-docs`) before writing code. Hallucinated APIs cost a full iteration to revert.
- **Check the live schema before writing data-layer code.** If the bullet touches AR models, migrations, queries, or fixtures, run `mcp__postgres__query` first to confirm column names, types, nullability, and indexes. The migration files might lag the actual DB.
- Implement only what the bullet describes. Do not touch unrelated files or implement the next bullet.
- Follow existing project conventions (language, style, linter config). Add no unnecessary comments.

## Step 3: Verify (fix until green or block)

Run in order. **The test suite must pass before you may commit or mark the bullet complete.**

1. Run the project linter/formatter on files you touched: `{{LINT_CMD}}`
2. Run the full test suite: `{{TEST_CMD}}`
3. If tests fail:
   a. Read the failure output carefully. If the failure is caused by your change, fix it and re-run the suite. Repeat until green.
   b. If a test was already failing **before** your change (i.e., it fails on a clean checkout of the prior commit too), note it under `## Followups` at the bottom of `IMPLEMENTATIONPLAN.md` and continue — but only after confirming it's pre-existing.
   c. If you cannot make the suite green after 3 fix attempts, **revert your changes** (`git checkout -- .`), mark the bullet as blocked in `## Blocked` with the failure details, and emit: `BLOCKED: test suite red — see IMPLEMENTATIONPLAN.md ## Blocked`

**Do NOT commit with a red test suite. Do NOT mark a bullet `- [x]` with a red test suite. A red suite blocks the loop.**

## Step 4: Mark and commit

1. Change the bullet's `- [ ]` to `- [x]` in `IMPLEMENTATIONPLAN.md`.
2. `git add` only the files changed this iteration (including `IMPLEMENTATIONPLAN.md`).
3. Commit. Subject = bullet text stripped of the leading `- [ ]` and trailing citation. Body = one line citing the spec file(s). Include the trailer:
   `Co-Authored-By: {{MODEL_NAME}} <noreply@anthropic.com>`
4. Do not push. Do not use `--amend` or `--no-verify`.

## Rules

- **Plan edits**: only toggle `- [ ]` → `- [x]`, rewrite the `## Blocked` heading when probes show it's stale, and append to `## Followups`. Never reorder, rewrite, or delete existing bullets. Plan-level rewrites happen via `bin/ralph plan` (separate invocation), not from inside the build loop.
- **No scope creep**: if you spot a gap, add a note under `## Followups` (not a new bullet). Let the human triage it.
- **Exit after one bullet**: output a one-line summary of what you did. The loop handles the rest.
- **Never touch secrets files**: do NOT create, edit, or delete encrypted-credentials files or their master keys. If a bullet requires editing credentials, treat it as host-blocked and emit the `BLOCKED:` sentinel per step 5.
```

---

## Loop Protocol — Plan Mode

The `PROMPT_plan.md` driving `bin/ralph plan`. One-shot: run on demand to (re)generate `IMPLEMENTATIONPLAN.md` from `specs/*.md` and current source state. Not part of the build loop. Run when:
- The plan is stale (specs changed, code drifted).
- The build loop hits `BLOCKED:` and the human wants to re-plan around the obstacle.
- Initial plan generation after a `/ralph prepare` round of spec writing.

No placeholders to substitute — this template is project-agnostic. Copy verbatim.

```markdown
# Ralph — plan mode

You are running planning mode for a ralph loop, not building. Your job is to (re)generate `IMPLEMENTATIONPLAN.md` based on the current contents of `specs/*.md` and the current source tree. **Do not modify source files. Only edit `IMPLEMENTATIONPLAN.md`.**

## Step 1: Study the inputs

Dispatch parallel subagents — one per spec file in `specs/` — and have each subagent return:
- The spec's goal in 1–2 lines.
- A list of concrete tasks needed to satisfy the spec, with cited file paths.
- For each task, whether it is **already done**, **not done**, or **partial** — verified by reading or grepping the codebase. Do NOT assume not implemented; confirm by code search first.
- For each external library, framework, or API the spec depends on, **look up current docs via context7** (`mcp__context7__resolve-library-id` then `mcp__context7__get-library-docs`) before deciding what tasks are needed. Don't fabricate API surfaces from training-data memory — Rails, gems, and JS libs all change between minor versions.
- If the project uses Postgres and the spec touches data models or queries, **inspect the live schema via `mcp__postgres__query`** (e.g., `SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name='...'`). Tasks should be grounded in what the database actually looks like, not what the spec or migration files imply.

Separately, read the existing `IMPLEMENTATIONPLAN.md` (if present):
- Note completed bullets (`- [x]`) — these are preserved.
- For each entry under `## Blocked`, **re-probe** whether it is still blocked. If the probe succeeds (resource reachable, dep installed, credential present), it is no longer blocked.
- Note current `## Followups` entries — they are preserved unless the spec now addresses them.

Reserve the main context for synthesis; don't read whole spec files yourself when a subagent can do it.

## Step 2: Synthesize

Rewrite `IMPLEMENTATIONPLAN.md`:

- Group tasks into sections by logical boundary (e.g., "Database layer", "API endpoints", "UI"). Prepend a one-line rationale to each section: *what spec drives it.*
- Within each section, dependency-ordered: foundational tasks first.
- Each task formatted: `- [ ] <description> — edit/create <path> (see specs/<file>.md § <section>)`.
- Preserve completed bullets (`- [x]`) at the top of their relevant section.
- `## Blocked`: list current real blockers, each with what concretely is needed to resolve. Stale entries that probed clean are removed.
- `## Followups`: preserve prior entries; add new ones for scope creep observations or ambiguities found in specs.

## Step 3: Verify

- Every task cites a spec file (and section, if a section title exists).
- No task is large enough to span multiple build iterations — split if so.
- No task duplicates existing source. If unsure, grep before listing.
- If a spec is itself ambiguous or contradictory, do NOT fabricate a design — note it under `## Followups` so a human can resolve.

## Rules

- **Plan only.** No code edits outside `IMPLEMENTATIONPLAN.md`.
- **Capture the why.** A future ralph build iteration reading the plan should not need to re-derive intent.
- **Don't assume not implemented** — confirm via code search.
- **Don't guess library APIs.** When a spec depends on an external library or framework, consult context7 (`mcp__context7__resolve-library-id` → `mcp__context7__get-library-docs`) before deciding what tasks the spec implies. A bad plan built on stale API memory wastes the entire build loop.
- **Preserve completed work.** Never remove `- [x]` bullets — they are the loop's audit trail.

Exit after `IMPLEMENTATIONPLAN.md` is written. Output a one-line summary of how the plan changed (e.g., "rewrote API section, unblocked 2 items, added 3 new bullets").
```
