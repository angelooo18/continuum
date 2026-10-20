# Continuum Live Test Report

Date: 2026-10-20 UTC
Pi: 1.3.0
Model: DeepSeek V4.1 Flash (`deepseek/deepseek-flash`)
Packages tested: `@lolipopshock/pi-clm`, `pi-subagents`, `pi-web-access`

## Passed

### Pi + DeepSeek

- `pi --print` returned a response with `deepseek/deepseek-flash`.
- Project `.pi/settings.json` loaded with `--approve`.

### CLM

- `pi-clm` loaded and exposed `live_context_annotate` / `live_context_recall`.
- The model edited `LIVE_CONTEXT.md` and the edit was accepted as a
  `live-context-state` custom entry (revision 1).
- A follow-up turn in the same session recalled the edited note (`CLM_OK`).
- `pi --fork <session> --session-id <new>` restored the CLM projection; the
  forked session also recalled `CLM_OK`.

### pi-subagents

- `scout` child ran successfully and returned a repository summary.
- Child session was written under
  `.agent/sessions/<parent-stem>/<run-id>/run-0/session.jsonl`.
- Child artifacts were written under
  `.agent/sessions/subagent-artifacts/`.
- Parent tools included `subagent`, `contact_supervisor`, and
  `subagent_supervisor`; the scout child had `contact_supervisor` and no
  downward supervisor tool.

### Verifier

- The `verifier` child checked `TASK.md`, ran commands, and wrote
  `VERDICT.json`.
- Verdict: PASS for a trivial `hello.txt` acceptance check, with explicit
  evidence and residual risks.

### Continuum ledger / archives

- `project-ledger.ts` wrote `.agent/active.json` and `.agent/ledger.ndjson`.
- `session_start`, `turn_end`, `day_seal`, and `session_shutdown` events were
  recorded.
- `continuum seal` wrote a per-session archive:
  `.agent/sessions/days/<date>/<session-id>/`.
- Archives include `session.jsonl`, `manifest.json`, `seal.json`, `TASK.md`,
  `PLAN.md`, and `VERDICT.json` when present.
- Subagent artifacts and child run sessions were copied into the archive.
- `continuum verify` passed on intact archives and failed correctly on a
  tampered archive in the smoke suite.
- `continuum doctor` passed all required checks.

## Fixed during testing

- Day archives were originally one file per day; multiple sessions in a day
  could overwrite each other. Changed to per-session directories:
  `days/YYYY-MM-DD/<session-id>/`.
- Subagent artifacts were not included in archives. Added copying of:
  - `<sessionDir>/<parent-session-stem>/` child runs,
  - `<sessionDir>/subagent-artifacts/` files for the current session,
  - `<sessionDir>/artifacts/<session-id>/` when present.

## Additional checks

- tmux session creation and single-writer behavior were tested with a fake Pi
  binary: a second `continuum open` did not create a second session.
- Real TUI attach/detach was not exercised in the non-interactive test shell.
- `continuum backup --command true` and `continuum verify --root` were tested.
- `npm pack`, global install from the tarball, and `pi install` from the local
  package were tested.

## Not yet tested live

- real TUI attach/detach with a human client.
- `continuum fork-day` interactive launch.
- parent→child steering while a child is running.
- child→parent `contact_supervisor` question/reply round trip.
- long-session day rollover across UTC midnight.
- crash/restart with a live tmux session.

## Notes

- Pi auto-installed project packages into `.pi/npm/` on first run.
- DeepSeek was used for both lead and verifier; the verifier receives a
  separate context and produced evidence-backed output.
- The test API key must be revoked after testing.
