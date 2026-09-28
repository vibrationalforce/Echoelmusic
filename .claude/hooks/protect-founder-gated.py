#!/usr/bin/env python3
"""PreToolUse hook (matcher: Bash) — founder-gated paths ask before a Bash write.

WHY THIS EXISTS (measured 2026-09-28 in a throwaway repo, not assumed): the built-in
`permissions.ask` rules in `.claude/settings.json` (`Edit(/project.yml)` …) cover the
Edit/Write tools and the Bash writes Claude Code can PARSE (redirects, `cp`, `sed -i`,
`git mv`). They do NOT see a write done INSIDE an interpreter. With those rules in place,
`python3 -c "open('project.yml','w')…"` went through in `default` mode (this project
pre-allows `Bash(python3 -c:*)`); in `auto` mode only the model classifier stopped it, and
the same write passed the classifier once the rules were absent. A judgement, not a rule.

WHAT IT DOES
  1. Text rule: a Bash unit that WRITES a protected path -> "ask".
       · shell unit: the path is a redirect target, the DESTINATION of `cp`/`install`/
         `ln`/`rsync`/`dd`, or sits next to a write command (`tee`, `sed -i`, `mv`, `rm`,
         `git checkout/restore/…`, …). Quoted text containing whitespace is prose (a
         commit message, a prompt) and never counts as a path or a command word.
       · interpreter unit (`python3 -c`, `python3 - <<EOF`, `node -e`, …): the path is a
         WHOLE string literal ('project.yml') and it is the TARGET of a write call —
         directly, or through a variable assigned from it in the same unit. Reading the
         path and writing another file does not count. A `bash <<EOF` body is shell.
  2. Commit backstop: `git commit` whose staged changes (plus unstaged for -a/--all) touch
     a protected path -> "ask". Catches what rule 1 cannot see (encoded paths, helper
     functions, `cd` first).
  Everything else: no output, exit 0 -> Claude Code's normal permission flow decides.

DECISION (founder 2026-09-28, variant A): "deny" when the payload says
permission_mode == "auto", "ask" otherwise. Why: in the phone cloud session (2.1.283,
auto) this hook emitted "ask" and the command ran anyway; WHICH instance resolved the ask
is unknown. After the switch a recognised write in that session was refused and did not
run (README "Deny-Beleg"). There is deliberately no token, file or variable the agent could
set to release itself. A headless `claude -p` has no one to answer, so "ask" blocks there.

PROTECTED (founder-gated, CLAUDE.md "DO NOT" + .claude/rules/context.md §3):
  .github/workflows/**   project.yml   Resources/iOS/Info.plist   .deploy/release

LIMITS: `--limits`. Self-test (run after any edit): `--selftest`.
"""
import json
import os
import re
import subprocess
import sys

PROTECTED_FILES = ("project.yml", "Resources/iOS/Info.plist", ".deploy/release")
PROTECTED_DIRS = (".github/workflows/",)

LIMITS = """\
- Rule 1 reads TEXT. A path built at runtime (base64, string concatenation, a helper
  function's parameter, `open(p, mode='w')`, `cd Resources/iOS && … Info.plist`) is
  invisible to it. Rule 2 (commit) is the net for those.
- `cd elsewhere && … project.yml` is read as THIS repo's path: a false ask in another
  directory, never a false pass. So is a script whose SOURCE contains the literal
  `open('project.yml','w')` inside a string (editing this hook's own selftest).
- Rule 2 fires at `git commit` only. `git merge`, `cherry-pick`, `revert` and `am` create
  commits without it, and `git push` is not inspected.
- The hook and `.claude/settings.json` are NOT protected themselves (scope = the four
  paths). An agent could edit them; that shows up in the diff and in the commit.
- Only Claude's own tool calls pass through here. CI, the founder's editor and the
  founder's own terminal are untouched.
- Measured with Claude Code 2.1.283 in `default` and `auto` only. `bypassPermissions`
  skipping "ask" is from the docs, NOT measured; other modes and versions are untested.
- "deny" covers only what THIS hook recognises in Bash. The Edit/Write tools go through
  the built-in `permissions.ask` rules, and whether those hold in auto mode is UNMEASURED.
- A payload without `permission_mode` (other versions) falls back to "ask".
- Fail-open on an internal error, EXCEPT when the raw command names a protected path —
  then it asks (denies in auto mode).
"""

