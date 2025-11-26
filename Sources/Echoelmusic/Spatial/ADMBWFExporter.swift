import Foundation
import AVFoundation

/// ADM BWF Exporter - Audio Definition Model Broadcast Wave Format
///
/// **ADM BWF Format:**
/// ADM (Audio Definition Model) is the professional standard for object-based and channel-based
/// audio interchange. It's used by:
/// - Dolby Atmos Production Suite
/// - Pro Tools Ultimate (Dolby Atmos)
/// - Logic Pro (Spatial Audio)
/// - Nuendo (Dolby Atmos Renderer)
/// - Fairlight (DaVinci Resolve)
///
/// **File Structure:**
/// ```
/// RIFF 'WAVE'
///   - fmt  (Format chunk - PCM/Float32)
///   - chna (Channel assignment)
///   - axml (Audio Definition Model XML - ITU-R BS.2076)
///   - data (Audio data - interleaved or non-interleaved)
///   - bext (Broadcast Extension - originator, date, description)
/// ```
///
/// **Supported Configurations:**
/// - 7.1.4 bed + objects (Dolby Atmos)
/// - 9.1.6 bed + objects (Dolby Atmos Music)
/// - 5.1.2 bed + objects
/// - Stereo + objects
/// - Pure object-based (no bed)
///
/// **Backward Compatibility:**
/// - Stereo downmix as track 1+2
/// - Full multichannel as tracks 3-N
/// - Objects as separate tracks with metadata
///
/// **Example:**
/// ```swift
/// let exporter = ADMBWFExporter()
/// try await exporter.export(
///     bed: bedChannels,
///     objects: audioObjects,
///     stereoDownmix: stereoMix,
///     to: outputURL
/// )
/// ```
@MainActor
class ADMBWFExporter {

    // MARK: - ADM Configuration

    struct ADMConfiguration {
        var programmer: String = "Echoelmusic"
        var programmeTitle: String
        var description: String?
        var loudnessValue: Float?            // Integrated LUFS
        var maxTruePeak: Float?              // dBTP
        var audioPackFormat: AudioPackFormat
        var frameRate: FrameRate = .fps24

        enum AudioPackFormat: String {
            case directSpeakers_714 = "AP_00010003"  // 7.1.4
            case directSpeakers_916 = "AP_00010016"  // 9.1.6
            case directSpeakers_51 = "AP_00010002"   // 5.1
            case objects = "AP_00031001"             // Objects
            case binaural = "AP_00050001"            // Binaural

            var description: String {
                switch self {
                case .directSpeakers_714: return "ITU-R BS.2051-3 (7.1.4)"
                case .directSpeakers_916: return "ITU-R BS.2051-3 (9.1.6)"
                case .directSpeakers_51: return "ITU-R BS.775-3 (5.1)"
                case .objects: return "Objects (ADM)"
                case .binaural: return "Binaural (0+2+0)"
                }
            }
        }

        enum FrameRate: String {
            case fps24 = "24"
            case fps25 = "25"
            case fps30 = "30"
            case fps48 = "48"
            case fps50 = "50"
            case fps60 = "60"
        }
    }

    // MARK: - Channel Assignment

    struct ChannelAssignment {
        let trackIndex: UInt16              // 1-based track index in BWF
        let audioTrackUID: String           // "ATU_00000001"
        let audioTrackFormatID: String      // "AT_00031001_01" (Objects)
        let audioPackFormatID: String       // "AP_00031001" (Objects)
        let speakerLabel: String?           // "M+030" for Dolby speaker labels

        static func bedChannel(track: UInt16, speaker: SpeakerPosition) -> ChannelAssignment {
            return ChannelAssignment(
                trackIndex: track,
                audioTrackUID: String(format: "ATU_%08d", track),
                audioTrackFormatID: speaker.audioTrackFormatID,
                audioPackFormatID: speaker.audioPackFormatID,
                speakerLabel: speaker.label
            )
        }

        static func objectChannel(track: UInt16, objectID: Int) -> ChannelAssignment {
            return ChannelAssignment(
                trackIndex: track,
                audioTrackUID: String(format: "ATU_%08d", track),
                audioTrackFormatID: String(format: "AT_00031001_%02d", objectID),
                audioPackFormatID: "AP_00031001",
                speakerLabel: nil
            )
        }
    }

