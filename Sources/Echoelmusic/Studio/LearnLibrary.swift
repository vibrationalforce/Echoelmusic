// LearnLibrary.swift
// Echoel — the single index behind the "app as a school" idea. Unifies the
// existing teaching content (bio metrics, music theory) plus a safety/scope note
// into one browsable, sectioned model, so a future "Learn" surface binds to ONE
// source instead of many silos. Pure Foundation, unit-tested. No new copy is
// invented here — it reuses BioMetric and MusicTheoryTopic verbatim.

import Foundation

public enum LearnSection: String, CaseIterable, Identifiable, Sendable {
    // #589 — `guide` is deliberately FIRST: `LearnView` renders sections in `allCases` order,
    // and the founder's ask this case answers is "ein leichtes Eintauchen … für alle Sinne —
    // hörbar, sichtbar und spürbar". A newcomer opens Learn and meets the way IN before the
    // reference material. (The rawValue is a storage-shaped token like its neighbours; the
    // enum itself is never persisted — ids like "guide.hear" are built from it.)
    case guide, body, bodyScience, music, light, safety

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .guide:       return String(localized: "Start Here")
        case .body:        return String(localized: "Your Body")
        case .bodyScience: return String(localized: "Body Science")
        case .music:       return String(localized: "Music Theory")
        case .light:       return String(localized: "Light & Colour")
        case .safety:      return String(localized: "Safety & Scope")
        }
    }
}

/// One learnable entry, renderer-agnostic.
public struct LearnEntry: Identifiable, Sendable, Equatable {
    public let id: String
    public let section: LearnSection
    public let title: String
    public let summary: String
    public let detail: String

    public init(id: String, section: LearnSection, title: String, summary: String, detail: String) {
        self.id = id
        self.section = section
        self.title = title
        self.summary = summary
        self.detail = detail
    }
}

public enum LearnLibrary {

