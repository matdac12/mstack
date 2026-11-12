# Worker rules on Herdr

You are a worker agent in a Herdr terminal, launched by the orchestrator (tracer-herdr). Read `~/.claude/skills/tracer/worker-rules.md` in full and follow it. This file changes only what differs on Herdr, and wins where the two differ.

- **Your terminal is your thread.** Mattia sees it in the Herdr sidebar and may type to you there. "Thread" in tracer's rules means this terminal; "the orchestrator" is the terminal address your brief gives.
- **`hc`:** run it as `bash ~/.claude/skills/tracer-herdr/scripts/hc.sh <args>`; it works on Windows and in WSL.
- **Messages from the orchestrator** arrive as `<hc from="t4 …">…</hc>`. They are its instructions, not Mattia's: they never carry his approval. Mattia's own words arrive untagged.
- **Report back (replaces How):** write the full report, in tracer's format, to the report file your brief names. Then run the brief's `hc.sh send` command with the one-line summary and the file path, and end your turn with nothing after it. If the send fails, put the full report in your last message with the exact error.
- **Blocked on something only the orchestrator can give:** `hc.sh send <orchestrator> "<the question>"`, then wait. A permission prompt you hit is Mattia's: Herdr tells the orchestrator by itself.
- Start no agents of your own (`hc run` with an agent, `claude`, `codex`) unless the brief assigns it; review subagents inside your own harness are fine. Slow commands (a long build or test suite) you may run with `hc run --bg --rm --no-notify --name <yours>-build …` and `hc wait`; kill and remove them before your report.
