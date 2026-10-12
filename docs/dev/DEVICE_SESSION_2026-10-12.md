# Geräte-Sitzung iPhone, ungefähr 20 Minuten

Für den neuesten TestFlight-Build. Welcher das ist, steht oben in `docs/dev/FOUNDER_INBOX.md` §2; zuletzt gemessen war es 10.79.496 = Build 2621. Bitte die Nummer nicht von hier abschreiben.

**Was du brauchst:**
- iPhone mit dem Build
- AirPods oder andere Bluetooth-Kopfhörer
- ein zweites Telefon für einen Anruf (oder Siri)
- AUM, falls installiert
- optional ein MIDI-Gerät oder eine MIDI-Monitor-App

**Rückmeldung:** pro Schritt ein Wort (Ja / Nein / übersprungen). Bei Nein reicht ein Satz, was passiert ist. Ganz am Ende schickst du einmal das Diagnose-Log (Schritt 15).

---

## Familie 1: Erster Start und Stabilität (ca. 5 Min)

**1. Frische Installation (nur wenn du nichts Wichtiges darauf hast)**
- **Tun:** App löschen, aus TestFlight neu installieren, starten. ⚠️ Beim Löschen gehen alle gespeicherten Stücke verloren.
- **Achten auf:** Die App öffnet auf dem Stück („Piece“), das Bild ist eine kleine Karte. Kein schwarzer Bildschirm, kein Safe-Mode-Schirm.
- **Zurück:** Ja / Nein + was du siehst.

**2. Play auf dem leeren Stück**
- **Tun:** Auf „Piece“ den Play-Knopf in der Leiste ansehen und antippen, ohne vorher etwas anzulegen.
- **Achten auf:** Der Knopf ist abgedunkelt und spielt nichts. VoiceOver bzw. der Hinweis sagt: „Unavailable: add a part with notes or audio, or start the instrument.“ Er darf nichts Halbes starten und darf nicht einfrieren.
- **Zurück:** abgedunkelt ja/nein · Hinweis verständlich ja/nein.

**3. Frische Installation: der Weg zum ersten Ton**
- **Tun:** Auf der Stück-Fläche „Add Audio Track“ tippen.
- **Achten auf:** Eine Spur „Audio 1“ erscheint, und die Fläche zeigt nicht mehr „leer“.
- **Zurück:** Ja / Nein.

**4. Dreimal kalt starten**
- **Tun:** App wegwischen, Icon tippen, und das dreimal.
- **Achten auf:** Jeder Start ist normal. Kein Safe-Mode-Schirm, kein schwarzer Bildschirm. Falls doch einmal Safe Mode kam: war das direkt nach einem Neustart des Telefons oder direkt nach einer TestFlight-Installation?
- **Zurück:** 3/3 ok · oder welcher Start schiefging und unter welchen Umständen.

**5. Alle fünf Bereiche und das Tonart-Menü während der Puls läuft**
- **Tun:** Unten alle fünf Wörter antippen (Arrange · Mixer · Instrument · Browse · Piece). Dann auf „Instrument“ mit Play starten, den Finger auf die Kamera legen und, während der Puls läuft, das Tonart-Menü öffnen und einen Eintrag wählen.
- **Achten auf:** Das Menü reagiert und friert nicht ein. Der Wechsel der Bühne stoppt weder Puls noch Musik.
- **Zurück:** Ja / Nein + wo es hing.

## Familie 2: Unterbrechungen, Anruf, Siri und Hintergrund (ca. 4 Min)

**6. Anruf mitten im Spiel**
- **Tun:** Instrument spielen lassen. Vom zweiten Telefon anrufen lassen, kurz annehmen, auflegen.
- **Achten auf:** Nach dem Auflegen kommt die Musik ohne Neustart der App zurück, höchstens nach einem Tipp auf Play. Kein Absturz, keine dauerhafte Stille.
- **Zurück:** kommt allein zurück / nach Play-Tipp / bleibt still.

**7. Siri mitten im Spiel**
- **Tun:** Während die Musik läuft, Siri aufrufen („Wie spät ist es?“) und warten, bis Siri fertig ist.
- **Achten auf:** Wie in Schritt 6.
- **Zurück:** wie in Schritt 6.

**8. Hintergrund und Vordergrund**
- **Tun:** Während Instrument und Puls laufen: Home-Geste, 10 Sekunden warten, zurück in die App.
- **Achten auf:** Musik und Puls laufen nach der Rückkehr weiter. Zur Puls-Pille oben:
  - Die Pille verliert ihr grünes Schloss innerhalb von etwa einer Sekunde.
  - Sie zeigt ein ehrliches Wort wie „Camera paused“ und nicht den gelben Hinweis zur Fingerposition.
