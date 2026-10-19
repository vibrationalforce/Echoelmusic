export const meta = {
  name: 'echoel-factory-review',
  description: 'Echoel factory review round: up to four read-only lenses on a job diff, then rework, approve or escalate',
  whenToUse: 'After the PM built a factory job (scratchpads/factory/<id>/spec.md exists). Args: {job, base, head, round, lenses}. Read .claude/skills/factory/SKILL.md first.',
  phases: [
    { title: 'Review', detail: 'read-only lenses in parallel; the approver waits for all of them' },
    { title: 'Approve', detail: 'a separate approver checks every acceptance criterion: APPROVE or ESCALATE' },
  ],
}

// The verbatim clause of .claude/rules/context.md section 5. Every agent prompt goes through
// withReadOnly(); TheFactoryReviewersAreReadOnlyTests counts that every agent call does.
const READ_ONLY = 'read-only inspection only — `git diff`, `git show`, `git log`, `git grep`, Read/Grep/Glob; never `git checkout`, `stash`, `restore`, `reset`, `clean`, `add`, `commit`, `push`; never edit, create or delete a file; report findings as text.'

// The builder (the PM) may rework at most this many times. Review round MAX_REWORK_ROUNDS + 1
// is the last one; CHANGES there escalate to the founder instead of a third rework.
const MAX_REWORK_ROUNDS = 2
const MAX_LENSES = 4

const withReadOnly = (text) => `${READ_ONLY}\n\n${text}`

const LENSES = {
  'code-reviewer': {
    agentType: 'code-reviewer',
    charter: 'Code lens: correctness, edge cases (nil, empty, NaN, division by zero, bounds), Swift 6 isolation, no force unwrap, os_log only, the conventions of the surrounding file. A finding needs file and line.',
  },
  'security-agent': {
    agentType: 'security-agent',
    charter: 'Security and privacy lens: secrets, entitlements, network exposure, data leaving the device, file paths escaping their folder, App Store 5.1.x privacy rules, untrusted input (song files, OSC, MIDI, foreign model text).',
  },
  'ux': {
    agentType: 'general-purpose',
    charter: 'User-Advocate and claims lens: is every visible sentence true for this build (ContentPipeline/CLAIMS.md, docs/dev/FEATURE_STATUS.md)? No health, wellness or esoteric wording. Accessibility: VoiceOver labels, Dynamic Type, contrast, reduce motion, flashes at most 3 Hz. Uncodixfy rules from CLAUDE.md (radius at most 16, no glassmorphism, EchoelValueField for numeric parameters). A first-time user must understand what a control does.',
  },
  'audio-thread-reviewer': {
    agentType: 'audio-thread-reviewer',
    charter: 'Audio-thread lens: render blocks and DSP kernels may not allocate, lock, message ObjC, do I/O or GCD.',
  },
  'bio-safety-reviewer': {
    agentType: 'bio-safety-reviewer',
    charter: 'Bio-safety lens: bio and health data stay on device, mandatory warnings, no medical claims, flash rate at most 3 Hz.',
  },
  'ui-state-reviewer': {
    agentType: 'ui-state-reviewer',
    charter: 'UI-state lens: SwiftUI observation boundaries, no high-frequency reads in a menu host or its ancestors, presentation-modifier ceiling, no two modals at once.',
  },
  'concurrency-reviewer': {
    agentType: 'concurrency-reviewer',
    charter: 'Concurrency lens: actor isolation, Sendable, closures that a framework calls off the main queue.',
  },
  'dsp-reviewer': {
    agentType: 'dsp-reviewer',
    charter: 'DSP lens: algorithm correctness; the protected Rausch triad is read-only.',
  },
  'e2e-test-agent': {
    agentType: 'e2e-test-agent',
    charter: 'Ship-path lens: targets, entitlements, Info.plist, what each CI gate does and does not prove.',
  },
}
const ALWAYS = ['code-reviewer', 'security-agent', 'ux']

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASS', 'CHANGES'] },
    summary: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
          file: { type: 'string' },
          line: { type: 'integer' },
          issue: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['severity', 'file', 'issue'],
      },
    },
  },
  required: ['verdict', 'summary', 'findings'],
}

const APPROVER_SCHEMA = {
  type: 'object',
  properties: {
    decision: { type: 'string', enum: ['APPROVE', 'ESCALATE'] },
    why: { type: 'string' },
    acceptance: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          criterion: { type: 'string' },
          met: { type: 'boolean' },
          evidence: { type: 'string' },
        },
        required: ['criterion', 'met', 'evidence'],
      },
    },
    forTheHuman: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          question: { type: 'string' },
          recommendation: { type: 'string' },
          whyFounder: { type: 'string' },
        },
        required: ['question', 'recommendation', 'whyFounder'],
      },
    },
  },
  required: ['decision', 'why', 'acceptance', 'forTheHuman'],
}

// --- argument check: a malformed call is reported, never guessed around ---
const a = args || {}
const REF = /^[A-Za-z0-9._\/~^-]{1,80}$/
const problems = []
if (typeof a.job !== 'string' || !/^\d{3}-[a-z0-9-]{1,60}$/.test(a.job)) problems.push('job must look like 001-short-slug')
if (typeof a.base !== 'string' || !REF.test(a.base)) problems.push('base must be a git ref or sha')
const head = typeof a.head === 'string' ? a.head : 'HEAD'
if (!REF.test(head)) problems.push('head must be a git ref or sha')
const round = Number.isInteger(a.round) ? a.round : 1
if (round < 1 || round > MAX_REWORK_ROUNDS + 1) problems.push(`round must be 1..${MAX_REWORK_ROUNDS + 1}`)
const requested = Array.isArray(a.lenses) && a.lenses.length ? a.lenses : ALWAYS
const lenses = [...new Set(requested)]
const unknown = lenses.filter(l => !LENSES[l])
if (unknown.length) problems.push(`unknown lenses: ${unknown.join(', ')}`)
if (lenses.length > MAX_LENSES) problems.push(`at most ${MAX_LENSES} lenses (ultracode: four workers per lead)`)
if (problems.length) return { decision: 'INVALID', problems }

