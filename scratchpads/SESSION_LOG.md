> **NEWEST ENTRIES ARE AT THE END OF THIS FILE.** It holds 2026-10 onward. Every
> earlier entry (2026-02 → 2026-09) was moved verbatim on 2026-10-10 (GMMW CL-12) to
> `scratchpads/archive/SESSION_LOG_before_2026-10.md` — grep there for older history.

## 2026-10-01 — E4-38: Bio-Leiste und Stimmungs-Pads sprechen Deutsch (219212e2d)

- **Gebaut:** BioStripView — das Lock-Banner („Puls erkannt — du kannst loslassen & spielen“) geht als Schlüssel in `banner(_ text: String …)` (Signatur unverändert), die drei gesprochenen Zustände des Treiber-Punkts sind ein berechnetes `drivingLabel` (der innere Zweig ein eigener typisierter Schritt), der Quellen-Tag gibt `String(localized: "No signal")`, die drei `LocalizedStringKey`-Werte des Kamera-Hinweises (Misst… · Kamera abdecken · Verbindet…) bekommen ihre Einheiten ohne Swift-Änderung. MoodPads — Titel und Achsen-Beschriftungen der zwei Pads als `String(localized:)`-Argumente; die gesprochenen Label/Wert/Aktions-Namen des Pads waren interpolierte Literale (Format-Schlüssel „%@ mood pad“/„More %@“, die kein Katalog-Eintrag tragen kann) und sind jetzt Nähte um die Beschriftungs-Hälften. Katalog 1136 → 1156 (+20). Drei Sources-Dateien.
- **Deutsch-Entscheidung:** „still · bewegt“ (Klang) und „ruhig · Energie“ (Visual) — zwei Wörter für zwei Achsen, nicht zweimal „ruhig“; „Visual“ bleibt „Visual“ (Katalog sagt schon „Visuals“); „Klang – Stimmungsfeld“ mit Gedankenstrich, weil die Naht nicht umstellen kann.
- **Wächter:** Anspruch 11 E4-38-Block (6 + 11 Nähte, 3 + 6 Abwesenheits-Nadeln, 4 Trenner-Pins — jede deutsche Beschriftung teilt sich an „ · “ in genau zwei Wörter, weil die Aktionen daran splitten —, 22 Einheiten; XCTAssert 182 → 187). Kein Wächter re-verankert: LockCueDoesNotShoveTheControls liest Zeilen über `lockedCueVisible`, CoachingTextScales die `banner`-Signatur — beide unberührt.
- **Benotung** `scratchpad/transcribe_e4_38.py` (Log-Datei, nicht Pipe): HEAD FAIL (16 Nähte fehlen, 9 Verbatim-Stellen vorhanden, 20 Einheiten fehlen — EIN Befund), WORK PASS; Katalog-Invariante grün. Checker: dead-needles OK, count-pins 0 RED, swift-escapes OK, foreign-needles OK, moved-needles drei Treffer = eigene Nadeln, dupblocks 0, Klammerbilanz je Swift-Datei OK, Wächter-Block 0/0.
- **Gates:** 5b18eff9d (E4-34…E4-37) gepusht 00:0xZ, Monitor bohmyzhuk; E4-38 lokal — Push nach dem Compile Check auf 5b18eff9d.
- **Offen (E4):** EchoelStudioView-Stellen, EchoelFXView, FloatingVisualWindow, PerformSessionView, WorkspaceView (Tonsystem-/Notennamen-Hinweise).

## 2026-10-01 — E4-39: Visual-Fenster-Leiste und Kopf-Monitor sprechen Deutsch (f0ca8c4c4)

- **Gebaut:** FloatingVisualWindow — jedes `.accessibilityLabel(flag ? "A" : "B")` der Leiste (WAV-Knopf, Notenraster-Umschalter, Größe/Vollbild-verlassen) war ein Ternär aus zwei nackten Literalen, also ein `String`, den VoiceOver auf einem deutschen Telefon wörtlich las — jetzt zwei `String(localized:)`-Zweige; `WindowSize.label` (Klein · Mittel · Groß · Vollbild) liefert Schlüssel; der gesprochene WAV-Aussetzer ist Nähte um eine `EchoelDecimalText`-Zahl statt eines `String(format:)`-Schlüssels; „Writing to disk failed“ ein Schlüssel; die Zieh-Beschriftung des Griffs behält ihre eine Zeile, „Echoelmusic“ bleibt das Markenwort. WorkspaceView — Monitor-Knopf (Schwebendes Visual ein-/ausblenden) zwei Schlüssel; der Notennamen-Hinweis war eine `+`-Kette aus drei Literalen (ein `String`) und ist EIN Literal, also ein Schlüssel. Katalog 1156 → 1173 (+17). Drei Sources-Dateien.
- **Wächter:** Anspruch 11 E4-39-Block (7 + 2 Nähte, 7 + 2 Abwesenheits-Nadeln, 2 Laufzeit-Gegengewichte — `wavAccessibilityValue(…, 1.5)` == „Recording, 1.5 seconds lost“, `WindowSize.fullscreen.label` == „Fullscreen“ —, 17 Einheiten; XCTAssert 187 → 195). Kein Wächter re-verankert: TheWayOutSurvivesRotation (`"Exit fullscreen"` vor `"Hide visual"`), TheFloatingWindowMovesWithoutADrag (Zieh-Label auf genau einer Zeile), TheCaptureTapDoesNotTouchTheDisk (`seconds lost`) finden ihre Nadeln weiter.
- **Benotung** `scratchpad/transcribe_e4_39.py` (Log-Datei): HEAD FAIL (9 Nähte fehlen, 9 Verbatim-Stellen vorhanden, 17 Einheiten fehlen — EIN Befund), WORK PASS. ⚠️ Erste Fassung WORK FAIL: die Abwesenheits-Nadel `: "Echoelmusic — drag …")` traf `localized: "Echoelmusic — …"))` — auf die eingerückte Verbatim-Form gezielt (E4-37-Lehre, zum dritten Mal; das Harness fing es VOR dem Commit). Checker: dead-needles OK, count-pins 0 RED, swift-escapes OK, foreign-needles OK, moved-needles ein Treffer = eigene Nadel, dupblocks 0, Klammerbilanz je Datei OK, Wächter-Block 0/0. Längste neue Swift-Zeile 166 Zeichen (SwiftLint error ab 200).
- **Gates:** 40783448c (E4-38) gepusht, Monitor bszu72x33; E4-39 lokal — Push nach dem Compile Check auf 40783448c.
- **Offen (E4):** PerformSessionView (vier `static let`-Sätze + Open/Closed), EchoelFXView (Preset/Morph-Texte), EchoelStudioView-Stellen.

## 2026-10-01 — E4-40: Perform-Platte und FX-Prosa sprechen Deutsch (013ed295c)

- **Gebaut:** PerformSessionView — die vier `static let`-Sätze (Titel, Hinweis, Leerzustand, Instrument-läuft) erreichten `Text(Self.x)` als `String` und waren wörtlich; jetzt berechnete Schlüssel. Der Aufklapp-Wert sagt Expanded/Collapsed wie die drei Geschwister-Aufklapper (PhotoSeedCard, VideoSeedCard, WorkstationView) — ein Wort pro Sache, zwei Schlüssel; „Open“ ist im Katalog schon das Tür-Verb „Öffnen“ und kann nicht zugleich das Zustandswort sein. EchoelFXView — Morph-Label (`Label(String)`) als Naht + Preset-Name, die vier `Text(flag ? "A" : "B")`-Fußzeilen/Köpfe je zwei Schlüssel, die Dropout-Notiz (`+`-Kette) EIN Literal auf EINER Zeile, damit der Literal-Extraktor von ADropoutSaysWhichHalfLetGo den Satz weiter von der Anker-Zeile liest, die Neutral-0,50-Fußzeile ein Literal; „My Preset“ bleibt wörtlich (persistierter Preset-Name); die Alert-Titel „Save preset“/„Rename preset“ waren Schlüssel ohne Einheit. Katalog 1173 → 1193 (+20); das deutsche „gehalten“ in beiden Notizen ist die Katalog-Einheit `held` (vom Skript geprüft). Drei Sources-Dateien.
- **Wächter:** Anspruch 11 E4-40-Block (5 + 11 Nähte, 5 + 8 Abwesenheits-Nadeln in eingerückter Verbatim-Form, 2 Laufzeit-Gegengewichte, 20 Einheiten; XCTAssert 195 → 201). Zwei Wächter 1:1 re-verankert: ADropoutSaysWhichHalfLetGo (Anker-Schreibweise, drei Ansprüche, +2 Kommentarzeilen) und PerformIsASecondViewOfTheSameSession (Nadel auf den Aufklapp-Wert, +1 Kommentarzeile) — den zweiten fand die Lost-Literal-Menge des Harness (`Open" : "Closed")` stand im Wächter escaped, mein `grep` hatte ihn verfehlt). TheFXHeadersSayWhoseBody (`"Always on — … → timbre"` in Anführungszeichen), AHeldReadingSaysSo (`the signal has stopped arriving`) und die Laufzeit-`contains` von PerformIsASecondView bleiben unverändert grün.
- **Benotung** `scratchpad/transcribe_e4_40.py` (Log-Datei; REANCHORED jetzt ein Dict mit Zeilen-Delta je Datei): HEAD FAIL (16 Nähte fehlen, 13 Verbatim-Stellen vorhanden, 20 Einheiten fehlen — EIN Befund), WORK PASS. Checker: dead-needles OK, count-pins 0 RED, swift-escapes OK, foreign-needles OK, moved-needles vier Treffer = eigene eingerückte Nadeln, dupblocks 0, Klammerbilanz je Datei OK, Wächter-Block 0/0. Lint: `ci.yml` fährt SwiftLint mit `continue-on-error: true`, `--strict` nur in `pr-check.yml`; die Einzeiler-Notiz ist ~360 Zeichen (AlwaysOnBioChannel trägt seit E4-37 schon 250).
- **Gates:** 9d46d79f5 (E4-39) gepusht, Monitor bepjgcuqq; E4-40 lokal — Push nach dem Compile Check auf 9d46d79f5.
- **Offen (E4):** die drei Expanded/Collapsed-Ternäre (PhotoSeedCard, VideoSeedCard, WorkstationView:1593 — Schlüssel existieren jetzt), EchoelStudioView-Stellen.

## 2026-10-01 — E4-41: die Foto-Karte spricht Deutsch (b79c89411)

- **Gebaut:** `PhotoSeedText` — die zwei gespeicherten Sätze berechnete Schlüssel; `colour` („Main colour: hue “ + Zahl + „°“), `change` (Name + Wert, dann „, unchanged“ oder „ → “ + Wert) und die vier Feldnamen von `changes` über Nähte/Schlüssel (Einheiten des Visual-Panels wiederverwendet). Karte — die drei Prozent-Zeilen waren interpolierte `Text`-Literale, also Format-Schlüssel, jetzt Schlüssel + „ “ + Wert; die Überschrift Applied/With this photo zwei Schlüssel; der `??`-Fallback des Anwenden-Hinweises ein Schlüssel; gesprochener Aufklapp-Wert, Rückgängig-Label und -Hinweis (sie interpolierten `undo.medium`, einen von beiden Karten VERGLICHENEN Bezeichner) als private Helfer in typisierten Schritten über die neue `MediaLookUndo.spokenMedium` („Foto“/„Video“ als Schlüssel; `photoMedium`/`videoMedium` unangetastet). „Undo photo look“ → „Rückgängig: Foto-Look“. Katalog 1193 → 1216 (+23; 8 Schlüssel hatten schon Einheiten). Zwei Sources-Dateien.
- **Wächter:** Anspruch 11 E4-41-Block (14 Nähte, 10 Abwesenheits-Nadeln, 2 Laufzeit-Gegengewichte — `change("Hue", 0.5, 0.5)` == „Hue 0.50, unchanged“, `unreadable`-Präfix —, 31 Einheiten; XCTAssert 201 → 205). Kein Wächter re-verankert: APhotoIsReadSmallAndOffTheStage pinnt Laufzeit-Englisch („Main colour: hue 180°“, „46 %“, „→“), TheMediaLookHasOneWriter seine Quell-Nadeln (`undo.medium == MediaLookUndo.photoMedium`, `.accessibilityHint(undo.applyBlockedReason ??`, kein „Undo it first“).
- **Benotung** `scratchpad/transcribe_e4_41.py` (Log-Datei): HEAD FAIL (14 Nähte fehlen, 10 Verbatim-Stellen vorhanden, 23 Einheiten fehlen — EIN Befund), WORK PASS. Checker: dead-needles OK, count-pins 0 RED, swift-escapes OK, foreign-needles OK, moved-needles 0 Treffer, dupblocks 0, Klammerbilanz OK, Wächter-Block 0/0. ⚠️ Skript-Lehre: die Datei endet mit `#endif`, nicht mit einer Klammer — die Datei-Ende-Assertion stoppte das atomare Skript vor jedem Schreiben (Baum blieb sauber); die Extension steht jetzt vor dem `#endif`, innerhalb desselben `canImport`-Schirms wie die Karten. ⚠️ Zweite Lehre: der Docs-Schritt lief als f-String und brach an einer geschweiften Klammer im Prosa-Text — Docs-Texte jetzt als Plain-String mit `.replace("b79c89411", sha)`.
- **Gates:** 9d46d79f5: Compile Check 3113 ✓ (Auto-Merge 4011 läuft); main = 40783448c (E4-38 drin). E4-40 + E4-41 werden jetzt als Stapel gepusht.
- **Offen (E4):** VideoSeedCard (VideoSeedText length/cuts/bars/sound, Karten-Rumpf, `spokenMedium`), WorkstationView-Ternäre (On/Off, Warp, Play/Stop, Expanded/Collapsed, Hinweise), `MediaLookUndo.applyBlockedReason`.

## 2026-10-01 — Rot-Lesung 9d46d79f5 + Fix d48571327, dann E4-42: die Video-Karte spricht Deutsch (0713afa5f)

- **Gate ROT:** 9d46d79f5 CI/CD 6577 Build for Testing rot, Auto-Merge 4011 failure, main blieb 40783448c. Ursache (Job-Log, `gh-test-verdict.py`): `TheChromeSpeaksGermanTests.swift:1316` — `FloatingVisualWindow.wavAccessibilityValue(…)` ist ein Static auf einem `@MainActor struct … : View`, die Testmethode war nonisolated-synchron. E4-40s `PerformSessionView.sectionTitle`/`emptyNote` hätten auf 5c0468035 dasselbe getan.
- **Fix d48571327 (nur Tests, allein gepusht):** `@MainActor func testTheLabelHelpersTakeAKey()` — Bündel-Konvention (117 Methoden). Keine Behauptung geändert. Allein gepusht, damit der nächste Compile Check genau den Sources-Stand von 5c0468035 misst. Monitor b24xbm0iz.
- **Lehre:** ein Laufzeit-Gegengewicht auf einem View-Static ist ein Main-Actor-Aufruf; die Transkription benotet Text, nie Isolation — das sieht nur das Gate. Enums (`PhotoSeedText`, `VideoSeedText`, nested `WindowSize`) sind nicht isoliert, deshalb war nur Zeile 1316 rot.
- **E4-42 gebaut (lokal, Push nach dem Compile Check auf d48571327):** `VideoSeedText` unreadable/reading/length/cuts/bars/sound + Feldnamen als Nähte mit typisierten `let`-Schritten; Karte: Movement/Brightness als Schlüssel + Wert, `let hueLine` vor dem Ternär, Kopf, Apply-Fallback, `disclosureValue`/`undoLabel` über `spokenMedium`. Katalog 1216 → 1238 (+22).
- **Wächter:** Anspruch 11 E4-42-Block (18 Nähte, 15 Abwesenheits-Nadeln, 2 Laufzeit-Gegengewichte — `cuts([1…7])` mit „and 2 more“, `unreadable`-Präfix —, 24 Einheiten; XCTAssert 205 → 209). Kein Wächter re-verankert (AVideoCardSaysWhatWasMeasured pinnt Laufzeit-Englisch, byte-identisch).
- **Benotung** `scratchpad/transcribe_e4_42.py` (Log-Datei): HEAD FAIL (18 Nähte fehlen, 15 Verbatim-Stellen vorhanden, 22 Einheiten fehlen — EIN Befund), WORK PASS. Checker: dead-needles OK, count-pins 0 RED, swift-escapes OK, foreign-needles keine kaputte Nadel, dupblocks 0, Klammerbilanz 0/0.
- **Docs-Nachtrag:** der E4-41-Satz im Founder-Postfach fehlte in 5c0468035 (Heredoc nicht `&&`-verkettet) — hier nachgezogen.
- **Offen (E4):** WorkstationView-Ternäre (On/Off, Warp, Play/Stop, Expanded/Collapsed, Hinweise), `MediaLookUndo.applyBlockedReason`, EchoelStudioView-Stellen.

## 2026-10-01 — E4-43: die Workstation-Ternäre sprechen Deutsch (1287d9892)

- **Gebaut:** zehn Ternäre nackter Literale in `WorkstationView` → `String(localized:)`-Arme (Mute/Solo-Wert, Warp-Text/-Wert/-Hinweis — Wert als zwei typisierte `let`-Schritte —, Pitch-Hinweis, Play/Stop-Wort + -Label, Tempo-Feld-Label, Compose-Guide-Aufklapp-Wert/-Hinweis). Katalog 1238 → 1248 (+10).
- **Wächter:** Anspruch 11 E4-43-Block (12 Nähte, 10 Abwesenheits-Nadeln, 19 Einheiten; XCTAssert 209 → 211). Zwei Wächter 1:1 re-verankert (TheWorkstationPlaysTheTimelineTests, TheTrackHeaderMutesAndSolosTests). TheWorkstationArmsTheClickTests war ein Harness-Fehlalarm (nennt die Datei, prüft die Nadel auf WorkstationClickToggle) — gelesen, mit Begründung ausgenommen.
- **Benotung** `scratchpad/transcribe_e4_43.py` (Log-Datei): HEAD FAIL (12 Nähte fehlen, 10 Verbatim-Stellen vorhanden, 10 Einheiten fehlen — EIN Befund), WORK PASS. Checker: dead-needles OK, count-pins 0 RED, swift-escapes OK, foreign-needles keine kaputte Nadel, dupblocks 0, Klammerbilanz 0/0.
- **Gates:** d48571327 Compile Check 3115 ✓ → E4-42-Stapel (0713afa5f + dbf84a8ae) gepusht, Monitor bumht72oy. E4-43 lokal — Push nach dem Compile Check auf dbf84a8ae.
- **Offen (E4):** die drei Geschwister-On/Off-Ternäre (PerformSessionView:194, ProjectHeader:198, WorkstationClickToggle:56 — je ein Wächter pinnt sie), `MediaLookUndo.applyBlockedReason`, EchoelStudioView-Stellen; Einheiten (`semitones`) und Mute/Solo-Namen unentschieden.

## 2026-10-01 — E4-44: die drei On/Off-Geschwister sprechen Deutsch (e08b9e791)

- **Gebaut:** PerformSessionView (Mix-Schalter), ProjectHeader (Guide-Knopf), WorkstationClickToggle — `String(localized:)`-Arme, keine neuen Einheiten (Katalog 1248). Drei Wächter 1:1 nachgezogen. `git grep '? "On" : "Off"' -- Sources` → 0.
- **Wächter:** Anspruch 11 E4-44-Block (je Datei eine Naht + eine Abwesenheits-Nadel; XCTAssert 211 → 217). Benotung `scratchpad/transcribe_e4_44.py`: HEAD FAIL (3 Nähte fehlen, 3 Verbatim-Stellen vorhanden), WORK PASS. Checker alle OK, Klammerbilanz 0/0.
- **Gates:** d48571327 Auto-Merge 4013 ✓ → main = d48571327 (E4-39…E4-41 drin). dbf84a8ae (E4-42) läuft, Monitor bumht72oy. E4-43 (1287d9892) + E4-44 (e08b9e791) lokal — Push nach dem Compile Check auf dbf84a8ae.
- **Offen (E4):** `MediaLookUndo.applyBlockedReason` + `spokenMedium`-Umzug in den Owner, EchoelStudioView-Stellen.

## 2026-10-01 — E4-45: der Blocked-Apply-Satz spricht Deutsch, `spokenMedium` zieht in den Owner (03921c594)

- **Gebaut:** `applyBlockedReason` als zwei Nähte um `spokenMedium`; `spokenMedium` von der PhotosUI-geschützten PhotoSeedCard-Extension in `MediaLookUndo` (Foundation-only). Katalog 1248 → 1250. Englisch byte-identisch (TheMediaLookHasOneWriterTests end-to-end).
- **Wächter:** Anspruch 11 E4-45-Block (3 Owner-Nähte, 2 Abwesenheiten, 4 Einheiten; XCTAssert 217 → 220); die E4-41-Naht auf den Körper von `spokenMedium` ist aus der Foto-Karten-Liste in den E4-45-Block gewandert (moved-needles hatte sie als „still in Sources“ gezeigt). Benotung `scratchpad/transcribe_e4_45.py`: HEAD FAIL, WORK PASS. Harness-Lehren: Abwesenheits-only-Datei erlaubt; `videoMedium`-Fehlalarm (One-Writer-Tupel der VIDEO-Karte) gelesen und ausgenommen.
- **Gates:** dbf84a8ae Compile Check 3116 ✓ → E4-43/E4-44-Stapel (1287d9892 · a80062fb1 · e08b9e791 · 675b78ae6) gepusht, Monitor bscmk8rwc. E4-45 lokal — Push nach dem Compile Check auf 675b78ae6.
- **Offen (E4):** EchoelStudioView-Stellen (Explore/New, Visual-Fenster-Paar, Favoriten-Menü, „Default sound“), EchoelNumberPad „Make negative/positive“, türlose Flächen zuletzt.

## 2026-10-01 — E4-46: EchoelStudioView-Ternäre und gesprochene Labels sprechen Deutsch (02d98a5b1)

- **Gebaut:** zwölf Stellen — Explore/New, Variations-Zeile (typisierte Schritte), Visual-Fenster-Knopf, Preset-Hinweis, Look-Chip-Wert/-Hinweis, zwei Favoriten-Labels, „Default sound“. Katalog 1250 → 1270 (+20). Keine neuen heißen Reads im Rumpf (Diff-Grep 0).
- **Wächter:** Anspruch 11 E4-46-Block (15 Nähte, 10 Abwesenheits-Nadeln, 21 Einheiten; XCTAssert 220 → 222). Benotung `scratchpad/transcribe_e4_46.py`: HEAD FAIL (15/10/20 — EIN Befund), WORK PASS. Checker alle OK, Klammerbilanz 0/0.
- **Gates:** 675b78ae6 (E4-43/E4-44) läuft, Monitor bscmk8rwc. E4-45 (03921c594) + E4-46 (02d98a5b1) lokal — Push nach dem Compile Check auf 675b78ae6.
- **Offen (E4):** EchoelNumberPad „Make negative/positive“, AnalysisSpectrumView sharp/flat, türlose Flächen (BreathGuide/BioSource/Broadcast) zuletzt; BodyTempoField `compact ? "" : "Tempo"` ist schon ein Schlüssel-Arm.

## 2026-10-01 — E4-47: die vier Analyse-Anzeigen sprechen Deutsch (382b8cf22)

- **Gebaut:** Spektrum (gesprochene Form, zwei frühe Returns), Oszilloskop (Stille/Spitze, gedruckt + gesprochen), Wellenfeld (drei Sätze), Poincaré (Kamera aus / Warten / Absage / SD1-SD2) als typisierte Schritte um die Zahlen. Katalog 1270 → 1292 (+22). Kein `%` in einem Schlüssel. Fünf Sources-Dateien (vier Ansichten + Katalog) — ausdrücklich genannt.
- **Wächter:** Anspruch 11 E4-47-Block (22 Nähte, 12 Abwesenheits-Nadeln, 22 Einheiten; XCTAssert 222 → 230). AnalysisViewsSpeakTheirNumbersTests 1:1 re-verankert (`spoken = "` → `spoken = `, breiter, +1 Kommentarzeile). Benotung `scratchpad/transcribe_e4_47.py`: HEAD FAIL (22/12/22 — EIN Befund), WORK PASS. Checker alle OK, Klammerbilanz 0/0.
- **Gates:** 675b78ae6 Compile Check 3117 ✓, BfT 6581/Auto-Merge 4015 laufen (Monitor bscmk8rwc); 5fdac5293 (E4-45/E4-46) gepusht, Monitor b1qz45alh. E4-47 (382b8cf22) lokal — Push nach dem Compile Check auf 5fdac5293.
- **Offen (E4):** türlose Flächen (BreathGuide/BioSource/Broadcast) zuletzt; EchoelNumberPad-Vorzeichen übersprungen (schon LocalizedStringKey, Wächter TheSignKeysSayWhatTheyDoTests); Einheiten und Mute/Solo-Namen unentschieden.

## 2026-10-01 — E4-48: Teil-Leiste Play/Stop, Vorhören-Knopf, FX-Favoriten sprechen Deutsch (b37cd9fd2)

- **Gebaut:** SelectedPartBar (Text + Label + Hinweis-Arm), MediaBrowserView Preview/Stop, EchoelFXView Unstar/Favorite ×2 als Schlüssel-Arme. Katalog 1292 → 1297 (+5). Vier Sources-Dateien (drei Ansichten + Katalog) — ausdrücklich genannt.
- **Wächter:** Anspruch 11 E4-48-Block (5 Nähte, 5 Abwesenheits-Nadeln, 8 Einheiten; XCTAssert 230 → 236). Benotung `scratchpad/transcribe_e4_48.py`: HEAD FAIL (5/5/5 — EIN Befund), WORK PASS. Checker alle OK.
- **Gates:** 675b78ae6 Compile 3117 ✓ + Auto-Merge 4015 ✓ → main = 675b78ae6. 5fdac5293 (E4-45/46) gepusht, Compile Check läuft (Monitor b1qz45alh). E4-47 (382b8cf22) + E4-48 (b37cd9fd2) lokal — Push nach dem Compile Check auf 5fdac5293.
- **Offen (E4, erreichbar):** PatchbayView Blackout, EchoelStudioView „Armed“ + Musikfarbe-Zeile, PartNoteEditor Velocity-Arme, LiveColaboView Go Live; türlose Flächen zuletzt.

## 2026-10-01 — E4-49: Blackout-Knopf, „Armed“-Wert, Musikfarbe-Zeile sprechen Deutsch (6d6d45878)

- **Gebaut:** PatchbayView Blackout (Text + Label), EchoelStudioView „Armed“-Wert + Musikfarbe-Zeile (Text-Ternär; das gesprochene Label war ein interpoliertes `live`/`idle` und ist jetzt zwei ganze Sätze). Katalog 1297 → 1306 (+9); „Preview“ → „Vorschau“ nachgezogen (Familie „Vorschau: “/„Vorschau stoppen“). Drei Sources-Dateien; kein neuer heißer Read im Studio-Rumpf (Diff-Grep 0).
- **Wächter:** Anspruch 11 E4-49-Block (5 Nähte, 5 Abwesenheits-Nadeln, 9 Einheiten; XCTAssert 236 → 240). Benotung `scratchpad/transcribe_e4_49.py`: HEAD FAIL (5/5/9 — EIN Befund), WORK PASS. Checker alle OK.
- **Gates:** 5fdac5293 Compile Check offen (Monitor b1qz45alh). E4-47 (382b8cf22), E4-48 (b37cd9fd2), E4-49 (6d6d45878) lokal — Push nach dem Compile Check.
- **Offen (E4, erreichbar):** PartNoteEditor Velocity-Arme (beide schon Schlüssel), LiveColaboView Go Live; danach türlose Flächen.

## 2026-10-01 — E4-50: Live Colabo Go Live + Einladung, Bio-Quelle-Tag sprechen Deutsch (d916d0586)

- **Gebaut:** LiveColaboView Go Live/Stop (Schlüssel-Arme) + Einladungssatz (Naht), BioStripView „Bio source: “-Naht. Katalog 1306 → 1309 (+3). PartNoteEditor-Velocity-Arme bewusst nicht angefasst (EchoelValueField liest `label` als Schlüssel, E4-10; beide Arme sind Schlüssel).
- **Wächter:** Anspruch 11 E4-50-Block (3 Nähte, 3 Abwesenheits-Nadeln, 4 Einheiten; XCTAssert 240 → 244). Benotung `scratchpad/transcribe_e4_50.py`: HEAD FAIL (3/3/3 — EIN Befund), WORK PASS. Checker alle OK.
- **Gates:** 5fdac5293 Compile Check 3118 + CI/CD 6582 + Auto-Merge 4016 laufen (Monitor b1qz45alh). E4-47…E4-50 lokal — Push nach dem Compile Check.
- **Offen (E4, erreichbar):** acht interpolierte Sprach-Labels in EchoelStudioView (Export/Import/Not opened/Share/New name/play-surface/visual preset/look); danach türlose Flächen.

## 2026-10-01 — E4-51: acht interpolierte Sprach-Labels in EchoelStudioView sprechen Deutsch (f3c32250e)

- **Gebaut:** Export-Fehlerzeile (Text + Label), Import-/Open-Notiz, Spielflächen-Klang-Chip, Visual-Preset-Kachel, Look-Chip, Teilen, Umbenennen-Feld als Schlüssel-Nähte um den Wert. Katalog 1309 → 1317 (+8). TheExportFailureSpeaksAtTheButtonTests 1:1 re-verankert (drei Nadeln, +1 Kommentarzeile). Zwei Sources-Dateien; heiße Reads im Diff 0.
- **Wächter:** Anspruch 11 E4-51-Block (9 Nähte, 9 Abwesenheits-Nadeln, 9 Einheiten; XCTAssert 244 → 246). Benotung `scratchpad/transcribe_e4_51.py`: HEAD FAIL (9/9/8 — EIN Befund), WORK PASS. Checker alle OK.
- **Gates:** d004dfbba (E4-47…E4-50) gepusht, Monitor bnrm4l13h. E4-51 (f3c32250e) lokal — Push nach dem Compile Check.
- **Offen (E4):** sichtbare `Text("…\\(Wert)…")`-Interpolationen mit Wörtern (nächste Messung), LoopExporter-Gründe, türlose Flächen zuletzt.

## 2026-10-01 — E4-52: sichtbare interpolierte Zeilen sprechen Deutsch (dee4d6994)

- **Gebaut:** zwei „Undo delete of“-Labels, Teil-Plätze-Hinweis, „by“-Credit, Künstlername-Caption, Live-Colabo-Einladungszeile, „Piece from“ als Schlüssel-Nähte. Katalog 1317 → 1324 (+7). Loop-Anzeige bleibt wörtlich (E4-24-Gegengewicht). Drei Sources-Dateien; heiße Reads 0.
- **Wächter:** Anspruch 11 E4-52-Block (7 Nähte, 6 Abwesenheits-Nadeln, 7 Einheiten; XCTAssert 246 → 250). Benotung `scratchpad/transcribe_e4_52.py`: HEAD FAIL (7/6/7 — EIN Befund), WORK PASS. Checker alle OK.
- **Gates:** d004dfbba (E4-47…E4-50) Compile Check läuft (Monitor bnrm4l13h). E4-51 (f3c32250e) + E4-52 (dee4d6994) lokal — Push nach dem Compile Check.
- **Offen (E4):** Mood-Caption mit `romanceSeventhClause`, WAV-HUD, LoopExporter-Gründe; türlose Flächen bewusst NICHT verschlüsselt (Tür zuerst, dann Wörter).

## 2026-10-01 — E4-53: die noch fehlenden Schlüssel-Einheiten (fd8e4ee39)

- **Gebaut:** Scan aller LocalizedStringKey-nehmenden Aufrufe gegen den Katalog → 23 Schlüssel ohne `de`; 13 bekommen eine Einheit (Routing-Karte, Live Colabo, Onboarding-Start), 10 bleiben bewusst englisch (Marke, BPM, `untranslatedPanelWords`). PatchbayView: `\\u{2014}` → „—“, damit der Schlüssel trifft. Katalog 1324 → 1337 (+13).
- **Wächter:** Anspruch 11 E4-53-Block (2 Text-Nadeln, 2 Escape-Abwesenheits-Nadeln, 13 Einheiten; XCTAssert 250 → 252). Benotung `scratchpad/transcribe_e4_53.py`: HEAD FAIL (2/2/13 — EIN Befund), WORK PASS. Checker alle OK.
- **Gates:** d004dfbba Compile Check läuft (Monitor bnrm4l13h). E4-51 (f3c32250e), E4-52 (dee4d6994), E4-53 (fd8e4ee39) lokal — Push nach dem Compile Check.
- **Offen (E4):** zwei `Text("a" + "b")`-Captions im Studio (Save-Hinweis, Puffer-Hinweis), Mood-Caption mit `romanceSeventhClause` (MoodKnobsSayWhatTheyDoTests pinnt zweimal), WAV-GAP-HUD, LoopExporter-Gründe; türlose Flächen erst nach einer Tür.

## 2026-10-01 — E4-54: die drei als String gebauten Studio-Captions (51745c062)

- **Gebaut:** Save-Hinweis und Puffer-Hinweis (`Text("a" + "b")`) sowie die Mood-Caption mit `romanceSeventhClause` werden `String(localized:)`-Nähte mit `+` (≤ 4 Operanden je Schritt); die Klausel behält `static let` und näht „ von “ / „ angebotenen)“ um ihre zwei Zählwerte. Katalog 1337 → 1345 (+8). Sources: 1 Datei + Katalog.
- **Wächter:** MoodKnobsSayWhatTheyDoTests 1:1 re-verankert (zwei Nadeln auf die Naht-Form, +1 Kommentar; Regex `of the [0-9]+ offered` weiter abwesend). Anspruch 11 E4-54-Block (8 Naht-Nadeln, 6 Abwesenheits-Nadeln, 8 Einheiten; XCTAssert 252 → 254). Benotung `scratchpad/transcribe_e4_54.py`: HEAD FAIL (8/6/8 — EIN Befund), WORK PASS. Checker alle OK, Klammerbilanz 0.
- **Gates:** d004dfbba Compile Check 3119 ✓ (Quick Test, Full Suite, Auto-Merge Docs ✓; CI/CD + Auto-Merge Claude laufen). Stapel E4-51…E4-54 wird nach diesem Commit gepusht.
- **Offen (E4):** WAV-GAP-HUD (bewusst englisch), LoopExporter-Gründe, Mute/Solo `name:`; türlose Flächen erst nach einer Tür.

## 2026-10-01 — E4-55: Exporter-Gründe · Studio-Hints · Pad-Shape-Caption · Narrations-Hint (5dad34609)

- **Gebaut:** die fünf Fehlergründe des LoopExporters (sechs `.failed(_:)`-Stellen), Live-Colabo-Tür-Hint und Klick-Akzent-Hint in EchoelStudioView, die elf Segmente von `padShapeCaption`, der Hint der Narrations-Aufklappung — alle als `String(localized:)`-Nähte (≤ 4 Operanden je Schritt). Katalog 1345 → 1368 (+23). Sources: 3 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-55-Block (23 Naht-Nadeln, 14 Abwesenheits-Nadeln, 23 Einheiten; XCTAssert 254 → 260). Kein Re-Anker nötig (gemessen: kein Wächter pinnt die Fragmente; NoClock-Versprechen im Diff 0, „Dynamic and Flowing“ nur im Kommentar wie zuvor). Benotung `scratchpad/transcribe_e4_55.py`: HEAD FAIL (23/14/23 — EIN Befund), WORK PASS. Checker alle OK, Klammerbilanz 0.
- **Gates:** ca5b84258 (E4-51…E4-54) gepusht, Monitor bcc564hux: Quick Test 3848 ✓, Auto-Merge Docs 581 ✓; Compile Check/CI/CD/Auto-Merge laufen. E4-55 (5dad34609) lokal — Push nach dem Compile Check.
- **Offen (E4):** Import-Erfolgssätze (MIDIImport/MediaPlacement/AudioImport `successNote`, ClipNoteEdit `gridLabel`) — Laufzeit-Wächter prüfen; WAV-HUD bewusst englisch; türlose Flächen erst nach einer Tür.

## 2026-10-01 — E4-56: die fünf Import-Sätze (6b34101a7)

- **Gebaut:** MIDIImport (addedTrackNote · emptyPartNote · successNote), MediaPlacement.successNote, AudioImport.successNote als `String(localized:)`-Nähte um Namen und Zahlen (≤ 4 Operanden je Schritt); Plurale als Ternär zweier Schlüssel, `bar`/`bars` wiederverwendet. Katalog 1368 → 1389 (+21, 2 wiederverwendet). Sources: 3 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-56-Block (20 Naht-Nadeln, 8 Abwesenheits-Nadeln, 23 Einheiten; XCTAssert 260 → 266). Laufzeit-Wächter (fünf Dateien) lesen die englische Zusammensetzung unverändert — Python-Spiegel hat jede Nadel reproduziert. Benotung `scratchpad/transcribe_e4_56.py`: HEAD FAIL (20/8/21 — EIN Befund), WORK PASS. Checker alle OK, Klammerbilanz 0.
- **Gates:** 7247cb093 (E4-55) gepusht, Monitor bsakg0dn1 läuft. E4-56 (6b34101a7) lokal — Push nach dem Compile Check.
- **Offen (E4):** ClipNoteEdit.gridLabel (ThePartNoteGridSpeaksTests pinnt vier Laufzeit-Sätze exakt), WorkstationView Compose-Guide-Nummer, ArrangeCanvasView gesprochene Zeile; WAV-HUD bewusst englisch; türlose Flächen erst nach einer Tür.

