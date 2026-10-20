# Continuum — Pi Project Runtime — Draft v0.2

**Status:** design draft for review, not production. See `REVIEW-2.md` for the v0.2 decisions on subagents, rollover, skills, DeepSeek-for-all, and publishing.
**Goal:** a repeatable project template that binds Pi + CLM + a verifier/subagent strategy to a project name, with UTC-traceable daily session archives.

---

## 1. What this is

A project runtime with four layers:

1. **Project identity** — a name maps to one repository and one runtime config.
2. **Live session** — Pi resumes the same active session when you run the project name.
3. **CLM context control** — the model edits its own live context instead of relying on lossy compaction.
4. **Verification loop** — a read-only verifier checks the result before work is marked done.

The intended UX:

```bash
myproject
```

That command should:
- attach to the already-running session if one exists,
- otherwise resume today's session,
- otherwise create today's session from yesterday's handoff,
- always use the project's CLM config, models, agents, and verification rules.

---

## 2. Feasibility verdict

| Requirement | Feasible? | Mechanism | Main caveat |
|---|---|---|---|
| Run project name to resume | **Yes** | registry + generated `~/.local/bin/<name>` wrapper + `pi --session-id` / `--session` | Name collisions; need a global registry |
| Instant resume if already running | **Yes** | tmux session `pi-<name>` + `tmux attach` | Requires tmux; one writer only |
| Everything in its own folder | **Yes** | repo `.agent/` + `.pi/`; `sessionDir=.agent/sessions` | Project config still lives in the repo |
| UTC-traceable sessions | **Yes** | UTC timestamps + JSONL session + append-only ledger + SHA-256 manifest | Hashes prove integrity, not truth |
| Day-by-day archives | **Yes** | snapshot/fork at UTC day boundary | Must not copy a session mid-write; use quiescent points |
| Keep CLM continuity across days | **Likely yes** | CLM revisions are session entries; `--fork` copies active branch; snapshot preserves raw | Must verify CLM restores on fork with current Pi |
| Information is saved | **Strong mitigation** | Pi session is append-only; raw history never rewritten; daily snapshot + ledger | Disk failure still possible; add remote backup |
| Context never runs out | **Mitigation, not guarantee** | CLM budget + overflow guard + handoff fallback | Model can still mismanage context |
| 100% best results | **No** | verifier + deterministic tests + requirement checklist | No system can guarantee correctness |
| Async interactive subagents | **Yes** | `pi-subagents` (default); optional `pi-interactive-subagents` for tmux panes | `pi-interactive-subagents` is not on npm and needs a compatibility pass |

### Bottom line

The architecture is feasible. The default subagent runtime should be **`pi-subagents`**, which is built for current `@earendil-works` Pi. **`pi-interactive-subagents`** is optional for tmux-pane UX and likely needs a compatibility fork; see `REVIEW-2.md`.

---

## 3. Architecture

```text
~/.local/bin/myproject
        │
        ▼
bin/continuum open myproject
        │
        ├── tmux session exists? ──yes──► tmux attach
        │
        ├── UTC day changed? ──yes──► seal yesterday (snapshot); fork-day optional
        │
        └── start/resume Pi
                │
                ├── .pi/settings.json  (packages, sessionDir, tools)
                ├── .pi/agents/*.md    (scout, implementer, verifier, researcher)
                ├── .pi/extensions/project-ledger.ts
                ├── CLM_STEERING.md
                └── .agent/
                     ├── project.json
                     ├── sessions/live/
                     ├── sessions/days/YYYY-MM-DD/
                     ├── artifacts/
                     └── ledger.ndjson
```

### Session model

- **Live session** is one Pi session for the project, stored under `.agent/sessions/`.
- **Day archive** is an immutable snapshot of the live session at a UTC boundary, plus its subagent artifacts and verification files.
- **Default rollover mode: `snapshot`** — keep one continuous live session and copy it into an immutable `days/YYYY-MM-DD/<session-id>/` archive at the UTC boundary. This gives the best continuity and avoids duplicating the active branch every day.
- **Optional mode: `fork`** — on the first launch of a new UTC day, if no live process is running, seal the previous day and create a new session with `pi --fork <live-session> --session-id <project>-YYYYMMDD`. Use this when you deliberately want a clean day branch. It preserves CLM revisions but duplicates the prior branch into the new session file.

