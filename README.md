# Continuum

**Continuum** is a project runtime for [Pi](https://pi.dev) that combines:

- `pi-clm` for model-managed context,
- `pi-subagents` for scoped specialists,
- UTC-traceable per-session day archives,
- a project name that resumes or attaches to the live session,
- a verifier gate before work is marked done.

It is packaged as a Pi package plus a thin `continuum` launcher.

## Requirements

- Pi 1.3 or newer
- Node.js 20+
- Python 3.10+ (`python3` on `PATH`)
- Linux or macOS
- `tmux` recommended for instant attach/resume; without it, Continuum runs Pi directly
- A model provider configured in Pi (for example DeepSeek via `/login deepseek`)

Continuum 0.1.1 is tested on Linux/macOS. Native Windows is not supported because the launcher uses POSIX locking and tmux.

## Install

### From a local checkout

```bash
git clone <your-repo> continuum
cd continuum
npm install -g .
continuum --help
```

### From npm, once published

```bash
npm install -g pi-continuum@0.1.1
continuum --help
```

### Pi package resources

`pi-continuum` also ships the Continuum extension as a Pi package resource. Core agents and skills are installed into each project by `continuum new`.

```bash
pi install npm:pi-continuum@0.1.1
```

If you install the Pi package globally, create projects with:

```bash
continuum new acme --repo ~/src/acme --no-local-extension
```

Otherwise, `continuum new` copies the extension into the project and does not require the global Pi package. This avoids loading the same extension twice.

For local development:

```bash
pi install /path/to/continuum
```

## Quick start

```bash
continuum new acme --repo ~/src/acme
acme
```

`continuum new` writes:

```text
acme/
├── .agent/                 project manifest and runtime state
├── .pi/                    project config, agents, skills, extension
├── AGENTS.md               operating rules
├── CLM_STEERING.md         context-management brief
├── TASK.md / PLAN.md       task and plan templates
└── PROJECT_SKILLS.md       how to add project-local capabilities
```

`acme` is a generated wrapper for `continuum open acme`. The wrapper is placed in `~/.local/bin` when that directory is on `PATH`; otherwise Continuum uses `~/.pi/agent/bin`.

On first run, Pi will ask you to trust the project configuration. Review `.pi/` before approving.

## Commands

```text
continuum new <name> --repo <path>
continuum open <name>
continuum status <name>
continuum doctor <name>
continuum seal <name>
continuum fork-day <name>
continuum verify <name> [--root <path>]
continuum backup <name>
continuum list
continuum path <name>
```

### `new`

Creates the project scaffold, registry entry, and optional `~/.local/bin/<name>` wrapper.

Options:

```text
--model <provider/model>          default: deepseek/deepseek-flash
--verifier-model <provider/model> default: deepseek/deepseek-flash
--thinking <level>                default: high
--rollover snapshot|fork          default: snapshot
--no-link                         do not create the wrapper
--force                           overwrite metadata/template files
```

### `open`

Fast preflight, then:

1. attach to the live tmux session, if present;
2. otherwise resume the active session;
3. if the UTC day changed, seal the old day and continue or fork according to `rollover.mode`;
4. launch Pi with CLM environment and the project config.

Useful flags:

```text
--dry-run          print the command and CLM environment
--no-preflight     skip the fast checks
--no-tmux          run Pi directly, without tmux
```

### `seal`

Copies the active session into:

```text
.agent/sessions/days/<UTC-date>/<session-id>/
├── session.jsonl
├── manifest.json
├── seal.json
├── subagent-sessions/
├── subagent-artifacts/
├── TASK.md
├── PLAN.md
├── VERDICT.json
└── ...
```

### `verify`

Recomputes the archive hash and seal chain. Fails closed on missing files, tampering, or a broken seal.

### `fork-day`

Creates a new session from the current one with `pi --fork`, preserving the CLM projection. Refuses while the project tmux session is running.

## Rollover

`rollover.mode` in `.agent/project.json`:

- **`snapshot`** (default) — one continuous live session; daily archives.
- **`fork`** — first open of a new UTC day creates a new session via `pi --fork`.

Snapshot is recommended for continuity and storage. Fork is available when you deliberately want a clean day branch.

## Agents

Core agents installed in each project:

- `scout` — read-only repository mapping
- `implementer` — implementation and tests
- `verifier` — independent read-only verification
- `toolsmith` — creates project-local skills/extensions on demand

Optional examples, not loaded by default:

```text
examples/agents/researcher.md
examples/agents/diagrammer.md
examples/skills/research-protocol/
examples/skills/diagramming/
```

Add them per project when needed. `PROJECT_SKILLS.md` documents the workflow.

## Verification

`verifier` checks `TASK.md`, runs the relevant commands, and writes `VERDICT.json`. Work is not done until:

- every acceptance check has evidence,
- tests/lint/typecheck pass,
- verifier returns `PASS`,
- no unresolved high-risk item remains.

This improves reliability; it does not guarantee “100% correct” results.

## Backup

State is local by default. Configure `backup.command` in `.agent/project.json` and run:

```bash
continuum backup acme
```

See [docs/BACKUP.md](docs/BACKUP.md) for restic/rclone examples and the restore test.

## Security

Read [SECURITY.md](./SECURITY.md).

- Project-local packages, agents, skills, and extensions execute code.
- Review `.pi/` before granting project trust.
- Never commit API keys or `auth.json`.
- CLM makes context model-editable; treat untrusted repository content as a prompt-injection risk.

## Uninstall

```bash
pi remove npm:pi-continuum
npm uninstall -g pi-continuum
rm ~/.local/bin/<project>       # generated wrapper
```

Project runtime state lives in each repo’s `.agent/` directory. Remove it only after archiving what you need.

## Development

```bash
make test
```

The smoke test creates a temporary project, seals a synthetic session, verifies it, tampers with it, and confirms verification fails.

See:

- [docs/design/DRAFT.md](docs/design/DRAFT.md) — architecture
- [docs/design/LIVE-TEST-REPORT.md](docs/design/LIVE-TEST-REPORT.md) — live test results
- [docs/design/TEST-PLAN.md](docs/design/TEST-PLAN.md) — full test matrix
- [docs/design/PACKAGING.md](docs/design/PACKAGING.md) — packaging notes
