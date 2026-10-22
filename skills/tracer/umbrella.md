# Umbrella checkouts

For a main checkout that holds several tool repos, each its own git repo, listed in a `tools.json` manifest (mstack). Most projects are one repo and skip this file.

- Run preflight steps 1-2 for each tool repo the work touches, and keep a table: repo path, T3 `projectId`, default branch, unpushed commits.
- Find each tool's T3 project by matching `workspaceRoot` across every page of `t3_project_list` (follow the cursor) before concluding it is missing. Creating one needs full-access.
- Launch each worker in its own tool's T3 project; issue keys say which tool (the manifest and AGENTS.md map them).
- Every git command names its repo: `git -C <repo> ...`.
- Merge, verify and push per repo, with that repo's own checks and AGENTS.md.
