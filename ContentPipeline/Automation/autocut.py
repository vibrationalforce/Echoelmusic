#!/usr/bin/env python3
"""autocut — Sync, Highlights und Upload-Proxys für Echoel-Rohmaterial.

FOUNDER-AUFTRAG 2026-09-09, wörtlich: "Soll alles können. Aktuell Auto Sync der Clips und
herausschneiden der spannendsten Stellen" — dazu, auf die Frage was am Drive ewig dauert:
"Videos hochladen".

PIPELINE-ONLY. Nichts hier wird ausgeliefert, nichts hier fasst `Sources/` an (ContentPipeline
/README.md). Kein neues Target, keine Signierung, keine Mac-App: eine Datei plus eine
`.command` zum Doppelklicken.

⛔ WARUM KEINE MAC-APP (Council 2026-09-09). Ein eigenes Target hieße Signierung, Wartung und
ein ZWEITES PRODUKT neben dem Instrument — genau die "unendliche Wartungsfläche", die
`docs/dev/PRODUCT_DEFINITION.md` als Grund für die DMMW-Streichung nennt. Dazu praktisch: die
Sitzung, die das hier schreibt, hat kein macOS und kein Xcode und könnte eine App weder bauen
noch testen.

⛔ WARUM `VideoMuxAlignment` NICHT WIEDERVERWENDET IST, obwohl es "Sync" im Namen führt.
Gemessen: es richtet nach DAUER aus und setzt voraus, dass beide Aufnahmen zur selben Sekunde
ENDEN (der App-Fall: Videospur + RetroCapture-Ring, ein Stopp). Zwei unabhängig gestartete
Geräte teilen dieses Ende nicht. Das ist ein anderes Problem und braucht Wellenform-Korrelation.
Eine behauptete Wiederverwendung wäre hier falsch.

═══════════════════════════════════════════════════════════════════════════════════════
WAS BEWIESEN IST UND WAS NICHT — vor dem ersten Lauf lesen.

  · Die REINEN KERNE (Hüllkurve, Korrelation, Fenster-Auswahl, Strom-Zerteilung) sind mit
    `--selftest` gegen synthetische Signale mit BEKANNTER Verschiebung getrieben. Das lief —
    und drei Mutanten machen den Selbsttest nachweislich ROT, er ist also nicht wirkungslos.
  · Die FFMPEG-HÜLLE (Extraktion, Encoding) ist NICHT getrieben — in diesem Container gibt
    es kein ffmpeg. Der erste echte Lauf ist deiner.
  · Deshalb: `python3 autocut.py --selftest` ZUERST. Er braucht kein ffmpeg und muss grün
    sein, bevor du dem Werkzeug ein Video gibst.

BRAUCHT: ffmpeg + ffprobe  (`brew install ffmpeg`). Sonst nichts — kein numpy, kein pip.
═══════════════════════════════════════════════════════════════════════════════════════
"""

from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from dataclasses import dataclass

# ── Konstanten, benannt statt eingestreut ────────────────────────────────────────────

PROBE_RATE = 8000          # Hz, Mono — reicht für Hüllkurven-Korrelation, hält Arrays klein
FINE_HOP_MS = 10           # Hüllkurven-Auflösung fein  → 100 Hz
COARSE_DECIMATE = 10       # grob = fein / 10          → 10 Hz
DEFAULT_MAX_OFFSET_S = 120.0
MIN_CONFIDENCE = 1.25      # Spitze muss die zweitbeste um diesen Faktor schlagen
FINE_WINDOW_S = 2.0        # ± um den groben Treffer

PROXY_HEIGHT = 480
PROXY_CRF = 32
CONTACT_TILE = "4x4"


class Missing(RuntimeError):
    """Ein externes Werkzeug fehlt. Laut, nie still."""


# ── Reine Kerne — hier getrieben, ohne ffmpeg ────────────────────────────────────────

def _rms_window(values, hop: int) -> float:
    """Ein Fenster → EIN Wert. Bewusst eigene Funktion: der Strom-Leser unten muss BITGLEICH
    dieselbe Mathematik fahren wie die vom Selbsttest getriebene `envelope`. Zwei Kopien
    derselben Formel wären zwei Formeln, sobald eine repariert wird."""
    acc = 0.0
    for v in values:
        if v == v and -1e6 < v < 1e6:          # NaN/inf fallen still raus, nicht in die Summe
            acc += v * v
    return math.sqrt(acc / hop)


