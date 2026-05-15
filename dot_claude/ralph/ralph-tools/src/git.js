// git_status / git_diff / git_commit. The commit verb is the strict one:
// auto-stages exactly the files the LLM touched this iteration; never accepts
// --amend / --force / push; sets identity from the manifest.

import { spawn } from "node:child_process";

const WORKSPACE = "/workspace";

function gitExec(argv, { input, env } = {}) {
  return new Promise((resolve) => {
    const child = spawn("git", argv, {
      cwd: WORKSPACE,
      env: { ...process.env, ...env },
      stdio: ["pipe", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    if (input != null) {
      child.stdin.write(input);
      child.stdin.end();
    } else {
      child.stdin.end();
    }
    child.stdout.on("data", (d) => (stdout += d.toString("utf8")));
    child.stderr.on("data", (d) => (stderr += d.toString("utf8")));
    child.on("exit", (code) => resolve({ exitCode: code, stdout, stderr }));
    child.on("error", (err) => resolve({ exitCode: -1, stdout, stderr: stderr + err.message }));
  });
}

export async function gitStatus() {
  const r = await gitExec(["status", "--short", "--branch"]);
  if (r.exitCode !== 0) throw new Error(`git status failed: ${r.stderr}`);
  return r.stdout;
}

export async function gitDiff(path) {
  const argv = ["diff", "--no-color"];
  if (path) argv.push("--", path);
  const r = await gitExec(argv);
  if (r.exitCode !== 0) throw new Error(`git diff failed: ${r.stderr}`);
  return r.stdout;
}

/**
 * Auto-stage exactly the files in `touchedFiles` (relative to /workspace),
 * then commit. Refuses if `subject` looks like an amend/push request.
 */
export async function gitCommit({ subject, body, touchedFiles, identity, skipHooks }) {
  if (typeof subject !== "string" || subject.length === 0) {
    throw new Error("subject is required");
  }
  // Block obvious abuse vectors in the subject/body — these aren't `git` flags
  // when used as commit message text, but they signal intent we should refuse.
  for (const banned of ["--amend", "--force", " push ", "--no-verify"]) {
    if (subject.toLowerCase().includes(banned.trim()) || (body || "").toLowerCase().includes(banned.trim())) {
      throw new Error(`commit message references forbidden operation '${banned.trim()}'`);
    }
  }

  if (!touchedFiles || touchedFiles.size === 0) {
    throw new Error("no files touched this iteration; nothing to commit");
  }

  // Reset the index, then add only the touched files.
  const resetR = await gitExec(["reset"]);
  if (resetR.exitCode !== 0) throw new Error(`git reset failed: ${resetR.stderr}`);

  // Always include IMPLEMENTATIONPLAN.md since mark_* may have touched it.
  const filesToAdd = new Set(touchedFiles);
  filesToAdd.add("IMPLEMENTATIONPLAN.md");

  // Filter to only files git knows or that exist.
  const args = ["add", "--"];
  for (const f of filesToAdd) args.push(f);
  const addR = await gitExec(args);
  if (addR.exitCode !== 0) {
    throw new Error(`git add failed: ${addR.stderr}`);
  }

  // Verify we have something to commit (auto-add of non-existent files silently
  // skips them; we don't want an empty commit).
  const cachedR = await gitExec(["diff", "--cached", "--name-only"]);
  if (cachedR.exitCode !== 0) throw new Error(`git diff --cached failed: ${cachedR.stderr}`);
  if (!cachedR.stdout.trim()) {
    throw new Error("nothing staged after add — touched files may not exist or be ignored");
  }

  const commitArgs = ["commit", "-F", "-"];
  if (skipHooks) commitArgs.push("--no-verify");
  commitArgs.push("--no-edit");

  const fullMessage = body ? `${subject}\n\n${body}\n` : subject + "\n";
  const env = {
    GIT_AUTHOR_NAME: identity.authorName,
    GIT_AUTHOR_EMAIL: identity.authorEmail,
    GIT_COMMITTER_NAME: identity.authorName,
    GIT_COMMITTER_EMAIL: identity.authorEmail,
  };
  const r = await gitExec(commitArgs, { input: fullMessage, env });
  if (r.exitCode !== 0) {
    throw new Error(`git commit failed: ${r.stderr || r.stdout}`);
  }
  return { ok: true, files: [...filesToAdd], message: r.stdout.trim() };
}
