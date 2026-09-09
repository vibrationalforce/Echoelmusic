#!/usr/bin/env python3
"""Guards that read a NON-Swift repo file: is the needle still true there?

WHY THIS EXISTS (#1191). `scripts/moved-needles.py` says so in its own output: it diffs
`-- Sources` ONLY (#1182). `scripts/dead-needles.py` is narrower still — every one of its shapes is
gated on the guard file naming ONLY `Sources/` paths, deliberately, because that gate is what
keeps its false-alarm rate at zero. So a guard that asserts a literal against `CLAUDE.md`,
`project.yml`, `docs/*.html`, `ContentPipeline/CLAIMS.md`, `decisions.csv`, `fastlane/…` or
`Resources/iOS/Info.plist` was covered by NOTHING.

That is not hypothetical. #1190 moved provenance out of `CLAUDE.md` and, in its first form,
merged two sentences into one:

    "Harmonizer auf seiner Stimme SCHALTBAR seit #841"  +  "Granular … seit #849"
        →  "Harmonizer (#841) und Granular (#849) liegen SCHALTBAR auf seiner Stimme"

Identical in meaning, and it cut BOTH needles of
`TheVocalChainStopsAtTheAutotuneTests` claim 5. All four rot-checkers ran and all four exited
0. A hand sweep found it. This script is that hand sweep, made repeatable.

⚠️ AND THE HAND SWEEP WAS ITSELF WRONG TWICE ON ITS FIRST RUN, both in the harmless
direction — it reported two findings that were not real:
  · it ignored POLARITY: `XCTAssertFalse(claude.contains("snapshot (10 Hz poll)"))` demands
    ABSENCE, and the retracted wording is absent on purpose.
  · it ran `unicode_escape` over UTF-8 source, so "löst" became mojibake and matched nothing.
With the signs reversed either bug would have waved a real break through in silence. Both are
why this file decodes needles through `dead-needles.decode_needle` (which SKIPS anything it
cannot decode) rather than rolling its own, and why polarity is carried explicitly.

WHAT IT CHECKS. In every `Tests/CISmoke/*.swift`:
  1. bindings of a repo file that is NOT under `Sources/` and does NOT end in `.swift`
     — `let X = try loader("PATH")`, the `appendingPathComponent("PATH")` form, and the
       `static let name = "PATH"` indirection;
  2. `XCTAssertTrue/False( [!] X.contains("NEEDLE") )` against that binding;
  3. whether NEEDLE's presence in the file on disk matches the polarity asserted.

QUIETER, NEVER LOUDER — the three deliberate blind spots, stated rather than hidden:
  · a needle carrying an escape this scan cannot decode is SKIPPED (shared decode);
  · a file that is not on disk is SKIPPED (the guard skips too);
  · when the file is read through a COMMENT-STRIPPING helper (one whose body calls
    `SourceText.codeOnly(`), an ABSENCE assertion whose needle IS in the raw file is SKIPPED —
    stripping could legitimately have removed it. The reverse direction stays reportable:
    stripping only ever REMOVES, so a needle missing from the raw file is missing from the
    stripped read as well.

⛔ WHY `dead-needles.stripping_helpers` IS *NOT* REUSED FOR THAT LAST CHECK, although reusing
it was the first thing tried and it cost a red self-test. Its helper regex is an allowlist of
five names — `codeText|read|body|rawSource|source` — which is exactly right for its own
`Sources/`-only charter and blind to every loader this script actually meets (`text`,
`rawFile`, `file`, `codeLines`, `routineText`, `byteCount`). A stripping `text()` would have
gone undetected, and the failure would have been a FALSE ALARM: an absence finding that
stripping explains. So the detection here is name-agnostic — any `func NAME(` whose
comment-blanked body calls `SourceText.codeOnly(` — while `decode_needle` and `strip_comments`
ARE reused, because those two ask the same question in both files.
⚠️ Gated stripping (`flag ? SourceText.codeOnly(x) : x`, #1167) is treated as "may strip"
without resolving the flag. That is deliberately coarse in the SAFE direction: it can only add
a skip, never a finding.

⚠️ IT SCANS `Tests/CISmoke/` ONLY, AND THAT IS MEASURED RATHER THAN ASSUMED. The
non-blocking suite is the obvious second place to look, and today it has nothing to find:

    grep -rlP 'try\s+\w+\("(?!Sources/)[^"]+\.(md|html|yml|yaml|txt|json|csv|plist)"\)|appendingPathComponent\("(?!Sources/)[^"]+\.(md|html|yml|yaml|txt|json|csv|plist)"\)' Tests/EchoelmusicTests/*.swift | wc -l

returns 0 across all of `Tests/EchoelmusicTests/`. The number of files there is a date, not a
fact (`git ls-files 'Tests/EchoelmusicTests/*.swift' | wc -l`); the ZERO is the point. If a
guard there ever binds a foreign file, widen `scan`'s `guard_dir` — the rest of this script
does not care which directory it walked. Deliberate scope, re-derivable, not an oversight.

A RUN THAT EXTRACTS ZERO NEEDLES EXITS 2, NOT 0. `.claude/rules/context.md` §2: a parser that
matches nothing is a finding, never a pass. That is how the first hand sweep would have failed
silently if its regex had been one character wrong.
"""

