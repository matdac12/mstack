#!/usr/bin/env bash
# Run with Git Bash or Linux bash; uses disposable repositories and no network.
set -euo pipefail
scripts=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
mkdir -p "$tmp/home" "$tmp/bin"
export HOME="$tmp/home"
failures=0
check() { if "$@"; then echo "PASS: $*"; else echo "FAIL: $*"; failures=$((failures+1)); fi; }
reject() { if "$@" >"$tmp/output" 2>&1; then return 1; fi; }
git init -q -b main "$tmp/repo"
repo=$(cd "$tmp/repo" && pwd)
git -C "$repo" config core.hooksPath /dev/null
git -C "$repo" commit -q --allow-empty -m initial
git -C "$repo" switch -q -c feature
git -C "$repo" commit -q --allow-empty -m feature
sha=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" switch -q main
git -C "$repo" config tracer.projectKeys TEST
for message in 'Merge local/private-helper' 'Merge TEST-12' 'Merge Traccia'; do
 printf '%s\n' "$message" > "$tmp/message"
 check reject bash "$scripts/land.sh" merge "$repo" feature "$sha" "$tmp/message"
done
printf 'Merge feature\n' > "$tmp/message"
check bash "$scripts/land.sh" merge "$repo" feature "$sha" "$tmp/message"
git -C "$repo" config --unset tracer.projectKeys
check reject bash "$scripts/leak-check.sh" "$repo" main..feature
git -C "$repo" config tracer.projectKeys TEST
check reject bash "$scripts/leak-check.sh" "$repo" missing..main
git -C "$repo" switch -q -c preview
git -C "$repo" branch merge-input
git -C "$repo" commit -q --allow-empty -m 'preview base'
base=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" switch -q merge-input
git -C "$repo" commit -q --allow-empty -m 'clean input'
git -C "$repo" branch clean-input
git -C "$repo" merge -q --no-ff --no-commit preview
printf 'TEST-123\n' > "$repo/merge-only.txt"
git -C "$repo" add merge-only.txt
git -C "$repo" commit -q -m 'merge with an extra edit'
sha=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" switch -q preview
check reject bash "$scripts/leak-check.sh" "$repo" preview..merge-input
check grep -q '(issue key TEST-NNN)' "$tmp/output"
check reject env TRACER_DEFAULT=preview bash "$scripts/land.sh" merge "$repo" merge-input "$sha" "$tmp/message"
check test "$(git -C "$repo" rev-parse HEAD)" = "$base"
clean_sha=$(git -C "$repo" rev-parse clean-input)
check bash "$scripts/leak-check.sh" "$repo" preview..clean-input
check env TRACER_DEFAULT=preview bash "$scripts/land.sh" merge "$repo" clean-input "$clean_sha" "$tmp/message"
check test "$(git -C "$repo" rev-parse HEAD^2)" = "$clean_sha"
git -C "$repo" switch -q main
cat > "$tmp/bin/ssh" <<'SH'
#!/usr/bin/env bash
shift
exec bash -c "$*"
SH
chmod +x "$tmp/bin/ssh"
export PATH="$tmp/bin:$PATH"
git -C "$repo" branch local/active
git -C "$repo" worktree add -q "$tmp/active" local/active
check reject bash "$scripts/land.sh" drop-remote-ref "$repo" test "$repo" local/active main
check git -C "$tmp/active" rev-parse --verify HEAD
check reject bash "$scripts/land.sh" drop-remote-ref "$repo" test "$repo" main main
git -C "$repo" branch local/merged
check bash "$scripts/land.sh" drop-remote-ref "$repo" test "$repo" local/merged main
check reject git -C "$repo" show-ref --verify refs/heads/local/merged
git -C "$repo" branch local/unmerged feature
git -C "$repo" -c core.hooksPath=/dev/null commit -q --allow-empty -m later
git -C "$repo" branch -f local/unmerged HEAD
check reject bash "$scripts/land.sh" drop-remote-ref "$repo" test "$repo" local/unmerged feature
# Simulate another actor advancing the helper after validation, before deletion.
export REAL_GIT=$(command -v git)
export ADVANCED_TIP=$(git -C "$repo" rev-parse local/unmerged)
cat > "$tmp/bin/git" <<'SH'
#!/usr/bin/env bash
if [ "${RACE_REF:-}" != "" ] && [ "${3:-}" = update-ref ] && [ "${4:-}" = -d ]; then
  "$REAL_GIT" -C "$2" update-ref "$RACE_REF" "$ADVANCED_TIP"
fi
exec "$REAL_GIT" "$@"
SH
chmod +x "$tmp/bin/git"
git -C "$repo" branch local/race feature
export RACE_REF=refs/heads/local/race
check reject bash "$scripts/land.sh" drop-remote-ref "$repo" test "$repo" local/race feature
unset RACE_REF
check git -C "$repo" merge-base --is-ancestor "$ADVANCED_TIP" local/race
printf '{}\n' > "$repo/.mcp.json"
git -C "$repo" worktree add -q "$tmp/broken" -b seed-broken feature
printf 'block\n' > "$tmp/broken/.claude"
check reject bash "$scripts/seed-worktree.sh" "$tmp/broken"
note=$(git -C "$tmp/broken" rev-parse --path-format=absolute --git-dir)/tracer-seed
check grep -q '^seed failed' "$note"
git -C "$repo" worktree add -q "$tmp/success" -b seed-success feature
check bash "$scripts/seed-worktree.sh" "$tmp/success"
note=$(git -C "$tmp/success" rev-parse --path-format=absolute --git-dir)/tracer-seed
check grep -q '^seed done' "$note"
echo "$failures failures; fixtures: $tmp"
test "$failures" -eq 0
