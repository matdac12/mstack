# Remote machines

Linked T3 environments are Mattia's other machines. They are optional: an extension of this machine for heavy work, not a second orchestrator. Planning, review, merge and the push of `<defaultBranch>` stay with you, here. What each machine is good at and where its repos live: `~/.t3/machines.md`, private and local; never copy it into a tracked file.

## When

Propose a linked machine for:
- Machine-heavy or long work: full builds, test suites, CI-style and Docker runs, E2E runs, dependency-heavy installs, big refactors.
- Reproducing a bug Mattia only sees on that machine.
- A dev server running somewhere Mattia can open a URL for a hand check.

Anything else runs here, as usual. A hand check never keeps work off a linked machine: the preview reaches Mattia as a tailnet link (Previews).

## Checking it

- Preflight calls `t3_environment_links` once and keeps label → `environmentId`. Check again, silently, right before each proposal.
- Resolve a machine by its label every session. Never hardcode or save an id: re-linking changes it.
- Not `reachable` (expired, unreachable): say nothing, propose nothing, run the work here. Never work around it.

## Proposing

- At his desk, Mattia decides. Reachable and the task fits: propose it in one line with the reason, taken from machines.md ("TRC-160 runs the Docker E2E suite; the Linux box does that faster. Run it there?").
- Name in the same line anything in the way: `<defaultBranch>` has unpushed commits (that machine sees only origin, so the worker would start from older code), a provider you would pick is missing there, or the repo is not cloned there yet (offer to clone it).
- Away mode: you decide, and your summary says what ran where. Anything in the way is parked (SKILL.md, Away mode).
- Never anything silently: a failed launch, a missing provider, a machine that drops mid-task. Tell Mattia; he fixes it.

## Reaching it

- That machine has its own logins and provider list. Before the first launch there, call `orchestrator_capabilities({ environmentId })` once and keep its model ids. A provider absent or listed with a constraint (not authenticated, disabled) is missing: tell Mattia. Never swap the model yourself.
- Models: the workers.md table and choosing rules. `instanceId` is that machine's `providerInstanceId`.
- Project: find it with `t3_project_list({ environmentId })`, matching `repositoryIdentity.canonicalKey` (paths differ between machines). Not there: on Mattia's yes, `t3_project_clone` it into the folder machines.md names, then `t3_project_create` with the same `environmentId`.
- A thread Mattia sees: `t3_thread_launch` with `environmentId`, the project's `projectId`, `runtimeMode: "full-access"` and always an explicit `modelSelection`. A project there may have no default model, and the launch then fails with "the project has no default model".
- Work with no repo: `scratch: true`.
- Short parented jobs you consume yourself (one build, one test run, a repro): `delegate_task` with `target.environmentId`.

## Still a worker

- Same brief (workers.md, Brief), same fixed report, tracker calls fine. The brief names the machine and gives your thread id plus this machine's `environmentId` (top level of `t3_environment_links`), so the report reaches you.
- One worktree per issue in that machine's checkout: `{"type":"worktree","baseRef":"<defaultBranch>","branch":"<branch>","startFromOrigin":true}`. It owns its files, never merges, never publishes.
- Branch: `<issue-id>-slug` in a personal repo, the slug alone in a client repo (a pushed branch is visible to the client; the tracker records the branch name).
- Rebase notices: it rebases onto `origin/<defaultBranch>`. Unpushed commits on your `<defaultBranch>`: tell Mattia first.
- Heartbeat: read its thread; you cannot run git there (workers.md, Heartbeat).

## Pushing

- A remote worker pushes its own branch to origin once its work is committed, without asking. Only its own branch, never `<defaultBranch>`.
- You fetch it (`git fetch origin <branch>`), review and merge it locally (merge.md), like a local branch.
- When you push `<defaultBranch>` after the merge (Mattia's yes or grant), delete the merged branch from origin in the same step.
- That push is never a route around a guard hook or a permission prompt.

## Previews

- The dev server listens on all interfaces (`0.0.0.0`). The link is `http://<tailscale name>:<port>`; machines.md gives the name.
- Plain http by default. Use `tailscale serve` (https) only when the app needs a secure origin (login redirects, clipboard, camera, service workers), and say so in the report.
- Before you hand Mattia the link, open it from here (`curl`) and confirm it answers.
- Once Mattia has looked, the worker that started the preview stops it, `tailscale serve` included. A preview still running after that, you stop.

## Never

- Answer a remote permission prompt for Mattia.
- Run a command a guard hook blocked.
- Deploys or migrations, repo visibility or tokens.
- Move a client repo's source of truth to that machine.

## Reporting and hygiene

- When you report, name the machine in one clause and say where the output lives: a path there, a branch on origin, or a URL.
- Scratch threads land under that machine's "No project" scratch root. Settle remote threads when done (merge.md, Settle).
- Leave no server or watcher running there unless Mattia asked for it or a preview still waits for his look (Previews).