A day archive is still a full session file and can be opened or forked later, so snapshot mode does not sacrifice day-level recovery. `REVIEW-2.md` has the objective comparison.

---

## 4. Folder layout

```text
<repo>/
├── .agent/
│   ├── project.json
│   ├── ledger.ndjson
│   ├── active.json
│   ├── locks/
│   ├── sessions/
│   │   ├── live/
│   │   └── days/
│   │       └── 2026-10-19/
│   │           └── <session-id>/
│   │               ├── session.jsonl
│   │               ├── manifest.json
│   │               ├── seal.json
│   │               ├── subagent-sessions/
│   │               ├── subagent-artifacts/
│   │               ├── TASK.md
│   │               ├── PLAN.md
│   │               ├── VERDICT.json
│   │               ├── diff.patch
│   │               ├── tests.log
│   │               └── HANDOFF.md
│   └── artifacts/
├── .pi/
│   ├── settings.json
│   ├── agents/
│   │   ├── scout.md
│   │   ├── implementer.md
│   │   ├── verifier.md
│   │   └── researcher.md
│   └── extensions/
│       └── project-ledger.ts
├── AGENTS.md
├── CLM_STEERING.md
└── TASK.md

~/.local/bin/myproject -> continuum open myproject
```

`project.json` is the project manifest. `.pi/settings.json` is the Pi project config. `.agent/` is runtime state and audit data.

---

## 5. Session/day lifecycle

### First creation

```text
continuum new acme --repo ~/src/acme
```

Creates:
- registry entry `acme -> ~/src/acme`,
- `.agent/project.json`,
- `.pi/settings.json` + agents + ledger extension,
- `AGENTS.md`, `CLM_STEERING.md`, `TASK.md`,
- `~/.local/bin/acme` wrapper.

### Normal open

```text
acme
```

1. Resolve `acme` in registry.
2. If `tmux has-session -t pi-acme`, attach.
3. Else read `.agent/active.json`.
4. If active UTC day is today, resume its session.
5. If day changed and no process is live:
   - seal previous day,
   - create a new day session (only in `fork` mode),
   - resume it.
6. Launch inside `tmux` so subagents and re-attach work.

### Day seal

At the first turn after UTC midnight, or on `session_shutdown`, the ledger extension:
- snapshots the live session JSONL,
- copies the subagent artifact directory,
- writes `manifest.json` with SHA-256, bytes, session id, leaf id, model, timestamp,
- appends a `day_seal` event to `ledger.ndjson`.

If the process is running across midnight, it keeps running. The seal happens at the next quiescent boundary. In `snapshot` mode the live session simply continues; in `fork` mode the next day session is created only after the process exits.

### Concurrency

- tmux session is the primary lock: one writer per project.
- If tmux is unavailable, a `flock` lock file prevents two Pi processes from opening the same live session.
- `continuum status` reports whether the tmux session is live and which session file is active. `continuum doctor` runs the full preflight; `continuum open` runs the fast subset automatically.

---

## 6. Command surface

```text
continuum new <name> --repo <path>
continuum open <name>
continuum list
continuum status <name>
continuum seal <name>
continuum fork-day <name>
continuum verify <name>
continuum path <name>
continuum doctor <name>
```

Generated wrapper:

```text
~/.local/bin/<name>  ->  continuum open <name>
```

Inside Pi, optional commands from the ledger extension:

```text
/project status
/project seal
/project handoff
```

`/project handoff` is the emergency path: generate a fresh handoff brief from the current task state and start a new session if CLM or the current context has become unreliable.

---

## 7. Pi and CLM configuration

### Project `.pi/settings.json`

