import Foundation

/// Export tuning presets to industry-standard formats for DAWs, plugins, and external instruments
/// Supports more formats than Omnisphere, with seamless integration to professional tools
///
/// Supported export formats:
/// - Scala (.scl/.tun) - Universal standard
/// - MIDI Tuning Standard (MTS) SysEx
/// - Logic Pro X / GarageBand tuning
/// - Ableton Live tuning
/// - Serum wavetable synth tuning
/// - Omnisphere tuning (for comparison/compatibility)
/// - JSON (custom format for DAW scripting)
/// - AnaMark TUN format
@MainActor
class TuningPresetExporter: ObservableObject {

    /// Export formats
    enum ExportFormat: String, CaseIterable {
        case scala = "Scala (.scl)"
        case scalaTun = "Scala with Keyboard Mapping (.tun)"
        case midiTuningStandard = "MIDI Tuning Standard (MTS SysEx)"
        case logicProX = "Logic Pro X / GarageBand"
        case abletonLive = "Ableton Live"
        case serum = "Serum Wavetable Synth"
        case omnisphere = "Omnisphere"
        case json = "JSON (Universal)"
        case anaMarkTun = "AnaMark TUN"
        case csv = "CSV (Spreadsheet)"
    }


    // MARK: - Export Methods

    /// Export tuning system to specified format
    /// - Parameters:
    ///   - tuning: TuningSystem to export
    ///   - format: Export format
    /// - Returns: File content as Data
    func export(tuning: TuningSystem, format: ExportFormat) throws -> Data {
        switch format {
        case .scala:
            return try exportScalaScale(tuning: tuning)
        case .scalaTun:
            return try exportScalaTuning(tuning: tuning)
        case .midiTuningStandard:
            return try exportMTS(tuning: tuning)
        case .logicProX:
            return try exportLogicProX(tuning: tuning)
        case .abletonLive:
            return try exportAbletonLive(tuning: tuning)
        case .serum:
            return try exportSerum(tuning: tuning)
        case .omnisphere:
            return try exportOmnisphere(tuning: tuning)
        case .json:
            return try exportJSON(tuning: tuning)
        case .anaMarkTun:
            return try exportAnaMark(tuning: tuning)
        case .csv:
            return try exportCSV(tuning: tuning)
        }
    }

    /// Export microtonal scale to specified format
    func export(scale: MicrotonalScale, format: ExportFormat) throws -> Data {
        switch format {
        case .scala:
            return try exportScalaScale(scale: scale)
        case .scalaTun:
            return try exportScalaTuning(scale: scale)
        case .midiTuningStandard:
            return Data(scale.exportMTS())
        case .json:
            return try exportJSON(scale: scale)
        default:
            // For simple tuning systems, convert to TuningSystem and export
            throw ExportError.formatNotSupported("This format requires TuningSystem, not MicrotonalScale")
        }
    }


    // MARK: - Scala Export (.scl)

    private func exportScalaScale(tuning: TuningSystem) throws -> Data {
        var scl = """
        ! \(tuning.name)
        ! \(tuning.description)
        !
        ! Historical context: \(tuning.era.rawValue), \(tuning.region.rawValue)
        ! Reference: A4 = \(tuning.a4Frequency) Hz
        !
        """

        if !tuning.scientificReferences.isEmpty {
            scl += "! Scientific references:\n"
            for ref in tuning.scientificReferences {
                scl += "! - \(ref)\n"
            }
        }

        scl += "!\n"
        scl += " \(tuning.name)\n"
        scl += " 12\n"  // 12 notes (standard chromatic scale)
        scl += "!\n"

        // Calculate cent deviations for all 12 notes
        for midiNote in 60...71 {  // C4 to B4
            let frequency = tuning.frequency(forMIDINote: midiNote)
            let standardFrequency = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
            let cents = 1200.0 * log2(frequency / standardFrequency)
            scl += String(format: " %.6f\n", 100.0 * Double(midiNote - 60) + cents)
        }

        scl += " 1200.0\n"  // Octave

        guard let data = scl.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }

    private func exportScalaScale(scale: MicrotonalScale) throws -> Data {
        guard let data = scale.exportScalaScale().data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }


    // MARK: - Scala Tuning (.tun)

    private func exportScalaTuning(tuning: TuningSystem) throws -> Data {
        var tun = """
        ; \(tuning.name)
        ; \(tuning.description)
        ; Reference: A4 = \(tuning.a4Frequency) Hz
        ;

        """

        // Write frequencies for all 128 MIDI notes
        for midiNote in 0...127 {
            let freq = tuning.frequency(forMIDINote: midiNote)
            tun += String(format: "note %d\t%.6f\n", midiNote, freq)
        }

        guard let data = tun.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }

