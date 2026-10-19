# Runde 1 — security-agent

Range `1814d6b10..08ded356a` · Workflow `wf_19315ca5-304` · gesagt: CHANGES

## Zusammenfassung

Security/privacy review of 1814d6b10..08ded356a (factory job 002, round 1). The App Group design itself is sound from this lens. Only same-team processes whose profile carries group.com.echoelmusic.shared can write the record. The extension only reads it and never writes. Nothing leaves the device: no network, no logging of the purchase state, no iCloud sync of these defaults. A missing entitlement fails closed, because UserDefaults(suiteName:) without the group falls back to a private domain, the extension reads false and the demo stays. The change does break the App Store privacy-manifest rules. The diff makes the extension's first required-reason API call: UserDefaults in PluginUnlock.recordedOwned, compiled into EchoelPlugins through Plugins/Shared. The extension's PrivacyInfo.xcprivacy still declares an empty NSPrivacyAccessedAPITypes, even though its own comment says to declare the API in the same commit that first calls it. The app's manifest declares only CA92.1. Apple defines CA92.1 as app-only and gives App Group suites their own reason, 1C8F.1, which the repo's root manifest already uses for exactly this case. The rest is minor: comments that overclaim signing safety, a stale entitlement comment, and the known weakness of a sticky, unauthenticated Bool (the spec accepts it).

## Befunde

### 1. major — `EchoelStudio/Support/Plugins/PrivacyInfo.xcprivacy`:13

The extension now calls a required-reason API: PluginUnlock.recordedOwned() calls UserDefaults(suiteName:).bool(forKey:), and project.yml compiles all of Plugins/Shared into EchoelPlugins. The extension's manifest still has an empty NSPrivacyAccessedAPITypes array. Lines 11-12 of the file say "The extension calls no required-reason API ... Declare one here in the same commit that first calls it", and the diff does not touch the file. The repo's own guard header (Tests/CISmoke/ThePrivacyManifestIsDeclaredForBothTargetsTests.swift:7-8) records that Apple rejects at upload with ITMS-91053 when a bundle uses a required-reason API it does not declare. Each bundle is scanned separately, so the .appex is affected.

**Vorschlag:** Add an NSPrivacyAccessedAPICategoryUserDefaults dict with reason 1C8F.1 (App Group defaults shared with the containing app) to the extension's manifest, and replace the "calls no required-reason API" comment with what now calls it (PluginUnlock.recordedOwned).

### 2. major — `EchoelStudio/Support/App/PrivacyInfo.xcprivacy`:21

The app now writes App Group defaults (PluginUnlock.recordOwned via StoreController.refreshOwned, StoreController.swift:85), and the extension reads them. The manifest declares UserDefaults with CA92.1 only. Apple's definition of CA92.1 is information accessible only to the app itself, and it does not permit writing information other apps or extensions can read. The App Group case is reason 1C8F.1. The repo's root Resources/PrivacyInfo.xcprivacy:48-52 declares CA92.1 plus 1C8F.1 for exactly this situation. As it stands, the declared reason does not match what the code does (5.1.1 accuracy). The comment at line 15 also lists only the App/Engine callers.

**Vorschlag:** Add <string>1C8F.1</string> next to CA92.1 and add the plugin-purchase record (PluginUnlock.recordOwned, group.com.echoelmusic.shared) to the comment at line 15.

### 3. minor — `EchoelStudio/Plugins/Shared/PluginLicense.swift`:9

The recorded true short-circuits StoreKit and stays sticky. A refund or revocation (revocationDate set) reaches the extension only when the app next runs refreshOwned (at launch or through Transaction.updates while the app is alive). A buyer who refunds and never opens Echoel Studio again keeps the plugins unlocked in AUM or GarageBand indefinitely. The record is also an unauthenticated plist Bool that can be edited on a jailbroken device. The spec accepts both (Bool, read the container first), so this is not a blocker.

**Vorschlag:** Optional: record a timestamp of the last verified pass next to the Bool and treat a stale true as unknown, falling back to StoreKit. At minimum, state the revocation lag in the PluginUnlock doc comment so nobody reads the record as revocation-safe.

### 4. minor — `EchoelStudio/project.yml`:96

The comment says "A group the profile lacks fails signing in studio-testflight.yml, so a mismatch never reaches a device", and EchoelPlugins.entitlements:9 makes the same claim. The spec's own Assumptions say this is NOT guaranteed, and the repo has the counter-example: Tests/CISmoke/TheAUv3RegistersAndStaysIsolatedTests.swift:118-122 records an AUv3 that signed with an App Group its App ID lacked and then failed with -3000 in every host. A future session that trusts this comment would skip device check 6 (the AUM load test that comes first).

**Vorschlag:** Reword both comments to match the spec: a mismatch PROBABLY fails at signing, but the legacy extension signed and then hit -3000 in hosts, so the first device check is the AUM load test, and if it fails, the group entry in EchoelPlugins.entitlements is the first suspect.

### 5. minor — `EchoelStudio/project.yml`:84

The comment above the app's CODE_SIGN_ENTITLEMENTS still says "The App Group the earlier app saved its songs in; read once to import them." That group (group.com.echoelmusic) is not requested. The file now requests group.com.echoelmusic.shared for the plugin-purchase record, so the reason given for this entitlement reference is stale.

**Vorschlag:** Update the comment: the entitlements request group.com.echoelmusic.shared (plugin purchase record, job 002), and group.com.echoelmusic (song import) is still waiting on F17.

