# 007 — Umbenennen härten (die Minor-Befunde aus Job 006, Runde 3)

## Goal

Die Tür „Rename Song…“ (Job 006) bleibt, wie sie ist; diese Reparatur schließt die fünf
Doppel- und Dreifachfehler, die die letzte Prüfrunde gemessen hat, damit ein Song nie in ein
fremdes Paket schreibt, nie ohne Satz unter einem Zwischennamen liegen bleibt und ein
VoiceOver-Nutzer die Längen-Grenze hört.

## Assumptions

- A1 — Reparatur einer gebauten Scheibe, keine neue Fläche (`docs/dev/FOUNDER_INBOX.md`,
  Regel 2: zwischen den Builds Reparatur und freigegebene Scheiben). Das WIP-Limit 3 bleibt bei
  SP · SR · SN; diese Arbeit ist keine vierte Scheibe. Quelle aller Befunde:
  `scratchpads/factory/006-rename-song/reviews/round-3/` (code-reviewer m1/m2, security-agent m1,
  ux m1/m2/m3), jeder am Code nachgemessen am 2026-10-22.
- A2 — Ob ein gescheiterter Rückweg das Paket gestrandet hat, fragt der Code das PAKET (liegt
  noch etwas unter dem Zwischennamen?), nicht den alten Namen. Den alten Namen kann in der
  Zwischenzeit ein anderes Paket belegt haben — der Import der früheren Songs reserviert Namen
  abseits des Main-Threads. Der Import zählt deshalb NICHT als „beschäftigt“: er schreibt in
  andere Pakete, nie in das offene; das Rennen schließt die richtige Frage, nicht ein längeres
  Warten.
- A3 — Ein gestrandetes Paket folgt keinem Namen mehr: JEDER Name ist dann fällig, auch der alte,
  bis eine Verschiebung gelingt oder ein anderer Song sich öffnet. So bringt ein Undo zurück zum
  alten Namen das Paket ebenfalls zurück, statt die Zeile zu löschen und es unter dem Zwischennamen
  zu lassen.
- A4 — Öffnet sich ein Song, dessen Paket einen Zwischennamen trägt („<Stamm> renaming 1A2B3C4D“,
  genau so, wie `rename` ihn schreibt: acht Zeichen in Großbuchstaben-Hex, auf jeder Plattform
  groß geschrieben; Runde 1), gilt es als gestrandet: das nächste Schreiben gibt ihm den
  Namen seines Songs. Das ist eine bewusste Ausnahme von Job 006 A3 („ein Unterschied beim Öffnen
  bewegt nichts“): diesen Namen hat kein Musiker gewählt, ihn hat ein abgestürzter oder
  gescheiterter Zwei-Schritt-Umzug hinterlassen. Grenze: ein Paket, das jemand in Dateien von Hand
  genau so benennt und dessen innerer Name abweicht, bekommt beim nächsten Schreiben seinen
  inneren Namen.
- A5 — Die Zeile über eine gescheiterte Verschiebung sagt, wo die Datei JETZT ist, in EINEM Satz,
  der in jedem Zustand stimmt: „In the Files app the song is called <Datei> for now; Echoel tries
  again when it next saves.“ Kein „renamed“ mehr (Runde 1): nach einem Undo zum alten Namen und bei
  einem Song, der aus einem Zwischennamen öffnete, hat niemand umbenannt. Weil der Satz nur den Ort
  nennt, ändert er sich genau dann, wenn der Ort sich ändert (ein späterer Versuch strandet unter
  dem Zwischennamen); dann ersetzt der neue den alten, derselbe wird nie zweimal gesagt.
- A6 — Wählt der Musiker den offenen Song in „Open“ erneut, liest der Code das Paket dort, wo es
  nach dem Speichern davor liegt: das Speichern kann eine geschuldete Verschiebung eben ausgeführt
  haben, und die alte URL gibt es dann nicht mehr.
- A7 — Der Test-Saum für den Rückweg ist ein interner Parameter (`moving:`) von `rename`; die
  öffentliche Schnittstelle bleibt `rename(_:to:)`. Kein neuer Typ, keine Abhängigkeit.
