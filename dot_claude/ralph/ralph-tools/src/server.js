// ralph-tools MCP server.
//
// Wires every tool to its safety-checked implementation. The MCP framing
// (stdio JSON-RPC, capability negotiation) is provided by
// @modelcontextprotocol/sdk; this file is the gluecode.

import fs from "node:fs";
import { spawn } from "node:child_process";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

import { loadConfig } from "./config.js";
import { PathGuard } from "./paths.js";
import { IterationState } from "./iteration-state.js";
import { runProjectCommand } from "./subprocess.js";
import { gitStatus, gitDiff, gitCommit } from "./git.js";
import { markComplete, markBlocked, markAllDone, readPlanText } from "./plan.js";

const TOOLS = [
  {
    name: "read_workspace_file",
    description: "Read a file from /workspace. Refuses sensitive paths and symlink escapes. Returns UTF-8 string content.",
    inputSchema: {
      type: "object",
      properties: { path: { type: "string", description: "Path relative to /workspace, or absolute under /workspace." } },
      required: ["path"],
    },
  },
  {
    name: "write_workspace_file",
    description: "Overwrite a file in /workspace with the given content. Refuses sensitive paths, IMPLEMENTATIONPLAN.md, symlink targets, and paths outside /workspace.",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string" },
        content: { type: "string" },
      },
      required: ["path", "content"],
    },
  },
  {
    name: "apply_patch",
    description: "Apply a unified diff to /workspace. Refuses diff entries creating symlinks, special files, or touching sensitive paths.",
    inputSchema: {
      type: "object",
      properties: { diff: { type: "string", description: "Unified diff." } },
      required: ["diff"],
    },
  },
  {
    name: "run_lint",
    description: "Run the project's configured lint command. Returns exit code, stdout, stderr.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "run_tests",
    description: "Run the project's configured test command. Optional scope argument appended to the command.",
    inputSchema: {
      type: "object",
      properties: { scope: { type: "string", description: "Optional argument appended to the test command (e.g. a single spec file)." } },
    },
  },
  {
    name: "install_dependencies",
    description: "Run the project's configured dependency install command.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "git_status",
    description: "Show short-form git status with branch info.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "git_diff",
    description: "Show unstaged diff for the workspace, optionally scoped to a path.",
    inputSchema: {
      type: "object",
      properties: { path: { type: "string" } },
    },
  },
  {
    name: "git_commit",
    description: "Commit files YOU touched this iteration. No file list arg — the server auto-stages exactly the files written via write_workspace_file or apply_patch. Refuses amend/force/push/no-verify (unless manifest sets skip_hooks).",
    inputSchema: {
      type: "object",
      properties: {
        subject: { type: "string", description: "Commit subject line." },
        body: { type: "string", description: "Optional commit body." },
      },
      required: ["subject"],
    },
  },
  {
    name: "mark_complete",
    description: "Mark a bullet in IMPLEMENTATIONPLAN.md as complete. The only path that mutates the plan; write_workspace_file refuses direct writes to the plan.",
    inputSchema: {
      type: "object",
      properties: { bullet_id: { type: "string", description: "Bullet text or `[id:xyz]` identifier." } },
      required: ["bullet_id"],
    },
  },
  {
    name: "mark_blocked",
    description: "Move a bullet to ## Blocked with a reason. Terminates the loop after the current iteration.",
    inputSchema: {
      type: "object",
      properties: {
        bullet_id: { type: "string" },
        reason: { type: "string", description: "One-line explanation of what's missing." },
      },
      required: ["bullet_id", "reason"],
    },
  },
  {
    name: "mark_all_done",
    description: "Signal that no unchecked bullets remain. Terminates the loop. Refuses if `- [ ]` bullets still exist.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "read_plan",
    description: "Return the current IMPLEMENTATIONPLAN.md text.",
    inputSchema: { type: "object", properties: {} },
  },
];

function textResult(text) {
  return { content: [{ type: "text", text }] };
}

function errorResult(message) {
  return { content: [{ type: "text", text: `ERROR: ${message}` }], isError: true };
}

