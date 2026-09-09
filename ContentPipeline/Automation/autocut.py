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

  · `--selftest` treibt die REINEN KERNE (Hüllkurve, Korrelation, Fenster-Auswahl,
    Strom-Zerteilung) gegen synthetische Signale mit BEKANNTER Verschiebung. Braucht kein
    ffmpeg. Drei Mutanten machen ihn nachweislich ROT, er ist also nicht wirkungslos.
  · `--drive ORDNER` treibt die FFMPEG-HÜLLE: es baut zwei echte Videos mit bekanntem
    Versatz und fährt sync, highlights und den Schnitt durch. Beides lief hier grün.
  · ⛔ VIER DATEIEN SAGTEN "die ffmpeg-Hülle ist ungetestet". Das stimmte nur, solange
    niemand nachsah: `ffmpeg` fehlt zwar im PATH dieses Containers, aber das Wheel
    `imageio-ffmpeg` liefert eine echte Binärdatei (siehe .claude/skills/watch-clip). "Nicht
    auf dem PATH" ist nicht dasselbe wie "nicht verfügbar" — und der Unterschied hat eine
    ganze Prüfung als unmöglich erscheinen lassen, die zehn Minuten kostete.
  · WAS WEITERHIN NUR DEIN MAC BEWEISEN KANN: die `.command` selbst (kein macOS hier) und
    ob ECHTES Kameramaterial syncet — die Testvideos teilen denselben erzeugten Ton, zwei
    Geräte im Raum teilen nur den Lautstärkeverlauf.

  Reihenfolge auf deinem Mac:  `--selftest`  →  `--drive /tmp/ac`  →  echtes Material.

BRAUCHT: ffmpeg. Sonst nichts — kein ffprobe, kein numpy, kein pip.
         (`brew install ffmpeg` bringt trotzdem beide mit, das schadet nicht.)
