#!/usr/bin/env node
// Global PreToolUse hook for Bash: blocks destructive commands that have
// cost time in past sessions (e.g. `supabase db reset` wiping seeded test
// data). Emits exit code 2 so Claude sees the reason on stderr and
// can explain to the user instead of retrying.
//
// Shared by every machine: each one points the PreToolUse Bash hook in its
// ~/.claude/settings.json at this file in its mstack checkout.
//
// This complements the deny list in settings.json — deny blocks outright,
// this hook explains and teaches Claude to ask first.

const { execSync } = require("child_process");
const path = require("path");

function gitOut(args, cwd) {
  try {
    return execSync(`git ${args}`, {
      cwd,
      stdio: ["ignore", "pipe", "ignore"],
    })
      .toString()
      .trim();
  } catch {
    return "";
  }
}

// A linked worktree has a --git-dir under <main>/.git/worktrees/<name>,
// distinct from --git-common-dir (the shared <main>/.git). In the main
// checkout the two are identical.
//
// `--path-format=absolute` is not decoration. Without it, git answers these
// two in whatever form is shortest for the cwd: from the repo root both come
// back as `.git`, but from a subdirectory --git-dir is absolute while
// --git-common-dir is relative (`../.git`). Resolving them by hand then
// compares git's own normalised spelling of the path against the shell's,
// and on Windows those differ whenever the cwd was typed with different
// capitalisation — the filesystem doesn't care, string equality does. The
// result was a guard that blocked legitimate merges from the main checkout
// depending only on which directory the shell happened to be in (24/08).
function isWorktreeCwd(cwd) {
  const gitDir = gitOut("rev-parse --path-format=absolute --git-dir", cwd);
  const commonDir = gitOut(
    "rev-parse --path-format=absolute --git-common-dir",
    cwd
  );
  if (!gitDir || !commonDir) return false; // not a git repo — fail open
  return path.resolve(gitDir) !== path.resolve(commonDir);
}

const MAIN_BRANCHES = new Set(["main", "master"]);

// Returns a reason string if this command would land changes on main/master
// from inside a worktree, or "" if it's safe to proceed.
function checkMainWorktreeRisk(cmd, cwd) {
  if (!isWorktreeCwd(cwd)) return "";

  const isPush = gitRe(String.raw`push\b`).test(cmd);
  const isMergeOrRebase = gitRe(String.raw`(merge|rebase)\b`).test(cmd);

  // Push explicitly naming main/master as the destination ref, e.g.
  // `git push origin main`, `git push origin HEAD:main`, or the full
  // refspec form `git push origin HEAD:refs/heads/main` — regardless of
  // which branch is currently checked out.
  if (isPush && gitRe(String.raw`push\b.*[:\s/](main|master)(?:\s|$)`).test(cmd)) {
    return "`git push` targeting main/master from a worktree.";
  }

  // Any push/merge/rebase while this worktree somehow has main/master
  // checked out (git normally refuses this while main is checked out in
  // the primary checkout, but don't rely solely on that).
  const branch = gitOut("rev-parse --abbrev-ref HEAD", cwd);
  if ((isPush || isMergeOrRebase) && MAIN_BRANCHES.has(branch)) {
    return `${isPush ? "push" : "merge/rebase"} from a worktree that has \`${branch}\` checked out.`;
  }

  return "";
}

// `git` plus any global options before the subcommand
// (`git -C <path> branch -D`, `git -c k=v push --force`).
const GIT = String.raw`\bgit(?:\s+(?:-[Cc]\s+(?:"[^"]*"|'[^']*'|\S+)|--[\w-]+(?:=\S+)?))*\s+`;
function gitRe(rest) {
  return new RegExp(GIT + rest);
}

// Rules match one command at a time, so a flag from a later command in a
// chain (`git push ...; docker images -f ...`) is not read as a push flag.
function segments(cmd) {
  return cmd.split(/&&|\|\||[;|\n]/);
}

let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => (input += chunk));
process.stdin.on("end", () => {
  try {
    const data = JSON.parse(input || "{}");
    if (data.tool_name !== "Bash") process.exit(0);
    const cmd = (data.tool_input && data.tool_input.command) || "";
    if (!cmd) process.exit(0);

    // Orchestrator invariant: only the orchestrator (running from the main
    // checkout) may land changes on main/master. Worker agents run inside a
    // per-task git worktree and must never push or merge/rebase there.
    for (const seg of segments(cmd)) {
      if (!gitRe(String.raw`(push|merge|rebase)\b`).test(seg)) continue;
      const worktreeCheck = checkMainWorktreeRisk(seg, data.cwd || process.cwd());
      if (worktreeCheck) {
        process.stderr.write(
          `BLOCKED by the guard hook (mstack hooks/guard-destructive.js)\n` +
            `Reason: ${worktreeCheck}\n` +
            `Command: ${cmd}\n` +
            `Next step: only the orchestrator merges/pushes to main, and only from the main checkout. If this cwd is a worker's task worktree, report done/blocked instead and let the orchestrator handle the merge.\n`,
        );
        process.exit(2);
      }
    }

    const rules = [
      {
        re: /\bsupabase\s+db\s+reset\b/,
        reason:
          "`supabase db reset` wipes the local database (including seeded test data). Confirm with the user first.",
      },
      {
        re: gitRe(String.raw`reset\s+--hard\b`),
        reason:
          "`git reset --hard` discards uncommitted work. Confirm with the user first.",
      },
      {
        re: gitRe(String.raw`push\s+(?!.*--force-with-lease)(?:.*\s)?(?:--force\b|-f\b)`),
        reason:
          "`git push --force` rewrites remote history. Use `--force-with-lease` or confirm first.",
      },
      {
        re: gitRe(String.raw`clean\s+-[a-z]*f`),
        reason:
          "`git clean -f` deletes untracked files (possibly WIP). Confirm first.",
      },
      {
        re: gitRe(String.raw`branch\s+(?:.*\s)?-D\b`),
        reason:
          "`git branch -D` force-deletes a branch even if unmerged. Confirm first.",
      },
      {
        re: /\brm\s+-[rRf]*f[rRf]*\s+(\/|\/[ch]\/?|~\/?|C:\\?)(\s|$)/i,
        reason: "`rm -rf` targeting a root/home/system drive.",
      },
      {
        re: /\bDROP\s+DATABASE\b/i,
        reason: "`DROP DATABASE` is permanent. Confirm first.",
      },
      {
        re: /\bDROP\s+TABLE\b/i,
        reason: "`DROP TABLE` is permanent. Confirm first.",
      },
      {
        re: /\bTRUNCATE\s+(TABLE\s+)?/i,
        reason: "`TRUNCATE` empties a table. Confirm first.",
      },
      {
        re: /--no-verify\b/,
        reason:
          "`--no-verify` skips pre-commit hooks. Fix the underlying issue instead, or ask the user to authorize.",
      },
    ];

    for (const { re, reason } of rules) {
      if (segments(cmd).some((seg) => re.test(seg))) {
        process.stderr.write(
          `BLOCKED by the guard hook (mstack hooks/guard-destructive.js)\n` +
            `Reason: ${reason}\n` +
            `Command: ${cmd}\n` +
            `Next step: explain to the user what you intended to do and why, then wait for explicit confirmation before retrying. Do not try to bypass this hook.\n`,
        );
        process.exit(2);
      }
    }
    process.exit(0);
  } catch {
    // Never block on parse errors — fail open.
    process.exit(0);
  }
});
