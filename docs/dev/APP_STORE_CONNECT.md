# App Store Connect — Canonical Identity Map

Single source of truth for Echoel's App Store Connect identifiers, bundle IDs, and the
target ↔ bundle mapping. Mirror the headline facts in `CLAUDE.md` §IDENTITY; keep the full
table here. Update this file whenever a target or identifier changes.

## Account & app

| Field | Value |
|---|---|
| App name | **Echoelmusic** |
| Developer | Echoel (Michael Terbuyken) · Studio Hamburg |
| Apple App ID (ASC) | **6757957358** |
| SKU | **Simsalabimbam** |
| Bundle prefix | `com.echoelmusic` |
| Marketing version | follows line 1 of `.deploy/release` — `testflight.yml` rewrites `project.yml`'s `MARKETING_VERSION` from the first `vX.Y.Z` in that file on every run (measure: `head -1 .deploy/release`; shipped 2026-10-07: 10.79.492, build 2617). The literal in `project.yml` is a stale placeholder that never reaches a build |
| Build number | `${BUILD_NUMBER:=1}` (`CURRENT_PROJECT_VERSION`) |
| Echoel Studio version | `MARKETING_VERSION` in `EchoelStudio/project.yml` (11.0.0) — `EchoelStudio/RELEASE` only triggers the upload. Build number = 10000 + the run number of `studio-testflight.yml` (2026-10-19: 10004 and 10005), so it never collides with the earlier app's builds (2617 on 2026-10-07) |
| Team ID | via `APPLE_TEAM_ID` GitHub Actions secret (not committed) |
| App category | `public.app-category.music` |
| Deployment floor | iOS 18 |

## Bundle identifiers (App Store Connect registration)

The owner-registered ASC identifier set. Universal Purchase: all primary platforms share the
single `com.echoelmusic.app` ID so one purchase unlocks iOS / macOS / tvOS / visionOS.

> ✅ **One project generator.** `project.yml` (XcodeGen) is the single source of truth —
> `testflight.yml` runs `xcodegen generate` and archives it. The former Tuist `Project.swift`
> (a parallel, never-CI-built generator) was **removed 2026-06-19** (no-JUCE / single-pipeline
> cleanup). The status column below is the ground truth for what ships.