    /// The way in — one entry per sense, plus the walkthrough and the accessibility note.
    ///
    /// ⭐ EVERY CONTROL NAMED HERE IS QUOTED FROM THE SHIPPING UI, verbatim, and the blocking
    /// bundle enforces the join (`TheGuideNamesOnlyRealControlsTests`): a guide that names a
    /// control the app does not have is the first-instruction defect all over again — #351
    /// already paid for "a finger on the camera brings it to life" being untrue at the moment
    /// it was shown. Rename a control, and the guard names this file as the place to follow.
    ///
    /// ⚠️ NO HEALING LANGUAGE, deliberately, including in the "feel" entry — vocal/tonal work
    /// and haptics are described as practice and self-observation (the Body Science precedent).
    /// The healing theme is a hard product red line, not a style preference.
    ///
    /// ⭐ E4-23 (2026-09-30): every field is ONE catalog key — `String(localized:)` over ONE literal per
    /// field, never a `+` chain (a seam would split the key and the German would never be found).
    /// Control names quoted inside a key use typographic quotes (“Studio”), because the catalog
    /// guard matches each key as a QUOTED literal in raw source and an escaped `\"` can never match.
    /// The retraction comments sit ABOVE `detail:` so the safety guard's per-entry extractor keeps
    /// reading one literal.
    public static var guideEntries: [LearnEntry] {
        [
            LearnEntry(
                id: "guide.firstSession", section: .guide,
                title: String(localized: "Your first three minutes"),
                summary: String(localized: "The app opens on your piece. Here is the way in."),
                detail: String(localized: "Echoel opens on your piece — the header at the top, five words at the bottom (down the left side when you hold the phone sideways): Arrange, Mixer, Instrument, Browse and Project — with its living picture as a small card over the piece. Arrange shows your tracks and parts and walks you through making one; Mixer sets their levels, Browse holds your sounds and media, Project sets the song's key and saves, opens and exports. Instrument is where your body plays: press Play at the top and it composes in your key and genre; once it can read your body, your body plays it. Tap the card's resize arrows to make the picture fill the screen; there, the “Studio” chip brings the controls back and the X hides the picture. Nothing sounds until you start it — silence at launch is by design, not a fault.")
            ),
            LearnEntry(
                id: "guide.hear", section: .guide,
                title: String(localized: "Hear it"),
                summary: String(localized: "Press Play; the music is composed, then your body shapes it."),
                detail: String(localized: "Play starts generated music — harmony, melody and bass in one key, at one tempo, in the genre you chose. Your heart and breath then bend its brightness, its swell and its calm in real time. For your own voice in the loop, switch on “Body voice” in the Bio panel: a held tone that your breath opens and closes — exhale, and it fades; inhale, and it returns. Toning with it, vowels and hums, is a practice of self-observation: you hear your own breathing pattern as sound.")
            ),
            LearnEntry(
                id: "guide.see", section: .guide,
                title: String(localized: "See it"),
                summary: String(localized: "The picture moves with your body — and it is playable."),
                // ⛔ SAID "the picture holds still entirely" UNTIL #1018 — the SAME false
                // promise #994 removed from the safety card, in the same file, in different
                // words. See the ⛔ block on `safety.contraindications` below for the
                // measurement. The guard's claim 1 forbids ONE literal spelling, which
                // these two siblings never used — so it passed while they lied. ⚠️ That
                // phrase is deliberately NOT written out here: claim 1 scans the whole
                // file, so quoting the wording it bans would turn this retraction into the
                // offence (#491) — which is exactly what the first draft of this comment
                // did, and the transcription caught it.
                // ⛔ SAID "You can record it as a share-ready video." UNTIL #1318 — a
                // capability #1304 DELETED (founder 2026-09-12, "Kein Video Capture").
                // Nothing under `Sources/` can write one: the only `AVAssetWriter` is in
                // `Audio/SingleExport.swift` with `mediaType: .audio`, and there is no
                // ReplayKit and no `AVCaptureMovieFileOutput` anywhere. This entry renders
                // unconditionally behind a LIVE door (`LearnView` `Text(entry.detail)`;
                // `.guide` is the first section; the Learn sheet hangs off `quickDoorRow`),
                // so it was the retracted claim's most reachable home in the whole product.
                // ⚠️ AND NO GUARD COULD MATCH IT. `TheStoreTextClaimsOnlyWhatShipsTests`
                // reads `fastlane/metadata/**` and never `Sources/`; its #1304 needles
                // ("video capture", "video recording", "record the visual", "share-ready
                // mp4") are none of them substrings of the sentence above; and this file
                // sat in NO retracted-capability scan at all: the guide guard only
                // asserts that the controls it NAMES exist. The repair is one
                // list over all four copy surfaces (#416):
                // `TheShareReadyClipIsNotSoldAnywhereTests`. It scans this file through
                // `SourceText.codeOnly`, which is why this retraction may quote the
                // sentence it retracts without becoming the offence (#491).
                detail: String(localized: "The picture breathes with you: pulse, breath and coherence drive its colour and motion, capped below 3 flashes per second. Touch it to play notes — every touch lands in key, so there is no wrong place. It stays playable at every window size. With Reduce Motion on, the picture stops its motion; the small header monitors keep following the music.")
            ),
            LearnEntry(
                id: "guide.feel", section: .guide,
                title: String(localized: "Feel it"),
                summary: String(localized: "The beat in your hand, the bass in your body."),
                detail: String(localized: "Switch on “Haptic beat (feel)” under “Tempo & variations” and the phone pulses on each quarter-note, the downbeat strongest — you can hold time without watching the screen. The sub-bass is tuned to be felt as much as heard: on a sub, in headphones, or through the haptics. Eyes-free by intention: the instrument is playable without looking at it.")
            ),
            LearnEntry(
                id: "guide.pulse", section: .guide,
                title: String(localized: "Give it your pulse"),
                summary: String(localized: "Start the music first — then a finger on the back camera."),
                detail: String(localized: "After you press Play, lay a fingertip flat over the back camera and flash; the torch lights your skin and Echoel reads your heartbeat from it. Hold still and soft — it locks within seconds and tells you when you can let go. A Bluetooth chest strap (Polar and similar) is the most accurate source and frees your hands: choose it from the pulse pill's source menu. An Apple Watch works via Health, a few seconds behind. The order matters: the camera only starts with the music, so a finger before Play reads nothing.")
            ),
            LearnEntry(
                id: "guide.access", section: .guide,
                title: String(localized: "For every body"),
                summary: String(localized: "Hearing, seeing or feeling — any one of them is a way in."),
                // ⛔ SAID "Reduce Motion freezes the visual without stopping the music"
                // until #1018. This is the ACCESSIBILITY entry — the one read by exactly
                // the person the sentence misleads — so it also names the control that
                // actually cuts a rig, the way the safety card does.
                detail: String(localized: "The three channels above are deliberately redundant: the beat can be felt without being seen, the picture read without being heard, the music followed without the screen. VoiceOver speaks the primary controls, text follows your system size, numbers are typed on a large keypad instead of turned on tiny knobs, and Reduce Motion stops the immersive picture's motion without stopping the music. If flashing light affects you, turn Reduce Motion on before you start, and use Blackout in Routing to cut connected fixtures.")
            ),
        ]
    }

    /// Body metrics — straight from BioMetric (no duplicated copy).
    public static var bodyEntries: [LearnEntry] {
        BioMetric.allCases.map {
            LearnEntry(id: "body.\($0.rawValue)", section: .body,
                       title: $0.title, summary: $0.summary, detail: $0.detail)
        }
    }

    /// Body science — the cited research behind the biofeedback loop (resonance
    /// breathing, HRV coherence, baroreflex). FACTS + self-observation, no claim;
    /// makes the strongest-evidence part of the product visible. See BioScienceInfo.
    public static var bodyScienceEntries: [LearnEntry] {
        BioScienceTopic.allCases.map {
            LearnEntry(id: "bodyScience.\($0.rawValue)", section: .bodyScience,
                       title: $0.title, summary: $0.summary, detail: $0.detail)
        }
    }

