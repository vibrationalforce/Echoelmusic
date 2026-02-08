// Phase8000Localization.swift
// Echoelmusic - 8000% MAXIMUM OVERDRIVE MODE
//
// Multi-language support for worldwide collaboration
// German, Japanese, Spanish, French, Chinese, and more
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import SwiftUI

// MARK: - Supported Languages

public enum SupportedLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case german = "de"
    case japanese = "ja"
    case spanish = "es"
    case french = "fr"
    case chinese = "zh"
    case korean = "ko"
    case portuguese = "pt"
    case italian = "it"
    case russian = "ru"
    case arabic = "ar"
    case hindi = "hi"

    public var displayName: String {
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
        case .russian: return "Русский"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        }
    }

    public var isRTL: Bool {
        self == .arabic
    }
}

// MARK: - Localization Keys

public enum LocalizationKey: String, CaseIterable {
    // General
    case appName = "app_name"
    case welcome = "welcome"
    case start = "start"
    case stop = "stop"
    case settings = "settings"
    case help = "help"
    case cancel = "cancel"
    case confirm = "confirm"
    case save = "save"
    case delete = "delete"
    case share = "share"

    // Navigation
    case home = "home"
    case video = "video"
    case creative = "creative"
    case science = "science"
    case wellness = "wellness"
    case collaboration = "collaboration"
    case developer = "developer"

    // Video
    case videoStudio = "video_studio"
    case resolution = "resolution"
    case frameRate = "frame_rate"
    case effects = "effects"
    case recording = "recording"
    case streaming = "streaming"
    case quantumEffects = "quantum_effects"

    // Creative
    case creativeStudio = "creative_studio"
    case generateArt = "generate_art"
    case generateMusic = "generate_music"
    case prompt = "prompt"
    case style = "style"
    case genre = "genre"

    // Science
    case scientificLab = "scientific_lab"
    case visualization = "visualization"
    case simulation = "simulation"
    case dataset = "dataset"
    case quantumState = "quantum_state"

    // Wellness
    case wellnessCenter = "wellness_center"
    case meditation = "meditation"
    case breathing = "breathing"
    case relaxation = "relaxation"
    case focus = "focus"
    case wellnessDisclaimer = "wellness_disclaimer"

    // Collaboration
    case collaborationHub = "collaboration_hub"
    case joinSession = "join_session"
    case createSession = "create_session"
    case participants = "participants"
    case coherenceSync = "coherence_sync"

    // Quantum
    case quantumMode = "quantum_mode"
    case coherence = "coherence"
    case entanglement = "entanglement"
    case superposition = "superposition"
}

// MARK: - Localization Strings

public struct LocalizationStrings {

    // MARK: - English (Base)

    public static let english: [LocalizationKey: String] = [
        .appName: "Echoelmusic",
        .welcome: "Welcome to Echoelmusic",
        .start: "Start",
        .stop: "Stop",
        .settings: "Settings",
        .help: "Help",
        .cancel: "Cancel",
        .confirm: "Confirm",
        .save: "Save",
        .delete: "Delete",
        .share: "Share",

        .home: "Home",
        .video: "Video",
        .creative: "Creative",
        .science: "Science",
        .wellness: "Wellness",
        .collaboration: "Collaborate",
        .developer: "Developer",

        .videoStudio: "Video Studio",
        .resolution: "Resolution",
        .frameRate: "Frame Rate",
        .effects: "Effects",
        .recording: "Recording",
        .streaming: "Streaming",
        .quantumEffects: "Quantum Effects",

        .creativeStudio: "Creative Studio",
        .generateArt: "Generate Art",
        .generateMusic: "Generate Music",
        .prompt: "Prompt",
        .style: "Style",
        .genre: "Genre",

        .scientificLab: "Scientific Lab",
        .visualization: "Visualization",
        .simulation: "Simulation",
        .dataset: "Dataset",
        .quantumState: "Quantum State",

        .wellnessCenter: "Wellness Center",
        .meditation: "Meditation",
        .breathing: "Breathing",
        .relaxation: "Relaxation",
        .focus: "Focus",
        .wellnessDisclaimer: "For general wellness only. Not medical advice. Consult healthcare professionals for medical concerns.",

        .collaborationHub: "Collaboration Hub",
        .joinSession: "Join Session",
        .createSession: "Create Session",
        .participants: "Participants",
        .coherenceSync: "Coherence Sync",

        .quantumMode: "Quantum Mode",
        .coherence: "Coherence",
        .entanglement: "Entanglement",
        .superposition: "Superposition"
    ]

    // MARK: - German (Deutsch)

