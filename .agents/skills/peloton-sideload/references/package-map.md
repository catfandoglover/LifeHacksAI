# Peloton Sideload Package Map

Use these package IDs and install routes when sideloading common apps onto a Peloton or similar Android tablet. Verify current versions in Aurora/F-Droid at install time.

## Default Favorites Set

When the user asks for the same setup from the original Peloton workflow, install and pin these favorites when available: SmartTube, Netflix, Hulu, Disney+, Spotify, HBO Max/Max, Prime Video, Kindle, YUTorah, Fennec/Firefox, Aurora Store, and Discreet Launcher. Add X and Activity Launcher only when requested.

## F-Droid Direct Installs

| App | Package | Helper key | Notes |
| --- | --- | --- | --- |
| Aurora Store | `com.aurora.store` | `aurora` | Use to fetch Play Store apps without Play Store installed. Let the user choose anonymous/login mode. |
| SmartTube | `app.smarttube.fdroid` | `smarttube` | Preferred YouTube replacement on devices without Google Play Services/GSF. |
| Fennec/Firefox | `org.mozilla.fennec_fdroid` | `fennec` | Good browser fallback that does not depend on Chrome or Play Store. |
| Activity Launcher | `de.szalkowski.activitylauncher` | `activity-launcher` | Useful for inspecting/launching hidden app activities. |
| Discreet Launcher | `com.vincent_falzon.discreetlauncher` | `discreet-launcher` | Lightweight home launcher with favorites and "Always show favorites". |

## Aurora Store Apps

| App | Package | GSF expectation | Notes |
| --- | --- | --- | --- |
| Netflix | `com.netflix.mediaclient` | Often works, DRM/device checks may vary | On some Peloton screens Netflix may already be installed. |
| Hulu | `com.hulu.plus` | Known to work in this workflow | Good baseline streaming test. |
| Disney+ | `com.disney.disneyplus` | May require GSF or device support | Installable, but playback/sign-in may vary by version. |
| Spotify | `com.spotify.music` | Often works | Touch layout may be phone/tablet optimized, not TV optimized. |
| HBO Max / Max | `com.wbd.stream` | May require GSF or device support | Branding and package name can change; verify in Aurora. |
| Prime Video | `com.amazon.avod.thirdpartyclient` | Often works, DRM/device checks may vary | Amazon login and playback support depend on device build. |
| Kindle | `com.amazon.kindle` | Often works | Good reader option on large Peloton displays. |
| YUTorah | `org.yutorah.app` | Usually lightweight | Install from Aurora if available. |
| X | `com.twitter.android` | May degrade without GSF | Browser/PWA fallback may be easier. |
| YouTube | `com.google.android.youtube` | Requires Google Play Services on most builds | Prefer SmartTube instead. |

## Peloton-Specific Activities

| Purpose | Component |
| --- | --- |
| Peloton original home | `com.peloton.launcher/.LauncherActivity` |
| Discreet Launcher home | `com.vincent_falzon.discreetlauncher/.ActivityMain` |

Use `cmd package set-home-activity` to switch between them:

```sh
adb -s "$SERIAL" shell cmd package set-home-activity com.vincent_falzon.discreetlauncher/.ActivityMain
adb -s "$SERIAL" shell cmd package set-home-activity com.peloton.launcher/.LauncherActivity
```
