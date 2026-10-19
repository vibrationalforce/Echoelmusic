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
| Echoelmusic AUv3 | `com.echoelmusic.app.auv3` | Audio Unit v3 instrument extension (`aumu`/`echl`) | ✅ **embedded + builds** — REVIVED 2026-09-20 (#1385, founder ask) after its removal 2026-07-24 (#121 Slice 1); ships inside the host app like the widget (`project.yml` app dependencies), loads in AUM (device-measured, #1386). **No App Group**: the App ID lacks the capability, and with the key iOS refuses to launch the appex (`-3000`), so its entitlements file is deliberately empty. ⛔ This row said "TARGET DELETED" until 2026-09-25. |
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
- `com.echoelmusic.app` carries App Groups (needed for the import of earlier songs — ⛔ since `2b9956c`
  (2026-10-19) the Studio's entitlements file does not ask for `group.com.echoelmusic`, because the
  profile no longer grants it; the key comes back once the founder re-ticks it, FOUNDER_INBOX F17. ⭐
  Since factory job 002 (2026-10-19) it asks for `group.com.echoelmusic.shared`, which the profile
  grants: the app records the plugin purchase there for the extension, `PluginUnlock`) plus many capabilities the earlier app used (HealthKit, iCloud/CloudKit, Push, Sign in
  with Apple, Siri, WeatherKit, MusicKit, ShazamKit, Maps, Data Protection „Complete" …). An App ID
  capability only PERMITS an entitlement; what App Review sees is the binary's entitlements, and the
  Studio's file asks for nothing beyond the defaults today (the App Group alone once it returns). Do not untick them while builds of the earlier app exist.
- `com.echoelmusic.app.auv3` had **no** App Group in these recordings and only Sign in with Apple
  ticked, which nothing uses. ⚠️ The F17 run of the same evening printed the ISSUED .auv3 profile
  carrying `group.com.echoelmusic.shared`, and since factory job 002 the extension requests it (to read
  the plugin purchase). The two readings disagree; the next Studio archive settles it — on failure
  `studio-testflight.yml` prints every profile's groups. If the group must be ticked by hand:
  Identifiers → `com.echoelmusic.app.auv3` → App Groups → `group.com.echoelmusic.shared`.

> **Deferred platforms** (macOS / tvOS / visionOS) were previously declared only in the removed
> Tuist `Project.swift`. They are **not currently defined anywhere** and would be re-added to
> `project.yml` in a dedicated, signing-verified cycle when actually built (iPhone-first for now).

### App Group

| App Group | Status |
|---|---|
| `group.com.echoelmusic` | Canonical (entitlements + `CLAUDE.md`). Used by the earlier app, its widget and the unembedded watch target (`git grep -l group.com.echoelmusic -- '*.entitlements'`); the AUv3 carries none on purpose. ⛔ **Measured 2026-10-18/19 (Studio TestFlight runs 39158721875, 39158926622, 39180435790): the profile Apple issues for `com.echoelmusic.app` grants only `group.com.echoelmusic.shared`.** The last earlier-app upload (run 38996952047, 2026-10-17 03:04) still signed with `group.com.echoelmusic`, so the group left the App ID between those dates. Until the founder re-ticks it (F17), every earlier-app build that asks for it fails at signing. |

> ⚠️ **Discrepancy to resolve owner-side:** `fastlane/Appfile` reference comments mention
> `group.com.echoelmusic.shared`. The committed entitlements use `group.com.echoelmusic`.
> Confirm which App Group is registered in the Apple Developer portal and make the Appfile
> comment match the entitlements. Mismatched App Group IDs break signing/provisioning.

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
