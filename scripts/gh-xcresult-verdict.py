#!/usr/bin/env python3
"""Read the COMPLETE result of a CI/CD test run — the uploaded .xcresult — and name every
red, skipped and missing test, with file:line and message.

WHY THIS EXISTS (W-RED, 2026-11-01). `gh-test-verdict.py` reads the JOB LOG, and the job log
is `tail -200 test.log` (#807): a test that fails earlier in the run leaves no trace there.
`auto-merge-claude.yml` reads only the `Build for Testing` step. Between the two, nothing read
the test results at all — W-MAP measured 30 red tests in `Tests/CISmoke` from the artifact of
run 41314108847 (`aa1083050`), and none of them had stopped a merge. The complete results were
always there: `ci.yml` runs `xcodebuild test-without-building … -resultBundlePath TestResults`
and uploads that directory as the artifact `test-results-ios-<device>` — the cheap shape #807
named. This tool reads it.

THE FORMAT, MEASURED (xcresult 3.56, storage `fileBacked2`, compression `standard`) — Apple
does not document it, so every rule here was checked against two real bundles:
  · `Info.plist` → `rootId.hash` names the root object. Every object lives in
    `Data/data.<id>`, zstd-compressed (magic 28 B5 2F FD) or stored raw.
  · An object is a token stream: `[` TYPE FIELD* `]`. TYPE is `T[K2:_nV<n>:<Name>]` the first
    time a name occurs (a supertype hangs off it as `K2:_s[…]`) and `S<n>:<Name>` after. A
    FIELD is `K<n>:<key>` + an object; a scalar holds `K2:_v` + `V<n>:<text>`; an array holds
    its elements as bare objects. ⚠️ Every <n> counts BYTES of UTF-8, not characters —
    measured: failure messages carrying `—` and `×` parse to the exact end of their blob only
    with byte counts, and `--selftest` keeps a multi-byte message in its fixture so a
    character-counting rewrite goes red there instead of mis-reading a real run.
  · ActionsInvocationRecord.actions[].actionResult.testsRef → ActionTestPlanRunSummaries →
    summaries[].testableSummaries[].tests[] → ActionTestSummaryGroup.subtests[] (nested) →
    ActionTestMetadata{identifier, testStatus, summaryRef}. A red test's summaryRef holds
    ActionTestSummary.failureSummaries[]{fileName, lineNumber, message}; a skipped one's holds
    skipNoticeSummary. Only those blobs are decompressed — a bundle has ~12 000.

THREE VERDICTS, and the third is the one a job log can never give:
  · FAILED  — any status that is not a pass ("Failure", and anything unknown).
  · SKIPPED — a skip asserted nothing; `gh-test-verdict.py` exits 1 on it for the same reason
    (#806): every `XCTSkip` in this bundle guards an anchor.
  · MISSING — declared in `Tests/CISmoke` at the run's commit and absent from the result. On
    run 41211998467 (`2b2aa0735`) the test runner hung before one test connected; that test
    has NO entry in the tree at all, only a line in the bundle's error summaries. Counting
    only what the result contains would have called that run complete (#445: absence proves
    nothing — so it must be checked against the declarations, not inferred).
    The check needs the commit in this clone; when it is not, the line says so and the exit
    code does not pretend it ran.

Usage:
  python3 scripts/gh-xcresult-verdict.py <run-id>         download the artifact with `gh`
  python3 scripts/gh-xcresult-verdict.py --sha <commit>   newest CI/CD run of that commit
  python3 scripts/gh-xcresult-verdict.py <dir|zip> [--commit <sha>]   a bundle already here
  python3 scripts/gh-xcresult-verdict.py --selftest
Options: --full (whole messages) · --names (one machine-readable line per non-passing test,
for `diff` between two runs) · --keep <dir> (keep the download) · --repo <owner/name>.
Exit 0 = every test passed and none is missing, 1 = something failed, skipped or is
missing, 2 = INSTRUMENT UNAVAILABLE (no zstd, no artifact, unreadable bundle, no tests found)
— a 2 says nothing about the repo.

zstd: Python ≥ 3.14 has it (`compression.zstd`); otherwise the hashed `zstandard` pin in
`scripts/requirements-pipeline.txt`, otherwise a `zstd` binary on PATH. A pipeline tool only —
nothing here ships in either app.
"""
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