_PATHS = "|".join([re.escape(p) for p in PROTECTED_FILES] + [re.escape(d.rstrip("/")) for d in PROTECTED_DIRS])
INTERPRETERS = r"(?:python3?|node|ruby|perl|bash|sh|zsh|swift|osascript)"
# An interpreter as a COMMAND WORD — never `Foo.swift`, `bin/sh.md`, `sh-foo`.
INTERPRETER_RE = re.compile(r"(?:^|(?<=[\s;|&(]))" + INTERPRETERS + r"(?=\s|$)")
HEREDOC_RE = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_]\w*)\1")
REDIRECT_RE = re.compile(r"(?<![<>&0-9])>{1,2}\s*(\S+)")
# Any argument position is a write for these.
SHELL_WRITE_RE = re.compile(
    r"(?:^|(?<=[\s;|&(]))(?:tee|mv|truncate|touch|chmod|chown|rm|unlink|patch)(?=\s)"
    r"|(?:^|(?<=[\s;|&(]))(?:sed|perl)(?:\s[^\n]*?)?\s-[A-Za-z]*i"
    r"|\bgit\s+(?:checkout|restore|rm|mv|apply|am|stash|reset|cherry-pick|revert)\b")
# For these only the DESTINATION (last argument, or dd's of=) is written; the source is read.
COPY_RE = re.compile(r"(?:^|(?<=[\s;|&(]))(?:cp|install|ln|rsync|dd)(?=\s)")
WRITE_MODE = r"['\"][wax]b?\+?['\"]"
SHELL_INTERPRETER_RE = re.compile(r"(?:^|(?<=[\s;|&(]))(?:bash|sh|zsh)(?=\s|$)")
# Unstaging touches the INDEX only, never the file — it is how a protected change is taken
# OUT of a commit, so it must stay free. `--worktree`/`-W` or `reset --hard` do write.
UNSTAGE_RE = re.compile(
    r"\bgit\s+(?:restore\s+(?=[^\n]*(?:--staged|\s-S\b))(?![^\n]*(?:--worktree|\s-W\b|\s-[A-Za-z]*W))"
    r"|reset\s+(?![^\n]*--(?:hard|merge|keep)\b))")
COMMIT_RE = re.compile(r"\bgit\b(?:\s+-[Cc]\s+\S+|\s+--?[\w.-]+(?:=\S+)?)*\s+commit\b")
COMMIT_ALL_RE = re.compile(r"\bcommit\b[^\n]*?\s(?:-[A-Za-z]*a[A-Za-z]*|--all)\b")


def mention_re(project_dir):
    """A protected path as its own token: optionally `./` or the absolute project prefix.
    `docs/project.yml.md` and `Sources/x/project.yml` are NOT mentions."""
    absolute = re.escape(project_dir.rstrip("/") + "/") if project_dir else r"(?!)"
    return re.compile(r"(?:^|(?<=[\s'\"=(`:>]))(?:\./|" + absolute + r")?(?:" + _PATHS + r")(?![\w.-])")


def literal_pattern(project_dir):
    """A protected path as a WHOLE string literal — 'project.yml', "./.deploy/release"."""
    absolute = re.escape(project_dir.rstrip("/") + "/") if project_dir else r"(?!)"
    inner = r"(?:\./|" + absolute + r")?(?:" + _PATHS + r")"
    # no backreference: this pattern is embedded in larger ones, where group numbers shift
    return r"(?:'" + inner + r"(?:/[^'\s]*)?'|\"" + inner + r"(?:/[^\"\s]*)?\")"


