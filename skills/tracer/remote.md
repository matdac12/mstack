# Remote machines

Linked T3 environments are Mattia's other machines. They are optional: an extension of this machine for heavy work, not a second orchestrator. Planning, review, merge and every push to origin stay with you, here. What each machine is good at, its SSH target and where its repos live: `~/.t3/machines.md`, private and local. Its names (labels, host names, `local/<defaultBranch>`) stay out of every tracked file, commit message and tracker issue text: they mean nothing to anyone else. merge.md's leak check catches the host names.

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
- The guard hook protects Claude workers there only if that machine's `~/.claude/settings.json` runs mstack's `hooks/guard-destructive.js` (machines.md says how). Before the first launch, check it over SSH (`grep -c guard-destructive ~/.claude/settings.json`); missing: tell Mattia before launching. Codex and OpenCode workers have no guard on any machine.
- Models: the workers.md table and choosing rules. `instanceId` is that machine's `providerInstanceId`.
- Project: find it with `t3_project_list({ environmentId })`, matching `repositoryIdentity.canonicalKey` (paths differ between machines), else the `workspaceRoot` folder name: a just-created project has no identity yet. Its `workspaceRoot` is the remote checkout. Not there: on Mattia's yes, seed it over SSH, never from GitHub: `git init -b <defaultBranch> <root>` there, sync (Before each launch, step 1), `git -C <root> merge --ff-only local/<defaultBranch>` and `git remote add origin <your origin url>` there, then `t3_project_create` with the same `environmentId`, and keep the `projectId` it returns.
- A thread Mattia sees: `t3_thread_launch` with `environmentId`, the project's `projectId`, `runtimeMode: "full-access"` and always an explicit `modelSelection`. A project there may have no default model, and the launch then fails with "the project has no default model".
- Work with no repo: `scratch: true`.
- Short parented jobs you consume yourself (one build, one test run, a repro): `delegate_task` with `target.environmentId`.
- Every T3 call about a remote thread (read, list, wait, send, pending requests, settle) carries that machine's `environmentId`; without it the call looks here. `t3_thread_list` there also needs the `projectId`. `t3_project_list` is unfiltered and large: look the project up once and keep its id. The work map names the machine per task.

## Before each launch

