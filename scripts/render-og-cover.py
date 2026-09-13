#!/usr/bin/env python3
"""Render docs/og-cover.png from docs/og-image.svg.

WHY THIS EXISTS (#1312). `docs/og-cover.png` is the `og:image` / `twitter:image` of
20 pages — every link preview of echoelmusic.com. Until now it was a hand-made binary
with NO generator in the repo, so it drifted silently past its own artwork source:
the shipped PNG advertised a badge reading "AUv3" and the word "motion", both of which
the repo had already struck (#158/#192 removed the AUv3 claim from the site; CLAUDE.md
struck "motion" 2026-07-31 for having no producer). A text guard cannot see a raster,
and a `git grep` for "AUv3" returns only the site's DENIALS (docs/CLAUDE.md §5) — so
nothing in the toolchain could report it. The repair is not a better grep: it is making
the PNG DERIVABLE, so the artwork source is the single truth and a re-render is one
command.

The SVG names 'Atkinson Hyperlegible' by family only, which a headless browser does not
have installed. This wraps it in an HTML page that declares @font-face against the
repo's own `docs/fonts/*.woff2`, so the render uses the same faces the site does.
The wrapper is written INTO `docs/` (and removed again) because the font URLs in the
SVG are relative to that directory.

Every render also writes `docs/og-cover.source.sha256` — the digest of the SVG the PNG was
made from. That sidecar, not a digest of the PNG, is what the guard
`Tests/CISmoke/TheSocialCardIsDerivedFromItsArtworkTests.swift` compares: a PNG digest would
differ between Chromium builds and would turn a correct re-render on another machine red
(#364), while the source digest is byte-identical everywhere and still goes red for exactly
the case that happened here — artwork edited, raster not re-rendered.

Usage:  python3 scripts/render-og-cover.py [--check]
        --check renders to a temp file and reports whether the committed PNG matches,
        without writing it (for a human; no CI gate runs on a docs-only commit).

Needs a Chromium binary. Looked up in this order: $CHROME, a Playwright download under
$PLAYWRIGHT_BROWSERS_PATH (or /opt/pw-browsers), then chromium / chromium-browser /
google-chrome on PATH. On a Mac without any of those:
  /Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome  (pass via $CHROME)
"""

import glob
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG = os.path.join(ROOT, "docs", "og-image.svg")
PNG = os.path.join(ROOT, "docs", "og-cover.png")
STAMP = os.path.join(ROOT, "docs", "og-cover.source.sha256")
WIDTH, HEIGHT = 1200, 630

WRAPPER_HEAD = """<!DOCTYPE html><html><head><meta charset="utf-8"><style>
@font-face{font-family:'Atkinson Hyperlegible';src:url('fonts/atkinson-regular.woff2') format('woff2');font-weight:400;font-style:normal;}
@font-face{font-family:'Atkinson Hyperlegible';src:url('fonts/atkinson-bold.woff2') format('woff2');font-weight:700;font-style:normal;}
html,body{margin:0;padding:0;background:#000;}
svg{display:block;width:%dpx;height:%dpx;}
</style></head><body>
""" % (WIDTH, HEIGHT)


def find_chromium():
    env = os.environ.get("CHROME")
    if env and os.path.exists(env):
        return env
    base = os.environ.get("PLAYWRIGHT_BROWSERS_PATH", "/opt/pw-browsers")
    for pattern in ("chromium-*/chrome-linux/chrome", "chromium-*/chrome-mac/Chromium.app/Contents/MacOS/Chromium"):
        hits = sorted(glob.glob(os.path.join(base, pattern)))
        if hits:
            return hits[-1]
    for name in ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable"):
        found = shutil.which(name)
        if found:
            return found
    return None


def render(chrome, out_path):
    wrapper = os.path.join(ROOT, "docs", ".og-cover-render.html")
    with open(SVG, encoding="utf-8") as handle:
        svg = handle.read()
    with open(wrapper, "w", encoding="utf-8") as handle:
        handle.write(WRAPPER_HEAD + svg + "\n</body></html>\n")
    try:
        subprocess.run(
            [
                chrome, "--headless", "--no-sandbox", "--disable-gpu",
                "--hide-scrollbars", "--force-device-scale-factor=1",
                "--window-size=%d,%d" % (WIDTH, HEIGHT),
                "--screenshot=" + out_path,
                "file://" + wrapper,
            ],
            check=True, capture_output=True,
        )
    finally:
        if os.path.exists(wrapper):
            os.remove(wrapper)


def sha256(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def main():
    check = "--check" in sys.argv[1:]
    chrome = find_chromium()
    if chrome is None:
        print("FAIL: no Chromium found. Set $CHROME to a Chrome/Chromium binary.")
        return 2
    if not os.path.exists(SVG):
        print("FAIL: missing %s" % SVG)
        return 2

    if check:
        handle, tmp = tempfile.mkstemp(suffix=".png")
        os.close(handle)
        try:
            render(chrome, tmp)
            if not os.path.exists(PNG):
                print("DRIFT: %s does not exist" % PNG)
                return 1
            if sha256(tmp) == sha256(PNG):
                print("OK: docs/og-cover.png matches docs/og-image.svg")
                return 0
            print("DRIFT: docs/og-cover.png does not match docs/og-image.svg.")
            print("       Re-render: python3 scripts/render-og-cover.py")
            print("       (byte-exact equality also needs the same Chromium build;")
            print("        compare the rendered text before assuming a real drift.)")
            return 1
        finally:
            os.remove(tmp)

    render(chrome, PNG)
    digest = sha256(SVG)
    with open(STAMP, "w", encoding="utf-8") as handle:
        handle.write(digest + "  docs/og-image.svg\n")
    print("wrote %s (%d B) from docs/og-image.svg using %s" % (PNG, os.path.getsize(PNG), chrome))
    print("wrote %s (%s)" % (STAMP, digest[:16] + "…"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
