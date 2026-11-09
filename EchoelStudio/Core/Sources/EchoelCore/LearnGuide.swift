import Foundation

/// The names of the places and controls the Learn chapters point to, as the app spells them
/// (Recovery 8, 2026-11-05). One list, so a chapter can only name a control that is on it: a path
/// is typed in these cases, and every name a chapter quotes in its text (between “ and ”) is the
/// title of one of them — `LearnGuideTests` holds both. Each title was looked up in
/// `EchoelStudio/App` when it was written here; where the model in this package already carries a
/// name (an engine, an instrument, an effect), the tests compare the title with it.
///
/// Nothing here is stored. A renamed control is renamed here too, or Learn sends the musician to a
/// button that is not there.
public enum StudioPlace: String, CaseIterable, Sendable {
    // The song menu and its sections.
    case songMenu, songSection, exportSection, playAndSyncSection, connectSection, appSection
    case songSettings, browser, importMIDI, learn
    // The bar of views at the bottom.
    case instrument, tracks, arrange, session, mixer, field, sky
    // The transport and its switches.
    case play, record, loop, keys, click, more, midiLearn, writeAutomation, fieldWindow
    // Tracks.
    case addTrack, audio, returnTrack, video, drums, editNotes
    // Recording and takes.
    case monitor, useTheWholeTake, unfoldTakes
    // The track editor.
    case notes, steps, sound, done, timing, chords
    // The Sound page.
    case synth, sampler, engine, wavetable, texture, wavetableFromFile, builtInShapes, songFiles
    case character, rule, density, evolveRate, seed, audioUnitInstrument, importAudioFile
    case sliceToPads, writeThePatternAsAClip, removeSlices, reverse
    // The step grid.
    case euclideanRhythm, rotateLater, rotateEarlier, accent
    // An audio region's menu in Arrange.
    case pitchAndTexture, pitchCorrection, granularTexture, fadesGainAndWarp, convertToMIDI
    // Effects and the mix.
    case effects, addEffect, echoel, audioUnits, masterEffects, mixAnalysis
    case measured, masking, suggestMaster, applyToMaster
    case eq, compressor, delay, reverb
    // Modulation and the body.
    case modulate, bodySource, off, heartRateStrap, camera, appleHealth, phoneMotion
    case heartRate, hrv, coherence, breath, tiltLeftRight, tiltForwardBack, turning, movement
    case invert, remove, tempo, fixed, flow
    // The Field.
    case fullScreen, pattern, show, blendWith, externalDisplay, fieldOnExternalDisplay
    case cornerPin, resetCorners
    // Connections and the light show.
    case connections, artNet, sACN, admOSC, lightShow, fixturesAndCues, addFixture, addCue
    case go, blackout, look, snapshot, goThisCue, placeAtPlayhead, onTheTimeline, renderDMX, shareDMX
    // Export.
    case exportWAV, exportSpatialHeadphoneMix, exportStems, exportMIDI, exportEDL, exportOTIO
    case exportDAWproject, exportVideo, exportFieldLayer, headphoneSpatialMonitor
    // Siri and Shortcuts: the actions as the Shortcuts app lists them.
    case setTempo, launchScene, setKey, muteOrUnmuteTrack, stop, exportStemsAction

