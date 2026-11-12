# Workers on Herdr: models, launch, talking, heartbeat

`hc` below is `bash ~/.claude/skills/tracer-herdr/scripts/hc.sh`. The sections of tracer's `workers.md` not repeated here (Dependencies, Windows / Git Bash, Shared machine) apply as written.

## Models

| Key | Command `spawn-worker.sh` runs | Use for |
| --- | --- | --- |
| `sonnet` | `claude --model claude-sonnet-5-5 --effort <e>` | Implementation, execute-a-plan, fixes, refactors. The default, at `medium`. |
| `opus` | `claude --model claude-opus-5-5 --effort <e>` | Design, hard refactors, anything Sonnet struggled with, at `high`. |
| `fable` | `claude --model claude-fable-5-2 --effort <e>` | **A review model**: second-model reviews (tracer kinds.md, Review), read-only, effort by risk there. Code work only when Mattia picks it. Never its `ultracode` option. |
| `gpt` or `gpt:<model>` | `codex --no-daemon --sandbox danger-full-access -m <model> -c model_reasoning_effort=<e>` (default model `gpt-6.1-sol`) | **A review model, and nothing else**, as in tracer: Mattia's OpenAI plan is small. Another GPT model (`gpt:gpt-6-luna`) only when he names it. |
| `grok` | `grok -m grok-4.7 --effort <e>` | Any task, only when Mattia picks it; ask the effort (`low`, `medium`, `high`, `xhigh`) unless he gave one. |

Codex flags: `--no-daemon` keeps its commands inside the terminal; `--sandbox danger-full-access` is T3's full-access mode, and without it the worker cannot run `hc` from WSL (the sandbox blocks the socket WSL uses to start Windows programs), so it can never report. Mattia's permission settings still apply. DeepSeek (OpenCode) is installed on Windows only and has no row: when he picks it, start it by hand with `hc run --bg --outlive-parent --name <n> --parent <you> --cwd <checkout> opencode …`, after reading `opencode --help`, and tell him it is a first try.

**Choosing:** as tracer's workers.md, Models (at his desk you propose and he picks; away mode you pick Claude only; Design and Guide are his). Co-Authored-By trailer matches the model.

**A worker's word on its own model is not evidence:** Codex workers have named the wrong model. The work map takes the model from the launch command or the agent's status bar (`hc read`).

## Worktree (first thread of a task)

T3 made worktrees for you; here you make them, where tracer's cleanup scripts expect them:

```
git -C <repo root> worktree add -b <branch> ~/.t3/worktrees/<repo name>/<branch> <defaultBranch>
bash ~/.claude/skills/tracer/scripts/seed-worktree.sh ~/.t3/worktrees/<repo name>/<branch>
```

Branch named per tracer's trackers.md (a client repo names it by the change, no issue key). Record path and branch on the issue. Later threads of the task reuse it. Seeding runs before the launch, so the worker finds its `tracer-seed` note at once. Read-only work (investigate, a review of another branch) runs in the main checkout, no worktree. One active worker per worktree.

## Launch

1. Write the brief (Brief, below) to `<git dir>/tracer-brief-<name>.md`, where `<git dir>` is `git -C <checkout> rev-parse --path-format=absolute --git-dir`: untracked, beside the task, gone with the worktree. A big task: the handoff document (tracer handoff.md) is the brief file.
2. `bash ~/.claude/skills/tracer-herdr/scripts/spawn-worker.sh <name> <checkout> <model> <effort> <brief file>`. Name: `<issue-id>-<2-3 words>` in lowercase, hyphens, at most 32 characters (`proj-12-login-form`). It starts the agent in a new terminal in your sidebar space, as your child (its blocked, error and exit notes come to you), outliving you, with the first message "Read <brief file> and follow it." From WSL the worker runs in WSL.
3. Keep its address from the printed JSON. About a minute later, `hc get <name>`: `working` is good; `blocked` on startup is usually a trust or MCP prompt: `hc read <name>` and tell Mattia (he answers it in the sidebar). **Codex: always `hc read <name> --lines 0` as well.** Herdr does not see Codex's "Trust this folder?" prompt (status stays empty or `idle`, no note comes), so only the screen shows it. Note on the work map when you expect the report.

A launch error: `hc ls` before retrying, a half-started terminal may exist.

## Brief

