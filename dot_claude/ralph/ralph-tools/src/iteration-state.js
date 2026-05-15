// Per-iteration state: tool call count, byte counters, set of files the LLM
// touched (for git_commit auto-staging).
//
// Lifetime: one "iteration" is one `claude -p` invocation. The MCP server
// process persists across iterations if claude reuses it, so we reset state
// on session boundaries. The cheap way: a `begin_iteration` tool call from
// the loop driver's prompt header, OR reset on the first tool call after
// idle. For v1, the state is constructed fresh each `claude -p` because the
// server is spawned per-session (stdio MCP transport behavior).

export class IterationState {
  constructor(quotas) {
    this.quotas = quotas;
    this.toolCalls = 0;
    this.bytesRead = 0;
    this.bytesWritten = 0;
    /** @type {Set<string>} relative-to-/workspace paths the LLM wrote/patched */
    this.touchedFiles = new Set();
    this.terminated = false;
    this.terminationReason = null;
  }

  recordCall() {
    if (this.terminated) {
      throw new Error(`iteration already terminated: ${this.terminationReason}`);
    }
    this.toolCalls += 1;
    if (this.toolCalls > this.quotas.maxToolCalls) {
      this.terminated = true;
      this.terminationReason = `quota exhausted: max_tool_calls (${this.quotas.maxToolCalls})`;
      throw new Error(this.terminationReason);
    }
  }

  recordRead(bytes) {
    this.bytesRead += bytes;
    if (this.bytesRead > this.quotas.maxBytesRead) {
      this.terminated = true;
      this.terminationReason = `quota exhausted: max_bytes_read (${this.quotas.maxBytesRead})`;
      throw new Error(this.terminationReason);
    }
  }

  recordWrite(bytes, relPath) {
    this.bytesWritten += bytes;
    if (this.bytesWritten > this.quotas.maxBytesWritten) {
      this.terminated = true;
      this.terminationReason = `quota exhausted: max_bytes_written (${this.quotas.maxBytesWritten})`;
      throw new Error(this.terminationReason);
    }
    if (relPath) {
      this.touchedFiles.add(relPath);
    }
  }

  markTouched(relPath) {
    this.touchedFiles.add(relPath);
  }
}
