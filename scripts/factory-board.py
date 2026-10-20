#!/usr/bin/env python3
"""Print the Echoel factory board from scratchpads/factory/<job>/board.json.

Read-only, like every tool in scripts/ (scripts/INDEX.md). The board is the terminal twin of
the web board in the clip the factory was learned from: one column per stage, one line per job.
The PM (the main session) is the ONLY writer of board.json; reviewers and the approver are
read-only agents and never touch it (.claude/skills/factory/SKILL.md).

    python3 -I scripts/factory-board.py              # the board
    python3 -I scripts/factory-board.py --open       # jobs not done or dropped, plus done jobs
                                                     # with an unverified device check or an
                                                     # unreviewed file outside their scope
    python3 -I scripts/factory-board.py --selftest   # after touching this file
    python3 -I scripts/factory-board.py --mutate     # every row of MUTATIONS must turn the selftest red

Exit 0 = printed · 1 = a board.json is unreadable, is not a JSON object, names an unknown stage,
carries an id that is not its folder name, has a deviceOpen list that is not a list of objects
with a YYYY-MM-DD `verified`, or a scopeOpen list that is not a list of objects with a `file` and,
where present, a `reviewedBy` that names another job of this factory or reads `founder YYYY-MM-DD`
(each a finding; the board does not guess) · with --selftest or --mutate: a case decided wrong, a
mutation survived or a mutation row no longer matches this file exactly once ·
2 = the factory folder does not exist yet.

A job approved with device checks is "done, device-unverified": its gates are green, but no device
has confirmed it. It stays on --open until every deviceOpen entry carries a `verified` date, so a
slice is never closed on the strength of code alone (job 001, round 2).

The same holds for scopeOpen: a sensitive file the job changed OUTSIDE its paths (the review's
`sensitiveOutside` — legal, privacy, health, entitlements, store text) is not covered by the
approval. The job stays on --open until each entry names who reviewed it in `reviewedBy` — another
job's id or `founder YYYY-MM-DD`, the same rigour as a device check's date. An absent or null
`reviewedBy` is open; any other value is a finding, never "reviewed" (job 003, round 1: `null`
read as the string "None" and closed the file).
"""
import json
import re
import sys
from pathlib import Path

STAGES = ["spec", "build", "review", "approve", "needs-human", "done", "dropped"]
OPEN = {"spec", "build", "review", "approve", "needs-human"}
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
REVIEWED = re.compile(r"^(?:(?P<job>\d{3}-[a-z0-9-]{1,60})|founder \d{4}-\d{2}-\d{2})$")


def device_open(job):
    """The deviceOpen entries that carry no verified date yet."""
    return [d for d in job.get("deviceOpen", []) if not d.get("verified")]


def scope_open(job):
    """The scopeOpen entries that nobody has reviewed yet (load() has rejected every malformed one)."""
    return [s for s in job.get("scopeOpen", []) if s.get("reviewedBy") is None]


def scope_problem(entry, root, own):
    """Why one scopeOpen entry is malformed, or None. An absent or null reviewedBy is open, not malformed."""
    if not (isinstance(entry, dict) and isinstance(entry.get("file"), str) and entry["file"].strip()):
        return "scopeOpen must be a list of objects with a file"
    by = entry.get("reviewedBy")
    if by is None:
        return None
    match = REVIEWED.match(by) if isinstance(by, str) else None
    if not match:
        return f"scopeOpen reviewedBy must be another job's id or 'founder YYYY-MM-DD', got {by!r}"
    job = match.group("job")
    if job and (job == own or not (root / job).is_dir()):
        return f"scopeOpen reviewedBy {by!r} names no other job of this factory"
    return None


def still_open(job):
    return bool(device_open(job) or scope_open(job))