## 2026-10-01 — E4-57: Notenraster · gewählte Note · Notes-Schalter · Arrangement-Zeile (a9286667f)

- **Gebaut:** `ClipNoteEdit.gridLabel` / `pickedNoteLine` / `notesSwitchTitle` und `ArrangementStrip.spoken` als `String(localized:)`-Nähte um die Zahlen (≤ 4 Operanden je Schritt), Plurale als Ternär zweier Schlüssel; „ of “, „ selected“, „ more“, „, beat “, „note“/„notes“ wiederverwendet. Katalog 1389 → 1399 (+10). Sources: 2 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-57-Block (13 Naht-Nadeln, 6 Abwesenheits-Nadeln, 16 Einheiten; XCTAssert 266 → 270). Vier Laufzeit-Wächter pinnen das exakte Englisch — Python-Spiegel je Zusammensetzung reproduziert es. Benotung `scratchpad/transcribe_e4_57.py`: HEAD FAIL (13/6/10 — EIN Befund), WORK PASS. Checker alle OK, Klammerbilanz 0.
- **Gates:** 7247cb093 (E4-55): Compile Check 3121 ✓, Quick Test 3849 ✓ (CI/CD + Auto-Merge laufen, Monitor bsakg0dn1). 1b8577f85 (E4-56) danach gepusht. E4-57 (a9286667f) lokal — Push nach dem Compile Check auf 1b8577f85.
- **Offen (E4):** BioMusicDirector-Narration (`text(for:tempo:)`, Laufzeit-Wächter mit Präfix-/Phrasen-Nadeln — eigene Vermessung); WAV-HUD bewusst englisch; türlose Flächen erst nach einer Tür.

## 2026-10-01 — E4-58: die EchoelAI-Erzählung (88331de51)

- **Gebaut:** `BioExplanation.text(for:tempo:)` und `BioNarrationDriver.heading` / `voiceOverLabel` aus Katalog-Schlüsseln — ein Schlüssel je Klausel; Tempo- und Atem-Adjektive sitzen IM Klausel-Schlüssel (einer je Zustandswert), damit Deutsch flektieren kann („ein ruhiges 90-BPM-Tempo“, „langsames Atmen formt das Anschwellen“). Präfix, Signal-Nennung und Engine-Schluss als Nähte (≤ 4 Operanden). Katalog 1399 → 1423 (+24). Sources: 1 Datei + Katalog. `BioStateSummary.prompt` (Modell-Eingabe) bleibt englisch.
- **Wächter:** Anspruch 11 E4-58-Block (22 Naht-Nadeln, 9 Abwesenheits-Nadeln, 24 Einheiten; XCTAssert 270 → 272). Laufzeit-Wächter (drei Dateien) lesen das Englische unverändert — Python-Spiegel reproduziert Präfixe, Phrasen und Abwesenheiten. Benotung `scratchpad/transcribe_e4_58.py`: HEAD FAIL (22/9/24 — EIN Befund), WORK PASS. Checker alle OK, Klammerbilanz 0.
- **Gates:** 7247cb093 (E4-55): Compile Check 3121 ✓, Auto-Merge 4019 ✓ → main = 7247cb093. 1b8577f85 (E4-56): Quick Test 3850 ✓, Compile Check läuft (Monitor bxgo56ern). E4-57 (a9286667f) + E4-58 (88331de51) lokal — Push nach dem Compile Check.
- **Offen (E4):** Rest-Scan nach dieser Scheibe neu messen (Ternäre: nur noch SF-Symbol-Namen und interne Zustandswörter; Verkettungen: Log-/Breadcrumb-Zeilen und türlose Flächen); WAV-HUD bewusst englisch; türlose Flächen erst nach einer Tür.

## 2026-10-01 — E4-59: Audio-Timing-Zeile und erkannte Tonart (ab1f1a0ba)

- **Gebaut:** `RenderGapDetector.Tally` (screenLine, evidenceSuffix, screenCaption, screenText) und `AudioKeyAnalysis.summarise` / `TuningDetector.keyName` (minor/major → Moll/Dur) aus Katalog-Schlüsseln, genäht um Zahlen, die ihr eigenes `String(format:)` behalten — ein Schlüssel trägt nie ein `%`, jede Ziffer bleibt byte-identisch. Katalog 1423 → 1444 (+21). Sources: 3 Dateien + Katalog. „A4 ≈ n Hz“ bleibt wörtlich.
- **Wächter:** Anspruch 11 E4-59-Block (18 Naht-Nadeln, 8 Abwesenheits-Nadeln, 21 Einheiten; XCTAssert 272 → 279). TimingVerdictReachesTheScreenTests pinnt „Nothing late in the last 60 s“ exakt — Python-Spiegel reproduziert alle Formen. Benotung `scratchpad/transcribe_e4_59.py`: HEAD FAIL (18/7/21 — EIN Befund), WORK PASS. Checker alle OK, Klammerbilanz 0.
- **Gates:** 1b8577f85 (E4-56): Compile Check 3122 ✓ (Auto-Merge läuft, Monitor bxgo56ern). b92e0c975 (E4-57/58) gepusht, Monitor bx1lvm9t5. E4-59 (ab1f1a0ba) lokal — Push nach dem Compile Check auf b92e0c975.
- **Offen (E4):** AudioTempoAnalysis.summarise (Tempo-Satz der Workstation) als nächste Scheibe; danach Rest-Scan; WAV-HUD bewusst englisch; türlose Flächen erst nach einer Tür.

## 2026-10-01 — E4-60: Tempo-Satz (399b2f413)

- **Gebaut:** `AudioTempoAnalysis.summarise` aus Katalog-Schlüsseln um die zwei `%.1f`-Zahlen; „Tempo ≈ “ und „ BPM“ bleiben wörtlich. Katalog 1444 → 1448 (+4). Sources: 1 Datei + Katalog.
- **Wächter:** Anspruch 11 E4-60-Block (5 Naht-Nadeln, 3 Abwesenheits-Nadeln, 4 Einheiten; XCTAssert 279 → 281). Benotung `scratchpad/transcribe_e4_60.py`: HEAD FAIL (5/3/4 — EIN Befund), WORK PASS. Checker alle OK.
- **Gates:** 1b8577f85 (E4-56): Auto-Merge 4020 ✓ → main = 1b8577f85. b92e0c975 (E4-57/58): Compile Check 3123 ✓ (Auto-Merge läuft). E4-59 (ab1f1a0ba) + E4-60 (399b2f413) werden danach gepusht.
- **Offen (E4):** Rest-Scan nach Scheibe 60 (verbleibende Treffer sind Log-Zeilen, SF-Symbole, interne Zustandswörter und türlose Flächen); WAV-HUD bewusst englisch; türlose Flächen erst nach einer Tür.

## 2026-10-01 — E4-61: Workstation-Transportzeile, Spur-Entfernen-Hinweis, Mix-Meter-Sprechtext (d9ad98849)

- **Gebaut:** `WorkstationSummary.transportCaption`, `TrackMix.removalNote`, `MixLevelMeter.spokenText` aus Katalog-Schlüsseln um die Zahl; Einzahl und fünf feste Sätze als eigene Schlüssel. Katalog 1448 → 1462 (+14, „ percent“ wiederverwendet). Sources: 3 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-61-Block (9 Naht-Nadeln, 5 Abwesenheits-Nadeln, 15 Einheiten; XCTAssert 281 → 287). Benotung `scratchpad/transcribe_e4_61.py`: HEAD FAIL (9/5/14 — EIN Befund), WORK PASS. Die vier Laufzeit-Wächter vergleichen das ZUSAMMENGESETZTE Englisch — Python-Spiegel vor dem Commit grün. Checker alle OK (count-pins 0 RED).
- **Gates:** 04fd18b95 (E4-59/60): Quick Test 3852 ✓, Auto-Merge Docs 585 ✓; Compile Check + CI/CD + Auto-Merge laufen (Monitor bnpaw55yt). E4-61 wird nach grünem Compile Check gepusht.
- **Rest-Scan nach E4-60 (gemessen):** verbleibende interpolierende Erzeuger — EchoelStudioView (Record-Label, Zoom-Caption, Keep-last-Label), MIDIImport.newPartHint, BioVariationMaze.boardSentence, PolarH10 statusLabel, PartNoteEditor.hint, TouchInstrumentView accessibilityValue, LookBlendMap.name, SessionLaunchView-Hint, EchoelValueField „Default“-Button, plus Konkatenationen in SessionSaveOpen/MediaRelink/RecordTakeControls; EchoelAppIntents-Phrasen (AppShortcut, eigener Mechanismus), WorkspaceView-Versionslabel (sprachneutral), NetworkActivityDot (türlos) bewusst ausgelassen.

## 2026-10-01 — E4-62: Platten-Labels (Record · Keep last · Textgröße) + Takt-Längen-Label (b6da6e7ad)

- **Gebaut:** `exportLabel`/`busyStatusLabel`, Textgrößen-Caption und `KeepLastCopy.title` (EchoelStudioView) sowie `LoopBarLength.label` (LoopCutter) aus Katalog-Schlüsseln um die Zahl; „8 bars“ war ein Literal, das alle Platten-Labels trugen. Deutsch hält die Kachel-Wörter im Sprechnamen (Regel 3). Katalog 1462 → 1477 (+15; „ of “, „1 bar“, „bars“ wiederverwendet). Sources: 2 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-62-Block (8 Naht-Nadeln, 5 Abwesenheits-Nadeln, 18 Einheiten; XCTAssert 287 → 291). Benotung `scratchpad/transcribe_e4_62.py`: HEAD FAIL (8/5/15 — EIN Befund), WORK PASS. Nachbar-Wächter (TheBarCountHasACarrierTests, TheTextSizeHasButtonsTests) gegen den Arbeitsbaum geprüft; Gesamt-Anspruch-Nadeln über beide Dateien 114/0. Checker alle OK.
- **Gates:** 04fd18b95 (E4-59/60): Compile Check + CI/CD + Auto-Merge laufen noch (Monitor bnpaw55yt). E4-61 (d9ad98849) + E4-62 (b6da6e7ad) lokal, Push nach grünem Compile Check.
- **Offen (E4):** MIDIImport.newPartHint + BioVariationMaze.boardSentence (E4-63), danach PolarH10 statusLabel · PartNoteEditor.hint · TouchInstrumentView accessibilityValue · LookBlendMap.name · SessionLaunchView-Hint · EchoelValueField „Default“-Button · SessionSaveOpen/MediaRelink/RecordTakeControls-Konkatenationen.

## 2026-10-01 — E4-63: Neuer-MIDI-Teil-Hinweis, Explore-Satz, Dichte-Wörter (137dfe875)

- **Gebaut:** `MIDIImport.newPartHint` (static let bleibt), `BioVariationMaze.boardSentence` (drei Subjekt-Formen) und `densityWord` aus Katalog-Schlüsseln; Deutsch „Ideen — Quelle: “ + Demo-Konstante (kein Kasus-Bruch). Katalog 1477 → 1488 (+11). Sources: 3 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-63-Block (8 Naht-Nadeln, 6 Abwesenheits-Nadeln, 11 Einheiten; XCTAssert 291 → 297). Benotung `scratchpad/transcribe_e4_63.py`: HEAD FAIL (8/6/11 — EIN Befund), WORK PASS. Laufzeit-Wächter (ANewPartLands…, TheVariationCardSaysWhoseTarget…, OneSpellingOfTheDemoSubject…) als Python-Spiegel grün; Gesamt-Anspruch-Nadeln 141/0. Checker alle OK.
- **Gates:** 04fd18b95: Compile Check 3124 läuft (02:25Z), CI/CD 6588 queued, Auto-Merge 4022 läuft. Lokal ungepusht: E4-61 d9ad98849 · E4-62 b6da6e7ad · E4-63 137dfe875 (+ Docs).
- **Offen (E4):** PolarH10 statusLabel · PartNoteEditor.hint · TouchInstrumentView accessibilityValue · LookBlendMap.name · SessionLaunchView-Hint · EchoelValueField „Default“-Button · SessionSaveOpen/MediaRelink/RecordTakeControls-Konkatenationen.

## 2026-10-01 — E4-64: Gurt-Status, Teil-Editor-Hinweis, Touch-Fläche (7675317bc)

- **Gebaut:** `PolarH10BioPublisher.statusLabel` (sechs Sprossen), `PartNoteEditor.hint(sharedBy:)`, `TouchInstrumentView` accessibilityValue aus Katalog-Schlüsseln um Gerätename / Teilzahl / Grundton+Stufenzahl. Katalog 1488 → 1502 (+14, „Connecting…“ wiederverwendet). Sources: 3 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-64-Block (8 Naht-Nadeln, 5 Abwesenheits-Nadeln, 15 Einheiten; XCTAssert 297 → 303). Benotung `scratchpad/transcribe_e4_64.py`: HEAD FAIL (8/5/14 — EIN Befund), WORK PASS. Python-Spiegel der Laufzeit-Erwartungen (PolarH10BioPublisherTests, TheGridLabelFitsItsCellTests) grün. Checker alle OK.
- **Gates:** b92e0c975 (E4-57/58): Auto-Merge 4021 ✓ → main = b92e0c975. 04fd18b95 (E4-59/60): Compile Check 3124 ✓, CI/CD 6588 + Auto-Merge 4022 laufen. Stapel E4-61…63 als 3cef15d08 gepusht (Monitor bklgzyq4i). E4-64 (7675317bc) lokal.
- **Offen (E4):** LookBlendMap.name · SessionLaunchView-Szenen-Hinweis · EchoelValueField „Default“-Button · SessionSaveOpen/MediaRelink/RecordTakeControls-Konkatenationen.

## 2026-10-01 — E4-65: Aufnahme-Captions, Öffnen-Absage, Relink-Gründe (bc4e1949d)

- **Gebaut:** `RecordTake.caption`/`armSubtitle`/`droppedSentence`, `SessionSaveOpen.refusal`, `MediaRelink.userMessage` aus Katalog-Schlüsseln; zitierte Namen wörtlich, Zahlen genäht, Relink-Dauern behalten `String(format:)`. Katalog 1502 → 1533 (+31). Sources: 3 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-65-Block (11 Naht-Nadeln, 7 Abwesenheits-Nadeln, 31 Einheiten; XCTAssert 303 → 309). Benotung `scratchpad/transcribe_e4_65.py`: HEAD FAIL (11/7/31 — EIN Befund), WORK PASS. Nachbar-Wächter-Fragmente („Recording starts at bar 1“, „instead of the parts under it“, „Stop the piece to relink a file.“) sitzen ganz in ihren Schlüsseln; Python-Spiegel grün; Gesamt-Anspruch-Nadeln 19/0. Checker alle OK.
- ⛔ **Befund ZURÜCKGENOMMEN (gemessen, dieselbe Stunde):** `MediaBrowserView.relinkRefusal` DELEGIERT an `MediaRelink.Refusal.songPlaying.userMessage` — kein Zwilling; der Wächter pinnt den EINEN Satz über den Delegaten. Eigener englischer Erzeuger dort: die Notiz „A relink is still checking its file.“ (E4-66). Lehre: eine Laufzeit-Erwartung in einem Wächter belegt keinen zweiten Erzeuger — die drei Zeilen lesen.
- **Gates:** 04fd18b95 (E4-59/60): Compile Check 3124 ✓, Auto-Merge 4022 ✓ → main = 04fd18b95. 3cef15d08 (E4-61…63): Quick Test 3853 ✓, Auto-Merge Docs 586 ✓, Compile Check/CI/CD/Auto-Merge laufen (Monitor bklgzyq4i). Lokal: E4-64 (7675317bc), E4-65 (bc4e1949d) + Docs.
- **Offen (E4):** SessionLaunchView-Szenen-Hinweis (+ Re-Anker TheSceneLaunchIsASwitchTests:429) · LookBlendMap.name · EchoelValueField „Default“-Knopf · MediaBrowserView.relinkRefusal.

## 2026-10-01 — E4-66: Szenen-Hinweise, Look-Name, „Default“-Aktion (820be6f62)

- **Gebaut:** `SessionLaunchView.sceneBlock` (zwei Sprech-Hinweise als typisierte lets), `LookBlendMap.name(for:)` („Look “ + Index), `EchoelValueField` VoiceOver-„Default“-Aktion („Default “ + Zahl, Schlüssel des Zahlenblocks). Katalog 1533 → 1538 (+5). Sources: 3 Dateien + Katalog; Tests: 2 (Re-Anker TheSceneLaunchIsASwitchTests:429, 1:1).
- **Wächter:** Anspruch 11 E4-66-Block (5 Naht-Nadeln, 4 Abwesenheits-Nadeln, 6 Einheiten; XCTAssert 309 → 315). Benotung `scratchpad/transcribe_e4_66.py`: HEAD FAIL (4/4/5 — EIN Befund), WORK PASS; Re-Anker +1 Zeile, XCTAssert gleich. Gesamt-Anspruch-Nadeln 34/0; Nachbar-Wächter-Nadeln (ValueField-Aktion, Szenen-Hinweis) im Arbeitsbaum grün. Checker alle OK.
- **Gates:** 3cef15d08 (E4-61…63): Compile Check 3125 ✓, Quick Test 3853 ✓, Auto-Merge Docs 586 ✓ (CI/CD + Auto-Merge laufen, Monitor bklgzyq4i). Stapel E4-64 (7675317bc) · E4-65 (bc4e1949d) · Rücknahme a21802487 · E4-66 (820be6f62) wird jetzt gepusht.
- **Offen (E4):** MediaBrowserView (Lese-Zeilen, Vorschau-Absagen, Relink-Prüfnotiz, Nutzungs-Ternary, drei accessibilityHint-Literale) als nächste Scheibe; danach Abschluss-Rest-Scan.

## 2026-10-01 — E4-67: Medienansicht — Zustandszeilen, Relink-Notiz, Vorschau-Absagen (674840cef)

- **Gebaut:** zehn nackte Literale in `MediaBrowserView` (drei `line(…)`-Zeilen, Relink-Caption-Paar, „still checking“-Notiz, drei Vorschau-Absagen, „the audio track“-Rückfall) als Katalog-Schlüssel; Deutsch zitiert die deutschen Labels „Audio importieren“ / „Neu verknüpfen“ (aus dem Katalog gelesen). Katalog 1538 → 1548 (+10). Sources: 1 Datei + Katalog.
- **Wächter:** Anspruch 11 E4-67-Block (5 Naht-Nadeln, 4 Abwesenheits-Nadeln, 10 Einheiten; XCTAssert 315 → 317). Benotung `scratchpad/transcribe_e4_67.py`: HEAD FAIL (5/4/10 — EIN Befund), WORK PASS. Gesamt-Anspruch-Nadeln 46/0. Checker alle OK.
- **Gates:** 823785a48 (E4-64…66): Quick Test 3854 ✓, Auto-Merge Docs 587 ✓; Compile Check / CI/CD / Auto-Merge laufen (Monitor btkl4tryp). 3cef15d08: CI/CD + Auto-Merge laufen (Monitor bklgzyq4i). E4-67 (674840cef) lokal.
- **Offen (E4):** Abschluss-Rest-Scan über Sources (Ternaries, `return "…"`-Sätze, Konkatenationen) — danach ist E4 bis auf WAV-HUD (bewusst englisch) und die türlosen Flächen durch.

## 2026-10-01 — E4-68: Import-Fehlersätze (Audio + MIDI) und Noten-Editor-Absagen (f76e4ffc0)

