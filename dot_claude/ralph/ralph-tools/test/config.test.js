import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { loadConfig } from "../src/config.js";

function writeConfig(content) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ralph-cfg-"));
  const p = path.join(dir, "config.yaml");
  fs.writeFileSync(p, content);
  return p;
}

test("loads a complete config and applies always-on invariants", () => {
  const p = writeConfig(`
schema_version: 1
stack:
  lint_cmd: "echo lint"
  test_cmd: "echo test"
  install_cmd: "echo install"
git_commit:
  author_name: "Ralph"
  author_email: "ralph@local"
quotas:
  max_tool_calls: 100
  max_bytes_read: 1000
  max_bytes_written: 500
sensitive_paths: [".env"]
network:
  allowed_domains: []
`);
  const c = loadConfig(p);
  // Always-on sensitive paths are injected.
  assert.ok(c.sensitivePaths.includes(".env"));
  assert.ok(c.sensitivePaths.includes("ralph.config.yaml"));
  assert.ok(c.sensitivePaths.includes("IMPLEMENTATIONPLAN.md"));
  assert.ok(c.sensitivePaths.includes("bin/ralph"));
  // Always-on allowed domain is injected.
  assert.ok(c.network.allowedDomains.includes("api.anthropic.com"));
});

test("rejects mismatched schema_version", () => {
  const p = writeConfig(`schema_version: 999\nstack: {lint_cmd: x, test_cmd: x, install_cmd: x}\nquotas: {max_tool_calls: 1, max_bytes_read: 1, max_bytes_written: 1}\ngit_commit: {author_name: a, author_email: a}\n`);
  assert.throws(() => loadConfig(p), /schema_version/);
});

test("requires stack commands", () => {
  const p = writeConfig(`schema_version: 1\nstack: {lint_cmd: ""}\nquotas: {max_tool_calls: 1, max_bytes_read: 1, max_bytes_written: 1}\ngit_commit: {author_name: a, author_email: a}\n`);
  assert.throws(() => loadConfig(p), /lint_cmd/);
});

test("requires positive quotas", () => {
  const p = writeConfig(`schema_version: 1\nstack: {lint_cmd: x, test_cmd: x, install_cmd: x}\nquotas: {max_tool_calls: 0, max_bytes_read: 1, max_bytes_written: 1}\ngit_commit: {author_name: a, author_email: a}\n`);
  assert.throws(() => loadConfig(p), /max_tool_calls/);
});

test("requires git_commit identity", () => {
  const p = writeConfig(`schema_version: 1\nstack: {lint_cmd: x, test_cmd: x, install_cmd: x}\nquotas: {max_tool_calls: 1, max_bytes_read: 1, max_bytes_written: 1}\n`);
  assert.throws(() => loadConfig(p), /git_commit/);
});
