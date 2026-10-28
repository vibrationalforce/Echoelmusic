# Plan W2 — Routen klingen (2026-10-28)

Stand: Core fertig und lokal/CI (Modulation.value, LinearRamp, Format 3 mit `modRoutes`,
Prüfung beim Öffnen, Aufräumen beim Löschen, Kommandos `modulation.set`/`.remove`).
Es fehlt: die Engine liest Routen, die App liefert Quellen, eine Fläche legt Routen an.

## Gesetze, die hier gelten
- Render-Thread: kein Lock, keine Allokation (EchoelStudio/CLAUDE.md Law 5).
- Offline-Export friert ein: keine Live-Quelle in einem Export (format-v3-migration,
  offline-export-freeze). Erste Fassung: Export rechnet mit „alle Quellen abwesend" — eine
  Route trägt nichts bei, der Export ist deterministisch. Aufzeichnen der Quelle als Spur
  ist eine spätere, eigene Scheibe.
- Ein fehlender Messwert trägt nichts bei (G-A M02/M17), nie 0,5 als Ersatz.

## Scheiben
E1 `ModulationInputs` (EchoelEngine): je Quelle ein `Atomic<UInt64>` (Bitmuster; NaN =
   abwesend). `set(_:_:)` vom Main-Thread, `reading(_:)` render-sicher. Test: setzen, lesen,
   NaN/außerhalb 0…1 = abwesend.
E2 Snapshot kompiliert Routen je Ziel: `CompiledRoute {source index, depth, curve, polarity}`
   in Id-Reihenfolge, nur aktivierte. Zuerst NUR Mixer-Lautstärke und -Pan von Spuren und
   Master (der häufigste Fall, ein Pfad: `MovingMix`). Eine Spur mit Route gilt als bewegt.
E3 `MovingMix.gains(at:)`: Wert (Automation oder Strip) → normiert über die Taper des
   Deskriptors → + Σ Routen → einmal klemmen → zurück. Quellen geglättet über `LinearRamp`
   (≈ 20 ms) je Quelle, Zustand im EngineCore, pro Block nachgeführt.
E4 App: `HeartRateStrap.pulse.value` → `ModulationInputs.set(.heartRate, …)` im 1-s-Tick und
   bei jedem Paket; aus → NaN.
E5 Fläche: „Body → parameter" auf der Spur-/Master-Seite: Quelle, Ziel aus `project.parameters`,
   Tiefe (EchoelValueField-Äquivalent in Studio), Kurve, Polarität; durch `ProjectStore.perform`.
E6 Weitere Ziele: Synth-Patch-Werte (`PatchAutomation`), Plugin-Parameter, Sends.
Danach erst TestFlight: „Puls bewegt Lautstärke" ist die erste hörbare Körper-Modulation.

## Offene Founder-Fragen (keine blockiert diesen Plan)
- Geräte-Test: klingt die Puls-Modulation musikalisch (Tiefe-Default)? — nach E5.
