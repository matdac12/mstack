---
name: close-the-day
description: End-of-day wrap-up or docs-and-memory maintenance for the current project. Use for a full closeout with tracker, cleanup and a restart note, or when Mattia explicitly asks to update only documentation and memories. Add "shutdown" for a full closeout that turns the PC off.
disable-model-invocation: true
user-invocable: true
argument-hint: "[shutdown]"
---

# Close the day

Write to Mattia following `~/.claude/skills/unslop/SKILL.md` (read it first). Choose the path from his request, whether or not Tracer is active:

- **Full closeout** is the default for `/close-the-day` or a request to close the day. Follow all six steps. Tidy the tracker and fix the docs yourself. In Tracer, settle and clean up under tracer's merge.md. An explicit shutdown request uses this path.
- **Docs and memories only** when Mattia narrows the request to that. Read the repo status, relevant diff and recent commits for context, then do step 3. Report what changed and what you could not verify. Leave tracker issues, handoff notes, threads, processes, worktrees and installed skills alone. Update project memories in their existing stores, including Traccia when used. Commit only if asked.

Never push or deploy during either path. In a full closeout, list unpushed work in the note.

## 1. Read the state

Repo root from `git rev-parse --show-toplevel`. Then `git status`, `git worktree list`, unmerged branches, unpushed commits (`git log --oneline origin/<defaultBranch>..<defaultBranch>`), and, with T3 tools, the threads this session launched (`t3_thread_list`, `t3_pending_request {"action":"list"}`). Done when you can say, for each piece of today's work: merged, pushed, waiting on Mattia, running, or dropped.

## 2. Tidy the tracker

The whole project, not only today's issues, so an agent opening it tomorrow knows exactly where the project stands. Use the tracker this session uses (none: skip). On Traccia, the project page is `get_project`: its description and its milestones with their "Rules for agents".

- **Status from the code:** check each open issue against git. Merged into `<defaultBranch>`: Done, or In Review when a hand check is still owed (say which in a comment). Work on a branch: In Progress. Never started: Backlog or Todo. Use only statuses that exist.
- **Descriptions:** each open issue's description matches today's reality: what is done, what is left, decisions taken. Rewrite stale ones; on Traccia pass `expectedUpdatedAt`.
- **Structure:** related issues sit under a parent issue or a milestone; blocking edges (`blockedBy`) match the real order. Create a parent or milestone when a group of 3+ issues has none.
- **Duplicates and dead issues:** Canceled with a comment naming the issue that replaces it, or why it was dropped. Never delete.
- **Project page:** the project description says where the project stands (current milestone, what is next) and stays short. On Traccia, update it with `save_project` and the project's `id` (tracer trackers.md); without the id it creates a new project.
- **Machine names:** search the project's tracker text (project description, open issues, today's comments) for the names in `~/.t3/machines.md`, in any case, and rewrite each hit without them: colleagues cannot know what they mean.

Done when every open issue has a status git agrees with, a current description, and a place in the structure.

## 3. Update the docs and memories

`CLAUDE.md` and `AGENTS.md`, whichever exist, are what every agent reads first. Scan both for stale commands, paths, behaviours, conventions and pointers. Edit claims the work changed or that you can verify are wrong. Keep durable rules and pointers in startup docs. In a full closeout, put temporary state such as unpushed commits and tomorrow's next task in the handoff note.

The README and the `docs/` folder: check claims the work touched against the code and fix what is wrong or missing. Private facts (scale, client details, tracker notes, machine names, local multi-machine setup, personal skills like `/tracer`, `superpowers`, `mattpocock-skills`, `unslop`, `close-the-day`) stay in the untracked local notes (`CLAUDE.local.md`, parent-folder `CLAUDE.md`, `~/.t3/worktrees/<repo>/CLAUDE.md`), never in a tracked file (`CLAUDE.md`, `AGENTS.md`, `README.md`, `docs/**`). A client repo stays free of issue keys and tracker names (tracer SKILL.md, Hard rules). In a full closeout, commit only the doc changes you made as one commit. If nothing needed changing, say so.

**Memories:** scan the project's local memory and index (such as Claude's `MEMORY.md`) and its tracker memories when available. Verify entries relevant to the work and anything that looks stale. Correct verified errors, merge duplicates, and keep the index in step. Save durable lessons a later session would otherwise have to relearn by updating an existing entry when it covers the same subject.

## 4. Clean up

- Settle the threads this session launched that are finished: merged, recorded, or dropped, with their subagents (`t3_thread_list {"settled":false,"includeSubagents":true}`, on each linked machine with its `environmentId` and `projectId`). Never one that is running, waiting on a request, or owns unmerged work.
- Clean up any finished, merged worktrees and merged `local/<epic>` refs left behind here or on a reachable linked machine (`git -C <root> worktree list` over SSH, then `remove-worktree.sh` and `land.sh drop-remote-ref` per tracer merge.md and remote.md).
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
- <task, worker thread link, and what to reconcile on return, or "nothing">
## This session
Orchestrator thread <id>: finished with this note. Its threads are settled, or listed above; a new session owns everything from here.
<in a tracer session, add:> Tracer session. If the tracer skill is not loaded when you read this, launch no thread and merge nothing: ask Mattia to send `/tracer` first.
```

## 6. Hand back

Reply with what waits on him and a few lines on what you changed in the tracker and docs, then a paste-in prompt for tomorrow in a code block. Copy the first concrete action from the note. Include any decision Mattia kept for himself that gates it. In a Tracer session start the prompt with `/tracer` on its own line. For a standalone handoff, start with `Resume`:

```
/tracer
Resume <repo>. Read ~/.t3/handoffs/<repo name>/close-of-day.md first, then check it against git before doing anything.
Start with <first concrete action>. <Ask me before the action that requires my decision, if any.>
```

When Mattia explicitly asks for shutdown, including via the `shutdown` argument, send the closeout with the paste-in prompt above before scheduling it. Include `shutdown /a` as the cancellation command in that same reply. Then run `shutdown /s /t 120` and report a scheduling failure if the command fails.
