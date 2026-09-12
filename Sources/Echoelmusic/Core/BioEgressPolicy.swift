//
//  BioEgressPolicy.swift
//  Echoelmusic — Sync
//
//  Pure, testable rule for which bio SOURCES may stream off the device
//  (OSC / ADM-OSC bio frames to user-chosen network targets).
//
//  App Store Guideline 5.1.3: data obtained from the HealthKit store may not be
//  shared with third parties — and once a UDP packet leaves the phone to a
//  user-typed host, we can no longer vouch for where it lands. So the network
//  senders forward ONLY Echoel's OWN measurements (camera rPPG, BLE strap,
//  front-camera face expression, the demo generator) and never frames sourced from
//  Apple Health / Watch / ring bridges. For face expression only the abstracted
//  [0..1] channels egress — never the image. Mirrors the non-circular pattern of
//  `HealthWritePolicy.isWritableSource`
//  (which gates the opposite direction: what we write INTO Health).
//
//  DISCRETE EVENTS ARE GATED TOO (#186, 2026-07-27) — and the honest reason is narrower
//  than the first version of this note claimed, so it is spelled out rather than asserted.
//  This header used to say events "need no gate today". The STRUCTURE that claim rested on
//  was wrong: `BioEventPublisher.tick` reads `bus.latestBio` regardless of source and feeds
//  `frame.breathPhase` / `frame.motionEnergy` into a graph whose detector state is shared
//  across sources. But the DATA today is not Health-store data:
//    · `motionEnergy` is hardcoded `0` on the HealthKit frame → a motion peak (needs ≥0.6)
//      can never fire from that source.
//    · `breathPhase` is a constant `0.5` there — its only writer in `EchoelBioEngine` sits
//      inside `startFallbackMode()`, which is mutually exclusive with the HealthKit path.
//      Inhale needs `previous < 0.5`, exhale needs `previous > 0.8`; neither can trigger.
//    · `breathRate` IS real Health-store data, but the graph is never fed it.
//    · `cleanedHeart` is passed as `0`, so graph heartbeats do not fire at all.
//  So no Health-store VALUE has actually left the device through this path. What could:
//  a SHARED detector state across sources, where a camera session leaving `previous` at 0.3
//  followed by a HealthKit frame at 0.5 fires one inhale that belongs to neither.
//  ⚠️ AND THE GATE BELOW WOULD NOT HAVE CAUGHT IT: such an event is stamped with whichever
//  frame was current when it fired, so it could arrive stamped `.cameraPPG` and PASS. The
//  stamp was wrong, not missing. That artifact is closed at its root instead — one
//  `BioEventGraph` PER SOURCE in `BioEventPublisher`, so no edge can span two sources.
//  This gate is therefore DEFENCE-IN-DEPTH: it costs nothing, and it means a future
//  publisher that carries real Health-derived channels into the graph is covered on arrival
//  instead of needing someone to remember this file. It is NOT the thing that fixed #186.
//  Do not re-introduce an "events are exempt" claim; equally, do not overstate it as an
//  active leak — both errors have now been made in this exact paragraph.
//

import Foundation

public enum BioEgressPolicy {

    /// Whether frames from this source may be sent off-device. Only sources
    /// Echoel measures itself (or synthesizes, for the demo) pass; anything
    /// read out of the HealthKit store stays on the device (5.1.3).
    public static func allowsEgress(_ source: BioSource) -> Bool {
        switch source {
        case .ble, .cameraPPG, .faceCam, .fallback:
            // faceCam is measured on-device like rPPG; only the abstracted [0..1]
            // expression channels egress (never the image), same principle as PPG.
            return true
        case .healthKit, .watch, .oura:
            return false
        }
    }

    /// Whether this discrete event may be sent off-device (#186).
    ///
    /// It lives HERE, not inline in `OSCSender`, for a reason found by review: the first
    /// cut inlined the guard and the test re-implemented it, so the test passed even with
    /// the production guard deleted — a tautology wearing a regression test's clothes.
    /// One symbol, called by both.
    ///
    /// An UNSTAMPED event (`source == nil`) is refused. `BioEventGraph` is a protected
    /// component that cannot know provenance, so its events arrive unstamped and are
    /// stamped by whoever publishes them; failing closed means a producer that forgets
    /// goes silent rather than leaking.
    public static func allowsEgress(_ event: BioEvent) -> Bool {
        guard let source = event.source else { return false }
        return allowsEgress(source)
    }

    // MARK: - WHICH VALUES may leave (#1292)

    /// What CLASS of value an egress address carries.
    ///
    /// ⭐ THE RULE IN ONE SENTENCE: **what the instrument PLAYS may leave; what a
    /// CLINICIAN would read off may not, unless the player asks for it.**
    ///
    /// The source gate above answers "may THIS BODY's numbers leave" (5.1.3). It has
    /// never been able to answer "may THIS NUMBER leave", and that gap is why the
    /// millisecond HRV statistics sat on the default wire beside the musical controls:
    /// nothing in the policy had the vocabulary to tell them apart. One gate answering
    /// two different questions is how the second one goes unasked.
    public enum FieldClass: String, Sendable, CaseIterable {

