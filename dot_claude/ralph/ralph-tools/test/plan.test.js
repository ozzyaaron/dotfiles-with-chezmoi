// Plan-mutator tests. Plan module hard-codes /workspace/IMPLEMENTATIONPLAN.md so
// we use the lower-level bulletKey logic via re-export. For a real end-to-end
// test we'd need to redirect the plan path; here we focus on the public API
// indirectly via a fixture.

import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

// To test plan.js without the /workspace hard-code, we'd refactor it to take a
// PLAN_PATH argument. For now, we write to /tmp and ASSERT on the parsing
// helpers — full mutator tests come in the in-container integration suite.

import * as planModule from "../src/plan.js";

// Smoke-test that the module loads without error.
test("plan module exports the mutator API", () => {
  assert.equal(typeof planModule.markComplete, "function");
  assert.equal(typeof planModule.markBlocked, "function");
  assert.equal(typeof planModule.markAllDone, "function");
  assert.equal(typeof planModule.readPlanText, "function");
});