    public static let german: [LocalizationKey: String] = [
        .appName: "Echoelmusic",
        .welcome: "Willkommen bei Echoelmusic",
        .start: "Starten",
        .stop: "Stoppen",
        .settings: "Einstellungen",
        .help: "Hilfe",
        .cancel: "Abbrechen",
        .confirm: "Bestätigen",
        .save: "Speichern",
        .delete: "Löschen",
        .share: "Teilen",

        .home: "Startseite",
        .video: "Video",
        .creative: "Kreativ",
        .science: "Wissenschaft",
        .wellness: "Wohlbefinden",
        .collaboration: "Zusammenarbeit",
        .developer: "Entwickler",

        .videoStudio: "Video-Studio",
        .resolution: "Auflösung",
        .frameRate: "Bildrate",
        .effects: "Effekte",
        .recording: "Aufnahme",
        .streaming: "Streaming",
        .quantumEffects: "Quanteneffekte",

        .creativeStudio: "Kreativ-Studio",
        .generateArt: "Kunst Generieren",
        .generateMusic: "Musik Generieren",
        .prompt: "Eingabe",
        .style: "Stil",
        .genre: "Genre",

        .scientificLab: "Wissenschaftslabor",
        .visualization: "Visualisierung",
        .simulation: "Simulation",
        .dataset: "Datensatz",
        .quantumState: "Quantenzustand",

        .wellnessCenter: "Wellness-Center",
        .meditation: "Meditation",
        .breathing: "Atmung",
        .relaxation: "Entspannung",
        .focus: "Fokus",
        .wellnessDisclaimer: "Nur für allgemeines Wohlbefinden. Keine medizinische Beratung. Konsultieren Sie Fachpersonal bei gesundheitlichen Fragen.",

        .collaborationHub: "Kollaborations-Hub",
        .joinSession: "Sitzung Beitreten",
        .createSession: "Sitzung Erstellen",
        .participants: "Teilnehmer",
        .coherenceSync: "Kohärenz-Sync",

        .quantumMode: "Quantenmodus",
        .coherence: "Kohärenz",
        .entanglement: "Verschränkung",
        .superposition: "Superposition"
    ]

    // MARK: - Japanese (日本語)

    public static let japanese: [LocalizationKey: String] = [
        .appName: "Echoelmusic",
        .welcome: "Echoelmusicへようこそ",
        .start: "開始",
        .stop: "停止",
        .settings: "設定",
        .help: "ヘルプ",
        .cancel: "キャンセル",
        .confirm: "確認",
        .save: "保存",
        .delete: "削除",
        .share: "共有",

        .home: "ホーム",
        .video: "ビデオ",
        .creative: "クリエイティブ",
        .science: "サイエンス",
        .wellness: "ウェルネス",
        .collaboration: "コラボレーション",
        .developer: "開発者",

        .videoStudio: "ビデオスタジオ",
        .resolution: "解像度",
        .frameRate: "フレームレート",
        .effects: "エフェクト",
        .recording: "録画",
        .streaming: "配信",
        .quantumEffects: "量子エフェクト",

        .creativeStudio: "クリエイティブスタジオ",
        .generateArt: "アート生成",
        .generateMusic: "音楽生成",
        .prompt: "プロンプト",
        .style: "スタイル",
        .genre: "ジャンル",

        .scientificLab: "科学研究室",
        .visualization: "可視化",
        .simulation: "シミュレーション",
        .dataset: "データセット",
        .quantumState: "量子状態",

        .wellnessCenter: "ウェルネスセンター",
        .meditation: "瞑想",
        .breathing: "呼吸",
        .relaxation: "リラクゼーション",
        .focus: "集中",
        .wellnessDisclaimer: "一般的なウェルネス目的のみ。医療アドバイスではありません。健康上の問題は医療専門家にご相談ください。",

        .collaborationHub: "コラボレーションハブ",
        .joinSession: "セッションに参加",
        .createSession: "セッションを作成",
        .participants: "参加者",
        .coherenceSync: "コヒーレンス同期",

        .quantumMode: "量子モード",
        .coherence: "コヒーレンス",
        .entanglement: "エンタングルメント",
        .superposition: "重ね合わせ"
    ]

    // MARK: - Spanish (Español)

