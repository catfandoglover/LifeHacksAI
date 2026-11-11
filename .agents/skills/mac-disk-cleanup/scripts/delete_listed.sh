#!/usr/bin/env bash
# Delete the absolute paths listed in a file, one per line (# comments and blank lines skipped).
# Only run this on a list the user approved.
# Usage: delete_listed.sh <list-file> [--dry-run]
set -uo pipefail
list=${1:?list file}; dry=${2:-}
free_kb() { df -k /System/Volumes/Data 2>/dev/null | awk 'NR==2{print $4}'; }
before=$(free_kb); n=0

while IFS= read -r p || [ -n "$p" ]; do
  p="${p%%#*}"; p="${p%"${p##*[![:space:]]}"}"   # strip comment + trailing space
  [ -z "$p" ] && continue
  case "$p" in
    /|"$HOME"|"$HOME/"|/Applications|/Applications/|/System*|/Library|/usr*|/bin*|/sbin*|/private*)
      echo "REFUSED  $p (protected)"; continue ;;
    "$HOME"/*|/Applications/*) ;;
    *) echo "REFUSED  $p (outside \$HOME and /Applications)"; continue ;;
  esac
  [ -e "$p" ] || { echo "missing  $p"; continue; }
  if [ "$dry" = "--dry-run" ]; then echo "would remove $(du -xsh "$p" 2>/dev/null | cut -f1)  $p"; continue; fi
  if [[ "$p" == *Docker.raw ]]; then osascript -e 'quit app "Docker"' 2>/dev/null; sleep 3; fi
  rm -rf -- "$p" && { echo "removed  $p"; n=$((n+1)); } || echo "FAILED   $p"
done < "$list"

after=$(free_kb)
echo; echo "Removed $n paths. Freed about $(( (after-before)/1048576 )) GB. Free now: $(( after/1048576 )) GB"
