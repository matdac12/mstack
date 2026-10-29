<div align="center">
  <!-- Banner goes here once the artwork is ready: <img src="assets/banner.png" alt="mstack"> -->
  <h1><samp>mstack</samp></h1>
  <p><em>An agentic toolbox for Windows.</em></p>
  <img alt="Platform: Windows" src="https://img.shields.io/badge/platform-windows-0b0f14?style=flat&amp;labelColor=0b0f14">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-ff9e0b?style=flat&amp;labelColor=0b0f14">
</div>

<br>

Small, sharp tools I build and use every day to work alongside coding agents: talk instead of type, track work with your agents, point at the screen, park files, keep music on, reach everything from one key.

Each tool is its own repo with its own history and releases. mstack is where they meet, plus the agent skills that drive them.

## Tools

| Tool | What it does | Built with |
| --- | --- | --- |
| [**parla**](https://github.com/matdac12/parla) | Dictation. Hold <kbd>Ctrl</kbd>+<kbd>Alt</kbd>, talk, and the transcript is pasted into the focused app. Cloud or fully local transcription. | Tauri · Rust · TypeScript |
| [**traccia**](https://github.com/matdac12/traccia) | A self-hosted issue tracker for you and your agents. Agents reach it over MCP; you use the dashboard. | TypeScript |
| [**annota**](https://github.com/matdac12/annota) | Annotated screenshots for agent chats. Drag a region, box what matters, add a note, paste one PNG. | Tauri · Rust · TypeScript |
| [**tasca**](https://github.com/matdac12/tasca) | A file shelf that slides out of the screen edge. Park files mid-drag, drag them out later. Tray icon, its own shortcut (<kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>D</kbd> by default), prebuilt `.exe` on its Releases page. | Rust · Win32 |
| [**hyperkey**](https://github.com/matdac12/hyperkey) | Caps Lock as a hyper key: open or focus apps, switch virtual desktops. | Python · AutoHotkey v2 |
| [**musica**](https://github.com/matdac12/musica) | Background music from YouTube, from the tray. Search, play, keep working. No browser tab, no ads. *Prototype.* | Rust · Win32 · mpv |
| [**scrivi**](https://github.com/matdac12/scrivi) | A minimal Notepad replacement. Every plain-text file opens in tabs in one window; markdown gets light styling and a rendered view on <kbd>Ctrl</kbd>+<kbd>E</kbd>. Prebuilt `.exe` on its Releases page. | Rust · Win32 |

They are separate apps that compose. Hyperkey is the glue: <kbd>Caps</kbd>+<kbd>S</kbd> opens annota, <kbd>Caps</kbd>+<kbd>D</kbd> opens tasca, <kbd>Caps</kbd>+<kbd>M</kbd> opens musica, <kbd>Caps</kbd>+<kbd>N</kbd> opens a new scrivi tab, and you dictate into annota's notes with parla like into any text box.

## Skills

Agent skills for [Claude Code](https://claude.com/claude-code) and other agents that read `SKILL.md` folders.

| Skill | What it does |
| --- | --- |
| [**tracer**](skills/tracer/SKILL.md) | Turns a [T3 Code](https://github.com/pingdotgg/t3code) session into an orchestrator: plans with you, spawns worker threads in their own worktrees, reviews and merges their branches, and keeps Linear or Traccia up to date. |
| [**close-the-day**](skills/close-the-day/SKILL.md) | Wraps up the day on a project: tidies the tracker (statuses checked against the code, descriptions, sub-issues, milestones), brings CLAUDE.md, AGENTS.md, docs and agent memories up to date, cleans up threads and dev servers, and writes the note and paste-in prompt the next session starts from. You invoke it yourself. |

More are on the way.

## Get the stack

```powershell
git clone https://github.com/matdac12/mstack
cd mstack
.\setup.ps1            # clone every tool next to this README
.\setup.ps1 -Skills    # also link the skills into ~\.claude\skills and ~\.agents\skills
```

`setup.ps1` only clones what is missing and never overwrites anything. Build and install steps live in each tool's README. To take a single skill, copy its folder from [`skills/`](skills) into `~\.claude\skills`.

```text
mstack/
├── skills/        agent skills, tracked here
├── hooks/         Claude Code hooks shared by every machine (the destructive-command guard)
├── tools.json     the tool manifest setup.ps1 reads
├── setup.ps1
└── parla/ traccia/ annota/ tasca/ hyperkey/ musica/ scrivi/  ← cloned by setup.ps1, each its own repo
```

## License

This repo and its skills are [MIT](LICENSE). Each tool is licensed in its own repo.

<sub>Built by [Mattia Da Campo](https://github.com/matdac12).</sub>