def load(root):
    """Return (jobs, problems). A job is the parsed board.json plus its folder name."""
    jobs, problems = [], []
    for board in sorted(root.glob("*/board.json")):
        try:
            data = json.loads(board.read_text(encoding="utf-8"))
        except (OSError, ValueError) as err:
            problems.append(f"{board}: unreadable ({err})")
            continue
        if not isinstance(data, dict):
            problems.append(f"{board}: not a JSON object")
            continue
        stage = data.get("stage")
        if stage not in STAGES:
            problems.append(f"{board}: unknown stage {stage!r} (one of {', '.join(STAGES)})")
            continue
        if data.get("id") != board.parent.name:
            problems.append(f"{board}: id {data.get('id')!r} differs from its folder {board.parent.name!r}")
            continue
        asks = data.get("deviceOpen", [])
        if not isinstance(asks, list) or not all(isinstance(d, dict) for d in asks):
            problems.append(f"{board}: deviceOpen must be a list of objects")
            continue
        bad = [d.get("verified") for d in asks if d.get("verified") and not DATE.match(str(d["verified"]))]
        if bad:
            problems.append(f"{board}: deviceOpen verified must be YYYY-MM-DD, got {bad}")
            continue
        scoped = data.get("scopeOpen", [])
        why = ("scopeOpen must be a list of objects with a file" if not isinstance(scoped, list)
               else next((w for w in (scope_problem(s, root, board.parent.name) for s in scoped) if w), None))
        if why:
            problems.append(f"{board}: {why}")
            continue
        jobs.append(data)
    return jobs, problems


def render(jobs, only_open=False):
    lines = []
    for stage in STAGES:
        here = [j for j in jobs if j.get("stage") == stage]
        if only_open and stage not in OPEN:
            # A done job with an unverified device check or an unreviewed outside file is not closed yet.
            here = [j for j in here if stage == "done" and still_open(j)]
            if not here:
                continue
        lines.append(f"── {stage.upper()} ({len(here)})")
        for j in here:
            extra = []
            if j.get("round"):
                extra.append(f"round {j['round']}")
            if j.get("inbox"):
                extra.append(f"inbox {j['inbox']}")
            if device_open(j):
                extra.append(f"device open {len(device_open(j))}")
            if scope_open(j):
                extra.append(f"scope open {len(scope_open(j))}")
            if j.get("head"):
                extra.append(str(j["head"])[:9])
            tail = f"  [{', '.join(extra)}]" if extra else ""
            lines.append(f"   {j['id']}  {j.get('title', '')}{tail}")
    return "\n".join(lines)


