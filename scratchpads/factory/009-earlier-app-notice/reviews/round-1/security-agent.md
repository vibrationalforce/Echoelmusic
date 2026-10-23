# Round 1 — security-agent: PASS

range: 42d91ecfb54b987251777bb67e3649deb7472b8d..29bb6cc74c872858d9469c66ead2d06705d2ea69
since: None
paths: docs/integrations.html, docs/reaper-osc.html, docs/resolume-osc.html, docs/touchdesigner-osc.html, docs/artnet-sacn-from-a-phone.html, docs/tools.html, docs/support.html, scratchpads/factory/009-earlier-app-notice
criteria: 5  deviceCriteria: []  founderAssumptions: 0  recount: False
workflow: wf_756e310a-c7c

Security and privacy review, round 1 of job 009 (no earlier reviews, since scratchpads/factory/009-earlier-app-notice/ holds only spec.md and board.json). The change adds one static paragraph to each of seven docs/ pages and adds the job's board.json. Nothing in it touches secrets, entitlements, scripts, external resources, forms or headers. Every link is the relative roadmap.html, which exists at head.

The inline style="margin-top:8px;" on tools.html:135 and support.html:80 is allowed by the site CSP (docs/_headers line 15 has style-src 'self' 'unsafe-inline'), and no page carries a meta CSP that would block it.

The two absence claims check out against EchoelStudio/ at head:
- No OSC/Art-Net/sACN: the only grep hit is an `osc` oscillator variable in DSPTests.swift.
- No body reads: no HealthKit, CoreBluetooth, AVCaptureDevice or CoreLocation, and no camera, health, Bluetooth or location usage descriptions in EchoelStudio/project.yml.

They also agree with privacy.html:110 ("Not in Echoel Studio: camera, heart-rate sensors, Apple Health, location, OSC, Art-Net and sACN"). The paragraphs claim nothing about Studio's microphone or Network MIDI, which do exist (project.yml:77 and :83). So they do not understate what Studio collects, and no 5.1.x disclosure goes false. "iPhone and iPad" matches TARGETED_DEVICE_FAMILY "1,2" (project.yml:66 and :135).

board.json holds only job metadata, with no tokens or personal data. The diff does not touch .claude/workflows, .claude/agents, any CLAUDE.md or .claude/rules.

One minor wording point on support.html, listed below; it does not block shipping.

Findings:
- **minor** `docs/support.html:80` — The new notice says "The questions below describe the earlier app (10.79.515)". That sentence also covers the privacy answer at support.html:108-109 ("Is my data safe? Yes. All biometric data stays on your device. We don't collect or store any personal data."), which is just as true for Echoel Studio (privacy.html:103: "no account, no analytics, no advertising, no server of ours"). A Studio tester could take the privacy answer to apply only to the frozen app and think Studio's data handling is not addressed on the support page. It is not false, because the answer links privacy.html, which has a Studio section.
  - Fix: Optional: add a short clause to the notice, e.g. "...describe the earlier app (10.79.515), which is frozen; Echoel Studio's data handling is on the <a href=\"privacy.html#studio\">Privacy</a> page...". The other option is to leave it, since the FAQ already links privacy.html.