import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def _load_dead_needles():
    """Reuse the sibling's decode + strip-detection instead of writing a second pair."""
    path = os.path.join(HERE, "dead-needles.py")
    spec = importlib.util.spec_from_file_location("_dead_needles", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_DN = _load_dead_needles()
decode_needle = _DN.decode_needle
strip_comments = _DN.strip_comments

# Name-agnostic on purpose — see the ⛔ block in this file's docstring.
ANY_FUNC = re.compile(r'\bfunc\s+(\w+)\s*\(')


def stripping_loaders(code):
    """Names of helpers in THIS guard file whose body may return comment-stripped text.

    Brace-matched, not line-windowed: this repo writes 30-40-line doc blocks above a helper,
    so any fixed window is unsound by construction (`Tests/CISmoke/CLAUDE.md` §2).
    The body is comment-blanked FIRST, so a doc comment that merely NAMES `SourceText.codeOnly(`
    does not qualify its function — the #1169 defect, in the home it would land in next.
    """
    names = set()
    for match in ANY_FUNC.finditer(code):
        opening = code.find("{", match.end())
        if opening < 0:
            continue
        depth, i = 0, opening
        while i < len(code):
            if code[i] == "{":
                depth += 1
            elif code[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        if "SourceText.codeOnly(" in strip_comments(code[opening:i]):
            names.add(match.group(1))
    return names

# `let name = try loader("path")` — the loader may be any helper the guard file defines.
BIND_LOADER = re.compile(r'let\s+(\w+)\s*=\s*try\s+(\w+)\(\s*"([^"\\]+)"\s*\)')
# `let name = try String(contentsOf: <anything>.appendingPathComponent("path")…)`
BIND_APPEND = re.compile(
    r'let\s+(\w+)\s*=\s*try\s+String\(\s*contentsOf:[^)]*?appendingPathComponent\(\s*"([^"\\]+)"\s*\)')
# `static let lawFile = "CLAUDE.md"` then `let name = try loader(Self.lawFile)`
BIND_CONST_DECL = re.compile(r'static\s+let\s+(\w+)\s*(?::\s*String\s*)?=\s*"([^"\\]+)"')
BIND_CONST_USE = re.compile(r'let\s+(\w+)\s*=\s*try\s+(\w+)\(\s*(?:Self\.)?(\w+)\s*\)')


def assertion_pattern(var):
    return re.compile(
        r'XCTAssert(True|False)\(\s*(!\s*)?' + re.escape(var) + r'\.contains\(\s*"((?:[^"\\]|\\.)*)"\s*\)')


def is_foreign(path):
    """A repo file this script owns: not Swift source, not under `Sources/`."""
    if path.endswith(".swift"):
        return False
    if path.startswith("Sources/"):
        return False
    return "." in os.path.basename(path)


def bindings(code):
    """{var: (relative path, loader name or None)} for foreign files read in this guard."""
    consts = {name: value for name, value in BIND_CONST_DECL.findall(code)}
    found = {}
    for var, loader, path in BIND_LOADER.findall(code):
        if is_foreign(path):
            found[var] = (path, loader)
    for var, path in BIND_APPEND.findall(code):
        if is_foreign(path):
            found[var] = (path, None)          # read verbatim: `String(contentsOf:)`
    for var, loader, const in BIND_CONST_USE.findall(code):
        path = consts.get(const)
        if path and is_foreign(path):
            found.setdefault(var, (path, loader))
    return found


def scan(repo_root, guard_dir=None):
    guard_dir = guard_dir or os.path.join(repo_root, "Tests", "CISmoke")
    stats = {"files": 0, "bindings": 0, "checked": 0,
             "skip_escape": 0, "skip_missing": 0, "skip_stripped": 0}
    findings = []
    cache = {}

    if not os.path.isdir(guard_dir):
        return findings, stats

    for name in sorted(os.listdir(guard_dir)):
        if not name.endswith(".swift"):
            continue
        with open(os.path.join(guard_dir, name), encoding="utf-8") as handle:
            raw = handle.read()
        # ⛔ THE GUARD'S OWN COMMENTS MUST GO FIRST — found by the tool's first real run
        # (#1191). `TheNeedleCheckerNamesBothErrorDirectionsTests` RETRACTED an assertion and
        # kept it quoted in a `//` block explaining why (the #491 trap, recorded on purpose).
        # Read raw, that retracted line parses as live and the tool reports a needle nobody
        # asserts — a FALSE ALARM, which is how a checker stops being read (#665). Sibling
        # `dead-needles.py` strips the file it SEARCHES for the same reason; the assertion side
        # needed it too. #456: the repair goes in every home.
        code = strip_comments(raw)
        bound = bindings(code)
        if not bound:
            continue
        strippers = stripping_loaders(raw)
        stats["files"] += 1
        stats["bindings"] += len(bound)
        for var, (path, loader) in sorted(bound.items()):
            if path not in cache:
                full = os.path.join(repo_root, path)
                try:
                    with open(full, encoding="utf-8") as handle:
                        cache[path] = handle.read()
                except OSError:
                    cache[path] = None
            text = cache[path]
            strips = loader in strippers if loader else False
            for polarity, negated, literal in assertion_pattern(var).findall(code):
                needle = decode_needle(literal)
                if needle is None:
                    stats["skip_escape"] += 1
                    continue
                if text is None:
                    stats["skip_missing"] += 1
                    continue
                want_present = (polarity == "True") != bool(negated)
                present = needle in text
                if present == want_present:
                    stats["checked"] += 1
                    continue
                if present and not want_present and strips:
                    stats["skip_stripped"] += 1     # the loader may have removed it
                    continue
                stats["checked"] += 1
                findings.append((name, path, want_present, needle))
    return findings, stats


def report(findings, stats):
    print("FOREIGN NEEDLES — guards asserting literals against non-Swift repo files")
    print(f"  guard files with such a binding: {stats['files']}"
          f" · bindings: {stats['bindings']} · needles checked: {stats['checked']}")
    print(f"  skipped — undecodable escape {stats['skip_escape']}"
          f" · file not on disk {stats['skip_missing']}"
          f" · absence unprovable through a stripping loader {stats['skip_stripped']}")
    if not findings:
        print("  no broken needle.")
        print("  Not a proof that every guard is right — it proves only that each literal this")
        print("  scan could read is on the side of its file that its assertion demands.")
        return
    print()
    for guard, path, want_present, needle in findings:
        demand = "must be PRESENT in" if want_present else "must be ABSENT from"
        print(f"  {guard}")
        print(f"    {demand} {path}")
        print(f"    needle: {needle[:100]}")
    print()
    print(f"  {len(findings)} broken needle(s). REPAIR THE PROSE OR THE GUARD — and decide which")
    print("  carries the law. In #1190 the needle WAS the law, so the prose moved back (#364).")


def selftest():
    """Drive both polarities, the stripping blind spot, and the vacuous-pass exit."""
    import tempfile

    def build(root, prose, guard):
        os.makedirs(os.path.join(root, "Tests", "CISmoke"))
        with open(os.path.join(root, "NOTES.md"), "w", encoding="utf-8") as handle:
            handle.write(prose)
        with open(os.path.join(root, "Tests", "CISmoke", "XTests.swift"), "w",
                  encoding="utf-8") as handle:
            handle.write(guard)

    plain = ('final class XTests: XCTestCase {\n'
             '    func testA() throws {\n'
             '        let law = try rawFile("NOTES.md")\n'
             '        XCTAssertTrue(law.contains("KEPT PHRASE"), "gone")\n'
             '        XCTAssertFalse(law.contains("RETRACTED PHRASE"), "back")\n'
             '    }\n'
             '    private func rawFile(_ p: String) throws -> String { "" }\n'
             '}\n')

    # 1. correct tree — both polarities satisfied, and the reach is non-zero.
    with tempfile.TemporaryDirectory() as root:
        build(root, "a KEPT PHRASE here\n", plain)
        findings, stats = scan(root)
        assert findings == [], findings
        assert stats["checked"] == 2, stats
    # 2. the #1190 break — the present-needle disappears from the prose.
    with tempfile.TemporaryDirectory() as root:
        build(root, "the phrase was reworded\n", plain)
        findings, _ = scan(root)
        assert len(findings) == 1 and findings[0][2] is True, findings
    # 3. the opposite polarity — a retracted phrase creeps back in.
    with tempfile.TemporaryDirectory() as root:
        build(root, "a KEPT PHRASE and a RETRACTED PHRASE\n", plain)
        findings, _ = scan(root)
        assert len(findings) == 1 and findings[0][2] is False, findings
    # 4. the stripping blind spot: same tree as 3, but the loader strips comments, so the
    #    ABSENCE finding must be withheld while the PRESENCE check still runs.
    stripped = plain.replace(
        'private func rawFile(_ p: String) throws -> String { "" }',
        'private func rawFile(_ p: String) throws -> String { SourceText.codeOnly(p) }')
    with tempfile.TemporaryDirectory() as root:
        build(root, "a KEPT PHRASE and a RETRACTED PHRASE\n", stripped)
        findings, stats = scan(root)
        assert findings == [], findings
        assert stats["skip_stripped"] == 1, stats
    #    …and the presence half of that same loader is NOT withheld.
    with tempfile.TemporaryDirectory() as root:
        build(root, "nothing of the sort\n", stripped)
        findings, _ = scan(root)
        assert len(findings) == 1 and findings[0][2] is True, findings
    # 5. a Swift path under Sources/ is NOT this script's territory (dead-needles owns it).
    assert not is_foreign("Sources/Echoelmusic/Audio/AudioEngine.swift")
    assert not is_foreign("Tests/CISmoke/XTests.swift")
    assert is_foreign("CLAUDE.md") and is_foreign("docs/faq.html")
    assert is_foreign("Tests/CISmoke/CLAUDE.md")
    # 6. an undecodable needle is skipped, never guessed at.
    assert decode_needle('a\\nb') is None
    # 6b. a RETRACTED assertion, kept as a `//` quotation, is not an assertion. This is the
    #     tool's own first real finding turned into a claim: without it the checker reports a
    #     needle nobody asserts, and a checker with false alarms is a checker nobody runs.
    commented = plain.replace(
        '        XCTAssertFalse(law.contains("RETRACTED PHRASE"), "back")',
        '        // was: XCTAssertFalse(law.contains("RETRACTED PHRASE"), "back") — withdrawn')
    with tempfile.TemporaryDirectory() as root:
        build(root, "a KEPT PHRASE and a RETRACTED PHRASE\n", commented)
        findings, stats = scan(root)
        assert findings == [], findings
        assert stats["checked"] == 1, stats
    # 7. the vacuous-pass guard: an empty tree yields zero needles, which main() calls a
    #    finding. Without this the whole script could rot into a green that means nothing.
    with tempfile.TemporaryDirectory() as root:
        _, stats = scan(root)
        assert stats["checked"] == 0, stats
    print("foreign-needles --selftest: 8 claims OK")
    return 0


def main(repo_root):
    findings, stats = scan(repo_root)
    report(findings, stats)
    if stats["checked"] == 0:
        print()
        print("  INSTRUMENT UNAVAILABLE — zero needles extracted. That is a finding, not a pass:")
        print("  either the loader shapes moved or this scan's regexes stopped matching.")
        return 2
    return 1 if findings else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv[1:]:
        sys.exit(selftest())
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    sys.exit(main(args[0] if args else "."))
