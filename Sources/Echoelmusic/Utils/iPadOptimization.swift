import Foundation
import UIKit

/// iPad-specific optimizations and feature detection
///
/// **Purpose:** Leverage iPad's larger screen and more powerful hardware
///
/// **Optimizations:**
/// - Higher particle counts (more screen space)
/// - Higher quality defaults (more powerful chips)
/// - Larger audio buffers (better for multi-channel)
/// - Split-view and multitasking support
///
/// **Usage:**
/// ```swift
/// let iPadOpt = iPadOptimization.shared
///
/// if iPadOpt.isiPad {
///     particleCount = iPadOpt.recommendedParticleCount
///     quality = iPadOpt.recommendedQuality
/// }
/// ```
@MainActor
public class iPadOptimization: ObservableObject {

    // MARK: - Singleton

    public static let shared = iPadOptimization()

    // MARK: - Published State

    /// Whether running on iPad
    @Published public private(set) var isiPad: Bool = false

    /// Whether running on iPad Pro
    @Published public private(set) var isiPadPro: Bool = false

    /// Current device model (if iPad)
    @Published public private(set) var iPadModel: iPadModel = .unknown

    /// Whether currently in Split View mode
    @Published public private(set) var isInSplitView: Bool = false

    /// Whether currently in Slide Over mode
    @Published public private(set) var isInSlideOver: Bool = false

    // MARK: - Screen Info

    /// Screen size in points
    public var screenSize: CGSize {
        UIScreen.main.bounds.size
    }

    /// Screen scale factor
    public var screenScale: CGFloat {
        UIScreen.main.scale
    }

    /// Whether using external display
    public var hasExternalDisplay: Bool {
        UIScreen.screens.count > 1
    }

    // MARK: - Initialization

    private init() {
        detectDevice()
        setupMultitaskingObserver()

        if isiPad {
            print("[iPad Optimization] ✅ iPad detected")
            print("   Model: \(iPadModel.rawValue)")
            print("   Screen: \(screenSize.width)x\(screenSize.height) @ \(screenScale)x")
            print("   Pro Model: \(isiPadPro ? "YES" : "NO")")
        }
    }

    // MARK: - Device Detection

    private func detectDevice() {
        isiPad = UIDevice.current.userInterfaceIdiom == .pad

        guard isiPad else { return }

        // Detect iPad model
        iPadModel = detectiPadModel()
        isiPadPro = iPadModel.isPro
    }

    private func detectiPadModel() -> iPadModel {
        let modelIdentifier = HardwareCapability.shared.deviceModel

        // iPad Pro models
        if modelIdentifier.contains("iPad13,") || // iPad Pro 12.9" (5th/6th gen)
           modelIdentifier.contains("iPad14,") || // iPad Pro 11" (4th gen)
           modelIdentifier.contains("iPad8,") ||  // iPad Pro 11" (3rd gen)
           modelIdentifier.contains("iPad7,") {   // iPad Pro 10.5"
            return .pro
        }

        // iPad Air models
        if modelIdentifier.contains("iPad13,16") || // iPad Air (5th gen)
           modelIdentifier.contains("iPad13,17") || // iPad Air (5th gen)
           modelIdentifier.contains("iPad11,")  {   // iPad Air (4th gen)
            return .air
        }

        // iPad Mini models
        if modelIdentifier.contains("iPad14,1") || // iPad Mini (6th gen)
           modelIdentifier.contains("iPad14,2") || // iPad Mini (6th gen)
           modelIdentifier.contains("iPad11,1") || // iPad Mini (5th gen)
           modelIdentifier.contains("iPad11,2") {  // iPad Mini (5th gen)
            return .mini
        }

        // Standard iPad
        return .standard
    }

    // MARK: - Multitasking Detection

