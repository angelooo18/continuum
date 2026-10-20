# Review 2 — Subagents, rollover, skills, DeepSeek, and publishing

This supersedes the open questions in `DRAFT.md` where it disagrees.

---

## 1. Recommended subagent runtime

There is **no official `@earendil-works/pi-subagents` package**. Subagents are an extension ecosystem. The closest thing to “the earendil one” is:

### Primary: `pi-subagents` by nicobailon

- npm: `pi install npm:pi-subagents`
- repo: <https://github.com/nicobailon/pi-subagents>
- current version: 0.79.1
- peers: `@earendil-works/pi-ai`, `pi-agent-core`, `pi-coding-agent`, `pi-tui`
- built-in agents: `scout`, `researcher`, `evidence-auditor`, `worker`, `reviewer`, `oracle`, `delegate`
- supports foreground/background children, custom `.pi/agents/*.md`, model/thinking overrides, skills, tool allowlists, persistent child sessions, live fleet view, worktree isolation, and Pi 1.0+.

This is the best default for the template.

### Optional: `pi-interactive-subagents`

- repo: <https://github.com/amosblomqvist/pi-interactive-subagents>
- tmux panes, live pane UI, steer by typing into the child pane.
- Not on npm; install from git.
- Latest package peers target `@mariozechner/pi-coding-agent` (0.65-era), not current `@earendil-works` 1.3. It likely needs a compatibility fork.
- Keep it as an optional UI layer if you specifically want tmux panes; do not make it the foundation.

### Not a subagent package: `@earendil-works/pi-durable`

`pi-durable` is Earendil’s experimental **durable harness library** for building agents with committed transcripts/tasks and crash recovery. It is not a drop-in subagent extension for `pi-clm`. It is relevant if you later want a custom durable runtime, but it would be a separate project.

---

## 2. Day rollover: fork vs snapshot

The intuition that “constant fork gives smoother continuity” is understandable, but it is not quite right.

### What a daily fork actually does

`pi --fork <old-session> --session-id <new>` copies the old session’s active branch into a new session file. It does **not** reset context. It gives you a new file that contains the old history.

Consequences:

- CLM revisions are copied, so CLM should restore — this is good.
- The new day’s session file contains the **entire prior branch**. Each day duplicates the history again.
- The active session gets heavier every day; fork/load time grows.
- Old and new session files are near-duplicates, which makes `/resume` noisy.
- If the fork fails, you still have the old session, so it is safe — just not efficient.
- It gives **day isolation**, not smoother continuity. Continuity comes from copied context, not from the fork itself.

### What a daily snapshot does

Keep one live session; copy it to `days/YYYY-MM-DD/` at the UTC boundary. The live session stays the same.

- No session switch; continuity is literally the same session.
- No duplication in the active working set.
- The day archive is still a full session file and can be opened/forked later.
- CLM projection stays in one place.
- Simpler recovery and less fork overhead.

### Objective comparison

| Criterion | Daily fork | Daily snapshot |
|---|---|---|
| Continuity | Good, but via copied context | **Best** — same live session |
| Day isolation | **Best** — one session per day | Archives, not active isolation |
| Active session size | Grows/duplicates every day | Single session |
| Storage | Duplicates branch each day | One live + daily archive |
| CLM restore risk | Must validate on fork | No switch; lowest risk |
| Crash safety | Old session intact | Live session + archive |
| Complexity | Higher | Lower |
| Auditability | Good | **Good** — manifest + seal |
| Resuming a past day | Natural | Open/fork the archive |

### Recommendation

**Default: snapshot.** One continuous live session, immutable UTC day archives.

**Optional: `fork-day`.** Use it when you deliberately want a clean day branch, or once a week/month, not every day. If you insist on daily fork, add retention/compression and test CLM restore first.

A good compromise:

- live session = continuous;
- `days/YYYY-MM-DD/` = immutable snapshot;
- `pi-project fork-day` = manual clean branch;
- `rollover.mode = "snapshot"` by default; `"fork"` available.

---

## 3. What “project root” means

It is only the directory where `.pi/` and `.agent/` live, and where Pi starts.

### Option A — repo root (recommended)

```text
~/src/acme/          <- project root; Pi cwd
├── .pi/
├── .agent/
└── src/
```

- Each repo is one project.
- `.agent/` is gitignored.
- Multiple projects = multiple repos + separate tmux sessions.
- Simplest and most compatible with Pi’s project config and subagent discovery.

### Option B — separate workspace

```text
~/pi-projects/acme/  <- project root; Pi cwd
├── .pi/
├── .agent/
└── repo/            <- code
```

- More isolated, but Pi’s tools start at the workspace root; the agent must `cd repo` for git/tests.
- Or run Pi inside `repo/` and keep state in `../.agent`, which complicates project config discovery.

**Recommendation:** Option A for the MVP. It already isolates each Pi by repo and session directory. Add Option B later only if you want a container folder per project.

---

## 4. Project skills and extensions: lead or disposable agents?

Use **both**, but keep the lead small.

### Lead

The lead should have only:

- CLM and context management,
- orchestration/delegation,
- task/plan/verdict state,
- a small project-protocol skill,
- permission/verification gates.

Do **not** load web research, paper search, diagram rendering, or every project extension into the lead. That bloats context and expands the permission surface.

