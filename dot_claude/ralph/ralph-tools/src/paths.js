// Symlink-safe path resolution scoped to /workspace.
//
// Threat model:
// - LLM passes a path string to a tool.
// - The path may contain `..`, may include a symlink anywhere along the chain,
//   or may match a `sensitive_paths` glob.
// - We must refuse paths that would escape /workspace or read/write masked files.

import fs from "node:fs";
import path from "node:path";

const WORKSPACE = "/workspace";

// Convert a glob pattern (simple subset: `*`, `**`, `?`) to a RegExp.
function globToRegex(glob) {
  let re = "^";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") {
        re += ".*";
        i++;
      } else {
        re += "[^/]*";
      }
    } else if (c === "?") {
      re += "[^/]";
    } else if ("\\^$.+|()[]{}".includes(c)) {
      re += "\\" + c;
    } else {
      re += c;
    }
  }
  re += "$";
  return new RegExp(re);
}

export class PathGuard {
  constructor(sensitivePaths) {
    this.sensitiveRegexes = sensitivePaths.map(globToRegex);
  }

  isSensitive(relPath) {
    return this.sensitiveRegexes.some((re) => re.test(relPath));
  }

  /**
   * Resolve `inputPath` (which may be relative or absolute) into a canonical
   * absolute path that MUST live under /workspace and MUST NOT match any
   * sensitive_paths glob.
   *
   * @param {string} inputPath
   * @param {object} opts
   * @param {"read" | "write"} opts.intent
   * @returns {{ absPath: string, relPath: string }}
   */
  resolve(inputPath, { intent }) {
    if (typeof inputPath !== "string" || inputPath.length === 0) {
      throw new Error("path must be a non-empty string");
    }
    if (inputPath.includes("\0")) {
      throw new Error("path may not contain null bytes");
    }

    // Normalize to an absolute path under WORKSPACE.
    let candidate;
    if (path.isAbsolute(inputPath)) {
      candidate = path.normalize(inputPath);
    } else {
      candidate = path.normalize(path.join(WORKSPACE, inputPath));
    }
    if (!candidate.startsWith(WORKSPACE + "/") && candidate !== WORKSPACE) {
      throw new Error(`path escapes /workspace: ${inputPath}`);
    }

    // For READS, follow symlinks then verify the resolved path is still under
    // WORKSPACE. For WRITES, the final segment must NOT be a symlink (O_NOFOLLOW
    // semantics emulated below by lstat).
    const segments = candidate.slice(WORKSPACE.length + 1).split("/").filter(Boolean);

    // Walk parents, refusing symlinks that escape WORKSPACE.
    let walked = WORKSPACE;
    for (const seg of segments) {
      walked = path.join(walked, seg);
      let stat;
      try {
        stat = fs.lstatSync(walked);
      } catch (err) {
        if (err.code === "ENOENT") {
          // For writes, intermediate dirs must exist (the LLM creates them
          // explicitly). For reads, missing path is just ENOENT — let the caller
          // surface that.
          break;
        }
        throw err;
      }
      if (stat.isSymbolicLink()) {
        const target = fs.readlinkSync(walked);
        const resolved = path.isAbsolute(target)
          ? path.normalize(target)
          : path.normalize(path.join(path.dirname(walked), target));
        if (!resolved.startsWith(WORKSPACE + "/") && resolved !== WORKSPACE) {
          throw new Error(
            `path traverses symlink escaping /workspace: ${inputPath} → ${resolved}`
          );
        }
        if (intent === "write" && walked === candidate) {
          // Final segment is a symlink; refuse to write through it.
          throw new Error(`write target is a symlink: ${inputPath}`);
        }
      }
    }

    const relPath = candidate.slice(WORKSPACE.length + 1);
    if (this.isSensitive(relPath)) {
      throw new Error(`path is in sensitive_paths: ${relPath}`);
    }

    return { absPath: candidate, relPath };
  }
}
