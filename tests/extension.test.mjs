import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const extensionUrl = pathToFileURL(resolve("extensions/continuum.ts")).href;
const originalCwd = process.cwd();
const roots = [];

function project() {
  const root = mkdtempSync(join(tmpdir(), "continuum-extension-"));
  roots.push(root);
  mkdirSync(join(root, ".agent"), { recursive: true });
  writeFileSync(
    join(root, ".agent/project.json"),
    JSON.stringify({ name: "extdemo", repo: root, model: "deepseek/deepseek-flash" }),
  );
  writeFileSync(join(root, "TASK.md"), "# Task\n- [ ] AC-1: works\n");
  writeFileSync(join(root, "PLAN.md"), "# Plan\n");
  const session = join(root, "session.jsonl");
  writeFileSync(
    session,
    [
      JSON.stringify({ type: "session", version: 3, id: "extdemo-20261021", timestamp: "2026-10-21T00:00:00Z" }),
      JSON.stringify({ type: "message", id: "m1", parentId: null, message: { role: "user", content: "hi" } }),
      "",
    ].join("\n"),
  );
  return { root, session };
}

function register() {
  const handlers = new Map();
  const pi = { on(name, fn) { handlers.set(name, fn); } };
  return { handlers, pi };
}

async function load(projectRoot) {
  process.chdir(projectRoot);
  const { default: registerExtension } = await import(`${extensionUrl}?v=${Date.now()}-${Math.random()}`);
  const runtime = register();
  registerExtension(runtime.pi);
  return runtime.handlers;
}

function ctx(session) {
  return {
    sessionManager: {
      getSessionFile: () => session,
      getLeafEntry: () => ({ id: "m1" }),
    },
    model: { id: "deepseek/deepseek-flash" },
  };
}

try {
  {
    const { root, session } = project();
    const handlers = await load(root);
    const context = ctx(session);
    await handlers.get("session_start")({}, context);
    await handlers.get("session_shutdown")({}, context);

    const active = JSON.parse(readFileSync(join(root, ".agent/active.json"), "utf8"));
    assert.equal(active.session_id, "extdemo-20261021");
    const archive = join(root, ".agent/sessions/days/2026-10-21/extdemo-20261021");
    const manifest = JSON.parse(readFileSync(join(archive, "manifest.json"), "utf8"));
    assert.equal(manifest.entry_count, 2);
    assert.equal(manifest.last_entry_id, "m1");
    assert.deepEqual(manifest.missing_evidence, []);
    assert.ok(manifest.files["TASK.md"], "TASK.md inventory");
    assert.ok(existsSync(join(archive, "TASK.md")), "TASK.md archived");
    assert.ok(existsSync(join(archive, "PLAN.md")), "PLAN.md archived");

    const before = readFileSync(join(root, ".agent/active.json"), "utf8");
    process.env.PI_SUBAGENT_CHILD = "1";
    await handlers.get("session_start")({}, context);
    assert.equal(readFileSync(join(root, ".agent/active.json"), "utf8"), before, "child modified active state");
    delete process.env.PI_SUBAGENT_CHILD;
    console.log("PASS: extension snapshot/inventory and child guard");
  }

  {
    const { root, session } = project();
    const RealDate = Date;
    let now = new RealDate("2026-10-21T23:59:00Z").valueOf();
    class FakeDate extends RealDate {
      constructor(...args) {
        super(...(args.length ? args : [now]));
      }
      static now() {
        return now;
      }
    }
    globalThis.Date = FakeDate;
    try {
      const handlers = await load(root);
      const context = ctx(session);
      await handlers.get("session_start")({}, context);

      now = new RealDate("2026-10-22T00:01:00Z").valueOf();
      writeFileSync(
        session,
        readFileSync(session, "utf8") +
          JSON.stringify({
            type: "message",
            id: "m2",
            parentId: "m1",
            message: { role: "assistant", content: "after midnight" },
          }) +
          "\n",
      );
      await handlers.get("turn_end")({}, context);

      const oldArchive = join(root, ".agent/sessions/days/2026-10-21/extdemo-20261021");
      const newArchive = join(root, ".agent/sessions/days/2026-10-22/extdemo-20261021");
      assert.ok(existsSync(join(oldArchive, "session.jsonl")), "boundary snapshot did not archive the ending day");
      assert.equal(existsSync(newArchive), false, "boundary snapshot used the new day as the archive day");
      assert.equal(
        JSON.parse(readFileSync(join(root, ".agent/active.json"), "utf8")).utc_day,
        "2026-10-22",
        "active day did not advance",
      );

      await handlers.get("session_shutdown")({}, context);
      assert.ok(existsSync(join(newArchive, "session.jsonl")), "shutdown snapshot did not use the current day");
      console.log("PASS: UTC-boundary snapshot uses the day that ended");
    } finally {
      globalThis.Date = RealDate;
    }
  }

  {
    const { root } = project();
    writeFileSync(join(root, "TASK.md"), "# Task\n");
    const bad = join(root, "bad.jsonl");
    writeFileSync(
      bad,
      [
        JSON.stringify({ type: "session", version: 3, id: "badsession", timestamp: "2026-10-21T00:00:00Z" }),
        "BROKEN",
        JSON.stringify({ type: "message", id: "m2", parentId: null, message: { role: "user", content: "later" } }),
        "",
      ].join("\n"),
    );
    const handlers = await load(root);
    const context = ctx(bad);
    await handlers.get("session_shutdown")({}, context);
    const ledger = readFileSync(join(root, ".agent/ledger.ndjson"), "utf8");
    assert.match(ledger, /snapshot_error/);
    assert.equal(existsSync(join(root, ".agent/sessions/days/2026-10-21/badsession/manifest.json")), false);
    console.log("PASS: extension rejects malformed middle JSONL");
  }
} finally {
  process.chdir(originalCwd);
  for (const root of roots) rmSync(root, { recursive: true, force: true });
}