REPO = "vibrationalforce/Echoelmusic"
WORKFLOW = "ci.yml"
ARTIFACT_PREFIX = "test-results-ios-"
ZSTD_MAGIC = b"\x28\xb5\x2f\xfd"
SUITE_DIR = "Tests/CISmoke"
INSTALL_HINT = ("python3 -m pip install --require-hashes -r scripts/requirements-pipeline.txt "
                "(repo root; installs `zstandard`), or Python >= 3.14, or a `zstd` binary")


class Unavailable(Exception):
    """The instrument cannot answer — never a statement about the tests."""


# ── zstd, from whichever backend exists ─────────────────────────────────────────────────────

def _backend():
    try:
        from compression import zstd as stdlib_zstd  # Python >= 3.14
        return "compression.zstd", stdlib_zstd.decompress
    except ImportError:
        pass
    try:
        import zstandard
    except ImportError:
        zstandard = None
    if zstandard is not None:
        def via_zstandard(raw):
            # One decompressobj per frame: `ZstdDecompressor().decompress()` refuses a frame
            # without a content size, and a blob may hold more than one frame.
            out = []
            while raw:
                obj = zstandard.ZstdDecompressor().decompressobj()
                out.append(obj.decompress(raw))
                raw = obj.unused_data
            return b"".join(out)
        return "zstandard", via_zstandard
    if shutil.which("zstd"):
        def via_cli(raw):
            done = subprocess.run(["zstd", "-dcq"], input=raw, capture_output=True)
            if done.returncode != 0:
                raise ValueError(done.stderr.decode(errors="replace").strip())
            return done.stdout
        return "zstd binary", via_cli
    return None, None


# ── The object encoding ─────────────────────────────────────────────────────────────────────

class Parser:
    """Recursive reader for one decompressed object blob (grammar in the module docstring)."""

    def __init__(self, data):
        self.b = data
        self.i = 0

    def _counted(self, tag):
        if self.b[self.i:self.i + 1] != tag:
            raise ValueError(f"expected {tag!r} at byte {self.i}: {self.b[self.i:self.i + 32]!r}")
        colon = self.b.index(b":", self.i)
        n = int(self.b[self.i + 1:colon])
        end = colon + 1 + n
        if end > len(self.b):
            raise ValueError(f"length {n} at byte {self.i} runs past the blob end")
        self.i = end
        return self.b[colon + 1:end].decode("utf-8")

    def _type_spec(self):
        if self.b[self.i:self.i + 1] != b"[":
            raise ValueError(f"expected a type spec at byte {self.i}")
        self.i += 1
        name = None
        while self.b[self.i:self.i + 1] != b"]":
            key = self._counted(b"K")
            if key == "_n":
                name = self._counted(b"V")
            elif key == "_s":
                self._type_spec()           # the supertype — read and dropped
            else:
                raise ValueError(f"unknown type-spec key {key!r} at byte {self.i}")
        self.i += 1
        return name

    def node(self):
        if self.b[self.i:self.i + 1] != b"[":
            raise ValueError(f"expected an object at byte {self.i}")
        self.i += 1
        tag = self.b[self.i:self.i + 1]
        if tag == b"T":
            self.i += 1
            kind = self._type_spec()
        elif tag == b"S":
            kind = self._counted(b"S")
        else:
            raise ValueError(f"expected T or S at byte {self.i}: {self.b[self.i:self.i + 32]!r}")
        out = {"_t": kind}
        items = []
        while self.b[self.i:self.i + 1] != b"]":
            if self.i >= len(self.b):
                raise ValueError("blob ended inside an object")
            if self.b[self.i:self.i + 1] == b"K":
                key = self._counted(b"K")
                if key == "_v":
                    out["_v"] = self._counted(b"V")
                else:
                    out[key] = self.node()
            else:
                items.append(self.node())
        self.i += 1
        if items:
            out["_items"] = items
        return out

    def whole(self):
        top = self.node()
        if self.i != len(self.b):
            raise ValueError(f"{len(self.b) - self.i} trailing bytes after the object")
        return top


def text(n, *path):
    """`text(node, "a", "b")` → node["a"]["b"]["_v"], or None anywhere along the way."""
    for key in path:
        if not isinstance(n, dict) or key not in n:
            return None
        n = n[key]
    return n.get("_v") if isinstance(n, dict) else None


def items(n, key):
    child = n.get(key) if isinstance(n, dict) else None
    return child.get("_items", []) if isinstance(child, dict) else []


