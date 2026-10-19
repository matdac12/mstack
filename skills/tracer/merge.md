# Review, merge, push, settle

## Review

Read the real diff (`git diff <defaultBranch>...<branch>`, `git log`), not the report. Check the claimed tests, that changed files stay within the owned files, that the worktree is clean and committed (`git -C <path> status --porcelain`), overlap with other unmerged branches, and any warning the worker raised. Execute-a-plan work is reviewed against the plan. Tell Mattia in a few lines: what changed, tests, caveats, what to look at by eye, a recommendation.

## Merge

A yes naming the branches ("merge all three") counts once you have reviewed them and nothing alarms you; dirty main, red checks or out-of-boundary conflicts mean stop and ask. A yes to merge is never a yes to push. One branch at a time, in his order unless dependencies force another, else the larger first. Wait (`t3_thread_wait`) until the worker's thread is idle before touching its branch; never interrupt it.

1. **Preconditions, every time:** main checkout on `<defaultBranch>`, no merge or rebase in progress, `git status --porcelain --untracked-files=no` empty (untracked handoff docs are fine). Otherwise ask whether to commit or stash; once he says which, do it and tell him (restoring a stash is his call).
2. Note `git rev-parse <defaultBranch>`, then `git merge --no-ff <branch>`.
3. **Conflicts:** `git merge --abort` first (never leave main half-merged). Then **you** resolve them in the worker's idle, clean worktree: merge `<defaultBranch>` into the branch, resolve only the conflicting hunks keeping both sides' intent, rerun the project's checks, commit, retry. Unclear intent, or files outside the task's boundaries: stop and ask.
4. **Verify** the merged result with the project's own declared commands (package.json scripts via its lockfile's manager, pytest, Makefile `test`), typecheck and lint before tests. Never invent a command; no harness means say it is unverified and ask before Done. Record command and exit code.
5. **Green:** set the issue Done, then tell the others to rebase (below). **Red:** undo only this merge with `git revert -m 1 HEAD` (never `reset --hard` or other workarounds), set the issue back to In Review or blocked with a comment, tell Mattia. Never leave `<defaultBranch>` red for others to branch from. To merge a reverted branch again, first revert the revert. Still red after the revert: stop, tell him, and find the culprit among recent merges before merging more.
6. Only then the next branch.

## Integration rehearsal

Two finished branches touch the same files? Do not hand-test them one by one.
1. Scratch worktree `int-<ids>` from `<defaultBranch>` (`git worktree add <path> -b int-<ids> <defaultBranch>`), rerere on. Merge both with `--no-ff`; resolve conflicts there as in Merge step 3.
2. rerere replays conflict hunks, not semantic additions outside them (a new field a shared type also needs). Re-check the merged result compiles and passes the full checks, then build the release artifact.
3. Mattia does **one** combined hand check on that build. On his yes, merge `int-<ids>` into `<defaultBranch>` with a proper message naming the issues, verify as in step 4, then clean up the worktree and branches.

## Rebase notice (after each merge verified green)

For every active worker with an unmerged branch (running or idle), `t3_thread_send` with mode `queue` (lands after their current turn): "`<defaultBranch>` moved: `<ISSUE>` is merged. When your current step is committed, rebase onto `<defaultBranch>`, rerun your checks and report. If the rebase conflicts, abort it and report; do not resolve it." Their conflicts are yours at merge time (step 3). Launch no worker from `<defaultBranch>` until the merge is verified green. A sub-tracer gets its own wording (subtracer.md).

## Push

Merge and verify everything locally, then **ask**, separately: a yes to merge is never a yes to push. `git fetch origin`, show `git log origin/<defaultBranch>..<defaultBranch>`, push once with `git push origin <defaultBranch>` (never `--force`). Recommend CI when native or platform code changed (Rust, ...): it may be the only Linux check. Rejected or origin moved: merge or rebase locally, re-verify, show the revised set, ask again. Timeout: fetch and inspect before retrying. Nothing else goes to the network (no feature branches, no PRs) unless he asks for a PR.

"Push without CI" means `[skip ci]` in the **head** commit message. Prefer an empty commit (`git commit --allow-empty -m "<IDS>: push ... [skip ci]"`) to amending a merge commit: amending changes SHAs that sub-tracers or workers may already have been told about.

## Clean up and settle

After the whole task is merged and verified, in the same step as the tracker update:
- **Worktree:** `git worktree remove <path>` (no `--force`), then `git branch -d <branch>`. Remove a merged remote branch only with Mattia's OK, and never a branch that did not merge (old experiments) without asking. Uncommitted changes: leave it and tell Mattia. Directory in use (a parked thread; normal on Windows): settle the threads, retry once, then look for leftover dev servers (workers.md, Windows), else tell him the folder is a leftover to delete after the thread is closed. A guard hook that blocks `git branch -D` stays blocked even after his OK: give him the exact PowerShell to run.
- **Settle threads** so they leave his sidebar: `t3_thread_organize {"action":"settle","threadId":"<id>"}` (reversible with `unsettle`; archive only if he asks), and tell him which. `t3_thread_list` with `settled:false` also returns idle **subagent** threads (review subagents a worker spawned): after a merge settle the finished workers and their subagents together, in parallel batches. Implement, fix and execute threads: when the task is merged, verified and Done. Design and guide threads: once the execution thread is launched from their plan (or the design is dropped). Review and investigate threads: once the report is recorded and acted on. **Never** settle a thread that is running, has a pending request, has an unrecorded report, or has an unmerged branch; so never a running sub-tracer or its active workers.

## Deploy

Only when asked, with the project's documented procedure, from the clean main checkout; long steps in the background. Verify health and report the version.
