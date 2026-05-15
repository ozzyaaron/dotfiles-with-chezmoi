// Spawns project commands (lint/test/install) with a sanitized environment.
// Strips credentials that should not reach the project's test code, then
// injects masked env vars from /etc/ralph/masked/.

import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const STRIPPED_VARS = [
  "CLAUDE_CODE_OAUTH_TOKEN",
  "ANTHROPIC_API_KEY",
  "ANTHROPIC_AUTH_TOKEN",
  "RALPH_POSTGRES_DSN",
  "GH_TOKEN",
  "GITHUB_TOKEN",
  "AWS_ACCESS_KEY_ID",
  "AWS_SECRET_ACCESS_KEY",
  "AWS_SESSION_TOKEN",
];

function buildEnv(maskedDir) {
  const env = { ...process.env };
  for (const k of STRIPPED_VARS) {
    delete env[k];
  }

  // Load masked env vars from /etc/ralph/masked/env (one KEY=value per line).
  // The launcher's `bin/ralph mask-env` produces this file deterministically.
  const envFile = path.join(maskedDir || "/etc/ralph/masked", "env");
  try {
    const content = fs.readFileSync(envFile, "utf8");
    for (const line of content.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const idx = trimmed.indexOf("=");
      if (idx < 0) continue;
      const key = trimmed.slice(0, idx);
      const value = trimmed.slice(idx + 1);
      env[key] = value;
    }
  } catch (err) {
    if (err.code !== "ENOENT") throw err;
  }

  // Force git identity from the manifest at the env layer so even if the
  // project somehow tries to read .git/config (masked), git_commit still works.
  // (Identity is also set explicitly in git.js via GIT_AUTHOR_*/GIT_COMMITTER_*.)
  return env;
}

/**
 * Run a configured command (argv list or string) under a sanitized env.
 * Refuses shell metacharacters: the command MUST be a literal `argv` list, or
 * a string we'll tokenize with shell-words rules — never `bash -c`.
 */
export function runProjectCommand(commandString, cwd, { maskedDir, timeout } = {}) {
  const argv = tokenize(commandString);
  if (argv.length === 0) {
    return Promise.resolve({ exitCode: 0, stdout: "", stderr: "(empty command)" });
  }
  const env = buildEnv(maskedDir);
  return new Promise((resolve) => {
    let stdout = "";
    let stderr = "";
    const child = spawn(argv[0], argv.slice(1), {
      cwd: cwd || "/workspace",
      env,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let timer;
    if (timeout) {
      timer = setTimeout(() => child.kill("SIGTERM"), timeout);
    }
    child.stdout.on("data", (d) => (stdout += d.toString("utf8")));
    child.stderr.on("data", (d) => (stderr += d.toString("utf8")));
    child.on("error", (err) => {
      if (timer) clearTimeout(timer);
      resolve({ exitCode: -1, stdout, stderr: stderr + `\nspawn error: ${err.message}` });
    });
    child.on("exit", (code, signal) => {
      if (timer) clearTimeout(timer);
      resolve({
        exitCode: code != null ? code : -1,
        stdout: truncate(stdout, 1_000_000),
        stderr: truncate(stderr, 200_000),
        signal,
      });
    });
  });
}

// Simple POSIX-shell-words tokenizer (handles `'...'` and `"..."` but no expansion).
function tokenize(s) {
  const out = [];
  let cur = "";
  let i = 0;
  let quote = null;
  while (i < s.length) {
    const c = s[i];
    if (quote) {
      if (c === quote) {
        quote = null;
      } else {
        cur += c;
      }
    } else if (c === '"' || c === "'") {
      quote = c;
    } else if (c === "\\" && i + 1 < s.length) {
      cur += s[++i];
    } else if (/\s/.test(c)) {
      if (cur) {
        out.push(cur);
        cur = "";
      }
    } else if ("|&;<>$`(){}".includes(c)) {
      // Refuse shell metacharacters — these would only matter under `bash -c`,
      // which we don't use, but make it explicit so misconfigurations fail loudly.
      throw new Error(`command contains shell metacharacter '${c}': commands must be plain argv`);
    } else {
      cur += c;
    }
    i++;
  }
  if (quote) throw new Error("unterminated quoted string in command");
  if (cur) out.push(cur);
  return out;
}

function truncate(s, n) {
  return s.length > n ? s.slice(0, n) + `\n…[truncated ${s.length - n} bytes]` : s;
}