class Bundle:
    def __init__(self, path, decompress):
        self.path = path
        self.decompress = decompress
        try:
            with open(os.path.join(path, "Info.plist"), "rb") as fh:
                self.info = plistlib.load(fh)
            self.root_id = self.info["rootId"]["hash"]
        except (OSError, KeyError, plistlib.InvalidFileException) as exc:
            raise Unavailable(f"{path} is not an .xcresult bundle ({exc})")

    def load(self, ident):
        blob_path = os.path.join(self.path, "Data", "data." + ident)
        try:
            with open(blob_path, "rb") as fh:
                raw = fh.read()
        except OSError:
            raise Unavailable(f"object {ident[:16]}… is missing from {self.path}/Data")
        if raw[:4] == ZSTD_MAGIC:
            if self.decompress is None:
                raise Unavailable("the bundle is zstd-compressed and no zstd backend exists — "
                                  + INSTALL_HINT)
            try:
                raw = self.decompress(raw)
            except Exception as exc:  # any backend's error type
                raise Unavailable(f"object {ident[:16]}… does not decompress ({exc})")
        try:
            return Parser(raw).whole()
        except (ValueError, UnicodeDecodeError) as exc:
            raise Unavailable(f"object {ident[:16]}… does not parse ({exc})")


# ── From the object graph to verdicts ──────────────────────────────────────────────────────

PASSING = {"Success", "Expected Failure"}
RANK = {"Success": 0, "Expected Failure": 1, "Skipped": 2}   # anything else ranks as a failure


def display(identifier):
    """`Suite/testName()` → `Suite.testName` (the spelling the job log and W-MAP's list use)."""
    return identifier.replace("()", "").replace("/", ".")


def repo_path(path):
    """`/Users/runner/work/Echoelmusic/Echoelmusic/Tests/…` → `Tests/…`."""
    return re.sub(r"^.*?/work/[^/]+/[^/]+/", "", path or "")


def read_results(bundle):
    root = bundle.load(bundle.root_id)
    actions = items(root, "actions")
    test_actions = [a for a in actions if isinstance(a.get("actionResult"), dict)
                    and "testsRef" in a["actionResult"]]
    errors = [text(e, "message") or "" for e in items(root.get("issues", {}), "errorSummaries")]
    issue_lists = [items(root.get("issues", {}), "testFailureSummaries")]
    tests = {}
    statuses = []
    for action in test_actions:
        result = action["actionResult"]
        statuses.append(text(result, "status") or "?")
        errors += [text(e, "message") or "" for e in items(result.get("issues", {}),
                                                            "errorSummaries")]
        issue_lists.append(items(result.get("issues", {}), "testFailureSummaries"))
        tests_id = text(result, "testsRef", "id")
        if not tests_id:
            raise Unavailable("a test action carries no testsRef id")
        plan = bundle.load(tests_id)
        stack = [plan]
        while stack:
            n = stack.pop()
            if not isinstance(n, dict):
                continue
            if n.get("_t") == "ActionTestMetadata":
                ident = text(n, "identifier") or "?"
                status = text(n, "testStatus") or "Unknown"
                ref = text(n, "summaryRef", "id")
                old = tests.get(ident)
                if old is None or RANK.get(status, 9) > RANK.get(old[0], 9):
                    tests[ident] = (status, ref)
                continue
            for key, value in n.items():
                if key == "_items":
                    stack.extend(value)
                elif not key.startswith("_"):
                    stack.append(value)
    # The issue list is the fallback for a red test whose summary object is gone.
    by_case = {}
    for issues in issue_lists:
        for issue in issues:
            case = (text(issue, "testCaseName") or "").replace("()", "")
            url = text(issue, "documentLocationInCreatingWorkspace", "url") or ""
            m = re.search(r"StartingLineNumber=(\d+)", url)
            where = repo_path(url.replace("file://", "").split("#")[0])
            # DVTTextDocumentLocation counts lines from 0 (measured: 86 here, 87 in the summary).
            line = int(m.group(1)) + 1 if m else 0
            by_case.setdefault(case, []).append((where, line, text(issue, "message") or ""))
    # The root and the action both carry the run's error summaries; say each once.
    return tests, statuses, list(dict.fromkeys(e for e in errors if e)), by_case


def details(bundle, ident, status, ref, by_case):
    """[(file, line, message)] for one non-passing test."""
    found = []
    if ref:
        try:
            summary = bundle.load(ref)
        except Unavailable:
            summary = None
        if summary is not None:
            notices = items(summary, "failureSummaries")
            if status == "Skipped" and isinstance(summary.get("skipNoticeSummary"), dict):
                notices = [summary["skipNoticeSummary"]]
            for f in notices:
                found.append((repo_path(text(f, "fileName")), int(text(f, "lineNumber") or 0),
                              text(f, "message") or ""))
    if not found:
        found = by_case.get(display(ident), [])
    return found