```json
{
  "sessionDir": ".agent/sessions",
  "packages": [
    "npm:@lolipopshock/pi-clm",
    "npm:pi-subagents",
    "npm:pi-web-access"
  ],
  "defaultTools": ["+codemode"],
  "subagents": {
    "defaultModel": "deepseek/deepseek-flash",
    "defaultThinking": "high"
  }
}
```

### CLM settings

```text
/clm config budget 256k
/clm config reserve 32k
/clm config reminders 50/75/90%
/clm config guard on
/clm config compaction auto
/clm config cap 10000:0.5
/clm config trailer on
/clm config one-tool off
/clm config steering CLM_STEERING.md
```

Environment defaults for the launcher:

```text
PI_CLM_BUDGET=262144
PI_CLM_RESERVE=32768
PI_CLM_OBSERVATION_CAP=10000:0.5
PI_CLM_SIZE_TRAILER=1
PI_CLM_STEERING=<repo>/CLM_STEERING.md
```

### Model split

- **Lead / CLM:** DeepSeek V4.1 Flash 1017 (`deepseek/deepseek-flash`).
- **Verifier:** DeepSeek, read-only, separate context.
- **Scout / implementer / researcher:** DeepSeek.
- **Optional oracle:** a second model only for high-risk decisions.

Why: `LLM-as-a-Verifier` shows DeepSeek V4.1 Flash is a strong verifier, including self-verification, when used with explicit criteria and repeated scoring. DeepSeek-for-all is the simplest cost/speed default. Keep deterministic tests as the primary gate; use an optional second model only where independence matters more than cost.

### Load order

- `pi-clm` must be loaded before other context-transforming extensions.
- Do not load `pi-observational-memory` in the same session; CLM owns compaction.
- If Jev is used, keep only its permission/routing gates; avoid its conditional-context and output-ladder features while CLM is active.
- Subagents should **not** load CLM. Give them isolated contexts and narrow tool allowlists; only the lead manages context.

---

## 8. Subagent strategy

```text
Lead (DeepSeek + CLM)
├── scout        read-only repo map
├── implementer  edits + tests
├── verifier     read-only, independent checks
└── researcher   optional web/docs
```

Rules:
- Lead plans and integrates; it owns `TASK.md` and `PLAN.md`.
- Scout is read-only; do not use a scout for indexed repo Q&A if code search is enough.
- Implementer may edit and run tests.
- Verifier never edits. It checks the diff against acceptance criteria, runs tests, and writes `VERDICT.json`.
- Use at most 2–4 active specialists. BOAD’s top-2 specialists beat wider teams; MS-Eval found unnecessary delegation is overhead.
- Subagents return evidence, not raw transcripts. The lead sees a summary + file paths.

`pi-subagents` is the default:
- built-in `scout`, `researcher`, `evidence-auditor`, `worker`, `reviewer`, `oracle`, `delegate`;
- custom `.pi/agents/*.md` with model/thinking/tools/skills/extensions;
- foreground and background children, model overrides, worktree isolation, fleet view;
- peers target `@earendil-works` and Pi 1.0+.

`pi-interactive-subagents` is optional:
- tmux panes, live pane UI, steer-by-typing;
- not on npm; install from git;
- peers target `@mariozechner` 0.65-era and need a compatibility fork;
- use it only if the tmux-pane UX is worth the maintenance.

---

## 8b. Skills, extensions, and disposable specialists

Keep the lead small. Put heavy tools and long instructions in disposable specialists.

| Asset | Where | Who loads it |
|---|---|---|
| Project protocol / CLM steering | `AGENTS.md`, `CLM_STEERING.md` | Lead only |
| Research procedure | optional `examples/skills/research-protocol` | project `researcher` |
| Paper reading | project-created skill | project `researcher` |
| Diagram conventions | optional `examples/skills/diagramming` | project `diagrammer` |
| Verification checklist | `.pi/skills/verification/SKILL.md` | core `verifier` |
| Web access | optional `npm:pi-web-access` | project `researcher`, `evidence-auditor` |
| Diagram rendering | project extension or local Mermaid/Graphviz CLI | project `diagrammer` only |
| Ledger / day snapshots | `.pi/extensions/project-ledger.ts` | Lead only |

