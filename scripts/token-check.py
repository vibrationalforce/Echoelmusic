#!/usr/bin/env python3
"""token-check.py — is the website still written in the app's tokens?

Python 3 standard library only, read-only, no compiler, no network. Run it after any change to a
colour, a radius, a spacing, a motion time or a font on the website or in EchoelBrand.swift.

THE ONE SOURCE
    EchoelStudio/Plugins/Shared/EchoelBrand.swift
        the app reads it through `Theme` (App/Design/Theme.swift), the Audio Unit window directly.

THE COPIES THIS CHECK HOLDS AGAINST IT
    1. docs/shared.css                       the top-level `:root` block
    2. every docs/*.html                     an inline `:root` (index.html and one-clock.html load
                                             no shared.css, so theirs is a second and third copy),
                                             and the `:root` overrides inside @media, twin by twin
    3. EchoelStudio/App/Assets.xcassets      AccentColor.colorset = accent, LaunchBackground = background
    4. docs/manifest.json and <meta name="theme-color">   = background
    5. docs/*.svg                            the mark is drawn in the text grey on the ground
    6. the two font faces                    App/Design/Fonts/<Face>.ttf and the woff2 the CSS names
    7. App/Design/Theme.swift                a shared token is a REFERENCE to EchoelBrand, never a
                                             second literal

WHAT IT DOES NOT SEE (say so rather than imply it)
    - font SIZES: the site writes px, the app text styles; there is no mapping to hold.
    - whether a .ttf and a .woff2 carry the same glyphs (it checks names and presence only).
    - the app icon PNG (a picture; measured by hand in the report, not here).
    - colours a page computes in JavaScript.

EXIT   0  every copy equals the source
       1  at least one DRIFT
       2  the check could not read what it names — a parser that matches nothing is a finding,
          never a pass (the positive controls below)

USAGE  python3 scripts/token-check.py [--repo PATH] [--strict] [--quiet] [--selftest]
       --strict   a one-step rounding difference (NOTE) also fails
"""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys

SOURCE = "EchoelStudio/Plugins/Shared/EchoelBrand.swift"
THEME = "EchoelStudio/App/Design/Theme.swift"
CSS = "docs/shared.css"
ASSETS = "EchoelStudio/App/Assets.xcassets"
APP_FONTS = "EchoelStudio/App/Design/Fonts"

# token in EchoelBrand -> custom property on the website
COLOR_MAP = [
    ("background", "--bg"),
    ("text", "--text"),
    ("textSecondary", "--dim"),
    ("textTertiary", "--dim-tertiary"),
    ("surface", "--surface"),
    ("surfaceRaised", "--surface-raised"),
    ("border", "--border"),
    ("borderStrong", "--border-strong"),
    ("accent", "--accent"),
    ("onAccent", "--on-accent"),
    ("record", "--record"),
    ("warning", "--warning"),
]
RADIUS_MAP = [("small", "--radius-s"), ("medium", "--radius-m"), ("large", "--radius-l")]
MOTION_MAP = [("quick", "--motion-quick"), ("standard", "--motion-standard")]
# How many tokens the source must yield before anything else is believed (positive control).
MIN_COLORS, MIN_RADII, MIN_MOTION, MIN_FACES = 12, 3, 2, 2


# ----------------------------------------------------------------------------- reading Swift

def blank_swift_comments(text: str) -> str:
    """Comments become spaces (newlines kept), so offsets and line numbers stay true."""
    out, i, n = [], 0, len(text)
    in_string = False
    while i < n:
        ch = text[i]
        if in_string:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1]); i += 2; continue
            if ch == '"':
                in_string = False
            i += 1
        elif ch == '"':
            in_string = True; out.append(ch); i += 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i)); i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("".join(c if c == "\n" else " " for c in text[i:j])); i = j
        else:
            out.append(ch); i += 1
    return "".join(out)


def enum_body(text: str, name: str) -> tuple[str, int] | None:
    """The text between the braces of `enum <name> {`, and its offset."""
    m = re.search(r"\benum\s+%s\b[^{]*\{" % re.escape(name), text)
    if not m:
        return None
    depth, i = 1, m.end()
    while i < len(text) and depth:
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        i += 1
    return text[m.end():i - 1], m.end()


