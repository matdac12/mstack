# Readiness, worktrees, task kinds

## 1. Readiness

Before choosing a kind, judge the task (read the issue and, unless obviously fresh, the code it touches: part of it may already be done) and tell Mattia the bucket in a line:

- **Ready:** clear outcome, bounded scope, nameable files, no decision needed from him → Implement, Fix, Review or Investigate.
- **Needs discussion:** several approaches, product or design decisions, unclear scope, needs a spec → a **Design thread** with him in it.
- **Needs triage:** vague, old, duplicate or maybe done → you read the code yourself, read-only (or via an `Agent`), no thread; then you recommend (do it, backlog and what would promote it, or drop) and talk it over with him **here**, with no thread. He decides.

Unsure between ready and discussion: say which you lean to and why, and let him choose.

## 2. One worktree per task

A task = one issue = one branch = **one worktree**. Its threads (design, then execution, then a review fix) run in it one after another, so the spec, plan and installed dependencies are already there.

- The first thread creates it: `workspaceStrategy {"type":"worktree","baseRef":"<defaultBranch>","branch":"<issue-id>-slug","startFromOrigin":false}`. Record the path and branch on the issue.
- Later threads: `{"type":"existing_worktree","worktreePath":"<path>","branch":"<branch>"}` (path from `t3_worktree_list`, never guessed).
- **One active thread per worktree.** Before the next, check the previous is idle and its work committed.
- Seed and install dependencies once, in the first thread, reusing main's install when the lockfile matches (workers.md).
- Any thread that writes files gets a worktree. `{"type":"root"}` is only for threads that write nothing (Investigate, a review of another branch, Q&A).

## 3. Kinds

Say the kind to Mattia in a word. Skills named below are assumed installed for every worker model (Mattia keeps Claude, OpenCode and Codex stocked); if a worker reports one missing, tell him.

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

Brief: goal and issue, skill family, where spec and plan go (project convention, else `docs/superpowers/specs/` and `plans/`), owned files, and workers.md's rules. Add: commit the spec and plan on your branch, do not implement, and **report only when Mattia has approved the plan** (a draft is not a report). Report: spec and plan (paths, or tracker references), branch and commit, task count, open decisions. Then record it, tell Mattia in two lines, and propose the execution thread; spawn on his yes. For a big epic with a chain, that execution is a sub-tracer (subtracer.md), not one worker.

**Execute a plan.** A fresh thread in the design thread's worktree (`existing_worktree`), once that thread is idle and the plan committed. Brief: `superpowers:executing-plans` on `<repo-relative plan path>` (for the Matt Pocock family, which produces a spec rather than a plan, use its `implement` skill on the spec instead), issue, boundaries from the plan, rules; follow the plan as written, flag deviations in the report, run the project's checks, finish with `simplify` and `code-review`. **Do not split a plan into several tasks** unless Mattia asks; then each part is its own issue and worktree branching from the design branch, in dependency order.

**Implement:** the inline brief; if it proves bigger or ambiguous, the worker stops and reports and you reclassify as Design. **Fix:** `superpowers:systematic-debugging`; the brief gives symptom and repro, the report gives the root cause. **Review:** `code-review` or `simplify` on a named branch; findings only (use `ask-codex` yourself for a second model's opinion). **Investigate:** read-only; findings you will act on become issues. **Guide:** one question at a time, 2 or 3 options with a recommendation.
