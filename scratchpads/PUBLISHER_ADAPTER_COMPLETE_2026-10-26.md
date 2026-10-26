# Publisher-Adapter Bridge — Complete
2026-10-26

## Components
1. **BodyFrameSource** (`@Observable`) — holds heartRate, hrvNormalized, coherence, isActive.
2. **BodyFramePublisherAdapter** — thin class with `update(...)` that writes into the source. Includes a `startDemo()` for immediate visibility.
3. **BodyFrameView** — reads `@Environment(BodyFrameSource.self)` and displays the values with full accessibility and off-switch.

## Next (still ≤3 files)
- In `EchoelStudioApp` or `StudioView`: create one `BodyFrameSource` and one adapter, inject the source as environment, and call `startDemo()` on appear so the display shows values immediately.
- Later replace `startDemo()` with a real call from the ported publisher.

## Status
Bridge is complete and ready. No rules changed.

*Proactive completion of the requested adapter.*