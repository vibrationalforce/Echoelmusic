# G-A — Körperquellen und Modulation: Integrationsvertrag

Stand 27.10.2026, geprüft gegen `31ce86372ed852626f186f91d2984996bb958b89`.
**Vorschlag für Claude, keine implementierte Studio-Fähigkeit.** Die Python-Referenz
prüft diesen Vertrag; sie prüft weder Swift noch Sensoren, Audiothreads oder Geräte.
Die vollständige W0–W10-Vision bleibt bestehen. Produktion besitzt Ressourcenpriorität;
Körperdaten sind eine optionale Steuerquelle. Keine neue Gesundheitsbehauptung.

Inhalt: [Besitzer](#besitzer) · [Messung](#messung) · [Zustände](#zustände) ·
[Modulation](#modulation) · [Format](#format) · [Export](#export) ·
[Plattform](#plattform) · [Abnahme](#abnahme).

## Besitzer

- `EchoelCore`: reine Zustands-/Routingwerte, Validierung und Dokumentbefehle.
- `App`: ein Besitzer pro ausgewählter Quelle; Kamera/BLE/Health-Lebenszyklus,
  Consent und MainActor-Projektion. Bestehende `BodyFrameSource`/Adapter/View ersetzen
  ihre Platzhalter in kleinen Scheiben. Keine zweite unverbundene Anzeige.
- `EchoelEngine`/Kernels: begrenzte, vorkompilierte Modulationsdaten; Rendern liest
  niemals `Project`, SwiftUI oder den MainActor. Extension-Isolation bleibt erhalten.
- Änderungen von Routen gehen durch `ProjectStore.perform`; laufende Messwerte
  erzeugen **keine** Dokumentbefehle, Undo-Schritte oder Dateischreibvorgänge.
- Historische Algorithmen gezielt portieren. Die Python-Referenz benutzt Dictionaries
  zur Lesbarkeit; diese sind ausdrücklich KEINE Vorlage für den Audiothread.

## Messung

Jede Quelle liefert Quellenkennung, Laufgeneration, Sequenz, Messzeit, Empfangszeit
und pro Metrik Wert, Einheit, Qualität und Gültigkeit. Rohwerte und normalisierte
kreative Werte sind getrennt. BPM bleibt BPM; normierte HRV ist keine Millisekundenzahl.
Fehlende Atem-/HRV-/Kohärenzwerte bleiben fehlend, selbst wenn Puls gültig ist.
Kein `72`, `0.45`, `0.62`, plausibler Zufallswert oder `0.5` als Ersatzmessung.

Die Referenz modelliert **einen bereits normierten Kanal** in `[0,1]`. Mehrere
Metriken benötigen unabhängige Gültigkeit/Alter; ein gültiger Puls macht HRV nicht gültig.
Rohsignalprüfung und physiologische Ableitungen sind nicht in diesem Modell enthalten.
Der reale Produzent muss diese davor nachweisen. Keine erfundene universelle
HRV-/Kohärenz-Konfidenz aus einer fehlenden SDK-Eigenschaft.

Zeit wird in der Referenz als nichtnegative ganzzahlige **Millisekunden einer
monotonen Host-Uhr** übergeben. In Swift eine explizite monotone Zeitbasis verwenden;
keine Mischung aus Unix-Zeit, Audio-Samples, Kamera-PTS und Host-Ticks. Health-Daten
mit historischen Zeitstempeln bleiben historische Daten: eine neue Abfrage macht sie
nicht neu. Abbildung dieser Uhr muss nach Zeitkorrektur/Resume neu geprüft werden.

**Policy-Beispiele**, keine gemessenen Sensorgrenzen: `max_age_ms=2000`,
`min_quality=0.7`. Alter exakt 2000 ms ist gültig, darüber veraltet; Qualität exakt
0.7 ist zulässig. Für jeden realen Produzenten/Metrik separat begründen, kalibrieren
und versionieren. Langsam eintreffende Health-Werte nicht durch ein längeres Timeout
zu Beat-Sync erklären. UI darf einen historischen Wert separat mit Alter anzeigen;
der Echtzeitkanal hat bei Ungültigkeit `value=nil`.

## Zustände

| Ereignis | Übergang / Nachbedingung |
|---|---|
| Initialzustand | `off`, Generation 0, kein Wert, kein laufender Produzent |
| Nutzer startet/wechselte Quelle | Generation +1, alte Werte löschen, `waiting` bzw. `denied`; Suspension bleibt bestehen |
| Frische, endliche, ausreichend gute Messung | `valid`; Quellenkennung und Generation müssen passen |
| Keine Messung oder Health-Lesezugriff unbekannt | `waiting`, niemals „berechtigt und gemessen“ ableiten |
| Neue Messung ungültig/zu geringe Qualität | `invalid`, Wert entfernen |
| Alter > konfiguriertes Maximum | `stale`, Wert entfernen; Scheduler prüft auch ohne neue Pakete |
| Aus | Generation +1, Produzent stoppen, Werte löschen, `off` |
| Bekannter Berechtigungswechsel | Generation +1, Werte löschen, `waiting` oder `denied` |
| Unterbrechung/Ressource entzogen | Generation +1, Werte löschen, `suspended` |
| Resume | Generation +1, erst neue Messung akzeptieren, keine alten Werte wiederbeleben |

Der Besitzer serialisiert Übergänge. `start` wählt eine Quelle; bestehendes Consent
wird nicht aus einem Sample abgeleitet. Alte Quelle/Generation wird ignoriert,
auch bei asynchronen `permission`-Ergebnissen: diese tragen `source` und `epoch`
des zugehörigen Starts. Eine späte Kamera-Ablehnung darf BLE nicht sperren.
`stop`/`suspend`/`resume` sind synchron serialisierte Besitzerentscheidungen;
SDK-Ereignisse dürfen sie erst nach derselben Tokenprüfung auslösen.
Sequenz und Messzeit müssen innerhalb einer Generation strikt steigen; doppelte oder
umgeordnete Samples werden ignoriert, ohne das Alter des letzten gültigen Werts zu
verlängern. Ein Timestamp in der Zukunft invalidiert den aktuellen Wert.
Fehlerhafte Sequenz/Zeit invalidiert, ohne sie als neue Reihenfolge zu übernehmen;
ein geordnetes, aber qualitativ ungültiges Sample verbraucht seine Sequenz/Zeit.
Ein Rücksprung der Host-Uhr ist ein Vertragsfehler, kein negativer Messwert.

Die Referenz behandelt Suspend als Besitzerzustand: Quellenwechsel umgeht ihn nicht.
Die Produktionskamera darf den Kamera-Bio-Pfad suspendieren. Eine separat verfügbare
BLE-Quelle kann nach einer expliziten Besitzerentscheidung und neuem Start/Resume
übernehmen. Keine automatische stille Auswahl und kein Besitzkampf zweier Sessions.
Generation muss ein tatsächliches Lauf-Token sein: keine Wiederverwendung durch
Neukonstruktion, Counter-Überlauf oder einen spät eintreffenden Callback.

## Modulation

**Vorgeschlagene** Route: `id` (UUID), `source`, `target` (bestehende
`ParameterAddress.description`), `depth` in `[-1,1]`, `curve` (`linear`/`square`),
`polarity` (`unipolar`/`bipolar`), `enabled` (Bool). Die Referenz verwendet beispielhaft
`body.heartRate`, `body.hrv`, `body.coherence`, `body.breath`, `lfo.1`, `macro.1`,
`midi.cc.1`; das ist **kein neuer eingefrorener Produktionskatalog**. Vor dem ersten
v3-Schreiber konkrete Quelladressierung für weitere LFOs, Makros, MIDI-Port/Kanal/CC
festlegen. Sonst würde die Referenz-Auswahl irrtümlich den W2-Scope begrenzen.

Vorgeschlagenes Startbudget: höchstens 64 Routen insgesamt, auch deaktivierte zählen.
65 wird atomar abgelehnt. Dies ist eine Kapazitätsgrenze, **kein Leistungsnachweis**.
Ids eindeutig einschließlich UUID-Schreibvarianten; Werte endlich; Ziel muss über
die vorhandene Registry auflösbar sein. Keine Adress-/Parameter-Abschrift.
Eine bekannte, vorübergehend inaktive Geräteadresse darf erhalten bleiben und wird
als inaktiv angezeigt; ein unbekannter/gelöschter Besitzer ist ein Fehler.
Löschung eines referenzierten Ziels entfernt seine Routen in derselben atomaren
Dokumentaktion, Undo stellt beide wieder her. Vor Export auch Laufzeitauflösung prüfen.

1. Baseline = automatisierter Parameterwert am Samplezeitpunkt, sonst Dokumentbasis.
2. Baseline mit bestehendem `ParameterDescriptor.normalized` nach `[0,1]` abbilden.
3. Für eine **gültige** Quelle x: unipolar u=x, bipolar u=2x−1.
4. Linear c=u; quadratisch c=u·abs(u) (Vorzeichen bleibt erhalten).
5. In kanonischer UUID-Reihenfolge summieren: `n = baseline + Σ(depth*c)`.
6. **Einmal nach der Summe** auf `[0,1]` begrenzen; nicht nach jeder Route.
7. Über `ParameterDescriptor.value(forNormalized:)` in Parametereinheiten abbilden.

Fehlend, veraltet, ungültig oder deaktiviert: Beitrag exakt null. Insbesondere ist
„bipolare Quelle fehlt“ nicht x=0 und damit nicht −depth. Automation wird nicht in
den Song zurückgeschrieben. Der Musiker ändert nur Basis/Route über die Befehlstür.
Taper (`linear`, `exponential`, `fader`, `stepped`) und Auswahlparameter behalten ihre
bestehenden Semantiken. Keine Multiplikation in Hz/dB an der Registry vorbei.
Tempo benötigt die vorhandene Sample-/TempoMap-Integration; ein normalisierter Wert
allein beweist keinen synchronen Tempoänderungspfad.

Übergänge bei Quelle/Generation, Bypass und Ausfall führen zum neutralen Beitrag
über eine begrenzte Rampe. Vorschlag: 10 ms, in Samples umgerechnet, Zustand über
Blockgrenzen erhalten. Die Referenz demonstriert nur lineare Sample-Rampen mit
Startwert an Index 0 und Zielwert an Index N. Kein Klickfreiheit-/DSP-Benchmark.
Stepped-Parameter brauchen diskrete, bewusst definierte Anwendung statt einer Folge
zufälliger Zwischenwahlwerte. Glättung pro Ziel mit seinen musikalischen Regeln.

Compile/Validierung außerhalb von Render: Zielindizes, Routenobergrenze, atomare
Snapshot-Veröffentlichung und Speicherbesitz festlegen. Ein kohärenter Snapshot
darf keine teilweise aktualisierten Mehrfeldwerte liefern. Alte Pläne dürfen erst
nach Ende aller lesenden Render-Aufrufe freigegeben werden; keine ARC-Freigabe,
Locks, Allokation, Dictionary-Suche, ObjC, Tasks oder I/O im Callback.

## Format

Aktuell ist Studio **Format 2** (`Project.currentFormatVersion`, `docs/FORMAT.md`).
Vor Implementierung W2 auf **3** erhöhen, `modRoutes` spezifizieren und vorhandene
gespeicherte Namen/ParameterAddress-Form beibehalten. Python ist keine Swift-Migration.

- v1/v2 → v3: leere Routenliste. **Keine Default-Bio-Routen**; bisheriger Klang bleibt.
- Bestehende v1-ParameterAddress-Migration weiterverwenden, nicht als Roh-JSON kopieren.
- Für das vorgeschlagene v3 ist `modRoutes` erforderlich; fehlend/falscher Typ ablehnen.
- Version >3, ungültige Version, doppelte Routen und ungültige Referenzen ablehnen.
- Ein altes Dokument mit fremdem `modRoutes`-Feld nicht still überschreiben: expliziter
  Fehler oder später dokumentierte kompatible Strategie, keine heimliche Klangänderung.
- Existierende Golden-Erwartungen bleiben erhalten; neue v3-Fixtures ergänzen und
  explizit versionierte neue Encode-Erwartungen hinzufügen. Alte Dateien nie so
  umschreiben, dass der Rückwärtskompatibilitätstest verschwindet.
- Speichern atomar über vorhandenen Dokumentbesitzer; fehlgeschlagener Save ersetzt
  die letzte gültige Datei nicht. Command-/Codec-/Undo-/Save-Tests sind getrennt nötig.

`migrate_envelope` prüft absichtlich nur Versionshülle + leere Routen und erhält die
übrigen Beispielwerte. Die Beispiele sind keine vollständigen `.echoel`-Songs.
Project-Validierung, v1-Adresse, Media, Plug-in-State und v3-Codec bleiben Swift-Abnahme.

## Export

Ein Offline-Export konsultiert keine laufende Kamera/BLE/Health-Uhr. Vor Beginn einmal
Projektgeneration, Routenplan und Quellenstrategie einfrieren:

- **Frozen**: nur zu diesem Zeitpunkt gültige Werte fixieren; fehlende bleiben fehlend.
  Dieses Snapshot-Alter läuft während Offline-Render nicht gegen die Wanduhr weiter.
- **Recorded**: explizit aufgezeichnete Quellautomation in Sample-/Songzeit abspielen,
  mit festgelegter Interpolation, Lückenregel, Metadaten und Nutzereinwilligung.

Frozen ist der minimale vorgeschlagene erste Pfad, Recorded eine folgende Scheibe.
UI benennt die Strategie; keine Behauptung, dass ein Live-Auftritt mit wechselnden
Körperwerten durch einen einzelnen eingefrorenen Wert reproduziert wird. Zwei Exporte
derselben eingefrorenen Eingabe brauchen identische Kontrollfolgen bei verschiedenen
Blockgrößen; Audio-Toleranz nur nach tatsächlich verwendetem Kernel festlegen.
Fehlgeschlagenes AU-Rendering bricht nachvollziehbar ab; eine WAV-Datei ist kein PASS.
Rohdaten/Quelle verlassen das Gerät nicht allein durch Aktivierung einer Route.

## Plattform

Nur App-Besitzer fordert Zugriff an, erst nach opt-in. Extension erbt keinen Sensorzugriff.
Benötigte Projektänderungen als getrennten konkreten Diff vorbereiten; in diesem Paket
bleiben Projekt, Entitlements, Workflows und Release-Trigger unverändert.

- Kamera: `NSCameraUsageDescription`, reale Autorisierungsprüfung und Freigabe der
  Ressource bei Stop; Produktionsaufnahme hat Vorrang.
- Bluetooth: `NSBluetoothAlwaysUsageDescription`, tatsächlichen Managerzustand,
  Autorisierung, Verbindung und Datenqualität getrennt behandeln.
- Health: passende Capability/Entitlement und Zwecktexte für die tatsächlich
  angefragten Datentypen; keine unnötigen Schreibrechte. **Leseberechtigung ist nicht
  über `authorizationStatus(for:)` feststellbar.** Keine Daten bedeutet nicht sicher
  „verweigert“. Referenzzustand `unknown` darf echte frische Health-Daten annehmen.
  Ein erfolgreich abgeschlossener Permission-Dialog ist kein Messnachweis.

Primärquellen, gelesen am 27.10.2026:
[Kamera](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription),
[Bluetooth](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription),
[Health-Leseprivatsphäre](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data),
[HKAuthorizationStatus](https://developer.apple.com/documentation/healthkit/hkauthorizationstatus).

## Abnahme

Aus dem Repository-Root:

```bash
python3 .claude/skills/g-a-body-modulation/references/reference.py --selftest
```

`--fixtures PATH` liest alternative JSON-Testdaten, `--json` liefert Details.
Exit 0 = alle ausgeführten Referenzprüfungen bestanden, 1 = falsches Ergebnis,
2 = ungültige Eingabedatei. Negative Kontrollen manipulieren je Gruppe einen Sollwert;
jede Manipulation muss eine Abweichung erzeugen. JSON enthält keine NaN/Infinity;
diese werden separat im Python-Selbsttest injiziert. `basis` begründet feste Sollwerte.

Zu portieren: S* → Zustands-/Generations-Verhaltenstests; M* → Routing-Mathematik;
F* → **nur** zusätzliche Hülltests neben echten FormatGoldenTests; R* → samplebasierte
Glättung. Zusätzlich zwingend: reale Registry/Taper, kohärente Übergabe, mehrere Metriken,
Dokumentgeneration, AUv3-Isolation, Snapshot-Export, Undo, Save/Recall und Ressourcenwechsel.
Diese Produktionsfälle bleiben NOT_RUN, bis Swift-/Gerätenachweise vorliegen.

Gerätesession, erst auf einem Build mit integriertem W1/W2, maximal fünf Aufgaben:
1. Aus starten: keine Messanzeige und kein Sensorlauf; Berechtigung bewusst verweigern.
2. Eine Quelle einschalten, Werte mit Referenz vergleichen, Aus/Verlust/Resume beobachten.
3. Eine hörbare Route samt Automation aufnehmen; Bypass, Ausfall und Undo prüfen.
4. Song speichern/wiederöffnen; Frozen-Export zweimal abhören und vergleichen.
5. Produktionskamera gegen Bio-Kamera testen; VoiceOver, große Schrift und Aus-Schalter.
Je Schritt Buildnummer, Release-SHA, Gerät/OS, Quelle, Ergebnis und Beleg erfassen.
