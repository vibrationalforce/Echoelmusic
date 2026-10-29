import Foundation

/// Which body data may leave the device over a connection, and when. Ported from the earlier
/// app's `BioEgressPolicy` (its two gates are kept as they were proven) and given the third gate
/// Echoel Studio adds: nothing of the body goes out until the musician turns body sharing on in
/// the Connections panel. Pure; `ConnectionsPolicyTests` replays every decision.
///
/// Three questions, asked in this order, each failing closed:
/// 1. **May this body's numbers leave at all?** Only what Echoel measures itself — the camera and
///    a chest strap. Anything read from the Health store stays on the device, whatever the
///    musician switches on (App Store Review 5.1.3: Health data is never shared with third
///    parties, and a UDP packet to a typed host is beyond our vouching).
/// 2. **Did the musician ask?** `Consent.sharesBody` is the panel's toggle, off at every launch.
/// 3. **May this number leave?** A `.derived` value is what the instrument plays with — a pulse in
///    beats per minute, a coherence 0 … 1 — and goes with body sharing. A `.clinical` value is
///    what a cardiologist would read off (RMSSD, SDNN, pNN50 in medical units) and needs its own
///    consent. `.raw` — a waveform, an interval series — never leaves; no switch reaches it.
/// An address nobody classified is refused, so a new address ships silent until someone decides.
public enum BioEgressPolicy {
    public enum FieldClass: String, Sendable, CaseIterable {
        case derived
        case clinical
        case raw
    }

    /// What the musician has switched on. Both start off and are not stored across launches.
    public struct Consent: Equatable, Sendable {
        public var sharesBody: Bool
        public var sharesClinicalDetail: Bool

        public init(sharesBody: Bool = false, sharesClinicalDetail: Bool = false) {
            self.sharesBody = sharesBody
            self.sharesClinicalDetail = sharesClinicalDetail
        }

        public static let off = Consent()
    }

    /// Gate 1. No `default`, on purpose: a source added to `BodyChannel.Source` does not compile
    /// here until someone decides whether it may leave the device — that compile error is the
    /// review step. A default would hand a future Health-derived source the answer silently.
    public static func allowsEgress(_ source: BodyChannel.Source) -> Bool {
        switch source {
        case .camera, .ble:
            return true
        case .health:
            return false
        }
    }

    public static let clinicalAddresses: Set<String> = [
        "/echoelmusic/bio/heart/rmssd",
        "/echoelmusic/bio/heart/pnn50",
        "/echoelmusic/bio/heart/sdnn",
    ]

    public static let derivedAddresses: Set<String> = [
        "/echoelmusic/bio/synthetic",
        "/echoelmusic/bio/heart/bpm",
        "/echoelmusic/bio/heart/hrv",
        "/echoelmusic/bio/breath/rate",
        "/echoelmusic/bio/breath/phase",
        "/echoelmusic/bio/coherence",
        "/echoelmusic/bio/motion",
    ]

    /// The song's own state — not the body. Listed one by one rather than as a prefix, so an
    /// address added to the namespace ships silent until it is classified here.
    public static let musicAddresses: Set<String> = [
        "/echoelmusic/music/tempo",
        "/echoelmusic/music/key/root",
        "/echoelmusic/music/beat/phase",
        "/echoelmusic/music/level/master",
        "/echoelmusic/music/note/count",
    ]

    /// Namespaces whose every member is a derived control value.
    public static let derivedPrefixes: [String] = [
        "/echoelmusic/bio/event/",
        "/echoelmusic/mod/",
    ]

    /// The namespaces whose addresses may carry a body: every `/bio/` address is a measurement,
    /// and a modulation tap (`/mod/`) carries whatever a route feeds it — a body route included,
    /// and the address cannot say which. Both need consent; everything else under
    /// `/echoelmusic/` is the song's.
    public static let bodyPrefixes: [String] = [
        "/echoelmusic/bio/",
        "/echoelmusic/mod/",
    ]

    /// Whether an address may carry body data at all (gates 1 and 2 apply), as against the song's.
    public static func carriesBody(address: String) -> Bool {
        bodyPrefixes.contains { address.hasPrefix($0) }
    }

    /// The class of an address, or nil when nothing here knows it — which the caller reads as "do
    /// not send", never as "probably fine".
    public static func fieldClass(ofOSCAddress address: String) -> FieldClass? {
        if clinicalAddresses.contains(address) { return .clinical }
        if derivedAddresses.contains(address) { return .derived }
        if musicAddresses.contains(address) { return .derived }
        if derivedPrefixes.contains(where: { address.hasPrefix($0) }) { return .derived }
        return nil
    }

    /// Gate 3 alone. `.raw` ignores the consent: there is no setting under which it is true.
    public static func allowsEgress(fieldClass: FieldClass, consent: Consent) -> Bool {
        switch fieldClass {
        case .derived: return true
        case .clinical: return consent.sharesClinicalDetail
        case .raw: return false
        }
    }

    /// The whole decision for one message. A body address needs an allowed source, body sharing
    /// and an allowed class; a song address needs only its class. Callers ask this and never
    /// re-state the rule at the call site — a rule copied there is a rule whose test passes with
    /// the real guard deleted.
    public static func allowsEgress(address: String, source: BodyChannel.Source?, consent: Consent) -> Bool {
        guard let fieldClass = fieldClass(ofOSCAddress: address) else { return false }
        if carriesBody(address: address) {
            guard consent.sharesBody, let source, allowsEgress(source) else { return false }
        }
        return allowsEgress(fieldClass: fieldClass, consent: consent)
    }
}
