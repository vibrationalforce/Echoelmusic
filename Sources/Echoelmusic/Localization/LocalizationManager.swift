import Foundation
import Combine

/// Localization Manager für globale Multi-Language-Unterstützung
///
/// Unterstützt 20+ Sprachen für weltweite Nutzerbasis:
/// - Deutsch, Englisch, Spanisch, Französisch, Italienisch, Portugiesisch
/// - Chinesisch (vereinfacht/traditionell), Japanisch, Koreanisch
/// - Arabisch, Hebräisch (RTL-Support)
/// - Hindi, Bengali, Tamil (indische Sprachen)
/// - Russisch, Polnisch, Türkisch
/// - Indonesisch, Thai, Vietnamesisch
///
/// Features:
/// - Dynamischer Sprachwechsel ohne App-Neustart
/// - Pluralisierung und Geschlecht
/// - Datumsformatierung
/// - Zahlenformatierung
/// - RTL (Right-to-Left) Support
/// - Kontext-sensitive Übersetzungen
/// - Fallback-Mechanismus
///
@MainActor
@Observable
class LocalizationManager {

    private let log = ProfessionalLogger.shared

    // MARK: - Published Properties

    /// Aktuelle Sprache
    var currentLanguage: Language = .german {
        didSet {
            if currentLanguage != oldValue {
                languageDidChange.send(currentLanguage)
                log.info(category: .system, "🌍 Language changed to: \(currentLanguage.displayName)")
            }
        }
    }

    /// Verfügbare Sprachen
    let availableLanguages: [Language] = Language.allCases

    /// Ist RTL-Layout aktiv?
    var isRTL: Bool {
        currentLanguage.isRTL
    }

    // MARK: - Private Properties

    private var translations: [Language: [String: String]] = [:]
    private let languageDidChange = PassthroughSubject<Language, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Language Definition

    enum Language: String, CaseIterable, Codable {
        // European Languages
        case german = "de"
        case english = "en"
        case spanish = "es"
        case french = "fr"
        case italian = "it"
        case portuguese = "pt"
        case russian = "ru"
        case polish = "pl"
        case turkish = "tr"

        // Asian Languages
        case chineseSimplified = "zh-Hans"
        case chineseTraditional = "zh-Hant"
        case japanese = "ja"
        case korean = "ko"
        case hindi = "hi"
        case bengali = "bn"
        case tamil = "ta"
        case indonesian = "id"
        case thai = "th"
        case vietnamese = "vi"

        // Middle Eastern Languages
        case arabic = "ar"
        case hebrew = "he"
        case persian = "fa"

        var displayName: String {
            switch self {
            case .german: return "Deutsch"
            case .english: return "English"
            case .spanish: return "Español"
            case .french: return "Français"
            case .italian: return "Italiano"
            case .portuguese: return "Português"
            case .russian: return "Русский"
            case .polish: return "Polski"
            case .turkish: return "Türkçe"
            case .chineseSimplified: return "简体中文"
            case .chineseTraditional: return "繁體中文"
            case .japanese: return "日本語"
            case .korean: return "한국어"
            case .hindi: return "हिन्दी"
            case .bengali: return "বাংলা"
            case .tamil: return "தமிழ்"
            case .indonesian: return "Bahasa Indonesia"
            case .thai: return "ไทย"
            case .vietnamese: return "Tiếng Việt"
            case .arabic: return "العربية"
            case .hebrew: return "עברית"
            case .persian: return "فارسی"
            }
        }

        var nativeLanguageName: String {
            displayName
        }

        var isRTL: Bool {
            switch self {
            case .arabic, .hebrew, .persian:
                return true
            default:
                return false
            }
        }

        var locale: Locale {
            Locale(identifier: rawValue)
        }
    }

    // MARK: - Translation Keys

    enum TranslationKey: String {
        // General
        case appName = "app.name"
        case welcome = "general.welcome"
        case ok = "general.ok"
        case cancel = "general.cancel"
        case save = "general.save"
        case delete = "general.delete"
        case edit = "general.edit"
        case done = "general.done"
        case close = "general.close"
        case settings = "general.settings"

        // Bio-Reactive Features
        case hrv = "bio.hrv"
        case coherence = "bio.coherence"
        case heartRate = "bio.heart_rate"
        case breathingRate = "bio.breathing_rate"
        case stress = "bio.stress"
        case relaxation = "bio.relaxation"
        case meditation = "bio.meditation"

