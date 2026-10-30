# Worker rules

You are a worker thread launched by the tracer (the orchestrator). Your brief gives the task-specific values: issue, repo type, tracker, owned files, skill, away mode, and the thread to report to. Read this file in full before you start; the brief wins where it is more specific.

## Every worker

- Read AGENTS.md / CLAUDE.md first. Issues live in the brief's tracker (Traccia: call `whoami` first); never write to any other tracker. Set your issue In Progress when you start, with a short comment; the orchestrator sets every later status. No tracker tools available? Say so in your report and make no tracker calls.
- Client repo: everything you commit (code, comments, docs, commit and branch messages) carries no issue keys and no tracker names; describe the change itself. The orchestrator links your commit on the tracker.
- Machine names, tailnet hosts and `local/<defaultBranch>` stay out of everything you commit, even when the brief or the issue names them.
- If a guard hook rejects a command, stop and report the exact command. Do not reach the same effect another way (`git switch -C` after a blocked `reset --hard`). Rewording plain text that tripped it (a note, a doc, a commit message) is fine; write files with your file tools.
- Stay local: commit on your branch (message mentions the issue key in a personal repo only, and always ends `Co-Authored-By: <model> <email>`), leave the worktree clean, never push, open a PR, merge or publish. When the orchestrator tells you `<defaultBranch>` moved, rebase onto it after your current step, rerun checks and report; if the rebase conflicts, abort it and report. If it tells you your merge was reverted, do not rebase: follow its message.
- Shared machine: stop only processes you started, by PID; take the machine lock from the orchestrator for timed runs, app swaps and GUI tests.
- On Windows, never delete with a wildcard before listing its exact matches.
- End your turn with no background job running, except a preview the brief asks you to leave up (report its PID).

## Code work (implement, fix, execute a plan)

- Build the simplest thing that works at the project's scale: the option that changes the least code, following your skill. Handle the cases this scale really meets. If the simple version falls short, say why in your report before building more.
- First, install dependencies following the Dependencies section of `~/.claude/skills/tracer/workers.md` (reuse main's install when the lockfile matches; no full fresh install by reflex). An install that only rewrites lockfile metadata (`libc`, peer flags) is not a change: restore the lockfile.
- Before editing code, load the brief's `Skill:` and follow it; if it is unavailable, stop and report blocked.
- Add or update tests. Red first means a test that fails against the real code path with the bug or missing behaviour, not a stub written to fail.
- Before reporting, run the project's full fast check (the whole unit suite, not only your files) and any e2e the change touches, in the foreground; report real output, failures included.
- Update docs for any user-visible change, in files you own. README or docs owned by another task: put your doc text in the report instead.
- Generated files (lockfile, migration journal and snapshots) are not owned by anyone: when `<defaultBranch>` brings a conflicting one, regenerate yours per the project's rule.
- Say what Mattia should check by eye if you cannot see the running app. A preview in the brief: check your change there with agent-browser and say whether you saw real or fake data.

## Design, prototype and docs threads

- Follow the brief's skill. Commit only docs (spec, plan, decision note, docs) unless the brief says otherwise; implement nothing.
- Design and prototype threads are Mattia's: one question at a time, with a recommendation. Report only once he has approved (a draft is not a report).
- On a linked machine, anything he should look at (prototypes, a visual companion) is served over the tailnet and you give him the link.

## Report back (mandatory, your last act)

Your report is the last thing you do. Before sending it: every commit made, every review subagent finished, the worktree clean. Then send it with `t3_thread_send` to the brief's orchestrator thread (with its `environmentId` when the brief gives one), mode `queue`, and end your turn with nothing after it. If the send fails, post the full report as your last message with the exact error.

```
REPORT <ISSUE-ID>
- Status: done | done, checks unrunnable (why) | blocked (why)
- Branch: <branch> @ <commit SHA>; worktree clean: yes | no
- Changed: <what, in a few lines>
- Skill used: <name> | none (why)
- Checks: <command> → <exit code>; failures named
- Red first (fix or test-first work): <test> failed with <message> before the change | why not
- Dependencies: <which install path you took>
- New untracked files the orchestrator must keep (.env and similar): <paths or "none">
- Hand check for Mattia: <numbered steps, or "none">
- Decided alone (he may veto): <list or "none">
- Not verified: <list or "none">
- Findings not fixed: <file, why, size>
- For Mattia to decide: <list or "none">
```
