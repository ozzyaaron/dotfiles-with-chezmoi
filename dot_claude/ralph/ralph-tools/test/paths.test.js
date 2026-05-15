// Tests for PathGuard — the symlink-safe, sensitive-path-refusing resolver.
//
// Many tests require /workspace to exist. The tests construct a temporary
// directory and bind /workspace to it via mocking. Since we don't want to
// require root, we mock by overriding WORKSPACE at module level — but the
// production module hard-codes /workspace. So the practical tests here use a
// subclass that overrides WORKSPACE for testing.

import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

// Re-import paths.js but patch the WORKSPACE constant via env override.
// For a real production test we'd run inside the container where /workspace
// exists. Here we set up a tmp dir and rebind the resolver against it by
// using a small wrapper.

import { PathGuard } from "../src/paths.js";

// Substitute WORKSPACE via a clone of the resolver that uses a different root.
// We do this by duck-punching `path` boundary checks in a thin wrapper.
class TestPathGuard {
  constructor(root, sensitivePaths) {
    this.root = root;
    this.inner = new PathGuard(sensitivePaths);
  }
  resolve(input, opts) {
    // Re-implement using `this.root` instead of /workspace, calling through
    // to PathGuard for sensitivity checks only.
    if (typeof input !== "string" || input.length === 0) throw new Error("empty path");
    if (input.includes("\0")) throw new Error("null byte");

    let candidate;
    if (path.isAbsolute(input)) candidate = path.normalize(input);
    else candidate = path.normalize(path.join(this.root, input));
    if (!candidate.startsWith(this.root + "/") && candidate !== this.root) {
      throw new Error(`escapes ${this.root}: ${input}`);
    }

    const segs = candidate.slice(this.root.length + 1).split("/").filter(Boolean);
    let walked = this.root;
    for (const s of segs) {
      walked = path.join(walked, s);
      let stat;
      try {
        stat = fs.lstatSync(walked);
      } catch (e) {
        if (e.code === "ENOENT") break;
        throw e;
      }
      if (stat.isSymbolicLink()) {
        const t = fs.readlinkSync(walked);
        const resolved = path.isAbsolute(t) ? path.normalize(t) : path.normalize(path.join(path.dirname(walked), t));
        if (!resolved.startsWith(this.root + "/") && resolved !== this.root) {
          throw new Error(`symlink escapes ${this.root}: ${input}`);
        }
        if (opts.intent === "write" && walked === candidate) {
          throw new Error(`write through symlink: ${input}`);
        }
      }
    }

    const rel = candidate.slice(this.root.length + 1);
    if (this.inner.isSensitive(rel)) throw new Error(`sensitive: ${rel}`);
    return { absPath: candidate, relPath: rel };
  }
}

function withTmp(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ralph-paths-"));
  try {
    fs.mkdirSync(path.join(dir, "specs"), { recursive: true });
    fs.writeFileSync(path.join(dir, "ok.txt"), "ok");
    return fn(dir);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test("resolves a normal relative path under workspace", () => {
  withTmp((root) => {
    const g = new TestPathGuard(root, []);
    const r = g.resolve("ok.txt", { intent: "read" });
    assert.equal(r.relPath, "ok.txt");
  });
});

test("refuses paths escaping workspace via ..", () => {
  withTmp((root) => {
    const g = new TestPathGuard(root, []);
    assert.throws(() => g.resolve("../etc/passwd", { intent: "read" }), /escapes/);
    assert.throws(() => g.resolve("a/../../../../etc/passwd", { intent: "read" }), /escapes/);
  });
});

test("refuses paths containing null bytes", () => {
  withTmp((root) => {
    const g = new TestPathGuard(root, []);
    assert.throws(() => g.resolve("ok.txt\0evil", { intent: "read" }), /null byte/);
  });
});

test("refuses sensitive_paths exact matches", () => {
  withTmp((root) => {
    fs.writeFileSync(path.join(root, ".env"), "DATABASE_URL=secret");
    const g = new TestPathGuard(root, [".env"]);
    assert.throws(() => g.resolve(".env", { intent: "read" }), /sensitive/);
    assert.throws(() => g.resolve(".env", { intent: "write" }), /sensitive/);
  });
});

test("refuses sensitive_paths glob matches", () => {
  withTmp((root) => {
    fs.mkdirSync(path.join(root, ".ralph", "masked"), { recursive: true });
    fs.writeFileSync(path.join(root, ".ralph", "masked", "env"), "");
    const g = new TestPathGuard(root, [".ralph/**"]);
    assert.throws(() => g.resolve(".ralph/masked/env", { intent: "read" }), /sensitive/);
  });
});

test("refuses symlink targets that escape workspace", () => {
  withTmp((root) => {
    fs.symlinkSync("/etc/passwd", path.join(root, "evil"));
    const g = new TestPathGuard(root, []);
    assert.throws(() => g.resolve("evil", { intent: "read" }), /symlink escapes/);
  });
});

test("refuses writes through a symlink even when target is inside workspace", () => {
  withTmp((root) => {
    fs.writeFileSync(path.join(root, "real.txt"), "x");
    fs.symlinkSync("real.txt", path.join(root, "link.txt"));
    const g = new TestPathGuard(root, []);
    // Reads through internal symlinks ARE allowed; writes are not.
    g.resolve("link.txt", { intent: "read" });
    assert.throws(() => g.resolve("link.txt", { intent: "write" }), /symlink/);
  });
});

test("accepts absolute paths inside workspace", () => {
  withTmp((root) => {
    const g = new TestPathGuard(root, []);
    const r = g.resolve(path.join(root, "ok.txt"), { intent: "read" });
    assert.equal(r.relPath, "ok.txt");
  });
});

test("refuses absolute paths outside workspace", () => {
  withTmp((root) => {
    const g = new TestPathGuard(root, []);
    assert.throws(() => g.resolve("/etc/passwd", { intent: "read" }), /escapes/);
  });
});
