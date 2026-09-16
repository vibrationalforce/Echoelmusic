#!/usr/bin/env python3
"""PRE-BATCH CALCULATOR for the Genre-Welt epic. Read-only.

Answers every arithmetic the batch template says to run BEFORE writing a genre batch,
from the SHIPPED tree plus a JSON spec of the candidates. Written after #1286, where
five false prose claims were found by measuring what had been remembered.

    python3 scripts/genre-prebatch.py <candidates.json>
    python3 scripts/genre-prebatch.py --patch "<Patch Name>"
    python3 scripts/genre-prebatch.py --selftest

⭐ THE `--patch` MODE EXISTS BECAUSE OF #1350, AND IT IS THE CHEAPEST LESSON IN THIS FILE.
Ten wrong numbers reached TWO shipped doc comments in `GenrePatches.swift` — five of them in
code that had already merged — because a throwaway parser silently matched 31 of the file's
73 `patch(` blocks and reported only what it found. Every claim derived from it ("FREE
between X and Y", "the darkest", "the sixth-slowest") was a coin flip on whether the real
neighbour happened to be inside the 31. **A measurement that cannot state its own COVERAGE
is not a measurement**; this mode prints `parsed N of M` and REFUSES to report when N != M.
Write a patch doc comment from ITS output, never from a parser typed for the occasion.

⭐ WHY THIS FILE IS IN THE REPO (#1320). It was authored inside a SESSION SCRATCHPAD and
lived there through G6a…G11b, while `scratchpads/PLAN_GENRE_WELT_2026-09-11.md` cited it
by that path as the measurement every remaining batch must run first. A scratchpad dies
with its container: the plan's own recipe was one session away from being unrunnable, and
the next session would have gone back to remembering — which is the exact failure #1286
paid for. Same law as the repo's "a pointer is only as durable as what it points at",
one level out: a RECIPE is only as durable as the tool it names.

⚠️ READ-ONLY BY CONSTRUCTION. It parses `Sources/Echoelmusic/Sequencer/*.swift` and a
JSON file; it writes nothing and imports nothing from the tree. A green run says the
arithmetic of a DRAFT holds, never that the genre sounds good — that is an ear.

Candidate shape (one object per genre, all keys required except `sustained`/`arpeggiated`):
  {"name":"blackMetal","displayName":"Black Metal","scale":"hungarianMinor",
   "beatArchetype":"backbeat","tempoRange":[160,200],"defaultTempo":180,"swing":0.0,
   "leadPatchName":"Warm Strings","progression":[0,1,6],"chordTones":[0,4,7],
   "padOctave":4,"defaultMode":"studioLocked","synthPatch":"Cold Stack",
   "bassPatch":"Cold Sub","bassGrammar":"drivingEighths","delayDivisionQuarters":null,
   "arpeggiated":false,"sustained":false}
"""
import re, io, json, math, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'Sources', 'Echoelmusic', 'Sequencer') + os.sep
def code(t): return "\n".join(re.sub(r"//.*$","",l) for l in t.split("\n"))

