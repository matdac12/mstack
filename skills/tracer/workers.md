# Workers: models, briefs, pitfalls

## Models

Only these four. Another model only when Mattia names it.

| Worker | `modelSelection` | Use for |
| --- | --- | --- |
| Claude Sonnet 5.5 | `{"instanceId":"claudeAgent","provider":"claudeAgent","model":"claude-sonnet-5-5","options":[{"id":"effort","value":"medium"}]}` | Implementation, execute-a-plan, fixes, refactors. The default. |
| Claude Opus 5.5 | `{"instanceId":"claudeAgent","provider":"claudeAgent","model":"claude-opus-5-5","options":[{"id":"effort","value":"high"}]}` | Design, hard refactors, anything Sonnet struggled with. |
| GPT 6.1 Sol | `{"instanceId":"codex","provider":"codex","model":"gpt-6.1-sol","options":[{"id":"reasoningEffort","value":"medium"},{"id":"serviceTier","value":"default"}]}` | **The review model**: second-model reviews (kinds.md, Review), with `reasoningEffort` set by risk there. Otherwise short tasks only: Mattia's limits there are tight. `serviceTier` is always `default`. When he moves to a newer OpenAI model, only this row changes. |
| DeepSeek 4.1 Flash | `{"instanceId":"opencode","provider":"opencode","model":"opencode-go/deepseek-v4.1-flash","options":[{"id":"variant","value":"high"}]}` | Guide, tests, docs. The only OpenCode model. |

Check a model's option ids in the capabilities file from preflight (`jq '.providers[]|select(.providerInstanceId=="<id>")|.models[]|select(.id=="<model>")|.options'`). Claude models take only `effort` (no `contextWindow`).

**Choosing:**
- **At his desk:** before the first spawn, propose a model per task with a one-line reason and wait for his pick. A model he names for a kind of task ("Sonnet for implementation") holds for the session: record it as a tracker comment and do not re-ask until a different kind of task comes up. A model named for one issue covers that issue only, and "like the last one" is not his choice.
- **Away mode:** you choose, Claude only: Sonnet, Opus for hard work.
- **Design or Guide** threads are his: always ask.
- `t3_thread_configure` changes a running thread's model, only when he asks.

Co-Authored-By trailer matches the model: `Claude Sonnet 5.5 <noreply@anthropic.com>`, `DeepSeek <noreply@opencode.ai>`; for others use the model's name.

## Tools

- A thread Mattia sees: `t3_thread_launch` (`runtimeMode: "full-access"`). Quick child work you consume yourself: `Agent` or `delegate_task`. No retry key on launch: after an error, check `t3_thread_list` before retrying.
- Talk: `t3_thread_send`, mode chosen per message (Talking to a worker).
- Read: `t3_thread_read` with `view:"messages"`, `limit` about 5, `maxCharsPerItem` about 1500. The `activity` view only to diagnose a stuck worker, with a small limit.
- List: `t3_thread_list` filtered (`titleContains`, `statuses`, `settled:false`); `includeSubagents` only when settling or checking a worker that looks done.
- Big tracker issues: read recent comments with a limit, not the whole issue.
- Your thread id: `parentThreadId` from preflight.

## Talking to a worker

A worker's turn often runs 10 to 20 minutes, often the whole task, and a `queue` message waits for that turn to end: it can land after the worker has already reported. Before each send to a running worker, read its last messages and weigh them against this chat, then ask: **would this message lose value by arriving only after the current turn?**

- **Yes: `steer`.** It reaches the running turn at its next step. Corrections to the approach, a changed or clarified requirement, an answer it is waiting on or working around, a `<defaultBranch>` move near its files, a machine-lock grant or release, a stop. Anything Mattia just asked to change is urgent for the worker it touches.
- **No: `queue`.** It belongs after the current turn: a follow-up task, a nudge to a worker already writing its report.
- **Unsure: `steer`.** Put the timing in the words ("when your current step is committed, rebase…"); arriving early costs nothing, arriving late costs the work in between.
- **Idle worker:** `auto` starts it.
- `restart` only when Mattia asks.

A queued message that turns urgent: find it with `t3_queue_list`, then `t3_queue_promote_to_steer`.

## Heartbeat

One safety net for a worker that forgets to report or stops moving. With the first worker launched, create a single `schedule_task`: `schedule {"type":"interval","everyMs":1800000}`, bound to this thread (the default), prompt "Tracer heartbeat: check unreported workers (workers.md, Heartbeat)". First `list_scheduled_tasks`: if a heartbeat bound to this thread already exists (after a compaction you no longer know its id), reuse it. Keep its id. Delete it (`delete_scheduled_task`) when no worker is active, and create it again with the next launch. One heartbeat, never one per worker, and no `sleep` timers: per-worker timers keep firing after the work is done.