    private func setupMultitaskingObserver() {
        guard isiPad else { return }

        // Monitor for window size changes (indicates Split View/Slide Over)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMultitaskingState()
        }
    }

    private func updateMultitaskingState() {
        guard isiPad else { return }

        // Get main window bounds
        let windowWidth = UIScreen.main.bounds.width

        // Detect Split View (less than full screen width)
        isInSplitView = windowWidth < screenSize.width * 0.9

        // Detect Slide Over (very narrow)
        isInSlideOver = windowWidth < 400

        if isInSplitView {
            print("[iPad Optimization] Split View detected: \(windowWidth)pt wide")
        }
    }

    // MARK: - Optimization Recommendations

    /// Recommended particle count for iPad
    public var recommendedParticleCount: Int {
        guard isiPad else {
            return HardwareCapability.shared.maxParticleCount
        }

        if isInSlideOver {
            // Slide Over: reduce particles
            return 500
        } else if isInSplitView {
            // Split View: moderate particles
            return 1500
        } else if isiPadPro {
            // Full screen iPad Pro: maximum particles
            return 4000
        } else {
            // Full screen standard iPad: high particles
            return 2500
        }
    }

    /// Recommended quality for iPad
    public var recommendedQuality: AdaptiveQuality {
        guard isiPad else {
            return AdaptiveQuality.fromHardware(HardwareCapability.shared)
        }

        if isInSlideOver {
            return .medium  // Conserve resources in Slide Over
        } else if isInSplitView {
            return .high    // High quality in Split View
        } else if isiPadPro {
            return .ultra   // Maximum quality on iPad Pro
        } else {
            return .high    // High quality on standard iPad
        }
    }

    /// Recommended audio buffer size for iPad
    public var recommendedAudioBufferSize: AVAudioFrameCount {
        guard isiPad else {
            return HardwareCapability.shared.recommendedAudioBufferSize()
        }

        // iPad has more powerful audio hardware, can handle larger buffers
        if isiPadPro {
            return 1024  // Larger buffer for multi-channel on Pro
        } else {
            return 512   // Standard buffer
        }
    }

    /// Recommended FFT size for iPad
    public var recommendedFFTSize: Int {
        guard isiPad else {
            return HardwareCapability.shared.recommendedFFTSize
        }

        // iPad can handle larger FFT for better frequency resolution
        if isiPadPro {
            return 8192  // Very high resolution
        } else {
            return 4096  // High resolution
        }
    }

    /// Whether to enable advanced features
    public var shouldEnableAdvancedFeatures: Bool {
        guard isiPad else { return false }

        // Enable advanced features on iPad Pro in full screen
        return isiPadPro && !isInSplitView && !isInSlideOver
    }

    // MARK: - UI Recommendations

    /// Recommended column count for grid layouts
    public var recommendedGridColumns: Int {
        guard isiPad else { return 2 }

        if isInSlideOver {
            return 1  // Single column in Slide Over
        } else if isInSplitView {
            return 2  // Two columns in Split View
        } else {
            return 3  // Three columns in full screen
        }
    }

    /// Recommended spacing for UI elements
    public var recommendedSpacing: CGFloat {
        guard isiPad else { return 12.0 }

        if isInSlideOver {
            return 8.0   // Compact spacing
        } else if isInSplitView {
            return 16.0  // Normal spacing
        } else {
            return 24.0  // Generous spacing
        }
    }

    /// Recommended font size multiplier
    public var fontSizeMultiplier: CGFloat {
        guard isiPad else { return 1.0 }

        if isInSlideOver {
            return 0.9   // Smaller text in Slide Over
        } else if isInSplitView {
            return 1.0   // Normal text in Split View
        } else {
            return 1.2   // Larger text in full screen
        }
    }

    // MARK: - Statistics

    public var description: String {
        guard isiPad else {
            return "[iPad Optimization] Not running on iPad"
        }

        return """
        [iPad Optimization]
        Model: \(iPadModel.rawValue)
        Pro Model: \(isiPadPro ? "YES" : "NO")
        Screen: \(String(format: "%.0f", screenSize.width))x\(String(format: "%.0f", screenSize.height)) @ \(screenScale)x
        Multitasking: \(isInSplitView ? "Split View" : isInSlideOver ? "Slide Over" : "Full Screen")
        External Display: \(hasExternalDisplay ? "YES" : "NO")

        Recommendations:
        - Particles: \(recommendedParticleCount)
        - Quality: \(recommendedQuality.level.rawValue)
        - Audio Buffer: \(recommendedAudioBufferSize) frames
        - FFT Size: \(recommendedFFTSize)
        - Grid Columns: \(recommendedGridColumns)
        - Spacing: \(String(format: "%.0f", recommendedSpacing))pt
        - Font Multiplier: \(String(format: "%.1f", fontSizeMultiplier))x
        """
    }
}

// MARK: - Supporting Types

public enum iPadModel: String {
    case pro = "iPad Pro"
    case air = "iPad Air"
    case mini = "iPad Mini"
    case standard = "iPad"
    case unknown = "Unknown"

    var isPro: Bool {
        return self == .pro
    }

    var displaySize: String {
        switch self {
        case .pro:
            return "11\" or 12.9\""
        case .air:
            return "10.9\""
        case .mini:
            return "8.3\""
        case .standard:
            return "10.2\""
        case .unknown:
            return "Unknown"
        }
    }
}
