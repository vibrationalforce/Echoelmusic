import Foundation

/// The Body voice (W12): an instrument track named "Body" that the keys play and the body shapes,
/// through ordinary modulation routes the musician sees and changes like any other (W2). Silent
/// until switched on: the Instrument page's switch adds the track the first time and from then on
/// unmutes and mutes it; the track and its routes stay in the song either way.
///
/// Only sources a body source measures move it — the pulse, coherence and the breath, which the
/// chest strap and the camera both carry (the breath read from the timing of the heartbeat, W12b) —
/// so no route waits for a value that never comes. The routes are made when the voice is added and
/// never again: a song whose Body voice was made before a route existed keeps the routes it has.
public enum BodyVoice {
    public static let trackName = "Body"
    /// The pad it starts from, on the DDSP engine, whose character runs from dark and breathy to
    /// bright and pure — the value coherence moves.
    public static let presetName = "Warm Pad"
    public static let engineName = "DDSP"
    public static let character = 0.35
    /// Green in the track lists; colour is never its only cue, it is named.
    public static let colorIndex = 4

    /// One route of the voice: the source, the synth value it moves and how far — a share of that
    /// value's travel, as every route has it — and whether the source moves it from zero
    /// (unipolar) or both ways around where the sound sets it (bipolar).
    public struct Route: Sendable, Equatable {
        public let source: ModulationSource
        public let parameter: SynthParameter
        public let depth: Double
        public let polarity: ModulationRoute.Polarity

        init(source: ModulationSource, parameter: SynthParameter, depth: Double,
             polarity: ModulationRoute.Polarity = .unipolar) {
            self.source = source
            self.parameter = parameter
            self.depth = depth
            self.polarity = polarity
        }
    }

    /// Coherence opens the filter and brightens the engine; the pulse sets the vibrato; the breath
    /// swells the level — up with a breath in, down with a breath out, both ways around where the
    /// sound sets it, so the voice is as loud on average with the breath as without it. The synth's
    /// own level rather than the track's fader: it is the instrument breathing, ahead of its
    /// effects, so a reverb's tail rings on, and the fader stays the musician's. The depth keeps the
    /// swell a breath, not a gate: the pad never falls silent at the bottom of a breath out.
    public static let routes: [Route] = [
        Route(source: .coherence, parameter: .cutoff, depth: 0.25),
        Route(source: .coherence, parameter: .character, depth: 0.4),
        Route(source: .heartRate, parameter: .vibrato, depth: 1),
        Route(source: .breath, parameter: .level, depth: 0.1, polarity: .bipolar),
    ]

    /// The song's Body track: the first instrument track named `trackName`.
    public static func track(in project: Project) -> Track? {
        project.tracks.first { $0.kind == .instrument && $0.name == trackName }
    }

    /// Whether the voice sounds: its track is there and not muted.
    public static func isOn(in project: Project) -> Bool {
        guard let voice = track(in: project) else { return false }
        return !voice.mixer.isMuted
    }

    /// Whether the switch can turn the voice on: its track is there, or the song has room for one
    /// more instrument track and its routes.
    public static func hasRoom(in project: Project) -> Bool {
        track(in: project) != nil
            || (project.canAddTrack(.instrument) && project.modRoutes.count + routes.count <= Modulation.routeLimit)
    }

    /// What turning the switch performs, as one undo step: on, the first time, the track with its
    /// sound and routes, else the track unmuted; off, the track muted. Nil when the switch already
    /// stands there.
    public static func switching(_ on: Bool, in project: Project,
                                 newID: () -> UUID = { UUID() }) -> (commands: [Command], title: String)? {
        if let voice = track(in: project) {
            guard voice.mixer.isMuted == on else { return nil }
            let mute: [Command] = [.setMute(voice.id, !on)]
            return (mute, on ? "Body Voice On" : "Body Voice Off")
        }
        guard on else { return nil }
        let id = TrackID(newID())
        var commands: [Command] = [
            .addTrack(id: id, name: trackName, kind: .instrument, index: nil),
            .setTrackColor(id, colorIndex: colorIndex),
            .loadInstrumentPreset(id, name: presetName),
        ]
        if let engine = SynthParameter.engine.choices.firstIndex(of: engineName) {
            commands.append(.setInstrumentParameter(id, key: SynthParameter.engine.key.rawValue, value: Double(engine)))
        }
        commands.append(.setInstrumentParameter(id, key: SynthParameter.character.key.rawValue, value: character))
        for route in routes {
            let target = ParameterAddress(.track(id), route.parameter.key)
            commands.append(.setModRoute(ModulationRoute(id: newID(), source: route.source, target: target, depth: route.depth,
                                                         polarity: route.polarity)))
        }
        return (commands, "Add Body Voice")
    }
}