        /// Bounded or summary control values — the instrument's musical output.
        /// A BPM, a [0..1] coherence, a breath rate, a gesture channel. These ARE the
        /// product: an integrator's lighting desk, Resolume patch or ADM renderer is
        /// driven by them, and withholding them would not protect a body, it would
        /// break the thing Echoel is for.
        case derived

        /// Un-normalized time-domain HRV statistics in medical units — rMSSD and SDNN
        /// in milliseconds, pNN50 as a proportion of successive NN intervals. They are
        /// derived, not raw, so they are not forbidden — but they are the numbers a
        /// cardiology paper reports, they drive no light and no object position, and a
        /// default that streams them to a user-typed UDP host claims more of a body
        /// than the instrument needs. OPT-IN, never on by default.
        case clinical

        /// The un-derived signal itself, or anything it can be reconstructed from: a
        /// PPG waveform, an RR-interval series, camera frames, EEG samples.
        ///
        /// ⭐ **THIS CASE IS AN ASSERTION, NOT A SWITCH.** Nothing may set it to
        /// permitted, and today nothing could produce it either: `BioSampleFrame` is
        /// scalar-only — it declares no array, no buffer, no collection — so the
        /// transport type is STRUCTURALLY incapable of carrying a reconstructible
        /// signal off this device. The case exists so that a future field which COULD
        /// has somewhere to be classified, and so the guard has something to pin.
        case raw
    }

    /// The three millisecond/proportion HRV statistics. ONE definition (#416) — the
    /// sender filters on it and the guard reads it, so neither can drift from the other.
    public static let clinicalAddresses: Set<String> = [
        "/echoelmusic/bio/heart/rmssd",
        "/echoelmusic/bio/heart/pnn50",
        "/echoelmusic/bio/heart/sdnn",
    ]

    /// Every fixed address that carries a musical control value.
    public static let derivedAddresses: Set<String> = [
        "/echoelmusic/bio/synthetic",
        "/echoelmusic/bio/heart/bpm",
        "/echoelmusic/bio/heart/hrv",
        "/echoelmusic/bio/breath/rate",
        "/echoelmusic/bio/breath/phase",
        "/echoelmusic/bio/coherence",
        "/echoelmusic/bio/motion",
    ]

    /// Namespaces whose every member is a derived control value: the gesture channels
    /// (`ModSource.rawValue(from:)` is bounded per channel), the discrete bio events
    /// (`[confidence, aux]`) and the modulation tap (already-applied, scaled values).
    public static let derivedPrefixes: [String] = [
        "/echoelmusic/gesture/",
        "/echoelmusic/bio/event/",
        "/echoelmusic/mod/",
    ]

    /// Classify an egress address, or `nil` if nothing here knows it.
    ///
    /// ⚠️ `nil` IS A FINDING, NOT A SHRUG. The caller fails CLOSED on it, so a new
    /// address added without a class goes silent rather than streaming unclassified —
    /// and `TheClinicalDetailIsOptInTests` reddens with the name of the address, so the
    /// silence lasts one CI round rather than until someone notices. Fail-open here
    /// would mean every future address ships permitted by forgetfulness, which is the
    /// exact shape of the gap this enum was written to close.
    public static func fieldClass(ofOSCAddress address: String) -> FieldClass? {
        if clinicalAddresses.contains(address) { return .clinical }
        if derivedAddresses.contains(address) { return .derived }
        if derivedPrefixes.contains(where: { address.hasPrefix($0) }) { return .derived }
        return nil
    }

    /// May a value of this class leave, given the player's clinical-detail setting?
    ///
    /// `.raw` ignores the setting entirely — there is no configuration under which it
    /// returns `true`, and that is the whole point of it being a separate case rather
    /// than a stricter default.
    public static func allowsEgress(fieldClass: FieldClass, clinicalDetailEnabled: Bool) -> Bool {
        switch fieldClass {
        case .derived:  return true
        case .clinical: return clinicalDetailEnabled
        case .raw:      return false
        }
    }

    /// The whole decision for one outgoing message: source gate AND field gate.
    /// Callers ask THIS rather than composing the two themselves — the #186 lesson in
    /// this file's own header is that a rule re-stated at the call site is a rule whose
    /// test passes with the production guard deleted.
    public static func allowsEgress(address: String,
                                    source: BioSource,
                                    clinicalDetailEnabled: Bool) -> Bool {
        guard allowsEgress(source) else { return false }
        guard let cls = fieldClass(ofOSCAddress: address) else { return false }
        return allowsEgress(fieldClass: cls, clinicalDetailEnabled: clinicalDetailEnabled)
    }
}