const jobDir = `scratchpads/factory/${a.job}`
const range = `${a.base}..${head}`

phase('Review')
log(`Job ${a.job}, round ${round}: ${lenses.join(', ')} on ${range}`)
const reviews = await parallel(lenses.map(name => () =>
  agent(withReadOnly(`You are the ${name} reviewer of the Echoel factory, round ${round}.
${LENSES[name].charter}

Read the job spec ${jobDir}/spec.md (Goal, Assumptions, Acceptance criteria), then the change itself:
\`git log --oneline ${range}\` and \`git diff ${range}\`. Earlier rounds, if any, are in ${jobDir}/reviews/.
Review ONLY what this diff changes, through your lens only. Verify every finding against the real source
and give file plus line; a finding you cannot point at is not a finding. Say "blocker" or "major" only
for something that must change before this ships; style preferences are "minor".
VERDICT is PASS unless you have at least one blocker or major finding.
Your final answer is data for the orchestrator, not a message to a person.`),
    { label: `review:${name}`, phase: 'Review', agentType: LENSES[name].agentType, schema: REVIEW_SCHEMA })))

// Deterministic verdicts: a CHANGES without a pointed blocker/major finding counts as PASS,
// a PASS that lists a blocker counts as CHANGES. The words follow the evidence.
const graded = lenses.map((name, i) => {
  const r = reviews[i]
  if (!r) return { lens: name, verdict: 'MISSING', summary: 'reviewer returned nothing', findings: [] }
  const findings = Array.isArray(r.findings) ? r.findings : []
  const pointed = findings.filter(f => (f.severity === 'blocker' || f.severity === 'major') && f.file && f.file.trim())
  return { lens: name, verdict: pointed.length ? 'CHANGES' : 'PASS', said: r.verdict, summary: r.summary, findings }
})
const missing = graded.filter(g => g.verdict === 'MISSING').map(g => g.lens)
const open = graded.flatMap(g => g.findings
  .filter(f => (f.severity === 'blocker' || f.severity === 'major') && f.file && f.file.trim())
  .map(f => ({ lens: g.lens, ...f })))
graded.filter(g => g.said && g.said !== g.verdict).forEach(g => log(`${g.lens}: said ${g.said}, graded ${g.verdict} from its findings`))

if (missing.length) {
  log(`No answer from ${missing.join(', ')} — a missing review is not a pass`)
  return { job: a.job, round, decision: 'RERUN', missing, reviews: graded }
}
if (open.length && round <= MAX_REWORK_ROUNDS) {
  log(`${open.length} open finding(s); rework ${round} of ${MAX_REWORK_ROUNDS}`)
  return { job: a.job, round, decision: 'REWORK', nextRound: round + 1, findings: open, reviews: graded }
}

phase('Approve')
const capReached = open.length > 0
const approver = await agent(withReadOnly(`You are the approver of the Echoel factory. You did not build this change and you
did not write the reviews; judge it fresh.

Read ${jobDir}/spec.md, \`git diff ${range}\`, and these graded reviews of round ${round}:
${JSON.stringify(graded)}
${capReached ? `The rework cap (${MAX_REWORK_ROUNDS} rounds) is reached and these findings are still open: ${JSON.stringify(open)}. You must ESCALATE.` : 'All lenses passed.'}

For EVERY acceptance criterion in the spec, say whether it is met and give evidence (file:line, a command and
its output, or the guard that pins it). A criterion that needs a device, an ear or an eye is NOT met by code;
name it in forTheHuman instead.
ESCALATE when: the cap is reached; a criterion is unmet; or an Assumption in the spec is the founder's to make —
product scope per docs/dev/FOUNDER_PRODUCT_LAW.md, money, prices, contracts, legal or licence text, health or
wellness wording, App Store submission, deleting user data, or a founder-locked file (.github/workflows/** other
than the studio workflows, the root project.yml, Resources/iOS/Info.plist).
Before you write a question for the human, grep docs/dev/FOUNDER_INBOX.md for it: an answered question is not
asked again, cite its number instead. Otherwise APPROVE. Your final answer is data for the orchestrator.`),
  { label: 'approver', phase: 'Approve', agentType: 'general-purpose', schema: APPROVER_SCHEMA, effort: 'high' })

if (!approver) return { job: a.job, round, decision: 'RERUN', missing: ['approver'], reviews: graded }
const unmet = (approver.acceptance || []).filter(c => !c.met)
let decision = approver.decision
if (capReached || unmet.length) decision = (!capReached && round <= MAX_REWORK_ROUNDS) ? 'REWORK' : 'ESCALATE'
if (decision !== approver.decision) log(`approver said ${approver.decision}; ${unmet.length} unmet criterion(s) make it ${decision}`)
return { job: a.job, round, decision, nextRound: decision === 'REWORK' ? round + 1 : undefined, findings: open, unmet, reviews: graded, approver }
