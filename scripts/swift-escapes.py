#!/usr/bin/env python3
"""Invalid escape sequences in Swift string literals — the one compile error a
transcription cannot see.

WHY THIS EXISTS (#1280). This repo has no Swift toolchain in a web session, so every
guard is graded by re-implementing its logic in Python (`Tests/CISmoke/CLAUDE.md` §0).
That grades the needle's CONTENT. It says nothing about the Swift that CARRIES it.
#1275 wrote a key path — `subcategories.flatMap(\\.genres)` — inside a plain `"…"`
literal, where `\\.` is not a valid escape. Four checkers, a full Python
transcription and a mutant run all passed it; `Build for Testing` then failed and
`Tests/CISmoke` did not compile for THREE commits, so none of those guards ran.

This is deliberately ONE error class, not a Swift parser. It is the class that (a)
reads as ordinary text to every tool we have, (b) is mechanically decidable without
a type checker, and (c) has actually cost this repo a CI round trip.

    python3 scripts/swift-escapes.py            # 0 = clean · 1 = a literal will not compile
    python3 scripts/swift-escapes.py --selftest # after touching it

⚠️ BOTH FALSE-ALARM CLASSES ARE LEGAL SWIFT AND BOTH LOOK EXACTLY LIKE THE DEFECT.
They are recorded because the first two drafts shipped them, and a checker with false
alarms is a checker nobody reads (#665):

  1. `\\` before a newline is the LINE CONTINUATION of a `\"\"\"` literal, which nearly
     every failure message in the blocking bundle uses. Draft 1 printed 1.3 MB of them.
  2. `\\.` inside a `\\( … )` INTERPOLATION is a key path in CODE, not an escape —
     `\\(list.map(\\.rawValue))` is the house idiom. Draft 2 printed 28 of them, and
     every one was correct Swift.

Neither announces itself: both drafts were "clean" in the sense of running, and only
reading the output disproved them (`.claude/rules/context.md` §2 — a parser that
matches the wrong thing fails in whichever direction you are not looking).

VALIDATED AGAINST A KNOWN POSITIVE, per §4: it reports exactly 1 finding on the tree
that carried the #1275 defect and 0 on the tree that repaired it, over ~900 files.

LIMITS, stated rather than discovered later:
  · It reads `//`, `/* */`, `"…"`, `\"\"\"…\"\"\"` and raw `#\"…\"#` (any hash count). It is a
    LEXER, not a parser — it does not know types, scopes or conditional compilation.
  · It checks ONE rule: the character after a backslash. Every other compile error in a
    literal (an unterminated string, a bad `\\u{}` body) is out of scope and will pass.
  · A clean run means no literal carries an invalid escape. It is NOT evidence that the
    bundle compiles — only `Build for Testing` is that (`Tests/CISmoke/CLAUDE.md` §5).
"""

import glob
import sys

# \0 \\ \t \n \r \" \' \u{…}, plus \( which opens an interpolation.
VALID = set('0\\tnr"\'u(')


def findings(text):
    """(line, context) for every invalid escape in a string literal of `text`.

    Pure, so the selftest drives THIS rather than the file walk — the #914/#941 lesson
    this repo has paid for twice is that what bites is the composition, and the file
    walk is the part with nothing to get wrong.
    """
    out, i, n = [], 0, len(text)
    while i < n:
        char = text[i]
        if char == "/" and text[i + 1:i + 2] == "/":
            nl = text.find("\n", i)
            i = n if nl < 0 else nl
            continue
        if char == "/" and text[i + 1:i + 2] == "*":
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        # A run of `#` immediately followed by a quote opens a RAW literal: no escapes at
        # all inside it, so `#"…\\.genres…"#` is exactly how the #1275 defect is repaired.
        # `#if`, `#filePath` and `#available` must stay ordinary code — hence the quote test.
        if char == "#":
            k = i
            while k < n and text[k] == "#":
                k += 1
            if text[k:k + 1] == '"':
                hashes = k - i
                quote = '"""' if text[k:k + 3] == '"""' else '"'
                closer = quote + "#" * hashes
                end = text.find(closer, k + len(quote))
                i = n if end < 0 else end + len(closer)
                continue
            i = k
            continue
        if char == '"':
            triple = text[i:i + 3] == '"""'
            quote = '"""' if triple else '"'
            i += len(quote)
            while i < n:
                if text[i] == "\\":
                    nxt = text[i + 1:i + 2]
                    if triple and nxt in "\n\r":
                        i += 2                      # line continuation (false-alarm class 1)
                        continue
                    if nxt == "(":
                        i = _skip_interpolation(text, i + 2)   # (false-alarm class 2)
                        continue
                    if nxt not in VALID:
                        line = text[:i].count("\n") + 1
                        out.append((line, text[max(0, i - 30):i + 20].replace("\n", "\\n")))
                    i += 2
                    continue
                if text[i:i + len(quote)] == quote:
                    i += len(quote)
                    break
                i += 1
            continue
        i += 1
    return out