# ── MISSING: declared at the run's commit, absent from the result ──────────────────────────

CLASS_DECL = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:public\s+|open\s+|internal\s+)?"
                        r"(?:final\s+)?class\s+(\w+)\s*:\s*XCTestCase\b")
# XCTest runs an instance method named test… that takes NO argument and is visible to the
# runtime — so `private`, `static` and any parameter list are not tests, and stay out.
TEST_DECL = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:override\s+)?func\s+(test\w*)\s*\(\s*\)")
# The same two shapes for `git grep -E`, in POSIX classes: `\s`/`\w` are GNU extensions that
# BSD regex (the founder's Mac) does not promise. Python refines every hit with the two above.
GREP_DECL = (r"class[[:space:]]+[[:alnum:]_]+[[:space:]]*:[[:space:]]*XCTestCase"
             r"|func[[:space:]]+test[[:alnum:]_]*[[:space:]]*\(")


def declared_tests(grep_lines):
    """`path:line:text` lines (a `git grep -n` over the suite) → {"Suite/testName"}.

    Each `func test…(` belongs to the nearest XCTestCase subclass ABOVE it in its file.
    Measured on `aa1083050`: 5 864 declaration lines, 5 863 distinct names, and the result of
    its run held exactly those 5 863 (one name is declared twice in one file)."""
    by_file = {}
    for raw in grep_lines:
        parts = raw.split(":", 2)
        if len(parts) == 3 and parts[1].isdigit():
            by_file.setdefault(parts[0], []).append((int(parts[1]), parts[2]))
    out = set()
    for rows in by_file.values():
        suite = None
        for _, line in sorted(rows):
            c = CLASS_DECL.match(line)
            if c:
                suite = c.group(1)
                continue
            f = TEST_DECL.match(line)
            if f and suite:
                out.add(f"{suite}/{f.group(1)}")
    return out


def declared_at(commit):
    """Declared tests of `Tests/CISmoke` at `commit` in this clone, or (None, reason)."""
    top = git_root()
    if top is None:
        return None, "not inside a git clone"
    if subprocess.run(["git", "-C", top, "cat-file", "-e", f"{commit}^{{commit}}"],
                      capture_output=True).returncode != 0:
        return None, f"commit {commit[:9]} is not in this clone (`git fetch origin {commit}`)"
    done = subprocess.run(["git", "-C", top, "grep", "-n", "-E", GREP_DECL, commit, "--",
                           f"{SUITE_DIR}/*.swift"], capture_output=True, text=True)
    if done.returncode not in (0, 1):
        return None, f"git grep failed: {done.stderr.strip()[:120]}"
    lines = [ln.split(":", 1)[1] for ln in done.stdout.splitlines() if ":" in ln]
    found = declared_tests(lines)
    if not found:
        return None, f"no test declaration found in {SUITE_DIR} at {commit[:9]} — a parser " \
                     "that matches nothing is a finding, not a pass"
    return found, None