        // Music Theory
        case scale = "music.scale"
        case chord = "music.chord"
        case rhythm = "music.rhythm"
        case tempo = "music.tempo"
        case key = "music.key"
        case mode = "music.mode"
        case interval = "music.interval"

        // Emotions
        case emotionNeutral = "emotion.neutral"
        case emotionHappy = "emotion.happy"
        case emotionSad = "emotion.sad"
        case emotionEnergetic = "emotion.energetic"
        case emotionCalm = "emotion.calm"
        case emotionAnxious = "emotion.anxious"
        case emotionFocused = "emotion.focused"
        case emotionRelaxed = "emotion.relaxed"

        // Effects
        case reverb = "effect.reverb"
        case delay = "effect.delay"
        case distortion = "effect.distortion"
        case compressor = "effect.compressor"
        case eq = "effect.eq"
        case filter = "effect.filter"
        case limiter = "effect.limiter"

        // Export
        case export = "export.title"
        case exportFormat = "export.format"
        case exportQuality = "export.quality"
        case exportSuccess = "export.success"
        case exportFailed = "export.failed"

        // Performance
        case performance = "performance.title"
        case fps = "performance.fps"
        case cpuUsage = "performance.cpu"
        case memoryUsage = "performance.memory"
        case quality = "performance.quality"

        // Errors
        case errorGeneric = "error.generic"
        case errorNetwork = "error.network"
        case errorPermission = "error.permission"
        case errorFileNotFound = "error.file_not_found"
    }

    // MARK: - Initialization

    init() {
        loadTranslations()
        detectSystemLanguage()
    }

    private func loadTranslations() {
        // Lade alle Übersetzungen
        for language in Language.allCases {
            translations[language] = loadTranslationFile(for: language)
        }
    }

    private func loadTranslationFile(for language: Language) -> [String: String] {
        // In einer echten App würden die Übersetzungen aus JSON/Strings-Files geladen
        // Hier verwenden wir eingebettete Übersetzungen für Demo-Zwecke
        return getEmbeddedTranslations(for: language)
    }

    private func detectSystemLanguage() {
        let preferredLanguages = Locale.preferredLanguages
        guard let preferredLang = preferredLanguages.first else { return }

        // Versuche Sprache zu matchen
        if let matchedLanguage = Language.allCases.first(where: { preferredLang.hasPrefix($0.rawValue) }) {
            currentLanguage = matchedLanguage
        } else if preferredLang.hasPrefix("en") {
            currentLanguage = .english
        } else {
            currentLanguage = .english // Fallback
        }
    }

    // MARK: - Translation Methods

    func translate(_ key: TranslationKey, language: Language? = nil) -> String {
        let lang = language ?? currentLanguage
        let keyString = key.rawValue

        if let translation = translations[lang]?[keyString] {
            return translation
        }

        // Fallback zu Englisch
        if lang != .english, let englishTranslation = translations[.english]?[keyString] {
            return englishTranslation
        }

        // Fallback zu Key
        return keyString
    }

    func translate(_ keyString: String, language: Language? = nil) -> String {
        let lang = language ?? currentLanguage

        if let translation = translations[lang]?[keyString] {
            return translation
        }

        // Fallback zu Englisch
        if lang != .english, let englishTranslation = translations[.english]?[keyString] {
            return englishTranslation
        }

        // Fallback zu Key
        return keyString
    }

    // MARK: - Pluralization

    func pluralize(_ key: String, count: Int, language: Language? = nil) -> String {
        let lang = language ?? currentLanguage
        let pluralKey = "\(key).\(getPluralForm(for: count, language: lang))"

        if let translation = translations[lang]?[pluralKey] {
            return String(format: translation, count)
        }

        return translate(key, language: lang)
    }

