#!/usr/bin/env python3
r"""Which closures formed on the main actor are handed to a framework that calls them elsewhere?

WHY THIS EXISTS (GMMW P0-5). Build 2613 crashed with SIGTRAP on a background queue. The cause
was not a data race but a CHECK. Under Swift 6 (SE-0423), a closure written inside a
`@MainActor` type, with no `@Sendable`, INHERITS main-actor isolation. Hand it to an Objective-C
or C framework that does not mark the block Sendable, and the compiler inserts a runtime check
at the closure's entry. The framework then calls it on its own queue, and the check traps.
Nothing warns at compile time.

Eight fixes closed that class one site at a time, and each site was found AFTER a crash or by
reading:
  bebdfa8 RetroCapture (DispatchSource) · 39dc05e SingleExport (requestMediaDataWhenReady) ·
  bba1030 MIDIInput (CoreMIDI) · 39ba753 EchoelBioEngine + HealthKitWriter (HealthKit) ·
  a2b09f4 HapticEngine (CoreHaptics) · e24db42 MetalBioView (Metal) ·
  8fb5c79 AnnouncementCenter (CloudKit) · 8ddb0be AudioClipPlayer (AVAudioPlayerNode).
The next site should come from a list, not from a crash. This script is that list.

WHAT IT LISTS. Every closure literal that meets all three conditions:
  1. it is formed in an ISOLATED context: a `@MainActor` type or function, an `actor`, a type
     conforming to `View`/`App`/… (main-actor protocols in the iOS 18 SDK), a subclass of a
     UIKit view class, or an extension of any of those;
  2. it is not in a `nonisolated` function, a `deinit`, or inside a `@Sendable` closure or a
     `Task.detached`. Any of those makes the closure non-isolated, so there is nothing to check;
  3. it is passed to, or assigned to, something NOT declared in this repository. Our own APIs
     are compiled in Swift 6 mode, so the compiler checks them statically.

Each listed site gets exactly one verdict:
  TRAPS-ON-WORKER    a family that calls on its own thread (see FAMILIES), and the closure is
                     not `@Sendable`. Work; exit code 1.
  SAFE-BY-SENDABLE   the closure is spelled `@Sendable`, so it is non-isolated by construction.
  SAFE-ON-MAIN       the API delivers on the main queue (`queue: .main`, `DispatchQueue.main`,
                     a SwiftUI view builder or modifier, a main-run-loop timer).
  NEEDS-SDK-READING  everything else. The verdict depends on how the SDK header annotates the
                     block. ⚠️ A model's belief that some SDK block is Sendable is a HYPOTHESIS
                     and is printed as one (`hypothesis:`), never as a verdict. Only a Mac
                     reading the header turns it into SAFE.

LIMITS (stated, so a clean run is not read as more than it is):
  · No compiler. Isolation is inferred from the source text: attributes, conformances,
    superclasses and `extension` targets, to a fixpoint across files. Inference through a
    protocol from ANOTHER module, other than the main-actor list here, is not seen.
  · "Not declared here" is a NAME test. A framework method with the same name as one of ours
    (`save`, `delete`, `start`) reads as ours. The FAMILIES table wins over that name test,
    which is why every known trap family is listed there with the import it needs.
  · A closure stored in a variable first (`let h = { … }`) and passed later is not followed.
    It is counted under "stored closures, not followed".
  · Recall is proven on the eight historic sites only (`--selftest`). A family nobody has
    named yet still shows up, as NEEDS-SDK-READING, as long as its call has a closure literal
    at the call site.

⛔ WHAT THE FIRST DRAFT GOT WRONG, each caught by driving it rather than reading it:
  · The import parser used `\s+` and an optional "kind" word, so `import Foundation` swallowed
    the NEXT line's `import` as that word and a file with two adjacent imports lost the second.
    ArtNetSender lost `Network`, and its handler fell out of its family into NEEDS-SDK-READING.
  · The selftest matched the API token in the DISPLAY text, which is cut to 70 characters. Two
    of the nine historic sites (`node.scheduleBuffer(…)`, `MIDIInputPortCreateWithProtocol(…)`)
    read as not found while the scanner had found them. It matches the full call now.
  · A family pinned ONE import name. MetalBioView imports `MetalKit`, never `Metal`, so the
    P0-2 site was invisible. A family now names every module that re-exports its API.
  · The header walk stopped at a `}`. In `f(a: { … }, b: {` the second closure then had no
    callee, and 316 closures fell silently into an "undetermined" bucket. Braces are skipped
    like parentheses now, and the undetermined bucket is printed as a count.
  · OSCReceiver's two Network handlers read TRAPS-ON-WORKER although `start(queue: .main)`
    runs them on main. The queue a Network object was started on is resolved now.

Usage:
  python3 scripts/isolation-inventory.py               # HEAD of the worktree
  python3 scripts/isolation-inventory.py --all         # also print SAFE-* and counted buckets
  python3 scripts/isolation-inventory.py --rev <sha>   # read Sources/ at a commit instead
  python3 scripts/isolation-inventory.py --selftest    # the eight historic sites, before/after
Exit: 0 = no TRAPS-ON-WORKER · 1 = at least one · 2 = the scan could not run.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys
import warnings

warnings.filterwarnings("ignore", category=SyntaxWarning)
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import doctor  # noqa: E402  — one definition of "code, not prose" (#416)

ROOT = pathlib.Path(__file__).resolve().parent.parent

# ── Source access ──────────────────────────────────────────────────────────────────────────

def list_files(rev: str | None) -> list[str]:
    cmd = ["git", "-C", str(ROOT)]
    cmd += ["ls-tree", "-r", "--name-only", rev, "--", "Sources"] if rev else ["ls-files", "Sources"]
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.split()
    return [f for f in out if f.endswith(".swift")]


def read_file(rev: str | None, path: str) -> str:
    if rev is None:
        return (ROOT / path).read_text(encoding="utf-8")
    return subprocess.run(["git", "-C", str(ROOT), "show", f"{rev}:{path}"],
                          capture_output=True, text=True, check=True).stdout


def read_all(rev: str | None) -> dict[str, str]:
    """Every Swift file under Sources/ at `rev` (or the worktree), read in ONE git process."""
    if rev is None:
        return {f: read_file(None, f) for f in list_files(None)}
    listing = subprocess.run(["git", "-C", str(ROOT), "ls-tree", "-r", rev, "--", "Sources"],
                             capture_output=True, text=True, check=True).stdout.splitlines()
    blobs = []
    for row in listing:
        meta, path = row.split("\t", 1)
        if path.endswith(".swift") and meta.split()[1] == "blob":
            blobs.append((meta.split()[2], path))
    out = subprocess.run(["git", "-C", str(ROOT), "cat-file", "--batch"],
                         input="\n".join(sha for sha, _ in blobs).encode(),
                         capture_output=True, check=True).stdout
    texts, pos = {}, 0
    for sha, path in blobs:
        nl = out.index(b"\n", pos)
        size = int(out[pos:nl].split()[2])
        texts[path] = out[nl + 1:nl + 1 + size].decode("utf-8", errors="replace")
        pos = nl + 1 + size + 1
    return texts


# ── Brace tree ─────────────────────────────────────────────────────────────────────────────

MODS = (r"(?:(?:public|private|fileprivate|internal|open|final|indirect|nonisolated|static|class|"
        r"override|mutating|nonmutating|convenience|required|lazy|weak|unowned|dynamic|optional|"
        r"package)(?:\([^()]*\))?\s+)")
ATTR = r"(?:@[\w.]+(?:\([^()]*\))?\s+)"
TYPE_RE = re.compile(r"^" + ATTR + r"*" + MODS + r"*(class|struct|enum|actor|extension|protocol)\s+"
                     r"([A-Za-z_][\w.]*)\s*(<[^{]*?>)?\s*(:[^{]*?)?\s*(where[^{]*)?$", re.S)
FUNC_RE = re.compile(r"^" + ATTR + r"*" + MODS + r"*(func\s+[^\s(<]+|init[?!]?|deinit|subscript)\b", re.S)
VAR_RE = re.compile(r"^" + ATTR + r"*" + MODS + r"*(var|let)\s+\w+\s*:[^=]*$", re.S)
# A stored property with a default AND observers: `var x: Bool = true {` / `var x = 0 {`. Only a
# `didSet`/`willSet` body makes it one; `let x = items.map {` is a trailing closure.
OBSERVED_RE = re.compile(r"^" + ATTR + r"*" + MODS + r"*var\s+\w+\s*(?::[^=]*)?=", re.S)
ACC_RE = re.compile(r"^" + MODS + r"*(get|set|willSet|didSet|_modify|_read)(\s*\(\s*\w*\s*\))?$")
CTRL_RE = re.compile(r"^(?:case\b[^:]*:\s*|default\s*:\s*|\w+\s*:\s*)?"
                     r"(if|guard|for|while|switch|do|catch|repeat|defer|else)\b", re.S)
# A closure's own signature (`[weak self] a, b in`), stripped from a header that starts at its `{`.
SIG_RE = re.compile(r"^\s*(?:@\w+\s*)*(?:\[[^\]]*\]\s*)?(?:\([^()]*\)|[\w\s,]*?)\s*(?:async\s*)?"
                    r"(?:throws\s*)?(?:->\s*[^{}]*?)?\s*\bin\b", re.S)


def _pairs(code: str) -> list[tuple[int, int]]:
    stack, pairs = [], []
    for i, ch in enumerate(code):
        if ch == "{":
            stack.append(i)
        elif ch == "}" and stack:
            pairs.append((stack.pop(), i))
    pairs.sort()
    return pairs


def _header_start(code: str, o: int) -> tuple[int, str]:
    """Walk back from the `{` at `o` to the start of its statement; say what stopped the walk."""
    # Braces are skipped like parentheses: in `f(a: { … }, b: {` the second closure's statement
    # runs back through the first one to `f(`. A `{` at depth 0 is the enclosing block.
    j, depth = o - 1, 0
    while j >= 0:
        ch = code[j]
        if ch in ")]}":
            depth += 1
        elif ch in "([":
            if depth == 0:
                return j + 1, "open"
            depth -= 1
        elif ch == "{":
            if depth == 0:
                return j + 1, ch
            depth -= 1
        elif depth == 0 and ch == ";":
            return j + 1, ch
        elif depth == 0 and ch == "\n":
            k = j - 1
            while k >= 0 and code[k] in " \t\n":     # a blanked comment line is not a statement end
                k -= 1
            n = j + 1
            while n < len(code) and code[n] in " \t\n":
                n += 1
            nxt = code[n] if n < len(code) else ""
            line_before = code[code.rfind("\n", 0, j) + 1:j].strip()
            continues = (nxt in ".?:" or code.startswith(("where", "->", "throws", "async", "rethrows"), n)
                         or re.match(r"\w+\s*:\s*\{", code[n:n + 80]) is not None   # next trailing closure
                         or (k >= 0 and code[k] in ",([=:.&|+-*/<>")
                         or code[max(0, k - 1):k + 1] == "->"
                         or re.search(r"\bin$", code[max(0, k - 3):k + 1]) is not None)
            attribute_line = re.fullmatch(r"(@[\w.]+(\([^()]*\))?\s*)+", line_before) is not None
            if not (continues or attribute_line):
                return j + 1, "nl"
        j -= 1
    return 0, "bof"


def _kind(header: str, why: str, body: str = "") -> str:
    hh = header.strip()
    if OBSERVED_RE.match(hh) and re.match(r"\s*(?:didSet|willSet)\b", body):
        return "var"
    if why == "{" and not CTRL_RE.match(hh):
        m = SIG_RE.match(hh)
        if m:
            hh = hh[m.end():].strip()
            if not hh:
                return "closure"
    if TYPE_RE.match(hh):
        return "type"
    if FUNC_RE.match(hh):
        return "func"
    if VAR_RE.match(hh):
        return "var"
    if ACC_RE.match(hh):
        return "acc"
    if CTRL_RE.match(hh) or re.search(r"\belse$", hh):
        return "ctrl"
    return "closure"


class Node:
    __slots__ = ("o", "c", "s", "why", "h", "k", "parent")

    def __init__(self, o, c, s, why, h, k):
        self.o, self.c, self.s, self.why, self.h, self.k, self.parent = o, c, s, why, h, k, None


def tree(code: str) -> list[Node]:
    nodes = []
    for o, c in _pairs(code):
        s, why = _header_start(code, o)
        nodes.append(Node(o, c, s, why, code[s:o], _kind(code[s:o], why, code[o + 1:o + 2000])))
    stack: list[Node] = []
    for n in nodes:
        while stack and stack[-1].c < n.o:
            stack.pop()
        n.parent = stack[-1] if stack else None
        stack.append(n)
    return nodes


def flat(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()


# ── Isolation of types, to a fixpoint across files ────────────────────────────────────────

# Protocols the iOS 18 SDK declares `@MainActor`, and UIKit classes that are `@MainActor`.
MAIN_PROTOCOLS = {"View", "App", "Scene", "ViewModifier", "UIViewRepresentable",
                  "UIViewControllerRepresentable", "Commands", "ToolbarContent", "ButtonStyle",
                  "PrimitiveButtonStyle", "LabelStyle", "ToggleStyle", "PreviewProvider",
                  "UIApplicationDelegate", "UIWindowSceneDelegate", "UISceneDelegate"}
# SDK protocols whose isolation could not be read here. Treated as MAIN — the conservative side:
# a wrong guess lists a site that is merely safe; the other guess would hide one that traps.
ASSUMED_MAIN_PROTOCOLS = {"MTKViewDelegate"}
MAIN_SUPERS = {"UIView", "UIViewController", "UIResponder", "MTKView", "UIApplication", "UIWindow",
               "UIHostingController", "UINavigationController", "AUViewController", "UIControl",
               "UIScrollView", "UIScene", "UIWindowScene"}


def _inherits(header: str) -> list[str]:
    m = TYPE_RE.match(header.strip())
    if not m or not m.group(4):
        return []
    return [re.sub(r"<.*", "", x).strip().split(".")[-1] for x in m.group(4)[1:].split(",") if x.strip()]


def type_isolation(all_trees: dict[str, tuple[str, list[Node]]]) -> dict[str, str]:
    decls: dict[str, list[tuple[str, list[str], str]]] = {}
    for code, nodes in all_trees.values():
        for n in nodes:
            if n.k != "type":
                continue
            m = TYPE_RE.match(n.h.strip())
            if not m:
                continue
            decls.setdefault(m.group(2).split(".")[-1], []).append((m.group(1), _inherits(n.h), flat(n.h)))
    iso: dict[str, str] = {}
    main_protos = set(MAIN_PROTOCOLS)
    changed = True
    while changed:
        changed = False
        for name, ds in decls.items():
            if name in iso:
                continue
            verdict = None
            for kw, parents, h in ds:
                if kw == "actor":
                    verdict = "actor"
                elif re.search(r"@MainActor\b", h) and kw != "extension":
                    verdict = "main"
                elif kw != "extension" and any(p in main_protos or p in MAIN_SUPERS or iso.get(p) == "main"
                                               or p in ASSUMED_MAIN_PROTOCOLS for p in parents):
                    verdict = "main"
                if verdict:
                    break
            if verdict:
                iso[name] = verdict
                if any(kw == "protocol" for kw, _, _ in ds) and verdict == "main":
                    main_protos.add(name)
                changed = True
    return iso


# ── Families: APIs known to call the closure on a thread of their own ─────────────────────
# (regex on the call text ending at the `{`, imports of which the file must carry one, thread, basis)
# basis "crash" = a device crash proved it · "reading" = fixed after reading the SDK contract.

NETWORK_QUEUE = "<the queue passed to start(queue:)>"

FAMILIES = [
    (r"\bset(?:Event|Cancel|Registration)Handler\s*(?:\([^()]*\))?\s*$", None, "<the DispatchSource's queue>", "crash bebdfa8"),
    (r"\brequestMediaDataWhenReady\(\s*on:", ("AVFoundation", "AVFAudio"), "<the queue named by on:>", "crash 39dc05e"),
    (r"\bMIDI\w+CreateWith(?:Block|Protocol)\(", ("CoreMIDI",), "<CoreMIDI's own thread>", "crash bba1030"),
    (r"\bHK\w+Query\(", ("HealthKit",), "<HealthKit's background queue>", "crash 39ba753"),
    (r"\.(?:save|delete)\(", ("HealthKit",), "<HealthKit's background queue>", "crash 39ba753"),
    (r"\.updateHandler\s*=\s*$", ("HealthKit",), "<HealthKit's background queue>", "crash 39ba753"),
    (r"\.(?:resetHandler|stoppedHandler)\s*=\s*$", ("CoreHaptics",), "<CoreHaptics' own queue>", "reading a2b09f4"),
    (r"\.add(?:Completed|Scheduled)Handler\s*$", ("Metal", "MetalKit"), "<Metal's completion thread>", "reading e24db42"),
    (r"\.(?:save|delete|fetch)\(", ("CloudKit",), "<CloudKit's own queue>", "reading 8fb5c79"),
    (r"\bschedule(?:Buffer|Segment|File)\(", ("AVFoundation", "AVFAudio"), "<AVFAudio's completion thread>", "reading 8ddb0be"),
    (r"\binstallTap\(\s*onBus:", ("AVFoundation", "AVFAudio"), "<the audio engine's tap thread>", "reading"),
    (r"\bAVAudio(?:Source|Sink)Node\(", ("AVFoundation", "AVFAudio"), "<the audio render thread>", "reading"),
    (r"\.(?:stateUpdateHandler|newConnectionHandler|pathUpdateHandler|viabilityUpdateHandler|"
     r"betterPathUpdateHandler)\s*=\s*$", ("Network",), NETWORK_QUEUE, "reading"),
    (r"\.send\(\s*content:.*\.contentProcessed\s*$", ("Network",), NETWORK_QUEUE, "reading"),
    (r"\.receive(?:Message)?\s*(?:\([^()]*\))?\s*$", ("Network",), NETWORK_QUEUE, "reading"),
]
FAMILY_RES = [(re.compile(rx, re.S), imp, thread, basis) for rx, imp, thread, basis in FAMILIES]

# Closure parameters that run synchronously on the caller's thread, or Swift-native concurrency
# APIs the compiler checks statically. Neither can trap this way, so they are counted, not listed.
SYNC_OR_CHECKED = {
    "map", "compactMap", "flatMap", "filter", "forEach", "reduce", "sorted", "sort", "first", "last",
    "firstIndex", "lastIndex", "contains", "allSatisfy", "min", "max", "removeAll", "drop", "prefix",
    "split", "partition", "mapValues", "compactMapValues", "merge", "merging", "count", "sum",
    "withUnsafeBufferPointer", "withUnsafeMutableBufferPointer", "withUnsafeBytes",
    "withUnsafeMutableBytes", "withUnsafePointer", "withUnsafeMutablePointer", "withMemoryRebound",
    "withExtendedLifetime", "withLock", "sync", "autoreleasepool", "withCheckedContinuation",
    "withCheckedThrowingContinuation", "withUnsafeContinuation", "withUnsafeThrowingContinuation",
    "withTaskGroup", "withThrowingTaskGroup", "withDiscardingTaskGroup", "addTask", "Task",
    "detached", "run", "withTaskCancellationHandler", "AsyncStream", "AsyncThrowingStream",
    "Dictionary", "Set", "Array", "zip", "lazy", "enumerated", "indices", "stride", "joined",
    "removeFirst", "drop", "trimmingPrefix", "replaceSubrange", "init", "dropFirst", "dropLast",
    "max", "min", "withContiguousStorageIfAvailable", "assumeIsolated", "withObservationTracking",
    "onTermination",
}

# APIs that deliver on the main queue. SwiftUI's view builders and modifiers are `@MainActor`
# in the iOS 18 SDK; a run-loop timer created on the main actor fires on the main run loop.
MAIN_DELIVERY = {"withAnimation", "withTransaction", "animate", "performWithoutAnimation"}
# Main ONLY when the receiver is the main queue / run loop; the bare name proves nothing
# (`DispatchQueue.global().asyncAfter`, `context.perform`).
MAIN_RECEIVER = re.compile(r"(?:DispatchQueue\.main|OperationQueue\.main|RunLoop\.main)\s*\.\s*"
                           r"(?:async|asyncAfter|addOperation|perform)\s*(?:\([^()]*\))?\s*$")
SWIFTUI_NAMES = {
    "VStack", "HStack", "ZStack", "LazyVStack", "LazyHStack", "LazyVGrid", "LazyHGrid", "Grid",
    "GridRow", "ForEach", "Button", "Menu", "Section", "Group", "GeometryReader", "ScrollView",
    "ScrollViewReader", "List", "NavigationStack", "NavigationLink", "NavigationView",
    "TimelineView", "ViewThatFits", "Picker", "Toggle", "Label", "TabView", "Form",
    "DisclosureGroup", "ControlGroup", "Stepper", "Slider", "TextField", "SecureField",
    "ShareLink", "Link", "Canvas", "Layer", "ContextMenu", "ToolbarItem", "ToolbarItemGroup",
    "Alert", "ConfirmationDialog", "PhotosPicker", "Gauge", "ProgressView", "LabeledContent",
    "WindowGroup", "Settings", "CommandMenu", "CommandGroup", "Path", "AnyView", "Text",
    "DragGesture", "TapGesture", "LongPressGesture", "MagnificationGesture", "MagnifyGesture",
    "RotationGesture", "SpatialTapGesture", "ExclusiveGesture", "SimultaneousGesture",
}
SWIFTUI_MODIFIER = re.compile(
    r"^(on[A-Z]\w*|sheet|fullScreenCover|popover|alert|confirmationDialog|contextMenu|toolbar|"
    r"overlay|background|mask|task|refreshable|swipeActions|gesture|simultaneousGesture|"
    r"highPriorityGesture|updating|safeAreaInset|fileImporter|fileExporter|dropDestination|"
    r"draggable|accessibilityAction|accessibilityAdjustableAction|accessibilityRepresentation|"
    r"navigationDestination|searchable|photosPicker|transaction|animation|chartOverlay|"
    r"chartBackground|alignmentGuide|anchorPreference|backgroundPreferenceValue|"
    r"overlayPreferenceValue|scrollTargetLayout|visualEffect|focusedValue|"
    r"inspector|modifier|textSelection|keyboardShortcut|labelStyle|buttonStyle|"
    r"accessibility\w*|matchedGeometryEffect|transformEffect|sensoryFeedback|"
    r"containerRelativeFrame|containerBackground|scrollTransition|contentTransition|Gesture)$")

# Main-run-loop hops spelled through Dispatch or OperationQueue.
MAIN_QUEUE = re.compile(r"^(?:DispatchQueue\.main|OperationQueue\.main|RunLoop\.main|\.main)$")

# Hypotheses about SDK annotations. Printed with the site, never used as a verdict.
HYPOTHESES = [
    (re.compile(r"\.async\s*(?:\([^()]*\))?\s*$"),
     "the Dispatch overlay marks `async(execute:)` @Sendable"),
    (re.compile(r"\baddObserver\(\s*forName:"),
     "Foundation marks `addObserver(forName:object:queue:using:)` @Sendable; queue nil = posting thread"),
    (re.compile(r"\.sink\s*(?:\(|$)"),
     "Combine is not concurrency-annotated; `.sink` runs on the publisher's thread unless "
     "`.receive(on:)` moves it"),
    (re.compile(r"\brequestAccess\("), "AVFoundation marks `requestAccess(for:completionHandler:)` @Sendable"),
    (re.compile(r"\brequestAuthorization\("), "the framework marks `requestAuthorization` @Sendable"),
]


# ── Own declarations: our APIs are checked by the compiler ────────────────────────────────

def own_names(all_trees: dict[str, tuple[str, list[Node]]]) -> tuple[set[str], set[str]]:
    funcs, vars_ = set(), set()
    for code, _ in all_trees.values():
        funcs |= set(re.findall(r"\bfunc\s+([A-Za-z_]\w*)", code))
        funcs |= set(re.findall(r"\b(?:class|struct|enum|actor|protocol|typealias)\s+([A-Za-z_]\w*)", code))
        vars_ |= set(re.findall(r"\b(?:var|let)\s+([A-Za-z_]\w*)", code))
        vars_ |= set(re.findall(r"\bcase\s+([A-Za-z_]\w*)", code))
    return funcs, vars_


# ── Callee of a closure literal ───────────────────────────────────────────────────────────

def callee(code: str, n: Node) -> tuple[str, str, str]:
    """(call_text, last_name, shape) for the closure `n`; shape is trailing|arg|assign|stored|other."""
    h = n.h
    hstrip = h.strip()
    if re.search(r"(?:->|:)[^=]*=$", hstrip) and not re.search(r"\b(?:let|var)\b", hstrip):
        return flat(hstrip), "", "stored"          # a default argument value: `x: () -> Void = {`
    if n.why == "open" and (not hstrip or re.search(r"\w\s*:$", hstrip)):
        p = n.s - 1                                   # the unmatched `(`
        before = code[max(0, p - 200):p]
        m = re.search(r"([A-Za-z_][\w.?!]*)\s*(?:<[^<>]*>)?\s*$", before)
        name = m.group(1) if m else ""
        call = flat(before[-160:] + "(" + h)
        return call, re.split(r"[.?!]", name)[-1] if name else "", "arg"
    hs = h.rstrip()
    # A trailing closure INSIDE an argument list (`conn.send(content: d, completion: .x {`): the
    # header stops at the `(`, so the outer call is put back in front for the family match.
    prefix = ""
    if n.why == "open":
        prefix = flat(code[max(0, n.s - 161):n.s - 1]) + "("
    if n.why == "{":
        m = SIG_RE.match(hs)
        if m:
            hs = hs[m.end():]
    hs = hs.rstrip()
    # Bodies of earlier closures in the same statement say nothing about the callee.
    while True:
        stripped = re.sub(r"\{[^{}]*\}", "", hs)
        if stripped == hs:
            break
        hs = stripped
    hs = hs.rstrip()
    if n.why != "open" and re.search(r"[)\w:]\s+\w+\s*:$", hs):
        while re.search(r"[)\w:]\s+\w+\s*:$", hs):   # `f(…) { … } a: { … } b:` — the call is `f(…)`
            hs = re.sub(r"\s+\w+\s*:$", "", hs)
    elif n.why != "open" and re.search(r",\s*\w+\s*:$", hs):
        # `f(a: { … }, label:` reached through a skipped closure: the callee is before `(`.
        depth, p = 0, len(hs) - 1
        while p >= 0:
            if hs[p] == ")":
                depth += 1
            elif hs[p] == "(":
                if depth == 0:
                    break
                depth -= 1
            p -= 1
        m = re.search(r"([A-Za-z_][\w.?!]*)\s*(?:<[^<>]*>)?\s*$", hs[:p]) if p > 0 else None
        name = m.group(1) if m else ""
        return prefix + flat(hs), re.split(r"[.?!]", name)[-1] if name else "", "arg"
    if re.search(r"^(?:return|case\b[^:]*:\s*return)$|\?\?$|\s[?:]$|^\?$|^:$", hs.strip()):
        return prefix + flat(hs), "", "stored"   # a closure value: returned, coalesced, a ternary arm
    hs = re.sub(r"^\s*return\s+", "", hs)
    if re.search(r"(?:^|[^=!<>])=$", hs):
        if re.search(r"\b(?:let|var)\s+\w+\s*(?::[^=]*)?=$", hs):
            return prefix + flat(hs), "", "stored"
        m = re.search(r"([A-Za-z_]\w*)\s*=$", hs)
        return prefix + flat(hs), m.group(1) if m else "", "assign"
    if hs.endswith(")"):
        depth, p = 0, len(hs) - 1
        while p >= 0:
            if hs[p] == ")":
                depth += 1
            elif hs[p] == "(":
                depth -= 1
                if depth == 0:
                    break
            p -= 1
        m = re.search(r"([A-Za-z_][\w.?!]*)\s*(?:<[^<>]*>)?\s*$", hs[:p])
        name = m.group(1) if m else ""
        return prefix + flat(hs), re.split(r"[.?!]", name)[-1] if name else "", "trailing"
    m = re.search(r"([A-Za-z_][\w.?!]*)\s*(?:<[^<>]*>)?$", hs)
    if m and not re.search(r"\b(?:return|in|else|try|await)$", hs):
        name = m.group(1)
        return prefix + flat(hs), re.split(r"[.?!]", name)[-1], "trailing"
    return prefix + flat(hs), "", "other"


# ── Isolation of the context a closure is formed in ───────────────────────────────────────

def body_head(code: str, n: Node) -> str:
    return code[n.o + 1:n.o + 120].lstrip()


def context(code: str, n: Node, iso: dict[str, str]) -> tuple[str, str]:
    """('main'|'actor'|'none', why) for the closure `n`."""
    a = n.parent
    while a is not None:
        hh = flat(a.h)
        if a.k == "closure":
            head = body_head(code, a)
            if head.startswith("@Sendable"):
                return "none", "inside a @Sendable closure"
            if head.startswith("@MainActor"):
                return "main", "inside a @MainActor closure"
            if re.search(r"\bTask\.detached\b[^{]*$", hh):
                return "none", "inside Task.detached"
        elif a.k in ("func", "var", "acc"):
            if re.search(r"\bnonisolated\b", hh):
                return "none", "nonisolated member"
            if re.search(r"\bdeinit\b", hh):
                return "none", "deinit"
            if re.search(r"@MainActor\b", hh):
                return "main", "@MainActor member"
        elif a.k == "type":
            m = TYPE_RE.match(a.h.strip())
            if not m:
                return "none", "unparsed type"
            kw, name = m.group(1), m.group(2).split(".")[-1]
            if kw == "actor":
                return "actor", f"actor {name}"
            if re.search(r"@MainActor\b", hh):
                return "main", f"@MainActor {kw} {name}"
            if kw != "extension":
                parents = _inherits(a.h)
                hit = [p for p in parents if p in MAIN_PROTOCOLS or p in MAIN_SUPERS or iso.get(p) == "main"]
                if hit:
                    return "main", f"{kw} {name}: {hit[0]}"
                assumed = [p for p in parents if p in ASSUMED_MAIN_PROTOCOLS]
                if assumed:
                    return "main", f"{kw} {name}: {assumed[0]} (assumed main — SDK annotation not read)"
            if iso.get(name) in ("main", "actor"):
                return iso[name], f"{kw} {name} ({iso[name]})"
            return "none", f"{kw} {name}"
        a = a.parent
    return "none", "global"


# ── Verdict for one listed site ───────────────────────────────────────────────────────────

def _imports(raw: str) -> set[str]:
    # `[ \t]` and an explicit kind list on purpose: with `\s+` and `(?:\w+\s+)?`, the line
    # `import Foundation` swallowed the NEXT line's `import` as its "kind" word, so a file with
    # two adjacent imports lost the second one (ArtNetSender lost `Network`).
    return set(re.findall(r"^[ \t]*(?:@\w+[ \t]+)?import[ \t]+"
                          r"(?:(?:typealias|struct|class|enum|protocol|let|var|func)[ \t]+)?(\w+)", raw, re.M))


def _dispatch_queue(code: str, n: Node, receiver: str) -> str | None:
    """The `queue:` the DispatchSource `receiver` was made with, read in the enclosing body."""
    a = n.parent
    while a is not None and a.k == "closure":
        a = a.parent
    scope = code[a.o:n.o] if a is not None else code[:n.o]
    ms = list(re.finditer(re.escape(receiver) + r"\s*=\s*DispatchSource\.make\w+Source\(([^)]*)\)", scope))
    if not ms:
        return None
    q = re.search(r"queue:\s*([^,)\s]+)", ms[-1].group(1))
    return q.group(1) if q else "<no queue: — a global queue>"


# ── Publishers: on which thread does a Combine `.sink` / SwiftUI `.onReceive` action run? ──

POSTERS: dict[str, list[tuple[str, int, str]]] = {}     # notification name → (file, line, context)


def collect_posters(all_trees: dict[str, tuple[str, list[Node]]], iso: dict[str, str]) -> None:
    """Every `post(name: .x` in Sources/, with the isolation of the code that posts it."""
    POSTERS.clear()
    for f, (code, nodes) in all_trees.items():
        for m in re.finditer(r"\bpost\(\s*name:\s*\.?([A-Za-z_]\w*)", code):
            inner = None
            for nd in nodes:
                if nd.o < m.start() < nd.c and (inner is None or nd.o > inner.o):
                    inner = nd
            probe = Node(m.start(), m.start(), m.start(), "nl", "", "closure")
            probe.parent = inner
            ctx, _ = context(code, probe, iso)
            POSTERS.setdefault(m.group(1), []).append((f, code.count("\n", 0, m.start()) + 1, ctx))


def publisher_thread(chain: str, scope: str, hops: int = 1) -> tuple[str | None, str]:
    """(main|None, why) for the publisher spelled in `chain` (one hop through a local `let`)."""
    if re.search(r"\.receive\(\s*on:\s*(?:DispatchQueue\.main|RunLoop\.main|\.main)\s*\)", chain):
        return "main", "receive(on: main)"
    if re.search(r"\bTimer\.publish\([^)]*\bon:\s*(?:\.main|RunLoop\.main)\b", chain):
        return "main", "Timer.publish on the main run loop"
    m = re.search(r"\bpublisher\(\s*for:\s*([\w.]+)", chain)
    if m:
        note = m.group(1)
        short = note.split(".")[-1]
        posts = POSTERS.get(short, [])
        if posts and all(ctx == "main" for _, _, ctx in posts):
            return "main", f"all {len(posts)} post(name: .{short}) sites are on the main actor"
        if posts:
            off = [f"{f.split('/')[-1]}:{ln}" for f, ln, ctx in posts if ctx != "main"]
            return None, f"post(name: .{short}) off the main actor at {', '.join(off[:3])}"
        if note.startswith("UIApplication.") or note.startswith("UIScene."):
            return None, f"hypothesis: UIKit posts {note} on the main thread"
        return None, f"{note} is posted by the system on a thread this script cannot read"
    if hops:
        recv = re.search(r"([A-Za-z_]\w*)\s*\.\s*(?:sink|receive)\b", chain) or \
            re.search(r"onReceive\(\s*([A-Za-z_]\w*)\s*[,)]", chain)
        if recv:
            mm = list(re.finditer(r"\b(?:let|var)\s+" + re.escape(recv.group(1)) + r"\b[^=\n]*=([^\n]*(?:\n\s*\.[^\n]*)*)", scope))
            if mm:
                return publisher_thread(mm[-1].group(1), scope, hops - 1)
            mm = re.search(r"\bvar\s+" + re.escape(recv.group(1)) + r"\b[^{]*\{\s*([^{}]*)", scope)
            if mm:
                return publisher_thread(mm.group(1), scope, hops - 1)
    return None, "the publisher's thread is not spelled at the call"


def verdict(code: str, raw_imports: set[str], n: Node, call: str, name: str, shape: str,
            funcs: set[str], vars_: set[str], ctx: str = "main") -> tuple[str, str, str] | None:
    """(VERDICT, thread, note), or None when the site is not listed (our own API, sync, …)."""
    sendable = body_head(code, n).startswith("@Sendable")
    tail = call[-240:]
    if ("Combine" in raw_imports and re.search(r"\.sink\s*(?:\([^()]*\))?\s*$", tail)) or \
            re.search(r"\.onReceive\(", tail[-160:]):
        # Scope for the one-hop `let x = publisher` lookup: the enclosing TYPE, because a View
        # keeps its timer publisher as a stored property outside `body`.
        a = n.parent
        while a is not None and a.k != "type":
            a = a.parent
        scope = code[a.o:a.c] if a is not None else code
        # The chain is THIS call's only: a view stacks several `.onReceive(…)` modifiers, and
        # the first draft read the first one for every closure.
        window = code[max(0, n.s - 600):n.o]
        if re.search(r"\.onReceive\(", tail[-160:]):
            chain = window[window.rfind(".onReceive("):]
        else:
            chain = code[n.s:n.o]
        thread, why = publisher_thread(chain, scope)
        if thread == "main":
            return "SAFE-ON-MAIN", "<main>", why
        if sendable:
            return "SAFE-BY-SENDABLE", "<publisher's thread>", why
        return "NEEDS-SDK-READING", "<publisher's thread>", why
    for rx, imp, thread, basis in FAMILY_RES:
        if rx.search(tail) and (imp is None or any(i in raw_imports for i in imp)):
            q = None
            if "setEventHandler" in tail or "setCancelHandler" in tail or "setRegistrationHandler" in tail:
                recv = re.search(r"([A-Za-z_]\w*)\s*\.\s*set\w+Handler", tail)
                q = _dispatch_queue(code, n, recv.group(1)) if recv else None
                thread = q or "<no DispatchSource.make…Source( for this receiver in scope>"
            if thread == NETWORK_QUEUE:
                # Network calls every handler of a connection or listener on the queue its
                # `start(queue:)` named. The receiver is often started in another function
                # (an accepted connection), so the rule is file-wide and stated as such:
                # every `start(queue:)` in this file names the same queue.
                starts = set(re.findall(r"\.start\(\s*queue:\s*([^,)\s]+)\s*\)", code))
                if len(starts) == 1:
                    q = starts.pop()
                    thread = f"{q} (every start(queue:) in this file)"
            mq = re.search(r"\b(?:on|queue):\s*([^,)\s]+)", tail)
            if q is None and mq and "requestMediaDataWhenReady" in tail:
                q = mq.group(1)
                thread = q
            if q and MAIN_QUEUE.match(q):
                return "SAFE-ON-MAIN", q, f"family: {basis}"
            if sendable:
                return "SAFE-BY-SENDABLE", thread, f"family: {basis}"
            return "TRAPS-ON-WORKER", thread, f"family: {basis}"
    if shape in ("stored", "other") or not name:
        return None
    if shape == "assign":
        if name in vars_:
            return None
    else:
        if name in funcs or name in SYNC_OR_CHECKED or name in vars_:
            return None
        if name in SWIFTUI_NAMES or SWIFTUI_MODIFIER.match(name) or name in MAIN_DELIVERY:
            return ("SAFE-BY-SENDABLE" if sendable else "SAFE-ON-MAIN"), "<main>", "SwiftUI/main delivery"
        if MAIN_RECEIVER.search(tail):
            return ("SAFE-BY-SENDABLE" if sendable else "SAFE-ON-MAIN"), "<main>", "main queue"
        if name == "scheduledTimer" and ctx == "main":
            # A timer scheduled from the main actor runs on the main run loop.
            return ("SAFE-BY-SENDABLE" if sendable else "SAFE-ON-MAIN"), "<main run loop>", "scheduled from main"
    mq = re.search(r"\bqueue:\s*([^,)\s]+)", tail)
    if mq and MAIN_QUEUE.match(mq.group(1)):
        return ("SAFE-BY-SENDABLE" if sendable else "SAFE-ON-MAIN"), mq.group(1), "queue: main"
    if sendable:
        return "SAFE-BY-SENDABLE", "<unknown>", ""
    note = ""
    for rx, text in HYPOTHESES:
        if rx.search(tail):
            note = "hypothesis: " + text
            if text.startswith("Combine") and re.search(r"\.receive\(\s*on:\s*(?:DispatchQueue\.main|RunLoop\.main)", code[max(0, n.s - 400):n.o]):
                return "SAFE-ON-MAIN", "receive(on: main)", "Combine hop to main"
            break
    return "NEEDS-SDK-READING", "<unknown>", note


# ── Scan ──────────────────────────────────────────────────────────────────────────────────

_PARSED: dict[str, tuple[str, list[Node]]] = {}


def scan(rev: str | None, only: list[str] | None = None) -> tuple[list[dict], dict[str, int]]:
    raws_all = read_all(rev)
    files = sorted(raws_all)
    all_trees, raws = {}, {}
    for f in files:
        raw = raws_all[f]
        if raw not in _PARSED:                    # adjacent revisions share almost every file
            code = doctor._code_only(raw, blank_strings=True)
            _PARSED[raw] = (code, tree(code))
        all_trees[f] = _PARSED[raw]
        raws[f] = raw
    iso = type_isolation(all_trees)
    funcs, vars_ = own_names(all_trees)
    collect_posters(all_trees, iso)
    sites, counts = [], {"closures": 0, "isolated": 0, "nonisolated": 0, "own-or-sync": 0, "stored": 0,
                         "undetermined": 0}
    for f in (only or files):
        if f not in all_trees:
            continue
        code, nodes = all_trees[f]
        imps = _imports(raws[f])
        for n in nodes:
            if n.k != "closure":
                continue
            counts["closures"] += 1
            ctx, why = context(code, n, iso)
            if ctx == "none":
                counts["nonisolated"] += 1
                continue
            counts["isolated"] += 1
            call, name, shape = callee(code, n)
            if shape == "stored":
                counts["stored"] += 1
                continue
            v = verdict(code, imps, n, call, name, shape, funcs, vars_, ctx)
            if v is None:
                counts["undetermined" if shape == "other" or not name else "own-or-sync"] += 1
                continue
            line = code.count("\n", 0, n.o) + 1
            sites.append({"verdict": v[0], "file": f, "line": line, "owner": why,
                          "api": call[-70:], "call": call, "thread": v[1], "note": v[2], "name": name})
    return sites, counts


ORDER = ["TRAPS-ON-WORKER", "NEEDS-SDK-READING", "SAFE-ON-MAIN", "SAFE-BY-SENDABLE"]


def report(sites: list[dict], counts: dict[str, int], show_all: bool, label: str) -> int:
    by = {k: [s for s in sites if s["verdict"] == k] for k in ORDER}
    print(f"isolation-inventory ({label}): {counts['closures']} closure literal(s); "
          f"{counts['isolated']} formed in an isolated context, {counts['nonisolated']} not.")
    print(f"  of the isolated ones: {counts['own-or-sync']} go to our own API or run synchronously "
          f"(counted, not listed) · {counts['stored']} stored closures, not followed · "
          f"{counts['undetermined']} with no callee the parser could name.")
    for k in ORDER:
        print(f"  {k:18} {len(by[k])}")
    for k in ORDER:
        if not by[k] or (k.startswith("SAFE") and not show_all):
            continue
        print(f"\n── {k}")
        for s in by[k]:
            print(f"  {s['file']}:{s['line']}  [{s['owner']}]")
            print(f"      api: …{s['api']}")
            print(f"      thread: {s['thread']}" + (f" · {s['note']}" if s["note"] else ""))
    if not show_all and (by["SAFE-ON-MAIN"] or by["SAFE-BY-SENDABLE"]):
        print("\n  (SAFE-* sites hidden; --all prints them.)")
    return 1 if by["TRAPS-ON-WORKER"] else 0


# ── Selftest: the eight historic sites, before and after their fix ────────────────────────

HISTORY = [
    ("bebdfa8", "Sources/Echoelmusic/Audio/RetroCapture.swift", "setEventHandler"),
    ("39dc05e", "Sources/Echoelmusic/Audio/SingleExport.swift", "requestMediaDataWhenReady"),
    ("bba1030", "Sources/Echoelmusic/Audio/MIDIInput.swift", "MIDI"),
    ("39ba753", "Sources/Echoelmusic/Bio/EchoelBioEngine.swift", "Query"),
    ("39ba753", "Sources/Echoelmusic/Bio/HealthKitWriter.swift", "save"),
    ("a2b09f4", "Sources/Echoelmusic/Studio/HapticEngine.swift", "Handler"),
    ("e24db42", "Sources/Echoelmusic/Views/MetalBioView.swift", "addCompletedHandler"),
    ("8fb5c79", "Sources/Echoelmusic/Sync/AnnouncementCenter.swift", "."),
    ("8ddb0be", "Sources/Echoelmusic/Sequencer/AudioClipPlayer.swift", "schedule"),
]


def selftest() -> int:
    failures = 0
    for sha, path, token in HISTORY:
        try:
            before, _ = scan(f"{sha}^", only=[path])
            after, _ = scan(sha, only=[path])
        except subprocess.CalledProcessError:
            print(f"  ⛔ {sha} {path}: the commit or its parent is not in this clone — INCONCLUSIVE")
            failures += 1
            continue
        trapped = [s for s in before if s["verdict"] == "TRAPS-ON-WORKER" and token in s["call"]]
        still = [s for s in after if s["verdict"] == "TRAPS-ON-WORKER" and token in s["call"]]
        ok = bool(trapped) and not still
        failures += not ok
        print(f"  {'✅' if ok else '❌'} {sha} {path.split('/')[-1]}: parent lists "
              f"{len(trapped)} TRAPS-ON-WORKER ({', '.join(str(s['line']) for s in trapped) or '-'}), "
              f"the fix leaves {len(still)}")
    print(f"selftest: {len(HISTORY) - failures}/{len(HISTORY)} historic sites are found before "
          f"their fix and cleared after it.")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true", help="also print SAFE-* sites")
    ap.add_argument("--rev", help="read Sources/ at this commit instead of the worktree")
    ap.add_argument("--selftest", action="store_true", help="the eight historic sites, before and after")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    try:
        sites, counts = scan(args.rev)
    except (subprocess.CalledProcessError, OSError) as exc:
        print(f"⛔ INSTRUMENT UNAVAILABLE — {exc}")
        return 2
    if counts["closures"] == 0:
        print("⛔ INSTRUMENT UNAVAILABLE — no closure literal found; a parser that matches nothing "
              "is a finding, never a pass (.claude/rules/context.md §2).")
        return 2
    return report(sites, counts, args.all, args.rev or "worktree")


if __name__ == "__main__":
    sys.exit(main())
