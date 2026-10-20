#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME" "$TMP/repo"
mkdir -p "$TMP/repo"

"$ROOT/bin/continuum" new smoke --repo "$TMP/repo" --no-link >/dev/null
"$ROOT/bin/continuum" status smoke >/dev/null
"$ROOT/bin/continuum" open smoke --dry-run | grep -q -- "--session-id smoke-"

mkdir -p "$TMP/repo/.agent/sessions/live"
cat > "$TMP/repo/.agent/sessions/live/smoke.jsonl" <<'EOF'
{"type":"session","version":3,"id":"smoke-20261019","timestamp":"2026-10-19T00:00:00.000Z","cwd":"/tmp/smoke"}
{"type":"message","id":"a1","parentId":null,"timestamp":"2026-10-19T00:00:01.000Z","message":{"role":"user","content":"hello","timestamp":1760000000000}}
EOF
cat > "$TMP/repo/.agent/active.json" <<EOF
{"project":"smoke","utc_day":"2026-10-19","session_id":"smoke-20261019","session_file":"$TMP/repo/.agent/sessions/live/smoke.jsonl","leaf_id":"a1","model":"deepseek/deepseek-flash","updated_at":"2026-10-19T00:00:01Z"}
EOF

"$ROOT/bin/continuum" seal smoke >/dev/null
"$ROOT/bin/continuum" verify smoke | grep -q '^PASS'
"$ROOT/bin/continuum" backup smoke --command 'true'

mkdir -p "$TMP/restore/.agent"
cp -a "$TMP/repo/.agent/." "$TMP/restore/.agent/"
"$ROOT/bin/continuum" verify smoke --root "$TMP/restore" | grep -q '^PASS'

printf 'x' >> "$TMP/repo/.agent/sessions/days/2026-10-19/smoke-20261019/session.jsonl"
if "$ROOT/bin/continuum" verify smoke >/dev/null 2>&1; then
  echo "FAIL: tampered archive passed verification"
  exit 1
fi

echo "PASS: continuum smoke tests"