- **Zurück:** läuft weiter ja/nein · die Pille wirkt **ehrlich** oder **kaputt**? (Das ist eine Geschmacksfrage an dich.)

## Familie 3: Audio-Ausgang Lautsprecher ↔ Bluetooth (ca. 3 Min)

**9. Wechsel des Ausgangs während des Spiels**
- **Tun:** Instrument öffnen, Master-Panel, Zeile „Audio route“ ansehen. Über den Lautsprecher spielen, dann AirPods verbinden, dann AirPods wieder trennen.
- **Achten auf:** Die Zeile wechselt von „Playing · Speaker …“ zu „Playing · AirPods …“ und wieder zurück. Die Musik läuft weiter, ohne Neustart der App und ohne Tonhöhensprung (nicht „höher“ oder „schneller“).
- **Zurück:** Ja / Nein + was.

**10. Anruf, während die AirPods verbunden sind**
- **Tun:** Mit verbundenen AirPods anrufen lassen und, während der Anruf läuft, die Zeile „Audio route“ ansehen. Danach auflegen.
- **Achten auf:** Während des Anrufs steht „Call mode · …“ mit einem Satz zur Abhilfe darunter. Nach dem Auflegen geht es zurück, ohne Neustart der App.
- **Zurück:** Ja / Nein.

**11. Lautheit auf beiden Ausgängen (optional, 1 Min)**
- **Tun:** Dasselbe Stück einmal über AirPods und einmal über den Lautsprecher spielen und jeweils den Wert „Master LUFS“ ablesen.
- **Achten auf:** Beide Zahlen liegen etwa gleich, höchstens ungefähr 1 LU auseinander.
- **Zurück:** die zwei Zahlen.

## Familie 4: MIDI OUT und das Plug-in in AUM (ca. 4 Min)

**12. MIDI OUT**
- **Tun:** Licht-Kachel im Kopf → Routing → „MIDI out“ einschalten. In AUM (oder einer MIDI-Monitor-App) „Echoelmusic“ als MIDI-Quelle wählen. Instrument spielen. Danach „MPE note layout“ ein- und wieder ausschalten.
- **Achten auf:**
  - Noten kommen an, und keine Note bleibt hängen, wenn du stoppst.
  - Der Schalter für Ausdruck („Expression“) ist ausgegraut, solange MPE aus ist.
  - Hast du einen Mac zur Hand: mit „MIDI 2.0 source“ an erscheint dort zusätzlich „Echoelmusic (MIDI 2.0)“. Das ist optional.
- **Zurück:** Noten kommen an ja/nein · hängende Noten ja/nein.

**13. Plug-in „EchoelBodyVibe“ in AUM**
- **Tun:** AUM öffnen → Instrument hinzufügen → EchoelBodyVibe. Dann auf der AUM-Tastatur Tasten spielen: tiefe, mittlere und hohe.
- **Achten auf:** Das Laden und der freilaufende Ton sind schon bestätigt (20.09.). **Neu ist die Frage, ob die Tonhöhe den Tasten folgt**, also höhere Taste gleich höherer Ton, ohne Knacken.
- **Zurück:** folgt den Tasten ja/nein. Falls du GarageBand hast: lädt es dort, und klingt es hörbar zu hoch? Das ist optional; „zu hoch“ ist dort sogar der erwartete Befund.

## Familie 5: Klang und Dauerlauf (ca. 4 Min aktiv, 10 Min läuft nebenher)

**14. Zehn Minuten am Stück, mit drei Genres**
- **Tun:** Instrument mit Puls (Kamera oder Gurt) starten, die App vorne lassen, Display an. Drei Genres deiner Wahl hintereinander, je etwa drei Minuten, insgesamt ungefähr zehn Minuten ohne Stop. Einmal das Genre wechseln, während der Take läuft. Wenn du magst, auch „Self-Observation“ mit 8-Takt-Loop.
- **Achten auf:**
  - Jedes Genre klingt nach sich selbst und professionell, nichts läuft auf denselben Klang zusammen.
  - Nach einem Genrewechsel folgt der neue Klang innerhalb von etwa einer halben Sekunde.
  - Über die zehn Minuten keine Aussetzer, kein Knacken, kein Einfrieren. Das Telefon wird höchstens warm.
  - Bei „Self-Observation“: atmet der Loop von Takt zu Takt, ohne unruhig zu werden?
- **Zurück:**
  - Klang: Ja / Nein + welches Genre.
  - 10 Minuten stabil: Ja / Nein + Minute und was passiert ist.
  - „Self-Observation“: zu brav / passt / zu zappelig.

