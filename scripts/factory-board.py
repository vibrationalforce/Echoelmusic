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

Exit 0 = printed · 1 = a board.json is unreadable, is not a JSON object, names an unknown stage,
carries an id that is not its folder name, has a deviceOpen list that is not a list of objects
with a YYYY-MM-DD `verified`, or a scopeOpen list that is not a list of objects with a `file`
(each a finding; the board does not guess) ·
2 = the factory folder does not exist yet.

A job approved with device checks is "done, device-unverified": its gates are green, but no device
has confirmed it. It stays on --open until every deviceOpen entry carries a `verified` date, so a
slice is never closed on the strength of code alone (job 001, round 2).

The same holds for scopeOpen: a sensitive file the job changed OUTSIDE its paths (the review's
`sensitiveOutside` — legal, privacy, health, entitlements, store text) is not covered by the
approval. The job stays on --open until each entry names who reviewed it in `reviewedBy` (job 003).
"""
import json
import re
import sys
from pathlib import Path

STAGES = ["spec", "build", "review", "approve", "needs-human", "done", "dropped"]
OPEN = {"spec", "build", "review", "approve", "needs-human"}
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def device_open(job):
    """The deviceOpen entries that carry no verified date yet."""
    return [d for d in job.get("deviceOpen", []) if not d.get("verified")]


def scope_open(job):
    """The scopeOpen entries that nobody has reviewed yet."""
    return [s for s in job.get("scopeOpen", []) if not str(s.get("reviewedBy", "")).strip()]


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
        if not isinstance(scoped, list) or not all(isinstance(s, dict) and isinstance(s.get("file"), str) and s["file"].strip()
                                                   for s in scoped):
            problems.append(f"{board}: scopeOpen must be a list of objects with a file")
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
            "011-scoped": {"id": "011-scoped", "stage": "done", "scopeOpen": [{"file": "docs/privacy.html", "reviewedBy": "founder"}]},
            "012-scopeblank": {"id": "012-scopeblank", "stage": "done", "scopeOpen": [{"file": "LICENSE", "reviewedBy": "  "}]},
            "013-scopebad": {"id": "013-scopebad", "stage": "done", "scopeOpen": ["docs/privacy.html"]},
            "014-scopenofile": {"id": "014-scopenofile", "stage": "done", "scopeOpen": [{"reviewedBy": "x"}]},
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
        want = ["001-good", "005-device", "006-checked", "010-scope", "011-scoped", "012-scopeblank"]
        if [j["id"] for j in jobs] != want:
            failures.append(f"expected {want}, got {[j['id'] for j in jobs]}")
        named = ["002-bad", "003-moved", "004-broken", "007-baddate", "008-devstring", "009-devlist", "013-scopebad", "014-scopenofile"]
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
        if "012-scopeblank" not in opened:
            failures.append("a blank reviewedBy closed an outside file")
        if "011-scoped" in opened:
            failures.append("--open still printed a done job whose outside files are all reviewed")
    if failures:
        print("SELFTEST FAILED:\n  " + "\n  ".join(failures))
        return 1
    print("selftest ok: 6 jobs loaded, 8 malformed boards reported, --open hides closed jobs and keeps device-open and scope-open ones")
    return 0


def main(argv):
    if "--selftest" in argv:
        return selftest()
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
