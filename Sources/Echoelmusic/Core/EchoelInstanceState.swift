//
//  EchoelInstanceState.swift
//  Echoelmusic — Core (WA3 slice 2 / WA4 prerequisite 4: the Echoel Device's instance state,
//  assembled READ-ONLY from the owners that hold it today)
//
//  WHY THIS EXISTS. `docs/dev/NATIVE_DEVICE_ARCHITECTURE.md` §P item 4: WA4 (the Arrange +
//  Session front) may only show "this track's Echoel" once the Echoel instance state has at
//  least a read-only assembly — otherwise the first front invents a second truth for it. Today
//  that state is spread over `@AppStorage` keys, `MoodStorage`'s JSON, `MixerStore`, the
//  modulation matrix and the view-private `currentPatch`. This file gathers it into ONE value.
//
//  ⛔ IT IS NOT `EchoelDeviceState`. That type (`DSP/EchoelBodyVibeDevice.swift`) lives in the
//  AUv3-compiled `DSP/` layer, knows exactly one device type (`echoel.bodyvibe`, the plug-in)
//  and refuses every other one at both boundaries. The app instrument is a DIFFERENT device —
//  mood, genre, rhythm characters, the role mix and a modulation matrix have no field there,
//  and registering an app type inside `DSP/` would drag app types into the plug-in build.
//
//  ⚠️ IMPORTER FIRST, WRITER SECOND (#1416). Nothing restores from this value and nothing
//  persists it. `assemble` READS its inputs and writes nothing — the guard compares the whole
//  `UserDefaults` dictionary before and after. The owners on disk stay the truth; a wrong
//  assembly costs a corrected function, never a user's sound.
//
//  WHAT IS DELIBERATELY OUTSIDE (the WA2 §O / WA3 §E split, not an oversight):
//  · SESSION state — key, scale, A4, tone system, the BPM lock and the tempo modulation route.
//    A device reads those from the Session; it never owns them.
//  · RUNTIME state — the body-voice arm, `isActive`, every bio value, `ModulationEngine`'s
//    10 Hz outputs. None of it is creative state, and bio never enters a saved value.
//  · The preset-list cursor `studio.presetIndex` — a UI cache, not sound.
//  · KNOWN GAPS, named so nobody reads this as complete: the three bus inserts (`TrackFXStore`
//    keeps its keys private), the live FX-chain parameters and `delaySync` (not persisted
//    anywhere today), and the `touch.*` / `field.autoPlay.*` surfaces (a second step).
//
//  Foundation-only on purpose: every field is a raw value or a Foundation-only model type, so
//  the value can move into the EchoelCore target (#95) unchanged when that target exists.
//

import Foundation

/// The creative state of ONE Echoel instrument instance, as today's owners hold it.
public struct EchoelInstanceState: Codable, Sendable, Equatable {

    public static let currentSchemaVersion = 1

    /// The device TYPE id. Distinct from `EchoelBodyVibeDevice.typeID` ("echoel.bodyvibe"):
    /// the plug-in and the app instrument are two device types, not one.
    public static let deviceType = "echoel.instrument"

    public var schemaVersion: Int
    public var deviceType: String

    /// The sound: the patch the instrument is playing, as the caller hands it over.
    public var patch: SynthPatch
    /// `FXCharacter` raw value (the enum is not `Codable`).
    public var fxCharacterRaw: String
    /// `MusicStyle` raw value — genre is DEVICE-local (WA3 §E), not Session context.
    public var genreRaw: String
    /// The eight mood dials in `MoodStorage`'s field form.
    public var moodFields: [String: Float]
    /// The global bar-variation depth (#1402).
    public var variation: Double
    /// `nil` = never set, so the instrument's own default applies. The key has no typed owner
    /// with a default (it is declared by literal in one view), and copying that literal here
    /// would be a second default that can drift.
    public var articulation: Double?
    public var bassRhythmRaw: String
    public var padRhythmRaw: String
    public var padGate: Double
    public var padAccent: Double
    public var padEvolve: Double
    public var autoMode: Bool
    /// `LoopBarLength` raw value — the device's PHRASE length, not the Session loop (§O).
    public var loopBarsRaw: Int
    /// The composer's internal role mix, keyed by `MixerStore.storageKeys`. ⚠️ This is the
    /// DEVICE's voice balance (bass · pad · lead), never a workstation mixer (WA1 S28).
    public var roleLevels: [String: Float]
    /// The device's own modulation routes. The tempo route is Session state and is removed.
    public var modulation: ModulationMatrix