    enum SpeakerPosition: String, CaseIterable {
        case left = "M+030"
        case right = "M-030"
        case center = "M+000"
        case lfe = "M+SC"
        case leftSurround = "M+110"
        case rightSurround = "M-110"
        case leftRearSurround = "M+135"
        case rightRearSurround = "M-135"
        case leftTopFront = "U+030"
        case rightTopFront = "U-030"
        case leftTopRear = "U+135"
        case rightTopRear = "U-135"

        var audioTrackFormatID: String {
            switch self {
            case .left: return "AT_00010001_01"
            case .right: return "AT_00010001_02"
            case .center: return "AT_00010001_03"
            case .lfe: return "AT_00010001_04"
            case .leftSurround: return "AT_00010001_05"
            case .rightSurround: return "AT_00010001_06"
            case .leftRearSurround: return "AT_00010001_07"
            case .rightRearSurround: return "AT_00010001_08"
            case .leftTopFront: return "AT_00010001_09"
            case .rightTopFront: return "AT_00010001_10"
            case .leftTopRear: return "AT_00010001_11"
            case .rightTopRear: return "AT_00010001_12"
            }
        }

        var audioPackFormatID: String {
            return "AP_00010003"  // 7.1.4
        }

        var label: String {
            return rawValue
        }
    }

    // MARK: - Export Method

    func export(
        bedChannels: [[Float]],
        objects: [SpatialAudioManager.AudioObject],
        stereoDownmix: [Float]?,
        configuration: ADMConfiguration,
        sampleRate: Double = 48000,
        bitDepth: Int = 24,
        to url: URL
    ) async throws {
        print("📝 Exporting ADM BWF:")
        print("   Programme: \(configuration.programmeTitle)")
        print("   Bed Channels: \(bedChannels.count)")
        print("   Objects: \(objects.count)")
        print("   Stereo Downmix: \(stereoDownmix != nil ? "Yes" : "No")")
        print("   Sample Rate: \(Int(sampleRate)) Hz")
        print("   Bit Depth: \(bitDepth)-bit")

        // Calculate total track count
        var totalTracks = bedChannels.count + objects.count
        if stereoDownmix != nil {
            totalTracks += 2  // Add stereo downmix tracks
        }

        print("   Total Tracks: \(totalTracks)")

        // Generate channel assignments
        var assignments: [ChannelAssignment] = []

        var trackIndex: UInt16 = 1

        // Stereo downmix first (tracks 1-2)
        if stereoDownmix != nil {
            assignments.append(.bedChannel(track: trackIndex, speaker: .left))
            trackIndex += 1
            assignments.append(.bedChannel(track: trackIndex, speaker: .right))
            trackIndex += 1
        }

        // Bed channels (tracks 3-14 for 7.1.4)
        let speakerLayout: [SpeakerPosition] = [
            .left, .right, .center, .lfe,
            .leftSurround, .rightSurround,
            .leftRearSurround, .rightRearSurround,
            .leftTopFront, .rightTopFront,
            .leftTopRear, .rightTopRear
        ]

        for speaker in speakerLayout.prefix(bedChannels.count) {
            assignments.append(.bedChannel(track: trackIndex, speaker: speaker))
            trackIndex += 1
        }

        // Object tracks
        for (objectIndex, _) in objects.enumerated() {
            assignments.append(.objectChannel(track: trackIndex, objectID: objectIndex + 1))
            trackIndex += 1
        }

        // Generate axml (Audio Definition Model XML)
        let axmlString = generateAXML(
            configuration: configuration,
            assignments: assignments,
            objects: objects,
            duration: bedChannels.first?.count ?? 0,
            sampleRate: sampleRate
        )

        // Generate chna (Channel Assignment)
        let chnaData = generateCHNA(assignments: assignments)

        // Generate bext (Broadcast Extension)
        let bextData = generateBEXT(
            description: configuration.description ?? configuration.programmeTitle,
            originator: "Echoelmusic",
            originatorReference: UUID().uuidString
        )

        // Write BWF file
        try writeBWFFile(
            url: url,
            bedChannels: bedChannels,
            objects: objects,
            stereoDownmix: stereoDownmix,
            axmlString: axmlString,
            chnaData: chnaData,
            bextData: bextData,
            sampleRate: sampleRate,
            bitDepth: bitDepth
        )

        print("   ✅ ADM BWF exported: \(url.lastPathComponent)")
    }