═══════════════════════════════════════════════════════════════════════════════════════
"""

from __future__ import annotations

import argparse
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

PROXY_LONG_SIDE = 854
# ⛔ HIER STAND `PROXY_HEIGHT = 480` MIT `scale=-2:480`, UND DAS MASS WAR DIE FALSCHE SEITE.
#    Gemessen an einer echten iPhone-Aufnahme des Founders (1320×2868, hochkant): daraus wird
#    220×480 = 106k Bildpunkte, während ein QUERFORMAT-Video bei derselben Einstellung
#    854×480 = 410k bekommt. Hochformat bekam also VIERMAL weniger Auflösung aus derselben
#    Zahl — und bei einer hochkanten Bildschirmaufnahme begrenzt die BREITE die Lesbarkeit,
#    nicht die Höhe. Die lange Seite ist das richtige Mass; sie ist in beiden Lagen dieselbe
#    Grösse. (Gefunden, weil ich den Proxy an echtem Material gefahren habe statt an meinem
#    eigenen Testclip — dieselbe Lehre wie #1187, drittes Mal an einem Tag.)
PROXY_CRF = 32
CONTACT_TILE = "4x4"

# ── Echoel CI (Corporate Identity) ───────────────────────────────────────────────────
# Founder 2026-09-09: "Echoelmusic CI soll auch mit eingebaut werden. Siehe Website und
# Echoelmusic Repo." NEBEN JEDEM WERT STEHT SEINE QUELLE — diese Datei darf keine ZWEITE
# Palette werden, die von der App wegdriftet. Nachmessen statt glauben:
#   Sources/Echoelmusic/Studio/EchoelTheme.swift   (die App)
#   docs/index.html  --bg/--text                   (die Website)
#   docs/logo-horizontal.svg                       (nennt sich selbst "CI v7.1")
BRAND_INK = "0xe0e0e0"     # EchoelTheme.text (0.878³) == Website --text #e0e0e0
BRAND_GROUND = "black"     # EchoelTheme.bg == Website --bg #000
BRAND_PLATE_ALPHA = 0.75   # massive Fläche, KEIN Glas — Uncodixfy verbietet Glasoptik
BRAND_BORDER_ALPHA = 0.20  # 1 px, gedämpft — Website --border rgba(224,224,224,0.08..0.2)
BRAND_PLATE_FRACTION = 0.13   # Plattenhöhe als Anteil der Videohöhe
BRAND_MARK_FRACTION = 0.62    # Marke innerhalb der Platte
BRAND_MARGIN_FRACTION = 0.045 # Abstand zum Rand
BRAND_LOGO = "docs/favicon-512.png"

# ── Auto-Zoom: wo passiert etwas? ────────────────────────────────────────────────────
# Founder 2026-09-09: "An die richtigen Ausschnitte heranzoomen wo was passiert bei
# bildschirmaufnahmen etc."
ZOOM_COLS = 48             # Analyse-Raster; grob genug für reines Python, fein genug für eine Ecke
ZOOM_ROWS = 27
ZOOM_FPS = 4               # Abtastrate der Analyse — nicht die Bildrate der Ausgabe
ZOOM_COVERAGE = 0.75       # so viel der Gesamt-Veränderung muss im Ausschnitt liegen
ZOOM_PAD = 0.10            # Luft um das gefundene Rechteck
ZOOM_MIN_FRACTION = 0.25   # niemals enger als ein Viertel der Bildbreite/-höhe
ZOOM_MIN_CONCENTRATION = 0.50
# ⭐ DIESE SCHWELLE IST AN ECHTEM FOUNDER-MATERIAL GEMESSEN, nicht geschätzt (#1187).
#    "Konzentration" = welcher Anteil der Gesamtveränderung in den aktivsten 10 % der Zellen
#    liegt. Gemessen an drei echten iPhone-Bildschirmaufnahmen der App: 20,3 % · 33,2 % ·
#    33,9 %. An synthetischem Material mit EINER blinkenden Stelle: 100 %.
#    Bei einer laufenden Echoel-Sitzung bewegt sich der GANZE Schirm (Bio-Visual, Pegel,
#    Zahlen) — es gibt dort keine "eine Stelle", und 50 % trennt beide Lagen sauber.

# ⛔ KEIN GRÜN. `EchoelTheme.accent` (bio-green) trägt dort den Vermerk "signal only" — es
#    bedeutet ein gemessenes Signal. Als Zierfarbe in einem Video bräche es die eigene CI,
#    und zwar an der Stelle, an der die CI am sichtbarsten ist. Die Marke ist Tinte auf Grund.
#
# ⛔ KEIN TEXT. Die Wortmarke bräuchte den ffmpeg-Filter `drawtext`, und ob der da ist, lässt
#    sich NICHT am Bau-Flag ablesen: die Binärdatei dieser Prüfung meldet
#    `--enable-libfreetype` und hat trotzdem NULL drawtext in `-filters`. Ein Bau-Flag ist
#    eine Absicht, die Filterliste ist die Tatsache. Die Bildmarke braucht keine Schrift und
#    läuft deshalb überall.


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

def activity_grid(frames: list[bytes], cols: int, rows: int) -> list[float]:
    """Wie viel hat sich je Rasterzelle über den ganzen Clip verändert?

    ⭐ VERÄNDERUNG, NICHT HELLIGKEIT. Eine Bildschirmaufnahme ist grösstenteils stillstehend;
       "wo passiert etwas" heisst dort buchstäblich "wo ändern sich Pixel". Das ist eine
       ANDERE Frage als die von `highlights` (dort: wo ist es laut) — und für eine stumme
       Bildschirmaufnahme die einzige, die überhaupt eine Antwort hat.

    ⚠️ Absolute Differenz aufeinanderfolgender Abtastungen, NICHT gegen das erste Bild:
       gegen ein festes Referenzbild würde ein einmaliges Scrollen den Rest des Clips
       dauerhaft als "aktiv" markieren, auch wenn dort danach nichts mehr geschieht.
    """
    size = cols * rows
    acc = [0.0] * size
    previous = None
    for frame in frames:
        if len(frame) < size:
            continue                                   # Halbes Bild am Ende: verwerfen
        if previous is not None:
            for i in range(size):
                acc[i] += abs(frame[i] - previous[i])
        previous = frame
    return acc


def activity_box(activity: list[float], cols: int, rows: int,
                 coverage: float = ZOOM_COVERAGE) -> tuple[int, int, int, int]:
    """Kleinstes Zellen-Rechteck, das `coverage` der Gesamtveränderung enthält.

    Verfahren: Zellen nach Veränderung absteigend nehmen, bis der Anteil erreicht ist, dann
    deren umschliessendes Rechteck. Einfach und robust — und wichtiger: es kann NICHT auf
    einen einzelnen Ausreisser zusammenschnurren, weil der Anteil erst mit genug Zellen
    zusammenkommt.

    ⚠️ Bei völlig regungslosem Material ist die Summe 0. Dann gibt es keine "Stelle, wo etwas
       passiert", und die ehrliche Antwort ist das GANZE Bild — nicht eine willkürliche Ecke.
    """
    total = sum(activity)
    if total <= 0 or not activity:
        return (0, 0, cols - 1, rows - 1)
    order = sorted(range(len(activity)), key=lambda i: activity[i], reverse=True)
    taken, running = [], 0.0
    for i in order:
        taken.append(i)
        running += activity[i]
        if running >= total * coverage:
            break
    xs = [i % cols for i in taken]
    ys = [i // cols for i in taken]
    return (min(xs), min(ys), max(xs), max(ys))


def concentration(activity: list[float]) -> float:
    """Welcher Anteil der Veränderung liegt in den aktivsten 10 % der Zellen?

    ⛔ DIESE FUNKTION EXISTIERT, WEIL DER ZOOM AUF ECHTEM MATERIAL NICHTS TAT — und das erst
       auffiel, als ich ihn auf die Bildschirmaufnahmen des Founders losliess. An
       synthetischem Material mit EINER blinkenden Stelle arbeitete er perfekt; an drei echten
       Aufnahmen der laufenden App gab er 100 % der Fläche zurück, also gar keinen Zoom.
       **Der Grund ist kein Fehler, sondern das Material**: bei laufender App bewegt sich der
       ganze Schirm. Falsch war nicht das Ergebnis, sondern dass das Werkzeug es nicht SAGTE —
       ein stiller Vollbild-"Zoom" sieht aus wie ein Zoom, der nichts gefunden hat, und nicht
       wie einer, der etwas gefunden hat, das überall ist.

    ⭐ GESETZ: ein Werkzeug an SYNTHETISCHEM Material zu prüfen beweist die RECHNUNG, nie den
       NUTZEN. Beides braucht seine eigene Probe, und die zweite braucht echtes Material.
    """
    # ⛔ HIER STAND ZUSÄTZLICH `if not activity: return 0.0` — überflüssig, und ein Mutant hat
    #    es bewiesen: bei leerer Liste ist `sum([])` gleich 0, also greift die Zeile darunter
    #    ohnehin. Eine Wache, die man abschalten kann, ohne dass etwas rot wird, wacht nicht.
    total = sum(activity)
    if total <= 0:
        return 0.0
    top = sorted(activity, reverse=True)[:max(1, len(activity) // 10)]
    return sum(top) / total


def crop_rect(box: tuple[int, int, int, int], cols: int, rows: int,
              width: int, height: int, aspect: float | None = None,
              pad: float = ZOOM_PAD,
              min_fraction: float = ZOOM_MIN_FRACTION) -> tuple[int, int, int, int]:
    """Zellen-Rechteck → Pixel-Zuschnitt (x, y, w, h), gepolstert, seitenverhältnis-treu,
    im Bild gehalten und mit GERADEN Kanten.

    ⚠️ GERADE KANTEN SIND KEINE KOSMETIK: h264 mit yuv420p verlangt gerade Breite und Höhe.
       Ein ungerader Zuschnitt lässt ffmpeg abbrechen — mit einer Meldung über Pixelformate,
       die nichts über die eigentliche Ursache sagt.

    ⚠️ `min_fraction` verhindert den unbrauchbaren Extremfall: ein blinkender Cursor ist eine
       winzige, sehr aktive Fläche, und ein Zuschnitt darauf wäre ein Standbild vom Cursor.
    """
    x0, y0, x1, y1 = box
    cw, ch = width / cols, height / rows
    px0, py0 = x0 * cw, y0 * ch
    px1, py1 = (x1 + 1) * cw, (y1 + 1) * ch

    bw, bh = px1 - px0, py1 - py0
    px0 -= bw * pad
    px1 += bw * pad
    py0 -= bh * pad
    py1 += bh * pad

    bw = max(px1 - px0, width * min_fraction)
    bh = max(py1 - py0, height * min_fraction)
    cx, cy = (px0 + px1) / 2, (py0 + py1) / 2

    if aspect and aspect > 0:
        if bw / bh < aspect:
            bw = bh * aspect
        else:
            bh = bw / aspect

    if bw > width:
        bw = float(width)
        bh = bw / aspect if aspect else bh
    if bh > height:
        bh = float(height)
        bw = bh * aspect if aspect else bw

    x = min(max(cx - bw / 2, 0.0), width - bw)
    y = min(max(cy - bh / 2, 0.0), height - bh)

    # ⛔ ERST STAND HIER EINE EINZIGE RUNDUNGSFUNKTION `max(2, …)` FÜR ALLE VIER WERTE, und
    #    der Selbsttest hat sie sofort rot gemacht: für BREITE und HÖHE ist die Untergrenze 2
    #    richtig (ein Zuschnitt von 0 Pixeln ist keiner), für die POSITION ist sie falsch —
    #    x=0 ist gültig, und aus 0 wurde 2, also lag der Zuschnitt bei Vollbild um zwei Pixel
    #    ausserhalb (x+w = 1922 bei 1920). Zwei verschiedene Grössen, zwei verschiedene
    #    Untergrenzen; eine gemeinsame "Hilfsfunktion" hat genau das verwischt.
    def even_size(v: float) -> int:
        return max(2, int(v) // 2 * 2)

    def even_pos(v: float) -> int:
        return max(0, int(v) // 2 * 2)

    w_i, h_i = even_size(bw), even_size(bh)
    # Nach dem Abrunden kann die Position noch überstehen — erst jetzt endgültig klemmen.
    x_i = min(even_pos(x), max(0, width - w_i))
    y_i = min(even_pos(y), max(0, height - h_i))
    return (x_i, y_i, w_i, h_i)


def require(tool: str) -> str:
    path = shutil.which(tool)
    if path is None:
        raise Missing(
            f"'{tool}' nicht gefunden. Auf dem Mac:  brew install ffmpeg\n"
            f"    (autocut braucht NUR ffmpeg; sonst nichts.)")
    return path


# ⛔ HIER STAND EIN `probe()` MIT NULL AUFRUFERN — gemessen, nicht vermutet
#    (`grep -n "probe(" autocut.py` → nur die eigene Signatur). Gelöscht nach dem Dead-Code-
#    Verbot in `.claude/rules/engineering.md` §2. Der Gewinn ist nicht kosmetisch: es war das
#    EINZIGE, was `ffprobe` verlangte. autocut braucht jetzt nur noch `ffmpeg` — eine
#    Abhängigkeit weniger auf dem Rechner des Founders, und die `.command` prüft eine Sache
#    weniger. Wer wieder Metadaten braucht: `ffmpeg -hide_banner -i DATEI 2>&1` druckt Dauer,
#    Auflösung, fps und Codec, ohne ein zweites Programm zu verlangen.


def envelope_from_stream(reader, hop: int, block_hops: int = 64) -> list[float]:
    """float32-Rohstrom → Hüllkurve, ohne je alles zu halten. `reader` braucht nur `.read(n)`.

    ⭐ DASS DIESE FUNKTION KEIN FFMPEG KENNT, IST DER PUNKT. Sie ist damit im `--selftest`
       prüfbar, der bewusst OHNE ffmpeg auskommt — sonst wäre die Zerteil-Logik nur über
       `--drive` erreichbar, also nur dort, wo ffmpeg schon läuft. Zwei Prüfebenen statt einer;
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


