# Changelog

## Unreleased

- Resolve Pi extension session paths against the project root, so `open`,
  `seal`, and `fork-day` work when the launcher runs outside the repository.
- Make fork IDs collision-safe against Pi's timestamp-prefixed live session
  files and archived session directories.
- Reject unlisted files during archive verification and require at least one
  `AC-*` check in `TASK.md` for the completion gate.
- Archive an extension snapshot taken at the UTC day boundary under the day
  that ended, so sessions left open across midnight keep both day archives.
- Isolate core subagents from ambient extensions: `extensions:` empty in every
  core agent, `subagents.defaultExtensions: []` in project settings, and a
  `PI_SUBAGENT_CHILD=1` guard in the Continuum extension.
- Run the verifier in the foreground and add `continuum check` as a
  deterministic `TASK.md`/`VERDICT.json` gate.
- Make `verify` fail closed on missing roots, ledgers, manifests, seals,
  archived evidence, and inventory/hash mismatches.
- Reject malformed middle JSONL lines during seal/snapshot; only a partial
  trailing line is dropped.
- Add a project writer lock, an exclusive seal lock, shared backup/verify
  locks, a locked tmux pane wrapper, and direct-launch refusal while another
  writer is active.
- Make `--dry-run` side-effect free and let `--no-tmux` bypass tmux attach.
- Merge ignore/settings into existing repositories, add `.agent/.gitignore`,
  back up `--force` overwrites, and refuse reserved/shadowing wrapper names.
- Wire `--verifier-model` through `subagents.agentOverrides.verifier.model`.
- Generate unique same-day fork IDs and record accurate seal reasons.
- Document the default delegation depth, no-auto-spawn rule, and worktree condition in the project template.
- Add a capability-acceptance check for project skills/extensions.
- Add research notes for Meta-Harness, PluginRSI, Inside the Scaffold, the missing knowledge layer, and Jev decision-controller counterevidence.
- Document deliberate non-goals: no runtime topology router, no recursive spawning, no Jev controller, and no observational memory in the lead.
- Add regression coverage for the fail-closed verifier, dry-run, subagent
  isolation, existing-repository merge, writer locks, and wrapper names.

## 0.1.7 — 2026-10-20

- Remove Continuum npm packaging/publishing instructions.
- Install the CLI from GitHub with `./install.sh`.
- Keep only the minimal `package.json` needed for Pi package/Git installation.
- Replace npm-package uninstall steps with `./uninstall.sh` and `pi remove git:...`.
- Remove historical design/packaging docs from the public repo.

## 0.1.6 — 2026-10-20

- Add `docs/CLM-DEEPSEEK.md` with everyday-high and hard-max CLM profiles.
- Link the DeepSeek profiles from the README and research notes.

## 0.1.5 — 2026-10-20

- Document exactly which upstream packages are installed.
- Document duplicate-extension/package behavior.
- Add manual pinned install commands for `pi-clm` and `pi-subagents`.

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
