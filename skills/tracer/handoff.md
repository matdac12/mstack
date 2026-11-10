# Handoff document for big kickoffs

For a brief longer than a screenful. The substance lives in a file; the worker's first message is a short pointer, never the contents.

**Where:** `docs/handoff/<YYYY-MM-DD>-<issue-id>-<slug>.md` in the main checkout (today's date from the environment; `-2`, `-3` if it exists). The worker's worktree will not contain this uncommitted file, so reference it by absolute path and tell the worker not to commit it. Plans and specs the worker must follow belong on the branch, not here.

**Rules:** reference specs, plans, issues and diffs by path or id instead of copying them. Redact secrets and personal data; name where a credential lives (env var and source), never the value. Write only what is true.
**Template:**

```markdown
# Task: <title>
**Date** · **Repo** · **Issue** · **Branch** (based on <defaultBranch>) · **Kind** (kinds.md; name the skill)

## What to do
First step: load your tracker's tools, or say in the report they are missing. Then 2-5 plain sentences.
## Context you need
Why, and background not obvious from the code.
## Read first
- `path` or URL: what to look for
## Ownership
Owns: <files; in a parallel wave, its own section of each shared doc>. Do NOT touch: <files, and who owns them>.
## Constraints
## Definition of done
Checklist with the commands to verify, ending with one in-thread review pass (kinds.md, Review layers). A hand check: which test data must be real (files that must open, a real account).
## Out of scope
## Reporting
<the line: read ~/.claude/skills/tracer/worker-rules.md first and follow it; then the report line from workers.md (Brief), word for word, with thread <ORCHESTRATOR_THREAD_ID> (and its environmentId on a linked machine)>
## Skill
<the implementing skill from kinds.md, plus any domain skill; required when the task writes code>
```

For continuing work already started, use instead: Goal, Where we are (say if tests failed or a step was skipped), Key decisions (and what was rejected), Open questions, Next steps, Files that matter.

**Message to the worker** (`t3_thread_launch` message or `t3_thread_send`):

```
Your task for <ISSUE-ID> is in /abs/path/docs/handoff/<file>.md (outside your worktree; do not commit it).
Read it first, then carry out the task. When it is done, your last act is one REPORT sent with `t3_thread_send` to thread <ORCHESTRATOR_THREAD_ID>, mode `queue` (its Reporting section).
```

Tell Mattia the path and which thread got it.
