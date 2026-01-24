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
class LocalizationManager: ObservableObject {

    private let log = ProfessionalLogger.shared

    // MARK: - Published Properties

    /// Aktuelle Sprache
    @Published var currentLanguage: Language = .german {
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
        case indonesian = "id"      // Indonesia - Largest SE Asian market
        case thai = "th"
        case vietnamese = "vi"

        // Middle Eastern Languages
        case arabic = "ar"
        case hebrew = "he"
        case persian = "fa"

        // Tier 5: Strategic Expansion (NEW - 12 Languages)
        case malay = "ms"           // Malaysia/Singapore
        case finnish = "fi"         // Finland - Nordic completion
        case greek = "el"           // Greece - Mediterranean
        case czech = "cs"           // Czech Republic - Central Europe
        case romanian = "ro"        // Romania - Eastern Europe
        case hungarian = "hu"       // Hungary - Central Europe
        case ukrainian = "uk"       // Ukraine - Eastern Europe
        case filipino = "tl"        // Philippines - Large market
        case swahili = "sw"         // East Africa - Growing market
        case telugu = "te"          // South India - 80M+ speakers
        case marathi = "mr"         // India - 90M+ speakers

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
            // Tier 5: Strategic Expansion
            case .malay: return "Bahasa Melayu"
            case .finnish: return "Suomi"
            case .greek: return "Ελληνικά"
            case .czech: return "Čeština"
            case .romanian: return "Română"
            case .hungarian: return "Magyar"
            case .ukrainian: return "Українська"
            case .filipino: return "Filipino"
            case .swahili: return "Kiswahili"
            case .telugu: return "తెలుగు"
            case .marathi: return "मराठी"
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

        case .russian, .polish, .ukrainian:
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

        case .czech:
            // Czech: one (1), few (2-4), other
            if count == 1 {
                return "one"
            } else if count >= 2 && count <= 4 {
                return "few"
            } else {
                return "other"
            }

        case .romanian:
            // Romanian: one (1), few (0, 2-19, 101-119...), other
            let mod100 = count % 100
            if count == 1 {
                return "one"
            } else if count == 0 || (mod100 >= 2 && mod100 <= 19) {
                return "few"
            } else {
                return "other"
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
             .indonesian, .malay, .thai, .vietnamese, .turkish, .hungarian,
             .filipino, .swahili, .telugu, .marathi:
            // No plural distinction (or two-form languages that use other)
            return "other"

        case .finnish, .greek:
            // Finnish/Greek: singular (1), plural (other)
            return count == 1 ? "one" : "other"

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
        case .korean:
            return koreanTranslations
        case .portuguese:
            return portugueseTranslations
        case .italian:
            return italianTranslations
        case .russian:
            return russianTranslations
        case .hindi:
            return hindiTranslations
        // Additional Core Languages
        case .polish:
            return polishTranslations
        case .turkish:
            return turkishTranslations
        case .chineseTraditional:
            return chineseTraditionalTranslations
        case .bengali:
            return bengaliTranslations
        case .tamil:
            return tamilTranslations
        case .thai:
            return thaiTranslations
        case .vietnamese:
            return vietnameseTranslations
        case .hebrew:
            return hebrewTranslations
        case .persian:
            return persianTranslations
        // Tier 5: Strategic Expansion
        case .indonesian:
            return indonesianTranslations
        case .malay:
            return malayTranslations
        case .finnish:
            return finnishTranslations
        case .greek:
            return greekTranslations
        case .czech:
            return czechTranslations
        case .romanian:
            return romanianTranslations
        case .hungarian:
            return hungarianTranslations
        case .ukrainian:
            return ukrainianTranslations
        case .filipino:
            return filipinoTranslations
        case .swahili:
            return swahiliTranslations
        case .telugu:
            return teluguTranslations
        case .marathi:
            return marathiTranslations
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
            "general.delete": "حذف",
            "general.edit": "تعديل",
            "general.done": "تم",
            "general.close": "إغلاق",
            "general.settings": "الإعدادات",

            "bio.hrv": "تقلب معدل ضربات القلب",
            "bio.coherence": "التماسك",
            "bio.heart_rate": "معدل ضربات القلب",
            "bio.breathing_rate": "معدل التنفس",
            "bio.stress": "التوتر",
            "bio.relaxation": "الاسترخاء",
            "bio.meditation": "التأمل",

            "emotion.neutral": "محايد",
            "emotion.happy": "سعيد",
            "emotion.sad": "حزين",
            "emotion.calm": "هادئ",
            "emotion.energetic": "نشيط",
            "emotion.anxious": "قلق",
            "emotion.focused": "مركز",
            "emotion.relaxed": "مرتاح"
        ]
    }

    private var koreanTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "환영합니다",
            "general.ok": "확인",
            "general.cancel": "취소",
            "general.save": "저장",
            "general.delete": "삭제",
            "general.edit": "편집",
            "general.done": "완료",
            "general.close": "닫기",
            "general.settings": "설정",

