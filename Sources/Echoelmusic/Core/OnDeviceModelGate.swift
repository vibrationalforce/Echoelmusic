import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Why the on-device model can or cannot answer right now, one case per reason
/// (GMMW AI-3). Every caller asks the gate for this instead of reading the
/// framework itself, so "is the model there?" has exactly ONE reader (#416).
public enum OnDeviceModelStatus: Sendable, Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceOff
    case modelNotReady
    case osTooOld
    case frameworkAbsent

    /// One plain sentence per case, for a refusal the player can act on.
    /// Deliberately no "AI" wording — that copy is founder-gated (AI-8).
    public var sentence: String {
        switch self {
        case .available:
            return String(localized: "The on-device model is ready.")
        case .deviceNotEligible:
            return String(localized: "This device cannot run the on-device model.")
        case .appleIntelligenceOff:
            return String(localized: "Turn on Apple Intelligence in Settings to use this.")
        case .modelNotReady:
            return String(localized: "The on-device model is still downloading. Try again later.")
        case .osTooOld:
            return String(localized: "This needs iOS 26 or later.")
        case .frameworkAbsent:
            return String(localized: "This build has no on-device model.")
        }
    }
}

/// Single chokepoint deciding whether the on-device LLM features may run.
///
/// The privacy rule lives here, in one place: Echoel's promise is that
/// biometrics stay on the device, so the bio→music "director" is only ever
/// allowed to run against Apple's **on-device** system model. When that model is
/// unavailable, every AI feature turns OFF — it must never silently fall back to
/// Private Cloud Compute or any third-party provider. Callers that want a working
/// experience on iOS 18 (or when the model is absent) use the deterministic,
/// no-LLM `BioDirectionFallback` instead.
public enum OnDeviceModelGate {

    /// The ONE read of the framework's availability in `Sources/` (AI-3).
    /// Reasons are matched with `if case` rather than an exhaustive `switch`,
    /// so a reason the SDK adds later lands on `.modelNotReady` instead of
    /// breaking the build.
    public static var status: OnDeviceModelStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let availability = SystemLanguageModel.default.availability
            if case .available = availability { return .available }
            if case .unavailable(.deviceNotEligible) = availability { return .deviceNotEligible }
            if case .unavailable(.appleIntelligenceNotEnabled) = availability { return .appleIntelligenceOff }
            return .modelNotReady
        }
        return .osTooOld
        #else
        return .frameworkAbsent
        #endif
    }

    /// True only when Apple's on-device system language model is present and ready.
    public static var isOnDeviceLLMAvailable: Bool { status == .available }
}