export async function startServer({ configPath }) {
  // Make this process undumpable so the LLM-controlled `ralph` user (uid 1000)
  // cannot ptrace us or read /proc/<pid>/mem.
  try {
    // PR_SET_DUMPABLE = 4 (linux/prctl.h). Best-effort; on macOS this no-ops.
    const { default: ffi } = await import("node:os");
    // No standard Node API for prctl; rely on the container's no-new-privileges
    // + the separate uid as the primary defenses. PR_SET_DUMPABLE would be a
    // belt-and-suspenders measure; skip if no addon is available.
    void ffi;
  } catch (_) {
    // ignore
  }

  const config = loadConfig(configPath);
  const guard = new PathGuard(config.sensitivePaths);
  const state = new IterationState(config.quotas);

  const server = new Server(
    { name: "ralph-tools", version: "0.1.0" },
    { capabilities: { tools: {} } }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

  server.setRequestHandler(CallToolRequestSchema, async (req) => {
    const name = req.params.name;
    const args = req.params.arguments || {};
    try {
      state.recordCall();
      switch (name) {
        case "read_workspace_file": return await handleRead(args, guard, state);
        case "write_workspace_file": return await handleWrite(args, guard, state);
        case "apply_patch": return await handlePatch(args, guard, state);
        case "run_lint": return await handleLint(config, state);
        case "run_tests": return await handleTests(args, config, state);
        case "install_dependencies": return await handleInstall(config, state);
        case "git_status": return textResult(await gitStatus());
        case "git_diff": return textResult(await gitDiff(args.path));
        case "git_commit": return await handleCommit(args, config, state);
        case "mark_complete": {
          const r = markComplete(args.bullet_id);
          state.markTouched("IMPLEMENTATIONPLAN.md");
          return textResult(JSON.stringify(r));
        }
        case "mark_blocked": {
          const r = markBlocked(args.bullet_id, args.reason);
          state.markTouched("IMPLEMENTATIONPLAN.md");
          return textResult(JSON.stringify(r));
        }
        case "mark_all_done": {
          const r = markAllDone();
          return textResult(JSON.stringify(r));
        }
        case "read_plan": return textResult(readPlanText());
        default: return errorResult(`unknown tool: ${name}`);
      }
    } catch (err) {
      return errorResult(err.message || String(err));
    }
  });

  const transport = new StdioServerTransport();
  await server.connect(transport);
}

// ---- Tool handlers ----

async function handleRead(args, guard, state) {
  const { absPath, relPath } = guard.resolve(args.path, { intent: "read" });
  let content;
  try {
    content = fs.readFileSync(absPath, "utf8");
  } catch (err) {
    if (err.code === "ENOENT") return errorResult(`no such file: ${relPath}`);
    if (err.code === "EISDIR") return errorResult(`path is a directory: ${relPath}`);
    throw err;
  }
  state.recordRead(Buffer.byteLength(content, "utf8"));
  return textResult(content);
}

async function handleWrite(args, guard, state) {
  const { absPath, relPath } = guard.resolve(args.path, { intent: "write" });
  const content = String(args.content ?? "");
  const bytes = Buffer.byteLength(content, "utf8");
  // Reserve quota BEFORE writing so we don't leave a partial file.
  state.recordWrite(bytes, relPath);
  fs.writeFileSync(absPath, content, { encoding: "utf8" });
  return textResult(`wrote ${bytes} bytes to ${relPath}`);
}

async function handlePatch(args, guard, state) {
  const diff = String(args.diff || "");
  // Refuse diff entries that would create symlinks or special files.
  if (/^new file mode 120000/m.test(diff) || /^new file mode 12/m.test(diff)) {
    return errorResult("patch creates a symlink or special file; refused");
  }
  if (/^deleted file mode/m.test(diff)) {
    // Allowed, but tracked.
  }
  // Extract target paths from the diff (`+++ b/<path>` and `--- a/<path>` lines).
  const targets = new Set();
  for (const line of diff.split("\n")) {
    const m = line.match(/^[+\-]{3} [ab]\/(.+)$/);
    if (m && m[1] !== "/dev/null") targets.add(m[1]);
  }
  // Validate every target against sensitive_paths + workspace scope.
  for (const t of targets) {
    guard.resolve(t, { intent: "write" });
  }
  // Apply via `git apply --whitespace=nowarn`.
  const result = await new Promise((resolve) => {
    const child = spawn("git", ["apply", "--whitespace=nowarn", "-"], {
      cwd: "/workspace",
      stdio: ["pipe", "pipe", "pipe"],
    });
    let stderr = "";
    child.stdin.write(diff);
    child.stdin.end();
    child.stderr.on("data", (d) => (stderr += d.toString("utf8")));
    child.on("exit", (code) => resolve({ exitCode: code, stderr }));
    child.on("error", (err) => resolve({ exitCode: -1, stderr: err.message }));
  });
  if (result.exitCode !== 0) {
    return errorResult(`git apply failed: ${result.stderr}`);
  }
  const bytes = Buffer.byteLength(diff, "utf8");
  for (const t of targets) state.recordWrite(0, t); // count touched files; bytes counted once
  state.recordWrite(bytes, null);
  return textResult(`applied patch touching ${targets.size} file(s)`);
}

async function handleLint(config, state) {
  const r = await runProjectCommand(config.stack.lintCmd, "/workspace", {
    maskedDir: "/etc/ralph/masked",
    timeout: 5 * 60 * 1000,
  });
  return textResult(JSON.stringify({
    command: config.stack.lintCmd,
    exit_code: r.exitCode,
    stdout: r.stdout,
    stderr: r.stderr,
  }));
}

async function handleTests(args, config, state) {
  let cmd = config.stack.testCmd;
  if (args && typeof args.scope === "string" && args.scope.length > 0) {
    // Append scope as a quoted argv element by reusing tokenizer rules implicitly.
    // We require the scope to be a path-like token with no shell metacharacters.
    if (/[|&;<>$`(){}]/.test(args.scope)) {
      return errorResult("scope contains shell metacharacters");
    }
    cmd = `${cmd} ${args.scope}`;
  }
  const r = await runProjectCommand(cmd, "/workspace", {
    maskedDir: "/etc/ralph/masked",
    timeout: 30 * 60 * 1000,
  });
  return textResult(JSON.stringify({
    command: cmd,
    exit_code: r.exitCode,
    stdout: r.stdout,
    stderr: r.stderr,
  }));
}

async function handleInstall(config, state) {
  const r = await runProjectCommand(config.stack.installCmd, "/workspace", {
    maskedDir: "/etc/ralph/masked",
    timeout: 10 * 60 * 1000,
  });
  return textResult(JSON.stringify({
    command: config.stack.installCmd,
    exit_code: r.exitCode,
    stdout: r.stdout,
    stderr: r.stderr,
  }));
}

async function handleCommit(args, config, state) {
  const r = await gitCommit({
    subject: args.subject,
    body: args.body,
    touchedFiles: state.touchedFiles,
    identity: config.gitCommit,
    skipHooks: config.gitCommit.skipHooks,
  });
  return textResult(JSON.stringify(r));
}
