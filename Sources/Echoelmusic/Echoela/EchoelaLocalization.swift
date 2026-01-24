/**
 * EchoelaLocalization.swift
 * Echoelmusic - Multi-Language Support for Echoela
 *
 * Provides localized content for Echoela in 20 languages:
 * EN, DE, JA, ES, FR, ZH, KO, PT, IT, RU, AR, HI,
 * NL, DA, SV, NO, PL, TR, TH, VI
 *
 * Market Research Based Selection:
 * - Tier 1: USA, China, Japan, UK, Germany, France (major revenue)
 * - Tier 2: Netherlands, Denmark (63% iPhone!), Sweden, Norway (wealthy, high penetration)
 * - Tier 3: Poland (Eastern Europe), Turkey (large market), Thailand, Vietnam (growth)
 * - Tier 4: Arabic (48% YoY growth), Hindi (23% YoY growth)
 *
 * Features:
 * - Automatic language detection from device locale
 * - User language preference override
 * - Input language detection
 * - Localized guidance content
 * - RTL support for Arabic and Hebrew
 *
 * Created: 2026-01-24
 * Updated: 2026-01-24 - Added 8 strategic languages based on market research
 */

import Foundation
import NaturalLanguage

// MARK: - Supported Languages

/// All languages supported by Echoela (20 languages)
public enum EchoelaLanguage: String, CaseIterable, Codable {
    // Tier 1: Major Revenue Markets
    case english = "en"
    case german = "de"
    case japanese = "ja"
    case spanish = "es"
    case french = "fr"
    case chinese = "zh"

    // Tier 2: High Penetration Markets
    case korean = "ko"
    case portuguese = "pt"
    case italian = "it"
    case dutch = "nl"       // Netherlands - wealthy, high Apple penetration
    case danish = "da"      // Denmark - 63% iPhone market share!
    case swedish = "sv"     // Sweden - wealthy Scandinavia
    case norwegian = "no"   // Norway - very wealthy

    // Tier 3: Growth Markets
    case russian = "ru"
    case polish = "pl"      // Poland - largest Eastern Europe
    case turkish = "tr"     // Turkey - large growing market
    case thai = "th"        // Thailand - Southeast Asia leader
    case vietnamese = "vi"  // Vietnam - 23% YoY growth

    // Tier 4: High Growth Emerging
    case arabic = "ar"      // Saudi/UAE - 48% YoY growth
    case hindi = "hi"       // India - 23% YoY growth

    // Tier 5: Strategic Expansion (NEW - 15 Languages)
    case indonesian = "id"  // Indonesia - Largest SE Asian market
    case malay = "ms"       // Malaysia/Singapore
    case finnish = "fi"     // Finland - Nordic completion
    case greek = "el"       // Greece - Mediterranean
    case czech = "cs"       // Czech Republic - Central Europe
    case romanian = "ro"    // Romania - Eastern Europe
    case hungarian = "hu"   // Hungary - Central Europe
    case ukrainian = "uk"   // Ukraine - Eastern Europe
    case hebrew = "he"      // Israel - Middle East, RTL
    case filipino = "tl"    // Philippines - Large market
    case swahili = "sw"     // East Africa - Growing market
    case bengali = "bn"     // Bangladesh/India - 230M+ speakers
    case tamil = "ta"       // South India/Sri Lanka - 80M+ speakers
    case telugu = "te"      // South India - 80M+ speakers
    case marathi = "mr"     // India - 90M+ speakers

    /// Display name in native language
    public var nativeName: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        case .japanese: return "日本語"
        case .spanish: return "Español"
        case .french: return "Français"
        case .chinese: return "中文"
        case .korean: return "한국어"
        case .portuguese: return "Português"
        case .italian: return "Italiano"
        case .dutch: return "Nederlands"
        case .danish: return "Dansk"
        case .swedish: return "Svenska"
        case .norwegian: return "Norsk"
        case .russian: return "Русский"
        case .polish: return "Polski"
        case .turkish: return "Türkçe"
        case .thai: return "ไทย"
        case .vietnamese: return "Tiếng Việt"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        // Tier 5: Strategic Expansion
        case .indonesian: return "Bahasa Indonesia"
        case .malay: return "Bahasa Melayu"
        case .finnish: return "Suomi"
        case .greek: return "Ελληνικά"
        case .czech: return "Čeština"
        case .romanian: return "Română"
        case .hungarian: return "Magyar"
        case .ukrainian: return "Українська"
        case .hebrew: return "עברית"
        case .filipino: return "Filipino"
        case .swahili: return "Kiswahili"
        case .bengali: return "বাংলা"
        case .tamil: return "தமிழ்"
        case .telugu: return "తెలుగు"
        case .marathi: return "मराठी"
        }
    }

    /// Flag emoji for UI display
    public var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .german: return "🇩🇪"
        case .japanese: return "🇯🇵"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .chinese: return "🇨🇳"
        case .korean: return "🇰🇷"
        case .portuguese: return "🇧🇷"
        case .italian: return "🇮🇹"
        case .dutch: return "🇳🇱"
        case .danish: return "🇩🇰"
        case .swedish: return "🇸🇪"
        case .norwegian: return "🇳🇴"
        case .russian: return "🇷🇺"
        case .polish: return "🇵🇱"
        case .turkish: return "🇹🇷"
        case .thai: return "🇹🇭"
        case .vietnamese: return "🇻🇳"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        // Tier 5: Strategic Expansion
        case .indonesian: return "🇮🇩"
        case .malay: return "🇲🇾"
        case .finnish: return "🇫🇮"
        case .greek: return "🇬🇷"
        case .czech: return "🇨🇿"
        case .romanian: return "🇷🇴"
        case .hungarian: return "🇭🇺"
        case .ukrainian: return "🇺🇦"
        case .hebrew: return "🇮🇱"
        case .filipino: return "🇵🇭"
        case .swahili: return "🇰🇪"
        case .bengali: return "🇧🇩"
        case .tamil: return "🇱🇰"
        case .telugu: return "🇮🇳"
        case .marathi: return "🇮🇳"
        }
    }

    /// Whether language is RTL (right-to-left)
    public var isRTL: Bool {
        self == .arabic || self == .hebrew
    }

    /// Market tier for prioritization
    public var marketTier: Int {
        switch self {
        case .english, .german, .japanese, .spanish, .french, .chinese:
            return 1  // Major revenue
        case .korean, .portuguese, .italian, .dutch, .danish, .swedish, .norwegian:
            return 2  // High penetration
        case .russian, .polish, .turkish, .thai, .vietnamese:
            return 3  // Growth markets
        case .arabic, .hindi:
            return 4  // High growth emerging
        case .indonesian, .malay, .finnish, .greek, .czech, .romanian, .hungarian,
             .ukrainian, .hebrew, .filipino, .swahili, .bengali, .tamil, .telugu, .marathi:
            return 5  // Strategic expansion
        }
    }

    /// BCP 47 language tag for speech synthesis
    public var speechLanguageCode: String {
        switch self {
        case .english: return "en-US"
        case .german: return "de-DE"
        case .japanese: return "ja-JP"
        case .spanish: return "es-ES"
        case .french: return "fr-FR"
        case .chinese: return "zh-CN"
        case .korean: return "ko-KR"
        case .portuguese: return "pt-BR"
        case .italian: return "it-IT"
        case .dutch: return "nl-NL"
        case .danish: return "da-DK"
        case .swedish: return "sv-SE"
        case .norwegian: return "nb-NO"
        case .russian: return "ru-RU"
        case .polish: return "pl-PL"
        case .turkish: return "tr-TR"
        case .thai: return "th-TH"
        case .vietnamese: return "vi-VN"
        case .arabic: return "ar-SA"
        case .hindi: return "hi-IN"
        // Tier 5: Strategic Expansion
        case .indonesian: return "id-ID"
        case .malay: return "ms-MY"
        case .finnish: return "fi-FI"
        case .greek: return "el-GR"
        case .czech: return "cs-CZ"
        case .romanian: return "ro-RO"
        case .hungarian: return "hu-HU"
        case .ukrainian: return "uk-UA"
        case .hebrew: return "he-IL"
        case .filipino: return "fil-PH"
        case .swahili: return "sw-KE"
        case .bengali: return "bn-BD"
        case .tamil: return "ta-IN"
        case .telugu: return "te-IN"
        case .marathi: return "mr-IN"
        }
    }

    /// Initialize from locale identifier
    public init(localeIdentifier: String) {
        let code = String(localeIdentifier.prefix(2)).lowercased()
        self = EchoelaLanguage(rawValue: code) ?? .english
    }

    /// Initialize from device locale
    public static var deviceLanguage: EchoelaLanguage {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return EchoelaLanguage(rawValue: code) ?? .english
    }
}

// MARK: - Localization Manager

/// Manages Echoela's multi-language support
@MainActor
public final class EchoelaLocalizationManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelaLocalizationManager()

    // MARK: - Published State

    /// Current active language
    @Published public var currentLanguage: EchoelaLanguage {
        didSet {
            saveLanguagePreference()
            log.info("✨ Echoela: Language changed to \(currentLanguage.nativeName)", category: .accessibility)
        }
    }

    /// Whether to auto-detect input language
    @Published public var autoDetectInput: Bool = true

    /// Last detected input language
    @Published public var detectedInputLanguage: EchoelaLanguage?

    // MARK: - Private

    private let log = EchoelLogger.shared
    private let languageRecognizer = NLLanguageRecognizer()
    private let preferenceKey = "echoela_language_preference"

    // MARK: - Initialization

    private init() {
        // Load saved preference or use device language
        if let saved = UserDefaults.standard.string(forKey: preferenceKey),
           let language = EchoelaLanguage(rawValue: saved) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = EchoelaLanguage.deviceLanguage
        }

        log.info("✨ Echoela: Localization initialized - \(currentLanguage.nativeName)", category: .accessibility)
    }

    // MARK: - Language Detection

    /// Detect language of input text
    public func detectLanguage(of text: String) -> EchoelaLanguage {
        languageRecognizer.reset()
        languageRecognizer.processString(text)

        guard let dominantLanguage = languageRecognizer.dominantLanguage else {
            return currentLanguage
        }

        let detected = EchoelaLanguage(rawValue: dominantLanguage.rawValue) ?? currentLanguage
        detectedInputLanguage = detected

        return detected
    }

    /// Get language probabilities for input text
    public func languageProbabilities(for text: String) -> [(EchoelaLanguage, Double)] {
        languageRecognizer.reset()
        languageRecognizer.processString(text)

        let hypotheses = languageRecognizer.languageHypotheses(withMaximum: 5)

        return hypotheses.compactMap { (nlLanguage, probability) in
            guard let language = EchoelaLanguage(rawValue: nlLanguage.rawValue) else {
                return nil
            }
            return (language, probability)
        }.sorted { $0.1 > $1.1 }
    }

    // MARK: - Localized Strings

    /// Get localized string for key
    public func string(for key: LocalizationKey) -> String {
        return key.localized(for: currentLanguage)
    }

    /// Get localized string with language override
    public func string(for key: LocalizationKey, language: EchoelaLanguage) -> String {
        return key.localized(for: language)
    }

    // MARK: - Persistence

    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: preferenceKey)
    }

    /// Reset to device language
    public func resetToDeviceLanguage() {
        currentLanguage = EchoelaLanguage.deviceLanguage
    }
}

// MARK: - Localization Keys

/// All localizable strings for Echoela
public enum LocalizationKey: String, CaseIterable {

    // MARK: - Welcome
    case welcomeTitle
    case welcomeDescription
    case welcomeOptional
    case welcomeOptionalDesc
    case welcomeLearnStyle
    case welcomeLearnStyleDesc
    case welcomeNoRush
    case welcomeNoRushDesc
    case welcomeAskAnytime
    case welcomeAskAnytimeDesc

    // MARK: - General Help
    case generalHelpTitle
    case generalHelpDescription
    case generalHelpTip
    case generalHelpTipDetail

    // MARK: - Audio Basics
    case audioBasicsTitle
    case audioBasicsDescription
    case audioBasicsHint
    case audioBasicsHintDetail
    case audioWhatYouHear
    case audioWhatYouHearDesc
    case audioVolume
    case audioVolumeDesc
    case audioSoundTypes
    case audioSoundTypesDesc
    case audioNoWrong
    case audioNoWrongDesc

    // MARK: - Biofeedback
    case biofeedbackTitle
    case biofeedbackDescription
    case biofeedbackDisclaimer
    case biofeedbackDisclaimerDetail
    case biofeedbackWhat
    case biofeedbackWhatDesc
    case biofeedbackHeartRate
    case biofeedbackHeartRateDesc
    case biofeedbackHRV
    case biofeedbackHRVDesc
    case biofeedbackBreathing
    case biofeedbackBreathingDesc
    case biofeedbackTouch
    case biofeedbackTouchDesc
    case biofeedbackOptional
    case biofeedbackOptionalDesc

    // MARK: - Visualizer
    case visualizerTitle
    case visualizerDescription
    case visualizerHint
    case visualizerHintDetail
    case visualizerWhatYouSee
    case visualizerWhatYouSeeDesc
    case visualizerColors
    case visualizerColorsDesc
    case visualizerMotion
    case visualizerMotionDesc
    case visualizerAccessibility
    case visualizerAccessibilityDesc

    // MARK: - Presets
    case presetsTitle
    case presetsDescription
    case presetsHint
    case presetsHintDetail
    case presetsWhat
    case presetsWhatDesc
    case presetsBrowsing
    case presetsBrowsingDesc
    case presetsSwitching
    case presetsSwitchingDesc
    case presetsCreating
    case presetsCreatingDesc

    // MARK: - Recording
    case recordingTitle
    case recordingDescription
    case recordingPrivacy
    case recordingPrivacyDetail
    case recordingWhat
    case recordingWhatDesc
    case recordingStart
    case recordingStartDesc
    case recordingFind
    case recordingFindDesc
    case recordingStorage
    case recordingStorageDesc

    // MARK: - Streaming
    case streamingTitle
    case streamingDescription
    case streamingAdvanced
    case streamingAdvancedDetail
    case streamingWhat
    case streamingWhatDesc
    case streamingWhere
    case streamingWhereDesc
    case streamingPrivacy
    case streamingPrivacyDesc

    // MARK: - Accessibility
    case accessibilityTitle
    case accessibilityDescription
    case accessibilityHint
    case accessibilityHintDetail
    case accessibilityVision
    case accessibilityVisionDesc
    case accessibilityHearing
    case accessibilityHearingDesc
    case accessibilityMotor
    case accessibilityMotorDesc
    case accessibilityCognitive
    case accessibilityCognitiveDesc
    case accessibilitySensory
    case accessibilitySensoryDesc

    // MARK: - Settings
    case settingsTitle
    case settingsDescription
    case settingsHint
    case settingsHintDetail
    case settingsFind
    case settingsFindDesc
    case settingsCategories
    case settingsCategoriesDesc
    case settingsEchoela
    case settingsEchoelaDesc

    // MARK: - Collaboration
    case collaborationTitle
    case collaborationDescription
    case collaborationConsent
    case collaborationConsentDetail
    case collaborationWhat
    case collaborationWhatDesc
    case collaborationJoin
    case collaborationJoinDesc
    case collaborationPrivacy
    case collaborationPrivacyDesc

    // MARK: - Wellness
    case wellnessTitle
    case wellnessDescription
    case wellnessDisclaimer
    case wellnessDisclaimerDetail
    case wellnessWhat
    case wellnessWhatDesc
    case wellnessBreathing
    case wellnessBreathingDesc
    case wellnessCoherence
    case wellnessCoherenceDesc
    case wellnessDisclaimerFull
    case wellnessDisclaimerFullDesc

    // MARK: - Help Offers
    case helpHesitation1
    case helpHesitation2
    case helpHesitation3
    case helpRepeatedErrors1
    case helpRepeatedErrors2
    case helpRepeatedErrors3
    case helpFirstTime1
    case helpFirstTime2
    case helpFirstTime3
    case helpUserRequested

    // MARK: - UI Elements
    case dismiss
    case learnMore
    case gotIt
    case showMe
    case skip
    case next
    case previous
    case close
    case help
    case settings

    /// Get localized string for this key
    public func localized(for language: EchoelaLanguage) -> String {
        return EchoelaStrings.string(for: self, language: language)
    }
}

// MARK: - Localized Strings Database

