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

- The first thread creates it: `workspaceStrategy {"type":"worktree","baseRef":"<defaultBranch>","branch":"<branch>","startFromOrigin":false}`, named per trackers.md (a client repo names it by the change, with no issue key). Record the path and branch on the issue.
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
- **Visual design** (a page, a table, a layout): ask which route, recommending the first: a **prototype** session (`/prototype` as the first line of the launch message: throwaway prototypes he looks at and discusses), or superpowers brainstorming with visual feedback. A prototype's issue goes Done when its decision note merges; building the chosen version is its own issue.

Brief: goal and issue, skill family, where spec and plan go (project convention, else `docs/superpowers/specs/` and `plans/`), owned files, and the worker-rules.md line. Add: commit the spec and plan on your branch (unless the project keeps planning docs local and gitignored: follow its policy), do not implement, and **report only when Mattia has approved the plan** (a draft is not a report). Report: spec and plan (paths, or tracker references), branch and commit, task count, open decisions. Then record it, tell Mattia in two lines, and propose the execution, routed by what the design produced:
- **A superpowers plan, no tickets:** one execution thread. Always ask him native or subagent-driven (table below); never pick for him. If he wants it run in parallel, turn the plan into tickets first (`to-tickets`), then the next line applies.
- **3+ tickets in the tracker** (`to-tickets`): propose a sub-tracer in that same message and let him choose (subtracer.md).

**Away mode:** no design thread starts. Design decisions are Mattia's alone, so a task that needs one is parked (SKILL.md, Away mode) until he is back.

**Which skill implements.** Every thread that writes code gets one, named on the brief's `Skill:` line; a brief without it does not launch. Pick it by what the worker is handed, not by how big the task is:

| The worker is handed | Skill |
| --- | --- |
| A committed plan (superpowers design) | `superpowers:executing-plans` (native, inline) or `superpowers:subagent-driven-development` (subagents inside the thread: more checks, slower). **Mattia picks each time**, never you; in away mode, native. |
| A spec and tickets, no plan (Matt Pocock design, or a spec alone) | `/implement <ticket>` (user-only: first line of the launch message). It runs `tdd` and `code-review` itself. |
| A small, clear task with no spec or plan | `superpowers:test-driven-development` |
| A bug | `superpowers:systematic-debugging` |
| A visual tweak, CSS only (colors, spacing, sizes) | `frontend-design` alone; checked by a screenshot or Mattia's hand check, not a test |

Otherwise a domain skill (`frontend-design`) is added on top of that skill, never instead of it. Never use `implement-spec`: it runs subagents inside one session; a spec with 3+ tickets is proposed as a sub-tracer (his choice), whose workers each get `/implement`. "The spec is detailed enough" is not a reason to skip the skill.

**Execute a plan.** A fresh thread in the design thread's worktree (`existing_worktree`), once that thread is idle and the plan committed. Brief: the skill chosen above on `<repo-relative plan path>`, issue, boundaries from the plan, rules; follow the plan as written, flag deviations in the report, run the project's checks, finish with `simplify` and `code-review`. **Do not split a plan into several tasks** unless Mattia asks; then each part is its own issue and worktree branching from the design branch, in dependency order.

**Implement:** the inline brief, with the skill from the table; finish with the full suite and `code-review` (`/implement` already reviews). If it proves bigger or ambiguous, the worker stops and reports and you reclassify as Design. **Fix:** the skill from the table; the brief gives symptom and repro, the report gives the root cause. The regression test is committed before the fix and shown failing in the report's `Red first` line, so you can rerun it on the fix's parent. It must fail against the real code path with the bug; a stub written to fail proves nothing. **Review:** `code-review` or `simplify` on a named branch; findings only. **Investigate:** read-only; findings you will act on become issues. **Guide:** one question at a time, 2 or 3 options with a recommendation.

**Second-model review.** A risky diff gets a Review thread on the review model (workers.md, Models) before merge, on top of the worker's own `code-review`. Risky means: migrations or data writes, security, database or connection code, shared code other tasks depend on, a sub-tracer's epic diff. Effort follows risk: `high` for migrations that drop, rename or rewrite data, code that creates or drops databases, security, and anything that reaches production; `medium` for additive migrations (a new table or nullable column), shared code and epics. The brief gives the diff range (`<defaultBranch>...<branch>`) and one paragraph of intent: what the change must do and why. The reviewer judges the code against that intent and reports each finding with severity, location and evidence; it praises nothing, and "no findings" is a valid answer. You triage its findings (merge.md, Review). Mattia's OpenAI usage is small: if the review model hits a usage limit (session or five-hour), relaunch the review on Claude Opus 5.5 with the same effort.
