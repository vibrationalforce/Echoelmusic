#!/usr/bin/env python3
"""Drive the factory review workflow's decision logic with stub agents — its selftest.

`.claude/workflows/echoel-factory-review.js` is plain JavaScript that only the Workflow harness
runs, so nothing in CI ever executes it. This tool strips its `meta` block, runs the body under
Node with stub `agent`/`parallel` hooks, and checks one case per branch of the decision: every
malformed argument is INVALID, the three always-on lenses are a floor, a [DEVICE] criterion never
blocks, an ESCALATE is never downgraded, an unmet code criterion is REWORK while rounds remain,
an empty acceptance list and a missing review are RERUN. No agent runs, nothing is written.

    python3 -I scripts/factory-review-selftest.py          # after touching the workflow
    FACTORY_VERBOSE=1 python3 -I scripts/factory-review-selftest.py   # every case, not only misses

Exit 0 = every case matches · 1 = a case decided wrong (the workflow or this table changed) ·
2 = no `node` on PATH, or the workflow file is missing — nothing was checked, which is not a pass.
Skill: .claude/skills/factory/SKILL.md (job 001, round 1 found the bugs these cases pin).
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

WORKFLOW = Path(__file__).resolve().parent.parent / ".claude" / "workflows" / "echoel-factory-review.js"

HARNESS = r"""import { readFileSync } from 'node:fs'
const src = readFileSync(process.env.FACTORY_WORKFLOW, 'utf8')
const body = src.replace(/^export const meta = \{[\s\S]*?\n\}\n/, '')
const make = new Function('args', 'agent', 'parallel', 'phase', 'log', `return (async () => {${body}})()`)
const failures = []
const PASS = { verdict: 'PASS', summary: 's', findings: [] }
const MAJOR = { verdict: 'CHANGES', summary: 's', findings: [{ severity: 'major', file: 'x.js', line: 1, issue: 'i', fix: 'f' }] }
async function run(name, args, reviewer, approver, expect, mustSpawn = []) {
  const spawned = []
  const agent = async (prompt, opts) => { spawned.push(opts.label); return opts.label === 'approver' ? approver : reviewer(opts.label) }
  const parallel = async (ts) => Promise.all(ts.map(t => t().catch(() => null)))
  const r = await make(args, agent, parallel, () => {}, () => {})
  const ok = r.decision === expect && mustSpawn.every(l => spawned.includes(l))
  if (!ok) failures.push(name)
  if (!ok || process.env.FACTORY_VERBOSE) console.log(`${ok ? 'OK ' : 'BAD'} ${name}: ${r.decision}${r.problems ? ' ' + JSON.stringify(r.problems) : ''}${r.reason ? ' (' + r.reason + ')' : ''} spawned=${spawned.length}`)
  return r
}
const base = { job: '001-x', base: 'b1cfc8ad1', head: '9c0677f03', round: 1 }
const ap = (decision, acc, q = []) => ({ decision, why: 'w', acceptance: acc, forTheHuman: q })
const C = (kind, met) => ({ criterion: 'c', kind, met, evidence: 'e' })
await run('round "3" string', { ...base, round: '3' }, () => PASS, null, 'INVALID')
await run('round 2.5', { ...base, round: 2.5 }, () => PASS, null, 'INVALID')
await run('round null', { ...base, round: null }, () => PASS, null, 'INVALID')
await run('head HEAD', { ...base, head: 'HEAD' }, () => PASS, null, 'INVALID')
await run('head missing', { job: '001-x', base: 'b1', round: 1 }, () => PASS, null, 'INVALID')
await run('head 123 number', { ...base, head: 123 }, () => PASS, null, 'INVALID')
await run('base --all', { ...base, base: '--all' }, () => PASS, null, 'INVALID')
await run('base a..b', { ...base, base: 'a..b' }, () => PASS, null, 'INVALID')
await run('lenses string', { ...base, lenses: 'dsp-reviewer' }, () => PASS, null, 'INVALID')
await run('lenses constructor', { ...base, lenses: ['constructor'] }, () => PASS, null, 'INVALID')
await run('lenses __proto__', { ...base, lenses: ['__proto__'] }, () => PASS, null, 'INVALID')
await run('two domain lenses', { ...base, lenses: ['dsp-reviewer', 'e2e-test-agent'] }, () => PASS, null, 'INVALID')
await run('args array', ['x'], () => PASS, null, 'INVALID')
const r1 = await run('only dsp lens -> floor of 3 added', { ...base, lenses: ['dsp-reviewer'] }, () => PASS, ap('APPROVE', [C('code', true)]), 'APPROVE',
  ['review:code-reviewer', 'review:security-agent', 'review:ux', 'review:dsp-reviewer', 'approver'])
await run('device unmet does not block', { ...base, lenses: [] }, () => PASS, ap('APPROVE', [C('code', true), C('device', false)]), 'APPROVE')
await run('approver ESCALATE + code unmet stays ESCALATE', base, () => PASS, ap('ESCALATE', [C('code', false)]), 'ESCALATE')
await run('code unmet round1 -> REWORK', base, () => PASS, ap('APPROVE', [C('code', false)]), 'REWORK')
await run('code unmet round3 -> ESCALATE', { ...base, round: 3 }, () => PASS, ap('APPROVE', [C('code', false)]), 'ESCALATE')
await run('founder unmet -> ESCALATE', base, () => PASS, ap('APPROVE', [C('code', true), C('founder', false)]), 'ESCALATE')
await run('question for human -> ESCALATE', base, () => PASS, ap('APPROVE', [C('code', true)], [{ question: 'q', recommendation: 'r', whyFounder: 'w' }]), 'ESCALATE')
await run('empty acceptance -> RERUN', base, () => PASS, ap('APPROVE', []), 'RERUN')
await run('approver null -> RERUN', base, () => PASS, null, 'RERUN')
await run('major finding round1 -> REWORK, no approver', base, (l) => l === 'review:ux' ? MAJOR : PASS, null, 'REWORK')
await run('major finding round3 -> ESCALATE', { ...base, round: 3 }, (l) => l === 'review:ux' ? MAJOR : PASS, ap('APPROVE', [C('code', true)]), 'ESCALATE')
await run('missing reviewer -> RERUN', base, (l) => l === 'review:ux' ? null : PASS, null, 'RERUN')
await run('round absent defaults 1', { job: '001-x', base: 'b1', head: 'abcdef1' }, () => PASS, ap('APPROVE', [C('code', true)]), 'APPROVE')
await run('kind missing treated as code unmet', base, () => PASS, ap('APPROVE', [{ criterion: 'c', met: false, evidence: 'e' }]), 'REWORK')
console.log(failures.length ? `${failures.length} case(s) wrong` : 'all cases match')
process.exit(failures.length ? 1 : 0)
"""


def main():
    node = shutil.which("node")
    if not node:
        print("factory-review-selftest: no node on PATH — NOTHING CHECKED (exit 2)")
        return 2
    if not WORKFLOW.is_file():
        print(f"factory-review-selftest: {WORKFLOW} missing — NOTHING CHECKED (exit 2)")
        return 2
    env = {**os.environ, "FACTORY_WORKFLOW": str(WORKFLOW)}
    run = subprocess.run([node, "--input-type=module", "-e", HARNESS], env=env)
    return 0 if run.returncode == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