def _skip_interpolation(text, start):
    """Index just past the `)` closing an interpolation opened at `start`.

    Counts nested parens and steps over nested string literals, because
    `\\(a.map { $0.name(\"x)\") })` is writable and a naive `find(\")\")` stops inside it.
    """
    depth, i, n = 1, start, len(text)
    while i < n and depth:
        char = text[i]
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == '"':
            i += 1
            while i < n and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
        i += 1
    return i


def selftest():
    ok = True
    cases = [
        # (label, source, expected finding count)
        ("the #1275 defect", 'let a = ["flatMap(\\.genres)"]', 1),
        ("raw string repairs it", 'let a = [#"flatMap(\\.genres)"#]', 0),
        ("multi-hash raw", 'let a = ##"flatMap(\\.genres)"##', 0),
        ("line continuation in a \"\"\" message", 'let m = """\n  a long line \\\n  and more\n  """', 0),
        ("key path inside an interpolation", 'let m = "got \\(list.map(\\.rawValue))"', 0),
        ("nested parens in an interpolation", 'let m = "\\(f(g(\\.x)))"', 0),
        ("a literal inside an interpolation", 'let m = "\\(f("a)b"))"', 0),
        ("ordinary escapes", 'let m = "a\\tb\\nc\\"d\\\\e\\u{1F600}"', 0),
        ("the defect inside a \"\"\" literal", 'let m = """\n  flatMap(\\.genres)\n  """', 1),
        ("#if is code, not a literal", '#if os(iOS)\nlet m = "flatMap(\\.genres)"\n#endif', 1),
        ("#filePath is code", 'let p = #filePath\nlet m = "\\.x"', 1),
        ("a comment may say anything", '// flatMap(\\.genres)\nlet m = "ok"', 0),
        ("a block comment may too", '/* \\.genres */\nlet m = "ok"', 0),
    ]
    for label, source, expected in cases:
        got = len(findings(source))
        if got != expected:
            print(f"selftest: {label!r} gave {got} finding(s), expected {expected}. "
                  f"Source: {source!r}", file=sys.stderr)
            ok = False
    # ⭐ THE COMPOSITION CASE, not a piecewise one: the two false-alarm classes and the real
    # defect IN ONE CHUNK. Drafts 1 and 2 each handled their own class and still mis-read a
    # file that mixes them, which is what every guard in this repo actually looks like.
    mixed = ('let m = """\n'
             '    listed \\(all.map(\\.rawValue)) and \\\n'
             '    also flatMap(\\.genres) here\n'
             '    """')
    hits = findings(mixed)
    if len(hits) != 1:
        print(f"selftest: the mixed chunk gave {len(hits)} finding(s), expected exactly 1 — "
              "the real defect, with the continuation and the interpolated key path beside "
              "it. Handling each class alone is what drafts 1 and 2 did (#1280).",
              file=sys.stderr)
        ok = False
    print("swift-escapes --selftest:", "OK" if ok else "FAILED")
    return 0 if ok else 1


def main():
    bad = []
    for path in sorted(glob.glob("Sources/**/*.swift", recursive=True)
                       + glob.glob("Tests/**/*.swift", recursive=True)):
        try:
            text = open(path, encoding="utf-8").read()
        except OSError:
            continue
        for line, context in findings(text):
            bad.append(f"{path}:{line}  …{context}…")
    if not bad:
        print("swift-escapes: OK — no literal carries an invalid escape sequence.")
        print("  NOT evidence that the bundle compiles — only `Build for Testing` is that.")
        return 0
    print(f"swift-escapes: {len(bad)} invalid escape sequence(s) — these do NOT compile:")
    for row in bad:
        print("  " + row)
    print("\n`\\.` is a KEY PATH, legal in code and not an escape in a string. Use a raw "
          "literal (#\"…\\.x…\"#) when the text is the point, or `\\\\.` to mean a backslash.")
    return 1


if __name__ == "__main__":
    sys.exit(selftest() if "--selftest" in sys.argv else main())
