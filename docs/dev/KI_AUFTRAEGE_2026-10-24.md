# KI-Aufträge bis Mittwoch 2026-10-28 — Grok (SuperGrok Heavy) und ChatGPT

Founder 2026-10-24: „Grok und ChatGPT sollen Vorarbeit leisten bis Mittwoch. Gib ihnen Aufträge, die du abnimmst.“

**Abnahme-Regel (Lernmodus, `.claude/skills/learn-mode/SKILL.md`):** jede Antwort ist eine HYPOTHESE. Sie wird
am Mittwoch durch `python3 -I scripts/learn-intake.py` gesäubert, jede Behauptung einzeln gemessen
(`git grep`, Datei-Read, Apple-/GitHub-Seite), das Verdikt in `inspiration.csv` geloggt. Kein Satz aus
den Antworten wandert in Code, Store-Text oder Website; Code wird aus dem Repo neu hergeleitet.

**Was rausgeht (öffentlich, getrackt):** nur die Repo-URL und Dateien an einem festen Commit:
`https://github.com/vibrationalforce/Echoelmusic`, Commit `1dd172f4ca38f9b2165da2f115a665e0dfe56026`
(Rohdateien: `https://raw.githubusercontent.com/vibrationalforce/Echoelmusic/1dd172f4ca38f9b2165da2f115a665e0dfe56026/<Pfad>`).
**Nie:** `.claude/settings.local.json`, Diagnose-Logs, App-Store-Connect-Schlüssel, Tester-Daten,
private Claude-Docs, Namen von Personen.

**Format jeder Antwort (gilt für alle Aufträge):** höchstens 8 Punkte · je Punkt Datei:Zeile oder
URL + Abrufdatum · je Punkt „sicher“ oder „vermutet“ · KEIN Code, KEIN Befehl, KEIN Diff ·
„nicht gefunden“ ist eine gültige Antwort und besser als eine erfundene.

---

## GROK (SuperGrok Heavy) — Recherche mit Belegen

### G1 · Scheibe 0 belegen: iOS-AUv3 aus einer „Designed for iPad“-App auf Apple-Silicon-Macs
Frage: Erscheinen die Audio-Unit-Erweiterungen (AUv3) einer iPad-App, die als „Designed for iPad“ auf
einem Apple-Silicon-Mac installiert ist, in Logic Pro, GarageBand oder anderen Mac-Hosts? Gibt es
Apple-Dokumentation, WWDC-Sessions oder belegte Entwicklerberichte in BEIDE Richtungen?
Ergebnis: Liste der Belege mit URL + Datum, je Beleg „bestätigt / widerspricht / unklar“, und ein
Satz, welche Bedingungen genannt werden (Sandbox, Entitlements, `AudioComponents`-Info.plist).
Abnahme: ich prüfe jede URL; eine Quelle ohne URL zählt nicht. Hintergrund: Plan §2 Scheibe 0 in
`scratchpads/PLAN_STORE_FIRST_2026-10-24.md`.

### G2 · App Store Connect: erster In-App-Kauf + Mac/Vision-Verfügbarkeit, Schritt für Schritt
Frage: Welche Schritte braucht ein nicht-verbrauchbarer In-App-Kauf (Produkt-ID `com.echoelmusic.app.pro`)
beim ERSTEN Mal — Paid Applications Agreement, Steuer-/Bankdaten, Produkt anlegen, Review-Screenshot,
„submit with app version“? Was genau schaltet „Pricing and Availability → Mac (Apple Silicon)“ und
„Apple Vision Pro“, und ab wann ist Universal Purchase unumkehrbar? Welche Punkte gelten für das
Small Business Program?
Ergebnis: nummerierte Checkliste, jeder Punkt mit Apple-Hilfe-URL + Datum.
Abnahme: Abgleich gegen die Apple-Seiten; Punkte ohne Apple-Quelle werden „vermutet“.

### G3 · Privates GitHub-Repo: was es kostet und was bricht
Frage: Für ein privates Repo auf GitHub Free bzw. Pro (Einzelkonto): Actions-Minuten pro Monat,
Multiplikator für macOS-Runner, Preis pro Überschreitungsminute, Ausgabenlimit-Default; läuft GitHub
Pages aus einem privaten Repo (welcher Plan)? Baut Cloudflare Pages / Workers Builds weiter aus einem
privaten GitHub-Repo, und was ist dafür nötig? Was passiert mit bestehenden Forks beim Umschalten?
Ergebnis: Tabelle Frage → Antwort → URL + Datum.
Abnahme: jede Zahl gegen die Originalseite (docs.github.com, developers.cloudflare.com).

