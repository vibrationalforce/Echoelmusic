#!/usr/bin/env python3
"""After-edit check for Claude Code: a PostToolUse hook on Edit, Write and MultiEdit.

It reads the hook's JSON on stdin, takes the edited file and checks that ONE file at once, so a
session sees a broken law in the turn it broke it, not 25 minutes later in CI:

- Swift under EchoelStudio/: the laws a line can decide without a compiler — no print, no force
  unwrap, no ObservableObject, no UIScreen.main, no @MainActor on an XCTestCase class, no lock,
  GCD, file I/O, log or Task in the render packages (DSP, EchoelKernels) and in the three render
  closures, imports only where studio.yml names them, network only in the files studio.yml
  allows, no banned word in a user-facing string. Comments and string contents are read as
  Swift reads them (EchoelStudio/Support/CI/swift_imports.py, the parser the CI gate uses).
- Fast unit tests where a Swift toolchain exists (a Mac): the edited file's own test class, by
  `swift test --package-path <package> --filter <Class>`. In a cloud session there is none, and
  CI (`Echoel Studio`, studio.yml) stays the compiler; the hook then says nothing about tests.
- Python under scripts/, .claude/hooks/ or EchoelStudio/Support/CI/: it must parse, and a tool
  that has a --selftest must pass it.

A finding that breaks a law exits 2, which hands the text to the session to repair. Advice that
a rule cannot decide alone (an @Observable without @MainActor, a test that names a source file)
comes back as context and does not block. Clean files print nothing. Read-only: the hook never
writes a file. Every check was measured against the tree before it was armed: on the code that
CI keeps green it flags nothing (`--tree`).

    python3 .claude/hooks/verify-after-edit.py --selftest
    python3 .claude/hooks/verify-after-edit.py --tree      # every EchoelStudio Swift file
"""
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.environ.get("CLAUDE_PROJECT_DIR") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "EchoelStudio", "Support", "CI"))
import swift_imports as swift  # noqa: E402  (the CI's own Swift reader)

TEST_SECONDS = int(os.environ.get("ECHOEL_HOOK_TEST_SECONDS", "300"))

# ---------- what the laws ban, as lines can show it ----------

PRINT = re.compile(r"(?<![\w.$])(?<!func )(?:print|debugPrint|NSLog|dump)\s*\(")
FORCE = re.compile(r"(?<=[\w)\]])!(?!=)")
IUO_DECL = re.compile(r"\b(?:let|var)\s+\w+\s*:\s*[\w.]+(?:<[^>]*>)?!")
OBSERVABLE_OBJECT = re.compile(r"\bObservableObject\b|@(?:Published|StateObject|ObservedObject|EnvironmentObject)\b")
UISCREEN_MAIN = re.compile(r"\bUIScreen\s*\.\s*main\b")
COLOR_MAGENTA = re.compile(r"(?<![\w.])Color\s*\.\s*magenta\b")
TEST_CLASS = re.compile(r"\bclass\s+\w+\s*:\s*[^{]*\bXCTestCase\b")
ATTRIBUTES_ONLY = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s*)+$")
RENDER_TOKENS = re.compile(
    r"\b(?:DispatchQueue|DispatchSemaphore|DispatchGroup|NSLock|NSRecursiveLock|NSCondition|pthread_mutex\w*"
    r"|os_unfair_lock\w*|Mutex|OSAllocatedUnfairLock|FileManager|NSLog|os_log|Logger|fopen|fwrite|fread)\b"
    r"|\bTask\s*(?:\{|\.detached|<)|\bawait\b|@objc\b|\bNSObject\b|(?<![\w.])print\s*\(")
RENDER_PACKAGES = ("EchoelStudio/DSP/Sources/", "EchoelStudio/Engine/Sources/EchoelKernels/")
RENDER_CLOSURES = {
    "EchoelStudio/App/Engine/AudioEngine.swift": re.compile(r"AVAudioSourceNode\s*\(\s*format\s*:"),
    "EchoelStudio/Plugins/Shared/InstrumentAudioUnit.swift": re.compile(r"\bvar\s+internalRenderBlock\s*:\s*AUInternalRenderBlock"),
    "EchoelStudio/Engine/Sources/EchoelHost/StandardEffectUnit.swift": re.compile(r"\bvar\s+internalRenderBlock\s*:\s*AUInternalRenderBlock"),
}
BANNED = re.compile(
    r"(?i)\b(?:wellness|meditat\w*|entspannung\w*|relaxation|solfeggio|chakra\w*|chakren|binaural"
    r"|healing\s+frequenc\w*|heilfrequenz\w*|auto-?tune\w*|blab|vibrational\s+force)\b")
