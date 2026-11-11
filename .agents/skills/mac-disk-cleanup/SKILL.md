---
name: mac-disk-cleanup
description: Use when a Mac is low on disk space, the user asks what is taking up space, asks to "free up space", "clean up my computer", "clear disk", or a build, Docker, or download fails with "No space left on device" / ENOSPC. Covers developer machines with many git clones, worktrees, agent run outputs, caches, Docker, and IDEs.
---

# Mac Disk Cleanup

## Overview

Find where the space went, compare it with what the user actually used recently, and free it in tiers from safe to risky. **Measure first, protect unsaved work, ask for anything you cannot rebuild, and verify the result.** Never delete because a folder is big. Delete because it is rebuildable, stale under the user's rules, or approved by the user.

## Default rules (confirm or replace with the user's own)

| Tier | What | Action |
|---|---|---|
| A. Rebuildable | Tool caches with their own cleaner (npm, pnpm, pip, uv, Go, Homebrew, CocoaPods, Yarn); Playwright browsers; app updater caches | Delete without asking |
| B. Safe by rule | Git checkouts with `merged=yes`, `unpushed=0`, `dirty=0`, `inuse=no`, `ignored` under ~50M (nothing to lose, any age). Checkouts with last commit **and** last uncommitted edit 30+ days ago (back up first). Our own scratch and run-output folders whose newest file is 21+ days old, **including LLM/API outputs** (age wins) | Delete after the safety checks below |
| C. Ask first | Run outputs or caches **newer** than 21 days that cost money or hours to build; **client data and client deliverables at any age** (unless the user's own rule says otherwise); checkouts with non-rebuildable `ignored` files or `.env` files; Docker VM; whole apps and SDKs; unmerged recent checkouts; anything you cannot classify | Ask (see step 7) |

**Never touch:** anything with `inuse=yes`, or that contains or sits inside a path under "Folders in use", or that was committed or edited in the last 24 hours (an agent may be running there), the repo you are running in, Photos, Mail, Messages, iCloud Drive, Keychains, browser profiles, `.env` files and secrets folders, agent transcripts and memory (`~/.claude/projects`, `~/.codex/sessions`), and git branches (remove worktrees, keep branches).

## Workflow

0. **Set a target.** Ask how much space the user needs, or use "until 20% free" by default. If they already have that, report the findings and stop unless they want more.
1. **Measure.** Run `scripts/scan.sh` (read-only, about 3 minutes). Run it in the background if your shell times out. It prints:
   - free space and the top folders
   - cache folders and the real size of the Docker VM
   - each app's last-opened date
   - folders that a running process is using
   - every git checkout, with its size, last commit, unpushed and uncommitted counts, and whether it is merged
2. **Account for the gap.** Compare the scan totals with "used" in `df`. macOS privacy (TCC) blocks `du` from Photos, Mail, Messages, and iCloud Drive, so 50–100 GB can be invisible. Tell the user to check System Settings → General → Storage for that part. Do not guess.
3. **Drill into the top 3–5 buckets** with `du -xsh <dir>/* <dir>/.[!.]* | sort -rh | head`. Include the dot folders: `.git`, `.claude/worktrees`. Big single folders are usually run outputs or a Docker VM, not code.
4. **Compare with recent use.**
   - **Checkouts:** use the last commit date and the uncommitted count. A file's modification date is not a usage signal, because a fresh checkout gives every file a new date.
   - **Run folders:** use the newest file inside, with `find <dir> -type f -newermt <date> | head -1`.
   - **Apps:** use `kMDItemLastUsedDate`. `(null)` means Spotlight has no record. It does not prove the app is unused, so those apps are tier C.
   - **Squash merges:** `merged=no` can be wrong for squash-merged branches. Check with `gh pr list --head <branch> --state merged`.
5. **Tier A now.** Run `scripts/clean_caches.sh`. App cache folders that have no cleaner go into the delete list.
6. **Tier B, with safety checks:**
   - **Checkouts:** run `scripts/backup_unsaved.sh <path> <backup-dir>`. Remove the checkout only if it exits 0. Exit 1 with an `ignored:` list means git-ignored data would be lost: put it in tier C, and re-run with `ALLOW_IGNORED=1` only after the user approves. To remove a worktree, run it from the main repo: `git -C <main-repo> worktree remove <path>` (add `--force` only after a successful backup). Standalone clones go into the delete list; their bundle holds every local branch and the stash.
   - **Run folders:** before deleting folder X, search the folders you keep (sibling runs, `maps/`, `release/`, the repo's code) for X's parent and name together, e.g. `basemap/b6-thirty`. A bare name like `harness` matches too much. Use `grep -rIlF --exclude-dir=node_modules --exclude-dir=.git "<parent>/<X>" <keep dirs>` (`-I` skips binaries and searches every text type). Loop in Python or over a list file, not in zsh. If a release or package names X, keep X. If only score or report files cite X, you can delete it, because those files stay.
7. **Tier C: ask once.** Each item needs its size, last-used date, and what the user loses. The question tool allows at most 4 options per question and 4 questions per call. Group items by kind (run outputs, worktrees, apps, Docker) and use multi-select.
8. **Delete.** Write the approved absolute paths to a list file, one per line. Preview with `scripts/delete_listed.sh <list> --dry-run`, then run it without `--dry-run`. If a hook or permission rule blocks recursive deletes, **do not route around it** with Python, `find -delete`, or similar. Give the user the exact `! bash <path>/delete_listed.sh <list>` command. Large deletes take several minutes. Afterwards, run `git worktree prune` in each repo whose worktrees were in the list.
9. **Verify.** Re-run `df -h /System/Volumes/Data`. Check that the kept folders still exist. Report:
   - free space before and after
   - what was removed
   - where the backups are
   - what will behave differently, for example Docker images must be pulled again

## Common mistakes

| Mistake | Fix |
|---|---|
| Treating file mtimes in a checkout as "recent use" | Use the last commit date and the uncommitted count. |
| `for x in $list` in zsh | zsh does not word-split. Use a list file or Python. |
| Reading `ls -l Docker.raw` (shows ~1 TB sparse) | Use `du -sh` for the real size. |
| `git log origin/main..` to find unpushed work | Use `git rev-list HEAD --not --remotes` (any remote, any branch). |
| Only age-based rules for worktrees | Merged + clean checkouts are safe at any age. They are often the biggest win. |
| Free space "not moving" | Other jobs may be writing at the same time. Compare per-item sizes, not only `df`. |
| Removing a worktree an agent is running in | Check `inuse=` and skip anything committed or edited in the last 24 hours. |
| "Clean" checkout with git-ignored data (`.env`, run outputs) | `git worktree remove` deletes ignored files silently. Check `ignored=`; `backup_unsaved.sh` refuses until approved. |
| `rm` on a worktree folder without pruning | Run `git worktree prune` afterwards, or git keeps a stale entry. |
| Removing branches with worktrees | `git worktree remove` keeps the branch. Never run `git branch -D` during cleanup. |

## Files

- `scripts/scan.sh [roots...]`: read-only report (default roots: `$HOME`, `/Applications`).
- `scripts/clean_caches.sh`: tier-A cleanup with each tool's own command. Prints the space freed.
- `scripts/backup_unsaved.sh <git-dir> <backup-dir>`: saves unpushed commits (every local branch and the stash for standalone clones), uncommitted changes (binary-safe patch) and untracked files. Exits 1 if any part fails or non-rebuildable git-ignored files are present.
  To restore, clone the repo, then run `git fetch <name>.bundle HEAD:refs/heads/restored`, `git switch restored`, `git apply <name>.patch`, and `tar xzf <name>-untracked.tgz`. The bundle holds only the unpushed commits, so `git clone <bundle>` fails by design.
- `scripts/delete_listed.sh <list-file> [--dry-run]`: deletes listed absolute paths. It skips missing paths, refuses system paths and anything outside `$HOME` and `/Applications`, quits Docker before it deletes `Docker.raw`, and prints the space freed.
