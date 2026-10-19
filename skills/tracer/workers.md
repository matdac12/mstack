# Workers: models, briefs, pitfalls

## Models

Mattia picks, **and you always ask before the first spawn** (see Confirm the model). Never launch on a default he has not confirmed. Claude models take only an `effort` option in T3 (no `contextWindow`; do not send one). Check the model's options with the `jq` below. For a **Design or Guide** thread always ask him, it is his thread. For any other model find the exact ids with `jq` on the file named in the `orchestrator_capabilities` result (it is huge; never read it whole): e.g. `jq -r '.providers[]|select(.driverKind=="claudeAgent")|.models[].id'`, `.models[]|select(.id=="<id>")|.options` for effort. His choice overrides the "use for" column. `t3_thread_configure` changes a running thread's model, only when he asks.

| Worker | `modelSelection` | Default for |
| --- | --- | --- |
| DeepSeek 4.1 Flash | `{"instanceId":"opencode","provider":"opencode","model":"opencode-go/deepseek-v4.1-flash"}` | Guide, tests, docs. Not `deepseek-v4-pro` unless asked. |
| Claude Sonnet 5.5 | `{"instanceId":"claudeAgent","provider":"claudeAgent","model":"claude-sonnet-5-5","options":[{"id":"effort","value":"medium"}]}` | Implementation, execute-a-plan, fixes, refactors, review passes. |
| Claude Opus 5.5 | `{"instanceId":"claudeAgent","provider":"claudeAgent","model":"claude-opus-5-5","options":[{"id":"effort","value":"high"}]}` | Hard design, tricky refactors, anything Sonnet struggled with. |

## Confirm the model (before the first spawn, and whenever the next worker could differ)

Ask Mattia in one short question which model runs the worker(s): **Sonnet 5.5** or **Opus 5.5** (or another he names), with your recommendation for the kind of task. Wait for the answer; do not spawn first. His answer covers the workers of that batch; ask again if he changes the plan or a different kind of task comes up.

Co-Authored-By trailer matches the model: `Claude Sonnet 5.5 <noreply@anthropic.com>`, `DeepSeek <noreply@opencode.ai>`; for others use the model's name.

## Tools

- A thread Mattia sees: `t3_thread_launch` (`runtimeMode: "full-access"`). Quick child work you consume yourself: `Agent` or `delegate_task`.
- Talk: `t3_thread_send` (`queue` for a follow-up after the current turn, `auto` steers); read `t3_thread_read`; wait `t3_thread_wait`. No retry key on launch: after an error, check `t3_thread_list` before retrying.
- Your thread id: `jq -r .parentThreadId` on the capabilities result.

## Worktree seeding (first thread of a task)

Gitignored files do not come with a worktree. If the project has a `.mcp.json`, copy `<repo root>/.claude/settings.local.json` into the worktree's `.claude/` (`mkdir -p` first; a failing `cp` is a stop-and-report), or write `{"enableAllProjectMcpServers": true}` if the source is missing; otherwise the worker stalls on "New MCP servers found". A worktree whose path casing differs from the repo's stalls on "Do you trust the files in this folder?". A stalled worker cannot report that: shortly after launch, `t3_thread_read` it and `t3_pending_request_list`; if stuck, tell Mattia (he accepts trust prompts). The worker's first act: `git rev-parse --path-format=absolute --git-common-dir` must print `<repo root>/.git`, else report blocked "wrong repo". If a worker says its tracker MCP is missing in the worktree, tell Mattia; it must not fall back to the other tracker.

## Dependencies (first thread of a task)

Installed dependencies are gitignored too, and a fresh install in every worktree repeats identical work. Project-agnostic rule: the worker reuses the main checkout's install instead of reinstalling from scratch, and does so only when it is provably the same.