def literal_re(project_dir):
    return re.compile(literal_pattern(project_dir))


def code_writes(unit, lit_pattern):
    """The protected literal is the TARGET of a write call — directly, or through a variable
    assigned from it. Reading it and writing some other file is not a write of it."""
    L = lit_pattern
    direct = [
        r"open\(\s*" + L + r"\s*,\s*" + WRITE_MODE,
        r"Path\(\s*" + L + r"\s*\)\s*\.(?:write_text|write_bytes|unlink|rename|replace|touch|open\(\s*" + WRITE_MODE + r")",
        # copy family writes only its DESTINATION (an argument after a comma, or dst=):
        # a protected SOURCE is a read, and a protected source must not hide a protected target
        r"\bshutil\.copy\w*\([^\n]*?(?:,\s*|\bdst\s*=\s*)" + L,
        # move/rename/remove change the source too, so any position counts
        r"\b(?:shutil\.(?:move|rmtree)|os\.(?:replace|rename|remove|unlink|truncate))\([^)]*" + L,
        r"\bfs\.(?:writeFile|writeFileSync|appendFile|appendFileSync|rmSync|unlinkSync|renameSync)\(\s*" + L,
    ]
    if any(re.search(d, unit) for d in direct):
        return True
    for var in set(re.findall(r"\b(\w+)\s*=\s*(?:(?:pathlib\.)?Path\(\s*)?" + L, unit)):
        v = re.escape(var)
        via = [
            r"open\(\s*" + v + r"\s*,\s*" + WRITE_MODE,
            r"\b" + v + r"\.(?:write_text|write_bytes|unlink|rename|replace|touch)\(",
            r"Path\(\s*" + v + r"\s*\)\s*\.(?:write_text|write_bytes|unlink|rename|replace|touch)",
            r"\bshutil\.copy\w*\([^\n]*?(?:,\s*|\bdst\s*=\s*)" + v + r"\b",
            r"\b(?:shutil\.(?:move|rmtree)|os\.(?:replace|rename|remove|unlink|truncate))\([^)]*\b" + v + r"\b",
            r"\bfs\.(?:writeFile|writeFileSync|appendFile|appendFileSync)\(\s*" + v + r"\b",
        ]
        if any(re.search(x, unit) for x in via):
            return True
    return False


_PROSE_RE = re.compile(r"""'[^'\n]*\s[^'\n]*'|"(?:[^"\\\n]|\\.)*\s(?:[^"\\\n]|\\.)*\"""")


def without_prose(text):
    """Blank quoted strings that contain whitespace — a commit message, a `claude -p` prompt,
    a sed script. A quoted PATH has no whitespace and survives, so `sed -i 's/a b/c/'
    'project.yml'` still reads as `sed -i _ 'project.yml'`."""
    return _PROSE_RE.sub("_", text)


def split_segments(line):
    """Split at ; && || | OUTSIDE quotes, so `python3 -c "a; b"` stays one segment."""
    out, cur, quote, i = [], [], None, 0
    while i < len(line):
        ch = line[i]
        if quote:
            cur.append(ch)
            if ch == "\\" and quote == '"' and i + 1 < len(line):
                cur.append(line[i + 1])
                i += 1
            elif ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
            cur.append(ch)
        elif line.startswith(("&&", "||"), i):
            out.append("".join(cur))
            cur = []
            i += 1
        elif ch in ";|":
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
        i += 1
    out.append("".join(cur))
    return [s for s in out if s.strip()]