The brief file holds tracer's Brief template (tracer workers.md, Brief) with two changes:
- **First step line:** "load your tracker's tools (Traccia: then `whoami`); missing means say so in your report. Then read ~/.claude/skills/tracer/worker-rules.md and ~/.claude/skills/tracer-herdr/worker-rules.md (the second wins where they differ) and follow them."
- **Report line**, word for word, with your address filled in:

```
Report: when the work is done, your last act is one REPORT: write it to <git dir>/tracer-report-<name>.md in the format of worker-rules.md, then run `bash ~/.claude/skills/tracer-herdr/scripts/hc.sh send <ORCHESTRATOR_ADDRESS> "REPORT <ISSUE-ID> <status>: <report file path>"`. Send it without waiting for anyone's approval, unless this brief says Mattia works with you in this terminal; then send it once he approves the outcome. Until then, progress stays in your own terminal.
```

The rest of tracer's Brief rules hold (a user-only skill as the first line, no shell syntax in the first message, "Mattia works with you in this terminal." for design, guide and hand-check workers).

## Talking to a worker

`hc send <t> "<text>"` types into its prompt. A running Claude worker gets it at its next step (a steer); an idle one starts a new turn on it. Herdr holds a send while Mattia is typing in that terminal (up to 60 seconds).
- Before each send, `hc read <t> --lines 40` and weigh it against this chat: **would this message lose value by arriving after the current turn?** Yes or unsure: send now, with the timing in the words ("when your current step is committed, rebase…"). No: hold it until the report.
- An idle worker acts on whatever it reads: send it only work you want done.
- `hc send` refuses a `blocked` worker. Never `--force` it, never `hc keys` a permission or question: tell Mattia.
- `hc interrupt <t>` stops a turn: only when Mattia asks.
- Long messages: write them to a file beside the brief and send the path.

## Reports

- A report arrives as `<hc from="t7 proj-12-login-form">REPORT PROJ-12 done: /…/tracer-report-proj-12-login-form.md</hc>`. Read the file; that is the report. Handle it once: there is no queue to clear.
- `<hc>t7 name is blocked (question). See: hc read t7</hc>` and similar notes come from Herdr, not the worker: `hc read` it, then tell Mattia what it waits on (away mode: park it, tracer SKILL.md).
- A worker that exited (`finished`) without a report: read its screen; follow tracer's "A worker that died or failed" with a new terminal in the same worktree.

## Heartbeat

Herdr reports blocked, errors and exits by itself; the heartbeat only catches a worker that went idle without reporting, or stopped moving.
- **Exists only while a worker needs watching** (no recorded report, not waiting on Mattia). At such a launch, `CronList` first (load it with ToolSearch): reuse yours. None: one `CronCreate`, recurring, every 10 minutes when every watched task is small, 30 when design or a big build is among them, on an off minute (`7-59/10 * * * *`), prompt "Tracer heartbeat: check unreported workers (tracer-herdr workers.md, Heartbeat)". It fires only while you are idle and expires after 7 days. Keep its id; `CronDelete` it as soon as no worker needs watching.
- **Each run:** clock first (a gap over twice the interval means the machine slept: say how long). Then `hc get` each watched worker:
  - `working`, within its estimate: nothing. Past twice its estimate: `hc read` it, plus `git -C <worktree> log -1 --format=%cr` and `status --porcelain`; not moving: tell Mattia.
  - `idle` or `done` with no report: `hc read --lines 60`. Ending on a question to Mattia: it waits on him; nothing. Otherwise ask it once for the report with `hc send`.
  - `blocked`: tell Mattia (it should already have come as a note).
  - Nothing to do: end the turn in one line.

## Settle and clean up

tracer's merge.md, Settle and clean up, with the map: settle a terminal with `hc kill <t>` then `hc rm <t>`, at the moments it names (never one that is working, blocked, unreported or owns an unmerged branch). Only terminals whose parent is you. Then `cleanup-task.sh` as written.

## Other machines

`hc machine ls` lists the machines Herdr reaches. A worker there: `hc run --bg --outlive-parent --on <machine> --parent <you> --name <n> --cwd <remote checkout> <command> "Read <brief> and follow it."`, address `<machine>/t7`. The git side (syncing `<defaultBranch>`, seeding, never pushing from there) is tracer's remote.md. The brief's report command uses the address `hc` prints for you on that machine. **Not yet tried:** the first remote launch is a test; tell Mattia, and check the report arrives before relying on it.