    /// The name as it stands on the screen (or, for a button drawn as an icon, as VoiceOver says it).
    public var title: String {
        switch self {
        case .songMenu: "Song menu"
        case .songSection: "Song"
        case .exportSection: "Export"
        case .playAndSyncSection: "Play and Sync"
        case .connectSection: "Connect"
        case .appSection: "App"
        case .songSettings: "Song Settings…"
        case .browser: "Browser…"
        case .importMIDI: "Import MIDI…"
        case .learn: "Learn…"
        case .instrument: "Instrument"
        case .tracks: "Tracks"
        case .arrange: "Arrange"
        case .session: "Session"
        case .mixer: "Mixer"
        case .field: "Field"
        case .sky: "Sky"
        case .play: "Play"
        case .record: "Record"
        case .loop: "Loop"
        case .keys: "Keys"
        case .click: "Click"
        case .more: "More"
        case .midiLearn: "MIDI Learn"
        case .writeAutomation: "Write Automation"
        case .fieldWindow: "Field Window"
        case .addTrack: "Add Track"
        case .audio: "Audio"
        case .returnTrack: "Return"
        case .video: "Video"
        case .drums: "Drums"
        case .editNotes: "Edit Notes"
        case .monitor: "Monitor"
        case .useTheWholeTake: "Use the Whole Take"
        case .unfoldTakes: "Unfold Takes"
        case .notes: "Notes"
        case .steps: "Steps"
        case .sound: "Sound"
        case .done: "Done"
        case .timing: "Timing"
        case .chords: "Chords"
        case .synth: "Synth"
        case .sampler: "Sampler"
        case .engine: "Engine"
        case .wavetable: "Wavetable"
        case .texture: "Texture"
        case .wavetableFromFile: "Wavetable from File…"
        case .builtInShapes: "Built-in Shapes"
        case .songFiles: "Song Files"
        case .character: "Character"
        case .rule: "Rule"
        case .density: "Density"
        case .evolveRate: "Evolve Rate"
        case .seed: "Seed"
        case .audioUnitInstrument: "Audio Unit Instrument"
        case .importAudioFile: "Import Audio File…"
        case .sliceToPads: "Slice to Pads"
        case .writeThePatternAsAClip: "Write the pattern as a clip"
        case .removeSlices: "Remove Slices"
        case .reverse: "Reverse"
        case .euclideanRhythm: "Euclidean Rhythm"
        case .rotateLater: "Rotate Later"
        case .rotateEarlier: "Rotate Earlier"
        case .accent: "Accent"
        case .pitchAndTexture: "Pitch & Texture…"
        case .pitchCorrection: "Pitch Correction"
        case .granularTexture: "Granular Texture"
        case .fadesGainAndWarp: "Fades, Gain & Warp…"
        case .convertToMIDI: "Convert to MIDI…"
        case .effects: "Effects"
        case .addEffect: "Add Effect"
        case .echoel: "Echoelmusic"
        case .audioUnits: "Audio Units"
        case .masterEffects: "Master Effects"
        case .mixAnalysis: "Mix Analysis…"
        case .measured: "Measured"
        case .masking: "Masking"
        case .suggestMaster: "Suggest Master"
        case .applyToMaster: "Apply to Master"
        case .eq: "EQ"
        case .compressor: "Compressor"
        case .delay: "Delay"
        case .reverb: "Reverb"
        case .modulate: "Modulate"
        case .bodySource: "Body Source"
        case .off: "Off"
        case .heartRateStrap: "Heart Rate Strap"
        case .camera: "Camera (fingertip on the rear lens)"
        case .appleHealth: "Apple Health (Apple Watch)"
        case .phoneMotion: "Phone Motion"
        case .heartRate: "Heart Rate"
        case .hrv: "HRV"
        case .coherence: "Coherence"
        case .breath: "Breath"
        case .tiltLeftRight: "Tilt Left/Right"
        case .tiltForwardBack: "Tilt Forward/Back"
        case .turning: "Turning"
        case .movement: "Movement"
        case .invert: "Invert"
        case .remove: "Remove"
        case .tempo: "Tempo"
        case .fixed: "Fixed"
        case .flow: "Flow"
        case .fullScreen: "Full Screen"
        case .pattern: "Pattern"
        case .show: "Show"
        case .blendWith: "Blend With"
        case .externalDisplay: "External Display"
        case .fieldOnExternalDisplay: "Field on External Display"
        case .cornerPin: "Corner Pin"
        case .resetCorners: "Reset Corners"
        case .connections: "Connections…"
        case .artNet: "Art-Net"
        case .sACN: "sACN (E1.31)"
        case .admOSC: "ADM-OSC"
        case .lightShow: "Light Show"
        case .fixturesAndCues: "Fixtures and Cues…"
        case .addFixture: "Add Fixture"
        case .addCue: "Add Cue"
        case .go: "GO"
        case .blackout: "Blackout"
        case .look: "Look"
        case .snapshot: "Snapshot"
        case .goThisCue: "GO This Cue"
        case .placeAtPlayhead: "Place at Playhead"
        case .onTheTimeline: "On the Timeline"
        case .renderDMX: "Render DMX"
        case .shareDMX: "Share DMX (CSV)"
        case .exportWAV: "Export WAV…"
        case .exportSpatialHeadphoneMix: "Export Spatial Headphone Mix (WAV)…"
        case .exportStems: "Export Stems…"
        case .exportMIDI: "Export MIDI…"
        case .exportEDL: "Export EDL for Resolve"
        case .exportOTIO: "Export for Resolve (OTIO)"
        case .exportDAWproject: "Export DAWproject"
        case .exportVideo: "Export Video…"
        case .exportFieldLayer: "Export Field Layer (Alpha)"
        case .headphoneSpatialMonitor: "Headphone Spatial Monitor"
        case .setTempo: "Set Tempo"
        case .launchScene: "Launch Scene"
        case .setKey: "Set Key"
        case .muteOrUnmuteTrack: "Mute or Unmute Track"
        case .stop: "Stop"
        case .exportStemsAction: "Export Stems"
        }
    }

