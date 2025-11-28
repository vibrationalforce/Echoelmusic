//
//  LocalizationExtensions.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  FUTURE-PROOF LOCALIZATION SYSTEM
//  Connects LocalizationManager to SwiftUI with zero friction
//

import SwiftUI

// MARK: - Property Wrapper for Easy Localization

/// Property wrapper that automatically localizes strings
/// Usage: @Localized("welcome") var welcomeText
@propertyWrapper
struct Localized: DynamicProperty {
    @StateObject private var manager = LocalizationManager.shared

    private let key: String
    private let arguments: [CVarArg]

    init(_ key: String, _ arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }

    var wrappedValue: String {
        if arguments.isEmpty {
            return manager.translate(key)
        } else {
            return String(format: manager.translate(key), arguments: arguments)
        }
    }
}

// MARK: - View Extension for Localization

extension View {
    /// Apply localized accessibility label
    func localizedAccessibilityLabel(_ key: String) -> some View {
        self.accessibilityLabel(LocalizationManager.shared.translate(key))
    }

    /// Apply localized accessibility hint
    func localizedAccessibilityHint(_ key: String) -> some View {
        self.accessibilityHint(LocalizationManager.shared.translate(key))
    }
}

// MARK: - Text Extension for Localization

extension Text {
    /// Create localized text
    init(localized key: String) {
        self.init(LocalizationManager.shared.translate(key))
    }

    /// Create localized text with arguments
    init(localized key: String, _ arguments: CVarArg...) {
        let format = LocalizationManager.shared.translate(key)
        self.init(String(format: format, arguments: arguments))
    }
}

// MARK: - String Extension for Localization

extension String {
    /// Localize this string key
    var localized: String {
        LocalizationManager.shared.translate(self)
    }

    /// Localize with arguments
    func localized(_ arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.translate(self)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Comprehensive Translation Keys

/// Centralized translation keys for type-safe localization
enum L10nKey {
    // MARK: - General UI
    enum General: String {
        case welcome = "welcome"
        case ok = "ok"
        case cancel = "cancel"
        case save = "save"
        case delete = "delete"
        case edit = "edit"
        case done = "done"
        case close = "close"
        case settings = "settings"
        case back = "back"
        case next = "next"
        case skip = "skip"
        case continue_ = "continue"
        case loading = "loading"
        case error = "error"
        case success = "success"
        case retry = "retry"
        case search = "search"
        case filter = "filter"
        case sort = "sort"

        var localized: String {
            LocalizationManager.shared.translate(rawValue)
        }
    }

    // MARK: - Navigation
    enum Navigation: String {
        case daw = "daw"
        case video = "video"
        case lighting = "lighting"
        case eoelwork = "eoelwork"
        case settings = "settings"

        var localized: String {
            LocalizationManager.shared.translate(rawValue)
        }
    }

    // MARK: - Audio/DAW
    enum Audio: String {
        case play = "audio.play"
        case pause = "audio.pause"
        case stop = "audio.stop"
        case record = "audio.record"
        case rewind = "audio.rewind"
        case fastForward = "audio.fastForward"
        case mute = "audio.mute"
        case solo = "audio.solo"
        case volume = "audio.volume"
        case pan = "audio.pan"
        case track = "audio.track"
        case addTrack = "audio.addTrack"
        case mixer = "audio.mixer"
        case instruments = "audio.instruments"
        case effects = "audio.effects"
        case tempo = "audio.tempo"
        case timeSignature = "audio.timeSignature"

        var localized: String {
            LocalizationManager.shared.translate(rawValue)
        }
    }

    // MARK: - Biofeedback
    enum Bio: String {
        case heartRate = "bio.heartRate"
        case hrv = "bio.hrv"
        case coherence = "bio.coherence"
        case breathing = "bio.breathing"
        case stress = "bio.stress"
        case relaxation = "bio.relaxation"
        case meditation = "bio.meditation"
        case flow = "bio.flow"
        case arousal = "bio.arousal"
        case valence = "bio.valence"

        var localized: String {
            LocalizationManager.shared.translate(rawValue)
        }
    }

    // MARK: - Safety
    enum Safety: String {
        case photosensitivityWarning = "safety.photosensitivity.warning"
        case hearingProtection = "safety.hearing.protection"
        case binauralWarning = "safety.binaural.warning"
        case emergencyStop = "safety.emergency.stop"
        case reduce Motion = "safety.reduceMotion"
        case doNotUseIf = "safety.doNotUseIf"
        case stopImmediately = "safety.stopImmediately"
        case medicalDisclaimer = "safety.medicalDisclaimer"
        case iAcknowledge = "safety.iAcknowledge"
        case iDecline = "safety.iDecline"

        var localized: String {
            LocalizationManager.shared.translate(rawValue)
        }
    }

    // MARK: - Monetization
    enum Monetization: String {
        case unlockPro = "monetization.unlockPro"
        case subscribe = "monetization.subscribe"
        case restore = "monetization.restore"
        case freeTrial = "monetization.freeTrial"
        case proPlan = "monetization.proPlan"
        case premiumPlan = "monetization.premiumPlan"
        case perMonth = "monetization.perMonth"
        case perYear = "monetization.perYear"
        case lifetime = "monetization.lifetime"

        var localized: String {
            LocalizationManager.shared.translate(rawValue)
        }
    }

    // MARK: - Onboarding
    enum Onboarding: String {
        case welcomeTitle = "onboarding.welcome.title"
        case welcomeMessage = "onboarding.welcome.message"
        case featureBiofeedback = "onboarding.feature.biofeedback"
        case featureInstruments = "onboarding.feature.instruments"
        case featureEffects = "onboarding.feature.effects"
        case permissionMicrophone = "onboarding.permission.microphone"
        case permissionCamera = "onboarding.permission.camera"
        case permissionHealth = "onboarding.permission.health"
        case getStarted = "onboarding.getStarted"

        var localized: String {
            LocalizationManager.shared.translate(rawValue)
        }
    }

    // MARK: - Errors
    enum Error: String {
        case generic = "error.generic"
        case network = "error.network"
        case permission = "error.permission"
        case fileNotFound = "error.fileNotFound"
        case invalidInput = "error.invalidInput"
        case timeout = "error.timeout"

        var localized: String {
            LocalizationManager.shared.translate(rawValue)
        }
    }
}

// MARK: - Environment Key for Localization

private struct LocalizationManagerKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localizationManager: LocalizationManager {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }
}

// MARK: - Localized Modifier

struct LocalizedModifier: ViewModifier {
    @StateObject private var manager = LocalizationManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.localizationManager, manager)
            .environment(\.layoutDirection, manager.isRTL ? .rightToLeft : .leftToLeft)
    }
}