def repo_root() -> str:
    """Die Wurzel des Repos, von DIESER Datei aus — nicht vom Arbeitsverzeichnis.
    Ein Doppelklick startet die `.command` im Automation-Ordner, ein Terminal irgendwo."""
    return os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def brand_logo_path() -> str:
    path = os.path.join(repo_root(), BRAND_LOGO)
    if not os.path.exists(path):
        raise Missing(f"Die Marke fehlt: {BRAND_LOGO}\n"
                      f"    erwartet unter {path}\n"
                      f"    (autocut liest sie aus dem Repo — starte es aus dem Repo heraus.)")
    return path


def brand_filter(height: int, position: str) -> str:
    """Marke auf massiver Platte, unten rechts (oder wohin `position` zeigt).

    ⚠️ DIE PLATTE IST NICHT DEKORATION. Die Marke ist HELLE Tinte (#e0e0e0); auf hellem
       Material verschwindet sie sonst. Gemessen an einem hellgrauen Testbild: ohne Platte
       kaum sichtbar, mit Platte auf hell UND dunkel lesbar. Massive Füllung plus 1-px-Rand
       ist genau das, was die Uncodixfy-Regeln VERLANGEN — Glasoptik, Verlauf und Schein
       sind dort verboten.

    ⚠️ WARUM DIE HELLIGKEIT ZUR DECKKRAFT WIRD. `docs/favicon-512.png` ist RGB OHNE
       Alpha-Kanal (gemessen: PNG-Farbtyp 2, kein tRNS) — direkt überlagert klebte ein
       schwarzes Quadrat im Bild. Die Marke ist aber helle Tinte auf schwarzem Grund, also
       IST ihre Helligkeit ihre Deckkraft; `geq` baut daraus den fehlenden Alpha-Kanal.

    ⚠️ `drawbox` kennt `W`/`H` NICHT (dort sind `w`/`h` die Box selbst) — es braucht `iw`/`ih`.
       Mit `W` schlägt es fehl, und unter `-v error` sagt ffmpeg nur "Invalid argument",
       ohne die Ursache zu nennen.
    """
    plate = max(32, int(height * BRAND_PLATE_FRACTION))
    mark = max(16, int(plate * BRAND_MARK_FRACTION))
    margin = max(8, int(height * BRAND_MARGIN_FRACTION))
    inset = (plate - mark) // 2

    if position not in ("br", "bl", "tr", "tl"):
        raise Missing(f"Unbekannte Position '{position}' — erlaubt: br bl tr tl")
    left = position.endswith("l")
    top = position.startswith("t")
    box_x = f"{margin}" if left else f"iw-{margin + plate}"
    box_y = f"{margin}" if top else f"ih-{margin + plate}"
    ov_x = f"{margin + inset}" if left else f"W-{margin + plate - inset}"
    ov_y = f"{margin + inset}" if top else f"H-{margin + plate - inset}"

    return (
        f"[1:v]format=rgba,"
        f"geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='max(r(X,Y),max(g(X,Y),b(X,Y)))',"
        f"scale={mark}:{mark}[mark];"
        f"[0:v]drawbox=x={box_x}:y={box_y}:w={plate}:h={plate}:"
        f"color={BRAND_GROUND}@{BRAND_PLATE_ALPHA}:t=fill,"
        f"drawbox=x={box_x}:y={box_y}:w={plate}:h={plate}:"
        f"color={BRAND_INK}@{BRAND_BORDER_ALPHA}:t=1[plate];"
        f"[plate][mark]overlay={ov_x}:{ov_y}"
    )


def video_height(path: str) -> int:
    """Höhe aus ffmpeg selbst — wir haben absichtlich kein ffprobe (#1184)."""
    require("ffmpeg")
    with tempfile.TemporaryFile() as err_file:
        subprocess.run(["ffmpeg", "-hide_banner", "-i", path], stdout=subprocess.DEVNULL,
                       stderr=err_file)
        err_file.seek(0)
        text = err_file.read().decode("utf-8", "replace")
    for line in text.splitlines():
        if "Video:" in line:
            for token in line.replace(",", " ").split():
                if "x" in token and token.replace("x", "").isdigit():
                    parts = token.split("x")
                    if len(parts) == 2 and all(p.isdigit() for p in parts):
                        return int(parts[1])
    raise Missing(f"Keine Bildgröße in '{os.path.basename(path)}' gefunden — hat die Datei "
                  f"überhaupt ein Bild?")


def apply_brand(src: str, dst: str, position: str = "br") -> None:
    """Marke einbrennen. IMMER in eine NEUE Datei — Einbrennen ist unumkehrbar."""
    if os.path.abspath(src) == os.path.abspath(dst):
        raise Missing("Die Marke würde das Original überschreiben. Einbrennen ist "
                      "unumkehrbar — autocut schreibt grundsätzlich eine neue Datei.")
    require("ffmpeg")
    logo = brand_logo_path()
    flt = brand_filter(video_height(src), position)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src, "-i", logo,
                    "-filter_complex", flt,
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
                    "-c:a", "copy", dst], check=True)


def cmd_brand(args) -> int:
    src = args.input
    stem = os.path.splitext(os.path.basename(src))[0]
    outdir = args.outdir or os.path.dirname(os.path.abspath(src))
    os.makedirs(outdir, exist_ok=True)
    dst = os.path.join(outdir, f"{stem}_echoel.mp4")
    apply_brand(src, dst, args.position)
    print(f"  {os.path.basename(dst)}  {os.path.getsize(dst)/1e6:.1f} MB")
    print("  Das Original ist unangetastet.")
    return 0