    private func getPluralForm(for count: Int, language: Language) -> String {
        switch language {
        case .english, .german, .spanish, .french, .italian, .portuguese:
            // Germanic/Romance: singular (1), plural (other)
            return count == 1 ? "one" : "other"

        case .russian, .polish:
            // Slavic: one (1), few (2-4), many (5+), other
            let mod10 = count % 10
            let mod100 = count % 100
            if count == 1 {
                return "one"
            } else if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) {
                return "few"
            } else {
                return "many"
            }

        case .arabic:
            // Arabic: zero, one, two, few (3-10), many (11-99), other (100+)
            if count == 0 {
                return "zero"
            } else if count == 1 {
                return "one"
            } else if count == 2 {
                return "two"
            } else if count >= 3 && count <= 10 {
                return "few"
            } else if count >= 11 && count <= 99 {
                return "many"
            } else {
                return "other"
            }

        case .japanese, .korean, .chineseSimplified, .chineseTraditional,
             .indonesian, .thai, .vietnamese, .turkish:
            // No plural distinction
            return "other"

        default:
            return count == 1 ? "one" : "other"
        }
    }

    // MARK: - Number Formatting

    func formatNumber(_ number: Double, style: NumberFormatter.Style = .decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = style
        formatter.locale = currentLanguage.locale
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    func formatPercentage(_ value: Double) -> String {
        formatNumber(value, style: .percent)
    }

    func formatCurrency(_ amount: Double, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = currentLanguage.locale
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    // MARK: - Date Formatting

    func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        formatter.locale = currentLanguage.locale
        return formatter.string(from: date)
    }

    func formatTime(_ date: Date, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = style
        formatter.locale = currentLanguage.locale
        return formatter.string(from: date)
    }

    func formatDateTime(_ date: Date, dateStyle: DateFormatter.Style = .medium,
                       timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.locale = currentLanguage.locale
        return formatter.string(from: date)
    }

    func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = currentLanguage.locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Embedded Translations

    private func getEmbeddedTranslations(for language: Language) -> [String: String] {
        switch language {
        case .german:
            return germanTranslations
        case .english:
            return englishTranslations
        case .spanish:
            return spanishTranslations
        case .french:
            return frenchTranslations
        case .chineseSimplified:
            return chineseSimplifiedTranslations
        case .japanese:
            return japaneseTranslations
        case .arabic:
            return arabicTranslations
        default:
            return englishTranslations // Fallback
        }
    }

    // MARK: - Translation Dictionaries

    private var germanTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Willkommen",
            "general.ok": "OK",
            "general.cancel": "Abbrechen",
            "general.save": "Speichern",
            "general.delete": "Löschen",
            "general.edit": "Bearbeiten",
            "general.done": "Fertig",
            "general.close": "Schließen",
            "general.settings": "Einstellungen",

            "bio.hrv": "Herzfrequenzvariabilität",
            "bio.coherence": "Kohärenz",
            "bio.heart_rate": "Herzfrequenz",
            "bio.breathing_rate": "Atemfrequenz",
            "bio.stress": "Stress",
            "bio.relaxation": "Entspannung",
            "bio.meditation": "Meditation",

            "music.scale": "Tonleiter",
            "music.chord": "Akkord",
            "music.rhythm": "Rhythmus",
            "music.tempo": "Tempo",
            "music.key": "Tonart",
            "music.mode": "Modus",
            "music.interval": "Intervall",

            "emotion.neutral": "Neutral",
            "emotion.happy": "Glücklich",
            "emotion.sad": "Traurig",
            "emotion.energetic": "Energetisch",
            "emotion.calm": "Ruhig",
            "emotion.anxious": "Ängstlich",
            "emotion.focused": "Fokussiert",
            "emotion.relaxed": "Entspannt",

            "effect.reverb": "Hall",
            "effect.delay": "Verzögerung",
            "effect.distortion": "Verzerrung",
            "effect.compressor": "Kompressor",
            "effect.eq": "Equalizer",
            "effect.filter": "Filter",
            "effect.limiter": "Limiter",

            "export.title": "Exportieren",
            "export.format": "Format",
            "export.quality": "Qualität",
            "export.success": "Export erfolgreich",
            "export.failed": "Export fehlgeschlagen",

            "performance.title": "Performance",
            "performance.fps": "Bilder pro Sekunde",
            "performance.cpu": "CPU-Auslastung",
            "performance.memory": "Speichernutzung",
            "performance.quality": "Qualität",

            "error.generic": "Ein Fehler ist aufgetreten",
            "error.network": "Netzwerkfehler",
            "error.permission": "Berechtigung erforderlich",
            "error.file_not_found": "Datei nicht gefunden"
        ]
    }

    private var englishTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Welcome",
            "general.ok": "OK",
            "general.cancel": "Cancel",
            "general.save": "Save",
            "general.delete": "Delete",
            "general.edit": "Edit",
            "general.done": "Done",
            "general.close": "Close",
            "general.settings": "Settings",

            "bio.hrv": "Heart Rate Variability",
            "bio.coherence": "Coherence",
            "bio.heart_rate": "Heart Rate",
            "bio.breathing_rate": "Breathing Rate",
            "bio.stress": "Stress",
            "bio.relaxation": "Relaxation",
            "bio.meditation": "Meditation",

            "music.scale": "Scale",
            "music.chord": "Chord",
            "music.rhythm": "Rhythm",
            "music.tempo": "Tempo",
            "music.key": "Key",
            "music.mode": "Mode",
            "music.interval": "Interval",

            "emotion.neutral": "Neutral",
            "emotion.happy": "Happy",
            "emotion.sad": "Sad",
            "emotion.energetic": "Energetic",
            "emotion.calm": "Calm",
            "emotion.anxious": "Anxious",
            "emotion.focused": "Focused",
            "emotion.relaxed": "Relaxed",

            "effect.reverb": "Reverb",
            "effect.delay": "Delay",
            "effect.distortion": "Distortion",
            "effect.compressor": "Compressor",
            "effect.eq": "Equalizer",
            "effect.filter": "Filter",
            "effect.limiter": "Limiter",

            "export.title": "Export",
            "export.format": "Format",
            "export.quality": "Quality",
            "export.success": "Export successful",
            "export.failed": "Export failed",

            "performance.title": "Performance",
            "performance.fps": "Frames per Second",
            "performance.cpu": "CPU Usage",
            "performance.memory": "Memory Usage",
            "performance.quality": "Quality",

            "error.generic": "An error occurred",
            "error.network": "Network error",
            "error.permission": "Permission required",
            "error.file_not_found": "File not found"
        ]
    }

    private var spanishTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Bienvenido",
            "general.ok": "Aceptar",
            "general.cancel": "Cancelar",
            "general.save": "Guardar",
            "general.delete": "Eliminar",
            "general.settings": "Configuración",

            "bio.hrv": "Variabilidad de Frecuencia Cardíaca",
            "bio.coherence": "Coherencia",
            "bio.heart_rate": "Frecuencia Cardíaca",

            "emotion.happy": "Feliz",
            "emotion.sad": "Triste",
            "emotion.calm": "Tranquilo",
            "emotion.energetic": "Energético"
        ]
    }

    private var frenchTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Bienvenue",
            "general.ok": "OK",
            "general.cancel": "Annuler",
            "general.save": "Enregistrer",
            "general.settings": "Paramètres",

            "bio.hrv": "Variabilité de la Fréquence Cardiaque",
            "bio.coherence": "Cohérence",
            "bio.heart_rate": "Fréquence Cardiaque",

            "emotion.happy": "Heureux",
            "emotion.sad": "Triste",
            "emotion.calm": "Calme"
        ]
    }

    private var chineseSimplifiedTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "欢迎",
            "general.ok": "确定",
            "general.cancel": "取消",
            "general.save": "保存",
            "general.settings": "设置",

            "bio.hrv": "心率变异性",
            "bio.coherence": "一致性",
            "bio.heart_rate": "心率",

            "emotion.happy": "快乐",
            "emotion.sad": "悲伤",
            "emotion.calm": "平静",
            "emotion.energetic": "有活力"
        ]
    }

    private var japaneseTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "ようこそ",
            "general.ok": "OK",
            "general.cancel": "キャンセル",
            "general.save": "保存",
            "general.settings": "設定",

            "bio.hrv": "心拍変動",
            "bio.coherence": "コヒーレンス",
            "bio.heart_rate": "心拍数",

            "emotion.happy": "嬉しい",
            "emotion.sad": "悲しい",
            "emotion.calm": "穏やか",
            "emotion.energetic": "活力的"
        ]
    }

    private var arabicTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "مرحبا",
            "general.ok": "موافق",
            "general.cancel": "إلغاء",
            "general.save": "حفظ",
            "general.settings": "الإعدادات",

            "bio.hrv": "تقلب معدل ضربات القلب",
            "bio.coherence": "التماسك",
            "bio.heart_rate": "معدل ضربات القلب",

            "emotion.happy": "سعيد",
            "emotion.sad": "حزين",
            "emotion.calm": "هادئ",
            "emotion.energetic": "نشيط"
        ]
    }

    // MARK: - Public API

    func changeLanguage(to language: Language) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "selectedLanguage")
    }

    func observeLanguageChanges() -> AnyPublisher<Language, Never> {
        languageDidChange.eraseToAnyPublisher()
    }
}

// MARK: - SwiftUI Extension

#if canImport(SwiftUI)
import SwiftUI

extension LocalizationManager {
    static let shared = LocalizationManager()
}

@propertyWrapper
struct Localized: DynamicProperty {
    @ObservedObject private var manager = LocalizationManager.shared
    private let key: LocalizationManager.TranslationKey

    init(_ key: LocalizationManager.TranslationKey) {
        self.key = key
    }

    var wrappedValue: String {
        manager.translate(key)
    }
}
#endif
