#!/usr/bin/env node
// mask-env.js — deterministic generator of $ROOT/.ralph/masked/ from real
// sensitive files in $ROOT. No LLM involvement.
//
// Reads ralph.config.yaml; reads host's real files; writes masked variants.
// Outputs:
//   $ROOT/.ralph/masked/env         combined KEY=value file the MCP subprocess
//                                   injects into lint/test/install env.
//   $ROOT/.ralph/masked/<path>      per-path masked copy of each sensitive_paths
//                                   entry that's a real file — bind-mounted into
//                                   the sandbox in place of the real one.
//
// Usage: node mask-env.js <project_root>

import fs from "node:fs";
import path from "node:path";

// We don't want to require external deps here — the helper must run on a bare
// macOS install. Inline a tiny YAML subset parser for the fields we need.
//
// Recognized shape (must match templates.md):
//   sensitive_paths:
//     - "<glob>"
//     - "<glob>"
//   masked_env_vars: ["A", "B"]
//   masked_env_vars:
//     - "A"
function parseYamlSubset(text) {
  const out = {};
  const lines = text.split("\n");
  let currentKey = null;
  let inFlow = false;
  for (let raw of lines) {
    // Strip trailing comments
    const hashIdx = raw.indexOf("#");
    if (hashIdx >= 0 && !raw.slice(0, hashIdx).match(/["'][^"']*$/)) {
      raw = raw.slice(0, hashIdx);
    }
    const line = raw.replace(/\s+$/, "");
    if (!line) continue;

    // Top-level: `key:` (start a list) or `key: [..., ...]` (flow list)
    const topMatch = line.match(/^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$/);
    if (topMatch && !line.startsWith(" ")) {
      currentKey = topMatch[1];
      const rest = topMatch[2];
      if (rest.startsWith("[")) {
        // Flow style: [a, b, c]
        const close = rest.lastIndexOf("]");
        const inner = rest.slice(1, close >= 0 ? close : rest.length);
        out[currentKey] = inner.split(",").map((s) => stripQuotes(s.trim())).filter(Boolean);
        currentKey = null;
      } else if (rest === "") {
        out[currentKey] = [];
      } else {
        // Scalar value — we don't need scalars in this helper. Skip.
        out[currentKey] = stripQuotes(rest);
        currentKey = null;
      }
      continue;
    }

    // List items (block style): indented `- value`
    const itemMatch = line.match(/^\s+-\s+(.*)$/);
    if (itemMatch && currentKey) {
      const arr = Array.isArray(out[currentKey]) ? out[currentKey] : (out[currentKey] = []);
      arr.push(stripQuotes(itemMatch[1]));
      continue;
    }
  }
  return out;
}

function stripQuotes(s) {
  if (!s) return "";
  let t = s.trim();
  if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
    return t.slice(1, -1);
  }
  return t;
}

function maskValue(v) {
  if (/^postgres(ql)?:\/\//.test(v)) return "postgres://masked:masked@masked.invalid/masked";
  if (/^mysql:\/\//.test(v)) return "mysql://masked:masked@masked.invalid/masked";
  if (/^rediss?:\/\//.test(v)) return "redis://masked:masked@masked.invalid:6379/0";
  if (/^amqps?:\/\//.test(v)) return "amqp://masked:masked@masked.invalid:5672/";
  if (/^https:\/\//.test(v)) return "https://masked.invalid/";
  if (/^http:\/\//.test(v)) return "http://masked.invalid/";
  if (/^s3:\/\//.test(v)) return "s3://masked/masked";
  if (/^sk[-_](?:live|test)?/.test(v) || /^sk-/.test(v)) return "sk-MASKED00000000000000000000000000000000";
  if (/^pk[-_](?:live|test)?/.test(v) || /^pk-/.test(v)) return "pk-MASKED00000000000000000000000000000000";
  if (/^[^@]+@[^@.]+\.[^@]+$/.test(v)) return "masked@masked.invalid";
  // Length-preserving fallback.
  return "M".repeat(v.length);
}

function maskEnvFile(filePath) {
  const out = [];
  const text = fs.readFileSync(filePath, "utf8");
  for (let line of text.split("\n")) {
    if (!line || line.trim().startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq < 0) continue;
    let key = line.slice(0, eq).trim();
    let val = line.slice(eq + 1);
    // Optional `export ` prefix
    if (key.startsWith("export ")) key = key.slice(7).trim();
    val = stripQuotes(val);
    out.push(`${key}=${maskValue(val)}`);
  }
  return out;
}

function isEnvLike(rel) {
  const base = path.basename(rel);
  return base === ".env" || base.startsWith(".env.") || base.endsWith(".env");
}

function shouldConsider(rel) {
  if (rel === "ralph.config.yaml") return false;
  if (rel === "bin/ralph") return false;
  if (rel === "PROMPT.md") return false;
  if (rel === "IMPLEMENTATIONPLAN.md") return false;
  if (rel.startsWith(".ralph/")) return false;
  if (rel.startsWith("specs/")) return false;
  return true;
}

// Tiny glob matcher (matches `*`, `**`, `?`).
function globToRegex(glob) {
  let re = "^";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") { re += ".*"; i++; }
      else { re += "[^/]*"; }
    } else if (c === "?") re += "[^/]";
    else if ("\\^$.+|()[]{}".includes(c)) re += "\\" + c;
    else re += c;
  }
  re += "$";
  return new RegExp(re);
}

function listRealFiles(root, glob) {
  // Walk the tree; collect files whose relative paths match the glob.
  const out = [];
  const re = globToRegex(glob);
  function walk(dir) {
    let entries;
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); }
    catch { return; }
    for (const e of entries) {
      const abs = path.join(dir, e.name);
      const rel = path.relative(root, abs);
      // Skip well-known noisy paths (but not .git — we handle it specially).
      if (rel === ".ralph" || rel === "node_modules") continue;
      if (e.isDirectory()) {
        // .git: only check for .git/config; don't recurse further.
        if (e.name === ".git") {
          const candidate = path.join(rel, "config");
          if (re.test(candidate)) {
            try { fs.statSync(path.join(root, candidate)); out.push(candidate); }
            catch {}
          }
          continue;
        }
        walk(abs);
      } else if (e.isFile()) {
        if (re.test(rel)) out.push(rel);
      }
    }
  }
  walk(root);
  return out;
}

function main() {
  const root = process.argv[2] || process.cwd();
  const configPath = path.join(root, "ralph.config.yaml");
  if (!fs.existsSync(configPath)) {
    console.error(`[mask-env] no manifest at ${configPath}`);
    process.exit(1);
  }
  const doc = parseYamlSubset(fs.readFileSync(configPath, "utf8"));
  const sensitive = Array.isArray(doc.sensitive_paths) ? doc.sensitive_paths : [];
  const declared = Array.isArray(doc.masked_env_vars) ? doc.masked_env_vars : [];

  const maskedDir = path.join(root, ".ralph", "masked");
  fs.mkdirSync(maskedDir, { recursive: true });

  // Truncate combined env file.
  const combinedEnv = path.join(maskedDir, "env");
  fs.writeFileSync(combinedEnv, "");

  let envFileCount = 0;
  const seenEnvKeys = new Set();

  for (const pattern of sensitive) {
    if (!shouldConsider(pattern)) continue;
    const matches = listRealFiles(root, pattern);
    for (const rel of matches) {
      const real = path.join(root, rel);
      const dest = path.join(maskedDir, rel);
      fs.mkdirSync(path.dirname(dest), { recursive: true });

      if (isEnvLike(rel)) {
        const masked = maskEnvFile(real);
        fs.writeFileSync(dest, masked.join("\n") + "\n", { mode: 0o600 });
        for (const line of masked) {
          const eq = line.indexOf("=");
          if (eq >= 0) {
            const k = line.slice(0, eq);
            if (!seenEnvKeys.has(k)) {
              fs.appendFileSync(combinedEnv, line + "\n");
              seenEnvKeys.add(k);
            }
          }
        }
        envFileCount += 1;
      } else if (rel === "config/master.key") {
        fs.writeFileSync(dest, "00000000000000000000000000000000", { mode: 0o600 });
      } else if (/config\/credentials.*\.yml(\.enc)?$/.test(rel)) {
        fs.writeFileSync(dest, Buffer.alloc(64).toString("base64"), { mode: 0o600 });
      } else if (rel.endsWith(".git/config")) {
        fs.writeFileSync(dest, [
          "[core]",
          "\trepositoryformatversion = 0",
          "\tfilemode = true",
          "\tbare = false",
          "\tlogallrefupdates = true",
          "[user]",
          "\tname = Ralph Loop",
          "\temail = ralph@local",
          "",
        ].join("\n"), { mode: 0o600 });
      } else {
        // Generic placeholder: same byte length, filled with 'M'.
        const size = fs.statSync(real).size;
        fs.writeFileSync(dest, Buffer.alloc(size, "M".charCodeAt(0)), { mode: 0o600 });
      }
    }
  }

  // Honor declared masked_env_vars even if no real env file contained them.
  for (const v of declared) {
    if (!v || seenEnvKeys.has(v)) continue;
    fs.appendFileSync(combinedEnv, `${v}=MMMMMMMMMMMMMMMM\n`);
    seenEnvKeys.add(v);
  }
  fs.chmodSync(combinedEnv, 0o600);

  console.log(`[mask-env] processed ${envFileCount} env-like file(s); wrote ${maskedDir}/`);
}

main();
