# Trackers

Read only the section for the tracker chosen at the start of the session.

## Traccia

Tools: the `traccia` MCP. Run `whoami` first (expect actor `agent`). Default project key `TRC` (check `list_projects` for others).

- Search with `list_issues` / `query` before creating.
- Labels must exist (`list_issue_labels`). `labels` on `save_issue` replaces the whole set.
- `description` replaces the whole text. For issues several threads edit, fetch the latest and pass `expectedUpdatedAt`.
- Agents cannot purge; deleting is soft (`restore` undoes it).
- Knowledge layer: **memories** (titled markdown notes with tags) and **documents** (files). Read the relevant ones before briefing a worker (`list_memories`/`get_memory`; `list_documents`/`get_document`), and record durable facts with `save_memory` and files with `create_document`. Agents may purge memories and documents, unlike other types.
- Triage with Mattia: for each `needs-triage` issue give a recommendation (do, backlog with what would promote it, drop), apply his answer with a short decision comment, remove `needs-triage`.
- Linear identifiers (`MAT-nnn`) from the old archive are findable by searching Traccia for that text. Look one up before telling anyone its TRC number; never assume a mapping.
- Branch naming: `trc-NNN-slug`. Commit messages mention `TRC-NNN`.

## Linear

Tools: the `linear` MCP (`mcp__linear__*`; load schemas with ToolSearch first).

- Find the team with `list_teams`; search `list_issues` before creating with `save_issue`.
- Statuses come from `list_issue_statuses` for the team; use only names that exist (map In Progress / In Review / Done / blocked onto them; no "blocked" status means comment plus an existing label).
- Labels via `list_issue_labels`; do not create one without Mattia's say-so.
- Comments with `save_comment` (short decision notes, branch and commit). Put the issue id in the branch name.
- Branch naming: the issue's `gitBranchName` from `get_issue`. Commit messages mention `<ID>`.
- Follow the repo's `AGENTS.md` if it adds Linear conventions (it wins).