    public init(schemaVersion: Int, deviceType: String, patch: SynthPatch,
                fxCharacterRaw: String, genreRaw: String, moodFields: [String: Float],
                variation: Double, articulation: Double?, bassRhythmRaw: String,
                padRhythmRaw: String, padGate: Double, padAccent: Double, padEvolve: Double,
                autoMode: Bool, loopBarsRaw: Int, roleLevels: [String: Float],
                modulation: ModulationMatrix) {
        self.schemaVersion = schemaVersion
        self.deviceType = deviceType
        self.patch = patch
        self.fxCharacterRaw = fxCharacterRaw
        self.genreRaw = genreRaw
        self.moodFields = moodFields
        self.variation = variation
        self.articulation = articulation
        self.bassRhythmRaw = bassRhythmRaw
        self.padRhythmRaw = padRhythmRaw
        self.padGate = padGate
        self.padAccent = padAccent
        self.padEvolve = padEvolve
        self.autoMode = autoMode
        self.loopBarsRaw = loopBarsRaw
        self.roleLevels = roleLevels
        self.modulation = modulation
    }

    /// The two keys declared by literal at their single view site (`EchoelStudioView`),
    /// named once here so the guard can scan that view for them (the `SoundReset` pattern).
    public static let fxCharacterKey = "studio.fxCharacter"
    public static let articulationKey = "studio.articulation"

    /// Assemble the instance state from today's owners. READ-ONLY: nothing is written.
    ///
    /// - Parameters:
    ///   - defaults: the store the instrument's `@AppStorage` keys live in.
    ///   - patch: the live patch. It is view state (`currentPatch`), so the caller on the main
    ///     actor passes it — the same value `currentProject()` saves.
    ///   - modulation: the engine's matrix, passed by value for the same reason.
    ///
    /// No argument has a default (#431/#440/#443): a defaulted argument no call site writes
    /// shows up in no diff.
    public static func assemble(defaults: UserDefaults,
                                patch: SynthPatch,
                                modulation: ModulationMatrix) -> EchoelInstanceState {

        func string(_ key: String, _ fallback: String) -> String {
            defaults.string(forKey: key) ?? fallback
        }
        func double(_ key: String, _ fallback: Double) -> Double {
            guard defaults.object(forKey: key) != nil else { return fallback }
            let v = defaults.double(forKey: key)
            return v.isFinite ? v : fallback
        }

        let moodRaw = string(StudioDefaultKeys.mood.key, StudioDefaultKeys.mood.value)
        let moodFields = MoodStorage.fields(from: MoodStorage.decode(moodRaw))

        var roleLevels: [String: Float] = [:]
        for key in MixerStore.storageKeys {
            if defaults.object(forKey: key) == nil {
                roleLevels[key] = MixerStore.defaultLevel
            } else {
                let v = defaults.float(forKey: key)
                roleLevels[key] = v.isFinite ? v : MixerStore.defaultLevel
            }
        }

        let loopBars: Int = defaults.object(forKey: StudioDefaultKeys.loopBars.key) == nil
            ? StudioDefaultKeys.loopBars.value.rawValue
            : defaults.integer(forKey: StudioDefaultKeys.loopBars.key)

        let autoMode: Bool = defaults.object(forKey: StudioDefaultKeys.autoMode.key) == nil
            ? StudioDefaultKeys.autoMode.value
            : defaults.bool(forKey: StudioDefaultKeys.autoMode.key)

        var articulation: Double? = nil
        if defaults.object(forKey: articulationKey) != nil {
            let v = defaults.double(forKey: articulationKey)
            if v.isFinite { articulation = v }
        }

        let deviceRoutes = modulation.routes.filter { $0.destination.key != ModDestinationKey.tempo }

        return EchoelInstanceState(
            schemaVersion: currentSchemaVersion,
            deviceType: deviceType,
            patch: patch,
            fxCharacterRaw: string(fxCharacterKey, FXCharacter.auto.rawValue),
            genreRaw: string(StudioDefaultKeys.genre.key, StudioDefaultKeys.genre.value.rawValue),
            moodFields: moodFields,
            variation: double(StudioDefaultKeys.moodVariation.key,
                              StudioDefaultKeys.moodVariation.value),
            articulation: articulation,
            bassRhythmRaw: string(StudioDefaultKeys.bassRhythm.key,
                                  StudioDefaultKeys.bassRhythm.value),
            padRhythmRaw: string(StudioDefaultKeys.padRhythm.key,
                                 StudioDefaultKeys.padRhythm.value),
            padGate: double(StudioDefaultKeys.padGate.key, StudioDefaultKeys.padGate.value),
            padAccent: double(StudioDefaultKeys.padAccent.key, StudioDefaultKeys.padAccent.value),
            padEvolve: double(StudioDefaultKeys.padEvolve.key, StudioDefaultKeys.padEvolve.value),
            autoMode: autoMode,
            loopBarsRaw: loopBars,
            roleLevels: roleLevels,
            modulation: ModulationMatrix(routes: deviceRoutes))
    }
}