OBSERVABLE = re.compile(r"@Observable\b")
SOURCE_NAMES = re.compile(r"\.swift\b|\.md\b|CLAUDE|/Sources/|EchoelStudio/")
FILE_LITERAL = re.compile(r"#(?:filePath|file|fileID)\b")


def strings_only(source):
    """`source` with code and comments blanked, the contents of string literals kept (newlines stay).
    The mirror of swift.strip: the same state machine, keeping the other half."""
    stripped = swift.strip(source)
    comments_blank = _strip_comments(source)
    # A character is string content where the comment-free text still has it and the code-only text does not.
    return "".join(c if (c != s and c == k) or c == "\n" else " " for c, s, k in zip(source, stripped, comments_blank))


def _strip_comments(source):
    out, i, n, depth_string = list(source), 0, len(source), None
    while i < n:
        if depth_string is None:
            if source.startswith("//", i):
                end = source.find("\n", i)
                end = n if end < 0 else end
                for k in range(i, end):
                    out[k] = " "
                i = end
                continue
            if source.startswith("/*", i):
                depth, j = 1, i + 2
                while j < n and depth:
                    if source.startswith("/*", j):
                        depth, j = depth + 1, j + 2
                    elif source.startswith("*/", j):
                        depth, j = depth - 1, j + 2
                    else:
                        j += 1
                for k in range(i, j):
                    if out[k] != "\n":
                        out[k] = " "
                i = j
                continue
            if source.startswith('"""', i):
                depth_string, i = '"""', i + 3
                continue
            if source[i] == '"':
                depth_string, i = '"', i + 1
                continue
            i += 1
        else:
            if source[i] == "\\":
                i += 2
                continue
            if source.startswith(depth_string, i):
                i += len(depth_string)
                depth_string = None
                continue
            if depth_string == '"' and source[i] == "\n":
                depth_string = None
            i += 1
    return "".join(out)


def _closure_extent(code, anchor):
    """The text between the braces of the first closure after `anchor`, or None."""
    match = anchor.search(code)
    if not match:
        return None
    start = code.find("{", match.end())
    if start < 0:
        return None
    depth = 0
    for k in range(start, len(code)):
        if code[k] == "{":
            depth += 1
        elif code[k] == "}":
            depth -= 1
            if depth == 0:
                return start, k
    return None


def _studio_rules():
    """The import rows and the network allowlist, read from studio.yml as CI runs them."""
    try:
        yml = open(os.path.join(ROOT, ".github", "workflows", "studio.yml"), encoding="utf-8").read()
    except OSError:
        return None, None
    block = re.search(r"rows = \[(.*?)\n\s*\]", yml, re.S)
    rows = [(prefix, set(names.split())) for prefix, names in
            re.findall(r'\(\s*"(EchoelStudio/[^"]+)",\s*"([^"]+)"\s*\)', block.group(1))] if block else []
    allowed = re.search(r"allowed = \{(.*?)\}", yml, re.S)
    network = set(re.findall(r'"(EchoelStudio/[^"]+\.swift)"', allowed.group(1))) if allowed else None
    return rows, network