| ASC display name | Bundle ID | Role | CI (`project.yml`) |
|---|---|---|---|
| Echoelmusic | `com.echoelmusic.app` | Main app (iOS + universal) | ✅ **builds + ships** |
| Echoelmusic AUv3 | `com.echoelmusic.app.auv3` | Audio Unit v3 instrument extension (`aumu`/`echl`) | ✅ **embedded + builds** — REVIVED 2026-09-20 (#1385, founder ask) after its removal 2026-07-24 (#121 Slice 1); ships inside the host app like the widget (`project.yml` app dependencies), loads in AUM (device-measured, #1386). **No App Group in the EARLIER app's extension** (`Sources/EchoelmusicAUv3`): with the key iOS refused to launch that appex (`-3000`), so its entitlements file is deliberately empty. ⭐ The Studio's extension (`EchoelPlugins.appex`) asks for `group.com.echoelmusic.shared` since factory job 002 and signed with it in build 10008; whether it launches in a host is device step SP2. ⛔ This row said "TARGET DELETED" until 2026-09-25. |
| Echoelmusic Widgets | `com.echoelmusic.app.widgets` | WidgetKit extension | ✅ **embedded + ships** |
| Echoelmusic watchOS | `com.echoelmusic.app.watchkitapp` | watchOS companion | ⚠️ compile-verified, **embed blocked** (local Xcode) |
| Echoelmusic Clip | `com.echoelmusic.app.clip` | App Clip | ❌ ASC-registered, **target deferred** |
| Echoelmusic Notification Service | `com.echoelmusic.app.notification-service` | Notification Service extension | ❌ ASC-registered, **target deferred** |
| (voice) | `com.echoelmusic.app.voice` | — | ❌ **registered** in the developer portal (founder screen recording 2026-10-18), no target. ⛔ The note below said it was "not in the owner's ASC bundle set"; it is. Unused — a spare id, do not build on it without a founder ask |

**EchoelStudio (the restart) uses exactly two of these** (audit 2026-10-18,
`docs/dev/AUDIT_ECHOELSTUDIO_2026-10-18.md`): the app `com.echoelmusic.app` and ONE extension
`com.echoelmusic.app.auv3` carrying every Echoel Audio Unit. Its single in-app purchase is
`com.echoelmusic.app.pro` — **not yet created in App Store Connect** (the In-App-Käufe page was empty
on 2026-10-18); the first one must be submitted together with an app version, after the Account Holder
accepts the updated Paid Applications Schedule. Measured in the developer portal on 2026-10-18: the six
ids above plus `.voice` and a wildcard `*`.

**Measured again 2026-10-18 evening (two founder screen recordings of the developer portal):**
- An App ID **„Echoelmusic Pro" `com.echoelmusic.app.pro`** was registered, with no capability ticked
  beyond the default In-App Purchase. **It is not needed:** a product id is not an App ID. The purchase
  is created in App Store Connect under the app (Monetarisierung → In-App-Käufe); nothing builds,
  signs or ships under the bundle id `.pro`. Harmless if kept; removing it avoids the confusion.
- `com.echoelmusic.app` carries two App Groups, each with one purpose: `group.com.echoelmusic.shared`
  (since factory job 002, 2026-10-19: the app records the plugin purchase there for the extension,
  `PluginUnlock`) and `group.com.echoelmusic` (the container the earlier app kept its songs in; the
  Studio reads it once to import them). ⭐ **F17 closed 2026-10-21:** the founder ticked
  `group.com.echoelmusic` on this App ID again, and the signing probe on `7c0760edc` (run 39647016707,
  17:52 UTC) printed both groups in the development and App Store profiles of the app and of the
  extension, with the signed Echoel.app carrying both. The Studio's entitlements ask for both since
  `a14e1960a`. ⛔ From `2b9956c` (2026-10-19) to then they did not ask for `group.com.echoelmusic`,
  because the profile did not grant it: builds 10004–10007 asked for no group, 10008–10009 for
  `.shared` alone, and in all six the import found no container and skipped quietly. The App ID also
  carries many capabilities the earlier app used (HealthKit, iCloud/CloudKit, Push, Sign in
  with Apple, Siri, WeatherKit, MusicKit, ShazamKit, Maps, Data Protection „Complete" …). An App ID
  capability only PERMITS an entitlement; what App Review sees is the binary's entitlements. Do not
  untick them while builds of the earlier app exist.
- `com.echoelmusic.app.auv3` had **no** App Group in these recordings and only Sign in with Apple
  ticked, which nothing uses. ⚠️ The F17 run of the same evening printed the ISSUED .auv3 profile
  carrying `group.com.echoelmusic.shared`, and since factory job 002 the extension requests it (to read
  the plugin purchase). ⭐ **Settled on the signing side 2026-10-19 (Studio TestFlight run 39341933847,
  build 10008, `f61d7872d`):** the archive signed BOTH the app and `EchoelPlugins.appex` with
  `group.com.echoelmusic.shared` in their entitlements, the extension under the profile
  „iOS Team Provisioning Profile: com.echoelmusic.app.auv3", and App Store Connect accepted the
  upload. A profile without the group stops the archive with a profile error (attempts 1–3 of F17 did
  exactly that for the app), so the issued profile grants it. ⚠️ Whether the extension then LAUNCHES in
  a host with the group is a device question (the earlier extension signed fine and failed in the host
  with `-3000`) — FOUNDER_INBOX §2 family SP, step SP2. The probe of 2026-10-21 (run 39647016707)
  printed the .auv3 development and App Store profiles granting both groups; `group.com.echoelmusic`
  sits there because the founder first ticked it on this App ID by mistake (probe 4, run
  39591787947). It may stay: the extension does not ask for it.

> **Deferred platforms** (macOS / tvOS / visionOS) were previously declared only in the removed
> Tuist `Project.swift`. They are **not currently defined anywhere** and would be re-added to
> `project.yml` in a dedicated, signing-verified cycle when actually built (iPhone-first for now).

### App Group

| App Group | Status |
|---|---|
| `group.com.echoelmusic` | Canonical (entitlements + `CLAUDE.md`). Used by the earlier app, its widget, the unembedded watch target and, since `a14e1960a`, the Studio app, which reads the earlier songs from it once (`git grep -l group.com.echoelmusic -- '*.entitlements'`); the earlier app's AUv3 carries none on purpose. ⭐ **Granted again since 2026-10-21 (F17, signing probe run 39647016707).** ⛔ Measured 2026-10-18/19 (Studio TestFlight runs 39158721875, 39158926622, 39180435790): the profile for `com.echoelmusic.app` granted only `group.com.echoelmusic.shared`; the last earlier-app upload (run 38996952047, 2026-10-17 03:04) still signed with this group, so it left the App ID between those dates. Whether `testflight.yml` signs the earlier app again is not measured: no earlier-app build ran since. |
| `group.com.echoelmusic.shared` | The plugin purchase record (`PluginUnlock`), written by the Studio app and read by `EchoelPlugins.appex` (factory job 002). Granted on `com.echoelmusic.app` and `com.echoelmusic.app.auv3`; build 10008 signed both with it. |

> ⛔ A note here said `fastlane/Appfile` names `group.com.echoelmusic.shared` while the entitlements
> use `group.com.echoelmusic`. Measured 2026-10-21: the Appfile names `group.com.echoelmusic` only
> (`grep -n group fastlane/Appfile`), and both groups are registered, each for its own purpose (table
> above). There is no mismatch to resolve.

## Notes & deferred work (iPhone-first scope)

- **iPhone-first MVP.** `.clip` and `.notification-service` are registered in App Store
  Connect but their Xcode targets are **intentionally deferred** to avoid build/signing risk
  this round. Add them only in a dedicated cycle with entitlements + provisioning verified.
- **Former extra target:** the removed Tuist `Project.swift` also declared `com.echoelmusic.app.voice`
  (an `EchoelVoice` AUv3), not in the owner's ASC bundle set. With Tuist gone it is no longer
  declared. The AUv3 target #121 removed was revived by #1385 as the BodyVibe instrument
  (`com.echoelmusic.app.auv3`), not as `EchoelVoice`; `.voice` stays undeclared. Do not
  re-declare it without a founder ask.
- **TestFlight signing** is pure App Store Connect API key (no Match). Required GitHub Actions
  secrets: `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
  `APP_STORE_CONNECT_PRIVATE_KEY`, `APPLE_TEAM_ID`. See `.github/workflows/testflight.yml`.

## Cross-platform vision

iPhone is the instrument and the hub; every other surface extends it meaningfully — see
`scratchpads/PLAN_MULTIPLATFORM_LINKING.md`.