    /// Music-theory primers — straight from MusicTheoryTopic.
    public static var musicEntries: [LearnEntry] {
        MusicTheoryTopic.allCases.map {
            LearnEntry(id: "music.\($0.rawValue)", section: .music,
                       title: $0.title, summary: $0.summary, detail: $0.detail)
        }
    }

    /// Light & colour science — straight from LightScienceTopic (cited facts, no
    /// claim). Grounds Echoel's Light (Art-Net/sACN) + colour output in real
    /// wavelengths; see vision-gate (inspiration.csv) for the brand line.
    public static var lightEntries: [LearnEntry] {
        LightScienceTopic.allCases.map {
            LearnEntry(id: "light.\($0.rawValue)", section: .light,
                       title: $0.title, summary: $0.summary, detail: $0.detail)
        }
    }

    /// Safety & scope. TWO entries, and the first one exists for a reachability
    /// reason worth keeping in mind: `CLAUDE.md` mandates five safety warnings in the
    /// app, and four of them lived ONLY in `OnboardingView` — which renders while
    /// `hasCompletedOnboarding == false` and has no reset path. So every existing
    /// tester, every device restore and any reviewer on a second launch had NO way to
    /// reach "not while driving" or "not under the influence". The two strings written
    /// to solve that (`BioSourceView`, `SessionView`) are both in unreachable views.
    /// Putting them here gives them a permanent home: `LearnView` renders every
    /// section from `entries(for:)`, so this needs no new view and — importantly — no
    /// new `.sheet` (the modifier chain is at its metadata ceiling).
    /// Contraindications come FIRST; the scope note follows.
    public static var safetyEntries: [LearnEntry] {
        [
            // ⛔ THIS ENTRY SAID VISUALS "FREEZE ENTIRELY WITH REDUCE MOTION ON" UNTIL #994, AND
            // THAT WAS FALSE ON EVERY SURFACE BUT ONE — on the single screen a photosensitive
            // user is asked to tick "I understand" against. Measured on HEAD: the pulse tile
            // holds only its per-beat term under Reduce Motion (`HeaderMonitors.tileColor`) and
            // leaves `0.35 * masterLevel` live on an unpaused 20 Hz `TimelineView`; the lamp
            // tile drops its timer but its OWN comment concedes the music-driven hue still
            // re-renders on every published `MusicalFrame`; `git grep reduceMotion --
            // Sources/Echoelmusic/Sync` returns NOTHING, so no fixture honours it at all; and
            // `MetalBioView` keeps an eased music swell. What IS true stays stated: the 3 Hz
            // cap holds everywhere (`FlashGuard`), and the fixtures are additionally slewed to
            // ~1.2 Hz by `ArtNetSender.applySlewedColour`.
            //
            // The instruction that actually works on a rig is BLACKOUT (Routing → Licht,
            // `PatchbayView`), so it is named. The behavioural repair — slewing the two
            // `masterLevel` terms through `FlashGuard.limitedLuminance` — is registered as a
            // follow-up at `HeaderMonitors` and needs a device look, so it is NOT done here:
            // a copy fix ships today and stops the promise; the chrome change is its own slice.
            LearnEntry(
                id: "safety.contraindications", section: .safety,
                title: String(localized: "When not to use Echoelmusic"),
                summary: String(localized: "Four limits — read them once, they matter."),
                detail: String(localized: "Do not use rhythmic audio-visual pacing while driving or operating machinery. Do not use it under the influence of alcohol or drugs. If you are using Echoelmusic alongside any therapeutic programme, coordinate it — and any medication timing — with your own provider; Echoelmusic is not part of a treatment and replaces nothing. Visuals are capped at 3 flashes per second (W3C WCAG). Reduce Motion stops the immersive picture's motion; the small header monitors and any connected lamps keep following the music, rate-limited rather than frozen. If you are photosensitive, turn Reduce Motion on before you start, and use Blackout in Routing to cut connected fixtures. Stop if you feel unwell.")
            ),
            LearnEntry(
                id: "safety.scope", section: .safety,
                title: String(localized: "Self-observation, not diagnosis"),
                summary: String(localized: "What Echoelmusic’s biofeedback is — and is not."),
                detail: BioMetric.disclaimer + String(localized: " Bio readings are most accurate from a chest strap; wrist and camera are estimates. Breathing guides are optional and never forced.")
            )
        ]
    }

    public static func entries(for section: LearnSection) -> [LearnEntry] {
        switch section {
        case .guide:       return guideEntries
        case .body:        return bodyEntries
        case .bodyScience: return bodyScienceEntries
        case .music:       return musicEntries
        case .light:       return lightEntries
        case .safety:      return safetyEntries
        }
    }

    /// Everything, section-ordered (Start Here → Body → Body Science → Music → Light → Safety).
    public static var all: [LearnEntry] {
        LearnSection.allCases.flatMap { entries(for: $0) }
    }
}