- **Same lockfile:** the worktree's committed lockfile (whatever the ecosystem uses) has no diff against the main checkout's (`git diff --quiet <defaultBranch> -- <lockfile>` and no uncommitted change to it in main), and main has the installed directory (`node_modules`, `vendor`, ...).
- **Location-independent directory** (`node_modules`, `vendor`, `Pods`): copy it from main with a fast bulk copy (`MSYS_NO_PATHCONV=1 robocopy ... /E /MT:16` on Windows, `cp -a` elsewhere; never a junction or symlink, a shared directory lets one worker corrupt main and the others). Then run the project's own offline or frozen verify (`npm ls`, `composer validate`, ...) and fall back to the normal install if it fails.
- **Location-bound directory** (Python `.venv`, `target`, anything with absolute paths baked in): do not copy. Run the normal install, with the tool's cache and offline flags (`--prefer-offline`, `uv sync`, ...), so the download is already skipped.
- Lockfile differs, main has no install, or the ecosystem is unfamiliar: the normal install, once, with its cache flags.
- The worker states in its report which path it took. Later threads of the task reuse the worktree and install nothing unless the lockfile changed.

## Windows / Git Bash

- `robocopy` from Git Bash: prefix `MSYS_NO_PATHCONV=1`, or `/E` is mangled (exit 16).
- PowerShell from bash: wrap the command in single quotes so bash does not expand `$env:...`; build paths with `Join-Path $env:APPDATA ...`.
- **Wildcards:** `settings.json.*` also matches `settings.json` (a trailing `.*` matches an empty extension). That deleted a live settings file with API keys. List the exact matches before deleting, or name each file.
- **A running app locks its exe:** a release build into the same target dir fails at the final copy ("Access denied, os error 5"), and `| tail` can hide it. Stop the app, build, restart it, check the exe timestamp.
- A worktree folder that will not delete is usually held by leftover dev servers (vite, esbuild, node). Find them with `Get-CimInstance Win32_Process` filtered on the path in `ExecutablePath`/`CommandLine`, stop those, then delete. Never kill `claude.exe` sessions.
- A denied `rm` or a blocked command: do not retry the same thing; ask Mattia.

## Workers that swap his running app

When a worker tests a build in place of the app Mattia uses daily, put this in its brief:
- Before stopping the app, check which exe is running.
- Back up the app's settings first, restore them byte-identical afterwards, and restart his normal app from its usual shortcut.
- Report the final machine state truthfully.
- Several workers may do this at once: tell each about the others, or hand out one lock (subtracer.md).

## Brief

Small, clear task: this brief as the launch message. Big task: write a handoff document (handoff.md) containing it and send only the short pointer; the Rules and Report back blocks go in either way.

```
Do <ISSUE-ID> in the <project> repo (this worktree, branch `<issue-id>-slug`, based on the local <defaultBranch>).

## The issue
<title, expected result, constraints>
Owns: <files you may change>. Do NOT touch: <files owned by another worker, and who>.

## Rules
- Read AGENTS.md / CLAUDE.md first. Issues live in <Linear|Traccia> (Traccia: call whoami first); do not write to the other tracker. Set <ISSUE-ID> In Progress when you start, with a short comment; the orchestrator sets every later status.
- First thing, install dependencies as in "Dependencies" above (reuse main's install when the lockfile is identical; do not run a full fresh install by reflex).
- Add or update tests; run the project's check command and any e2e the change touches; report real output, failures included.
- Stay local: commit on your branch (message mentions <ISSUE-ID> and ends `Co-Authored-By: <model> <email>`), leave the worktree clean, do not push, open a PR, merge or publish. When the orchestrator tells you `<defaultBranch>` moved, rebase onto it after your current step, rerun checks and report; if the rebase conflicts, abort it and report. No tracker MCP or skill available? Say so in your report.
- Say what Mattia should check by eye if you cannot see the running app.
- On Windows, never delete with a wildcard before listing its exact matches.

## Report back (mandatory)
To the orchestrator, thread <ORCHESTRATOR_THREAD_ID>: what changed, branch and last commit SHA, that the worktree is clean, decisions you took alone (so he can veto), test results, what you did NOT verify, findings you did not fix (file, why, size), anything for Mattia to decide. Also send a 5-line summary with `t3_thread_send`.
```