Rules:
- The lead gets orchestration, CLM, and verification gates — not every research/diagram tool.
- A specialist gets only the tools and skills for its job.
- Research and diagrams are disposable: fresh context, artifact output, summary back to the lead.
- If a skill is useful to several agents, keep it in project `.pi/skills/` and select it explicitly in each agent's `skills:` list.
- If an extension is needed only by one specialist, load it in that agent's `extensions:` / `subagentOnlyExtensions:` rather than project-wide.
- The base template stays small. A `toolsmith` specialist creates project-local skills/extensions on demand; see `PROJECT_SKILLS.md`.
- Research/diagram agents and skills are optional examples under `examples/`, not loaded by default.

---

## 9. Verification protocol

### Files

`TASK.md`:
```markdown
## Goal
## Constraints
## Acceptance checks
- [ ] ...
## Non-goals
## Evidence required
```

`PLAN.md`:
```markdown
## Steps
## Risks
## Verification plan
```

`VERDICT.json`:
```json
{
  "status": "PASS",
  "checks": [
    { "id": "AC-1", "result": "pass", "evidence": "tests.log:42" }
  ],
  "tests": { "command": "npm test", "result": "pass" },
  "risks": [],
  "unresolved": []
}
```

### Gate

Work is not “done” unless:
1. every acceptance check has evidence,
2. tests/lint/typecheck pass,
3. verifier returns `PASS`,
4. no unresolved high-risk item remains,
5. the diff was reviewed.

If verifier returns `FAIL`, lead fixes and re-verifies. Cap at 3 loops, then escalate to the human.

### Honest limit

This improves reliability; it does **not** guarantee “100% best results.” A verifier can be wrong, tests can be incomplete, and requirements can be ambiguous. The template makes failures visible and recoverable rather than claiming perfection.

---

## 10. Durability and audit

- Pi session JSONL is append-only; CLM never rewrites raw history.
- `.agent/ledger.ndjson` records UTC `session_start`, `turn_end`, `day_seal`, `session_shutdown` events with session id, leaf id, and file hash.
- `.agent/sessions/days/YYYY-MM-DD/<session-id>/manifest.json` stores SHA-256 and byte counts.
- `continuum verify` recomputes hashes and reports tampering or truncation.
- Optional remote backup: `git` for artifacts, `restic`/`rclone` for `.agent/sessions`.
- A `HANDOFF.md` can be generated at seal time for disaster recovery.

What this does not cover: disk failure, provider outage during a write, or malicious local modification before a hash is recorded. Add remote backup if durability matters.

---

## 11. Prototype status

The draft includes a dependency-free `bin/continuum` prototype and project templates.

Tested locally:

- `new`, `status`, `list`, `path` on a scratch repository;
- `seal` against a synthetic session JSONL;
- `verify` passes on an untouched snapshot and fails on a tampered one.

Not yet tested:

- `open` end-to-end with Pi + tmux;
- `--fork` day rollover with a real CLM session;
- `project-ledger.ts` against a live Pi process;
- `pi-subagents` with Pi 1.3.

These are exactly the Phase 0–2 tests.

---

## 12. Implementation phases

### Phase 0 — compatibility spike
- Install `pi-subagents` + `pi-web-access` in a scratch repo.
- Verify a foreground `scout` and a background `researcher` run, and that a child session can be resumed.
- Verify `--fork` with a CLM session only if you plan to use `fork` mode.
- Optional: test `pi-interactive-subagents` separately for the tmux-pane UX.

### Phase 1 — project CLI
- `new`, `open`, `list`, `status`, `path`.
- Registry, wrapper symlink, tmux attach, lock.
- No automatic day fork yet; snapshot mode is the default.

### Phase 2 — ledger + day snapshots
- `project-ledger.ts` on `session_start`, `turn_end`, `session_shutdown`.
- Snapshot, manifest, ledger, `verify`.
- Manual `seal`.

