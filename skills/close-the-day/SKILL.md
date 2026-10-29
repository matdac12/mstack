---
name: close-the-day
description: End-of-day wrap-up for the current project. Tidies the whole tracker project, brings CLAUDE.md, AGENTS.md, docs and memories up to date, cleans up, and writes the note and paste-in prompt tomorrow starts from. Add "shutdown" to turn the PC off at the end.
disable-model-invocation: true
user-invocable: true
argument-hint: "[shutdown]"
---

# Close the day

Mattia is stopping for the day. Leave the project so tomorrow's session starts from a written note, not from memory. Write everything to him following `~/.claude/skills/unslop/SKILL.md` (read it first).

Invoking this skill is Mattia asking you to tidy the tracker and fix the docs yourself, also inside a tracer session; there, settle and clean-up still follow tracer's merge.md. Never push or deploy here, even when work is unpushed: list it instead.

## 1. Read the state

Repo root from `git rev-parse --show-toplevel`. Then `git status`, `git worktree list`, unmerged branches, unpushed commits (`git log --oneline origin/<defaultBranch>..<defaultBranch>`), and, with T3 tools, the threads this session launched (`t3_thread_list`, `t3_pending_request_list`). Done when you can say, for each piece of today's work: merged, pushed, waiting on Mattia, running, or dropped.

## 2. Tidy the tracker

The whole project, not only today's issues, so an agent opening it tomorrow knows exactly where the project stands. Use the tracker this session uses (none: skip). On Traccia, the project page is `get_project`: its description and its milestones with their "Rules for agents".

- **Status from the code:** check each open issue against git. Merged into `<defaultBranch>`: Done, or In Review when a hand check is still owed (say which in a comment). Work on a branch: In Progress. Never started: Backlog or Todo. Use only statuses that exist.
- **Descriptions:** each open issue's description matches today's reality: what is done, what is left, decisions taken. Rewrite stale ones; on Traccia pass `expectedUpdatedAt`.
- **Structure:** related issues sit under a parent issue or a milestone; blocking edges (`blockedBy`) match the real order. Create a parent or milestone when a group of 3+ issues has none.
- **Duplicates and dead issues:** Canceled with a comment naming the issue that replaces it, or why it was dropped. Never delete.
- **Project page:** the project description says where the project stands (current milestone, what is next) and stays short.

Done when every open issue has a status git agrees with, a current description, and a place in the structure.

## 3. Update the docs and memories

`CLAUDE.md`, `AGENTS.md`, the README and the `docs/` folder, whichever exist. Check each claim that today's work touched against the code (commands, paths, behaviour, conventions) and fix what is wrong or missing. Keep `AGENTS.md` and `CLAUDE.md` short: rules and pointers, not history. Private facts (scale, client details, tracker notes) stay in the private notes, never in a tracked file. A client repo stays free of issue keys and tracker names (tracer SKILL.md, Hard rules). Commit the doc changes as one commit; nothing changed: say so.

**Memories** are what agents rely on most, so a stale one does the most harm. Read every memory for this project: your own local memory (the agent memory folder and its index, such as Claude's `MEMORY.md`) and the tracker's (Traccia memories). Check each against the code and the tracker: fix what went stale, delete what is wrong, merge near-duplicates, keep the index in step. Add the lessons from today a later session should not have to re-learn, updating an existing memory rather than adding a near-duplicate. Done when every memory you kept is true today.

## 4. Clean up

- Settle the threads this session launched that are finished: merged, recorded, or dropped. Never one that is running, waiting on a request, or owns unmerged work.
- Stop dev servers, localhost and watchers this session started, by PID or process tree, never by image name.
- Update the shared skills: `git pull --ff-only` in each clone under `~/.agents/sources/`, here and on every reachable linked machine over SSH (tracer remote.md), plus the mstack checkout there. Say in one line what moved or failed; a failed pull stays as it is, never forced.
- Delete scratch files this session made (screenshots, throwaway prototypes, temp scripts) that are untracked and referenced by nothing. List the exact paths before deleting; anything unsure stays and goes in the note.

Done when nothing this session started is still running, except what you leave on purpose and name in the note.

## 5. Write the note

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

## 6. Hand back

Reply with what waits on him and a few lines on what you changed in the tracker and docs, then a paste-in prompt for tomorrow in a code block:

```
Resume <repo>. Read ~/.t3/handoffs/<repo name>/close-of-day.md first, then check it against git before doing anything.
```

With the `shutdown` argument, and only then: once the reply is written, run `shutdown /s /t 120` and tell him `shutdown /a` cancels it.