def envelope(samples: list[float], sample_rate: int, hop_ms: int = FINE_HOP_MS) -> list[float]:
    """RMS je Zeitfenster. Die Hüllkurve, NICHT die Rohwelle, ist das Sync-Signal:
    zwei Mikrofone unterscheiden sich in Pegel, Klangfarbe und Phase, teilen aber den
    Lautstärkeverlauf. Rohwellen-Korrelation scheitert genau daran."""
    hop = max(1, int(sample_rate * hop_ms / 1000))
    return [_rms_window(samples[s:s + hop], hop)
            for s in range(0, len(samples) - hop + 1, hop)]


def normalised(env: list[float]) -> list[float]:
    """Mittelwert ab, auf Standardabweichung normiert. Macht die Korrelation pegelunabhängig."""
    n = len(env)
    if n == 0:
        return []
    mean = sum(env) / n
    var = sum((v - mean) ** 2 for v in env) / n
    sd = math.sqrt(var)
    if sd <= 0:
        return [0.0] * n
    return [(v - mean) / sd for v in env]


def decimate(env: list[float], factor: int) -> list[float]:
    """Mittelt je `factor` Werte zusammen. Für den groben Durchgang."""
    if factor <= 1:
        return list(env)
    out: list[float] = []
    for i in range(0, len(env) - factor + 1, factor):
        out.append(sum(env[i:i + factor]) / factor)
    return out