    /// The place whose title is `title`; nil for a name the list does not hold.
    public init?(title: String) {
        guard let place = Self.allCases.first(where: { $0.title == title }) else { return nil }
        self = place
    }
}

/// One chapter of Learn: what a part of the app does today and the way to it.
public struct LearnChapter: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    /// One line, shown in the list under the title.
    public let summary: String
    /// The text, a paragraph each. A control's name stands between “ and ”.
    public let paragraphs: [String]
    /// The ways to the chapter's controls, each from where the musician starts.
    public let paths: [[StudioPlace]]
    /// Words a search should find the chapter by that its text does not use.
    public let keywords: [String]

    public init(id: String, title: String, summary: String, paragraphs: [String],
                paths: [[StudioPlace]], keywords: [String] = []) {
        self.id = id
        self.title = title
        self.summary = summary
        self.paragraphs = paragraphs
        self.paths = paths
        self.keywords = keywords
    }

    /// Every name the text quotes, in the order it quotes them.
    public var quotedNames: [String] {
        (paragraphs + [summary]).flatMap(LearnGuide.quotedNames(in:))
    }

    /// A path as one line, the steps joined by an arrow.
    public static func line(_ path: [StudioPlace]) -> String {
        path.map(\.title).joined(separator: " › ")
    }

    /// A path as VoiceOver says it.
    public static func spoken(_ path: [StudioPlace]) -> String {
        path.map(\.title).joined(separator: ", then ")
    }
}

