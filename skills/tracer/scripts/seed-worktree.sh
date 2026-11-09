#!/usr/bin/env bash
# Seed a task's new worktree with what git does not bring (workers.md, Worktree seeding).
# Usage: seed-worktree.sh <worktree-path>
#   Run right after the launch that creates the worktree: waits up to
#   SEED_WAIT seconds (default 120) for it. Then, from the main checkout:
#   - .claude/settings.local.json when the project has a .mcp.json;
#   - untracked .env* files at the same relative paths, each made ignored there;
#   - the installed dependency directory when the lockfile is byte-identical,
#     then the project's verify (`git config tracer.depsVerify`, else the
#     ecosystem's own); a failed verify removes the copy.
#   Existing files in the worktree are kept. Env contents are never printed.
#   The outcome goes to <git-dir>/tracer-seed, which the worker reads.
# Exit 0 seeded, 1 failed, 2 usage.
set -euo pipefail

[ $# -eq 1 ] || { sed -n '2,13p' "$0"; exit 2; }
wt=$1
note=""
fail() {
  echo "seed failed: $*" >&2
  [ -n "$note" ] && echo "seed failed: $*; install per workers.md, Dependencies" >> "$note"
  exit 1
}

case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) win=1 ;; *) win=0 ;; esac

wait=${SEED_WAIT:-120}; waited=0
until git -C "$wt" rev-parse --git-dir >/dev/null 2>&1; do
  [ "$waited" -lt "$wait" ] || fail "no worktree at $wt after ${wait}s"
  sleep 2; waited=$((waited + 2))
done

common=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir)
main=$(dirname "$common")
[ "$(git -C "$main" rev-parse --show-toplevel 2>/dev/null)" = "$main" ] || fail "no main checkout at $main"
wt=$(git -C "$wt" rev-parse --show-toplevel)
[ "$wt" != "$main" ] || fail "$wt is the main checkout, not a worktree"
note="$(git -C "$wt" rev-parse --path-format=absolute --git-dir)/tracer-seed"
: > "$note"
say() { echo "$*"; echo "$*" >> "$note"; }

# MCP approval: without it the worker stalls on "New MCP servers found".
if [ -f "$main/.mcp.json" ] && [ ! -e "$wt/.claude/settings.local.json" ]; then
  mkdir -p "$wt/.claude"
  if [ -f "$main/.claude/settings.local.json" ]; then
    cp -p "$main/.claude/settings.local.json" "$wt/.claude/" || fail "could not copy .claude/settings.local.json"
  else
    echo '{"enableAllProjectMcpServers": true}' > "$wt/.claude/settings.local.json"
  fi
  say "mcp: settings.local.json in place"
fi

exclude=$(git -C "$wt" rev-parse --path-format=absolute --git-path info/exclude)
while IFS= read -r f; do
  [ -f "$main/$f" ] || continue
  if [ -e "$wt/$f" ]; then
    say "env: kept existing $f"
  else
    mkdir -p "$(dirname "$wt/$f")"
    cp -p "$main/$f" "$wt/$f" || fail "could not copy $f"
    say "env: copied $f"
  fi
  if ! git -C "$wt" check-ignore -q "$f"; then
    mkdir -p "$(dirname "$exclude")"
    echo "/$f" >> "$exclude"
    say "env: $f was not ignored in the worktree; added to info/exclude"
  fi
done < <(git -C "$main" ls-files -oi --exclude-standard --directory | grep -E '(^|/)\.env[^/]*$' || true)

# Dependencies: lockfile, installed directory, default verify.
deps() {
  case $1 in
    package-lock.json)
      if [ "$win" = 1 ]; then echo "node_modules|npm install --prefer-offline --no-audit --no-fund"
      else echo "node_modules|npm ls"; fi ;;
    pnpm-lock.yaml) echo "node_modules|pnpm install --offline --frozen-lockfile" ;;
    yarn.lock)      echo "node_modules|yarn install --offline --frozen-lockfile" ;;
    composer.lock)  echo "vendor|composer validate --no-check-publish" ;;
  esac
}
for lock in package-lock.json pnpm-lock.yaml yarn.lock composer.lock; do
  [ -f "$main/$lock" ] || continue
  spec=$(deps "$lock"); dir=${spec%%|*}
  verify=$(git -C "$main" config --get tracer.depsVerify || echo "${spec#*|}")
  if ! cmp -s "$main/$lock" "$wt/$lock"; then
    say "$dir: left to the worker ($lock differs from the main checkout's)"
  elif [ ! -d "$main/$dir" ]; then
    say "$dir: left to the worker (the main checkout has no $dir)"
  elif [ -e "$wt/$dir" ]; then
    say "$dir: kept the existing one"
  else
    tmp="$wt/.$dir.seeding"
    rm -rf -- "$tmp"
    if [ "$win" = 1 ]; then
      rc=0; MSYS_NO_PATHCONV=1 robocopy "$(cygpath -w "$main/$dir")" "$(cygpath -w "$tmp")" /E /MT:16 /NFL /NDL /NJH /NJS /NP >/dev/null || rc=$?
      [ "$rc" -lt 8 ] || { rm -rf -- "$tmp"; fail "robocopy of $dir failed (exit $rc)"; }
    else
      cp -a "$main/$dir" "$tmp" || { rm -rf -- "$tmp"; fail "copy of $dir failed"; }
    fi
    # Renamed into place in one step, so a worker never sees half a copy.
    mv -T "$tmp" "$wt/$dir" 2>/dev/null || { rm -rf -- "$tmp"; fail "$wt/$dir appeared during the copy"; }
    if (cd "$wt" && sh -c "$verify") >/dev/null 2>&1; then
      say "$dir: copied from the main checkout, verified ($verify)"
    else
      rm -rf -- "${wt:?}/$dir"
      say "$dir: left to the worker (the copy failed '$verify' and was removed)"
    fi
    # A verify that only rewrote lockfile metadata is not a change.
    git -C "$wt" diff --quiet -- "$lock" || { git -C "$wt" checkout -q -- "$lock"; say "$lock: restored after the verify rewrote it"; }
  fi
  break
done
say "seed done"
