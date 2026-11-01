import Foundation

/// The Body voice (W12): an instrument track named "Body" that the keys play and the body shapes,
/// through ordinary modulation routes the musician sees and changes like any other (W2). Silent
/// until switched on: the Instrument page's switch adds the track the first time and from then on
/// unmutes and mutes it; the track and its routes stay in the song either way.
///
/// Only sources a body source measures move it — the pulse and coherence, which the chest strap
/// and the camera both carry — so no route waits for a value that never comes. Breath is a source
/// name without a producer in the studio today; it joins when something measures it.
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
    /// value's travel, as every route has it.
    public struct Route: Sendable, Equatable {
        public let source: ModulationSource
        public let parameter: SynthParameter
        public let depth: Double
    }

    /// Coherence opens the filter and brightens the engine; the pulse sets the vibrato.
    public static let routes: [Route] = [
        Route(source: .coherence, parameter: .cutoff, depth: 0.25),
        Route(source: .coherence, parameter: .character, depth: 0.4),
        Route(source: .heartRate, parameter: .vibrato, depth: 1),
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
            commands.append(.setModRoute(ModulationRoute(id: newID(), source: route.source, target: target, depth: route.depth)))
        }
        return (commands, "Add Body Voice")
    }
}
