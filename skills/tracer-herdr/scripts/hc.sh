#!/usr/bin/env bash
# Run herdr-core's `hc` the same way from Windows (Git Bash) and WSL.
# Usage: hc.sh <hc arguments...>   runs hc with them
#        hc.sh --self              prints this terminal's hc address (t4)
#        hc.sh --space <address>   prints that terminal's herdr.space label
# In WSL only `hc.exe` is on PATH, and $HC_TERMINAL_ID is not passed in:
# it is read from the Windows side of the same terminal through cmd.exe.
# Exit 0 ok, 1 not inside Herdr / hc missing, else hc's own exit code.
set -uo pipefail

if command -v hc >/dev/null 2>&1; then HC=hc
elif command -v hc.exe >/dev/null 2>&1; then HC=hc.exe
else echo "hc not found: is Herdr installed on this machine?" >&2; exit 1
fi

case "${1:-}" in
  --self)
    id=${HC_TERMINAL_ID:-}
    if [ -z "$id" ] && command -v cmd.exe >/dev/null 2>&1; then
      id=$(cd /mnt/c 2>/dev/null; cmd.exe /c "echo %HC_TERMINAL_ID%" 2>/dev/null | tr -d '\r')
    fi
    case "$id" in
      t[0-9a-z]*) [ "$id" = "%HC_TERMINAL_ID%" ] || { echo "$id"; exit 0; } ;;
    esac
    echo "not inside a Herdr terminal (no HC_TERMINAL_ID)" >&2; exit 1 ;;
  --space)
    [ $# -eq 2 ] || { echo "usage: hc.sh --space <address>" >&2; exit 2; }
    "$HC" get "$2" --json | grep -o '"herdr.space":"[^"]*"' | head -n 1 | cut -d'"' -f4
    exit 0 ;;
esac

exec "$HC" "$@"
