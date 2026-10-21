# Continuum

**Continuum** is a project runtime for [Pi](https://pi.dev) that combines:

- `pi-clm` for model-managed context,
- `pi-subagents` for scoped specialists,
- UTC-traceable per-session day archives,
- a project name that resumes or attaches to the live session,
- a verifier workflow plus a deterministic `continuum check` gate.

It is packaged as a Pi package plus a thin `continuum` launcher.

## Requirements

- Pi 1.3 or newer
- Node.js 20+
- Python 3.10+ (`python3` on `PATH`)
- Linux or macOS
- `tmux` recommended for instant attach/resume; without it, Continuum runs Pi directly
- A model provider configured in Pi (for example DeepSeek via `/login deepseek`)

Continuum 0.1.7 is tested on Linux/macOS. Native Windows is not supported because the launcher uses POSIX locking and tmux.

## Install

### From GitHub

```bash
git clone https://github.com/angelooo18/continuum.git
cd continuum
./install.sh
continuum --help
```

`install.sh` symlinks `bin/continuum` into a user bin directory already on `PATH`.

### Pi package resources

The repo also exposes the Continuum extension as a Pi package resource. Core agents and skills are installed into each project by `continuum new`.

Optional global Pi package install from Git:

```bash
pi install git:github.com/angelooo18/continuum@v0.1.7
```

If you install the Pi package globally, create projects with:

```bash
continuum new acme --repo ~/src/acme --no-local-extension
```

Otherwise, `continuum new` copies the extension into the project and does not require the global Pi package. This avoids loading the same extension twice.

## What gets installed

`pi-continuum` itself contains:

- the Continuum extension,
- project templates,
- core agents,
- the verification skill.

It does **not** vendor `pi-clm` or `pi-subagents`. They remain separate upstream packages.

`continuum new` merges these requirements into the project’s `.pi/settings.json`,
preserving existing keys and packages:

```json
{
  "packages": [
    "npm:@lolipopshock/pi-clm@1.0.0",
    "npm:pi-subagents@0.79.1"
  ],
  "subagents": {
    "defaultExtensions": [],
    "agentOverrides": {
      "verifier": {
        "model": "deepseek/deepseek-flash"
      }
    }
  }
}
```

Core agents also declare an empty `extensions:` list, so background children do not get a
second copy of `pi-clm` or the Continuum ledger extension. The verifier runs in
the foreground (`async: false`).

Pi installs those pinned packages into the project’s `.pi/npm/` directory on the first trusted run. To preinstall them manually:

```bash
pi install npm:@lolipopshock/pi-clm@1.0.0
pi install npm:pi-subagents@0.79.1
```

Optional, only when using the researcher example:

```bash
pi install npm:pi-web-access@0.42.0
```

Because the base template sets `subagents.defaultExtensions: []`, a copied
example agent must name the web-access extension explicitly in its `extensions`
frontmatter. See [examples/README.md](examples/README.md).

### Avoid duplicates

- The **Continuum extension** is copied into each project by default. If you also install `pi-continuum` globally as a Pi package, create projects with `continuum new ... --no-local-extension` so it is not loaded twice.
- `pi-clm` and `pi-subagents` are declared once, in the project settings. If you also install them globally, Pi treats the project entry as the project-scoped replacement for the same package identity; keep versions pinned and avoid mixing incompatible versions.
- Do not run `pi-observational-memory` alongside `pi-clm`; both manage compaction.

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

`acme` is a generated wrapper for `continuum open acme`. The wrapper is placed in `~/.local/bin` when that directory is on `PATH`; otherwise Continuum uses `~/.pi/agent/bin`. Reserved command names (`pi`, `continuum`, `git`, `node`, …) and names that already resolve to another command are refused unless you pass `--no-link`.

For an existing repository, `new` merges the required ignore rules and Pi
settings instead of replacing them, and creates `.agent/.gitignore` as a
defense in depth. `--force` backs up overwritten template files under
`.agent/backups/` before replacing them.

On first run, Pi will ask you to trust the project configuration. Review `.pi/` before approving.

## Commands

```text
continuum new <name> --repo <path>
continuum open <name>
continuum status <name>
continuum doctor <name>
continuum seal <name>
continuum fork-day <name>
continuum verify <name> [--root <path>] [--allow-empty]
continuum check <name>
continuum backup <name>
continuum list
continuum path <name>
```

### `new`

Creates the project scaffold, registry entry, and optional `~/.local/bin/<name>` wrapper.

Options:

```text
--model <provider/model>          lead model; default: deepseek/deepseek-flash
--verifier-model <provider/model> effective verifier model; default: deepseek/deepseek-flash
--thinking <level>                lead thinking level; default: high
--rollover snapshot|fork          default: snapshot
--no-link                         do not create the wrapper
--force                           overwrite metadata/template files with backups
```

### `open`

Fast preflight, then:

1. attach to the live tmux session, if present and tmux is wanted;
2. otherwise resume the active session;
3. if the UTC day changed, seal the old day and continue or fork according to `rollover.mode`;
4. launch Pi with CLM environment and the project config.

Useful flags:

```text
--dry-run          print the plan, command, and CLM environment; no seals, no attach, no launch
--no-preflight     skip the fast checks
--no-tmux          run Pi directly, even if the project tmux session exists
```

A direct launch holds `.agent/locks/open.lock` for the life of the Pi process.
tmux panes use an internal launcher to hold the same lock across `exec`. A
second launch (direct or tmux) fails instead of writing the same session
concurrently. `seal`, `backup`, and `verify` take the corresponding exclusive
or shared lock.

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

Recomputes the session hash, seal, and the manifest inventory. It fails closed
when the archive root, ledger, manifest, seal, session, or archived evidence is
missing or changed, and when the archive contains an unlisted file. `--root`
verifies a restored `.agent/` tree; `--allow-empty` is the explicit opt-in for a
project with no archives yet.

The seal is a local integrity check, not a retained cryptographic chain: each
archive keeps only its latest seal and the previous seal hash. Use external
backup/versioning when you need historical proof.

### `check`

Validates `VERDICT.json` against the `AC-*` acceptance checks in `TASK.md`.
It requires overall `PASS`, a `PASS` entry with evidence for every acceptance
check, and records a `done_gate` ledger event. This is the deterministic gate
the verifier and lead must run before declaring work done.

### `fork-day`

Creates a new session from the current one with `pi --fork`, preserving the CLM projection. Refuses while the project tmux session is running or the project writer lock is held. The new session ID includes a UTC time suffix, so same-day forks do not collide.

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
- `continuum check <name>` returns `PASS`,
- no unresolved high-risk item remains.

`continuum check` is a deterministic command gate; Pi does not prevent a lead
from ignoring it. The project `AGENTS.md`, verifier prompt, and verification
skill require it. This improves reliability; it does not guarantee “100%
correct” results.

## Design constraints

Continuum deliberately keeps the delegation tree shallow:

- the lead chooses delegation from `PLAN.md`; the default depth is 2;
- specialists do not auto-spawn or recursively spawn other specialists;
- parallel writers require isolated worktrees; otherwise implementation stays serial;
- there is no runtime topology router, no Jev-style decision controller, and no observational-memory layer in the lead;
- CLM is the only context manager in the lead, and `TASK.md`, `PLAN.md`, and `VERDICT.json` are the durable state.

Project-local skills and extensions are evaluated before adoption. See [RESEARCH.md](./RESEARCH.md) for the evidence and deliberate non-goals.

## Backup

State is local by default. Configure `backup.command` in `.agent/project.json` and run:

```bash
continuum backup acme
```

See [docs/BACKUP.md](docs/BACKUP.md) for restic/rclone examples and the restore test.

## Research

Continuum’s defaults are informed by CLM, multi-agent orchestration, verification, and harness-engineering research. See [RESEARCH.md](./RESEARCH.md) for paper citations, reported results, and the evidence caveats. DeepSeek-specific CLM profiles are in [docs/CLM-DEEPSEEK.md](docs/CLM-DEEPSEEK.md).

## Credits

Continuum composes separate upstream packages. See [CREDITS.md](./CREDITS.md) for Pi, `pi-clm`, `pi-subagents`, optional `pi-web-access`, and research references.

## Security

Read [SECURITY.md](./SECURITY.md).

- Project-local packages, agents, skills, and extensions execute code.
- Review `.pi/` before granting project trust.
- Never commit API keys or `auth.json`.
- CLM makes context model-editable; treat untrusted repository content as a prompt-injection risk.

## Uninstall

```bash
./uninstall.sh
pi remove git:github.com/angelooo18/continuum
```

Remove generated project wrappers individually if needed:

```bash
rm ~/.local/bin/<project>
rm ~/.pi/agent/bin/<project>
```

Project runtime state lives in each repo’s `.agent/` directory. Remove it only after archiving what you need.

## Development

```bash
make test
```

`make test` runs the smoke test, the regression suite, and the TypeScript
extension checks. The smoke test creates a temporary project, seals a synthetic
session, verifies it, tampers with it, and confirms verification fails. The
regression suite covers fail-closed verification, JSONL corruption, dry-run/tmux
precedence, writer locks, existing repository merges, reserved wrapper names,
fork IDs, the completion gate, and effective verifier configuration. The
extension checks run the real TypeScript handlers against a synthetic project,
including the subagent guard and malformed-JSONL path.

See:

- [docs/CLM-DEEPSEEK.md](docs/CLM-DEEPSEEK.md) — DeepSeek CLM profiles
- [docs/BACKUP.md](docs/BACKUP.md) — backup and restore
- [RESEARCH.md](RESEARCH.md) — research citations
- [CREDITS.md](CREDITS.md) — upstream projects