- A8 — VoiceOver: das Namensfeld trägt die Zeile darunter als Hinweis; wird der Name zu lang,
  sagt die App „At most 128 characters.“ an (`AccessibilityNotification.Announcement`, wie die
  alte App mit `import SwiftUI`), mit HOHER Priorität, damit das Echo der Taste oder des Einfügens
  sie nicht überspricht (Runde 1; Form aus Apples WWDC23-Beispiel, `AttributedString` mit
  `accessibilitySpeechAnnouncementPriority = .high`). „Rename“ trägt denselben Satz als Hinweis,
  solange es deshalb gesperrt ist. Die Zeile selbst ist für VoiceOver verborgen, weil Hinweis und
  Ansage sie tragen — sonst käme sie beim Durchwischen zweimal.

## Acceptance criteria

1. Ein Wechsel nur der Schreibweise, dessen zweiter Schritt UND Rückweg scheitern, während ein
   anderes Paket den alten Namen belegt hat, wirft `ProjectLibrary.RenameStranded` mit dem Paket
   unter dem Zwischennamen (es hält `Media/`), und das andere Paket bleibt unberührt; scheitert nur
   der zweite Schritt und der Rückweg gelingt, kommt der Fehler selbst und das Paket liegt wie
   vorher. Der Rückweg im ersten Wächter ist ein ECHTER Umzug auf den belegten, leeren Ordner
   (Runde 1: POSIX `rename(2)` ersetzte einen leeren Ordner; der Schutz hängt daran, dass der Umzug
   einen belegten Namen verweigert) — Wächter
   `ProjectLibraryTests.testAStrandedRenameIsFoundByItsPackageNotItsOldName` und
   `ProjectLibraryTests.testACaseRenameThatGoesBackLeavesThePackageAsItWas`.
2. `ProjectLibrary.isBetweenStem` erkennt den Zwischennamen, den `rename` schreibt, und keinen
   gewöhnlichen Namen (auch nicht „renaming“ ohne die acht Zeichen, und nicht die acht Zeichen in
   Kleinbuchstaben) — Wächter
   `ProjectLibraryTests.testTheNameInBetweenIsKnownAgain`.
3. `SongFileName.stranded()` macht jeden Namen fällig, auch den gefolgten; „beschäftigt“ schiebt
   ihn weiter auf; `followed(_:)` und `opened(named:)` heben es auf — Wächter
   `SongFileNameTests.testAStrandedPackageIsOwedEvenUnderItsOldName`.
4. `DocumentController`: der gestrandete Zweig von `followRenamedSong` ruft `fileName.stranded()`;
   `open(throwing:)` markiert ein Paket mit Zwischennamen als gestrandet und liest den offenen Song
   nach `mayLeaveSong` unter `currentURL`; `moveFailed` sagt EINEN Satz, der nur den Ort nennt,
   ersetzt eine stehende Zeile, wenn der Ort sich geändert hat, und sagt einen gleichen nie zweimal
   — belegt durch Code-Lesen von
   `App/Documents/DocumentController.swift` und den App-Build im Workflow `Echoel Studio`.
5. `RenameSongView`: Hinweis am Feld, Ansage mit hoher Priorität beim Überschreiten der Länge,
   Hinweis an „Rename“, die Zeile unter dem Feld für VoiceOver verborgen —
   belegt durch Code-Lesen von `App/Views/RenameSongView.swift` und den App-Build.
6. [DEVICE] Mit VoiceOver: im Blatt „Rename Song“ über 128 Zeichen hinaus tippen (z. B. einen
   langen Text einfügen). VoiceOver sagt „At most 128 characters.“; „Rename“ wird als gedimmt
   mit demselben Satz vorgelesen.
7. Der Workflow `Echoel Studio` ist auf dem Kopf grün: die Wächter aus 1–3 sind im Core-Log
   namentlich bestanden, und der App-Build (Simulator und Release-Gerät) ist grün; `Echoel Studio
   (Linux)` ebenso.

## Out of scope

- Alles, was Job 006 schon als außerhalb geführt hat (andere Songs umbenennen, Spuren, der
  Assistent, eine Verschiebung über einen Songwechsel).
- Den Import der früheren Songs als „beschäftigt“ zu zählen (A2).
- Der Wortlaut von Kriterium 1 aus Job 006 bleibt im freigegebenen Job stehen; die Korrektur
  steht in dessen `board.json`.
