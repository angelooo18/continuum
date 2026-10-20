#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$ROOT/bin/continuum"

path_has() {
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

if path_has "$HOME/.local/bin"; then
  BIN="$HOME/.local/bin"
elif path_has "$HOME/.pi/agent/bin"; then
  BIN="$HOME/.pi/agent/bin"
else
  BIN="$HOME/.local/bin"
  echo "warning: neither ~/.local/bin nor ~/.pi/agent/bin is on PATH" >&2
  echo "add this to your shell profile: export PATH=\"$BIN:\$PATH\"" >&2
fi

mkdir -p "$BIN"
ln -sf "$TARGET" "$BIN/continuum"
echo "installed $BIN/continuum -> $TARGET"
echo "run: continuum --help"