Code and files move over SSH (`<ssh>` and `<root>`: machines.md and the project's `workspaceRoot`), never through origin. Any step failing: stop and tell Mattia.
1. Sync your `<defaultBranch>`, as its own command: `bash ~/.claude/skills/tracer/scripts/land.sh sync <repo root> <ssh> <root>` (a `git push` to `local/<defaultBranch>` there, never forced). This is a sync, not a publish: no yes needed, unpushed commits included. Rejected: something moved `local/<defaultBranch>` there; stop and ask Mattia. When the sync brought a lockfile change, fast-forward that machine's main checkout (`merge --ff-only local/<defaultBranch>`, only if clean) and run the frozen install there (`npm ci`), so its workers can reuse it.
2. Private notes: copy the project's private notes (SKILL.md, Preflight 5) into `~/.t3/private/<repo>/` there, replacing the old copy. A big task's handoff file (handoff.md) goes there too, and the launch pointer names that path. One-way: lessons go to the tracker, not into the copy.
3. Env files: copy the repo's untracked `.env*` files into `<root>` at the same relative paths (`git ls-files -oi --exclude-standard --directory | grep -E '(^|/)\.env[^/]*$'`, piped through `tar` over SSH). Then each must be ignored there: `git -C <root> check-ignore -q <path>`, else append the path to `<root>/.git/info/exclude`, so no worker commits it. Never print them. Other data (dumps, fixtures) only when Mattia asks for that task.
4. Skills: `git -C <mstack checkout there> pull --ff-only` (machines.md gives the path), so `worker-rules.md`, the scripts and the guard match yours. A failed pull: tell Mattia.

## Still a worker

- Same brief (workers.md, Brief), same fixed report. The brief names the machine (worker-rules.md keeps that name out of everything committed), gives your thread id plus this machine's `environmentId` (top level of `t3_environment_links`) so the report reaches you, points to `~/.t3/private/<repo>/` for private notes, and tells the worker to copy the `.env*` files from `<root>` into its worktree first. If its report send fails, it posts the report as its last message with the exact error: read it there, and tell Mattia the error.
- Tracker: the session's tracker, if that agent has it on that machine (machines.md); otherwise its brief says no tracker calls, and you record for it.
- One worktree per issue in that machine's checkout, branch named as here (trackers.md; a client repo names it by the change): `{"type":"worktree","baseRef":"local/<defaultBranch>","branch":"<branch>","startFromOrigin":false}`. It owns its files, never merges, never publishes.
- Rebase notices and merge conflicts (merge.md, step 3): sync `local/<defaultBranch>` first; the worker rebases onto it, or you resolve in its worktree there over SSH against `local/<defaultBranch>`. Then fetch again.
- Heartbeat: as for a local worker, with git run over SSH (workers.md, Heartbeat).

## Bringing work back

- A remote worker never pushes to origin. It commits on its branch and reports.
- Fetch it into its own ref, never onto a local branch: `git fetch <ssh>:<root> +<branch>:refs/remotes/<label>/<branch>`. Check it matches the reported SHA, then review and merge from that ref (merge.md; `land.sh merge` with the remote arguments fetches, checks and deletes the ref for you).
- At cleanup, remove its worktree and branch on that machine with the cleanup script over SSH (merge.md, Clean up). merge.md's "Mattia's OK" for branches on origin does not apply here.

## Previews

- A preview runs from its own detached worktree on that machine (`git worktree add --detach ~/.t3/worktrees/<repo>/preview-<what> <ref>`), never from a main checkout: cleanup fast-forwards the main checkout, and new code would hot-reload under Mattia's hand check. Remove that worktree when the preview stops. Live mode (below) is the one exception.
- After a merge that adds a migration, the preview's database lacks it. Migrating it is a migration on shared data: ask Mattia first.
- The dev server listens on the tailnet address only (`tailscale ip -4` there), not `0.0.0.0`, which also exposes it to the home network. The link is `http://<tailscale name>:<port>`; machines.md gives the name.
- Plain http by default. Use `tailscale serve` (https) only when the app needs a secure origin (login redirects, clipboard, camera, service workers), and say so in the report.
- A dev server that checks the Host header must allow the tailscale name: Vite `server.allowedHosts`, Next.js `allowedDevOrigins`. Use an untracked config where the tool allows one; otherwise name the one-line change in the report instead of committing it.
- Web plus API: the page runs in Mattia's browser, where `localhost` is his laptop. Point the API URL at the tailscale name too, in the same untracked config, and allow that origin in the API's CORS.
- Before you hand Mattia the link, open it from here (`curl`): that is the real tailnet test. Then have a worker load it in a real browser (agent-browser, about 30 seconds: the page renders and its data loads). A worker on that same machine pins the tailnet IP (`curl --resolve`, agent-browser `--host-resolver-rules`): there the tailnet name resolves to loopback. Only then send it.
- A design thread there keeps its visual companion: served on the tailnet address the same way, and the thread gives Mattia the link.
- A worker asked for a preview leaves it running past its turn (its brief exempts it from the no-background-job rule) and reports its PID. It stays up while the hand check is owed. When you settle that thread (merge.md, Settle), stop the preview by that PID, `tailscale serve` included.

## Live mode

Only on Mattia's yes. For a session of small visual tweaks on a running preview, ask once: "quick iteration in live mode?" Otherwise the normal flow. Never in away mode: live mode exists for him to watch.
- Start: no other worker on that repo, both checkouts clean. Sync, then `git -C <root> merge --ff-only local/<defaultBranch>` there; a divergence means stop and ask. Your `<defaultBranch>` takes no commits until the end.
- One preview, served from that checkout. Workers edit and commit there directly; this overrides the brief's worktree and branch lines. Usually one worker; two only on disjoint files, each committing only its own files by path.
- Mattia checks live; there is no per-task merge.
- End: fetch that `<defaultBranch>` into `refs/remotes/<label>/<defaultBranch>`, review the diff since the start, fast-forward yours to it, verify the build here, push on his yes.

## Never

- SKILL.md's hard rules apply on that machine too.
- Move a client repo's source of truth to that machine, except for a live mode session Mattia said yes to.

## Reporting and hygiene

- When you report, name the machine in one clause and say where the output lives: a path there, a branch there, or a URL.
- Scratch threads land under that machine's "No project" scratch root. Settle remote threads when done (merge.md, Settle).
- Leave no server or watcher running there unless Mattia asked for it or a preview still waits for his look (Previews).
