# Round 1 — approver: APPROVE

range: 42d91ecfb54b987251777bb67e3649deb7472b8d..29bb6cc74c872858d9469c66ead2d06705d2ea69
since: None
paths: docs/integrations.html, docs/reaper-osc.html, docs/resolume-osc.html, docs/touchdesigner-osc.html, docs/artnet-sacn-from-a-phone.html, docs/tools.html, docs/support.html, scratchpads/factory/009-earlier-app-notice
criteria: 5  deviceCriteria: []  founderAssumptions: 0  recount: False
workflow: wf_756e310a-c7c

reason: all 5 criteria graded, every code criterion met

unmet: []
founderOpen: []
deviceAsks: []

## approver

```json
{
 "decision": "APPROVE",
 "why": "I counted the spec at 29bb6cc74 before opening board.json. It has 5 numbered acceptance criteria, none tagged [DEVICE], and none of its five Assumptions (A1 to A5) starts with [FOUNDER]. A4 does say it leaves the health, privacy and legal pages alone, but it makes no founder decision.\n\nThe whole job, 42d91ecfb..29bb6cc74, touches 9 files. Seven are docs/*.html pages, each with exactly one added line (diff --stat: 7 files, 7 insertions). The other two are the job's spec.md and board.json.\n\nNo founder-locked file is in the unscoped list. At the base, context.md §3 locks .github/workflows/**, project.yml and Resources/iOS/Info.plist. protect-founder-gated.py locks .claude/settings.json and .mcp.json (PROTECTED_DIRS is empty), and permissions.ask covers settings.json, .mcp.json and .claude/hooks/**. No CLAUDE.md and nothing under .claude/rules changed.\n\nThe added copy claims only two things Studio lacks, and I checked both at the head commit:\n- **No OSC, Art-Net or sACN:** the only hit in EchoelStudio/ is a CI checker, Support/CI/swift_imports.py, which itself forbids NWConnection and `import Network`.\n- **No body input:** HealthKit, AVCaptureDevice and CoreBluetooth have no hits.\n\n\"iPhone and iPad\" matches TARGETED_DEVICE_FAMILY \"1,2\" at EchoelStudio/project.yml:66 and :135. \"10.79.515\" matches .deploy/release and roadmap.html:102. The return dates the notices point to are at roadmap.html:114-115.\n\nThe copy has no health, wellness or esoteric wording, and it decides no scope, money, legal or store matter. board.json records base 42d91ecfb54b987251777bb67e3649deb7472b8d, so the range under review is the whole job.\n\nThe reviewers' minor points are polish, not failures: the notice is the second subtitle on tools.html, integrations.html does not mention that MIDI out is clock only, and the Roadmap link has no visible link styling.",
 "acceptance": [
  {
   "number": 1,
   "criterion": "Each of the seven pages carries exactly one paragraph with 'Since 19 October 2026, TestFlight carries Echoel Studio', placed before its first <h2>.",
   "kind": "code",
   "met": true,
   "evidence": "I ran grep -n on git show 29bb6cc74 for each page. Notice line vs. first <h2>: integrations 83<86, reaper-osc 82<85, resolume-osc 82<85, touchdesigner-osc 82<85, artnet-sacn-from-a-phone 81<84, tools 135<151, support 80<84. Each page has exactly one hit."
  },
  {
   "number": 2,
   "criterion": "The five OSC/DMX pages say 'It does not send OSC, Art-Net or sACN yet'; tools and support say 'It does not read the body yet'. Both are measured.",
   "kind": "code",
   "met": true,
   "evidence": "grep -c at head: osc=1 and body=0 on integrations, reaper-osc, resolume-osc, touchdesigner-osc and artnet-sacn-from-a-phone; osc=0 and body=1 on tools and support. Measured at head: git grep for OSCSender, Art-Net, sACN, NWConnection and import Network in EchoelStudio/ finds only Support/CI/swift_imports.py, a checker that forbids them. git grep for HealthKit, AVCaptureDevice and CoreBluetooth in EchoelStudio/ finds nothing."
  },
  {
   "number": 3,
   "criterion": "Each paragraph links roadmap.html and names the earlier app with '10.79.515' and 'frozen'.",
   "kind": "code",
   "met": true,
   "evidence": "grep -c 'href=\"roadmap.html\">Roadmap' is 1 on every page at base and 2 at head, so each page gained exactly one link, inside the notice. grep -c '10.79.515), which is frozen' is 1 on all seven pages. .deploy/release line 1 reads v10.79.515."
  },
  {
   "number": 4,
   "criterion": "No other line of the seven pages changes, and no other file under docs/ changes.",
   "kind": "code",
   "met": true,
   "evidence": "git diff --stat 42d91ecfb..29bb6cc74 -- docs/ shows 7 files, each '1 +', 7 insertions(+), no deletions. The unscoped name-only list adds only scratchpads/factory/009-earlier-app-notice/{spec.md,board.json}."
  },
  {
   "number": 5,
   "criterion": "No Tests/CISmoke guard that reads these pages turns red (the needle scripts end with 0).",
   "kind": "code",
   "met": true,
   "evidence": "I did not run the needle scripts, because they fall outside the read-only command set. The change adds no Tests file and no heading, so TheHeadingOrderNeverSkipsALevelTests is unaffected. The added text contains none of the TheCopyMakesNoHealthClaimTests terms (Tests/CISmoke/TheCopyMakesNoHealthClaimTests.swift:41-46). It also contains none of the plugin-hosting needles in WebsitePagesAreFindableAndHonestTests (around line 409: 'AUv3 host', 'plugin host' and similar). docs/** and scratchpads/** trigger no gate path filter."
  }
 ],
 "forTheHuman": [],
 "specCriteria": 5,
 "specDevice": [],
 "specFounder": 0
}
```
