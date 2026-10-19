#!/usr/bin/env python3
"""ptf-wordcount.py — word limits of the Prototype Fund application form, measured.

The class-03 handbook (PTF_Handbuch_2026.pdf, September 2026, p. 4) makes the limit a
VALIDITY condition: "Bewerbungen sind nur gültig, wenn die erlaubte Wortanzahl pro Frage
eingehalten wird." The limits are WORDS, not characters. This tool reads the form-ready
answers in docs/dev/FOERDERUNG_PROTOTYPE_FUND_2026.md §7.5 and prints, per answer:

  <id>  <words>/<limit>  worst=<n>  OK | TIGHT | OVER

An answer is a block between two HTML comments that are invisible when the markdown renders:

  <!-- ptf: F2 limit=100 -->
  …answer text…
  <!-- /ptf -->

Counting rule — conservative on purpose, because nobody has measured the platform's counter:
  words  = whitespace-separated tokens after stripping markdown emphasis (** * `), with
           list markers ("1.", "-", "•") removed; a lone dash or middle dot still counts.
  worst  = the same text with "-", "/", "–", "—" and "→" treated as word separators
           (OSC/ADM-OSC → 3 words). If `worst` exceeds the limit the answer is NOT safe.
  status = OVER  if words  > limit, or worst > limit
           TIGHT if words or worst > limit − ceil(limit × 0.08)  (less than an 8 % margin)
           OK    otherwise
  ⚠️ TIGHT reads `worst` too since 2026-10-19: a block whose plain count has room but whose
  worst case sits at the limit flips to OVER as soon as a placeholder is filled with a
  hyphenated name — the critic of the verification round found two such blocks reported OK.

Placeholders such as "[Founder: …]" count as words — they will be replaced by text of similar
length, so the margin must hold with them in place.

READ-ONLY. Like every script in this folder it changes no file (scripts/INDEX.md).
  python3 -I scripts/ptf-wordcount.py                 # the funding document, default path
  python3 -I scripts/ptf-wordcount.py <file.md>       # another markdown file with ptf blocks
  python3 -I scripts/ptf-wordcount.py --selftest      # the counting rule on built-in samples
Exit status: 0 when every block is OK or TIGHT, 1 when any block is OVER or none was found,
2 when the file cannot be read.
"""
from __future__ import annotations

import math
import re
import sys
from pathlib import Path

DEFAULT = "docs/dev/FOERDERUNG_PROTOTYPE_FUND_2026.md"
OPEN = re.compile(r"<!--\s*ptf:\s*(?P<id>[A-Za-z0-9_.-]+)\s+limit=(?P<limit>\d+)\s*-->")
CLOSE = re.compile(r"<!--\s*/ptf\s*-->")
EMPHASIS = re.compile(r"[*`_]+")
LIST_MARKER = re.compile(r"^\s*(?:\d+[.)]|[-•*])\s+", re.MULTILINE)
SPLITTERS = re.compile(r"[-/–—→]+")


def clean(block: str) -> str:
    text = LIST_MARKER.sub("", block)
    text = EMPHASIS.sub("", text)
    return text


def count_words(block: str) -> tuple[int, int]:
    text = clean(block)
    words = [t for t in text.split() if t.strip()]
    worst = [t for t in SPLITTERS.sub(" ", text).split() if t.strip()]
    return len(words), len(worst)


def status(words: int, worst: int, limit: int) -> str:
    if words > limit or worst > limit:
        return "OVER"
    if max(words, worst) > limit - math.ceil(limit * 0.08):
        return "TIGHT"
    return "OK"


def blocks(text: str):
    pos = 0
    while True:
        m = OPEN.search(text, pos)
        if not m:
            return
        end = CLOSE.search(text, m.end())
        if not end:
            yield m.group("id"), int(m.group("limit")), None
            return
        yield m.group("id"), int(m.group("limit")), text[m.end():end.start()]
        pos = end.end()


def report(text: str) -> int:
    found = 0
    over = 0
    for ident, limit, body in blocks(text):
        found += 1
        if body is None:
            print(f"{ident:<8} UNCLOSED block — no <!-- /ptf --> after the opener")
            over += 1
            continue
        words, worst = count_words(body)
        verdict = status(words, worst, limit)
        if verdict == "OVER":
            over += 1
        print(f"{ident:<8} {words:>3}/{limit:<3} worst={worst:<3} {verdict}")
    if found == 0:
        print("no <!-- ptf: … --> block found — that is a finding, not a pass")
        return 1
    print(f"{found} blocks, {over} OVER")
    return 1 if over else 0


SAMPLE = """
<!-- ptf: A limit=10 -->
Ein **Paket** für `Puls` und Atem.
<!-- /ptf -->
<!-- ptf: B limit=9 -->
1. OSC/ADM-OSC und sACN — drei Worte mehr.
2. Zweiter Punkt.
<!-- /ptf -->
<!-- ptf: C limit=5 -->
eins zwei drei vier fünf sechs
<!-- /ptf -->
"""


def selftest() -> int:
    rows = list(blocks(SAMPLE))
    assert [r[0] for r in rows] == ["A", "B", "C"], rows
    a_words, a_worst = count_words(rows[0][2])
    assert (a_words, a_worst) == (6, 6), (a_words, a_worst)
    b_words, b_worst = count_words(rows[1][2])
    # "OSC/ADM-OSC und sACN — drei Worte mehr." + "Zweiter Punkt." → 9 tokens, worst 10
    assert (b_words, b_worst) == (9, 10), (b_words, b_worst)
    assert status(b_words, b_worst, 9) == "OVER", "worst-case split must count (9 words fit, 10 do not)"
    c_words, _ = count_words(rows[2][2])
    assert c_words == 6 and status(c_words, c_words, 5) == "OVER"
    assert status(27, 27, 30) == "OK" and status(28, 28, 30) == "TIGHT"
    assert status(27, 30, 30) == "TIGHT", "a worst case at the limit has no margin"
    assert status(60, 60, 60) == "TIGHT" and status(53, 60, 60) == "TIGHT"
    assert status(92, 92, 100) == "OK" and status(93, 93, 100) == "TIGHT"
    assert status(161, 161, 175) == "OK" and status(162, 162, 175) == "TIGHT"
    unclosed = list(blocks("<!-- ptf: X limit=3 --> text without end"))
    assert unclosed[0][2] is None
    print("selftest OK")
    return 0


def main(argv: list[str]) -> int:
    if "--selftest" in argv:
        return selftest()
    path = Path(argv[1]) if len(argv) > 1 else Path(DEFAULT)
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"cannot read {path}: {exc}")
        return 2
    return report(text)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