def line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


NUM = r"([0-9]*\.?[0-9]+)"


def read_source(text: str) -> dict:
    """{'colors': {name: (r, g, b, a, line)}, 'radii': {...}, 'motion': {name: (ms, line)}, 'faces': [...]}"""
    clean = blank_swift_comments(text)
    found: dict = {"colors": {}, "radii": {}, "space": {}, "motion": {}, "faces": []}

    block = enum_body(clean, "Color")
    if block:
        body, base = block
        raw: dict[str, tuple] = {}
        for m in re.finditer(r"static\s+let\s+(\w+)\s*=\s*([^\n]+)", body):
            raw[m.group(1)] = (m.group(2).strip(), line_of(clean, base + m.start()))

        def resolve(name: str, seen: tuple = ()) -> tuple | None:
            if name not in raw or name in seen:
                return None
            expr, line = raw[name]
            m = re.match(r"(?:SwiftUI\.)?Color\(\s*red:\s*%s\s*,\s*green:\s*%s\s*,\s*blue:\s*%s\s*\)$" % (NUM, NUM, NUM), expr)
            if m:
                return (float(m.group(1)), float(m.group(2)), float(m.group(3)), 1.0, line)
            m = re.match(r"(?:SwiftUI\.)?Color\(\s*white:\s*%s\s*\)$" % NUM, expr)
            if m:
                w = float(m.group(1)); return (w, w, w, 1.0, line)
            if re.match(r"(?:SwiftUI\.)?Color\.black$", expr):
                return (0.0, 0.0, 0.0, 1.0, line)
            if re.match(r"(?:SwiftUI\.)?Color\.white$", expr):
                return (1.0, 1.0, 1.0, 1.0, line)
            m = re.match(r"(\w+)\.opacity\(\s*%s\s*\)$" % NUM, expr)
            if m:
                base_color = resolve(m.group(1), seen + (name,))
                return None if base_color is None else (*base_color[:3], float(m.group(2)), line)
            m = re.match(r"(\w+)$", expr)
            if m:
                base_color = resolve(m.group(1), seen + (name,))
                return None if base_color is None else (*base_color[:4], line)
            return None

        for name in raw:
            value = resolve(name)
            if value is not None:
                found["colors"][name] = value

    for key, enum in (("radii", "Radius"), ("space", "Space")):
        block = enum_body(clean, enum)
        if block:
            body, base = block
            for m in re.finditer(r"static\s+let\s+(\w+)\s*:\s*CGFloat\s*=\s*%s" % NUM, body):
                found[key][m.group(1)] = (float(m.group(2)), line_of(clean, base + m.start()))

    block = enum_body(clean, "Motion")
    if block:
        body, base = block
        for m in re.finditer(r"static\s+var\s+(\w+)\s*:\s*Animation\s*\{[^}]*duration:\s*%s" % NUM, body):
            found["motion"][m.group(1)] = (round(float(m.group(2)) * 1000), line_of(clean, base + m.start()))

    for m in re.finditer(r'case\s+(\w+)\s*=\s*"([A-Za-z]+-[A-Za-z]+)"', clean):
        found["faces"].append((m.group(1), m.group(2), line_of(clean, m.start())))
    return found


# ----------------------------------------------------------------------------- reading CSS

def blank_css_comments(text: str) -> str:
    return re.sub(r"/\*.*?\*/", lambda m: "".join(c if c == "\n" else " " for c in m.group(0)), text, flags=re.S)


def root_blocks(css: str, line_base: int = 0) -> list[dict]:
    """Every `:root { … }` with the at-rules around it: [{'media': '', 'vars': {name: (value, line)}}]."""
    css = blank_css_comments(css)
    blocks, stack, start = [], [], 0
    i, n = 0, len(css)
    while i < n:
        ch = css[i]
        if ch == "{":
            prelude = " ".join(css[start:i].split())
            stack.append((prelude, i + 1))
            start = i + 1
        elif ch == "}":
            if stack:
                prelude, body_start = stack.pop()
                if prelude == ":root":
                    media = " | ".join(p for p, _ in stack)
                    body = css[body_start:i]
                    declared = {}
                    for m in re.finditer(r"(--[a-z0-9-]+)\s*:\s*([^;}]+)", body):
                        declared[m.group(1)] = (" ".join(m.group(2).split()),
                                                line_base + line_of(css, body_start + m.start()))
                    blocks.append({"media": media, "vars": declared})
            start = i + 1
        elif ch == ";":
            start = i + 1
        i += 1
    return blocks


