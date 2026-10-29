# Remote machines

Linked T3 environments are Mattia's other machines. They are optional: an extension of this machine for heavy work, not a second orchestrator. Planning, review, merge and every push to origin stay with you, here. What each machine is good at, its SSH target and where its repos live: `~/.t3/machines.md`, private and local; never copy it into a tracked file.

## When

Propose a linked machine for:
- Machine-heavy or long work: full builds, test suites, CI-style and Docker runs, E2E runs, dependency-heavy installs, big refactors.
- Reproducing a bug Mattia only sees on that machine.
- A dev server running somewhere Mattia can open a URL for a hand check.

Anything else runs here, as usual. A hand check never keeps work off a linked machine: the preview reaches Mattia as a tailnet link (Previews).

## Checking it

- Preflight calls `t3_environment_links` once and keeps label → `environmentId`. Check again, silently, right before each proposal.
- Resolve a machine by its label every session. Never hardcode or save an id: re-linking changes it.
- Not `reachable` (expired, unreachable), or no SSH target in machines.md: say nothing, propose nothing, run the work here. Never work around it.

## Proposing

- At his desk, Mattia decides. Reachable and the task fits: propose it in one line with the reason, taken from machines.md ("TRC-160 runs the Docker E2E suite; the Linux box does that faster. Run it there?").
- Name in the same line anything in the way: a provider you would pick is missing there, or the repo is not cloned there yet (offer to clone it).
- Away mode: you decide, and your summary says what ran where. Anything in the way is parked (SKILL.md, Away mode).
- Never anything silently: a failed launch or sync, a missing provider, a machine that drops mid-task. Tell Mattia; he fixes it.

## Reaching it

- That machine has its own logins and provider list. Before the first launch there, call `orchestrator_capabilities({ environmentId })` once and keep its model ids. A provider absent or listed with a constraint (not authenticated, disabled) is missing: tell Mattia. Never swap the model yourself.
- Models: the workers.md table and choosing rules. `instanceId` is that machine's `providerInstanceId`.
- Project: find it with `t3_project_list({ environmentId })`, matching `repositoryIdentity.canonicalKey` (paths differ between machines). Its `workspaceRoot` is the remote checkout. Not there: on Mattia's yes, `t3_project_clone` it into the folder machines.md names, then `t3_project_create` with the same `environmentId`.
- A thread Mattia sees: `t3_thread_launch` with `environmentId`, the project's `projectId`, `runtimeMode: "full-access"` and always an explicit `modelSelection`. A project there may have no default model, and the launch then fails with "the project has no default model".
- Work with no repo: `scratch: true`.
- Short parented jobs you consume yourself (one build, one test run, a repro): `delegate_task` with `target.environmentId`.

## Before each launch

Code and files move over SSH (`<ssh>` and `<root>`: machines.md and the project's `workspaceRoot`), never through origin. Any step failing: stop and tell Mattia.
1. Sync your `<defaultBranch>`: `git push <ssh>:<root> +<defaultBranch>:refs/heads/local/<defaultBranch>`. This is a sync, not a publish: no yes needed, unpushed commits included.
2. Private notes: copy the project's private notes (SKILL.md, Preflight 5) into `~/.t3/private/<repo>/` there, replacing the old copy. One-way: lessons go to the tracker, not into the copy.
3. Env files: copy the repo's untracked `.env*` files into `<root>` at the same relative paths (`git ls-files -oi --exclude-standard --directory | grep -E '(^|/)\.env[^/]*$'`, piped through `tar` over SSH; `--directory` keeps out copies inside build folders and nested worktrees). Never print them. Other data (dumps, fixtures) only when Mattia asks for that task.

## Still a worker

- Same brief (workers.md, Brief), same fixed report. The brief names the machine, gives your thread id plus this machine's `environmentId` (top level of `t3_environment_links`) so the report reaches you, points to `~/.t3/private/<repo>/` for private notes, and tells the worker to copy the `.env*` files from `<root>` into its worktree first. If its report send fails, it posts the report as its last message with the exact error; the heartbeat picks it up, and you tell Mattia the link back to this machine needs re-linking.
- Tracker: Claude and OpenCode workers there have Traccia and set In Progress as usual. Codex there has no tracker: its brief says no tracker calls, and you record for it.
- One worktree per issue in that machine's checkout, branch `<issue-id>-slug` as here: `{"type":"worktree","baseRef":"local/<defaultBranch>","branch":"<branch>","startFromOrigin":false}`. It owns its files, never merges, never publishes.
- Rebase notices: sync `local/<defaultBranch>` first (Before each launch, step 1), then tell the worker to rebase onto it.
- Heartbeat: as for a local worker, with git run over SSH (workers.md, Heartbeat).

## Bringing work back

- A remote worker never pushes to origin. It commits on its branch and reports.
- You fetch it over SSH: `git fetch <ssh>:<root> +<branch>:<branch>`. Then review and merge it locally (merge.md), like a local branch.
- At cleanup (merge.md), remove its worktree and branch there over SSH too.
- Pushing to origin stays yours, on Mattia's yes or grant (SKILL.md, Hard rules).

## Previews

- The dev server listens on all interfaces (`0.0.0.0`). The link is `http://<tailscale name>:<port>`; machines.md gives the name.
- Plain http by default. Use `tailscale serve` (https) only when the app needs a secure origin (login redirects, clipboard, camera, service workers), and say so in the report.
- A dev server that checks the Host header must allow the tailscale name: Vite `server.allowedHosts`, Next.js `allowedDevOrigins`. Use an untracked config where the tool allows one; otherwise name the one-line change in the report instead of committing it.
- Before you hand Mattia the link, open it from here (`curl`) and confirm it answers.
- The preview lives with the worker's thread. It stops when that thread is settled, once Mattia confirms the area of work is done (merge.md, Settle); `tailscale serve` goes with it. A preview still running after that, you stop.

## Live mode

Only on Mattia's yes. For a session of small visual tweaks on a running preview, ask once: "quick iteration in live mode?" Otherwise the normal flow.
- One preview, served from that machine's checkout of `<defaultBranch>`. Workers edit and commit there directly, with no branch or worktree; two run at once only on disjoint files.
- Mattia checks live; there is no per-task merge. While it lasts, that checkout holds the newest code: sync nothing onto it.
- At the end, fetch that `<defaultBranch>` back over SSH, verify the build here, and push on his yes.

## Never

- Answer a remote permission prompt for Mattia.
- Run a command a guard hook blocked.
- Deploys or migrations, repo visibility or tokens.
- Move a client repo's source of truth to that machine, except for a live mode session Mattia said yes to.

## Reporting and hygiene

- When you report, name the machine in one clause and say where the output lives: a path there, a branch there, or a URL.
- Scratch threads land under that machine's "No project" scratch root. Settle remote threads when done (merge.md, Settle).
- Leave no server or watcher running there unless Mattia asked for it or a preview still waits for his look (Previews).