def load_table():
    text=io.open(SRC+'MusicStyle.swift',encoding='utf-8').read()

    def strip_comments(t):
        out=[]; in_block=False
        for line in t.split('\n'):
            res=''; j=0
            while j < len(line):
                if in_block:
                    k=line.find('*/', j)
                    if k<0: j=len(line); break
                    in_block=False; j=k+2; continue
                if line.startswith('//', j): break
                if line.startswith('/*', j): in_block=True; j+=2; continue
                if line[j]=='"':
                    k=j+1
                    while k < len(line):
                        if line[k]=='\\': k+=2; continue
                        if line[k]=='"': k+=1; break
                        k+=1
                    res+=line[j:k]; j=k; continue
                res+=line[j]; j+=1
            out.append(res)
        return '\n'.join(out)

    code = strip_comments(text)

    def prop_body(sig):
        i = code.find(sig)
        if i < 0: return None
        # brace match from the first { after sig
        j = code.index('{', i)
        depth=0
        for k in range(j, len(code)):
            if code[k]=='{': depth+=1
            elif code[k]=='}':
                depth-=1
                if depth==0: return code[j+1:k]
        return None

    def switch_body(body):
        if body is None: return None
        i = body.find('switch self {')
        if i < 0: return body
        j = body.index('{', i); depth=0
        for k in range(j, len(body)):
            if body[k]=='{': depth+=1
            elif body[k]=='}':
                depth-=1
                if depth==0: return body[j+1:k]
        return None

    def cases_of(body, depth_target=1):
        """Return list of (list_of_case_names, arm_text) for top-level `case .x, .y:` arms."""
        body = switch_body(body)
        if body is None: return []
        out=[]; lines=body.split('\n'); depth=0; cur=None; buf=[]; pending=''
        for line in lines:
            stripped=line.strip()
            if depth==0:
                probe = (pending + ' ' + stripped).strip() if pending else stripped
                if probe.startswith('case ') or probe.startswith('default:'):
                    if probe.startswith('case ') and ':' not in probe:
                        pending = probe
                        depth += line.count('{') - line.count('}')
                        continue
                    pending=''
                    m = re.match(r'^case ((?:\.\w+\s*,?\s*)+):(.*)$', probe, re.S)
                    d = re.match(r'^default:(.*)$', probe, re.S)
                    if m or d:
                        if cur is not None: out.append((cur,'\n'.join(buf)))
                        if m:
                            cur=[c.strip().lstrip('.') for c in m.group(1).split(',') if c.strip()]
                            buf=[m.group(2)]
                        else:
                            cur=['__default__']; buf=[d.group(1)]
                        depth += line.count('{') - line.count('}')
                        continue
            if cur is not None: buf.append(line)
            depth += line.count('{') - line.count('}')
        if cur is not None: out.append((cur,'\n'.join(buf)))
        return out

    # enum cases
    enum_i = code.find('public enum MusicStyle')
    enum_body = prop_body('public enum MusicStyle')
    names=[]
    depth=0
    for line in enum_body.split('\n'):
        s=line.strip()
        if depth==0:
            m=re.match(r'^case (\w+)(?:\s*=\s*"[^"]*")?\s*$', s)
            if m: names.append(m.group(1))
        depth += line.count('{') - line.count('}')

    props = {
     'displayName':'public var displayName: String {',
     'lineage':'public var lineage: String {',
     'beatArchetype':'public var beatArchetype: BeatArchetype {',
     'tempoRange':'public var tempoRange: ClosedRange<Double> {',
     'defaultTempo':'public var defaultTempo: Double {',
     'swing':'public var swing: Double {',
     'leadPatchName':'public var leadPatchName: String {',
     'mixLevels':'public var mixLevels: (bass: Float, harmony: Float, lead: Float) {',
     'scale':'public var scale: Scale {',
     'harmonicProfile':'public var harmonicProfile: HarmonicProfile {',
     'subcategory':'public var subcategory: Subcategory {',
     'defaultMode':'public var defaultMode: ComposerMode {',
    }
    table={n:{} for n in names}
    missing={}
    for pname,sig in props.items():
        body=prop_body(sig)
        arms=cases_of(body)
        covered=set()
        for cs,arm in arms:
            for c in cs:
                if c=='__default__': continue
                covered.add(c)
                if c in table: table[c][pname]=' '.join(arm.split())
        has_default=any('__default__' in cs for cs,_ in arms)
        missing[pname]=(sorted(set(names)-covered), has_default)
    return {'names': names, 'table': table}

d=load_table(); NAMES=d['names']; T=d['table']
msc=code(io.open(SRC+'MusicStyle.swift',encoding='utf-8').read())
OFFERED=[x for x in re.findall(r"\.(\w+)",
    re.search(r"static let offered: \[MusicStyle\] = \[(.*?)\]", msc, re.S).group(1))]
def g(p,n,dflt=None):
    v=T.get(n,{}).get(p); return v.replace('return ','').strip() if v else dflt
def hp(n,k,dflt=None):
    v=g('harmonicProfile',n)
    if not v: return dflt
    m=re.search(k+r":\s*(\[[^\]]*\]|[-\w.]+)", v); return m.group(1) if m else dflt
def ints(s): return [int(x) for x in re.findall(r"-?\d+", s)] if s else []

# scale intervals
mk=code(io.open(SRC+'MusicalKey.swift',encoding='utf-8').read())
IV={}
for m in re.finditer(r"case ((?:\.\w+(?:, )?)+):\s*return \[([0-9, ]+)\]", mk):
    for n in [x.strip().lstrip('.') for x in m.group(1).split(',')]: 
        IV[n]=[int(x) for x in m.group(2).split(',') if x.strip()]