def git_root():
    here = os.path.dirname(os.path.abspath(__file__))
    done = subprocess.run(["git", "-C", here, "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True)
    return done.stdout.strip() if done.returncode == 0 else None


# ── Getting a bundle onto disk ──────────────────────────────────────────────────────────────

def gh_json(args):
    if shutil.which("gh") is None:
        raise Unavailable("`gh` is not installed")
    done = subprocess.run(["gh"] + args, capture_output=True, text=True)
    if done.returncode != 0:
        raise Unavailable(f"gh {' '.join(args[:3])}… failed: {done.stderr.strip()[:200]}")
    return json.loads(done.stdout or "null")


def run_for_sha(sha, repo):
    runs = gh_json(["run", "list", "-R", repo, "--workflow", WORKFLOW, "--commit", sha,
                    "--json", "databaseId,status,conclusion,createdAt", "-L", "20"]) or []
    if not runs:
        raise Unavailable(f"no {WORKFLOW} run for {sha[:9]} — did the commit touch a path "
                          "that triggers it (Sources/, Tests/, Package.swift, project.yml)?")
    runs.sort(key=lambda r: r["createdAt"], reverse=True)
    return str(runs[0]["databaseId"])


def download(run_id, repo, into):
    """→ (head_sha, run_status, [(artifact_name, dir)])."""
    run = gh_json(["api", f"repos/{repo}/actions/runs/{run_id}"])
    arts = gh_json(["api", f"repos/{repo}/actions/runs/{run_id}/artifacts"])
    names = [a["name"] for a in arts.get("artifacts", [])
             if a["name"].startswith(ARTIFACT_PREFIX) and not a.get("expired")]
    if not names:
        raise Unavailable(f"run {run_id} ({run.get('status')}) has no unexpired "
                          f"`{ARTIFACT_PREFIX}*` artifact — still running, never reached the "
                          "test step, or older than the retention window")
    out = []
    for name in sorted(names):
        target = os.path.join(into, re.sub(r"[^\w.-]+", "_", name))
        done = subprocess.run(["gh", "run", "download", run_id, "-R", repo, "-n", name,
                               "-D", target], capture_output=True, text=True)
        if done.returncode != 0:
            raise Unavailable(f"download of `{name}` failed: {done.stderr.strip()[:200]}")
        out.append((name, target))
    return run.get("head_sha", ""), f"{run.get('status')}/{run.get('conclusion')}", out


def locate(path, scratch):
    """A bundle directory, a folder holding one, or the artifact zip → the bundle directory."""
    if os.path.isfile(path) and zipfile.is_zipfile(path):
        target = os.path.join(scratch, "unzipped")
        with zipfile.ZipFile(path) as zf:
            for member in zf.namelist():
                dest = os.path.realpath(os.path.join(target, member))
                if not dest.startswith(os.path.realpath(target) + os.sep):
                    raise Unavailable(f"{path} holds a path outside its folder: {member}")
            zf.extractall(target)
        path = target
    for candidate, _, files in os.walk(path):
        if "Info.plist" in files and os.path.isdir(os.path.join(candidate, "Data")):
            return candidate
    raise Unavailable(f"no .xcresult (Info.plist + Data/) under {path}")


# ── Report ─────────────────────────────────────────────────────────────────────────────────

def report(bundle, label, commit, full, names_only, out=print):
    tests, statuses, errors, by_case = read_results(bundle)
    if not tests:
        raise Unavailable(f"{label}: the bundle holds no test result at all — a parser that "
                          "matches nothing is a finding, not a pass")
    by_status = {}
    for ident, (status, _) in tests.items():
        by_status.setdefault(status, []).append(ident)
    failed = sorted(i for i, (s, _) in tests.items() if s not in PASSING and s != "Skipped")
    skipped = sorted(by_status.get("Skipped", []))
    declared, why_not = (declared_at(commit) if commit else (None, "no commit given (--commit)"))
    present = {i.replace("()", "") for i in tests}
    missing = sorted(declared - present) if declared is not None else []

    if names_only:
        for i in failed:
            out(f"FAILED {display(i)}")
        for i in skipped:
            out(f"SKIPPED {display(i)}")
        for i in missing:
            out(f"MISSING {display(i)}")
        return 1 if (failed or skipped or missing) else 0

    created = bundle.info.get("dateCreated", "?")
    version = bundle.info.get("version", {})
    out(f"bundle   : {label} (created {created}, format {version.get('major')}."
        f"{version.get('minor')})")
    out(f"action   : Test — status {', '.join(statuses) or 'none'}")
    counts = " · ".join(f"{k} {len(v)}" for k, v in sorted(by_status.items()))
    suites = len({i.split('/')[0] for i in tests})
    out(f"tests    : {len(tests)} in {suites} suites — {counts}")
    if declared is not None:
        out(f"declared : {len(declared)} in {SUITE_DIR} at {commit[:9]} — "
            f"{len(missing)} without a result")
    else:
        out(f"declared : NOT CHECKED — {why_not}. Absence from the result is then unproven "
            "either way (#445).")
    for e in errors:
        out(f"error    : {e[:300]}")
    width = None if full else 300
    for heading, group in (("FAILED", failed), ("SKIPPED", skipped)):
        if not group:
            continue
        out(f"\n{heading} ({len(group)}):")
        for ident in group:
            status, ref = tests[ident]
            out(f"  {display(ident)}" + ("" if status in ("Failure", "Skipped")
                                         else f"   [status {status}]"))
            rows = details(bundle, ident, status, ref, by_case)
            if not rows:
                out("      (no message recorded in the bundle)")
            for where, line, msg in rows:
                flat = " ".join(msg.split())
                out(f"      {where}:{line}")
                out(f"      {flat[:width] if width else flat}"
                    + (" …" if width and len(flat) > width else ""))
    if missing:
        out(f"\nMISSING ({len(missing)}) — declared, no result (did not run, or the runner "
            "died before it reported):")
        for ident in missing:
            out(f"  {display(ident)}")
    bad = len(failed) + len(skipped) + len(missing)
    if bad:
        out(f"\nVERDICT: {len(failed)} failed · {len(skipped)} skipped · {len(missing)} missing "
            f"of {len(tests)} results. Not green.")
        return 1
    tail = "" if declared is not None else " The declared-count check did not run, so a test " \
                                           "that never reported cannot be ruled out."
    out(f"\nVERDICT: all {len(tests)} results passed.{tail}")
    return 0


# ── Selftest ───────────────────────────────────────────────────────────────────────────────

class _Enc:
    """Writes the token stream the Parser reads — `T` on a name's first use, `S` after."""

    def __init__(self):
        self.seen = set()

    @staticmethod
    def counted(tag, s):
        b = s.encode("utf-8")
        return tag + str(len(b)).encode() + b":" + b

    def spec(self, name, sup=None):
        if name in self.seen:
            return self.counted(b"S", name)
        self.seen.add(name)
        body = self.counted(b"K", "_n") + self.counted(b"V", name)
        if sup:
            body += self.counted(b"K", "_s") + b"[" + self.counted(b"K", "_n") \
                + self.counted(b"V", sup) + b"]"
        return b"T[" + body + b"]"

    def scalar(self, kind, value):
        return b"[" + self.spec(kind) + self.counted(b"K", "_v") + self.counted(b"V", value) + b"]"

    def obj(self, kind, fields=(), elems=(), sup=None):
        out = b"[" + self.spec(kind, sup)
        for key, value in fields:
            out += self.counted(b"K", key) + value
        for e in elems:
            out += e
        return out + b"]"


def _fixture(folder, compress, statuses, tree_bytes=None):
    """A minimal bundle: one test action, one suite per status entry."""
    data = os.path.join(folder, "Data")
    os.makedirs(data, exist_ok=True)

    def put(ident, payload):
        if compress:
            payload = compress(payload)
        with open(os.path.join(data, "data." + ident), "wb") as fh:
            fh.write(payload)

    e = _Enc()
    metas = []
    for n, (name, status) in enumerate(statuses):
        ref = f"0~summary{n}"
        fields = [("identifier", e.scalar("String", f"{name}()")),
                  ("testStatus", e.scalar("String", status)),
                  ("summaryRef", e.obj("Reference", [("id", e.scalar("String", ref))]))]
        metas.append(e.obj("ActionTestMetadata", fields))
        s = _Enc()
        notice = s.obj("ActionTestFailureSummary", [
            ("fileName", s.scalar("String", f"/Users/runner/work/R/R/Tests/CISmoke/{name.split('/')[0]}.swift")),
            ("lineNumber", s.scalar("Int", str(10 + n))),
            # ⚠️ multi-byte on purpose: a CHARACTER-counting parser mis-reads this blob.
            ("message", s.scalar("String", f"XCTAssertTrue failed — {name} × ⛔"))])
        key = "skipNoticeSummary" if status == "Skipped" else "failureSummaries"
        value = notice if status == "Skipped" else s.obj("Array", elems=[notice])
        put(ref, s.obj("ActionTestSummary", [(key, value)], sup="ActionAbstractTestSummary"))
    groups = {}
    for (name, _), meta in zip(statuses, metas):
        groups.setdefault(name.split("/")[0], []).append(meta)
    g = [e.obj("ActionTestSummaryGroup", [("subtests", e.obj("Array", elems=m))])
         for _, m in sorted(groups.items())]
    testable = e.obj("ActionTestableSummary", [("tests", e.obj("Array", elems=g))])
    run = e.obj("ActionTestPlanRunSummary", [("testableSummaries", e.obj("Array",
                                                                         elems=[testable]))])
    tree = e.obj("ActionTestPlanRunSummaries", [("summaries", e.obj("Array", elems=[run]))])
    put("0~tests", tree if tree_bytes is None else tree_bytes(tree))
    r = _Enc()
    result = r.obj("ActionResult", [("status", r.scalar("String", "failed")),
                                    ("testsRef", r.obj("Reference",
                                                       [("id", r.scalar("String", "0~tests"))]))])
    action = r.obj("ActionRecord", [("actionResult", result)])
    put("0~root", r.obj("ActionsInvocationRecord", [("actions", r.obj("Array",
                                                                      elems=[action]))]))
    with open(os.path.join(folder, "Info.plist"), "wb") as fh:
        plistlib.dump({"rootId": {"hash": "0~root"}, "version": {"major": 3, "minor": 56},
                       "dateCreated": "selftest"}, fh)


def selftest():
    name, decompress = _backend()
    compress = None
    if name == "zstandard":
        import zstandard
        compress = zstandard.ZstdCompressor().compress
    elif name == "compression.zstd":
        from compression import zstd as stdlib_zstd
        compress = stdlib_zstd.compress
    problems = []

    def check(label, cond):
        print(("ok    " if cond else "FAIL  ") + label)
        if not cond:
            problems.append(label)

    statuses = [("ASuiteTests/testOne", "Success"), ("ASuiteTests/testTwo", "Failure"),
                ("BSuiteTests/testThree", "Success"), ("BSuiteTests/testFour", "Failure"),
                ("CSuiteTests/testFive", "Skipped"), ("CSuiteTests/testSix", "Expected Failure"),
                ("DSuiteTests/testSeven", "Mixed")]
    variants = [("raw", None)] + ([(name, compress)] if compress else [])
    with tempfile.TemporaryDirectory() as tmp:
        for label, packer in variants:
            folder = os.path.join(tmp, re.sub(r"\W", "_", label))
            _fixture(folder, packer, statuses)
            lines = []
            b = Bundle(folder, decompress)
            code = report(b, "fixture", None, True, False, out=lines.append)
            body = "\n".join(lines)
            tag = f"[{label} blobs] "
            check(tag + "seven results, four suites", "tests    : 7 in 4 suites" in body)
            check(tag + "both red tests named, by Suite.test", "ASuiteTests.testTwo" in body
                  and "BSuiteTests.testFour" in body)
            check(tag + "an unknown status counts as FAILED, never as a pass",
                  "DSuiteTests.testSeven   [status Mixed]" in body and "FAILED (3)" in body)
            check(tag + "Expected Failure is a pass", "CSuiteTests.testSix" not in body)
            check(tag + "the skip is named with its reason", "SKIPPED (1)" in body
                  and "XCTAssertTrue failed — CSuiteTests/testFive × ⛔" in body)
            check(tag + "file:line is repo-relative", "\n      Tests/CISmoke/ASuiteTests.swift:11\n"
                  in body and "/Users/runner" not in body)
            check(tag + "multi-byte message survives byte-counted lengths", "× ⛔" in body)
            check(tag + "exit 1 on red", code == 1)
            names = []
            report(b, "fixture", None, False, True, out=names.append)
            check(tag + "--names: one line per non-passing test", names == [
                "FAILED ASuiteTests.testTwo", "FAILED BSuiteTests.testFour",
                "FAILED DSuiteTests.testSeven", "SKIPPED CSuiteTests.testFive"])
        green = os.path.join(tmp, "green")
        _fixture(green, None, [("ASuiteTests/testOne", "Success")])
        lines = []
        check("all passing → exit 0", report(Bundle(green, decompress), "g", None, False,
                                             False, out=lines.append) == 0)
        check("…and says the declared check did not run", "NOT CHECKED" in "\n".join(lines))
        only_skip = os.path.join(tmp, "skip")
        _fixture(only_skip, None, [("ASuiteTests/testOne", "Success"),
                                   ("ASuiteTests/testTwo", "Skipped")])
        for names_only in (False, True):
            check(f"a skip ALONE → exit 1 (a skip asserted nothing, #806; --names={names_only})",
                  report(Bundle(only_skip, decompress), "s", None, False, names_only,
                         out=lambda _: None) == 1)
        for order in (("Failure", "Success"), ("Success", "Failure")):
            twice = os.path.join(tmp, "twice_" + order[0])
            _fixture(twice, None, [("ASuiteTests/testOne", order[0]),
                                   ("ASuiteTests/testOne", order[1])])
            names = []
            report(Bundle(twice, decompress), "t", None, False, True, out=names.append)
            check(f"one name reported twice ({order[0]} then {order[1]}) → the worse wins",
                  names == ["FAILED ASuiteTests.testOne"])
        junk = os.path.join(tmp, "junk")
        _fixture(junk, None, statuses, tree_bytes=lambda t: t + b"[S6:String]")
        try:
            report(Bundle(junk, decompress), "j", None, False, False, out=lambda _: None)
            check("bytes after the object → Unavailable (the stream is not what we think)",
                  False)
        except Unavailable:
            check("bytes after the object → Unavailable (the stream is not what we think)",
                  True)
        empty = os.path.join(tmp, "empty")
        _fixture(empty, None, [])
        try:
            report(Bundle(empty, decompress), "e", None, False, False, out=lambda _: None)
            check("zero results → Unavailable (exit 2), never a green", False)
        except Unavailable:
            check("zero results → Unavailable (exit 2), never a green", True)
        cut = os.path.join(tmp, "cut")
        _fixture(cut, None, statuses, tree_bytes=lambda t: t[:-7])
        try:
            report(Bundle(cut, decompress), "c", None, False, False, out=lambda _: None)
            check("a truncated object → Unavailable, never a partial count", False)
        except Unavailable:
            check("a truncated object → Unavailable, never a partial count", True)
        char_counted = os.path.join(tmp, "chars")
        _fixture(char_counted, None, statuses)
        blob = os.path.join(char_counted, "Data", "data.0~summary1")
        with open(blob, "rb") as fh:
            body = fh.read().decode("utf-8")
        fake = re.sub(r"V(\d+):(XCTAssertTrue failed[^\]]*)",
                      lambda m: f"V{len(m.group(2))}:{m.group(2)}", body).encode("utf-8")
        with open(blob, "wb") as fh:
            fh.write(fake)
        check("the fixture really carries multi-byte text (else the next check proves nothing)",
              fake != body.encode("utf-8"))
        try:
            Bundle(char_counted, decompress).load("0~summary1")
            check("a CHARACTER-counted length is rejected, not silently mis-read", False)
        except Unavailable:
            check("a CHARACTER-counted length is rejected, not silently mis-read", True)
    sample = ["Tests/CISmoke/X.swift:3:final class XTests: XCTestCase {",
              "Tests/CISmoke/X.swift:9:    func testA() throws {",
              "Tests/CISmoke/X.swift:20:    @MainActor func testB() async throws {",
              "Tests/CISmoke/X.swift:30:    private func testHelperNotATest() {",
              "Tests/CISmoke/X.swift:31:    func testWithAnArgument(_ x: Int) {",
              "Tests/CISmoke/X.swift:32:    static func testStatic() {",
              "Tests/CISmoke/Y.swift:1:class YTests: XCTestCase {",
              "Tests/CISmoke/Y.swift:2:    func testC() {"]
    check("declarations → Suite/test; private, static and parameterised helpers excluded",
          declared_tests(sample) == {"XTests/testA", "XTests/testB", "YTests/testC"})
    grep_shape = re.compile(GREP_DECL.replace("[[:space:]]", r"\s").replace("[[:alnum:]_]",
                                                                             r"\w"))
    check("the git-grep prefilter admits every line the refiners accept",
          all(grep_shape.search(s) for s in sample))
    if name is None:
        print(f"note  no zstd backend here, so only RAW blobs were exercised — {INSTALL_HINT}")
    print("SELFTEST", "FAILED: " + "; ".join(problems) if problems else "passed")
    return 1 if problems else 0


# ── main ───────────────────────────────────────────────────────────────────────────────────

def main(argv):
    if argv == ["--selftest"]:
        return selftest()
    opts = {"--full": False, "--names": False}
    vals = {"--keep": None, "--repo": REPO, "--commit": None, "--sha": None}
    rest = []
    it = iter(argv)
    for a in it:
        if a in opts:
            opts[a] = True
        elif a in vals:
            vals[a] = next(it, None)
        else:
            rest.append(a)
    if len(rest) + (1 if vals["--sha"] else 0) != 1:
        print(__doc__.split("Usage:")[1].split("zstd:")[0].rstrip(), file=sys.stderr)
        return 2
    backend, decompress = _backend()
    scratch = vals["--keep"] or tempfile.mkdtemp(prefix="xcresult-")
    try:
        target = vals["--sha"] or rest[0]
        bundles = []
        commit = vals["--commit"]
        if vals["--sha"] or target.isdigit():
            run_id = run_for_sha(target, vals["--repo"]) if vals["--sha"] else target
            head, state, got = download(run_id, vals["--repo"], scratch)
            commit = commit or head
            if not opts["--names"]:
                print(f"run      : {run_id} at {head[:9]} ({state})")
            for art, folder in got:
                bundles.append((art, locate(folder, scratch)))
        else:
            bundles.append((target, locate(target, scratch)))
        if decompress is None and not opts["--names"]:
            print(f"zstd     : none — compressed objects cannot be read; {INSTALL_HINT}")
        code = 0
        for label, folder in bundles:
            code = max(code, report(Bundle(folder, decompress), label, commit,
                                    opts["--full"], opts["--names"]))
        return code
    except Unavailable as exc:
        print(f"INSTRUMENT UNAVAILABLE: {exc}", file=sys.stderr)
        return 2
    finally:
        if not vals["--keep"]:
            shutil.rmtree(scratch, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
