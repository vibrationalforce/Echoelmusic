//
//  VideoExportManager.swift
//  EchoelCalculator
//
//  Export scientific timing data to Video Editing Software
//  Premiere Pro, DaVinci Resolve, Final Cut Pro
//

import Foundation

/// Export manager for video editing software
public class VideoExportManager {

    // MARK: - Video Sync Point

    /// Video editing sync point with scientific metadata
    public struct VideoSyncPoint {
        public let timestamp: Double  // seconds
        public let intensity: Float  // 0-1
        public let cutType: CutType
        public let colorTemperature: Float  // Kelvin
        public let brightness: Float  // 0-1
        public let brainwave: String
        public let description: String

        public enum CutType: String {
            case cut = "Cut"
            case dissolve = "Dissolve"
            case fade = "Fade"
            case wipe = "Wipe"
        }
    }

    // MARK: - Sync Point Generation

    /// Generate video sync points based on BPM and neuroscience
    /// Based on: Cutting et al. (2011). Attention, Perception, & Psychophysics
    public static func generateSyncPoints(
        from output: ScientificEchoelCalculator.CalculatorOutput,
        duration: TimeInterval
    ) -> [VideoSyncPoint] {

        var syncPoints: [VideoSyncPoint] = []

        var currentTime: Double = 0
        var beatCount = 0

        while currentTime < duration {
            beatCount += 1

            // Calculate intensity based on entrainment frequency
            let phase = Float(currentTime) * Float(output.entrainmentFrequency) * 2.0 * .pi
            let intensity = 0.5 + 0.5 * sin(phase)

            // Determine cut type based on beat position
            let cutType: VideoSyncPoint.CutType
            if beatCount % 4 == 1 {
                cutType = .cut  // On downbeat
            } else if beatCount % 2 == 0 {
                cutType = .dissolve  // On half beat
            } else {
                cutType = .fade
            }

            // Color temperature affects arousal (Küller et al., 2006)
            // Warm = relaxing, Cool = alerting
            let colorTemp: Float
            switch output.dominantBrainwave.name {
            case "Delta":
                colorTemp = 2700  // Very warm (sleep)
            case "Theta":
                colorTemp = 3000  // Warm (meditation)
            case "Alpha":
                colorTemp = 4000  // Neutral (relaxation)
            case "Beta":
                colorTemp = 5500  // Cool (focus)
            case "Gamma", "40Hz Gamma (MIT)":
                colorTemp = 6500  // Cool daylight (alertness)
            default:
                colorTemp = 4000
            }

            // Brightness modulation
            let brightness = 0.4 + 0.6 * intensity

            let syncPoint = VideoSyncPoint(
                timestamp: currentTime,
                intensity: intensity,
                cutType: cutType,
                colorTemperature: colorTemp,
                brightness: brightness,
                brainwave: output.dominantBrainwave.name,
                description: "Beat \(beatCount) - \(output.dominantBrainwave.name) (\(String(format: "%.1f", output.entrainmentFrequency)) Hz)"
            )

            syncPoints.append(syncPoint)

            currentTime += Double(output.msDelay) / 1000.0
        }

        return syncPoints
    }

    // MARK: - Adobe Premiere Pro XML

