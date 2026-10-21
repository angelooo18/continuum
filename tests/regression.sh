#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
C="$ROOT/bin/continuum"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME" "$TMP/bin"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

DAY="$(date -u +%F)"
YDAY="$(python3 -c 'from datetime import datetime,timedelta,timezone; print((datetime.now(timezone.utc)-timedelta(days=1)).strftime("%Y-%m-%d"))')"
SID="demo-$(date -u +%Y%m%d)"

new_project() {
  local name="$1" repo="$2"
  mkdir -p "$repo"
  rm -f "$HOME/.pi/projects/registry.json"
  "$C" new "$name" --repo "$repo" --no-link >/dev/null
}

write_session() {
  local repo="$1" day="$2" sid="$3" content="${4:-}"
  mkdir -p "$repo/.agent/sessions"
  if [ -z "$content" ]; then
    printf '{"type":"session","version":3,"id":"%s","timestamp":"%sT00:00:00Z"}\n{"type":"message","id":"m1","parentId":null,"message":{"role":"user","content":"hi"}}\n' "$sid" "$day" > "$repo/.agent/sessions/$sid.jsonl"
  else
    printf '%s' "$content" > "$repo/.agent/sessions/$sid.jsonl"
  fi
  cat > "$repo/.agent/active.json" <<JSON
{"project":"demo","utc_day":"$day","session_id":"$sid","session_file":"$repo/.agent/sessions/$sid.jsonl","leaf_id":"m1","model":"deepseek/deepseek-flash"}
JSON
}

# 1. Existing repository: merge ignore/settings, and refuse shadowing names.
REPO="$TMP/existing"
mkdir -p "$REPO/.pi"
git -C "$REPO" init -q
printf 'node_modules/\n' > "$REPO/.gitignore"
printf '{"theme":"dark","packages":["npm:pi-subagents@0.79.1"],"subagents":{"agentOverrides":{"verifier":{"model":"existing/verifier"}}}}\n' > "$REPO/.pi/settings.json"
"$C" new demo --repo "$REPO" --no-link >/dev/null
git -C "$REPO" check-ignore -q .agent/active.json || fail "existing .agent state is not ignored"
grep -q '^# BEGIN continuum runtime$' "$REPO/.gitignore" || fail "existing .gitignore not merged"
grep -q 'npm:@lolipopshock/pi-clm@1.0.0' "$REPO/.pi/settings.json" || fail "pi-clm not merged"
grep -q '"model": "existing/verifier"' "$REPO/.pi/settings.json" || fail "existing verifier override was not preserved"
printf 'custom task\n' > "$REPO/TASK.md"
"$C" new demo --repo "$REPO" --no-link --force >/dev/null
grep -q '"model": "existing/verifier"' "$REPO/.pi/settings.json" || fail "--force replaced existing settings"
find "$REPO/.agent/backups" -name TASK.md -exec grep -q 'custom task' {} \; || fail "--force did not back up TASK.md"
grep -q '^extensions:$' "$ROOT/templates/project/.pi/agents/scout.md" || fail "core agent ambient extension policy missing"
grep -q '^async: false$' "$ROOT/templates/project/.pi/agents/verifier.md" || fail "verifier is not foreground"
pass "existing repository merge and subagent isolation"

if "$C" new pi --repo "$TMP/reserved" >/dev/null 2>&1; then
  fail "reserved wrapper name was accepted"
fi
if "$C" new other --repo "$REPO" --no-link >/dev/null 2>&1; then
  fail "same repository registered under a second name"
fi
pass "wrapper and project identity guards"

# 2. Empty projects require explicit opt-in; sealed archives verify.
REPO="$TMP/empty"
new_project demo "$REPO"
"$C" verify demo --allow-empty >/dev/null || fail "--allow-empty did not pass"
if "$C" verify demo >/dev/null 2>&1; then fail "empty project verified without opt-in"; fi

REPO="$TMP/archive"
new_project demo "$REPO"
write_session "$REPO" "$DAY" "$SID"
"$C" seal demo >/dev/null
"$C" verify demo >/dev/null || fail "intact archive did not verify"
ARCH="$REPO/.agent/sessions/days/$DAY/$SID"
cp -a "$REPO/.agent" "$TMP/agent-valid"

printf 'unlisted\n' > "$ARCH/extra.txt"
if "$C" verify demo >/dev/null 2>&1; then fail "unlisted archive file verified"; fi
rm "$ARCH/extra.txt"
"$C" verify demo >/dev/null || fail "archive did not verify after removing unlisted file"

rm "$ARCH/TASK.md"
if "$C" verify demo >/dev/null 2>&1; then fail "missing archived TASK.md verified"; fi
rm -rf "$REPO/.agent"; cp -a "$TMP/agent-valid" "$REPO/.agent"

rm "$ARCH/manifest.json"
if "$C" verify demo >/dev/null 2>&1; then fail "missing manifest verified"; fi
rm -rf "$REPO/.agent"; cp -a "$TMP/agent-valid" "$REPO/.agent"

