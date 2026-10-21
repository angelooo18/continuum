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
   - If this adds a project skill or extension, run the capability acceptance check in `PROJECT_SKILLS.md`.
5. Run deterministic checks.
6. Run the verifier. It must write `VERDICT.json`.
7. Run `continuum check <project>` and require `PASS`.
8. Work is **not done** until:
   - every acceptance check has evidence,
   - tests/lint/typecheck pass,
   - verifier returns `PASS`,
   - no unresolved high-risk item remains.
9. If verifier returns `FAIL`, fix and re-verify. After 3 loops, stop and ask the human.

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
- Default delegation depth is 2: lead → specialist. A specialist does not spawn another specialist without lead approval.
- Do not auto-spawn subagents. The lead chooses delegation from `PLAN.md`.
- Parallel writers require isolated git worktrees. If worktrees are not available, keep implementation serial.
- The lead owns topology selection. Do not add a runtime router or auto-spawner to the base template; experiment behind a project-local extension if needed.

## Capability rules

- `toolsmith` creates project-local skills/extensions only on request.
- Before adoption, run the capability acceptance check in `PROJECT_SKILLS.md`; keep only capabilities with a measured benefit or risk reduction.
- Do not add a capability to the lead unless it is an orchestration or verification gate.
- Do not build a separate plugin library; `.pi/skills/` and `.pi/extensions/` are the project library.

## Verification rules

- Verifier is read-only.
- It checks the diff against `TASK.md`, not against the implementer’s claims.
- It runs the relevant tests itself.
- It records exact commands and evidence in `VERDICT.json`.
- A green test suite is necessary but not sufficient; acceptance checks still need evidence.