**15. Diagnose-Log zurückschicken (1 Min, immer)**
- **Tun:** „Save & Export“ → „Diagnostics“ → teilen und an mich schicken.
- **Achten auf:**
  - Die erste Zeile lautet `launch v10.79.… (…)` und passt zum installierten Build.
  - Über dem Header steht kein neues `CRASH`. Der alte 2618-Block darunter darf bleiben.
  - Die Zeile „Handling Warning pressure“ taucht nicht auf, obwohl das Telefon nicht wirklich knapp an Speicher war.
- **Zurück:** die Log-Datei selbst.

---

**Bewusst nicht in dieser Runde:** iPad, Video-Export, Aufnahme und Mitschnitt, Binaural/Kopfhörer-Raum. Die übrigen offenen Bitten (G1–G10, S-Reihe) bleiben in `docs/dev/FOUNDER_INBOX.md` §2 offen und werden hier nicht doppelt gefragt.

**Abhaken:** Erledigte Punkte markiere ich danach an der Quelle mit `VERIFIED-JJJJ-MM-TT` und hake sie in FOUNDER_INBOX §2 ab.

---

## Quellen

**Werkzeug und Planungsdokumente**
- `python3 scripts/founder-verify.py`: 343 offene Bitten in 293 Dateien, 0 beantwortet (Stand dieses Laufs). Davon sind 27 nur Erwähnungen des Markers und keine echten Aufträge. Das Skript gibt beim Start eine SyntaxWarning aus, `scripts/founder-verify.py:51`, wegen `\d` in einem Kommentar.
- `docs/dev/FOUNDER_INBOX.md:134-222` (§2: G4 Klang, G5 Stabilität, G9/G10 stiller Start und Diagnose-Log, ältere Bitten zum MIDI-Eingang und zu den Status-Wörtern).
- `docs/dev/FOUNDER_DEVICE_SESSION.md` existiert nicht. Die Datei liegt unter `scratchpads/FOUNDER_DEVICE_SESSION.md`. Verwendet: §2b AUM, offen nur noch „Noten spielen“ (`:97-133`), §3 Ship-Gates (`:258-270`).
- `CLAUDE.md`, CURRENT STATE: Ship-Gate „Klang“ ist Founder-Ohr, „Stabilität“ geht nur am Gerät.

**Code und Tests, je Schritt**
- **Schritt 2:** `Sources/Echoelmusic/Studio/ProjectTransport.swift:87-105` und `:218` (Text „Unavailable …“, Zustand `.unavailable`).
- **Schritt 3:** `Sources/Echoelmusic/Studio/WorkstationView.swift:124-130` (frische Installation / Add Audio Track).
- **Schritt 5:** `Tests/CISmoke/ThePieceStageHasOnePlayTests.swift:26-31`.
- **Schritte 6 und 7:** `Tests/CISmoke/TheLifecycleCatchesSpeakInTheExportedLogTests.swift:80-84` (Anruf / Interruption). Dazu `Sources/Echoelmusic/Audio/AudioConfiguration.swift:1121ff`: im Vordergrund nimmt die App die Wiedergabe immer wieder auf.
- **Schritt 8:** `Tests/CISmoke/TheLockNeedsFramesTests.swift:158-162` und `Tests/CISmoke/TheStalledPillSaysWhySilentTests.swift:143-146` (Hintergrund, Puls-Pille).
- **Schritte 9 und 10:** `Sources/Echoelmusic/Studio/EchoelStudioView.swift:5147-5151` (AudioRouteRow) und `Tests/CISmoke/TheAudioRouteRowSaysWhereTheSoundGoesTests.swift:15`.
- **Schritt 11:** `Tests/CISmoke/TheLoudnessMeterIsSampleRateCorrectTests.swift:26-28`.
- **Schritt 12:** `Sources/Echoelmusic/Studio/PatchbayView.swift:301-348` (MIDI out, MPE, Expression, UMP2) und `Sources/Echoelmusic/Core/StudioDefaultKeys.swift:608-611`.
- **Schritt 13:** `Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift:80`.
- **Schritt 14:** `Sources/Echoelmusic/Core/StudioDefaultKeys.swift:232-235` (Self-Observation) und `Tests/CISmoke/AReclaimedFloorIsNotAddedToTheWaitTests.swift:47` (Genrewechsel).
- **Schritt 15:** `Sources/Echoelmusic/Core/MemoryPressureHandler.swift:318-321`.

**Hinweis:** Für „10 Minuten Dauerlauf“ und „Siri“ gibt es keinen eigenen `NEEDS-FOUNDER-VERIFY`-Marker im Code. Diese beiden Schritte habe ich aus dem Auftrag ergänzt; sie stehen auf Familie 5 bzw. 2 und laufen über denselben Interruption-Pfad wie der Anruf.