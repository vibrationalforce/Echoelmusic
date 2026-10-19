# Runde 2 — ux

Workflow `wf_b2b87d43-108`, Bereich `08ded356a..edb5a5d7b` mit `paths`, Urteil der Linse: **PASS**.

## Zusammenfassung

Round 2, ux lens (user-advocate and claims), range 08ded356a..edb5a5d7b.

Earlier findings:
- R1 #1 (major, privacy sentence and its twins): FIXED. About → "Your data" (AboutView.swift:22), SECURITY.md:4-6, docs/roadmap.html:96 and docs/privacy.html:107 now all name the App Store check at launch. They match the code: StoreController.init:29 starts an unconditional refreshOwned() pass, and EchoelStudioApp.swift:11 constructs the controller at launch. That pass reads only Transaction.currentEntitlements, so the user sees no sign-in prompt. The privacy.html phrase "a container only Echoel and its own Audio Units can read" is true: git grep finds group.com.echoelmusic.shared only in the two Studio targets.
- R1 #2 (major, comments promising a signing failure): FIXED. EchoelStudio/project.yml:94-100, EchoelPlugins.entitlements:7-11, PluginUnlock.swift:19-20, APP_STORE_CONNECT.md and F17 now carry the hedge. The project.yml comment says a failed archive prints every profile's groups; studio-testflight.yml:137-145 confirms that.
- R1 #3 (minor, in-plugin remedy sentence): rebutted with a reason and moved to "Out of scope" until E8. Accepted: the live copy still says "The unlock is not on sale yet" (PluginControlsView.swift:104), so the remedy sentence would contradict it. The second half, qualifying the StoreController doc comment, was neither applied nor rebutted (see below).
- R1 #4 (minor, an empty pass demotes a buyer): rebutted, and covered by device criterion 10. Accepted.

New findings: the diff changes no UI except one string. So VoiceOver, Dynamic Type, contrast, reduce-motion, the 3 Hz flash limit and the Uncodixfy rules all pass by construction. No health, wellness or esoteric wording was added. Every remaining finding is minor: copies of a claim this round corrected in some places but not all of them (#456), and one narrowed sentence. No blocker or major finding.

## Befunde

1. **minor** `EchoelStudio/App/Views/AboutView.swift:22` — The new sentence names only two App Store uses: the launch check and "for prices when you open the store". The old wording, "when you open the store", covered every store-screen use. The new one leaves out Restore Purchases (StoreView.swift:24 → StoreController.restore → AppStore.sync()), which always contacts the App Store, and the later buy(). SECURITY.md:5 narrows the same way. The other twins disagree: docs/roadmap.html:96 keeps the broad form ("when you open the store screen"), and docs/privacy.html:107 names Restore Purchases. The user starts both actions, so nobody is misled, but an "only for" sentence should list every use.
   - Vorschlag: Write "... at launch, to check whether you bought Echoel Plugins, and when you open the store (prices, buying, Restore Purchases) — ...". Make the same change in SECURITY.md:5 so the three twins say the same thing.

2. **minor** `EchoelStudio/RELEASE:15` — The device test list still says '"Your data" names the App Store (when you open the store)'. This diff changed that sentence, so a tester following RELEASE would check for a sentence that no longer exists. RELEASE is a fourth twin of the corrected sentence; criterion 11 counts only three. The header line 'All four carry no App Group entitlement' will also be wrong for the first build that carries this commit.
   - Vorschlag: In the RELEASE bump that ships this commit, update the 'Your data' check to the launch-time wording. Add device criteria 6-10 to 'What to try on the device', with criteria 9 and 6 first.

3. **minor** `EchoelStudio/Support/App/EchoelStudio.entitlements:14` — This round retracted 'both profiles carry it (F17)' in PluginUnlock.swift:19-20, project.yml, EchoelPlugins.entitlements, APP_STORE_CONNECT.md and F17: whether the .auv3 profile grants the group is open. Two copies still state it as fact. One is the app's entitlements comment, lines 14-15: 'both profiles carry it (F17)'. The other is spec.md Assumption 1, scratchpads/factory/002-plugin-unlock-app-group/spec.md:17: '... UND com.echoelmusic.app.auv3 tragen sie bereits. Kein Portal-Schritt.' That contradicts APP_STORE_CONNECT.md's new hand-tick instruction for com.echoelmusic.app.auv3.
   - Vorschlag: Change both to the hedged form: the app's profile grants it (F17 run), and whether the .auv3 profile does is decided by the next Studio archive, followed by the AUM load test.

4. **minor** `docs/dev/FOUNDER_INBOX.md:277` — The F17 row now says that the next Studio archive run decides whether the .auv3 profile grants the group the extension requests, so that run may fail at signing. Its status cell still says 'Studio-Route seit Versuch 4 nicht mehr blockiert' without qualification. The founder reads the status cell first.
   - Vorschlag: Qualify the status cell, for example: '… seit Versuch 4 nicht blockiert; seit Job 002 entscheidet der nächste Archiv-Lauf, ob die .auv3-Gruppe fehlt'.

5. **minor** `EchoelStudio/App/Store/StoreController.swift:7` — Second half of R1 #3, neither applied nor rebutted. The doc comment still says the purchase 'unlocks every plugin in every host on every device of the same Apple account' with no precondition. Under the new design an unlock in a host needs the app to have run its launch pass on that device. PluginUnlock.swift:39 now says 'on THIS device'. Also, 'every plugin' overstates it: only the instruments are locked, the effects are free.
   - Vorschlag: Change it to '... unlocks Echoel's instruments in every host on a device of the same Apple account once the app has run there ...'.
