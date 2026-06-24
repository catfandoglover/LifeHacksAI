---
name: peloton-sideload
description: "End-to-end ADB-based Peloton tablet setup and sideloading workflow. Use when the user wants Codex to walk them through enabling Android developer mode, turning on USB or wireless debugging, pairing or connecting ADB to a Peloton screen or similar Android tablet, asking which apps to install, opening Aurora Store or installing F-Droid APKs, handling Google Play Services/GSF failures, changing the Peloton logo/Home button to a sideload launcher, configuring Activity Launcher or Discreet Launcher, and pinning installed apps as always-visible favorites."
---

# Peloton Sideload

This skill turns a Peloton tablet or similar Android screen into a manageable ADB target, installs apps from reasonable sources, and configures a simple launcher so the user can reach favorite apps without Codex.

Use the bundled helper script when it reduces command churn:

```sh
.agents/skills/peloton-sideload/scripts/peloton_adb.sh help
```

Load `references/package-map.md` when choosing package IDs, install routes, or GSF-safe alternatives.

## Guardrails

Work only on a device the user owns or is allowed to administer. Do not bypass account login, subscriptions, DRM, paid app access, enterprise management, or device security controls. Prefer F-Droid, Aurora Store, vendor stores, or APKs the user explicitly provides. Avoid random APK mirror sites unless the user accepts the risk and no safer source exists.

Do not silently install Google Play Services, Google Services Framework, or Play Store on Peloton hardware. Treat GSF installation on non-certified Android builds as fragile and potentially destabilizing; prefer non-GSF alternatives such as SmartTube for YouTube and browser/PWA fallbacks when apps refuse to run.

Never type the user's account credentials. Open the relevant app or store page and let the user complete sign-in, purchase, or consent screens on the device.

## Session Intake

Start by asking for the minimum live details needed to drive the setup:

- Peloton/tablet model if known.
- Whether Developer options, USB debugging, or Wireless debugging are already enabled.
- Whether the user wants Wi-Fi debugging, USB debugging, or whichever works fastest.
- The apps they want installed and whether any apps are must-have versus nice-to-have.
- Whether they want the Peloton logo/Home button to open the app launcher by default.
- Whether they want Codex to drive UI taps through ADB screenshots or have the user tap along manually.

Default to this app set when the user says "the ones we did" or "streaming setup": SmartTube, Netflix, Hulu, Disney+, Spotify, HBO Max/Max, Prime Video, Kindle, YUTorah, Fennec/Firefox, Aurora Store, and Discreet Launcher. Treat X and Activity Launcher as optional unless requested.

## Workflow

1. Walk the user through developer mode before ADB exists:

```text
Peloton Settings -> Device Settings -> System -> About tablet -> tap Build number 7 times
Back to System -> Developer options
Enable Developer options
Enable USB debugging and, when present, Wireless debugging
```

On some Peloton builds, `About tablet` appears directly under `Device Settings`; on others it is under `System`. If the user cannot find settings, have them try the top-right settings menu or the three-dot menu, then `Device Settings`.

For USB debugging, have the user connect the screen to the computer and accept the RSA/debugging prompt on the Peloton. For wireless debugging, have the user open `Wireless debugging`, choose `Pair device with pairing code`, then send:

- Pairing IP and port.
- Pairing code.
- Connect IP and port, if visible.

If the connect port is not visible, use `adb mdns services` after pairing to find `_adb-tls-connect._tcp`.

2. Verify ADB on the host:

```sh
command -v adb || brew install android-platform-tools
adb version
```

On non-macOS hosts, install official Android platform-tools or the platform package manager equivalent, then verify `adb version`.

3. Discover and connect to the device:

```sh
adb devices -l
adb mdns services
adb pair HOST:PAIR_PORT
adb connect HOST:CONNECT_PORT
```

For Android 11+ Wi-Fi debugging, the pairing port and connect port are different. Use the pairing endpoint from `_adb-tls-pairing._tcp` and the connect endpoint from `_adb-tls-connect._tcp`. Pairing codes expire quickly; ask the user for a fresh code if pairing fails.

Set a serial when more than one device can appear:

```sh
export SERIAL=10.0.0.24:33465
adb -s "$SERIAL" shell getprop ro.product.model
```

The helper script respects `SERIAL`:

```sh
SERIAL=10.0.0.24:33465 .agents/skills/peloton-sideload/scripts/peloton_adb.sh inspect
```

4. Inspect compatibility before installing:

```sh
adb -s "$SERIAL" shell getprop ro.product.model
adb -s "$SERIAL" shell getprop ro.product.cpu.abilist
adb -s "$SERIAL" shell getprop ro.build.version.release
adb -s "$SERIAL" shell wm size
adb -s "$SERIAL" shell wm density
adb -s "$SERIAL" shell pm list packages | rg 'gms|gsf|vending|play'
```

On Peloton tablets, expect Android 11-era builds, arm64 support, and no `com.google.android.gms`, `com.google.android.gsf`, or `com.android.vending`. Apps that hard-require Google Services Framework will usually fail after installation.

5. Confirm the install plan with the user:

- Map each requested app to `references/package-map.md`.
- Say plainly when an official app is likely to fail without Google Play Services or GSF.
- Prefer SmartTube over official YouTube.
- Prefer Fennec/Firefox or a web app when a social/media app refuses to run.
- Ask the user to keep the Peloton screen awake and respond to any permission, install, login, or store prompts.