def stack(scale,ct,oct_):
    iv=IV[scale]; n=len(iv)
    def deg(i):
        sh=math.floor(i/n); return (oct_+1)*12+iv[i-sh*n]+12*sh
    r=deg(ct[0]); return [deg(c)-r for c in ct]

# patches
gp=code(io.open(SRC+'GenrePatches.swift',encoding='utf-8').read())
PATCHES=re.findall(r'patch\(\s*"([^"]*)"\s*,\s*"([^"]*)"', gp)
SUFFIX={i for i,_ in PATCHES}; PNAMES=[nm for _,nm in PATCHES]

ART={'offbeat':'skank','fourOnFloor':'stab','backbeat':'comp',
     'halfTime':'sustained','none':'sustained','signature':'sustained'}
def fingerprint(n):
    return (ART[g('beatArchetype',n).lstrip('.')], g('scale',n).lstrip('.'),
            tuple(ints(hp(n,'progression'))), tuple(ints(hp(n,'chordTones'))),
            int(hp(n,'padOctave')), hp(n,'arpeggiated','false')=='true',
            hp(n,'sustained','false')=='true')
def cand_fingerprint(c):
    return (ART[c['beatArchetype']], c['scale'], tuple(c['progression']),
            tuple(c['chordTones']), c['padOctave'],
            bool(c.get('arpeggiated',False)), bool(c.get('sustained',False)))

WARM={'Deep Sub','Soft Keys','Pluck','Hollow Reed','Choir Vox','Warm Strings'}

def selftest():
    """Drive the tool's two sharpest checks against candidates BUILT FROM THE SHIPPED TREE.

    #808 — a needle that only ever runs on a passing input is verified by nothing. Both
    cases below must FAIL, each for its own named reason, or this tool can go green on a
    draft it should have refused. The inputs are derived, never typed: a hand-written
    fixture ages out of the tree it is supposed to describe.
    """
    import subprocess, tempfile
    low = min(int(hp(n,'padOctave')) for n in OFFERED)
    twin = next((n for n in OFFERED if int(hp(n,'padOctave')) > low), None)
    if twin is None:
        print("SELFTEST: no offered genre sits above the lowest padOctave — cannot build a "
              "clone without tripping check 6 as well. That is a finding about the tree, "
              "not a pass.")
        return 1
    base = {"name": "selftestClone", "displayName": "Selftest Clone",
            "scale": g('scale', twin).lstrip('.'),
            "beatArchetype": g('beatArchetype', twin).lstrip('.'),
            "tempoRange": [120, 140], "defaultTempo": 130, "swing": 0.0,
            "leadPatchName": g('leadPatchName', twin).strip('"'),
            "progression": ints(hp(twin,'progression')),
            "chordTones": ints(hp(twin,'chordTones')),
            "padOctave": int(hp(twin,'padOctave')),
            "defaultMode": g('defaultMode', twin).lstrip('.'),
            "synthPatch": "Selftest Stack", "bassPatch": "Selftest Sub",
            "bassGrammar": None, "delayDivisionQuarters": None,
            "arpeggiated": hp(twin,'arpeggiated','false')=='true',
            "sustained": hp(twin,'sustained','false')=='true'}
    cases = [("a clone of an offered genre's fingerprint must clash", base, "share"),
             ("an unshipped BassGrammar case must be named as absent",
              dict(base, bassGrammar="thisFigureDoesNotExist"),
              "is not a shipped BassGrammar case")]
    failures = 0
    for title, cand, needle in cases:
        path = tempfile.mktemp(suffix=".json")
        json.dump([cand], open(path, "w"))
        r = subprocess.run([sys.executable, os.path.abspath(__file__), path],
                           capture_output=True, text=True)
        os.unlink(path)
        ok = r.returncode != 0 and needle in r.stdout
        print(("   ok   " if ok else "   FAIL ") + title)
        if not ok:
            failures += 1
            print(f"        exit={r.returncode} needle={needle!r} not found in output")
    # #1350 — the `--patch` mode's two refusals, both driven rather than asserted in prose.
    for title, argv, needle in [
        ("--patch must refuse a name that is not shipped",
         ["--patch", "ThisPatchIsNotShipped"], "no shipped patch is named"),
        ("--patch must refuse with no name at all", ["--patch"], "needs a patch name"),
    ]:
        r = subprocess.run([sys.executable, os.path.abspath(__file__)] + argv,
                           capture_output=True, text=True)
        ok = r.returncode != 0 and needle in r.stdout
        print(("   ok   " if ok else "   FAIL ") + title)
        if not ok:
            failures += 1
            print(f"        exit={r.returncode} needle={needle!r} not found in output")

    # And its POSITIVE case, derived from the tree so it cannot age: the first shipped patch
    # name must report, and the report must state full coverage. A mode that only ever
    # refuses is not verified either (#808, the other direction).
    first = PNAMES[0]
    r = subprocess.run([sys.executable, os.path.abspath(__file__), "--patch", first],
                       capture_output=True, text=True)
    want = f"parsed {len(PATCHES)} of {len(PATCHES)}"
    ok = r.returncode == 0 and want in r.stdout
    print(("   ok   " if ok else "   FAIL ") + f'--patch "{first}" reports at full coverage')
    if not ok:
        failures += 1
        print(f"        exit={r.returncode} expected {want!r} in output")

    print(f"SELFTEST (cloned from .{twin}):", "OK" if failures == 0 else f"{failures} BROKEN CHECK(S)")
    return 1 if failures else 0