def best_lag(a: list[float], b: list[float], max_lag: int) -> tuple[int, float, float]:
    """Kreuzkorrelation von `a` gegen `b` über ±`max_lag`.

    Rückgabe: (bester Versatz, Spitzenwert, zweitbester Wert eines ANDEREN Gipfels).
    Ein positiver Versatz heißt: `b` beginnt SPÄTER als `a`.

    ⚠️ Der zweitbeste Wert ist kein Beiwerk — er ist die Vertrauensmessung. Eine
    Korrelation hat immer eine Spitze; ob sie etwas BEDEUTET, sagt erst der Abstand zur
    nächstbesten. Ohne das liefert das Werkzeug bei zwei unabhängigen Aufnahmen eine
    plausible Zahl, und ein falscher Sync sieht richtiger aus als gar keiner.
    """
    n = min(len(a), len(b))
    if n == 0:
        return 0, 0.0, 0.0
    scores: dict[int, float] = {}
    for lag in range(-max_lag, max_lag + 1):
        acc = 0.0
        count = 0
        for i in range(n):
            j = i + lag
            if 0 <= j < n:
                acc += a[i] * b[j]
                count += 1
        scores[lag] = acc / count if count > 0 else 0.0
    top = max(scores, key=lambda k: scores[k])
    peak = scores[top]
    # Zweitbester GIPFEL: alles direkt neben der Spitze gehört zu ihr und zählt nicht.
    guard = max(2, max_lag // 20)
    others = [v for k, v in scores.items() if abs(k - top) > guard]
    second = max(others) if others else 0.0
    return top, peak, second


def refine_parabolic(scores_lo: float, scores_mid: float, scores_hi: float) -> float:
    """Sub-Schritt-Genauigkeit aus drei Punkten um die Spitze. Gibt eine Verschiebung
    in Schritten zurück, immer in [-0.5, +0.5]."""
    denom = scores_lo - 2 * scores_mid + scores_hi
    if denom == 0:
        return 0.0
    delta = 0.5 * (scores_lo - scores_hi) / denom
    return max(-0.5, min(0.5, delta))


@dataclass
class SyncResult:
    offset_seconds: float
    confidence: float          # Spitze / zweitbester Gipfel
    trustworthy: bool


def sync_offset(env_a: list[float], env_b: list[float],
                hop_ms: int = FINE_HOP_MS,
                max_offset_s: float = DEFAULT_MAX_OFFSET_S) -> SyncResult:
    """Zwei Hüllkurven → Versatz in Sekunden. Zwei Stufen: grob (10 Hz), dann fein.

    ⚠️ ZWEI STUFEN SIND KEINE OPTIMIERUNG, SONDERN DIE BEDINGUNG. Eine 20-Minuten-Aufnahme
    hat bei 100 Hz 120 000 Hüllkurvenwerte; ein voller Suchlauf über ±120 s wäre in reinem
    Python zweistellig Minuten. Grob auf 10 Hz kostet ein Hundertstel davon, fein danach
    nur noch ±2 s.
    """
    a_n, b_n = normalised(env_a), normalised(env_b)
    if not a_n or not b_n:
        return SyncResult(0.0, 0.0, False)

    coarse_hop_s = hop_ms * COARSE_DECIMATE / 1000.0
    a_c, b_c = decimate(a_n, COARSE_DECIMATE), decimate(b_n, COARSE_DECIMATE)
    max_lag_c = max(1, int(max_offset_s / coarse_hop_s))
    lag_c, peak_c, second_c = best_lag(a_c, b_c, max_lag_c)
    coarse_s = lag_c * coarse_hop_s

    fine_hop_s = hop_ms / 1000.0
    window = max(1, int(FINE_WINDOW_S / fine_hop_s))
    centre = int(round(coarse_s / fine_hop_s))
    lo, hi = centre - window, centre + window
    scores: dict[int, float] = {}
    n = min(len(a_n), len(b_n))
    for lag in range(lo, hi + 1):
        acc, count = 0.0, 0
        for i in range(n):
            j = i + lag
            if 0 <= j < n:
                acc += a_n[i] * b_n[j]
                count += 1
        scores[lag] = acc / count if count > 0 else 0.0
    top = max(scores, key=lambda k: scores[k])
    sub = refine_parabolic(scores.get(top - 1, scores[top]), scores[top],
                           scores.get(top + 1, scores[top]))
    offset = (top + sub) * fine_hop_s

    confidence = (peak_c / second_c) if second_c > 0 else (float("inf") if peak_c > 0 else 0.0)
    return SyncResult(offset, confidence, confidence >= MIN_CONFIDENCE and peak_c > 0)


@dataclass
class Highlight:
    start_seconds: float
    duration_seconds: float
    score: float


def pick_highlights(env: list[float], hop_ms: int, clip_seconds: float,
                    count: int, min_gap_seconds: float = 0.0) -> list[Highlight]:
    """Die `count` lautesten, sich NICHT überlappenden Fenster der Länge `clip_seconds`.

    ⚠️ "Spannend" ist hier ENERGIE, und das ist eine Annahme, keine Wahrheit. Für eine
    Performance mit Musik trifft sie meistens; für ein leises, schönes Bild trifft sie
    nicht. Deshalb heißt die Zahl `score` und wird ausgedruckt — du siehst, worauf das
    Werkzeug hereingefallen ist, statt es raten zu müssen.
    """
    hop_s = hop_ms / 1000.0
    width = max(1, int(clip_seconds / hop_s))
    if width > len(env) or count <= 0:
        return []
    # Laufende Summe → jedes Fenster in O(1)
    prefix = [0.0]
    for v in env:
        prefix.append(prefix[-1] + v)
    windows = [(prefix[i + width] - prefix[i], i) for i in range(len(env) - width + 1)]
    windows.sort(key=lambda t: t[0], reverse=True)

    gap = max(width, int(min_gap_seconds / hop_s) + width)
    chosen: list[Highlight] = []
    taken: list[int] = []
    for score, i in windows:
        if any(abs(i - t) < gap for t in taken):
            continue
        taken.append(i)
        chosen.append(Highlight(i * hop_s, clip_seconds, score / width))
        if len(chosen) >= count:
            break
    chosen.sort(key=lambda h: h.start_seconds)
    return chosen


# ── ffmpeg-Hülle — NICHT in diesem Container getrieben ───────────────────────────────

def require(tool: str) -> str:
    path = shutil.which(tool)
    if path is None:
        raise Missing(
            f"'{tool}' nicht gefunden. Auf dem Mac:  brew install ffmpeg\n"
            f"    (autocut braucht ffmpeg UND ffprobe; sonst nichts.)")
    return path


def probe(path: str) -> dict:
    require("ffprobe")
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries",
         "format=duration,size:stream=width,height,codec_type,codec_name",
         "-of", "json", path],
        capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def envelope_from_stream(reader, hop: int, block_hops: int = 64) -> list[float]:
    """float32-Rohstrom → Hüllkurve, ohne je alles zu halten. `reader` braucht nur `.read(n)`.

    ⭐ DASS DIESE FUNKTION KEIN FFMPEG KENNT, IST DER PUNKT. Dieser Container hat kein ffmpeg,
       also wäre die Zerteil-Logik sonst der einzige ungetestete Rechenteil des Werkzeugs —
       und sie hat die eine Stelle, an der ein stiller Fehler wohnt: den ÜBERHANG, wenn ein
       gelesener Block nicht auf einer Fenstergrenze endet. Der Selbsttest treibt sie gegen
       `envelope` und verlangt BITGLEICHE Werte, bei absichtlich schlecht passender Blockgröße.
    """
    frame = hop * 4                                   # float32
    out: list[float] = []
    carry = b""
    while True:
        block = reader.read(frame * block_hops)
        if not block:
            break
        buf = carry + block
        whole = len(buf) // frame
        for k in range(whole):
            seg = buf[k * frame:(k + 1) * frame]
            out.append(_rms_window(struct.unpack(f"<{hop}f", seg), hop))
        carry = buf[whole * frame:]
    return out                                        # ein Rest < einem Fenster fällt weg,
                                                      # genau wie in `envelope` (range-Grenze)


