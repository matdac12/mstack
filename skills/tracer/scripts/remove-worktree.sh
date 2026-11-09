#!/usr/bin/env bash
# Remove a finished task's worktree, its leftover folder and its branch.
# Usage: remove-worktree.sh <repo-root> <worktree-path> <branch> <base-ref>
#   <base-ref>: what the branch must be merged into (`main` here, `local/main`
#   on a linked machine). Settle the thread and stop its dev servers first.
# Over SSH: ssh <target> bash -s -- <args> < remove-worktree.sh
# Locally it runs through cleanup-task.sh, the one cleanup path.
# New untracked .env* files in the worktree are copied into the main checkout
# first. One that exists in both is compared by its set of keys, and by value
# only for the keys `git config tracer.sharedEnvKeys` lists (space separated;
# set from the project's private notes): a per-worktree value (a database
# name, a port) does not stop the removal. Values are never printed.
# TRACER_FORCE_UNMERGED=1 (set by cleanup-task.sh --force-unmerged) also
# removes an unmerged branch and prints its tip.
# Refuses (exit 1) instead of forcing anything that could lose work.
set -u
force=${TRACER_FORCE_UNMERGED:-0}

repo=${1:?repo root}; wt=${2:?worktree path}; branch=${3:?branch}; base=${4:?base ref}

refuse() { echo "refused: $*"; exit 1; }
env_keys() { sed -nE 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=.*/\2/p' "$1" | sort -u; }
env_val() { sed -nE "s/^[[:space:]]*(export[[:space:]]+)?$2[[:space:]]*=[[:space:]]*//p" "$1" | tail -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//'; }

case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) win=1 ;; *) win=0 ;; esac

norm() {
  if [ "$win" = 1 ]; then cygpath -m "$1" | tr '[:upper:]' '[:lower:]' | sed 's#/*$##'
  else realpath -m "$1"
  fi
}

root=$(norm "$HOME/.t3/worktrees")
target=$(norm "$wt")
case "$target" in "$root"/?*) ;; *) refuse "$wt is not under ~/.t3/worktrees" ;; esac

registered=0
while IFS= read -r line; do
  [ "$(norm "${line#worktree }")" = "$target" ] && registered=1
done < <(git -C "$repo" worktree list --porcelain | grep '^worktree ')

if [ "$registered" = 1 ]; then
  [ -z "$(git -C "$wt" status --porcelain)" ] || refuse "$wt has uncommitted changes"
  [ "$force" = 1 ] || git -C "$repo" merge-base --is-ancestor "$branch" "$base" 2>/dev/null \
    || refuse "$branch is not merged into $base"
  # Env files a worker created live only here: bring new ones back to the
  # main checkout first. A new key, or a changed shared value, is left for you.
  shared=$(git -C "$repo" config --get tracer.sharedEnvKeys || true)
  while IFS= read -r f; do
    [ -f "$wt/$f" ] || continue
    if [ ! -e "$repo/$f" ]; then
      mkdir -p "$(dirname "$repo/$f")" && cp -p "$wt/$f" "$repo/$f" && echo "copied new $f into the main checkout"
    elif ! cmp -s "$wt/$f" "$repo/$f"; then
      [ "$(env_keys "$wt/$f")" = "$(env_keys "$repo/$f")" ] \
        || refuse "$f has other keys than the main checkout's copy: compare them, then rerun"
      for k in $shared; do
        case $k in *[!A-Za-z0-9_]*) refuse "tracer.sharedEnvKeys holds a bad key name: $k" ;; esac
        [ "$(env_val "$wt/$f" "$k")" = "$(env_val "$repo/$f" "$k")" ] \
          || refuse "$f: shared key $k differs from the main checkout's: compare them, then rerun"
      done
      echo "kept the main checkout's $f (same keys, only per-worktree values differ)"
    fi
  done < <(git -C "$wt" ls-files -oi --exclude-standard --directory | grep -E '(^|/)\.env[^/]*$')
  git -C "$repo" -c core.longpaths=true worktree remove --force "$wt" 2>/dev/null \
    && echo "removed worktree $wt"
elif [ -e "$wt/.git" ]; then
  refuse "$wt is a checkout this repo does not know"
fi

if [ -e "$wt" ]; then
  if [ "$win" = 1 ]; then
    # rmdir /s removes junctions without following them into their targets.
    MSYS_NO_PATHCONV=1 cmd /c rmdir /s /q "\\\\?\\$(cygpath -w "$wt")"
  else
    rm -r --interactive=never -- "$wt"
  fi
  [ -e "$wt" ] && refuse "could not delete $wt"
  echo "deleted folder $wt"
fi
git -C "$repo" worktree prune

git -C "$repo" show-ref --verify --quiet "refs/heads/$branch" || exit 0
# `branch -d` checks against the checked-out branch. On a linked machine that
# is behind `local/<defaultBranch>`, so fast-forward it first when it is clean.
head=$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$head" ] && [ "$(git -C "$repo" rev-parse HEAD)" != "$(git -C "$repo" rev-parse "$base")" ] \
  && [ -z "$(git -C "$repo" status --porcelain --untracked-files=no)" ]; then
  git -C "$repo" merge --ff-only -q "$base" 2>/dev/null && echo "fast-forwarded $head to $base"
fi
if [ "$force" = 1 ] && ! git -C "$repo" merge-base --is-ancestor "$branch" "$base" 2>/dev/null; then
  tip=$(git -C "$repo" rev-parse "$branch")
  git -C "$repo" branch -D "$branch" >/dev/null || refuse "could not delete $branch"
  echo "deleted unmerged branch $branch (tip $tip; restore: git branch $branch $tip)"
  exit 0
fi
git -C "$repo" branch -d "$branch" >/dev/null 2>&1 && echo "deleted branch $branch" \
  || refuse "$branch not deleted: not merged into $head"