def check_swift(path, source, rules=None):
    """(blocking findings, advice) for one Swift file at repo-relative `path`."""
    findings, advice = [], []
    code = swift.strip(source)
    lines = code.split("\n")
    is_test = "/Tests/" in path

    def flag(number, what):
        findings.append(f"{path}:{number}: {what}")

    for number, line in enumerate(lines, 1):
        if PRINT.search(line):
            flag(number, "print/NSLog/dump is banned (EchoelStudio/CLAUDE.md Law 9); use a Logger off the render thread")
        if FORCE.search(line) and not IUO_DECL.search(line):
            flag(number, "force unwrap (`!`, try!, as!) is banned (Law 9); use guard let or a fallback")
        if OBSERVABLE_OBJECT.search(line):
            flag(number, "ObservableObject is banned (root CLAUDE.md DO NOT); use @Observable with @MainActor")
        if UISCREEN_MAIN.search(line):
            flag(number, "UIScreen.main is banned (root CLAUDE.md DO NOT); read the size from the view")
        if COLOR_MAGENTA.search(line):
            flag(number, "Color.magenta does not exist; write Color(red: 1, green: 0, blue: 1)")
        if path.startswith(RENDER_PACKAGES) and RENDER_TOKENS.search(line):
            flag(number, "a lock, GCD, Task/await, file I/O, a log or ObjC in a render package (Law 5)")

    if is_test:
        for number, line in enumerate(lines, 1):
            if TEST_CLASS.search(line):
                above = [line]
                k = number - 2
                while k >= 0 and ATTRIBUTES_ONLY.match(lines[k]):
                    above.append(lines[k])
                    k -= 1
                if any("@MainActor" in part for part in above):
                    flag(number, "no @MainActor on an XCTestCase class: Linux test discovery traps (EchoelStudio/CLAUDE.md build lessons)")

    anchor = RENDER_CLOSURES.get(path)
    if anchor:
        extent = _closure_extent(code, anchor)
        if extent is None:
            advice.append(f"{path}: the render closure's anchor was not found; the render-closure check did not run")
        else:
            body = code[extent[0]:extent[1]]
            first = code.count("\n", 0, extent[0]) + 1
            for offset, line in enumerate(body.split("\n")):
                if RENDER_TOKENS.search(line):
                    flag(first + offset, "a lock, GCD, Task/await, file I/O, a log or ObjC inside the render closure (Law 5)")

    found = swift.imports(source)
    rows, network = rules if rules else _studio_rules()
    for prefix, names in rows or []:
        if path.startswith(prefix + "/"):
            stray = sorted(found - names)
            if stray:
                flag(1, f"imports {', '.join(stray)} outside its row in studio.yml ({prefix}: {' '.join(sorted(names))}); "
                        "a new import widens that row in the same commit")
    if path.startswith("EchoelStudio/Plugins/") and "EchoelEngine" in found:
        flag(1, "the AUv3 extension never imports EchoelEngine (EchoelStudio/CLAUDE.md layout)")
    if found & {"HaishinKit", "RTMPHaishinKit", "SRTHaishinKit"} and not path.startswith("EchoelStudio/App/Streaming/"):
        flag(1, "HaishinKit is imported only under EchoelStudio/App/Streaming/ (studio.yml)")
    if network is not None and not is_test and swift.names_network(source) and path not in network:
        flag(1, "a network API outside the files studio.yml allows (Law 10): add the file to that list in the same "
                "commit, off by default and shown in the Song menu, or move the call")
    if re.search(r"\bUnsafeMutableAudioBufferListPointer\b", code) and "AVFoundation" not in found:
        flag(1, "UnsafeMutableAudioBufferListPointer needs `import AVFoundation` on iOS (build lessons)")
    if re.search(r"\brequestViewController\b", code) and "CoreAudioKit" not in found:
        flag(1, "requestViewController needs `import CoreAudioKit` (build lessons)")

    if path.startswith(("EchoelStudio/App/", "EchoelStudio/Plugins/")):
        for number, line in enumerate(strings_only(source).split("\n"), 1):
            word = BANNED.search(line)
            if word:
                flag(number, f"'{word.group(0)}' in a user-facing string (root CLAUDE.md Sprache, ContentPipeline/CLAIMS.md §2)")

    for number, line in enumerate(lines, 1):
        if OBSERVABLE.search(line):
            window = lines[max(0, number - 4):number + 1]
            if not any("@MainActor" in part for part in window):
                advice.append(f"{path}:{number}: @Observable without @MainActor nearby (.claude/rules/swift-audio.md)")
    if is_test:
        for number, line in enumerate(lines, 1):
            literal = FILE_LITERAL.search(line)
            if literal and not re.search(r"StaticString\s*=\s*$", line[:literal.start()]):
                advice.append(f"{path}:{number}: a test that reads its own file path may be reading source (Law 8)")
        for number, line in enumerate(strings_only(source).split("\n"), 1):
            if SOURCE_NAMES.search(line):
                advice.append(f"{path}:{number}: a test string names a source or prose file; tests test behaviour (Law 8)")
    return findings, advice