### G4 · Code-Lesung des Kaufpfads (nur lesen, nichts vorschlagen, was Code ist)
Dateien am Commit oben: `EchoelStudio/App/Store/StoreController.swift`, `EchoelStudio/App/Store/StoreView.swift`,
`EchoelStudio/Plugins/Shared/PluginLicense.swift`, `EchoelStudio/Plugins/Shared/PluginUnlock.swift`,
`EchoelStudio/Plugins/Shared/PluginViewController.swift`, `EchoelStudio/Plugins/Shared/PluginControlsView.swift`.
Frage: Wo kann ein Käufer die Demo-Pause trotz Kauf sehen, wo kann ein Nicht-Käufer sie verlieren,
wo kann ein StoreKit-Aufruf hängen oder zweimal laufen, wo widerspricht ein Kommentar dem Code?
Rahmen: Swift 6 strict concurrency, StoreKit 2, App Group `group.com.echoelmusic.shared`, Apple
unterstützt StoreKit in App-Extensions nicht.
Ergebnis: ≤ 8 Befunde, je Datei:Zeile, Szenario in zwei Sätzen, „sicher/vermutet“.
Abnahme: jeden Pfad nachlesen; nur ein nachvollziehbarer Pfad wird eine Reparatur-Scheibe.

---

## CHATGPT — Prüfen gegen das Repo

### C1 · Store-Text gegen die Wahrheitsliste
Dateien: `docs/dev/APP_STORE_LISTING_STUDIO_11.md` (Entwurf en/de) und `ContentPipeline/CLAIMS.md`,
Abschnitt „Echoel Studio 11.0.0“.
Frage: Welcher Satz des Listings wird von KEINEM Satz in CLAIMS.md gedeckt? Welcher CLAIMS-Satz
fehlt im Listing, obwohl er verkaufsrelevant ist? Welche Formulierung könnte Apple als Gesundheits-,
Therapie- oder Wellness-Behauptung lesen (Guideline 5.1.3 / 2.3)?
Ergebnis: Tabelle Listing-Satz → CLAIMS-Satz oder „ungedeckt“ → Risiko. Kein neuer Text.
Abnahme: Zeile für Zeile gegen beide Dateien.

### C2 · Plan-Widerlegung
Datei: `scratchpads/PLAN_STORE_FIRST_2026-10-24.md`.
Frage: Versuche jede als „sicher“ markierte Aussage zu widerlegen — mit einer Repo-Datei:Zeile oder
einer Apple-/GitHub-Seite (URL + Datum). Welche Aussagen widersprechen sich innerhalb des Plans?
Welche Reihenfolge der Scheiben wäre falsch, und warum?
Ergebnis: ≤ 8 Widersprüche, je mit Beleg. Lob ist kein Ergebnis.
Abnahme: jeder Widerspruch wird gemessen; bestätigte landen als Korrektur im Plan.

### C3 · Mac-nativ: was `AVAudioSession` in der Engine wirklich braucht (Entwurfsnotiz, kein Code)
Datei: `EchoelStudio/App/Engine/AudioEngine.swift` (dazu `EchoelStudio/App/Engine/PluginHost.swift`).
Frage: Liste jede `AVAudioSession`-Stelle (Zeile) mit dem, was sie fachlich leistet (Kategorie,
Aktivierung, Route-Analyse für den Rückkopplungsschutz, Unterbrechung, Latenz) und nenne das
native macOS-Gegenstück (CoreAudio / AVAudioEngine-Benachrichtigung) oder „kein Gegenstück“.
Ergebnis: Tabelle Zeile → Zweck → macOS-Gegenstück → Risiko. Prosa, keine Protokolle, kein Swift.
Abnahme: Zeilen gegen die Datei; Gegenstücke gegen Apple-Doku. Dient Plan §2 Scheibe 3b (1.1).

### C4 · Nebenläufigkeit der zwei Store-Commits
Diffs: `https://github.com/vibrationalforce/Echoelmusic/commit/9c144dcd2` und
`https://github.com/vibrationalforce/Echoelmusic/commit/929af2f98`.
Frage: Wo kann unter Swift 6 strict concurrency ein Datenrennen, ein verlorener Schreibvorgang
(`pass`-Zähler, `isBusy`, `model?.unlock()`) oder eine Isolation-Verletzung (MainActor,
`@unchecked Sendable`-Box) entstehen? Welcher Fall ist mit `Task.isCancelled` NICHT abgedeckt?
Ergebnis: ≤ 8 Befunde, Datei:Zeile, Szenario, „sicher/vermutet“.
Abnahme: Pfad nachvollziehen; bestätigte werden je eine Scheibe ≤ 3 Dateien.

---

## Gestrichen
- **ChatGPT-Auftrag 4 vom 24.10. (Förderzahlen gegenprüfen)** ist GEGENSTANDSLOS: keine Förderung mehr
  (Founder 2026-10-24 abends, `decisions.csv`). Nicht ausführen.

## Am Mittwoch
Antworten als Text in den privaten Tab „KI-Aufträge“ oder in den Chat; ich fahre je Antwort
`learn-intake.py`, messe jede Behauptung, logge Verdikte und baue höchstens EINE Scheibe je
bestätigtem Befund.