### Disposable specialists

Use narrow, fresh-context agents for:

| Need | Agent | Tools |
|---|---|---|
| Repo mapping | `scout` | read, grep, find, ls |
| Web/docs research | `researcher` | web_search, fetch_content, get_search_content, source_check |
| Paper reading | `researcher` or `paper-reader` | web + read + write notes |
| Claim checking | `evidence-auditor` | web source checks |
| Diagrams | `diagrammer` | read, write, bash (Mermaid/Graphviz) |
| Implementation | `implementer`/`worker` | read, write, edit, bash |
| Verification | `verifier`/`reviewer` | read, grep, find, ls, bash |

They return **artifacts + summaries**, not raw transcripts. That keeps the lead context clean.

### Skills vs extensions

- **Skill** = instructions/procedure. Put project skills in `.pi/skills/`; assign to agents with `skills:` in frontmatter. Examples: `research-protocol`, `paper-reading`, `diagramming`, `verification-checklist`.
- **Extension** = executable tools/hooks. Put project extensions in `.pi/extensions/` or install a package. Load only in the agent that needs it via `extensions:` or `subagentOnlyExtensions:`.
- **Lead** gets orchestration/CLM/verification skills only.
- **Specialists** get the tools and skills for their job.

For example:

- `researcher` gets `pi-web-access` + `research-protocol` skill.
- `diagrammer` gets Mermaid/Graphviz tools + `diagramming` skill.
- `verifier` gets test tools + `verification-checklist` skill.
- Lead gets `project-protocol` and `CLM_STEERING.md`.

This is the same principle as the research: don’t build a deep tree for context; build narrow specialists with isolated contexts and return evidence.

---

## 5. DeepSeek for all roles

The linked repo — [LLM-as-a-Verifier](https://github.com/llm-as-a-verifier/llm-as-a-verifier), paper [arXiv:2607.05391](https://arxiv.org/abs/2607.05391) — is strong evidence that DeepSeek V4.1 Flash is a capable verifier:

- On Terminal-Bench 4.0, DeepSeek V4.1 Flash verifies Claude Opus 5.5 trajectories:
  - Best-of-3: **66.2%** vs 63.1% Pass@1.
  - Best-of-5: **69.2%** vs 64.8%.
- On Terminal-Bench 2.1 self-verification:
  - Best-of-3: **86.5%** vs 79.4% Pass@1.
  - Best-of-5: **88.0%** vs 78.7%.

Important nuance: those gains come from **LLM-as-a-Verifier’s method** — fine-grained scoring, logprob expectations, criteria decomposition, and repeated evaluation — not merely from asking DeepSeek “review this diff.” A plain verifier prompt will not reproduce those numbers.

Still, the conclusion is reasonable: **DeepSeek for all roles is a good default** for cost, speed, and simplicity. Use:

- DeepSeek for lead, scout, implementer, researcher, verifier.
- Separate verifier context + explicit acceptance criteria + deterministic tests.
- For high-stakes work, run multiple verifier samples or integrate `llm-verifier`-style scoring.
- Optional `oracle` second opinion on risky decisions, not routine work.

Same-model verification is not independent in the statistical sense, but the repo’s self-verification results show it can still be useful when the verifier sees a different context and a strict rubric. Keep tests as the primary gate.

---

## 6. Publishing on GitHub without personal details

This project is **not just an extension or a skill**. It is:

- a **CLI** (`pi-project`),
- a **project template** (`.pi/`, `.agent/`, AGENTS/CLM docs),
- a **Pi extension** (`project-ledger`),
- **skills** (research, diagrams, verification),
- **agent definitions**.

Publish it as one repo:

```text
pi-project-runtime/
├── bin/pi-project
├── templates/project/
│   ├── .pi/settings.json
│   ├── .pi/agents/
│   ├── .pi/extensions/
│   ├── .pi/skills/
│   ├── AGENTS.md
│   ├── CLM_STEERING.md
│   └── TASK.md
├── docs/
├── README.md
├── LICENSE
├── SECURITY.md
└── .gitignore
```

Later you can split:

- npm package for the CLI,
- Pi package for the ledger extension and skills,
- template repo for the scaffold.

Sanitization checklist:

- Replace absolute paths like `/home/<user>` with `~`, `$HOME`, or placeholders.
- No personal project names in examples; use `example`/`acme`.
- `.gitignore`: `.agent/`, `*.jsonl`, `auth.json`, `.env`, `logs/`, `node_modules/`.
- Never commit session data, API keys, or generated artifacts.
- Add `LICENSE` (MIT), `SECURITY.md`, and a short “review before installing” note.
- Do not claim “100% guaranteed”; document the limits.

---

## 7. Changes applied to the draft

- Default subagent package changed to `npm:pi-subagents`.
- Added `npm:pi-web-access` for the researcher.
- Default verifier model changed to `deepseek/deepseek-flash`.
- Agent frontmatter converted from `pi-interactive-subagents` fields to `pi-subagents` fields.
- Added a `diagrammer` agent.
- Rollover recommendation changed to **snapshot default**, with manual `fork-day`.
- Project root recommendation: repo root with `.agent/`.

The day-rollover code still supports both modes; only the default recommendation changes.
