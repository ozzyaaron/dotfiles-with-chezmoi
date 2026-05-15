// IMPLEMENTATIONPLAN.md parser + mutators for mark_complete / mark_blocked /
// mark_all_done. This is the only path that mutates the plan; `write_workspace_file`
// refuses direct writes.

import fs from "node:fs";

const PLAN_PATH = "/workspace/IMPLEMENTATIONPLAN.md";

function readPlan() {
  return fs.readFileSync(PLAN_PATH, "utf8");
}

function writePlan(content) {
  fs.writeFileSync(PLAN_PATH, content, "utf8");
}

/**
 * Bullet identifier: prefer an explicit `[id:xyz]` marker; otherwise use the
 * canonicalized text after `- [ ]` / `- [x]` (lowercased, whitespace-collapsed).
 */
function bulletKey(line) {
  const idMatch = line.match(/\[id:([a-z0-9_-]+)\]/i);
  if (idMatch) return idMatch[1].toLowerCase();
  const m = line.match(/^- \[[ xX]\]\s+(.+)$/);
  if (!m) return null;
  return m[1].toLowerCase().replace(/\s+/g, " ").trim();
}

export function markComplete(bulletId) {
  const target = bulletId.toLowerCase().replace(/\s+/g, " ").trim();
  const content = readPlan();
  const lines = content.split("\n");
  let mutated = false;
  for (let i = 0; i < lines.length; i++) {
    const key = bulletKey(lines[i]);
    if (!key) continue;
    if (key !== target && !target.endsWith(key) && !key.endsWith(target)) continue;
    if (lines[i].match(/^- \[[xX]\]/)) {
      throw new Error(`bullet already complete: ${bulletId}`);
    }
    lines[i] = lines[i].replace(/^- \[ \]/, "- [x]");
    mutated = true;
    break;
  }
  if (!mutated) {
    throw new Error(`bullet not found: ${bulletId}`);
  }
  writePlan(lines.join("\n"));
  return { ok: true };
}

export function markBlocked(bulletId, reason) {
  if (typeof reason !== "string" || reason.length === 0) {
    throw new Error("reason is required");
  }
  const target = bulletId.toLowerCase().replace(/\s+/g, " ").trim();
  const content = readPlan();
  const lines = content.split("\n");
  let bulletText = null;
  for (let i = 0; i < lines.length; i++) {
    const key = bulletKey(lines[i]);
    if (!key) continue;
    if (key !== target && !target.endsWith(key) && !key.endsWith(target)) continue;
    bulletText = lines[i];
    break;
  }
  if (!bulletText) {
    throw new Error(`bullet not found: ${bulletId}`);
  }

  // Find or create a `## Blocked` section.
  let blockedIdx = lines.findIndex((l) => /^## Blocked\s*$/.test(l));
  if (blockedIdx === -1) {
    // Append a new section at the end.
    if (lines[lines.length - 1] !== "") lines.push("");
    lines.push("## Blocked", "");
    blockedIdx = lines.length - 2;
  }

  // Insert the entry just below the heading.
  const entry = `${bulletText.trim()} — **blocked**: ${reason}`;
  lines.splice(blockedIdx + 1, 0, entry);
  writePlan(lines.join("\n"));
  return { ok: true, bullet: bulletText };
}

export function markAllDone() {
  const content = readPlan();
  // Verify there really are no `- [ ]` bullets left.
  for (const line of content.split("\n")) {
    if (/^- \[ \]/.test(line)) {
      throw new Error("plan still has unchecked bullets; cannot mark all done");
    }
  }
  return { ok: true };
}

export function readPlanText() {
  return readPlan();
}