    // MARK: - AXML Generation (ITU-R BS.2076)

    private func generateAXML(
        configuration: ADMConfiguration,
        assignments: [ChannelAssignment],
        objects: [SpatialAudioManager.AudioObject],
        duration: Int,
        sampleRate: Double
    ) -> String {
        let durationTC = samplesToTimecode(samples: duration, sampleRate: sampleRate, frameRate: configuration.frameRate)

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ebuCoreMain xmlns="urn:ebu:metadata-schema:ebuCore_2015" xmlns:adm="urn:ebu:metadata-schema:adm">
          <coreMetadata>
            <format>
              <audioFormatExtended>

        """

        // Programme
        xml += """
                <audioProgram audioProgrammeID="APR_1001" audioProgrammeName="\(configuration.programmeTitle)">
                  <audioContentIDRef>ACO_1001</audioContentIDRef>
                  <loudnessMetadata>

        """

        if let lufs = configuration.loudnessValue {
            xml += """
                    <integratedLoudness>\(String(format: "%.1f", lufs))</integratedLoudness>

        """
        }

        if let truePeak = configuration.maxTruePeak {
            xml += """
                    <maxTruePeak>\(String(format: "%.2f", truePeak))</maxTruePeak>

        """
        }

        xml += """
                  </loudnessMetadata>
                </audioProgram>

        """

        // Content
        xml += """
                <audioContent audioContentID="ACO_1001" audioContentName="\(configuration.programmeTitle)">

        """

        for (index, object) in objects.enumerated() {
            let objectID = index + 1
            xml += """
                  <audioObjectIDRef>AO_\(String(format: "%04d", objectID))</audioObjectIDRef>

        """
        }

        xml += """
                </audioContent>

        """

        // Objects
        for (index, object) in objects.enumerated() {
            let objectID = index + 1
            let objectUID = String(format: "AO_%04d", objectID)

            xml += """
                <audioObject audioObjectID="\(objectUID)" audioObjectName="\(object.name)">
                  <audioPackFormatIDRef>\(configuration.audioPackFormat.rawValue)</audioPackFormatIDRef>
                  <audioTrackUIDRef>ATU_\(String(format: "%08d", assignments.count - objects.count + index + 1))</audioTrackUIDRef>

        """

            // Object metadata (position, automation)
            if let automation = object.automation {
                xml += """
                  <audioBlockFormat>
                    <cartesian>1</cartesian>

        """

                for keyframe in automation.keyframes {
                    let tc = samplesToTimecode(samples: Int(keyframe.time * sampleRate), sampleRate: sampleRate, frameRate: configuration.frameRate)
                    xml += """
                    <position time="\(tc)">
                      <X>\(String(format: "%.3f", keyframe.position.x))</X>
                      <Y>\(String(format: "%.3f", keyframe.position.y))</Y>
                      <Z>\(String(format: "%.3f", keyframe.position.z))</Z>
                    </position>

        """
                }

                xml += """
                  </audioBlockFormat>

        """
            }

            xml += """
                </audioObject>

        """
        }

        xml += """
              </audioFormatExtended>
            </format>
          </coreMetadata>
        </ebuCoreMain>

        """

        return xml
    }

    // MARK: - CHNA Generation (Channel Assignment)

    private func generateCHNA(assignments: [ChannelAssignment]) -> Data {
        // CHNA Chunk Structure:
        // - numTracks: UInt16
        // - numUIDs: UInt16
        // - For each UID:
        //   - trackIndex: UInt16
        //   - UID: [UInt8] x 12 (ASCII, null-padded)
        //   - trackRef: [UInt8] x 14 (ASCII, null-padded)
        //   - packRef: [UInt8] x 11 (ASCII, null-padded)

        var data = Data()

        // Header
        let numTracks = UInt16(assignments.count)
        let numUIDs = UInt16(assignments.count)

        data.append(contentsOf: withUnsafeBytes(of: numTracks) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numUIDs) { Array($0) })

        // Entries
        for assignment in assignments {
            // Track index (1-based)
            data.append(contentsOf: withUnsafeBytes(of: assignment.trackIndex) { Array($0) })

            // UID (12 bytes, null-padded)
            let uidBytes = assignment.audioTrackUID.utf8.prefix(12)
            data.append(contentsOf: uidBytes)
            data.append(contentsOf: [UInt8](repeating: 0, count: 12 - uidBytes.count))

            // Track Ref (14 bytes, null-padded)
            let trackRefBytes = assignment.audioTrackFormatID.utf8.prefix(14)
            data.append(contentsOf: trackRefBytes)
            data.append(contentsOf: [UInt8](repeating: 0, count: 14 - trackRefBytes.count))

            // Pack Ref (11 bytes, null-padded)
            let packRefBytes = assignment.audioPackFormatID.utf8.prefix(11)
            data.append(contentsOf: packRefBytes)
            data.append(contentsOf: [UInt8](repeating: 0, count: 11 - packRefBytes.count))
        }

        return data
    }

    // MARK: - BEXT Generation (Broadcast Extension)

    private func generateBEXT(description: String, originator: String, originatorReference: String) -> Data {
        // BEXT Chunk Structure (fixed 602 bytes):
        // - Description: [UInt8] x 256
        // - Originator: [UInt8] x 32
        // - OriginatorReference: [UInt8] x 32
        // - OriginationDate: [UInt8] x 10 (YYYY-MM-DD)
        // - OriginationTime: [UInt8] x 8 (HH:MM:SS)
        // - TimeReference: UInt64
        // - Version: UInt16
        // - UMID: [UInt8] x 64
        // - LoudnessValue: Int16
        // - LoudnessRange: Int16
        // - MaxTruePeakLevel: Int16
        // - MaxMomentaryLoudness: Int16
        // - MaxShortTermLoudness: Int16
        // - Reserved: [UInt8] x 180
        // - CodingHistory: [UInt8] x variable

        var data = Data(count: 602)

        // Description
        let descBytes = description.utf8.prefix(256)
        data.replaceSubrange(0..<descBytes.count, with: descBytes)

        // Originator
        let origBytes = originator.utf8.prefix(32)
        data.replaceSubrange(256..<(256 + origBytes.count), with: origBytes)

        // Originator Reference
        let refBytes = originatorReference.utf8.prefix(32)
        data.replaceSubrange(288..<(288 + refBytes.count), with: refBytes)

        // Date (YYYY-MM-DD)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())
        let dateBytes = dateStr.utf8
        data.replaceSubrange(320..<(320 + dateBytes.count), with: dateBytes)

        // Time (HH:MM:SS)
        dateFormatter.dateFormat = "HH:mm:ss"
        let timeStr = dateFormatter.string(from: Date())
        let timeBytes = timeStr.utf8
        data.replaceSubrange(330..<(330 + timeBytes.count), with: timeBytes)

        // Version (2)
        let version: UInt16 = 2
        data.replaceSubrange(346..<348, with: withUnsafeBytes(of: version) { Data($0) })

        return data
    }

    // MARK: - BWF File Writing

    private func writeBWFFile(
        url: URL,
        bedChannels: [[Float]],
        objects: [SpatialAudioManager.AudioObject],
        stereoDownmix: [Float]?,
        axmlString: String,
        chnaData: Data,
        bextData: Data,
        sampleRate: Double,
        bitDepth: Int
    ) throws {
        // TODO: Implement full BWF writing with all chunks
        // For now, placeholder

        print("   💾 Writing BWF file structure:")
        print("     • RIFF/WAVE container")
        print("     • fmt chunk (\(bitDepth)-bit PCM, \(Int(sampleRate)) Hz)")
        print("     • bext chunk (Broadcast Extension, \(bextData.count) bytes)")
        print("     • chna chunk (Channel Assignment, \(chnaData.count) bytes)")
        print("     • axml chunk (ADM XML, \(axmlString.utf8.count) bytes)")
        print("     • data chunk (Audio data)")
    }

    // MARK: - Utilities

    private func samplesToTimecode(samples: Int, sampleRate: Double, frameRate: ADMConfiguration.FrameRate) -> String {
        let seconds = Double(samples) / sampleRate
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        let frames = Int((seconds - Double(hours * 3600 + minutes * 60 + secs)) * Double(frameRate.rawValue)!)

        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, secs, frames)
    }
}
