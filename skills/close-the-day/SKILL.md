---
name: close-the-day
description: End-of-day wrap-up for the current project. Records the day in the tracker, memory and docs, cleans up, and writes the note and paste-in prompt tomorrow starts from. Add "shutdown" to turn the PC off at the end.
disable-model-invocation: true
user-invocable: true
argument-hint: "[shutdown]"
---

# Close the day

Mattia is stopping for the day. Leave the project so tomorrow's session starts from a written note, not from memory. Write everything to him following `~/.claude/skills/unslop/SKILL.md` (read it first).

Inside a tracer session, tracer's rules still hold: workers do the edits, and settle and clean-up follow its merge.md. Never push or deploy here, even when work is unpushed: list it instead.

## 1. Read the state

Repo root from `git rev-parse --show-toplevel`. Then `git status`, `git worktree list`, unmerged branches, unpushed commits (`git log --oneline origin/<defaultBranch>..<defaultBranch>`), and, with T3 tools, the threads this session launched (`t3_thread_list`, `t3_pending_request_list`). Done when you can say, for each piece of today's work: merged, pushed, waiting on Mattia, running, or dropped.

## 2. Record

- **Tracker** (the one this session uses; none: skip): each issue touched today has its real status and a short comment saying where it stands. Use only statuses that exist.
- **Lessons:** a fact or lesson a later session should not have to re-learn goes to the tracker's knowledge layer (Traccia memories) or the project's agent memory. Update an existing note rather than adding a near-duplicate.
- **Docs:** docs that today's work made wrong get fixed in one commit (in a tracer session, by a worker). A client repo stays free of issue keys and tracker names (tracer SKILL.md, Hard rules).

## 3. Clean up

- Settle the threads this session launched that are finished: merged, recorded, or dropped. Never one that is running, waiting on a request, or owns unmerged work.
- Stop dev servers, localhost and watchers this session started, by PID or process tree, never by image name.
- Delete scratch files this session made (screenshots, throwaway prototypes, temp scripts) that are untracked and referenced by nothing. List the exact paths before deleting; anything unsure stays and goes in the note.

Done when nothing this session started is still running, except what you leave on purpose and name in the note.

## 4. Write the note

Overwrite `~/.t3/handoffs/<repo name>/close-of-day.md` (create the folder). It sits outside the repo, so client repos stay clean, and tracer reads it at its next start.

```markdown
# Close of day: <repo> · <YYYY-MM-DD>
## Where we are
2-4 plain sentences.
## Done today
- <issue or change>: merged | pushed | waiting on hand check
## Waiting on Mattia
- <call or hand check, with my recommendation>
## Not pushed
<commits on <defaultBranch> not on origin, or "nothing">
## Next
1. <first thing tomorrow>
## Left running on purpose
<or "nothing">
```

## 5. Hand back

Reply with what waits on him, then a paste-in prompt for tomorrow in a code block:

```
Resume <repo>. Read ~/.t3/handoffs/<repo name>/close-of-day.md first, then check it against git before doing anything.
```

With the `shutdown` argument, and only then: once the reply is written, run `shutdown /s /t 120` and tell him `shutdown /a` cancels it.