            "bio.hrv": "심박변이도",
            "bio.coherence": "일관성",
            "bio.heart_rate": "심박수",
            "bio.breathing_rate": "호흡수",
            "bio.stress": "스트레스",
            "bio.relaxation": "휴식",
            "bio.meditation": "명상",

            "music.scale": "음계",
            "music.chord": "화음",
            "music.rhythm": "리듬",
            "music.tempo": "템포",
            "music.key": "키",
            "music.mode": "모드",
            "music.interval": "음정",

            "emotion.neutral": "중립",
            "emotion.happy": "행복",
            "emotion.sad": "슬픔",
            "emotion.energetic": "활력",
            "emotion.calm": "차분함",
            "emotion.anxious": "불안",
            "emotion.focused": "집중",
            "emotion.relaxed": "편안함",

            "effect.reverb": "리버브",
            "effect.delay": "딜레이",
            "effect.distortion": "디스토션",
            "effect.compressor": "컴프레서",
            "effect.eq": "이퀄라이저",
            "effect.filter": "필터",
            "effect.limiter": "리미터",

            "export.title": "내보내기",
            "export.format": "형식",
            "export.quality": "품질",
            "export.success": "내보내기 성공",
            "export.failed": "내보내기 실패",

            "error.generic": "오류가 발생했습니다",
            "error.network": "네트워크 오류",
            "error.permission": "권한이 필요합니다",
            "error.file_not_found": "파일을 찾을 수 없습니다"
        ]
    }

    private var portugueseTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Bem-vindo",
            "general.ok": "OK",
            "general.cancel": "Cancelar",
            "general.save": "Salvar",
            "general.delete": "Excluir",
            "general.edit": "Editar",
            "general.done": "Concluído",
            "general.close": "Fechar",
            "general.settings": "Configurações",

            "bio.hrv": "Variabilidade da Frequência Cardíaca",
            "bio.coherence": "Coerência",
            "bio.heart_rate": "Frequência Cardíaca",
            "bio.breathing_rate": "Taxa Respiratória",
            "bio.stress": "Estresse",
            "bio.relaxation": "Relaxamento",
            "bio.meditation": "Meditação",

            "music.scale": "Escala",
            "music.chord": "Acorde",
            "music.rhythm": "Ritmo",
            "music.tempo": "Tempo",
            "music.key": "Tom",
            "music.mode": "Modo",
            "music.interval": "Intervalo",

            "emotion.neutral": "Neutro",
            "emotion.happy": "Feliz",
            "emotion.sad": "Triste",
            "emotion.energetic": "Energético",
            "emotion.calm": "Calmo",
            "emotion.anxious": "Ansioso",
            "emotion.focused": "Focado",
            "emotion.relaxed": "Relaxado",

            "effect.reverb": "Reverb",
            "effect.delay": "Delay",
            "effect.distortion": "Distorção",
            "effect.compressor": "Compressor",
            "effect.eq": "Equalizador",
            "effect.filter": "Filtro",
            "effect.limiter": "Limitador",

            "export.title": "Exportar",
            "export.format": "Formato",
            "export.quality": "Qualidade",
            "export.success": "Exportação bem-sucedida",
            "export.failed": "Falha na exportação",

            "error.generic": "Ocorreu um erro",
            "error.network": "Erro de rede",
            "error.permission": "Permissão necessária",
            "error.file_not_found": "Arquivo não encontrado"
        ]
    }

    private var italianTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Benvenuto",
            "general.ok": "OK",
            "general.cancel": "Annulla",
            "general.save": "Salva",
            "general.delete": "Elimina",
            "general.edit": "Modifica",
            "general.done": "Fine",
            "general.close": "Chiudi",
            "general.settings": "Impostazioni",

            "bio.hrv": "Variabilità della Frequenza Cardiaca",
            "bio.coherence": "Coerenza",
            "bio.heart_rate": "Frequenza Cardiaca",
            "bio.breathing_rate": "Frequenza Respiratoria",
            "bio.stress": "Stress",
            "bio.relaxation": "Rilassamento",
            "bio.meditation": "Meditazione",

            "music.scale": "Scala",
            "music.chord": "Accordo",
            "music.rhythm": "Ritmo",
            "music.tempo": "Tempo",
            "music.key": "Tonalità",
            "music.mode": "Modo",
            "music.interval": "Intervallo",

            "emotion.neutral": "Neutrale",
            "emotion.happy": "Felice",
            "emotion.sad": "Triste",
            "emotion.energetic": "Energico",
            "emotion.calm": "Calmo",
            "emotion.anxious": "Ansioso",
            "emotion.focused": "Concentrato",
            "emotion.relaxed": "Rilassato",

            "effect.reverb": "Riverbero",
            "effect.delay": "Delay",
            "effect.distortion": "Distorsione",
            "effect.compressor": "Compressore",
            "effect.eq": "Equalizzatore",
            "effect.filter": "Filtro",
            "effect.limiter": "Limitatore",

            "export.title": "Esporta",
            "export.format": "Formato",
            "export.quality": "Qualità",
            "export.success": "Esportazione riuscita",
            "export.failed": "Esportazione fallita",

            "error.generic": "Si è verificato un errore",
            "error.network": "Errore di rete",
            "error.permission": "Autorizzazione richiesta",
            "error.file_not_found": "File non trovato"
        ]
    }

    private var russianTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Добро пожаловать",
            "general.ok": "ОК",
            "general.cancel": "Отмена",
            "general.save": "Сохранить",
            "general.delete": "Удалить",
            "general.edit": "Редактировать",
            "general.done": "Готово",
            "general.close": "Закрыть",
            "general.settings": "Настройки",

            "bio.hrv": "Вариабельность сердечного ритма",
            "bio.coherence": "Когерентность",
            "bio.heart_rate": "Частота сердечных сокращений",
            "bio.breathing_rate": "Частота дыхания",
            "bio.stress": "Стресс",
            "bio.relaxation": "Расслабление",
            "bio.meditation": "Медитация",

            "music.scale": "Гамма",
            "music.chord": "Аккорд",
            "music.rhythm": "Ритм",
            "music.tempo": "Темп",
            "music.key": "Тональность",
            "music.mode": "Лад",
            "music.interval": "Интервал",

            "emotion.neutral": "Нейтральный",
            "emotion.happy": "Счастливый",
            "emotion.sad": "Грустный",
            "emotion.energetic": "Энергичный",
            "emotion.calm": "Спокойный",
            "emotion.anxious": "Тревожный",
            "emotion.focused": "Сосредоточенный",
            "emotion.relaxed": "Расслабленный",

            "effect.reverb": "Реверберация",
            "effect.delay": "Задержка",
            "effect.distortion": "Дисторшн",
            "effect.compressor": "Компрессор",
            "effect.eq": "Эквалайзер",
            "effect.filter": "Фильтр",
            "effect.limiter": "Лимитер",

            "export.title": "Экспорт",
            "export.format": "Формат",
            "export.quality": "Качество",
            "export.success": "Экспорт выполнен",
            "export.failed": "Ошибка экспорта",

            "error.generic": "Произошла ошибка",
            "error.network": "Ошибка сети",
            "error.permission": "Требуется разрешение",
            "error.file_not_found": "Файл не найден"
        ]
    }

    private var hindiTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "स्वागत है",
            "general.ok": "ठीक है",
            "general.cancel": "रद्द करें",
            "general.save": "सहेजें",
            "general.delete": "हटाएं",
            "general.edit": "संपादित करें",
            "general.done": "हो गया",
            "general.close": "बंद करें",
            "general.settings": "सेटिंग्स",

            "bio.hrv": "हृदय गति परिवर्तनशीलता",
            "bio.coherence": "सुसंगति",
            "bio.heart_rate": "हृदय गति",
            "bio.breathing_rate": "श्वास दर",
            "bio.stress": "तनाव",
            "bio.relaxation": "विश्राम",
            "bio.meditation": "ध्यान",

            "music.scale": "स्केल",
            "music.chord": "तार",
            "music.rhythm": "ताल",
            "music.tempo": "गति",
            "music.key": "सुर",
            "music.mode": "मोड",
            "music.interval": "अंतराल",

            "emotion.neutral": "तटस्थ",
            "emotion.happy": "खुश",
            "emotion.sad": "उदास",
            "emotion.energetic": "ऊर्जावान",
            "emotion.calm": "शांत",
            "emotion.anxious": "चिंतित",
            "emotion.focused": "केंद्रित",
            "emotion.relaxed": "तनावमुक्त",

            "effect.reverb": "रिवर्ब",
            "effect.delay": "डिले",
            "effect.distortion": "डिस्टॉर्शन",
            "effect.compressor": "कंप्रेसर",
            "effect.eq": "इक्वलाइज़र",
            "effect.filter": "फ़िल्टर",
            "effect.limiter": "लिमिटर",

            "export.title": "निर्यात",
            "export.format": "प्रारूप",
            "export.quality": "गुणवत्ता",
            "export.success": "निर्यात सफल",
            "export.failed": "निर्यात विफल",

            "error.generic": "एक त्रुटि हुई",
            "error.network": "नेटवर्क त्रुटि",
            "error.permission": "अनुमति आवश्यक",
            "error.file_not_found": "फ़ाइल नहीं मिली"
        ]
    }

    // MARK: - Polish Translations

    private var polishTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Witamy",
            "general.ok": "OK",
            "general.cancel": "Anuluj",
            "general.save": "Zapisz",
            "general.delete": "Usuń",
            "general.edit": "Edytuj",
            "general.done": "Gotowe",
            "general.close": "Zamknij",
            "general.settings": "Ustawienia",

            "bio.hrv": "Zmienność rytmu serca",
            "bio.coherence": "Koherencja",
            "bio.heart_rate": "Tętno",
            "bio.breathing_rate": "Częstość oddechów",
            "bio.stress": "Stres",
            "bio.relaxation": "Relaksacja",
            "bio.meditation": "Medytacja",

            "emotion.neutral": "Neutralny",
            "emotion.happy": "Szczęśliwy",
            "emotion.sad": "Smutny",
            "emotion.energetic": "Energiczny",
            "emotion.calm": "Spokojny",

            "error.generic": "Wystąpił błąd",
            "error.network": "Błąd sieci",
            "error.permission": "Wymagane uprawnienie",
            "error.file_not_found": "Nie znaleziono pliku"
        ]
    }

    // MARK: - Turkish Translations

    private var turkishTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Hoş geldiniz",
            "general.ok": "Tamam",
            "general.cancel": "İptal",
            "general.save": "Kaydet",
            "general.delete": "Sil",
            "general.edit": "Düzenle",
            "general.done": "Bitti",
            "general.close": "Kapat",
            "general.settings": "Ayarlar",

            "bio.hrv": "Kalp Hızı Değişkenliği",
            "bio.coherence": "Tutarlılık",
            "bio.heart_rate": "Kalp Hızı",
            "bio.breathing_rate": "Solunum Hızı",
            "bio.stress": "Stres",
            "bio.relaxation": "Rahatlama",
            "bio.meditation": "Meditasyon",

            "emotion.neutral": "Nötr",
            "emotion.happy": "Mutlu",
            "emotion.sad": "Üzgün",
            "emotion.energetic": "Enerjik",
            "emotion.calm": "Sakin",

            "error.generic": "Bir hata oluştu",
            "error.network": "Ağ hatası",
            "error.permission": "İzin gerekli",
            "error.file_not_found": "Dosya bulunamadı"
        ]
    }

    // MARK: - Chinese Traditional Translations

    private var chineseTraditionalTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "歡迎",
            "general.ok": "確定",
            "general.cancel": "取消",
            "general.save": "儲存",
            "general.delete": "刪除",
            "general.edit": "編輯",
            "general.done": "完成",
            "general.close": "關閉",
            "general.settings": "設定",

            "bio.hrv": "心率變異性",
            "bio.coherence": "一致性",
            "bio.heart_rate": "心率",
            "bio.breathing_rate": "呼吸頻率",
            "bio.stress": "壓力",
            "bio.relaxation": "放鬆",
            "bio.meditation": "冥想",

            "emotion.neutral": "中性",
            "emotion.happy": "快樂",
            "emotion.sad": "悲傷",
            "emotion.energetic": "充滿活力",
            "emotion.calm": "平靜",

            "error.generic": "發生錯誤",
            "error.network": "網路錯誤",
            "error.permission": "需要權限",
            "error.file_not_found": "找不到檔案"
        ]
    }

    // MARK: - Bengali Translations

    private var bengaliTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "স্বাগতম",
            "general.ok": "ঠিক আছে",
            "general.cancel": "বাতিল",
            "general.save": "সংরক্ষণ",
            "general.delete": "মুছুন",
            "general.edit": "সম্পাদনা",
            "general.done": "সম্পন্ন",
            "general.close": "বন্ধ",
            "general.settings": "সেটিংস",

            "bio.hrv": "হার্ট রেট ভ্যারিয়েবিলিটি",
            "bio.coherence": "সমন্বয়",
            "bio.heart_rate": "হার্ট রেট",
            "bio.breathing_rate": "শ্বাসের হার",
            "bio.stress": "মানসিক চাপ",
            "bio.relaxation": "শিথিলতা",
            "bio.meditation": "ধ্যান",

            "emotion.neutral": "নিরপেক্ষ",
            "emotion.happy": "খুশি",
            "emotion.sad": "দুঃখিত",
            "emotion.energetic": "উদ্যমী",
            "emotion.calm": "শান্ত",

            "error.generic": "একটি ত্রুটি ঘটেছে",
            "error.network": "নেটওয়ার্ক ত্রুটি",
            "error.permission": "অনুমতি প্রয়োজন",
            "error.file_not_found": "ফাইল পাওয়া যায়নি"
        ]
    }

    // MARK: - Tamil Translations

    private var tamilTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "வரவேற்கிறோம்",
            "general.ok": "சரி",
            "general.cancel": "ரத்து",
            "general.save": "சேமி",
            "general.delete": "நீக்கு",
            "general.edit": "திருத்து",
            "general.done": "முடிந்தது",
            "general.close": "மூடு",
            "general.settings": "அமைப்புகள்",

            "bio.hrv": "இதய துடிப்பு மாறுபாடு",
            "bio.coherence": "ஒத்திசைவு",
            "bio.heart_rate": "இதய துடிப்பு",
            "bio.breathing_rate": "சுவாச விகிதம்",
            "bio.stress": "மன அழுத்தம்",
            "bio.relaxation": "தளர்வு",
            "bio.meditation": "தியானம்",

            "emotion.neutral": "நடுநிலை",
            "emotion.happy": "மகிழ்ச்சி",
            "emotion.sad": "சோகம்",
            "emotion.energetic": "ஆற்றல்மிக்க",
            "emotion.calm": "அமைதி",

            "error.generic": "பிழை ஏற்பட்டது",
            "error.network": "நெட்வொர்க் பிழை",
            "error.permission": "அனுமதி தேவை",
            "error.file_not_found": "கோப்பு கிடைக்கவில்லை"
        ]
    }

    // MARK: - Thai Translations

    private var thaiTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "ยินดีต้อนรับ",
            "general.ok": "ตกลง",
            "general.cancel": "ยกเลิก",
            "general.save": "บันทึก",
            "general.delete": "ลบ",
            "general.edit": "แก้ไข",
            "general.done": "เสร็จสิ้น",
            "general.close": "ปิด",
            "general.settings": "การตั้งค่า",

            "bio.hrv": "ความแปรปรวนของอัตราการเต้นของหัวใจ",
            "bio.coherence": "ความสอดคล้อง",
            "bio.heart_rate": "อัตราการเต้นของหัวใจ",
            "bio.breathing_rate": "อัตราการหายใจ",
            "bio.stress": "ความเครียด",
            "bio.relaxation": "การผ่อนคลาย",
            "bio.meditation": "การทำสมาธิ",

            "emotion.neutral": "เป็นกลาง",
            "emotion.happy": "มีความสุข",
            "emotion.sad": "เศร้า",
            "emotion.energetic": "มีพลัง",
            "emotion.calm": "สงบ",

            "error.generic": "เกิดข้อผิดพลาด",
            "error.network": "ข้อผิดพลาดเครือข่าย",
            "error.permission": "ต้องได้รับอนุญาต",
            "error.file_not_found": "ไม่พบไฟล์"
        ]
    }

    // MARK: - Vietnamese Translations

    private var vietnameseTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Chào mừng",
            "general.ok": "OK",
            "general.cancel": "Hủy",
            "general.save": "Lưu",
            "general.delete": "Xóa",
            "general.edit": "Chỉnh sửa",
            "general.done": "Xong",
            "general.close": "Đóng",
            "general.settings": "Cài đặt",

            "bio.hrv": "Biến thiên nhịp tim",
            "bio.coherence": "Sự mạch lạc",
            "bio.heart_rate": "Nhịp tim",
            "bio.breathing_rate": "Nhịp thở",
            "bio.stress": "Căng thẳng",
            "bio.relaxation": "Thư giãn",
            "bio.meditation": "Thiền định",

            "emotion.neutral": "Trung lập",
            "emotion.happy": "Vui vẻ",
            "emotion.sad": "Buồn",
            "emotion.energetic": "Tràn đầy năng lượng",
            "emotion.calm": "Bình tĩnh",

            "error.generic": "Đã xảy ra lỗi",
            "error.network": "Lỗi mạng",
            "error.permission": "Cần quyền truy cập",
            "error.file_not_found": "Không tìm thấy tệp"
        ]
    }

    // MARK: - Hebrew Translations

    private var hebrewTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "ברוכים הבאים",
            "general.ok": "אישור",
            "general.cancel": "ביטול",
            "general.save": "שמור",
            "general.delete": "מחק",
            "general.edit": "ערוך",
            "general.done": "סיום",
            "general.close": "סגור",
            "general.settings": "הגדרות",

            "bio.hrv": "שונות קצב הלב",
            "bio.coherence": "קוהרנטיות",
            "bio.heart_rate": "קצב לב",
            "bio.breathing_rate": "קצב נשימה",
            "bio.stress": "מתח",
            "bio.relaxation": "הרפיה",
            "bio.meditation": "מדיטציה",

            "emotion.neutral": "ניטרלי",
            "emotion.happy": "שמח",
            "emotion.sad": "עצוב",
            "emotion.energetic": "אנרגטי",
            "emotion.calm": "רגוע",

            "error.generic": "אירעה שגיאה",
            "error.network": "שגיאת רשת",
            "error.permission": "נדרשת הרשאה",
            "error.file_not_found": "הקובץ לא נמצא"
        ]
    }

    // MARK: - Persian Translations

    private var persianTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "خوش آمدید",
            "general.ok": "تایید",
            "general.cancel": "لغو",
            "general.save": "ذخیره",
            "general.delete": "حذف",
            "general.edit": "ویرایش",
            "general.done": "انجام شد",
            "general.close": "بستن",
            "general.settings": "تنظیمات",

            "bio.hrv": "تغییرپذیری ضربان قلب",
            "bio.coherence": "انسجام",
            "bio.heart_rate": "ضربان قلب",
            "bio.breathing_rate": "سرعت تنفس",
            "bio.stress": "استرس",
            "bio.relaxation": "آرامش",
            "bio.meditation": "مدیتیشن",

            "emotion.neutral": "خنثی",
            "emotion.happy": "شاد",
            "emotion.sad": "غمگین",
            "emotion.energetic": "پرانرژی",
            "emotion.calm": "آرام",

            "error.generic": "خطایی رخ داد",
            "error.network": "خطای شبکه",
            "error.permission": "مجوز لازم است",
            "error.file_not_found": "فایل یافت نشد"
        ]
    }

    // MARK: - Indonesian Translations

    private var indonesianTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Selamat datang",
            "general.ok": "OK",
            "general.cancel": "Batal",
            "general.save": "Simpan",
            "general.delete": "Hapus",
            "general.edit": "Edit",
            "general.done": "Selesai",
            "general.close": "Tutup",
            "general.settings": "Pengaturan",

            "bio.hrv": "Variabilitas Detak Jantung",
            "bio.coherence": "Koherensi",
            "bio.heart_rate": "Detak Jantung",
            "bio.breathing_rate": "Laju Pernapasan",
            "bio.stress": "Stres",
            "bio.relaxation": "Relaksasi",
            "bio.meditation": "Meditasi",

            "emotion.neutral": "Netral",
            "emotion.happy": "Bahagia",
            "emotion.sad": "Sedih",
            "emotion.energetic": "Energik",
            "emotion.calm": "Tenang",

            "error.generic": "Terjadi kesalahan",
            "error.network": "Kesalahan jaringan",
            "error.permission": "Izin diperlukan",
            "error.file_not_found": "File tidak ditemukan"
        ]
    }

    // MARK: - Malay Translations

    private var malayTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Selamat datang",
            "general.ok": "OK",
            "general.cancel": "Batal",
            "general.save": "Simpan",
            "general.delete": "Padam",
            "general.edit": "Edit",
            "general.done": "Selesai",
            "general.close": "Tutup",
            "general.settings": "Tetapan",

            "bio.hrv": "Variabiliti Kadar Jantung",
            "bio.coherence": "Koherensi",
            "bio.heart_rate": "Kadar Jantung",
            "bio.breathing_rate": "Kadar Pernafasan",
            "bio.stress": "Tekanan",
            "bio.relaxation": "Relaksasi",
            "bio.meditation": "Meditasi",

            "emotion.neutral": "Neutral",
            "emotion.happy": "Gembira",
            "emotion.sad": "Sedih",
            "emotion.energetic": "Bertenaga",
            "emotion.calm": "Tenang",

            "error.generic": "Ralat berlaku",
            "error.network": "Ralat rangkaian",
            "error.permission": "Kebenaran diperlukan",
            "error.file_not_found": "Fail tidak dijumpai"
        ]
    }

    // MARK: - Finnish Translations

    private var finnishTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Tervetuloa",
            "general.ok": "OK",
            "general.cancel": "Peruuta",
            "general.save": "Tallenna",
            "general.delete": "Poista",
            "general.edit": "Muokkaa",
            "general.done": "Valmis",
            "general.close": "Sulje",
            "general.settings": "Asetukset",

            "bio.hrv": "Sykevälivaihtelu",
            "bio.coherence": "Koherenssi",
            "bio.heart_rate": "Syke",
            "bio.breathing_rate": "Hengitystiheys",
            "bio.stress": "Stressi",
            "bio.relaxation": "Rentoutuminen",
            "bio.meditation": "Meditaatio",

            "emotion.neutral": "Neutraali",
            "emotion.happy": "Iloinen",
            "emotion.sad": "Surullinen",
            "emotion.energetic": "Energinen",
            "emotion.calm": "Rauhallinen",

            "error.generic": "Tapahtui virhe",
            "error.network": "Verkkovirhe",
            "error.permission": "Lupa vaaditaan",
            "error.file_not_found": "Tiedostoa ei löydy"
        ]
    }

    // MARK: - Greek Translations

    private var greekTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Καλώς ήρθατε",
            "general.ok": "OK",
            "general.cancel": "Ακύρωση",
            "general.save": "Αποθήκευση",
            "general.delete": "Διαγραφή",
            "general.edit": "Επεξεργασία",
            "general.done": "Τέλος",
            "general.close": "Κλείσιμο",
            "general.settings": "Ρυθμίσεις",

            "bio.hrv": "Μεταβλητότητα Καρδιακού Ρυθμού",
            "bio.coherence": "Συνοχή",
            "bio.heart_rate": "Καρδιακοί Παλμοί",
            "bio.breathing_rate": "Ρυθμός Αναπνοής",
            "bio.stress": "Άγχος",
            "bio.relaxation": "Χαλάρωση",
            "bio.meditation": "Διαλογισμός",

            "emotion.neutral": "Ουδέτερο",
            "emotion.happy": "Χαρούμενος",
            "emotion.sad": "Λυπημένος",
            "emotion.energetic": "Ενεργητικός",
            "emotion.calm": "Ήρεμος",

            "error.generic": "Παρουσιάστηκε σφάλμα",
            "error.network": "Σφάλμα δικτύου",
            "error.permission": "Απαιτείται άδεια",
            "error.file_not_found": "Το αρχείο δεν βρέθηκε"
        ]
    }

    // MARK: - Czech Translations

    private var czechTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Vítejte",
            "general.ok": "OK",
            "general.cancel": "Zrušit",
            "general.save": "Uložit",
            "general.delete": "Smazat",
            "general.edit": "Upravit",
            "general.done": "Hotovo",
            "general.close": "Zavřít",
            "general.settings": "Nastavení",

            "bio.hrv": "Variabilita srdeční frekvence",
            "bio.coherence": "Koherence",
            "bio.heart_rate": "Srdeční tep",
            "bio.breathing_rate": "Dechová frekvence",
            "bio.stress": "Stres",
            "bio.relaxation": "Relaxace",
            "bio.meditation": "Meditace",

            "emotion.neutral": "Neutrální",
            "emotion.happy": "Šťastný",
            "emotion.sad": "Smutný",
            "emotion.energetic": "Energický",
            "emotion.calm": "Klidný",

            "error.generic": "Došlo k chybě",
            "error.network": "Chyba sítě",
            "error.permission": "Vyžadováno povolení",
            "error.file_not_found": "Soubor nenalezen"
        ]
    }

    // MARK: - Romanian Translations

    private var romanianTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Bine ați venit",
            "general.ok": "OK",
            "general.cancel": "Anulare",
            "general.save": "Salvare",
            "general.delete": "Ștergere",
            "general.edit": "Editare",
            "general.done": "Gata",
            "general.close": "Închide",
            "general.settings": "Setări",

            "bio.hrv": "Variabilitatea Ritmului Cardiac",
            "bio.coherence": "Coerență",
            "bio.heart_rate": "Ritm Cardiac",
            "bio.breathing_rate": "Frecvența Respiratorie",
            "bio.stress": "Stres",
            "bio.relaxation": "Relaxare",
            "bio.meditation": "Meditație",

            "emotion.neutral": "Neutru",
            "emotion.happy": "Fericit",
            "emotion.sad": "Trist",
            "emotion.energetic": "Energic",
            "emotion.calm": "Calm",

            "error.generic": "A apărut o eroare",
            "error.network": "Eroare de rețea",
            "error.permission": "Permisiune necesară",
            "error.file_not_found": "Fișier negăsit"
        ]
    }

    // MARK: - Hungarian Translations

    private var hungarianTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Üdvözöljük",
            "general.ok": "OK",
            "general.cancel": "Mégse",
            "general.save": "Mentés",
            "general.delete": "Törlés",
            "general.edit": "Szerkesztés",
            "general.done": "Kész",
            "general.close": "Bezárás",
            "general.settings": "Beállítások",

            "bio.hrv": "Szívritmus-variabilitás",
            "bio.coherence": "Koherencia",
            "bio.heart_rate": "Pulzus",
            "bio.breathing_rate": "Légzésszám",
            "bio.stress": "Stressz",
            "bio.relaxation": "Relaxáció",
            "bio.meditation": "Meditáció",

            "emotion.neutral": "Semleges",
            "emotion.happy": "Boldog",
            "emotion.sad": "Szomorú",
            "emotion.energetic": "Energikus",
            "emotion.calm": "Nyugodt",

            "error.generic": "Hiba történt",
            "error.network": "Hálózati hiba",
            "error.permission": "Engedély szükséges",
            "error.file_not_found": "Fájl nem található"
        ]
    }

    // MARK: - Ukrainian Translations

    private var ukrainianTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Ласкаво просимо",
            "general.ok": "OK",
            "general.cancel": "Скасувати",
            "general.save": "Зберегти",
            "general.delete": "Видалити",
            "general.edit": "Редагувати",
            "general.done": "Готово",
            "general.close": "Закрити",
            "general.settings": "Налаштування",

            "bio.hrv": "Варіабельність серцевого ритму",
            "bio.coherence": "Когерентність",
            "bio.heart_rate": "Частота серцебиття",
            "bio.breathing_rate": "Частота дихання",
            "bio.stress": "Стрес",
            "bio.relaxation": "Розслаблення",
            "bio.meditation": "Медитація",

            "emotion.neutral": "Нейтральний",
            "emotion.happy": "Щасливий",
            "emotion.sad": "Сумний",
            "emotion.energetic": "Енергійний",
            "emotion.calm": "Спокійний",

            "error.generic": "Сталася помилка",
            "error.network": "Помилка мережі",
            "error.permission": "Потрібен дозвіл",
            "error.file_not_found": "Файл не знайдено"
        ]
    }

    // MARK: - Filipino Translations

    private var filipinoTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Maligayang pagdating",
            "general.ok": "OK",
            "general.cancel": "Kanselahin",
            "general.save": "I-save",
            "general.delete": "Tanggalin",
            "general.edit": "I-edit",
            "general.done": "Tapos",
            "general.close": "Isara",
            "general.settings": "Mga Setting",

            "bio.hrv": "Pagkakaiba-iba ng Heart Rate",
            "bio.coherence": "Koherensya",
            "bio.heart_rate": "Heart Rate",
            "bio.breathing_rate": "Bilis ng Paghinga",
            "bio.stress": "Stress",
            "bio.relaxation": "Pagpapahinga",
            "bio.meditation": "Meditasyon",

            "emotion.neutral": "Neutral",
            "emotion.happy": "Masaya",
            "emotion.sad": "Malungkot",
            "emotion.energetic": "Masigla",
            "emotion.calm": "Kalmado",

            "error.generic": "May nangyaring error",
            "error.network": "Error sa network",
            "error.permission": "Kailangan ng permiso",
            "error.file_not_found": "Hindi nakita ang file"
        ]
    }

    // MARK: - Swahili Translations

    private var swahiliTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "Karibu",
            "general.ok": "Sawa",
            "general.cancel": "Ghairi",
            "general.save": "Hifadhi",
            "general.delete": "Futa",
            "general.edit": "Hariri",
            "general.done": "Imekamilika",
            "general.close": "Funga",
            "general.settings": "Mipangilio",

            "bio.hrv": "Tofauti ya Mapigo ya Moyo",
            "bio.coherence": "Mshikamano",
            "bio.heart_rate": "Mapigo ya Moyo",
            "bio.breathing_rate": "Kiwango cha Kupumua",
            "bio.stress": "Msongo",
            "bio.relaxation": "Kupumzika",
            "bio.meditation": "Kutafakari",

            "emotion.neutral": "Wastani",
            "emotion.happy": "Furaha",
            "emotion.sad": "Huzuni",
            "emotion.energetic": "Nguvu",
            "emotion.calm": "Utulivu",

            "error.generic": "Hitilafu imetokea",
            "error.network": "Hitilafu ya mtandao",
            "error.permission": "Ruhusa inahitajika",
            "error.file_not_found": "Faili haipatikani"
        ]
    }

    // MARK: - Telugu Translations

    private var teluguTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "స్వాగతం",
            "general.ok": "సరే",
            "general.cancel": "రద్దు",
            "general.save": "సేవ్",
            "general.delete": "తొలగించు",
            "general.edit": "సవరించు",
            "general.done": "పూర్తయింది",
            "general.close": "మూసివేయి",
            "general.settings": "సెట్టింగ్స్",

            "bio.hrv": "హృదయ స్పందన వైవిధ్యత",
            "bio.coherence": "సమన్వయం",
            "bio.heart_rate": "హృదయ స్పందన",
            "bio.breathing_rate": "శ్వాస రేటు",
            "bio.stress": "ఒత్తిడి",
            "bio.relaxation": "విశ్రాంతి",
            "bio.meditation": "ధ్యానం",

            "emotion.neutral": "తటస్థ",
            "emotion.happy": "సంతోషం",
            "emotion.sad": "దుఃఖం",
            "emotion.energetic": "శక్తివంతం",
            "emotion.calm": "ప్రశాంతం",

            "error.generic": "లోపం సంభవించింది",
            "error.network": "నెట్‌వర్క్ లోపం",
            "error.permission": "అనుమతి అవసరం",
            "error.file_not_found": "ఫైల్ కనుగొనబడలేదు"
        ]
    }

    // MARK: - Marathi Translations

    private var marathiTranslations: [String: String] {
        [
            "app.name": "Echoelmusic",
            "general.welcome": "स्वागत आहे",
            "general.ok": "ठीक आहे",
            "general.cancel": "रद्द करा",
            "general.save": "जतन करा",
            "general.delete": "हटवा",
            "general.edit": "संपादित करा",
            "general.done": "झाले",
            "general.close": "बंद करा",
            "general.settings": "सेटिंग्ज",

            "bio.hrv": "हृदय गती परिवर्तनीयता",
            "bio.coherence": "सुसंगतता",
            "bio.heart_rate": "हृदय गती",
            "bio.breathing_rate": "श्वसन दर",
            "bio.stress": "ताण",
            "bio.relaxation": "विश्रांती",
            "bio.meditation": "ध्यान",

            "emotion.neutral": "तटस्थ",
            "emotion.happy": "आनंदी",
            "emotion.sad": "दुःखी",
            "emotion.energetic": "ऊर्जावान",
            "emotion.calm": "शांत",

            "error.generic": "त्रुटी आली",
            "error.network": "नेटवर्क त्रुटी",
            "error.permission": "परवानगी आवश्यक",
            "error.file_not_found": "फाइल सापडली नाही"
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