/// Contains all localized strings for all languages
public struct EchoelaStrings {

    /// Get localized string for key and language
    public static func string(for key: LocalizationKey, language: EchoelaLanguage) -> String {
        switch language {
        // Tier 1: Major Revenue Markets
        case .english: return english[key] ?? key.rawValue
        case .german: return german[key] ?? english[key] ?? key.rawValue
        case .japanese: return japanese[key] ?? english[key] ?? key.rawValue
        case .spanish: return spanish[key] ?? english[key] ?? key.rawValue
        case .french: return french[key] ?? english[key] ?? key.rawValue
        case .chinese: return chinese[key] ?? english[key] ?? key.rawValue
        // Tier 2: High Penetration Markets
        case .korean: return korean[key] ?? english[key] ?? key.rawValue
        case .portuguese: return portuguese[key] ?? english[key] ?? key.rawValue
        case .italian: return italian[key] ?? english[key] ?? key.rawValue
        case .dutch: return dutch[key] ?? english[key] ?? key.rawValue
        case .danish: return danish[key] ?? english[key] ?? key.rawValue
        case .swedish: return swedish[key] ?? english[key] ?? key.rawValue
        case .norwegian: return norwegian[key] ?? english[key] ?? key.rawValue
        // Tier 3: Growth Markets
        case .russian: return russian[key] ?? english[key] ?? key.rawValue
        case .polish: return polish[key] ?? english[key] ?? key.rawValue
        case .turkish: return turkish[key] ?? english[key] ?? key.rawValue
        case .thai: return thai[key] ?? english[key] ?? key.rawValue
        case .vietnamese: return vietnamese[key] ?? english[key] ?? key.rawValue
        // Tier 4: High Growth Emerging
        case .arabic: return arabic[key] ?? english[key] ?? key.rawValue
        case .hindi: return hindi[key] ?? english[key] ?? key.rawValue
        // Tier 5: Strategic Expansion
        case .indonesian: return indonesian[key] ?? english[key] ?? key.rawValue
        case .malay: return malay[key] ?? english[key] ?? key.rawValue
        case .finnish: return finnish[key] ?? english[key] ?? key.rawValue
        case .greek: return greek[key] ?? english[key] ?? key.rawValue
        case .czech: return czech[key] ?? english[key] ?? key.rawValue
        case .romanian: return romanian[key] ?? english[key] ?? key.rawValue
        case .hungarian: return hungarian[key] ?? english[key] ?? key.rawValue
        case .ukrainian: return ukrainian[key] ?? english[key] ?? key.rawValue
        case .hebrew: return hebrew[key] ?? english[key] ?? key.rawValue
        case .filipino: return filipino[key] ?? english[key] ?? key.rawValue
        case .swahili: return swahili[key] ?? english[key] ?? key.rawValue
        case .bengali: return bengali[key] ?? english[key] ?? key.rawValue
        case .tamil: return tamil[key] ?? english[key] ?? key.rawValue
        case .telugu: return telugu[key] ?? english[key] ?? key.rawValue
        case .marathi: return marathi[key] ?? english[key] ?? key.rawValue
        }
    }

    // MARK: - English (Base)

    private static let english: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Hello, I'm Echoela",
        .welcomeDescription: "I'm here to help you explore Echoelmusic. I'll offer gentle guidance when you might need it, but you're always in control.",
        .welcomeOptional: "I'm Optional",
        .welcomeOptionalDesc: "You can turn me off in Settings anytime. I won't be offended.",
        .welcomeLearnStyle: "I Learn Your Style",
        .welcomeLearnStyleDesc: "As you use the app, I'll give you less guidance when you're confident, and more when things are new.",
        .welcomeNoRush: "I Never Rush You",
        .welcomeNoRushDesc: "There are no timers, no scores, no pressure. Take all the time you need.",
        .welcomeAskAnytime: "Ask Anytime",
        .welcomeAskAnytimeDesc: "If you ever need help, just tap the Echoela button or look for the sparkle icon.",

        // General Help
        .generalHelpTitle: "How Can I Help?",
        .generalHelpDescription: "Choose a topic to learn more about it. You can always come back here.",
        .generalHelpTip: "Tip: Topics you've explored are marked with a checkmark.",
        .generalHelpTipDetail: "But you can revisit them anytime. There's no limit to how many times you can read something.",

        // Audio Basics
        .audioBasicsTitle: "Audio Basics",
        .audioBasicsDescription: "Learn how sound works in Echoelmusic.",
        .audioBasicsHint: "You don't need music experience to use this app.",
        .audioBasicsHintDetail: "Echoelmusic is designed for everyone. The app creates sounds for you based on your input.",
        .audioWhatYouHear: "What You Hear",
        .audioWhatYouHearDesc: "Echoelmusic creates sounds in real-time. These sounds change based on what you do — touching the screen, your heart rate, your voice, or your movements.",
        .audioVolume: "Volume Control",
        .audioVolumeDesc: "Use your device's volume buttons to adjust how loud the sound is. You can also find a volume slider in the app.",
        .audioSoundTypes: "Sound Types",
        .audioSoundTypesDesc: "The app can make many kinds of sounds: gentle tones, rhythms, ambient textures, and more. Presets give you different sound styles to try.",
        .audioNoWrong: "No Wrong Sounds",
        .audioNoWrongDesc: "There's no wrong way to make sound here. Whatever you create is valid. This is about exploration, not perfection.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Learn how your body connects to the music.",
        .biofeedbackDisclaimer: "Important: This is art, not medicine.",
        .biofeedbackDisclaimerDetail: "Echoelmusic is a creative tool. It doesn't diagnose, treat, or cure any condition. Always consult healthcare professionals for medical concerns.",
        .biofeedbackWhat: "What is Biofeedback?",
        .biofeedbackWhatDesc: "Your body constantly produces signals — your heart beats, you breathe, your muscles move. Biofeedback means using these signals as input.",
        .biofeedbackHeartRate: "Heart Rate",
        .biofeedbackHeartRateDesc: "If you have an Apple Watch or compatible device, Echoelmusic can respond to your heart rate. Faster heartbeat might make faster rhythms.",
        .biofeedbackHRV: "HRV (Heart Rate Variability)",
        .biofeedbackHRVDesc: "HRV measures the tiny changes between heartbeats. Higher HRV often indicates relaxation. The app can use this to create calmer sounds.",
        .biofeedbackBreathing: "Breathing",
        .biofeedbackBreathingDesc: "Some features respond to your breathing pattern. The app might detect this from your heart rate changes or from sounds you make.",
        .biofeedbackTouch: "Touch & Gesture",
        .biofeedbackTouchDesc: "No sensors needed! You can also control sound by touching the screen or moving in front of the camera.",
        .biofeedbackOptional: "All Input is Optional",
        .biofeedbackOptionalDesc: "You don't need any sensors to enjoy Echoelmusic. The app works great with just touch input.",

        // Visualizer
        .visualizerTitle: "Visualizer",
        .visualizerDescription: "Understand the visual feedback in the app.",
        .visualizerHint: "Visuals respond to sound and your input.",
        .visualizerHintDetail: "The patterns you see change with the music and your biometric data. It's like seeing what you feel.",
        .visualizerWhatYouSee: "What You See",
        .visualizerWhatYouSeeDesc: "Echoelmusic shows visual patterns that move and change. These visuals respond to the sound and your input.",
        .visualizerColors: "Colors",
        .visualizerColorsDesc: "Colors often represent different things — calm blues for relaxation, warm oranges for energy. But there's no strict rule.",
        .visualizerMotion: "Motion",
        .visualizerMotionDesc: "The speed and style of motion relates to the music tempo and your bio-signals.",
        .visualizerAccessibility: "Accessibility",
        .visualizerAccessibilityDesc: "If you find the visuals overwhelming, you can enable 'Calm Colors' or 'Reduce Animations' in Settings.",

        // Presets
        .presetsTitle: "Presets",
        .presetsDescription: "Quick ways to change the entire experience.",
        .presetsHint: "Presets are starting points, not limits.",
        .presetsHintDetail: "Each preset configures sound and visuals for a particular mood or activity. You can modify them or create your own.",
        .presetsWhat: "What is a Preset?",
        .presetsWhatDesc: "A preset is a saved configuration. It sets up sound, visuals, and response settings all at once.",
        .presetsBrowsing: "Browsing Presets",
        .presetsBrowsingDesc: "You can browse presets by category: Meditation, Creative, Energetic, and more. Tap any preset to try it.",
        .presetsSwitching: "Switching Presets",
        .presetsSwitchingDesc: "You can switch presets anytime. The transition is smooth — you won't hear a sudden change.",
        .presetsCreating: "Creating Your Own",
        .presetsCreatingDesc: "Once you're comfortable, you can save your own presets with your favorite settings.",

        // Recording
        .recordingTitle: "Recording",
        .recordingDescription: "Capture and save your sessions.",
        .recordingPrivacy: "Recordings stay on your device unless you share them.",
        .recordingPrivacyDetail: "Your privacy matters. Nothing is uploaded without your explicit action.",
        .recordingWhat: "What Gets Recorded?",
        .recordingWhatDesc: "You can record the audio you create, the visuals, or both together as a video.",
        .recordingStart: "Starting a Recording",
        .recordingStartDesc: "Tap the record button (circle icon) to start. Tap again to stop.",
        .recordingFind: "Finding Your Recordings",
        .recordingFindDesc: "All recordings are saved in the Library section. You can play them back, share them, or delete them.",
        .recordingStorage: "Storage",
        .recordingStorageDesc: "Recordings use storage space on your device. You can delete old recordings if you need more space.",

        // Streaming
        .streamingTitle: "Streaming",
        .streamingDescription: "Share your experience live with others.",
        .streamingAdvanced: "Streaming is advanced and completely optional.",
        .streamingAdvancedDetail: "If you never stream, that's perfectly fine. Many people use Echoelmusic privately.",
        .streamingWhat: "What is Streaming?",
        .streamingWhatDesc: "Streaming means broadcasting your audio-visual experience live over the internet. Others can watch in real-time.",
        .streamingWhere: "Where to Stream",
        .streamingWhereDesc: "Echoelmusic can stream to YouTube, Twitch, and other platforms. You'll need an account on those services.",
        .streamingPrivacy: "Privacy Considerations",
        .streamingPrivacyDesc: "When streaming, others can see what you create. Bio-data display is optional — you control what's visible.",

        // Accessibility
        .accessibilityTitle: "Accessibility",
        .accessibilityDescription: "Customize the app to work for you.",
        .accessibilityHint: "Echoelmusic is designed for everyone.",
        .accessibilityHintDetail: "We've built in many options to make the app usable regardless of vision, hearing, motor, or cognitive differences.",
        .accessibilityVision: "Vision",
        .accessibilityVisionDesc: "VoiceOver is fully supported. You can also enable high contrast, larger text, and color adjustments.",
        .accessibilityHearing: "Hearing",
        .accessibilityHearingDesc: "Visual beat indicators can show rhythm. Haptic feedback lets you feel the beat. Bass-enhanced mode makes vibrations stronger.",
        .accessibilityMotor: "Motor",
        .accessibilityMotorDesc: "Voice control lets you navigate hands-free. Switch access and dwell selection are supported. Target sizes can be enlarged.",
        .accessibilityCognitive: "Cognitive",
        .accessibilityCognitiveDesc: "Simplified UI mode reduces complexity. Focus mode hides non-essential elements. Memory aids can remind you of recent actions.",
        .accessibilitySensory: "Sensory Sensitivity",
        .accessibilitySensoryDesc: "Reduce motion, reduce brightness, and calm color options help if you're sensitive to visual stimulation.",

        // Settings
        .settingsTitle: "Settings",
        .settingsDescription: "Configure the app to your preferences.",
        .settingsHint: "You can always change settings later.",
        .settingsHintDetail: "Nothing is permanent. Experiment freely — you can reset to defaults anytime.",
        .settingsFind: "Finding Settings",
        .settingsFindDesc: "Tap the gear icon to open Settings. It's usually in the top corner of the main screen.",
        .settingsCategories: "Categories",
        .settingsCategoriesDesc: "Settings are grouped: Audio, Visual, Bio-Input, Accessibility, Privacy, and Echoela (that's me!).",
        .settingsEchoela: "Echoela Settings",
        .settingsEchoelaDesc: "You can adjust how much guidance I give, or turn me off entirely. No hard feelings.",

        // Collaboration
        .collaborationTitle: "Collaboration",
        .collaborationDescription: "Create together with others.",
        .collaborationConsent: "Collaboration is optional and consent-based.",
        .collaborationConsentDetail: "You choose whether to join sessions. Your data is only shared if you explicitly allow it.",
        .collaborationWhat: "What is Collaboration?",
        .collaborationWhatDesc: "Multiple people can connect their Echoelmusic apps and create together. Your bio-signals can influence each other's sounds.",
        .collaborationJoin: "Joining a Session",
        .collaborationJoinDesc: "Someone shares a session code or link. You enter it to join. Both parties must agree.",
        .collaborationPrivacy: "Privacy",
        .collaborationPrivacyDesc: "You control what you share. You can participate with just sound input, without sharing bio-data.",

        // Wellness
        .wellnessTitle: "Wellness Features",
        .wellnessDescription: "Understand the wellness-related features.",
        .wellnessDisclaimer: "Important: This is not medical advice.",
        .wellnessDisclaimerDetail: "Echoelmusic wellness features are for general wellbeing and creativity. They are not medical devices and don't diagnose or treat conditions.",
        .wellnessWhat: "What Wellness Means Here",
        .wellnessWhatDesc: "We use 'wellness' to mean general relaxation, creativity, and self-exploration. Not medical treatment.",
        .wellnessBreathing: "Breathing Exercises",
        .wellnessBreathingDesc: "The app includes optional guided breathing. These are general relaxation techniques, not therapy.",
        .wellnessCoherence: "Coherence Display",
        .wellnessCoherenceDesc: "The app may show 'coherence' based on your HRV. This is a visualization tool, not a medical metric.",
        .wellnessDisclaimerFull: "Disclaimer",
        .wellnessDisclaimerFullDesc: "If you have health concerns, please consult a healthcare professional. Echoelmusic is a creative tool, not a substitute for medical care.",

        // Help Offers
        .helpHesitation1: "Take your time. Would you like some guidance?",
        .helpHesitation2: "No rush. I'm here if you need a hint.",
        .helpHesitation3: "Whenever you're ready. Need any help?",
        .helpRepeatedErrors1: "That can be tricky. Would you like me to explain?",
        .helpRepeatedErrors2: "Let me help clarify this for you.",
        .helpRepeatedErrors3: "This part takes practice. Want some tips?",
        .helpFirstTime1: "This is new. Would you like a quick overview?",
        .helpFirstTime2: "First time here? I can show you around.",
        .helpFirstTime3: "Let me introduce you to this feature.",
        .helpUserRequested: "How can I help you?",

