# DMMW Phase 1 — UX-Shell und Navigation (2026-09-29)

## Stand VOR der Änderung

- Branch lokal `feature/media-seed-2026-09-27`, Push-Ziel `claude/echoelmusic-review-optimize-u5jjpd`
- HEAD = Remote-Branch = `8b89a59a4` (nur Checkpoint-Notizen über `9ce3dfd50`)
- `main` = `9ce3dfd50`
- Gates auf `9ce3dfd50`: Xcode Compile Check 36560451034 grün; CI/CD 36560450977 —
  Build for Testing grün, Run Tests grün („Test execute Succeeded“)
- TestFlight: Build 2605 auf `9ce3dfd50` = `state=VALID`

## Bestandsbericht (aus dem Code gelesen, drei Lese-Agenten + eigene Lektüre)

**Shell.** `WorkspaceView` = Kopfleiste (`topBar`) + `CompositionHeaderStrip` +
`EchoelStudioView` + schwebendes Visual-Fenster. Im Instrument: Start-/Transport-Zeile,
dann die Chip-Leiste, dann eine Platte (das Panel des gewählten Chips).

**Chip-Leiste.** Die Leiste zeigt neun Chips in Signalfluss-Reihenfolge: Sound · FX · Mix ·
Master · Mood · Tempo · Field · Workstation · Save/Export. Den zehnten, Bio, öffnet nur die
Puls-Pille. Die Leiste scrollt horizontal und läuft auf einem Telefon über (#291/#607). Sie
ist eine flache Liste ohne Bereichsstruktur: der Nutzer sieht „welches Panel“, aber nicht
„in welchem Teil der Arbeit bin ich“.

**Zwei Transporte.** Das Instrument (`PatternEngine`, Play/Stop in der Start-Zeile) und die
Workstation (`TimelineRegionPlayer`, eigener Play/Stop auf der Workstation-Platte) haben je
einen eigenen Transport. Einen globalen Transport- oder Timeline-Bereich gibt es noch nicht;
er ist Thema einer eigenen Phase (Arrangement/Performance) und wird hier nicht angefasst.

**Was fehlt oder versteckt ist:**
- kein Settings-Bildschirm. Einstellungen sind verstreut: `utilityRow` hinter
  „Save/Export“, das Master-Panel und das Routing-Sheet hinter der EchoelLux-Kachel.
- keine Tür „Neues Projekt“.
- keine Instrumentenwahl je Spur. Das Gerät des Echoel-Tracks öffnet `soundPanel`.
- die Bibliothek ist zweigeteilt. Die Projekte erreicht man nur über das Open-Sheet
  (`openSheet`); die Medien liegen hinter einem Workstation-Chevron.
- viele Workstation-Funktionen erscheinen erst nach einer Auswahl oder hinter einem Chevron.

**Barrierefreiheit (gefunden, nicht Teil dieser Scheibe):**
- Treffbereich der Workstation-Spurzeile etwa 32 pt (unter 44)
- Transport-Glyphen in fester Größe, ohne Large Content Viewer
- Brand-Button unter 44 pt
- die Chrome ist auf `.accessibility1` gedeckelt
- dem Immersive-Schalter fehlen Wert, Hint und Trait

**Gesetze, die die Lösung begrenzen:**
- Black-Screen-Kette: kein neuer Modal. 11 auf der Kette, 12 dateiweit, gepinnt.
- Freeze-Gesetz: kein 10-Hz-Read im `body`.
- #572: keine Chips verstecken — „ORDER or EMPHASIS, not absence“.
- D10: keine alte Shell zurück, eine Wurzel mit austauschbaren Platten.
- Die Chip-Reihenfolge ist Founder-Entscheidung.

## Kleinste sinnvolle Shell-Verbesserung (diese Scheibe)

**Eine Bereichs-Zeile über der Chip-Leiste: Compose · Perform · Visuals · Library ·
Settings.** Jeder Bereich wählt seine Heimat-Platte, und der zugehörige Chip darunter leuchtet
auf.

| Bereich | Heimat | Platten im Bereich |
|---|---|---|
| Compose | Workstation | Workstation, Tempo, Mood |
| Perform | Sound | Sound, FX, Mix, Master, Bio |
| Visuals | Field | Field |
| Library | Projektliste (bestehendes `showOpen`-Sheet) | — |
| Settings | Save/Export | Save/Export |

- **Kein Chip entfernt oder umsortiert** (#572), kein neuer Modal (Library nutzt `showOpen`).
- Kein Hot-Read: die Zeile liest nur `displayedMenu`, das sich auf Tipp ändert.
- 44-pt-Ziele. Jeder Button hat VoiceOver-Label, Hint und `.isSelected`.
- Dynamic Type: `ViewThatFits` fällt bei großer Schrift auf horizontales Scrollen zurück,
  statt Text zu verkleinern.
- Tippt man auf den Bereich, in dem man schon ist, bleibt die Platte (Perform auf Mix
  bleibt Mix).
- `StudioMenu.area` ist ein erschöpfender Switch: eine neue Platte kompiliert erst, wenn sie
  einen Bereich wählt.

Dateien: `Studio/StudioArea.swift` (neu, rein), `Studio/EchoelStudioView.swift`,
`Tests/CISmoke/EveryPlateBelongsToOneAreaTests.swift` (neu).

## Grenzen dieser Scheibe

- **Settings zeigt auf „Save/Export“.** Das ist heute die einzige Einstellungs-Platte. Die
  I/O-Einstellungen (Routing) bleiben hinter der EchoelLux-Kachel. Ein echter
  Settings-Bildschirm ist eine eigene Scheibe.
- **Library öffnet nur Projekte.** Die Medienbibliothek bleibt in der Workstation.
- **Der globale Transport ist nicht gebaut** (siehe oben).
- **Die Zeile kostet eine Zeile Höhe** (44 pt) über der Platte.
- **NEEDS-FOUNDER-VERIFY:** Aussehen, Passform auf dem Telefon und VoiceOver-Ansage sind
  nur am Gerät prüfbar.