def read_activity_frames(path: str, cols: int = ZOOM_COLS,
                         rows: int = ZOOM_ROWS, fps: int = ZOOM_FPS) -> list[bytes]:
    """Graue Miniaturbilder als Strom — dieselbe Bauform wie `read_envelope` (#1183):
    nie das ganze Video im Speicher, jedes Bild sofort auf `cols*rows` Byte reduziert."""
    require("ffmpeg")
    size = cols * rows
    out: list[bytes] = []
    with tempfile.TemporaryFile() as err_file:
        proc = subprocess.Popen(
            ["ffmpeg", "-v", "error", "-i", path, "-an",
             "-vf", f"fps={fps},scale={cols}:{rows}", "-f", "rawvideo",
             "-pix_fmt", "gray", "-"],
            stdout=subprocess.PIPE, stderr=err_file)
        try:
            carry = b""
            while True:
                block = proc.stdout.read(size * 32)
                if not block:
                    break
                buf = carry + block
                whole = len(buf) // size
                for k in range(whole):
                    out.append(buf[k * size:(k + 1) * size])
                carry = buf[whole * size:]
            proc.stdout.close()
            code = proc.wait()
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
        err_file.seek(0)
        message = err_file.read().decode("utf-8", "replace").strip()
    if code != 0:
        raise Missing(f"ffmpeg konnte das Bild von '{os.path.basename(path)}' nicht lesen "
                      f"(Code {code}).\n    {message[:400]}")
    if len(out) < 2:
        raise Missing(f"'{os.path.basename(path)}' liefert weniger als zwei Bilder — ohne "
                      f"zwei Bilder gibt es keine Veränderung zu messen.")
    return out


def video_size(path: str) -> tuple[int, int]:
    """Breite und Höhe aus ffmpeg selbst (kein ffprobe, #1184)."""
    require("ffmpeg")
    with tempfile.TemporaryFile() as err_file:
        subprocess.run(["ffmpeg", "-hide_banner", "-i", path], stdout=subprocess.DEVNULL,
                       stderr=err_file)
        err_file.seek(0)
        text = err_file.read().decode("utf-8", "replace")
    for line in text.splitlines():
        if "Video:" in line:
            for token in line.replace(",", " ").split():
                parts = token.split("x")
                if len(parts) == 2 and all(p.isdigit() for p in parts):
                    return int(parts[0]), int(parts[1])
    raise Missing(f"Keine Bildgröße in '{os.path.basename(path)}' gefunden.")


ASPECTS = {"quelle": None, "16:9": 16 / 9, "9:16": 9 / 16, "1:1": 1.0, "4:5": 4 / 5}


def cmd_zoom(args) -> int:
    src = args.input
    width, height = video_size(src)
    frames = read_activity_frames(src)
    activity = activity_grid(frames, ZOOM_COLS, ZOOM_ROWS)
    box = activity_box(activity, ZOOM_COLS, ZOOM_ROWS, args.coverage)
    aspect = ASPECTS[args.aspect]
    x, y, w, h = crop_rect(box, ZOOM_COLS, ZOOM_ROWS, width, height, aspect)

    moved = sum(activity)
    conc = concentration(activity)
    print(f"autocut zoom: {os.path.basename(src)}  ({width}×{height}, "
          f"{len(frames)} Abtastungen)")
    print(f"  Konzentration: {conc:.0%} der Veränderung in den aktivsten 10 % der Fläche")

    if moved <= 0:
        print("  ⛔ NICHTS BEWEGT SICH in diesem Clip. Es gibt keine Stelle, an die man\n"
              "     heranzoomen könnte.")
        return 2
    if conc < ZOOM_MIN_CONCENTRATION and not args.force:
        print(f"  ⛔ DIE VERÄNDERUNG IST ÜBER DAS GANZE BILD VERTEILT "
              f"(unter {ZOOM_MIN_CONCENTRATION:.0%}).\n"
              f"     Es gibt hier keine EINE Stelle — bei einer laufenden Echoel-Sitzung\n"
              f"     bewegt sich der ganze Schirm. Ein Ausschnitt wäre willkürlich, und ein\n"
              f"     willkürlicher Zoom sieht absichtlich aus.\n"
              f"     Was hilft: einen kurzen Abschnitt herausschneiden, in dem NUR eine\n"
              f"     Bedienung passiert — oder --force, wenn du es trotzdem willst.")
        return 2

    print(f"  Ausschnitt: {w}×{h} bei ({x}, {y})  — {100*w*h/(width*height):.0f} % der Fläche")

    if not args.write:
        print("  (nur gemessen — mit --write wird geschnitten)")
        return 0

    stem = os.path.splitext(os.path.basename(src))[0]
    outdir = args.outdir or os.path.dirname(os.path.abspath(src))
    os.makedirs(outdir, exist_ok=True)
    dst = os.path.join(outdir, f"{stem}_zoom.mp4")
    if os.path.abspath(src) == os.path.abspath(dst):
        raise Missing("Der Zuschnitt würde das Original überschreiben.")
    require("ffmpeg")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src,
                    "-vf", f"crop={w}:{h}:{x}:{y}",
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
                    "-c:a", "copy", dst], check=True)
    print(f"  → {os.path.basename(dst)}   (Original unangetastet)")
    if args.brand:
        branded = os.path.join(outdir, f"{stem}_zoom_echoel.mp4")
        apply_brand(dst, branded, args.position)
        print(f"  → {os.path.basename(branded)}")
    return 0


def cmd_proxy(args) -> int:
    """Kleine Datei + Kontaktbogen — gegen den genannten Engpass 'Videos hochladen'."""
    src = args.input
    stem = os.path.splitext(os.path.basename(src))[0]
    outdir = args.outdir or os.path.dirname(os.path.abspath(src))
    os.makedirs(outdir, exist_ok=True)
    proxy = os.path.join(outdir, f"{stem}_proxy.mp4")
    sheet = os.path.join(outdir, f"{stem}_contact.jpg")
    require("ffmpeg")

    src_w, src_h = video_size(src)
    if src_w >= src_h:
        scale = f"scale={PROXY_LONG_SIDE}:-2"
    else:
        scale = f"scale=-2:{PROXY_LONG_SIDE}"
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src,
                    "-vf", scale, "-c:v", "libx264",
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
            if getattr(args, "brand", False):
                # ⚠️ ZWEI Dateien, nicht eine überschriebene: der rohe Schnitt bleibt liegen.
                #    Einbrennen ist unumkehrbar, und wer die Marke anders setzen will, soll
                #    nicht neu schneiden müssen.
                branded = os.path.join(outdir, f"{stem}_hl{i:02d}_echoel.mp4")
                apply_brand(out, branded, args.position)
                print(f"     → {os.path.basename(out)}  +  {os.path.basename(branded)}")
            else:
                print(f"     → {os.path.basename(out)}")
    else:
        print("  (nur gemessen — mit --write werden die Clips geschrieben)")
    return 0


# ── Selbsttest: treibt die reinen Kerne, braucht kein ffmpeg ─────────────────────────