/// The chapters of Learn and the search over them. Data, not views: the page draws what is here.
public enum LearnGuide {
    /// The chapters, in reading order.
    public static let chapters: [LearnChapter] = [
        LearnChapter(
            id: "firstTrack", title: "Your First Track and Recording",
            summary: "Add a track, play it on the keys, and record.",
            paragraphs: [
                "Open “Tracks” in the bar of views at the bottom and use “Add Track”: “Instrument”, “Audio”, “Return”, “Video” or “Drums”. Tap an instrument track to open its editor.",
                "The “Keys” under the views play the live track. “Record” in the transport starts the song and records the armed track; with nothing armed, it records the track the keys play. A MIDI take becomes a new clip, as one undo step.",
                "To record audio, arm an audio track with the round record button on its row and choose its input on the “Mixer”: the input menu of its strip also holds “Monitor”. Takes stay on the device.",
                "Every edit is one undo step: Undo and Redo sit beside the “Song menu”. Songs save on their own.",
            ],
            paths: [[.tracks, .addTrack], [.record], [.mixer, .monitor]],
            keywords: ["start", "begin", "microphone", "input", "arm", "undo", "save"]),
        LearnChapter(
            id: "comping", title: "Comping and Loop Record",
            summary: "Record pass after pass, then choose the best stretch of each.",
            paragraphs: [
                "With “Loop” on, the song repeats from bar 1 to the end of its last bar. When that loop is two bars or longer, a take keeps recording through every repeat and each pass becomes a take of its own; the line under the transport counts them. On a one-bar loop a take runs on as one recording. Loop record is in beta.",
                "The takes of a track stack as lanes under its row in “Arrange”, oldest on top. Tap a bar on a lane to use that take there, or swipe along a lane to use it for the stretch swiped. Touch and hold a lane for “Use the Whole Take” or “Unfold Takes”.",
                "Comping never changes a take: it only chooses which one sounds where, and every choice is one undo step.",
            ],
            paths: [[.loop], [.arrange]],
            keywords: ["takes", "comp", "lanes", "overdub", "passes", "beta"]),
        LearnChapter(
            id: "sound", title: "The Sound Page and the Engines",
            summary: "Choose an instrument and an engine, and shape its sound.",
            paragraphs: [
                "Tap an instrument track, then “Sound” at the top of the editor. “Instrument” chooses “Synth”, “Drums” or “Sampler”; “Audio Unit Instrument” plays an installed instrument from another maker.",
                "On the synth, “Engine” picks how the voice is made. “Wavetable” plays a table of single cycles: “Built-in Shapes”, or “Wavetable from File…” cuts the cycles from an audio file of your own, and “Song Files” reuses one the song already holds. “Character” moves through the table.",
                "“Texture” builds a tone from a row of cells that changes as it plays: “Rule” sets how the row evolves, “Density” how many partials sound, “Evolve Rate” how fast it changes and “Seed” the row each note starts from.",
                "The sampler plays one imported file across the keyboard: “Import Audio File…” brings it in.",
            ],
            paths: [[.tracks, .sound, .engine], [.tracks, .sound, .wavetableFromFile]],
            keywords: ["synth", "preset", "patch", "wavetable", "texture", "oscillator", "plugin"]),
        LearnChapter(
            id: "drums", title: "Drums and Slice to Pads",
            summary: "Program a beat on the step grid, or cut a break into pads.",
            paragraphs: [
                "“Add Track” › “Drums” adds a drum track with an empty one-bar clip. Tap the track: “Steps” shows one row per kit piece. Tap a step to set or clear a hit, hold it for an “Accent”.",
                "Touch and hold a row's name for “Euclidean Rhythm”, which spreads a number of hits evenly over the clip, and “Rotate Later” or “Rotate Earlier”.",
                "To play a drum loop as pads, put the file on a “Sampler” track and use “Slice to Pads” on its “Sound” page. It cuts the file at its hits into up to 16 pads from note 36; with “Write the pattern as a clip” on, it also writes the loop as a clip so the break plays at the song's tempo. Each pad has its start, its tune and “Reverse”; “Remove Slices” takes them away.",
            ],
            paths: [[.tracks, .addTrack, .drums], [.tracks, .sound, .sliceToPads]],
            keywords: ["beat", "steps", "kit", "break", "slicer", "pads", "euclid"]),
        LearnChapter(
            id: "effects", title: "Effects and Mix Analysis",
            summary: "Insert effects on any track or the master, then measure the mix.",
            paragraphs: [
                "On the “Mixer”, “Effects” on a strip opens that track's insert chain; the master strip opens “Master Effects”. “Add Effect” offers the “Echoelmusic” effects — “EQ”, “Compressor”, “Delay”, “Reverb” and more — and installed “Audio Units”.",
                "On an audio region in “Arrange”, touch and hold for “Pitch & Texture…”: “Pitch Correction” and “Granular Texture” are rendered into the region offline.",
                "“Mix Analysis…” in the master's effects measures the song offline: loudness, true peak and stereo image under “Measured”, tracks that share their strongest octave under “Masking”, and a master chain under “Suggest Master”, with every number it comes from. Nothing changes until “Apply to Master”, which replaces the master's effects as one undo step.",
            ],
            paths: [[.mixer, .effects, .addEffect], [.mixer, .masterEffects, .mixAnalysis]],
            keywords: ["fx", "insert", "master", "loudness", "lufs", "pitch correction"]),
        LearnChapter(
            id: "body", title: "Modulation and Body Sources",
            summary: "Let a pulse, a breath or the phone's movement move a sound.",
            paragraphs: [
                "Choose a source under “Song menu” › “Connect” › “Body Source”: “Heart Rate Strap”, “Camera (fingertip on the rear lens)” or “Apple Health (Apple Watch)”, one at a time, and “Phone Motion” beside any of them. “Off” stops them all.",
                "In “Arrange”, touch and hold a track's name for “Modulate” and choose what moves what, for example “Heart Rate”, “HRV”, “Coherence”, “Breath”, “Tilt Left/Right”, “Tilt Forward/Back”, “Turning” or “Movement” onto a volume, a pan or a synth value. Each route has its depth, “Invert” and “Remove”.",
                "Know the limits. HRV needs about 8 clean beats and coherence about 16 before they add anything; a camera reading takes a still fingertip. Apple Health arrives 4–5 seconds late, so it suits slow changes only. The body never sets the beat. On the “Instrument” view, “Tempo” offers “Flow”, which waits for a steady pulse and then moves the tempo one step per bar, and “Fixed”, which keeps it where you set it.",
                "Body readings are for self-observation only, not a diagnosis. They stay on the device unless you share them yourself in “Connections…”.",
            ],
            paths: [[.songMenu, .connectSection, .bodySource], [.arrange, .modulate], [.instrument, .tempo]],
            keywords: ["pulse", "heart", "bpm", "strap", "watch", "motion", "lfo", "route"]),
        LearnChapter(
            id: "field", title: "The Field and an External Screen",
            summary: "A picture that moves with the song, on the phone or a projector.",
            paragraphs: [
                "“Field” in the bar of views shows the picture; “Field Window” in the transport keeps it as a small window over the other views, and “Full Screen” fills the screen with it.",
                "The button with the grid, “Pattern”, chooses the look, a second look under “Blend With”, and under “Show” a meter of the master in its place.",
                "Connect a display or projector and the Field goes out there; “Field on External Display” under “External Display” turns that off. “Corner Pin” squares a projected picture, and “Reset Corners” takes it back.",
            ],
            paths: [[.field, .pattern], [.field, .pattern, .externalDisplay]],
            keywords: ["visual", "picture", "projector", "screen", "monitor", "beamer"]),
        LearnChapter(
            id: "light", title: "Light Cues",
            summary: "Patch fixtures, build cues and run a light show with the song.",
            paragraphs: [
                "Open “Song menu” › “Connections…” › “Fixtures and Cues…”. “Add Fixture” patches a fixture from its profile; “Add Cue” makes a new cue with the values of the cue showing now.",
                "“GO” starts the next cue with a fade, “GO This Cue” a chosen one, and “Blackout” fades every light to dark. A cue's “Look” is a “Snapshot” or follows the song's key, level and beat.",
                "“Place at Playhead” puts a cue on the song; the placed ones are listed “On the Timeline” and start where they stand. The light goes out through the “Art-Net” and “sACN (E1.31)” connections, which are off until you switch one on. “Render DMX” writes the show as a file to share with “Share DMX (CSV)”.",
            ],
            paths: [[.songMenu, .connections, .fixturesAndCues]],
            keywords: ["dmx", "lighting", "fixture", "cue", "artnet", "show"]),
        LearnChapter(
            id: "export", title: "Export to Resolve, DAWproject, MIDI, Stems and Spatial",
            summary: "Take the song to another app, an editor or a DAW.",
            paragraphs: [
                "Every export is in the “Song menu” under “Export”; a finished file comes up in the share sheet.",
                "“Export WAV…” renders the arrangement and reports its loudness and true peak. “Export Stems…” writes one WAV per track the mix hears, before the master effects. “Export MIDI…” writes a Standard MIDI File.",
                "For DaVinci Resolve, “Export EDL for Resolve” and “Export for Resolve (OTIO)” write the song's video and audio parts with their files; “Export Field Layer (Alpha)” writes the Field alone with transparency, and “Export Video…” the song as an MP4. “Export DAWproject” hands tracks, clips, notes, tempo, markers and audio to another DAW.",
                "Spatial: “Headphone Spatial Monitor” under “Play and Sync” places every track around you on headphones, and “Export Spatial Headphone Mix (WAV)…” renders exactly that. “ADM-OSC” in “Connections…” sends every track as an audio object to an immersive renderer.",
            ],
            paths: [[.songMenu, .exportSection], [.songMenu, .playAndSyncSection, .headphoneSpatialMonitor]],
            keywords: ["resolve", "edl", "otio", "dawproject", "midi", "stems", "wav", "video", "spatial", "share"]),
        LearnChapter(
            id: "siri", title: "Siri and Shortcuts",
            summary: "Play, stop and change the open song by voice or with a shortcut.",
            paragraphs: [
                "Echoelmusic's actions are in the Shortcuts app and work with Siri, Spotlight and the Action button: “Play”, “Stop”, “Set Tempo”, “Add Track”, “Launch Scene”, “Set Key”, “Mute or Unmute Track” and “Export Stems”.",
                "Say, for example, \"Play Echoelmusic\", \"Set the tempo in Echoelmusic\" or \"Export stems in Echoelmusic\". Each change to the song is one undo step, and finished stems come up in the share sheet.",
            ],
            paths: [[.songMenu, .exportSection, .exportStems]],
            keywords: ["siri", "shortcuts", "voice", "spotlight", "action button"]),
        LearnChapter(
            id: "safety", title: "Safety",
            summary: "Light, level and what body readings are for.",
            paragraphs: [
                "Light and the Field never change faster than three times a second (3 Hz). Listen at a moderate level, especially on headphones; a new song starts with the master 6 dB down, and you raise it on the “Mixer”. Body readings are for self-observation only, never a diagnosis.",
            ],
            paths: [[.mixer]],
            keywords: ["flash", "volume", "hearing", "health", "privacy"]),
    ]

    /// The chapters a search for `query` finds, in reading order: every word of the query must
    /// appear in the chapter's title, summary, text, paths or keywords, without regard to case
    /// or accents. An empty query finds every chapter.
    public static func search(_ query: String, in chapters: [LearnChapter] = LearnGuide.chapters) -> [LearnChapter] {
        let words = query.split(whereSeparator: { $0.isWhitespace }).map { fold(String($0)) }
        guard !words.isEmpty else { return chapters }
        return chapters.filter { chapter in
            let haystack = fold(([chapter.title, chapter.summary] + chapter.paragraphs + chapter.keywords
                                 + chapter.paths.flatMap { $0.map(\.title) }).joined(separator: " "))
            return words.allSatisfy { haystack.contains($0) }
        }
    }

    /// Every name `text` quotes between “ and ”.
    public static func quotedNames(in text: String) -> [String] {
        var names: [String] = []
        var rest = text[...]
        while let open = rest.firstIndex(of: "“") {
            let after = rest.index(after: open)
            guard let close = rest[after...].firstIndex(of: "”") else { break }
            names.append(String(rest[after..<close]))
            rest = rest[rest.index(after: close)...]
        }
        return names
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
