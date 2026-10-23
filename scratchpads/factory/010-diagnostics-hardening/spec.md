# 010 — Diagnose-Log härten (die Runde-1-Minors aus Job 008)

## Goal

Die Datei, die ein Musiker nach einem Absturz teilt, zeigt den gestorbenen Lauf auch dann, wenn der
letzte Byte mitten in einem Zeichen abriss. Sie nimmt keine fremde Zeile mit und bleibt auch bei einer
absurden Fehler-Domain einzeilig. Sie sagt, dass ihre Zeiten UTC sind und welcher Lauf der LETZTE ist,
nicht „dieser“. Und der Log beginnt wirklich vor jedem anderen Code des Starts.

## Assumptions

- A1 — Reparatur einer gebauten Scheibe, keine neue Fläche (WIP 3 voll, FOUNDER_INBOX Regel 2/3):
  jede Änderung kommt aus einem Minor der Job-008-Runde 1 (`wf_dca9ce6d-79c`,
  `scratchpads/factory/008-diagnostics/reviews/round-1/`). Kein `[DEVICE]`-Kriterium aus demselben
  Grund wie 008 A2.
- A2 — Gemessen: `EchoelStudio/RELEASE` änderte sich zuletzt VOR `42d91ecfb`
  (`git merge-base --is-ancestor 394299ab2 42d91ecfb`), kein ausgelieferter Build trägt also das
  Format von 008. Die Kopfzeilen umzubenennen kostet keinem Tester einen Lauf.
- A3 — „Latest run“ statt „this run“: nach einem Absturz und vor dem nächsten Start ist der letzte
  Lauf der Datei der gestorbene; „this run“ las sich dort wie der laufende. Die Startzeile endet mit
  „, times in UTC“, weil die Zeiten UTC sind und der Musiker Ortszeit erwartet.
- A4 — Mitgenommen wird nur, was die Form einer eigenen Zeile hat (Zeitstempel
  `0000-00-00T00:00:00.000Z  `, danach ein Zeichen, kein Steuerzeichen). Eine Zeile, die jemand in
  der Dateien-App dazuschrieb, erreicht so nie die nächste geteilte Datei. Gelesen wird nur das Ende
  der Datei (2 × Kapazität + 64 Byte; der letzte Lauf einer eigenen Datei ist höchstens eine
  Kapazität lang), dekodiert verlustbehaftet, sodass ein abgerissenes Byte ein Zeichen kostet und
  nicht den Lauf. Übernommen werden die NEUESTEN Zeilen, die in eine Kapazität passen.
- A5 — Eine Fehler-Domain behält ASCII-Buchstaben, Ziffern, `.`, `-`, `_`; jedes andere Zeichen
  wird `_`, und es bleiben die LETZTEN 64 Zeichen: das Ende nennt den Typ, der Anfang das Modul
  (eine private Swift-Fehlerart hat `(unknown context at $…)` in der Mitte).
- A6 — Bleibt draußen: das Ende eines vollen Laufs statt seines Anfangs behalten (Entwurf A6 von
  008, eigene Scheibe), ein Satz in `docs/privacy.html` (sensible Datei), die Testerinfo zum Pfad.

## Acceptance criteria

1. Nur eigene Zeilen wandern in den Lauf davor: `testOnlyTheLogsOwnLinesAreCarriedOver` und
   `testAFileThisLogDidNotWriteIsNotCarriedOver` grün.
2. Ein abgerissenes UTF-8-Byte am Dateiende kostet den Lauf davor nicht:
   `testABrokenByteDoesNotCostTheRunBefore` grün.
3. Eine übergroße Datei wird nur am Ende gelesen, und übernommen werden die neuesten Zeilen, die in
   eine Kapazität passen: `testAnOversizedFileIsReadOnlyAtItsEnd` grün.
4. Eine Fehler-Domain bleibt eine kurze Zeile (`._-`, Buchstaben, Ziffern, die letzten 64):
   `testAnErrorDomainStaysOneShortLine` und `testAnErrorIsWrittenByDomainAndCodeNeverByItsDescription`
   grün.
5. Die Voll-Zeile trägt ihren Zeitstempel, und der Lauf bleibt in der Kapazität, die aus der
   echten Zeitstempel-Länge gerechnet ist: `testARunStopsAtItsCapacityWithOneLastLine` grün.
6. Die Uhr läuft nie unter dem Schloss: in `DiagnosticLog.swift` steht jedes `Self.timestamp(clock())`
   vor `lock.lock()` in derselben Funktion. Prüfung: Code lesen.
7. Kopfzeilen „== latest run ==“ / „== run before ==“, die Startzeile endet mit „, times in UTC“:
   `testARunStartsWithItsVersionAndBuild` und `testANewRunKeepsTheLastRunAndDropsTheOneBefore` grün.
8. `StoreController()` wird in `EchoelStudioApp.init()` NACH `DiagnosticLog.beginApp()` gebaut,
   nicht als Vorgabewert der Eigenschaft. Prüfung: Code lesen.
9. `AudioEngine.failed(_:_:)` gibt die Fehlerbeschreibung an `os_log` mit `privacy: .private`.
   Prüfung: Code lesen.
10. Auf dem Kopf sind „Echoel Studio“ (macOS: Core-Tests, App für Simulator und Release-Gerät) und
    „Echoel Studio (Linux)“ grün.

## Out of scope

- Ende statt Anfang eines vollen Laufs behalten (A6).
- Website-, Datenschutz- und Store-Text.
- Jede neue Leiter-Sprosse.
