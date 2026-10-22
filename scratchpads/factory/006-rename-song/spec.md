# 006 — Song umbenennen

## Goal

Der Musiker gibt dem offenen Song im Song-Menü einen neuen Namen; Kopfzeile, „Open“-Liste,
Exporte und die Dateien-App zeigen ihn, und Undo nimmt ihn zurück.

## Assumptions

- A1 — Die Tür ist „Rename Song…“ im Song-Menü. Sie öffnet ein Blatt im EINEN Präsentationsplatz
  (`StudioSheet.renameSong`, Gesetz 7): ein Feld mit der Beschriftung „Name“ darüber,
  „Cancel“ und „Rename“. Kein `.alert`, weil das ein zweiter Präsentations-Modifier wäre.
- A2 — Der Name IM Song ist, was getippt wurde (`Names.validated`: getrimmt, nicht leer,
  höchstens 128 Zeichen). Das Paket bekommt die dateitaugliche Schreibweise davon
  (`ProjectLibrary.fileName`), mit Nummer, wenn ein ANDERER Song sie hat („Beat 2“). Das eigene
  Paket zählt nie als belegt: „Beat 2“ (innen „Beat“) heißt nach „Beat“ weiterhin „Beat 2“, wenn
  „Beat“ vergeben ist, und wandert nicht nach „Beat 3“.
- A3 — Das Paket folgt einer ÄNDERUNG des inneren Namens, egal woher (Tür, Undo, Redo), beim
  nächsten Schreiben. Ein Unterschied, der beim Öffnen schon bestand (ein übernommenes
  „Track (1).echoel“ mit innerem Namen „Track“), bewegt nichts, bis jemand umbenennt.
- A4 — Solange etwas aus dem Paket liest oder hineinschreibt (ein Audio-Import, eine Aufnahme
  vom Anlegen des Ziels bis zum Übernehmen, ein Export oder ein Teilen, das Laden der Medien
  eines eben geöffneten Songs), wartet die Verschiebung; das Ende dieser Arbeit und jedes
  Schreiben danach machen sie. Jeder Take zählt für sich (Runde 1: ein einzelner Schalter ließ
  einen Take den anderen freigeben). Die Tür „Rename Song…“ ist in dieser Zeit gesperrt (Runde 1:
  sonst nahm ein fertiger Export dem getippten Namen den Präsentationsplatz, und ein Songwechsel
  ließ die Datei still beim alten Namen) — warten kann damit nur ein Undo oder Redo.
- A5 — Eine Änderung nur der Groß-/Kleinschreibung („beat“ → „Beat“) benennt das Paket über
  einen Zwischennamen in zwei Schritten um. So klappt sie auch auf einem Volume ohne
  Unterscheidung der Schreibweise (APFS-Standard) und wird nicht zu „Beat 2“. Der Zwischenname
  ist NICHT versteckt: ein Song, den ein Absturz zwischen den Schritten erwischt, steht sichtbar
  in der Liste („Beat renaming 1a2b3c4d“) statt unsichtbar.
- A6 — Eine Umbenennung ist EIN Undo-Schritt mit dem Titel „Rename Song“, und das Blatt schreibt
  sofort (`saveNow`), statt die Autosave-Pause abzuwarten.
- A7 — Scheitert die Verschiebung (Platte), bleibt der innere Name geändert; `lastError` sagt
  EINMAL, dass die Datei ihren alten Namen vorerst behält, neben einer Meldung, die schon steht,
  nicht über ihr. Jedes weitere Schreiben versucht es still erneut (Runde 1: ohne Wiederholung gab
  es keinen Weg zurück, weil „Rename“ beim unveränderten Namen gesperrt ist). Scheitert bei einer
  Groß-/Kleinschreibung auch der Rückweg, folgt der Song dem Paket unter den Zwischennamen, statt
  unter dem alten Namen ein zweites Paket ohne Audio anzulegen. Sobald nichts mehr geschuldet ist
  (die Verschiebung ging durch, ein Undo nahm den Namen zurück), geht die Zeile wieder (Runde 2).
  Ein Dateiname ist in BYTES begrenzt, nicht in Zeichen: der Stamm hat höchstens 200 Bytes UTF-8,
  damit ein Name, den die Tür nimmt, nie über die 255 eines Dateinamens kommt (Runde 2).
- A8 — Ist der Start noch nicht bestätigt, folgt der Name, den der Startschutz als „wird
  geöffnet“ führt, der Verschiebung — sonst hielte ein späterer Absturz einen Namen fest, den
  es nicht mehr gibt.