At each launch, note on the work map when you expect the report (about N minutes).

Each run, for every worker you launched that has no recorded report:
- **Running, within its estimate:** nothing.
- **Running, past twice its estimate:** read its last messages and activity first. Quiet since the last run: also check `git -C <worktree> log -1 --format=%cr` and `git -C <worktree> status --porcelain` (over SSH for a remote worker, remote.md). Moving by either: nothing. Not moving: tell Mattia what you see (away mode: SKILL.md, stuck).
- **Idle, and its last message has the report fields:** that is its report; record it.
- **Idle without a report:** check `includeSubagents` (its review subagents may still be running); if nothing runs, ask it once for the report with `t3_thread_send`.
- **Waiting on a request** (`t3_pending_request_list`): tell Mattia.

Nothing to do: end the turn in one line, without messaging Mattia.

**A worker that died or failed** gets a fresh thread in the same worktree, picked by cause: context limit → a smaller scope (split the task, or a handoff of what is done); tool or provider error → another model; unknown → the same brief once. At his desk, propose the relaunch to Mattia; in away mode, do it. Two failed relaunches: stop, tell him, and replan the task.

## Worktree seeding (first thread of a task)

Gitignored files do not come with a worktree. If the project has a `.mcp.json`, copy `<repo root>/.claude/settings.local.json` into the worktree's `.claude/` (`mkdir -p` first; a failing `cp` is a stop-and-report), or write `{"enableAllProjectMcpServers": true}` if the source is missing; otherwise the worker stalls on "New MCP servers found". A worktree whose path casing differs from the repo's stalls on "Do you trust the files in this folder?". A stalled worker cannot report that: shortly after launch, `t3_thread_read` it and `t3_pending_request_list`; if stuck, tell Mattia (he accepts trust prompts). The worker's first act: `git rev-parse --path-format=absolute --git-common-dir` must print `<repo root>/.git`, else report blocked "wrong repo". If a worker says its tracker MCP is missing in the worktree, tell Mattia; it must not fall back to the other tracker.

## Dependencies (first thread of a task)

Installed dependencies are gitignored too, and a fresh install in every worktree repeats identical work. Project-agnostic rule: the worker reuses the main checkout's install instead of reinstalling from scratch, and does so only when it is provably the same.

- **Same lockfile:** the worktree's committed lockfile (whatever the ecosystem uses) has no diff against the main checkout's (`git diff --quiet <defaultBranch> -- <lockfile>` and no uncommitted change to it in main), and main has the installed directory (`node_modules`, `vendor`, ...).
- **Location-independent directory** (`node_modules`, `vendor`, `Pods`): copy it from main with a fast bulk copy (`MSYS_NO_PATHCONV=1 robocopy ... /E /MT:16` on Windows, `cp -a` elsewhere; never a junction or symlink, a shared directory lets one worker corrupt main and the others). Then run the project's own offline or frozen verify (`npm ls`, `composer validate`, ...) and fall back to the normal install if it fails.
- **Location-bound directory** (Python `.venv`, `target`, anything with absolute paths baked in): do not copy. Run the normal install, with the tool's cache and offline flags (`--prefer-offline`, `uv sync`, ...), so the download is already skipped.
- Lockfile differs, main has no install, or the ecosystem is unfamiliar: the normal install, once, with its cache flags.
- The worker states in its report which path it took. Later threads of the task reuse the worktree and install nothing unless the lockfile changed.

## Windows / Git Bash (you and the workers)

- `git -C <repo>` instead of `cd` in compound commands: a `cd` moves the session's working directory.
- `robocopy` from Git Bash: prefix `MSYS_NO_PATHCONV=1`, or `/E` is mangled (exit 16).
- PowerShell from bash: wrap the command in single quotes so bash does not expand `$env:...`; build paths with `Join-Path $env:APPDATA ...`.
- **Wildcards:** `settings.json.*` also matches `settings.json` (a trailing `.*` matches an empty extension). That deleted a live settings file with API keys. List the exact matches before deleting, or name each file.
- **A running app locks its exe:** a release build into the same target dir fails at the final copy ("Access denied, os error 5"), and `| tail` can hide it. Stop the app, build, restart it, check the exe timestamp.
- A denied `rm` or a blocked command: do not retry the same thing; ask Mattia.

## Shared machine