def units(command):
    """(kind, text) scan units. A heredoc body fed to an INTERPRETER is code and joins the
    segment that opens it; a body fed to anything else (`cat > notes.md`, `tee`,
    `git commit -F -`) is DATA and is dropped — only the head is judged, which is where the
    write target sits. Commit segments are left to rule 2."""
    lines = command.split("\n")
    out, i = [], 0
    while i < len(lines):
        line = lines[i]
        m = HEREDOC_RE.search(line)
        body, j = [], i + 1
        if m:
            while j < len(lines) and lines[j].strip() != m.group(2):
                body.append(lines[j])
                j += 1
        for seg in split_segments(line):
            if COMMIT_RE.search(seg):
                continue
            is_code = bool(INTERPRETER_RE.search(without_prose(seg.split("<<")[0])))
            if m and "<<" in seg and is_code:
                out.append(("code", seg + "\n" + "\n".join(body)))
            else:
                out.append(("code" if is_code else "shell", seg))
        i = j + 1 if m else i + 1
    return out


def text_rule(command, project_dir=""):
    """Rule 1. Returns the protected path a unit writes, or None."""
    mention, literal = mention_re(project_dir), literal_re(project_dir)
    for kind, unit in units(command):
        if kind == "code":
            head, _, body = unit.partition("\n")
            if body and SHELL_INTERPRETER_RE.search(head.split("<<")[0]):
                inner = text_rule(body, project_dir)          # a shell heredoc is shell
                if inner:
                    return inner
            lit = literal.search(unit)
            if lit and code_writes(unit, literal_pattern(project_dir)):
                return lit.group(0).strip("'\"")
        # redirects count for both kinds (`python3 x.py > .deploy/release`), but only on
        # the head line — a heredoc body is code, not shell
        for target in REDIRECT_RE.findall(unit.split("\n")[0]):
            hit = mention.search(target)
            if hit:
                return hit.group(0)
        if kind == "shell":
            unit = without_prose(unit)
            hit = mention.search(unit)
            if hit and SHELL_WRITE_RE.search(unit) and not UNSTAGE_RE.search(unit):
                return hit.group(0)
            if hit and COPY_RE.search(unit):
                args = [a for a in unit.split() if not a.startswith("-") and a not in (">", ">>")]
                dest = next((a[3:] for a in args if a.startswith("of=")), args[-1] if args else "")
                if mention.search(dest.strip("'\"")):
                    return mention.search(dest.strip("'\"")).group(0)
    return None


def is_protected(rel):
    rel = rel[2:] if rel.startswith("./") else rel
    return rel in PROTECTED_FILES or any(rel.startswith(d) for d in PROTECTED_DIRS)


def _git_names(cwd, args):
    try:
        out = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return []
    return [ln.strip() for ln in out.stdout.splitlines() if ln.strip()] if out.returncode == 0 else []


_GIT_PREFIX = r"\bgit\b(?:\s+-[Cc]\s+\S+|\s+--?[\w.-]+(?:=\S+)?)*\s+"
STAGE_RE = re.compile(_GIT_PREFIX + r"(?:add|stage)\b([^\n;&|]*)")
COMMIT_ARGS_RE = re.compile(_GIT_PREFIX + r"commit\b([^\n;&|]*)")
# commit options that take a VALUE — the next token is not a pathspec
_COMMIT_VALUE_OPTS = {"-m", "-F", "-C", "-c", "-t", "--message", "--file", "--author", "--date",
                      "--template", "--reuse-message", "--reedit-message", "--fixup", "--squash",
                      "--trailer", "--cleanup", "--pathspec-from-file"}
_STAGE_ALL = {".", ":/", ":", "-A", "--all", "-u", "--update", "--no-ignore-removal"}


def _pathspecs(args, value_opts=()):
    """Non-option tokens of a git argument string. Quoted prose (a -m message) is blanked
    first, so a message that names a protected path is never read as a pathspec."""
    out, skip, after_dashdash = [], False, False
    for tok in without_prose(args).split():
        if skip:
            skip = False
        elif after_dashdash:
            out.append(tok)
        elif tok == "--":
            after_dashdash = True
        elif tok in _STAGE_ALL:
            out.append(tok)
        elif tok.startswith("-"):
            skip = tok in value_opts
        elif not tok.startswith(("<", ">", "_")):
            out.append(tok)
    return out