def styles_of(html: str) -> list[tuple[str, int]]:
    """The contents of every <style> element, each with the line it starts on (minus one)."""
    return [(m.group(1), html.count("\n", 0, m.start(1)))
            for m in re.finditer(r"<style[^>]*>(.*?)</style>", html, flags=re.S | re.I)]


def css_color(value: str) -> tuple | None:
    """(r, g, b, a) with channels 0…255 and alpha 0…1; None for anything that is not a colour."""
    v = value.strip().lower()
    m = re.fullmatch(r"#([0-9a-f]{3})", v)
    if m:
        return (*[int(c * 2, 16) for c in m.group(1)], 1.0)
    m = re.fullmatch(r"#([0-9a-f]{6})", v)
    if m:
        h = m.group(1)
        return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 1.0)
    m = re.fullmatch(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*%s\s*)?\)" % NUM, v)
    if m:
        return (int(m.group(1)), int(m.group(2)), int(m.group(3)), float(m.group(4)) if m.group(4) else 1.0)
    return None


def spell(color: tuple) -> str:
    """A source colour the way the site would write it."""
    r, g, b = (math.floor(c * 255 + 0.5) for c in color[:3])
    a = color[3]
    return "#%02x%02x%02x" % (r, g, b) if a >= 0.9995 else "rgba(%d,%d,%d,%.2f)" % (r, g, b, a)


def compare_color(source: tuple, value: str) -> tuple[str, str]:
    """('ok' | 'note' | 'drift', why)."""
    got = css_color(value)
    if got is None:
        return "drift", "is not a colour this check can read"
    if abs(got[3] - source[3]) > 0.005:
        return "drift", "alpha %.2f, the token has %.2f" % (got[3], source[3])
    exact = [c * 255 for c in source[:3]]
    if all(math.floor(e + 0.5) == g for e, g in zip(exact, got[:3])):
        return "ok", ""
    if all(abs(e - g) < 1.0 for e, g in zip(exact, got[:3])):
        return "note", "one rounding step off (the token is %s to the nearest step)" % spell(source)
    return "drift", "the token is %s" % spell(source)


# ----------------------------------------------------------------------------- the report

class Report:
    def __init__(self, quiet: bool):
        self.quiet = quiet
        self.rows: list[tuple[str, str]] = []

    def add(self, kind: str, text: str) -> None:
        self.rows.append((kind, text))
        if not (self.quiet and kind in ("ok", "info")):
            print("%-6s %s" % ({"ok": "OK", "note": "NOTE", "drift": "DRIFT", "blind": "BLIND", "info": "INFO"}[kind], text))

    def count(self, kind: str) -> int:
        return sum(1 for k, _ in self.rows if k == kind)


