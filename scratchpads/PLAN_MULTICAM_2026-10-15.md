# PLAN — Echoel Multicam (YoloBox-Ersatz), 2026-10-15

Founder 2026-10-15: „Im Prinzip soll die Technologie von YOLObox auch ersetzt werden. Also mehrere
Kameras captured und syncen plus Audio aber auf professionellste Art und Weise direkt in die
Echoelmusic Software bzw als Stream, Colabo und Content Schmiede."

## Was YoloBox Ultra kann (Händlerangaben, nicht Herstellerdoku)
4× HDMI + USB-C/USB-A Eingänge · NDI + SRT ein/aus · RTMP/RTMPS · ISO-Aufnahme jedes Eingangs +
Programm · Multistream (3× quer, 2× hoch) · Line/Mic-In · Grafiken/Overlays.

## Was das iPhone kann und was nicht (gemessen per Recherche, nicht am Gerät)
- **USB/HDMI-Kameras (UVC): nur iPad** mit USB-C. Auf dem iPhone findet `AVCaptureDevice`
  keine externen Kameras (Apple-Forum-Antworten, Doku nennt „On iPad"). → HDMI-Eingänge = iPad-Ziel.
- **Front + Rück gleichzeitig:** `AVCaptureMultiCamSession` (XS/XR und neuer). Keine Abhängigkeit.
- **Weitere iPhones als Kameras:** nur übers Netz — eigenes Echoel-zu-Echoel (Multipeer/Network,
  keine Abhängigkeit), SRT (Blackmagic Camera ≥ 3.2 sendet SRT/RTMP; Empfang braucht libsrt, C,
  MPL-2.0), NDI (NDI-SDK; iOS-Lizenz bei NDI zu klären).
- **Audio-Interfaces** (BiG SiX, Xone:96) über USB-C: class-compliant am iPhone möglich; hängt am
  Mikrofon-/Eingangs-Landing E10-1 (Info.plist, founder-gated).
- **Stream raus:** RTMP/SRT braucht eine Bibliothek (HaishinKit, geplant, nicht verlinkt).

## Was Entfalt beiträgt (vibrationalforce/entfalt, Zweig claude/entfalt-bootstrap-rlkkrk)
Kein iPhone-Code (Bash/ffmpeg, Remotion, Marketing-Skills) — aber erprobte SPEZIFIKATIONEN, die
als Export-/Content-Logik ins Produkt portiert werden (Recovery-Prinzip: Kern portieren, nichts
hineinkopieren):
- `pipeline/scripts/studio.sh`: Zeitversatz zweier Aufnahmen (`--versatz`), Zoom-Ausschnitte im
  Zielverhältnis, Bild-im-Bild-Ecken, hoch 1080×1920 / quer 1920×1080 — das ist das Multicam-
  Schnitt-Rezept, heute von Hand.
- `pipeline/scripts/loudnorm.sh`: −14 LUFS / TP −1 Ziel je Plattform.
- `formats/PLATFORM_SPECS.md`, `stream/STREAM_FORMATS.md` (F1–F4), `stream/CLIP_ERNTE.md`:
  Formate, Clip-Ernte nach dem Stream.
- `stream/OBS_SETUP.md`: Audio-Routing Xone:96 → BiG SiX (eine Clock), Szenen-Gerüst.

## Reihenfolge (eine Scheibe je Zyklus, jede mit Wächter)
- **M1 — Zwei Linsen, eine Aufnahme:** Front + Rück gleichzeitig (`AVCaptureMultiCamSession`),
  zwei Takes auf zwei Video-Spuren. Keine Abhängigkeit.
- **M2 — Winkel-Schnitt:** heute zeigt die Spur-Ebene nur die ERSTE Bildspur. Eine Programm-Spur
  wählt je Takt/Teil den Winkel (Multicam-Schnitt wie im NLE).
- **M3 — Auto-Sync per Ton:** mehrere Aufnahmen (z. B. drei iPhones mit Blackmagic Camera)
  importieren, per Audio-Kreuzkorrelation ausrichten — ersetzt `studio.sh --versatz`. Braucht den
  Ton der Datei (heute legt Import Video nur das Bild ab).
- **M4 — Echoel-Kamera-Link:** zweites iPhone mit Echoel im Kamera-Modus sendet Bild + Song-Uhr
  an das Haupt-iPhone (Multipeer/Network, HEVC über VideoToolbox). Keine Abhängigkeit.
- **M5 — Stream raus:** RTMP/SRT, Multistream hoch + quer. **Braucht HaishinKit — Founder-OK.**
- **M6 — Fremd-Eingänge:** SRT (Blackmagic Camera) und NDI. **Braucht libsrt / NDI-SDK —
  Founder-OK + NDI-Lizenzklärung.**
- **iPad-Ziel:** HDMI/USB-Kameras über UVC — erst wenn iPad als Target zurückkommt.

## Ehrlichkeit
Nichts davon ist am Gerät bestätigt. Nach außen (Store, Website, CLAIMS) wird nichts davon
behauptet, bevor es läuft.
