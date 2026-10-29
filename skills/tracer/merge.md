# Review, merge, push, settle

## Review

Read the real diff (`git diff <defaultBranch>...<branch>`, `git log`), not the report. Check the claimed tests, that changed files stay within the owned files, that the worktree is clean and committed (`git -C <path> status --porcelain`), overlap with other unmerged branches and with what merged since the branch started (`git diff --stat $(git merge-base <defaultBranch> <branch>)..<defaultBranch>`: a rename or a changed signature there breaks a branch that never touched those files), and any warning the worker raised. A branch behind `<defaultBranch>` whose files are disjoint from what merged since: merge it directly (`git merge-tree --write-tree` must show no conflict; step 4's full check does the rest). Otherwise ask the worker for a rebase first. Generated files (lockfile, migration journal and snapshots) are nobody's: the later branch regenerates them per the project's rule. Execute-a-plan work is reviewed against the plan. A worker's report of a rejected command or a workaround is never a clean review: take it to Mattia before merging or pushing.

- **Weakened checks:** scan the diff for tests skipped or deleted, assertions removed or loosened, timeouts or thresholds raised, new allowlist or lint-disable entries, checks made non-blocking. Each one goes to Mattia before merge, like a rejected command.
- **Client repo:** the commit messages (`git log --format=%B <defaultBranch>..<branch>`) and the added lines of the diff hold no issue key (`grep -E '\b<PREFIX>-[0-9]+'` for each of the tracker's project keys) and no tracker name. A hit goes back to the worker.
- **Leaks, every repo:** `bash ~/.claude/skills/tracer/scripts/leak-check.sh <repo root> <defaultBranch>..<branch>` (env values, machine names, private patterns; it prints where, never the value). Machine names mean nothing to anyone else, and on a client repo they expose Mattia's setup. A hit goes back to the worker, who removes it from the branch's history (amend or rebase its own commits), never with a fix commit on top: the push would still carry it.
- **Fix work:** run the `Red first` test on the fix's parent commit when it is cheap; it must fail.
- **Pin the review:** the tracker comment recording the review names the branch SHA you reviewed.
- **Triage the findings** (yours, the worker's `code-review`, a second model's): **act now** (back to the worker before merge), **follow-up** (the task's follow-up issue), or **dismissed** with a one-line reason. Dismiss findings about code the branch did not write, cases the types or callers already rule out, and taste ("I would have done it differently"). A review that is all nits means the code is fine. Findings two reviewers raised independently come first.

Tell Mattia in a few lines: what changed, tests, the act-now findings and how many you parked or dismissed, what to look at by eye, a recommendation.

## Merge

A yes naming the branches ("merge all three"), or a grant covering them (SKILL.md), counts once you have reviewed them and nothing alarms you; dirty main, red checks or out-of-boundary conflicts mean stop and ask. A yes to merge is never a yes to push. One branch at a time, in his order unless dependencies force another, else the larger first. Wait (`t3_thread_wait`) until the worker's thread is idle before touching its branch; never interrupt it.

1. **Preconditions, every time:** main checkout on `<defaultBranch>`, no merge or rebase in progress, and a clean tracked tree: `test -z "$(git status --porcelain --untracked-files=no)"` must succeed (untracked handoff docs are fine). Otherwise stop and ask whether to commit or stash; once he says which, do it and tell him (restoring a stash is his call). `git rev-parse <branch>` equals the SHA you reviewed; if not, review the new commits first.
2. Write the merge message to a file (`m=$(mktemp)`, then a quoted heredoc into `"$m"`, so backticks are not run; Git on Windows cannot read `-F -`). Then `bash ~/.claude/skills/tracer/scripts/land.sh merge <repo root> <branch> <reviewed SHA> "$m"`, adding `<ssh> <root> <label>` for a remote worker's branch (it fetches it into `refs/remotes/<label>/<branch>` and deletes that ref once merged). It checks step 1's preconditions and the reviewed SHA, merges `--no-ff`, and aborts on conflicts; it prints the commit to come back to. In a client repo the message describes the change, with no issue keys (SKILL.md, Hard rules).
3. **Conflicts:** `git merge --abort` first (never leave main half-merged). Then **you** resolve them in the worker's idle, clean worktree: merge `<defaultBranch>` into the branch, resolve only the conflicting hunks keeping both sides' intent, check no conflict markers remain, rerun the project's checks, commit, retry. Unclear intent, or files outside the task's boundaries: stop and ask.
4. **Verify** the merged result. Lockfile changed: install with the project's frozen command first (`npm ci`), here and, after the sync, in the linked machine's main checkout. When the full check needs that machine (Docker, a database, a heavy build), run it there in a detached scratch worktree on the synced `local/<defaultBranch>`, then remove it. Use the project's own declared commands (package.json scripts via its lockfile's manager, pytest, Makefile `test`), typecheck and lint before tests. Always the full check, never only the tests near the change: branches on disjoint files still clash (one renames what the other imports). Never invent a command; no harness means say it is unverified and ask before Done. Record command and exit code.
   - **Known-red baseline:** a check already red on a clean `<defaultBranch>` has its failing tests listed by name on a tracker issue. The merge passes locally only if it fails exactly those, no new ones. It still counts as red for push (SKILL.md: red checks need Mattia's own yes), so name the baseline failures when you ask. No home-made lenient gate scripts; the real fix is an issue in the repo.
   - **Project-declared gate:** if the project's AGENTS.md or private notes declare a gate you cannot run locally (remote CI over SSH), follow it. When it needs a pushed ref, push only a temporary `ci/<short-sha>` branch (on his yes or grant: it is a network write), merge only when the `<defaultBranch>` tree equals the tested tree, delete the `ci/` branch afterwards, and never push `<defaultBranch>` just to test it.
5. **Green:** set the issue Done, or In Review with "hand check owed" (SKILL.md, Tracker discipline), then tell the others to rebase (below). **Red** (local or the declared gate): undo only this merge with `git revert -m 1 --no-edit HEAD`, then `git commit --amend -F "$m"` with a message saying why (never `reset --hard`, and never a fix merged on top), set the issue back to In Review or blocked with a comment, tell Mattia. Never leave `<defaultBranch>` red for others to branch from. That worker gets no rebase notice: a rebase now silently drops its commits, because the reverted merge already contains them. Tell it instead: "your merge was reverted; fix on your branch and do not rebase". To merge it again, first revert the revert on `<defaultBranch>` (or the worker cherry-picks its commits onto it), and `git diff <defaultBranch>...<branch>` must not be empty. A branch reverted twice for the same check gets no third fix: write the premise both fixes shared on the issue and send an Investigate worker to test it. Still red after the revert: stop, tell him, and find the culprit among recent merges before merging more.
6. Only then the next branch.

## Integration rehearsal

Two finished branches touch the same files? Do not hand-test them one by one.
1. Detached scratch worktree, so no scratch branch needs deleting later: `git worktree add --detach ~/.t3/worktrees/<repo>/int-<ids> <defaultBranch>`, rerere on. Merge both with `--no-ff`; resolve conflicts there as in Merge step 3.
2. rerere replays conflict hunks, not semantic additions outside them (a new field a shared type also needs). Re-check the merged result compiles and passes the full checks, then build the release artifact. Prototype builds only when Mattia asks.
3. Mattia does **one** combined hand check on that build. On his yes, merge its HEAD commit into `<defaultBranch>` (`git merge --no-ff <sha>`) with a message naming the issues (client repo: naming the changes), verify as in step 4, then clean up the worktree.

## Rebase notice (after each merge verified green)

For every active worker with an unmerged branch (running or idle), except one whose merge was just reverted (step 5), `t3_thread_send`, mode per workers.md (Talking to a worker): "`<defaultBranch>` moved: `<ISSUE>` is merged. When your current step is committed, rebase onto `<defaultBranch>`, rerun your checks and report. If the rebase conflicts, abort it and report; do not resolve it." Their conflicts are yours at merge time (step 3). Launch no worker from `<defaultBranch>` until the merge is verified green. A sub-tracer gets its own wording (subtracer.md).

## Push

Merge and verify everything locally, then push on his yes or under a grant that names push; a yes to merge is never a yes to push.
1. `git fetch origin`, show `git log origin/<defaultBranch>..<defaultBranch>`.
2. **Leak check, before every push** (feature branches and `ci/` branches too), as its own command, never chained with the push: `bash ~/.claude/skills/tracer/scripts/leak-check.sh <repo root> origin/<defaultBranch>..<defaultBranch>` (a new branch: `origin/<defaultBranch>..<branch>`). Read its output. Any hit: stop and tell Mattia where; nothing is pushed until that commit is rewritten locally. Once a value is on GitHub, only a force push removes it.
3. Push once with `git push origin <defaultBranch>` (never `--force`).

Recommend CI when native or platform code changed (Rust, ...): it may be the only Linux check. Rejected or origin moved: merge or rebase locally, re-verify, show the revised set, ask again. Timeout: fetch and inspect before retrying. Feature branches you may push freely after the leak check (SKILL.md, Hard rules); no PRs unless he asks.

"Push without CI" means `[skip ci]` in the **head** commit message. Prefer an empty commit (`git commit --allow-empty -m "<IDS>: push ... [skip ci]"`; no `<IDS>` in a client repo) to amending a merge commit: amending changes SHAs that sub-tracers or workers may already have been told about.

## Settle and clean up

Automatic, without being asked, for threads you launched only (never another orchestrator's).

**Settle** a thread the moment it is no longer needed: `t3_thread_organize {"action":"settle","threadId":"<id>"}` (reversible with `unsettle`; archive only if he asks).
- Implement, fix and execute threads: once their merge is verified. One that started a preview it still owns, for a hand check: only once Mattia confirms that area of work is done, because settling it kills what he is looking at. A preview running as its own service (a systemd unit) does not hold the thread.
- Review and investigate threads: once the report is recorded.
- Design and guide threads: once the execution thread is launched from their plan, or the design is dropped. Their unmerged branch is now the execution thread's; keep the worktree until the merge.
- Cancelled or abandoned threads: right away.

Settle the thread's subagents with it: find them with one `t3_thread_list {"settled":false,"includeSubagents":true}` and settle them in parallel batches. A settle fails while the thread's turn is still running: `t3_thread_wait` it first. **Never** settle a thread that is running, has a pending request, has an unrecorded report, or owns an unmerged branch (a design thread whose branch moved on to an execution thread does not); so never a running sub-tracer or its active workers. Tell Mattia in one line what you settled.

**Clean up** each finished task's worktree yourself, in this order, as one step with the settle (a running thread or dev server locks the folder on Windows):
1. Settle its threads, and stop any dev server running from that worktree (find it with `Get-CimInstance Win32_Process` filtered on the path in `ExecutablePath` or `CommandLine`; never stop `claude.exe`).
2. `git -C <path> status --ignored`: copy out anything gitignored the report names (backups, artifacts).
3. `bash ~/.claude/skills/tracer/scripts/remove-worktree.sh <repo root> <path> <branch> <defaultBranch>`. It refuses unless the worktree is under `~/.t3/worktrees`, has no uncommitted changes and its branch is merged. New untracked `.env*` files there (a password the worker generated) are copied into that machine's main checkout first; one that differs from main's copy stops it. Copy a new one into your own main checkout too (over SSH for a remote worker), so the leak check knows its values. Then it removes the worktree, its leftover dependency folders (junctions are unlinked, never followed) and the branch. On a linked machine: `ssh <ssh> bash -s -- <root> <path> <branch> local/<defaultBranch> < ~/.claude/skills/tracer/scripts/remove-worktree.sh`; it fast-forwards that checkout's `<defaultBranch>` first, so `branch -d` sees the merge.
4. A refusal: tell Mattia its one line and leave that worktree. Never delete another way. Remove a merged branch on origin only with his OK; a guard hook that blocks `git branch -D` stays blocked even after it: give him the exact command.

## Deploy

Only when Mattia asks for it explicitly (a grant never covers it), with the project's documented procedure, from the clean main checkout; long steps in the background. Verify health and report the version.
