# Handoff document for big kickoffs

For a brief longer than a screenful. The substance lives in a file; the worker's first message is a short pointer, never the contents.

**Where:** `docs/handoff/<YYYY-MM-DD>-<issue-id>-<slug>.md` in the main checkout (today's date from the environment; `-2`, `-3` if it exists). The worker's worktree will not contain this uncommitted file, so reference it by absolute path and tell the worker not to commit it. Plans and specs the worker must follow belong on the branch, not here.

**Rules:** reference specs, plans, issues and diffs by path or id instead of copying them. Redact secrets and personal data; name where a credential lives (env var and source), never the value. Write only what is true. List suggested skills only if they genuinely apply.

**Template:**

```markdown
# Task: <title>
**Date** · **Repo** · **Issue** · **Branch** (based on <defaultBranch>) · **Kind** (kinds.md; name the skill)

## What to do
2-5 plain sentences.
## Context you need
Why, and background not obvious from the code.
## Read first
- `path` or URL: what to look for
## Ownership
Owns: <files>. Do NOT touch: <files, and who owns them>.
## Constraints
## Definition of done
Checklist with the commands to verify.
## Out of scope
## Reporting
<the Rules and Report back blocks from workers.md, filled in, with the orchestrator thread id>
## Suggested skills
```

For continuing work already started, use instead: Goal, Where we are (say if tests failed or a step was skipped), Key decisions (and what was rejected), Open questions, Next steps, Files that matter.

**Message to the worker** (`t3_thread_launch` message or `t3_thread_send`):

```
Your task for <ISSUE-ID> is in /abs/path/docs/handoff/<file>.md (outside your worktree; do not commit it).
Read it first, then carry out the task. Its Reporting section says how to report to thread <ORCHESTRATOR_THREAD_ID>.
```

Tell Mattia the path and which thread got it.