def read_envelope(path: str, sample_rate: int = PROBE_RATE,
                  hop_ms: int = FINE_HOP_MS) -> list[float]:
    """Hüllkurve DIREKT aus der Datei — die Einzel-Samples liegen nie alle zugleich im Speicher.

    ⛔ DIE ERSTE FASSUNG WAR EIN `read_mono`, das erst ALLES in eine Python-Liste las und dann
       rechnete. Gerechnet: 2 Stunden × 8000 Hz = 57,6 Mio Werte; ein Python-Float kostet 24 B
       plus 8 B Zeiger, also über 1,8 GB — für Zahlen, die einzeln nie gebraucht werden. Und
       zwar auf GENAU dem Material, für das der Founder das Werkzeug bestellt hat ("Videos
       hochladen"). Der Fehler wäre erst auf seiner Maschine aufgetaucht, an der größten Datei.
       Hier läuft ffmpeg als Strom, und jedes Fenster wird sofort zu EINEM Wert reduziert.

    ⚠️ stderr geht in eine TEMPORÄRE DATEI, nicht in eine Pipe: eine volle stderr-Pipe blockiert
       ffmpeg, während wir auf stdout warten — ein Hänger, den man einer kaputten Datei nie
       ansieht. Eine Datei hat keine Puffergrenze.
    """
    require("ffmpeg")
    hop = max(1, int(sample_rate * hop_ms / 1000))
    frame = hop * 4                                   # float32
    with tempfile.TemporaryFile() as err_file:
        proc = subprocess.Popen(
            ["ffmpeg", "-v", "error", "-i", path, "-vn", "-ac", "1",
             "-ar", str(sample_rate), "-f", "f32le", "-"],
            stdout=subprocess.PIPE, stderr=err_file)
        try:
            out = envelope_from_stream(proc.stdout, hop)
            proc.stdout.close()
            code = proc.wait()
        finally:
            if proc.poll() is None:                   # Ausnahme mittendrin: ffmpeg nicht zurücklassen
                proc.kill()
                proc.wait()
        err_file.seek(0)
        message = err_file.read().decode("utf-8", "replace").strip()

    if code != 0:
        raise Missing(f"ffmpeg konnte den Ton von '{os.path.basename(path)}' nicht lesen "
                      f"(Code {code}).\n    {message[:400]}")
    if not out:
        raise Missing(f"'{os.path.basename(path)}' hat keine lesbare Tonspur. Ohne Ton kann "
                      f"autocut weder syncen noch Highlights finden — beide Verfahren HÖREN.")
    return out