def selftest():
    import tempfile
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        good = root / "001-good"
        good.mkdir()
        (good / "board.json").write_text(json.dumps(
            {"id": "001-good", "title": "A job", "stage": "needs-human", "round": 3, "inbox": "F23"}))
        bad_stage = root / "002-bad"
        bad_stage.mkdir()
        (bad_stage / "board.json").write_text(json.dumps({"id": "002-bad", "stage": "shipped"}))
        wrong_id = root / "003-moved"
        wrong_id.mkdir()
        (wrong_id / "board.json").write_text(json.dumps({"id": "003-other", "stage": "done"}))
        broken = root / "004-broken"
        broken.mkdir()
        (broken / "board.json").write_text("{not json")
        device = root / "005-device"
        device.mkdir()
        (device / "board.json").write_text(json.dumps(
            {"id": "005-device", "stage": "done", "deviceOpen": [{"ask": "AUM", "verified": "2026-10-20"}, {"ask": "buy"}]}))
        checked = root / "006-checked"
        checked.mkdir()
        (checked / "board.json").write_text(json.dumps(
            {"id": "006-checked", "stage": "done", "deviceOpen": [{"ask": "AUM", "verified": "2026-10-20"}]}))
        bad_date = root / "007-baddate"
        bad_date.mkdir()
        (bad_date / "board.json").write_text(json.dumps(
            {"id": "007-baddate", "stage": "done", "deviceOpen": [{"ask": "AUM", "verified": "yes"}]}))
        boards = {
            # deviceOpen as a string or a list of strings is reported, never a crash.
            "008-devstring": {"id": "008-devstring", "stage": "done", "deviceOpen": "AUM"},
            "009-devlist": {"id": "009-devlist", "stage": "done", "deviceOpen": ["AUM", "buy"]},
            "010-scope": {"id": "010-scope", "stage": "done",
                          "scopeOpen": [{"file": "docs/privacy.html", "reviewedBy": "founder 2026-10-20"}, {"file": "LICENSE"}]},
            "011-scoped": {"id": "011-scoped", "stage": "done", "scopeOpen": [{"file": "docs/privacy.html", "reviewedBy": "001-good"}]},
            # null is the natural placeholder; it must stay OPEN (round 1 read it as the string "None").
            "012-scopenull": {"id": "012-scopenull", "stage": "done", "scopeOpen": [{"file": "LICENSE", "reviewedBy": None}]},
            "013-scopebad": {"id": "013-scopebad", "stage": "done", "scopeOpen": ["docs/privacy.html"]},
            "014-scopenofile": {"id": "014-scopenofile", "stage": "done", "scopeOpen": [{"note": "LICENSE"}]},
            # A reviewedBy that is not a record is a finding, never "reviewed".
            "015-scopebare": {"id": "015-scopebare", "stage": "done", "scopeOpen": [{"file": "LICENSE", "reviewedBy": "founder"}]},
            "016-scopepending": {"id": "016-scopepending", "stage": "done", "scopeOpen": [{"file": "LICENSE", "reviewedBy": "pending"}]},
            "017-scopenojob": {"id": "017-scopenojob", "stage": "done", "scopeOpen": [{"file": "LICENSE", "reviewedBy": "099-missing"}]},
            "018-scopeself": {"id": "018-scopeself", "stage": "done", "scopeOpen": [{"file": "LICENSE", "reviewedBy": "018-scopeself"}]},
            "019-scopeblank": {"id": "019-scopeblank", "stage": "done", "scopeOpen": [{"file": "LICENSE", "reviewedBy": "  "}]},
            "020-scopenumber": {"id": "020-scopenumber", "stage": "done", "scopeOpen": [{"file": "LICENSE", "reviewedBy": 0}]},
            "021-scopefalse": {"id": "021-scopefalse", "stage": "done", "scopeOpen": [{"file": "LICENSE", "reviewedBy": False}]},
        }
        for name, data in boards.items():
            (root / name).mkdir()
            (root / name / "board.json").write_text(json.dumps(data))
        # A malformed board must come back as a problem; a crash here is the bug, not a pass.
        try:
            jobs, problems = load(root)
            text, opened = render(jobs), render(jobs, only_open=True)
        except Exception as err:  # noqa: BLE001 — the selftest reports any crash by name
            print(f"SELFTEST FAILED:\n  the board crashed on a malformed board: {type(err).__name__}: {err}")
            return 1
        want = ["001-good", "005-device", "006-checked", "010-scope", "011-scoped", "012-scopenull"]
        if [j["id"] for j in jobs] != want:
            failures.append(f"expected {want}, got {[j['id'] for j in jobs]}")
        named = ["002-bad", "003-moved", "004-broken", "007-baddate", "008-devstring", "009-devlist", "013-scopebad", "014-scopenofile",
                 "015-scopebare", "016-scopepending", "017-scopenojob", "018-scopeself", "019-scopeblank", "020-scopenumber",
                 "021-scopefalse"]
        unnamed = [n for n in named if not any(f"/{n}/" in p for p in problems)]
        if len(problems) != len(named) or unnamed:
            failures.append(f"expected {len(named)} problems naming {named}, missing {unnamed}, got {problems}")
        if "── NEEDS-HUMAN (1)" not in text or "inbox F23" not in text:
            failures.append("needs-human column or inbox number missing")
        if "005-device" not in opened or "device open 1" not in opened:
            failures.append("--open hid a done job with an unverified device check")
        if "006-checked" in opened:
            failures.append("--open still printed a done job whose device checks are all verified")
        if "010-scope" not in opened or "scope open 1" not in opened:
            failures.append("--open hid a done job with an unreviewed outside file")
        if "012-scopenull" not in opened:
            failures.append("a null reviewedBy closed an outside file")
        if "011-scoped" in opened:
            failures.append("--open still printed a done job whose outside files are all reviewed")
    if failures:
        print("SELFTEST FAILED:\n  " + "\n  ".join(failures))
        return 1
    print("selftest ok: 6 jobs loaded, 15 malformed boards reported, --open hides closed jobs and keeps device-open and scope-open ones")
    return 0