PATCH_FIELDS=['a','d','s','r','harm','hl','bright','noise','cutoff','res',
              'lfoAmt','lfoRate','lfoDepth','revMix','revDecay','vibRate','vibDepth','uni','det']

def patch_table():
    """Every shipped patch's numeric fields, WITH the block count it was derived from.

    Returns (table, blocks_seen). A caller that does not compare `len(table)` against
    `blocks_seen` has reproduced the #1350 defect exactly.
    """
    ms=list(re.finditer(r'patch\(\s*"([^"]*)"\s*,\s*"([^"]*)"', gp))
    out={}
    for i,m in enumerate(ms):
        end = ms[i+1].start() if i+1 < len(ms) else len(gp)
        b = gp[m.start():end]
        vals={}
        for f in PATCH_FIELDS:
            mm=re.search(r'\b%s:\s*(-?[0-9]+\.?[0-9]*)' % f, b)
            if mm: vals[f]=float(mm.group(1))
        adsr=[vals.get(k) for k in ('a','d','s','r')]
        if all(v is not None for v in adsr): vals['env(a+d+s+r)']=round(sum(adsr),4)
        out[m.group(2)]=vals
    return out, len(ms)

def patch_report(name):
    T, blocks = patch_table()
    print(f"PATCH NEIGHBOURHOOD \u2014 parsed {len(T)} of {blocks} `patch(` blocks")
    if len(T) != blocks:
        print(f"   REFUSED: the parser covered {len(T)} of {blocks} blocks. Nothing below "
              f"would be trustworthy, and a partial answer is the #1350 defect itself.")
        return 2
    if name not in T:
        near=[n for n in T if name.lower() in n.lower() or n.lower() in name.lower()]
        print(f'   no shipped patch is named "{name}".'
              + (f" Did you mean: {near}?" if near else f" {len(T)} names are shipped."))
        return 2
    me=T[name]
    print(f'   "{name}" \u2014 {len(me)} numeric fields\n')
    for f in list(PATCH_FIELDS)+['env(a+d+s+r)']:
        if f not in me: continue
        v=me[f]
        xs=sorted((o[f], n) for n, o in T.items() if f in o)
        same=[n for val, n in xs if val == v and n != name]
        below=[(n, val) for val, n in xs if val < v][-2:]
        above=[(n, val) for val, n in xs if val > v][:2]
        tag = f"TIED with {same}" if same else "SOLE HOLDER"
        pad = ' ' * 16
        lo_txt = below if below else '\u2014 (this is the file minimum)'
        hi_txt = above if above else '\u2014 (this is the file maximum)'
        print(f"   {f:16s} {v:<10g} {tag}")
        print(f"   {pad} below {lo_txt}")
        print(f"   {pad} above {hi_txt}")
    print("\n   File-wide extremes, for the \"the darkest / the longest\" kind of claim:")
    for f in list(PATCH_FIELDS)+['env(a+d+s+r)']:
        xs=sorted((o[f], n) for n, o in T.items() if f in o)
        if not xs: continue
        lo=[n for val, n in xs if val == xs[0][0]]; hi=[n for val, n in xs if val == xs[-1][0]]
        print(f"   {f:16s} min {xs[0][0]:<10g} {lo}   max {xs[-1][0]:<10g} {hi}")
    print("\n\u26a0 A free value is not a good value. This mode answers \"does this number take "
          "a rank\", never \"does the patch sound right\" \u2014 that is an ear.")
    return 0

