# Workers: models, briefs, pitfalls

## Models

Only these five. Another model only when Mattia names it.

| Worker | `modelSelection` | Use for |
| --- | --- | --- |
| Claude Sonnet 5.5 | `{"instanceId":"claudeAgent","provider":"claudeAgent","model":"claude-sonnet-5-5","options":[{"id":"effort","value":"medium"}]}` | Implementation, execute-a-plan, fixes, refactors. The default. |
| Claude Opus 5.5 | `{"instanceId":"claudeAgent","provider":"claudeAgent","model":"claude-opus-5-5","options":[{"id":"effort","value":"high"}]}` | Design, hard refactors, anything Sonnet struggled with. |
| GPT 6.1 Sol | `{"instanceId":"codex","provider":"codex","model":"gpt-6.1-sol","options":[{"id":"reasoningEffort","value":"medium"},{"id":"serviceTier","value":"default"}]}` | **The review model, and nothing else**: second-model reviews (kinds.md, Review), read-only, with `reasoningEffort` set by risk there. Never code work: Mattia's OpenAI plan is small. `serviceTier` is always `default`. When he moves to a newer OpenAI model, only this row changes. |
| DeepSeek 4.1 Flash | `{"instanceId":"opencode","provider":"opencode","model":"opencode-go/deepseek-v4.1-flash","options":[{"id":"variant","value":"high"}]}` | Guide, tests, docs. The only OpenCode model. |
| Grok 4.7 | `{"instanceId":"grok","provider":"grok","model":"grok-4.7","options":[{"id":"reasoningEffort","value":"<effort>"}]}` | Any task, only when Mattia picks it. Offer it in your proposal; when he picks it, ask the effort (`low`, `medium`, `high`, `xhigh`) unless he gave one. Always the `grok` instance (xAI), never Grok through `cursor`. The only Grok model. |

Check a model's option ids in the capabilities file from preflight (`jq '.providers[]|select(.providerInstanceId=="<id>")|.models[]|select(.id=="<model>")|.options'`). Claude models take only `effort` (no `contextWindow`).

**Choosing:**
- **At his desk:** before the first spawn, propose a model per task with a one-line reason and wait for his pick. A model he names for a kind of task ("Sonnet for implementation") holds for the session: record it as a tracker comment and do not re-ask until a different kind of task comes up. A model named for one issue covers that issue only, and "like the last one" is not his choice.
- **Away mode:** you choose, Claude only (Sonnet, Opus for hard work), unless Mattia named models for the session.
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
- Always name the mode. `auto` follows Mattia's T3 setting (queue for him), so an urgent message to a running worker says `steer`.
- **Idle worker:** a steer fails (`thread_not_sendable`); `auto` starts a new turn, and the worker acts on whatever it reads. Send an idle worker only work you want done; no rebase notice to one with nothing unmerged.
- `restart` only when Mattia asks.

A queued message that turns urgent: find it with `t3_queue {"action":"list","threadId":"<worker>"}`, then `t3_queue {"action":"promote_to_steer",...}`.

**Your own queue.** Reports that arrive while your turn runs wait in your queue and each starts a turn later. If you read and handle one early (`t3_queue {"action":"read"}` on your own thread), cancel it (`t3_queue {"action":"cancel"}`), or it re-delivers work you already did.

## Heartbeat

One safety net for a worker that forgets to report or stops moving. With the first worker launched, create a single `schedule_task`: `schedule {"type":"interval","everyMs":<interval>}`, bound to this thread (the default), prompt "Tracer heartbeat: check unreported workers (workers.md, Heartbeat)". The interval follows the work: 10 minutes (600000) while small tasks run, 30 (1800000) when only long ones (design, big builds, sub-tracers) are left; replace it when the mix changes. First `list_scheduled_tasks`: if a heartbeat bound to this thread already exists (after a compaction you no longer know its id), reuse it. Keep its id. Delete it (`delete_scheduled_task`) when no worker is active, and create it again with the next launch. One heartbeat, never one per worker, and no `sleep` timers: per-worker timers keep firing after the work is done.

At each launch, note on the work map when you expect the report (about N minutes). Agents are fast: a clear small task often takes minutes, not half an hour.

After recording any report, also run one `t3_thread_list` of your workers: one that went idle with no report gets the Idle-without-a-report step below now, not at the next heartbeat.

Each run, for every worker you launched that has no recorded report:
- **Running, within its estimate:** nothing.
- **Running, past twice its estimate:** read its last messages and activity first. Quiet since the last run: also check `git -C <worktree> log -1 --format=%cr` and `git -C <worktree> status --porcelain` (over SSH for a remote worker, remote.md). Moving by either: nothing. Not moving: tell Mattia what you see (away mode: SKILL.md, stuck).
- **Idle, and its last message has the report fields:** that is its report; record it.
- **Idle without a report:** check `includeSubagents` (its review subagents may still be running); if nothing runs, ask it once for the report with `t3_thread_send`.
- **Waiting on a request** (`t3_pending_request {"action":"list"}`): tell Mattia. That list does not show permission prompts: a running worker with no new activity item for 10 minutes gets its `activity` view read; a prompt there is his to answer.

Nothing to do: end the turn in one line, without messaging Mattia.