Workers share Mattia's laptop, often while he is using it.
- **One lock**, handed out by you to one worker at a time: timed runs, anything that stops, swaps or drives his apps, GUI tests. Grant it by message; the worker waits for your message instead of polling. While a timed run holds it, launch no build worker and run no build yourself. The project's AGENTS.md may name a lock file.
- Workers stop only processes they started, by PID or process tree (`taskkill /T /PID <pid>`); never by image name (`node`, `cargo`).
- Synthetic keystrokes and clicks go only to the test app's own window, never to whatever has focus.
- With other workers active, throttle test runners (`--maxWorkers=4` for vitest or jest).
- Swapping his running app: check which exe runs before stopping it; back up its settings and restore them byte-identical; restart his normal app from its usual shortcut; report the final machine state truthfully.
- **Away mode** (SKILL.md) frees the machine for the work: full CPU, parallel builds, stopping and restarting his apps without asking, GUI tests with real input. The lock for timed runs, own-process kills and the settings restore still hold.

## Brief

Small, clear task: this brief as the launch message. Big task: write a handoff document (handoff.md) containing it and send only the short pointer; the Rules and Report back blocks go in either way. A user-only skill (kinds.md) goes as the first line of the launch message, before the brief or the pointer.

```
Do <ISSUE-ID> in the <project> repo (this worktree, branch `<issue-id>-slug`, based on the local <defaultBranch>).

## The issue
<title, expected result, constraints>
Mattia's words: "<verbatim, when the issue comes from his feedback or a hand check>"
Owns: <files you may change>. Do NOT touch: <files owned by another worker, and who>.
Skill: <the implementing skill from kinds.md, plus any domain skill; required for any thread that writes code>
Private project notes: <paths, if the project has them; read them first>.
Scale: <the project's scale from its private notes; keep it out of every file you commit>
Repo: <personal | client>
Preview: <when one with data is running: its link and a login (never commit them). Check your change there with agent-browser, and say in your report whether you checked real or fake data.>

## Rules
- Build the simplest thing that works at this scale: the option that changes the least code, following your skill. Handle the cases this scale really meets. If the simple version falls short, say why in your report before building more.
- Client repo: everything you commit (code, comments, docs, commit messages) carries no issue keys and no tracker names; describe the change itself. The orchestrator links your commit on the tracker.
- Read AGENTS.md / CLAUDE.md first. Issues live in <Linear|Traccia> (Traccia: call whoami first); do not write to the other tracker. Set <ISSUE-ID> In Progress when you start, with a short comment; the orchestrator sets every later status.
- First thing, install dependencies as in "Dependencies" above (reuse main's install when the lockfile is identical; do not run a full fresh install by reflex).
- Before editing code, load the brief's `Skill:` and follow it; if it is unavailable, stop and report blocked.
- If a guard hook rejects a command, stop and report the exact command. Do not reach the same effect another way (`git switch -C` after a blocked `reset --hard`).
- Add or update tests. Before reporting, run the project's full fast check (the whole unit suite, not only the tests for your files) and any e2e the change touches; report real output, failures included. Run builds and tests in the foreground: end your turn with no background job running.
- Update README and docs for any user-visible change.
- Stay local: commit on your branch (message mentions <ISSUE-ID> in a personal repo, and always ends `Co-Authored-By: <model> <email>`), leave the worktree clean, do not push, open a PR, merge or publish. When the orchestrator tells you `<defaultBranch>` moved, rebase onto it after your current step, rerun checks and report; if the rebase conflicts, abort it and report. No tracker MCP or skill available? Say so in your report.
- Shared machine: stop only processes you started; take the machine lock from the orchestrator for timed runs, app swaps and GUI tests. Away mode: <on | off>.
- Say what Mattia should check by eye if you cannot see the running app.
- On Windows, never delete with a wildcard before listing its exact matches.

## Report back (mandatory, your last act)
When done or blocked, send this with `t3_thread_send` to thread <ORCHESTRATOR_THREAD_ID>, mode `queue`, as your final message:

REPORT <ISSUE-ID>
- Status: done | blocked (why)
- Branch: <branch> @ <commit SHA>; worktree clean: yes | no
- Changed: <what, in a few lines>
- Skill used: <name> | none (why)
- Checks: <command> → <exit code>; failures named
- Red first (fix or test-first work): <test> failed with <message> before the change | why not
- Dependencies: <which install path you took>
- Hand check for Mattia: <numbered steps, or "none">
- Decided alone (he may veto): <list or "none">
- Not verified: <list or "none">
- Findings not fixed: <file, why, size>
- For Mattia to decide: <list or "none">
```
