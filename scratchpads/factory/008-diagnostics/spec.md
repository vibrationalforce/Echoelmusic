# 008 — Diagnose-Log, das der Nutzer selbst exportiert (Ultra-Audit R3)

## Goal

Nach einem Absturz, einem stummen Start oder einem Aussetzer kann der Musiker in der Dateien-App
unter „Echoel → Diagnostics“ eine Textdatei teilen, die den Lauf davor und diesen Lauf zeigt:
Build, Szenenwechsel und jede Sprosse der Audio-Leiter, geschrieben VOR dem Schritt, den sie
nennt, und ohne einen einzigen Namen, den er getippt hat.

## Assumptions

- A1 — Das ist eine REPARATUR eines nicht eingelösten Plan-Versprechens, keine neue Fläche:
  `docs/dev/NEUPLANUNG_2026-10-18.md` §6 Versprechen 1 („Diagnose ist ein lokales Log, das der
  Nutzer selbst exportiert“) und `docs/dev/NEUSTART_2026-10-17.md` (der Eingang „schreibt eine
  Diagnose-Zeile VOR jedem Graph-Eingriff“). Gemessen am 2026-10-23 auf `f6143a92e`: die Leiter
  stand nur in `os_log` (auf dem Gerät für den Nutzer unsichtbar), eine Datei gab es nicht.
  `docs/dev/FOUNDER_INBOX.md` Regel 2 erlaubt zwischen den Builds Reparatur.
- A2 — KEINE neue Bedienfläche und deshalb KEIN `[DEVICE]`-Kriterium: das WIP-Limit 3 ist mit
  SP · SR · SN voll (Regel 3). Die Tür ist die Dateien-App, die die App schon heute öffnet
  (`INFOPLIST_KEY_UIFileSharingEnabled` und `LSSupportsOpeningDocumentsInPlace` stehen in
  `EchoelStudio/project.yml`, die Songs liegen im selben Documents-Ordner). Die Geräte-Bestätigung
  wird als Bitte eingetragen, sobald eine der drei Familien geschlossen ist — nicht vorher.
- A3 — Ort: `Documents/Diagnostics/Echoel diagnostics.log`. Die Bibliothek listet nur
  `.echoel`-Pakete (`ProjectLibrary`, `pathExtension == fileExtension`), also wird der Ordner nie
  für einen Song gehalten. Der Ordner ist von Backups ausgenommen (`isExcludedFromBackup`): was
  er sagt, gilt für dieses Gerät.
- A4 — Eine Datei, zwei Läufe: beim Start wandert der letzte Lauf unter „== previous run ==“, der
  davor fällt weg, darunter beginnt „== this run ==“. So reicht eine Datei, um nach einem Absturz
  zu teilen, was davor geschah. Kein Signal-Handler, kein Crash-SDK (NEUPLANUNG §6).
- A5 — Was eine Zeile tragen kann, legen die TYPEN fest, nicht eine Konvention: Ereignis, Grund
  und Feldnamen sind `StaticString` (nur Quelltext), Werte sind Zahlen, ein Fehler schreibt
  `_domain` und `_code`, nie seine Beschreibung (die einen Dateinamen tragen kann), Version und
  Build nur Ziffern und Punkte. So kommt kein Song-, Spur- oder Dateiname in die Datei, und es
  braucht keine Datenschutz-Prüfung je Aufrufstelle.
- A6 — Ein Lauf schreibt höchstens 256 KiB, dann eine letzte Zeile „this run's log is full“; die
  Datei hält also höchstens zwei Läufe dieser Größe. Jede Zeile ist ein ungepufferter Schreibzugriff
  unter einem Schloss — nie auf dem Render-Thread (Gesetz 5); alle Aufrufer laufen auf dem Main
  Actor.
- A7 — Die Zeit steht in UTC auf die Millisekunde, aus reiner Ganzzahl-Arithmetik
  (civil-from-days), damit Kalender und Zeitzone auf Linux und iOS nichts unterscheiden.
