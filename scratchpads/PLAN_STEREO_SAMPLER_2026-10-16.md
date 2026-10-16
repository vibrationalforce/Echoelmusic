# PLAN — Stereo-Sampler (Live-Set-Audit, Posten „Sampler stereo + Überlappung")

Stand 2026-10-16. ⛔ **PRÄMISSE ZURÜCKGENOMMEN (dieselbe Stunde):** `PolySynthVoice` rendert
**stereo** (`channels: 2`), also ist der Spur-Bus — Format der ersten Quelle — schon stereo. SS0 und
SS1 unten sind GESTRICHEN. Gebaut statt dessen: **SP1** (Sampler nimmt den Spur-Pan, Inspektor bietet
das Feld). Bleiben: SS2 (Stereo-Samples) und SS3 (Überlappung). Der Rest dieser Datei ist die
ursprüngliche, falsche Herleitung — stehen gelassen, damit niemand sie neu herleitet.

Council inline, Gate: **MITIGATE → erst messen, dann bauen.**

## Gemessen
- `SamplerVoice.loadSample` faltet jede Datei auf Mono (`resampleToMono`), Knoten-Format 1 Kanal.
- `LaneVoiceRack.noteOn` `.sampler`: dokumentierter Drum-Machine-Vertrag — ein neuer Treffer
  setzt auf den Anfang zurück, keine Überlappung.
- **Der Blocker:** `AudioEngine.attachTrackBus` nimmt das Format der ERSTEN Quelle als
  Bus-Format (`ownFormats.first`), und die erste Quelle ist `voices[slot]` (Mono-Synth). Ein
  Stereo-Sampler würde am Spur-Bus wieder auf Mono gefaltet — der Umbau in `SamplerVoice`
  allein liefert kein Stereo.
- `StemTapPoint.capture` kann zwei Puffer schon (seit LS-ST1 am Sampler).

## Council (eine Zeile je Sitz)
- Architect: Bus-Format von „erste Quelle" auf „breiteste Quelle" (max channelCount) — eine Zeile, aber jede Spur.
- DSP Purist: Stereo braucht ein zweites `ChannelInsertFX` (Filterzustand je Kanal) und den NaN-Sweep je Kanal.
- Shipper: kein lokaler Compiler; Stereo und Überlappung NIE in einer Scheibe.
- Skeptic: ein Stereo-Bus ändert das Pan-Gesetz der Spur (`setPan` auf Mono-Bus = Pan, auf Stereo-Bus = Balance?) — nicht gemessen, also nicht bauen.
- User-Advocate: Stereo-Loops klingen heute mono — hörbar. Überlappung fehlt nur bei schnellen Wiederholungen.
- Vision-Keeper: gehört zum DMMW-Umfang, kein Scope-Problem.

## Reihenfolge
1. **SS0 Messung:** CISmoke-Wächter mit `AVAudioEngine` im manuellen Render-Modus (offline,
   kein HAL): Mono-Quelle → Mono-Bus → Master mit pan −1/0/+1 gegen Mono-Quelle → STEREO-Bus →
   Master. Zahlen je Kanal festhalten. Entscheidet, ob ein Stereo-Bus das Pan-Gesetz hält.
2. **SS1 Bus-Format = breiteste Quelle** — nur wenn SS0 gleiches Pan-Gesetz zeigt (sonst Pan am
   Bus-EINGANG statt am Bus).
3. **SS2 Sampler stereo:** Slab planar (L dann R, `channels` im Slab), Konverter auf 2 Kanäle
   wenn die Quelle ≥2 hat, zweites InsertFX, Knoten 2 Kanäle; ein 1-Puffer-ABL (Tests) bekommt
   (L+R)/2.
4. **SS3 Überlappung** — eigener Vertragsbruch (Drum-Machine-Retrigger), mit Choke-Option;
   erst nach SS2 und Geräte-Hörprobe.

**Stand 2026-10-16:** SS2 GEBAUT (`37b8c7c`, Wächter `TheSamplerKeepsAStereoSampleStereoTests`). SS3 wartet auf FOUNDER_INBOX E36.

Geräte-Hörprobe nach SS2: Stereo-Loop auf Sampler-Spur, Pan links/rechts, klingt die Breite?
