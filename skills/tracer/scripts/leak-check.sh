#!/usr/bin/env bash
# Scan commits about to leave this machine for secrets and private names.
# Usage: leak-check.sh <repo-root> [--message-file <path>] <rev-range...>   e.g. origin/main..main
# Looks for: secret-looking values from the repo's untracked .env* files
# (keys naming a KEY, SECRET, TOKEN, PASS(WORD), DATABASE_URL or DSN), the
# machine names in ~/.t3/machines.md (any case), any line in
# ~/.t3/leak-patterns.txt, and, in a client repo, its tracker name, Mattia's
# personal skill names, local/<branch> sync refs and the issue keys in
# `git config tracer.projectKeys`. Strings in ~/.t3/leak-allow.txt are never
# patterns. Reads added diff lines and commit messages. Prints where a hit
# is, never the value.
# Exit 0 clean, 1 hits, 2 usage error. Run it as its own command, never
# chained with the push.
set -uo pipefail

repo=${1:?repo root}; shift
message_file=""
if [ "${1:-}" = "--message-file" ]; then
  [ $# -ge 3 ] && [ -f "$2" ] || { echo "missing message file or revision range"; exit 2; }
  message_file=$2; shift 2
fi
[ $# -gt 0 ] || { echo "usage: leak-check.sh <repo-root> <rev-range...>"; exit 2; }
git -C "$repo" rev-parse -q --verify HEAD >/dev/null || { echo "not a repo: $repo"; exit 2; }

pat=$(mktemp); trap 'rm -f "$pat"' EXIT

allow="$HOME/.t3/leak-allow.txt"
allowed() { [ -f "$allow" ] && grep -qxF -- "$1" "$allow"; }

# 1. Secret values from untracked .env files (secret-looking keys, values of
# 8+ chars), minus values that also sit in a committed example file.
examples=$(git -C "$repo" ls-files | grep -E '(^|/)\.env[^/]*$' || true)
git -C "$repo" ls-files -oi --exclude-standard --directory | grep -E '(^|/)\.env[^/]*$' |
while IFS= read -r f; do
  [ -f "$repo/$f" ] || continue
  sed -nE 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$/\2\t\3/p' "$repo/$f" |
  while IFS=$'\t' read -r key val; do
    echo "$key" | grep -qiE 'KEY|SECRET|TOKEN|PASS|DATABASE_URL|DSN' || continue
    val=${val%$'\r'}
    case "$val" in
      \"*) val=${val#\"}; val=${val%%\"*} ;;
      \'*) val=${val#\'}; val=${val%%\'*} ;;
      *) val=${val%%[[:space:]]#*}; val=${val%"${val##*[![:space:]]}"} ;;
    esac
    [ ${#val} -ge 8 ] || continue
    allowed "$val" && continue
    if [ -n "$examples" ] && (cd "$repo" && grep -qF -- "$val" $examples 2>/dev/null); then continue; fi
    printf '%s %s\t%s\n' "$f" "$key" "$val"
  done
done >> "$pat"

# 2. Machine names from machines.md (section labels, SSH targets, Tailscale
# names, and a "Private names:" line), matched in any case.
m="$HOME/.t3/machines.md"
if [ -f "$m" ]; then
  { grep -oE '`[^`@ ]+@[^` ]+`' "$m" | tr -d '`' | sed 's/.*@//'
    grep -ioE 'tailscale name: `[^`]+`' "$m" | sed -E 's/.*`([^`]+)`/\1/'
    grep -E '^## ' "$m" | sed 's/^## //'
    grep -iE '^- private names:' "$m" | grep -oE '`[^`]+`' | tr -d '`'
  } | tr -d '\r' | sort -u | while IFS= read -r h; do
    [ ${#h} -ge 4 ] && ! allowed "$h" && printf 'machine name\t%s\n' "$h"
  done >> "$pat"
fi

# 3. Extra private patterns, one per line.
p="$HOME/.t3/leak-patterns.txt"
[ -f "$p" ] && grep -v '^[[:space:]]*\(#\|$\)' "$p" | while IFS= read -r x; do
  printf 'pattern\t%s\n' "${x%$'\r'}"
done >> "$pat"

# 4. Client repos (no tools.json in main checkout or its parent): tracker names,
# personal skill names and local/<branch> sync refs stay out of commits. The
# tracker name is matched with its capital letter, so an Italian word such as
# "traccia" in prose is not a hit.
common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo "$repo/.git")
main=$(dirname "$common")
client_repo=0
if [ ! -f "$main/tools.json" ] && [ ! -f "$(dirname "$main")/tools.json" ]; then
  client_repo=1
  printf 'tracker name\tTraccia\n'
  for s in "/tracer" "sub-tracer" "subtracer" "mattpocock-skills" "superpowers:" "unslop" "grill-with-docs" "to-tickets" "to-spec" "close-the-day"; do
    allowed "$s" || printf 'client-repo rule (%s)\t%s\n' "$s" "$s"
  done
  printf 'client-repo regex (local/<branch>)\t(^|[^A-Za-z0-9_./-])local/[A-Za-z0-9]\n'
  printf 'client-repo regex (refs/heads/local/)\trefs/heads/local/\n'
fi >> "$pat"
proj_keys=$(git -C "$repo" config --get tracer.projectKeys || true)
if [ "$client_repo" = 1 ]; then
  [ -n "$proj_keys" ] || { echo "configure tracer.projectKeys with the tracker project prefixes before scanning a client repo"; exit 2; }
  [[ "$proj_keys" =~ [A-Za-z] ]] || { echo "empty tracer.projectKeys prefixes"; exit 2; }
  for key in $proj_keys; do
    [[ "$key" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] || { echo "invalid tracer.projectKeys prefix"; exit 2; }
  done
fi
# Validate ranges first: a failed git log must never turn into a clean scan.
git -C "$repo" rev-list "$@" >/dev/null || exit 2

n=$(wc -l < "$pat")
[ "$n" -gt 0 ] || echo "warning: no patterns found (no .env values, machines.md or leak-patterns.txt)"

hits=$(
  { git -C "$repo" log -p --diff-merges=first-parent --no-color --no-ext-diff --format='commit %H' "$@" || exit 2
    git -C "$repo" log --format='commit %H%nmessage%n%B' "$@" | sed '/^commit /!{/^message$/!s/^/+/}' || exit 2
    if [ -n "$message_file" ]; then
      printf 'commit pending\nmessage\n'
      sed 's/^/+/' "$message_file" || exit 2
    fi
  } | awk -F'\t' -v pf="$pat" -v keys="$proj_keys" -v client="$client_repo" '
    BEGIN {
      while ((getline l < pf) > 0) { i = index(l, "\t"); lab[++k] = substr(l, 1, i-1); val[k] = substr(l, i+1) }
      nk = split(keys, ka, /[[:space:]]+/)
    }
    /^commit / { c = substr($0, 8, 12); f = "?"; next }
    /^message$/ { f = "commit message"; next }
    /^\+\+\+ / { f = substr($0, 7); next }
    /^\+/ { lo = tolower($0)
            for (j = 1; j <= k; j++) {
              if (index(lab[j], "client-repo regex") == 1) hit = match(lo, val[j])
              else if (lab[j] == "machine name" || index(lab[j], "client-repo rule") == 1) hit = index(lo, tolower(val[j]))
              else hit = index($0, val[j])
              if (hit) print c "  " f "  (" lab[j] ")"
            }
            if (client) {
              for (m = 1; m <= nk; m++) {
                if (ka[m] != "" && match($0, "(^|[^A-Za-z0-9_])" ka[m] "-[0-9]+([^A-Za-z0-9_]|$)"))
                  print c "  " f "  (issue key " ka[m] "-NNN)"
              }
            } }
  ' | sort -u
) || { echo 'leak scan failed; nothing was verified'; exit 2; }

commits=$(git -C "$repo" rev-list --count "$@" 2>/dev/null || echo "?")
if [ -n "$hits" ]; then
  echo "LEAK CHECK FAILED ($commits commits, $n patterns):"
  echo "$hits"
  exit 1
fi
echo "leak check clean: $commits commits, $n patterns"