### Phase 3 — UTC day rollover
- Detect day change on open.
- Seal previous day; snapshot continues the live session by default.
- `fork-day` creates a new day session and updates the active pointer only in fork mode.
- Test CLM restore before enabling automatic fork.

### Phase 4 — CLM + agents
- Install CLM, set env/config, load steering.
- Add scout/implementer/verifier/researcher agents.
- Verify only the lead loads CLM.

### Phase 5 — verification gate
- `TASK.md`/`PLAN.md`/`VERDICT.json`.
- Verifier agent with read-only tools and test execution.
- Definition-of-done gate.

### Phase 6 — hardening
- Crash recovery, stale locks, partial JSONL handling.
- Remote backup.
- Context-pressure watchdog + handoff fallback.

---

## 13. Decisions

Settled:

1. **Day rollover:** `snapshot` default + manual `fork-day` (hybrid).
2. **Project root:** repo root with `.agent/`.
3. **Subagent runtime:** `pi-subagents`; optional tmux-pane profile later.
4. **Models:** DeepSeek for all roles; optional second-model oracle for high-risk decisions.
5. **Skills/extensions:** minimal template; `toolsmith` creates project-local assets on demand.

Remaining:

6. **Backup:** local only, git remote, or restic/rclone?
7. **Optional panes profile:** patch `pi-interactive-subagents` for direct tmux typing, or skip it?

---

## 14. Risks

- **Subagent runtime choice** — `pi-subagents` is the safe default; `pi-interactive-subagents` is optional and needs a compatibility fork.
- **CLM fork restore** — only relevant if you enable `fork` mode; test before relying on it.
- **Session concurrency** — tmux/lock is mandatory; two writers can corrupt a session.
- **Model verbosity** — DeepSeek 1017 is very verbose on AA; strict CLM steering and budget caps needed.
- **Prompt injection** — CLM makes context model-editable; untrusted repos can inject instructions. Keep permission gates and secrets out of context.
- **“100% best”** — impossible; verification reduces risk but cannot eliminate it.
- **Cost** — CLM edits invalidate prefix caches; measure with `supi-cache`/session cost.

---

## 15. MVP acceptance tests

- `continuum new demo --repo /tmp/demo` creates the full layout and wrapper.
- `demo` launches Pi in tmux; a second `demo` attaches instead of starting a second writer.
- `continuum status demo` shows live session, UTC day, model, and last ledger event.
- Simulated UTC day change (edit `active.json`) seals yesterday; `fork-day` creates today's clean branch on demand.
- `continuum verify demo` passes on untouched files and fails on a tampered snapshot.
- CLM panel shows edits; `/clm status` shows budget/reserve.
- Verifier agent produces `VERDICT.json` with evidence; lead refuses to mark done on `FAIL`.
- Kill the Pi process; `demo` resumes the same live session.
- Kill tmux; `demo` starts a new tmux session and resumes the same session file.

---

## References

- CLM paper: <https://arxiv.org/abs/2609.37725>
- `pi-clm`: <https://github.com/lolipopshock/pi-clm>
- Pi sessions/CLI: `docs/sessions.md`, `docs/cli.md` in the Pi installation
- `pi-subagents`: <https://github.com/nicobailon/pi-subagents>
- `pi-interactive-subagents` (optional): <https://github.com/amosblomqvist/pi-interactive-subagents>
- AA DeepSeek V4.1 Flash 1017: <https://artificialanalysis.ai/models/deepseek-v4-1-flash-1017>
- AA MiMo V2.6 Pro: <https://artificialanalysis.ai/models/mimo-v2-6-pro>
- BOAD: <https://arxiv.org/abs/2512.23631>
- Decomposition Buys Integrity, Not Yield: <https://arxiv.org/abs/2609.17464>
- When Sub-Agents Work in Parallel: <https://arxiv.org/abs/2610.10263>
- MS-Eval: <https://arxiv.org/abs/2610.22869>
