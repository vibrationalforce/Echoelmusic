#!/bin/bash
# Autocut — Doppelklick-Start für autocut.py (macOS).
#
# FOUNDER-AUFTRAG 2026-09-09: "kannst du mir eine autocut application bauen, die ich auf dem
# Mac Book installiere?" — das hier IST die Installation: Datei doppelklicken, fertig.
# Kein Target, keine Signierung, keine App im Ordner "Programme".
#
# ⛔ WARUM BASH UND NICHT PYTHON-GUI. Ein Doppelklick auf eine .command öffnet Terminal im
#    richtigen Ordner. Eine GUI bräuchte ein Fenster-Framework, das dieses Repo nicht hat
#    (ZERO dependencies) und das diese Sitzung ohne macOS nicht testen könnte.
#
# ⚠️ WAS HIER NICHT GETESTET IST: diese Datei selbst. Die Sitzung, die sie schreibt, hat kein
#    macOS. Das Werkzeug DAHINTER ist getrieben — `--selftest` (Rechnung) und `--drive`
#    (echtes ffmpeg, echte Videos) liefen beide grün. Der Selbsttest läuft hier absichtlich
#    als ERSTES, damit ein kaputtes Python auffällt, bevor du ein Video anfasst.

set -u
cd "$(dirname "$0")" || exit 1

PY=python3
SCRIPT=./autocut.py

echo "════════════════════════════════════════════════"
echo "  Echoel Autocut"
echo "════════════════════════════════════════════════"
echo

# ── 1. Läuft Python? ────────────────────────────────────────────────────────────────
if ! command -v "$PY" >/dev/null 2>&1; then
  echo "FEHLT: python3."
  echo "  macOS bringt es mit den Xcode Command Line Tools:  xcode-select --install"
  echo
  read -r -p "[Enter] schließt das Fenster." _
  exit 1
fi

# ── 2. Läuft ffmpeg? Kein Abbruch — der Selbsttest braucht es nicht. ────────────────
# ⛔ Hier wurde auch `ffprobe` geprüft. autocut braucht es nicht mehr — sein einziger Nutzer
#    war eine Funktion mit null Aufrufern (#1184). Eine Prüfung auf ein Programm, das das
#    Werkzeug gar nicht ruft, schickt Leute grundlos zum Installieren.
HAVE_FFMPEG=1
if ! command -v ffmpeg >/dev/null 2>&1; then
  HAVE_FFMPEG=0
  echo "FEHLT: ffmpeg"
fi
if [ "$HAVE_FFMPEG" -eq 0 ]; then
  echo
  echo "  So installierst du es:   brew install ffmpeg"
  echo "  (Homebrew fehlt?         https://brew.sh )"
  echo
  echo "  Der Selbsttest läuft trotzdem. Videos verarbeiten geht ohne ffmpeg nicht."
  echo
fi

# ── 3. Selbsttest ZUERST — er ist der einzige bewiesene Teil. ───────────────────────
echo "── Selbsttest ──────────────────────────────────"
if ! "$PY" "$SCRIPT" --selftest; then
  echo
  echo "SELBSTTEST ROT. Nichts weiter tun — melde das, bevor du Material verarbeitest."
  read -r -p "[Enter] schließt das Fenster." _
  exit 1
fi
echo

if [ "$HAVE_FFMPEG" -eq 0 ]; then
  read -r -p "[Enter] schließt das Fenster." _
  exit 0
fi

# ── 4. Pfad-Eingabe. Auf dem Mac zieht man die Datei ins Fenster; ───────────────────
#     der Finder fügt sie mit Backslash-Escapes oder in Anführungszeichen ein.
ask_path() {
  local prompt="$1" p
  # ⛔ NICHT `read -p`: bash druckt dessen Prompt NUR, wenn stdin ein Terminal ist, und in
  #    einer Kommando-Substitution ist das nicht garantiert. Ein unsichtbarer Prompt sieht
  #    aus wie ein hängendes Fenster. Selbst drucken, nach stderr, damit $( ) ihn nicht frisst.
  printf '%s' "$prompt" >&2
  read -r p
  p="${p#\"}"; p="${p%\"}"      # "…"
  p="${p#\'}"; p="${p%\'}"      # '…'
  p="${p%"${p##*[![:space:]]}"}"  # Leerzeichen am Ende (Finder hängt eins an)
  printf '%s' "${p//\\ / }"     # \  → Leerzeichen
}

while true; do
  echo "Was soll ich tun?"
  echo "  0) Prüfen     — baut Testvideos und fährt alles durch (--drive)"
  echo "  1) Proxy      — kleine Datei zum Hochladen (dein genanntes Problem)"
  echo "  2) Sync       — Versatz zweier Aufnahmen über den Ton messen"
  echo "  3) Highlights — die lautesten Stellen finden und schneiden"
  echo "  q) Schluss"
  echo
  read -r -p "Auswahl: " choice
  echo

  case "$choice" in
    0)
      "$PY" "$SCRIPT" --drive "${TMPDIR:-/tmp}/autocut-drive"
      ;;
    1)
      IN=$(ask_path "Video hierher ziehen, dann Enter: ")
      [ -n "$IN" ] && "$PY" "$SCRIPT" proxy "$IN"
      ;;
    2)
      A=$(ask_path "Aufnahme A hierher ziehen, dann Enter: ")
      B=$(ask_path "Aufnahme B hierher ziehen, dann Enter: ")
      if [ -n "$A" ] && [ -n "$B" ]; then
        "$PY" "$SCRIPT" sync "$A" "$B"
        # Exit 2 = das Werkzeug VERWEIGERT die Antwort, weil es sich nicht sicher ist.
        [ $? -eq 2 ] && echo "→ Kein verlässlicher Versatz. Von Hand ausrichten ist hier ehrlicher."
      fi
      ;;
    3)
      IN=$(ask_path "Video hierher ziehen, dann Enter: ")
      if [ -n "$IN" ]; then
        read -r -p "Wie viele Clips? [5] " N; N="${N:-5}"
        read -r -p "Wie lang je Clip in Sekunden? [20] " L; L="${L:-20}"
        read -r -p "Wirklich schneiden? (sonst nur Liste) [j/N] " W
        if [ "$W" = "j" ] || [ "$W" = "J" ]; then
          "$PY" "$SCRIPT" highlights "$IN" --count "$N" --length "$L" --write
        else
          "$PY" "$SCRIPT" highlights "$IN" --count "$N" --length "$L"
        fi
      fi
      ;;
    q|Q) exit 0 ;;
    *) echo "Nicht verstanden." ;;
  esac
  echo
done
