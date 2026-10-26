# Publisher-Adapter Status — 2026-10-26

## Erstellt
`EchoelStudio/App/Models/BodyFramePublisherAdapter.swift`

- Schmaler @MainActor Adapter.
- Schreibt in BodyFrameSource: heartRate, hrvNormalized, coherence, isActive.
- Hat `pushPlaceholder()` für Demo/Tests.

## Nächster Schritt (entschieden)
In StudioView oder einem Test den Adapter instanziieren und `pushPlaceholder()` aufrufen, damit die Anzeige echte (Demo-)Werte zeigt.

Dann echten Publisher anbinden.

**Status:** Adapter steht. Kette bereit.