    /// Export to Adobe Premiere Pro (FCP7 XML format)
    /// Reference: Apple FCP7 XML Interchange Format
    public static func exportToPremiereXML(
        _ output: ScientificEchoelCalculator.CalculatorOutput,
        duration: TimeInterval,
        projectName: String = "EchoelSync"
    ) -> String {

        let syncPoints = generateSyncPoints(from: output, duration: duration)

        var xml = ""
        xml += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<!DOCTYPE xmeml>\n"
        xml += "<xmeml version=\"5\">\n"
        xml += "  <project>\n"
        xml += "    <name>\(projectName)</name>\n"
        xml += "    <children>\n"

        // Sequence
        xml += "      <sequence>\n"
        xml += "        <name>EchoelSync Sequence</name>\n"
        xml += "        <duration>\(Int(duration * output.optimalFrameRate))</duration>\n"

        // Rate
        xml += "        <rate>\n"
        xml += "          <timebase>\(Int(output.optimalFrameRate))</timebase>\n"
        xml += "          <ntsc>\(output.optimalFrameRate == 29.97 ? "TRUE" : "FALSE")</ntsc>\n"
        xml += "        </rate>\n"

        // Media
        xml += "        <media>\n"
        xml += "          <video>\n"
        xml += "            <track>\n"

        // Add clips for each sync point
        for (index, point) in syncPoints.enumerated() {
            let startFrame = Int(point.timestamp * Double(output.optimalFrameRate))
            let endFrame = startFrame + output.framesPerBeat

            xml += "              <clipitem id=\"clip\(index)\">\n"
            xml += "                <name>\(point.description)</name>\n"
            xml += "                <start>\(startFrame)</start>\n"
            xml += "                <end>\(endFrame)</end>\n"
            xml += "                <in>0</in>\n"
            xml += "                <out>\(output.framesPerBeat)</out>\n"

            // Add filter for color temperature
            xml += "                <filter>\n"
            xml += "                  <effect>\n"
            xml += "                    <name>Color Temperature</name>\n"
            xml += "                    <parameter>\n"
            xml += "                      <parameterid>temperature</parameterid>\n"
            xml += "                      <value>\(point.colorTemperature)</value>\n"
            xml += "                    </parameter>\n"
            xml += "                  </effect>\n"
            xml += "                </filter>\n"

            // Add brightness adjustment
            xml += "                <filter>\n"
            xml += "                  <effect>\n"
            xml += "                    <name>Brightness & Contrast</name>\n"
            xml += "                    <parameter>\n"
            xml += "                      <parameterid>brightness</parameterid>\n"
            xml += "                      <value>\(point.brightness)</value>\n"
            xml += "                    </parameter>\n"
            xml += "                  </effect>\n"
            xml += "                </filter>\n"

            xml += "              </clipitem>\n"
        }

        xml += "            </track>\n"
        xml += "          </video>\n"
        xml += "        </media>\n"

        // Markers
        xml += "        <marker>\n"
        for (index, point) in syncPoints.enumerated() {
            let frame = Int(point.timestamp * Double(output.optimalFrameRate))
            xml += "          <marker id=\"marker\(index)\">\n"
            xml += "            <name>\(point.description)</name>\n"
            xml += "            <in>\(frame)</in>\n"
            xml += "            <out>\(frame)</out>\n"
            xml += "            <comment>Brainwave: \(point.brainwave), Intensity: \(String(format: "%.2f", point.intensity))</comment>\n"
            xml += "          </marker>\n"
        }
        xml += "        </marker>\n"

        xml += "      </sequence>\n"
        xml += "    </children>\n"
        xml += "  </project>\n"
        xml += "</xmeml>\n"

        return xml
    }

    // MARK: - DaVinci Resolve EDL

    /// Export to DaVinci Resolve EDL format
    /// Reference: CMX 3600 EDL specification
    public static func exportToResolveEDL(
        _ output: ScientificEchoelCalculator.CalculatorOutput,
        duration: TimeInterval
    ) -> String {

        let syncPoints = generateSyncPoints(from: output, duration: duration)

        var edl = ""
        edl += "TITLE: EchoelSync Project\n"
        edl += "FCM: NON-DROP FRAME\n"
        edl += "\n"

        // Add edits
        for (index, point) in syncPoints.enumerated() {
            let editNumber = String(format: "%03d", index + 1)
            let timecode = formatTimecode(point.timestamp, frameRate: output.optimalFrameRate)
            let endTimecode = formatTimecode(
                point.timestamp + Double(output.msDelay) / 1000.0,
                frameRate: output.optimalFrameRate
            )

            edl += "\(editNumber)  AX       V     C        "
            edl += "\(timecode) \(endTimecode) \(timecode) \(endTimecode)\n"
            edl += "* FROM CLIP NAME: \(point.description)\n"
            edl += "* BRAINWAVE: \(point.brainwave)\n"
            edl += "* INTENSITY: \(String(format: "%.2f", point.intensity))\n"
            edl += "* COLOR TEMP: \(Int(point.colorTemperature))K\n"
            edl += "* TRANSITION: \(point.cutType.rawValue)\n"
            edl += "\n"
        }

        // Add scientific metadata as comments
        edl += "* SCIENTIFIC METADATA\n"
        edl += "* Brainwave Range: \(output.dominantBrainwave.name) (\(String(format: "%.1f", output.dominantBrainwave.minHz))-\(String(format: "%.1f", output.dominantBrainwave.maxHz)) Hz)\n"
        edl += "* Entrainment Frequency: \(String(format: "%.2f", output.entrainmentFrequency)) Hz\n"
        edl += "* Cognitive Effect: \(output.cognitiveEffect)\n"
        edl += "* Statistical Significance: p < \(output.dominantBrainwave.pValue)\n"
        edl += "* Effect Size: d = \(output.dominantBrainwave.effectSize)\n"
        edl += "* Reference: \(output.dominantBrainwave.reference)\n"

        return edl
    }

