# Changelog

## 0.1.4 — 2026-10-20

- Add `RESEARCH.md` with citations and the design decisions they informed.
- Include research and credits in the package and README.

## 0.1.3 — 2026-10-20

- Add `CREDITS.md` with upstream extension/project citations.
- Clarify that Continuum composes rather than vendors upstream packages.
- Remove personal test paths from design docs.

## 0.1.2 — 2026-10-20

- Fix direct project-command launch when the wrapper is invoked with no arguments. The default open namespace was missing `no_preflight`.

## 0.1.1 — 2026-10-20

- Choose a wrapper directory that is already on `PATH` (prefers `~/.local/bin`, falls back to `~/.pi/agent/bin`).
- Warn when the wrapper directory is not on `PATH`.
- Remove the wrapper from both locations in the desktop cleanup script.
- Document the GitHub install path.

## 0.1.0 — 2026-10-20

Initial Continuum package.

- `continuum` launcher: project registry, session resume, tmux attach, UTC day snapshots, fork-day.
- `continuum new`, `open`, `status`, `seal`, `fork-day`, `verify`, `doctor`, `list`, `path`.
- Project template with CLM steering, core agents, verification skill, and toolsmith.
- Pi extension: active-session ledger, per-session day archives, manifest/seal hashes, subagent artifact capture.
- Snapshot default with optional fork mode.
- DeepSeek defaults for lead and verifier; optional second-model oracle later.
- Automated smoke test and GitHub Actions workflow.
