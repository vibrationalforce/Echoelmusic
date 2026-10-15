# Grok und ChatGPT — Gegenprüfung des Deep Audits (2026-10-15)

**Gebrauch:** Kopf (Abschnitt 1) + EINEN Auftrag als EINE Nachricht in einen NEUEN Chat.
Grok bekommt Auftrag G, ChatGPT bekommt Auftrag C. Die Antworten kommen unverändert an Claude Code
zurück und werden dort am Code gemessen, bevor etwas übernommen wird.
Nichts Privates mitschicken (keine Logs, keine Schlüssel). Nichts hier ist Store-Text.

---

## 1. Kopf (immer mitschicken)

Du bist PRÜFER, nicht Bauer. Echoelmusic ist eine iPhone-App (Swift 6, SwiftUI, AVAudioEngine,
null Abhängigkeiten) von Echoel, einem Künstler für Wasser-Licht-Klang-Installationen und
Musikproduzenten. Sie wurde über Monate mit KI-Agenten gebaut ("Vibe Coding"); es gibt keinen
lokalen Compiler, nur CI, und TestFlight-Builds in jeder Runde.

Repo (öffentlich): https://github.com/vibrationalforce/Echoelmusic — Code-Stand `main` = `e75d99b7f`.
Der Audit-Bericht, um den es geht, liegt auf dem Arbeitszweig:
https://github.com/vibrationalforce/Echoelmusic/blob/claude/echoelmusic-review-optimize-u5jjpd/reports/Deep%20Audit%20und%20Produktwert%20(2026-10-15).md

**Kurzfassung des Audits (gemessen am Code, nichts am Gerät):**
1. 393 offene Geräte-Prüfbitten im Code, 0 als bestätigt markiert; Geräte-Beleg nur für AUv3 in AUM
   und den Kamera-Puls. Kein Absturz-Fix ist am Gerät nachgeprüft. Der Rückstand wächst pro Build.
2. Bedienung: frische Installation öffnet auf leerem Arrange mit ausgegrautem Play
   (`Sources/Echoelmusic/Core/StudioDefaultKeys.swift` `stage = .piece`,
   `Sources/Echoelmusic/Studio/ProjectTransport.swift` `.unavailable`); 5 Tabs auf 2 Bühnen,
   9 Chips, 88 Regler in `Studio/EchoelStudioView.swift` (13 404 Zeilen), Tempo an 4 Stellen,
   2 Play-Knöpfe, 23 „noch nicht verfügbar"-Sackgassen; der Puls braucht Wissen, das nur in einer
   Lernkarte steht (`Studio/LearnLibrary.swift`).
3. Einzigartiger Wert: Puls über die Kamera (`Bio/CameraRPPGBioPublisher.swift`) → Körper-Stimme →
   Komponist in Tonart (`Sequencer/BioComposer.swift`) → Tempo folgt dem Körper → Bild, Licht
   (Art-Net/sACN), Raum (ADM-OSC). Breite DAW-Teile (Arrange, Mixer, Audio-Editor) konkurrieren mit
   fertigen Apps. Dieselbe Fähigkeit wurde mehrfach gebaut und gestrichen (`docs/dev/HISTORY_ARCHIVE.md`).
4. Empfehlung des Audits: zwei Wochen Breiten-Stopp + eine Gerätesitzung
   (`docs/dev/DEVICE_SESSION_2026-10-12.md`); die Bio-Kette als Produkt; acht Vereinfachungen
   (Start auf dem Instrument, EIN Play, Finger-Hinweis, Routing hinter „Bühne", Field-Panel 4 + „Mehr",
   Tempo an einer Stelle, Sackgassen ausblenden, 9 → 6 Chips); DAW einfrieren; Hardware als
   Bühnen-Werkzeug. Vermarktung: Installations-/Licht-/Bühnenkünstler zuerst; nur wahre Sätze aus
   `ContentPipeline/CLAIMS.md`.
5. Spannung: der Founder nannte Biofeedback am 15.10. „nur ein kleines Gimmick" und setzte
   Profi-Produktion an die erste Stelle; das Audit empfiehlt „Bio als Haken und Herz, Produktion
   als Tiefe".