if "--patch" in sys.argv:
    i=sys.argv.index("--patch")
    if i+1 >= len(sys.argv):
        print('--patch needs a patch name, e.g. --patch "Wobble Keys"')
        sys.exit(2)
    sys.exit(patch_report(sys.argv[i+1]))

if "--selftest" in sys.argv:
    sys.exit(selftest())

if len(sys.argv) < 2:
    print(__doc__)
    sys.exit(2)
cands=json.load(open(sys.argv[1]))
print(f"SHIPPED: {len(NAMES)} genres, {len(OFFERED)} offered, {len(PATCHES)} patches")
print(f"ADDING : {len(cands)} — {', '.join(c['name'] for c in cands)}\n")
bad=0
def fail(m):
    global bad; bad+=1; print("  ✗",m)

# 1 — lead ceiling (ceil(bearing/6), fixed divisor: GenreBatchFourVoicingTests)
bearing=[n for n in NAMES if hp(n,'sustained','false')!='true']
cnt={}
for n in bearing: cnt[g('leadPatchName',n).strip('"')]=cnt.get(g('leadPatchName',n).strip('"'),0)+1
new_bearing=len(bearing)+sum(1 for c in cands if not c.get('sustained',False))
ceiling=math.ceil(new_bearing/6)
after=dict(cnt)
for c in cands:
    if c.get('sustained',False): continue
    after[c['leadPatchName']]=after.get(c['leadPatchName'],0)+1
print(f"1 LEAD CEILING — bearing {len(bearing)} → {new_bearing}, ceiling {math.ceil(len(bearing)/6)} → {ceiling}")
print("   before:", cnt); print("   after :", after)
for nm,v in sorted(after.items()):
    if nm not in WARM: fail(f'"{nm}" is not one of the six warm leads {sorted(WARM)}')
    elif v>ceiling: fail(f'"{nm}" would be on {v} of {new_bearing} — over the ceiling {ceiling}')
if len({k for k,v in after.items() if v>0})<5: fail("fewer than 5 distinct warm leads in play")
if bad==0: print("   ok\n")
else: print()

# 2 — fingerprint sweep over offered + candidates
print("2 FINGERPRINT (offered only, 7-tuple)")
seen={}
for n in OFFERED: seen.setdefault(fingerprint(n),[]).append(n)
for c in cands: seen.setdefault(cand_fingerprint(c),[]).append(c['name'])
clash=[(k,v) for k,v in seen.items() if len(v)>1]
if clash:
    for k,v in clash: fail(f"{v} share {k}")
else: print("   ok — no two offered genres share an audible fingerprint\n")

# 3 — patch suffixes and names
print("3 PATCHES")
want=[c['synthPatch'] for c in cands]+[c['bassPatch'] for c in cands if c.get('bassPatch')]
for nm in want:
    if nm in PNAMES: fail(f'patch name "{nm}" is already shipped')
dups=[x for x in want if want.count(x)>1]
if dups: fail(f"candidate patch names repeat: {sorted(set(dups))}")
nxt=[]
i=0
while len(nxt)<len(want):
    s=str(48+i); i+=1
    if s not in SUFFIX: nxt.append(s)
print(f"   free suffixes to use, in order: {nxt}")
if not [x for x in want if x in PNAMES] and not dups: print("   ok\n")
else: print()

# 4 — voicing resolved to semitones, and who else carries the array
print("4 VOICING (degrees resolved through MusicalKey.degree — never read as semitones)")
for c in cands:
    if c['scale'] not in IV: fail(f"{c['name']}: scale .{c['scale']} is not in MusicalKey"); continue
    st=stack(c['scale'],c['chordTones'],c['padOctave'])
    same=[n for n in NAMES if ints(hp(n,'chordTones'))==list(c['chordTones'])]
    samesc=[n for n in NAMES if g('scale',n)=='.'+c['scale']]
    sameprog=[n for n in NAMES if ints(hp(n,'progression'))==list(c['progression'])]
    print(f"   {c['name']:18s} {c['chordTones']} on {c['scale']:16s} = {st} semitones")
    print(f"       same chordTones: {same or '—'}")
    print(f"       same scale     : {samesc or '— (unique)'}"
          + (f"  [offered: {[x for x in samesc if x in OFFERED]}]" if samesc else ""))
    print(f"       same progression: {sameprog or '— (unique)'}")
print()