    public static let spanish: [LocalizationKey: String] = [
        .appName: "Echoelmusic",
        .welcome: "Bienvenido a Echoelmusic",
        .start: "Iniciar",
        .stop: "Detener",
        .settings: "Ajustes",
        .help: "Ayuda",
        .cancel: "Cancelar",
        .confirm: "Confirmar",
        .save: "Guardar",
        .delete: "Eliminar",
        .share: "Compartir",

        .home: "Inicio",
        .video: "Video",
        .creative: "Creativo",
        .science: "Ciencia",
        .wellness: "Bienestar",
        .collaboration: "Colaboración",
        .developer: "Desarrollador",

        .videoStudio: "Estudio de Video",
        .resolution: "Resolución",
        .frameRate: "Velocidad de Fotogramas",
        .effects: "Efectos",
        .recording: "Grabación",
        .streaming: "Transmisión",
        .quantumEffects: "Efectos Cuánticos",

        .creativeStudio: "Estudio Creativo",
        .generateArt: "Generar Arte",
        .generateMusic: "Generar Música",
        .prompt: "Indicación",
        .style: "Estilo",
        .genre: "Género",

        .scientificLab: "Laboratorio Científico",
        .visualization: "Visualización",
        .simulation: "Simulación",
        .dataset: "Conjunto de Datos",
        .quantumState: "Estado Cuántico",

        .wellnessCenter: "Centro de Bienestar",
        .meditation: "Meditación",
        .breathing: "Respiración",
        .relaxation: "Relajación",
        .focus: "Enfoque",
        .wellnessDisclaimer: "Solo para bienestar general. No es consejo médico. Consulte a profesionales de la salud para problemas médicos.",

        .collaborationHub: "Centro de Colaboración",
        .joinSession: "Unirse a Sesión",
        .createSession: "Crear Sesión",
        .participants: "Participantes",
        .coherenceSync: "Sincronización de Coherencia",

        .quantumMode: "Modo Cuántico",
        .coherence: "Coherencia",
        .entanglement: "Entrelazamiento",
        .superposition: "Superposición"
    ]

    // MARK: - French (Français)

    public static let french: [LocalizationKey: String] = [
        .appName: "Echoelmusic",
        .welcome: "Bienvenue sur Echoelmusic",
        .start: "Démarrer",
        .stop: "Arrêter",
        .settings: "Paramètres",
        .help: "Aide",
        .cancel: "Annuler",
        .confirm: "Confirmer",
        .save: "Enregistrer",
        .delete: "Supprimer",
        .share: "Partager",

        .home: "Accueil",
        .video: "Vidéo",
        .creative: "Créatif",
        .science: "Science",
        .wellness: "Bien-être",
        .collaboration: "Collaboration",
        .developer: "Développeur",

        .wellnessDisclaimer: "Pour le bien-être général uniquement. Pas un avis médical. Consultez des professionnels de santé pour les problèmes médicaux.",

        .quantumMode: "Mode Quantique",
        .coherence: "Cohérence",
        .entanglement: "Intrication",
        .superposition: "Superposition"
    ]

    // MARK: - Chinese (中文)

    public static let chinese: [LocalizationKey: String] = [
        .appName: "Echoelmusic",
        .welcome: "欢迎使用Echoelmusic",
        .start: "开始",
        .stop: "停止",
        .settings: "设置",
        .help: "帮助",
        .cancel: "取消",
        .confirm: "确认",
        .save: "保存",
        .delete: "删除",
        .share: "分享",

        .home: "首页",
        .video: "视频",
        .creative: "创意",
        .science: "科学",
        .wellness: "健康",
        .collaboration: "协作",
        .developer: "开发者",

        .wellnessDisclaimer: "仅用于一般健康目的。这不是医疗建议。如有健康问题，请咨询医疗专业人员。",

        .quantumMode: "量子模式",
        .coherence: "相干性",
        .entanglement: "量子纠缠",
        .superposition: "叠加态"
    ]
}

// MARK: - Localization Manager

@MainActor
public final class Phase8000LocalizationManager: ObservableObject {
    public static let shared = Phase8000LocalizationManager()

    @Published public var currentLanguage: SupportedLanguage = .english
    @Published public var strings: [LocalizationKey: String] = LocalizationStrings.english

    private init() {
        detectSystemLanguage()
    }

    public func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
        loadStrings(for: language)
    }

    public func localized(_ key: LocalizationKey) -> String {
        strings[key] ?? LocalizationStrings.english[key] ?? key.rawValue
    }

    public func localized(_ key: LocalizationKey, arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, arguments: arguments)
    }

    private func detectSystemLanguage() {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = String(preferredLanguage.prefix(2))

        if let language = SupportedLanguage(rawValue: languageCode) {
            setLanguage(language)
        }
    }

    private func loadStrings(for language: SupportedLanguage) {
        switch language {
        case .english: strings = LocalizationStrings.english
        case .german: strings = LocalizationStrings.german
        case .japanese: strings = LocalizationStrings.japanese
        case .spanish: strings = LocalizationStrings.spanish
        case .french: strings = LocalizationStrings.french
        case .chinese: strings = LocalizationStrings.chinese
        default: strings = LocalizationStrings.english
        }
    }
}

// MARK: - SwiftUI Extension

public extension String {
    var localized: String {
        self
    }
}

// MARK: - Localized View Modifier

public struct LocalizedText: View {
    let key: LocalizationKey
    @ObservedObject var manager = Phase8000LocalizationManager.shared

    public init(_ key: LocalizationKey) {
        self.key = key
    }

    public var body: some View {
        Text(manager.localized(key))
    }
}
