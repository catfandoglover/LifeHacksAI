#!/usr/bin/env bash
# Read-only disk report for macOS. Deletes nothing.
# Usage: scan.sh [root ...]   (default: $HOME /Applications)
set -uo pipefail
ROOTS=("$@"); [ ${#ROOTS[@]} -eq 0 ] && ROOTS=("$HOME" /Applications)
hr() { printf '\n== %s\n' "$1"; }

hr "Free space"
df -h /System/Volumes/Data 2>/dev/null | tail -1 || df -h / | tail -1

hr "Largest folders (top 25 per root)"
for r in "${ROOTS[@]}"; do
  echo "-- $r"
  du -xsk "$r"/* "$r"/.[!.]* 2>/dev/null | sort -rn | head -25 | awk '{s=$1; $1=""; printf "%7.1fG %s\n", s/1048576, $0}'
done

hr "~/Library breakdown (top 20)"
du -xsk ~/Library/{Caches,Containers,"Application Support","Group Containers",Developer}/* 2>/dev/null \
  | sort -rn | head -20 | awk '{s=$1; $1=""; printf "%7.1fG %s\n", s/1048576, $0}'

hr "Cache folders (tool caches are tier A; judge each app cache: paid-to-build caches are tier C)"
for p in ~/.npm ~/Library/pnpm ~/Library/Caches/pnpm ~/.cache ~/Library/Caches/pip ~/go/pkg/mod \
         ~/Library/Caches/go-build ~/Library/Caches/Homebrew ~/Library/Caches/CocoaPods \
         ~/Library/Caches/ms-playwright ~/Library/Caches/ms-playwright-mcp ~/.bun/install/cache ~/.cache/* \
         ~/Library/Developer/Xcode/DerivedData ~/.gradle/caches; do
  [ -e "$p" ] && du -xsh "$p" 2>/dev/null
done

hr "Docker VM (real size, not the sparse size)"
du -xsh ~/Library/Containers/com.docker.docker/Data/vms/*/data/Docker.raw 2>/dev/null || echo "none"

hr "Apps: size, last opened (null = no Spotlight record, NOT proof of non-use)"
for a in /Applications/*.app; do
  s=$(du -xsk "$a" 2>/dev/null | cut -f1)
  d=$(mdls -raw -name kMDItemLastUsedDate "$a" 2>/dev/null | cut -c1-10)
  echo "$((s/1024)) $d $(basename "$a")"
done | sort -rn | head -25 | awk '{printf "%6dM %-10s %s\n",$1,$2,substr($0,index($0,$3))}'

hr "Folders in use right now (working directory of a running process)"
INUSE=$(lsof -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | sort -u | grep -E "^($HOME|/Applications)/" | grep -vx "$HOME")
echo "${INUSE:-none}"

hr "Git checkouts (size | last commit | last uncommitted edit | unpushed | dirty | merged | in use | ignored-not-rebuildable | path)"
# merged=yes: HEAD is already in the remote default branch. Squash merges show no; check with gh.
# lastedit: newest change among uncommitted files (dates of unchanged files are checkout noise).
# ignored: git-ignored paths that are NOT node_modules/venv/build output; these vanish on removal.
regen='(^|/)(node_modules|\.venv|venv|dist|build|\.next|\.turbo|__pycache__|\.pytest_cache|target|\.cache|coverage)/?$'
find "${ROOTS[@]}" -maxdepth 6 \( -name node_modules -o -name .venv -o -name venv -o -name Library \
     -o -name .cache -o -name .npm -o -name '*.app' -o -name runtime -o -name site-packages \) -prune \
     -o -name .git -print 2>/dev/null | while IFS= read -r g; do
  w=$(dirname "$g")
  c=$(git -C "$w" log -1 --format=%cs 2>/dev/null) || continue
  # Standalone clone: count every local branch (its .git goes with it). Worktree: only HEAD.
  sc=HEAD; [ -d "$w/.git" ] && sc=--branches
  u=$(git -C "$w" rev-list $sc --not --remotes 2>/dev/null | wc -l | tr -d ' ')
  d=$(git -C "$w" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  le=-; [ "$d" != 0 ] && le=$(cd "$w" && git status --porcelain -z | tr '\0' '\n' | cut -c4- \
        | while IFS= read -r f; do [ -e "$f" ] && stat -f %m "$f"; done | sort -rn | head -1)
  [ -n "$le" ] && [ "$le" != - ] && le=$(date -r "$le" +%F)
  def=$(git -C "$w" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
  m=no; git -C "$w" merge-base --is-ancestor HEAD "$def" 2>/dev/null && m=yes
  iu=no; while IFS= read -r p; do case "$p/" in "$w"/*) iu=yes;; esac; done <<< "$INUSE"
  ig=$(git -C "$w" ls-files --others --ignored --exclude-standard --directory 2>/dev/null | grep -Ev "$regen" \
        | (cd "$w" && tr '\n' '\0' | xargs -0 du -sk 2>/dev/null) | awk '{s+=$1} END{printf "%.0fM", s/1024}')
  s=$(du -xsh "$w" 2>/dev/null | cut -f1)
  printf '%6s | %s | edit=%s | unpushed=%s | dirty=%s | merged=%s | inuse=%s | ignored=%s | %s\n' \
    "$s" "$c" "${le:--}" "$u" "$d" "$m" "$iu" "$ig" "$w"
done | sort -t'|' -k2

hr "Not visible to du"
echo "macOS privacy blocks Photos, Mail, Messages and iCloud Drive. Compare the totals above with"
echo "'used' in Free space; check System Settings > General > Storage for the gap."