**A worker that died or failed** gets a fresh thread in the same worktree, picked by cause: context limit → a smaller scope (split the task, or a handoff of what is done); tool or provider error → another model; unknown → the same brief once. At his desk, propose the relaunch to Mattia; in away mode, do it. Two failed relaunches: stop, tell him, and replan the task.

## Worktree seeding (first thread of a task)

Gitignored files do not come with a worktree. If the project has a `.mcp.json`, copy `<repo root>/.claude/settings.local.json` into the worktree's `.claude/` (`mkdir -p` first; a failing `cp` is a stop-and-report), or write `{"enableAllProjectMcpServers": true}` if the source is missing; otherwise the worker stalls on "New MCP servers found". A worktree whose path casing differs from the repo's stalls on "Do you trust the files in this folder?". A stalled worker cannot report that: shortly after launch, `t3_thread_read` it (`activity` view) and `t3_pending_request {"action":"list"}`; if stuck, tell Mattia (he accepts trust prompts). The worker's first act: `git rev-parse --path-format=absolute --git-common-dir` must print `<repo root>/.git`, else report blocked "wrong repo". If a worker says its tracker MCP is missing in the worktree, tell Mattia; it must not fall back to another tracker.

Env files do not come either. Copy the main checkout's untracked `.env*` files into the worktree at the same relative paths (`git ls-files -oi --exclude-standard --directory | grep -E '(^|/)\.env[^/]*$'`), then check each is ignored there (`git -C <worktree> check-ignore -q <path>`, else append it to `.git/info/exclude`). Never print them.

## Dependencies (first thread of a task)

Installed dependencies are gitignored too, and a fresh install in every worktree repeats identical work. Project-agnostic rule: the worker reuses the main checkout's install instead of reinstalling from scratch, and does so only when it is provably the same.

- **Same lockfile:** the worktree's committed lockfile (whatever the ecosystem uses) has no diff against the main checkout's (`git diff --quiet <defaultBranch> -- <lockfile>` and no uncommitted change to it in main), and main has the installed directory (`node_modules`, `vendor`, ...).
- **Location-independent directory** (`node_modules`, `vendor`, `Pods`): copy it from main with a fast bulk copy (`MSYS_NO_PATHCONV=1 robocopy ... /E /MT:16` on Windows, `cp -a` elsewhere; never a junction or symlink, a shared directory lets one worker corrupt main and the others). Then run the project's own offline or frozen verify (`npm ls`, `composer validate`, ...) and fall back to the normal install if it fails.
- **npm or pnpm workspaces on Windows:** robocopy follows the workspace junctions and copies main's packages in as stale folders, so tests run main's code. After the copy, always run `npm install --prefer-offline --no-audit --no-fund` (about a second: it only relinks), check the lockfile is unchanged (`git diff --quiet -- <lockfile>`), else `npm ci`. On Linux `cp -a` keeps the links relative and is enough.
- **Location-bound directory** (Python `.venv`, `target`, anything with absolute paths baked in): do not copy. Run the normal install, with the tool's cache and offline flags (`--prefer-offline`, `uv sync`, ...), so the download is already skipped.
- Lockfile differs, main has no install, or the ecosystem is unfamiliar: the normal install, once, with its cache flags.
- An install that only rewrites lockfile metadata (`libc` fields, peer flags; different npm versions do this) is not a change: restore the lockfile. Keep Node and npm the same on every machine (machines.md).
- The worker states in its report which path it took. Later threads of the task reuse the worktree and install nothing unless the lockfile changed.

## Windows / Git Bash (you and the workers)

- `git -C <repo>` instead of `cd` in compound commands: a `cd` moves the session's working directory.
- `robocopy` from Git Bash: prefix `MSYS_NO_PATHCONV=1`, or `/E` is mangled, and pass Windows paths (`$(cygpath -w <path>)`): with `/c/...` paths it fails with exit 16, which is easy to miss.
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

Small, clear task: this brief as the launch message. Big task: write a handoff document (handoff.md) containing it and send only the short pointer. The fixed rules and the report format live in `worker-rules.md`, which every worker reads; never paste them, and never put shell syntax (`$(...)`) in a launch message: tool parameters are not a shell. A user-only skill (kinds.md) goes as the first line of the launch message, before the brief or the pointer.

```
Do <ISSUE-ID> in the <project> repo (this worktree, branch `<branch>`, based on the local <defaultBranch>).

Read ~/.claude/skills/tracer/worker-rules.md first and follow it (sections: Every worker, plus Code work or Design, prototype and docs). Your report goes to thread <ORCHESTRATOR_THREAD_ID><, environmentId <ID>, on a linked machine>.

## The issue
<title, expected result, constraints>
Mattia's words: "<verbatim, when the issue comes from his feedback or a hand check>"
Owns: <files you may change>. Do NOT touch: <files owned by another worker, and who>.
Skill: <the implementing skill from kinds.md, plus any domain skill; required for any thread that writes code>
Repo: <personal | client>. Tracker: <Traccia | none>. Away mode: <on | off>.
Private project notes: <paths, if the project has them; read them first>.
Scale: <the project's scale from its private notes; keep it out of every file you commit>
Preview: <when one with data is running: its link and a login (never commit them)>
```