# 5 — tempo windows, defaults, octave fold and the delay ceiling
print("5 TEMPO + DELAY CEILING (maxDelaySeconds = 2.0)")
for c in cands:
    lo,hi=c['tempoRange']
    if not lo<=c['defaultTempo']<=hi: fail(f"{c['name']}: default {c['defaultTempo']} outside {lo}…{hi}")
    if hi/lo>=2.0: fail(f"{c['name']}: window {lo}…{hi} spans an octave — GenreTempoFoldTests' sub-octave half switches OFF")
    q=c.get('delayDivisionQuarters')
    if q:
        secs=q*60.0/hi
        mark="ok" if secs<=2.0 else "OVER"
        if secs>2.0: fail(f"{c['name']}: delay {q} quarters at {hi} BPM = {secs:.2f}s > 2.0s ceiling")
        else: print(f"   {c['name']:18s} delay {q} q at hi={hi} = {secs:.2f}s  {mark}")
    else:
        print(f"   {c['name']:18s} no delay")
print()

# 6 — register floor and mode
print("6 REGISTER + MODE")
low=min(int(hp(n,'padOctave')) for n in OFFERED)
holder=[n for n in OFFERED if int(hp(n,'padOctave'))==low]
print(f"   lowest offered padOctave today: {low} ({holder})")
for c in cands:
    if c['padOctave']<=low: fail(f"{c['name']}: padOctave {c['padOctave']} takes the lowest-register claim from {holder}")
    if c.get('sustained',False) and c['defaultMode']!='flowFree':
        print(f"   ⚠ {c['name']}: sustained Fläche on .{c['defaultMode']} — check, G5a's two are .flowFree")
    # ⛔ THIS CHECK USED `sustained` AS A PROXY FOR "HAS A BEAT" AND PRINTED
    # "beat-driven on .flowFree" for a genre whose archetype is `.none`. `isBeatDriven`
    # is `beatArchetype != .none` in the shipped source, and `ambientPulse` and
    # `slowBloom` are both `.none` + not-sustained + `.flowFree` today, so the warning
    # fired on a shape that ships twice over. Read the ARCHETYPE, which is the property
    # the app reads (#1290).
    if c['beatArchetype'] != 'none' and c['defaultMode'] != 'studioLocked':
        print(f"   ⚠ {c['name']}: archetype .{c['beatArchetype']} on .flowFree — "
              f"no shipped genre pairs a drum pattern with a body-followed tempo")
    if c['beatArchetype'] == 'none' and not c.get('sustained',False):
        print(f"   • {c['name']}: drum-free but not `sustained` — the onset generator runs "
              f"(the ambientPulse/slowBloom shape), intended?")
print()

# 7 — bass grammar co-ownership: figure may be shared, VOICE may not (#1286)
print("7 BASS GRAMMAR (figure shareable, voice never)")
bg=code(io.open(SRC+'BassGrammar.swift',encoding='utf-8').read())
BG={}
for m in re.finditer(r"case \.(\w+):\s*return \.(\w+)", bg[bg.index("var bassGrammar"):]):
    BG[m.group(1)]=m.group(2)
# ⛔ THE SHIPPED CASES, read from the enum itself. Without this the tool printed
# "existing owners: — (first)" for `pedalDrone`, a case that DOES NOT EXIST — it could
# not tell an empty figure from an absent one, and "(first)" reads as encouragement.
# `.claude/rules/context.md` §2: a parser that matches nothing is a finding, not a pass.
FIGURES=re.findall(r"^    case (\w+)$",
                   bg[bg.index("public enum BassGrammar"):bg.index("public struct Hit")], re.M)
assert FIGURES, "no BassGrammar cases extracted — the parser, not the tree"
print(f"   shipped figures: {FIGURES}")
for c in cands:
    fg=c.get('bassGrammar')
    if not fg: print(f"   {c['name']:18s} no figure"); continue
    if fg not in FIGURES:
        fail(f"{c['name']}: `{fg}` is not a shipped BassGrammar case — authoring it is its own "
             f"slice (one enum case, one `hits` arm, one map arm, one guard)")
        continue
    owners=[n for n in NAMES if BG.get(n)==fg]
    print(f"   {c['name']:18s} {fg:20s} existing owners: {owners or '— (first)'}")
    if not c.get('bassPatch'): fail(f"{c['name']} has a figure and no bass patch of its own")
print()
print("PRE-BATCH:", "OK" if bad==0 else f"{bad} BLOCKER(S)")
sys.exit(1 if bad else 0)
