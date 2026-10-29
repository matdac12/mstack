#!/usr/bin/env bash
# Remove a finished task's worktree, its leftover folder and its branch.
# Usage: remove-worktree.sh <repo-root> <worktree-path> <branch> <base-ref>
#   <base-ref>: what the branch must be merged into (`main` here, `local/main`
#   on a linked machine). Settle the thread and stop its dev servers first.
# Over SSH: ssh <target> bash -s -- <args> < remove-worktree.sh
# Refuses (exit 1) instead of forcing anything that could lose work.
set -u

repo=${1:?repo root}; wt=${2:?worktree path}; branch=${3:?branch}; base=${4:?base ref}

refuse() { echo "refused: $*"; exit 1; }

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
  git -C "$repo" merge-base --is-ancestor "$branch" "$base" 2>/dev/null \
    || refuse "$branch is not merged into $base"
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
git -C "$repo" branch -d "$branch" >/dev/null 2>&1 && echo "deleted branch $branch" \
  || refuse "$branch not deleted: not merged into $head"
