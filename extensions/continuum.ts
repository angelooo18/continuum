/**
 * Continuum project ledger
 *
 * Writes a UTC audit ledger and day snapshots for a Pi project.
 *
 * This is deliberately conservative:
 * - it never rewrites the live Pi session;
 * - it copies only complete JSONL entries into day snapshots;
 * - it writes manifests atomically;
 * - subagent child sessions are inert;
 * - snapshot failures are logged, never allowed to break the agent turn.
 */

import { createHash } from "node:crypto";
import {
  appendFileSync,
  copyFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, relative, resolve, sep } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Ctx = any;

interface ProjectConfig {
  name: string;
  repo: string;
  model?: string;
  clm?: Record<string, unknown>;
}

const AGENT_DIR = ".agent";
const PROJECT_FILE = join(AGENT_DIR, "project.json");
const LEDGER_FILE = join(AGENT_DIR, "ledger.ndjson");
const ACTIVE_FILE = join(AGENT_DIR, "active.json");
const EVIDENCE_FILES = [
  "TASK.md",
  "PLAN.md",
  "VERDICT.json",
  "HANDOFF.md",
  "diff.patch",
  "tests.log",
];
const REQUIRED_EVIDENCE = ["TASK.md", "PLAN.md"];

let lastSnapshotDay: string | null = null;

function utcDay(date = new Date()): string {
  return date.toISOString().slice(0, 10);
}

function nowIso(): string {
  return new Date().toISOString();
}

function ensureDir(path: string): void {
  mkdirSync(path, { recursive: true });
}

function readProject(): ProjectConfig | null {
  try {
    return JSON.parse(readFileSync(PROJECT_FILE, "utf8")) as ProjectConfig;
  } catch {
    return null;
  }
}

function isContinuumProject(): boolean {
  return readProject() !== null;
}

function sha256(text: string | Buffer): string {
  return createHash("sha256").update(text).digest("hex");
}

function atomicWrite(path: string, data: string): void {
  ensureDir(dirname(path));
  const tmp = `${path}.tmp-${process.pid}-${Date.now()}`;
  writeFileSync(tmp, data, "utf8");
  renameSync(tmp, path);
}

function appendLedger(event: string, fields: Record<string, unknown> = {}): void {
  ensureDir(AGENT_DIR);
  const row = { ts: nowIso(), event, ...fields };
  appendFileSync(LEDGER_FILE, `${JSON.stringify(row)}\n`, "utf8");
}

/**
 * Keep complete JSONL records; the live session is never modified.
 * Only a partial final line is droppable. A malformed line with data after it
 * is corruption and must abort the snapshot instead of truncating history.
 */
function readCompleteJsonl(path: string): string {
  const raw = readFileSync(path, "utf8");
  const lines = raw.split("\n");
  const kept: string[] = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].replace(/\r$/, "");
    if (!line.trim()) continue;
    try {
      JSON.parse(line);
    } catch (error) {
      const later = lines.slice(index + 1).some((candidate) => candidate.trim());
      if (later) {
        throw new Error(`malformed JSONL at line ${index + 1}: ${String(error)}`);
      }
      break;
    }
    kept.push(line);
  }
  return `${kept.join("\n")}\n`;
}

function jsonlStats(text: string): { entryCount: number; lastEntryId: string | null } {
  const rows = text.split("\n").filter((line) => line.trim());
  let lastEntryId: string | null = null;
  for (let index = rows.length - 1; index >= 0; index -= 1) {
    try {
      const row = JSON.parse(rows[index]);
      if (row && typeof row.id === "string") {
        lastEntryId = row.id;
        break;
      }
    } catch {
      // readCompleteJsonl already validated these lines.
    }
  }
  return { entryCount: rows.length, lastEntryId };
}

function inventory(root: string): Record<string, { sha256: string; bytes: number }> {
  const files: Record<string, { sha256: string; bytes: number }> = {};
  const walk = (dir: string): void => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.isFile()) {
        const rel = relative(root, full).split(sep).join("/");
        if (rel === "manifest.json" || rel === "seal.json") continue;
        files[rel] = {
          sha256: sha256(readFileSync(full)),
          bytes: statSync(full).size,
        };
      }
    }
  };
  walk(root);
  return files;
}

function copyEvidence(dayDir: string): string[] {
  const root = process.cwd();
  for (const name of EVIDENCE_FILES) {
    const source = join(root, name);
    const destination = join(dayDir, name);
    if (existsSync(source)) {
      copyFileSync(source, destination);
    } else if (existsSync(destination)) {
      unlinkSync(destination);
    }
  }
  return REQUIRED_EVIDENCE.filter((name) => !existsSync(join(root, name)));
}

function isSubagentChild(): boolean {
  return process.env.PI_SUBAGENT_CHILD === "1";
}

function sessionIdFromFile(sessionFile: string): string {
  try {
    const first = readFileSync(sessionFile, "utf8").split("\n", 1)[0];
    const header = JSON.parse(first);
    return typeof header.id === "string" ? header.id : basename(sessionFile, ".jsonl");
  } catch {
    return basename(sessionFile, ".jsonl");
  }
}