- A9 — Ein anderer Song, der sich öffnet, nimmt eine wartende Verschiebung des vorigen NICHT
  mit: dessen Datei behält dann ihren Namen bis zur nächsten Umbenennung. Das ist eine Grenze
  dieser Scheibe, kein Ziel; seit Runde 1 erreicht sie nur ein Undo oder Redo während laufender
  Arbeit am Paket (A4), ebenso ein App-Ende in dieser Zeit (der Werttyp lebt nur im Speicher).
  Ein offenes Blatt gehört dem Song, für den es aufging: öffnet sich ein anderer, schließt es.
  Derselbe Song, neu gelesen, ist kein anderer: er behält eine Verschiebung, die er noch schuldet
  (Runde 2).
- A10 — WIP-Limit 3 (`docs/dev/FOUNDER_INBOX.md`, Regel 3): auf ein Geräte-Urteil warten heute
  die Familien SP (Job 002) und SR (Robustheit, 22.10.); diese Scheibe ist die dritte.

## Acceptance criteria

1. `ProjectLibrary.renamedURL(for:from:)` gibt für einen Namen, dessen Schreibweise das Paket
   schon trägt, das Paket selbst zurück; sonst eine freie Schreibweise, an anderen Songs vorbei,
   mit dem eigenen Paket als frei; der Stamm bleibt in jeder Schreibweise unter 200 Bytes — Wächter
   `ProjectLibraryTests.testARenameTakesAFreeNameAndKeepsItsOwn` und
   `ProjectLibraryTests.testAFileNameStaysWithinTheFileSystemLimit`.
2. `ProjectLibrary.rename(_:to:)` verschiebt das Paket ganz (Dokument und `Media/`), lässt keinen
   alten Ordner zurück, und eine reine Schreibweisen-Änderung hinterlässt genau ein Paket in der
   neuen Schreibweise — Wächter `ProjectLibraryTests.testARenameMovesThePackageWithItsMedia` und
   `ProjectLibraryTests.testACaseOnlyRenameKeepsOnePackage`.
3. Ein reiner Werttyp in Core entscheidet: ein geänderter innerer Name macht die Verschiebung
   fällig; „beschäftigt“ schiebt sie auf; ein späteres Schreiben im Ruhezustand führt sie genau
   einmal aus; ein anderer Song löscht sie; ein beim Öffnen bestehender Unterschied macht nichts
   fällig — Wächter in `Core/Tests/EchoelCoreTests/SongFileNameTests.swift`.
4. `DocumentController.saveNow` fragt den Werttyp VOR seiner Unverändert-Prüfung, setzt danach
   `currentURL`, die Liste (`refresh`) und den Startschutz nach; Import, Export/Teilen, Laden der
   Medien und eine Aufnahme zählen als beschäftigt — belegt durch Code-Lesen von
   `App/Documents/DocumentController.swift` und den App-Build im Workflow `Echoel Studio`.
5. Das Song-Menü hat „Rename Song…“; es öffnet `StudioSheet.renameSong` und ist gesperrt,
   solange am Paket gearbeitet wird (A4). „Rename“ ist bei leerem, zu langem oder unverändertem
   Namen gesperrt (zu lang wird gesagt), führt `.renameProject` als ein Undo-Schritt „Rename Song“
   aus und schreibt sofort — belegt durch `App/Views/StudioView.swift`,
   `App/Navigation/StudioRouter.swift`, die neue Blatt-Datei und den App-Build.
6. `RecordController` meldet eine aufgegebene Aufnahme mit IHREM Ziel (Start gescheitert, kein
   Take zurückgekommen), damit eine gescheiterte Aufnahme die Verschiebung nie für immer hält und
   nie einen anderen, noch laufenden Take freigibt —
   belegt durch Code-Lesen von `App/Engine/RecordController.swift`.
7. [DEVICE] Auf einem iPhone: den offenen Song umbenennen. Die Kopfzeile zeigt den neuen Namen
   sofort, „Open“ listet ihn, die Dateien-App zeigt das Paket unter ihm, und der Song öffnet nach
   einem Neustart mit seinem Audio. Undo stellt den alten Namen an allen drei Stellen wieder her.
8. Der Workflow `Echoel Studio` ist auf dem Kopf grün: die Wächter aus 1–3 sind im Core-Log
   namentlich bestanden, und der App-Build (Simulator und Release-Gerät) ist grün.

## Out of scope

- Andere Songs als den offenen umbenennen (aus der „Open“-Liste heraus), Songs löschen.
- Spuren oder Teile umbenennen (eigene Scheibe; im Studio gibt es dafür heute keine Fläche).
- Ein Werkzeug des Assistenten für den Songnamen.
- Eine wartende Verschiebung über einen Songwechsel hinweg (A9).
- `docs/dev/FEATURE_STATUS.md`, `ContentPipeline/CLAIMS.md` und der Store-Text: die Fähigkeit
  kommt dort erst nach dem Geräte-Urteil hinein.
