#!/usr/bin/env bash
# Start a worker agent in a new Herdr terminal, beside the orchestrator in the
# sidebar (workers.md, Launch).
# Usage: spawn-worker.sh <name> <checkout> <model> <effort> <brief-file>
#   name      unique among live terminals: 1-32 of a-z 0-9 - _
#   checkout  the task's worktree (or the main checkout for read-only work)
#   model     sonnet | opus | fable | grok | gpt | gpt:<model> (gpt alone: gpt-6.1-sol)
#   effort    claude: low | medium | high | xhigh | max; gpt, grok: low | medium | high | xhigh
#   brief     the file holding the brief; the worker's first message only points to it
# Works from Windows (Git Bash) and WSL. From WSL the worker runs in WSL too.
# The worker is this terminal's child (its blocked, error and exit notes come
# here) and outlives it. Prints hc's JSON (address, name, state).
# Exit 0 started, 1 failed, 2 usage.
set -euo pipefail

[ $# -eq 5 ] || { sed -n '2,13p' "$0"; exit 2; }
name=$1 checkout=$2 model=$3 effort=$4 brief=$5
here=$(cd "$(dirname "$0")" && pwd)
hc() { bash "$here/hc.sh" "$@"; }

case "$name" in *[!a-z0-9_-]*|"") echo "bad name: $name" >&2; exit 2 ;; esac
git -C "$checkout" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git checkout: $checkout" >&2; exit 1; }
[ -s "$brief" ] || { echo "brief missing or empty: $brief" >&2; exit 1; }

case "$model" in
  sonnet) cmd="claude --model claude-sonnet-5-5 --effort $effort" ;;
  opus)   cmd="claude --model claude-opus-5-5 --effort $effort" ;;
  fable)  cmd="claude --model claude-fable-5-2 --effort $effort" ;;
  grok)   cmd="grok -m grok-4.7 --effort $effort" ;;
  gpt|gpt:*)
    gm=${model#gpt}; gm=${gm#:}; gm=${gm:-gpt-6.1-sol}
    case "$gm" in *[!a-z0-9.-]*) echo "bad gpt model: $gm" >&2; exit 2 ;; esac
    # danger-full-access: Codex's sandbox blocks the socket WSL needs to run hc.exe,
    # so a sandboxed worker could never report.
    cmd="codex --no-daemon --sandbox danger-full-access -m $gm -c model_reasoning_effort=$effort" ;;
  *) echo "unknown model: $model (sonnet | opus | fable | grok | gpt | gpt:<model>)" >&2; exit 2 ;;
esac
case "$effort" in *[!a-z]*|"") echo "bad effort: $effort" >&2; exit 2 ;; esac

self=$(hc --self) || exit 1
space=$(hc --space "$self" || true)
args=(run --json --bg --outlive-parent --name "$name" --parent "$self")
[ -n "$space" ] && args+=(--label "herdr.space=$space")

case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) win=1 ;; *) win=0 ;; esac
if [ "$win" = 1 ]; then
  first="Read $(cygpath -m "$brief") and follow it."
  # shellcheck disable=SC2086 # cmd is a fixed word list built above
  hc "${args[@]}" --cwd "$(cygpath -w "$checkout")" -- $cmd "$first"
else
  checkout=$(cd "$checkout" && pwd)
  brief=$(cd "$(dirname "$brief")" && pwd)/$(basename "$brief")
  first="Read $brief and follow it."
  hc "${args[@]}" --cwd "$(wslpath -w "$checkout")" -- \
    wsl.exe --cd "$checkout" -e bash -lic "$cmd '$first'"
fi
