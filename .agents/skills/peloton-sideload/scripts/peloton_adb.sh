#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<'USAGE'
Peloton ADB helper

Usage:
  peloton_adb.sh help
  peloton_adb.sh list
  peloton_adb.sh mdns
  peloton_adb.sh pair HOST:PAIR_PORT
  peloton_adb.sh connect HOST:CONNECT_PORT
  peloton_adb.sh inspect
  peloton_adb.sh install-apk URL
  peloton_adb.sh install-fdroid KEY
  peloton_adb.sh open-aurora PACKAGE_ID
  peloton_adb.sh wait-package PACKAGE_ID [SECONDS]
  peloton_adb.sh launch PACKAGE_ID
  peloton_adb.sh tap X Y
  peloton_adb.sh home
  peloton_adb.sh screenshot OUT.png
  peloton_adb.sh set-discreet-home
  peloton_adb.sh set-peloton-home

Set SERIAL when multiple devices are connected:
  SERIAL=10.0.0.24:33465 peloton_adb.sh inspect

F-Droid keys:
  aurora, smarttube, fennec, activity-launcher, discreet-launcher
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_adb() {
  command -v adb >/dev/null 2>&1 || die "adb not found. Install android-platform-tools first."
}

adb_cmd() {
  require_adb
  if [[ -n "${SERIAL:-}" ]]; then
    adb -s "$SERIAL" "$@"
  else
    adb "$@"
  fi
}

fdroid_url() {
  case "$1" in
    aurora) printf '%s\n' 'https://f-droid.org/repo/com.aurora.store_75.apk' ;;
    smarttube) printf '%s\n' 'https://f-droid.org/repo/app.smarttube.fdroid_2384.apk' ;;
    fennec) printf '%s\n' 'https://f-droid.org/repo/org.mozilla.fennec_fdroid_1520020.apk' ;;
    activity-launcher) printf '%s\n' 'https://f-droid.org/repo/de.szalkowski.activitylauncher_7400.apk' ;;
    discreet-launcher) printf '%s\n' 'https://f-droid.org/repo/com.vincent_falzon.discreetlauncher_72.apk' ;;
    *) die "unknown F-Droid key '$1'. Run: $SCRIPT_NAME help" ;;
  esac
}

install_apk_url() {
  local url="$1"
  local tmp apk
  tmp="$(mktemp -d)"
  apk="$tmp/app.apk"
  trap 'rm -rf "$tmp"' RETURN
  printf 'Downloading %s\n' "$url"
  curl -L --fail --show-error --output "$apk" "$url"
  adb_cmd install -r "$apk"
}

inspect_device() {
  printf 'ADB devices:\n'
  adb devices -l
  printf '\nModel: '
  adb_cmd shell getprop ro.product.model | tr -d '\r'
  printf 'Android: '
  adb_cmd shell getprop ro.build.version.release | tr -d '\r'
  printf 'SDK: '
  adb_cmd shell getprop ro.build.version.sdk | tr -d '\r'
  printf 'ABI list: '
  adb_cmd shell getprop ro.product.cpu.abilist | tr -d '\r'
  printf 'Screen size: '
  adb_cmd shell wm size | tr -d '\r'
  printf 'Density: '
  adb_cmd shell wm density | tr -d '\r'
  printf '\nGoogle service packages:\n'
  adb_cmd shell pm list packages | grep -E 'gms|gsf|vending|google' || true
  printf '\nCurrent home activity:\n'
  adb_cmd shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME || true
}

wait_package() {
  local package="$1"
  local seconds="${2:-180}"
  local end=$((SECONDS + seconds))
  while (( SECONDS < end )); do
    if adb_cmd shell pm list packages "$package" | tr -d '\r' | grep -q "^package:$package$"; then
      printf '%s installed\n' "$package"
      return 0
    fi
    sleep 3
  done
  die "timed out waiting for $package"
}

take_screenshot() {
  local out="$1"
  if adb_cmd exec-out screencap -p > "$out" && [[ -s "$out" ]]; then
    printf 'Saved %s\n' "$out"
    return 0
  fi
  printf 'exec-out screenshot failed, trying /sdcard fallback...\n' >&2
  adb_cmd shell screencap -p /sdcard/codex-screen.png
  adb_cmd pull /sdcard/codex-screen.png "$out"
  printf 'Saved %s\n' "$out"
}

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    help|-h|--help)
      usage
      ;;
    list)
      require_adb
      adb devices -l
      ;;
    mdns)
      require_adb
      adb mdns services
      ;;
    pair)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME pair HOST:PAIR_PORT"
      require_adb
      adb pair "$1"
      ;;
    connect)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME connect HOST:CONNECT_PORT"
      require_adb
      adb connect "$1"
      ;;
    inspect)
      inspect_device
      ;;
    install-apk)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME install-apk URL"
      install_apk_url "$1"
      ;;
    install-fdroid)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME install-fdroid KEY"
      install_apk_url "$(fdroid_url "$1")"
      ;;
    open-aurora)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME open-aurora PACKAGE_ID"
      adb_cmd shell am start -a android.intent.action.VIEW -d "market://details?id=$1" -p com.aurora.store
      ;;
    wait-package)
      [[ $# -ge 1 && $# -le 2 ]] || die "usage: $SCRIPT_NAME wait-package PACKAGE_ID [SECONDS]"
      wait_package "$@"
      ;;
    launch)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME launch PACKAGE_ID"
      adb_cmd shell monkey -p "$1" -c android.intent.category.LAUNCHER 1
      ;;
    tap)
      [[ $# -eq 2 ]] || die "usage: $SCRIPT_NAME tap X Y"
      adb_cmd shell input tap "$1" "$2"
      ;;
    home)
      adb_cmd shell input keyevent HOME
      ;;
    screenshot)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME screenshot OUT.png"
      take_screenshot "$1"
      ;;
    set-discreet-home)
      adb_cmd shell cmd package set-home-activity com.vincent_falzon.discreetlauncher/.ActivityMain
      ;;
    set-peloton-home)
      adb_cmd shell cmd package set-home-activity com.peloton.launcher/.LauncherActivity
      ;;
    *)
      die "unknown command '$cmd'. Run: $SCRIPT_NAME help"
      ;;
  esac
}

main "$@"
