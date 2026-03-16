#if canImport(AVFoundation)
import Foundation
import AVFoundation
import os

/// Registers and hosts the Echoelmusic AUv3 plugin from the standalone app
///
/// In standalone mode, the app can load its own AUv3 plugin internally
/// or make it available for other hosts (GarageBand, Logic, AUM, etc.)
/// via the system Audio Component registry.
@MainActor
public final class AUv3Host {

    private static let auLog = OSLog(
        subsystem: "com.echoelmusic.app.auv3",
        category: "Host"
    )

    /// Audio component description matching Info.plist registration
    public static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,          // aufx
        componentSubType: fourCharCode("echl"),
        componentManufacturer: fourCharCode("Echo"),
        componentFlags: 0,
        componentFlagsMask: 0
    )

    /// Register the AUv3 component for in-process hosting
    public static func register() {
        AUAudioUnit.registerSubclass(
            EchoelmusicAudioUnit.self,
            as: componentDescription,
            name: "Echoelmusic: Bio-Reactive Processor",
            version: 10000
        )
        os_log(.info, log: auLog, "AUv3 component registered for in-process hosting")
    }

    /// Instantiate the audio unit for standalone use
    public static func instantiate() async throws -> EchoelmusicAudioUnit {
        let audioUnit = try EchoelmusicAudioUnit(
            componentDescription: componentDescription,
            options: []
        )
        os_log(.info, log: auLog, "AUv3 instantiated for standalone use")
        return audioUnit
    }

    // MARK: - Helpers

    private static func fourCharCode(_ string: String) -> UInt32 {
        var code: UInt32 = 0
        for (index, char) in string.utf8.enumerated() where index < 4 {
            code = code << 8 | UInt32(char)
        }
        // Pad with spaces if less than 4 characters
        let remaining = 4 - min(string.utf8.count, 4)
        for _ in 0..<remaining {
            code = code << 8 | UInt32(UInt8(ascii: " "))
        }
        return code
    }
}
#endif
