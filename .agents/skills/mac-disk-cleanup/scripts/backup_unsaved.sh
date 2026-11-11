#!/usr/bin/env bash
# Save unpushed commits and uncommitted work of one git checkout/worktree before removing it.
# Usage: backup_unsaved.sh <git-dir> <backup-dir>
# Exit 0 = safe to remove: nothing unsaved, or every part of the backup was written and checked.
# Exit 1 = do NOT remove (backup failed, or git-ignored files need a human decision).
# Set ALLOW_IGNORED=1 only after the user approved losing the git-ignored files listed.
set -uo pipefail
w=${1:?git dir}; b=${2:?backup dir}
fail() { echo "FAILED  $w: $1"; exit 1; }
name=$(basename "$w"); mkdir -p "$b" || fail "cannot create $b"
head=$(git -C "$w" rev-parse HEAD) || fail "not a git checkout"
gitdir=$(git -C "$w" rev-parse --absolute-git-dir) || fail "git dir"
common=$(cd "$w" && cd "$(git rev-parse --git-common-dir)" && pwd) || fail "common dir"
# A linked worktree's branches live in the main repo's .git, which survives.
# A standalone clone's .git is deleted with it, so every local branch and the stash must be saved.
if [ "$gitdir" = "$common" ]; then scope=(--branches); kind=clone; else scope=(HEAD); kind=worktree; fi

revs=$(git -C "$w" rev-list "${scope[@]}" --not --remotes) || fail "rev-list"
unpushed=$(printf '%s' "$revs" | grep -c . || true)
stash=0; [ "$kind" = clone ] && git -C "$w" rev-parse -q --verify refs/stash >/dev/null && stash=1
changed=$(git -C "$w" status --porcelain --untracked-files=no | wc -l | tr -d ' ')
untracked=$(git -C "$w" ls-files --others --exclude-standard | wc -l | tr -d ' ')

# Git-ignored files are deleted by `git worktree remove` without a word. Rebuildable dirs are fine;
# anything else (secrets, run outputs, data) needs a decision.
regen='(^|/)(node_modules|\.venv|venv|dist|build|\.next|\.turbo|__pycache__|\.pytest_cache|target|\.cache|coverage)/?$'
ignored=$(git -C "$w" ls-files --others --ignored --exclude-standard --directory | grep -Ev "$regen" || true)
if [ -n "$ignored" ] && [ "${ALLOW_IGNORED:-0}" != 1 ]; then
  echo "$ignored" | head -20 | sed "s|^|  ignored: |"
  fail "has git-ignored files that are not rebuildable (see list). Ask the user, then re-run with ALLOW_IGNORED=1"
fi

if [ "$unpushed" = 0 ] && [ "$stash" = 0 ] && [ "$changed" = 0 ] && [ "$untracked" = 0 ]; then
  echo "clean   $w (nothing to back up)"; exit 0
fi

# For a worktree, a ref in the shared .git also keeps the commits if the branch is detached.
[ "$kind" = worktree ] && { git -C "$w" update-ref "refs/backup/cleanup-$(date +%Y%m%d)/$name" "$head" || fail "backup ref"; }
if [ "$unpushed" != 0 ] || [ "$stash" = 1 ]; then
  refs=("${scope[@]}"); [ "$stash" = 1 ] && refs+=(refs/stash)
  git -C "$w" bundle create "$b/$name.bundle" "${refs[@]}" --not --remotes >/dev/null 2>&1 || fail "bundle"
  git -C "$w" bundle verify "$b/$name.bundle" >/dev/null 2>&1 || fail "bundle verify"
fi
if [ "$changed" != 0 ]; then
  git -C "$w" diff --binary HEAD > "$b/$name.patch" && [ -s "$b/$name.patch" ] || fail "patch"
fi
if [ "$untracked" != 0 ]; then
  # One tar process reading a NUL list; xargs could split it and overwrite the archive.
  (cd "$w" && git ls-files --others --exclude-standard -z | tar --null -czf "$b/$name-untracked.tgz" -T -) \
    || fail "untracked tar"
  n=$(tar tzf "$b/$name-untracked.tgz" | grep -cv '/$') || fail "untracked tar verify"
  [ "$n" -ge "$untracked" ] || fail "untracked tar has $n of $untracked files"
fi
echo "$name kind=$kind HEAD=$head branch=$(git -C "$w" branch --show-current) unpushed=$unpushed stash=$stash changed=$changed untracked=$untracked path=$w" >> "$b/MANIFEST.txt"
echo "saved   $w -> $b"