function snapshot(ctx: Ctx, reason: string, archiveDay = utcDay()): void {
  const rawSessionFile = ctx.sessionManager?.getSessionFile?.();
  if (!rawSessionFile) return;
  const sessionFile = resolve(rawSessionFile);
  if (!existsSync(sessionFile)) return;

  const day = archiveDay;
  const sessionId = sessionIdFromFile(sessionFile);
  const dayDir = join(AGENT_DIR, "sessions", "days", day, sessionId);
  ensureDir(dayDir);
  const complete = readCompleteJsonl(sessionFile);
  const snapshotFile = join(dayDir, "session.jsonl");
  atomicWrite(snapshotFile, complete);

  // Subagent runtime artifacts live under the Pi session root, not next to
  // the parent .jsonl file. Copy this session's child runs and per-run files.
  const sessionRoot = join(process.cwd(), AGENT_DIR, "sessions");
  const childDir = join(sessionRoot, basename(sessionFile, ".jsonl"));
  if (existsSync(childDir)) {
    cpSync(childDir, join(dayDir, "subagent-sessions"), { recursive: true, force: true });
  }

  const subagentArtifacts = join(sessionRoot, "subagent-artifacts");
  if (existsSync(subagentArtifacts)) {
    const dest = join(dayDir, "subagent-artifacts");
    ensureDir(dest);
    for (const entry of readdirSync(subagentArtifacts)) {
      if (!entry.endsWith("_meta.json")) continue;
      try {
        const meta = JSON.parse(readFileSync(join(subagentArtifacts, entry), "utf8"));
        if (meta.parentSessionId !== sessionId || !meta.runId) continue;
        for (const file of readdirSync(subagentArtifacts)) {
          if (file.startsWith(`${meta.runId}_`)) {
            cpSync(join(subagentArtifacts, file), join(dest, file), { force: true });
          }
        }
      } catch {
        // Best-effort: a malformed meta file must not break the turn.
      }
    }
  }

  // pi-interactive-subagents-style artifacts, when present.
  const interactiveDir = join(sessionRoot, "artifacts", sessionId);
  if (existsSync(interactiveDir)) {
    cpSync(interactiveDir, join(dayDir, "artifacts"), { recursive: true, force: true });
  }

  const missingEvidence = copyEvidence(dayDir);
  const stats = jsonlStats(complete);
  const leaf = ctx.sessionManager?.getLeafEntry?.();
  const manifest = {
    project: readProject()?.name ?? null,
    day,
    session_id: sessionId,
    session_file: sessionFile,
    leaf_id: leaf?.id ?? null,
    snapshot_at: nowIso(),
    reason,
    model: ctx.model?.id ?? ctx.model?.modelId ?? null,
    source_bytes: statSync(sessionFile).size,
    bytes: statSync(snapshotFile).size,
    sha256: sha256(complete),
    entry_count: stats.entryCount,
    last_entry_id: stats.lastEntryId,
    missing_evidence: missingEvidence,
    files: inventory(dayDir),
  };
  atomicWrite(join(dayDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);

  const previousSealPath = join(dayDir, "seal.json");
  let previousSeal: string | null = null;
  try {
    previousSeal = JSON.parse(readFileSync(previousSealPath, "utf8")).seal ?? null;
  } catch {
    // first seal for this day
  }
  const seal = {
    ...manifest,
    previous_seal: previousSeal,
    seal: sha256(`${previousSeal ?? ""}\n${manifest.sha256}\n${manifest.snapshot_at}`),
  };
  atomicWrite(previousSealPath, `${JSON.stringify(seal, null, 2)}\n`);
  appendLedger("day_seal", { day, session_id: sessionId, reason, sha256: manifest.sha256 });
  // The archive day may be yesterday when sealing at a UTC boundary; the
  // session itself is now in the current day.
  lastSnapshotDay = utcDay();
}

function writeActive(ctx: Ctx): void {
  const rawSessionFile = ctx.sessionManager?.getSessionFile?.();
  if (!rawSessionFile) return;
  const sessionFile = resolve(rawSessionFile);
  const leaf = ctx.sessionManager?.getLeafEntry?.();
  const active = {
    project: readProject()?.name ?? null,
    utc_day: utcDay(),
    session_id: sessionIdFromFile(sessionFile),
    session_file: sessionFile,
    leaf_id: leaf?.id ?? null,
    model: ctx.model?.id ?? ctx.model?.modelId ?? null,
    updated_at: nowIso(),
  };
  atomicWrite(ACTIVE_FILE, `${JSON.stringify(active, null, 2)}\n`);
}

export default function (pi: ExtensionAPI): void {
  pi.on("session_start", async (_event, ctx: Ctx) => {
    if (!isContinuumProject() || isSubagentChild()) return;
    ensureDir(AGENT_DIR);
    ensureDir(join(AGENT_DIR, "sessions", "days"));
    writeActive(ctx);
    appendLedger("session_start", {
      session_id: ctx.sessionManager?.getSessionFile?.() ?? null,
    });
    lastSnapshotDay = utcDay();
  });

  pi.on("turn_end", async (_event, ctx: Ctx) => {
    if (!isContinuumProject() || isSubagentChild()) return;
    const day = utcDay();
    if (lastSnapshotDay && lastSnapshotDay !== day) {
      try {
        snapshot(ctx, "utc-day-boundary", lastSnapshotDay);
      } catch (error) {
        appendLedger("snapshot_error", { reason: "utc-day-boundary", error: String(error) });
      }
    }
    writeActive(ctx);
    appendLedger("turn_end", {
      session_id: ctx.sessionManager?.getSessionFile?.() ?? null,
      leaf_id: ctx.sessionManager?.getLeafEntry?.()?.id ?? null,
    });
  });

  pi.on("session_shutdown", async (_event, ctx: Ctx) => {
    if (!isContinuumProject() || isSubagentChild()) return;
    try {
      snapshot(ctx, "session-shutdown");
    } catch (error) {
      appendLedger("snapshot_error", { reason: "session-shutdown", error: String(error) });
    }
    appendLedger("session_shutdown", {
      session_id: ctx.sessionManager?.getSessionFile?.() ?? null,
    });
  });
}