6. Install the store and utility baseline:

```sh
.agents/skills/peloton-sideload/scripts/peloton_adb.sh install-fdroid aurora
.agents/skills/peloton-sideload/scripts/peloton_adb.sh install-fdroid smarttube
.agents/skills/peloton-sideload/scripts/peloton_adb.sh install-fdroid fennec
.agents/skills/peloton-sideload/scripts/peloton_adb.sh install-fdroid discreet-launcher
.agents/skills/peloton-sideload/scripts/peloton_adb.sh install-fdroid activity-launcher
```

Use SmartTube instead of official YouTube when the device lacks GSF. Use Fennec/Firefox as the default browser fallback because Chrome depends on Google services and Play Store plumbing more often.

7. Install Aurora Store apps by package ID:

```sh
.agents/skills/peloton-sideload/scripts/peloton_adb.sh open-aurora com.hulu.plus
.agents/skills/peloton-sideload/scripts/peloton_adb.sh wait-package com.hulu.plus
```

When Aurora opens, let the user choose anonymous/login mode if prompted, then tap Install/Update on the device. For each requested app, open the Aurora page, wait while the user installs, poll with `wait-package`, then move to the next app. If screen automation is needed on a 1920x1080 Peloton display, the install button is often near the top right of the listing, around `480 285` in the screencap coordinate system used by ADB on rotated displays; verify with a screenshot before tapping.

Install package IDs from `references/package-map.md`, commonly:

```text
com.netflix.mediaclient
com.hulu.plus
com.disney.disneyplus
com.spotify.music
com.wbd.stream
com.amazon.avod.thirdpartyclient
com.amazon.kindle
org.yutorah.app
com.twitter.android
```

8. Configure the Peloton logo/Home button and no-swipe launcher:

```sh
.agents/skills/peloton-sideload/scripts/peloton_adb.sh set-discreet-home
adb -s "$SERIAL" shell input keyevent HOME
```

The Peloton logo button behaves like Android Home on many Peloton screens. After setting Discreet Launcher as Home, pressing the Peloton logo or sending `input keyevent HOME` should open Discreet Launcher instead of the Peloton launcher. If Android shows a launcher chooser, tell the user to select Discreet Launcher and choose the always/default option.

In Discreet Launcher, do the favorites pass completely:

- Press Home/Peloton logo to open Discreet Launcher.
- Open the wrench/settings control.
- Use `Hidden apps` first if installed apps are missing from lists.
- Use `Favorites` to turn on every installed app the user wants on the launcher: SmartTube, Netflix, Hulu, Disney+, Spotify, HBO Max/Max, Prime Video, Kindle, YUTorah, Fennec/Firefox, Aurora Store, and any other requested apps.
- In `Operation`, enable `Always show favorites` so the home screen opens directly to favorites without swiping down.
- Press Home/Peloton logo again and verify the favorites are visible immediately.

If using ADB taps, take screenshots before tapping and after each settings change. Do not rely on stale coordinates when the launcher layout changes.

Keep a rollback command handy:

```sh
.agents/skills/peloton-sideload/scripts/peloton_adb.sh set-peloton-home
```

9. Verify and document the outcome:

```sh
adb -s "$SERIAL" shell pm list packages | rg 'netflix|hulu|disney|spotify|wbd|amazon|yutorah|smarttube|fennec|aurora|discreetlauncher'
adb -s "$SERIAL" shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
```

Do not call the workflow complete until the user can press the Peloton logo/Home button and see the selected favorites without swiping. Tell the user which apps installed, which apps are expected to fail without GSF, how to launch the home screen, how to edit favorites later, and the exact rollback command for Peloton Home.

## Troubleshooting

If `adb pair` succeeds but `adb connect` fails, run `adb mdns services` again. Wireless debugging ports change, and the pairing port is not the connect port.

If ADB reports `more than one device/emulator`, set `SERIAL` and pass `adb -s "$SERIAL"` for every command.

If mDNS shows the old IP but the device moved, use the IP currently displayed in Android wireless debugging settings, then rediscover with `adb mdns services`. `10.0.0.23` vs `10.0.0.24` style changes are normal on home networks.

If screenshots through `adb exec-out screencap -p` fail or return corrupt data, use the file fallback:

```sh
adb -s "$SERIAL" shell screencap -p /sdcard/codex-screen.png
adb -s "$SERIAL" pull /sdcard/codex-screen.png /tmp/codex-screen.png
```

If an app says Google Play Services, GSF, or the device is unsupported, do not keep reinstalling variants. Use a known non-GSF option, a web app in Fennec, or tell the user the app is blocked by the vendor's runtime requirements.

If the device returns to the Peloton launcher after pressing Home, confirm the home activity:

```sh
adb -s "$SERIAL" shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
```

Then set Discreet Launcher again if needed.

If an app is installed but not visible in Discreet Launcher favorites, open Discreet settings and check `Hidden apps`. Some apps also expose no leanback/home launcher activity; launch them once with:

```sh
adb -s "$SERIAL" shell monkey -p PACKAGE_ID -c android.intent.category.LAUNCHER 1
```
