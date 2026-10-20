# Project Operating Rules

This repository uses the Pi Project Runtime.

## Roles

- **Lead** — plans, integrates, owns `TASK.md`, `PLAN.md`, and the final answer. Uses `pi-clm`.
- **Scout** — read-only repository/codebase mapping. Returns findings and file paths, not patches.
- **Implementer** — implements the plan in small, testable steps. Runs tests.
- **Verifier** — read-only independent review. Does not edit. Runs tests and checks acceptance criteria.
- **Researcher** — optional; external docs/web only.

## Required flow

1. Read `TASK.md` and `CLM_STEERING.md`.
2. Write or update `PLAN.md` with steps, risks, and verification.
3. Delegate only independent work. Use the fewest specialists needed.
4. Implement.
5. Run deterministic checks.
6. Run the verifier. It must write `VERDICT.json`.
7. Work is **not done** until:
   - every acceptance check has evidence,
   - tests/lint/typecheck pass,
   - verifier returns `PASS`,
   - no unresolved high-risk item remains.
8. If verifier returns `FAIL`, fix and re-verify. After 3 loops, stop and ask the human.

## Context rules

- Only the lead uses `pi-clm`.
- Do not load observational memory or a second compaction manager in the lead session.
- Keep `TASK.md`, `PLAN.md`, and `VERDICT.json` current; they are the durable state.
- Prefer small context edits. Do not rewrite unchanged blocks.
- Offload raw logs; keep decisions, constraints, file paths, failing tests, and evidence.
- Never delete the original task, acceptance checks, or security constraints.

## Delegation rules

- At most 2–4 active specialists.
- Subagents get a narrow brief and an output contract.
- Subagents return evidence and file paths, not raw transcripts.
- Do not use a subagent just to search an indexed repository; use code search first.
- Do not use subagents for context offloading; use CLM.

## Verification rules

- Verifier is read-only.
- It checks the diff against `TASK.md`, not against the implementer’s claims.
- It runs the relevant tests itself.
- It records exact commands and evidence in `VERDICT.json`.
- A green test suite is necessary but not sufficient; acceptance checks still need evidence.
