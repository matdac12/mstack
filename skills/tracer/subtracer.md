# Sub-tracers: a tracer per epic

A **sub-tracer** is a worker thread that is itself a tracer. It spawns its own workers, merges them into its epic branch and reports to you only at the end. It saves your context and lets Mattia talk to the epic directly.

## When

- One unit of work (a spec or a plan) that splits into 3+ tickets and that you can hand over whole, or when Mattia asks. Two tasks, independent fixes and parallel front/back workers on one small change stay plain workers: no sub-tracer for "anything", and no proposal either.
- **You propose, he chooses.** When you see 3+ tickets, say so in one line with a recommendation: "delegate to a sub-tracer and wait for its report, or I manage the workers myself?" Never launch one unasked.
- A design thread (kinds.md) usually comes first and produces the spec and tickets; the sub-tracer then executes them.

## Launch

`t3_thread_launch`, `runtimeMode: "full-access"`, the model Mattia picked for all workers (workers.md, Models), title `<EPIC-ID> · epic <slug>`, and a worktree on a new epic branch: `{"type":"worktree","baseRef":"<defaultBranch>","branch":"<epic-slug>","startFromOrigin":false}`. `baseRef` is the commit that holds the approved spec, plan and tickets: the design branch when they are not merged yet, else an integration branch (below). **You decide the epic worktree and branch** (record path and branch on the epic issue); the sub-tracer creates no other checkout of its own, and every worker it launches gets a worktree branching from the epic branch. Nothing the sub-tracer or its workers do touches the main checkout or other branches. Seed the worktree as in workers.md. The brief is always a handoff doc (handoff.md), with the pointer in the message, so both of you can re-read it after a compaction.

The message starts with `/tracer <tracker>` and then **overrides that win over the skill**:

```
/tracer <tracker>

You are the sub-tracer for <EPIC-ID>, epic branch `<epic>`. Parent thread: <PARENT_THREAD_ID>. These overrides win over the skill:
- Your worktree is your "main checkout" and `<epic>` is your `<defaultBranch>`; preflight accepts that. Your workers branch from `<epic>`; you merge them into it following merge.md (review, full checks, rebase notices).
- You never push, open PRs or merge into `<realDefaultBranch>`. merge.md's Push section does not apply.
- Model and skills are decided: workers run <model> and use <skill, from kinds.md "Which skill implements", e.g. /implement as the first line of each launch>. Do not ask again.
- The epic and its sub-issues are <IDS>. A sub-issue goes In Review when merged into `<epic>`, and Done only once its hand check passed (or at that merge when it needs none). Leave the epic In Progress; the parent closes it.
- Grants and away mode from the parent: <none | the grant or away mode, restated>.
- Order and parallelism come from the issue edges. Hand out the machine lock one worker at a time for timed runs or anything that swaps Mattia's app.
- Ask Mattia directly in this thread for hand checks and decisions, never through the parent.
- Report to the parent only when everything is done or you are blocked on the parent, via t3_thread_send (mode `queue`) as one message and your last act, with: final branch and SHA, worktree clean, per-ticket summary, checks with real output, hand-check results, open decisions, unfixed findings filed as issues.
- AGENTS.md product rules still hold.
```

## Parent's job afterwards

- Never `t3_thread_wait` on a sub-tracer: its report arrives as a message. If only a pointer arrives, read its thread (`view:"messages"`) before reviewing.
- Review the whole epic diff (`git diff <defaultBranch>...<epic>`), focused on the shared hot paths.
- `git merge-tree --write-tree <defaultBranch> <epic>` must print a tree with no conflicts.
- Report to Mattia. Merge (merge.md) on his yes, push on a separate yes (or under a grant), then close the epic and settle the sub-tracer once it is merged.
- Its report can be wrong about Mattia's machine ("kept at his request" when it was its own choice). Verify claims about his environment.

## Rebase notice to a sub-tracer

When `<defaultBranch>` moves under it, or its base gets fixes: `t3_thread_send`, mode per workers.md (Talking to a worker), a stable `clientRequestId`: "`<defaultBranch>` moved. Between tickets, merge it into your epic branch, rerun checks, and tell your running workers to rebase onto the epic branch."

## Starting on unmerged work

If the epic touches the same code as branches still waiting for hand checks, build its base from them without a worktree:

```
T=$(git merge-tree --write-tree A B)        # conflicts: stop, rehearse in int- (merge.md)
C=$(git commit-tree $T -p A -p B -m "<epic> base: A + B")
git branch <epic>-base $C
```

Launch with `baseRef` `<epic>-base` and say so in the brief. The epic now contains A and B: merge it only after they are accepted.