def cmd_proxy(args) -> int:
    """Kleine Datei + Kontaktbogen — gegen den genannten Engpass 'Videos hochladen'."""
    src = args.input
    stem = os.path.splitext(os.path.basename(src))[0]
    outdir = args.outdir or os.path.dirname(os.path.abspath(src))
    os.makedirs(outdir, exist_ok=True)
    proxy = os.path.join(outdir, f"{stem}_proxy.mp4")
    sheet = os.path.join(outdir, f"{stem}_contact.jpg")
    require("ffmpeg")

    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src,
                    "-vf", f"scale=-2:{PROXY_HEIGHT}", "-c:v", "libx264",
                    "-preset", "veryfast", "-crf", str(PROXY_CRF),
                    "-c:a", "aac", "-b:a", "96k", proxy], check=True)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src,
                    "-vf", f"fps=1,scale=380:-1,tile={CONTACT_TILE}",
                    "-frames:v", "1", sheet], check=True)

    for p in (proxy, sheet):
        if os.path.exists(p):
            mb = os.path.getsize(p) / 1e6
            print(f"  {os.path.basename(p)}  {mb:.1f} MB")
    print("Diese zwei Dateien hochladen — nicht das Original.")
    return 0


def cmd_sync(args) -> int:
    a, b = args.a, args.b
    print(f"autocut sync: {os.path.basename(a)}  ←→  {os.path.basename(b)}")
    env_a = read_envelope(a)
    env_b = read_envelope(b)
    res = sync_offset(env_a, env_b, FINE_HOP_MS, args.max_offset)

    sign = "später" if res.offset_seconds >= 0 else "früher"
    print(f"  Versatz:   {res.offset_seconds:+.3f} s "
          f"({os.path.basename(b)} beginnt {abs(res.offset_seconds):.3f} s {sign})")
    print(f"  Vertrauen: {res.confidence:.2f}×  (Schwelle {MIN_CONFIDENCE})")
    if not res.trustworthy:
        print("  ⛔ ZU UNSICHER — kein Versatz angewandt.\n"
              "     Wahrscheinlich teilen die zwei Dateien keinen gemeinsamen Ton, oder die\n"
              "     Überlappung ist zu kurz. Ein FALSCHER Sync ist schlimmer als keiner.")
        return 2
    print("  ✅ verwendbar. Das Anwenden (Muxen) ist Scheibe 2 — heute wird nur gemessen.")
    return 0


def cmd_highlights(args) -> int:
    src = args.input
    print(f"autocut highlights: {os.path.basename(src)}")
    env = read_envelope(src)
    hits = pick_highlights(env, FINE_HOP_MS, args.length, args.count, args.gap)
    if not hits:
        print("  nichts gefunden (Datei kürzer als die Clip-Länge?)")
        return 1
    for i, h in enumerate(hits, 1):
        m, s = divmod(h.start_seconds, 60)
        print(f"  {i:2d}.  {int(m):02d}:{s:05.2f}  ({h.duration_seconds:.0f} s)  score {h.score:.4f}")
    if args.write:
        require("ffmpeg")
        stem = os.path.splitext(os.path.basename(src))[0]
        outdir = args.outdir or os.path.dirname(os.path.abspath(src))
        os.makedirs(outdir, exist_ok=True)
        for i, h in enumerate(hits, 1):
            out = os.path.join(outdir, f"{stem}_hl{i:02d}.mp4")
            subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", f"{h.start_seconds:.3f}",
                            "-i", src, "-t", f"{h.duration_seconds:.3f}",
                            "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
                            "-c:a", "aac", out], check=True)
            print(f"     → {os.path.basename(out)}")
    else:
        print("  (nur gemessen — mit --write werden die Clips geschrieben)")
    return 0


# ── Selbsttest: treibt die reinen Kerne, braucht kein ffmpeg ─────────────────────────