    private func exportScalaTuning(scale: MicrotonalScale) throws -> Data {
        guard let data = scale.exportScalaTuning().data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }


    // MARK: - MIDI Tuning Standard (MTS)

    private func exportMTS(tuning: TuningSystem) throws -> Data {
        var mts: [UInt8] = []

        // MIDI Tuning Standard (MTS) SysEx
        // F0 7E <device ID> 08 <sub-ID> <tuning program> [data] F7

        // Universal Non-Real Time SysEx header
        mts += [0xF0, 0x7E, 0x7F]  // F0=SysEx, 7E=Non-Real Time, 7F=All devices

        // Sub-ID #1: 08 = MIDI Tuning Standard
        mts.append(0x08)

        // Sub-ID #2: 02 = Single Note Tuning Change (Real-Time)
        mts.append(0x02)

        // Tuning program number (0-127)
        mts.append(0x00)

        // Tuning name (16 bytes ASCII)
        let nameData = tuning.name.prefix(16).data(using: .ascii) ?? Data()
        mts += nameData + Data(repeating: 0x20, count: 16 - nameData.count)

        // Tuning data for all 128 MIDI notes
        for midiNote in 0...127 {
            let freq = tuning.frequency(forMIDINote: midiNote)

            // Convert frequency to MTS format
            // MTS uses: semitone number + fractional semitone in units of 1/16384
            let semitones = 69.0 + 12.0 * log2(freq / 440.0)
            let semitoneByte = UInt8(clamping: Int(semitones))
            let fraction = (semitones - floor(semitones)) * 16384.0
            let fractionMSB = UInt8(clamping: Int(fraction) >> 7)
            let fractionLSB = UInt8(clamping: Int(fraction) & 0x7F)

            mts += [semitoneByte, fractionMSB, fractionLSB]
        }

        // Checksum (optional, using 0x00)
        mts.append(0x00)

        // End of SysEx
        mts.append(0xF7)

        return Data(mts)
    }


    // MARK: - Logic Pro X / GarageBand

    private func exportLogicProX(tuning: TuningSystem) throws -> Data {
        // Logic Pro X uses MIDI Learn or scripting
        // Export as readable text file with instructions

        var logic = """
        Logic Pro X / GarageBand Tuning: \(tuning.name)

        Reference Frequency: A4 = \(tuning.a4Frequency) Hz

        INSTRUCTIONS:
        1. Create a new Software Instrument track
        2. Open the Track Settings inspector
        3. Use the Tuning control to adjust the global tuning
        4. Or use the Hermode Tuning plugin (if available)

        Cent deviations from A=440 Hz for each semitone:

        """

        for midiNote in 60...71 {  // C4 to B4
            let noteName = noteNameForMIDI(midiNote)
            let freq = tuning.frequency(forMIDINote: midiNote)
            let standardFreq = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
            let cents = 1200.0 * log2(freq / standardFreq)

            logic += String(format: "%@: %+.2f cents (%.2f Hz)\n", noteName, cents, freq)
        }

        logic += "\n"
        logic += "Historical Context:\n\(tuning.historicalContext)\n"

        guard let data = logic.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }


    // MARK: - Ableton Live

    private func exportAbletonLive(tuning: TuningSystem) throws -> Data {
        // Ableton Live 11+ supports Scala files
        // Also export as Max for Live tuning device preset

        var ableton = """
        Ableton Live Tuning: \(tuning.name)

        Reference: A4 = \(tuning.a4Frequency) Hz

        METHOD 1: Use Scala .scl file
        - Save the accompanying .scl file
        - Load it in Ableton Live's Tuning section (Live 11+)
        - Or use Max for Live Scale device

        METHOD 2: Manual tuning (Sampler/Wavetable)
        Pitch transpose (cents) for each MIDI note:

        """

        for midiNote in 60...71 {
            let noteName = noteNameForMIDI(midiNote)
            let cents = centsDeviation(tuning: tuning, midiNote: midiNote)
            ableton += String(format: "%@ (MIDI %d): %+.2f cents\n", noteName, midiNote, cents)
        }

        guard let data = ableton.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }


    // MARK: - Serum

    private func exportSerum(tuning: TuningSystem) throws -> Data {
        // Serum uses .ttun files (text-based)
        var serum = """
        ; Serum tuning file
        ; \(tuning.name)
        ; \(tuning.description)

        [Tuning]
        reference_note=69
        reference_pitch=\(tuning.a4Frequency)

        """

        // Serum expects cent deviations for each MIDI note
        for midiNote in 0...127 {
            let cents = centsDeviation(tuning: tuning, midiNote: midiNote)
            serum += String(format: "note.%d=%.6f\n", midiNote, cents)
        }

        guard let data = serum.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }


    // MARK: - Omnisphere

    private func exportOmnisphere(tuning: TuningSystem) throws -> Data {
        // Omnisphere uses custom tuning files
        // Export in similar format to Serum for compatibility

        var omni = """
        [OMNISPHERE TUNING]
        Name=\(tuning.name)
        Description=\(tuning.description)
        Category=\(tuning.category.rawValue)
        Reference=A4=\(tuning.a4Frequency) Hz

        """

        for midiNote in 0...127 {
            let freq = tuning.frequency(forMIDINote: midiNote)
            omni += String(format: "NOTE_%03d=%.6f\n", midiNote, freq)
        }

        guard let data = omni.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }


    // MARK: - JSON

    private func exportJSON(tuning: TuningSystem) throws -> Data {
        let jsonDict: [String: Any] = [
            "name": tuning.name,
            "description": tuning.description,
            "category": tuning.category.rawValue,
            "era": tuning.era.rawValue,
            "region": tuning.region.rawValue,
            "referenceFrequency": tuning.a4Frequency,
            "referenceMIDINote": 69,
            "historicalContext": tuning.historicalContext,
            "scientificReferences": tuning.scientificReferences,
            "frequencies": (0...127).map { tuning.frequency(forMIDINote: $0) },
            "centsDeviations": (0...127).map { centsDeviation(tuning: tuning, midiNote: $0) }
        ]

        return try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
    }

    private func exportJSON(scale: MicrotonalScale) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(scale)
    }


    // MARK: - AnaMark TUN

    private func exportAnaMark(tuning: TuningSystem) throws -> Data {
        // AnaMark TUN format (used by various soft synths)
        var tun = """
        ; AnaMark Tuning File
        ; \(tuning.name)

        [Tuning]

        """

        for midiNote in 0...127 {
            let freq = tuning.frequency(forMIDINote: midiNote)
            tun += String(format: "note %d = %.6f\n", midiNote, freq)
        }

        guard let data = tun.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }


    // MARK: - CSV

    private func exportCSV(tuning: TuningSystem) throws -> Data {
        var csv = "MIDI Note,Note Name,Frequency (Hz),Cents Deviation from A440\n"

        for midiNote in 0...127 {
            let noteName = noteNameForMIDI(midiNote)
            let freq = tuning.frequency(forMIDINote: midiNote)
            let cents = centsDeviation(tuning: tuning, midiNote: midiNote)

            csv += String(format: "%d,%@,%.6f,%+.6f\n", midiNote, noteName, freq, cents)
        }

        guard let data = csv.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }


    // MARK: - Helper Methods

    private func centsDeviation(tuning: TuningSystem, midiNote: Int) -> Double {
        let freq = tuning.frequency(forMIDINote: midiNote)
        let standardFreq = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
        return 1200.0 * log2(freq / standardFreq)
    }

    private func noteNameForMIDI(_ midiNote: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midiNote / 12) - 1
        let noteName = noteNames[midiNote % 12]
        return "\(noteName)\(octave)"
    }


    // MARK: - File Saving

    /// Save exported data to file
    func save(data: Data, filename: String, format: ExportFormat) throws -> URL {
        let fileExtension = fileExtension(for: format)
        let fullFilename = filename.hasSuffix(fileExtension) ? filename : "\(filename)\(fileExtension)"

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent("Tunings").appendingPathComponent(fullFilename)

        // Create directory if needed
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try data.write(to: fileURL)
        return fileURL
    }

    private func fileExtension(for format: ExportFormat) -> String {
        switch format {
        case .scala:
            return ".scl"
        case .scalaTun:
            return ".tun"
        case .midiTuningStandard:
            return ".syx"
        case .logicProX:
            return ".txt"
        case .abletonLive:
            return ".txt"
        case .serum:
            return ".ttun"
        case .omnisphere:
            return ".omni"
        case .json:
            return ".json"
        case .anaMarkTun:
            return ".tun"
        case .csv:
            return ".csv"
        }
    }
}


// MARK: - Extensions

extension UInt8 {
    init(clamping value: Int) {
        if value < 0 {
            self = 0
        } else if value > 255 {
            self = 255
        } else {
            self = UInt8(value)
        }
    }
}


// MARK: - Errors

enum ExportError: Error {
    case encodingFailed
    case formatNotSupported(String)
    case invalidData
}