def _covers(spec, name, project_dir):
    """Would pathspec `spec` (as written in the command) stage worktree path `name`?"""
    for prefix in ("./", (project_dir.rstrip("/") + "/") if project_dir else None):
        if prefix and spec.startswith(prefix):
            spec = spec[len(prefix):]
    spec = spec.strip("'\"")
    if spec in _STAGE_ALL or any(ch in spec for ch in "*?["):
        return True                                   # everything dirty, conservatively
    return name == spec or name.startswith(spec.rstrip("/") + "/")


def commit_rule(command, cwd, lister=_git_names, project_dir=""):
    """Rule 2. Protected paths this commit would carry. The index is read BEFORE the command
    runs, so paths the same command stages first (`git add x && git commit`, or a pathspec
    commit `git commit x`) are taken from the working tree instead."""
    if not COMMIT_RE.search(command):
        return []
    names = lister(cwd, ["diff", "--cached", "--name-only"])
    specs = [p for m in STAGE_RE.finditer(command) for p in _pathspecs(m.group(1))]
    specs += [p for m in COMMIT_ARGS_RE.finditer(command) for p in _pathspecs(m.group(1), _COMMIT_VALUE_OPTS)]
    if COMMIT_ALL_RE.search(command) or specs:
        dirty = lister(cwd, ["diff", "--name-only"]) + lister(cwd, ["ls-files", "--others", "--exclude-standard"])
        if COMMIT_ALL_RE.search(command):
            names += dirty
        names += [n for n in dirty if any(_covers(sp, n, project_dir) for sp in specs)]
    return sorted({n for n in names if is_protected(n)})


def decide(payload, lister=_git_names):
    if payload.get("tool_name") != "Bash":
        return None
    command = (payload.get("tool_input") or {}).get("command") or ""
    cwd = payload.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    hit = text_rule(command, os.environ.get("CLAUDE_PROJECT_DIR", ""))
    if hit:
        return (f"Founder-gated path '{hit}': this Bash command writes it. "
                "Only the founder releases this, one action at a time.")
    carried = commit_rule(command, cwd, lister, os.environ.get("CLAUDE_PROJECT_DIR", ""))
    if carried:
        return ("This commit carries founder-gated path(s): " + ", ".join(carried) +
                ". Only the founder releases this, one action at a time.")
    return None


def decision_for(payload):
    """"deny" in auto mode, "ask" otherwise (founder 2026-09-28, variant A). Measured in the
    phone cloud session: an "ask" was emitted and the command ran anyway, resolved by an
    instance nobody could name. In auto mode "ask" is therefore not a lock. A missing or
    unknown permission_mode keeps "ask" — the measured behaviour of default mode."""
    return "deny" if isinstance(payload, dict) and payload.get("permission_mode") == "auto" else "ask"


def emit(decision, reason):
    if decision == "deny":
        reason += (" Denied because the session runs in auto mode, where an \"ask\" did not"
                   " hold. Release: the founder edits it himself, or runs this step in"
                   " default mode.")
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}))


def main():
    raw = sys.stdin.read()
    payload = None
    try:
        payload = json.loads(raw)
        reason = decide(payload)
    except Exception:  # noqa: BLE001 — fail-open, but never on a protected mention
        reason = ("Hook error while checking a command that names a founder-gated path."
                  if mention_re("").search(raw) else None)
    if reason:
        if payload is None and re.search(r'"permission_mode"\s*:\s*"auto"', raw):
            payload = {"permission_mode": "auto"}
        emit(decision_for(payload), reason)
    return 0


