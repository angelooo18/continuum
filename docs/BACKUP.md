# Backup and restore

Continuum keeps runtime state under each project’s `.agent/` directory. The launcher and extension do not upload it anywhere.

## Configure a backup command

Edit `.agent/project.json`:

```json
{
  "backup": {
    "mode": "command",
    "command": "restic backup \"$CONTINUUM_STATE\""
  }
}
```

`continuum backup <name>` runs the command with:

- `CONTINUUM_PROJECT` — project name
- `CONTINUUM_REPO` — project repository root
- `CONTINUUM_STATE` — `<repo>/.agent`

The command runs from the repository root. Its exit code is recorded in
`.agent/ledger.ndjson`. Backup takes a shared project lock and refuses while a
writer or seal holds the project lock.

Examples:

```json
{
  "backup": {
    "mode": "command",
    "command": "restic -r sftp:backup.example:/continuum backup \"$CONTINUUM_STATE\""
  }
}
```

```json
{
  "backup": {
    "mode": "command",
    "command": "rclone sync \"$CONTINUUM_STATE\" remote:continuum/$(basename \"$CONTINUUM_REPO\")"
  }
}
```

## Restore test

1. Restore a copy of `.agent/` into a temporary project root:

```bash
mkdir -p /tmp/continuum-restore
cp -a /path/to/restored/.agent /tmp/continuum-restore/.agent
```

2. Verify the restored archives without touching the original project:

```bash
continuum verify acme --root /tmp/continuum-restore
```

`verify` recomputes each session hash, seal, manifest inventory, and ledger record. A `PASS` means the restored archive is complete and internally consistent; it does not prove the backup provider’s retention or encryption, and the seal is not a retained cryptographic chain.

For a full restore drill, also open a copied day archive in a scratch Pi session and confirm the expected session content is present.
