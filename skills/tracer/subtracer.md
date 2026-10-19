# Sub-tracers: a tracer per epic

A **sub-tracer** is a worker thread that is itself a tracer. It spawns its own workers, merges them into its epic branch and reports to you only at the end. It saves your context and lets Mattia talk to the epic directly.

## When

- An epic of roughly 3+ tickets with a blocking chain (A → B → C), or when Mattia asks. Small, independent fixes stay plain workers.
- A design thread (kinds.md) usually comes first and produces the spec, ADRs and tickets; the sub-tracer then executes them.

## Launch

`t3_thread_launch`, `runtimeMode: "full-access"`, the model Mattia picked for all workers (workers.md, Confirm the model), title `<EPIC-ID> · epic <slug>`, and a worktree on a new epic branch: `{"type":"worktree","baseRef":"<defaultBranch>","branch":"<epic-slug>","startFromOrigin":false}`. `baseRef` is an integration branch when the epic starts on unmerged work (below). Seed the worktree as in workers.md. Brief over a screenful: handoff doc (handoff.md), pointer as the message.

The message starts with `/tracer <tracker>` and then **overrides that win over the skill**:

```
/tracer <tracker>

You are the sub-tracer for <EPIC-ID>, epic branch `<epic>`. Parent thread: <PARENT_THREAD_ID>. These overrides win over the skill:
- Your worktree is your "main checkout" and `<epic>` is your `<defaultBranch>`; preflight accepts that. Your workers branch from `<epic>`; you merge them into it following merge.md (review, full checks, rebase notices).
- You never push, open PRs or merge into `<realDefaultBranch>`. merge.md's Push section does not apply.
- Model and skills are decided: workers run <model> and start with <skill, e.g. /implement>. Do not ask again.
- The epic and its sub-issues are <IDS>. Set their statuses as the skill says; leave the epic In Progress, the parent closes it.
- Order and parallelism come from the issue edges. Hand out the machine lock one worker at a time for timed runs or anything that swaps Mattia's app.
- Ask Mattia directly in this thread for hand checks and decisions, never through the parent.
- Report to the parent only when everything is done or you are blocked on the parent, via t3_thread_send, with: final branch and SHA, worktree clean, per-ticket summary, checks with real output, hand-check results, open decisions, unfixed findings filed as issues.
- AGENTS.md product rules still hold.
```

## Parent's job afterwards

- Review the whole epic diff (`git diff <defaultBranch>...<epic>`), focused on the shared hot paths.
- `git merge-tree --write-tree <defaultBranch> <epic>` must print a tree with no conflicts.
- Report to Mattia. Merge (merge.md) on his yes, push on a separate yes, then close the epic and settle the sub-tracer once it is merged.
- Its report can be wrong about Mattia's machine ("kept at his request" when it was its own choice). Verify claims about his environment.

## Rebase notice to a sub-tracer

When `<defaultBranch>` moves under it, or its base gets fixes: `t3_thread_send`, mode `queue`, a stable `clientRequestId`: "`<defaultBranch>` moved. Between tickets, merge it into your epic branch, rerun checks, and tell your running workers to rebase onto the epic branch."

## Starting on unmerged work

If the epic touches the same code as branches still waiting for hand checks, build its base from them without a worktree:

```
T=$(git merge-tree --write-tree A B)        # conflicts: stop, rehearse in int- (merge.md)
C=$(git commit-tree $T -p A -p B -m "<epic> base: A + B")
git branch <epic>-base $C
```

Launch with `baseRef` `<epic>-base` and say so in the brief. The epic now contains A and B: merge it only after they are accepted.