rm "$ARCH/seal.json"
if "$C" verify demo >/dev/null 2>&1; then fail "missing seal verified"; fi
rm -rf "$REPO/.agent"; cp -a "$TMP/agent-valid" "$REPO/.agent"

rm -rf "$ARCH"
if "$C" verify demo >/dev/null 2>&1; then fail "missing archive verified"; fi
rm -rf "$REPO/.agent"; cp -a "$TMP/agent-valid" "$REPO/.agent"

rm "$REPO/TASK.md" "$REPO/PLAN.md"
"$C" seal demo >/dev/null
if "$C" verify demo >/dev/null 2>&1; then fail "re-seal without TASK/PLAN verified"; fi
pass "verify fails closed"

# 3. Malformed middle line aborts; partial trailing line is tolerated.
REPO="$TMP/malformed"
new_project demo "$REPO"
SID2="demo-20261021-bad"
write_session "$REPO" "$DAY" "$SID2" "{\"type\":\"session\",\"version\":3,\"id\":\"$SID2\",\"timestamp\":\"${DAY}T00:00:00Z\"}
{\"type\":\"message\",\"id\":\"m1\",\"parentId\":null,\"message\":{\"role\":\"user\",\"content\":\"hi\"}}
BROKEN
{\"type\":\"message\",\"id\":\"m2\",\"parentId\":\"m1\",\"message\":{\"role\":\"assistant\",\"content\":\"later\"}}
"
if "$C" seal demo >/dev/null 2>&1; then fail "malformed middle line sealed"; fi

REPO="$TMP/partial"
new_project demo "$REPO"
SID3="demo-20261021-partial"
write_session "$REPO" "$DAY" "$SID3" "{\"type\":\"session\",\"version\":3,\"id\":\"$SID3\",\"timestamp\":\"${DAY}T00:00:00Z\"}
{\"type\":\"message\",\"id\":\"m1\",\"parentId\":null,\"message\":{\"role\":\"user\",\"content\":\"hi\"}}
{\"partial\":"
"$C" seal demo >/dev/null
"$C" verify demo >/dev/null || fail "partial trailing line was not tolerated"
pass "JSONL integrity handling"

# 4. Relative session paths from the Pi extension resolve against the project.
REPO="$TMP/relative"
new_project demo "$REPO"
SID_REL="demo-$(date -u +%Y%m%d)-rel"
mkdir -p "$REPO/.agent/sessions"
printf '{"type":"session","version":3,"id":"%s","timestamp":"%sT00:00:00Z"}\n{"type":"message","id":"m1","parentId":null,"message":{"role":"user","content":"hi"}}\n' "$SID_REL" "$DAY" > "$REPO/.agent/sessions/$SID_REL.jsonl"
cat > "$REPO/.agent/active.json" <<JSON
{"project":"demo","utc_day":"$DAY","session_id":"$SID_REL","session_file":".agent/sessions/$SID_REL.jsonl","leaf_id":"m1"}
JSON
(cd /tmp && "$C" open demo --dry-run >/dev/null) || fail "open failed on a relative session path"
(cd /tmp && "$C" seal demo >/dev/null) || fail "seal failed on a relative session path"
(cd /tmp && "$C" verify demo >/dev/null) || fail "verify failed after relative-path seal"
pass "project-relative session paths"

# 5. Dry-run does not seal or attach; --no-tmux bypasses fake tmux.
printf '#!/bin/sh\necho "tmux $*" >> "%s/tmux.log"\nif [ "$1" = "has-session" ]; then exit 0; fi\nexit 0\n' "$TMP" > "$TMP/bin/tmux"
chmod +x "$TMP/bin/tmux"
cat > "$TMP/bin/pi" <<'PI'
#!/bin/sh
echo ran > "${PI_MARKER:?}"
exit 0
PI
chmod +x "$TMP/bin/pi"

REPO="$TMP/dryrun"
new_project demo "$REPO"
write_session "$REPO" "$YDAY" "demo-$(python3 -c 'from datetime import datetime,timedelta,timezone; print((datetime.now(timezone.utc)-timedelta(days=1)).strftime("%Y%m%d"))')"
PATH="$TMP/bin:$PATH" TMUX_LOG="$TMP/tmux.log" "$C" open demo --dry-run >/dev/null
[ ! -e "$TMP/tmux.log" ] || fail "dry-run invoked tmux"
[ -z "$(find "$REPO/.agent/sessions/days" -type f -print -quit)" ] || fail "dry-run sealed an archive"
PATH="$TMP/bin:$PATH" TMUX_LOG="$TMP/tmux.log" "$C" open demo --dry-run --no-tmux >/dev/null
[ ! -e "$TMP/tmux.log" ] || fail "dry-run --no-tmux invoked tmux"

write_session "$REPO" "$DAY" "$SID"
PATH="$TMP/bin:$PATH" PI_BIN="$TMP/bin/pi" PI_MARKER="$TMP/pi-ran" "$C" open demo --no-tmux >/dev/null
[ -e "$TMP/pi-ran" ] || fail "direct launch did not run Pi"
[ ! -e "$TMP/tmux.log" ] || fail "--no-tmux attached to tmux"
pass "dry-run and --no-tmux precedence"

# 6. Direct writer lock and read-side exclusion.
cat > "$TMP/bin/pi-sleep" <<'PI'
#!/bin/sh
echo "$$" > "${PI_PID_FILE:?}"
sleep 3
PI
chmod +x "$TMP/bin/pi-sleep"
REPO="$TMP/lock"
new_project demo "$REPO"
write_session "$REPO" "$DAY" "$SID"
PI_BIN="$TMP/bin/pi-sleep" PI_PID_FILE="$TMP/pi.pid" "$C" open demo --no-tmux >/dev/null 2>&1 &
BGPID=$!
for _ in $(seq 1 50); do [ -s "$TMP/pi.pid" ] && break; sleep 0.1; done
[ -s "$TMP/pi.pid" ] || fail "writer did not start"
if "$C" open demo --no-tmux >/dev/null 2>&1; then fail "second writer was allowed"; fi
if "$C" seal demo >/dev/null 2>&1; then fail "seal ran while a writer was active"; fi
if "$C" verify demo >/dev/null 2>&1; then fail "verify ran while a writer was active"; fi
if "$C" backup demo --command true >/dev/null 2>&1; then fail "backup ran while a writer was active"; fi
wait "$BGPID" || true
pass "writer lock"

# 7. Same-day fork IDs are fresh and dry-run does not seal.
REPO="$TMP/fork"
new_project demo "$REPO"
write_session "$REPO" "$DAY" "$SID"
FORK_OUT="$("$C" fork-day demo --dry-run)"
printf '%s\n' "$FORK_OUT" | grep -q -- "--session-id demo-.*-[0-9][0-9][0-9][0-9][0-9][0-9]" || fail "fork id is not time-qualified"
[ -z "$(find "$REPO/.agent/sessions/days" -type f -print -quit)" ] || fail "fork dry-run sealed"

# Pi prefixes live session filenames with a timestamp. A collision check that
# only probes <session-id>.jsonl misses an existing ID in such a file.
python3 - "$C" "$REPO" <<'PY'
import importlib.util
import json
import sys
from datetime import datetime, timezone
from importlib.machinery import SourceFileLoader
from pathlib import Path

sys.dont_write_bytecode = True
cli, root = sys.argv[1], Path(sys.argv[2])
loader = SourceFileLoader("continuum_cli", cli)
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

class FixedDatetime(datetime):
    @classmethod
    def now(cls, tz=None):
        return datetime(2026, 10, 21, 4, 10, 10, tzinfo=tz or timezone.utc)

module.datetime = FixedDatetime
sid = "demo-20261021-041010"
sessions = root / ".agent" / "sessions"
prefixed = sessions / f"2026-10-21T04-10-08-000Z_{sid}.jsonl"
prefixed.write_text(json.dumps({"type": "session", "id": sid}) + "\n")
assert module.fresh_session_id(root, "demo", "2026-10-21") == f"{sid}-1"

prefixed.unlink()
archive = sessions / "days" / "2026-10-21" / sid
archive.mkdir(parents=True, exist_ok=True)
assert module.fresh_session_id(root, "demo", "2026-10-21") == f"{sid}-1"
print("PASS: fork id collision checks header and archive ids")
PY
pass "same-day fork id"

# 8. Deterministic completion gate.
REPO="$TMP/check"
new_project demo "$REPO"
cat > "$REPO/TASK.md" <<'TASK'
# Task
## Acceptance checks
- [ ] AC-1: works
- [ ] AC-2: tested
TASK
cat > "$REPO/VERDICT.json" <<'VERDICT'
{"status":"PASS","checks":[{"id":"AC-1","status":"PASS","evidence":"ran test"},{"id":"AC-2","status":"PASS","evidence":["pytest"]}]}
VERDICT
"$C" check demo >/dev/null || fail "valid verdict did not pass check"
printf '# Task\n\nNo checks.\n' > "$REPO/TASK.md"
cat > "$REPO/VERDICT.json" <<'VERDICT'
{"status":"PASS","checks":[{"id":"AC-1","status":"PASS","evidence":"ran test"}]}
VERDICT
if "$C" check demo >/dev/null 2>&1; then fail "task without acceptance checks passed check"; fi
cat > "$REPO/TASK.md" <<'TASK'
# Task
## Acceptance checks
- [ ] AC-1: works
- [ ] AC-2: tested
TASK
cat > "$REPO/VERDICT.json" <<'VERDICT'
{"status":"PASS","checks":[{"id":"AC-1","status":"PASS","evidence":"ran test"}]}
VERDICT
if "$C" check demo >/dev/null 2>&1; then fail "missing acceptance evidence passed check"; fi
pass "completion gate"

# 9. --verifier-model is effective in project settings.
REPO="$TMP/verifier"
mkdir -p "$REPO"
"$C" new verifier --repo "$REPO" --no-link --verifier-model custom/verifier >/dev/null
grep -q '"model": "custom/verifier"' "$REPO/.pi/settings.json" || fail "verifier model override not written"
"$C" status verifier | grep -q 'custom/verifier' || fail "status does not show effective verifier"
pass "effective verifier model"

echo "PASS: continuum regression tests"