# ---------- fast tests where a toolchain exists ----------

PACKAGES = ("EchoelStudio/Core", "EchoelStudio/DSP", "EchoelStudio/Engine")


def test_classes(path):
    """The package and the XCTest classes that test `path`, or (None, [])."""
    package = next((p for p in PACKAGES if path.startswith(p + "/")), None)
    if not package:
        return None, []
    tests_dir = os.path.join(ROOT, package, "Tests")
    if "/Tests/" in path:
        try:
            source = open(os.path.join(ROOT, path), encoding="utf-8").read()
        except OSError:
            return package, []
        return package, re.findall(r"\bclass\s+(\w+)\s*:\s*[^{]*\bXCTestCase\b", swift.strip(source))
    name = os.path.splitext(os.path.basename(path))[0] + "Tests"
    pattern = re.compile(r"\bclass\s+" + re.escape(name) + r"\s*:")
    for folder, _, files in os.walk(tests_dir):
        for file in files:
            if file.endswith(".swift"):
                try:
                    if pattern.search(open(os.path.join(folder, file), encoding="utf-8").read()):
                        return package, [name]
                except OSError:
                    continue
    return package, []


def run_tests(path):
    if not shutil.which("swift"):
        return None
    package, classes = test_classes(path)
    if not package or not classes:
        return None
    command = ["swift", "test", "--package-path", os.path.join(ROOT, package), "--filter", "|".join(classes)]
    try:
        done = subprocess.run(command, capture_output=True, text=True, timeout=TEST_SECONDS)
    except subprocess.TimeoutExpired:
        return f"swift test --filter {'|'.join(classes)} ran past {TEST_SECONDS} s; CI decides"
    if done.returncode != 0:
        tail = "\n".join((done.stdout + done.stderr).strip().split("\n")[-40:])
        return f"swift test --package-path {package} --filter {'|'.join(classes)} FAILED:\n{tail}"
    return ""


# ---------- python ----------

def check_python(path):
    full = os.path.join(ROOT, path)
    try:
        source = open(full, encoding="utf-8").read()
        compile(source, path, "exec")
    except SyntaxError as error:
        return [f"{path}:{error.lineno}: does not parse: {error.msg}"]
    except OSError:
        return []
    if "--selftest" not in source or path.endswith("verify-after-edit.py") and os.environ.get("ECHOEL_HOOK_INNER"):
        return []
    try:
        done = subprocess.run([sys.executable, "-I", full, "--selftest"], capture_output=True, text=True, timeout=120,
                              cwd=ROOT, env={**os.environ, "ECHOEL_HOOK_INNER": "1"})
    except subprocess.TimeoutExpired:
        return [f"{path}: --selftest ran past 120 s"]
    if done.returncode != 0:
        return [f"{path}: --selftest failed:\n" + "\n".join((done.stdout + done.stderr).strip().split("\n")[-20:])]
    return []


# ---------- the hook ----------

def relative(path):
    full = os.path.abspath(path)
    root = os.path.abspath(ROOT)
    return os.path.relpath(full, root) if full.startswith(root + os.sep) else None


def review(path):
    findings, advice = [], []
    if path.startswith("EchoelStudio/") and path.endswith(".swift"):
        try:
            source = open(os.path.join(ROOT, path), encoding="utf-8-sig").read()
        except OSError:
            return [], []
        findings, advice = check_swift(path, source)
        if not findings:
            outcome = run_tests(path)
            if outcome:
                findings.append(outcome)
    elif path.endswith(".py") and path.startswith(("scripts/", ".claude/hooks/", "EchoelStudio/Support/CI/")):
        findings = check_python(path)
    return findings, advice


def main():
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return 0
    tool_input = payload.get("tool_input") or {}
    path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not path:
        return 0
    path = relative(path)
    if not path:
        return 0
    findings, advice = review(path)
    if findings:
        sys.stderr.write("verify-after-edit found what a law forbids — repair it before going on:\n" + "\n".join(findings) + "\n")
        return 2
    if advice:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse",
                                                 "additionalContext": "verify-after-edit advice:\n" + "\n".join(advice)}}))
    return 0