    // MARK: - Final Cut Pro XML

    /// Export to Final Cut Pro X XML (FCPXML)
    public static func exportToFinalCutProXML(
        _ output: ScientificEchoelCalculator.CalculatorOutput,
        duration: TimeInterval
    ) -> String {

        let syncPoints = generateSyncPoints(from: output, duration: duration)

        var xml = ""
        xml += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<!DOCTYPE fcpxml>\n"
        xml += "<fcpxml version=\"1.9\">\n"
        xml += "  <resources>\n"
        xml += "    <format id=\"r1\" name=\"FFVideoFormat1080p\(Int(output.optimalFrameRate))\" frameDuration=\"1/\(Int(output.optimalFrameRate))s\" width=\"1920\" height=\"1080\"/>\n"
        xml += "  </resources>\n"

        xml += "  <library>\n"
        xml += "    <event name=\"EchoelSync\">\n"
        xml += "      <project name=\"EchoelSync Project\">\n"
        xml += "        <sequence format=\"r1\" duration=\"\(Int(duration * Double(output.optimalFrameRate)))/\(Int(output.optimalFrameRate))s\">\n"
        xml += "          <spine>\n"

        // Add clips
        for (index, point) in syncPoints.enumerated() {
            let offset = String(format: "%.0f", point.timestamp * Double(output.optimalFrameRate))
            let durationFrames = output.framesPerBeat

            xml += "            <video name=\"\(point.description)\" offset=\"\(offset)/\(Int(output.optimalFrameRate))s\" duration=\"\(durationFrames)/\(Int(output.optimalFrameRate))s\">\n"

            // Add color correction based on brainwave
            xml += "              <color-correction>\n"
            xml += "                <temperature>\(Int(point.colorTemperature))</temperature>\n"
            xml += "                <exposure>\(point.brightness)</exposure>\n"
            xml += "              </color-correction>\n"

            // Add marker
            xml += "              <marker start=\"0s\" value=\"\(point.brainwave) - \(String(format: "%.2f", point.intensity))\" />\n"

            xml += "            </video>\n"
        }

        xml += "          </spine>\n"
        xml += "        </sequence>\n"
        xml += "      </project>\n"
        xml += "    </event>\n"
        xml += "  </library>\n"
        xml += "</fcpxml>\n"

        return xml
    }

    // MARK: - JSON Export (Universal)

    /// Export to JSON for custom integrations
    public static func exportToJSON(
        _ output: ScientificEchoelCalculator.CalculatorOutput,
        duration: TimeInterval
    ) -> String {

        let syncPoints = generateSyncPoints(from: output, duration: duration)

        var json: [String: Any] = [:]

        // Project metadata
        json["project"] = [
            "name": "EchoelSync Project",
            "duration": duration,
            "bpm": output.bpm,
            "frameRate": output.optimalFrameRate
        ]

        // Neuroscience metadata
        json["neuroscience"] = [
            "brainwave": output.dominantBrainwave.name,
            "entrainmentFrequency": output.entrainmentFrequency,
            "cognitiveEffect": output.cognitiveEffect,
            "pValue": output.dominantBrainwave.pValue,
            "effectSize": output.dominantBrainwave.effectSize,
            "reference": output.dominantBrainwave.reference
        ]

        // Sync points
        var syncPointsArray: [[String: Any]] = []
        for point in syncPoints {
            syncPointsArray.append([
                "timestamp": point.timestamp,
                "intensity": point.intensity,
                "cutType": point.cutType.rawValue,
                "colorTemperature": point.colorTemperature,
                "brightness": point.brightness,
                "brainwave": point.brainwave,
                "description": point.description
            ])
        }
        json["syncPoints"] = syncPointsArray

        // Convert to JSON string
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "{}"
    }

    // MARK: - Helpers

    /// Format time as SMPTE timecode
    private static func formatTimecode(_ seconds: Double, frameRate: Float) -> String {
        let totalFrames = Int(seconds * Double(frameRate))
        let frames = totalFrames % Int(frameRate)
        let totalSeconds = totalFrames / Int(frameRate)
        let secs = totalSeconds % 60
        let mins = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600

        return String(format: "%02d:%02d:%02d:%02d", hours, mins, secs, frames)
    }

    // MARK: - File Writing

    /// Save export to file
    public static func saveToFile(content: String, filename: String) throws {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