def drive(workdir: str) -> int:
    """Ende-zu-Ende gegen ECHTE Dateien: baut zwei Videos mit BEKANNTEM Versatz und fährt
    alle drei Befehle durch.

    ⭐ WARUM DAS EXISTIERT. `--selftest` treibt die Rechnung, fasst aber kein ffmpeg an. Nach
       dem ersten Bau stand in vier Dateien "die ffmpeg-Hülle ist ungetestet" — und das war
       nur solange wahr, wie niemand nachsah. Ein einmal von Hand gefahrener Beweis altert
       zu einer Behauptung; dieser hier ist ein Befehl. Für den Founder ist er zusätzlich der
       billige Weg, sein eigenes ffmpeg zu prüfen, BEVOR er echtes Material anfasst.

    ⚠️ WAS ER NICHT BEWEIST: dass echtes Kameramaterial syncet. Diese Videos teilen denselben
       erzeugten Ton. Zwei Geräte im Raum teilen NUR den Lautstärkeverlauf — verschiedene
       Mikrofone, verschiedene Abstände, verschiedener Hall. Deshalb misst `sync` sein
       Vertrauen und verweigert im Zweifel.
    """
    require("ffmpeg")
    os.makedirs(workdir, exist_ok=True)
    truth = 2.0
    sr = 44100
    fails = 0

    def check(name: str, ok: bool, detail: str = "") -> None:
        nonlocal fails
        print(f"  {'PASS' if ok else 'FAIL'}  {name}{'  — ' + detail if detail else ''}")
        if not ok:
            fails += 1

    import wave                                       # nur hier gebraucht

    def write_wav(path: str, lead: float) -> None:
        n = int(sr * 40.0)
        frames = bytearray(n * 2)
        for at, width in ((3.0, 0.6), (7.4, 0.3), (12.1, 1.1), (19.8, 0.4),
                          (26.5, 0.9), (33.2, 0.5)):
            t0 = int((at + lead) * sr)
            for i in range(t0, min(n, t0 + int(width * sr))):
                v = int(math.sin(2 * math.pi * 220 * i / sr) * 0.8 * 32000)
                struct.pack_into("<h", frames, i * 2, v)
        with wave.open(path, "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(sr)
            f.writeframes(bytes(frames))

    print(f"autocut --drive  (Arbeitsordner: {workdir})")
    paths = {}
    for name, lead in (("a", 0.0), ("b", truth)):
        wav = os.path.join(workdir, f"drive_{name}.wav")
        mp4 = os.path.join(workdir, f"drive_{name}.mp4")
        write_wav(wav, lead)
        subprocess.run(["ffmpeg", "-y", "-v", "error",
                        "-f", "lavfi", "-i", "color=c=blue:s=640x360:r=25:d=40",
                        "-i", wav, "-c:v", "libx264", "-preset", "ultrafast",
                        "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", mp4], check=True)
        paths[name] = mp4

    res = sync_offset(read_envelope(paths["a"]), read_envelope(paths["b"]),
                      FINE_HOP_MS, DEFAULT_MAX_OFFSET_S)
    err = abs(res.offset_seconds - truth)
    check(f"sync findet die bekannten {truth:+.2f} s durch echtes ffmpeg",
          res.trustworthy and err < 0.05,
          f"gemessen {res.offset_seconds:+.3f} s, Fehler {err*1000:.0f} ms, "
          f"Vertrauen {res.confidence:.2f}×")

    env = read_envelope(paths["a"])
    hits = pick_highlights(env, FINE_HOP_MS, clip_seconds=1.0, count=3, min_gap_seconds=2.0)
    # Die drei LÄNGSTEN Bursts liegen bei 12,1 s · 26,5 s · 3,0 s. Ein Fenster darf davor
    # beginnen, muss den Burst aber treffen.
    wanted = (12.1, 26.5, 3.0)
    got = sorted(h.start_seconds for h in hits)
    ok = len(hits) == 3 and all(
        any(w - 1.0 <= g <= w + 1.0 for g in got) for w in wanted)
    check("highlights trifft die drei lautesten Stellen", ok,
          f"{[round(g, 2) for g in got]}")

    out = os.path.join(workdir, "drive_out")
    os.makedirs(out, exist_ok=True)
    for i, h in enumerate(hits[:2], 1):
        clip = os.path.join(out, f"drive_hl{i:02d}.mp4")
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", f"{h.start_seconds:.3f}",
                        "-i", paths["a"], "-t", f"{h.duration_seconds:.3f}",
                        "-c:v", "libx264", "-preset", "veryfast", "-c:a", "aac", clip],
                       check=True)
        clip_env = read_envelope(clip)
        loud = (sum(clip_env) / len(clip_env)) if clip_env else 0.0
        # Der geschnittene Clip muss WESENTLICH lauter sein als der Schnitt des Ganzen —
        # sonst hat `-ss` danebengegriffen und wir hätten Stille exportiert.
        check(f"geschnittener Clip {i} trägt den lauten Teil",
              loud > 3 * (sum(env) / len(env)), f"Mittel {loud:.4f}")

    # ── Die Marke (CI) ───────────────────────────────────────────────────────────────
    src = paths["a"]
    before = (os.path.getsize(src), os.path.getmtime(src))
    branded = os.path.join(out, "drive_branded.mp4")
    apply_brand(src, branded, "br")
    check("Marke schreibt eine NEUE Datei", os.path.exists(branded))
    check("Marke lässt das Original unangetastet",
          (os.path.getsize(src), os.path.getmtime(src)) == before)

    # ⛔ ERST PRÜFTE DIESER BLOCK NUR "Ecke ändert sich, Mitte nicht", UND BEIDE MUTANTEN
    #    KAMEN DURCH: eine auf VOLLBILD skalierte Marke sitzt wegen `overlay=W-…` fast ganz
    #    ausserhalb des Bildes, und eine WEGGELASSENE Platte ändert die Ecke ja trotzdem.
    #    Die Ansprüche prüften, DASS etwas passiert, nicht WO und nicht WOZU. Jetzt:
    #    die drei anderen Ecken müssen unberührt bleiben (Ort), und auf HELLEM Material muss
    #    die Ecke deutlich DUNKLER werden (Zweck der Platte — genau das, was die Marke auf
    #    einer Bildschirmaufnahme überhaupt lesbar macht).
    def quadrants(path: str) -> dict:
        raw = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", path, "-frames:v", "1",
             "-vf", "scale=64:36", "-f", "rawvideo", "-pix_fmt", "gray", "-"],
            capture_output=True, check=True).stdout
        if len(raw) < 64 * 36:
            raise Missing("Graubild zu kurz — ffmpeg hat kein Vollbild geliefert")
        rows = [raw[y * 64:(y + 1) * 64] for y in range(36)]

        def patch(x0, y0):
            return sum(sum(r[x0:x0 + 12]) for r in rows[y0:y0 + 10])

        return {"tl": patch(2, 2), "tr": patch(50, 2),
                "bl": patch(2, 24), "br": patch(50, 24),
                "mitte": patch(26, 13)}

    before_q = quadrants(src)
    after_q = quadrants(branded)
    check("Marke verändert die gewählte Ecke (br)", before_q["br"] != after_q["br"],
          f"{before_q['br']} → {after_q['br']}")
    untouched = [k for k in ("tl", "tr", "bl", "mitte") if before_q[k] != after_q[k]]
    check("Marke fasst NUR ihre Ecke an", not untouched,
          f"mit-verändert: {untouched}" if untouched else "die anderen vier Felder bleiben gleich")

    # Der Zweck der Platte, an HELLEM Material gemessen — dem Fall einer Bildschirmaufnahme.
    light = os.path.join(workdir, "drive_light.mp4")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi",
                    "-i", "color=c=0xF2F2F2:s=854x480:d=1:r=25",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", light], check=True)
    light_branded = os.path.join(out, "drive_light_echoel.mp4")
    apply_brand(light, light_branded, "br")
    # ⛔ ERST WURDE MIT DEM 64×36-RASTER OBEN GEMESSEN, UND DER ANSPRUCH WAR ZU RECHT ROT:
    #    11 % statt der verlangten 25 %. Nicht die Platte war zu schwach, sondern das
    #    MESSFELD zu gross — es war rund fünfmal so breit wie die Platte, also verdünnte der
    #    unveränderte Rand den Effekt. Ein Messfeld, das nicht deckungsgleich mit der Sache
    #    ist, misst den Durchschnitt aus Sache und Umgebung. Jetzt schneidet ffmpeg exakt das
    #    Plattenrechteck heraus und mittelt es auf EINEN Wert — keine Rasterarithmetik.
    def plate_luma(path: str) -> int:
        h = video_height(path)
        plate = max(32, int(h * BRAND_PLATE_FRACTION))
        margin = max(8, int(h * BRAND_MARGIN_FRACTION))
        raw = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", path, "-frames:v", "1",
             "-vf", f"crop={plate}:{plate}:iw-{margin + plate}:ih-{margin + plate},"
                    f"scale=1:1", "-f", "rawvideo", "-pix_fmt", "gray", "-"],
            capture_output=True, check=True).stdout
        if not raw:
            raise Missing("Kein Bildpunkt zurückgekommen — Zuschnitt ausserhalb des Bildes?")
        return raw[0]

    lb, la = plate_luma(light), plate_luma(light_branded)
    check("die Platte dunkelt auf hellem Material wirklich ab", la < lb * 0.75,
          f"Helligkeit {lb} → {la} (mindestens 25 % dunkler verlangt)")

    # ⛔ UND HIER FEHLTE DER WICHTIGSTE ANSPRUCH ÜBERHAUPT, gefunden durch einen Mutanten,
    #    der die Marke auf Vollbild skaliert: sie landet dann wegen `overlay=W-…` fast ganz
    #    AUSSERHALB des Bildes, und übrig bleibt eine leere dunkle Platte OHNE LOGO. Alle
    #    bisherigen Ansprüche blieben grün — sie prüften die Platte (dunkel), den Ort (Ecke)
    #    und die Unversehrtheit des Originals, aber KEINER prüfte, ob die Marke selbst da ist.
    #    Ein Wasserzeichen ohne Zeichen bestand jede Prüfung. Gemessen wird jetzt der KONTRAST
    #    INNERHALB der Platte: helle Tinte auf dunklem Grund spreizt die Helligkeit, eine leere
    #    Platte ist gleichförmig.
    def plate_contrast(path: str) -> int:
        # ⚠️ 15 % EINZUG, UND DAS IST DER GANZE ANSPRUCH. Ohne Einzug liegen der 1-px-Rand der
        #    Platte und ihre weichgezeichnete Kante gegen den hellen Grund MIT im Messfeld, und
        #    die erzeugen für sich schon Kontrast: gemessen bei 480p 84 mit Marke gegen 70 ohne
        #    — 14 Punkte Abstand, aus denen keine Schwelle etwas machen kann. Mit Einzug sind es
        #    111 gegen 3.
        # ⛔ UND ICH HABE DAS ZUERST BEI 1080p GEPRÜFT UND ENTWARNUNG GEGEBEN: dort ist der Rand
        #    1 px von 140 und stört kaum (10), bei den 480p dieses Tests ist er 1 von 62 und
        #    dominiert. Eine Messung in einem anderen MASSSTAB als die geprüfte Sache ist eine
        #    andere Messung — sie kann in beide Richtungen beruhigen.
        h = video_height(path)
        plate = max(32, int(h * BRAND_PLATE_FRACTION))
        margin = max(8, int(h * BRAND_MARGIN_FRACTION))
        inset = max(2, int(plate * 0.15))
        side = plate - 2 * inset
        raw = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", path, "-frames:v", "1",
             "-vf", f"crop={side}:{side}:iw-{margin + plate - inset}:ih-{margin + plate - inset},"
                    f"scale=8:8", "-f", "rawvideo", "-pix_fmt", "gray", "-"],
            capture_output=True, check=True).stdout
        if len(raw) < 64:
            raise Missing("Zu wenige Bildpunkte für den Kontrast der Platte")
        return max(raw[:64]) - min(raw[:64])

    contrast = plate_contrast(light_branded)
    check("die MARKE selbst steht auf der Platte (nicht nur ein leerer Kasten)",
          contrast > 40, f"Kontrast in der Platte: {contrast} (mehr als 40 verlangt)")

    try:
        apply_brand(src, src, "br")
        check("Marke verweigert das Überschreiben des Originals", False, "hat NICHT verweigert")
    except Missing:
        check("Marke verweigert das Überschreiben des Originals", True)
    except subprocess.CalledProcessError:
        # ⚠️ Ohne unseren Schutz verweigert ffmpeg SELBST (Ein- und Ausgabe dieselbe Datei)
        #    und wirft. Das ist ebenfalls "nicht überschrieben", aber als Absturz statt als
        #    Befund — deshalb hier als FAIL gewertet: ein Werkzeug, das mit einem Stacktrace
        #    endet, hat dem Nutzer nichts erklärt.
        check("Marke verweigert das Überschreiben des Originals", False,
              "ffmpeg brach ab, statt dass autocut es sauber ablehnt")

    # ── Auto-Zoom gegen echtes Material ──────────────────────────────────────────────
    # Eine "Bildschirmaufnahme": ruhige helle Fläche, und NUR unten rechts blinkt ein Kasten.
    screen = os.path.join(workdir, "drive_screen.mp4")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi",
                    "-i", "color=c=0xF2F2F2:s=1280x720:d=6:r=25",
                    "-vf", "drawbox=x=980:y=560:w=180:h=110:"
                           "color=black@1.0:t=fill:enable='lt(mod(t,1),0.5)'",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", screen], check=True)

    w0, h0 = video_size(screen)
    grid = read_activity_frames(screen)
    act = activity_grid(grid, ZOOM_COLS, ZOOM_ROWS)
    zbox = activity_box(act, ZOOM_COLS, ZOOM_ROWS, ZOOM_COVERAGE)
    zx, zy, zw, zh = crop_rect(zbox, ZOOM_COLS, ZOOM_ROWS, w0, h0, None)

    # Der blinkende Kasten liegt bei x 980..1160, y 560..670 von 1280×720.
    covers = zx <= 980 and zy <= 560 and zx + zw >= 1160 and zy + zh >= 670
    check("Zoom findet den blinkenden Bereich in echtem Material", covers,
          f"Zuschnitt ({zx},{zy}) {zw}×{zh}")
    check("Zoom schneidet wirklich zu, statt das Vollbild zurückzugeben",
          zw * zh < w0 * h0 * 0.75,
          f"{100 * zw * zh / (w0 * h0):.0f} % der Fläche")

    zoomed = os.path.join(out, "drive_zoom.mp4")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", screen,
                    "-vf", f"crop={zw}:{zh}:{zx}:{zy}", "-c:v", "libx264",
                    "-preset", "veryfast", zoomed], check=True)
    zw2, zh2 = video_size(zoomed)
    check("der geschnittene Clip hat genau die berechnete Grösse",
          (zw2, zh2) == (zw, zh), f"{zw2}×{zh2} gegen {zw}×{zh}")

    # ⚠️ Und er muss den Kasten WIRKLICH ENTHALTEN. Eine Grössenprüfung allein wäre blind
    #    dafür, dass der Zuschnitt an der falschen Stelle sitzt: der Ausschnitt muss ZEITLICH
    #    zwischen hell und dunkel wechseln, weil der Kasten blinkt.
    def mean_luma_at(path: str, when: float) -> int:
        raw = subprocess.run(
            ["ffmpeg", "-v", "error", "-ss", f"{when:.2f}", "-i", path, "-frames:v", "1",
             "-vf", "scale=1:1", "-f", "rawvideo", "-pix_fmt", "gray", "-"],
            capture_output=True, check=True).stdout
        if not raw:
            raise Missing("Kein Bildpunkt — Zeitpunkt hinter dem Ende?")
        return raw[0]

    bright = mean_luma_at(zoomed, 0.75)   # Kasten AUS
    dark = mean_luma_at(zoomed, 2.25)     # Kasten AN
    check("im Ausschnitt blinkt es wirklich (er sitzt an der richtigen Stelle)",
          bright - dark > 20, f"hell {bright} gegen dunkel {dark}")

    # ⭐ DER FALL DES ECHTEN MATERIALS (#1187): bei laufender App bewegt sich der GANZE
    #    Schirm. Ein Rauschbild ist die härteste Form davon — der Zoom muss hier VERWEIGERN,
    #    nicht einen willkürlichen Ausschnitt liefern.
    busy = os.path.join(workdir, "drive_busy.mp4")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi",
                    "-i", "nullsrc=s=640x360:d=4:r=25",
                    "-vf", "geq=random(1)*255:128:128", "-c:v", "libx264",
                    "-pix_fmt", "yuv420p", busy], check=True)
    busy_conc = concentration(activity_grid(read_activity_frames(busy),
                                            ZOOM_COLS, ZOOM_ROWS))
    check("Veränderung über das ganze Bild wird als NICHT konzentriert erkannt",
          busy_conc < ZOOM_MIN_CONCENTRATION, f"{busy_conc:.0%}")
    check("konzentriertes Material liegt klar darüber",
          concentration(act) > ZOOM_MIN_CONCENTRATION, f"{concentration(act):.0%}")

    # ── Proxy: die LANGE Seite ist das Mass, in beiden Lagen (#1188) ─────────────────
    for label, size in (("quer", "854x480"), ("hoch", "480x854")):
        raw_clip = os.path.join(workdir, f"drive_proxy_{label}.mp4")
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi",
                        "-i", f"testsrc=s={size}:d=2:r=25", "-c:v", "libx264",
                        "-pix_fmt", "yuv420p", raw_clip], check=True)

        class ProxyArgs:
            input = raw_clip
            outdir = os.path.join(out, f"proxy_{label}")
        cmd_proxy(ProxyArgs())
        made = os.path.join(ProxyArgs.outdir,
                            f"drive_proxy_{label}_proxy.mp4")
        pw, ph = video_size(made)
        check(f"Proxy ({label}) misst die LANGE Seite, nicht die Höhe",
              max(pw, ph) == PROXY_LONG_SIDE, f"{pw}×{ph}, lange Seite {max(pw, ph)}")

    print(f"\n--drive: {'alles grün' if fails == 0 else f'{fails} FEHLER'}")
    return 0 if fails == 0 else 1


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

    # ── Auto-Zoom: die reine Rechnung ────────────────────────────────────────────────
    cols, rows = 48, 27

    def frame_with_blob(cx: int, cy: int, value: int) -> bytes:
        """Grauwert-Miniatur: ruhiger Grund, ein Fleck bei (cx, cy)."""
        buf = bytearray([40] * (cols * rows))
        for y in range(max(0, cy - 2), min(rows, cy + 3)):
            for x in range(max(0, cx - 2), min(cols, cx + 3)):
                buf[y * cols + x] = value
        return bytes(buf)

    # Der Fleck flackert unten rechts, sonst passiert nichts.
    seq = [frame_with_blob(40, 21, 40 if i % 2 else 220) for i in range(12)]
    act = activity_grid(seq, cols, rows)
    box = activity_box(act, cols, rows)
    check("Zoom findet die Zelle, in der sich etwas ändert",
          box[0] >= 36 and box[1] >= 17 and box[2] <= 44 and box[3] <= 25, f"{box}")

    # ⚠️ Gegen ein FESTES Referenzbild wäre eine einmalige Änderung für immer "aktiv".
    #    Hier bewegt sich der Fleck EINMAL und bleibt dann liegen — die spätere Ruhe
    #    darf nicht als Aktivität zählen.
    # ⛔ ERST PRÜFTE DIESER ANSPRUCH NUR, WIE VIELE ZELLEN AKTIV SIND — und ein Mutant, der
    #    gegen das ERSTE Bild statt gegen das vorige rechnet, kam grün durch: er markiert
    #    DIESELBEN Zellen, nur zehnmal so hoch. Die Menge der aktiven Zellen kann die beiden
    #    Verfahren gar nicht unterscheiden; die SUMME kann es. Ein einmaliger Wechsel muss
    #    genau EINEN Übergang wert sein, nicht zehn.
    once = [frame_with_blob(8, 5, 40)] + [frame_with_blob(8, 5, 220)] * 10
    one_step = sum(activity_grid([frame_with_blob(8, 5, 40),
                                  frame_with_blob(8, 5, 220)], cols, rows))
    act2 = activity_grid(once, cols, rows)
    check("ein einmaliger Wechsel zählt EINMAL, nicht für den Rest des Clips",
          act2 and abs(sum(act2) - one_step) < 1e-6,
          f"Summe {sum(act2):.0f}, ein Übergang wäre {one_step:.0f}")

    # ── Konzentration: gibt es überhaupt EINE Stelle? ────────────────────────────────
    check("eine einzelne blinkende Stelle ist hoch konzentriert",
          concentration(act) > ZOOM_MIN_CONCENTRATION, f"{concentration(act):.0%}")

    # Veränderung überall — der Fall der laufenden App. Jede Zelle ändert sich um denselben
    # Betrag, also trägt jede gleich viel; die aktivsten 10 % tragen dann auch nur 10 %.
    everywhere = []
    for i in range(10):
        buf = bytearray(cols * rows)
        for j in range(cols * rows):
            buf[j] = 60 if (i + j) % 2 else 200
        everywhere.append(bytes(buf))
    conc_spread = concentration(activity_grid(everywhere, cols, rows))
    check("Veränderung ÜBERALL ist NICHT konzentriert (der Zoom muss hier verweigern)",
          conc_spread < ZOOM_MIN_CONCENTRATION, f"{conc_spread:.0%}")

    check("ohne jede Veränderung ist die Konzentration 0, nicht undefiniert",
          concentration([0.0] * 100) == 0.0 and concentration([]) == 0.0)

    still = [frame_with_blob(10, 10, 100)] * 6
    check("völlig ruhiges Material ergibt das GANZE Bild, keine willkürliche Ecke",
          activity_box(activity_grid(still, cols, rows), cols, rows) == (0, 0, cols - 1, rows - 1))

    # ⛔ ERST PRÜFTE DIES EINEN EINZIGEN ZUSCHNITT, UND DER WAR ZUFÄLLIG SCHON GERADE (480×270):
    #    ein Mutant, der das Abrunden weglässt, kam grün durch. Ein Anspruch über eine
    #    Rundungsregel braucht einen Fall, in dem ohne sie etwas UNGERADES herauskäme —
    #    sonst prüft er die Regel gar nicht. Jetzt viele Bildgrössen und Kästen, darunter
    #    krumme Seitenlängen, für die die Rasterteilung nicht aufgeht.
    odd_seen = False
    bad_even, bad_inside = [], []
    for (fw, fh) in ((1920, 1080), (1280, 720), (1001, 563), (854, 480), (720, 1280)):
        for bx in (0, 7, 23, 40, cols - 1):
            for by in (0, 5, 13, rows - 1):
                b = (bx, by, min(cols - 1, bx + 3), min(rows - 1, by + 2))
                for asp in (None, 16 / 9, 9 / 16, 1.0):
                    cx_, cy_, cw_, ch_ = crop_rect(b, cols, rows, fw, fh, asp)
                    if any(v % 2 for v in (cx_, cy_, cw_, ch_)):
                        bad_even.append((fw, fh, b, asp, (cx_, cy_, cw_, ch_)))
                    if cx_ < 0 or cy_ < 0 or cx_ + cw_ > fw or cy_ + ch_ > fh:
                        bad_inside.append((fw, fh, b, asp, (cx_, cy_, cw_, ch_)))
                    if (fw * 1.0 / cols) % 2 or (fh * 1.0 / rows) % 2:
                        odd_seen = True
    check("Zuschnitt hat IMMER gerade Kanten (h264 verlangt das)",
          not bad_even and odd_seen,
          f"{len(bad_even)} krumme von {5*5*4*4} Fällen" if bad_even else
          "alle 400 Fälle gerade, krumme Rasterteilungen dabei")
    check("Zuschnitt bleibt IMMER im Bild", not bad_inside,
          f"{len(bad_inside)} ausserhalb" if bad_inside else "alle 400 Fälle innerhalb")

    # Die Polsterung hat einen Zweck: die Handlung soll nicht am Ausschnittrand kleben.
    # Ein grosser Kasten, bei dem die Mindestgrösse NICHT greift — sonst prüfte der Anspruch
    # die Mindestgrösse statt die Polsterung.
    big = (10, 5, 37, 21)
    bw_px = (big[2] + 1 - big[0]) * 1920 / cols
    bh_px = (big[3] + 1 - big[1]) * 1080 / rows
    padded = crop_rect(big, cols, rows, 1920, 1080, aspect=None)
    check("um die Handlung bleibt Luft (die Polsterung wirkt)",
          padded[2] > bw_px + 2 and padded[3] > bh_px + 2,
          f"Kasten {bw_px:.0f}×{bh_px:.0f} → Ausschnitt {padded[2]}×{padded[3]}")

    tiny = crop_rect((24, 13, 24, 13), cols, rows, 1920, 1080, aspect=None)
    check("Zuschnitt schnurrt NICHT auf einen blinkenden Cursor zusammen",
          tiny[2] >= 1920 * ZOOM_MIN_FRACTION and tiny[3] >= 1080 * ZOOM_MIN_FRACTION,
          f"{tiny[2]}×{tiny[3]}")

    tall = crop_rect((20, 10, 28, 16), cols, rows, 1920, 1080, aspect=9 / 16)
    ratio = tall[2] / tall[3]
    check("Hochformat 9:16 wird eingehalten", abs(ratio - 9 / 16) < 0.02,
          f"{tall[2]}×{tall[3]} = {ratio:.3f}")

    wide = crop_rect((0, 0, cols - 1, rows - 1), cols, rows, 1920, 1080, aspect=16 / 9)
    check("ein Vollbild-Kasten sprengt das Bild nicht",
          wide[0] + wide[2] <= 1920 and wide[1] + wide[3] <= 1080, f"{wide}")

    print(f"\nselftest: {'alle Ansprüche grün' if fails == 0 else f'{fails} FEHLER'}")
    return 0 if fails == 0 else 1


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(
        prog="autocut", description="Sync · Highlights · Upload-Proxy für Echoel-Rohmaterial")
    p.add_argument("--drive", metavar="ORDNER",
                   help="Ende-zu-Ende gegen echte, selbst gebaute Videos (braucht ffmpeg)")
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

    sz = sub.add_parser("zoom", help="an die Stelle heranzoomen, wo etwas passiert")
    sz.add_argument("input")
    sz.add_argument("--aspect", default="quelle", choices=list(ASPECTS),
                    help="Seitenverhältnis der Ausgabe (9:16 = Hochformat)")
    sz.add_argument("--coverage", type=float, default=ZOOM_COVERAGE,
                    help="Anteil der Veränderung, der im Ausschnitt liegen muss")
    sz.add_argument("--force", action="store_true",
                    help="auch zoomen, wenn die Veränderung über das ganze Bild verteilt ist")
    sz.add_argument("--write", action="store_true", help="wirklich schneiden")
    sz.add_argument("--brand", action="store_true", help="Marke danach einbrennen")
    sz.add_argument("--position", default="br", choices=["br", "bl", "tr", "tl"])
    sz.add_argument("--outdir")
    sz.set_defaults(fn=cmd_zoom)

    sb = sub.add_parser("brand", help="Echoel-Marke einbrennen (neue Datei)")
    sb.add_argument("input")
    sb.add_argument("--position", default="br", choices=["br", "bl", "tr", "tl"],
                    help="Ecke: br unten-rechts (Standard), bl, tr, tl")
    sb.add_argument("--outdir")
    sb.set_defaults(fn=cmd_brand)

    sh = sub.add_parser("highlights", help="die spannendsten Stellen finden")
    sh.add_argument("input")
    sh.add_argument("--count", type=int, default=5)
    sh.add_argument("--length", type=float, default=20.0, help="Clip-Länge in Sekunden")
    sh.add_argument("--gap", type=float, default=5.0, help="Mindestabstand zwischen Clips")
    sh.add_argument("--write", action="store_true", help="Clips wirklich schreiben")
    sh.add_argument("--brand", action="store_true",
                    help="Echoel-Marke in die geschriebenen Clips einbrennen")
    sh.add_argument("--position", default="br", choices=["br", "bl", "tr", "tl"])
    sh.add_argument("--outdir")
    sh.set_defaults(fn=cmd_highlights)

    args = p.parse_args(argv)
    if args.selftest:
        return selftest()
    if args.drive:
        try:
            return drive(args.drive)
        except Missing as exc:
            print(f"autocut: {exc}", file=sys.stderr)
            return 3
    if not getattr(args, "fn", None):
        p.print_help()
        return 1
    try:
        return args.fn(args)
    except Missing as exc:
        print(f"autocut: {exc}", file=sys.stderr)
        return 3
    except subprocess.CalledProcessError as exc:
        print(f"autocut: ffmpeg brach ab ({exc.returncode}).", file=sys.stderr)
        return 4


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