def selftest():
    staged = {"cached": [], "worktree": []}

    def fake(cwd, args):
        return list(staged["cached"] if "--cached" in args else staged["worktree"])

    cases = [
        # (command, cached, worktree, expect_ask, label)
        ("cat project.yml", [], [], False, "read is not a write"),
        ("grep -n Echoelmusic project.yml | head", [], [], False, "read through a pipe"),
        ("git diff project.yml", [], [], False, "git read"),
        ("sed -n '1,20p' project.yml", [], [], False, "sed without -i"),
        ("grep -n x project.yml 2>/dev/null | head", [], [], False, "stderr redirect is not a write"),
        ("python3 -c \"print(open('project.yml').read())\"", [], [], False, "python read"),
        ("python3 -c \"open('project.yml','w').write('x')\"", [], [], True, "python -c write (the measured gap)"),
        ("python3 -c \"p='.deploy/release'; open(p,'w').write('x')\"", [], [], True, "python -c with ; inside quotes"),
        ("python3 - <<'EOF'\nimport pathlib\np = pathlib.Path('.github/workflows/ci.yml')\np.write_text('x')\nEOF",
         [], [], True, "python heredoc body write"),
        ("python3 - <<'EOF'\np='CLAUDE.md'; s=open(p).read()\ns=s.replace('project.yml + Info.plist','x')\nopen(p,'w').write(s)\nEOF",
         [], [], False, "python edits ANOTHER file whose prose names project.yml"),
        ("printf 'v2' > .deploy/release", [], [], True, "redirect"),
        ("echo x >> ./.github/workflows/ci.yml", [], [], True, "append, ./ prefix, nested dir"),
        ("sed -i 's/a/b/' Resources/iOS/Info.plist", [], [], True, "sed -i"),
        ("cp notes.md Resources/iOS/Info.plist", [], [], True, "cp onto"),
        ("cp .deploy/release /tmp/release.prev", [], [], False, "cp FROM a protected file is a read"),
        # regression 2026-09-28: shutil.copy FROM a protected source is a read
        ("python3 -c \"import shutil; shutil.copy('.deploy/release', '/tmp/r')\"", [], [], False, "shutil.copy from a protected source"),
        ("python3 -c \"import shutil; p='.deploy/release'; shutil.copy2(p, 'out.txt')\"", [], [], False, "shutil.copy2 from a protected variable"),
        ("python3 -c \"import shutil; shutil.copy('project.yml', '.deploy/release')\"", [], [], True, "shutil.copy protected -> protected: the target counts"),
        ("python3 -c \"import shutil; p='project.yml'; q='.deploy/release'; shutil.copy(p, q)\"", [], [], True, "shutil.copy protected var -> protected var"),
        ("python3 -c \"import shutil; shutil.copyfile(dst='.deploy/release', src='/tmp/r')\"", [], [], True, "shutil.copyfile dst= keyword FIRST (no comma before it)"),
        ("python3 -c \"import shutil; shutil.copy('/tmp/r', '.deploy/release')\"", [], [], True, "shutil.copy onto a protected target"),
        ("python3 -c \"import shutil; shutil.move('.deploy/release', '/tmp/r')\"", [], [], True, "shutil.move removes the protected source"),
        ("python3 - <<'EOF'\nnote = open('.deploy/release').read().replace('*','')\nopen('out.txt','w').write(note)\nEOF",
         [], [], False, "python reads the protected file, writes another"),
        ("python3 - <<'EOF'\np = '.deploy/release'\ns = open(p, encoding='utf-8').read()\nopen(p, 'w', encoding='utf-8').write(s)\nEOF",
         [], [], True, "python writes through a variable"),
        ("git checkout main -- project.yml", [], [], True, "git checkout path"),
        ("git restore --staged .github/workflows/ci.yml", [], [], False, "unstaging touches the index only"),
        ("git reset -q -- .deploy/release", [], [], False, "reset of a path unstages"),
        ("git restore --staged --worktree project.yml", [], [], True, "--worktree writes the file"),
        ("git restore project.yml", [], [], True, "restore without --staged writes the file"),
        ("printf 'One touch of .deploy/release per deploy' > $SP/msg.txt", [], [], False, "prose in quotes names path and a verb"),
        ("claude -p \"run python3 -c to write project.yml\" < /dev/null", [], [], False, "interpreter named only inside a prompt"),
        ("sed -i 's/a b/c d/' 'project.yml'", [], [], True, "quoted sed script, quoted path"),
        ("echo x > /REPO/project.yml", [], [], True, "absolute project path"),
        ("cat > .deploy/release <<'EOF'\nbuild: v2\nEOF", [], [], True, "heredoc DATA into a protected file"),
        ("bash <<'EOF'\nsed -i 's/a/b/' project.yml\nEOF", [], [], True, "shell heredoc body is code"),
        ("echo ok > notes.md", [], [], False, "unprotected write"),
        ("sed -i 's/a/b/' Sources/Echoelmusic/project.yml.swift", [], [], False, "look-alike name"),
        ("echo x > docs/project.yml", [], [], False, "same name in another dir"),
        ("cat > Tests/CISmoke/XTests.swift <<'EOF'\n// reads project.yml and .deploy/release\nEOF",
         [], [], False, "a .swift FILE NAME is not the swift interpreter"),
        ("cat > scratchpads/NOTE.md <<'EOF'\nwe rm .deploy/release and cp project.yml\nEOF",
         [], [], False, "heredoc DATA into another file"),
        ("git commit -m msg", ["Sources/A.swift"], [], False, "commit without protected"),
        ("git -c user.name=C commit -q -F - <<'EOF'\nfix: rm .deploy/release > project.yml\nEOF",
         ["Sources/A.swift"], [], False, "commit message prose is data"),
        ("git -c user.name=C commit -q -F - <<'EOF'\nmsg\nEOF", ["project.yml"], [], True, "commit carries project.yml"),
        ("git commit -am x", [], [".deploy/release"], True, "commit -a picks up worktree"),
        ("git commit -m x", [], [".deploy/release"], False, "unstaged, no -a: not carried"),
        # regression 2026-09-28: staging and commit in ONE command (index read before it runs)
        ("git add project.yml && git commit -m x", [], ["project.yml"], True, "add + commit in one command"),
        ("git add -A && git commit -q -m 'touch project.yml'", [], [".deploy/release"], True, "add -A + commit"),
        ("git add .github && git commit -m x", [], [".github/workflows/ci.yml"], True, "add a covering dir + commit"),
        ("git commit -m x -- project.yml", [], ["project.yml"], True, "pathspec commit stages the path"),
        ("git add notes.md && git commit -m 'edit project.yml later'", [], ["notes.md", "project.yml"], False,
         "add + commit of an unprotected file; message prose is no pathspec"),
        ("f=$(echo cHJvamVjdC55bWw= | base64 -d); echo x > $f", [], [], False, "encoded path: rule 1 blind (limit)"),
    ]
    os.environ["CLAUDE_PROJECT_DIR"] = "/REPO"
    bad = 0
    for cmd, cached, work, want, label in cases:
        staged["cached"], staged["worktree"] = cached, work
        got = decide({"tool_name": "Bash", "tool_input": {"command": cmd}, "cwd": "."}, fake) is not None
        ok = got == want
        bad += not ok
        print(f"{'ok ' if ok else 'BAD'} {'ask ' if got else 'pass'}  {label}")
    none = decide({"tool_name": "Edit", "tool_input": {"file_path": "project.yml"}}, fake)
    print(f"{'ok ' if none is None else 'BAD'} pass  Edit tool is the built-in rules' job")
    bad += none is not None
    # variant A: the DECISION a recognised write gets, per permission mode
    modes = [({"permission_mode": "auto"}, "deny"), ({"permission_mode": "default"}, "ask"),
             ({}, "ask"), (None, "ask")]
    for payload, want in modes:
        got = decision_for(payload)
        ok = got == want
        bad += not ok
        mode = None if payload is None else payload.get("permission_mode")
        print(f"{'ok ' if ok else 'BAD'} {got:<4}  permission_mode={mode}")
    total = len(cases) + 1 + len(modes)
    print(f"\n{total - bad}/{total} selftest cases hold")
    return 1 if bad else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    if "--limits" in sys.argv:
        print(LIMITS)
        sys.exit(0)
    sys.exit(main())