# (name, old, new): each old must occur exactly once in this file; a stale row is a failure, not a skip.
MUTATIONS = [
    ("deviceOpen list-of-objects check dropped", "if not isinstance(asks, list) or not all(isinstance(d, dict) for d in asks):", "if False:"),
    ("deviceOpen items unchecked", "if not isinstance(asks, list) or not all(isinstance(d, dict) for d in asks):", "if not isinstance(asks, list):"),
    ("verified date unchecked", "and not DATE.match(str(d[\"verified\"]))]", "and False]"),
    ("scopeOpen list check dropped", "why = (\"scopeOpen must be a list of objects with a file\" if not isinstance(scoped, list)", "why = (None if True"),
    ("scopeOpen file not required", "isinstance(entry.get(\"file\"), str) and entry[\"file\"].strip()", "True"),
    ("null reviewedBy reads as reviewed", "if s.get(\"reviewedBy\") is None]", "if not str(s.get(\"reviewedBy\", \"\")).strip()]"),
    ("reviewedBy format unchecked", "match = REVIEWED.match(by) if isinstance(by, str) else None", "match = REVIEWED.match(\"founder 2026-01-01\")"),
    ("reviewedBy job existence unchecked", "if job and (job == own or not (root / job).is_dir()):", "if job and job == own:"),
    ("self-review allowed", "if job and (job == own or not (root / job).is_dir()):", "if job and not (root / job).is_dir():"),
    ("scope_open ignored on --open", "stage == \"done\" and still_open(j)", "stage == \"done\" and device_open(j)"),
    ("device_open ignored on --open", "stage == \"done\" and still_open(j)", "stage == \"done\" and scope_open(j)"),
    ("scope count not rendered", "extra.append(f\"scope open {len(scope_open(j))}\")", "pass"),
]


def mutate():
    """Each row must turn the selftest red; a row whose old text is gone is stale."""
    import subprocess
    import tempfile
    src = Path(__file__).read_text(encoding="utf-8")
    # The table quotes the code it mutates, so every old text occurs once in the code and once here.
    code = src[:src.index("# (name, old, new): each old must occur")]
    survived, stale = [], []
    with tempfile.TemporaryDirectory() as tmp:
        target = Path(tmp) / "board.py"
        for name, old, new in MUTATIONS:
            if code.count(old) != 1:
                stale.append(f"{name} (old text occurs {code.count(old)}x in the code)")
                continue
            target.write_text(code.replace(old, new, 1) + src[len(code):], encoding="utf-8")
            run = subprocess.run([sys.executable, "-I", str(target), "--selftest"], capture_output=True, text=True)
            caught = run.returncode == 1 and "SELFTEST FAILED" in run.stdout
            if not caught:
                survived.append(name)
            print(f"{'CAUGHT  ' if caught else 'SURVIVED'} {name}")
    for s in stale:
        print(f"STALE    {s}")
    print(f"{len(MUTATIONS) - len(survived) - len(stale)}/{len(MUTATIONS)} mutations caught")
    return 1 if survived or stale else 0


def main(argv):
    if "--selftest" in argv:
        return selftest()
    if "--mutate" in argv:
        return selftest() or mutate()
    root = Path(__file__).resolve().parent.parent / "scratchpads" / "factory"
    if not root.is_dir():
        print(f"no factory yet: {root} does not exist (start a job per .claude/skills/factory/SKILL.md)")
        return 2
    jobs, problems = load(root)
    print(render(jobs, only_open="--open" in argv))
    for p in problems:
        print(f"⚠️ {p}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
