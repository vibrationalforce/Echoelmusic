# Runde 1 — code-reviewer

Range `1814d6b10..08ded356a` · Workflow `wf_19315ca5-304` · gesagt: CHANGES

## Zusammenfassung

The code does what the spec asks. PluginUnlock defines the group and the key once (criterion 1). StoreController's init now runs refreshOwned at launch, and every pass writes the result (criterion 2). PluginLicense reads the record first and falls back to StoreKit otherwise (criterion 3). Both targets request group.com.echoelmusic.shared (criterion 4). Swift 6 isolation is clean: PluginUnlock is a nonisolated enum with Sendable statics, it is called synchronously from the MainActor in the app and from a nonisolated Task in the extension, and nothing runs on a render path. There are no force unwraps or prints, and the new file imports Foundation. One major finding: the new comments in project.yml and EchoelPlugins.entitlements say a group the profile lacks fails at signing, so a mismatch can never reach a device. The spec's Assumption 2 and Criterion 6 say this is not guaranteed, and so does the legacy -3000 evidence quoted in the same comment. A session that hits -3000 in AUM would rule out the one suspect the spec names first. The minor findings are: the Transaction.updates listener now starts only after the first entitlements pass; the record's refund and account-switch latency is not documented; the app's CODE_SIGN_ENTITLEMENTS comment is stale; a missing entitlement is silent; and the canonical identity doc plus F17 still say neither target asks for a group.

## Befunde

### 1. major — `EchoelStudio/project.yml`:95

The new comment ends: "A group the profile lacks fails signing in studio-testflight.yml, so a mismatch never reaches a device." Three things refute it. Spec Assumption 2 says "Das ist nicht garantiert". Line 93 of the same comment says the legacy extension failed in every host with -3000, so its mismatch signed fine and reached devices. Tests/CISmoke/TheAUv3RegistersAndStaysIsolatedTests.swift:118-121 says the same: the component registers and then returns -3000. The same overclaim is in EchoelPlugins.entitlements:8-9 ("if it ever does not, studio-testflight.yml fails at signing and uploads nothing"). This is the comment Criterion 4 asks to describe the new situation, and it tells whoever triages Criterion 6 to rule out the one suspect the spec names first.

**Vorschlag:** In both places, replace the guarantee with what is actually known. A mismatch MAY fail at signing, as F17 did for the app. It may also sign and only fail in the host with -3000, as the legacy extension did. In that case this entitlement is the first suspect: remove the key from EchoelPlugins.entitlements (Criterion 6).

### 2. minor — `EchoelStudio/App/Store/StoreController.swift`:22

`await self?.refreshOwned()` now runs before `for await result in Transaction.updates`. The updates listener therefore only starts after the first full currentEntitlements pass, while Apple's guidance is to listen from launch. Unfinished transactions get finished late, and any update delivered during that window depends on StoreKit buffering it. The impact is low because currentEntitlements already covers what the record needs.

**Vorschlag:** Keep the updates loop as the first thing in its Task, and run the launch refresh in its own `Task { [weak self] in await self?.refreshOwned() }`, or start it after the listener is created.

### 3. minor — `EchoelStudio/Plugins/Shared/PluginLicense.swift`:9

A recorded `true` returns before the StoreKit loop that checks `revocationDate`. The record is per device, not per Apple account. A refund, or a switch to an account that never bought, made while the app is not running keeps the instruments unlocked in hosts until the app launches again. The spec accepts this order (container first), but neither the PluginUnlock doc nor the PluginLicense doc says so, and PluginUnlock.swift:30 describes only the false case.

**Vorschlag:** Add to the recordedOwned() doc that a true record outlives a refund or an account change until the app's next launch refresh. That way nobody later 'fixes' the refund path in the extension's StoreKit branch, which the record bypasses.

### 4. minor — `EchoelStudio/Plugins/Shared/PluginUnlock.swift`:27

`UserDefaults(suiteName:)` does not return nil when the App Group entitlement is missing; it quietly returns a process-local domain. Without the entitlement, recordOwned() writes into the app's own sandbox, and the extension reads its own (false), with no log line anywhere. The `?? false` and the doc's "container is unavailable" case never cover the failure that matters for device criteria 6 and 7.

**Vorschlag:** In recordOwned(), check `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: sharedGroup) != nil` once and log a warning with `Logger` when it is nil. Device triage can then tell 'not entitled' apart from 'not bought'.

### 5. minor — `EchoelStudio/project.yml`:84

The comment above the app's `CODE_SIGN_ENTITLEMENTS` still says "The App Group the earlier app saved its songs in; read once to import them." After this diff the file requests a different group (group.com.echoelmusic.shared), which holds the plugin purchase. The songs group is deliberately absent.

**Vorschlag:** Reword it to: the shared container where the app records the plugin purchase (PluginUnlock); the earlier songs group returns as a second entry once F17 is resolved.

### 6. minor — `docs/dev/APP_STORE_CONNECT.md`:56

This diff makes the canonical identity map false. Lines 56-58 say "the Studio's entitlements file asks for NO App Group", and lines 61-62 say "`com.echoelmusic.app.auv3` has **no** App Group (correct — see the row above)". docs/dev/FOUNDER_INBOX.md:277 (F17) likewise still reads "(harmlos, die Erweiterung verlangt keine Gruppe)".

**Vorschlag:** Update both documents in the same commit: app and extension now request group.com.echoelmusic.shared for the plugin purchase record (factory job 002).