def read(repo: str, path: str) -> str | None:
    try:
        with open(os.path.join(repo, path), encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return None


def check_block(report: Report, where: str, declared: dict, tokens: dict, require_all: bool) -> None:
    for name, prop in COLOR_MAP:
        if prop not in declared:
            if require_all:
                report.add("drift", "%s: %s (EchoelBrand.Color.%s) is not declared" % (where, prop, name))
            continue
        value, line = declared[prop]
        if value.startswith("var("):
            report.add("info", "%s:%d %s is an alias (%s)" % (where, line, prop, value))
            continue
        kind, why = compare_color(tokens["colors"][name], value)
        report.add(kind, "%s:%d %s: %s%s" % (where, line, prop, value, "" if kind == "ok" else " — " + why))
    for group, mapping, unit in (("radii", RADIUS_MAP, "px"), ("motion", MOTION_MAP, "ms")):
        for name, prop in mapping:
            if prop not in declared:
                if require_all:
                    report.add("drift", "%s: %s is not declared" % (where, prop))
                continue
            value, line = declared[prop]
            want = "%g%s" % (tokens[group][name][0], unit)
            report.add("ok" if value == want else "drift",
                       "%s:%d %s: %s%s" % (where, line, prop, value, "" if value == want else " — the token is " + want))
    if "--font" in declared:
        value, line = declared["--font"]
        first = value.split(",")[0].strip().strip("'\"")
        family = tokens["faces"][0][1].split("-")[0]
        same = first.replace(" ", "") == family
        report.add("ok" if same else "drift",
                   "%s:%d --font leads with '%s'%s" % (where, line, first, "" if same else " — the app's face is " + family))
    elif require_all:
        report.add("drift", "%s: --font is not declared" % where)


def run(repo: str, strict: bool, quiet: bool) -> int:
    report = Report(quiet)

    # ---- the source, and the positive controls
    source_text = read(repo, SOURCE)
    if source_text is None:
        print("BLIND  cannot read %s" % SOURCE); return 2
    tokens = read_source(source_text)
    counts = (len(tokens["colors"]), len(tokens["radii"]), len(tokens["motion"]), len(tokens["faces"]))
    print("source %s: %d colours, %d radii, %d motion speeds, %d faces" % ((SOURCE,) + counts))
    missing = [n for n, _ in COLOR_MAP if n not in tokens["colors"]] \
        + [n for n, _ in RADIUS_MAP if n not in tokens["radii"]] + [n for n, _ in MOTION_MAP if n not in tokens["motion"]]
    if missing or counts[0] < MIN_COLORS or counts[1] < MIN_RADII or counts[2] < MIN_MOTION or counts[3] < MIN_FACES:
        print("BLIND  the source parser did not find: %s — re-anchor the parser before trusting anything below"
              % (", ".join(missing) or "enough tokens"))
        return 2

    # ---- 7. Theme.swift refers, it does not repeat
    theme = read(repo, THEME)
    if theme is None:
        report.add("blind", "cannot read %s" % THEME)
    else:
        clean = blank_swift_comments(theme)
        refs = 0
        for name in tokens["colors"]:
            m = re.search(r"static\s+let\s+%s\s*=\s*([^\n]+)" % re.escape(name), clean)
            if not m:
                continue
            if m.group(1).strip() == "EchoelBrand.Color.%s" % name:
                refs += 1
            else:
                report.add("drift", "%s:%d Theme.Color.%s is its own value (%s), not EchoelBrand.Color.%s"
                           % (THEME, line_of(clean, m.start()), name, m.group(1).strip(), name))
        report.add("ok" if refs else "blind", "%s: %d shared colour tokens are references to EchoelBrand" % (THEME, refs))

    # ---- 1. shared.css
    css = read(repo, CSS)
    shared_blocks: list[dict] = []
    if css is None:
        report.add("blind", "cannot read %s" % CSS)
    else:
        shared_blocks = root_blocks(css)
        top = [b for b in shared_blocks if not b["media"]]
        if not top:
            report.add("blind", "%s has no top-level :root block" % CSS)
        else:
            check_block(report, CSS, top[0]["vars"], tokens, require_all=True)
    shared_media = {b["media"]: b["vars"] for b in shared_blocks if b["media"]}

    # ---- 2. every page
    docs = os.path.join(repo, "docs")
    pages = sorted(f for f in os.listdir(docs) if f.endswith(".html")) if os.path.isdir(docs) else []
    if not pages:
        report.add("blind", "no docs/*.html found")
    linked = twins = 0
    for page in pages:
        html = read(repo, "docs/" + page) or ""
        where = "docs/" + page
        loads_shared = bool(re.search(r'<link[^>]+href="[^"]*shared\.css', html))
        linked += loads_shared
        blocks: list[dict] = []
        for body, base in styles_of(html):
            blocks += root_blocks(body, base)
        top = [b for b in blocks if not b["media"]]
        if top and not loads_shared:
            twins += 1
            report.add("info", "%s loads no shared.css and carries its own :root — a copy" % where)
        for block in top:
            check_block(report, where, block["vars"], tokens, require_all=False)
        if not loads_shared:
            declared = set().union(*[set(b["vars"]) for b in top]) if top else set()
            used = set(re.findall(r"var\((--[a-z0-9-]+)", html))
            mapped = {p for _, p in COLOR_MAP + RADIUS_MAP + MOTION_MAP} | {"--font"}
            for prop in sorted((used & mapped) - declared):
                report.add("drift", "%s uses var(%s) and declares it nowhere" % (where, prop))
            # the @media overrides of a twin, against shared.css's
            own_media = {b["media"]: b["vars"] for b in blocks if b["media"]}
            for media in sorted(set(own_media) | set(shared_media)):
                if not top:
                    continue
                mine = {k: v[0] for k, v in own_media.get(media, {}).items()}
                theirs = {k: v[0] for k, v in shared_media.get(media, {}).items()}
                if mine == theirs:
                    report.add("ok", "%s @media %s: the same overrides as shared.css" % (where, media))
                else:
                    report.add("drift", "%s `%s`: %s — shared.css: %s" % (where, media, mine or "no override", theirs or "no override"))
        # 4. theme-color
        m = re.search(r'<meta\s+name="theme-color"\s+content="([^"]+)"', html)
        if m:
            kind, why = compare_color(tokens["colors"]["background"], m.group(1))
            if kind != "ok":
                report.add(kind, "%s theme-color %s — %s" % (where, m.group(1), why))
    report.add("info", "%d pages, %d load shared.css, %d carry their own :root instead" % (len(pages), linked, twins))

    # ---- 3. asset catalog
    for asset, token in (("AccentColor.colorset", "accent"), ("LaunchBackground.colorset", "background")):
        path = "%s/%s/Contents.json" % (ASSETS, asset)
        raw = read(repo, path)
        if raw is None:
            report.add("blind", "cannot read %s" % path); continue
        colours = [c.get("color", {}).get("components") for c in json.loads(raw).get("colors", [])]
        colours = [c for c in colours if c]
        if not colours:
            report.add("blind", "%s holds no colour" % path); continue
        want = tokens["colors"][token]
        for index, comp in enumerate(colours):
            got = tuple(float(comp[k]) for k in ("red", "green", "blue"))
            same = all(abs(g - w) < 0.0005 for g, w in zip(got, want[:3]))
            report.add("ok" if same else "drift", "%s colour %d = %s%s"
                       % (path, index, got, "" if same else " — EchoelBrand.Color.%s is %s" % (token, want[:3])))

    # ---- 4. manifest
    manifest = read(repo, "docs/manifest.json")
    if manifest is None:
        report.add("blind", "cannot read docs/manifest.json")
    else:
        data = json.loads(manifest)
        for key in ("theme_color", "background_color"):
            kind, why = compare_color(tokens["colors"]["background"], str(data.get(key, "")))
            report.add(kind, "docs/manifest.json %s: %s%s" % (key, data.get(key), "" if kind == "ok" else " — " + why))

    # ---- 5. the mark
    allowed = {spell(tokens["colors"]["text"]), spell(tokens["colors"]["background"])}
    for svg in sorted(f for f in (os.listdir(docs) if os.path.isdir(docs) else []) if f.endswith(".svg")):
        text = read(repo, "docs/" + svg) or ""
        inks = set()
        for h in re.findall(r"#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b", text):
            c = css_color(h)
            if c:
                inks.add("#%02x%02x%02x" % c[:3])
        other = sorted(inks - allowed)
        report.add("ok" if not other else "info", "docs/%s inks %s%s"
                   % (svg, sorted(inks), "" if not other else " — not a token: %s" % other))

    # ---- 6. the faces
    for case, face, line in tokens["faces"]:
        path = "%s/%s.ttf" % (APP_FONTS, face)
        present = os.path.isfile(os.path.join(repo, path))
        report.add("ok" if present else "drift", "%s:%d face %s -> %s %s" % (SOURCE, line, face, path, "present" if present else "MISSING"))
    if css is not None:
        for m in re.finditer(r"@font-face\s*\{[^}]*url\('([^']+)'\)[^}]*font-weight:\s*(\d+)[^}]*font-style:\s*(\w+)", css):
            present = os.path.isfile(os.path.join(repo, "docs", m.group(1)))
            report.add("ok" if present else "drift", "%s @font-face %s %s -> docs/%s %s"
                       % (CSS, m.group(2), m.group(3), m.group(1), "present" if present else "MISSING"))

    drift, notes, blind = report.count("drift"), report.count("note"), report.count("blind")
    print("\n%d checked · %d DRIFT · %d NOTE · %d BLIND" % (len(report.rows), drift, notes, blind))
    if blind:
        return 2
    if drift or (strict and notes):
        return 1
    return 0


# ----------------------------------------------------------------------------- selftest

def selftest() -> int:
    swift = '''
    enum EchoelBrand {
        enum Color {
            /// a comment with Color(red: 9, green: 9, blue: 9)
            static let neutral = SwiftUI.Color(red: 0.878, green: 0.878, blue: 0.878)
            static let background = SwiftUI.Color.black
            static let border = neutral.opacity(0.10)
            static let text = neutral
            static let keyBlack = SwiftUI.Color(white: 0.12)
        }
        enum Radius { static let small: CGFloat = 4 }
        enum Motion { static var quick: Animation { .easeOut(duration: 0.12) } }
        enum Font { enum Face: String { case regular = "AtkinsonHyperlegible-Regular" } }
    }'''
    t = read_source(swift)
    css = "/* :root { --bg: #fff; } */ :root { --bg: #000; --border: rgba(224,224,224,0.10); }\n" \
          "@media (prefers-contrast: high) { :root { --dim: rgba(224,224,224,0.85); } }"
    blocks = root_blocks(css)
    checks = [
        ("neutral parsed", t["colors"].get("neutral", (0,))[0] == 0.878),
        ("alias resolved", t["colors"].get("text", (0,))[:4] == (0.878, 0.878, 0.878, 1.0)),
        ("opacity resolved", t["colors"].get("border", (0, 0, 0, 0))[3] == 0.10),
        ("comment not read", len(t["colors"]) == 5),
        ("radius", t["radii"].get("small", (0,))[0] == 4),
        ("motion in ms", t["motion"].get("quick", (0,))[0] == 120),
        ("face", t["faces"] and t["faces"][0][1] == "AtkinsonHyperlegible-Regular"),
        ("two :root blocks", len(blocks) == 2),
        ("commented :root ignored", blocks[0]["vars"]["--bg"][0] == "#000"),
        ("media kept", blocks[1]["media"] == "@media (prefers-contrast: high)"),
        ("equal colour", compare_color((0.878, 0.878, 0.878, 1.0), "#e0e0e0")[0] == "ok"),
        ("half rounds up", compare_color((0.30, 0.85, 0.55, 1.0), "#4dd98c")[0] == "ok"),
        ("rounding step is a note", compare_color((0.104, 0.104, 0.118, 1.0), "#1a1a1e")[0] == "note"),
        ("other colour is drift", compare_color((0.30, 0.85, 0.55, 1.0), "#34c759")[0] == "drift"),
        ("alpha is drift", compare_color((0.878, 0.878, 0.878, 0.65), "rgba(224,224,224,0.55)")[0] == "drift"),
        ("short hex", css_color("#000") == (0, 0, 0, 1.0)),
    ]
    bad = [name for name, ok in checks if not ok]
    print("selftest: %d of %d" % (len(checks) - len(bad), len(checks)) + ("" if not bad else " — FAILED: " + ", ".join(bad)))
    return 1 if bad else 0


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description="EchoelBrand.swift against the website's tokens")
    ap.add_argument("--repo", default=os.path.dirname(here), help="repository root (default: the parent of scripts/)")
    ap.add_argument("--strict", action="store_true", help="a rounding NOTE fails too")
    ap.add_argument("--quiet", action="store_true", help="print only what is not equal")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    return run(args.repo, args.strict, args.quiet)


if __name__ == "__main__":
    sys.exit(main())
