#!/usr/bin/env bash
# The one path for cleaning up a finished task (merge.md, Clean up).
# Usage: cleanup-task.sh <repo-root> <worktree-path> <branch> <base-ref> [--force-unmerged] [--drop-db <name>]
#   Removes the worktree and its branch through remove-worktree.sh, with the
#   same refusals (outside ~/.t3/worktrees, uncommitted changes, env files).
#   --force-unmerged  also removes a branch not merged into <base-ref>, only
#                     on Mattia's yes; prints its tip so it can be restored.
#   --drop-db <name>  then drops that scratch database with the command in
#                     the repo's git config: tracer.dropDbCommand ({db} stands
#                     for the name) and tracer.scratchDbPrefix (the name must
#                     start with it). Mattia sets both from the project's
#                     private notes; the drop command is never typed on the
#                     command line.
# Exit 0 done, 1 refused, 2 usage.
set -euo pipefail

usage() { sed -n '2,14p' "$0"; exit 2; }
refuse() { echo "refused: $*"; exit 1; }

[ $# -ge 4 ] || usage
repo=$1; wt=$2; branch=$3; base=$4; shift 4
force=0; db=""
while [ $# -gt 0 ]; do
  case $1 in
    --force-unmerged) force=1; shift ;;
    --drop-db) [ $# -ge 2 ] || usage; db=$2; shift 2 ;;
    *) usage ;;
  esac
done

# Check the database first, so a bad name removes nothing.
if [ -n "$db" ]; then
  cmd=$(git -C "$repo" config --get tracer.dropDbCommand || true)
  prefix=$(git -C "$repo" config --get tracer.scratchDbPrefix || true)
  [ -n "$cmd" ] && [ -n "$prefix" ] \
    || refuse "set tracer.dropDbCommand and tracer.scratchDbPrefix in $repo's git config (from the project's private notes) first"
  case $cmd in *"{db}"*) ;; *) refuse "tracer.dropDbCommand has no {db} placeholder" ;; esac
  case $db in *[!A-Za-z0-9_]*) refuse "database name $db: letters, digits and _ only" ;; esac
  case $db in "$prefix"?*) ;; *) refuse "$db is not a scratch database (no $prefix prefix)" ;; esac
fi

TRACER_FORCE_UNMERGED=$force bash "$(dirname "$0")/remove-worktree.sh" "$repo" "$wt" "$branch" "$base"

if [ -n "$db" ]; then
  sh -c "${cmd//\{db\}/$db}" || refuse "dropping $db failed; the worktree and branch are already gone"
  echo "dropped scratch database $db"
fi
