#!/usr/bin/env bash
# The mechanical part of landing a reviewed branch (merge.md, Merge).
#   land.sh merge <repo-root> <branch> <reviewed-sha> <message-file> [<ssh> <remote-root> <label>]
#     Checks the main checkout is on its default branch, clean, with no merge
#     or rebase in progress; with the remote arguments fetches the branch from
#     the linked machine into refs/remotes/<label>/<branch>; checks it is the
#     reviewed commit; merges --no-ff with the message file. On conflicts it
#     aborts the merge. A fetched ref is deleted once merged.
#   land.sh sync <repo-root> <ssh> <remote-root>
#     Pushes the default branch to local/<default> there (never forced).
# Verifying the merged result stays yours. Exit 0 done, 1 stopped, 2 usage.
set -u

stop() { echo "stopped: $*"; exit 1; }
usage() { sed -n '2,11p' "$0"; exit 2; }

cmd=${1:-}; repo=${2:-}
[ -n "$cmd" ] && [ -n "$repo" ] || usage
default=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
default=${default#origin/}; default=${default:-main}

case "$cmd" in
merge)
  [ $# -eq 5 ] || [ $# -eq 8 ] || usage
  branch=$3; sha=$4; msg=$5
  [ -s "$msg" ] || stop "message file $msg is empty or missing"
  [ "$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null)" = "$default" ] || stop "main checkout is not on $default"
  gd=$(git -C "$repo" rev-parse --git-dir)
  case "$gd" in /*|?:*) ;; *) gd="$repo/$gd" ;; esac
  [ -e "$gd/MERGE_HEAD" ] || [ -d "$gd/rebase-merge" ] || [ -d "$gd/rebase-apply" ] && stop "a merge or rebase is in progress"
  [ -z "$(git -C "$repo" status --porcelain --untracked-files=no)" ] || stop "tracked changes in the main checkout: commit or stash first (ask Mattia)"
  ref=$branch
  if [ $# -eq 8 ]; then
    ssh=$6; root=$7; label=$8; ref="refs/remotes/$label/$branch"
    git -C "$repo" fetch -q "$ssh:$root" "+$branch:$ref" || stop "fetch from $ssh failed"
  fi
  want=$(git -C "$repo" rev-parse -q --verify "$sha^{commit}") || stop "unknown commit $sha"
  have=$(git -C "$repo" rev-parse -q --verify "$ref^{commit}") || stop "no branch $ref"
  [ "$have" = "$want" ] || stop "$ref is at ${have:0:12}, you reviewed ${want:0:12}: review the new commits first"
  before=$(git -C "$repo" rev-parse HEAD)
  if ! git -C "$repo" merge -q --no-ff -F "$msg" "$ref"; then
    git -C "$repo" merge --abort
    stop "conflicts merging $branch; main is back at ${before:0:12}. Resolve them in the worker's worktree (merge.md, step 3)"
  fi
  echo "merged $branch (${want:0:12}) into $default: ${before:0:12} -> $(git -C "$repo" rev-parse --short=12 HEAD)"
  echo "now verify; red means: git revert -m 1 --no-edit HEAD"
  [ "$ref" = "$branch" ] || { git -C "$repo" update-ref -d "$ref" && echo "deleted fetched ref $ref"; }
  ;;
sync)
  [ $# -eq 4 ] || usage
  ssh=$3; root=$4
  git -C "$repo" push -q "$ssh:$root" "$default:refs/heads/local/$default" \
    || stop "sync rejected: local/$default there moved; ask Mattia, never force it"
  echo "synced $default ($(git -C "$repo" rev-parse --short=12 "$default")) to local/$default on $ssh"
  ;;
*) usage ;;
esac