        // UI Elements
        .dismiss: "Dismiss",
        .learnMore: "Learn More",
        .gotIt: "Got It",
        .showMe: "Show Me",
        .skip: "Skip",
        .next: "Next",
        .previous: "Previous",
        .close: "Close",
        .help: "Help",
        .settings: "Settings"
    ]

    // MARK: - German

    private static let german: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Hallo, ich bin Echoela",
        .welcomeDescription: "Ich bin hier, um dir beim Erkunden von Echoelmusic zu helfen. Ich biete sanfte Anleitung, wenn du sie brauchst, aber du behältst immer die Kontrolle.",
        .welcomeOptional: "Ich bin optional",
        .welcomeOptionalDesc: "Du kannst mich jederzeit in den Einstellungen ausschalten. Ich nehme es nicht persönlich.",
        .welcomeLearnStyle: "Ich lerne deinen Stil",
        .welcomeLearnStyleDesc: "Während du die App nutzt, gebe ich dir weniger Anleitung wenn du sicher bist, und mehr bei neuen Dingen.",
        .welcomeNoRush: "Ich hetze dich nie",
        .welcomeNoRushDesc: "Es gibt keine Timer, keine Punkte, keinen Druck. Nimm dir alle Zeit die du brauchst.",
        .welcomeAskAnytime: "Frag jederzeit",
        .welcomeAskAnytimeDesc: "Wenn du Hilfe brauchst, tippe einfach auf den Echoela-Button oder suche nach dem Funkeln-Symbol.",

        // General Help
        .generalHelpTitle: "Wie kann ich helfen?",
        .generalHelpDescription: "Wähle ein Thema um mehr darüber zu erfahren. Du kannst jederzeit hierher zurückkehren.",
        .generalHelpTip: "Tipp: Themen die du erkundet hast sind mit einem Häkchen markiert.",
        .generalHelpTipDetail: "Aber du kannst sie jederzeit erneut besuchen. Es gibt kein Limit wie oft du etwas lesen kannst.",

        // Audio Basics
        .audioBasicsTitle: "Audio-Grundlagen",
        .audioBasicsDescription: "Lerne wie Sound in Echoelmusic funktioniert.",
        .audioBasicsHint: "Du brauchst keine Musikerfahrung um diese App zu nutzen.",
        .audioBasicsHintDetail: "Echoelmusic ist für jeden gemacht. Die App erstellt Sounds basierend auf deiner Eingabe.",
        .audioWhatYouHear: "Was du hörst",
        .audioWhatYouHearDesc: "Echoelmusic erstellt Sounds in Echtzeit. Diese Sounds ändern sich basierend auf dem was du tust — Bildschirmberührung, Herzfrequenz, Stimme oder Bewegungen.",
        .audioVolume: "Lautstärkeregelung",
        .audioVolumeDesc: "Nutze die Lautstärketasten deines Geräts um die Lautstärke anzupassen. Du findest auch einen Lautstärkeregler in der App.",
        .audioSoundTypes: "Sound-Arten",
        .audioSoundTypesDesc: "Die App kann viele Arten von Sounds erzeugen: sanfte Töne, Rhythmen, Ambiente-Texturen und mehr. Presets geben dir verschiedene Sound-Stile zum Ausprobieren.",
        .audioNoWrong: "Keine falschen Sounds",
        .audioNoWrongDesc: "Es gibt keinen falschen Weg hier Sound zu machen. Was auch immer du erschaffst ist gültig. Es geht um Erkundung, nicht Perfektion.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Lerne wie dein Körper mit der Musik verbunden ist.",
        .biofeedbackDisclaimer: "Wichtig: Das ist Kunst, keine Medizin.",
        .biofeedbackDisclaimerDetail: "Echoelmusic ist ein kreatives Werkzeug. Es diagnostiziert, behandelt oder heilt keine Erkrankungen. Konsultiere immer Fachleute bei medizinischen Fragen.",
        .biofeedbackWhat: "Was ist Biofeedback?",
        .biofeedbackWhatDesc: "Dein Körper produziert ständig Signale — dein Herz schlägt, du atmest, deine Muskeln bewegen sich. Biofeedback bedeutet diese Signale als Eingabe zu nutzen.",
        .biofeedbackHeartRate: "Herzfrequenz",
        .biofeedbackHeartRateDesc: "Mit einer Apple Watch oder kompatiblem Gerät kann Echoelmusic auf deine Herzfrequenz reagieren. Schnellerer Herzschlag könnte schnellere Rhythmen erzeugen.",
        .biofeedbackHRV: "HRV (Herzratenvariabilität)",
        .biofeedbackHRVDesc: "HRV misst die kleinen Veränderungen zwischen Herzschlägen. Höhere HRV zeigt oft Entspannung an. Die App kann dies nutzen um ruhigere Sounds zu erzeugen.",
        .biofeedbackBreathing: "Atmung",
        .biofeedbackBreathingDesc: "Einige Funktionen reagieren auf dein Atemmuster. Die App erkennt dies möglicherweise aus Herzfrequenzänderungen oder Geräuschen die du machst.",
        .biofeedbackTouch: "Touch & Geste",
        .biofeedbackTouchDesc: "Keine Sensoren nötig! Du kannst Sound auch durch Bildschirmberührung oder Bewegung vor der Kamera steuern.",
        .biofeedbackOptional: "Alle Eingaben sind optional",
        .biofeedbackOptionalDesc: "Du brauchst keine Sensoren um Echoelmusic zu genießen. Die App funktioniert großartig nur mit Touch-Eingabe.",

        // Help Offers
        .helpHesitation1: "Nimm dir Zeit. Möchtest du etwas Anleitung?",
        .helpHesitation2: "Kein Stress. Ich bin hier wenn du einen Hinweis brauchst.",
        .helpHesitation3: "Wann immer du bereit bist. Brauchst du Hilfe?",
        .helpRepeatedErrors1: "Das kann knifflig sein. Soll ich es erklären?",
        .helpRepeatedErrors2: "Lass mich das für dich klären.",
        .helpRepeatedErrors3: "Dieser Teil braucht Übung. Möchtest du Tipps?",
        .helpFirstTime1: "Das ist neu. Möchtest du einen kurzen Überblick?",
        .helpFirstTime2: "Erstes Mal hier? Ich kann dir alles zeigen.",
        .helpFirstTime3: "Lass mich dir diese Funktion vorstellen.",
        .helpUserRequested: "Wie kann ich dir helfen?",

        // UI Elements
        .dismiss: "Schließen",
        .learnMore: "Mehr erfahren",
        .gotIt: "Verstanden",
        .showMe: "Zeig mir",
        .skip: "Überspringen",
        .next: "Weiter",
        .previous: "Zurück",
        .close: "Schließen",
        .help: "Hilfe",
        .settings: "Einstellungen"
    ]

    // MARK: - Japanese

    private static let japanese: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "こんにちは、エコエラです",
        .welcomeDescription: "Echoelmusicを探索するお手伝いをします。必要な時に優しくガイダンスを提供しますが、あなたが常にコントロールできます。",
        .welcomeOptional: "オプションです",
        .welcomeOptionalDesc: "設定からいつでもオフにできます。気にしませんよ。",
        .welcomeLearnStyle: "あなたのスタイルを学びます",
        .welcomeLearnStyleDesc: "アプリを使うにつれて、自信がある時は少なく、新しいことには多くガイダンスを提供します。",
        .welcomeNoRush: "急かしません",
        .welcomeNoRushDesc: "タイマーもスコアもプレッシャーもありません。必要なだけ時間をかけてください。",
        .welcomeAskAnytime: "いつでも聞いてください",
        .welcomeAskAnytimeDesc: "ヘルプが必要な時は、エコエラボタンをタップするか、キラキラアイコンを探してください。",

        // General Help
        .generalHelpTitle: "何をお手伝いしましょうか？",
        .generalHelpDescription: "トピックを選んで詳しく学びましょう。いつでもここに戻れます。",
        .generalHelpTip: "ヒント：探索済みのトピックにはチェックマークが付きます。",
        .generalHelpTipDetail: "でもいつでも再訪問できます。何度読んでも制限はありません。",

        // Audio Basics
        .audioBasicsTitle: "オーディオの基本",
        .audioBasicsDescription: "Echoelmusicでの音の仕組みを学びましょう。",
        .audioBasicsHint: "このアプリを使うのに音楽経験は必要ありません。",
        .audioBasicsHintDetail: "Echoelmusicは誰でも使えるよう設計されています。アプリがあなたの入力に基づいて音を作成します。",
        .audioWhatYouHear: "聞こえるもの",
        .audioWhatYouHearDesc: "Echoelmusicはリアルタイムで音を作成します。これらの音は、画面タッチ、心拍数、声、動きに応じて変化します。",
        .audioVolume: "音量調整",
        .audioVolumeDesc: "デバイスの音量ボタンで音量を調整できます。アプリ内にも音量スライダーがあります。",
        .audioSoundTypes: "サウンドの種類",
        .audioSoundTypesDesc: "アプリは様々な種類の音を作れます：優しいトーン、リズム、アンビエントテクスチャなど。プリセットで異なるサウンドスタイルを試せます。",
        .audioNoWrong: "間違った音はありません",
        .audioNoWrongDesc: "ここでは音を作る間違った方法はありません。あなたが作るものは何でも有効です。完璧さではなく、探索が大切です。",

        // Biofeedback
        .biofeedbackTitle: "バイオフィードバック",
        .biofeedbackDescription: "体と音楽がどうつながるか学びましょう。",
        .biofeedbackDisclaimer: "重要：これはアートであり、医療ではありません。",
        .biofeedbackDisclaimerDetail: "Echoelmusicは創作ツールです。病気の診断、治療、治癒はしません。医療上の懸念は常に専門家にご相談ください。",
        .biofeedbackWhat: "バイオフィードバックとは？",
        .biofeedbackWhatDesc: "体は常に信号を出しています—心臓が鼓動し、呼吸し、筋肉が動きます。バイオフィードバックはこれらの信号を入力として使うことです。",
        .biofeedbackHeartRate: "心拍数",
        .biofeedbackHeartRateDesc: "Apple Watchや互換デバイスがあれば、Echoelmusicは心拍数に反応できます。速い心拍は速いリズムを生み出すかもしれません。",

        // Help Offers
        .helpHesitation1: "ゆっくりどうぞ。ガイダンスが必要ですか？",
        .helpHesitation2: "急ぎません。ヒントが必要なら言ってください。",
        .helpHesitation3: "準備ができたら。ヘルプが必要ですか？",
        .helpRepeatedErrors1: "難しいですよね。説明しましょうか？",
        .helpRepeatedErrors2: "明確にするお手伝いをしましょう。",
        .helpRepeatedErrors3: "この部分は練習が必要です。ヒントが欲しいですか？",
        .helpFirstTime1: "初めてですね。簡単な概要をお見せしましょうか？",
        .helpFirstTime2: "初めてここに来ましたか？案内しますよ。",
        .helpFirstTime3: "この機能を紹介させてください。",
        .helpUserRequested: "何をお手伝いしましょうか？",

        // UI Elements
        .dismiss: "閉じる",
        .learnMore: "詳しく見る",
        .gotIt: "わかりました",
        .showMe: "見せて",
        .skip: "スキップ",
        .next: "次へ",
        .previous: "前へ",
        .close: "閉じる",
        .help: "ヘルプ",
        .settings: "設定"
    ]

    // MARK: - Spanish

    private static let spanish: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Hola, soy Echoela",
        .welcomeDescription: "Estoy aquí para ayudarte a explorar Echoelmusic. Te ofreceré orientación gentil cuando la necesites, pero siempre tienes el control.",
        .welcomeOptional: "Soy opcional",
        .welcomeOptionalDesc: "Puedes desactivarme en Configuración en cualquier momento. No me ofenderé.",
        .welcomeLearnStyle: "Aprendo tu estilo",
        .welcomeLearnStyleDesc: "A medida que uses la app, te daré menos orientación cuando estés seguro, y más cuando algo sea nuevo.",
        .welcomeNoRush: "Nunca te apresuro",
        .welcomeNoRushDesc: "No hay temporizadores, ni puntuaciones, ni presión. Tómate todo el tiempo que necesites.",
        .welcomeAskAnytime: "Pregunta cuando quieras",
        .welcomeAskAnytimeDesc: "Si necesitas ayuda, solo toca el botón Echoela o busca el ícono de destello.",

        // General Help
        .generalHelpTitle: "¿Cómo puedo ayudarte?",
        .generalHelpDescription: "Elige un tema para aprender más. Siempre puedes volver aquí.",
        .generalHelpTip: "Consejo: Los temas que has explorado tienen una marca de verificación.",
        .generalHelpTipDetail: "Pero puedes revisitarlos cuando quieras. No hay límite de cuántas veces puedes leer algo.",

        // Audio Basics
        .audioBasicsTitle: "Básicos de Audio",
        .audioBasicsDescription: "Aprende cómo funciona el sonido en Echoelmusic.",
        .audioBasicsHint: "No necesitas experiencia musical para usar esta app.",
        .audioBasicsHintDetail: "Echoelmusic está diseñado para todos. La app crea sonidos basándose en tu entrada.",
        .audioWhatYouHear: "Lo que escuchas",
        .audioWhatYouHearDesc: "Echoelmusic crea sonidos en tiempo real. Estos sonidos cambian según lo que hagas — tocar la pantalla, tu ritmo cardíaco, tu voz o tus movimientos.",
        .audioVolume: "Control de volumen",
        .audioVolumeDesc: "Usa los botones de volumen de tu dispositivo para ajustar el volumen. También hay un control deslizante en la app.",
        .audioSoundTypes: "Tipos de sonido",
        .audioSoundTypesDesc: "La app puede crear muchos tipos de sonidos: tonos suaves, ritmos, texturas ambientales y más. Los presets te dan diferentes estilos de sonido para probar.",
        .audioNoWrong: "No hay sonidos incorrectos",
        .audioNoWrongDesc: "No hay forma incorrecta de hacer sonido aquí. Lo que crees es válido. Se trata de exploración, no de perfección.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Aprende cómo tu cuerpo se conecta con la música.",
        .biofeedbackDisclaimer: "Importante: Esto es arte, no medicina.",
        .biofeedbackDisclaimerDetail: "Echoelmusic es una herramienta creativa. No diagnostica, trata ni cura ninguna condición. Consulta siempre a profesionales de salud para preocupaciones médicas.",

        // Help Offers
        .helpHesitation1: "Tómate tu tiempo. ¿Te gustaría algo de orientación?",
        .helpHesitation2: "Sin prisa. Estoy aquí si necesitas una pista.",
        .helpHesitation3: "Cuando estés listo. ¿Necesitas ayuda?",
        .helpRepeatedErrors1: "Eso puede ser complicado. ¿Quieres que te explique?",
        .helpRepeatedErrors2: "Déjame ayudarte a aclarar esto.",
        .helpRepeatedErrors3: "Esta parte requiere práctica. ¿Quieres algunos consejos?",
        .helpFirstTime1: "Esto es nuevo. ¿Te gustaría una vista rápida?",
        .helpFirstTime2: "¿Primera vez aquí? Puedo mostrarte.",
        .helpFirstTime3: "Déjame presentarte esta función.",
        .helpUserRequested: "¿Cómo puedo ayudarte?",

        // UI Elements
        .dismiss: "Cerrar",
        .learnMore: "Más información",
        .gotIt: "Entendido",
        .showMe: "Muéstrame",
        .skip: "Omitir",
        .next: "Siguiente",
        .previous: "Anterior",
        .close: "Cerrar",
        .help: "Ayuda",
        .settings: "Configuración"
    ]

    // MARK: - French

    private static let french: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Bonjour, je suis Echoela",
        .welcomeDescription: "Je suis là pour vous aider à explorer Echoelmusic. Je vous offrirai des conseils doux quand vous en aurez besoin, mais vous gardez toujours le contrôle.",
        .welcomeOptional: "Je suis optionnel",
        .welcomeOptionalDesc: "Vous pouvez me désactiver dans les Paramètres à tout moment. Je ne serai pas vexé.",
        .welcomeLearnStyle: "J'apprends votre style",
        .welcomeLearnStyleDesc: "Au fur et à mesure que vous utilisez l'app, je vous donnerai moins de conseils quand vous êtes confiant, et plus quand les choses sont nouvelles.",
        .welcomeNoRush: "Je ne vous presse jamais",
        .welcomeNoRushDesc: "Il n'y a pas de chronomètre, pas de score, pas de pression. Prenez tout le temps dont vous avez besoin.",
        .welcomeAskAnytime: "Demandez à tout moment",
        .welcomeAskAnytimeDesc: "Si vous avez besoin d'aide, appuyez simplement sur le bouton Echoela ou cherchez l'icône étincelle.",

        // General Help
        .generalHelpTitle: "Comment puis-je vous aider ?",
        .generalHelpDescription: "Choisissez un sujet pour en savoir plus. Vous pouvez toujours revenir ici.",

        // Audio Basics
        .audioBasicsTitle: "Bases Audio",
        .audioBasicsDescription: "Apprenez comment le son fonctionne dans Echoelmusic.",
        .audioBasicsHint: "Vous n'avez pas besoin d'expérience musicale pour utiliser cette app.",
        .audioBasicsHintDetail: "Echoelmusic est conçu pour tout le monde. L'app crée des sons basés sur votre entrée.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Apprenez comment votre corps se connecte à la musique.",
        .biofeedbackDisclaimer: "Important : C'est de l'art, pas de la médecine.",
        .biofeedbackDisclaimerDetail: "Echoelmusic est un outil créatif. Il ne diagnostique, traite ni guérit aucune condition. Consultez toujours des professionnels de santé pour les questions médicales.",

        // Help Offers
        .helpHesitation1: "Prenez votre temps. Voulez-vous des conseils ?",
        .helpHesitation2: "Pas de précipitation. Je suis là si vous avez besoin d'un indice.",
        .helpHesitation3: "Quand vous êtes prêt. Besoin d'aide ?",
        .helpRepeatedErrors1: "Ça peut être délicat. Voulez-vous que j'explique ?",
        .helpRepeatedErrors2: "Laissez-moi vous aider à clarifier.",
        .helpRepeatedErrors3: "Cette partie demande de la pratique. Voulez-vous des conseils ?",
        .helpUserRequested: "Comment puis-je vous aider ?",

        // UI Elements
        .dismiss: "Fermer",
        .learnMore: "En savoir plus",
        .gotIt: "Compris",
        .showMe: "Montrez-moi",
        .skip: "Passer",
        .next: "Suivant",
        .previous: "Précédent",
        .close: "Fermer",
        .help: "Aide",
        .settings: "Paramètres"
    ]

    // MARK: - Chinese (Simplified)

    private static let chinese: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "你好，我是Echoela",
        .welcomeDescription: "我在这里帮助你探索Echoelmusic。当你需要时，我会提供温和的指导，但你始终掌控一切。",
        .welcomeOptional: "我是可选的",
        .welcomeOptionalDesc: "你可以随时在设置中关闭我。我不会介意的。",
        .welcomeLearnStyle: "我会学习你的风格",
        .welcomeLearnStyleDesc: "随着你使用应用，当你有信心时我会减少指导，当遇到新事物时会增加指导。",
        .welcomeNoRush: "我从不催促你",
        .welcomeNoRushDesc: "没有计时器，没有分数，没有压力。慢慢来。",
        .welcomeAskAnytime: "随时提问",
        .welcomeAskAnytimeDesc: "如果你需要帮助，只需点击Echoela按钮或寻找闪光图标。",

        // General Help
        .generalHelpTitle: "我能帮你什么？",
        .generalHelpDescription: "选择一个主题了解更多。你随时可以回到这里。",

        // Audio Basics
        .audioBasicsTitle: "音频基础",
        .audioBasicsDescription: "了解Echoelmusic中声音的工作原理。",
        .audioBasicsHint: "使用这个应用不需要音乐经验。",
        .audioBasicsHintDetail: "Echoelmusic为每个人设计。应用根据你的输入创建声音。",

        // Biofeedback
        .biofeedbackTitle: "生物反馈",
        .biofeedbackDescription: "了解你的身体如何与音乐连接。",
        .biofeedbackDisclaimer: "重要：这是艺术，不是医学。",
        .biofeedbackDisclaimerDetail: "Echoelmusic是创意工具。它不诊断、治疗或治愈任何疾病。医疗问题请咨询专业人士。",

        // Help Offers
        .helpHesitation1: "慢慢来。需要一些指导吗？",
        .helpHesitation2: "不着急。如果需要提示我在这里。",
        .helpHesitation3: "准备好了吗？需要帮助吗？",
        .helpRepeatedErrors1: "这可能有点棘手。要我解释一下吗？",
        .helpRepeatedErrors2: "让我帮你理清这个。",
        .helpRepeatedErrors3: "这部分需要练习。想要一些技巧吗？",
        .helpUserRequested: "我能帮你什么？",

        // UI Elements
        .dismiss: "关闭",
        .learnMore: "了解更多",
        .gotIt: "明白了",
        .showMe: "演示",
        .skip: "跳过",
        .next: "下一步",
        .previous: "上一步",
        .close: "关闭",
        .help: "帮助",
        .settings: "设置"
    ]

    // MARK: - Korean

    private static let korean: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "안녕하세요, 저는 에코엘라입니다",
        .welcomeDescription: "Echoelmusic을 탐색하는 것을 도와드리겠습니다. 필요할 때 부드러운 안내를 제공하지만, 항상 당신이 주도권을 가집니다.",
        .welcomeOptional: "저는 선택 사항입니다",
        .welcomeOptionalDesc: "설정에서 언제든지 저를 끌 수 있습니다. 기분 나빠하지 않을게요.",
        .welcomeLearnStyle: "당신의 스타일을 배웁니다",
        .welcomeLearnStyleDesc: "앱을 사용하면서 자신감이 있을 때는 안내를 줄이고, 새로운 것에는 더 많은 안내를 제공합니다.",
        .welcomeNoRush: "절대 서두르지 않습니다",
        .welcomeNoRushDesc: "타이머도, 점수도, 압박도 없습니다. 필요한 만큼 시간을 가지세요.",
        .welcomeAskAnytime: "언제든지 물어보세요",
        .welcomeAskAnytimeDesc: "도움이 필요하면 에코엘라 버튼을 탭하거나 반짝이는 아이콘을 찾으세요.",

        // General Help
        .generalHelpTitle: "어떻게 도와드릴까요?",
        .generalHelpDescription: "주제를 선택해서 자세히 알아보세요. 언제든지 여기로 돌아올 수 있습니다.",

        // Audio Basics
        .audioBasicsTitle: "오디오 기초",
        .audioBasicsDescription: "Echoelmusic에서 소리가 어떻게 작동하는지 배우세요.",
        .audioBasicsHint: "이 앱을 사용하는데 음악 경험이 필요하지 않습니다.",
        .audioBasicsHintDetail: "Echoelmusic은 모두를 위해 설계되었습니다. 앱이 당신의 입력을 기반으로 소리를 만듭니다.",

        // Biofeedback
        .biofeedbackTitle: "바이오피드백",
        .biofeedbackDescription: "당신의 몸이 음악과 어떻게 연결되는지 배우세요.",
        .biofeedbackDisclaimer: "중요: 이것은 예술이지, 의학이 아닙니다.",
        .biofeedbackDisclaimerDetail: "Echoelmusic은 창작 도구입니다. 어떤 질환도 진단, 치료, 치유하지 않습니다. 의료 문제는 항상 전문가와 상담하세요.",

        // Help Offers
        .helpHesitation1: "천천히 하세요. 안내가 필요하신가요?",
        .helpHesitation2: "서두르지 마세요. 힌트가 필요하면 여기 있습니다.",
        .helpHesitation3: "준비되셨나요? 도움이 필요하신가요?",
        .helpRepeatedErrors1: "까다로울 수 있어요. 설명해 드릴까요?",
        .helpRepeatedErrors2: "명확히 해드리겠습니다.",
        .helpRepeatedErrors3: "이 부분은 연습이 필요해요. 팁을 드릴까요?",
        .helpUserRequested: "어떻게 도와드릴까요?",

        // UI Elements
        .dismiss: "닫기",
        .learnMore: "더 알아보기",
        .gotIt: "알겠습니다",
        .showMe: "보여주세요",
        .skip: "건너뛰기",
        .next: "다음",
        .previous: "이전",
        .close: "닫기",
        .help: "도움말",
        .settings: "설정"
    ]

    // MARK: - Portuguese (Brazilian)

    private static let portuguese: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Olá, eu sou a Echoela",
        .welcomeDescription: "Estou aqui para ajudar você a explorar o Echoelmusic. Oferecerei orientação gentil quando você precisar, mas você sempre está no controle.",
        .welcomeOptional: "Sou opcional",
        .welcomeOptionalDesc: "Você pode me desativar nas Configurações a qualquer momento. Não vou ficar chateada.",
        .welcomeLearnStyle: "Aprendo seu estilo",
        .welcomeLearnStyleDesc: "Conforme você usa o app, darei menos orientação quando você estiver confiante, e mais quando as coisas forem novas.",
        .welcomeNoRush: "Nunca te apresso",
        .welcomeNoRushDesc: "Não há cronômetros, pontuações ou pressão. Leve o tempo que precisar.",
        .welcomeAskAnytime: "Pergunte a qualquer momento",
        .welcomeAskAnytimeDesc: "Se precisar de ajuda, basta tocar no botão Echoela ou procurar o ícone de brilho.",

        // General Help
        .generalHelpTitle: "Como posso ajudar?",
        .generalHelpDescription: "Escolha um tópico para saber mais. Você sempre pode voltar aqui.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Aprenda como seu corpo se conecta à música.",
        .biofeedbackDisclaimer: "Importante: Isso é arte, não medicina.",
        .biofeedbackDisclaimerDetail: "Echoelmusic é uma ferramenta criativa. Não diagnostica, trata ou cura nenhuma condição. Sempre consulte profissionais de saúde para questões médicas.",

        // Help Offers
        .helpHesitation1: "Leve seu tempo. Gostaria de alguma orientação?",
        .helpHesitation2: "Sem pressa. Estou aqui se precisar de uma dica.",
        .helpHesitation3: "Quando estiver pronto. Precisa de ajuda?",
        .helpUserRequested: "Como posso ajudar você?",

        // UI Elements
        .dismiss: "Dispensar",
        .learnMore: "Saiba mais",
        .gotIt: "Entendi",
        .showMe: "Mostre-me",
        .skip: "Pular",
        .next: "Próximo",
        .previous: "Anterior",
        .close: "Fechar",
        .help: "Ajuda",
        .settings: "Configurações"
    ]

    // MARK: - Italian

    private static let italian: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Ciao, sono Echoela",
        .welcomeDescription: "Sono qui per aiutarti a esplorare Echoelmusic. Ti offrirò una guida gentile quando ne avrai bisogno, ma sei sempre tu a controllare.",
        .welcomeOptional: "Sono opzionale",
        .welcomeOptionalDesc: "Puoi disattivarmi nelle Impostazioni in qualsiasi momento. Non mi offenderò.",
        .welcomeLearnStyle: "Imparo il tuo stile",
        .welcomeLearnStyleDesc: "Man mano che usi l'app, ti darò meno guida quando sei sicuro, e di più quando le cose sono nuove.",
        .welcomeNoRush: "Non ti metto mai fretta",
        .welcomeNoRushDesc: "Non ci sono timer, punteggi o pressioni. Prenditi tutto il tempo che ti serve.",
        .welcomeAskAnytime: "Chiedi quando vuoi",
        .welcomeAskAnytimeDesc: "Se hai bisogno di aiuto, tocca il pulsante Echoela o cerca l'icona scintillante.",

        // General Help
        .generalHelpTitle: "Come posso aiutarti?",
        .generalHelpDescription: "Scegli un argomento per saperne di più. Puoi sempre tornare qui.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Scopri come il tuo corpo si connette alla musica.",
        .biofeedbackDisclaimer: "Importante: Questa è arte, non medicina.",
        .biofeedbackDisclaimerDetail: "Echoelmusic è uno strumento creativo. Non diagnostica, tratta o cura alcuna condizione. Consulta sempre professionisti sanitari per questioni mediche.",

        // Help Offers
        .helpHesitation1: "Prenditi il tuo tempo. Vorresti qualche guida?",
        .helpHesitation2: "Nessuna fretta. Sono qui se hai bisogno di un suggerimento.",
        .helpHesitation3: "Quando sei pronto. Hai bisogno di aiuto?",
        .helpUserRequested: "Come posso aiutarti?",

        // UI Elements
        .dismiss: "Chiudi",
        .learnMore: "Scopri di più",
        .gotIt: "Capito",
        .showMe: "Mostrami",
        .skip: "Salta",
        .next: "Avanti",
        .previous: "Indietro",
        .close: "Chiudi",
        .help: "Aiuto",
        .settings: "Impostazioni"
    ]

    // MARK: - Russian

    private static let russian: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Привет, я Echoela",
        .welcomeDescription: "Я здесь, чтобы помочь вам исследовать Echoelmusic. Я буду мягко направлять вас, когда это нужно, но вы всегда контролируете ситуацию.",
        .welcomeOptional: "Я опциональна",
        .welcomeOptionalDesc: "Вы можете отключить меня в Настройках в любое время. Я не обижусь.",
        .welcomeLearnStyle: "Я учусь вашему стилю",
        .welcomeLearnStyleDesc: "По мере использования приложения я буду давать меньше подсказок, когда вы уверены, и больше, когда что-то новое.",
        .welcomeNoRush: "Я никогда не тороплю вас",
        .welcomeNoRushDesc: "Нет таймеров, очков или давления. Не торопитесь.",
        .welcomeAskAnytime: "Спрашивайте когда угодно",
        .welcomeAskAnytimeDesc: "Если нужна помощь, просто нажмите кнопку Echoela или найдите значок искры.",

        // General Help
        .generalHelpTitle: "Чем я могу помочь?",
        .generalHelpDescription: "Выберите тему, чтобы узнать больше. Вы всегда можете вернуться сюда.",

        // Biofeedback
        .biofeedbackTitle: "Биофидбек",
        .biofeedbackDescription: "Узнайте, как ваше тело связано с музыкой.",
        .biofeedbackDisclaimer: "Важно: Это искусство, а не медицина.",
        .biofeedbackDisclaimerDetail: "Echoelmusic - творческий инструмент. Он не диагностирует, не лечит и не излечивает никакие заболевания. По медицинским вопросам всегда консультируйтесь со специалистами.",

        // Help Offers
        .helpHesitation1: "Не торопитесь. Хотите немного подсказок?",
        .helpHesitation2: "Без спешки. Я здесь, если нужна подсказка.",
        .helpHesitation3: "Когда будете готовы. Нужна помощь?",
        .helpUserRequested: "Чем я могу помочь?",

        // UI Elements
        .dismiss: "Закрыть",
        .learnMore: "Подробнее",
        .gotIt: "Понятно",
        .showMe: "Покажите",
        .skip: "Пропустить",
        .next: "Далее",
        .previous: "Назад",
        .close: "Закрыть",
        .help: "Помощь",
        .settings: "Настройки"
    ]

    // MARK: - Arabic

    private static let arabic: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "مرحباً، أنا إيكويلا",
        .welcomeDescription: "أنا هنا لمساعدتك في استكشاف Echoelmusic. سأقدم إرشادات لطيفة عندما تحتاجها، لكنك دائماً المتحكم.",
        .welcomeOptional: "أنا اختيارية",
        .welcomeOptionalDesc: "يمكنك إيقافي في الإعدادات في أي وقت. لن أنزعج.",
        .welcomeLearnStyle: "أتعلم أسلوبك",
        .welcomeLearnStyleDesc: "كلما استخدمت التطبيق، سأقدم إرشادات أقل عندما تكون واثقاً، والمزيد عندما تكون الأمور جديدة.",
        .welcomeNoRush: "لا أستعجلك أبداً",
        .welcomeNoRushDesc: "لا توجد مؤقتات أو نقاط أو ضغط. خذ كل الوقت الذي تحتاجه.",
        .welcomeAskAnytime: "اسأل في أي وقت",
        .welcomeAskAnytimeDesc: "إذا احتجت مساعدة، فقط اضغط على زر إيكويلا أو ابحث عن أيقونة البريق.",

        // General Help
        .generalHelpTitle: "كيف يمكنني مساعدتك؟",
        .generalHelpDescription: "اختر موضوعاً لمعرفة المزيد. يمكنك العودة هنا دائماً.",

        // Biofeedback
        .biofeedbackTitle: "الارتجاع الحيوي",
        .biofeedbackDescription: "تعلم كيف يتصل جسمك بالموسيقى.",
        .biofeedbackDisclaimer: "مهم: هذا فن، ليس طب.",
        .biofeedbackDisclaimerDetail: "Echoelmusic أداة إبداعية. لا يشخص أو يعالج أو يشفي أي حالة. استشر دائماً متخصصي الرعاية الصحية للمخاوف الطبية.",

        // Help Offers
        .helpHesitation1: "خذ وقتك. هل تريد بعض الإرشادات؟",
        .helpHesitation2: "لا تستعجل. أنا هنا إذا احتجت تلميحاً.",
        .helpHesitation3: "عندما تكون جاهزاً. هل تحتاج مساعدة؟",
        .helpUserRequested: "كيف يمكنني مساعدتك؟",

        // UI Elements
        .dismiss: "إغلاق",
        .learnMore: "اعرف المزيد",
        .gotIt: "فهمت",
        .showMe: "أرني",
        .skip: "تخطي",
        .next: "التالي",
        .previous: "السابق",
        .close: "إغلاق",
        .help: "مساعدة",
        .settings: "الإعدادات"
    ]

    // MARK: - Hindi

    private static let hindi: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "नमस्ते, मैं इकोएला हूं",
        .welcomeDescription: "मैं आपको Echoelmusic खोजने में मदद करने के लिए यहां हूं। जब आपको जरूरत होगी तब मैं कोमल मार्गदर्शन दूंगी, लेकिन आप हमेशा नियंत्रण में हैं।",
        .welcomeOptional: "मैं वैकल्पिक हूं",
        .welcomeOptionalDesc: "आप मुझे सेटिंग्स में कभी भी बंद कर सकते हैं। मुझे बुरा नहीं लगेगा।",
        .welcomeLearnStyle: "मैं आपकी शैली सीखती हूं",
        .welcomeLearnStyleDesc: "जैसे-जैसे आप ऐप का उपयोग करेंगे, जब आप आत्मविश्वासी होंगे तब कम मार्गदर्शन दूंगी, और जब चीजें नई हों तब अधिक।",
        .welcomeNoRush: "मैं कभी जल्दी नहीं करती",
        .welcomeNoRushDesc: "कोई टाइमर नहीं, कोई स्कोर नहीं, कोई दबाव नहीं। जितना समय चाहिए लीजिए।",
        .welcomeAskAnytime: "कभी भी पूछें",
        .welcomeAskAnytimeDesc: "अगर मदद चाहिए, बस इकोएला बटन टैप करें या चमक आइकन खोजें।",

        // General Help
        .generalHelpTitle: "मैं कैसे मदद कर सकती हूं?",
        .generalHelpDescription: "अधिक जानने के लिए एक विषय चुनें। आप कभी भी यहां वापस आ सकते हैं।",

        // Biofeedback
        .biofeedbackTitle: "बायोफीडबैक",
        .biofeedbackDescription: "जानें कि आपका शरीर संगीत से कैसे जुड़ता है।",
        .biofeedbackDisclaimer: "महत्वपूर्ण: यह कला है, चिकित्सा नहीं।",
        .biofeedbackDisclaimerDetail: "Echoelmusic एक रचनात्मक उपकरण है। यह किसी भी स्थिति का निदान, उपचार या इलाज नहीं करता। चिकित्सा संबंधी चिंताओं के लिए हमेशा स्वास्थ्य पेशेवरों से परामर्श करें।",

        // Help Offers
        .helpHesitation1: "अपना समय लें। क्या आप कुछ मार्गदर्शन चाहेंगे?",
        .helpHesitation2: "कोई जल्दी नहीं। अगर संकेत चाहिए तो मैं यहां हूं।",
        .helpHesitation3: "जब आप तैयार हों। मदद चाहिए?",
        .helpUserRequested: "मैं आपकी कैसे मदद कर सकती हूं?",

        // UI Elements
        .dismiss: "खारिज करें",
        .learnMore: "और जानें",
        .gotIt: "समझ गया",
        .showMe: "दिखाओ",
        .skip: "छोड़ें",
        .next: "अगला",
        .previous: "पिछला",
        .close: "बंद करें",
        .help: "मदद",
        .settings: "सेटिंग्स"
    ]

    // MARK: - Dutch (Netherlands - High Apple Penetration)

    private static let dutch: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Hallo, ik ben Echoela",
        .welcomeDescription: "Ik ben hier om je te helpen Echoelmusic te verkennen. Ik bied zachte begeleiding wanneer je het nodig hebt, maar jij hebt altijd de controle.",
        .welcomeOptional: "Ik ben optioneel",
        .welcomeOptionalDesc: "Je kunt me altijd uitschakelen in Instellingen. Ik neem het niet persoonlijk.",
        .welcomeLearnStyle: "Ik leer jouw stijl",
        .welcomeLearnStyleDesc: "Terwijl je de app gebruikt, geef ik minder begeleiding als je zelfverzekerd bent, en meer bij nieuwe dingen.",
        .welcomeNoRush: "Ik haast je nooit",
        .welcomeNoRushDesc: "Er zijn geen timers, scores of druk. Neem alle tijd die je nodig hebt.",
        .welcomeAskAnytime: "Vraag wanneer je wilt",
        .welcomeAskAnytimeDesc: "Als je hulp nodig hebt, tik op de Echoela-knop of zoek het sparkle-icoon.",

        // General Help
        .generalHelpTitle: "Hoe kan ik helpen?",
        .generalHelpDescription: "Kies een onderwerp om meer te leren. Je kunt altijd terugkomen.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Leer hoe je lichaam verbonden is met de muziek.",
        .biofeedbackDisclaimer: "Belangrijk: Dit is kunst, geen medicijn.",
        .biofeedbackDisclaimerDetail: "Echoelmusic is een creatief hulpmiddel. Het diagnosticeert, behandelt of geneest geen aandoeningen. Raadpleeg altijd zorgprofessionals bij medische vragen.",

        // Help Offers
        .helpHesitation1: "Neem je tijd. Wil je wat begeleiding?",
        .helpHesitation2: "Geen haast. Ik ben hier als je een hint nodig hebt.",
        .helpHesitation3: "Wanneer je klaar bent. Hulp nodig?",
        .helpUserRequested: "Hoe kan ik je helpen?",

        // UI Elements
        .dismiss: "Sluiten",
        .learnMore: "Meer leren",
        .gotIt: "Begrepen",
        .showMe: "Laat zien",
        .skip: "Overslaan",
        .next: "Volgende",
        .previous: "Vorige",
        .close: "Sluiten",
        .help: "Help",
        .settings: "Instellingen"
    ]

    // MARK: - Danish (Denmark - 63% iPhone Market Share!)

    private static let danish: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Hej, jeg er Echoela",
        .welcomeDescription: "Jeg er her for at hjælpe dig med at udforske Echoelmusic. Jeg tilbyder blid vejledning, når du har brug for det, men du har altid kontrollen.",
        .welcomeOptional: "Jeg er valgfri",
        .welcomeOptionalDesc: "Du kan slå mig fra i Indstillinger når som helst. Jeg bliver ikke fornærmet.",
        .welcomeLearnStyle: "Jeg lærer din stil",
        .welcomeLearnStyleDesc: "Mens du bruger appen, giver jeg mindre vejledning, når du er sikker, og mere når tingene er nye.",
        .welcomeNoRush: "Jeg presser dig aldrig",
        .welcomeNoRushDesc: "Der er ingen timere, scores eller pres. Tag al den tid du har brug for.",
        .welcomeAskAnytime: "Spørg når som helst",
        .welcomeAskAnytimeDesc: "Hvis du har brug for hjælp, tryk på Echoela-knappen eller kig efter glimt-ikonet.",

        // General Help
        .generalHelpTitle: "Hvordan kan jeg hjælpe?",
        .generalHelpDescription: "Vælg et emne for at lære mere. Du kan altid vende tilbage hertil.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Lær hvordan din krop forbinder med musikken.",
        .biofeedbackDisclaimer: "Vigtigt: Dette er kunst, ikke medicin.",
        .biofeedbackDisclaimerDetail: "Echoelmusic er et kreativt værktøj. Det diagnosticerer, behandler eller helbreder ingen tilstande. Konsulter altid sundhedsprofessionelle ved medicinske spørgsmål.",

        // Help Offers
        .helpHesitation1: "Tag din tid. Vil du have lidt vejledning?",
        .helpHesitation2: "Intet hastværk. Jeg er her, hvis du har brug for et hint.",
        .helpHesitation3: "Når du er klar. Har du brug for hjælp?",
        .helpUserRequested: "Hvordan kan jeg hjælpe dig?",

        // UI Elements
        .dismiss: "Luk",
        .learnMore: "Lær mere",
        .gotIt: "Forstået",
        .showMe: "Vis mig",
        .skip: "Spring over",
        .next: "Næste",
        .previous: "Forrige",
        .close: "Luk",
        .help: "Hjælp",
        .settings: "Indstillinger"
    ]

    // MARK: - Swedish (Sweden - Wealthy Scandinavia)

    private static let swedish: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Hej, jag är Echoela",
        .welcomeDescription: "Jag är här för att hjälpa dig utforska Echoelmusic. Jag erbjuder mjuk vägledning när du behöver det, men du har alltid kontrollen.",
        .welcomeOptional: "Jag är valfri",
        .welcomeOptionalDesc: "Du kan stänga av mig i Inställningar när som helst. Jag tar inte illa upp.",
        .welcomeLearnStyle: "Jag lär mig din stil",
        .welcomeLearnStyleDesc: "När du använder appen ger jag mindre vägledning när du är säker, och mer när saker är nya.",
        .welcomeNoRush: "Jag stressar dig aldrig",
        .welcomeNoRushDesc: "Det finns inga timers, poäng eller press. Ta all tid du behöver.",
        .welcomeAskAnytime: "Fråga när som helst",
        .welcomeAskAnytimeDesc: "Om du behöver hjälp, tryck på Echoela-knappen eller leta efter gnistr-ikonen.",

        // General Help
        .generalHelpTitle: "Hur kan jag hjälpa?",
        .generalHelpDescription: "Välj ett ämne för att lära dig mer. Du kan alltid komma tillbaka hit.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Lär dig hur din kropp ansluter till musiken.",
        .biofeedbackDisclaimer: "Viktigt: Detta är konst, inte medicin.",
        .biofeedbackDisclaimerDetail: "Echoelmusic är ett kreativt verktyg. Det diagnostiserar, behandlar eller botar inga tillstånd. Konsultera alltid vårdpersonal vid medicinska frågor.",

        // Help Offers
        .helpHesitation1: "Ta din tid. Vill du ha lite vägledning?",
        .helpHesitation2: "Ingen brådska. Jag är här om du behöver en ledtråd.",
        .helpHesitation3: "När du är redo. Behöver du hjälp?",
        .helpUserRequested: "Hur kan jag hjälpa dig?",

        // UI Elements
        .dismiss: "Stäng",
        .learnMore: "Läs mer",
        .gotIt: "Förstått",
        .showMe: "Visa mig",
        .skip: "Hoppa över",
        .next: "Nästa",
        .previous: "Föregående",
        .close: "Stäng",
        .help: "Hjälp",
        .settings: "Inställningar"
    ]

    // MARK: - Norwegian (Norway - Very Wealthy)

    private static let norwegian: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Hei, jeg er Echoela",
        .welcomeDescription: "Jeg er her for å hjelpe deg med å utforske Echoelmusic. Jeg tilbyr myk veiledning når du trenger det, men du har alltid kontrollen.",
        .welcomeOptional: "Jeg er valgfri",
        .welcomeOptionalDesc: "Du kan slå meg av i Innstillinger når som helst. Jeg tar det ikke personlig.",
        .welcomeLearnStyle: "Jeg lærer din stil",
        .welcomeLearnStyleDesc: "Mens du bruker appen, gir jeg mindre veiledning når du er sikker, og mer når ting er nye.",
        .welcomeNoRush: "Jeg stresser deg aldri",
        .welcomeNoRushDesc: "Det er ingen tidtakere, poeng eller press. Ta all den tiden du trenger.",
        .welcomeAskAnytime: "Spør når som helst",
        .welcomeAskAnytimeDesc: "Hvis du trenger hjelp, trykk på Echoela-knappen eller se etter gnist-ikonet.",

        // General Help
        .generalHelpTitle: "Hvordan kan jeg hjelpe?",
        .generalHelpDescription: "Velg et emne for å lære mer. Du kan alltid komme tilbake hit.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Lær hvordan kroppen din kobler til musikken.",
        .biofeedbackDisclaimer: "Viktig: Dette er kunst, ikke medisin.",
        .biofeedbackDisclaimerDetail: "Echoelmusic er et kreativt verktøy. Det diagnostiserer, behandler eller kurerer ingen tilstander. Konsulter alltid helsepersonell ved medisinske spørsmål.",

        // Help Offers
        .helpHesitation1: "Ta deg god tid. Vil du ha litt veiledning?",
        .helpHesitation2: "Ingen hastverk. Jeg er her hvis du trenger et hint.",
        .helpHesitation3: "Når du er klar. Trenger du hjelp?",
        .helpUserRequested: "Hvordan kan jeg hjelpe deg?",

        // UI Elements
        .dismiss: "Lukk",
        .learnMore: "Lær mer",
        .gotIt: "Skjønner",
        .showMe: "Vis meg",
        .skip: "Hopp over",
        .next: "Neste",
        .previous: "Forrige",
        .close: "Lukk",
        .help: "Hjelp",
        .settings: "Innstillinger"
    ]

    // MARK: - Polish (Poland - Largest Eastern Europe)

    private static let polish: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Cześć, jestem Echoela",
        .welcomeDescription: "Jestem tu, aby pomóc Ci odkrywać Echoelmusic. Oferuję delikatne wskazówki, gdy ich potrzebujesz, ale zawsze masz kontrolę.",
        .welcomeOptional: "Jestem opcjonalna",
        .welcomeOptionalDesc: "Możesz mnie wyłączyć w Ustawieniach w każdej chwili. Nie obrażę się.",
        .welcomeLearnStyle: "Uczę się Twojego stylu",
        .welcomeLearnStyleDesc: "Podczas korzystania z aplikacji daję mniej wskazówek, gdy jesteś pewny, a więcej, gdy rzeczy są nowe.",
        .welcomeNoRush: "Nigdy Cię nie poganiem",
        .welcomeNoRushDesc: "Nie ma żadnych timerów, punktów ani presji. Weź tyle czasu, ile potrzebujesz.",
        .welcomeAskAnytime: "Pytaj kiedy chcesz",
        .welcomeAskAnytimeDesc: "Jeśli potrzebujesz pomocy, dotknij przycisku Echoela lub poszukaj ikony iskierki.",

        // General Help
        .generalHelpTitle: "Jak mogę pomóc?",
        .generalHelpDescription: "Wybierz temat, aby dowiedzieć się więcej. Zawsze możesz tu wrócić.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Dowiedz się, jak Twoje ciało łączy się z muzyką.",
        .biofeedbackDisclaimer: "Ważne: To sztuka, nie medycyna.",
        .biofeedbackDisclaimerDetail: "Echoelmusic to narzędzie kreatywne. Nie diagnozuje, nie leczy ani nie leczy żadnych schorzeń. W kwestiach medycznych zawsze konsultuj się z lekarzem.",

        // Help Offers
        .helpHesitation1: "Nie spiesz się. Chcesz trochę wskazówek?",
        .helpHesitation2: "Bez pośpiechu. Jestem tu, jeśli potrzebujesz podpowiedzi.",
        .helpHesitation3: "Kiedy będziesz gotowy. Potrzebujesz pomocy?",
        .helpUserRequested: "Jak mogę Ci pomóc?",

        // UI Elements
        .dismiss: "Zamknij",
        .learnMore: "Dowiedz się więcej",
        .gotIt: "Rozumiem",
        .showMe: "Pokaż mi",
        .skip: "Pomiń",
        .next: "Dalej",
        .previous: "Wstecz",
        .close: "Zamknij",
        .help: "Pomoc",
        .settings: "Ustawienia"
    ]

    // MARK: - Turkish (Turkey - Large Growing Market)

    private static let turkish: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Merhaba, ben Echoela",
        .welcomeDescription: "Echoelmusic'i keşfetmene yardımcı olmak için buradayım. İhtiyacın olduğunda nazik rehberlik sunacağım, ama kontrol her zaman sende.",
        .welcomeOptional: "Ben isteğe bağlıyım",
        .welcomeOptionalDesc: "Beni Ayarlar'dan istediğin zaman kapatabilirsin. Gücenmem.",
        .welcomeLearnStyle: "Tarzını öğreniyorum",
        .welcomeLearnStyleDesc: "Uygulamayı kullandıkça, kendine güvendiğinde daha az, yeni şeylerle karşılaştığında daha fazla rehberlik vereceğim.",
        .welcomeNoRush: "Seni asla acele ettirmem",
        .welcomeNoRushDesc: "Zamanlayıcı yok, puan yok, baskı yok. İhtiyacın olan kadar zaman al.",
        .welcomeAskAnytime: "İstediğin zaman sor",
        .welcomeAskAnytimeDesc: "Yardıma ihtiyacın olursa, Echoela düğmesine dokun veya pırıltı simgesini ara.",

        // General Help
        .generalHelpTitle: "Nasıl yardımcı olabilirim?",
        .generalHelpDescription: "Daha fazla öğrenmek için bir konu seç. Her zaman buraya dönebilirsin.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Vücudunun müzikle nasıl bağlantı kurduğunu öğren.",
        .biofeedbackDisclaimer: "Önemli: Bu sanat, tıp değil.",
        .biofeedbackDisclaimerDetail: "Echoelmusic yaratıcı bir araçtır. Herhangi bir durumu teşhis, tedavi veya iyileştirmez. Tıbbi endişeler için her zaman sağlık uzmanlarına danışın.",

        // Help Offers
        .helpHesitation1: "Acele etme. Biraz rehberlik ister misin?",
        .helpHesitation2: "Acele yok. İpucu lazımsa buradayım.",
        .helpHesitation3: "Hazır olduğunda. Yardım lazım mı?",
        .helpUserRequested: "Sana nasıl yardımcı olabilirim?",

        // UI Elements
        .dismiss: "Kapat",
        .learnMore: "Daha fazla öğren",
        .gotIt: "Anladım",
        .showMe: "Göster",
        .skip: "Atla",
        .next: "Sonraki",
        .previous: "Önceki",
        .close: "Kapat",
        .help: "Yardım",
        .settings: "Ayarlar"
    ]

    // MARK: - Thai (Thailand - Southeast Asia Leader)

    private static let thai: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "สวัสดี ฉันคือ Echoela",
        .welcomeDescription: "ฉันอยู่ที่นี่เพื่อช่วยคุณสำรวจ Echoelmusic ฉันจะให้คำแนะนำอย่างอ่อนโยนเมื่อคุณต้องการ แต่คุณควบคุมได้เสมอ",
        .welcomeOptional: "ฉันเป็นตัวเลือก",
        .welcomeOptionalDesc: "คุณสามารถปิดฉันได้ในการตั้งค่าเมื่อไหร่ก็ได้ ฉันไม่โกรธ",
        .welcomeLearnStyle: "ฉันเรียนรู้สไตล์ของคุณ",
        .welcomeLearnStyleDesc: "เมื่อคุณใช้แอป ฉันจะให้คำแนะนำน้อยลงเมื่อคุณมั่นใจ และมากขึ้นเมื่อสิ่งต่างๆ ใหม่",
        .welcomeNoRush: "ฉันไม่เร่งคุณเลย",
        .welcomeNoRushDesc: "ไม่มีตัวจับเวลา ไม่มีคะแนน ไม่มีแรงกดดัน ใช้เวลาเท่าที่คุณต้องการ",
        .welcomeAskAnytime: "ถามได้ทุกเมื่อ",
        .welcomeAskAnytimeDesc: "หากคุณต้องการความช่วยเหลือ แตะปุ่ม Echoela หรือมองหาไอคอนประกาย",

        // General Help
        .generalHelpTitle: "ฉันช่วยอะไรได้บ้าง?",
        .generalHelpDescription: "เลือกหัวข้อเพื่อเรียนรู้เพิ่มเติม คุณกลับมาที่นี่ได้เสมอ",

        // Biofeedback
        .biofeedbackTitle: "ไบโอฟีดแบค",
        .biofeedbackDescription: "เรียนรู้ว่าร่างกายของคุณเชื่อมต่อกับเพลงอย่างไร",
        .biofeedbackDisclaimer: "สำคัญ: นี่คือศิลปะ ไม่ใช่ยา",
        .biofeedbackDisclaimerDetail: "Echoelmusic เป็นเครื่องมือสร้างสรรค์ ไม่ได้วินิจฉัย รักษา หรือรักษาอาการใดๆ ปรึกษาผู้เชี่ยวชาญด้านสุขภาพสำหรับข้อกังวลทางการแพทย์เสมอ",

        // Help Offers
        .helpHesitation1: "ใช้เวลาของคุณ ต้องการคำแนะนำบ้างไหม?",
        .helpHesitation2: "ไม่ต้องรีบ ฉันอยู่ที่นี่ถ้าคุณต้องการคำใบ้",
        .helpHesitation3: "เมื่อคุณพร้อม ต้องการความช่วยเหลือไหม?",
        .helpUserRequested: "ฉันช่วยคุณได้อย่างไร?",

        // UI Elements
        .dismiss: "ปิด",
        .learnMore: "เรียนรู้เพิ่มเติม",
        .gotIt: "เข้าใจแล้ว",
        .showMe: "แสดงให้ฉันดู",
        .skip: "ข้าม",
        .next: "ถัดไป",
        .previous: "ก่อนหน้า",
        .close: "ปิด",
        .help: "ช่วยเหลือ",
        .settings: "การตั้งค่า"
    ]

    // MARK: - Vietnamese (Vietnam - 23% YoY Growth)

    private static let vietnamese: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Xin chào, tôi là Echoela",
        .welcomeDescription: "Tôi ở đây để giúp bạn khám phá Echoelmusic. Tôi sẽ đưa ra hướng dẫn nhẹ nhàng khi bạn cần, nhưng bạn luôn kiểm soát.",
        .welcomeOptional: "Tôi là tùy chọn",
        .welcomeOptionalDesc: "Bạn có thể tắt tôi trong Cài đặt bất cứ lúc nào. Tôi sẽ không phiền.",
        .welcomeLearnStyle: "Tôi học phong cách của bạn",
        .welcomeLearnStyleDesc: "Khi bạn sử dụng ứng dụng, tôi sẽ đưa ra ít hướng dẫn hơn khi bạn tự tin, và nhiều hơn khi mọi thứ còn mới.",
        .welcomeNoRush: "Tôi không bao giờ vội bạn",
        .welcomeNoRushDesc: "Không có bộ đếm thời gian, điểm số, hay áp lực. Hãy dành thời gian bạn cần.",
        .welcomeAskAnytime: "Hỏi bất cứ lúc nào",
        .welcomeAskAnytimeDesc: "Nếu bạn cần trợ giúp, chỉ cần chạm vào nút Echoela hoặc tìm biểu tượng lấp lánh.",

        // General Help
        .generalHelpTitle: "Tôi có thể giúp gì?",
        .generalHelpDescription: "Chọn một chủ đề để tìm hiểu thêm. Bạn luôn có thể quay lại đây.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Tìm hiểu cách cơ thể bạn kết nối với âm nhạc.",
        .biofeedbackDisclaimer: "Quan trọng: Đây là nghệ thuật, không phải y học.",
        .biofeedbackDisclaimerDetail: "Echoelmusic là công cụ sáng tạo. Nó không chẩn đoán, điều trị hoặc chữa bất kỳ tình trạng nào. Luôn tham khảo ý kiến chuyên gia y tế về các vấn đề sức khỏe.",

        // Help Offers
        .helpHesitation1: "Từ từ thôi. Bạn có muốn một chút hướng dẫn không?",
        .helpHesitation2: "Không vội. Tôi ở đây nếu bạn cần gợi ý.",
        .helpHesitation3: "Khi bạn sẵn sàng. Cần giúp đỡ không?",
        .helpUserRequested: "Tôi có thể giúp gì cho bạn?",

        // UI Elements
        .dismiss: "Đóng",
        .learnMore: "Tìm hiểu thêm",
        .gotIt: "Đã hiểu",
        .showMe: "Cho tôi xem",
        .skip: "Bỏ qua",
        .next: "Tiếp theo",
        .previous: "Trước",
        .close: "Đóng",
        .help: "Trợ giúp",
        .settings: "Cài đặt"
    ]

    // MARK: - Indonesian (Indonesia - Largest SE Asian Market)

    private static let indonesian: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Halo, saya Echoela",
        .welcomeDescription: "Saya di sini untuk membantu Anda menjelajahi Echoelmusic. Saya akan memberikan panduan lembut saat Anda membutuhkannya, tapi Anda selalu memegang kendali.",
        .welcomeOptional: "Saya opsional",
        .welcomeOptionalDesc: "Anda bisa menonaktifkan saya di Pengaturan kapan saja. Saya tidak akan tersinggung.",
        .welcomeLearnStyle: "Saya belajar gaya Anda",
        .welcomeLearnStyleDesc: "Saat Anda menggunakan aplikasi, saya akan memberikan lebih sedikit panduan saat Anda percaya diri, dan lebih banyak saat hal-hal baru.",
        .welcomeNoRush: "Saya tidak pernah terburu-buru",
        .welcomeNoRushDesc: "Tidak ada timer, skor, atau tekanan. Ambil semua waktu yang Anda butuhkan.",
        .welcomeAskAnytime: "Tanya kapan saja",
        .welcomeAskAnytimeDesc: "Jika Anda butuh bantuan, cukup ketuk tombol Echoela atau cari ikon berkilau.",

        // General Help
        .generalHelpTitle: "Bagaimana saya bisa membantu?",
        .generalHelpDescription: "Pilih topik untuk mempelajari lebih lanjut. Anda selalu bisa kembali ke sini.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Pelajari bagaimana tubuh Anda terhubung dengan musik.",
        .biofeedbackDisclaimer: "Penting: Ini adalah seni, bukan obat.",
        .biofeedbackDisclaimerDetail: "Echoelmusic adalah alat kreatif. Tidak mendiagnosis, mengobati, atau menyembuhkan kondisi apa pun. Selalu konsultasikan dengan profesional kesehatan untuk masalah medis.",

        // Help Offers
        .helpHesitation1: "Pelan-pelan saja. Mau panduan?",
        .helpHesitation2: "Tidak terburu-buru. Saya di sini jika Anda butuh petunjuk.",
        .helpHesitation3: "Kapan Anda siap. Butuh bantuan?",
        .helpUserRequested: "Bagaimana saya bisa membantu Anda?",

        // UI Elements
        .dismiss: "Tutup",
        .learnMore: "Pelajari lebih",
        .gotIt: "Mengerti",
        .showMe: "Tunjukkan",
        .skip: "Lewati",
        .next: "Berikutnya",
        .previous: "Sebelumnya",
        .close: "Tutup",
        .help: "Bantuan",
        .settings: "Pengaturan"
    ]

    // MARK: - Malay (Malaysia/Singapore)

    private static let malay: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Hai, saya Echoela",
        .welcomeDescription: "Saya di sini untuk membantu anda meneroka Echoelmusic. Saya akan menawarkan panduan lembut apabila anda memerlukannya, tetapi anda sentiasa mengawal.",
        .welcomeOptional: "Saya pilihan",
        .welcomeOptionalDesc: "Anda boleh matikan saya dalam Tetapan bila-bila masa. Saya tidak akan tersinggung.",
        .welcomeLearnStyle: "Saya belajar gaya anda",
        .welcomeLearnStyleDesc: "Semasa anda menggunakan aplikasi, saya akan kurang memberi panduan apabila anda yakin, dan lebih apabila perkara baru.",
        .welcomeNoRush: "Saya tidak pernah tergesa-gesa",
        .welcomeNoRushDesc: "Tiada pemasa, skor, atau tekanan. Ambil masa yang anda perlukan.",
        .welcomeAskAnytime: "Tanya bila-bila masa",
        .welcomeAskAnytimeDesc: "Jika anda perlukan bantuan, ketik butang Echoela atau cari ikon berkilau.",

        // General Help
        .generalHelpTitle: "Bagaimana saya boleh membantu?",
        .generalHelpDescription: "Pilih topik untuk mengetahui lebih lanjut. Anda sentiasa boleh kembali ke sini.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Ketahui bagaimana badan anda berhubung dengan muzik.",
        .biofeedbackDisclaimer: "Penting: Ini adalah seni, bukan perubatan.",
        .biofeedbackDisclaimerDetail: "Echoelmusic adalah alat kreatif. Ia tidak mendiagnosis, merawat, atau menyembuhkan sebarang keadaan. Sentiasa rujuk profesional kesihatan untuk kebimbangan perubatan.",

        // Help Offers
        .helpHesitation1: "Ambil masa anda. Mahu panduan?",
        .helpHesitation2: "Tidak tergesa-gesa. Saya di sini jika anda perlukan petunjuk.",
        .helpHesitation3: "Apabila anda bersedia. Perlukan bantuan?",
        .helpUserRequested: "Bagaimana saya boleh membantu anda?",

        // UI Elements
        .dismiss: "Tutup",
        .learnMore: "Ketahui lebih",
        .gotIt: "Faham",
        .showMe: "Tunjukkan",
        .skip: "Langkau",
        .next: "Seterusnya",
        .previous: "Sebelumnya",
        .close: "Tutup",
        .help: "Bantuan",
        .settings: "Tetapan"
    ]

    // MARK: - Finnish (Finland - Nordic)

    private static let finnish: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Hei, olen Echoela",
        .welcomeDescription: "Olen täällä auttamassa sinua tutkimaan Echoelmusicin. Tarjoan lempeää opastusta kun tarvitset, mutta sinä hallitset aina.",
        .welcomeOptional: "Olen valinnainen",
        .welcomeOptionalDesc: "Voit kytkeä minut pois Asetuksista milloin tahansa. En loukkaannu.",
        .welcomeLearnStyle: "Opin tyylisi",
        .welcomeLearnStyleDesc: "Kun käytät sovellusta, annan vähemmän opastusta kun olet varma, ja enemmän kun asiat ovat uusia.",
        .welcomeNoRush: "En kiirehdi koskaan",
        .welcomeNoRushDesc: "Ei ajastimia, pisteitä tai painetta. Ota kaikki aika jonka tarvitset.",
        .welcomeAskAnytime: "Kysy milloin tahansa",
        .welcomeAskAnytimeDesc: "Jos tarvitset apua, napauta Echoela-painiketta tai etsi kimmelluskuvaketta.",

        // General Help
        .generalHelpTitle: "Miten voin auttaa?",
        .generalHelpDescription: "Valitse aihe oppiaksesi lisää. Voit aina palata tänne.",

        // Biofeedback
        .biofeedbackTitle: "Biopalaute",
        .biofeedbackDescription: "Opi miten kehosi yhdistyy musiikkiin.",
        .biofeedbackDisclaimer: "Tärkeää: Tämä on taidetta, ei lääketiedettä.",
        .biofeedbackDisclaimerDetail: "Echoelmusic on luova työkalu. Se ei diagnosoi, hoida tai paranna mitään tilaa. Ota aina yhteyttä terveydenhuollon ammattilaiseen terveyshuolien kanssa.",

        // Help Offers
        .helpHesitation1: "Ota aikasi. Haluatko opastusta?",
        .helpHesitation2: "Ei kiirettä. Olen täällä jos tarvitset vihjettä.",
        .helpHesitation3: "Kun olet valmis. Tarvitsetko apua?",
        .helpUserRequested: "Miten voin auttaa sinua?",

        // UI Elements
        .dismiss: "Sulje",
        .learnMore: "Lue lisää",
        .gotIt: "Selvä",
        .showMe: "Näytä",
        .skip: "Ohita",
        .next: "Seuraava",
        .previous: "Edellinen",
        .close: "Sulje",
        .help: "Apua",
        .settings: "Asetukset"
    ]

    // MARK: - Greek (Greece - Mediterranean)

    private static let greek: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Γεια, είμαι η Echoela",
        .welcomeDescription: "Είμαι εδώ για να σε βοηθήσω να εξερευνήσεις το Echoelmusic. Θα προσφέρω ήπια καθοδήγηση όταν τη χρειάζεσαι, αλλά πάντα έχεις τον έλεγχο.",
        .welcomeOptional: "Είμαι προαιρετική",
        .welcomeOptionalDesc: "Μπορείς να με απενεργοποιήσεις στις Ρυθμίσεις ανά πάσα στιγμή. Δεν θα προσβληθώ.",
        .welcomeLearnStyle: "Μαθαίνω το στυλ σου",
        .welcomeLearnStyleDesc: "Καθώς χρησιμοποιείς την εφαρμογή, θα δίνω λιγότερη καθοδήγηση όταν είσαι σίγουρος, και περισσότερη σε νέα πράγματα.",
        .welcomeNoRush: "Δεν σε βιάζω ποτέ",
        .welcomeNoRushDesc: "Δεν υπάρχουν χρονόμετρα, βαθμολογίες ή πίεση. Πάρε όλο τον χρόνο που χρειάζεσαι.",
        .welcomeAskAnytime: "Ρώτα όποτε θέλεις",
        .welcomeAskAnytimeDesc: "Αν χρειάζεσαι βοήθεια, απλά πάτα το κουμπί Echoela ή ψάξε το εικονίδιο με τη λάμψη.",

        // General Help
        .generalHelpTitle: "Πώς μπορώ να βοηθήσω;",
        .generalHelpDescription: "Επίλεξε ένα θέμα για να μάθεις περισσότερα. Μπορείς πάντα να επιστρέψεις εδώ.",

        // Biofeedback
        .biofeedbackTitle: "Βιοανάδραση",
        .biofeedbackDescription: "Μάθε πώς το σώμα σου συνδέεται με τη μουσική.",
        .biofeedbackDisclaimer: "Σημαντικό: Αυτό είναι τέχνη, όχι ιατρική.",
        .biofeedbackDisclaimerDetail: "Το Echoelmusic είναι δημιουργικό εργαλείο. Δεν διαγιγνώσκει, θεραπεύει ή ιατρεύει καμία κατάσταση. Συμβουλεύσου πάντα επαγγελματίες υγείας για ιατρικά θέματα.",

        // Help Offers
        .helpHesitation1: "Πάρε τον χρόνο σου. Θέλεις καθοδήγηση;",
        .helpHesitation2: "Χωρίς βιασύνη. Είμαι εδώ αν χρειαστείς υπόδειξη.",
        .helpHesitation3: "Όταν είσαι έτοιμος. Χρειάζεσαι βοήθεια;",
        .helpUserRequested: "Πώς μπορώ να σε βοηθήσω;",

        // UI Elements
        .dismiss: "Κλείσιμο",
        .learnMore: "Μάθε περισσότερα",
        .gotIt: "Κατάλαβα",
        .showMe: "Δείξε μου",
        .skip: "Παράλειψη",
        .next: "Επόμενο",
        .previous: "Προηγούμενο",
        .close: "Κλείσιμο",
        .help: "Βοήθεια",
        .settings: "Ρυθμίσεις"
    ]

    // MARK: - Czech (Czech Republic - Central Europe)

    private static let czech: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Ahoj, jsem Echoela",
        .welcomeDescription: "Jsem tu, abych ti pomohla prozkoumat Echoelmusic. Nabídnu ti jemné vedení, když ho budeš potřebovat, ale ty máš vždy kontrolu.",
        .welcomeOptional: "Jsem volitelná",
        .welcomeOptionalDesc: "Můžeš mě kdykoli vypnout v Nastavení. Neurazím se.",
        .welcomeLearnStyle: "Učím se tvůj styl",
        .welcomeLearnStyleDesc: "Jak budeš používat aplikaci, budu ti dávat méně rad, když budeš jistý, a více, když budou věci nové.",
        .welcomeNoRush: "Nikdy tě nespěchám",
        .welcomeNoRushDesc: "Žádné časovače, skóre ani tlak. Vezmi si veškerý čas, který potřebuješ.",
        .welcomeAskAnytime: "Zeptej se kdykoli",
        .welcomeAskAnytimeDesc: "Pokud potřebuješ pomoc, stačí klepnout na tlačítko Echoela nebo hledat ikonu jiskry.",

        // General Help
        .generalHelpTitle: "Jak mohu pomoci?",
        .generalHelpDescription: "Vyber si téma a dozvíš se více. Vždy se sem můžeš vrátit.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Zjisti, jak je tvé tělo propojeno s hudbou.",
        .biofeedbackDisclaimer: "Důležité: Toto je umění, ne medicína.",
        .biofeedbackDisclaimerDetail: "Echoelmusic je kreativní nástroj. Nediagnostikuje, neléčí ani neuzdravuje žádné stavy. Vždy konzultuj se zdravotnickými odborníky ohledně zdravotních problémů.",

        // Help Offers
        .helpHesitation1: "Nespěchej. Chceš trochu vedení?",
        .helpHesitation2: "Bez spěchu. Jsem tu, pokud potřebuješ nápovědu.",
        .helpHesitation3: "Až budeš připraven. Potřebuješ pomoc?",
        .helpUserRequested: "Jak ti mohu pomoci?",

        // UI Elements
        .dismiss: "Zavřít",
        .learnMore: "Zjistit více",
        .gotIt: "Rozumím",
        .showMe: "Ukaž mi",
        .skip: "Přeskočit",
        .next: "Další",
        .previous: "Předchozí",
        .close: "Zavřít",
        .help: "Nápověda",
        .settings: "Nastavení"
    ]

    // MARK: - Romanian (Romania - Eastern Europe)

    private static let romanian: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Salut, sunt Echoela",
        .welcomeDescription: "Sunt aici să te ajut să explorezi Echoelmusic. Voi oferi îndrumare blândă când ai nevoie, dar tu ești mereu în control.",
        .welcomeOptional: "Sunt opțională",
        .welcomeOptionalDesc: "Mă poți dezactiva din Setări oricând. Nu mă voi supăra.",
        .welcomeLearnStyle: "Învăț stilul tău",
        .welcomeLearnStyleDesc: "Pe măsură ce folosești aplicația, voi oferi mai puțină îndrumare când ești sigur, și mai multă când lucrurile sunt noi.",
        .welcomeNoRush: "Nu te grăbesc niciodată",
        .welcomeNoRushDesc: "Nu sunt cronometre, scoruri sau presiune. Ia-ți tot timpul de care ai nevoie.",
        .welcomeAskAnytime: "Întreabă oricând",
        .welcomeAskAnytimeDesc: "Dacă ai nevoie de ajutor, doar apasă butonul Echoela sau caută pictograma sclipitoare.",

        // General Help
        .generalHelpTitle: "Cum pot ajuta?",
        .generalHelpDescription: "Alege un subiect pentru a afla mai multe. Poți reveni oricând aici.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Află cum corpul tău se conectează la muzică.",
        .biofeedbackDisclaimer: "Important: Aceasta este artă, nu medicină.",
        .biofeedbackDisclaimerDetail: "Echoelmusic este un instrument creativ. Nu diagnostichează, tratează sau vindecă nicio afecțiune. Consultă întotdeauna profesioniști în sănătate pentru probleme medicale.",

        // Help Offers
        .helpHesitation1: "Nu te grăbi. Vrei puțină îndrumare?",
        .helpHesitation2: "Fără grabă. Sunt aici dacă ai nevoie de un indiciu.",
        .helpHesitation3: "Când ești gata. Ai nevoie de ajutor?",
        .helpUserRequested: "Cum te pot ajuta?",

        // UI Elements
        .dismiss: "Închide",
        .learnMore: "Află mai multe",
        .gotIt: "Am înțeles",
        .showMe: "Arată-mi",
        .skip: "Sari",
        .next: "Următorul",
        .previous: "Anterior",
        .close: "Închide",
        .help: "Ajutor",
        .settings: "Setări"
    ]

    // MARK: - Hungarian (Hungary - Central Europe)

    private static let hungarian: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Szia, Echoela vagyok",
        .welcomeDescription: "Azért vagyok itt, hogy segítsek felfedezni az Echoelmusic-ot. Gyengéd útmutatást adok, amikor szükséged van rá, de te mindig irányítasz.",
        .welcomeOptional: "Opcionális vagyok",
        .welcomeOptionalDesc: "Bármikor kikapcsolhatsz a Beállításokban. Nem sértődök meg.",
        .welcomeLearnStyle: "Megtanulom a stílusodat",
        .welcomeLearnStyleDesc: "Ahogy használod az alkalmazást, kevesebb útmutatást adok, amikor magabiztos vagy, és többet, amikor új dolgokkal találkozol.",
        .welcomeNoRush: "Soha nem siettetlek",
        .welcomeNoRushDesc: "Nincsenek időzítők, pontszámok vagy nyomás. Vedd el az összes időt, amire szükséged van.",
        .welcomeAskAnytime: "Kérdezz bármikor",
        .welcomeAskAnytimeDesc: "Ha segítségre van szükséged, csak érintsd meg az Echoela gombot, vagy keresd a csillogó ikont.",

        // General Help
        .generalHelpTitle: "Hogyan segíthetek?",
        .generalHelpDescription: "Válassz egy témát, hogy többet megtudj. Mindig visszatérhetsz ide.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Ismerd meg, hogyan kapcsolódik a tested a zenéhez.",
        .biofeedbackDisclaimer: "Fontos: Ez művészet, nem orvoslás.",
        .biofeedbackDisclaimerDetail: "Az Echoelmusic kreatív eszköz. Nem diagnosztizál, kezel vagy gyógyít semmilyen állapotot. Mindig konzultálj egészségügyi szakemberekkel orvosi kérdésekben.",

        // Help Offers
        .helpHesitation1: "Ne siess. Szeretnél útmutatást?",
        .helpHesitation2: "Nincs rohanás. Itt vagyok, ha tippre van szükséged.",
        .helpHesitation3: "Amikor készen állsz. Segítségre van szükséged?",
        .helpUserRequested: "Hogyan segíthetek neked?",

        // UI Elements
        .dismiss: "Bezárás",
        .learnMore: "Tudj meg többet",
        .gotIt: "Értem",
        .showMe: "Mutasd",
        .skip: "Kihagyás",
        .next: "Következő",
        .previous: "Előző",
        .close: "Bezárás",
        .help: "Súgó",
        .settings: "Beállítások"
    ]

    // MARK: - Ukrainian (Ukraine - Eastern Europe)

    private static let ukrainian: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Привіт, я Echoela",
        .welcomeDescription: "Я тут, щоб допомогти вам досліджувати Echoelmusic. Я запропоную м'яке керівництво, коли вам потрібно, але ви завжди контролюєте ситуацію.",
        .welcomeOptional: "Я необов'язкова",
        .welcomeOptionalDesc: "Ви можете вимкнути мене в Налаштуваннях у будь-який час. Я не образжусь.",
        .welcomeLearnStyle: "Я вивчаю ваш стиль",
        .welcomeLearnStyleDesc: "Коли ви користуєтесь додатком, я даватиму менше порад, коли ви впевнені, і більше, коли речі нові.",
        .welcomeNoRush: "Я ніколи не поспішаю вас",
        .welcomeNoRushDesc: "Немає таймерів, балів або тиску. Візьміть весь час, який вам потрібен.",
        .welcomeAskAnytime: "Запитуйте будь-коли",
        .welcomeAskAnytimeDesc: "Якщо вам потрібна допомога, просто натисніть кнопку Echoela або знайдіть значок блиску.",

        // General Help
        .generalHelpTitle: "Як я можу допомогти?",
        .generalHelpDescription: "Виберіть тему, щоб дізнатися більше. Ви завжди можете повернутися сюди.",

        // Biofeedback
        .biofeedbackTitle: "Біофідбек",
        .biofeedbackDescription: "Дізнайтеся, як ваше тіло з'єднується з музикою.",
        .biofeedbackDisclaimer: "Важливо: Це мистецтво, а не медицина.",
        .biofeedbackDisclaimerDetail: "Echoelmusic - це творчий інструмент. Він не діагностує, не лікує та не виліковує жодного стану. Завжди консультуйтеся з медичними фахівцями щодо медичних питань.",

        // Help Offers
        .helpHesitation1: "Не поспішайте. Хочете трохи керівництва?",
        .helpHesitation2: "Без поспіху. Я тут, якщо потрібна підказка.",
        .helpHesitation3: "Коли будете готові. Потрібна допомога?",
        .helpUserRequested: "Як я можу вам допомогти?",

        // UI Elements
        .dismiss: "Закрити",
        .learnMore: "Дізнатися більше",
        .gotIt: "Зрозуміло",
        .showMe: "Покажіть",
        .skip: "Пропустити",
        .next: "Далі",
        .previous: "Назад",
        .close: "Закрити",
        .help: "Допомога",
        .settings: "Налаштування"
    ]

    // MARK: - Hebrew (Israel - Middle East, RTL)

    private static let hebrew: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "שלום, אני אקואלה",
        .welcomeDescription: "אני כאן כדי לעזור לך לחקור את Echoelmusic. אציע הדרכה עדינה כשתצטרך, אבל אתה תמיד שולט.",
        .welcomeOptional: "אני אופציונלית",
        .welcomeOptionalDesc: "אתה יכול לכבות אותי בהגדרות בכל עת. לא אעלב.",
        .welcomeLearnStyle: "אני לומדת את הסגנון שלך",
        .welcomeLearnStyleDesc: "ככל שתשתמש באפליקציה, אתן פחות הדרכה כשאתה בטוח, ויותר כשדברים חדשים.",
        .welcomeNoRush: "אני לעולם לא ממהרת אותך",
        .welcomeNoRushDesc: "אין טיימרים, ניקוד או לחץ. קח את כל הזמן שאתה צריך.",
        .welcomeAskAnytime: "שאל בכל עת",
        .welcomeAskAnytimeDesc: "אם אתה צריך עזרה, פשוט לחץ על כפתור אקואלה או חפש את סמל הניצוץ.",

        // General Help
        .generalHelpTitle: "איך אני יכולה לעזור?",
        .generalHelpDescription: "בחר נושא כדי ללמוד עוד. אתה תמיד יכול לחזור לכאן.",

        // Biofeedback
        .biofeedbackTitle: "ביופידבק",
        .biofeedbackDescription: "למד איך הגוף שלך מתחבר למוזיקה.",
        .biofeedbackDisclaimer: "חשוב: זו אומנות, לא רפואה.",
        .biofeedbackDisclaimerDetail: "Echoelmusic הוא כלי יצירתי. הוא לא מאבחן, מטפל או מרפא שום מצב. התייעץ תמיד עם אנשי מקצוע בתחום הבריאות בנוגע לבעיות רפואיות.",

        // Help Offers
        .helpHesitation1: "קח את הזמן שלך. רוצה קצת הדרכה?",
        .helpHesitation2: "בלי לחץ. אני כאן אם אתה צריך רמז.",
        .helpHesitation3: "כשתהיה מוכן. צריך עזרה?",
        .helpUserRequested: "איך אני יכולה לעזור לך?",

        // UI Elements
        .dismiss: "סגור",
        .learnMore: "למד עוד",
        .gotIt: "הבנתי",
        .showMe: "הראה לי",
        .skip: "דלג",
        .next: "הבא",
        .previous: "הקודם",
        .close: "סגור",
        .help: "עזרה",
        .settings: "הגדרות"
    ]

    // MARK: - Filipino (Philippines - Large Market)

    private static let filipino: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Kamusta, ako si Echoela",
        .welcomeDescription: "Nandito ako para tulungan kang i-explore ang Echoelmusic. Mag-aalok ako ng mahinahong patnubay kapag kailangan mo, pero ikaw ang laging may kontrol.",
        .welcomeOptional: "Opsyonal lang ako",
        .welcomeOptionalDesc: "Pwede mo akong i-off sa Settings anumang oras. Hindi ako magagalit.",
        .welcomeLearnStyle: "Natututunan ko ang istilo mo",
        .welcomeLearnStyleDesc: "Habang ginagamit mo ang app, magbibigay ako ng mas kaunting patnubay kapag confident ka, at mas marami kapag bago ang mga bagay.",
        .welcomeNoRush: "Hindi kita minamadali kailanman",
        .welcomeNoRushDesc: "Walang timer, score, o pressure. Kumuha ng lahat ng oras na kailangan mo.",
        .welcomeAskAnytime: "Magtanong anumang oras",
        .welcomeAskAnytimeDesc: "Kung kailangan mo ng tulong, i-tap lang ang Echoela button o hanapin ang sparkle icon.",

        // General Help
        .generalHelpTitle: "Paano kita matutulungan?",
        .generalHelpDescription: "Pumili ng paksa para matuto pa. Pwede kang bumalik dito anumang oras.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Alamin kung paano kumokonekta ang katawan mo sa musika.",
        .biofeedbackDisclaimer: "Mahalaga: Ito ay sining, hindi medisina.",
        .biofeedbackDisclaimerDetail: "Ang Echoelmusic ay isang creative tool. Hindi ito nagde-diagnose, nagtatreat, o nagpapagaling ng anumang kondisyon. Laging kumonsulta sa mga healthcare professional para sa mga medikal na alalahanin.",

        // Help Offers
        .helpHesitation1: "Huwag magmadali. Gusto mo ng konting patnubay?",
        .helpHesitation2: "Walang apura. Nandito ako kung kailangan mo ng hint.",
        .helpHesitation3: "Kapag handa ka na. Kailangan mo ba ng tulong?",
        .helpUserRequested: "Paano kita matutulungan?",

        // UI Elements
        .dismiss: "Isara",
        .learnMore: "Matuto pa",
        .gotIt: "Sige",
        .showMe: "Ipakita",
        .skip: "Laktawan",
        .next: "Susunod",
        .previous: "Nakaraan",
        .close: "Isara",
        .help: "Tulong",
        .settings: "Settings"
    ]

    // MARK: - Swahili (East Africa - Growing Market)

    private static let swahili: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "Habari, mimi ni Echoela",
        .welcomeDescription: "Niko hapa kukusaidia kuchunguza Echoelmusic. Nitatoa mwongozo laini unapohitaji, lakini wewe daima uko katika udhibiti.",
        .welcomeOptional: "Mimi si lazima",
        .welcomeOptionalDesc: "Unaweza kunizima katika Mipangilio wakati wowote. Sitachukia.",
        .welcomeLearnStyle: "Ninajifunza mtindo wako",
        .welcomeLearnStyleDesc: "Unapotumia programu, nitatoa mwongozo mdogo unapokuwa na uhakika, na zaidi mambo yanapokuwa mapya.",
        .welcomeNoRush: "Siwi na haraka",
        .welcomeNoRushDesc: "Hakuna vipima muda, alama, au shinikizo. Chukua muda wote unaohitaji.",
        .welcomeAskAnytime: "Uliza wakati wowote",
        .welcomeAskAnytimeDesc: "Ukihitaji msaada, gusa tu kitufe cha Echoela au tafuta ikoni ya kung'aa.",

        // General Help
        .generalHelpTitle: "Naweza kukusaidiaje?",
        .generalHelpDescription: "Chagua mada ili kujifunza zaidi. Unaweza kurudi hapa wakati wowote.",

        // Biofeedback
        .biofeedbackTitle: "Biofeedback",
        .biofeedbackDescription: "Jifunze jinsi mwili wako unavyounganishwa na muziki.",
        .biofeedbackDisclaimer: "Muhimu: Hii ni sanaa, si dawa.",
        .biofeedbackDisclaimerDetail: "Echoelmusic ni zana ya ubunifu. Haigundui, haitibu, au kuponya hali yoyote. Daima wasiliana na wataalamu wa afya kwa wasiwasi wa kimatibabu.",

        // Help Offers
        .helpHesitation1: "Chukua muda wako. Ungependa mwongozo?",
        .helpHesitation2: "Hakuna haraka. Niko hapa ukihitaji kidokezo.",
        .helpHesitation3: "Unapokuwa tayari. Unahitaji msaada?",
        .helpUserRequested: "Naweza kukusaidiaje?",

        // UI Elements
        .dismiss: "Funga",
        .learnMore: "Jifunze zaidi",
        .gotIt: "Nimeelewa",
        .showMe: "Nionyeshe",
        .skip: "Ruka",
        .next: "Ijayo",
        .previous: "Iliyotangulia",
        .close: "Funga",
        .help: "Msaada",
        .settings: "Mipangilio"
    ]

    // MARK: - Bengali (Bangladesh/India - 230M+ Speakers)

    private static let bengali: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "হ্যালো, আমি ইকোএলা",
        .welcomeDescription: "আমি এখানে আপনাকে Echoelmusic অন্বেষণ করতে সাহায্য করতে এসেছি। আমি যখন প্রয়োজন হবে তখন মৃদু গাইডেন্স দেব, কিন্তু আপনি সবসময় নিয়ন্ত্রণে থাকবেন।",
        .welcomeOptional: "আমি ঐচ্ছিক",
        .welcomeOptionalDesc: "আপনি সেটিংস থেকে যেকোনো সময় আমাকে বন্ধ করতে পারেন। আমি মনে কষ্ট পাব না।",
        .welcomeLearnStyle: "আমি আপনার স্টাইল শিখি",
        .welcomeLearnStyleDesc: "আপনি যখন অ্যাপ ব্যবহার করবেন, আমি আত্মবিশ্বাসী হলে কম গাইডেন্স দেব, এবং নতুন কিছুতে বেশি দেব।",
        .welcomeNoRush: "আমি কখনো তাড়াহুড়ো করি না",
        .welcomeNoRushDesc: "কোনো টাইমার, স্কোর বা চাপ নেই। আপনার প্রয়োজনীয় সময় নিন।",
        .welcomeAskAnytime: "যেকোনো সময় জিজ্ঞাসা করুন",
        .welcomeAskAnytimeDesc: "যদি সাহায্য দরকার হয়, শুধু ইকোএলা বোতামে ট্যাপ করুন বা স্পার্কল আইকন খুঁজুন।",

        // General Help
        .generalHelpTitle: "আমি কীভাবে সাহায্য করতে পারি?",
        .generalHelpDescription: "আরো জানতে একটি বিষয় বেছে নিন। আপনি সবসময় এখানে ফিরে আসতে পারেন।",

        // Biofeedback
        .biofeedbackTitle: "বায়োফিডব্যাক",
        .biofeedbackDescription: "জানুন আপনার শরীর কীভাবে সঙ্গীতের সাথে সংযুক্ত।",
        .biofeedbackDisclaimer: "গুরুত্বপূর্ণ: এটি শিল্প, ওষুধ নয়।",
        .biofeedbackDisclaimerDetail: "Echoelmusic একটি সৃজনশীল টুল। এটি কোনো অবস্থা নির্ণয়, চিকিৎসা বা নিরাময় করে না। চিকিৎসা সংক্রান্ত উদ্বেগের জন্য সবসময় স্বাস্থ্য পেশাদারদের সাথে পরামর্শ করুন।",

        // Help Offers
        .helpHesitation1: "তাড়াহুড়ো করবেন না। কিছু গাইডেন্স চান?",
        .helpHesitation2: "কোনো তাড়া নেই। ইঙ্গিত দরকার হলে আমি এখানে আছি।",
        .helpHesitation3: "যখন আপনি প্রস্তুত। সাহায্য দরকার?",
        .helpUserRequested: "আমি আপনাকে কীভাবে সাহায্য করতে পারি?",

        // UI Elements
        .dismiss: "বন্ধ করুন",
        .learnMore: "আরো জানুন",
        .gotIt: "বুঝেছি",
        .showMe: "দেখান",
        .skip: "এড়িয়ে যান",
        .next: "পরবর্তী",
        .previous: "পূর্ববর্তী",
        .close: "বন্ধ",
        .help: "সাহায্য",
        .settings: "সেটিংস"
    ]

    // MARK: - Tamil (South India/Sri Lanka - 80M+ Speakers)

    private static let tamil: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "வணக்கம், நான் எக்கோயெலா",
        .welcomeDescription: "Echoelmusic-ஐ ஆராய உங்களுக்கு உதவ நான் இங்கே இருக்கிறேன். உங்களுக்கு தேவையான போது மென்மையான வழிகாட்டுதலை வழங்குவேன், ஆனால் நீங்கள் எப்போதும் கட்டுப்பாட்டில் இருப்பீர்கள்.",
        .welcomeOptional: "நான் விருப்பமானவள்",
        .welcomeOptionalDesc: "அமைப்புகளில் எப்போது வேண்டுமானாலும் என்னை அணைக்கலாம். நான் கோபப்பட மாட்டேன்.",
        .welcomeLearnStyle: "உங்கள் பாணியை கற்றுக்கொள்கிறேன்",
        .welcomeLearnStyleDesc: "நீங்கள் செயலியைப் பயன்படுத்தும்போது, நம்பிக்கையாக இருக்கும்போது குறைவான வழிகாட்டுதலும், புதிய விஷயங்களில் அதிகமும் தருவேன்.",
        .welcomeNoRush: "நான் ஒருபோதும் அவசரப்படுத்த மாட்டேன்",
        .welcomeNoRushDesc: "டைமர்கள், மதிப்பெண்கள் அல்லது அழுத்தம் இல்லை. உங்களுக்கு தேவையான நேரத்தை எடுத்துக்கொள்ளுங்கள்.",
        .welcomeAskAnytime: "எப்போது வேண்டுமானாலும் கேளுங்கள்",
        .welcomeAskAnytimeDesc: "உதவி தேவைப்பட்டால், எக்கோயெலா பொத்தானை தட்டுங்கள் அல்லது மின்னும் ஐகானைத் தேடுங்கள்.",

        // General Help
        .generalHelpTitle: "நான் எப்படி உதவ முடியும்?",
        .generalHelpDescription: "மேலும் அறிய ஒரு தலைப்பைத் தேர்ந்தெடுங்கள். நீங்கள் எப்போதும் இங்கே திரும்பி வரலாம்.",

        // Biofeedback
        .biofeedbackTitle: "பயோஃபீட்பேக்",
        .biofeedbackDescription: "உங்கள் உடல் இசையுடன் எவ்வாறு இணைகிறது என்பதை அறியுங்கள்.",
        .biofeedbackDisclaimer: "முக்கியம்: இது கலை, மருத்துவம் அல்ல.",
        .biofeedbackDisclaimerDetail: "Echoelmusic ஒரு படைப்பாற்றல் கருவி. இது எந்த நிலையையும் கண்டறிவதில்லை, சிகிச்சையளிப்பதில்லை அல்லது குணப்படுத்துவதில்லை. மருத்துவ கவலைகளுக்கு எப்போதும் சுகாதார நிபுணர்களை அணுகவும்.",

        // Help Offers
        .helpHesitation1: "அவசரப்படாதீர்கள். சிறிது வழிகாட்டுதல் வேண்டுமா?",
        .helpHesitation2: "அவசரம் இல்லை. குறிப்பு தேவைப்பட்டால் இங்கே இருக்கிறேன்.",
        .helpHesitation3: "நீங்கள் தயாராகும்போது. உதவி தேவையா?",
        .helpUserRequested: "நான் உங்களுக்கு எப்படி உதவ முடியும்?",

        // UI Elements
        .dismiss: "மூடு",
        .learnMore: "மேலும் அறிக",
        .gotIt: "புரிந்தது",
        .showMe: "காட்டு",
        .skip: "தவிர்",
        .next: "அடுத்து",
        .previous: "முந்தைய",
        .close: "மூடு",
        .help: "உதவி",
        .settings: "அமைப்புகள்"
    ]

    // MARK: - Telugu (South India - 80M+ Speakers)

    private static let telugu: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "హలో, నేను ఎకోయెలా",
        .welcomeDescription: "Echoelmusic అన్వేషించడంలో మీకు సహాయం చేయడానికి నేను ఇక్కడ ఉన్నాను. మీకు అవసరమైనప్పుడు సున్నితమైన మార్గదర్శకత్వం అందిస్తాను, కానీ మీరు ఎల్లప్పుడూ నియంత్రణలో ఉంటారు.",
        .welcomeOptional: "నేను ఐచ్ఛికం",
        .welcomeOptionalDesc: "సెట్టింగ్స్‌లో ఎప్పుడైనా నన్ను ఆఫ్ చేయవచ్చు. నేను బాధపడను.",
        .welcomeLearnStyle: "నేను మీ శైలిని నేర్చుకుంటాను",
        .welcomeLearnStyleDesc: "మీరు యాప్ ఉపయోగించినప్పుడు, మీకు ధైర్యం ఉన్నప్పుడు తక్కువ మార్గదర్శకత్వం, కొత్త విషయాలకు ఎక్కువ ఇస్తాను.",
        .welcomeNoRush: "నేను ఎప్పుడూ తొందరపెట్టను",
        .welcomeNoRushDesc: "టైమర్లు, స్కోర్లు లేదా ఒత్తిడి లేవు. మీకు అవసరమైన సమయం తీసుకోండి.",
        .welcomeAskAnytime: "ఎప్పుడైనా అడగండి",
        .welcomeAskAnytimeDesc: "సహాయం అవసరమైతే, ఎకోయెలా బటన్ నొక్కండి లేదా మెరుపు ఐకాన్ చూడండి.",

        // General Help
        .generalHelpTitle: "నేను ఎలా సహాయం చేయగలను?",
        .generalHelpDescription: "మరింత తెలుసుకోవడానికి టాపిక్ ఎంచుకోండి. మీరు ఎల్లప్పుడూ ఇక్కడికి తిరిగి రావచ్చు.",

        // Biofeedback
        .biofeedbackTitle: "బయోఫీడ్‌బ్యాక్",
        .biofeedbackDescription: "మీ శరీరం సంగీతంతో ఎలా కనెక్ట్ అవుతుందో తెలుసుకోండి.",
        .biofeedbackDisclaimer: "ముఖ్యం: ఇది కళ, వైద్యం కాదు.",
        .biofeedbackDisclaimerDetail: "Echoelmusic సృజనాత్మక సాధనం. ఇది ఏ పరిస్థితినీ నిర్ధారించదు, చికిత్స చేయదు లేదా నయం చేయదు. వైద్య సమస్యలకు ఎల్లప్పుడూ ఆరోగ్య నిపుణులను సంప్రదించండి.",

        // Help Offers
        .helpHesitation1: "తొందరపడకండి. కొంచెం మార్గదర్శకత్వం కావాలా?",
        .helpHesitation2: "తొందర లేదు. హింట్ అవసరమైతే నేను ఇక్కడ ఉన్నాను.",
        .helpHesitation3: "మీరు సిద్ధంగా ఉన్నప్పుడు. సహాయం కావాలా?",
        .helpUserRequested: "నేను మీకు ఎలా సహాయం చేయగలను?",

        // UI Elements
        .dismiss: "మూసివేయి",
        .learnMore: "మరింత తెలుసుకోండి",
        .gotIt: "అర్థమైంది",
        .showMe: "చూపించు",
        .skip: "దాటవేయి",
        .next: "తదుపరి",
        .previous: "మునుపటి",
        .close: "మూసివేయి",
        .help: "సహాయం",
        .settings: "సెట్టింగ్స్"
    ]

    // MARK: - Marathi (India - 90M+ Speakers)

    private static let marathi: [LocalizationKey: String] = [
        // Welcome
        .welcomeTitle: "नमस्कार, मी इकोएला आहे",
        .welcomeDescription: "Echoelmusic शोधण्यात तुम्हाला मदत करण्यासाठी मी येथे आहे. तुम्हाला गरज असेल तेव्हा मी सौम्य मार्गदर्शन देईन, पण तुम्ही नेहमी नियंत्रणात असता.",
        .welcomeOptional: "मी पर्यायी आहे",
        .welcomeOptionalDesc: "तुम्ही सेटिंग्जमध्ये कधीही मला बंद करू शकता. मला राग येणार नाही.",
        .welcomeLearnStyle: "मी तुमची शैली शिकतो",
        .welcomeLearnStyleDesc: "तुम्ही अॅप वापरता तेव्हा, तुम्ही आत्मविश्वासी असाल तेव्हा कमी मार्गदर्शन आणि नवीन गोष्टींसाठी जास्त देईन.",
        .welcomeNoRush: "मी कधीही घाई करत नाही",
        .welcomeNoRushDesc: "टायमर नाहीत, स्कोअर नाहीत किंवा दबाव नाही. तुम्हाला हवा तेवढा वेळ घ्या.",
        .welcomeAskAnytime: "कधीही विचारा",
        .welcomeAskAnytimeDesc: "मदत हवी असल्यास, फक्त इकोएला बटण दाबा किंवा चमकणारा आयकॉन शोधा.",

        // General Help
        .generalHelpTitle: "मी कशी मदत करू शकतो?",
        .generalHelpDescription: "अधिक जाणून घेण्यासाठी विषय निवडा. तुम्ही नेहमी येथे परत येऊ शकता.",

        // Biofeedback
        .biofeedbackTitle: "बायोफीडबॅक",
        .biofeedbackDescription: "तुमचे शरीर संगीताशी कसे जोडले जाते ते जाणून घ्या.",
        .biofeedbackDisclaimer: "महत्त्वाचे: ही कला आहे, औषध नाही.",
        .biofeedbackDisclaimerDetail: "Echoelmusic हे सर्जनशील साधन आहे. ते कोणत्याही स्थितीचे निदान, उपचार किंवा बरे करत नाही. वैद्यकीय चिंतांसाठी नेहमी आरोग्य व्यावसायिकांचा सल्ला घ्या.",

        // Help Offers
        .helpHesitation1: "घाई करू नका. थोडे मार्गदर्शन हवे?",
        .helpHesitation2: "घाई नाही. इशारा हवा असल्यास मी येथे आहे.",
        .helpHesitation3: "तुम्ही तयार असताना. मदत हवी?",
        .helpUserRequested: "मी तुम्हाला कशी मदत करू शकतो?",

        // UI Elements
        .dismiss: "बंद करा",
        .learnMore: "अधिक जाणून घ्या",
        .gotIt: "समजले",
        .showMe: "दाखवा",
        .skip: "वगळा",
        .next: "पुढे",
        .previous: "मागील",
        .close: "बंद करा",
        .help: "मदत",
        .settings: "सेटिंग्ज"
    ]
}
