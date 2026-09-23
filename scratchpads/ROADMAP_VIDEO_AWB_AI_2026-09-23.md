# ROADMAP ONLY — video auto white balance + provider-neutral AI video (2026-09-23)

**Status: RECORDED, NOT STARTED, NOT AUTHORIZED TO START.** The founder's brief says
verbatim *"keep in roadmap, do not implement yet"*. This file exists so the requirements
survive the loop without becoming a slice; nothing here is a plan to execute.

## ⚠️ READ THIS FIRST — the requirements presuppose a pipeline this repo does not have

**There is no video capture in Echoel.** #1304 (founder, 2026-09-12, verbatim *"Kein Video
Capture"*) removed the recorder, the muxer, the library, the REC control and every
user-visible line; #121 Slice 3 had already removed the edit half. `CLAUDE.md` states the
consequence: *"Es gibt keine Video-Grenze mehr zu erreichen."* The app encodes no video —
the only `AVAssetWriter` in `Sources/` is `Audio/SingleExport.swift`, `mediaType: .audio`.

So an auto-white-balance pipeline has **no frames to correct** today. Restoring a video
capture path is a founder decision, eleven days after the same founder struck it, and this
roadmap note is explicitly NOT that decision. **A future session must not read this file as
authorization.** If the founder does restore capture, these requirements apply to it.

⛔ **AND THE MOST EXPENSIVE MISTAKE AVAILABLE HERE IS A DIRECTORY-SHAPED ONE.**
`Sources/Echoelmusic/Video/` still exists and holds FOUR files — `CameraCapture`,
`CameraAnalyzer`, `RPPGConditioning`, `PulsePeriodEstimator`. **That is the rPPG PULSE path,
the flagship bio source.** It shares the directory name and nothing else. Anyone who reads
"video roadmap" and goes looking in `Video/` is one `rm` away from deleting the heartbeat.
The camera there is a photoplethysmograph, not a camera.

## The requirements, recorded verbatim in substance

**Auto white balance** — the pipeline the founder specified, in order:
illuminant estimate → temperature/tint → **confidence** → temporal smoothing →
scene-change reset → manual lock/override → deterministic transform.
Constraints: **no pumping**; **no AI vendor dependency required**.

⭐ Note for whoever builds it: the `confidence` stage is the same shape this session just
built twice (#F3, #F4). The law already has a home in the codebase — a derived value that
crosses a boundary must carry its own evidence, and the producer is the only place the
evidence exists. `temporal smoothing` + `scene-change reset` is the "no pumping" pair:
smoothing alone lags a real cut, a reset alone flickers. Neither is optional.

**AI video** — provider-neutral. *"Never make one provider canonical."* Reading that
against this repo's standing rules: it means a protocol/adapter boundary with no vendor type
in any core signature, and it collides with **zero external dependencies** — every vendor
SDK is a dependency, so this is Council + founder territory before a line is written.

## What would have to be decided FIRST (not by a session)

1. Does video capture come back at all? (#1304 says no; this note does not reopen it.)
2. If it does — capture only, or capture + the struck edit surface? The Editor≠Workstation
   boundary in `CLAUDE.md` cuts video edit explicitly.
3. AI video: any external dependency at all? Today `Package.swift` has `dependencies: []`.
4. Privacy: camera frames leaving the device would be a new egress class. `BioEgressPolicy`
   governs bio; nothing governs pixels, because nothing produces them.

**Nothing in this file is scheduled. It is a record, so the requirement is not lost and not
mistaken for a mandate.**
