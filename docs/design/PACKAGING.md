# Continuum Packaging Plan

## The constraint

A Pi extension runs **inside** an already-running Pi process. It can manage context, snapshots, commands, tools, and project state, but it cannot be the thing that turns a shell command like `myproject` into a new Pi session.

So the final product is:

- **one Pi package** — extension + skills + agents + templates,
- **one thin launcher** — `continuum` CLI that resolves the project, attaches to tmux, and starts/resumes Pi.

That is the minimum needed for the UX you want. “Just an extension” cannot also be the shell entry point.

## Target repository

```text
continuum/
├── package.json              # npm bin + pi manifest
├── bin/continuum             # thin launcher/CLI
├── extensions/
│   └── continuum.ts          # ledger, project state, commands, snapshots
├── skills/
│   ├── research-protocol/
│   ├── diagramming/
│   └── verification/
├── agents/
│   ├── scout.md
│   ├── implementer.md
│   ├── verifier.md
│   ├── researcher.md
│   ├── diagrammer.md
│   └── toolsmith.md
├── templates/project/        # optional scaffold used by `continuum new`
├── docs/
│   ├── ARCHITECTURE.md
│   ├── TESTING.md
│   ├── PACKAGING.md
│   └── SECURITY.md
├── README.md
├── LICENSE
└── .gitignore
```

## What stays

- `extensions/continuum.ts` — the core runtime.
- `bin/continuum` — project launcher.
- agents and skills that are stable.
- project templates.
- docs, tests, license, security notes.

## What goes

- `bin/pi-project` compatibility alias — remove before release unless needed.
- draft `DRAFT.md` / `REVIEW-2.md` — move to `docs/design/` or delete.
- scratch projects and generated `.agent/`.
- `__pycache__`, temp logs, demo registry entries.
- any personal paths, tokens, or machine-specific config.

## Install shapes

### A. Pi package only

```bash
pi install npm:@yourscope/continuum
```

Gives the extension, skills, agents, and templates. The user still needs a launcher for `myproject`.

### B. Pi package + global CLI (recommended)

```bash
npm install -g @yourscope/continuum
continuum new myproject --repo ~/src/myproject
myproject
```

`package.json` exposes `bin.continuum`, and `pi` exposes the package resources.

### C. Repo-only template

```bash
git clone ...
cd continuum
./install.sh
```

Useful before npm publishing; not the final UX.

## Extension responsibilities

- read/write `.agent/project.json`, `active.json`, `ledger.ndjson`;
- snapshot sessions into `days/YYYY-MM-DD/`;
- provide `/continuum status`, `/continuum seal`, `/continuum handoff`;
- validate manifests and seal chains;
- optionally scaffold project-local skills/extensions through `toolsmith`.

## Launcher responsibilities

- resolve project name from registry;
- attach to an existing tmux session;
- choose today’s session or fork it;
- pass CLM env/config;
- start Pi in the repo root.

## Release checklist

- [ ] Full test plan passes on a clean machine.
- [ ] No personal paths or secrets in repo.
- [ ] `pi install` from a clean agent dir loads without errors.
- [ ] `npm pack` includes only runtime files.
- [ ] README has install, first-run, security, and uninstall.
- [ ] Version 0.1.0 tagged.
- [ ] Test with DeepSeek + CLM + `pi-subagents`.
