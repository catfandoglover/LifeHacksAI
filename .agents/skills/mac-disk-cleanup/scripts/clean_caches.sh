#!/usr/bin/env bash
# Tier A: clear rebuildable caches with each tool's own cleaner. Safe to re-run.
# Everything here is re-downloaded on next use (Go modules, Homebrew bottles, pods); nothing is user data.
set -uo pipefail
free_kb() { df -k /System/Volumes/Data 2>/dev/null | awk 'NR==2{print $4}'; }
before=$(free_kb)
run() { command -v "$1" >/dev/null 2>&1 || return 0; echo "-> $*"; "$@" 2>&1 | tail -2; }

run npm cache clean --force
run pnpm store prune
run go clean -modcache
run go clean -cache
run pip3 cache purge
run brew cleanup -s --prune=all
run pod cache clean --all
run yarn cache clean
run uv cache clean

after=$(free_kb)
echo; echo "Freed about $(( (after-before)/1048576 )) GB. Free now: $(( after/1048576 )) GB"
echo "Cache folders without a cleaner (e.g. ~/Library/Caches/<app>) go in a delete list for delete_listed.sh."