extension View {
    /// Apply localization environment
    func withLocalization() -> some View {
        self.modifier(LocalizedModifier())
    }
}

// MARK: - Pluralization Helper

extension LocalizationManager {
    /// Get pluralized string
    /// Example: pluralized("track", count: 5) -> "5 tracks"
    func pluralized(_ key: String, count: Int) -> String {
        let pluralKey = count == 1 ? "\(key).singular" : "\(key).plural"
        let format = translate(pluralKey)
        return String(format: format, count)
    }
}

// MARK: - Date/Time Localization Helpers

extension Date {
    /// Localized string representation
    func localizedString(dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .none) -> String {
        return LocalizationManager.shared.formatDate(self, style: dateStyle, timeStyle: timeStyle)
    }

    /// Localized relative time (e.g., "2 hours ago")
    func localizedRelativeString() -> String {
        return LocalizationManager.shared.formatRelativeTime(self)
    }
}

// MARK: - Number Localization Helpers

extension Int {
    /// Localized number string
    var localizedString: String {
        LocalizationManager.shared.formatNumber(Double(self))
    }
}

extension Double {
    /// Localized number string
    var localizedString: String {
        LocalizationManager.shared.formatNumber(self)
    }

    /// Localized percentage string
    var localizedPercentage: String {
        LocalizationManager.shared.formatPercentage(self)
    }

    /// Localized currency string
    func localizedCurrency(code: String = "USD") -> String {
        LocalizationManager.shared.formatCurrency(self, currencyCode: code)
    }
}

// MARK: - Usage Examples (Comment Block)

/*

 USAGE EXAMPLES - FUTURE-PROOF LOCALIZATION
 ===========================================

 1. Simple Text Localization:

    Text(localized: "welcome")
    Text("welcome".localized)
    Text(L10nKey.General.welcome.localized)

 2. Text with Arguments:

    Text(localized: "greeting", userName)
    Text("tracks.count".localized(trackCount))

 3. Property Wrapper:

    struct MyView: View {
        @Localized("welcome") var welcomeText

        var body: some View {
            Text(welcomeText)
        }
    }

 4. Buttons with Localization:

    Button(L10nKey.General.save.localized) {
        saveAction()
    }

 5. Accessibility:

    Image(systemName: "play.fill")
        .localizedAccessibilityLabel("audio.play")

 6. Lists/Pickers:

    Picker(L10nKey.Audio.tempo.localized, selection: $tempo) {
        ForEach(tempos) { tempo in
            Text("\(tempo)").tag(tempo)
        }
    }

 7. Navigation:

    .navigationTitle(L10nKey.Navigation.daw.localized)

 8. Numbers/Dates:

    Text("\(count.localizedString) tracks")
    Text(date.localizedRelativeString())
    Text(price.localizedCurrency(code: "USD"))

 9. Pluralization:

    let text = LocalizationManager.shared.pluralized("track", count: trackCount)
    // count = 1: "1 track"
    // count = 5: "5 tracks"

 10. RTL Support (Automatic):

    HStack {
        Image(systemName: "arrow.right")
        Text("Next")
    }
    .withLocalization() // Automatically flips for RTL

 */
