# Runde 1 — e2e-test-agent

Range `1814d6b10..08ded356a` · Workflow `wf_19315ca5-304` · gesagt: CHANGES

## Zusammenfassung

Ship-path review, round 1, of 1814d6b10..08ded356a (one commit, 08ded356a). Gates: `Echoel Studio` (studio.yml) run 39337215366 on 08ded356a was green. In it, "Core + DSP + Engine" passed all steps, and "App (iPhone + iPad)" passed Generate project, Build for iOS Simulator (Debug) and Build for iOS device (Release). The app scheme depends on the EchoelPlugins target, so criterion 5 is met. That run proves compilation only: both app builds pass CODE_SIGNING_ALLOWED=NO (studio.yml:142, :153), so the new entitlements files are never signed or checked against a profile there. `Echoel Studio TestFlight` was NOT TRIGGERED: EchoelStudio/RELEASE is unchanged, and the last upload, run 7 on bab0f614a, contains no App Group. So whether the new `.shared` request survives signing is UNPROVEN, and so is whether the extension still launches in a host (criterion 6, -3000). What is consistent: targets 2/2 in EchoelStudio/project.yml (app plus extension, and the extension is embedded as a dependency). The App Group string is the same in EchoelStudio.entitlements:19, EchoelPlugins.entitlements:12 and PluginUnlock.swift:22. Both entitlements files are well-formed (checked with plistlib). CODE_SIGN_ENTITLEMENTS points at an existing file relative to the spec root. The network-allowlist step still passes. EchoelStudio/project.yml is not covered by the founder gate, which protects only the root project.yml. Blocking: (1) the extension's privacy manifest still declares no required-reason API, although this commit adds UserDefaults to the extension, and the app's UserDefaults reason (CA92.1) does not cover writing to an App Group. (2) Two new comments say that a group/profile mismatch always fails signing and so cannot reach a device. The spec's own Assumption 2 and the legacy -3000 history contradict that. Verdict for shipping: UNPROVEN until the next RELEASE bump's Archive step and the AUM device check.

## Befunde

### 1. major — `EchoelStudio/Support/Plugins/PrivacyInfo.xcprivacy`:11

The extension's privacy manifest says 'The extension calls no required-reason API … Declare one here in the same commit that first calls it' and keeps NSPrivacyAccessedAPITypes empty (lines 11-14). This commit is that first call: PluginLicense.swift:9 calls PluginUnlock.recordedOwned(), which runs `UserDefaults(suiteName: sharedGroup)?.bool(...)` (PluginUnlock.swift:32), and Plugins/Shared is compiled into EchoelPlugins (project.yml:104). NSUserDefaults is a required-reason API (NSPrivacyAccessedAPICategoryUserDefaults). App Store Connect checks each bundle's binary against its own manifest, so the next upload should draw ITMS-91053 'Missing API declaration' for EchoelPlugins.appex, which Apple's policy blocks for App Store submission. The app has a second gap. Its manifest declares UserDefaults only with CA92.1 (EchoelStudio/Support/App/PrivacyInfo.xcprivacy:15-22), and CA92.1 does not permit writing data that other members of an App Group can read. PluginUnlock.recordOwned (PluginUnlock.swift:27) now does exactly that, so the app needs 1C8F.1. No CI step checks manifests, so nothing here catches either gap before upload.

**Vorschlag:** In Support/Plugins/PrivacyInfo.xcprivacy, add an NSPrivacyAccessedAPICategoryUserDefaults entry with reason 1C8F.1, and replace the 'calls no required-reason API' comment with what it now reads. In Support/App/PrivacyInfo.xcprivacy, add 1C8F.1 next to CA92.1 for the UserDefaults category, and name the shared-group write in its comment.

### 2. major — `EchoelStudio/project.yml`:95

The new comment (project.yml:95-96) ends 'A group the profile lacks fails signing in studio-testflight.yml, so a mismatch never reaches a device.' The new EchoelPlugins.entitlements:8-9 says the same: 'if it ever does not, studio-testflight.yml fails at signing and uploads nothing.' The spec this job implements says the opposite, in Assumption 2: 'Das ist nicht garantiert: die Alt-App-Erweiterung signierte mit einer Gruppe, die ihre App-ID nicht trug, und scheiterte erst im Host mit -3000.' The repo's own history supports the spec: EchoelmusicAUv3.entitlements records an extension that signed, uploaded and then returned -3000 in every host, and Tests/CISmoke/TheAUv3RegistersAndStaysIsolatedTests.swift:118-122 pins that lesson. Both comments therefore claim that a green signing step proves the device outcome, and it does not. These comments stay in the spec file and the entitlements file, and a later session will read them when deciding whether the AUM device check (criterion 6) is still needed.

**Vorschlag:** Say what was measured. For example: 'A group the profile lacks usually fails signing in studio-testflight.yml (F17), but the legacy extension signed and then failed in every host with -3000, so a green upload does not prove the extension launches. Load it in AUM first (factory job 002, criterion 6).' Apply the same wording to EchoelPlugins.entitlements:8-9.

### 3. minor — `EchoelStudio/project.yml`:84

The comment directly above the app's `CODE_SIGN_ENTITLEMENTS: Support/App/EchoelStudio.entitlements` still says 'The App Group the earlier app saved its songs in; read once to import them.' After this commit that file requests only `group.com.echoelmusic.shared`, for the plugin purchase. The songs group `group.com.echoelmusic` is still absent (EchoelStudio.entitlements:5-16), so the comment now describes a group with a different purpose. A reader could take `.shared` for the songs container.

**Vorschlag:** Reword it, for example: 'App Group group.com.echoelmusic.shared (plugin purchase record, PluginUnlock); the earlier app's songs group returns with F17.'

### 4. minor — `EchoelStudio/App/Views/AboutView.swift`:22

The About text the user sees says 'Echoel uses the network only for the App Store, when you open the store, …'. Since this commit, StoreController.init (StoreController.swift:21-22) iterates Transaction.currentEntitlements on every launch, without the store being opened, which is the spec's deliberate choice. Whether that read reaches the network (for example on a fresh install, before StoreKit's local transaction store is filled) is unmeasured. If it does, the 'when you open the store' clause becomes a privacy statement that is false. This touches the UX/security lenses too; it is noted here because store copy is on the ship path.

**Vorschlag:** Either check that currentEntitlements stays local, or reword the clause, for example: 'for the App Store (checking your purchase at launch, and when you open the store)'.

### 5. minor — `EchoelStudio/RELEASE`:29

No Echoel Studio build has yet been confirmed to load in AUM on a device: the AUM/GarageBand step is still an open test item, and line 14 says nothing is device-verified. Criterion 6 says that if a -3000 appears, the new group is 'der erste Verdächtige'. Without a no-group baseline, though, a -3000 on the first build with the group cannot be attributed to the group rather than to the extension itself. The current TestFlight build (studio-testflight run 7, bab0f614a, no App Group) is that baseline. Separately, this commit does not bump RELEASE, so no build with the group exists yet.

**Vorschlag:** On the next RELEASE bump that ships this change, order the device test list: (a) load the current no-group build in AUM, then (b) the new build. Alternatively, record the baseline result in FOUNDER_INBOX §2 before the bump.

