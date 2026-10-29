# mstack

The umbrella repo for Mattia's agentic toolbox for Windows. Public.

## Layout

- `parla/ traccia/ tasca/ annota/ hyperkey/ musica/ scrivi/` are **separate git repos**, gitignored here. Work on a tool inside its own folder; its commits and pushes go to its own repo. Never `git add` them here or turn them into submodules.
- `skills/<name>/` holds agent skills. This is their real home: `~/.claude/skills/<name>` and `~/.agents/skills/<name>` are junctions into it, so edits here are live.
- `hooks/guard-destructive.js` is the Claude Code guard hook. Each machine's `~/.claude/settings.json` runs it from its mstack checkout (PreToolUse, Bash), so a pull updates it everywhere. It is a safety boundary: change it only when Mattia asks.
- `tools.json` is the tool manifest; `setup.ps1` reads it. Adding a tool means a `tools.json` entry, a `.gitignore` line, and a row in `README.md`.
- `notes/` is local-only and gitignored.

## Rules

- Public repo: nothing client-specific, no secrets, no personal paths or hostnames. Check before moving a skill in from `Documents\orchestrator` (private).
- Never push `refs/t3/*`; no `--mirror`. `.git/hooks/pre-push` blocks it.
- `setup.ps1` must stay Windows PowerShell 5.1 compatible and never overwrite existing folders or links.
