# Continuum Test Plan

Goal: prove the runtime works before collapsing the draft into a shippable Pi package.

## Test environments

1. **Scratch repo, no model** — CLI, registry, session/day files, seal/verify.
2. **Scratch repo + DeepSeek auth** — live Pi, CLM, subagents, tmux attach/resume.
3. **Clean machine/agent dir** — package install from git/npm, no personal state.
4. **Failure environment** — kill process, corrupt active pointer, missing session, concurrent open.

## Unit / CLI tests

- `continuum new` creates `.agent/`, `.pi/`, registry entry, wrapper.
- Name sanitization: spaces, slashes, leading digits.
- Duplicate project name is rejected; `--force` behavior is explicit.
- `continuum open --dry-run` builds the correct command for:
  - no active session,
  - same-day active session,
  - old-day snapshot mode,
  - old-day fork mode.
- `continuum status` reports model, verifier, rollover, tmux, active session, last ledger event.
- `continuum seal` handles:
  - complete JSONL,
  - partial trailing line,
  - empty session,
  - missing session file,
  - repeated seal.
- `continuum verify`:
  - passes on intact snapshot,
  - fails on modified session bytes,
  - fails on broken seal chain,
  - fails on missing manifest/session.
- `continuum fork-day --dry-run` builds `--fork <old> --session-id <new>`.

## Integration tests

- Install `@lolipopshock/pi-clm`, `pi-subagents`, `pi-web-access` into a clean agent dir.
- Pi starts with no extension load errors.
- `/clm status` shows budget/reserve/edits.
- `pi-subagents`:
  - spawn `scout` foreground and background,
  - spawn `researcher` with `pi-web-access`,
  - parent `steer` a running child,
  - child `contact_supervisor` → parent `subagent_supervisor` reply,
  - `resume` a completed child,
  - confirm nested coordinator routing A → B → C.
- `project-ledger` writes:
  - `.agent/active.json`,
  - `.agent/ledger.ndjson`,
  - day snapshot + manifest + seal.
- `continuum open`:
  - creates a tmux session,
  - a second open attaches instead of starting a second writer,
  - killing Pi and reopening resumes the same session.
- Day rollover:
  - snapshot mode continues the live session and archives the old day,
  - fork mode creates a new day session,
  - CLM projection restores after fork (or fallback is documented).
- Verifier gate:
  - verifier writes `VERDICT.json`,
  - lead refuses completion on `FAIL`,
  - evidence paths/commands are present.

## Failure tests

- Kill Pi mid-turn; session JSONL remains valid and resumable.
- Kill tmux; reopen starts a new tmux session with the same Pi session.
- Two `continuum open` calls race; only one writer wins.
- Corrupt `active.json`; `status` and `open` fail clearly, not silently.
- Delete active session file; seal/open report a clear error.
- Provider outage during a turn; Pi reports the error and session remains resumable.
- CLM deletes a constraint; verifier/steering catches it or handoff fallback is used.
- Disk-full or permission error during seal; live session is not modified.

## Pass criteria

- No data loss in tested crash paths.
- `verify` fails closed on tamper/truncation.
- Only one writer per project.
- CLM and subagents both function in the same lead session.
- A day archive can be opened/forked later.
- A failed verification cannot be marked done.
- Package installs on a clean machine without personal paths or secrets.

## Cleanup after tests

Delete:

- `/tmp/continuum-*` scratch repos and agent dirs,
- draft `__pycache__`,
- generated `.agent/` test state,
- `bin/pi-project` alias if the final package uses only `continuum`,
- any demo registry entries.

Keep:

- extension source,
- skills/agents,
- launcher,
- templates,
- README/LICENSE/SECURITY,
- test fixtures that are safe and reproducible.
