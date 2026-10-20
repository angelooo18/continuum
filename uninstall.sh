#!/usr/bin/env bash
set -euo pipefail

for path in "$HOME/.local/bin/continuum" "$HOME/.pi/agent/bin/continuum"; do
  if [ -L "$path" ] || [ -f "$path" ]; then
    rm -f "$path"
    echo "removed $path"
  fi
done