**Antwortformat (Pflicht):** höchstens 8 Punkte; jeder Punkt: Behauptung · Beleg (Datei:Zeile auf
`e75d99b7f` oder eine öffentliche Quelle mit Link) · SICHER oder VERMUTET · kleinster nächster
Schritt. Kein Code. Was du nicht selbst gesehen hast, heißt UNGEPRÜFT. Keine Wellness-, Heil- oder
Therapie-Sprache; Echoel ist ein Instrument.

---

## 2. Auftrag G — für Grok: das Audit angreifen

Du bist der Gegner dieses Audits. Finde, wo es FALSCH liegt oder zu bequem ist.
1. **Premortem:** Es ist Oktober 2027, Echoelmusic ist gescheitert, obwohl der Founder genau dieser
   Empfehlung gefolgt ist. Nenne die drei wahrscheinlichsten Gründe.
2. **Die Kern-These:** Ist „Puls über die Kamera → Musik" wirklich ein Produkt, für das Menschen die
   App öffnen und wiederkommen — oder eine Demo, die einmal staunen lässt? Belege mit vergleichbaren
   Apps oder Produkten (öffentliche Quellen), die Biofeedback in Musik oder Kunst nutzen und
   gescheitert sind oder funktionieren.
3. **Der Gegenentwurf:** Was wäre der stärkste Fall dafür, dass der Founder recht hat und
   Profi-Produktion (DAW, Hardware-Integration) die Führung haben sollte?
4. **Die Vereinfachungen:** Welche der acht schadet mehr, als sie nützt (z. B. wer verliert etwas,
   wenn die App auf dem Instrument statt dem Stück öffnet)?
5. **Blinder Fleck:** Was misst das Audit gar nicht, das über Erfolg entscheidet?
Am Ende: EIN Satz, was du an Stelle des Founders in den nächsten 14 Tagen tun würdest.

---

## 3. Auftrag C — für ChatGPT: der 14-Tage-Plan

Baue aus dem Audit einen konkreten Plan für 14 Tage, mit dem der Founder neben der Entwicklung
vermarktet. Bedingungen: höchstens eine Gerätesitzung von 20–30 Minuten pro Woche; die KI-Agenten
bauen, der Founder prüft am Gerät und dreht Clips.
1. **Reihenfolge der acht Vereinfachungen** (Abschnitt 1, Punkt 4): welche zuerst, welche zusammen
   in einen TestFlight-Build, welche brauchen ein Gerät, bevor sie sich lohnen. Prüfe dabei
   `Sources/Echoelmusic/Views/OnboardingView.swift`, `Studio/WorkspaceView.swift`,
   `Studio/WorkstationView.swift` und `Studio/PatchbayView.swift`.
2. **Die erste Minute in Worten:** was sieht und hört ein neuer Nutzer von der Installation bis zum
   ersten Ton und bis zum ersten Puls — Bildschirm für Bildschirm, mit höchstens drei Taps.
3. **Die Gerätesitzung:** welche fünf Prüfungen aus `docs/dev/DEVICE_SESSION_2026-10-12.md` zuerst
   (Absturz-Familien, Start, Export, Puls)?
4. **Vermarktungs-Kalender:** 14 Tage, je Tag höchstens 30 Minuten: welche Clips (aus
   `ContentPipeline/Scripts/template_short_form.md`), welche Communities (Resolume, TouchDesigner,
   AUM), welche Kontakte (`docs/press.html`, `docs/artist.html`), und was davon das Demo-Video oben
   auf `docs/index.html` wird. Nur Sätze aus `ContentPipeline/CLAIMS.md`.
5. **Messgröße:** woran merkt der Founder am Tag 14, ob es funktioniert hat (TestFlight-Tester,
   Rückmeldungen, Gerätesitzung beantwortet)?
Am Ende: eine Tabelle Tag · Bau-Scheibe · Founder-Aufgabe (≤ 30 min) · Vermarktung.
