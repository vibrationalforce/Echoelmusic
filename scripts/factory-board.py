#!/usr/bin/env python3
"""Print the Echoel factory board from scratchpads/factory/<job>/board.json.

Read-only, like every tool in scripts/ (scripts/INDEX.md). The board is the terminal twin of
the web board in the clip the factory was learned from: one column per stage, one line per job.
The PM (the main session) is the ONLY writer of board.json; reviewers and the approver are
read-only agents and never touch it (.claude/skills/factory/SKILL.md).

    python3 -I scripts/factory-board.py              # the board
    python3 -I scripts/factory-board.py --open       # only jobs that are not done or dropped
    python3 -I scripts/factory-board.py --selftest   # after touching this file

Exit 0 = printed · 1 = a board.json is unreadable or names an unknown stage (a finding, the
board does not guess) · 2 = the factory folder does not exist yet.
"""
import json
import sys
from pathlib import Path

STAGES = ["spec", "build", "review", "approve", "needs-human", "done", "dropped"]
OPEN = {"spec", "build", "review", "approve", "needs-human"}


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
        jobs.append(data)
    return jobs, problems


def render(jobs, only_open=False):
    lines = []
    for stage in STAGES:
        if only_open and stage not in OPEN:
            continue
        here = [j for j in jobs if j.get("stage") == stage]
        lines.append(f"── {stage.upper()} ({len(here)})")
        for j in here:
            extra = []
            if j.get("round"):
                extra.append(f"round {j['round']}")
            if j.get("inbox"):
                extra.append(f"inbox {j['inbox']}")
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
        jobs, problems = load(root)
        if [j["id"] for j in jobs] != ["001-good"]:
            failures.append(f"expected only 001-good, got {[j['id'] for j in jobs]}")
        if len(problems) != 3:
            failures.append(f"expected 3 problems (stage, id, json), got {problems}")
        text = render(jobs)
        if "── NEEDS-HUMAN (1)" not in text or "inbox F23" not in text:
            failures.append("needs-human column or inbox number missing")
        if "── DONE" in render(jobs, only_open=True):
            failures.append("--open still printed a closed column")
    if failures:
        print("SELFTEST FAILED:\n  " + "\n  ".join(failures))
        return 1
    print("selftest ok: 1 job loaded, 3 malformed boards reported, --open hides closed columns")
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
