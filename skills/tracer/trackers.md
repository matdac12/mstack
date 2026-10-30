# Trackers

Traccia is the only tracker.

- File new issues one at a time, then add the `blockedBy` links once they all exist. Never predict an issue id: another thread may take it first.
- A tracker error (a 502, a timeout): retry once after about 45 seconds. Still failing: tell Mattia, and keep the report in this chat until it can be written.

## Traccia

Tools: the `traccia` MCP. Run `whoami` first (expect actor `agent`). Default project key `TRC` (check `list_projects` for others).

- Search with `list_issues` / `query` before creating.
- Labels must exist (`list_issue_labels`). `labels` on `save_issue` replaces the whole set.
- No "blocked" status: use the `needs-info` label if the project has it, plus a comment saying what blocks it.
- `description` replaces the whole text. For issues several threads edit, fetch the latest and pass `expectedUpdatedAt`.
- Agents cannot purge; deleting is soft (`restore` undoes it).
- Knowledge layer: **memories** (titled markdown notes with tags) and **documents** (files). Read the relevant ones before briefing a worker (`list_memories`/`get_memory`; `list_documents`/`get_document`), and record durable facts with `save_memory` and files with `create_document`. Agents may purge memories and documents, unlike other types.
- Triage with Mattia: for each `needs-triage` issue give a recommendation (do, backlog with what would promote it, drop), apply his answer with a short decision comment, remove `needs-triage`.
- Old Linear identifiers (`MAT-nnn`) from the archive are findable by searching Traccia for that text. Look one up before telling anyone its TRC number; never assume a mapping.
- A milestone's description (its "Rules for agents") comes from `get_project` on the project, which returns every milestone with its full text. `list_milestones` does not return it. Read it before briefing a worker on that milestone, and point the brief at it (workers do the same through `get_project`).
- Branch naming: `trc-NNN-slug` in personal repos. Commit messages mention `TRC-NNN` (personal repos only). Client repos name the branch by the change (`euro-format`), with no key, and the issue records the branch (SKILL.md, Hard rules).
- Project description: `save_project` with the project's `id` (from `get_project`). Without `id` it creates a new project, even when you pass the key.

