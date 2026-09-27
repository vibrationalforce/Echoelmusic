# EchoelAI als Bedienagent — Aktionsschicht, Stand und Abdeckung (2026-09-27)

Founder-Auftrag 2026-09-27 („Ergänzung zum laufenden Auftrag: EchoelAI als integrierter
Bedienagent"). Lokaler Feature-Branch `feature/media-seed-2026-09-27`, kein Push.

## 1. Was vorher da war (gemessen, nicht erinnert)

| Baustein | Datei | Stand |
|---|---|---|
| Sprachschicht, anbieterneutral | `Core/EchoelLanguageModel.swift` (`EchoelLanguageModel`, `EchoelAIRouter`, `DeterministicLanguageModel`, `EchoelAIError`) | beantwortet TEXT; plant keine Aktionen |
| Apple-Foundation-Models-Adapter | `EchoelAI/FoundationModelsBrain.swift`, `BrainBackend.swift` | **null Aufrufer**, nie auf einem Gerät gelaufen |
| Parameter-Werkzeuge | `EchoelAI/ParameterToolCore.swift` | Logik für list/search/set über die Registry; keine Tür |
| `FeatureFlags.echoelAI` | — | **null Leser**; schützt nichts |
| AppIntents | `Studio/EchoelAppIntents.swift` | drei Intents, eigener Pfad |
| Song-Undo | `Core/TimelineStore.swift` | Teile, Noten, Automation, Clip-Quelle — **Pegel/Mixer absichtlich NICHT** |
| Auswahl | `Studio/WorkstationSelection.swift` | EIN Besitzer, veraltete IDs lösen beim Lesen zu nil auf |

Folge für den Entwurf: keine zweite Engine, kein zweites Dokument. Der Agent liest die zwei
kanonischen Besitzer und schreibt über dieselben Schreiber wie die Buttons.

## 2. Gebaut (Schritt 1)

- `EchoelAI/EchoelCommand.swift` — `EchoelCommandID` (stabile IDs), `EchoelCommand` (typisierte
  Parameter, Ziele `.selected` oder `.id(UUID)`), `EchoelCommandSpec` in EINER Registry
  (Parameter · Vorbedingungen · Wirkung · Undo-Verhalten · Berechtigungsklasse),
  `EchoelProposedAction` (was ein Modell vorschlägt: DATEN) → `EchoelCommandParser`,
  `EchoelLevelMath` (verweigert statt zu klammern), `EchoelActionPlan` (Anfrage-ID, Schritte,
  gesehener Zustand, Einwilligungen NUR vom Menschen), `EchoelExecutionReport` +
  `EchoelAgentState` (Understood · Working · Done · Question · Failed), die Planer-Naht
  `EchoelActionPlanning` + `EchoelPlanning.plan` (kein Planer → „No language model is
  connected"; Planer wirft → „did not answer. Nothing was changed.").
- `EchoelAI/EchoelCommandExecutor.swift` — `@MainActor`, prüft Zustand vor dem Start,
  Idempotenz je Anfrage-ID, busy, Abbruch zwischen Schritten, Teil-Erfolg, Nachprüfung nach
  jedem Schritt, eigenes Undo-Journal mit Konfliktschutz.

## 3. Abdeckungsmatrix — Nutzerfunktion → Befehl → Test → Lücke

| Nutzerfunktion (Tür) | Befehl | Test | Lücke |
|---|---|---|---|
| „Was ist ausgewählt?" | `project.describeState` | `TheAgentActsThroughTheButtonsPathsTests` Claim 1 | — |
| Spurpegel (Inspektor „Level") | `track.setLevel` (dB rel./abs.) | Claims 2, 3, 6 | — |
| Teil kopieren (Teil-Leiste „Copy") | `part.duplicateAfter` | Claims 4, 5, 6, 7 | — |
| Letzte Agenten-Änderung zurück | `agent.undoLast` | Claim 6 | — |
| Song-Undo-Knopf | — | — | Nachprüfung fehlt: ein Noten-Undo ändert den `ClipStore`, nicht das Dokument; der Store hat keine beobachtbare Revision. Erst eine Revision/Zählung am Store, dann der Befehl |
| Pan · Mute · Solo · Umbenennen | — | — | Schreiber existieren (`TrackMix.setPan/flipMute/flipSolo/rename`); je ein Befehl + Nachprüfung, gleiche Form wie Level |
| Teil verschieben · trimmen · teilen · entfernen | — | — | Schreiber existieren (`TrackParts.move/remove`, `resizeRegion`, `splitRegion`); Teilen braucht das Medien-Tempo wie `SelectedPartBar` |
| Spur hinzufügen / entfernen | — | — | `AudioImport.addAudioTrack`, `TrackMix.removeTrack` (Regel `TrackMix.removal`) |
| Szene starten „am nächsten Takt" | — | — | Weg existiert: `TimelineRegionPlayer.launchScene(_:quantize:)` bzw. `playFrom` — der TRANSPORT quantisiert, das Modell ist keine Uhr. Der Ausführer braucht dafür den Player als Abhängigkeit |
| Foto-Farben für die Visuals | — | — | `MediaSeedApplication` + `MediaLookUndo.shared` sind echt; der gewählte Seed lebt aber im `@State` der Karte. Erst den zuletzt gelesenen Seed an einen Besitzer heben, dann der Befehl (Undo gibt es schon) |
| Video → „vier spielbare Ausschnitte" | — | — | NICHT ausführbar: MS4/MS5 gehalten (`PLAN_MEDIA_SEED_2026-09-27.md` §5). Der Agent darf es nicht behaupten |
| Alles stoppen | — | — | bleibt bewusst beim Menschen (`EchoelStudioView.stopEverything`, Transport ■), unabhängig vom Agenten |
| Veröffentlichen · Senden · Original löschen · Export überschreiben | Klasse `explicitConsent` | Claim 1 (Registry) | kein solcher Befehl registriert; die Klasse und die Prüfung im Ausführer stehen |

## 4. Sprach-/Modellanbindung — ehrlich

**Keine.** Es gibt eine Naht (`EchoelActionPlanning`) und ihre Fehlerpfade, keinen Planer.
Kein Schlüsselwort-Matcher wird als KI ausgegeben. Nächster Schritt: `FoundationModelsBrain`
als `EchoelActionPlanning` (on-device, iOS 26) — braucht eine Gerätesitzung, weil die
Tool-/@Generable-API hier nicht kompiliert werden kann. Cloud nur nach Opt-in mit Nennung der
gesendeten Daten; Medien- und Bio-Rohdaten standardmäßig nie.

## 5. Nächste Scheiben (je klein, je mit Wächter)

1. Agenten-Fläche ohne neuen Modal: eine Zeile im Workstation-Blatt mit Textfeld, Zustand in
   Worten, „Cancel" / „Undo" — aber erst, wenn ein Planer existiert; ohne Planer wäre die Fläche
   eine Tür zu „No language model is connected".
2. Pan · Mute · Solo · Umbenennen als Befehle (gleiches Muster).
3. Szene am nächsten Takt über den Player.
4. Foto-Seed an einen Besitzer heben → „Nutze die Farben dieses Fotos".
5. Store-Revision → Song-Undo als Befehl mit Nachprüfung.

## 6. Prüfung

Kein Swift hier. Beide Wächter per Python transkribiert (Treiber im Session-Scratchpad), sieben
Mutanten je aus dem genannten Grund rot. `dead-needles` · `count-pins` (0 RED) ·
`swift-escapes` · `foreign-needles` · `moved-needles` sauber. **Nicht kompiliert, nicht gepusht,
nicht auf dem Gerät.**