# ---------- measuring the checks ----------

def tree():
    rules = _studio_rules()
    files = swift.files("EchoelStudio/*.swift")
    hits, notes = 0, 0
    for path in files:
        findings, advice = check_swift(path, swift.read(os.path.join(ROOT, path)), rules)
        for line in findings:
            print("BLOCK", line)
        hits += len(findings)
        notes += len(advice)
    print(f"{len(files)} files, {hits} blocking, {notes} advice")
    return 1 if hits else 0


def selftest():
    rules = ([("EchoelStudio/DSP/Sources", {"Foundation"})], {"EchoelStudio/App/Jam/JamLink.swift"})
    cases = [
        ("EchoelStudio/Core/Sources/EchoelCore/A.swift", 'func f() { print("x") }', True),
        ("EchoelStudio/Core/Sources/EchoelCore/A.swift", '// print("x")\nlet s = "print(1)"\nlogger.print(1)\nfunc print(_ x: Int) {}', False),
        ("EchoelStudio/Core/Sources/EchoelCore/A.swift", "let a = b!", True),
        ("EchoelStudio/Core/Sources/EchoelCore/A.swift", "let a = try! f()", True),
        ("EchoelStudio/Core/Sources/EchoelCore/A.swift", "var url: URL!\nif a != b, !c { }", False),
        ("EchoelStudio/App/Views/V.swift", "final class M: ObservableObject {}", True),
        ("EchoelStudio/App/Views/V.swift", "let w = UIScreen.main.bounds.width", True),
        ("EchoelStudio/App/Views/V.swift", "let c = Color.magenta", True),
        ("EchoelStudio/Core/Tests/EchoelCoreTests/T.swift", "@MainActor\nfinal class T: XCTestCase {}", True),
        ("EchoelStudio/Core/Tests/EchoelCoreTests/T.swift", "final class T: XCTestCase {\n    @MainActor func f() {}\n}", False),
        ("EchoelStudio/DSP/Sources/EchoelDSP/K.swift", "import Foundation\nlet q = DispatchQueue.main", True),
        ("EchoelStudio/DSP/Sources/EchoelDSP/K.swift", "import Foundation\n// DispatchQueue in a comment", False),
        ("EchoelStudio/DSP/Sources/EchoelDSP/K.swift", "import Foundation\nimport AVFoundation", True),
        ("EchoelStudio/App/Net/X.swift", "import Network", True),
        ("EchoelStudio/App/Jam/JamLink.swift", "import MultipeerConnectivity", False),
        ("EchoelStudio/App/Views/V.swift", 'Text("A calm wellness session")', True),
        ("EchoelStudio/App/Views/V.swift", "let relaxed = ordering.relaxed  // wellness in a comment", False),
        ("EchoelStudio/Plugins/Shared/P.swift", "import EchoelEngine", True),
    ]
    failures = 0
    for number, (path, source, should_block) in enumerate(cases, 1):
        findings, _ = check_swift(path, source, rules)
        if bool(findings) != should_block:
            failures += 1
            print(f"case {number} ({path}): expected {'a finding' if should_block else 'none'}, got {findings}")
    advice_case = check_swift("EchoelStudio/App/Views/V.swift", "@Observable\nfinal class M {}", rules)[1]
    if not advice_case:
        failures += 1
        print("advice case: an @Observable without @MainActor gave no advice")
    closure = 'let node = AVAudioSourceNode(format: f) { _, _, _, _ in\n    let q = DispatchQueue.main\n    return noErr\n}\n'
    if not check_swift("EchoelStudio/App/Engine/AudioEngine.swift", "import AVFoundation\n" + closure, rules)[0]:
        failures += 1
        print("render closure case: a DispatchQueue in the source-node block was not found")
    rows, network = _studio_rules()
    if not rows or not network:
        failures += 1
        print("studio.yml: the import rows or the network allowlist could not be read — the mirror matches nothing")
    print("ok" if not failures else f"{failures} failed", f"({len(cases) + 3} cases)")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    if "--tree" in sys.argv:
        sys.exit(tree())
    sys.exit(main())