def selftest() -> int:
    """Treibt `sync_offset` und `pick_highlights` selbst (#941: die Prüfung muss die
    ECHTE Entscheidung modellieren, nicht eine Nachbildung davon)."""
    fails = 0

    def check(name: str, ok: bool, detail: str = "") -> None:
        nonlocal fails
        print(f"  {'PASS' if ok else 'FAIL'}  {name}{'  — ' + detail if detail else ''}")
        if not ok:
            fails += 1

    sr, dur = PROBE_RATE, 40.0
    n = int(sr * dur)

    def burst_signal(shift_s: float) -> list[float]:
        """Ein wiedererkennbarer Lautstärkeverlauf: unregelmäßige Bursts."""
        out = [0.0] * n
        for at, width in ((3.0, 0.6), (7.4, 0.3), (12.1, 1.1), (19.8, 0.4),
                          (26.5, 0.9), (33.2, 0.5)):
            t0 = int((at + shift_s) * sr)
            for i in range(t0, min(n, t0 + int(width * sr))):
                out[i] = math.sin(2 * math.pi * 220 * i / sr) * 0.8
        return out

    for truth in (0.0, 1.5, -2.25, 5.0):
        a = envelope(burst_signal(0.0), sr)
        b = envelope(burst_signal(truth), sr)
        r = sync_offset(a, b, FINE_HOP_MS, 30.0)
        err = abs(r.offset_seconds - truth)
        check(f"sync findet {truth:+.2f} s", r.trustworthy and err < 0.05,
              f"gemessen {r.offset_seconds:+.3f} s, Fehler {err*1000:.0f} ms, "
              f"Vertrauen {r.confidence:.2f}×")

    noise_a = envelope([math.sin(i * 0.7) * 0.01 for i in range(n)], sr)
    noise_b = envelope([math.cos(i * 1.9) * 0.01 for i in range(n)], sr)
    r = sync_offset(noise_a, noise_b, FINE_HOP_MS, 30.0)
    check("sync VERWEIGERT bei unkorreliertem Material",
          not r.trustworthy, f"Vertrauen {r.confidence:.2f}× < {MIN_CONFIDENCE}")

    env = [0.1] * 1000
    for i in range(300, 340):
        env[i] = 0.9
    for i in range(700, 740):
        env[i] = 0.8
    hits = pick_highlights(env, FINE_HOP_MS, clip_seconds=0.4, count=2)
    check("highlights findet beide lauten Stellen", len(hits) == 2,
          f"{[round(h.start_seconds, 2) for h in hits]}")
    check("highlights überlappen nicht",
          len(hits) == 2 and abs(hits[0].start_seconds - hits[1].start_seconds) >= 0.4)

    check("NaN in den Samples kippt die Hüllkurve nicht",
          all(v == v for v in envelope([float("nan")] * 100 + [0.5] * 900, sr)))

    # ── Der Strom-Leser gegen den getriebenen Kern ───────────────────────────────────
    # Der ffmpeg-Aufruf ist hier nicht prüfbar, seine ZERTEIL-Logik schon: derselbe
    # Ton, einmal am Stück gerechnet und einmal blockweise gelesen, muss BITGLEICH
    # dasselbe ergeben. Die Blockgröße ist absichtlich krumm (7 Fenster), damit fast
    # jeder Block MITTEN in einem Fenster endet und der Überhang wirklich arbeitet.
    hop = max(1, int(sr * FINE_HOP_MS / 1000))

    class ShortReader:
        """Eine PIPE, kein Puffer.

        ⛔ ERST STAND HIER `io.BytesIO`, UND DER TEST WAR WIRKUNGSLOS — nachgewiesen, nicht
           vermutet: ein Mutant, der den Überhang wegwirft (`carry = b""`), kam grün durch.
           `BytesIO.read(n)` liefert IMMER genau n Bytes, also endet dort nie ein Block mitten
           in einem Fenster, und genau dafür existiert der Überhang. Eine echte ffmpeg-Pipe
           liefert KURZE Lesevorgänge in beliebiger Größe. Der Test modellierte also alles
           außer der Entscheidung, die er prüfen sollte (#941). Diese Klasse gibt absichtlich
           eine krumme, mit dem Fenster teilerfremde Menge zurück."""

        def __init__(self, data: bytes, step: int) -> None:
            self.data, self.step, self.at = data, step, 0

        def read(self, _requested: int) -> bytes:      # das Wunsch-Maß wird IGNORIERT
            out = self.data[self.at:self.at + self.step]
            self.at += len(out)
            return out

    # ⛔ ERST STAND HIER `burst_signal(0.0)[: hop * 50 + 17]` — die ersten 0,5 Sekunden, und
    #    die sind STILLE (der erste Burst liegt bei 3,0 s). Der Vergleich prüfte also 50 Nullen
    #    gegen 50 Nullen: ein zweiter Mutant, der jedes Fenster durch das erste ersetzt, kam
    #    grün durch, weil alle Fenster ohnehin gleich waren. Der Ausschnitt MUSS über einen
    #    Burst laufen, sonst prüft der Vergleich nur seine eigene Länge.
    lead = int(2.9 * sr)                               # kurz vor dem Burst bei 3,0 s
    tone = burst_signal(0.0)[lead:lead + hop * 50 + 17]   # +17: Rest kleiner als ein Fenster
    assert len(set(envelope(tone, sr))) > 3, "Testausschnitt ist zu gleichförmig"
    packed = struct.pack(f"<{len(tone)}f", *tone)
    # ⛔ UND DER VERGLEICH GING GEGEN DIE FALSCHE GRÖSSE: `envelope(tone, sr)` rechnet in
    #    float64, der Strom liest float32 von ffmpeg. Der Unterschied ist ~3e-9 und hat NICHTS
    #    mit der Zerteilung zu tun — der Test wäre für immer rot gewesen, aus einem Grund, den
    #    er nicht prüft. Bezug ist derselbe Ton NACH dem float32-Rundlauf; damit misst der
    #    Vergleich genau die Zerteilung und sonst nichts.
    direct = envelope(list(struct.unpack(f"<{len(tone)}f", packed)), sr)
    for step in (13, hop * 4 - 1, hop * 4 + 1, 1021):
        streamed = envelope_from_stream(ShortReader(packed, step), hop, block_hops=7)
        check(f"Strom-Leser bitgleich bei {step}-Byte-Häppchen",
              streamed == direct, f"{len(streamed)} Fenster gegen {len(direct)}")

    check("Strom-Leser wirft den angebrochenen Rest weg, statt ihn falsch zu füllen",
          len(envelope_from_stream(
              ShortReader(struct.pack(f"<{hop + 3}f", *([0.5] * (hop + 3))), 29), hop)) == 1)

    check("Strom-Leser über leerem Ton liefert nichts, statt zu krachen",
          envelope_from_stream(ShortReader(b"", 8), hop) == [])

    print(f"\nselftest: {'alle Ansprüche grün' if fails == 0 else f'{fails} FEHLER'}")
    return 0 if fails == 0 else 1


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(
        prog="autocut", description="Sync · Highlights · Upload-Proxy für Echoel-Rohmaterial")
    p.add_argument("--selftest", action="store_true",
                   help="treibt die reinen Kerne, braucht kein ffmpeg — VOR dem ersten echten Lauf")
    sub = p.add_subparsers(dest="cmd")

    sp = sub.add_parser("proxy", help="kleine Datei + Kontaktbogen zum Hochladen")
    sp.add_argument("input")
    sp.add_argument("--outdir")
    sp.set_defaults(fn=cmd_proxy)

    ss = sub.add_parser("sync", help="Versatz zweier Aufnahmen über den Ton messen")
    ss.add_argument("a")
    ss.add_argument("b")
    ss.add_argument("--max-offset", type=float, default=DEFAULT_MAX_OFFSET_S, dest="max_offset")
    ss.set_defaults(fn=cmd_sync)

    sh = sub.add_parser("highlights", help="die spannendsten Stellen finden")
    sh.add_argument("input")
    sh.add_argument("--count", type=int, default=5)
    sh.add_argument("--length", type=float, default=20.0, help="Clip-Länge in Sekunden")
    sh.add_argument("--gap", type=float, default=5.0, help="Mindestabstand zwischen Clips")
    sh.add_argument("--write", action="store_true", help="Clips wirklich schreiben")
    sh.add_argument("--outdir")
    sh.set_defaults(fn=cmd_highlights)

    args = p.parse_args(argv)
    if args.selftest:
        return selftest()
    if not getattr(args, "fn", None):
        p.print_help()
        return 1
    try:
        return args.fn(args)
    except Missing as exc:
        print(f"autocut: {exc}", file=sys.stderr)
        return 3
    except subprocess.CalledProcessError as exc:
        print(f"autocut: ffmpeg/ffprobe brach ab ({exc.returncode}).", file=sys.stderr)
        return 4


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
