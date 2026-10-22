"""What a Swift file imports and which network APIs its code names, for the Studio gate.

`.github/workflows/studio.yml` runs two checks with it: "Network only where named" and
"Imports only where named" (S-26 D4.2). Both read Swift as Swift, not as lines: comments
(nested ones too) and the contents of string literals are blanked first, so a comment, a doc
line or a string never counts as an import or a network call, and a "/*" inside a string never
hides the code after it. CI only: nothing here ships, and no test reads source (Law 8).

    python3 EchoelStudio/Support/CI/swift_imports.py --selftest
"""

import re
import subprocess

# Every spelling Swift accepts for an import declaration: attributes with arguments
# (`@_spi(A)`, `@_implementationOnly`, also on the line before), an access level (SE-0409),
# a kind (`import struct M.T`), several on one line. The declaration ends after the module
# path, so `import` used as a parameter label (`func load(import file: URL)`) is not one.
DECLARATION = re.compile(
    r"(?:^|;)\s*(?:(?:@[A-Za-z_]\w*(?:\([^)]*\))?|open|public|package|internal|fileprivate|private)\s+)*"
    r"import\s+(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?([A-Za-z_]\w*)(?:\.\w+)*[ \t]*(?=;|\r?$)",
    re.M)

# Frameworks that reach the network, and APIs that do so without one of them.
NETWORK_MODULES = {"Network", "StoreKit", "MultipeerConnectivity", "CloudKit", "WebKit", "SafariServices",
                   "CFNetwork", "GroupActivities", "AuthenticationServices", "WeatherKit", "MapKit"}
NETWORK_API = re.compile(
    r"\b(?:URLSession|URLRequest|NWConnection|NWListener|NWBrowser|MIDINetworkSession|NSURLConnection"
    r"|CFSocket\w*|CFStream\w*|getaddrinfo)\b|\b(?:socket|sendto)\s*\(")


def strip(source):
    """`source` with every comment and the contents of every string literal replaced by spaces.
    Newlines stay, so line anchors still work; code inside a string interpolation stays code."""
    out = list(source)
    n = len(source)
    i = 0
    # A stack of what is open: ("code", parens) for code inside an interpolation, or
    # ("string", hashes, multiline) for a literal.
    stack = [("code", 0)]

    def blank(a, b):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        top = stack[-1]
        c = source[i]
        if top[0] == "code":
            if source.startswith("//", i):
                end = source.find("\n", i)
                end = n if end < 0 else end
                blank(i, end)
                i = end
            elif source.startswith("/*", i):
                depth, j = 1, i + 2
                while j < n and depth:
                    if source.startswith("/*", j):
                        depth, j = depth + 1, j + 2
                    elif source.startswith("*/", j):
                        depth, j = depth - 1, j + 2
                    else:
                        j += 1
                blank(i, j)
                i = j
            elif c == "#" or c == '"':
                j = i
                while j < n and source[j] == "#":
                    j += 1
                if j < n and source[j] == '"':
                    hashes = j - i
                    multiline = source.startswith('"""', j)
                    i = j + (3 if multiline else 1)
                    stack.append(("string", hashes, multiline))
                else:
                    i = j if j > i else i + 1
            elif c == "(" and len(stack) > 1:
                stack[-1] = ("code", top[1] + 1)
                i += 1
            elif c == ")" and len(stack) > 1:
                if top[1] == 0:
                    stack.pop()  # the interpolation ends; back in its string
                else:
                    stack[-1] = ("code", top[1] - 1)
                i += 1
            else:
                i += 1
        else:
            _, hashes, multiline = top
            close = ('"""' if multiline else '"') + "#" * hashes
            escape = "\\" + "#" * hashes
            if source.startswith(close, i):
                stack.pop()
                i += len(close)
            elif source.startswith(escape + "(", i):
                blank(i, i + len(escape) + 1)
                i += len(escape) + 1
                stack.append(("code", 0))
            elif source.startswith(escape, i):
                blank(i, min(n, i + len(escape) + 1))
                i += len(escape) + 1
            else:
                if c != "\n":
                    out[i] = " "
                i += 1
    return "".join(out)


def imports(source):
    """The modules a Swift source imports."""
    return set(DECLARATION.findall(strip(source)))


def names_network(source):
    """Whether a Swift source imports a network framework or names a network API in code."""
    code = strip(source)
    return bool(set(DECLARATION.findall(code)) & NETWORK_MODULES) or bool(NETWORK_API.search(code))


def files(*pathspecs):
    """Tracked files for git pathspecs, with names exactly as on disk (no quoting)."""
    listed = subprocess.run(["git", "ls-files", "-z", "--", *pathspecs], capture_output=True, check=True).stdout
    return [name for name in listed.decode("utf-8").split("\0") if name]


def read(path):
    with open(path, encoding="utf-8-sig") as handle:
        return handle.read()


def selftest():
    cases = [
        ('import Foundation\nlet t = "audio/*"\nimport AVFoundation\n/* note */', {"Foundation", "AVFoundation"}),
        ("func load(\n    import file: URL) {}", set()),
        ('let s = "a; import UIKit"', set()),
        ("/* outer /* inner */ import AVFoundation */\nimport Foundation", {"Foundation"}),
        ("@_implementationOnly import A\n@_spi(X) public import B\ninternal import struct C.D\nimport E;import F",
         {"A", "B", "C", "E", "F"}),
        ('let s = """\nimport UIKit\n"""\nimport G', {"G"}),
        ('let r = #"a "quote" ; import H"#\nimport I', {"I"}),
        ('let s = "x \\(f("import J")) y"\nimport K', {"K"}),
        ("@_exported\nimport L", {"L"}),
        ("import M // trailing", {"M"}),
        ("#if canImport(UIKit)\nimport UIKit\n#endif", {"UIKit"}),
        ("import N\r\nimport O\r\n", {"N", "O"}),
        ('let s = "\\"; import P"', set()),
        ('let r = ##"one "# two"##\nimport Q', {"Q"}),
    ]
    failed = 0
    for source, expected in cases:
        got = imports(source)
        if got != expected:
            failed += 1
            print(f"FAIL imports {source!r}: {sorted(got)} != {sorted(expected)}")
    network = [
        ("// URLSession is not used here", False),
        ('let s = "URLSession"', False),
        ("let task = URLSession.shared", True),
        ("import Network", True),
        ("import Foundation", False),
        ("let fd = socket(AF_INET, SOCK_DGRAM, 0)", True),
        ("func load(\n    import Network: URL) {}", False),
    ]
    for source, expected in network:
        if names_network(source) != expected:
            failed += 1
            print(f"FAIL network {source!r}: expected {expected}")
    print("selftest:", "ok" if not failed else f"{failed} failed", f"({len(cases) + len(network)} cases)")
    return failed == 0


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["--selftest"]:
        sys.exit(0 if selftest() else 1)
    print(__doc__)
