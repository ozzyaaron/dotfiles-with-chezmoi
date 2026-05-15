import { test } from "node:test";
import assert from "node:assert/strict";
import { IterationState } from "../src/iteration-state.js";

const Q = { maxToolCalls: 3, maxBytesRead: 100, maxBytesWritten: 50 };

test("recordCall increments and trips on overflow", () => {
  const s = new IterationState(Q);
  s.recordCall();
  s.recordCall();
  s.recordCall();
  assert.throws(() => s.recordCall(), /max_tool_calls/);
  assert.equal(s.terminated, true);
});

test("recordRead trips on byte overflow", () => {
  const s = new IterationState(Q);
  s.recordRead(50);
  s.recordRead(40);
  assert.throws(() => s.recordRead(20), /max_bytes_read/);
});

test("recordWrite tracks touched files and trips on overflow", () => {
  const s = new IterationState(Q);
  s.recordWrite(10, "a.txt");
  s.recordWrite(20, "b/c.txt");
  assert.deepEqual([...s.touchedFiles].sort(), ["a.txt", "b/c.txt"]);
  assert.throws(() => s.recordWrite(30, "d.txt"), /max_bytes_written/);
});

test("recordWrite with null relPath only updates bytes", () => {
  const s = new IterationState(Q);
  s.recordWrite(10, null);
  assert.equal(s.touchedFiles.size, 0);
});

test("calls after termination throw immediately", () => {
  const s = new IterationState(Q);
  s.recordCall();
  s.recordCall();
  s.recordCall();
  try { s.recordCall(); } catch (_) {}
  assert.throws(() => s.recordCall(), /already terminated/);
});
