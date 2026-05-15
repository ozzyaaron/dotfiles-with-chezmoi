// Loads ralph.config.yaml and applies invariants the launcher's audit also enforces.
// The MCP server is one of two places these invariants are checked; the launcher
// is the other. Keep them in sync.

import fs from "node:fs";
import { parse as parseYaml } from "yaml";

const SCHEMA_VERSION = 1;

const ALWAYS_SENSITIVE = [
  "ralph.config.yaml",
  "bin/ralph",
  ".ralph/**",
  "PROMPT.md",
  "IMPLEMENTATIONPLAN.md",
  "specs/**",
];

const ALWAYS_ALLOWED_DOMAINS = ["api.anthropic.com"];

export function loadConfig(configPath) {
  let raw;
  try {
    raw = fs.readFileSync(configPath, "utf8");
  } catch (err) {
    throw new Error(`cannot read config at ${configPath}: ${err.message}`);
  }

  let doc;
  try {
    doc = parseYaml(raw) || {};
  } catch (err) {
    throw new Error(`malformed YAML at ${configPath}: ${err.message}`);
  }

  if (doc.schema_version !== SCHEMA_VERSION) {
    throw new Error(
      `schema_version mismatch: got ${doc.schema_version}, expected ${SCHEMA_VERSION}`
    );
  }

  // Stack required.
  const stack = doc.stack || {};
  for (const k of ["lint_cmd", "test_cmd", "install_cmd"]) {
    if (typeof stack[k] !== "string" || stack[k].length === 0) {
      throw new Error(`stack.${k} is required and must be a non-empty string`);
    }
  }

  // Sensitive paths: inject always-on entries.
  const sensitive = new Set(doc.sensitive_paths || []);
  for (const p of ALWAYS_SENSITIVE) sensitive.add(p);

  // Allowed domains: inject api.anthropic.com.
  const network = doc.network || {};
  const allowedDomains = new Set(network.allowed_domains || []);
  for (const d of ALWAYS_ALLOWED_DOMAINS) allowedDomains.add(d);

  // Quotas required.
  const quotas = doc.quotas || {};
  for (const k of ["max_tool_calls", "max_bytes_read", "max_bytes_written"]) {
    if (typeof quotas[k] !== "number" || quotas[k] <= 0) {
      throw new Error(`quotas.${k} is required and must be a positive number`);
    }
  }

  // Git commit identity required.
  const gitCommit = doc.git_commit || {};
  if (!gitCommit.author_name || !gitCommit.author_email) {
    throw new Error("git_commit.author_name and git_commit.author_email are required");
  }

  return {
    schemaVersion: doc.schema_version,
    stack: {
      name: stack.name || "unknown",
      lintCmd: stack.lint_cmd,
      testCmd: stack.test_cmd,
      installCmd: stack.install_cmd,
    },
    mcpServers: doc.mcp_servers || [],
    network: {
      allowedDomains: [...allowedDomains],
      registries: network.registries || [],
      dnsResolver: network.dns_resolver || "1.1.1.1",
    },
    sensitivePaths: [...sensitive],
    maskedEnvVars: doc.masked_env_vars || [],
    gitCommit: {
      authorName: gitCommit.author_name,
      authorEmail: gitCommit.author_email,
      skipHooks: Boolean(gitCommit.skip_hooks),
    },
    hostExposure: {
      dockerInternal: Boolean((doc.host_exposure || {}).docker_internal),
      dbPort: (doc.host_exposure || {}).db_port || null,
    },
    loopAllowedTools: doc.loop_allowed_tools || [],
    quotas: {
      maxToolCalls: quotas.max_tool_calls,
      maxBytesRead: quotas.max_bytes_read,
      maxBytesWritten: quotas.max_bytes_written,
    },
  };
}