- A8 — Der Typ liegt in `EchoelCore` (nur Foundation, wie `ProjectLibrary`, das ebenfalls Dateien
  bewegt), weil die App kein Test-Target hat: nur so ist sein Verhalten auf macOS UND Linux
  getestet. Die App-Seite (`App/Documents/Diagnostics.swift`, `EchoelStudioApp`, `AudioEngine`)
  ist Compile-Beleg.

## Acceptance criteria

1. Ein Lauf beginnt mit genau einer Zeile, die Version und Build nennt, unter „== this run ==“;
   der Ordner wird angelegt. Prüfung: `DiagnosticLogTests.testARunStartsWithItsVersionAndBuild`.
2. Eine Version oder ein Build mit anderem als Ziffern und Punkten steht als „?“ in der Datei.
   Prüfung: `testAVersionThatIsNotDigitsAndDotsIsAQuestionMark`.
3. Eine Notiz steht in der Datei, bevor der Aufruf zurückkehrt (gelesen über die Datei, nicht über
   das Log), mit Grund in Klammern, ganzen Zahlen ohne Nachkomma, anderen auf drei Stellen und
   „nan“ für NaN; der Aufruf gibt die Zeile ohne Zeit zurück. Prüfung:
   `testANoteIsInTheFileBeforeItReturns`.
4. Ein neuer Lauf behält den letzten unter „== previous run ==“ und verwirft den davor, auch wenn
   der letzte nie geschlossen wurde. Prüfung: `testANewRunKeepsTheLastRunAndDropsTheOneBefore`.
5. Ein Lauf hält an seiner Kapazität mit genau einer letzten Zeile; zwei volle Läufe bleiben unter
   2 × Kapazität plus Kopfzeile; die Zeile erreicht `os_log` trotzdem. Prüfung:
   `testARunStopsAtItsCapacityWithOneLastLine`.
6. Ein Fehler steht mit Domain und Code in der Datei, nie mit seiner Beschreibung. Prüfung:
   `testAnErrorIsWrittenByDomainAndCodeNeverByItsDescription`.
7. Ein Log, das seinen Ordner nicht anlegen kann, wirft nie und schreibt nichts; eine Notiz vor
   `begin` legt keine Datei an; eine Datei, die dieses Log nicht schrieb, wird nicht übernommen.
   Prüfung: `testALogItCannotWriteStaysSilent`, `testANoteBeforeTheRunBeganIsDropped`,
   `testAFileThisLogDidNotWriteIsNotCarriedOver`.
8. Die Zeit ist UTC auf die Millisekunde, auch vor 1970 und am Schalttag. Prüfung:
   `testTheTimeIsUTCToTheMillisecond`.
9. Jede Zeile, die `AudioEngine` vorher an `os_log` gab, geht jetzt zuerst in die Datei, dann an
   `os_log`, an derselben Stelle VOR dem Schritt; neu sind Sprossen für Unterbrechungsbeginn und
   -ende und jeden Routenwechsel (mit dem Grund-Code). Prüfung: `git grep -n 'log\.\(info\|error\)'
   EchoelStudio/App/Engine/AudioEngine.swift` liefert nur noch die Zeile in `failed(_:_:)`;
   Compile-Beleg: `Echoel Studio` (App-Jobs) auf dem Kopf.
10. Die App beginnt den Lauf als ERSTES in `EchoelStudioApp.init` und schreibt jeden Szenenwechsel
    (active · inactive · background) vor seinem Handler. Prüfung: Datei:Zeile in
    `EchoelStudio/App/EchoelStudioApp.swift`; Compile-Beleg wie 9.

## Out of scope

- Eine Zeile oder ein Knopf in der App (About-Seite „Diagnose teilen“): neue Fläche, wartet auf
  einen freien WIP-Platz.
- Signal-Handler, ein „Absturz erkannt“-Hinweis beim nächsten Start, MetricKit: eigene Scheiben.
- Zeilen außerhalb von `AudioEngine` (Dokumente, Plugins, MIDI): eigene Scheibe, sobald diese
  Leiter auf einem Gerät gelesen wurde.
- Store-, Website- oder `ContentPipeline`-Text: nichts davon behauptet die Datei, und diese
  Scheibe ändert keine Behauptung nach außen.