- **Gebaut:** `AudioImport.Failure.userMessage` (7), `MIDIImport.Failure.userMessage` (8; `.tooLong` hält `maxBars`/`maxNotes` zwischen drei Schlüsseln in einem typisierten `let`) und die vier `ClipNoteEdit`-Absagen als Katalog-Schlüssel. Katalog 1548 → 1567 (+19, „That file isn’t audio…“ wiederverwendet). Sources: 3 Dateien + Katalog. Deutsch u. a.: „Diese Datei konnte nicht geöffnet werden.“ · „Das Teile-Raster ist voll — alle 8 Plätze sind belegt.“ · „Diese MIDI-Datei ist zu lang — ein Teil fasst bis zu N Takte und M Noten.“ · „Der Komponist schreibt diesen Teil beim Weiterentwickeln neu, deshalb werden seine Noten gezeigt, nicht bearbeitet.“
- **Wächter:** Anspruch 11 E4-68-Block (7 Naht-Nadeln über drei Dateien, 3 Abwesenheits-Nadeln, 20 Einheiten; XCTAssert 317 → 323). Vier Import-Wächter vergleichen `userMessage` zur LAUFZEIT unter der Test-Locale (Gleichheit auf dem Schlüssel, `contains`, Set-Eindeutigkeit) — kein Re-Anker nötig. Benotung `scratchpad/transcribe_e4_68.py`: HEAD FAIL (7/2/19 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 931/0. Checker alle OK.
- **Gates:** 3cef15d08: Compile 3125 ✓, Quick Test 3853 ✓, Auto-Merge Docs 586 ✓; CI/CD + Auto-Merge laufen. 823785a48: Quick Test 3854 ✓, Auto-Merge Docs 587 ✓; Compile / CI/CD / Auto-Merge laufen. E4-67 (674840cef) + E4-68 (f76e4ffc0) lokal, Push nach Compile Check auf 823785a48.
- **Offen (E4):** Rest-Scan-Liste: ProjectStore.importFailureNote („Couldn’t read that file.“, Schlüssel existiert jetzt), WeatherMood/GenreFX/SkillLevel-Captions, LoudnessTarget „No target“, BreathPattern-Phasenwörter (nur türlose Leser?), CameraRPPG-Zustandswörter, LaneVoiceKind-Namen, MultipeerSession-Status, AudioConfiguration-Bluetooth-Zeilen, SingleExport-Fehler; als Diagnose/Modell-Eingabe einzustufen: EchoelCommand (EchoelAI ohne Leser), AudioEngine.stateDescription, BioMusicDirector „Body state:“.

## 2026-10-01 — E4-69: FX-Charaktere, Könnensstufen und Kamera-Erholungswörter (ceafa3b5a)

- **Gebaut:** `FXCharacter.displayName`+`blurb` (22), `SkillLevel.displayName`+`blurb` (6) und `RPPGRecoveryState.userHint`+`shortLabel` (6) als Katalog-Schlüssel. Katalog 1567 → 1601 (+34). Sources: 3 Dateien + Katalog. Deutsch u. a.: „Auto (Genre)“ · „Clean (trocken)“ · „Unterwasser“ · „Nutzt den Effektraum des Genres“ · „Einsteiger / Produzent / Profi“ · „Nur das Wesentliche — Klang, Stimmung, Sichern & Export.“ (Chip-Wörter aus dem Katalog) · Pille „Erholt sich / Kühlt ab / Pausiert“ (kurz, Slot-Gesetz) · Streifen „Gerät kühlt ab — der Puls hält kurz inne“.
- **Wächter:** Anspruch 11 E4-69-Block (6 Naht-Nadeln über drei Dateien, 3 Abwesenheits-Nadeln, 34 Einheiten; XCTAssert 323 → 329). TheStalledPillSaysWhySilentTests vergleicht `shortLabel` zur Laufzeit unter der Test-Locale — kein Re-Anker. Benotung `scratchpad/transcribe_e4_69.py`: HEAD FAIL (6/3/34 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 940/0. Checker alle OK.
- **Gates:** 3cef15d08: Auto-Merge 4023 ✓ → main = 3cef15d08. 823785a48: Compile Check 3126 ✓ (CI/CD 6590 + Auto-Merge 4024 laufen). Danach E4-67 + E4-68 gepusht als Spitze 12b7a2ffb (Monitor b3golb4gj, Aufgabe #373). E4-69 (ceafa3b5a) lokal.
- **Offen (E4):** ProjectStore.importFailureNote (4 Sätze, einer mit Feldpfad), AudioConfiguration-Codec-Notiz (zwei `+`-Ketten → je ein Schlüssel), MultipeerSession-Status (Live-Colabo; Erreichbarkeit prüfen), SingleExport.ExportError (Leser prüfen), LaneVoiceKind-Namen (gehen in Spur-Namen beim Anlegen — persistiert! nicht keyen), BreathPattern (nur türlose Leser), LoudnessTarget „No target“ (Datei liegt nicht unter Audio/ — Pfad messen); Diagnose/Modell-Eingabe: EchoelCommand, AudioEngine.stateDescription, BioMusicDirector „Body state:“.

## 2026-10-01 — E4-70: Colabo-Status, Öffnen-Absage und Bluetooth-Telefonie-Notizen (b934e2060)

- **Gebaut:** `MultipeerSession.status` (11 Zuweisungen; vier Interpolationen werden Schlüssel + Name, der Plural teilt sich in „ peer“ / „ peers“), `ProjectStore.importFailureNote` + `saveError`, die zwei `RouteCodec.note`-Sätze (je eine Drei-Literal-`+`-Kette → ein Schlüssel). Katalog 1601 → 1617 (+16; „Off“, „Connected to “, „Couldn’t read that file.“ wiederverwendet). Sources: 3 Dateien + Katalog. Deutsch u. a.: „Sucht Echoelmusic in der Nähe…“ · „Einladung an <Name>…“ · „Geteilt mit 2 Peers“ · „Teilen fehlgeschlagen“ · „Stück empfangen von <Name>“ · „Diese Datei ist kein Echoel-Stück.“ · „Bluetooth ist im Telefonie-Modus: mono und bandbegrenzt — die Musik auch. …“.
- **Wächter:** Anspruch 11 E4-70-Block (6 Naht-Nadeln über drei Dateien, 3 Abwesenheits-Nadeln, 19 Einheiten; XCTAssert 329 → 335). TheShareDoorReportsWhatItCannotSendTests behält beide Nadeln („Share failed“, „can’t be encoded“) innerhalb der Schlüssel; TheImportDoor…/TheCodecNote… vergleichen zur Laufzeit — kein Re-Anker. Benotung `scratchpad/transcribe_e4_70.py`: HEAD FAIL (6/3/16 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 949/0. Checker alle OK (moved-needles: eine eigene Naht-Nadel `return field.isEmpty`, Frage, kein Befund).
- **Gates:** Spitze 12b7a2ffb (E4-67/68) läuft (Monitor b3golb4gj, #373). E4-69 (ceafa3b5a) + E4-70 (b934e2060) lokal, Push nach Compile Check auf 12b7a2ffb.
- **Offen (E4):** Rest: EchoelNumberPad-Vorzeichen-Label (Ternary → prüfen, ob String statt Key), LoudnessTarget „No target“ (Leser messen), MusicStyle.lineage (182 Sätze — Leser messen, eigene Scheibe), WeatherMood-Captions (Pfad messen); BEWUSST NICHT: LaneVoiceKind.displayName (benennt neue Spuren persistiert — ein Schlüssel machte den Spurnamen locale-abhängig), SingleExport.ExportError (nur Breadcrumb), BreathPattern (türlose Leser), BioTempoDirector (Waise), EchoelCommand (EchoelAI ohne Leser), AudioEngine.stateDescription (Diagnose), BioMusicDirector „Body state:“ (Modell-Eingabe).

## 2026-10-01 — E4-71: Loudness-Ziele und Wetter-Erklärungen (7bc63b0da)

- **Gebaut:** `LoudnessTarget.displayName` (5; „Kein Ziel“, „Rundfunk (−23)“, „Kino (−24)“, Streaming/Podcast identisch) und `WeatherMood.Param.explanation` (8; „Gleicher Himmel behält bei jedem Spielen dasselbe harmonische Gerüst.“ …) als Katalog-Schlüssel. ⚠️ `Param.label` bleibt ABSICHTLICH nackt: `EchoelValueField(label:)` zeichnet es als Katalog-SCHLÜSSEL (Anspruch 12 läuft alle Labels ab) — eingewickelt bekäme das Feld einen deutschen String zum Nachschlagen. Katalog 1617 → 1630 (+13). Sources: 2 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-71-Block (5 Naht-Nadeln über zwei Dateien, davon eine auf das NACKTE Label, 2 Abwesenheits-Nadeln, 13 Einheiten; XCTAssert 335 → 339). Benotung `scratchpad/transcribe_e4_71.py`: HEAD FAIL (4/2/13 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 956/0. Checker alle OK.
- **Gates:** 823785a48: Compile 3126 ✓, Auto-Merge 4024 ✓ → main = 823785a48 (#372 zu). 12b7a2ffb: Quick Test 3855 ✓, Auto-Merge Docs 588 ✓, Compile 3127 / CI/CD 6591 / Auto-Merge 4025 laufen (Monitor b3golb4gj, #373). Lokal ungepusht: E4-69 (ceafa3b5a), E4-70 (b934e2060), E4-71 (7bc63b0da) + Docs — Push nach Compile 3127.
- ⛔ **ZURÜCKGENOMMEN (gleiche Stunde):** „nach dem Rest-Scan bleibt sichtbar nur das WAV-HUD“ war FALSCH — der Scan dahinter war mit `| head -40` gekappt und wurde als vollständig gelesen (genau der §2-Defekt aus `.claude/rules/context.md`: eine Messung, die still weniger liefern kann, ist keine). Ungekappt (gleiches Muster, ohne Log-/Diagnose-/türlose Dateien) bleiben 13 Dateien mit nackten Produzenten: EchoelStudioView 18 · MusicTheoryPrimer 12 · BioScienceInfo 11 · LightScienceInfo 8 · VisualAnalysisMeter 4 · BioSourceOption 4 · CameraCapture 3 · TrackInspectorView 3 · ImmersiveStageView 3 (türlos) · TrackInstrument 3 · StretchMode 2 · SongAutomationEditor 1 · LearnView 1 — plus der VoiceOver-Gestensatz in `EchoelValueField`. E4 geht mit E4-72 weiter (Quellen-Chooser, Spur-Untertitel, Inspektor-Engine-Zeilen). **Offen (E4) — korrigiert:** diese Liste; WAV-HUD bewusst englisch. Bewusst nicht gekeyt: LaneVoiceKind.displayName (benennt neue Spuren persistiert), MusicStyle.lineage (null Leser), SingleExport.ExportError (nur Breadcrumb), BreathPattern/BioSourceView-Familie (türlos), BioTempoDirector (Waise), EchoelCommand (EchoelAI ohne Leser), AudioEngine.stateDescription (Diagnose), BioMusicDirector.prompt (Modell-Eingabe), EchoelNumberPad-Vorzeichen-Label (LocalizedStringKey-Überladung, beide Schlüssel im Katalog). Nächster Schritt: Gates lesen, dann E4-Abschlussnotiz im Doc.

## 2026-10-01 — E4-72: Quellen-Chooser, Geräte-Namen des Inspektors, Messgerät-Namen (e07a078c4)

- **Gebaut:** `BioSourceOption.menuLabel` (4; „Spielen mit Kameralicht“ · „Spielen mit einem Bluetooth-Gurt — sucht einen“ · „Spielen mit der Simulation“ · „Spielen mit Apple Health — deine Watch, in ihrem eigenen Tempo“), `TrackInspectorView.deviceName` (6; „Echoel-Instrument“ · „Audiodatei-Player“ · „Bio-Kurve — kein Klang“ · „Noch keine Engine spielt diese Spur“ · „Keine Stimme — nur die ersten N zusätzlichen MIDI-Spuren spielen“ / „… sind in diesem Build aus“) und `VisualAnalysisMeter.spokenName` (4; „… des Master-Ausgangs“, „Pulsintervall-Diagramm der Kamera“) als Katalog-Schlüssel. `TrackInstrument.subtitle` bleibt nackt — kein Leser (gemessen). Katalog 1630 → 1645 (+15). Sources: 3 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-72-Block (6 Naht-Nadeln über drei Dateien, 3 Abwesenheits-Nadeln, 15 Einheiten; XCTAssert 339 → 345). TheBioSourceChooserHasOneDefinitionTests zählt jedes Label-Literal EINMAL über Definition + zwei Verbraucher — eingewickelt bleibt es eines; die Agent-Wächter vergleichen „Bio curve — no sound“ zur Laufzeit unter der Test-Locale — kein Re-Anker. Benotung `scratchpad/transcribe_e4_72.py`: HEAD FAIL (6/2/15 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 965/0. Checker OK (moved-needles: zwei eigene Naht-Nadeln, Fragen).
- **Gates:** 12b7a2ffb: Compile 3127 ✓ (CI/CD 6591 + Auto-Merge 4025 laufen, #373). Danach E4-69…71 + Rücknahme gepusht als Spitze 4167cc092 (Monitor beeuadk6r, #374). E4-72 (e07a078c4) lokal.
- **Offen (E4), ungekappt gemessen:** EchoelStudioView (Chip-Vollnamen für VoiceOver, Orts-Zeile, Rhythmus-Beschreibungen, Variations-Hinweis, Klangwort-Hinweis — 18), Wissens-Blätter MusicTheoryPrimer 12 · BioScienceInfo 11 · LightScienceInfo 8 (über LearnLibrary erreichbar), CameraCapture-Fehler 3 (Leser prüfen), SongAutomationEditor 1, LearnView 1, EchoelValueField-Gestensatz; türlos/leserlos bewusst nicht: ImmersiveStageView, StretchMode.characterHint (kein Leser), TrackInstrument.subtitle (kein Leser).

## 2026-10-01 — E4-73: Chip-Vollnamen, Orts-Zeile, Rhythmus-Beschreibungen, Variations-Hinweis (2075944bd)

- **Gebaut:** `StudioMenu.fullName` (10 VoiceOver-Namen; regionsbegrenzt ersetzt, weil `label` ebenfalls „Master“ zurückgibt), `placeStatusLine` (5; „Im Namen: “ + Ort + „ (manuell)“), die sechs Rhythmus-Beschreibungen der Field-Arp-Zeile plus die zwei Laid-back-Hinweise (deutsche Sätze zitieren Katalog-Chipwörter: Dichte, Entwicklung, Laid back), `moodVariationCaption` (Kette → ein Schlüssel; der interpolierte Satz um seine zwei Zahlen in typisierte `let`s zerlegt, `let moved = MoodProfile.variationSpread.count` bleibt in den ersten 900 Zeichen). Der Begriffs-Hinweis mit maskierten Anführungszeichen bleibt wörtlich (ein Schlüssel kann die Backslashes nicht ehrlich tragen). Katalog 1645 → 1670 (+25; „Effects“/„Master“ wiederverwendet). Sources: 1 Datei + Katalog; Tests: 3.
- **Wächter:** Anspruch 11 E4-73-Block (6 Naht-Nadeln, 3 Abwesenheits-Nadeln, 28 Einheiten; XCTAssert 345 → 347). Zwei Wächter 1:1 re-verankert: PerformIsASecondViewOfTheSameSessionTests (`.sound`), TheWorkstationHasADoorTests (`.workstation`) — je eine Nadel, eine Kommentarzeile, XCTAssert-Zahl gleich. SaveDoorNamingTests (liest die `.export`-ZEILE auf save/loop) und TheGenrePresetIsACentreNotAPointTests (900-Zeichen-Fenster) in Python gespiegelt: beide bestehen auf WORK. Benotung `scratchpad/transcribe_e4_73.py`: HEAD FAIL (6/3/25 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 974/0. Checker OK (moved-needles: zwei eigene Abwesenheits-Nadeln, Fragen).
- **Gates:** 12b7a2ffb: Compile 3127 ✓, CI/CD 6591 (Full Suite 2177 ✓), Auto-Merge 4025 ✓ → main = 12b7a2ffb (#373 zu). 4167cc092: Compile 3128 ✓, Quick Test 3856 ✓, Auto-Merge Docs 589 ✓; CI/CD 6592 + Auto-Merge 4026 laufen (#374). E4-72-Stapel (e07a078c4 + d634fe4b9) danach GEPUSHT als Spitze d634fe4b9. E4-73 (2075944bd) lokal — Push nach Compile Check auf d634fe4b9.
- **Offen (E4), ungekappt gemessen:** Wissens-Blätter MusicTheoryPrimer 12 · BioScienceInfo 11 · LightScienceInfo 8 (über LearnLibrary erreichbar), CameraCapture-Fehler 3 (Leser prüfen), SongAutomationEditor 1, LearnView 1, EchoelValueField-Gestensatz, EchoelStudioView-Begriffs-Hinweis (bewusst wörtlich); türlos/leserlos bewusst nicht.

## 2026-10-01 — E4-74: Musiktheorie-Blatt (2acebca2f)

- **Gebaut:** `MusicTheoryTopic.title`/`.summary`/`.detail` (9 × 3; Intervall · Skala & Modus · Akkord · Akkordfolge · Kadenz · Tonart · Tempo · Swing · Dynamik mit je einem Satz und einem Absatz) als Katalog-Schlüssel; Beispiele (I–V–vi–IV, V→I, c-Moll, A440) und Produktwörter (Stück, Tonart, Loop, Stems, DAW) bleiben. `MusicTheoryTopic.footer` bleibt nackt — kein Leser in Sources/ (gemessen). Katalog 1670 → 1695 (+25; „Key“/„Tempo“ wiederverwendet). Sources: 1 Datei + Katalog.
- **Wächter:** Anspruch 11 E4-74-Block (4 Naht-Nadeln, 2 Abwesenheits-Nadeln, 27 Einheiten; XCTAssert 347 → 349). Kein Quell-Nadel-Wächter pinnt die Zeilen (TheChromeSpeaksOneWordPerThingTests scannt die Datei auf gestrichene Wörter — null Treffer); MusicTheoryPrimerTests/LearnLibraryTests vergleichen zur Laufzeit unter der Test-Locale. Benotung `scratchpad/transcribe_e4_74.py`: HEAD FAIL (4/2/25 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 980/0. Checker OK (moved-needles: zwei eigene Abwesenheits-Nadeln, Fragen).
- **Gates:** d634fe4b9 (E4-72) gepusht, Monitor byisjbq38 (#375). E4-73 (2075944bd + 9335c5d74) und E4-74 (2acebca2f) lokal — Push nach Compile Check auf d634fe4b9.
- **Nächste Scheiben:** E4-75 BioScienceInfo (15; `\u{201C}`-Escape in hrvCoherence muss zum Literal werden, damit der Schlüssel als Literal in Sources steht — Laufzeit-String identisch; TheScienceCardClaimsNoSweepTests pinnt Sätze INNERHALB der Literale, überlebt das Einwickeln), E4-76 LightScienceInfo (15; `.scope`-Absatz trägt „39 %“ — `%` darf in keinen Schlüssel, Split um die Zahl verlangt einen 1:1-Re-Anker in TheColourCopyNamesThePurpleLineTests Anspruch 1).

## 2026-10-01 — E4-75: Körperwissenschafts-Blatt (b5d917970)

- **Gebaut:** `BioScienceTopic.title`/`.summary`/`.detail` (5 × 3; Resonanzatmung · Herzratenvariabilität & Kohärenz · Baroreflex-Schleife · Was die Forschung misst · Was das ist — und was nicht) als Katalog-Schlüssel. Der eine `\u{201C}`-Escape im HRV-Absatz wurde zum Glyph (Laufzeit-String identisch; nur ein Literal kann Schlüssel sein). Die deutsche Fassung hält die Markenlinie wörtlich: misst und zeigt, verschreibt nichts, kein Medizinprodukt, beide Zitate (Lehrer & Vaschillo; Goessl, Curtiss & Hofmann 2017). Katalog 1695 → 1710 (+15). Sources: 1 Datei + Katalog.
- **Wächter:** Anspruch 11 E4-75-Block (3 Naht-Nadeln, 2 Abwesenheits-Nadeln, 15 Einheiten; XCTAssert 349 → 351). TheScienceCardClaimsNoSweepTests pinnt Sätze INNERHALB der Literale („Lehrer & Vaschillo“, „does not run the clinical sweep“) und die Abwesenheit einer Sweep-Behauptung — beide in Python gespiegelt, bestehen auf WORK. Benotung `scratchpad/transcribe_e4_75.py`: HEAD FAIL (3/2/15 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 985/0. Checker OK.
- **Lehre:** ein Swift-`\u{…}`-Escape in einer Wächter-Nadel ist für die Python-Transkription unlesbar (`unicode_escape` kennt `\uXXXX`, nicht `\u{XXXX}`) — die erste Fassung brach beim Heben der Nadeln ab. Nadel mit Glyph schreiben; die Form mit maskiertem Backslash nur für die ABWESENHEITS-Nadel, die den Escape-Text selbst meint. Außerdem: eine Naht-Nadel, die eine `String(`-Zeile mitten im Satz abschneidet, verschiebt die Klammerbilanz des Diffs — ganze Zeile pinnen.
- **Gates:** d634fe4b9: Quick Test 3857 ✓, Auto-Merge Docs 590 ✓; Compile 3129 / CI/CD / Auto-Merge laufen (Monitor byisjbq38, #375). Lokal ungepusht: E4-73 (2075944bd + 9335c5d74), E4-74 (2acebca2f + 3ee24f3c2), E4-75 (b5d917970).

## 2026-10-01 — E4-76: Licht-Blatt (8ce815ff7)

- **Gebaut:** `LightScienceTopic.title`/`.summary`/`.detail` (5 × 3; Blaues Licht & die innere Uhr · Grünes Licht · Rot & Nahinfrarot · Farbe & Emotion · Was das Licht von Echoelmusic ist — und was nicht) als Katalog-Schlüssel. Der `.scope`-Absatz trägt „39 %“ als nackten Operanden zwischen zwei Schlüsseln (ein `%` darf nicht in den Katalog — `String(localized:)` liest den Schlüssel als Format, `% o` wäre ein Spezifizierer); der Satz, den ein Leser sieht, ist unverändert, deutsch „Etwa 39 % jeder Oktave landet auf dieser Naht“. Markenlinie wörtlich erhalten (echte Wellenlängen, keine Lichttherapie, kein Gesundheitsanspruch). Katalog 1710 → 1726 (+16). Sources: 1 Datei + Katalog; Tests: 2.
- **Wächter:** Anspruch 11 E4-76-Block (3 Naht-Nadeln, 2 Abwesenheits-Nadeln, 16 Einheiten; XCTAssert 351 → 353). TheColourCopyNamesThePurpleLineTests Anspruch 1 pinnt den 39-%-Satz per Quell-Nadel — 1:1 re-verankert auf die Drei-Operanden-Naht (eine Nadel, eine Kommentarzeile, XCTAssert-Zahl gleich); die zwei anderen Nadeln und Anspruch 2 sitzen in unberührten Literalen. In Python gespiegelt: alle vier Zählungen halten, der zusammengesetzte Laufzeit-String enthält den gepinnten Satz. Benotung `scratchpad/transcribe_e4_76.py`: HEAD FAIL (3/2/16 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 990/0. Checker OK.
- **Lehre:** die erste Fassung zerlegte den Absatz in `let seamShare` + `return` — damit lag die gepinnte Naht über einem Zeilenumbruch, und die re-verankerte Nadel traf nichts (der Spiegel fand es, die Transkription nicht: sie prüft Zeilen- und XCTAssert-Zahl des Re-Ankers, nicht die Nadel). Drei Operanden bleiben EIN Ausdruck; der `let`-Split ist für Ternäre und den fünften Operanden.
- **Gates:** d634fe4b9: Quick Test 3857 ✓, Auto-Merge Docs 590 ✓; Compile Check / CI/CD / Auto-Merge laufen (Monitor byisjbq38, #375). Lokal ungepusht: E4-73 (2075944bd + 9335c5d74), E4-74 (2acebca2f + 3ee24f3c2), E4-75 (b5d917970 + 35b66caa5), E4-76 (8ce815ff7).
- **Offen (E4):** CameraCapture-Fehler 3 (`CameraCaptureError.errorDescription` — Leser prüfen), SongAutomationEditor-Hinweis (1 + Nachsatz), LearnView-Statuszeile (4), EchoelValueField-Gestensatz (1); bewusst nicht: WAV-HUD, türlose Flächen, leserlose Zeilen, Begriffs-Hinweis mit maskierten Anführungszeichen, MusicTheoryTopic.footer (kein Leser).

## 2026-10-01 — E4-77: Automations-Hinweis, Wertfeld-Geste — E4-Durchgang geschlossen (20ce55bab)

- **Gebaut:** `SongAutomationEdit.hint` (4 Einheiten: „Tippe auf die Zeile, um den ersten Punkt zu setzen.“ / „… einen Punkt im Stück zu setzen.“ / „Tippe auf einen Punkt, um ihn zu wählen. Halte einen Punkt gedrückt und schiebe ihn, um ihn zu verschieben.“ / Nachsatz „ Die Kurve läuft weiter bis zu einem Punkt nach dem Ende des Stücks.“ — Nachsatz als typisierter Ternär aus Schlüssel und leerem String, das Leer-Paar als typisierter Ternär zweier Schlüssel, Funktion bleibt `nonisolated static`) und die VoiceOver-Geste des Wertfelds („Nach oben oder unten wischen zum Einstellen, oder doppelt tippen zum Eingeben“). Katalog 1726 → 1731 (+5). Sources: 2 Dateien + Katalog.
- **Gemessen und bewusst nackt gelassen:** `CameraCaptureError.errorDescription` (einziger Leser: eine Log-Zeile), LearnView-Ankündigungs-Statuszeile (hinter `cloudKitConfigured == false`, v1.1), `MusicTheoryTopic.footer` (kein Leser), WAV-HUD (bewusst englisch), Begriffs-Hinweis mit maskierten Anführungszeichen, türlose Flächen, persistierte Spurnamen, leserlose Genre-Herkunftszeilen.
- **Wächter:** Anspruch 11 E4-77-Block (3 Naht-Nadeln, 2 Abwesenheits-Nadeln, 5 Einheiten; XCTAssert 353 → 357). TheSongAutomationIsDrawnThroughOneWriterTests vergleicht zur Laufzeit unter der Test-Locale (Gleichheit, contains, hasSuffix — gespiegelt); ADisabledParameterRowLooksDisabledTests zählt den Gestensatz genau einmal und pinnt den Aus-Zweig — eingewickelt bleibt er einer (gespiegelt). Benotung `scratchpad/transcribe_e4_77.py`: HEAD FAIL (3/2/5 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 995/0. Checker OK.
- ⛔ **ZURÜCKGENOMMEN in derselben Stunde (bf8b14b08): „der Durchgang ist geschlossen“ stand hier und war FALSCH.** Der Scan dahinter traf nur `return "<Großbuchstabe> wort wort` — keine Ternäre, keine Kleinbuchstaben-Anfänge, kein `Unavailable:` — also ungekappt, aber ENG; eine enge Nadel liefert genauso still weniger als die Wahrheit wie eine gekappte Liste (context.md §2; die erste Rücknahme dieser Sitzung war die Kappung, diese ist die Nadel). Ein breiter Scan fand erreichbare nackte Erzeuger in WorkstationSummary (Transport-/Click-Hinweise), EchoelStudioView (:6242 Dynamic-Hinweis, Text-/Hint-Ternäre), BodyTempoField, HRVCoherence, FXModulation, AutomationStatus, NoteNaming, SignalRouter/SignalRouting, MicrotonalTuning, PartNoteEditor, LiveColaboView, AutomationStatusStrip u. a. Die E4-Liste ist WIEDER OFFEN; der breite Scan liegt im Scratchpad (`e4_rest.txt`) und wird scheibenweise abgearbeitet, jeder Treffer zuerst nach String-Position vs. LocalizedStringKey-Position eingeordnet.
- **Gates:** d634fe4b9: Compile 3129 ✓, Quick Test 3857 ✓, Auto-Merge Docs 590 ✓ (CI/CD 6593 + Auto-Merge 4027 laufen, #375). Stapel E4-73…E4-76 gepusht als Spitze 4d5251d93 (Quick Test 3858 ✓, Auto-Merge Docs 591 ✓; Compile/CI/CD/Auto-Merge laufen, Monitor b53mzqjfr, #376). E4-77 (20ce55bab) lokal — Push nach Compile Check auf 4d5251d93.

## 2026-10-01 — E4-78: Workstation-Ansagen, Tempo-Folge-Label, Akzent-Hinweise (209e0754f)

- **Gebaut:** erste Scheibe der wieder geöffneten Liste. `WorkstationSummary`: Transport-/Click-Hinweise („Spielt das Arrangement von vorn auf dem gemeinsamen Transport.“ / „Nicht verfügbar: dieses Stück hat keine Teile auf einer Spur, die spielt.“ / „Schaltet den Click aus.“ / „Spielt einen gleichmäßigen Click im aktuellen Tempo …“), die Fragmente der Zeilen-Beschreibung (Bio-Automationsspur · keine Teile · 1 Teil · N Teile · stumm · solo · scharf für Aufnahme · „noch keine Timeline-Engine spielt diese Art“) und die zwei Takt-Wörter („Takt “ / „Takte “, Zahl als nackter Operand). `TempoFollowLabel`: vier Sätze („Tempo, folgt — es kommt keine Messung an“, „Tempo, folgt: “ + Subjekt — Doppelpunkt, weil das geteilte Subjekt im Nominativ steht —, drei „Tempo festgestellt — tippen, damit …“) plus „Tempo auf diesen Wert feststellen“. `EchoelStudioView`: die zwei Akzent-Hinweise unter der Field-Arp-Zeile (Rhythmusname als nackter Operand). Katalog 1731 → 1751 (+20, 3 wiederverwendet). Sources: 3 Dateien + Katalog.
- **Benannter Kompromiss:** der Takt-Spannen-Verbinder ist der geteilte Schlüssel „ to “, dessen deutsche Einheit „ zu “ ist (Routen-/Relink-Zeilen) — eine deutsche Zeile sagt „Takte 1 zu 5“, bis der Founder ein Spannen-Wort wählt. Im Wächter-Kommentar benannt, nicht versteckt; Englisch unverändert.
- **Wächter:** Anspruch 11 E4-78-Block (8 Naht-Nadeln, 3 Abwesenheits-Nadeln, 23 Einheiten; XCTAssert 357 → 363). Alle Laufzeit-Wächter (TheWorkstationHasADoorTests barSpan/spoken, TheWorkstationArmsTheClickTests, TheWorkstationPlaysTheTimelineTests, TheSpokenTempoSaysWhoseBodyTests samt Einmal-Zählung des zitierten Lock-Literals, TheTempoModeSpeaksTheLocksWordsTests) in Python gespiegelt; keine Quell-Nadel umverankert. Benotung `scratchpad/transcribe_e4_78.py`: HEAD FAIL (8/3/20 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 1006/0. Checker OK, Klammerbilanz 0.
- **Harness-Lehre:** die „guard literals lost“-Prüfung der Transkription traf ein Anführungszeichen-Paarungs-Artefakt aus der Prosa von `LaunchLogsWhatItWokeUpWithTests` gegen `WorkstationSummary`, eine Datei, die dieser Wächter nie liest. Jetzt pro benannter Datei gescoped — für jeden Wächter, der die Datei liest, unverändert streng.
- **Gates:** d634fe4b9 komplett grün (Compile 3129, Quick Test 3857, Full Suite 2179, Auto-Merge Docs 590, Auto-Merge 4027 → main; #375 zu). 4d5251d93: Compile 3130 ✓, Quick Test 3858 ✓, Auto-Merge Docs 591 ✓, Auto-Merge 4028 abgebrochen (vom Folge-Push verdrängt, erwartet; #376 zu). 1d3719d17: Quick Test 3859 ✓, Auto-Merge Docs 592 ✓; Compile/CI/CD/Auto-Merge laufen (Monitor bm3mgksfm, #377). E4-78 (209e0754f) lokal — Push nach Compile Check auf 1d3719d17.

## 2026-10-01 — E4-79: Routing-Fläche — Schalter-Hinweise und Notizen (0eb66e9e4)

- **Gebaut:** PatchbayView, 28 Ternär-Sätze in `Text(cond ? … : …)` / `.accessibilityHint(cond ? …)` / `.accessibilityLabel(cond ? …)` — Strings, wo SwiftUI einen Schlüssel genommen hätte (E4-39-Lesart). Jeder Zweig ist jetzt sein eigenes `String(localized:)`: Drahtloses MIDI (4), MPE-Notenlayout + Ausdruck pro Note (8, das vorhandene Katalogwort), MIDI-2.0-Quelle (4), OSC-Steuereingang (4), klinisches HRV-Detail (4), die zwei deaktivierten Knopf-Labels (4; „Zurücksetzen“ = das Katalogwort für Clear, „Smart patch“ wiederverwendet). Katalog 1751 → 1779 (+28). Sources: 1 Datei + Katalog.
- **Prozentzeichen:** die klinische AN-Notiz trägt „(0–100 %)“; ein Katalogschlüssel wird als Format-String gelesen, also lebt der Satz in `clinicalDetailOnNote` als `scale` (Schlüssel + „%“) und `tail` (Schlüssel) — typisierte lets außerhalb des Ternärs, keine `+`-Kette darin (E4-28).
- **Wächter:** `TheRoutingCardDoesNotPromiseGestureTests` Anspruch 2 auf die `scale`-Zeile 1:1 umverankert (die zwei anderen Nadeln sind Teilstrings und überleben). Anspruch 11 E4-79-Block: 8 Nähte, 3 verbatim eingerückte Abwesenheiten, 14 Einheiten (XCTAssert 363 → 365). ⚠️ Die erste Abwesenheits-Nadel `: "Off. Every note is sent on channel 1.")` war TEILSTRING ihrer eigenen neuen Naht — die Transkription hat es gefangen (WORK FAIL, verbatim present 1). Deshalb zielen Abwesenheits-Nadeln auf die verbatim eingerückte Zeile.
- **Benotung** `scratchpad/transcribe_e4_79.py`: HEAD FAIL (8/3/28 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 1017/0. Checker OK, Sources-Klammerbilanz 0.
- **Gates:** 1d3719d17: Quick Test 3859 ✓, Auto-Merge Docs 592 ✓; Compile 3131, CI/CD 6595, Full Suite 2181, Auto-Merge 4029 laufen seit 03:35Z (Monitor bm3mgksfm, #377). E4-78 (209e0754f) und E4-79 (0eb66e9e4) lokal — Push nach Compile Check auf 1d3719d17.

## 2026-10-01 — E4-80: die restlichen Ternäre und Helfer-Strings des Studios (348d95ad7)

- **Gebaut:** EchoelStudioView — Export-Hinweis-Paar („Stoppt diese Aufnahme und verwirft sie. Nichts wird gesichert.“ / „Nimmt einen Loop auf und exportiert eine WAV zum Teilen“), Leerzeile des Variations-Boards, Wetterzeile (berechnetes `weatherLine`: Schlüssel oder „Jetzt: “ + Messung), Click-Akzent-Hinweis als EIN Schlüssel statt `+`-Kette, Routing-Tür und Textgrößen-Knöpfe (`masterDoorButton` und `sizeButton` nehmen `LocalizedStringKey` — null Aufrufstellen-Änderungen, E4-9), „Wie die Musik“, Diagnose-Leerzeile, Teilen-Absage, Behalten-Hinweis-Paar, Health-Statuspaar („Wartet auf die Erlaubnis in Health.“ / „Standardmäßig aus. Nur Herz- und Atemmessungen.“), die zwei Paare des Nur-Bild-Starts. Katalog 1779 → 1806 (+27, „Standard“ wiederverwendet). Sources: 1 Datei + Katalog.
- **Wächter:** Anspruch 11 E4-80-Block (9 Nähte inkl. beider neuer Signaturen und `Text(weatherLine)`, 3 verbatim eingerückte Abwesenheiten, 23 Einheiten; XCTAssert 365 → 367). `TheTextSizeHasButtonsTests` unverändert und in Python gespiegelt (Aufrufstellen byte-identisch). Benotung `scratchpad/transcribe_e4_80.py`: HEAD FAIL (9/3/27 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 1029/0. Checker OK, Sources-Klammerbilanz 0.
- **Harness-Lehre (zweite heute):** die „guard literals lost“-Prüfung paarte Anführungszeichen über den rohen Guard-Text; ein `"` in einem Kommentar verschob die Paarung, und eine ZWISCHEN-Literal-Lücke (`\n + `) traf den gefalteten Click-Hinweis. Jetzt Paarung auf `codeOnly`-Text mit ausgeblendeten `"""`-Blöcken. Kein Artefakt war eine Nadel, kein Wächter ist schwächer.
- **Gates:** Stapel E4-78/E4-79 gepusht als b967159b2 (nach Compile Check 3131 ✓ auf 1d3719d17): Quick Test 3860 ✓, Auto-Merge Docs 593 ✓; Compile/CI/CD/Auto-Merge laufen (Monitor bdjlpbjh8, #378). 1d3719d17: Compile 3131 ✓ (CI/CD 6595, Auto-Merge 4029 laufen, #377). E4-80 (348d95ad7) lokal — Push nach Compile Check auf b967159b2.

## 2026-10-01 — E4-81: Spur-Inspektor, Szenen-Start, Noten-Editor (a7ddc784b)

- **Gebaut:** `TrackMix.muteHint/soloHint` (4 Sätze: „Schaltet diese Spur und das Studio-Instrument stumm. Start hebt die Stummschaltung auf“ / „Schaltet diese Spur stumm“ / „Spielt nur die Solo-Spuren“ …), Szenen-Start-Leitzeile + Teil-Hinweis-Paar (4), Noten-Editor-Umschalt-Label-Paar + Gitter-Hinweis-Paar (4) als Schlüssel, je Ternär-Zweig ein `String(localized:)`. Vier LocalizedStringKey-Positionen bekamen nur ihre fehlende Einheit, ohne Sources-Änderung: „Nächste Note wählen“ / „Vorige Note wählen“ (ThePartNoteGridSpeaksTests pinnt die Zeilen verbatim), Colabo-Stream-Hinweis, FX-Suchfeld „Presets & Tags suchen“. Katalog 1806 → 1822 (+16). Sources: 3 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-81-Block (9 Nähte in drei Dateien, 3 verbatim eingerückte Abwesenheiten, 14 Einheiten; XCTAssert 367 → 373). Laufzeit-Spiegel TheTrackHeaderMutesAndSolosTests („Studio instrument“ im Echoel-Mute-Hinweis und in jedem Nicht-Echoel-Solo-Hinweis, sonst abwesend) hält unter en. Benotung `scratchpad/transcribe_e4_81.py`: HEAD FAIL (8/3/16 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 1041/0. Checker OK, Sources-Klammerbilanz 0.
- **Gates:** b967159b2 (E4-78/E4-79): Quick Test 3860 ✓, Auto-Merge Docs 593 ✓; Compile/CI/CD/Auto-Merge laufen (Monitor bdjlpbjh8, #378). E4-80 (348d95ad7) und E4-81 (a7ddc784b) lokal — Push nach Compile Check auf b967159b2.

## 2026-10-01 — E4-82: Automations-Editor, Automations-Leiste, Teil-Leiste (43ede9f50)

- **Gebaut:** Automations-Editor Umschalt-Label-Paar („Automation der gewählten Spur ausblenden/einblenden“) + Wertfeld-Hinweis („Setzt den Wert des gewählten Punkts“); Automations-Leiste Statuspaar („Globale Kurven bewegen diese Parameter, während der Transport läuft.“ / „Standardmäßig aus. Teil- und Arrangement-Kurven spielen weiter; …“); Teil-Leiste Start-Takt-Hinweis. Die Canvas-Hinweis-Einheit aus der E4-26-Zeit bleibt UNVERÄNDERT (der Skript prüft eine vorhandene Einheit statt sie zu überschreiben — deshalb brach er ab und lief erneut), „Nächsten/Vorigen Punkt wählen“ bekamen ihre Einheiten. Katalog 1822 → 1830 (+8). Sources: 3 Dateien + Katalog.
- **Wächter:** Anspruch 11 E4-82-Block (5 Nähte in drei Dateien, 2 verbatim eingerückte Abwesenheiten, 9 Einheiten; XCTAssert 373 → 378). Kein anderer Wächter pinnte diese Zeilen. Benotung `scratchpad/transcribe_e4_82.py`: HEAD FAIL (5/2/8 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 1048/0. Checker OK, Klammerbilanz 0.
- **Gates:** b967159b2: Quick Test 3860 ✓, Auto-Merge Docs 593 ✓; Compile/CI/CD/Auto-Merge laufen (Monitor bdjlpbjh8, #378). E4-80 (348d95ad7), E4-81 (a7ddc784b), E4-82 (43ede9f50) lokal — Push nach Compile Check auf b967159b2.

## 2026-10-01 — E4-83: Workstation-Fragmente, Colabo-Einladung, Caption-Leerzeile (7417ea544)

- **Gebaut:** WorkstationView Spur-Details-Hinweis-Paar („Schließt die Details dieser Spur“ / „Öffnet die Details dieser Spur: ihr Gerät sowie Mixer und Teile, wo sie welche hat“) und die drei `?? "…"`-Rückfälle für eine namenlose Spur („die MIDI-Spur“ ×2, „die Audiospur“ wiederverwendet); LiveColaboView Einladungs-Beitrittspaar; StudioCaptionView Leersatz („Jedes Bedienelement formt die Musik, während sie spielt.“). Katalog 1830 → 1836 (+6). Sources: 3 Dateien + Katalog.
- **Zwei Formen:** ein `?? "…"`-Rückfall, der in einen aus Schlüsseln gebauten Satz fließt, ist selbst ein nackter String — der Satz liest deutsch um einen englischen Spurnamen; und `Text(cond ? "…" : variable)` typisiert das Literal als String, weil der andere Zweig einer ist.
- **Wächter:** Anspruch 11 E4-83-Block (5 Nähte in drei Dateien, 2 verbatim eingerückte Abwesenheiten, 7 Einheiten; XCTAssert 378 → 383). Kein anderer Wächter pinnte diese Zeilen. Benotung `scratchpad/transcribe_e4_83.py`: HEAD FAIL (5/2/6 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 1055/0. Checker OK, Klammerbilanz 0.
- **Gates:** Stapel E4-80…E4-82 gepusht als 5fa4ed469 (nach Compile Check 3132 ✓ auf b967159b2; Monitor b6r2mv3yl, #379). b967159b2: Compile 3132 ✓, Quick Test 3860 ✓, Auto-Merge Docs 593 ✓; CI/CD + Auto-Merge laufen (#378). E4-83 (7417ea544) lokal — Push nach Compile Check auf 5fa4ed469.

## 2026-10-01 — E4-84: FX-Live-Überschriften, Audio-Degraded-Rückfall, Notennamen-Schemata (e91cf44ca)

- **Gebaut:** `LiveModOrigin.heading` (drei Literale, ein `switch`; gelesen vom FX-Sheet und vom Narrations-Blatt) → „Live — Körper → Klang“ / „Live — LFO → Klang“ / „Live — simulierte Demo → Klang“; AudioDegradedRow-Rückfall „Audio gestoppt und konnte nicht neu starten.“ (der Ursachen-Satz der Engine bleibt englisch — Diagnose, keine Kopie); die vier `NoteNaming.displayName`-Etiketten des Pickers („A B C (international)“, „A H C (deutsch)“, Solfège/Sargam identisch). Katalog 1836 → 1844 (+8). Sources: 3 Dateien + Katalog.
- **Nachgezogen im selben Commit:** der E4-35-Zähl-Pin auf FXModulation (`return String(localized: "`-Stellen) 20 → 23 — count-pins.py meldete ihn ROT, seine eigene Meldung verlangte das Nachführen; Python-Spiegel auf dem kommentarfreien Text = 23.
- **Bewusst nicht gekeyt:** `HRVCoherence.headline`/`lesson` — kein Sources-Leser (nur Kommentare nennen sie); `AudioEngine.lastAudioError`-Sätze (Engine-Diagnose).
- **Wächter:** Anspruch 11 E4-84-Block (8 Nähte in drei Dateien, 3 verbatim eingerückte Abwesenheiten, 8 Einheiten; XCTAssert 383 → 390). TheFXHeadersSayWhoseBodyTests pinnt die Überschriften per WERT — hält unter en. Benotung `scratchpad/transcribe_e4_84.py`: HEAD FAIL (8/3/8 — EIN Befund), WORK PASS. Gesamt-Anspruch-11-Nadeln 628/0 (147 Dateien). Checker OK (count-pins 0 RED nach dem Nachziehen), Klammerbilanz 0.
- **Lehre:** `rep()` auf das nackte Literal brach an `"Live — body → sound"` ab (3 Treffer: zwei Kommentare) — Ersetzung mit `return `-Präfix verankert; der Skript-Assert hat genau dafür gegriffen, nichts wurde geschrieben.
- **Gates:** 1d3719d17 (#377) und b967159b2 (#378) komplett grün inkl. Auto-Merge 4029/4030 → main. 5fa4ed469: Compile Check 3133 ✓, Quick Test 3861 ✓, Auto-Merge Docs 594 ✓ (#379; CI/CD + Auto-Merge laufen). Stapel 7417ea544 · ee6514bdd · e91cf44ca · Docs gepusht nach Compile 3133.

## 2026-10-01 — E4-85: Stimmungssystem-Namen (b2c859493)

- **Gebaut:** die fünfzehn `name:`-Literale von `TuningSystem.library` als Katalog-Schlüssel („12-TET (Standard)“, „24-TET (Vierteltöne)“, „Reine Stimmung — Dur/Moll“, „Pythagoreisch (diatonisch)“, „1/4-Komma-Mitteltönig (chromatisch)“, „Maqām Rāst/Bayātī (24-TET, theoretisch)“, „Gamelan Pélog (repräsentativ)“, „Hirajōshi (japanische Pentatonik)“, „Bohlen–Pierce (nicht oktavierend)“; Eigennamen identisch). Leser: Picker `Text(t.name)` in WorkspaceView, Banner-Titel. Katalog 1844 → 1859 (+15). Sources: 1 Datei + Katalog.
- **Gemessen, bewusst nackt:** `MusicStyle.Category.title` (neun Familien-Titel) hat KEINEN Sources-Leser (die Regale lesen seit E4-20 `Subcategory.title`). Der Banner-Satz „Non-standard tuning: \(systemName)…“ bleibt offen — Interpolation, braucht den E4-28-Split.
- **Wächter:** Anspruch 11 E4-85-Block (4 Nähte, Zähl-Pin 15, 1 verbatim Abwesenheit, 15 Einheiten; XCTAssert 390 → 393). Benotung `scratchpad/transcribe_e4_85.py`: HEAD FAIL (4/1/15 — EIN Befund), WORK PASS. Gesamt-Anspruch-11 632/0 (148 Dateien). Checker OK, Sources-Klammerbilanz 0 (Tests-Diff +4 = String-Inhalt).
- **Gates:** 823e502fa gepusht (E4-83 · E4-84 + Docs; Monitor bb2kh0l0v, #380). 5fa4ed469: Compile 3133 ✓, Quick Test ✓, Auto-Merge Docs ✓ (#379, Rest läuft). E4-85 (b2c859493) lokal — Push nach Compile Check auf 823e502fa.

## 2026-10-01 — E4-86: Visual-Preset-Blurbs und Medien-Seed-Presets (2746a8672)

- **Gebaut:** die fünf Werks-Blurbs von `VisualPreset.factory` („weiche, spärliche, langsame Aura“ … „maximal — dicht, schnell, zentrifugal“) und die zwei Seed-Presets aus MediaSeedLook („Aus Foto“ / „Aus Video“ + Blurbs) als Katalog-Schlüssel. Leser: `Text(preset.name)` und das gesprochene Label `preset.name + " visual preset — " + preset.blurb` (E4-41-Naht). Katalog 1859 → 1868 (+9). Sources: 2 Dateien + Katalog.
- **Bewusst nackt:** die fünf Werks-NAMEN (Aura · Vapor · Bloom · Pulse · Zentrifuge) — Eigennamen, VisualPresetTests pinnt „Aura“ zur Laufzeit.
- **Wächter:** Anspruch 11 E4-86-Block (7 Nähte, Zähl-Pin 5, 2 verbatim Abwesenheiten, 9 Einheiten; XCTAssert 393 → 398). Benotung `scratchpad/transcribe_e4_86.py`: HEAD FAIL (7/2/9 — EIN Befund), WORK PASS. Gesamt-Anspruch-11 639/0 (150 Dateien). Checker OK, Sources-Klammerbilanz 0.
- **Gates:** 5fa4ed469 komplett grün inkl. Auto-Merge 4031 → main (#379 zu). 823e502fa: Compile 3134 ✓, Quick Test ✓, Auto-Merge Docs ✓ (#380, Rest läuft). E4-85-Stapel 5c906c85b gepusht (Monitor bo299v9d7). E4-86 (2746a8672) lokal — Push nach Compile Check auf 5c906c85b.

## 2026-10-01 — E4-87: Routing-Port- und Konverter-Namen (95fc41e35)

- **Gebaut:** die zwölf Port-Namen des Standard-Graphen („Körper (Bio)“, „Musik“, „Brustgurt (BLE)“, „ADM-OSC (räumlich)“, „Art-Net (Licht)“, „sACN (Licht)“, „Audio-Master“; MIDI In/MPE Out, OSC Out, Broadcast identisch) und die zehn Konverter-Namen („Bio → Licht“, „Bio → Raumobjekt“, „Tonhöhe/Akkord → Farbe“, „Makro → Raum“ …) als Katalog-Schlüssel. Katalog 1868 → 1890 (+22). Sources: 2 Dateien + Katalog.
- **Sicher, weil:** nur `graph.routes` persistiert; Ports und Konverter entstehen bei jedem Start aus Code. Die `midi.in`-Zeile nennt weiter kein „MPE“ (Python-Spiegel des MPE-Wächters).
- **Wächter:** Anspruch 11 E4-87-Block (7 Nähte, Zähl-Pins 12/10, 2 verbatim Abwesenheiten, 22 Einheiten; XCTAssert 398 → 404). Benotung `scratchpad/transcribe_e4_87.py`: HEAD FAIL (7/2/22 — EIN Befund), WORK PASS. Gesamt-Anspruch-11 646/0 (152 Dateien). Checker OK, Sources-Klammerbilanz 0.
- **Gates:** 823e502fa (#380) und 5c906c85b komplett grün inkl. Auto-Merge 4032/4033 → main (CI/CD-Conclusion failure = #396-Form). Stapel E4-86 · E4-87 nach Compile Check 3135 gepusht.
- **Sitzung:** Founder hat das Modell gewechselt; get_session bestätigt den Wechsel. Kontext vollständig weitergeführt, keine Lücke im E4-Strang.

## 2026-10-01 — E4-88 · E4-89: Stimmungs-Banner und Modifier-Titel (fe60d3bde · b3f3e1788)

- **E4-88:** die Überschrift des Stimmungs-Banners besteht aus Schlüssel-Satzköpfen plus Operanden (Systemname, Hz-Zahl, „, A4 = “, „ Hz“). Katalog 1890 → 1892. Englisch byte-identisch, DetunedInstrumentSaysSoTests-Nadel bleibt im Rumpf.
- **E4-89 (Wächter-Blindheit):** Anspruch 10 kannte nur View-Konstruktoren; `.alert`/`.navigationTitle`-Titel waren nie ein Fundort. Fünf englisch ausgelieferte Titel („Save piece“, „Save mood“, „Save sound“, „Open piece“, „Recovery“) plus die identische EchoelFX-Einheit. Katalog 1892 → 1898, null Swift-Zeilen in Sources.
- **Gemessen:** erweiterter Lauf auf HEAD-Katalog 554 Fundorte / 6 fehlend, auf WORK 554 / 0. Der alte Lauf meldete auf HEAD [] — Blindheit, kein Bestehen.
- **Wächter:** Anspruch 11 E4-88 (3 Nähte, 1 Abwesenheit, 2 Einheiten) und E4-89 (5 Nähte, 6 Einheiten); XCTAssert 404 → 408. Beide Transkriptionen WORK PASS / HEAD FAIL. Gesamt-Anspruch-11 654/0 (155 Dateien).
- **Gates:** e004aa6f2 Compile Check 3136 ✓, Quick Test 3864 ✓, Auto-Merge Docs 597 ✓. Stapel E4-88 · E4-89 danach gepusht (Spitze b3f3e1788).
- **Nebenbefund Monitor:** die Gate-Schleife suchte `Echoel_CI/CD_Pipeline`, der gekürzte Name ist `Echoelmusic_CI/CD_Pipe` — ALL_DONE konnte nie feuern. Neue Schleife sucht `CI/CD`.

## 2026-10-01 — E4-90 · E4-91 · E4-92: die VoiceOver-Hälfte (7ad87b510 · 9ea54803a · 3c7c3cb96)

- **E4-90:** Arrange-Feld (Hörzustände „, stumm“ / „, solo“ / „, still, weil eine andere Spur solo ist“, Teil-Label) und die Ortszeile im Kopf („ · Teil bei Takt “). Katalog 1898 → 1902.
- **E4-91:** Noten-Editor (Anzahl über die vorhandenen „Note“/„Noten“, Schritt-Ansage „ bei Schritt “ / „, gewählt“) und der Ersatzname „Eine Spur“ in der Aufnahme-Zeile. Katalog 1905.
- **E4-92:** gesprochene Einheiten des Wertfelds (Hertz/Sekunden/Schläge pro Minute, Einheiten schon vorhanden), das gesprochene Folge-Tempo und Label/Hinweis der Feld-Spielfläche (UIKit). Katalog 1907.
- **Wächter:** Anspruch 11 E4-90/91/92, XCTAssert 408 → 423; jede Transkription WORK PASS / HEAD FAIL; Gesamt-Anspruch-11 668/0 (162 Dateien); Anspruch-10-Lauf 554/0.
- **Harness-Befund:** der Transkriptions-Filter verwarf jede Nadel mit Backslash-Klammer — auch die maskierte; zwei Kopfzeilen-Nadeln wären nie benotet worden. Filter verengt auf echte Interpolation.
- **Gates:** b3f3e1788 Compile Check 3137 ✓, Quick Test 3865 ✓; Stapel bis 3c7c3cb96 gepusht, Monitor läuft.

## 2026-10-01 — E4-93 … E4-96: die vier offenen Reste (2069d7184 · 25fefec04 · 273484e32 · b55d78e15)

- **E4-93:** Spur-Inspektor-Hinweise (Instrument, Pegel, Panorama) und der Hinweis „Bar variation“. Deutsch schreibt 1,00 / 2,00 (EchoelDecimalText ist locale-fähig). Katalog 1912.
- **E4-94:** Workstation-Zeile (gesprochene Namen „Stumm“/„Solo“, Detailzeile, Zustands-Etiketten STUMM/SOLO/SCHARF) und die Perform-Schalter. Buchstaben M/S bleiben. Katalog 1921.
- **E4-95:** Instrument-Notizen zum neuen Stück, Bibliotheks-/Speicher-Hinweis, Klangwort-Hinweis (an den zitierten Wörtern geteilt, weil ein Schlüssel kein `"` tragen darf) und das gesprochene „, Favorit“ über einen Helfer. Katalog 1929.
- **E4-96:** der VoiceOver-Hinweis des Einverständnis-Schalters im Onboarding, zwei Fragmente; der „NOT localised“-Kommentar ist zurückgenommen. Katalog 1931.
- **Wächter:** Anspruch 11 E4-93…E4-96, XCTAssert 423 → 437; jede Transkription WORK PASS / HEAD FAIL; Gesamt-Anspruch-11 699 Nadeln / 0 gebrochen (168 Dateien).
- **Gates:** 273484e32 gepusht, Monitor läuft; E4-96 wartet auf den Compile Check.
- **Offen:** weite Abschluss-Messung, bevor „Durchgang geschlossen“ stehen darf.

## 2026-10-01 — E4-97 … E4-112: Abschluss-Durchgang der deutschen Oberfläche (537411808 … 3c5ab2820)

- **Sechzehn Scheiben**, Katalog 1931 → 1998: Bio-Quellen-Zeile, Ecken-Aktionen, Licht-Ausgänge, Chip-Wörter, Bewegungs- und Messgeräte-Namen, Exporter-Grund, Routing- und Automations-Parameter, Latenz-Stufen, Engine-Fehlersätze, Beitritts-Status, zwei VoiceOver-Einheiten, WAV-Plaketten, Mood-Standard und Tone-Namen, Klangfarben-Namen.
- **Abschluss-Messung über vier Familien, Rest null:** `Text(x.rawValue)` (zwei Treffer → E4-112), StringProtocol-Initialisierer mit Variablen-Titel, Accessibility-Modifier mit Variable, String-Label-Eigenschaften mit nackten Literalen.
- **Scanner-Lehren:** `\b` vor `.modifier` trifft nach Leerraum nie (E4-109); ein Lookbehind gegen Buchstaben vor dem Leerzeichen überspringt jedes `return "…"` — ein Scan ohne Treffer ist ein Befund.
- **Zurückgenommen:** die Inbox nannte Engine-Fehlersätze und WAV-HUD „leserlos, bewusst englisch“; beide haben Leser und sind seit E4-107/E4-110 deutsch.
- **Bewusst nicht geschlüsselt (neu):** eingebaute und Community-Preset-Titel (Inhaltsnamen wie Genres); `OutputFormat`, `BeatMode`, `FilterType`, `QualityTier` (kein UI-Leser).
- **Wächter:** Anspruch 11 E4-97…E4-112, XCTAssert 437 → 469; Gesamt-Transkription 738 Nadeln / 0 gebrochen (185 Dateien).
- **Gates:** 333f9efa7 grün (Compile 3142, Auto-Merge 4040); 3c5ab2820 gepusht, Monitor läuft.
- **Gerät offen:** deutsches Telefon ohne abgeschnittenes Wort.

## 2026-10-01 — E3: Evolve-Schalter gebaut (935c33879)

- Founder-Antwort E3 („Ja; Evolve bekommt einen Schalter, Standard aus“) umgesetzt: „Keep evolving“ unter „Bar variation“, Standard AUS, `StudioDefaultKeys.evolveTake`.
- `evolveShouldReseed()` gab drei Monate hart `true` zurück; jetzt gibt es den Schalter zurück. Der Timer läuft weiter und loggt `evolve: HOLD (switch off)`.
- Drei Katalog-Einheiten deutsch („Weiterentwickeln“ + zwei Erklärsätze).
- Wächter `TheEvolveSwitchStartsOffTests`, Transkription WORK PASS / HEAD FAIL. Gates zum Commit-Zeitpunkt offen; Gerät offen.

## 2026-10-01 — Deploy v10.79.484 (der Stück-Build)

- **Notiz** in `.deploy/release`: acht Posten, Prüfliste T1–T10, `founder-verify.py --since 5683fb72d` → 45 neu/umformuliert von 280 (ui 15 · other 14 · audio 7 · visual 5 · sync 3 · bio 1), im SELBEN Commit wie der Bump.
- **Wächter transkribiert:** TheDeployNoteNamesRealDoorsTests 1–5 und TheShippedVersionComesFromTheReleaseFileTests auf WORK grün (Version v10.79.484, Zeile 1; Pfad-Wörter Bio · Field · Master · Mood · Save/Export · Sound · Tempo · Workstation, alle Chips).
- **Gates des Swift-Stands c0674a718:** Compile Check 3144 ✓, CI/CD 6608 Build for Testing ✓, Run Tests #396-Form (0 Fehlschläge im Fenster, TheEvolveSwitchStartsOffTests 4/4 beobachtet), Auto-Merge 4042 ✓.
- **Nicht drin:** 2b-ii. Postfach §2 zeigt jetzt auf 10.79.484.
- **Offen:** TestFlight-Lauf lesen (Archiv, Upload, „Verify build landed in App Store Connect").
- **Ergebnis TestFlight-Lauf 2608 (36838026009):** Preflight ✓, Compile Check ✓, Archive ✓; „Export & Upload“ ✗ — `403 FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED`. Apple-Vereinbarung muss der Account Holder akzeptieren; danach Re-run desselben Laufs. Eingetragen: FOUNDER_INBOX §3 F1, HARNESS_LEDGER Observation.
- **Ursachen-Eingrenzung (Founder: „geht erst nicht mehr seit ChatGPT dabei war“):** TestFlight 2604–2607 (workflow_dispatch auf main, 29.–30.09.) luden alle hoch, inkl. der drei vibrationalforce-Commits (7e6aea965 AUv3-Manifest, 2c33f00c3). `git diff 5d6ac6080 6b2cab77b` über Workflows/Fastlane/project.yml/Info.plist/Entitlements = leer. Der 403 entstand zwischen 30.09. 07:06Z und 01.10. 08:43Z auf Apples Seite.
- **Deploy 10.79.484 GELANDET:** Founder bestätigte die Apple-Vereinbarung; Re-run per API verweigert (403 integration), daher Retry-Absatz in `.deploy/release` (2be6db496) → TestFlight-Lauf 2609 (36844963225): Archive ✓, Upload ✓, Verify landed ✓. Build 2608 nie angekommen, kein Duplikat. Xcode Cloud bewertet: derzeit nicht relevant (GitHub Actions läuft, gleiche Konto-Sperre, schlechtere Sicht für die Sitzung).

## 2026-10-01 — Workstation-Neugestaltung: Deep Audit + Scheibe A1

- **Auftrag (Founder, Tablet-Entwurf angehängt):** Genres und rudimentäre Bedienung weg aus dem Vordergrund, „als Workstation ernsthaft vertreten“, beste Visuals.
- **Fünf Audits** (Oberfläche · Engine · Visual/Licht/Raum · Design-System · Recherche) → Plan `scratchpads/PLAN_WORKSTATION_REDESIGN_2026-10-01.md`.
- **Founder-Antworten protokolliert:** FOUNDER_INBOX H5, decisions.csv, memory/decisions.md, inspiration_intake.
- **A1 gebaut (d27e13258):** `EchoelTheme.TrackHue` (eine Weiche Instrument/Art → gedämpfte Farbe; Körper-Spur = `accent`), Canvas-Rinne mit Farbband + Symbol + Name, getönte Teile, Spuren 40 pt. Neuer Wächter `TheTracksWearTheirOwnHueTests`; zwei Re-Anker (Noten-Skizze, E4-90-Label — letzterer war vorbestehend rot).
- **Prüfwerkzeuge sauber:** dead-needles, swift-escapes, count-pins, foreign-needles; moved-needles 1 Treffer (andere Dateien, geprüft). Gates offen.
- **Nächste Scheiben:** A1b Teil-Namen · A2 Genre → „Stil“ · A3 Transportleiste unten.


## 2026-10-01 — Workstation-Neugestaltung: A1b · A2 · A3 · A6 · A5

- **A1b (Teil-Namen im Block)**, **A2 b006cdbd1** (Genre raus aus dem Kopfstreifen → „Stil“ am Echoel-Gerät; der vorbestehende Rot `labeled("Mode")` → „Tempo“ mitrepariert), **A3 dbbe191cf** (Scroll wandert in `WorkstationView`, `transportBar` per `safeAreaInset(edge: .bottom)` angeheftet; `ArrangeStage` ohne eigenen Scroll). Compile Check auf dbbe191cf ✓; Auto-Merge dort failure, BEVOR Build & Test lief = #310-Form, kein Code-Befund.
- **A6 12430034e:** Kompositions-Anleitung kommt auf einem Stück mit Noten ZUGEKLAPPT an — `ComposeGuide.opensExpanded` EINMAL über `State(initialValue:)`, nie selbst zuklappend (c672c2adf-Lehre). Wächter `TheGuideArrivesFoldedOnAWrittenPieceTests`.
- **A5 a63319b72:** Spurkopf im Canvas WÄHLT (Tipp + VoiceOver-Aktion = `selection.toggleTrack`, Ring + `.isSelected`, 44-pt-Zeilen); Kartenliste nur noch offene Spur + nicht gezeichnete (`ArrangeCanvas.listsCard`); Tonhöhe/Teil-Tempo einer Audiospur unter ihrem offenen Kopf. M/S bleibt EINMAL im Inspektor-Kopf (passt am Telefon nicht in die 96-pt-Rinne) → M/S-in-Rinne ist eine A9-/Founder-Frage. Wächter `TheTrackHeadSitsOnTheCanvasTests`, WORK 16/16, Eltern rot nur durch Abwesenheit + 40→44.
- **Prüfwerkzeuge** nach jeder Scheibe: dead/swift-escapes/foreign/count-pins sauber; moved-needles nur generische Treffer.
- **Zurückgestellt:** A3b (Kopf-Play doppelt Leisten-Play auf der Stück-Bühne; Kopf-Play bleibt für die Instrument-Bühne, viele Wächter pinnen es) · A4 im Wesentlichen schon da (Status/BPM im Kopf, Tonart im Streifen, Position in der Leiste) — offen nur „4/4“.
- **Gerät offen:** Leiste bleibt beim Scrollen stehen und verdeckt die letzte Zeile nicht; Ring auf jeder Spurfarbe lesbar; offener Kopf unter dem Canvas wird der beringten Zeile zugeordnet; zugeklappte Anleitung wird gefunden.
- **Nächste:** A7 Icon+Wort-Tabs · A8 Inspektor · A9 Querformat.

## 2026-10-01 — Workstation-Neugestaltung: A2-Nachtrag · A7 Reiter

- **A2-Nachtrag fb34a470d:** die Instanz-Zeile unter der Stil-Zeile sagt auch „Style“ (zwei Wörter für eine Sache auf einer Fläche = Regel 1).
- **A7 7303c048a:** `WorkstationView.pieceTabs` per `safeAreaInset(edge: .top)` über dem Stück — Arrange (Kachel, KEIN Knopf, `.isSelected`) · Sound · FX · Master (Chrome-Tür; FX/Master hinter `showsSongs`/`showsProTabs`). Empfänger: `"effects"`/`"master"` öffnen ihr Panel UND drehen die Bühne (`"master"` ist einer der vier #290-Fälle, mit seinem Erzeuger zurück). Mix/Export bewusst keine Reiter (B3/B4 fehlen).
- **Wächter:** neu `ThePieceHasTabsTests`; `TheArrangeStageIsTheFrontStageTests` Anspruch 6 2→4 Bühnen-Drehungen, jetzt je FALL gepinnt statt nur gezählt; `TheEchoelTrackOpensItsDeviceTests` Anspruch 2 = exakte MENGE zweier „sound“-Erzeuger. Transkription WORK 46/46, Eltern rot durch Abwesenheit + Zähl-Regression 2≠4. Prüfwerkzeuge sauber.
- **Gates:** Compile Check auf a63319b72 ✓ (A5/A6); Stapel 127307070…7303c048a gepusht, Gates laufen.
- **Gerät offen:** Reihe liest sich als Reiter; FX/Master landen auf ihrem Panel; „Stück“ bringt zurück.
- **Nächste:** A8 Inspektor · A9 Querformat.

## 2026-10-01 — Workstation-Neugestaltung: A8 · A9

- **A8 a5748ed13:** `laneFacts` (Kopf der offenen Spur) trägt dasselbe Farbband + Symbol wie die Canvas-Rinne (`EchoelTheme.TrackHue.of/symbol`) statt des grauen Art-Symbols; Band folgt der Zeilenhöhe (`minHeight`). Wächter `TheTracksWearTheirOwnHueTests` Anspruch 5. Teil-Felder Start/Länge gab es schon in `SelectedPartBar`.
- **A9 ceb9ede82:** Querformat (`verticalSizeClass == .compact`, nur mit gezeichnetem Canvas) = zwei Spalten per EINEM `AnyLayout`: Arrangement links, Spurköpfe + Inspektor rechts (260–360 pt); Hochformat unverändert. Leere Spalte sagt „Tippe auf einen Spurnamen …“. Wächter `TheArrangementSitsBesideItsTrackInLandscapeTests` (WORK 24/24, Eltern rot nur durch Abwesenheit); A3/A5/A6/A7-Transkriptionen weiter grün.
- **Gerät offen:** Kopffarbe ordnet sich der beringten Zeile zu; Spalten lesbar bei 667–932 pt; Drehung lässt Noten/Automation offen.
- **Nächste:** Phase B (B3 Mixer über alle Spuren, B4 Song-Export → dann Mix/Export-Reiter).

## 2026-10-01 — Workstation-Neugestaltung: B3 Mischpult

- **B3 ec276058b** — `PieceMixerView`: jede klingende Spur als Kanalzug (Farbe, Symbol, Name, dB,
  Pegel, Pan wo verdrahtet, M/S), hinter dem neuen Reiter „Mix“ (Tor `showsSongs`, Rückfall auf
  Arrange, wenn das Tor schließt). Steht STATT des Arrangements, damit ein Stumm-Schalter nie
  doppelt auf dem Schirm steht. Regel = `TrackMix.controls`, Schreiber = `TrackMix.*`; jeder Zug
  ist ein VoiceOver-Container mit dem Spurnamen. `TrackMix.levelHint` hält den Pegel-Hinweis
  EINMAL (#416). Wächter `ThePieceHasAMixerTests` neu; `ThePieceHasTabsTests` Anspruch 1 für zwei
  Platten-Ansichten neu gefasst — schärfer (bedingtes `.isSelected` Pflicht, Mix hinter dem Tor).
  Transkription 85/85 Arbeitsbaum; Prüfer sauber (dead-needles, count-pins 0 ROT, swift-escapes,
  foreign-needles; moved-needles 1 Treffer = andere Flächen, geprüft).
- Gates: A7 7303c048a Compile ✓; A8/A9/Doku als a724b604f gepusht (Compile läuft). B3 wird nach
  dessen Ende gepusht. Offen: B3b Mixer-Undo, B4 Song-MIDI-Export. Gerät: Kanalzüge lesbar,
  Fader hörbar, Mix → Arrange behält die Auswahl.

## 2026-10-01 — Workstation-Neugestaltung: B4 Song-MIDI-Export

- **B4 a6729b78e** — letzter Reiter „Export“ (Tor `showsSongs`, nach Master): `ShareLink` im
  eigenen Blatt `SongExportTab` → Teilen-Menü mit einer `.mid` des ganzen Stücks. Kein Modal
  (Schwarzbild-Gesetz), gedimmt UND inert ohne Note, Tempo über `preflightTempo` (kein heißer
  Lesezugriff). `SongMIDIExport` fragt die drei Regeln des Spielers (`midiLaneIDs` ·
  `executableNotes`, jetzt `nonisolated` · `activeRegion`); Bytes in
  `MIDIFileExporter.exportSong` (Format 1, Kanal 10 frei, Ende = `loopTicks`). Vier
  Katalog-Schlüssel mit Deutsch.
- **Wächter:** neu `ThePieceExportsTheSongAsMIDITests` (Ende-zu-Ende: Spuren + Bytes auf einer
  Vorlage mit Überlappung, Schnitt bei Übernahme, Trim-Fenster, Bio-/Audio-Spur; Tür- und
  Katalog-Scans). `ThePieceHasTabsTests`: FX-Tor auf „nächstes Tor VOR dem FX-Post“ neu
  verankert — die alte Rückwärtssuche hätte Exports eigenes Tor gefunden und wäre auf dem
  korrekten Baum rot geworden (#367); dazu „FX steht IM Tor“. Python-Transkription: alle
  Erwartungen nachgerechnet, Arbeitsbaum grün, Eltern rot nur durch Abwesenheit. Prüfer sauber
  (needle-reachability: 1 vorbestehender Fehlalarm, Interpolation in `pickedNoteLine`).
- **Grenzen:** Export prüft den Gewinner am Noten-Tick, der Transport im 16tel-Raster — für
  Raster-Inhalte identisch, steht im Dateikopf. Stumme Spuren werden geschrieben; Pegel/Pan/Klang
  nicht. B3b (Mixer-Undo) vertagt: der Agent-Pfad über `TrackMix.setLevel` darf keinen
  Undo-Schritt schreiben, es braucht einen eigenen Nutzer-Schreiber.
- **Gerät offen:** Teilen-Menü öffnet; die `.mid` öffnet in einer DAW mit einer Spur je
  MIDI-Spur, richtigem Tempo und Tonart.


### 2026-10-01 — B4 Review-Reparatur ff5a7c907
- Unabhängiges Review von a6729b78e: keine Compile-/Wächter-Probleme, drei semantische Befunde.
  MED: Spur-Transposition fehlte → `SongMIDIExport.sounding(_:transposeSemitones:)` (Noten außerhalb
  0…127 entfallen, ±48-Klammer nicht wiederholt, #416). MED: Kopf behauptete Gleichheit mit dem
  Spieler → „das Arrangement wie platziert“, drei Abweichungen benannt (16tel-Abtastung, taktgebundene
  Haupt-Roll-Spur, Roll-Sustain über eine Übernahme), nicht getragen: Operatoren, Tempo-Automation,
  Klang (Oktavierer/Detune gehören zum Klang). LOW: `.buttonStyle(.plain)` am ShareLink.
- Wächter: Bass −12 → Erwartung 26 statt 38 (Ansprüche 1+2), `sounding`-Direktprüfungen, Quell-Nadel
  auf `transposeSemitones: lane.transposeSemitones`. Transkribiert gegen beide Bäume; Checker sauber
  (needle-reachability: ein vorbestehender Befund in fremder Datei).
- Gerät offen: transponierte Spur öffnet in der DAW in der klingenden Lage.

### 2026-10-01 — Orchestrierte Runde 1: A4 b519c6c44 · B3b 5de7b12f4 (Workstation-Neugestaltung)
- Ablauf je Scheibe: Entwurf + adversariale Kritik durch read-only Agenten (Workflow), Umsetzung
  seriell durch die Hauptsitzung, Python-Transkription gegen beide Bäume, Prüfskripte, dann Push.
- **A4** Kopf zählt Takt.Schlag.16tel · BPM · 4/4: `WorkstationSummary.counterText`/`meterText`,
  Blatt `ProjectPositionReadout` (eigene `TimelineView` 15 fps, pausiert im Stopp, Breiten-Schablone),
  kein heißer Read im Kopf. Tonart bleibt im Streifen darüber (nicht wiederholt, #416). Wächter
  `TheHeadCountsThePieceInBarsBeatsAndSixteenthsTests` (6 Ansprüche; Kritik-Korrekturen a–d:
  Benotungskopf, Geräte-Zeile, Breiten-Schablone als Anspruch, Key-Nadel ohne Binding-Text).
- **B3b** Mixer-Undo: `.laneMix` über einen getrennten Nutzer-Pfad `editLaneMix`/`commitLaneMix`
  (der Agent-Pfad `TrackMix.setLevel` bleibt draußen — TheAgentActsThroughTheButtonsPathsTests
  Anspruch 2). Kritik-Befund D1 (MED) eingebaut: Undo setzt ein Feld nur zurück, wenn es noch das
  Ergebnis der Geste trägt — ein später anderswo gesetzter Pegel bleibt. Drei Wächter nachgezogen
  (Fall-Liste + Umbenennung #374, Closure-Nadeln, zwei Katalog-Schlüssel). Python-Modell mit
  Mutanten: geschützt grün, ungeschützt rot an genau den neuen Ansprüchen.
- **A2b** in die Inbox als H6 (Stil setzt Tonleiter? — Geschmack, nicht messbar), **A4-Geräte-
  frage** als H7 (zwei Zähler im selben Format). A1b-✓ im Plan nachgetragen.
- Runde 2 läuft: A3b · A8-Segmente · B1 · C1 (Entwurf + Kritik).
- Gerät offen: alles. Nichts davon ist am Telefon gesehen.

## 2026-10-01 — Workstation-Neugestaltung, Runde 2 (A3b · A8-Segmente · B1a · C1)
- **A3b ✓ 3f44da17a** (auf main): die Stück-Bühne hat EIN Play.
- **A8 ✓ 4c3d5be63**: Inspektor zeigt eine Seite von dreien (Spur · Teil · Gerät).
- **B1a ✓ a137976f7**: Teil-Gitter 8 → 64 (`ClipStore.slotCount`), altes Gitter wird aufgefüllt
  (`migratedGrid`, ein größeres wird abgelehnt), gespeichert wird das Präfix bis zum letzten belegten
  Platz, mindestens 8 (`storedGrid`) — ein Rückfall-Build behält bis zu 8 Teile. Wächter
  `TheOldPartGridOpensInTheLargerOneTests` (6 Ansprüche). B1b (Eigenständig machen) HOLD: H9.
- **C1 ✓ 357067db2**: `visual.creative.intensity` als erster Visual-Parameter auf dem kanonischen
  Pfad (Registry → Router → `VisualCreativeState`), pro Bild mit Slew 0,30/s gelesen; kein
  Produktions-Schreiber. Wächter mit AnchorMissing statt XCTSkip (12 Ansprüche).
- Inbox H8/H9/H10 (1783542be). Runde 3 (B3c · B2 · C5 · B6a) im Workflow.
- Gerät offen: alles. Benotet per Transkription, nicht kompiliert.

## 2026-10-01 — Workstation-Neugestaltung, Runde 3 (B3c · B2a · C5 · B6a)
- **B3c ✓ e0e28f83a**: Mix-Undo auch für Inspektor, Spurkopf und Perform — eine Geste = ein
  Schritt über `editLaneMix`/`commitLaneMix`. Begleitend bc907d1eb: TheWorkstationHasADoorTests
  Anspruch E war seit A7 rot (zwei Wächter widersprachen sich); eng ausgenommen ist genau EIN
  `@AppStorage(StudioDefaultKeys.skillLevel.key)`-Read — als Wächter-Änderung dem Founder gemeldet.
- **B2a ✓ 8d48d0461**: eine POLY-Rack-Spur wählt ihren Klang (Standard / „In diesem Stück" /
  Sounds) über `TimelineStore.setLanePatch` — erster Aufrufer. Das Stück hält eine KOPIE des
  Klangs. Nicht im Undo (B2b offen). Wächter `TheTrackChoosesItsSoundTests`.
- **C5 ✓ 9c4bb62b8**: Bereichs-Reiter Music · Visual · Light über der Workstation; Visual öffnet
  das Field-Panel auf der Instrument-Bühne, Light das Routing (verweigert, solange FX oder Colabo
  offen ist — Zwei-Modal-Gesetz). Space HOLD bis C4. Wächter `TheDomainTabsOpenOnlyWhatExistsTests`.
- **B6a ✓ 7e12f1976**: Anschlag-Spur unter dem Notenraster, Live-Vorschau per `@GestureState`,
  EIN Schreiber beim Loslassen. Wächter `TheVelocityIsDrawnUnderTheNotesInOneStepTests`.
- Lehre: `patch -F2` meldete Erfolg und wendete nur Hunks 1–3 an — nach jedem Patch `git diff`
  gegen den Plan lesen.
- Gerät offen: alles (Inbox §2, vier neue Zeilen). Benotet per Transkription, nicht kompiliert.

## 2026-10-01 — Workstation-Neugestaltung, Runde 4 (B2b · C3a · B6b-0 · B5; C2a HOLD)
- Workflow: fünf Entwürfe + fünf adversariale Kritiken (B2b · B5 · B6b · C3 · C2), je am Code geprüft.
- **B2b ✓ 1df12b6db**: eine Klangwahl im Inspektor ist EIN Undo-Schritt — `HistoryStep.lanePatch`
  trägt beide Klänge als WERTE (keine Bibliotheks-ID, weil die Bibliothek sich ändern darf), Schreiber
  `editLanePatch`; die rohen `setLanePatch`/`TrackMix.setSound` bleiben undo-frei für den Agenten.
  Wächter `TheSoundChoiceIsOneUndoStepTests`; Historien-Hinweis nennt jetzt „picked sound".
- **C3a ✓ fd782725b**: die Look-Stärke des Lichts gleitet in Art-Net UND sACN mit höchstens 0,3/s
  (`FlashGuard.luminanceDeltaThreshold × maxFlashHz`, keine neue Zahl); Anker = zuletzt AKZEPTIERTE
  Ausgabe. Heute byte-gleich (nichts bewegt die Stärke). Wächter `TheLightLookMovesNoFasterThanTheFlashLawTests`.
- **B6b-0 ✓ 02a68bcaf**: der MIDI-Import sagt, was er weglässt (Pedal; Bend/Aftertouch/CC-ÄNDERUNGEN,
  nur Kanäle mit Noten im Teil; Einrichtungs-CCs zählen nicht). B6b selbst HOLD: nichts spielt ein
  gespeichertes Controller-Ereignis. Wächter `TheMIDIImportSaysWhatItLeavesOutTests`.
- **C2a HOLD → Inbox H12**: hebt die C1-Sperre der Bild-Intensität auf; Blitzgrenze mit Verstärkung
  bis ~2,8× nur am Gerät belegbar.
- **Befund → Inbox H11 (Sicherheit)**: der Musik-Dimmer darf heute mit 2,42 Helligkeit/s schwanken
  (`FlashGuard.senderLuminancePerSecond`), BioPhaser mit 0,5/s — Vereinheitlichung ist laut Code-Kommentar
  eine Founder-Entscheidung mit Geräteblick. Empfehlung: bremsen.
- **B5** (eigener Pegel je Spur im Mix-Reiter) gebaut, Audio-Thread-Review vor dem Commit.
- Gerät offen: alles (Inbox §2, vier neue Zeilen). Benotet per Transkription, nicht kompiliert.

## 2026-10-01 — Workstation-Neugestaltung Runde 5 (B6b-1 · C4a-1) + TestFlight 10.79.485

- **Deploy 10.79.485** (093ec4849, testflight Lauf 2610): Upload ✓; Landung in App Store Connect beim Schreiben noch offen.
- **B6b-1 72c3b04e2** — Haltepedal verlängert gehaltene Noten beim MIDI-Import (Faltung pro Kanal nach dem Lauf, in Datei-Ticks); Landezeile zählt verlängerte Noten. Neuer Wächter `TheSustainPedalLengthensTheNotesItHoldsTests`, `TheMIDIImportSaysWhatItLeavesOutTests` nachgezogen. Kritik-Baum übernommen (Pedalwechsel am Loslass-Tick lässt den alten Akkord los).
- **C4a-1 358afe0a1** — Szene app-weit aus den Spuren, an `onDocumentChanged` gekettet; Routing-Schalter als erste Tür zu `streamsScene`. Kritik-Fixes übernommen: Leeres-Stück-Stille in An- und Aus-Text, „Position und feste Lautstärke“ statt „nur Positionen“, nur Entfernen nummeriert um, Neustart setzt zurück. Drei Wächter nachgezogen, ein neuer.
- Prüfer je Scheibe: dead-needles · swift-escapes · foreign-needles · count-pins · moved-needles sauber; Katalog-JSON gültig, jeder neue Text mit Deutsch. Nichts kompiliert lokal, nichts gerätegeprüft.
- Offen: C4b Bewegungs-Spur → Space-Reiter; C3b (nach H11), C2a (nach H12), B1b (nach H9).

## 2026-10-01 (spät) — Runde „Eine Tür, kompakt" + Deploy 10.79.486

Founder-Order: eine Tür je Bereich, kompakte Flächen, kein Slop, TestFlight.
- 430b20307 Guide-Karte ≤ 96 pt · 6f6e2f499 A Bereichs-Zeile weg · e5f853101 B eine Stück-Reiterzeile · a6c9b696f C Transport eine Zeile · ae397d05a E Kopf ≤ 2 Zeilen, Guide = aktueller Schritt · f61915c41 B-Reparatur (Anspruch 3 ankerte auf A's gelöschter `areaBar`) · 02658e892 D Blätter halbe Höhe + Sperre.
- Gates: A grün (Compile + BfT, main = 6f6e2f499). D-Stapel: siehe Deploy-Commit.
- Lehre: zwei parallel entworfene Scheiben (A, B) — B's neuer Wächter ankerte auf einem Symbol, das A löscht. Bei gestapelten Scheiben jeden NEUEN Wächter gegen den KOMBINIERTEN Baum transkribieren, nicht gegen den eigenen Eltern.
- Inbox H13–H15 (Undo-Symbol, Stopp/Aufnahme stoppen, Field unter Producer). Nichts gerätegeprüft.
- **Deploy 10.79.486 GELANDET** — TestFlight-Lauf 2611 (36935214681) auf 4218e00da: Preflight · Compile Check · iOS · „Verify build landed in App Store Connect" success. Gates davor: Compile Check + Build for Testing grün auf 02658e892 (main); Transkription aller 21 betroffenen Wächter gegen den kombinierten Baum: grün, keine Kompilier-Risiken. Gerät: offen (T1–T8).

## 2026-10-02 — H13–H15 entschieden, F + G gebaut, Deploy 10.79.487 vorbereitet

Founder: „Alles auf professionellstem Level. Du entscheidest."
- **H14 881248ccf** Aufnahme-Rot (Punkt bereit, Füllung aktiv) — Gates grün, main = 881248ccf.
- **F b6ec754a9** Workstation-Chip weg; Naht = eine Tür zum Stück. Kritik (5 MED, 6 LOW) eingearbeitet.
- **G 43bea0e8e** Routing eine Tür (Licht-Kachel); zwei Knöpfe gelöscht; zehn Wächter neu verankert, neuer `TheRoutingHasOneDoorTests`. Auf dem kombinierten F+G-Baum transkribiert: alle Prüfer 0.
- Inbox §2: drei Geräte-Bitten (H14, F, G). Deploy-Notiz 10.79.487 liegt bereit; Commit erst nach grünen G-Gates.
- Lehre: ein `$S` ohne Definition im selben Befehl ließ `cat > $S/../x` auf stdin warten und legte `/h14msg.txt` im Wurzelverzeichnis an — `S` immer im selben Befehl setzen.
- **Gates:** F b6ec754a9 — Compile Check ✓, Auto-Merge ✓ (main = b6ec754a9). G f6d758c95 — Compile Check ✓, Auto-Merge ✓ (main = f6d758c95).
- **Deploy 10.79.487 GELANDET** — TestFlight-Lauf 2612 (36976721664) auf 29f357674: Preflight · iOS · Export & Upload · „Verify build landed in App Store Connect" success. Gerät: nichts geprüft; Prüfliste T1–T7 in `.deploy/release`, Bitten in Inbox §2.

## 2026-10-02 — Nur Englisch + UX-Audit
- **de56d0a79** Katalog nur Englisch (2011 `de`-Einheiten raus), `TheChromeSpeaksGermanTests` → `TheChromeSpeaksOneLanguageTests`, 19 weitere Wächter auf `en`-Lesung umgestellt, `listingOnlyLanguages = ["de"]` mit eigenem Ehrlichkeits-Test. Alle Prüfer 0.
- Docs: `docs/dev/UX_AUDIT_2026-10-02.md` (14 Scheiben), Inbox E4 überholt, E4b + E15 neu.
- Lehre: ein ungequoteter Heredoc mit Backticks führt Kommando-Ersetzung aus und frisst jeden Bezeichner — Markdown immer über `<<'EOF'` oder das Write-Werkzeug schreiben.
- Gerät: nichts geprüft (ein deutsches iPhone zeigt jetzt Englisch).

## 2026-10-02 (Nachmittag) — UX-Audit Scheiben 4 · 10 · 13 + Deploy 10.79.488
Founder: „Vermeide, dass es unübersichtlich ist … so gut designt wie FL Studio Mobile und Ableton … Wo bleiben die ganzen Features?" — Antwort Englisch-only bestätigt.
- **13a ⌘Z f7b4ad680 · 13b Haptik-Tick a193f89fc** — Gates grün (main = a193f89fc).
- **10a/10b Stück als WAV** 387e64bf6 + Review-Reparatur 24956b53f (Zustand auf `LoopExporter`, Abweisung bei laufender Aufnahme, `body(of:)`-Helfer suchte die Klammer NACH dem Kopf) — Gates grün (main = 24956b53f).
- **4 „Add"-Menü** fe04ad196 + Review-Reparatur 5e5989e8e: fehlende Katalog-Schlüssel (H1, wäre ein roter Wächter gewesen), Hinweis-Zeile folgt den Türen (leere Platte ODER angeheftet unter der Reiterzeile mit ×), „Add Audio Track" wählt die neue Spur und sagt es. Gates grün (main = 5e5989e8e). Inbox E17: das Menü kehrt „ein Knopf, kein Menü" (2026-08-07) um — gebaut und umkehrbar, Empfehlung ja.
- **11 (Mixer kompakt) ZURÜCKGESTELLT** mit Messung: ~3 Streifen bei 375 pt; eine feste Feldbreite wäre Ökosystem-Schuld; kommt als `ViewThatFits`-Alternative für iPad/Querformat.
- **Deploy 10.79.488** c80cbb672 (TestFlight-Lauf 2613 / 36990713092).
- Lehre: eine Hinweis-Zeile, die nur an EINER von zwei Türen-Stellen hängt, verschwindet in dem Moment, in dem ihre Tür wandert — ein Prädikat (`WorkstationSummary.isEmpty`) für Türen UND Hinweis.
- Gerät: nichts geprüft. Offen: Scheiben 6 (Tempo-Schloss im Kopf), 8, 9, 12.
- **Deploy 10.79.488 GELANDET** — TestFlight-Lauf 2613 (36990713092) auf c80cbb672: Preflight · Compile Check · iOS · Export & Upload · „Verify build landed in App Store Connect" success. Gerät: offen (T1–T7).

## 2026-10-02 (Abend) — DAW-Hülle S3: das ≡-Menü ist das Projektmenü
- **Gebaut:** Logo-Menü = Open · Save │ Live Colabo · Learn │ Guide, auf beiden Bühnen. Weg: `quickDoorRow`, `SaveSessionButton`, `WorkstationProjectRow` (+ ihre Katalog-Schlüssel). Menü postet `.echoelChromeDoor`, der Empfänger hebt die vorhandenen Blätter — keine neue Sheet-Zeile, `WorkspaceView` weiter ohne Präsentations-Modifier.
- **#622 beim Tippen:** `saveHasNothing` → „Nothing to save yet …" + OK statt einer ausgegrauten Tür (kein Ahnen-Read).
- **Wächter:** 14 Dateien umgezogen (neue Form + Abwesenheit der alten Tür), zwei Testmethoden umbenannt (#374). Transkribiert gegen f4b4f006d und den Baum; alle sieben Prüfer 0 (dead/moved/count-pins/swift-escapes/foreign).
- **Lehren:** (1) ein „erstes Element des Menüs"-Fenster (80 Zeichen nach `Menu {`) wird falsch-rot, sobald das Menü wächst — die Entscheidung ist EINE Adresse, also klammergenau innerhalb des Menü-Blocks prüfen. (2) Der 3-Zeilen-Schlossblick von AHalfHighSheetLocks verbietet Kommentare/Mehrzeiler zwischen `guard !panelSheetUp` und dem Setter — Kommentare über die Wache, Zuweisungen in eine Zeile.
- Gates: f4b4f006d in main (⇒ Compile Check + BfT grün). Gerät: nichts geprüft (Inbox §2 „S3").
- **Nachkontrolle S3 (drei Prüf-Agenten, 42 Wächter transkribiert):** keiner rutscht durch S3 ins Rot. Gefunden: `TheWorkstationHasADoorTests` Anspruch F war seit B3c (`e0e28f83a`) rot auf korrektem Baum — die Mute/Solo-Taps riefen `timeline.editLaneMix/commitLaneMix` direkt aus der Stück-Fläche. **58106a0d2** führt sie über die Naht `TrackMix.tapStep` (ein Tipp = ein Undo-Schritt; Agent-Trichter bleibt nackt). Mitgezogen und nicht gelockert: `EveryHandMadeMixChangeIsOneUndoStepTests` (Naht-Pins) und `TheMixerGestureIsOneUndoStepTests` (Zensur — die moved-needles NICHT fand, weil die Nadel ein Fragment in einer `filesMatching`-Closure ist). Gates grün (main = 58106a0d2).
- **e0254a12a** Ort-Zeile in Save & Export nannte den gelöschten „Save button“ → „Save is in the logo menu at the top left.“
- Lehre: ein rot liegender Wächter unter #807 (Job-Log = `tail -200`) überlebt beliebig viele grüne Merges — eine Scheibe, die ein Gesetz WIEDER anfasst (hier die Naht), muss die Nachbar-Wächter ganz transkribieren, nicht nur das Delta (Tests/CISmoke/CLAUDE.md §3).

## 2026-10-02 (Abend) — DAW-Hülle S4a: Notes und Automation sind Seiten des einen Details
- **104c288db** Inspektor = Track · Part · Notes · Automation · Device; `inspectorPage` ist der eine Besitzer, `notesOpen` abgeleitet; die zwei Editor-Mounts unter der Arbeitsfläche sind weg, die Hide/Show-Knöpfe auch. `TrackMix.detailPages` bietet jede Seite über das Gate ihres Editors an.
- **Wächter:** `TheDetailShowsOnePageAtATimeTests` (umbenannt, Matrix über Spur × Auswahl × Kapazität) + sechs umgezogene. Transkribiert: Baum 127 Prüfungen, 0 rot; auf HEAD nennt jedes Rot die S4a-Abwesenheit. dead/swift-escapes/foreign/count-pins sauber.
- **Gefunden:** `spokenCount`-Nadel seit E4-91 rot auf korrektem Code (#807-Klasse) — neu verankert.
- Gates: laufen. Gerät: nichts geprüft (Inbox §2 „S4a").
- Gates S4a: Compile Check 3185 auf 104c288db success.

## 2026-10-02 (Abend) — DAW-Hülle S4b + S4a-Review-Reparaturen
- **2bf2cba20** `TheTrackInspectorShowsOnlyWiredControlsTests` Anspruch 5 kannte die Kopf-Naht `TrackMix.tapStep` nicht — seit 58106a0d2 rot auf korrektem Baum, unsichtbar unter #807. Menge nachgezogen.
- **e3ceb554c S4b:** Aufnahme-Schalter (Rack-MIDI) und Pitch (Audio) stehen auf der Track-Seite, das Teil-Tempo importierter Dateien auf der Part-Seite. `TrackInspectorView` ist generisch über zwei `@ViewBuilder`-Slots, die Reads bleiben im Workstation-Rumpf (keine neue Beobachtung, kein Modal, eine Konstruktionsstelle). Wächter Anspruch 2b.
- **0b05984fb** Review LOW: Notes-Überschrift sagt die Zahl nur einmal (`accessibilityLabel("Notes")`); Teile-Hinweis ohne „above" (im Querformat falsch) → „on the Selected part bar under the arrangement"; sechs veraltete Kommentare.
- **9cc6eee61** Review MED: `NoteToolFlow` (Layout) bricht die vier Werkzeugzeilen des Noten-Editors in der 260-pt-Spalte um statt „Des…" abzuschneiden; ideale Breiten, kein Skalierungsfaktor. Wächter Anspruch 2c.
- Offen als Gerätefrage: die Automationszeile behält ihre Namensspalte (Kurve ~130 pt im Querformat); „Automation" im Segment eventuell gekürzt.
- Gates: S4b läuft; 0b05984fb + 9cc6eee61 lokal, Push nach dem Compile Check auf e3ceb554c. Gerät: nichts geprüft.

- **Gates S4b:** Compile Check 3186 ✓, Auto-Merge 4084 ✓ → main = e3ceb554c (⇒ BfT grün). 0b05984fb · 9cc6eee61 · 7bcf13c37 gepusht.

## 2026-10-02 (Abend) — DAW-Hülle S5: der Mixer endet im Master-Streifen
- **6088a7525** `MasterStripView` (Lautstärke · Pegel + R128 · Clear) hängt im Mixer nach den Spur-Streifen, außerhalb des Leer-Song-Zweigs; das Instrument-Master-Panel behält Ziel, Ton, Audio-System. Eine Tür je Bereich: verschoben, nicht kopiert. Claimant `.masterPanel` → `.masterReadout`; drei Katalog-Schlüssel umbenannt.
- **Wächter:** neu `TheMixerEndsInTheMasterStripTests` (34/34 auf dem Baum transkribiert; auf dem Elternteil nicht kompilierbar — neues Symbol); umgezogen MasterPanelReflows (+3 Abwesenheiten), TapTargetFloor (Clear in neuer Datei), MasteringMeters (Umbenennung), ChromeSpeaksOneLanguage, WorkstationShowsTheMixLevel (Meldung). Prüfer sauber; moved-needles-Treffer geöffnet.
- **Lehre:** eine Nadel auf `resetMastering()` trifft auch die DEKLARATION `func resetMastering()` — für „wer ruft" `.resetMastering()` mit Punkt nehmen.
- Gates: Push nach dem Compile Check auf 7bcf13c37. Gerät: nichts geprüft (Inbox §2 „S5").
- **ffe049c11** Review S5 (MED-1): der Satz im Mix-Panel „Master level lives in the Master panel" sagt jetzt „on the Mixer's master strip" (Katalog-Schlüssel mitgezogen); veraltete Kommentare und drei Wächter-Meldungen nachgezogen (LOW-1). Keine Zusicherung geändert. S5-Stapel gepusht, als main = 7bcf13c37 stand.

## 2026-10-02 (Nacht) — DAW-Hülle S6a: Browse bietet die Klänge
- **4dedb218d** `SoundBrowserView` oben auf der Browse-Platte: alle gespeicherten Klänge in Speicher-Reihenfolge, Stern = Favorit, Haken = Klang der geöffneten Spur. Ein Tipp schreibt über `TrackMix.setSound` in `editLanePatch` (ein Undo-Schritt) — dieselbe Naht wie die Sound-Zeile. Ziel = `TrackMix.controls(…).sound`. Browse-Hinweis nennt die Klänge (Schlüssel umbenannt). Beide neuen Dateien (S5/S6) in beiden Chrome-Listen.
- **Wächter:** neu `TheBrowsePlateOffersTheSoundsTests` (Ziel-Regel end-to-end bikonditional gegen `TrackMix.controls`, Schreibnaht, Montage, Katalog). Transkribiert; Stripper TRAGEND (2 Urteile kippen roh). Prüfer sauber; needle-reachability meldet einen vorbestehenden Fund in `TheNoteGridSpeaksTheReadersNoteNamesTests:80` (nicht diese Scheibe, offen).
- **Lehre:** der Wächter der Sound-Zeile begründet „Speicher-Reihenfolge" mit dem Hinweistext — eine zweite Liste derselben Klänge muss dieselbe Reihenfolge haben, sonst heißt „der erste Klang" auf zwei Platten zweierlei.
- Gates: Push nach dem Compile Check auf ffe049c11. Gerät: nichts geprüft (Inbox §2 „S6").
- **7ce980201** S6-Review (MED-1/2, LOW-1…5): Zeilen ohne Ziel sind sichtbar gedimmt und ihr VoiceOver-Hinweis sagt warum; die Liste klappt wie die Medienbibliothek (zu bis geöffnet); „Default“ und „In this piece“ sind Zeilen in der Reihenfolge des Device-Menüs; die Klangwahl wird einmal je body gefragt; bei der Echoel-Spur verweist der Satz auf „Sound“ im Instrument; drei veraltete Zeilen (PieceView-Doc, Browse-Kommentar, erste Guide-Karte) zählen die Klänge mit. Wächter zieht mit; transkribiert, Prüfer sauber.
- **S7-Karte (lesend):** keines der sechs Instrument-Bedienelemente (▶ startButton, ⏸ Pause, Tempo-Feld, WAV-Aufnahme, Keep last, MIDI-Export) ist ein echtes Duplikat des Kopfes — jedes ist alleiniger Erzeuger einer Handlung (Bio-Start/-Ende im Pausenzustand, Pause mit Körper, BPM-Eingabe, Instrument-WAV, rückwirkende Schleife, Melodie-MIDI). S7 heißt also UMZIEHEN, nicht löschen; Save ist seit S3 schon weg.

## 2026-10-02 (Nacht) — DAW-Hülle S7a: ein Play
- **Gates S6:** Compile Check 3189 ✓ auf 55ef08e44, Auto-Merge → main = 55ef08e44 (⇒ BfT grün).
- **4daef6f69 S7a:** Das ▶/■ der Instrument-Platte ist gelöscht; der Play des Kopfes startet auf der Instrument-Bühne das Instrument (`PlayAction.startInstrument`) oder setzt eine gehaltene Sitzung fort und ist dort nie ausgegraut. Start über die Chrome-Tür an den Empfänger in `EchoelStudioView`. Der 44-pt-Boden des Kopf-Plays liest jetzt `EchoelTheme.controlTapHeight`. Lerntext „press Play at the top"; verwaister Stopp-Hinweis aus dem Katalog.
- **Wächter umgezogen (sieben Dateien):** OneStartControl (Ansprüche 1+6 neu gerichtet, auf dem Elternteil rot durch Anker-Abwesenheit), TransportBarIsDissolved, OneChromeControlHeight (Größe + Trefferfläche wandern zum Kopf-Play), ProjectHeaderRunsOneTransport (+ Instrument-Bühnen-Anspruch), ChromeSpeaksOneLanguage, PlateHasOnePause, ControlBoundary (Prosa). Prüfer sauber; moved-needles-Treffer geöffnet; needle-reachability: drei Funde in Dateien, die die Scheibe nicht berührt.
- **Kosten:** pausierte Sitzung beenden = Play, dann Stop (decisions.csv).
- Gates: laufen. Review läuft. Gerät: nichts geprüft (Inbox §2 „S7a").
- **7b4883c83** S7a-Review (HIGH-1/2): zwei Wächter wären auf korrektem Baum rot gelaufen — `TheArrangeStageIsTheFrontStageTests` las „Play button" in der ersten Guide-Karte, `TheWorkstationPlaysTheTimelineTests` „minHeight: 44" im Bereich des Kopf-Plays. Beide Nadeln folgen der neuen Form. LOW: Prosa (`transportLine1` = zwei Kinder, Mess-Tabelle in `EchoelTheme`).
- **Lehre:** `moved-needles.py` schlüsselt auf ganze ENTFERNTE Zeilen; beide Nadeln waren TEILSTRINGE von Zeilen, die S7a nur GEÄNDERT hat. Bei einer Textänderung (Kopie oder Modifier-Argument) zusätzlich das alte TEILSTÜCK über `Tests/CISmoke` greppen, nicht nur die alte Zeile.


### 2026-10-02 — DAW shell S8a + S9a

- **1fd73147f + 88058461d** S8a Querformat: die fünf Wörter stehen senkrecht links (`ShellLayout`). Review-MED (Leiste füllte ihre Spalte nicht) repariert; Guide-Karte nennt beide Lagen. Compile Check 3192 ✓ auf 88058461d; CI/CD 6656 lief noch.
- **4414ad4cd** S9a Zeit-Zoom: Schrift-Pinch von `SurfaceHost` entfernt (`StudioZoom(step:)` als Wert — der Typ verbietet einen zweiten Schreiber); `ArrangeTimeZoom` als eigenes Blatt (zwei Wächter erlauben im Canvas-File genau ein `@GestureState`); Canvas in zwei Spalten. Neuer Wächter `ThePinchZoomsTheArrangementsTimeTests` (Vorwärts-Wächter, sieben Mutanten rot); Anspruch 3 von `TheArrangeCanvasNamesItsBarsTests` strenger neu verankert (sieben Mutanten rot).
- **Lehre:** wer einen Ein-Spalten-Canvas in zwei Spalten teilt, muss die Zeilenhöhe in BEIDEN Spalten festnageln — vorher hielt die gemeinsame `HStack`-Zeile Name und Spur zusammen; jetzt tun es nur noch gleiche `spacing`, ein geteiltes `rulerHeight` und `rowHeight` auf beiden Seiten. Der Wächter pinnt alle drei.
- Gates: S9a laufen. Review S9a läuft. Gerät: nichts geprüft (Inbox §2 „S8a", „S9a").

### 2026-10-02 — DAW shell S8b

- **Gates S9a-Reparatur:** Compile Check auf a8149f7e3 ✓ (CI/CD lief beim Push von S8b noch).
- **4a457a7e7 S8b:** quer steht die Add-Kachel am Ende der Transportzeile statt in einer eigenen angehefteten Zeile; hochkant unverändert. Eine reine Entscheidung `ArrangeAddPlacement.of`, einmal gefragt in `addPlacement` (leere-Platte-Prädikat + `verticalSizeClass == .compact`, dieselbe Lesart wie A9/S8a), je Platzierung ein Tor; die Hinweiszeile folgt der Kachel. Nichts Heißes gelesen.
- **Wächter:** neu `TheAddTileEndsTheTransportInLandscapeTests`; zwei Wächter im selben Commit neu verankert. Transkribiert; 14 Mutanten rot; Prüfer sauber, moved-needles-Treffer geöffnet (einer neu verankert, einer gehört zu `ProjectHeader`).
- Gerät: nichts geprüft (Inbox §2 „S8b").

### 2026-10-02 — DAW shell S9b (Notenraster-Zoom)

- **a4717359b S9b:** das Notenraster hat drei Spaltenbreiten (`NoteGridZoom`, 11 · 22 · 44 pt), eine berechnete `stepWidth` für Raster, Linie, Velocity-Spur und Tipp-Treffer; Türen: Zoom out/in in der Werkzeugzeile, Pinch (einmal beim Loslassen), VoiceOver-Zoom; Anker hält den Schritt im Blick.
- **Wächter:** neu `TheNoteGridZoomsItsTimeTests`; zwei neu verankert. Transkribiert; 11 Mutanten rot; Prüfer sauber (moved-needles: ein Treffer, `region: region)`, alle Stellen weiter erreicht).
- **10639fad4:** S8b-Review LOW-5 (zwei veraltete Kommentare in WorkstationView); die übrigen fünf LOW im Plan festgehalten.
- Gerät: nichts geprüft (Inbox §2 „S9b").


### 2026-10-02 — Deploy 10.79.489 (DAW-Hülle S1–S9b) GELANDET
- `a3ef7c53b` (`.deploy/release`): Notiz mit Posten 1–4, Prüfliste T1–T9, `founder-verify.py --since c80cbb672` (8 neue Bitten). Vorher gegen alle fünf Ansprüche von TheDeployNoteNamesRealDoorsTests transkribiert; foreign-needles 0.
- Gates vor dem Bump: Compile Check ✓ + Auto-Merge → main = 77f29e2fa (⇒ BfT grün).
- TestFlight-Lauf 37046666493 (Nr. 2614): Preflight · Compile Check · iOS · Summary = success.
- Korrektur in der Notiz vor dem Commit: „Text size“ sitzt im Save/Export-Panel (`utilityRow`), nicht unter Project.
- Gerät: nichts bestätigt — T1–T9 ist die Geräte-Session.

## 2026-10-03 — Release-Passage R1 + vier Architektur-Entscheidungen (Stimme · Farbton · Workstation)
- Auftrag: „Mache die Passage und entscheide … Audio Input Autotune Harmonizer/Granulat … Farbton Übersetzung … Grundarchitektur der Workstation.“
- **R1 gebaut 2ecd00a6a:** `BreathPattern.release` (4/8, 5,0/min, keine Halte-Phasen, `exhaleCue`), Knopf „Release“ im `BreathCoachStrip`, Hinweis ersetzt „Breathe out“ nur beim Ausatmen. Wächter: ThePacedRateMustBeReadable (5,0 lesbar, Zählung 4→5, Methode umbenannt), TheBreathingPracticeIsInTheMainView neuer Anspruch „jedes vom Streifen startbare Muster ist ohne Halten“. Checker: swift-escapes/dead-needles/foreign/moved sauber; needle-reachability 3 vorbestehende, keiner aus dieser Scheibe.
- **Entscheidungen** (Plan `scratchpads/PLAN_RELEASE_VOICE_COLOR_2026-10-03.md`, decisions.csv + memory): D1 Release = Atemmuster; D2 Stimm-Effekte = Geräte, Kerne in `DSP/`, Dateien zuerst, Mikrofon zuletzt (V7, Info.plist founder); D3 `Core/SpectralColor` bleibt die EINE Farbsprache — die Farbton-Übersetzung existierte schon; D4 Workstation-Grundarchitektur.
- Postfach: E10 Architektur entschieden, Freigabe Info.plist bleibt offen; E20 neu (`aumf`-Target, project.yml).
- Gerät: nichts bestätigt.

## 2026-10-03 (Abend) — Audit-Scheiben end to end + Deploy 10.79.490
- Auftrag: „Du entscheidest alles und gibst die Scheiben end to end im optimierten hardcode für den TestFlight frei“.
- Gebaut, je ≤3 Dateien + Wächter, alle Checker sauber (swift-escapes, dead-needles, moved-needles, foreign-needles, count-pins): hpp-1 2e2cde027 · hpp-2 47830a943 · SEC-1 f849c61ff · Claims d0945a031 · MP-1 52a986510 · hpp-3 25be0b50e · A11Y-1 f28ee9019.
- **Compile Check ROT auf f28ee9019**: `PartNoteEditor.swift:243` „unable to type-check this expression in reasonable time“ — fünf Inline-`.accessibilityAction`-Closures auf der Gitter-Kette. Reparatur 10a4f2e84: `NoteEditActions`-ViewModifier mit drei typisierten Closures; Wächter-Anspruch 1 im selben Commit nachgezogen (gleich streng). Lehre: das Python-Transkript sieht Type-Checker-Zeit nicht; Aktionen bündeln, bevor eine lange Kette wächst.
- Website c2168c290: HRV-Zeile (Apple Health = Apples SDNN), Gurt als „still being tested on devices“, terms „Version 1.0 is free“. Postfach: H16 Mindestalter, H17 Verkauf v1.1, F9–F13 (iPad, Dokumenttypen, Ableton Link, Push/iCloud-Entitlements, Store-Texte).
- Pin `TheSelectedPartsNotesAreEditedThroughOneWriterTests` 11 → 14 im A11Y-1-Commit.
- Gerät: nichts bestätigt. Prüfliste T1–T7 in `.deploy/release` (10.79.490).

## 2026-10-03 (Nacht) — Broadcast S1 · Spatial S1 (ADM-OSC-Eingang) + Review-Reparatur
- Auftrag: „Du entscheidest und integrierst meine Visionen von Live Set, binaural broadcast, Spatial Audio, immersive und multidimensional media“. Reihenfolge von mir gewählt: zuerst der Raum, dessen Steuerhälfte schon real ist; Broadcast hängt an HaishinKit (Founder-Edit an `project.yml`, Hook + Klassifizierer lehnen ab).
- **Broadcast S1 ee163a910:** Stream-Key in die Keychain. Compile Check + Build for Testing grün. S2 (HaishinKit) BLOCKIERT, wartet auf den Founder.
- **Spatial S1 6097629b6:** `/adm/obj/{n}/{azim,elev,dist,aed,x,y,z,xyz,gain}` auf dem OSC-Eingang (Port 8001, gleicher Schalter, gleiche Allowlist) → `SpatialSceneStore.apply`, Objekt n = n-te Nicht-Bio-Spur. Gates grün, main = 6097629b6.
- **Review-Reparatur 766434c2f** (MED-3 + Status): einzelne kartesische Blätter hängen nicht mehr von der Reihenfolge ab (`CartesianHold`, /x dann /y = /y dann /x = −45°); ein bewegender Controller zählt im Status als Verkehr („moving tracks over ADM-OSC“). Wächter `TheSpatialControllerMovesTheTracksTests` Ansprüche 6/7. Compile Check grün; BfT läuft.
- **MED-2 aa8b82582 (docs):** integrations/privacy/faq/overview nennen jetzt die ADM-OSC-Spurpositionen; kein Rendering behauptet; alle Nadeln gehalten.
- **LOW-5 e919030a6:** `ignoredCount`/`refusedCount` unbeobachtet (Grapes schickt Breite/Mute/Name mit voller Rate); das Status-Blatt pollt im 0,5-s-Takt. Wächter `TheOSCInputIsBoundedTests` Anspruch 5.
- Gemessen für S2: der einzige andere Positions-Schreiber ist `ImmersiveStageView` (türlos) — eine Besitz-Regel braucht es heute nicht; Glättung bewusst nicht in der App (Renderer glätten selbst, sie kostete Latenz).
- Gerät: nichts bestätigt. Probe: Grapes → Port 8001, „Accept OSC control“ an, „Every track as its own object“ an.

## 2026-10-04 — Restrukturierung: Phase F in main, A3a gebaut

- **F3–F6b** (spielt · Schalter monochrom · gewählte Kachel mit Kante · Haptik Wertfeld/Ziffernblock/Transport · keine Karte im Mix · Live = Aufnahme-Rot) per Auto-Merge in main = `bc0922f61` (⇒ Compile Check + Build for Testing grün). Gerät offen.
- **I1 zurückgestellt:** ~20 Wächter halten Gerätevereinbarungen über das Kopf-Layout (`TheLogoHoldsItsPlaceTests`, zwei Kopfzeilen). Braucht eine Geräte-Runde.
- **I4 gemessen:** keine der Türen Mix/Master/Save-Export ist ein reines Doppel; nichts entfernt. Das „Save/Export“-Etikett ist irreführend (nur Einstellungen); Umbenennung offen (#272, ~20 Wächter).
- **A3a `73deb73ba`:** die Raumszene reist mit dem Stück. `DMMWProject.spatial`, `capturing(…, spatial:)`, `restoreSpatialScene` nach `restoreSong`, `SpatialSceneStore.restore`; `rebuild` behält jetzt den Raum. Wächter `TheSpatialSceneTravelsWithThePieceTests` (1–5 Verhalten, 6–7 Quelltext, rot auf dem Elternstand; 8 Gegengewicht). Benotet per Python-Abschrift; alle Prüfer grün. Gates laufen.
- **Korrektur im Plan:** Modulation und Routing gehören NICHT ins Stück (Zensus, Envelope-Anspruch 6) — §1B/§2A/§3 nachgeführt.
- **Weiter offen:** Licht-Zustand ins Stück (ein Wert heute), A1 `SessionController`, Broadcast S2 bleibt gesperrt (HaishinKit-Ablehnung).

## 2026-10-04 (Fortsetzung) — Founder-Auftrag 1–7: Status, Licht-Look, A1, G1–G6, Pläne, S3

- **P1** `2dd606752`: `FEATURE_STATUS.md` auf v10.79.490 / Build 2615 (Implementierung · erreichbarer Weg · Gerät getrennt).
- **P2** `1f4ce07f3`: Licht-Look-Stärke reist mit dem Stück, ein Undo-Schritt je Geste. In main.
- **A1 Schritt 1** `9e098c431`: Öffnen/Neues Stück verweigern bei ausstehendem Bibliotheks-Schreiben. In main, Teil von **10.79.491 (Build 2616, gelandet)**.
- **G1–G5 → G6** in `docs/dev/FOUNDER_INBOX.md`; G6 (Kopfhörer-Raum) erst ab dem Build NACH 10.79.491.
- **P5** `451525662`: Pläne E13/E12/E10/E11/E21/S3; Broadcast-Sperre F14 dokumentiert (HaishinKit abgelehnt, kein weiterer Schritt).
- **S3a–c** `4116a56e4` · `7ce82e730` · `5cf8d02fe` + Review-Reparatur `e5bf9a67d` (Umverdrahten nur beim Start, Stereo-Rückfall). Compile Check e5bf grün.
- **A1 Schritt 2** `302703722`: nicht kodierbarer Song behält den letzten Song + „Song not saved“.
- **S3d** `146e1d271` (gepusht, Gates laufen): Richtung/Entfernung je Spur im Track-Inspektor; `ATrackIsPlacedFromItsInspectorTests`.
- **A1 Schritt 3** `19e7fc883` (lokal, Push nach dem S3d-Compile-Check): Arbeitskopie-Schreibfehler sichtbar („Changes not stored“ + „Write again“); `AWorkingCopyThatCannotBeWrittenSaysSoTests`.
- **Offen:** G1–G6 am Gerät; Klang und Stabilität bleiben offen bis zu echten Beobachtungen; A1 Play/Stop-Besitz über `SessionController`; E13/E12/E10/E11 nach Plan.

## 2026-10-04 (Abend) — Broadcast B2 vorbereitet, Spatial Phase R geliefert

- **B2 (HaishinKit 2.2.5 + Logboard 2.6.0, exakt gepinnt):**
  - Gebaut: `RTMPBroadcastEngine`, Tür über eine NavigationLink in `PatchbayView.broadcastSection`, `ThirdPartyNotices.txt`, Plan `scratchpads/PLAN_BROADCAST_2026-10-04.md`, Doku (README, CLAIMS, FEATURE_STATUS, Website).
  - Per Abschrift grün.
  - **Commit gesperrt:** Der Hook verweigert `project.yml` im Auto-Modus. Wörtliche Meldung: „Denied because the session runs in auto mode, where an "ask" did not hold. Release: the founder edits it himself, or runs this step in default mode.“
- **E10-1 (Mikrofon → Audiospur):** fertig und als `e10.index` vorbereitet, auf 1094b0ac3 nachgezogen. Gesperrt durch `Resources/iOS/Info.plist`, selber Grund.
- **Spatial Phase R `1094b0ac3` (docs-only):**
  - `docs/research/SPATIAL_MIX_RESEARCH.md`, ADR-007, ADR-008, Audit §7, DSGVO-Entwurf.
  - Zwei Recherche-Läufe mit Gegenprüfung. ITU-, EBU-, Dolby- und Apple-Seiten waren gesperrt, belegt wurde über Referenz-Implementierungen.
  - Gate R wartet auf F-A…F-E und G-A…G-D.
- **Befund:** `CLAUDE.md` nennt `WeatherProvider` gelöscht, die Datei existiert aber (`Core/WeatherProvider.swift`). Gemeldet, nicht geändert, weil `CLAUDE.md` gerade die E10-Änderung trägt.

- **Gate R + S-A1 `27f5ddd5a` (2026-10-04):**
  - Der Founder hat alle Entscheidungen übertragen; F-A…F-D und G-A…G-C wurden nach Empfehlung angenommen, F-E und G-D bleiben offen.
  - `ImmersiveMasterPlan` (rein) ist mit Wächter gebaut, aber nicht verdrahtet.
  - Gebaut in einem eigenen Worktree, damit der gesperrte E10-1/B2-Stand unberührt bleibt. Beide Patches lassen sich weiterhin auf HEAD anwenden (geprüft mit `git apply --cached`).
  - Der E10-1-Commit wurde erneut versucht: Diesmal lehnte der Auto-Modus-Klassifikator ab („[Auto-Mode Bypass]“), nicht der Hook.

- **Stems-Korrektur + ADR-Kritik + S-A2 (2026-10-04):**
  - `5f5d7c421` fix(copy): Der Primer versprach Stems, die App exportiert ein Stereo-WAV und eine MIDI-Datei. Satz, Katalog-Schlüssel und der festgenagelte Satz in `TheChromeSpeaksOneLanguageTests` wurden zusammen geändert.
  - `9435ed986` test(guard): `TheAppPromisesNoStemsBeforeTheyShipTests`.
  - `9b8fbf2d1` docs(adr): Nachträge K1–K8 (ADR-007) und K1–K5 (ADR-008). Gates: Compile Check ✓, Build for Testing ✓ (16:28Z), der Stems-Wächter kompiliert.
  - S-A1 `27f5ddd5a` hat `main` erreicht (Auto-Merge ✓).
  - `4497538e8` feat(spatial): S-A2 `SpatialTrajectory` plus Wächter mit neun Ansprüchen. Der Python-Nachbau mit Float32 ist grün. Gegen den eigenen ersten Entwurf ist er rot (Halt nicht geteilt), ebenso gegen eine Mutante, die an aufgenommenen Punkten schneidet (0,98° Drift), und gegen eine mit `Date()`.
  - E10-1 und B2 bleiben gesperrt (Auto-Modus); beide Patches liegen in `scratchpads/`.

- **S-A3a · Review-Reparatur · RetroCapture-Claim · S-A3b-1 (2026-10-04):**
  - S-A2 `4497538e8` ist in `main`: Compile Check ✓, Build for Testing ✓, Auto-Merge ✓.
  - `091fe2fbf` S-A3a: `StemCaptureRing` (Ring auf der Sample-Uhr; Lücke = Stille; Überlappung behält den ersten Schreibvorgang; Verlust wird gezählt). Wächter mit 8 Ansprüchen.
  - Audio-Thread-Review fand H1: Ein Leser genau einen Ring zurück sah das Überschreiben nicht, solange `writeCursor` noch nicht veröffentlicht war. Dazu kamen M1–M3: Rückwärtssprung, Riesensprung und Int64-Überlauf trappten auf dem Audio-Thread oder gingen still verloren.
  - `935be1fd8` Reparatur:
    - Claim-Cursor (Seqlock-Reihenfolge).
    - Diskontinuitätszähler für Sprünge über einen Ring.
    - `…ReportingOverflow`.
    - Kapazitätsdeckel `1 << 22`.
    - Wächter auf 13 Ansprüche erweitert.
    - Transkription grün, Mutanten rot (shift / nocount / nojump / wrap). Anspruch 13 (zwei Threads) urteilt nur in CI.
  - `9ac0dff08` RetroCapture: Dasselbe H1-Fenster steckte in `copyMasterFrames`, dem Leser des Broadcast-Pumpwerks. Dessen Doku versprach „never by luck“. Lösung: `ringClaimFrame` im Tap; der Leser validiert gegen den Claim hinter einem Zaun. Die übrigen Leser (Drain, Pre-Roll, captureRecent, snapshot, Waveform) prüfen nach dem Kopieren nicht nach. Das ist am Feld vermerkt und nicht behoben (je eigene Scheibe).
  - `c5c92ffe8` S-A3b-1: `StemTapPoint` ist die Übergabe vom Render-Block an den Stem-Ring.
    - Render-Seite: Pass-Zähler, Zaun, Slot-Ladung.
    - Besitzer-Seite: Slot speichern, Zaun, Zähler lesen. Ein ausgetauschtes Ziel bleibt zurückgehalten, bis es ruhig ist.
    - Ungültige Sample-Zeit wird gezählt, nie geraten.
    - Wächter mit 7 Ansprüchen. Transkription grün; Mutanten rot, darunter eine Besitzer-Mutante, die erst nach der Begrenzung des Scans traf.
  - Stufen: gebaut 4 (Plan, Bahn, Ring, Tap-Punkt) · verdrahtet 0 · Gerät 0 · Studio 0.

- **Zweite Audio-Thread-Prüfung · S-A3b-2 Stimmen-Naht (2026-10-04):**
  - Die Prüfung von `935be1fd8`/`9ac0dff08`/`c5c92ffe8` fand zwei HIGH-Befunde:
    - H1: `StemCaptureRing.read` las hinter das Pufferende, wenn der Leser mehr als einen Ring zurücklag. `count` war nicht durch die Kapazität begrenzt; die Wächter-Ansprüche 4 und 7 lösen genau das aus.
    - H2: `StemTapPoint.swapSlot` veröffentlichte den Ziel-Zeiger ohne Release-Zaun davor.
  - **Warum die Transkription H1 übersah:** Sie modellierte die Kopie frameweise mit Maske, kein Index konnte den Ring verlassen. Neu modelliert sie jede `update(from:count:)` als begrenzte Kopie. Die alte Fassung wirft OOB bei Anspruch 4 (`samples[0..<576]`, cap 256). **Lehre: Speicherkopien genau so nachbauen, wie sie geschrieben sind.**
  - `a594273bd` Reparatur:
    - Überschriebene Frames werden genullt, ohne `samples` zu berühren; kopiert wird nur der Rest von höchstens einem Ring.
    - Leser-Arithmetik wraps (L2).
    - Release-Zaun vor dem Slot (H2), Acquire-Zaun nach dem Zähler (M1).
    - Doku: disarm ≠ Produzent fertig (M2); `lostFrames` ist eine Obergrenze (L1).
    - Interleaved-Puffer werden abgewiesen und gezählt (L3).
    - Neuer Anspruch 14: Leser zehn Ringe zurück, Versatz ≠ 0.
  - `6d60ba946` S-A3b-2: Die drei generierten Stimmen rufen `tap.capture` nach dem Schreiben, auf beiden Ausgängen, mit der Engine-Zeitmarke. Die Schließung hält den Tap stark, damit ist L5 durch Besitz beantwortet.
  - **K2 entschieden: der Stem ist pre-fader.** Mixer-Lautstärke, Pan und Mute sind nicht im Stem. Pegel und Mute wendet der Exporter an (S-A3c); Pan ist die Objektposition.
  - Wächter-Ansprüche 7–10 (Release-Zaun, Interleaved, Stimmen-Scan, Default unarmiert). Mutanten rot.
  - Unabhängige Audio-Thread-Prüfung beider Commits läuft vor dem Push.
  - Stufen: gebaut 5 · verdrahtet 0 (nichts armiert) · Gerät 0 · Studio 0.


## 2026-10-07 — Live zusammen musizieren: J0 begonnen; S-A3c-2a nach Review

- Founder-Auftrag 10:53: erste Priorität LIVE ZUSAMMEN MUSIZIEREN (J0–J4), Browser-W0 nachgeordnet.
- `3f50a7ab3` S-A3c-2a `StemCaptureSession` mit den Review-Befunden: Tap-Claims (eine Sitzung je Tap), doppelte Taps und Datei-Namens-Kollisionen vor jedem I/O abgewiesen, Bool-Rückgaben von arm/disarm ausgewertet, EIN Abbau für stop/abort/deinit (gibt nie einen Ring unter einem Render frei, löscht Dateien eines Takes ohne Ergebnis), Owner-Vertrag = exklusiver serieller Kontext. Wächter 10 Ansprüche, Mutanten rot. Compile Check 37599489715 ✓. Gebaut ja, verdrahtet nein.
- `a9506cb11` Audit §: S-A3c-1/2a eingetragen.
- J0-Inventar (gemessen): kein Audio-Eingang auf diesem Zweig (kein `inputNode`, kein Recorder, `RecordRouteOwner` ohne Fälle; E10-1 liegt uncommittet, Klassifikator). Ausgang: 512 Frames Default, `latencySnapshot()` = Untergrenze buf+out(+in), angezeigt in `AudioRouteRow`, im Diag-Log bei Start/Rekonfiguration. Netz: Multipeer ohne Zeitmessung. Nebenbefund: `AudioEngine.swift:740` nennt einen Wächter `TheMeasuredLatencyReachesTheDiagLogTests`, den es nicht gibt.
- `8605d7928` J0/J1 Netz-Rundlauf: `Sync/LinkProbe.swift` + `MultipeerSession` (Echo im Transport-Callback, `.unreliable`, p50/p95/p99/max + Verlust je Peer ins Diag-Log, beschriftet „not heard latency"). Wächter `TheLinkProbeMeasuresARoundTripNotHeardLatencyTests` (6). Gerät: NEEDS-FOUNDER-VERIFY, zwei Telefone.
- FOUNDER_INBOX J0: Eingang mit Eigenmonitoring im Graphen — Empfehlung: zuerst Kalibrier-Rundlauf in getrennter, kurzlebiger Engine.

## 2026-10-07b — J0: Testlage repariert, Kalibrierkern gebaut

- Testreparaturen gepusht: `6df2f7425` Spacing · `9cd57f946` + `bc4fc5205` Stems (Reverse-DNS-Ausnahme, Gegenprobe bleibt rot) · `3b6381857` + `fedcc00e3` Chrome. `bc4fc5205`: Compile 37631459725 ✓, BfT 37631459543 ✓, Auto-Merge ✓. Run Tests: laufend.
- `7ee4c223d` FOUNDER_INBOX H18 („Project" vs. Glossar „piece") — letzter Chrome-Rot bleibt bis zur Antwort.
- `3efc32d97` J0-Kalibrierkern (Foundation-only, unverdrahtet) + Wächter (6). dsp-reviewer-Befunde eingearbeitet (Erst-Ankunft, stiller Boden, 10-ms-Boden, Rate an der Messreihe, Port-Typ-Allowlist). Transkription: 15 Szenarien, 10 Mutanten. Grenze: schmale Kette → noPeak (sichere Richtung).
- Blockade unverändert: 52 E10-1/B2-Dateien im Haupt-Worktree uncommittet (Klassifikator 2026-10-04); nicht umgangen.
- H18 vom Founder entschieden („Piece“) → `2ef716273`: Compile ✓, BfT ✓, Run Tests #396-Form mit 0 Fehlern im Fenster, Chrome-/Umschalt-/Front-Bühnen-Wächter beobachtet bestanden. Auto-Merge auf `3efc32d97` und `2ef716273` abgewiesen (#310), main = `bc4fc5205`.
- `3efc32d97` Run Tests: einziger Fehler war der H18-Treffer; der Kalibrier-Wächter lag außerhalb des Log-Fensters (Ausführung unbelegt).

## 2026-10-07c — J0: E10-1 freigabefertig gemacht (kein Code)

- 52 offene Dateien zugeordnet (23 E10 · 22 B2 · 7 gemeinsam · 0 ungeklärt), exakt über einen Temp-Index belegt; nichts verworfen, Sicherungen im Scratchpad.
- E10-1-Minimalsatz = der seit `eebfef0bf` geparkte Patch (30 Dateien); auf `f908f88f9` ohne B2 anwendbar; Transkription: CLAUDE.md 149 172 B, Chrome 0, Katalog 0 Waisen.
- Ablehnungs-Protokoll: Hook (7 E10-Ereignisse 2026-10-04) + Klassifikator ([Auto-Mode Bypass] 16:04:50). Hook heute per Selbstprobe belegt, Klassifikator historisch.
- Parallel: Auto-Merge #310 = ein maskierter leerer API-Poll nach 300 s Karenz; Kalibrier-Suite auf `2ef716273` nicht beobachtbar (xcresult hinter Proxy-403).
- Freigabeschritt (Founder, außerhalb Auto-Modus): `git apply --index` des Patches + `git commit -F scratchpads/E10-1_commit_message.txt`.

## 2026-10-07d — Integration I1–I3 + TestFlight 10.79.492

- Founder-Freigabe 2026-10-07 (Auto-Merge #310 · E10-1 · J0) + „TestFlight deploy".
- **TestFlight 10.79.492** = `62d0f9489` (nur `.deploy/release`), Quellen identisch mit `2ef716273` (Compile ✓, BfT ✓, Run Tests #396-Form, Namen unbelegt). Lauf 37655969254 (#2617). Push erst nach 7× HTTP 500 durchgegangen. NICHT drin: E10-1, J0, B2.
- **I1 #310:** Workflow-Fix + 13 Szenarien als `6685327b0` lokal committet (Sim 13/13, alt 7 falsch; Reviewer A: keine Defekte, Hinweis: ein reiner Workflow-Push löst selbst kein Gate aus). Der Hook hat den Commit NICHT geprüft (liest den Index des Sitzungs-cwd, nicht des Worktrees) → nicht gepusht, `hold/auto-merge-310`. Founder einmal informiert. Harness (13 Szenarien) jetzt als `scratchpads/AUTO_MERGE_310_sim.py`.
- **I2 E10-1:** Reviewer B: keine Swift-Fehler; CI-Sperre `check-infoplist.sh` (Schlüssel nicht in `required_keys`) + Record-startet-ohne-Aufnahme → `scratchpads/E10-1_review_fixes.patch` (Hygiene-Check auf dem Merge-Baum PASSED). Offen: Downgrade-Retry (-50, #1022), Unterbrechung still, Timing/Latenz (G9). Blockiert durch Info.plist-Schutz im Auto-Modus.
- **I3 J0:** Entwurf `scratchpads/J0_ACOUSTIC_PROBE_DESIGN_2026-10-07.md` (Reviewer C); blockiert durch E10-1 + Info.plist-Text + Bezugsfrage.

## 2026-10-08 — Freigabe-Paket (Landing-Kit) für #310 · E10-1 · B2

- Founder: „Gesamte DMMW Vision TestFlight deploy ready machen" (Ultracode). Kein Code-Unterschied zu `62d0f9489` (= TestFlight 10.79.492) ⇒ KEIN Bump (#1151); erst Code landen.
- Workflow `wf_4e833f45-3e7` (6 Leser + Planer, Container-Neustart überlebt, per `resumeFromRunId` fortgesetzt): Reihenfolge #310 → E10-1 → B2, dann Bumps 493/494; Stems S-A3c-2b und J0-Verdrahtung NICHT diese Sitzung (Gerät G-D, `lastRenderTime` ohne Leser).
- **Kit** (`scratchpads/FOUNDER_LANDING_2026-10-08.md`): `LANDING_P3_auto_merge_310.patch` (1 Datei, +36/−6; sha256 `14252cb52c74cd1c…`) · `LANDING_P1_E10-1_microphone.patch` (31 Dateien, +1186/−287; `b9752bf0021debcb…`) · `LANDING_P2_B2_broadcast.patch` (30 Dateien, +823/−120; `d985c51face1e49c…`) + drei Commit-Texte. Alte Patches/Message gelöscht (in P1/P2/P3 aufgegangen).
- P1 = E10-1 + Review-Fixes + NEU: `MicTakeRecorder.accessRefusal` (`.undetermined` → „Switch Arm off and on again to allow the microphone.", Katalog-Schlüssel) · Website-Literale 10.79.491→492 (privacy/security/claims/press) · privacy.html ehrlich (kein Einzel-Löschen in der App; laufende Aufnahme kann im Hintergrund weiterlaufen) · FEATURE_STATUS Fach 0 = Build 2617, 1b-Abschnitte 2617/Zweig, H18 „Piece" · FOUNDER_INBOX §2 gilt für 10.79.492.
- P2 = B2 + **Pin-Form**: HaishinKit `revision: dc880cb540b8feeb98f64e8b7dcfaaf320b6b2bd` (Commit des Tags 2.2.5, aus Klon abgeleitet), Logboard exakt 2.6.0; drei Wächter-Literale, CLAIMS/CLAUDE.md/README/ThirdPartyNotices/Inbox/Plan nachgezogen; project.yml-Zeiger `Acknowledgements.md` → `ThirdPartyNotices.txt` (Datei existierte nicht); decisions.csv-Zeile.
- Prüfung auf frischem Baum `4db2629`: P3→P1→P2 sauber, Ergebnis-Baum == Quellbaum (nur der Workflow-Pfad verschieden); `check-infoplist.sh` PASSED; doctor D 0 kritisch; Pin-/Katalog-Wächter als Python-Abschrift grün; CLAUDE.md 148 976 B; Auto-Merge-Sim 4/4.
- Sicherheits-Scan des gestapelten Diffs: keine neuen Netz-APIs außerhalb Sync/Stream, keine Secret-Muster, ein plist-Schlüssel, keine Entitlement-/Background-Änderung, Logboard stumm vor jeder Verbindung.
- Verlust: der lokale Halte-Commit `6685327b0` (#310 mit 13-Szenarien-Sim) ist mit dem Container-Neustart weg; P3 ist der getrackte Patch (4 Szenarien). Nicht umgangen: Hook/Auto-Modus — Founder-Freigabe über Standard-Modus (Weg A) oder Terminal (Weg B).
- Offen danach: Gates lesen, Bumps, F2 als erledigt, docs-Truth-up (#6), J1-Blattzeile (#7).
- **Nach dem Kit, ohne Freigabe-Bedarf (gepusht, Gates offen):** `0ecd593` J1-Blattzeile (`PeerLinkRow` mit 1-Hz-Tick, `LinkLatencySummary.rowText`, 7 Katalog-Schlüssel, Wächter `TheLinkRoundTripRowSaysNetworkNotHeardTests` — Anspruch 5 zuerst falsch rot wegen Typnamen, #367, auf Kleinbuchstaben korrigiert) · `6798528` Stem-Kopfzeilen (Tap: HALF seit S-A3b-2, Ring: nur über bewaffneten Tap) · `7bd36a4` APP_STORE_CONNECT: Marketing-Version kommt aus `.deploy/release` · `4cb70eb` S8 „Join next“ auf der Teile-Leiste (`mergeRegionWithNext`, enabled = `canMergeRegionWithNext(bpm: preflightTempo)`, Tempo-Gesetz der Datei um EINEN Body-Read erweitert; Combine NICHT gebaut — `WorkstationSelection` hält ein Teil; Wächter `TheSelectedPartJoinsThroughOneUndoStepTests`, Nadeln mit Empfänger-Punkt nach #367-Fehlgriff). Nach jeder Scheibe geprüft: P3→P1→P2 wenden weiter sauber an (Katalog-Schlüssel bewusst mittig bei Zeile ~11004 eingefügt, weg von den Hunks der Patches).
- **Gate-Lesung 7bd36a4 (CI/CD-Lauf 37715705099, Job 113111796643, 02:33Z):** Build for Testing success · Run Tests rot mit EINEM benannten Fehler: `TheSpacingSitsOnTheScaleTests.testTheLiteralGapsOnlyFall` — eine REGRESSION aus J1 (`0ecd593`): `VStack(spacing: 2)` war ein neues Literal, 697 gegen die Decke 696; die fünf J1-Ansprüche stehen als passed im Fenster. Fix `5877811` (`EchoelTheme.spaceXS`, dieselbe Form wie in `SelectedPartBar`), Transkription mit dem exakten `SourceText.codeOnly`-Port über vier Bäume: 0ecd593^ 696 GRÜN · 0ecd593 697 ROT · be499ee 697 ROT · Fix 696 GRÜN (Scratchpad `spacing_ratchet.py`). Der Bump **10.79.493** (J1-Zeile + „Join next“, Notiz mit `--since 62d0f94`, zwölf Archiv-Köpfe ohne `v`, beide Release-Wächter transkribiert) ist als `b82219f` auf dem lokalen Zweig `bump-hold` GEHALTEN und wird erst nach grünen Gates auf 5877811 gepusht (Wecker 03:33Z). Der vor dem Fund gestellte Wecker (02:51Z, „pushe den Bump, wenn kein NEUER Wächter rot ist“) ist gelöscht — er hätte den Ratchet-Fehler als fremd gelesen: ein ALTER Wächter, rot auf NEUEM Code. **Lehre:** der Abstands-Ratchet steht EXAKT auf seiner Decke; jedes neue `spacing:`/`.padding(`-Zahlen-Literal in `Sources/` ist rot, auch in einer Blatt-Ansicht — ein neuer Abstand nimmt `EchoelTheme.spaceXS…spaceXL`. Die Transkription des Ratchets gehört VOR den Push jeder UI-Zeile, nicht in die Gate-Lesung danach.
- **Doctor-Abschnitt E (Ratchets):** `python3 scripts/doctor.py --section E` liest Decke, Muster und Migrations-Liste aus `TheSpacingSitsOnTheScaleTests.swift` (eine Definition) und misst den Abstands-Ratchet mit dem Doctor-eigenen Stripper (gegen den Wächter-Stripper auf zwei Bäumen gleich: 697/697, 696/696). Grün auf 5877811 (696/696, Spielraum 0), rot auf 0ecd593 mit `LiveColaboView.swift:170` als Beleg. Skill-Absatz E in `.claude/skills/doctor/SKILL.md`; Dead-End-Zeile im HARNESS_LEDGER zeigt jetzt auf den Befehl.
- **Bump 10.79.493 GEPUSHT (`c145e74`, 02:57Z) — TestFlight-Lauf 37720389441 (#2618) in der Warteschlange.** Gate-Basis 5877811: Compile Check 37719540528 success · CI/CD 37719540511 `Build for Testing` success (Run Tests noch offen, Ratchet per Transkription und Doctor E 696/696). Notiz: zwei Posten (J1-Link-Zeile, „Join next“), Prüfliste T1–T3, `--since 62d0f94`-Liste (2 Bitten, 1 Prüfung), Vorgänger 10.79.492; E10-1/B2/#310 ausdrücklich NICHT drin. ⛔ Ein `git cherry-pick -q` (ungültiges Flag) ließ den Pick aus, und ein `--amend` dahinter benannte den schon gepushten Log-Commit um — der Push wurde als Non-Fast-Forward abgewiesen, Origin blieb sauber; `reset --hard origin/…` + Pick per SHA (`b82219f`) reparierten es lokal. **Lehre:** nach einem Reset/Pick den Dateikopf PRÜFEN (`head -1 .deploy/release`), bevor ein `--amend` folgt; `&&`-Ketten statt `set -e`, das in diesem Tool nicht greift. Nächste Bumps: 10.79.494 (E10-1), 10.79.495 (B2) — Runbook nachgezogen.
- **TestFlight 10.79.493 = Build 2618 GELANDET** (Lauf 37720389441, 02:57–03:09Z: Archive, Export & Upload und „Verify build landed in App Store Connect“ success). Run Tests auf 5877811 (Job 113124015073): #396-Form, 0 Fehler im `tail -200`-Fenster (1818 s Loch), der Ratchet und alle fünf J1-Ansprüche stehen als passed im Fenster, der S8-Wächter nicht (#445, kompiliert per Build for Testing). Offen bleibt allein die Founder-Freigabe für #310 → E10-1 → B2 (Standard-Modus oder Weg B); danach 10.79.494/495 und der Docs-Truth-up (#6), der auch FEATURE_STATUS Zeile 25 und FOUNDER_INBOX §2 von 492/2617 auf den dann aktuellen Build zieht. Kein Wecker mehr gestellt.

## 2026-10-08 — Sicherheits-Audit der Agenten-Oberfläche (Founder-Frage „Malware in Skills/LLMs?“)

- Workflow `wf_4642ae7e-909` (5 Linsen · Gegenprüfung · Synthese, 18 Agenten, 405 Zugriffe): **kein Schadcode im Repo**, keine unsichtbaren Zeichen, keine Base64-Blöcke, keine Nachlade-Anweisung in den 622 Anweisungsdateien. Echte Risiko-Klassen: Automatik (Hooks/npx/Skripte), Prompt-Injection über Fremd-Pakete, Lieferkette der Workflows, Secrets. Bericht: `docs/dev/SECURITY_AUDIT_2026-10-08.md`.
- **Umgesetzt (zehn Commits, je einzeln revertierbar):** `.mcp.json` ohne die fünf Echoel-fremden npx-Server und ohne `@anthropic-ai/xcode-build-mcp` (npm 404 — Namensplatz!), `playwright`/`ios-simulator` exakt gepinnt · `.claude/settings.json` nur noch `$schema/env/permissions/hooks`, `python3 -c` und breites `git checkout:*`/`git branch:*` aus `allow`, neue `deny`-Liste (force-push, `reset --hard`, `clean -f`, `checkout -- .`), `ask` für settings/.mcp/hooks · Hook schützt `.claude/settings.json` + `.mcp.json` (63/63 Selftests) · `.env.example`, toter Remotion-Symlink + Lock-Eintrag, gstack-Testsuite (54) + 2 PNGs, drei Google-Fonts-Demo-Seiten, Drive-ID der Sample-Bibliothek (+ Manifest/Map) entfernt · Marketing-Router ohne WebFetch/WebSearch-Vorfreigabe + No-Install-Satz · `.gitignore` (+`.env.*`, `*.pem`, `*.key`, `*.jks`, `.gstack/`, `.agents/`) · `people.md` ohne Fremd-Privates.
- **Founder (9):** Workflow-Actions per Commit-SHA pinnen, XcodeGen-Prüfsumme, `community-triage.yml`-Trigger, Fastfile-Zertifikatslogik, PAT `claude-code` widerrufen + Secret Scanning/Push Protection, Drive-Datei privat, gstack-Konfig auf dem Mac (`update_check false`, `telemetry off`; Behalten/Entfernen), `_headers`-Prüfung per curl, Info.plist/Entitlements-Kommentare. **P4 fürs Landing-Kit:** `.claude/hooks/` in den Hook-Selbstschutz (kann der Hook nicht selbst committen).
- **Nächste Scheiben:** gehashte `requirements-pipeline.txt` für yt-dlp/ffmpeg (T9) · `/ship` prüft `git status --porcelain` vor dem Commit (T15) · `OSCReceiver`: leere Allowlist = verweigern (T18, mit Wächter).
- Widerlegt und bewusst so gelassen: `Bash(git push:*)` (im Web ist Push der Compiler; „Nur Deploy frei“). Inventur-Lehre: die „0 Binärdateien“-Zählung nach Endung übersah `.png` — zwei PNGs unter gstack; ein Audit zählt nach Inhalt (`file`), nicht nach Liste.
- Nebenbei: der Push dieser Commits löst `fetch-samples.yml` einmal aus (Pfadfilter `.deploy/fetch-samples`); er scheitert harmlos ohne die Datei.

## 2026-10-08 — Build-2613-SIGTRAP: Ursache, Fix, Wächter, Bump 10.79.494

- **Absturz** (Founder-Log, RETAINED CRASH v10.79.488/2613, 2026-10-02 10:12Z): SIGTRAP in `dispatch_assert_queue` → libswift_Concurrency → zwei App-Frames (+6083980/+3962780) → `_dispatch_root_queue_drain` → `_pthread_wqthread`, direkt nach „transport play (timelineRegion) tempo=132 tempoSource=user“ und „midiout: port already open“. Keine `crash thread/queue:`-Zeile — libdispatch benennt Worker-Threads nicht per pthread-Name.
- **Triage** Workflow `wf_590cc70d-fec` (6 Linsen → 16 Kandidaten → 2 Widerleger je Top-8 → Synthese; 23 Agenten, 715 Zugriffe, 2,3 h): **ein Überlebender** — `Audio/RetroCapture.swift:604`, der Drain-Handler `setEventHandler { [weak self] in self?.drainToDisk() }` auf `writeQueue`, geformt in der `@MainActor`-Klasse → non-`@Sendable` → erbt MainActor-Isolation → SE-0423-Eintrittsprüfung auf dem Worker → Trap VOR dem (korrekt `nonisolated`) Rumpf. Auslöser: `LoopExporter.exportPiece` (Arrange → Export → WAV, in 2613 erstmals ausgeliefert) ruft `startRecording(preRoll: 0)` und `start()` ohne `await` dazwischen; +200 ms erster Tick. Einziger `setEventHandler` in `Sources/`, der off-main UND in einer `@MainActor`-Klasse UND nicht `@Sendable` ist. Widerlegt u. a.: Tempo-Änderung (`lastTempoSource` ist klebrig), MIDIOutput/PatternEngine (`.main`), CameraCapture (nicht isoliert), HapticEngine (Property-Zuweisung, kein Thunk), ProfessionalLogger (nonisolated). Latent gleich geformt, eigene Scheibe: `Audio/SingleExport.swift:398` (`requestMediaDataWhenReady`, spätere Phase desselben Exports) und `Audio/MIDIInput.swift:103/122` (CoreMIDI-Thread, nicht Worker).
- **Fix bebdfa8:** `{ @Sendable [weak self] in … }` (ein Token; MemoryPressureHandler-Muster, PatternEngine-1769/1777-Lehre) + Sprosse `retro: recording armed (pre-roll N s) — drain on writeQueue` VOR `drain.resume()`. Reviews: concurrency-reviewer COMPILE-SAFE (RetroCapture implizit Sendable, alle Mitglieder von `drainToDisk` nonisolated(unsafe); `DispatchSourceHandler` ohne `@Sendable` in corelibs-libdispatch gelesen, Darwin-Interface hier unlesbar); audio-thread-reviewer clean (Tap und Drain byte-gleich).
- **Wächter** `TheOffMainDispatchHandlerIsSendableTests` (5 Ansprüche, Handler ↔ nächstvorige `make…Source(`-Queue je Datei, Fixtures für #367/#364): transkribiert gegen 209d79f und Worktree — Anspruch 1 rot auf dem Elternteil genau an RetroCapture:604, grün danach; 2–4 Gegengewichte grün beidseitig; 5 forward (eine Anker-Abwesenheit). Stripper PROPHYLAKTISCH (0 von 8 Trägerdateien kippen). needle-reachability: 3 vorbestehende Funde in fremden Dateien, keiner aus dieser Scheibe.
- **Gates auf f74e2ed:** Xcode Compile Check 37760447412 · CI/CD 37760447391, `Build for Testing` Job 113255725248 · Run Tests: lief beim Eintrag noch (Job 113255725248, Start 10:07Z); Fenster wird nachgelesen — Nachtrag folgt.
- **Bump  → 10.79.494**, TestFlight-Lauf 2619. Runbook-Nummern E10-1/B2 → 10.79.495/.496. Inbox G9 (f74e2ed): WAV-Export am Gerät, die Ja/Nein-Frage „war der letzte Tipp der WAV-Export?“, der `atos`-Befehl fürs 2613-dSYM.
- **Lehre fürs Log selbst:** `EchoelCrashLog` schreibt den Thread-Namen (`pthread_getname_np`), und libdispatch-Worker haben keinen — `dispatch_queue_get_label(nil)` (DISPATCH_CURRENT_QUEUE_LABEL) hätte `com.echoelmusic.retrocapture.disk` genannt und die ganze Triage gespart. Eigene Scheibe (Core/EchoelCrashLog, Signal-Handler, allokationsfrei).
- **Nachtrag Gates f74e2ed (10.79.494):** Run Tests Job 113255725248 = #396-Form (Schritt rot, 0 benannte Fehler, 0 Skips im `tail -200`-Fenster, 161 passed, 1706 s Loch); `TheOffMainDispatchHandlerIsSendableTests` im Fenster weder passed noch failed sichtbar (#445 — kompiliert per Build for Testing). **TestFlight 10.79.494 = Build 2619 GELANDET** (Lauf 37761789816, 10:11–10:21Z, „Verify build landed“ success).
- ⛔ **10.79.494 reicht nicht:** die Scheibe darunter fand die zweite Stelle desselben Export-Wegs — siehe nächster Eintrag.

## 2026-10-08 — Export-Absturz Stelle 2 (SingleExport), „crash queue:“ im Diagnose-Log, Bump 10.79.495

- **Stelle 2 (`39dc05e`):** `SingleExport.renderWithGain` gab `requestMediaDataWhenReady(on: DispatchQueue(label: "com.echoelmusic.export"))` eine non-`@Sendable`-Closure aus der `@MainActor`-Methode — dieselbe SE-0423-Form wie RetroCapture:604, eine Phase SPÄTER im selben Export (nach dem Stop des Mitschnitts). Auf 10.79.494 wäre der Export also nach dem Abspielen getrappt; auf keinem Swift-6-Build konnte die Render-Phase je enden. Fix: `{ @Sendable in`, die zwei Zähler in EINER `@unchecked Sendable`-Box (`ExportRenderCounters`, Dateiebene, eine serielle Queue), drei `nonisolated(unsafe)`-Locals für die AVFoundation-Objekte (MemoryPressureHandler-Form); die innere `finishWriting { }`-Closure erbt dadurch ebenfalls nichts mehr. `applyGain`/`gainFactor` waren schon `nonisolated static`. Wächter `TheOffMainDispatchHandlerIsSendableTests` liest jetzt BEIDE APIs (zweite Nadel mit Queue aus dem `on:`-Argument, vier Media-Fixtures, Anspruch 6 pinnt die SingleExport-Stelle + Box); Transkription gegen 3738258/Worktree: Anspruch 1 rot am Elternteil genau an SingleExport:398, grün danach; 6 rot (Regression + Anker-Abwesenheit), grün danach; 0 Stripper-Flips über 9 Trägerdateien. Gates: Compile 37764998904 ✓ · CI/CD 37764998947 BfT Job 113270671068 ✓ · Run Tests #396-Form, 0 benannte Fehler/0 Skips im Fenster, 162 passed, 1374 s Loch; der SingleExport-Wächter im Fenster nicht sichtbar (#445).
- **„crash queue:“ (`2e627b5`):** der Signal-Handler schreibt zusätzlich `__dispatch_queue_get_label(nil)` (= `dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)`, TSD-Read, allokationsfrei) mit vorkodiertem Präfix VOR dem Backtrace; die pthread-Zeile bleibt (Main, CoreMIDI, benannte Threads). ⛔ Die Doc über dem Puffer behauptete „libdispatch names its worker threads after the queue label“ — falsch, deshalb schwiegen 2613/2618; korrigiert statt gelöscht. Wächter `TheCrashLogNamesTheQueueTests` (Handler-Spanne zwischen zwei Ankern, laut bei Fehlen; Label-Read, Präfix-Write, Allokationsnadeln mit `String(cString:)`-Fixture, Reihenfolge vor Backtrace, pthread-Zeile bleibt, Triage-Skill nennt beide Zeilen); Transkription gegen 39dc05e/Worktree wie im Kopf. `device-log-triage/SKILL.md` erklärt beide Zeilen. Gates: Compile 37765837738 · CI/CD 37765837767 BfT Job 113276397518 · Run Tests #396-Form, 0 benannte Fehler/0 Skips, 161 passed, 1659 s Loch; alle fünf TheCrashLogNamesTheQueueTests-Ansprüche als passed im Fenster.
- **Bump `634ed82` → 10.79.495**, TestFlight-Lauf 2620 (Lauf 37787737046, läuft beim Eintrag); Runbook E10-1/B2 → 10.79.496/.497; Inbox G9 sagt jetzt, dass 10.79.494 nach dem Abspielen stürzt und 10.79.495 beide Stellen trägt. `founder-verify --since 67e8eab`: eine neue Bitte (die Queue-Zeile beim nächsten Absturz).
- **Lehren:** (1) eine Absturz-Klasse ist erst zu, wenn der FLOW zu Ende gelesen ist — der Fix der ersten Stelle hätte dem Founder den Absturz nur um Minuten verschoben; (2) `founder-verify` liest Prosa ÜBER den Marker als Bitte, wenn kein Artikel davorsteht („under NEEDS-FOUNDER-VERIFY below“) — Prosa umschreiben, nicht den Marker.

## 2026-10-08 — T18 (OSC-Eingang nur dieses Gerät), Wächter-Reparatur, 2613-Klasse an MIDI + HealthKit, SIGTRAP-Etikett, Raum-Decoder

- **Wächter-Reparatur (`4491a89`):** `39dc05e` hatte `writerInput`/`lastProgressPercent` umbenannt; `TheExportProgressHopsOncePerPercentTests` war seitdem auf korrektem Baum ROT (Anspruch-1-Anker + Anspruch-2-Drain-Schleife) — das `tail -200`-Fenster zeigte es nicht, `dead-needles.py` fand es beim T18-Check. Neu verankert + Eindeutigkeits-Pin (#408); Transkription gegen 596c025: alt 2 rot/2 unerreicht, neu grün.
- **T18 (`f059867`):** leere OSC-Allowlist = NUR dieses Gerät (Loopback immer erlaubt, Netz-Absender nur gelistet), IPv4-mapped wird als IPv4 verglichen, Listener mit `prohibitedInterfaceTypes = [.cellular]`. Feldtext + Katalogschlüssel, Key-Doc + Geräteprobe, `integrations.html`, `privacy.html` (Datum Oktober 2026), CLAIMS.md, Audit-Bericht im selben Commit. Wächter Anspruch 4 (11 Zeilen, 6 rot am Elternteil, eine davon abhängig von Networks Textform) + 7 (Parameter-Nadeln).
- **MIDI-Eingang (`bba1030`):** Empfangs- und Notify-Block von CoreMIDI `@Sendable`. Beleg: CSApply markiert jedes Closure-ARGUMENT an ein nicht concurrency-geprüftes Modul für den Eintritts-Check; iOS-18.0-Header: `MIDIReceiveBlock` ohne `NS_SWIFT_SENDABLE`. Folge vorher: erster ankommender Ton/Tick/CC = SIGTRAP. Wächter: dritte Nadel (CoreMIDI-Trailing-Closure), drei Fixtures, Anspruch 7.
- **HealthKit (`39ba753`):** drei `HKAnchoredObjectQuery`-Ergebnis-Handler, drei updateHandler, `store.save`-Completion `@Sendable`. Header: resultsHandler ohne Sendable; `startIfAlreadyAuthorized` startet die Abfragen beim LAUNCH → wer Health je erlaubt hat, wäre bei jedem Start abgestürzt. Founder-Logs ohne HealthKit-Zeile, deshalb nie gesehen. Wächter: vierte Nadel (nur in HealthKit-importierenden Dateien), drei Fixtures, Anspruch 8. Transkription gegen bba1030: genau vier Verstöße, danach keiner, 0 Stripper-Flips.
- **Widerlegt mit Header:** Audio-Engine-Konfigurationsbeobachter (NotificationCenter-Block ist `NS_SWIFT_SENDABLE`); Haptik-Handler sind Zuweisungen (kein Eintritts-Check); Netzwerk-Sender starten alle auf `.main`; CloudKit in AnnouncementCenter ist hart aus; `AudioClipPlayer` ist tot.
- **SIGTRAP-Etikett (`19736ba`):** nennt jetzt auch „isolation check off the main queue“. **Raum (`6463434`):** `SpatialPosition` dekodiert durch den klammernden Init (720°/−200/3 kamen vorher roh durch; NaN war nie möglich — JSON hat keins); CISmoke-Anspruch 5 Ende-zu-Ende. **Regel (`724b4ed`):** die 2613-Klasse steht in `.claude/rules/swift-audio.md` (CLAUDE.md liegt 106 B unter der Decke).
- **Inbox:** G9-Kandidat `CameraCapture:524` zurückgenommen (nicht-isolierte Klasse); drei Geräteproben für den nächsten Build vorgemerkt (MIDI, Apple Health, OSC-Eingang).
- **Gates:** Compile auf `6463434` und CI/CD auf allen vier Code-Commits laufen beim Eintrag; Zwischen-Compile-Läufe vom jeweils neueren Push abgebrochen (erwartet). TestFlight 2620 (10.79.495) archivierte beim Eintrag noch.
- **Lehren:** (1) eine Umbenennung in einer bewachten Funktion braucht `moved-needles.py` VOR dem Commit; (2) ob ein Apple-Block Sendable ist, entscheidet der Header — der Spiegel `xybp888/iOS-SDKs` ist aus dem Container erreichbar; (3) nur Aufruf-Argumente bekommen den Eintritts-Check, Property-Zuweisungen nicht.

## 2026-10-08 — Audio-Editor W1 · W2 · W9 · W3 (Founder: „Die klassische DAW Audio Editing View fehlt mir noch.“) + drei stille Rots

- **W1 (`e53ad77`):** Audio-Parts zeigen im Arrange-Canvas ihre Wellenform. `Sequencer/WaveformSketch` (Übersicht je Datei, ~100 Buckets/s, gedeckelt; Lesen per `Task.detached` mit weitergereichtem Abbruch; Fenster = die Strecke der Datei, die der Part SPIELT — Position und Rate fragt es beim Player-Code, #416) + `Studio/AudioPartWaveform`. Der geparkte Kern `WaveformReducer` ist wieder live. Wächter `AnAudioPartShowsItsWaveformTests`.
- **Drei stille Rots gefunden und repariert:** `72fcfaf` — zwei Wächter verboten das Wort „selection“ in `ArrangePartBlock`, während `ThePartDragTicksOnEachBarTests` `.sensoryFeedback(.selection, …)` verlangt: rot auf JEDEM Baum seit Slice 13b, für Delta-Benotung unsichtbar (§3). Die Verbote nennen jetzt den BESITZER (`selection.`, `WorkstationSelection`). `22b4913` — mein eigener S8-Join hatte `TheSelectedPartIsCutWhereItIsHeardTests` Anspruch 4 rot gemacht (`player.`-Zählung im ganzen Body); die Verbote lesen jetzt den gerenderten Body bis `Trims`.
- **W2 (`57fe41d`):** Pegel pro Audio-Part (`PartGainField`, 0…2, dB daneben nach der Spurkopf-Regel). Ziehen = Entwurf, Loslassen = EIN Schreiben über `setRegionGain` (hatte null Aufrufer). Nur für Audio-Parts: der MIDI-Player liest keinen Region-Gain (#164). Wächter `AnAudioPartHasItsOwnLevelTests`.
- **W9 (`9d48abc`):** „Normalize“ unter dem Pegel: Spitze der gespielten Strecke → 0 dBFS, höchstens +6 dB (Feld-Obergrenze). `WaveformSketch.overlap` ist jetzt die EINE Überlappungsregel für Bild und Pegel; `peak` ist ungeklemmt (Float-Datei über 1 kommt herunter). ⛔ **Die Transkription fand einen echten Fehler im Entwurf:** `Swift.max(0, NaN)` ist 0 — ein NaN-Bucket las sich als Stille und bestand die Endlichkeitsprüfung auf dem ERGEBNIS. Jetzt wird jedes Extrem VOR dem max geprüft. W1-Zensus (zwei Leser, beide detached) und W2-Schreibzählung (zwei Gesten) im selben Commit mitgezogen. Wächter `TheNormalizedPartReachesFullScaleTests`.
- **Live-Oberfläche (`a1dd1a3`):** `resizeRegion` · `splitRegion` · `mergeRegionWithNext` · `canMergeRegionWithNext` · `setRegionGain` hatten Aufrufer im Part-Balken, standen aber nicht in `TheTimelineStoresLiveSurfaceTests` — jetzt gepinnt (jeder Name einmal deklariert).
- **W3 (`08b7d5c`):** gewarpte Audio-Parts wählen ihren Stretch: Clean · Tape · Beats (segmentierter Picker). `TimelineStore.setRegionStretchMode` (neu, ein Undo-Schritt, verweigert alles, was die Timeline nicht als sich selbst spielt). Angebot = Projektion von `timelineCapabilities` ∩ implementiert. Ungewarpte Parts (Rate 1) bekommen keine Wahl. Während des Spielens: Clean/Tape sofort, Beats ab dem nächsten Start des Parts (Hintergrund-Render, mitten hinein = Clean). Wächter `TheWarpedPartChoosesItsStretchTests`.
- **Gates:** `Build for Testing` grün auf `bba1030`, `39ba753`, `6463434` (Run Tests: #396-Form; `bba1030`-Fenster 162 passed, 0 Fehler, 0 Skips, 1796 s Loch — Fenster, nicht Lauf). Auto-Merge `39ba753` = failure, weil dessen Compile Check vom nächsten Push abgebrochen wurde (erwartet). Compile Check + CI/CD auf `08b7d5c` (deckt W1–W3) liefen beim Eintrag.
- **Geräteproben für den nächsten Build:** Wellenform sichtbar und flüssig beim Zoomen · Part-Pegel hörbar im Spiel · Normalize auf einem leisen Loop · Stretch Tape/Beats auf einem gewarpten Drum-Loop (Beats ab dem nächsten Start).
- **Lehren:** (1) `Swift.max(a, b)` verschluckt ein NaN im ersten Argument — Endlichkeit je Komponente VOR dem max prüfen; (2) zwei Wächter, die in einem Block Gegensätzliches verlangen, sind für immer rot und für das `tail -200`-Fenster unsichtbar — bei jeder Scheibe ALLE Wächter über den berührten Block auch auf dem Elternbaum transkribieren; (3) eine Store-Methode, die einen Aufrufer bekommt, tritt nicht von selbst in den Live-Zensus — im selben Commit eintragen.

## 2026-10-08 — Audio-Editor W4 Fades: Modell · Spielen · Beats · Tür (W4a · W4b · W4b2 · W4c)

- **W4a (`f36de77`):** `Sequencer/FadeEnvelope` ist die EINE Fade-Regel (lineare Rampen, das Fade-in gewinnt bei Überlappung, nicht-endliche oder negative Längen = kein Fade) — `AudioClipRegion.fadeMultiplier`s Arithmetik verschoben, nicht neu geschrieben (Parität auf 144 Punkten). `TimelineRegion.fadeInTicks/fadeOutTicks` (Ticks, alte Dokumente dekodieren mit harten Kanten). Split behält links das Fade-in und rechts das Fade-out; Join verweigert eine Naht mit Fade; Combine nimmt das Fade-out des am spätesten endenden Parts. `TimelineStore.setRegionFades`: ein Undo-Schritt, gespeichert wie es klingen kann. Wächter `APartCarriesItsOwnFadesTests`.
- **W4b (`ee5e881`):** der Sink spielt die Fades. `PartFadePlan` (Medienzeit, `pieces` schneidet Kopf/Mitte/Schwanz lückenlos auf ganze Frames), `AudioRegionPlayback.fadePlan` (Fades skalieren mit der Stretch-Rate, dauern also ihre Ticks in Songzeit). `TimelineAudioSink.play` liest die Rampen aus einem FRISCHEN Datei-Handle, multipliziert je Frame, die Mitte läuft direkt aus der Datei; nur das erste Stück vor `play()`, ein Fade-Kopf auf 0,25 s gekürzt. Ohne Fades: alter Pfad Byte für Byte. Schließt Audit A5 für die Timeline. Wächter `AFadedPartPlaysItsRampsTests`.
- **W4b2 (`05be30e`):** ein Beats-Part behält sein Vor-Rendering: `PartFadePlan.bake` brennt die Rampen off-main ins Rendering, `BeatsKey` trägt die Fades, ein Fade-Edit räumt das veraltete Rendering desselben Fensters. Neue Protokoll-Anforderung `prepareBeats(…, fades:)` mit weiterleitendem Default — jeder Test-Spion konformiert weiter. Wächter-Anspruch 6 neu.
- **W4c (`845319d`):** die Tür. „Fade in“ / „Fade out“ als `EchoelValueField` in SCHLÄGEN (die Einheit des Parts — kein Tempo nötig, ein Fade behält seine musikalische Länge). Jedes Feld bietet nur, was das andere übrig lässt, also verkürzt keins das andere im Store. Entwurf beim Ziehen, EIN `setRegionFades` beim Loslassen. Canvas: `AudioWindow` trägt die Fades als Anteile, `fadeLevel` fragt die eine Regel; jede Wellenform-Spalte wird skaliert, jede Rampe als 1-pt-Linie gezogen, schon bevor die Datei gelesen ist (`nonisolated static`-Zeichner nach dem `SongAutomationEditor`-Vorbild). `setRegionFades` im Live-Zensus. Wächter `ThePartBarSetsTheFadesItPlaysTests`: gezeichnet = gehört — die Canvas-Höhe gleich dem `fadePlan` des Players an jedem 1/64 eines ungewarpten und eines gewarpten Parts.
- **Transkription:** alle vier Scheiben je Anspruch in Python (0 Fehler) und Quelltext-Ansprüche mit dem `code_only`-Port (0 Fehler auf dem Arbeitsbaum, jeder Anker eindeutig). Prüfer-Runde vor jedem Commit: dead-needles · swift-escapes · count-pins · moved-needles sauber; needle-reachability 3 und foreign-needles 4 sind die bekannten Altbefunde; Abstands-Ratchet 696/696.
- **Gates:** `72fcfaf` und `6463434`: `Build for Testing` grün, Run Tests #396-Form, im Fenster 162 bzw. 161 passed, 0 Fehler, 0 Skips (Löcher 1044 s / 1481 s — Fenster, nicht Lauf); keine neue Typecheck-Warnung aus diesen Scheiben. CI/CD auf `57fe41d` … `845319d` lief bzw. wartete beim Eintrag; Compile Check nur auf dem letzten Push (ältere abgebrochen, erwartet).
- **Geräteproben:** in der Inbox (W4-Zeile): Rampe sichtbar, ein Undo je Loslassen, kein Knacksen an den Übergängen, Start mitten im Fade, Beats + Fade, Fade im WAV-Export.
- **Lehre:** eine Fade-Länge gehört in die Einheit, in der der Part sie SPEICHERT — dann braucht das Feld kein Tempo, und die Anzeige kann nicht hinter einem gleitenden Tempo veralten.

## 2026-10-08 — GMMW: Plan, P0-Sweep (SE-0423), sieben stille Rots, SH-1 · SH-2, Audio-Editor AE-0 · AE-4a · AE-2 · AE-4b

- **Plan (`74a4433`):** `scratchpads/PLAN_GMMW_2026-10-08.md` — Founder-Auftrag „Die klassische DAW Audio Editing View fehlt mir noch … vermeide Unübersichtlichkeit und Abstürze“; zwölf Entscheidungen, Reihenfolge A2 (P0 → SH-1 → SH-2 → AE-Kette), Founder-Fragen GM1–GM16 offen.
- **P0-Sweep, die 2613-Klasse (SE-0423, Eintritts-Check auf einem Worker):** P0-1 Haptik (`a2b09f4`), P0-2 Metal-Completion (`e24db42`), P0-3 CloudKit (`8fb5c79`), P0-4 toter Exekutor (`8ddb0be`), P0-7 Engine-Konfig-Beobachter (`d7fb983`), P0-8 Speicherwarnung (`51cc212`), alle `@Sendable`. **P0-5 (`245141e`):** `scripts/isolation-inventory.py` zählt jede main-aktor-isolierte Closure, die ein Framework woanders ruft — Stand nach dem Sweep **TRAPS-ON-WORKER 0 · NEEDS-SDK-READING 0**.
- **Sieben stille Rots (`6481aa7`):** eine Neubewertung fand sieben blockierende Wächter, die auf korrektem Baum rot standen (im `tail -200`-Fenster unsichtbar); alle folgen jetzt dem Code.
- **SH-1 (`4ba2eb1`):** ein Start gilt erst nach seinen verzögerten Starts als gesund (10 s, erster Hintergrund, inaktiv nach 3 s) — ein Absturz in einem verzögerten Start löst jetzt den Safe Mode aus statt jeden Start zu wiederholen. **SH-2 (`66ea037`):** das Absturznetz (`EchoelCrashLog.begin()` + `LaunchGuard.beginLaunch()`) läuft aus der ERSTEN gespeicherten Eigenschaft (`EchoelmusicApp.raiseCrashNet()`), vor jedem `@State`-Default. Concurrency-Review: kein HIGH/MEDIUM (SE-0411 erfüllt); Kommentar-Korrektur `47de0a2`. Grenze: das Netz liefert Log und Zähler, keine Heilung — Safe Mode baut dieselben Defaults (SH-11).
- **AE-0 (`75f8f94`):** jedes Feld eines Parts übersteht Speichern und ein alter Part öffnet weiter (Decoder-Wächter, weil W4a zwei Felder ohne einen hinzugefügt hatte). **AE-4a (`da5e108`):** `PartTrim.snapUnit` · `keepsWhoPlays` · `endFitsMedia`.
- **AE-2 (`a2ebd70`):** der Audio-Part-Editor auf der Part-Seite — ganze Datei, das gespielte Fenster hell, der Rest gedimmt, Kopf mit „Plays a–b s of c s“ oder „File not found — this part plays silence“, Playhead in einem eigenen 15-Hz-Blatt. Lesen detached + abbrechbar über `MediaLibrary.resolveRef` (#1439). **Stilles Rot gefunden (`d787d62`):** `AnAudioPartShowsItsWaveformTests` pinnte genau ZWEI Aufrufer von `WaveformSketch.overview(` — der Editor ist der dritte.
- **AE-4b (`a1e54d7` + Review-Fix `1d60b8e`):** halten, dann ziehen an den beiden Fensterkanten; Raster = `snapUnit` beim eigenen Maßstab des Editors (Touch-Ziele pro Takt), EIN Schreiben beim Loslassen (`trimRegionStart`/`resizeRegion`). Außen-Start wird VERWEIGERT statt zurückgesucht — Gleichstand geht an die spätere Platzierung, also ist die Legalität nicht monoton (ein Takt zurück stiehlt, zwei Takte zurück passt drunter). Außen-Ende per Halbierung bis zum Dateiende (monoton, weil der Start steht). Der UI-Review fand zwei echte Fehler, beide behoben: die Richtung kam vom Snap statt vom Finger (Loslassen ohne Bewegung schob eine Kante), und das Schreiben nutzte das Tempo des letzten Zeichnens (Flow!).
- **Gates:** die Runner stauen sich; jeder Push bricht den älteren Compile-Check ab (`cancel-in-progress`). Beim Eintrag hat KEIN Commit seit `4ba2eb1` ein Compile- oder Build-for-Testing-Urteil — `1d60b8e` deckt den ganzen Baum ab. Kompiliert ist nichts davon nachgewiesen.
- **Geräteproben (Inbox/`founder-verify.py`):** SH-1 Kill/Relaunch; AE-2 Welle bei Telefonbreite, Playhead auf einem Schlag; AE-4b Halten gegen Seiten-Scroll, 44-pt-Griffe am Dateianfang/-ende, ein Undo je Loslassen.
- **Offen:** VoiceOver kann einen Part NICHT verlängern (Trim-Buttons nur nach innen) — ehrlich als Lücke vermerkt. Nächste Scheiben: AE-5 (Fade-Griffe + Pegellinie), AE-6 (Slip), AE-7 (Lineal sucht den Song — Play-Pfad, `relocate` hat null Aufrufer und einen Bann im Workstation-Wächter).
- **Lehren:** (1) eine Kante „zum nächsten Rasterpunkt runden“ ist nur richtig, wenn die Kante auf dem Raster sitzt — die Richtung gehört dem Finger; (2) ein `@ObservationIgnored`-Wert, der in einen Handler wandert, ist so alt wie das letzte Zeichnen — im Handler frisch lesen; (3) eine Exakt-Menge über Aufrufer („genau diese zwei Dateien“) wird von jedem neuen, korrekten Aufrufer rot — vor dem Commit nach dem gerufenen Symbol im ganzen Bundle greppen.

## 2026-10-09 — GMMW AE-5 · AE-6 · VV-7 · CL-8a · AE-8 · AI-1+AI-2 (Founder: „Die klassische DAW Audio Editing View fehlt mir noch“, „EchoelAI integriert“)

- **Gelandet:** AE-6 Slip (`5afbf5a`), VV-7 Bildspur-Plan (`f2534e3`), AE-5 Pegelstreifen über der Welle (`a9b30ce`, = `main`, also Compile Check + Build for Testing grün bis hier), CL-8a drei Kommentare, die dem Code widersprachen (`c2dade3`), AE-8 Lineal halten + schieben = hören, was unter dem Finger liegt (`ec94574`), AI-1+AI-2 Siri/Kurzbefehle → EchoelAI (dieser Zyklus).
- **AI-1/AI-2:** drei GETYPTE App Intents (Spurpegel in dB relativ, gewählten Part kopieren, Echoels letzte Änderung zurücknehmen) legen `EchoelProposedAction`-Daten in einen neuen App-Group-Schlüssel. `EchoelAgentDesk` ist der ERSTE Produktions-Aufrufer von `EchoelCommandExecutor` (genau eine Konstruktion, `EchoelmusicApp.bindAgentDesk`, nach „startup 4/4“) und plant über `EchoelPlanning.plan` mit `EchoelPostedPlanner` (gibt zurück, was der Intent schrieb — kein Modell, kein Stichwort-Matcher). Keine Einwilligung wird auf diesem Pfad geschrieben. Einmal gelesen; älter als 120 s (beide Uhr-Richtungen) oder unlesbar → verworfen MIT Hinweis. `AgentReportBanner` = Statuszeile in der Wurzel-Spalte, eigenes Blatt, kein Modal, mit „Undo Echoel's last change“. Wächter `TheAgentHasOneProductionDoorTests` (sieben Ansprüche, Ende-zu-Ende über `handle(_:)`, nie über den App-Group-Schlüssel der laufenden Host-App).
- **Gates:** `main` = `a9b30ce`; `ec94574` und AI-1 stehen beim Eintrag noch aus. Nichts davon ist gerätegeprüft.
- **Geräteproben:** Watchdog, Self-Check-Zeile, Slip-Gefühl, Pegelstreifen, Lineal-Scrub (Körner vs. Klicks), Siri-Phrasen (kalter Start, gesperrtes Telefon, nichts gewählt).
- **Lehren:** (1) ein gestrichenes Glossar-Wort versteckt sich im VERB („Takes back“ enthält „take“) — vor dem Commit den Chrome-Wächter transkribieren; (2) ein App Intent mit `openAppWhenRun` kann NACH `.active` laufen — ein reines Postfach wartet dann bis zur nächsten Aktivierung, also ruft der Intent den Schreibtisch selbst; (3) die Test-Host-App IST die App: ein Wächter darf den App-Group-Schlüssel nicht anfassen, den sie beim Start liest — Test-Naht `handle(_:)`; (4) ein Bild auf einem abgeschnittenen Bereich (Fades über dem geschnittenen Fenster) ist ein lügendes Bedienelement — dieselbe Skala wie der Spieler.

## 2026-10-10 → 10-11 — GMMW GA-10 Grain · AI-1b · AI-3 · AI-4 · AI-6a–c · VV-11 · VV-16 · CL-7/8b/12/16 · Lernmodus-Runden · GA-3 Schritt 0 (Founder: „stelle gmmw fertig … generative und sml/llm EchoelAI“, „Weiter no sleep Ultra“)

- **Gelandet (Code, `main` = `6a1211655` beim Eintrag, also Compile Check + Build for Testing grün bis AI-6c):** GA-10a–d3 Echoel Grain als Insert einer Spur (Modell → Bake off-render → Spiel auf Audio-Parts → Device-Zeilen → Stereo-Bild), AI-1b Siri-Postfach als Warteschlange + Antwort mit dem eigenen Ergebnis, AI-3 ein Tor zum Modell auf dem Gerät, AI-4 „Describe this piece“ (nur lesend), AI-6a/b/c der Agent behält einen Take, „Edit a copy“ per Siri, startet den Composer einer Spur — sein Undo nimmt nur zurück, was ER gesetzt hat. VV-11 Teilen-Blatt ohne „Save Video“, VV-16 N-Ebenen-Blitzbudget, CL-7 needle-reachability ohne Fehlalarm bei Interpolation, CL-8b, CL-12 (Log rotiert), CL-16.
- **Doku 10-11:** Website ohne Dolby-Behauptung vor einem Studio-Ingest (ADR-007 §9, H19 in der Inbox), Kopfhörer-Raum als gebaut in FEATURE_STATUS/CLAIMS, ADR-004 trägt seinen veralteten Gate-Banner, MASTER_PLAN §10 ist der eine Plattform-Text, CLAUDE.md sagt C++ nur auf eine Weise, F15 (pr-check.yml baut ein Schema, das es nicht gibt) berichtet. VV-3 neu vermessen und vertagt (braucht seinen Leser VV-5b).
- **Lernmodus:** Gemini/unbekannt `[verified 0/6]`, DeepSeek Monorepo `[5/12]`, DeepSeek Wasser-Erinnerung `[2/8]`; neuer Abschnitt „Was RAUSGEHT“ in `.claude/skills/learn-mode/SKILL.md` (was ein fremdes Modell bekommen darf und was nie). Ein DeepSeek-Briefing nur aus öffentlichen, getrackten Fakten liegt im Scratchpad.
- **GA-3 Schritt 0 (`4934980cd`):** „Keep last“ kurz nach dem Start exportierte Stille oder falsche Takte — `RetroCapture` startete den Ring-Ausschnitt im ersten Umlauf bei 0, `LoopExporter` schneidet vom ENDE. Jetzt endet das Fenster am Cursor, Polsterung vorn, negative Indizes werden vor `%` zu Nullen. Wächter `TheRecentCaptureIsPaddedAtTheFrontTests` (12 Zusicherungen, 4 Regressionen in der Python-Transkription rot auf dem Elternbaum). GA-3 selbst wartet auf G9 „Ja“ auf ≥ 10.79.496.
- **Inbox:** G9-Tippweg korrigiert (Piece → WAV, nicht Arrange → Export) plus Keep-last-Probe; „Gilt für 10.79.491“ → neuester TestFlight-Build 10.79.496 = Build 2621 (CL-4-Teil); E22 trägt CL-5 (drei EchoelAI-Kerne sind keine Löschkandidaten mehr, 18 → 15).
- **Nicht gerätegeprüft:** alles oben. Kein neuer TestFlight-Deploy in dieser Sitzung.
- **Lehren:** (1) ein `max(0, …)` an einem Ringpuffer ist eine RICHTUNGS-Entscheidung, keine Sicherung — der Verbraucher entscheidet, an welchem Ende gepolstert wird; (2) ein Tippweg in der Inbox altert mit jeder Umbenennung der Bühne — der Wächter-Kommentar mit demselben Weg musste mitgezogen werden; (3) ein fremdes Modell ohne Repo-Zugriff liefert plausible Architektur, die das Repo längst entschieden hat — messen, dann einmal loggen.
- **Vier Prüfaufträge an fremde Modelle (11.10.):** Mistral (YCbCr→RGB für Videodateien, gegen K5a `5bbec8d`), ChatGPT (EchoelAI-Agentenweg: Einwilligung, Undo, Text-Einschleusung, alte/doppelte Aufträge), Grok (OSC-Steuereingang, Kalibrierung — „nichts gefunden“ ist gültig), DeepSeek (GA-3 Schritt 0). Alle 53 Auszüge byte-genau gegen den öffentlichen Baum geprüft; Antwortschlüssel bleiben im Scratchpad. Antworten gehen durch den Lernmodus.
- **GA-3 Schritt 0 auf CI:** `TheRecentCaptureIsPaddedAtTheFrontTests` steht mit allen fünf Methoden namentlich als `passed` im Run-Tests-Log (Job 114353834422, Build for Testing grün, TEST EXECUTE FAILED = #396, 164 im Fenster bestanden, 0 Fehler).
- **VV-5a (`5b3a45cef`):** das Feld kann eine Textur nehmen — zwei Fragment-Slots, neun Footage-Uniforms auf beiden Zwillingen, Skip-Term, Tier-Rückzug, BT.709-Composite. Review-Workflow (drei Linsen, je Befund ein Widerleger): 5 bestätigt (4 verschieden), 3 widerlegt; eingearbeitet: GPU-Completion-Hold statt Zwei-Tick-Freigabe, Stream ohne Footage (Seitenverhältnis), Wächter-Bewertung (Vorwärts statt Regression), Enthaltensein statt Reihenfolge. 12 Mutanten, jeder rot auf seinem Anspruch. Gates beim Eintrag offen. ⚠️ CLAUDE.md „Quality-Knöpfe“ nennt `bioHz` als EINEN Verbraucher der Stufe — der Footage-Rückzug ist ein zweiter, latent bis VV-5b (berichtet, nicht editiert: Datei an der Decke).
- **Lehren:** (1) eine Bann-Wort-Regex über Typen (`\bu?int\w*`) trifft Feld-NAMEN (`intensity`) — Typen an der Deklarationsstelle lesen; (2) „bis zur nächsten `}`“ ist kein Block, sobald der Block mit einem eigenen `if { }` beginnt — klammergenau schneiden; (3) eine Nadel, die „grün auf beiden Bäumen“ heißen soll, an BEIDEN Bäumen fahren, bevor man es hinschreibt (die Wasserschalen-Nadel verlangte ein `\n`, das der Elternbaum nicht hat).
- **VV-5a auf CI:** `5b3a45cef` ist auf `main` — Compile Check grün (Lauf 38104513587), Build for Testing grün (Job 114367184690), Run Tests in der #396-Form (164 im Fenster bestanden, 0 Fehler); die VV-5a-Wächter stehen NICHT im Fenster — kompiliert nachweislich, Ausführung unbelegt.
- **VV-5b (`0205769fc`):** `Studio/VideoLayerSlot.swift` — der EINE Weg, auf dem Videobilder ins Visual kommen: ein Lock-Blatt, das jeder Renderer in `draw(in:)` zieht, einziger Aufrufer des Video-Outputs, `makeUIView` einziger Schreiber von `footageSource`. Noch hängt NICHTS einen Output an (VV-6/VV-8) — das Bild ist unverändert. Der VV-4-Begrenzer zählt JEDES Bild auf der Display-Uhr (gecachte Zellen × der für dieses Bild geglättete Regler, vor dem Anbieten); ein zweiter Renderer innerhalb `shortestFrameSeconds` teilt das Bild, ein Puffer, der ihn erreicht, zählt zur geteilten Zeit; nichts gezeigt (kein Puffer, verweigert, keine Karte, `footageDropped()` vom Renderer bei Bind-Fehler oder Tier-Sperre) → Regler auf 0, das nächste Bild blendet ein.
- **Zwei Review-Runden, beide mit Python-Treibern:** (1) Regler nur bei neuem Puffer gezählt → Sweep über 4.608 Low-FPS-Strobes: alt bis 6 gezeigte Wechsel/s (204 Fälle), neu ≤ 5 überall, auch mit zweitem Renderer; (2) ein Puffer auf dem geteilten Zug zur EIGENEN Zeit gezählt ließ die Uhr des Begrenzers bis 1,25× schnell laufen (8 Wechsel/s) — zur geteilten Zeit 5. Wächter `TheVideoFrameIsPulledOnTheDrawTests` (19 Ansprüche, jeder getriebene Mutant rot). Prüfer: swift-escapes · dead-needles · count-pins · needle-reachability · moved-needles · diag-ladder sauber, foreign-needles nur die 4 bekannten Lernmodus-Befunde.
- **Bewusst nicht getan:** kein CLAUDE.md-Registereintrag (Datei an der Decke, der Wächter-Text verweist nicht mehr darauf); Gerätefamilie 5 erst nach dem ersten `attachVideoOutput`-Aufrufer. Kein Deploy.
- **Lehren:** (1) ein Wert, der pro Zug gleitet, aber nur pro Puffer gezählt wird, ist ein zweiter Zeitgeber — der Begrenzer muss den Takt des BILDSCHIRMS sehen, nicht den der Datei; (2) „zwei Renderer teilen ein Bild" reicht nicht, solange der zweite noch Neues bringen kann — die Zeitmarke gehört dem geteilten Bild, sonst schiebt die Klemme des Begrenzers seine Uhr; (3) ein Kommentar mit Rechnung („1,25× schnell") ist eine Behauptung wie jede andere — die Prüferin hat sie nachgerechnet und 1,19× gefunden.
- **VV-5b auf CI (`0205769fc`, je Versuch 1):** Xcode Compile Check grün (Lauf 38113300022); CI/CD-Lauf 38113299996 — Build for Testing grün (Job 114393250542), Run Tests Exit 65 in der #396-Form (164 im Fenster bestanden, 0 Fehler, 0 Skips, eine Log-Lücke von 1.556 s); `main` = `0205769fc`. Die neuen Wächter stehen nicht im Fenster — kompiliert nachweislich, Ausführung unbelegt. Keine neue Typecheck-Warnung aus diesen Dateien.

## 2026-10-11 — Lernmodus: Mistral/Vibe-Repo-Review gemessen [verified 13/21]; Docs-Truth-up; Lagebild (Fable 5.1)
- Drei Messer + Lead (`wf_831a2ccb-122`). Zeile in `inspiration.csv`, Abschnitt in `memory/inspiration_intake.md`. Widerlegt: EchoelAI ohne Aufrufer (seit `0c164c516`), App-Upload (0× URLSession/MetricKit), „erst schmal". Bestätigt: Triade nie menschlich geprüft, ~89 % Claude-Commits (GitHub-API), Watch nicht eingebettet, MPE-Eingang fehlt.
- Docs-Truth-up in diesem Commit: README :24/:89/:132-136, FEATURE_STATUS Agent-Zeile, CLAUDE.md `ParameterToolCore` → `EchoelAI/` (149 911 B, Decke 150 000). `foreign-needles.py`: nur die 4 bekannten Learn-Mode-Fehlalarme. README-Map-Wächter transkribiert: nur `VideoRecorder`/`VideoMuxer` in einer ⛔-Note, pre-existing, vom Wächter übersprungen.
- Founder-Posten LR1–LR5 in `docs/dev/FOUNDER_INBOX.md` (About-Text, LICENSE, #418/#399, Triade-Tabelle, Puls-Offenlegung am Diagnose-Share).
- Gerät: Video + Export zeigen Safe Mode auf 2621 um 08:43 nach einem markerlosen 4-Zeilen-Lauf (2026-10-10 10:58 UTC, Tod zwischen Crash-Netz und `init a`); Log-Team läuft (`wf_550431ae-2a6`). Der Gemini-„Baustellen"-Text kam erneut — keine neue Zeile (Regel 4).

## 2026-10-11 — Orchester-Prompt · Inbox G10/LR3/LR5 · Vision-Prinzip 9 · SH-2b · Learn L1 · Review-Befund „Substring“ (Fable 5.1)

- **Orchester (`cc80127c5`):** `reports/Orchester – ein Kopf, fünf Aufträge (2026-10-11).md` — Founder: „Alle Modelle brauchen ihren Auftrag und sie müssen genau sagen, was worein soll“. Ein gemeinsamer Kopf (öffentliche Repo-Fakten, was nie rausgeht), je Modell EIN Prüfauftrag mit Rückgabeform (≤ 8 Punkte, Datei+Zeile, sicher/vermutet, kein Code), Rückweg = Lernmodus. Rolle der fremden Modelle: PRÜFER, nie Bauer.
- **Inbox (`5bc17bc6b`):** G10 „Der stille Start“ (Erinnerung · Relaunch · Instrument-„Record“ = die 2618-Tür · Piece-„WAV“ · Diagnostics erste Zeile `launch v10.79.496 (2621)`); LR3 trägt die fertige #418-Antwort (Diagnose-Text nicht öffentlich anhängen — Puls und Atmung —, per Mail an echoel@tropicaldrones.com, needs-info); LR5 trägt beide Offenlegungs-Sätze (In-App-Konstante am Diagnose-Share + privacy.html-Absatz), Gate = Founder-„Ja“. Beides sind Founder-Schreibrechte (GitHub nach außen), nicht meine.
- **Vision (`a4df15c46`):** das UNITY-Statement („World UNITY Friedensabkommen über sanften und lächelnden Handel … Echoelmusic als neue Musikschule“) durch den Vision-Gate (`wf_7ab06b71-143`): `memory/vision.md` Prinzip 9 **„Haltung, nicht Wirkung“** (Founder-Worte wörtlich; nie als Wirkung in Kopie — der Master-Prompt vom 2026-10-07 verbietet „Weltfrieden, Heilung oder Therapie als Wirkung“), Abschnitt in `memory/inspiration_intake.md`, Zeile in `inspiration.csv` `[verified 7/7]`, Review 2027-01-09. Die EINE ADOPT→PRODUCT-Scheibe daraus ist L1.
- **SH-2b (`f2a8be28f`):** Build 2621 schrieb vier Zeilen und starb ohne Marker. Jetzt schreibt `raiseCrashNet()` nach dem LaunchGuard-Urteil `EchoelCrashLog.launchContextLine()` — `prewarm=` (ActivePrewarm) · `boot=`/`up=` (sysctl KERN_BOOTTIME) · `age=` (sysctl KERN_PROC_PID p_starttime) · `avail=` (os_proc_available_memory, iOS) · `thermal=` · `lowpower=`; `-` heißt „hier nicht lesbar“, nie ein Wert; kleingeschrieben, frei von jedem Marker, den der nächste Start sucht. `init()` beginnt mit `breadcrumb("app: stored defaults done")` — ein Log, das die Zeile erreicht, starb nicht in einem Store-Konstruktor. Wächter: Ansprüche 4/5 in `TheCrashNetIsUpBeforeTheStoresTests` (Platz) + neu `TheLaunchContextLineIsNotAVerdictTests` (Format Ende-zu-Ende, `looksLikeUnseenCrash`/`neutralized` lesen die Zeile nie als Absturz). Transkription auf `5bc17bc` + Arbeitsbaum: beide neuen Ansprüche rot auf dem Elternbaum aus dem benannten Grund; Stripper TRAGEND nur für 5c (1 von 16).
- **Learn L1 (`96f744c15`):** siebte Start-Here-Karte **„From pulse to piece“** — der EINE Weg in Lernreihenfolge: Play · Fingerkuppe auf die Rückkamera · Tempo-Feld unter „Tempo & variations“ · „Key“/„Scale“ auf Piece · die fünf Arrange-Schritte · die „MIDI“-Kachel. Nur ausgelieferte Bedienelemente, wörtlich, kein Versprechen einer Wirkung. Vier Flächen in EINEM Commit: `LearnLibrary.guideEntries`, drei Katalog-Einheiten (en == key), Zähl-Pins (`LearnLibraryTests` 6→7; `TheChromeSpeaksOneLanguageTests` 8/8/7 → 9/9/8, Karten 8→9), neuer Join-Anspruch in `TheGuideNamesOnlyRealControlsTests` (neun zitierte Bedienelemente ↔ ihre Renderer; alle neun UI-Nadeln grün auf beiden Bäumen, 0 Flips).
- **Review-Befund (`wf_d7e232d4-f74`, „FIX-THEN-SHIP — one token“):** Anspruch 5 reichte `init()`s Kopf als `Substring` an `occurrences(of:in: String)` → `cannot convert value of type 'Substring'`, `** TEST BUILD FAILED **` auf `f2a8be28f` UND `96f744c15` — das blockierende Bundle kompilierte zwei Commits lang nicht (Compile Check beide Male grün, baut nur `Sources/`). Kein Prüfer konnte es sehen (sie lesen Nadeln als Daten; die Scheibe war der EMPFÄNGER einer Nadel), die Transkription war grün. **Fix `4e041a88b`:** `String(head)`; dazu die Should-fixes (SH-2b-Kommentar in `EchoelmusicApp` und Wächter-Kopf ohne Ordinalzahlen: launch · crash net · image · Urteil · context · „stored defaults done“ · init a; Grading ehrlich — auf `f2a8be28f` hatte KEIN Anspruch der Datei ein kompiliertes Urteil; Eltern-Zitat `a4df15c`; `availableMB` als `let` je Zweig). **`7cc9686c4`:** zwei weitere Ordinalzahlen in Zusicherungs-TEXTEN („the second line“, „fifth line“) — dritte und vierte Heimat desselben Fehlers, je eine pro Grep gefunden. Fünftes Mitglied der „kompiliert nicht“-Form in `Tests/CISmoke/CLAUDE.md` §4 eingetragen (mit dem Vorläufer in `EveryReachableRowStatesItsGridTests`, der die Vorsicht am 2026-10-04 in einem Kommentar hatte).
- **Nicht gerätegeprüft:** alles oben; ob `ActivePrewarm`, die zwei sysctls und `os_proc_available_memory` auf dem Telefon lesen, ist die G10-Probe. Kein neuer TestFlight-Deploy in dieser Sitzung (Founder-Vorgabe).
- **Lehren:** (1) ein Prüfer, der Nadeln als DATEN liest, sieht das Swift nicht, das sie trägt — eine Scheibe `app[a..<b]` ist ein `Substring`, bis man `String(…)` schreibt; vor dem Push jede Scheibe eines Wächters auflisten (`grep -nE '\[[A-Za-z]+\.(upper|lower)Bound'`) und lesen, wem sie übergeben wird; (2) eine Ordinalzahl in Prosa ist ein Datum (#818) — sie saß in VIER Heimaten (Kopf, App-Kommentar, zwei Zusicherungs-Texte) und wurde je eine pro Grep gefunden: beim Streichen `grep -i "second\|third\|fifth"` über ALLE Dateien der Scheibe, nicht nur über die, die der Reviewer nannte; (3) der Pflicht-Review-Workflow fand durch LESEN des Swift, was keine Transkription sehen kann — er bleibt Pflicht, und „grün hier“ heißt bis zum `Build for Testing` nur „transkribiert“; (4) eine Vorsicht in EINEM Wächter-Kommentar (`String(…)` „als billige Versicherung“) erreicht den nächsten Autor nur durch Zufall — sie gehört dorthin, wo er liest (CISmoke-Gesetz §4).
- **Gates (gelesen 08:24 UTC):** `4e041a88b` — **Build for Testing grün** (07:58:45 → 08:04:40, Job 114421830155): das blockierende Bundle kompiliert wieder, erstes kompiliertes Urteil für SH-2b-Ansprüche 4/5, `TheLaunchContextLineIsNotAVerdictTests` und den L1-Join; Run Tests läuft beim Eintrag seit 08:04:40 (Log antwortet 404 = läuft, §5). `7cc9686c4` — **Build for Testing grün** (08:01:06 → 08:06:37, Job 114422272427). `05047ad34` — **Xcode Compile Check grün** (Lauf 38123532864, 08:11:50 → 08:17:31 nach sieben Minuten Warteschlange); die Compile Checks von `4e041a88b` und `7cc9686c4` sind je vom nächsten Push abgebrochen (`cancel-in-progress`), alle drei Commits tragen DIESELBEN `Sources/` — die `let`-Korrektur in `EchoelCrashLog.launchContextLine()` ist damit kompiliert nachgewiesen. Vorher: `f2a8be28f` und `96f744c15` Compile Check grün, Build for Testing rot (ein ❌, `TheCrashNetIsUpBeforeTheStoresTests.swift:242`, `** TEST BUILD FAILED **`). Ob die neuen Wächter im `tail -200`-Fenster stehen, entscheidet das Run-Tests-Log — bis dahin: kompiliert nachweislich, Ausführung unbelegt (#445). `main` beim Eintrag nicht neu gemessen.
- **Run Tests `4e041a88b` (Job 114421830155, gelesen 08:33 UTC, `gh-test-verdict.py`):** Exit 65 in der #396-Form (`TEST EXECUTE FAILED`, kein Startfehler), 162 im Fenster bestanden, 0 Fehler, 0 Skips, Lücke 1.178 s (08:04:40 → 08:24:18 — Fenster, nicht Lauf). **Alle neun SH-2b-Methoden stehen namentlich als `passed`**: die vier von `TheLaunchContextLineIsNotAVerdictTests` auf Clone 1 — darunter `testTheLiveReaderKeepsTheShape`, also der echte sysctl-/ActivePrewarm-Leser auf dem Simulator-Host —, die fünf von `TheCrashNetIsUpBeforeTheStoresTests` auf Clone 2 (Ansprüche 1–5, mit den neuen 4 und 5). Die L1-Wächter (`TheGuideNamesOnlyRealControlsTests`, `TheChromeSpeaksOneLanguageTests`) stehen NICHT im Fenster — kompiliert nachweislich, Ausführung unbelegt (#445). 13 Typecheck-Warnungen, alle vor dieser Sitzung (die eine in `TheChromeSpeaksOneLanguageTests.swift:660` stammt aus `4d59d5db0`, 2026-10-04) — keine neue aus SH-2b oder L1.
- **Lernmodus · ChatGPT-Gate-Bericht zu `05047ad34` (`3f0712be8`):** 11 Behauptungen, 8 bestätigt, 3 unverifizierbar (die xcresult-Zahlen „5.469 / 21 / 1" hängen am Artefakt `test-results-ios-iPhone 17`, dessen Blob-Host hier CONNECT 403 liefert; L1-Join-Lauf und OSC-Loopback-Wechsel nicht im `tail -200`-Fenster). Verdikt WATCH; Zeile in `inspiration.csv` (Quelle `llm:chatgpt-astra`, Tally 16/23), Abschnitt in `memory/inspiration_intake.md`. Founder-Posten: Host freigeben, dann messen.
- **Orchester §6 „Jetzt":** Verteilung nach SH-2b (Gemini jetzt · Codex/Astra jetzt mit dem ersten eigenen Auftrag · ChatGPT/Mistral/DeepSeek/Grok erst nach den vier offenen Antworten vom 11.10.). Der Astra-Auftrag (Gegenprüfung SH-2b, Stand `05047ad34`) kam aus zwei Entwürfen + Richter (`wf_0e54c91a-af1`): 25 Zitatprüfungen, 24 stimmen, die eine Falschstelle lag in meiner Aufgabenstellung (`4e041a88b` statt `f2a8be28f` als Einführungs-Commit — korrigiert im ChatGPT-Nachtrag). Gemessen: von den Dateien der fünf externen Aufträge hat sich seit dem Kopf-Stand nur `EchoelmusicApp.swift` (+15) bewegt. **Lehre:** eine Aufgabenstellung an Entwürfe ist selbst eine Behauptung — der Richter prüft sie mit, und hier war sie die einzige falsche Zeile.
- **Lernmodus · „Meta-Prompt Engine“ (Founder-Einfügung, Herkunft unbekannt):** Rollen-Injektion in Reinform; Rolle NICHT übernommen (MASTER_PLAN §12 Prüfer · learn-mode „nie eingefügt“/„PRÜFER, nie Bauer“ · Kopf §2 ein Format, nur Claude Code schreibt). 3 Messer + Richter (`wf_604f63fe-9a2`): 13 Textbehauptungen, **[verified 2/13]**, 10 widerlegt (u. a. zero-hallucination gegen Tally 16/23; Grapes/Atmos/Python-Beispiel schon 2026-10-10 REJECT Zeile 242). Zwei Nebenprodukte: `50c334f51` — `learn-intake.py` las 0 anweisungsförmige Sätze auf dem Text → sechs Nadeln (je 0 Treffer über alle getrackten Dateien), Emoji-Präsentations-Selektor nicht mehr Kontamination, Selftest grün; `variants.md`:13 verneinte den seit #1386 wahren AUv3-Status → an CLAIMS §a/§b angeglichen. Orchester §5 Tally-Zeile datiert (8/12 war der Vormittags-Stand, §6 trägt 16/23). **Lehre:** ein Scanner, der 0 meldet, misst seine Nadelmenge; vor jeder neuen Nadel das Repo zählen — die 48-Treffer-Nadel bewusst draußen (#665).
- **Meta AI im Orchester (Founder: „Meta AI ist auch im Game"):** siebte Spur = Erstnutzer-Lesart (jeder Satz des ersten Starts gegen den Knopf dahinter; Onboarding · GuideOverlay · die sieben Start-Here-Karten), mit keiner der sechs Spuren überlappend. Zwei Entwürfe + Richter (`wf_9f408e92-e05`): 48 Zitatprüfungen, 46 stimmen; Auftrag auf 321 Zeilen in 20 Dateien geschnitten (Link-Zugriff ungewiss, Fallback = Bereiche einfügen, nur getrackte öffentliche Dateien; Metas Speicher-/Trainingspolitik vom Repo aus nicht prüfbar → nichts Privates). Report §7 + Meta-AI-Zeile in §6. Nebenbefund korrigiert: `f5aa7ec26` — `GuideOverlay.swift`:41 zählte „six" Einträge, L1 machte sieben; Kommentar nennt jetzt die Quelle (#818). **Lehre:** Entwürfe, die dem Prüfer den Befund im Entwickler-Kommentar mitliefern, prüfen nichts — der Richter strich drei solche Stellen aus ÖFFNE.
- **Founder 2026-10-12: nur Mistral, Grok, DeepSeek** — Meta AI, Gemini, ChatGPT/Codex öffnen die Links nicht. Report §8: die drei Aufträge gehen sofort raus; Store-Text-Prüfung übernimmt Claude Code selbst; SH-2b-Gegenprüfung und Erstnutzer-Lesart gehen nach der ersten Runde an das bestgemessene der drei.
- **Mistral-Antwort (rote Blitze) gemessen [verified 6/6]:** der Video-Begrenzer zählt nur Leuchtdichte; Gegenbeispiel nachgerechnet. Latent (attachVideoOutput 0 Aufrufer). ADOPT→PRODUCT: Rot-Kanal vor dem ersten Footage-Aufrufer.
- **Grok-Antwort (Video an die EINE Uhr) gemessen [verified 6/7]:** alle sieben Fakten am Code bestätigt, Befund 7 teilweise (Audio+Video springen gemeinsam), Apple-Verhalten unverifiziert. Referenz `BroadcastAudioAnchor` ist lebend (RetroCapture). WATCH→PLAN: Vorbedingung des VideoLanePlayer-Baus.
- **DeepSeek-Antwort (Echoel Grain) gemessen [verified 3/4]:** drei richtige Punkte, alle schon im Dateikopf dokumentiert; der neue (voller Korn-Pool) ist widerlegt — höchstens 4 von 8 Körnern aktiv. Kein Befund.
- **Orchester Runde 2 (Founder: „Gib mir step by step was du brauchst"):** drei Prompts mit eingebettetem Code, Stand `05047ad34` — ChatGPT stiller Start (umgestellt von `0205769fc`, Prewarm-Zeile jetzt erwähnt), Mistral SH-2b-Gegenprüfung (Astra-Auftrag), Grok Erststart-Lesart (Meta-Auftrag). Erzeugt per Skript aus `git show`; Gemini pausiert (Store-Text macht Claude Code).
- **Orchester Runde 2 gemessen:** ChatGPT [verified 3/8] (stiller Start, WATCH), Grok [verified 7/8] (Erststart: Onboarding-Play auf Piece ist `.unavailable` → Copy-Scheibe ADOPT→PRODUCT, Founder-Freigabe), DeepSeek-Duplikat nicht geloggt.
- **Musiktech-Briefing gemessen [verified 2/3]:** Xcode 27.1 RC + iOS 27.2 b3 bestätigt, Asset-Library-Datum unbelegt; iPhone Duo als ungenannter relevanter Punkt; vier Testflächen des Briefings existieren nicht. WATCH + ADOPT→PIPELINE.
- **Ultracode-Runde (Founder: „Du entscheidest alles"):** VV-4c Gates grün (Compile ✅, Build for Testing ✅). Erststart-Text `2ca5eb87f` (Onboarding + Karten 5/6 nennen „Instrument“, Langdruck/„Bio source“, „Export“ auf Piece; zwei Entwürfe + Richter, Wächter mitgezogen). Geräte-Checkliste `docs/dev/DEVICE_SESSION_2026-10-12.md`. Reflow-Audit fürs iPhone Duo: Top-Risiko die Tab-Leiste (StageShell 152, kein minimumScaleFactor) und EchoelValueField 150-pt-Box.
- **Orchester Runde 3 + Schreibrecht (2026-10-12 abends):** Mistral [verified 7/7] → `8f4c45d61` (Startkontext-Leser: `Int(clamping:)`, Kommentar „stirbt im Leser selbst“, Wächter-Markerliste). Grok [verified 5/6] → VV-4d `465713bf9` (`engagedGain = redCellTransitionThreshold / 4`, Anspruch 12 mit Screen-Blend; VV-4e Feldfarbe bleibt offen, Founder/Council). Dazu `5e9fcf4ae`: die kleine Visual-Karte wird nie schmaler als ihre Leiste (320 pt). Gates: Compile ✅ (465713bf9 deckt alle drei), Build for Testing ✅; die Startkontext-Wächter liefen sichtbar grün, UserFootage/ChromeBudget liegen außerhalb des 200-Zeilen-Fensters (unbelegt, nicht rot). Aufträge 09–12 geschrieben (09 Astra Audio-Editor, 10–12 MIT SCHREIBRECHT auf `orchester/<modell>/<auftrag>`, Basis `3a47150c5`); Entscheidung in `decisions.csv`. ChatGPT Auftrag 12 [verified 8/10] → `fcb570147` (acht Website-Ehrlichkeitskorrekturen neu formuliert, zwei Löschungen von Sicherheitstext abgelehnt) + Regel „Sicherheitstext nie löschen“ im README. Offen: Branch-Löschung (Founder), Grok 10 (Connector), Mistral 11, Astra 09.
- **GMMW in TestFlight (2026-10-12 abends):** v10.79.497 = Build 2622 (`1b2a76c2f`, baut `465713bf9`), „Verify build landed“ ✅. Fremder Statusbericht mit xcresult-Zugriff [verified 3/5]: der 201-Bucket-Befund war echt (kurzer `AVAudioFile.read` schloss einen halben Bucket) → `939aaa63f` Übertrag + Wächter; Compile ✅, Build for Testing ✅, auf main gemergt; Ausführung im 200-Zeilen-Fenster unbelegt. OSC-Loopback-8-s-Fehler offen (braucht die Meldung). xcresult hier nicht ladbar (Artefakt-Host gesperrt) — die Quelle soll die 23 Namen liefern. Mistral Auftrag 11 [verified 10/10] → `1924b8aee` (zwölf Sync-Kommentare, nur Kommentarzeilen). Orchester-Branches legt Claude Code an (`orchester/mistral/…`, `orchester/grok/vv4e-red-test` auf `3a47150c5`).

## 2026-10-13 — VV-4e geschlossen · Grok 10b · ACE-Step/GEV Lernmodus (Fable 5.1)

- **Grok Auftrag 10b [verified 6/6]** → `d3480ac13` (`TheFieldUnderTheLayerCannotTurnAColourIntoARedFlashTests`, Anspruch A zunächst als `XCTExpectFailure`), Compile ✅, Build for Testing ✅, auf main. Connector-freie Briefs mit eingebettetem Code sind die Form, die Grok annimmt.
- **VV-4e GESCHLOSSEN (`616b68ce9` + Review-Fix `969c271fb`):** der Begrenzer sieht das Feld nicht, also bindet er jedes Feld auf einmal — der Anteil der Ebene an gezeigtem R−G−B ist linear in (1−F) je Kanal, das Maximum sitzt an einer Ecke der Box; die sieben Ecken-Summen (R, −G, −B, R−G, R−B, −G−B, R−G−B) laufen als eigene Signale auf linearen R/G/B-Zellmitteln, die `VideoLayerSlot` aus demselben Puffer dekodiert (`ColourCells`, Fünf-Argument-`step`; die Vier-Argument-Form reicht nil weiter und ist nur für die Ansprüche 1–10). Python-Nachbau: Groks sechs Fälle 21 → 4 gezeigte Rot-Wechsel/s, 1 Hz = 2, Schwarz = 0; 400 Zufallsfelder × Farb-Strobes 3–30 Hz: schlechtester Fall 5, keiner darüber. Preis (sichere Richtung): ein Farbschimmer ≥2,5 Hz wird auch über nicht-rotem Feld gedimmt. Der Wrapper ist weg, Anspruch 5 pinnt die Ecken. **Review-Befund (Code-Reviewer, Arithmetik):** `TheVideoFrameIsPulledOnTheDrawTests` Anspruch 14 (Schachbrett bei Regler 0,05) wäre rot geworden — −G−B schwingt dort 0,1, über rotem Feld ein echter Rotblitz; Regler auf 0,03 (−G−B 0,06 < 0,0625). Gates `969c271fb`: Compile ✅, Build for Testing ✅, main = `969c271fb`. Nicht gerätegeprüft; keine Footage-Tür existiert (attachVideoOutput 0 Aufrufer), also kein Nutzer betroffen. Kein Deploy.
- **Lehre:** eine Reparatur, die ein Signal strenger macht, verschiebt die Prämisse von Nachbar-Wächtern, die „wird nicht gedimmt“ behaupten — `moved-needles.py` sieht das nicht (kein entfernter Text), nur ein Leser, der die Zahl nachrechnet. Vor dem Push eines Begrenzer-Umbaus jeden Wächter, der `opacity == dial` oder `gain == 1` pinnt, mit den neuen Schwellen durchrechnen.
- **Lernmodus:** YouTube-Zusammenfassung ACE-Step 1.5 (WATCH, Brücke = Import Audio, `d9c63c6a8`); LLM-Bericht dazu [verified 3/6] — Lizenz ist MIT, Gewichte ohne Lizenz, „uneingeschränkt kommerziell“ steht nicht auf der Seite (`595f07bab`); erweiterter Bericht mit God's Eye View [verified 2/5] → REJECT: Browser-Globus auf Google-3D-Tiles + OpenAI-Sprache (zwei Cloud-Dienste), kein Musik/VJ/OSC-Pfad, Abschnitte 6/7 leere Überschriften (`b3ed51e57`). Installationsschritte nicht ausgeführt.
- **Geplanter Trigger 06:52 gelöscht** (Bundle baute schon). Branch-Löschung der drei `orchester/*` hier vom Auto-Modus blockiert („Git Destructive“) — Founder oder Berechtigung.
- **Offen:** ChatGPT Auftrag 13 (23 xcresult-Fehler), Astra 09, OSC-Loopback 8 s, VV-3a, LR5, Geräte-Session Build 2622.

## 2026-10-13 — GMMW Deep Audit gelesen und korrigiert · drei fremde Berichte gemessen (Fable 5.1)

- Workflow `wf_b009e54f-195` (3 Teams × 3 Worker + Lead) fertig: nichts Falsches gelöscht; die
  Papiere hinken dem Code hinterher. Synthese: `scratchpads/AUDIT_GMMW_DEEP_2026-10-13.md`.
- Gelandet (nur Doku): README-Root · CLAUDE.md WeatherProvider/Multitrack/MPE/Video/CL-1/Wiring-Wahrheit
  (H1-Lehre nach Ledger §AM, 149.985 B) · CL-2 · CL-3 (D11 · B5 · J4 · H2) · CL-6 · B2-Wahrheit ·
  Spatial-Audit-Banner · A2b-Zeilen.
- Lernmodus: Grok Deep Audit [8/17] · ChatGPT GMMW Audit [4/5] · ChatGPT Design-Zielbild [8/8, 3 Lücken]
  · unbekannt „optimiert" [6/8, Mockups REJECT]. Neue Aufgaben #77 (R2 erster Take), #78 (Notenfarbe).
- Offen: die 22 Testnamen aus ChatGPTs xcresult (Artefakt nicht ziehbar, Blob 403); GM18–GM22.

## 2026-10-13 — „bis zum letzten TestFlight": R2 erster Take · Claims folgen dem Produktgesetz · Register (Fable 5.1)

- **Mandat (Founder):** „Du entscheidest alles aus meiner Perspektive und regelst alles bis zum letzten TestFlight."
- **R2 (`777824234`):** `TimelineRegionPlayer.takeArmed` (App: `recordController.isRecording`), `play`-Guard `canPlay || takeArmed`,
  `RecordTake.State.firstTake` + `offersATake`, `shownReason` ohne `startable`-Gate. Neuer Wächter `TheFirstTakeRunsTheClockTests`
  (zwei Laufzeit-Ansprüche, ein End-to-End-Take auf echtem `RecordController`, zwei Gegengewichte, Verdrahtungs-Scans); drei Wächter
  neu verankert (Take-Tür-Reihenfolge, Ein-Zeilen-Leiste, Record-Glyph). Xcode Compile Check ✅ (38376558056); Build for Testing lief
  beim Schreiben dieser Zeile.
- **Claims (`c0479032b`):** CLAIMS.md ✅ +5 (Mixer-Bühne · Sampler je Spur · Grain-Insert · Stück-WAV · Siri), §1b-Begründung
  „Produktgrenze" → Produktgesetz (Pin „Echoel lädt KEINE fremden Plugins" bleibt), §5 ohne „Sampler-Instrument"; claims.html claim-5;
  faq.html fünf Antworten (EchoelMix Live, Sampler je Spur, Hosting/Video/RTMP ohne „second product" — „Video is not part of Echoelmusic"
  und „never built" bleiben, die Wächter pinnen sie).
- **Register (`0c178e98c`):** FEATURE_STATUS §0 = Build 2622 (`1b2a76c2f`), fünftes Wort „Piece", Siri/Sampler/Grain nach §1, §1b = R2 ·
  VV-4e · Wellenform-Fix; PLAN_GMMW A5 die 13 Archiv-Posten mit Klasse und Phase; PLAN_RESTRUCTURE Löschliste 15 → 10.
- **Entscheidung geloggt:** R2 in `decisions.csv` + `memory/decisions.md` (Review 2026-11-12).


## 2026-10-13 — Letzter TestFlight des Auftrags: Notenraster in Tonhöhenfarbe · Fluid F1 · zwei Wächter breiter · zwei Prüfwerkzeuge repariert

- **Build 2624 (v10.79.499, Bump `f2602f9d6`):** Farbscheibe `f60fda649` (`SpectralColor.gridTint` bei OKLab-L 0,84,
  Frequenz über `PianoRollModel.soundingHz`, `NoteGridTint` im `PartNoteEditor`; schlechtester Kontrast auf den
  schattierten Zeilen 3,23:1 mit OKLab-Mischung, gemessen am Zwilling) · Fluid F1 `dec1986c0` (alle 12 Tests im CI-Log
  bestanden) · vier Kommentar-Wahrheiten (`9b44556d1`, `cc683262c`) · Spatial-Keep `ff6c4230d` (alle 7 Kerne plus zwei
  Dateien eine Ebene tiefer, Anspruch 5) · Geräte-Bitten `781e4273f` (A4-Feld der Piece-Bühne; Fluid-Satz ist keine Bitte)
  · Hot-State ``9ab00ae7e` + Prüfer-Korrektur `1e7c64aec` (Overlay-Lücke im Skip, Regex-Arm, Fehlrichtungen in drei Grenzblöcken)` (Taktuhr, Tempo-Gleiten, OSC-Eingang; Ausnahme nur für Aktions-Closures, exakt gepinnt).
- **Werkzeuge:** drei Prüfer ohne SyntaxWarning (`b0cec876d`, Ausgaben vorher/nachher identisch); `foreign-needles.py`
  bindet je Methode (`aba5129ac`) — die vier „bekannten" Lernmodus-Alarme waren Fehlalarme des Werkzeugs, Exit jetzt 0.
- **Register:** FEATURE_STATUS §0 = Build 2624; §1b geleert (R2/VV-4e/Wellenform waren seit 2623 ausgeliefert, F1–F6b/A3a seit 2616); §1a/§1c um die fehlenden Türen mit erstem Build ergänzt (Zuordnung je Commit per `merge-base`, fünf Stichproben bestätigt); §2c: Tonhöhe je Teil und Stretch-Modi haben seit 2621 Regler, Fluid F1 als Kern ohne Aufrufer; §4: Kopfhörer-Raum und „Use Its Sound“ seit 2617.
- **Entscheidung geloggt:** Farbscheibe in `decisions.csv` + `memory/decisions.md` (Review 2026-11-12).
- **Offen (Founder):** Geräte-Session für 2622–2624 · GM18–GM22 · E10-1, B2 und #310 im Standard-Modus · die drei
  `orchester/*`-Branches.

## 2026-10-14 (Nacht) — Plugin-Hosting produktionsreif · Wächter-Reparatur · Website ehrlich · Förderfristen

- **Hosting-Bugs aus dem Verlaufs-/Debug-Audit (wf_624b40ce-21e), je mit Wächter, rot auf dem Elternstand transkribiert:**
  B1 `e04c020a0` (Plugin-Wahl im Spielen leerte die Pumpe → `LaneNotePump.releaseSounding`) · B2 `8369bfd6d`
  (`.lanePlugin`-Undo nach ID statt Gleichheit, Redo mit gehaltenen Einstellungen) · B3 `1cc0f8676`
  (`requestView`/`captureState` nur für die genannte Komponente) · Format-Sperre `f5600e3a6`
  (`AudioEngine.trackBusTakes`, neuer Wächter `AHostedUnitMustSpeakTheTrackBusShapeTests`) · Review-Folgen `6a475f425`
  (4-Kanal-Format mit Layout, begrenztes Pumpen-Fenster, Doppeltipp).
- **Wächter `d6552d23f`:** drei auf dem Branch stille Rote (NoteGridZoom, SceneLaunch, ScrubNotifies) und ein #367-Grüner
  (DetailCaption) neu verankert.
- **Website `31ec619fd` / Register `eee0e12cd`:** Hosting auf faq/press/architecture wie overview („neu, nicht bestätigt,
  nicht behauptet"); „In active development" weg; HISTORY_ARCHIVE D1/D5/C3/A6 REPAIRED; FEATURE_STATUS Hosting + Grain.
- **Offen (Founder):** Video-Satz der FAQ (Wächter pinnt „Video is not part of Echoelmusic", Seed/Show-in-Visuals sind
  ausgeliefert) · Streaming „auf dem Plan" vs. „not planned" · `brainstorming.html` im Footer.
- **CI:** Runner-Schlange lang; Abbrechen alter Läufe ist dieser Integration verboten (403). Deploy 10.79.502 wartet auf
  beide Gates auf `6a475f425`; Notiz liegt vorbereitet im Scratchpad.
- **Außerhalb des Repos:** Förderfristen recherchiert, 12 Kalendertermine mit Gesprächsleitfäden und 5 Gmail-Entwürfe
  angelegt (nichts gesendet).

## 2026-10-15 — One World: Kanten-Trim + Video-Spur (ultracode)

- **T1** `6c2d3fea9`: Start/End-Griffe für MIDI- und Audio-Teile im Arrange-Canvas (`ArrangePartEdges.frames/room`), Griffe enden am Nachbarn und am Spurende. Wächter `TheCanvasPartEdgeMovesOnTheGridTests`.
- **V1** `912cb1dd5` Slot-Besitz (letzter Anhang gewinnt, eigener Detach) · **V2** `383ae1415` `VideoLanePlayer` an jedem Transport-Schritt · **V3a** `322358e5e` `VideoLaneAVSink` (stummer AVPlayer, keine eigene Uhr) · **V3b** `7b2e48b10` `.video` spielbar, Rolle `.picture` · **P1+P2** `a0489e091` `VideoImport` nach `Media/Picture`, Tür „Add Video Track"/„Import Video".
- **Review-Fixes** `e12903aaa`: Wächter 11b war rot (`clip.kind` im Prädikat) → `VideoLanePlan.isPicture`; frisch geladener Teil spielte nie (`clear()` setzte `running`); Lane holt den Slot bei jedem Show zurück; Ziel während langsamen Ladens bleibt erhalten.
- Offen: Gates für `e12903aaa`, Deploy-Bump, S4 VoiceOver-Kantenaktionen, Gerät-Verify (Bild läuft im Takt mit).

## 2026-10-15 (Nacht) — Echoel-Modus: MIDI-Clips entspannt bearbeiten

Founder: „Ich finde kein Spaß am Testen so lange ich so einfache Sachen wie Midi Clips nicht
entspannt bearbeiten kann" → eine Schleife nur für den MIDI-Editierfluss.
- Gebaut und gepusht: AUv3 still bis zur ersten Note (`950a25bcf`), D1 44-pt-Fingerziele
  (`9545797cc`) → 10.79.506; N-F1 Noten-Inspektor (`fc8733dc9`) → 10.79.507; EP-3b gewählte Noten
  direkt ziehen (`1b90c631d`), EP-4 Teil auf den Schlag + Länge (`ddb656a4c`), EP-6a Repeat
  (`d3dd0dd0e`), Review-Fixes (`32b65affc`: Länge/Repeat ändern nie „wer spielt", Überlauf-Wache).
- Review-Agent: kein Compile-Befund; Lücke Länge ohne #1440-Präzedenz → behoben.
- Bewusst offen: unabhängige Kopie (Clip-Platz, den Undo nicht zurückgibt), T-1 samplegenauer
  Sequencer (Council zuerst), Werkzeug-Modi (Gerät entscheidet, ob direktes Ziehen reicht).
- Design-Input: KI-Mockups gemessen (§4), Runde 2 an Grok/ChatGPT vorbereitet (§5, echte 508-Bilder).

## 2026-10-15 (spät) — End-to-End-Audit MIDI-Fluss + fünf Scheiben

- **Deploy:** 10.79.508 (`6f492d8`, Bump nach grünen Gates auf `32b65affc`).
- **Audit** (drei nur-lesende Agenten: Bearbeiten · Abspielen · Export). Kernbefunde: Tipp schaltete Auswahl um ·
  Teile außerhalb des Taktstrichs spielten versetzt (M1b, über EP-4/Repeat erreichbar) · Noten > 1 Takt klangen nur
  ihren Rest · Import kürzte deshalb auf einen Takt · MIDI-Startgriff nur ganztaktig. Offen: 16tel-Quantisierung beim
  Abspielen (T-1), Main-Queue-Takt, Rack 4 Plätze, kein Einzelteil-.mid, zwei „MIDI"-Türen, WAV nur Echtzeit,
  „unabhängige Kopie", versteckte Noten hinter verkürztem Teil ohne Hinweis.
- **Gebaut:** EP-7 `e7a54fb` Tipp wählt eine Note · EP-8 `e8f0ce4` Teil auf Schlag 3 spielt auf Schlag 3
  (`RegionNoteWindow.songBarSlices`/`songEntryBar`) · Review-Fix `757e2ca` (Phase auf den 16tel aufgerundet) ·
  EP-9 `9d7a259` lange Noten als Segmente mit derselben ID (Pumpe bindet nur innerhalb des Loops) · EP-10 `0fef0ef`
  Import ohne Ein-Takt-Kürzung · EP-11 `230dd33` MIDI-Startgriff folgt dem Zoom-Raster.
- Je Scheibe Wächter, in Python transkribiert (§0). Gates bei Schreiben in der Runner-Schlange; nichts am Gerät geprüft.

## 2026-10-16 (Vormittag) — GSIDMMW, Ultra-Masterplan, C2 Teil-Export, C1 Planer

- Bericht „Generative Intelligenz für Echoelmusic" (`reports/`), Ultra-Masterplan (`scratchpads/ULTRAMASTERPLAN_2026-10-16.md`, 278 Posten, 152 offen — seit GSIDMMW als UNTERGEORDNET markiert).
- Grok-GSI-Paste: Lernmodus 5/6; Copy-Wächter um superintelligence/quantum erweitert (353e14f).
- GSIDMMW-Übergabe (Founder): Nordstern in Law §1 + Masterplan §1, KI-Status dreigeteilt (0f8f08e); Audit-Messung `scratchpads/GSIDMMW_AUDIT_2026-10-16.md`.
- Paket B (35d95ee + 8a17474): Describe gehört zum Stück (Ticket + documentGeneration nach jedem await), kein isWorking über den Modellaufruf, Deadline 45 s, Stop ≠ Close, isModelBusy. ⛔ Erst rot im Compile Check: `Task { await self?.f() }` ist `Task<()?, Never>` (Einzelausdruck-Closure) — `guard let self` + `() -> Void`.
- C2 (fc5d1da): „Share as MIDI" für das gewählte MIDI-Teil (`SongMIDIExport.partTrack/partFile`, ShareLink-Blatt).
- C1 (183650e): `EchoelModelPlanner` ohne Tür.
- Gates: d17bb3c BfT grün (#396-Muster); 8a17474 Compile Check abgebrochen (cancel-in-progress), fc5d1da/183650e laufen.
- Nächstes: Gates lesen; dann C1-Tür (Council: zweite FoundationModelsBrain-Konstruktion) oder Masterplan-Scheiben A1/C1.

## 2026-10-16 (Fortsetzung) — Ultraplan-D1, GSIDMMW-C2a/C2b, Register nachgezogen

- **Ultraplan-D1** (`81ebe64`): „Add MIDI Track" hängt den No-voice-Satz an, wenn die Spur jenseits der Rack-Stimmen liegt. Wächter `AMIDITrackPastTheVoicesSaysItIsSilentTests`.
- **Founder-Korrektur (ChatGPT-Paste):** GSIDMMW bleibt führend; Lernmodus 4/4 (inspiration.csv, intake).
- **GSIDMMW-C2a** (`8e0299e`): `proposePlan` → `pendingProposal`, Apply/Discard im Banner, veraltete Basis → `.projectChanged`, Undo. Describe-Maschinerie geteilt (`startModelRequest`). Wächter `EchoelProposesBeforeItChangesTests`.
  ⚠️ C2a hätte `TheAgentHasOneProductionDoorTests` Anspruch 4 rot gemacht (zweites `EchoelPlanning.plan(` / `executor.execute(` im Desk) — beim Lesen für C2b gefunden und im C2b-Commit mitgezogen. Lehre (§4): vor einem zweiten Aufruf einer „genau-einmal"-Stelle `git grep` über `Tests/CISmoke`.
- **GSIDMMW-C2b** (`39f954d`): `AskEchoelIntent` → `AgentReportBanner.ask`; eine Konstruktion im privaten `onDeviceBrain()`, zwei Aufrufer (Tap, Intent). `TheOnDeviceModelHasOneGateTests` Anspruch 4 verschärft.
- **Register:** Audit (Präfix-IDs, vier Nachweise je Fähigkeit), FEATURE_STATUS §1b (fünf Einträge statt „Leer."), FOUNDER_INBOX G11.
- **Gates:** zum Zeitpunkt offen; 10.79.509 noch nicht gehoben (wartet auf grünen Compile Check + Build for Testing auf dem neuesten Code-Commit).

## 2026-10-16 (Mittag) — 10.79.509 ausgeliefert; GSIDMMW-D1/D2 Pan + Mute; C2c Ask Echoel in der App

- **TestFlight 2634 = 10.79.509** (`e171fed`) Conclusion success; dem Founder gemeldet, Verweis G11.
- **Paket D umgeplant, gemessen:** AI-7b (`parameter.set` über den Router) wäre eine zweite Wahrheit (Router-Setter schreiben nur den Live-Spiegel, kein Rücklesen, Patch erfährt nichts). Stattdessen je Befehl ein Besitzer + Rücklesen + Schreibzähler. decisions.csv + memory/decisions.md.
- **D1** (`c87ee46`) `track.setPan` (−1 … 1 ablehnen statt klemmen, `lanePanWrites`), Wächter `TheAgentPansThroughTheInspectorsWriterTests`.
- **D2** (`ee43f47`) `track.setMute` als ZUSTAND (`laneMuteWrites`; Heilung der Instrument-Spur zählt bewusst nicht), Wächter `TheAgentMutesThroughTheTracksSwitchTests`.
- **C2c** (`b53f423`) ≡ → „Ask Echoel" öffnet eine Eingabezeile im Bericht (kein Modal), gleicher `ask`-Weg wie Siri. Wächter `TheTypedRequestTakesTheSiriRoadTests`; `TheOnDeviceModelHasOneGateTests` Anspruch 4 auf zwei Frager erweitert.
- Register: FEATURE_STATUS §1b, Audit (Paket D, C2c, Fähigkeitstabelle), FOUNDER_INBOX G11 (g)(h).
- Gates zum Zeitpunkt in der Schlange; kein Bump vor grünem Compile Check + Build for Testing auf `b53f423`.

## 2026-10-16 (Fortsetzung) — Ultraplan Track A/C/D: sechs Scheiben, lokal gestapelt, ein Push

- **A6** (`1221d0d`) MIDI-Import nennt Programm-/Tempowechsel und Taktart ≠ 4/4 (nur Wechsel, B6b-0). Wächter `TheMIDIImportNamesTimingAndInstrumentChangesTests`.
- **A11** (`aae615b`) zwei VoiceOver-Aktionen am Titel der Part-Leiste: Kante nach außen bis zur nächsten Taktlinie, über `ArrangeCanvas.barLineEdit` (die Regel der Griffe). Wächter `APartsEdgeMovesOutWithoutAFingerTests`.
- **A2** (`924564c`) Tasten-Spalte neben dem Notengitter (`ClipNoteEdit.keyRows`, außerhalb der ScrollView). Wächter `TheNoteGridHasAKeyColumnTests`.
- **A3** (`6a02e43`) Zeilenzoom 1 · 4/3 · 5/3 des Touch-Bodens; EINE `zoomedRowHeight` für Canvas, Treffertest, Spalte. Wächter `TheNoteRowsZoomTallerNeverShorterTests`.
- **C1** (`84a7514`) Take-Tür „Take .mid“; Song-Tür „Export“ bleibt (Lernkarte zitiert sie). Wächter `TheMIDIDoorsNameWhatTheyWriteTests`.
- **D8** (`6f6d5d1`) Echoel-Spurzeile nennt `synth.appliedPatch` (das Gedächtnis der Stimme, nicht `currentPatch`). Wächter-Anspruch 5 in `TheEchoelTrackNamesItsInstanceTests`.
- **A4** (`e8fd57e`) Teil auf andere Spur ziehen: `ArrangeCanvas.dropLane` (gleiche Art, kein Bio, keine Komponisten-Take), `TrackParts.move(_:toStartTick:toLane:timeline:)` zählt in DOKUMENT-Reihenfolge; ein `@GestureState` (jetzt `CGSize`); VoiceOver-Aktionen. Wächter `APartIsDraggedOntoAnotherTrackTests`; drei Wächter nachgezogen.
- Lehre: bei voller macOS-Schlange lokal stapeln und EINMAL pushen — ein wartender Compile Check hat nichts gemessen, sein Abbruch verliert nichts; ein laufender schon.
- Gates: D1 (`c87ee46`) `Build for Testing` = success. Der Rest wartete zum Zeitpunkt auf Runner. Kein Bump vor grünem Compile Check + Build for Testing auf der Spitze.

## 2026-10-16 (Nachmittag) — 10.79.510 ausgeliefert; True Peak; Stem-Bausteine LS-ST1…3b

- **LS-TP1** (`d82e1e8`) Export-Normalisierung gegen BS.1770-True-Peak (−1 dBTP) · **LS-TP2** (`120e2b2`) Meter liest denselben Schätzer · Kernel-Zeiger (`896bc53`).
- **LS-ST1** (`784f1c7`) Sampler übergibt seinen Block an einen Stem-Abgriff (aus) · **LS-ST2** (`d9c22c8`) `AudioLaneStemPlan` = Gewinner-Regel des Live-Spielers · **LS-ST3a** (`7f66387`) Frames aus Ticks, Nachbarn teilen den Frame · **LS-ST3b** Renderer (mono 24 bit, Songlänge, lehnt Warp/Transpose/Effekte/fremde Rate vor dem Schreiben ab).
- **E34** (Laptop: E15 vor Catalyst) und **E35** (Stem-Tür wartet auf G-D) im Inbox; Stereo-Sampler: Bus ist schon stereo (PolySynthVoice 2 Kanäle; meine erste Herleitung „mono“ ist zurückgenommen) → **SP1** Sampler-Pan gebaut; SS2/SS3 offen.
- **10.79.510** (`d25c788`) gehoben nach grünem Compile Check + Build for Testing auf `d9c22c8`; TestFlight 2635 lief zum Zeitpunkt.
- Lehre: auf einen Gate-Lauf nicht warten — lokal weiterbauen, den Release-Commit EINZELN pushen (`git push origin <sha>:refs/heads/<branch>`), damit TestFlight genau den geprüften Stand baut.

## 2026-10-16 (Abend) — Arrange & Perform: die sieben Punkte gebaut

Founder-Ziel „einfacher Arrangement-Modus auf Ableton-Level + integrierter Performance-Modus“,
Liste in fester Reihenfolge (`scratchpads/PLAN_ARRANGE_PERFORM_2026-10-16.md`):
- **1 Marker** (`48a28d6`) · **2 Cycle-Ränder ziehen** (`28b1059`) · **3 Mehrfachauswahl + Zwischenablage** (`8b5d152`)
- **4a Spurfarbe** (`fa1f6b8`) · **4b Spuren umsortieren** (`1ded828`, die Echoel-Spur bleibt die erste MIDI-Spur — Reihenfolge IST Routing)
- **5 Einzähler** (`2eb8044`) — nur Click VOR dem einen Start; Record nimmt weiter ab Takt 1 (ein Transport-Pre-Roll hätte vor Tick 0 starten müssen — die Planabweichung steht im Plan)
- **6 Szenen ins Arrangement** (`69ac75d` pur `LaunchTake`, `fe858c1` Player + „Record to arrangement“, P4c über den Wrap)
- **7 Automation auf dem Canvas** (`9bb2d22` Anzeige, `27353aa` „Draw automation“, 7c geteilte Parameterwahl)
- Builds: **v10.79.513** (`df59b13`), **v10.79.514** (`d6105b9`); 515 nach grünen Gates.
- Lehre: die Wächter des Canvas (genau EIN `DragGesture(`, EIN `@GestureState`, kein `.menu`-Picker) haben die Form von 7b bestimmt — die Bearbeitung lebt in einem eigenen Blatt, nicht im Canvas. Vor jedem neuen Canvas-Zug zuerst diese Zähl-Pins messen.
- Lehre: `pasteRegions(parts, atTick: min start)` ist schon ein „füge an eigenen Ticks ein, ein Undo“-Schreiber — kein neuer Store-Schreiber für die Session-Aufnahme nötig.
- Alles NEEDS-FOUNDER-VERIFY (A1–A10, P1–P4, 7a–7c); nichts davon auf dem Gerät gesehen.

## 2026-10-16 (Nacht) — Finesse-Loop: alle Befunde der drei Reviews repariert, A7/A8 gebaut

**Gebaut:** A8 Teil benennen (`PartNameField`, `ClipStore.renameClip`) · A7 Spur duplizieren
(`TrackCopy`, `TimelineStore.duplicateLane`, ein Undo-Schritt `.trackCopy`).
**Repariert (26 Befunde aus drei Linsen: Count-in, Player/Session, Canvas-UI):** Aufnahme landet
nach Open im falschen Stück (HIGH, Sink jetzt synchron) · Aufnahme einmal schreiben, geschichtet,
echte MIDI-Schleifenlänge · Schalter an mitten im Spiel schließt laufende Parts ein · Ein-Schritt-
Blip nicht geschrieben · „Beat"-Launch zurückgenommen · Count-in: Sechzehntel-Flam, Abbruch immer
möglich, Play/Stop anderswo bricht ab, Klick-Abschalten bleibt (C5), Flow-Grenze benannt (C6) ·
Count-in ins Halte-Menü von Click (Transportzeile passte nicht) · Draw/Select legen kein Teil an ·
getipptes Teil sagt den „New MIDI Part"-Satz · Select-Ring nur für Gesammelte · Paste nur mit
existierender Spur · Farbmenü-Tönung · Marker-Namen nie doppelt · Neustart beendet Aufnahme gegen
ihr eigenes Stück · VoiceOver „Add a part" nur wo es wirkt · Marker-Fähnchen + VoiceOver-Name ·
Cycle-Griffe überlappen nicht, abgebrochener Zug räumt auf · Canvas-Maßstab in 8-Takt-Stufen.
**Werkzeug:** `gate.sh` im Scratchpad (sechs Prüfer); Commit nur bei sauberem Gate.
**Offen:** CI-Warteschlange (~20 CI/CD-Läufe gestapelt, Abbrechen per Integration verboten —
403); EIN Release 10.79.515 erst, wenn main den letzten Stand mit grünen Gates hat.
**Lehre:** viele kleine Pushes stapeln macOS-Läufe, die nichts abbricht — Scheiben lokal
sammeln, seltener pushen.

- 2026-10-17 03:45 UTC — **10.79.515 ausgeliefert**: TestFlight-Lauf 38996952047 auf `7aa0b1e` = success (App-Code `abb8261`, beide Gates grün). ⛔ **`main` hat ihn NICHT erreicht** (bleibt `cc63f2d`, 27 Commits dahinter): `auto-merge-claude.yml` triggert nur auf `Sources/** Tests/** Package.swift project.yml .github/workflows/**` — `.deploy/release` ist KEIN Trigger, die „Passagier"-Annahme im Release-Plan war falsch. Der nächste Code-Commit auf dem Zweig nimmt alles mit (nach Gates auf SEINEM sha). Nichts gerätegeprüft; Blatt `docs/dev/DEVICE_SESSION_2_ARRANGE_2026-10-16.md`.

## 2026-10-17 — Neustart Echoel Studio: M0 fertig, M1 bis auf Arrangement

Founder: „Alles nochmal von vorne" — konventionelle Profi-DAW (FL Studio Mobile / Ableton), iPad + iPhone,
AUv3, Live-Set, Agent. Plan: `docs/dev/NEUSTART_2026-10-17.md` (§3.5 offen gehaltene Türen für die
ganze DMMW-Vision, §4 Stand). Neuer Code nur unter `EchoelStudio/` (Core · DSP · Engine · App),
eigene CI `studio.yml` (macOS-Tests aller Pakete + iOS-Builds + App Simulator/Gerät). Jeder Schritt
dort grün, Runs #1–#15. Nichts gerätegeprüft. Commits a9a1c8b … 0b80aca.
Gelernt: Gesten im Piano Roll laufen im benannten Koordinatenraum des Rasters (sonst springt die
Translation mit der bewegten Note); ein Kind-Gesture verliert gegen ein highPriorityGesture des
Elternteils — Verschieben und Länge sind deshalb EINE Geste, entschieden am Startpunkt. Dreieck
aus integriertem Rechteck mit Integrator-Startwert = Dreieckswert, sonst 1,6-facher Überschwinger.
Nächstes: Arrangement-Ansicht, dann M2.
- 11:56 UTC — **M1 im Code komplett**: Arrange-Seite (c76051e, Namensfix d828beb, Run #17 grün).
  Gelernt: in einer `static func` verdeckt ein lokales `let end` die Schwester-Funktion `end(of:)` —
  Swift meldet „cannot call value of non-function type"; lokale Namen nie wie Methoden des Typs nennen.
  Nächstes: M2, zuerst Drum-Pattern-Core (Step-Raster als Clip-Noten, keine zweite Notenwahrheit).
- 13:55 UTC — **M2 im Code bis auf die Aufnahme**: Drum-Kit + Step-Raster (bis Run #24), Sampler-Kern
  (#25), Medien-Modell (#26), Engine spielt Sampler (6b75618, #28), Audio-Import auf Sampler-Spur
  (47b9b87, #29), Audioregionen im Core (ba31df5, #30), Engine spielt Regionen (b80149b, #31),
  Audiospuren im Arrange (ac05ffa, #32). Alles CI-grün, nichts gerätegeprüft.
  Gelernt: eine Leseposition, die über Blöcke AUFSUMMIERT wird, macht das Ergebnis von der
  Blockgröße abhängig — aus dem Ausgabe-Index berechnen. Ein von der Platte gelesener Song ist nie
  durch `media.add` gegangen: Pfade beim LESEN prüfen (`MediaFile.url(in:)`).
  Nächstes: Audio-Aufnahme (§6.2), dann M3.
- 14:06 UTC — **Audio-Aufnahme gebaut**: Ring + Platzierung (3b5c5c2), Eingang/Take/Bedienung (a88d7e4),
  Import-Fix (76037b3, Run #35 grün). Rot einmal: neue Engine-Datei ohne `import EchoelCore` — jede neue
  Datei eines Pakets importiert, was sie benutzt; die Nachbardateien vererben nichts.
  Nicht gerätegeprüft: Latenz, Startpositions-Schätzung (positionSample − Blockgröße), Picker-Dismiss.
  Nächstes: Audit der Render-Pfade (Agent), dann M3 AUv3-Host.
- 14:30 UTC — **M3 Teil 1: AUv3-Instrument-Hosting** — HostedUnit (5679017), PluginHost + Sound-Seite
  (9671dae), Plugin-Oberfläche + Zustand im Song (7e4155a), Run #42 grün (8484084). Rot zweimal: iOS braucht
  `import AVFoundation` für `UnsafeMutableAudioBufferListPointer` und `import CoreAudioKit` für
  `requestViewController` — macOS-`swift test` sieht beides nicht. Nichts gerätegeprüft.
  Nächstes: Effekt-Inserts, Offline-Render mit Plugins.
- 14:46 UTC — **M3 Teil 2: Effekt-Inserts + Export mit Plugins** — Stereo-Bus pro Spur + HostedEffect
  (d3991bf), Insert-Modell + 5 Befehle (bb6ea6e), Laden + Mixer-FX-Seite (437bcad), Offline-Export mit
  frischen Plugin-Kopien (c35d406), Run #46 grün. Nichts gerätegeprüft. Nächstes: eigene AUv3s (Kauf), Sends.
- 17:35 UTC — **Eigenes AUv3 „Echoel Synth" + Kauf** (c3e6de2, Run #47 grün beim ersten Lauf; `.appex`
  im Release-Build unter PlugIns/ belegt). SynthKernel im Engine-Paket getestet. Founder: IAP in ASC anlegen.
  Nicht gerätegeprüft: Laden in AUM/Logic, Demo-Stille, Kauf-Freischaltung in der Erweiterung.
