"""Simulated GitHub API answers against the auto-merge poll step (#310).

Usage: python3 -I scratchpads/AUTO_MERGE_310_sim.py <workflow.yml> [<workflow.yml> ...]
Extracts the run block of "Wait for the gates that decide whether main compiles",
replaces gh/date/sleep with fakes (fake clock, scripted answers per call), and
checks the verdict per scenario. Exit 1 if the LAST file given fails a scenario.
Read-only: writes only to a temp dir it deletes."""
import json, os, re, subprocess, sys, tempfile, shutil
STEP = "      - name: Wait for the gates that decide whether main compiles"
def extract(yml):
    lines = open(yml).read().split("\n")
    i = lines.index(STEP)
    j = next(k for k in range(i, len(lines)) if lines[k] == "        run: |")
    body = []
    for l in lines[j+1:]:
        if l.startswith("      - name:"): break
        body.append(l[10:] if l.startswith("          ") else l.strip())
    return "\n".join(body)
PRELUDE = r'''
date(){ cat "$SIM/now"; }
sleep(){ echo $(( $(cat "$SIM/now") + $1 )) > "$SIM/now"; }
gh(){
  local url="$2" kind=runs
  case "$url" in */jobs*) kind=jobs;; esac
  local n=$(( $(cat "$SIM/n_$kind" 2>/dev/null || echo 0) + 1 )); echo $n > "$SIM/n_$kind"
  local t=$(cat "$SIM/now"); local f
  f=$(python3 "$SIM/pick.py" "$SIM/$kind.json" $n $t) || return 1
  [ "$f" = "FAIL" ] && { echo "gh: HTTP 502 (simulated)" >&2; return 1; }
  printf '%s' "$f"
}
'''
PICK = r'''
import json,sys
seq=json.load(open(sys.argv[1])); n=int(sys.argv[2]); t=int(sys.argv[3])
# entries: [from_call, payload]  payload "FAIL" | object ; pick the last entry whose from_call <= n
cur=None
for frm,p in seq:
    if frm<=n: cur=p
if cur=="FAIL": print("FAIL")
elif isinstance(cur,str): print(cur)
else: print(json.dumps(cur))
'''
def runs(compile=None, ci=None):
    wr=[]
    if compile: wr.append({"name":"Xcode Compile Check","run_started_at":"2026-10-07T14:00:00Z","status":compile[0],"conclusion":compile[1]})
    if ci: wr.append({"name":"Echoelmusic CI/CD Pipeline","run_started_at":"2026-10-07T14:00:00Z","id":42,"status":ci})
    return {"workflow_runs":wr}
def jobs(bft):
    steps=[] if bft=="absent" else [{"name":"Build for Testing","conclusion":bft}]
    return {"jobs":[{"steps":steps}]}
OKC=("completed","success")
SCEN = {
 "runs-fail-after-grace": ([[1,runs(("in_progress",None),"in_progress")],[12,"FAIL"],[13,runs(OKC,"completed")]],
                           [[1,jobs(None)],[3,jobs("success")]], "success/success"),
 "jobs-fail-on-completed-ci": ([[1,runs(OKC,"completed")]], [[1,"FAIL"],[2,jobs("success")]], "success/success"),
 "runs-shapeless-answer": ([[1,'{"message":"Server Error"}'],[2,runs(OKC,"completed")]], [[1,jobs("success")]], "success/success"),
 "jobs-shapeless-answer": ([[1,runs(OKC,"completed")]], [[1,'{"message":"Server Error"}'],[2,jobs("success")]], "success/success"),
 "completed-ci-without-bft-step": ([[1,runs(OKC,"completed")]], [[1,jobs("absent")]], "success/never-ran"),
 "compile-never-appears": ([[1,runs(None,"completed")]], [[1,jobs("success")]], "never-ran/success"),
 "bft-failed": ([[1,runs(OKC,"completed")]], [[1,jobs("failure")]], "success/failure"),
 "api-down-for-good": ([[1,"FAIL"]], [[1,"FAIL"]], "timeout/timeout"),
 "jobs-down-for-good": ([[1,runs(OKC,"completed")]], [[1,"FAIL"]], "success/timeout"),
 "gate-vanishes-after-grace": ([[1,runs(("in_progress",None),"in_progress")],[12,runs(None,None)],[13,runs(OKC,"completed")]],
                               [[1,jobs(None)],[12,jobs("success")]], "success/success"),
 "compile-cancelled": ([[1,runs(("completed","cancelled"),"completed")]], [[1,jobs("success")]], "cancelled/success"),
 "compile-queued-forever": ([[1,runs(("queued",None),"completed")]], [[1,jobs("success")]], "timeout/success"),
 "ci-completed-zero-jobs": ([[1,runs(OKC,"completed")]], [[1,{"jobs":[]}]], "success/never-ran"),
}
def run(script, name, r, j):
    d=tempfile.mkdtemp()
    try:
        json.dump(r,open(f"{d}/runs.json","w")); json.dump(j,open(f"{d}/jobs.json","w"))
        open(f"{d}/pick.py","w").write(PICK); open(f"{d}/now","w").write("1000000")
        out=f"{d}/out"; open(out,"w").close()
        body=extract(script)
        p=subprocess.run(["bash","-e","-c",PRELUDE+body],env={**os.environ,"SIM":d,"SHA":"abc","REPO":"o/r","GITHUB_OUTPUT":out},capture_output=True,text=True,timeout=60)
        kv=dict(l.split("=",1) for l in open(out).read().split())
        retries=p.stdout.count("unreadable")
        return f'{kv.get("compile_check")}/{kv.get("build_for_testing")}', retries, p.returncode
    finally: shutil.rmtree(d)
bad=0
for script in sys.argv[1:]:
    print("==", os.path.basename(script))
    for name,(r,j,want) in SCEN.items():
        got,retries,rc=run(script,name,r,j)
        ok = got==want
        if script == sys.argv[-1] and not ok: bad+=1
        print(f"  {'ok ' if ok else 'BAD'} {name:32} got={got:22} want={want:20} retries={retries} exit={rc}")
sys.exit(1 if bad else 0)
