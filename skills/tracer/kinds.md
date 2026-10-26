# Readiness, worktrees, task kinds

## 1. Readiness

Before choosing a kind, judge the task (read the issue and, unless obviously fresh, the code it touches: part of it may already be done) and tell Mattia the bucket in a line:

- **Ready:** clear outcome, bounded scope, nameable files, no decision needed from him → Implement, Fix, Review or Investigate.
- **Needs discussion:** several approaches, product or design decisions, unclear scope, needs a spec → a **Design thread** with him in it.
- **Needs triage:** vague, old, duplicate or maybe done → you read the code yourself, read-only (or via an `Agent`), no thread; then you recommend (do it, backlog and what would promote it, or drop) and talk it over with him **here**, with no thread. He decides.

Unsure between ready and discussion: say which you lean to and why, and let him choose.

Before spawning a ready task, check what the brief will claim:
- Behaviour the issue describes: confirm it in the code first.
- Owned files: derive them from what actually imports the code you will touch (grep its importers), not from folder names.
- An issue another thread created or edited in the last few minutes: confirm its text with Mattia in one line.

## 2. One worktree per task

A task = one issue = one branch = **one worktree**. Its threads (design, then execution, then a review fix) run in it one after another, so the spec, plan and installed dependencies are already there.

- The first thread creates it: `workspaceStrategy {"type":"worktree","baseRef":"<defaultBranch>","branch":"<issue-id>-slug","startFromOrigin":false}`. Record the path and branch on the issue.
- Later threads: `{"type":"existing_worktree","worktreePath":"<path>","branch":"<branch>"}` (path from `t3_worktree_list`, never guessed).
- **One active thread per worktree.** Before the next, check the previous is idle and its work committed.
- **Resuming existing work:** `git fetch origin` and compare the local and remote branch before briefing. The branch exists but its worktree is gone: attach a worktree to that branch (`existing_worktree` or `t3_worktree_list`), never retry the create and never pick another branch name silently.
- Seed and install dependencies once, in the first thread, reusing main's install when the lockfile matches (workers.md).
- Any thread that writes files gets a worktree. `{"type":"root"}` is only for threads that write nothing (Investigate, a review of another branch, Q&A).

## 3. Kinds

Say the kind to Mattia in a word. Skills named below are assumed installed for every worker model (Mattia keeps Claude, OpenCode and Codex stocked); if a worker reports one missing, tell him.

**User-only skills** (marked `disable-model-invocation`, such as `implement`) cannot be started by the worker itself. Put the slash command as the first line of the launch message (`/implement TRC-42`), then the brief or the handoff pointer.

| Kind | Driven by | Output |
| --- | --- | --- |
| Design (brainstorm → spec → plan) | Mattia, in the thread | spec and plan, committed |
| Execute a plan | the worker | code, committed |
| Implement (small, clear) | the worker | code, committed |
| Fix / debug | the worker | fix + regression test, committed |
| Review | the worker | findings, no edits |
| Investigate | the worker | findings report |
| Guide (interview) | Mattia, in the thread | decisions, committed |

**Design.** The thread is his: he talks to the agent in the sidebar; you do not steer it and wait for its report. Ask him which model and which skill family (default superpowers):
- **superpowers:** `superpowers:brainstorming` through the spec, then `superpowers:writing-plans`.
- **Matt Pocock:** `grill-with-docs` or `grill-me`, then `to-spec` (and `to-tickets` if he wants tickets); `wayfinder` for something too big for one session. Tell the worker which tracker to target. `to-tickets` creates tracker issues, so only if he asks; those issues are then the tasks, and you file nothing extra.

Brief: goal and issue, skill family, where spec and plan go (project convention, else `docs/superpowers/specs/` and `plans/`), owned files, and workers.md's rules. Add: commit the spec and plan on your branch (unless the project keeps planning docs local and gitignored: follow its policy), do not implement, and **report only when Mattia has approved the plan** (a draft is not a report). Report: spec and plan (paths, or tracker references), branch and commit, task count, open decisions. Then record it, tell Mattia in two lines, and propose the execution thread; spawn on his yes. If the spec or plan splits into 3+ tickets (subtracer.md, When), propose a sub-tracer in that same message and let him choose.

**Which skill implements.** Every thread that writes code gets one, named on the brief's `Skill:` line; a brief without it does not launch. Pick it by what the worker is handed, not by how big the task is:

| The worker is handed | Skill |
| --- | --- |
| A committed plan (superpowers design) | `superpowers:executing-plans` (native, inline) or `superpowers:subagent-driven-development` (subagents inside the thread: more checks, slower). **Mattia picks each time**; in away mode, native. |
| A spec and tickets, no plan (Matt Pocock design, or a spec alone) | `/implement <ticket>` (user-only: first line of the launch message). It runs `tdd` and `code-review` itself. |
| A small, clear task with no spec or plan | `superpowers:test-driven-development` |
| A bug | `superpowers:systematic-debugging` |

A domain skill (`frontend-design`) is added on top of that skill, never instead of it. Never use `implement-spec`: it runs subagents inside one session; a spec with 3+ tickets is proposed as a sub-tracer (his choice), whose workers each get `/implement`. "The spec is detailed enough" is not a reason to skip the skill.

**Execute a plan.** A fresh thread in the design thread's worktree (`existing_worktree`), once that thread is idle and the plan committed. Brief: the skill chosen above on `<repo-relative plan path>`, issue, boundaries from the plan, rules; follow the plan as written, flag deviations in the report, run the project's checks, finish with `simplify` and `code-review`. **Do not split a plan into several tasks** unless Mattia asks; then each part is its own issue and worktree branching from the design branch, in dependency order.

**Implement:** the inline brief, with the skill from the table; finish with the full suite and `code-review` (`/implement` already reviews). If it proves bigger or ambiguous, the worker stops and reports and you reclassify as Design. **Fix:** the skill from the table; the brief gives symptom and repro, the report gives the root cause. **Review:** `code-review` or `simplify` on a named branch; findings only (use `ask-codex` yourself for a second model's opinion). **Investigate:** read-only; findings you will act on become issues. **Guide:** one question at a time, 2 or 3 options with a recommendation.
