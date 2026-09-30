# FOUNDER INBOX — jede Frage genau einmal

Stand: 2026-09-30 · angelegt als Zug 7 des Interface-Audits („Ein Postfach, ein Wochenlauf, ein
Bitten-Budget", Freigabe **ja**). Gemessen am Code und an den Logs, nicht aus dem Gedächtnis.

**Wozu diese Datei.** Bis heute standen die Fragen an den Founder verstreut: als
`NEEDS-FOUNDER-VERIFY`-Marker in 234 Quell- und Testdateien, als „HOLD-FOR-FOUNDER" in
Sitzungs-Aufgaben, als Kästchen in `scratchpads/FOUNDER_DEVICE_SESSION.md`, als Zeile im
Interface-Audit-Dokument. Dieselbe Frage wurde mehrfach gestellt, und keine Sitzung wusste, ob
sie schon beantwortet war. **Ab jetzt gilt: eine Frage an den Founder steht HIER, einmal, mit
Datum — oder sie wird nicht gestellt.** Eine Antwort bekommt ein Datum und wird nie gelöscht
(eine Antwort ist ein Datum, kein Zustand, der später „aufgeräumt" werden dürfte).

## Die vier Regeln (aus dem Audit, Founder-Freigabe 2026-09-30 zu Frage 5)

1. **Fünf Geräte-Bitten je Build.** Nicht mehr. Jede sagt: was tippen, was hören oder sehen,
   ja oder nein. Sie stehen in §2 dieser Datei, nicht verstreut im Code.
2. **Ein Build je Woche** mit genau diesen fünf. Dazwischen: Reparatur und freigegebene
   Scheiben, keine neue Fläche.
3. **WIP-Limit 3 an der Geräte-Abnahme.** Höchstens drei gebaute Scheiben warten gleichzeitig
   auf ein Geräte-Urteil; die vierte wird erst gebaut, wenn eine der drei geschlossen ist.
   ⚠️ Das gilt ab heute NACH VORN. Der Altbestand ist gemessen und steht in §2 als Zahl mit dem
   Befehl daneben — er wird nicht in diese Regel hineingelogen.
4. **Familien statt Einzelbitten.** Eine Geräte-Session prüft alle Kontrast-Fragen auf einmal,
   alle Puls-Fragen auf einmal. Zwanzig Marker, eine Antwort.

**Wie eine Sitzung diese Datei benutzt.** Bevor sie den Founder fragt: `grep` hier nach dem
Thema. Steht die Frage schon, ist sie NICHT noch einmal zu stellen — nur der Stand wird
nachgeführt. Steht sie nicht, wird sie hier eingetragen (Frage · Empfehlung · warum es die
Entscheidung des Founders ist) und im Chat mit der Nummer genannt. **Messen zuerst**
(`.claude/rules/context.md` §6): eine Frage, die eine Messung beantworten könnte, gehört nicht
hierher. Fällige Entscheidungen (§4) schließt die Sitzung selbst.

**Wie der Founder antwortet.** Im Chat mit der Nummer („E7: ja"), oder direkt hier: `[ ]` → `[x]`
plus Datum. Beides ist gültig; die Sitzung trägt die Chat-Antwort dann hier nach.

---

## §1 · Entscheidungen — die vierzehn aus dem Interface-Audit, plus die offenen HOLDs

Reihenfolge wie im Audit. **Die ersten fünf sind beantwortet** („Ja zu 1–5", 2026-09-30) und
haben damit die Züge freigegeben; sechs bis vierzehn waren bis dahin gesperrt und sind **jetzt
offen**. Der Founder hat außerdem am selben Tag delegiert: „Du entscheidest alles und weißt,
dass das Design insgesamt vor allem im Vordergrund eine DMMW ist." Wo eine Frage dadurch
faktisch entschieden wurde, steht das dabei — als Delegation, nicht als Founder-Wort; ein
Widerruf ist jederzeit eine Zeile hier.

| # | Frage | Empfehlung | Stand |
|---|---|---|---|
| E1 | Umbau nach dem Audit-Plan freigeben? | Ja, Scheibe für Scheibe | **[x] Ja, 2026-09-30.** Züge 1–4 gebaut (Gates grün, Gerät offen), Zug 7 = diese Datei |
| E2 | Startet die App im Stück statt im Vollbild-Visual? | Ja: Bild als Karte über dem Stück, Vollbild ein Tipp entfernt | **[x] Ja, 2026-09-30.** Gebaut 07e3d3d67 (Seed `.small`), Wächter `TheAppOpensOnThePieceTests` |
| E3 | Generatives Instrument vom Zuhause zum Gerät auf einer Spur, neue Stücke ohne es? | Ja; Evolve bekommt einen Schalter, Standard aus | **[x] Ja, 2026-09-30 — halb gebaut.** Das Zuhause ist das Stück (34f44edd7: Bühnen-Naht „Piece · Instrument"; der Echoel bleibt MONTIERT und verdeckt, weil ein Geschwister-Switch die Musik beendete). ⚠️ OFFEN geblieben: der Echoel als Gerät AUF EINER SPUR ist WA3 (`docs/dev/ECHOELMUSIC_MASTER_PLAN.md`), und der **Evolve-Schalter ist nicht gebaut** — `evolveShouldReseed()` gibt hart `true` (`git grep -n "func evolveShouldReseed" -- Sources`) |
| E4 | Sprache: spricht die App Deutsch? | Ja, String-Katalog; Chrome zuerst (~40 Wörter), Panels danach; Glossar Stück · Spur · Teil · Szene | **[x] Ja, 2026-09-30 — Glossar-Hälfte gebaut, Übersetzung nicht begonnen.** Die Wörter sind app-weit vereinheitlicht (`docs/dev/GLOSSARY.md`, Wächter `TheChromeSpeaksOneWordPerThingTests` über 42 Dateien); `Sources/Echoelmusic/Resources/Localizable.xcstrings` existiert. **Die deutsche Chrome ist GEBAUT (e3a71486d · 86a9d4eeb · 27b37253d · 7fd4215e8 · 25bafc201, Gates offen):** Bühnen-Naht, Bereichs-Zeile, Kopf-Transport, Undo/Redo, Record, die Puls-Pille (Kurzwort + Mess-Hinweis) und ALLE Status-Leitern — MIDI ein/aus · Audio-Route · Apple Health · Leistung · Ausgabe-Kacheln · Netz-Wort (Wort · Zeile · Erklärung · VoiceOver) — gehen über `String(localized:)`, der Katalog trägt 325 Schlüssel mit `de` (vorher 24) — seit 94236372b auch die Panel-Texte von 37 erreichbaren Chrome-Dateien (Workstation, Inspektor, Visual-Fenster, Bio-Leiste, Medienbibliothek, Safe Mode, Lernen; nur Katalog, kein Swift). Seit 8015db45c auch das Instrument selbst (EchoelStudioView, 162 Einheiten; Katalog 487). Seit e2152b4ab auch Routing (PatchbayView) und Effekte (EchoelFXView); Katalog 561. Seit 72fe0cc27 nehmen auch die Zeilen-/Gruppen-Helfer des Instruments einen Schlüssel (22 Labels; Katalog 583). Seit 82fe64d38 zeichnet das Wertfeld jedes Parameter-Label als Schlüssel (103 Einheiten, Katalog 686) — die Parameter-Ebene liest sich deutsch. Seit f11bfe664 auch die 13 FX-Stufentitel (Katalog 697). Seit 4cac7254f/d3552faa9/fb8568941 auch die neun Panel-Köpfe mit Untertiteln, die Loudness-Zeilen und die Medien-Knöpfe (Katalog 719). Seit 419170120/05d3e2705 auch Teil-Leiste und Noten-Editor inkl. VoiceOver (Katalog 774). Seit cf16b3425 auch Guide-Pfeile, Instanz-Zeile und die Save/Open-Türen der Workstation (Katalog 782). Seit 50122b5e9 auch die MIDI-Statuszeile in Routing, der Hilfe-Kartenzähler und die acht Regal-Überschriften des Tonleiter-Menüs (Katalog 793). Seit 4cc18316e auch die 23 Genre-Regale (Katalog 815), seit ad053edbb die 57 Tonleiter-Namen (Dur · Moll · Dorisch …; Katalog 872) — damit lesen alle drei Menüs (Genre · Tonleiter · Regale) deutsch. Seit d28c8ad9a auch die Symbol-Kacheln des Kopfes, der Record-Zustandstitel und die gesprochenen Vorzeichen (Kreuz/Be; Katalog 878). Seit 8cbbda285 auch die acht Hilfe-Karten (Hier anfangen · Hör es · Sieh es · Fühl es · Gib ihm deinen Puls · Für jeden Körper · die zwei Sicherheitskarten), die sechs Lernen-Überschriften und der Bio-Hinweis (Katalog 909). Seit 70f57542b auch die Zähl-Sätze der Stück-Bühne (Spuren/Teile/Takte, Waisen, Automation), die Datei-Tempo-Reihe und die Wurzel-Anzeigen Position/Datei/Stück (Katalog 938). Seit 5ca909882 auch das Takt-/Schlag-Vokabular der Modell-Helfer (Takt n Schlag b · n Takte · bis Takt n · n Punkte; Katalog 946). Seit a9b2d2b60 auch Teil-Leiste, Teile-Zeile und Kurven-Editor (Katalog 951). Seit 8700becbb auch Positions-Anzeige, Lande-Ansage und Szenen-Start (Katalog 961). Offen: Automations-Streifen, Medien, Zahlenblock, Compose-Guide. Gerät: deutsches Telefon zeigt Naht/Bereiche/Kopf deutsch, kein abgeschnittenes Wort (Deutsch ist länger) — zählt in §2 als G6 für den Build DANACH (fünf sind voll) |
| E5 | Bitten-Budget: höchstens fünf Geräte-Fragen je Build, ein Build je Woche? | Ja | **[x] Ja, 2026-09-30.** Diese Datei ist die Umsetzung; die fünf für den nächsten Build stehen in §2 |
| E6 | Startet ein neues Stück in „Spielen" oder in „Arrangieren"? | Audit: Spielen, mit einer leeren Noten-Spur, die stumm bleibt | **Entschieden durch Delegation („DMMW im Vordergrund"): Arrangieren.** Gebaut 56a1f0971 — „New piece" dreht die Bühne auf das Stück (`ANewPieceStartsAnEmptySongTests`). [ ] Widerruf? Dann sagt eine Zeile hier „Spielen", und die Scheibe dreht den Seed zurück |
| E7 | Verschwindet der Bereich „Compose" aus der Spielen-Bühne? | Ja; seine Inhalte leben im Sound-Chip und im Inspector weiter | **[ ] offen.** Heute: `StudioArea.compose` existiert und heißt „Compose" (`Sources/Echoelmusic/Studio/StudioArea.swift`). Kostet: ein Bereich weniger in der Reihe; der Sound-Chip trägt den Timbre-Editor schon (`soundPanel`) |
| E8 | Überlebt der Puls-Stream der Colabo-Session das Schließen des Sheets? | Ja, app-weiter Besitzer, 1 Hz, Sheet bleibt die Tür | **[ ] offen.** Körperdaten verlassen das Gerät länger als bisher — deshalb deine Entscheidung. Voraussetzung für Zug 6 Schritt 0 |
| E9 | SharePlay für „mehrere Körper, ein Stück, weltweit"? | Ja, nach Privacy-Label und Entitlement; erst dann Code | **[ ] offen.** Neues Framework + Entitlement in `project.yml` (founder-gated). Heute null `GroupActivities`-Import (`git grep -ln GroupActivities -- Sources project.yml` → nichts) |
| E10 | Audio-Aufnahme (Mikrofon) zurückholen? | Ja, aber als eigene Phase mit Council: neuer Eingangs-Besitzer statt des alten Graphen | **[ ] offen.** Nimmt #1302 zurück; braucht `Info.plist` (`NSMicrophoneUsageDescription` ist seit #1415 entfernt), ändert Store-Texte, Absturzfamilie am Eingangsknoten ungelöst (CLAUDE.md, Lebenszyklus-Leiter) |
| E11 | AUv3-Hosting: womit anfangen? | Erst Instrumente auf Noten-Spuren, dann Effekte auf Audio-Spuren | **[ ] offen.** Größter Neubau; berührt die Audio-Engine im laufenden Betrieb. Echoel IST seit #1385 selbst ein AUv3 (lädt in AUM, #1386) — hostet aber nichts |
| E12 | Video: als Spur abspielen oder auch aufnehmen? | Erst Video-Spur abspielen (Import) ins Bild; Aufnahme später | **[ ] offen.** Aufnahme nimmt #1304 zurück und konkurriert mit der Puls-Kamera (`Video/` ist heute NUR der rPPG-Pfad) |
| E13 | Beats: eigene Drum-Synthese oder erst Samples? | Erst Samples über die Medienbibliothek, Synthese danach | **[ ] offen.** Klang ist dein Ohr; Samples sind sofort brauchbar. `EchoelModalBank` liegt test-only bereit (#167) |
| E14 | Drei Store-Kästchen und die Widget-Schrift | Privacy-Label (Körperdaten verlassen das Gerät nur per Opt-in), Kategorie Musik, Preis v1.0 kostenlos; Marken-Schrift ins Widget über `project.yml` | **[ ] offen.** Jede der vier Zeilen ist für eine Sitzung gesperrt (App Store Connect / `project.yml`). Dieselben drei Kästchen stehen seit 2026-08 in `scratchpads/FOUNDER_DEVICE_SESSION.md` §5 — sie zählen hier EINMAL |

**Weitere HOLDs, die vor dieser Datei in Sitzungs-Aufgaben standen** (jede einmal, sonst
verfallen sie mit der Sitzung):

| # | Frage | Empfehlung | Stand |
|---|---|---|---|
| H1 | Marken-Zeile: „Create from Within" oder „multidimensional"? (U1) | eine der beiden, app-weit und auf der Website dieselbe | **[ ] offen** seit 2026-09 |
| H2 | Chip-Leiste hinter die Bereiche falten? Standard-Könnensstufe „Einfach"? (Gestaltung Regel 5) | Ja / Ja — beides eine Scheibe, beides umkehrbar | **[ ] offen**, Messung im Audit-Doc (rev 62–67) |
| H3 | HRV-Zeile im App-Store-Text (`fastlane/metadata`) — behalten oder streichen? | streichen, bis die Kohärenz am Gerät bestätigt ist (#1220) | **[ ] offen**; `fastlane/**` ist founder-gated |
| H4 | Zwei-Telefon-Probe `PeerIdentity` (#1435) | zwei Geräte, eine Colabo-Session, Namen bleiben getrennt | **[ ] offen** — ist eine Geräte-Bitte, zählt in §2 Familie E |

---

## §2 · Geräte-Bitten für den nächsten Build — genau fünf Familien

Alle Scheiben der Züge 1–4 sind **Gates-grün und Gerät-unbestätigt**. Statt 20 Einzelbitten
fünf Familien; jede Zeile sagt, was zu tun und was zu sehen ist. Ja/Nein je Zeile reicht.

| # | Familie | Was tippen | Was sehen oder hören | Ja/Nein |
|---|---|---|---|---|
| G1 | **Das Stück ist das Zuhause** (Zug 1 + Bühnen-Naht) | App frisch installieren oder Daten löschen, starten. Dann „Instrument" → „Piece" → „Instrument" wechseln, während der Puls läuft | Öffnet auf dem Stück, Bild als kleine Karte; der Bühnenwechsel beendet weder Puls noch Musik | [ ] |
| G2 | **Ein Kopf, der spricht und hört** (Zug 2) | Hardware-Tastatur (iPad/Mac): Leertaste am Kopf-Play; dann in ein Textfeld tippen und Leertaste drücken. Play → Pause-Chip auf der Instrument-Bühne → Kopf-Play | Statuswort neben dem Glyph wechselt; die Leertaste feuert NICHT, solange ein Textfeld den Fokus hat; Pause pausiert, der Kopf-Play setzt fort | [ ] |
| G3 | **Status-Leiter in Worten** (Zug 3, sechs Pfade) | Master → „Audio route"; Routing → Netzwerk-Punkt; Puls mit abgedeckter/kalter Lampe; Quelle „Apple Health"; MIDI-Controller stecken; Gerät warm laufen lassen → Field „Power" | Jede Zeile trägt ein WORT neben dem Punkt: Off / Playing / Call mode · off / sending / open, nothing sent · „No light" mit Abhilfe · Off / Waiting / Receiving / Unavailable · No controller / Connected / Playing · Full / Reduced / Saving mit Ursache | [ ] |
| G4 | **Eine Skala, ein Grün** (Zug 4) | Einstellungen → Bedienungshilfen → Textgröße AX5 und „Kontrast erhöhen" an; App öffnen, Workstation-Spur auswählen; Routing → Network-MIDI-Schalter ansehen | Symbole wachsen mit dem Text, nichts wird abgeschnitten; die gewählte Spur hat einen dickeren Rahmen, nicht nur eine andere Farbe; der ungetönte Schalter ist DASSELBE Grün wie der Akzent | [ ] |
| G5 | **Zwei Körper** (H4, Zug 6 Vorstufe) | Zwei Telefone, eine Colabo-Session öffnen | Beide Peers erscheinen mit getrennten, stabilen Namen (#1435) | [ ] |

**Der Altbestand, gemessen, mit Befehl:** `python3 scripts/founder-verify.py` druckt heute
**280 offene Bitten in 234 Dateien, 0 beantwortet** (AUDIO 78 · OTHER 76 · UI 50 · VISUAL 40 ·
BIO 21 · SYNC 15). Diese Datei ersetzt das Werkzeug NICHT — sie wählt daraus je Build fünf
Familien. Wer eine Bitte am Gerät erledigt, markiert sie an der Quelle
(`VERIFIED-JJJJ-MM-TT` auf derselben Zeile wie der Marker, siehe das Werkzeug) UND hakt hier ab.
⚠️ Die Zahl oben ist ein Datum; wer sie zitiert, führt den Befehl aus.

---

## §3 · Founder-gated Befunde — berichten, nicht editieren

Vier Pfade darf keine Sitzung ändern (`.claude/rules/context.md` §3, Hook seit 2026-09-28):
`.github/workflows/**`, `project.yml`, `Resources/iOS/Info.plist`, `.deploy/release`. Was dort
offen liegt, steht hier EINMAL. Jede Zeile hat einen fertigen Patch oder eine Ein-Zeilen-Reparatur.

| # | Befund | Wo | Reparatur | Stand |
|---|---|---|---|---|
| F1 | **Deploy v10.79.484** — Release-Notiz + Versions-Bump liegen als Patch bereit; der Hook verweigert den Commit im Auto-Modus | `.deploy/release` | `git apply` des Patches aus dem Sitzungs-Scratchpad (`FOUNDER_APPLY_2b-ii.md` / `slice-2b-ii-and-deploy-10.79.484.patch`) durch den Founder | [ ] offen seit 2026-09-30 |
| F2 | **auto-merge liest eine leere oder abgestandene API-Seite als „never-ran"** und weist Merges ab; 4 von 5 Code-Pushes an einem Tag abgewiesen (#310) | `.github/workflows/auto-merge-claude.yml` | `total_count`/`head_sha` gegen den eigenen Push prüfen, bei Abweichung erneut abfragen statt abweisen (`Tests/CISmoke/CLAUDE.md` §5, #1180) | [ ] offen |
| F3 | **`ci.yml` läuft nicht auf einem `CLAUDE.md`-only-Commit** — der Deckel-Wächter (150 000 B) kann seine Datei nicht sehen (#1176) | `.github/workflows/ci.yml` `paths:` | eine Zeile `- 'CLAUDE.md'` | [ ] offen |
| F4 | **DerivedData-Cache-Schlüssel hasht keine Xcode-/SDK-Version** — sporadisches `TEST BUILD FAILED` ohne Repo-Datei im Fehler (#478) | `ci.yml:127`, `:349` | Xcode-Version in den Schlüssel | [ ] offen |
| F5 | **`full-tests.yml` meldet `success`, während der Build scheitert** (`continue-on-error` auf dem Build-Schritt, #208) | `.github/workflows/full-tests.yml` | `continue-on-error` vom Build nehmen; Beschriftung der Suite-Zahl ist ebenfalls veraltet | [ ] offen seit 2026-07 |
| F6 | **#396 — ein Simulator-Clone stirbt bei jedem Lauf**, CI/CD-Conclusion ist damit auf jedem Push `failure` | `ci.yml` Test-Ziel (Parallelisierung) | `-parallel-testing-enabled NO` oder ein Clone | [ ] offen seit 2026-07 |
| F7 | **`EchoelCore`-Target** (M1, Foundation-only Zeitbasis) braucht einen `project.yml`-Eintrag | `project.yml` | Target-Block liegt in `scratchpads/` (#95) | [ ] offen |
| F8 | **Watch-Target ist kompiliert, aber nicht eingebettet**; `project.yml:296` trägt die alte Ein-Richtungs-Route | `project.yml` | Plan A–E in `scratchpads/PLAN_WATCH_2026-09-13.md`; Scheibe A gebaut (#1319) | [ ] offen |

---

## §4 · Fällige Entscheidungen — die Sitzung schließt sie selbst

`./review.sh | grep -c '^REVIEW DUE'` → **540** am 2026-09-30, älteste fällig seit 2026-04-10.
Nichts flaggt automatisch (CLAUDE.md, Decision Logging: kein `schedule:`-Trigger im Repo).
Regel aus dem Audit: **fällige Entscheidungen fragt keine Sitzung dem Founder ab — sie prüft am
Code, ob die Entscheidung noch gilt, und trägt das Ergebnis in `decisions.csv` nach** (Status
bestätigt / überholt mit Verweis). Nur eine Entscheidung, deren Prüfung eine ECHTE Founder-Frage
aufwirft, kommt nach §1 — einmal.

⚠️ Heute ist davon **nichts** geschlossen; die 540 sind eine eigene Scheibe (Familienweise,
nach Thema, nicht chronologisch), und diese Zeile bleibt ehrlich, bis sie gebaut ist.

---

## Grenzen

- Diese Datei ist Prosa. Kein Wächter zwingt eine Sitzung, hier zu lesen; die Regel steht in
  `.claude/rules/context.md` §6, das immer geladen ist.
- Die Zahlen in §2 und §4 sind Daten mit Befehl daneben. Wer sie nachführt, führt den Befehl aus.
- Antworten werden nie gelöscht, auch nicht, wenn die Fähigkeit dahinter später fällt — siehe
  `scratchpads/FOUNDER_DEVICE_SESSION.md` §6 (Voice clone: die Antwort blieb, der Auftrag fiel).
