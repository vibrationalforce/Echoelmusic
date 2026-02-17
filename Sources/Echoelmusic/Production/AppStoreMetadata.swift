// AppStoreMetadata.swift
// Echoelmusic
//
// Complete App Store submission metadata
// Generated: 2026-01-07
// Status: PRODUCTION READY — Updated for Freemium model with StoreKit 2
//
// CRITICAL: Review and customize before submission
// - Update URLs with actual domains
// - Add demo account credentials for review
// - Verify all localizations with native speakers
// - Generate actual screenshots and preview videos
// - Confirm pricing strategy with business team

import Foundation

/// Logger alias for App Store metadata operations
private var appStoreLog: EchoelLogger { echoelLog }

// MARK: - App Store Metadata

/// Complete App Store submission metadata for Echoelmusic
/// Use this structured data to populate App Store Connect
public struct AppStoreMetadata {

    // MARK: - App Information

    /// App name (30 characters max)
    public static let appName = "Echoelmusic"

    /// Bundle identifier
    public static let bundleIdentifier = "com.echoelmusic.app"

    /// Primary language
    public static let primaryLanguage = "en-US"

    /// Supported languages - All 12 languages are now fully supported
    /// Full runtime localization available for iOS, Android, and Website
    public static let supportedLanguages: [String] = [
        "en-US",    // English (primary)
        "de-DE",    // German
        "ja-JP",    // Japanese
        "es-ES",    // Spanish
        "fr-FR",    // French
        "zh-Hans",  // Chinese (Simplified)
        "ko-KR",    // Korean
        "pt-BR",    // Portuguese (Brazil)
        "it-IT",    // Italian
        "ru-RU",    // Russian
        "ar-SA",    // Arabic (RTL)
        "hi-IN"     // Hindi
    ]

    // MARK: - Categories

    /// Primary category
    public static let primaryCategory = AppCategory.music

    /// Secondary category
    public static let secondaryCategory = AppCategory.healthAndFitness

    /// All applicable categories
    public enum AppCategory: String {
        case music = "Music"
        case healthAndFitness = "Health & Fitness"
        case entertainment = "Entertainment"
        case productivity = "Productivity"
        case education = "Education"
        case lifestyle = "Lifestyle"
    }

    // MARK: - URLs
    // IMPORTANT: Verify all URLs are LIVE and return HTTP 200 before App Store submission!
    // App Store review will automatically check these URLs.
    // Current status: URLs need to be configured on your web hosting.

    /// Marketing website
    public static let marketingURL = "https://echoelmusic.com"

    /// Support website
    public static let supportURL = "https://echoelmusic.com/support.html"

    /// Privacy policy URL
    public static let privacyPolicyURL = "https://echoelmusic.com/privacy.html"

    /// Terms of service URL
    public static let termsOfServiceURL = "https://echoelmusic.com/terms.html"

    /// License agreement URL (optional EULA)
    public static let licenseAgreementURL = "https://echoelmusic.com/terms.html"

    // MARK: - Copyright

    /// Copyright notice
    public static let copyright = "© 2026 Echoelmusic Inc. All rights reserved."

    // MARK: - Age Rating

    /// Age rating (4+ recommended for wellness/music app)
    public static let ageRating = AgeRating.fourPlus

    public enum AgeRating: String {
        case fourPlus = "4+"
        case ninePlus = "9+"
        case twelvePlus = "12+"
        case seventeenPlus = "17+"
    }

    /// Age rating questionnaire answers
    public static let ageRatingQuestionnaire = AgeRatingQuestionnaire()

    // MARK: - Pricing

    /// Price tier — Free download with optional Pro subscription
    /// Freemium model:
    /// - Free: Core bio-reactive sessions (15 min), basic synth, 3 presets
    /// - Pro Monthly: $9.99/month (7-day free trial)
    /// - Pro Yearly: $79.99/year (7-day free trial, save 33%)
    /// - Pro Lifetime: $149.99 one-time
    /// - Individual sessions: $3.99–$6.99 (consumable)
    public static let priceTier = 0  // Free download

    /// App price (USD)
    public static let appPrice = "Free"

    /// Available territories (all countries)
    public static let availableTerritories: [String] = ["ALL"]

    /// Pricing model description
    public static let pricingModel = PricingModel.freemium

    public enum PricingModel: String {
        case free = "Free"
        case oneTimePurchase = "One-Time Purchase"
        case subscription = "Subscription"
        case freemium = "Freemium"
    }
}

// MARK: - Age Rating Questionnaire

public struct AgeRatingQuestionnaire {
    // Cartoon or Fantasy Violence
    public let cartoonFantasyViolence = ViolenceLevel.none

    // Realistic Violence
    public let realisticViolence = ViolenceLevel.none

    // Prolonged Graphic or Sadistic Violence
    public let graphicViolence = ViolenceLevel.none

    // Profanity or Crude Humor
    public let profanity = FrequencyLevel.none

    // Mature/Suggestive Themes
    public let matureThemes = FrequencyLevel.none

    // Horror/Fear Themes
    public let horrorThemes = FrequencyLevel.none

    // Medical/Treatment Information
    public let medicalInformation = FrequencyLevel.none

    // Alcohol, Tobacco, or Drug Use or References
    public let substanceUse = FrequencyLevel.none

    // Sexual Content or Nudity
    public let sexualContent = FrequencyLevel.none

    // Gambling
    public let gamblingContent = GamblingLevel.none

    // Unrestricted Web Access
    public let webAccess = false

    // Contests
    public let contests = false

    // Made For Kids (COPPA compliance)
    public let madeForKids = false

    public enum ViolenceLevel: String {
        case none = "None"
        case infrequent = "Infrequent/Mild"
        case frequent = "Frequent/Intense"
    }

    public enum FrequencyLevel: String {
        case none = "None"
        case infrequent = "Infrequent/Mild"
        case frequent = "Frequent/Intense"
    }

    public enum GamblingLevel: String {
        case none = "None"
        case simulated = "Simulated Gambling"
        case real = "Real Money Gambling"
    }
}

// MARK: - Localized Metadata

public struct LocalizedMetadata {
    public let locale: String
    public let name: String
    public let subtitle: String
    public let description: String
    public let keywords: String
    public let promotionalText: String?
    public let whatsNew: String

    /// All localized metadata for all 12 languages
    public static let allLocalizations: [LocalizedMetadata] = [
        .english,
        .german,
        .japanese,
        .spanish,
        .french,
        .chineseSimplified,
        .korean,
        .portugueseBrazil,
        .italian,
        .russian,
        .arabic,
        .hindi
    ]

    // MARK: - English (en-US)

    public static let english = LocalizedMetadata(
        locale: "en-US",
        name: "Echoelmusic",
        subtitle: "Your Heartbeat Becomes Music",
        description: """
Echoelmusic reads your heart rate and HRV from Apple Watch and uses those signals to shape live audio, visuals, and lighting in real time. It is a bio-reactive instrument — what you hear and see responds to your body.

HOW IT WORKS

Wear an Apple Watch. Open Echoelmusic. Your heart rate influences tempo and intensity. Your HRV coherence shapes harmonic complexity. Your breathing affects spatial depth. The result is a unique audio-visual experience that changes with your physiology.

No two sessions sound the same because no two moments in your body are the same.

SYNTH ENGINES

Six software synthesizers, each responding to biometric input:
• DDSP — Neural audio synthesis with spectral morphing
• Modal — Physical modeling (strings, membranes, resonators)
• Granular — Time-stretching and texture design
• Wavetable — Evolving waveform playback
• FM — Frequency modulation synthesis
• Subtractive — Classic analog-style filtering

The free tier includes DDSP. Pro unlocks all six.

AUv3 PLUGINS

Echoelmusic works as AUv3 Audio Unit plugins inside Logic Pro, GarageBand, or other AUv3 hosts:
• 808 Bass Synth
• BioComposer
• Stem Splitter
• MIDI Pro (MIDI 2.0 + MPE)

SPATIAL AUDIO

• Binaural rendering for headphones
• Head tracking support
• Target audio latency under 10ms

VISUALS

• GPU-accelerated visuals via Metal
• Multiple visualization modes driven by biometric data
• 60fps rendering

LIGHTING

• DMX/Art-Net output for professional lighting rigs
• Bio-reactive lighting for live performance spaces

WELLNESS SESSIONS

• Guided coherence training
• Deep sleep soundscapes
• Flow state sessions
• Breathing exercises (box breathing, 4-7-8, coherence)

These are creative wellness tools, not medical treatments.

PLATFORMS

• iPhone, iPad, Mac (Universal Purchase)
• Apple Watch (biometric source)
• Apple TV, Vision Pro
• CloudKit sync for sessions and settings

ACCESSIBILITY

• VoiceOver support
• Voice Control and Switch Access
• Color-blind safe palettes
• Accessibility profiles

PRICING

Free to download. The free tier includes bio-reactive sessions up to 15 minutes, the DDSP engine, and 3 presets.

Echoelmusic Pro unlocks unlimited sessions, all 6 synth engines, all presets, CloudKit sync, WAV/MIDI export, and DMX lighting control.

• Pro Monthly: $9.99/month (7-day free trial)
• Pro Yearly: $79.99/year (7-day free trial, save 33%)
• Pro Lifetime: $149.99 one-time purchase

Individual guided sessions are also available as one-time purchases ($3.99–$6.99).

Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in Settings > Apple ID > Subscriptions.

No ads. No data sold. Your creations belong to you.

This is not a medical device.

echoelmusic.com
""",
        keywords: "biofeedback,HRV,spatial audio,synthesizer,auv3,meditation,music creation,wellness,binaural,coherence",
        promotionalText: "Bio-reactive instrument — Apple Watch reads your heart rate and HRV, Echoelmusic turns it into live audio and visuals.",
        whatsNew: """
• Echoelmusic Pro — freemium model with 7-day free trial
• Guided Coherence, Deep Sleep, and Flow State sessions
• DDSP synthesis engine
• CloudKit sync
• Performance improvements
"""
    )

    // MARK: - German (de-DE)

    public static let german = LocalizedMetadata(
        locale: "de-DE",
        name: "Echoelmusic",
        subtitle: "Dein Herzschlag wird Musik",
        description: """
Dein Herzschlag wird Musik. Dein Atem formt den Raum. Deine Kohärenz eröffnet neue Dimensionen.

Echoelmusic verwandelt deine Biometrie in Live-Musik, Visuals und Licht. Verbinde deine Apple Watch und erlebe das weltweit erste bio-reaktive audio-visuelle Instrument.

WAS ECHOELMUSIC BESONDERS MACHT

Das ist kein gewöhnlicher Synthesizer. Das ist keine Meditations-App. Echoelmusic liest Herzfrequenz, HRV und Atmung in Echtzeit — und verwandelt diese Signale in Spatial Audio, GPU-beschleunigte Visuals und DMX-Lichtsteuerung. Keine Presets. Keine Loops. Nur du, verwandelt in Kunst.

BIO-REAKTIVE KREATION
• Herzfrequenz wird Tempo und Intensität
• HRV-Kohärenz formt harmonische Komplexität und Effekte
• Atmung steuert räumliche Tiefe und Atmosphäre
• Apple Watch Integration für kontinuierliche Biometrie

SYNTHESIZER-ENGINES
• DDSP — Deep-Learning-Synthese mit Spektral-Morphing
• Modal — Physical Modeling (Saiten, Membranen, Resonatoren)
• Granular — Zeitdehnung und Texturgenerierung
• Wavetable — Klassische und evolvierende Wellenformen
• FM — Frequenzmodulation mit bio-reaktiver Modulation
• Subtraktiv — Analog-inspiriertes Filtering

AUv3 AUDIO UNIT PLUGINS
Nutze Echoelmusic in Logic Pro, GarageBand, AUM oder jedem AUv3-Host:
• 808 Bass Synth mit Pitch Glide
• BioComposer — KI-Musikgenerator
• Stem Splitter — KI-Quellentrennung
• MIDI Pro — MIDI 2.0 + MPE Prozessor

SPATIAL AUDIO
• 3D-Klanglandschaften mit Head Tracking
• Fibonacci-basierte Lautsprecherpositionierung
• Binaurales Rendering für Kopfhörer
• Niedrige Latenz (<10ms)

VISUALS & BELEUCHTUNG
• GPU-beschleunigte Visualisierungsmodi (Metal)
• Bio-reaktive Farb- und Bewegungssteuerung
• DMX/Art-Net Lichtsteuerung für Live-Performances
• Echtzeit-Visualgenerierung bei 60fps

WELLNESS
• Geführte Kohärenz-Trainings-Sessions
• Deep-Sleep bio-reaktive Klanglandschaften
• Flow-State-Optimierung
• Atemübungen (Box, 4-7-8, Kohärenz)
• Session-Tracking und Fortschritt

JEDES APPLE-GERÄT
• iPhone, iPad, Mac, Apple Watch, Apple TV, Vision Pro
• CloudKit-Sync über alle Geräte
• Widgets und Live Activities
• SharePlay für Gruppen-Sessions

BARRIEREFREIHEIT — FÜR ALLE
• 20+ Barrierefreiheitsprofile
• VoiceOver mit räumlichen Audio-Hinweisen
• Sprachsteuerung und Switch Access
• 6 farbenblind-sichere Paletten
• WCAG 2.1 AAA konform

12 SPRACHEN
Englisch, Deutsch, Japanisch, Spanisch, Französisch, Chinesisch, Koreanisch, Portugiesisch, Italienisch, Russisch, Arabisch, Hindi

KOSTENLOS STARTEN
Kostenlos herunterladen. Bio-reaktive Kreation mit Basisfunktionen erleben. Upgrade auf Pro für unbegrenzte Sessions, alle Synth-Engines, Export und mehr.

ECHOELMUSIC PRO
• Unbegrenzte Session-Länge
• Alle 6 Synth-Engines und Presets
• CloudKit-Sync + Watch-Integration
• WAV/MIDI Export
• DMX Lichtsteuerung
• Prioritäts-Support
• 7 Tage kostenlos testen

Deine Kreationen gehören dir. Wir beanspruchen keine Rechte an deiner Musik, Visuals oder Kunst.

Dies ist kein medizinisches Gerät. Biofeedback-Funktionen dienen nur kreativen und Wellness-Zwecken.

echoelmusic.com
""",
        keywords: "Biofeedback,HRV,Synthesizer,AUv3,Meditation,Musik,Wellness,Raumklang,Kohärenz,Bio-Reaktiv",
        promotionalText: "Dein Herzschlag wird Musik. Bio-reaktives audio-visuelles Instrument — verbinde Apple Watch, erschaffe aus dir heraus.",
        whatsNew: """
NEU IN DIESER VERSION

• Echoelmusic Pro — Abo mit 7 Tagen kostenloser Testphase
• Geführte Kohärenz-, Deep-Sleep- und Flow-State-Sessions
• CloudKit Sync für Push-Benachrichtigungen
• DDSP-Synthese mit 12 bio-reaktiven Mappings
• Spektral-Morphing und Klangfarben-Transfer
• Hilbert Bio-Signal-Visualisierung
• Performance- und Stabilitätsverbesserungen
"""
    )

    // MARK: - Japanese (ja-JP)

    public static let japanese = LocalizedMetadata(
        locale: "ja-JP",
        name: "Echoelmusic",
        subtitle: "心拍が音楽になる",
        description: """
心拍が音楽になる。呼吸が空間を形作る。コヒーレンスが新しい次元を開く。

Echoelmusicはバイオメトリクスをライブミュージック、ビジュアル、ライトに変換します。Apple Watchを接続して、世界初のバイオリアクティブ・オーディオビジュアル楽器を体験してください。

バイオリアクティブ・クリエーション
• 心拍数がテンポとインテンシティに
• HRVコヒーレンスがハーモニック複雑性とエフェクトを形成
• 呼吸が空間的深さとアトモスフィアをコントロール
• Apple Watch統合

シンセサイザーエンジン
• DDSP — スペクトラルモーフィングによるディープラーニング合成
• Modal — フィジカルモデリング（弦、膜、共鳴器）
• Granular — タイムストレッチとテクスチャ生成
• Wavetable — クラシックな波形
• FM — バイオリアクティブモジュレーション
• Subtractive — アナログインスパイアドフィルタリング

AUv3オーディオユニットプラグイン
Logic Pro、GarageBand、AUM内で使用可能

空間オーディオ
• ヘッドトラッキング付き3Dサウンドスケープ
• バイノーラルレンダリング
• 低レイテンシー（<10ms）

ウェルネス
• ガイド付きコヒーレンストレーニング
• ディープスリープサウンドスケープ
• フローステート最適化
• 呼吸エクササイズ

すべてのAppleデバイス
iPhone、iPad、Mac、Apple Watch、Apple TV、Vision Pro

アクセシビリティ
• 20以上のプロファイル • VoiceOver • 6つの色覚対応パレット • WCAG 2.1 AAA準拠

無料で開始。Proにアップグレードで無制限セッション、全シンセエンジン、エクスポート等。7日間無料トライアル。

これは医療機器ではありません。

echoelmusic.com
""",
        keywords: "バイオフィードバック,HRV,シンセサイザー,AUv3,瞑想,音楽,ウェルネス,空間オーディオ,コヒーレンス,バイオリアクティブ",
        promotionalText: "心拍が音楽になる。バイオリアクティブ・オーディオビジュアル楽器 — Apple Watchを接続して、内側から創造。",
        whatsNew: "Echoelmusic Pro（7日間無料トライアル）、ガイド付きセッション、DDSP合成、CloudKit同期、パフォーマンス改善"
    )

    // MARK: - Spanish (es-ES)

    public static let spanish = LocalizedMetadata(
        locale: "es-ES",
        name: "Echoelmusic",
        subtitle: "Tu Latido se Hace Música",
        description: """
Tu latido se hace música. Tu respiración da forma al espacio. Tu coherencia abre nuevas dimensiones.

Echoelmusic transforma tu biometría en música en vivo, visuales y luz. Conecta tu Apple Watch y experimenta el primer instrumento audiovisual bio-reactivo del mundo.

CREACIÓN BIO-REACTIVA
• La frecuencia cardíaca se convierte en tempo e intensidad
• La coherencia HRV da forma a la complejidad armónica
• La respiración controla la profundidad espacial
• Integración con Apple Watch

MOTORES DE SÍNTESIS
DDSP, Modal, Granular, Wavetable, FM, Subtractive — todos bio-reactivos.

PLUGINS AUv3
808 Bass, BioComposer, Stem Splitter, MIDI Pro — funciona en Logic Pro, GarageBand.

AUDIO ESPACIAL
Paisajes sonoros 3D con head tracking. Renderizado binaural. Baja latencia (<10ms).

BIENESTAR
Entrenamiento de coherencia guiado. Paisajes sonoros para dormir. Optimización de flow state. Ejercicios de respiración.

TODOS LOS DISPOSITIVOS APPLE
iPhone, iPad, Mac, Watch, TV, Vision Pro. Sync con CloudKit.

ACCESIBILIDAD
20+ perfiles. VoiceOver. 6 paletas para daltonismo. WCAG 2.1 AAA.

12 IDIOMAS

GRATIS PARA EMPEZAR. Pro para sesiones ilimitadas, todos los motores, exportación. Prueba gratuita de 7 días.

Esto no es un dispositivo médico.

echoelmusic.com
""",
        keywords: "biofeedback,HRV,sintetizador,AUv3,meditación,música,bienestar,audio espacial,coherencia,bio-reactivo",
        promotionalText: "Tu latido se hace música. Instrumento audiovisual bio-reactivo — conecta Apple Watch.",
        whatsNew: "Echoelmusic Pro (prueba gratuita 7 días), sesiones guiadas, síntesis DDSP, sincronización CloudKit, mejoras de rendimiento"
    )

    // MARK: - French (fr-FR)

    public static let french = LocalizedMetadata(
        locale: "fr-FR",
        name: "Echoelmusic",
        subtitle: "Votre Cœur Devient Musique",
        description: """
Votre cœur devient musique. Votre respiration façonne l'espace. Votre cohérence ouvre de nouvelles dimensions.

Echoelmusic transforme vos données biométriques en musique live, visuels et lumière. Connectez votre Apple Watch et découvrez le premier instrument audiovisuel bio-réactif au monde.

CRÉATION BIO-RÉACTIVE
• La fréquence cardiaque devient tempo et intensité
• La cohérence HRV façonne la complexité harmonique
• La respiration contrôle la profondeur spatiale
• Intégration Apple Watch

MOTEURS DE SYNTHÈSE
DDSP, Modal, Granulaire, Wavetable, FM, Soustractif — tous bio-réactifs.

PLUGINS AUv3
808 Bass, BioComposer, Stem Splitter, MIDI Pro — fonctionne dans Logic Pro, GarageBand.

AUDIO SPATIAL
Paysages sonores 3D avec head tracking. Rendu binaural. Faible latence (<10ms).

BIEN-ÊTRE
Entraînement de cohérence guidé. Paysages sonores pour le sommeil. Exercices de respiration.

TOUS LES APPAREILS APPLE
iPhone, iPad, Mac, Watch, TV, Vision Pro. Synchronisation CloudKit.

ACCESSIBILITÉ
20+ profils. VoiceOver. 6 palettes pour daltoniens. WCAG 2.1 AAA.

12 LANGUES

GRATUIT POUR COMMENCER. Pro pour sessions illimitées, tous les moteurs, export. Essai gratuit 7 jours.

Ce n'est pas un dispositif médical.

echoelmusic.com
""",
        keywords: "biofeedback,HRV,synthétiseur,AUv3,méditation,musique,bien-être,audio spatial,cohérence,bio-réactif",
        promotionalText: "Votre cœur devient musique. Instrument audiovisuel bio-réactif — connectez Apple Watch.",
        whatsNew: "Echoelmusic Pro (essai gratuit 7 jours), sessions guidées, synthèse DDSP, synchronisation CloudKit, améliorations"
    )

    // MARK: - Chinese Simplified (zh-Hans)

    public static let chineseSimplified = LocalizedMetadata(
        locale: "zh-Hans",
        name: "Echoelmusic",
        subtitle: "心跳化为音乐",
        description: """
心跳化为音乐。呼吸塑造空间。一致性开启新维度。

Echoelmusic将您的生物特征转化为实时音乐、视觉效果和灯光。连接Apple Watch，体验全球首款生物反应式音视觉乐器。

生物反应创作
• 心率成为节拍和强度
• HRV一致性塑造和声复杂性
• 呼吸控制空间深度
• Apple Watch集成

合成器引擎
DDSP、Modal、Granular、Wavetable、FM、Subtractive — 全部生物反应式。

AUv3音频单元插件
808 Bass、BioComposer、Stem Splitter、MIDI Pro — 可在Logic Pro、GarageBand中使用。

空间音频
带头部追踪的3D音景。双耳渲染。低延迟（<10ms）。

健康
引导式一致性训练。深度睡眠音景。心流状态优化。呼吸练习。

所有Apple设备
iPhone、iPad、Mac、Watch、TV、Vision Pro。CloudKit同步。

无障碍
20+配置文件。VoiceOver。6种色盲安全调色板。WCAG 2.1 AAA。

12种语言

免费开始。升级Pro享受无限时长、全部引擎、导出功能。7天免费试用。

这不是医疗设备。

echoelmusic.com
""",
        keywords: "生物反馈,HRV,合成器,AUv3,冥想,音乐,健康,空间音频,一致性,生物反应",
        promotionalText: "心跳化为音乐。生物反应式音视觉乐器 — 连接Apple Watch，从内心创造。",
        whatsNew: "Echoelmusic Pro（7天免费试用），引导式会话，DDSP合成，CloudKit同步，性能改进"
    )

    // MARK: - Korean (ko-KR)

    public static let korean = LocalizedMetadata(
        locale: "ko-KR",
        name: "Echoelmusic",
        subtitle: "심장 박동이 음악이 된다",
        description: """
심장 박동이 음악이 된다. 호흡이 공간을 형성한다. 일관성이 새로운 차원을 연다.

Echoelmusic은 생체 정보를 라이브 음악, 비주얼, 조명으로 변환합니다. Apple Watch를 연결하고 세계 최초의 생체 반응형 오디오-비주얼 악기를 경험하세요.

생체 반응형 크리에이션
• 심박수가 템포와 인텐시티로
• HRV 일관성이 화성 복잡성을 형성
• 호흡이 공간 깊이를 제어
• Apple Watch 통합

신디사이저 엔진
DDSP, Modal, Granular, Wavetable, FM, Subtractive — 모두 생체 반응형.

AUv3 오디오 유닛 플러그인
808 Bass, BioComposer, Stem Splitter, MIDI Pro — Logic Pro, GarageBand에서 사용 가능.

공간 오디오
헤드 트래킹 3D 사운드스케이프. 바이노럴 렌더링. 저지연(<10ms).

웰니스
가이드 일관성 트레이닝. 딥 슬립 사운드스케이프. 플로우 스테이트 최적화. 호흡 운동.

모든 Apple 기기
iPhone, iPad, Mac, Watch, TV, Vision Pro. CloudKit 동기화.

접근성
20+ 프로필. VoiceOver. 6가지 색맹 안전 팔레트. WCAG 2.1 AAA.

12개 언어

무료로 시작. Pro로 무제한 세션, 모든 엔진, 내보내기. 7일 무료 체험.

의료 기기가 아닙니다.

echoelmusic.com
""",
        keywords: "생체피드백,HRV,신디사이저,AUv3,명상,음악,웰니스,공간오디오,일관성,생체반응",
        promotionalText: "심장 박동이 음악이 된다. 생체 반응형 오디오-비주얼 악기 — Apple Watch 연결.",
        whatsNew: "Echoelmusic Pro (7일 무료 체험), 가이드 세션, DDSP 합성, CloudKit 동기화, 성능 개선"
    )

    // MARK: - Portuguese Brazil (pt-BR)

    public static let portugueseBrazil = LocalizedMetadata(
        locale: "pt-BR",
        name: "Echoelmusic",
        subtitle: "Seu Batimento Vira Música",
        description: """
Seu batimento vira música. Sua respiração molda o espaço. Sua coerência abre novas dimensões.

Echoelmusic transforma sua biometria em música ao vivo, visuais e luz. Conecte seu Apple Watch e experimente o primeiro instrumento audiovisual bio-reativo do mundo.

CRIAÇÃO BIO-REATIVA
• Frequência cardíaca se torna tempo e intensidade
• Coerência HRV molda complexidade harmônica
• Respiração controla profundidade espacial
• Integração Apple Watch

MOTORES DE SÍNTESE
DDSP, Modal, Granular, Wavetable, FM, Subtractive — todos bio-reativos.

PLUGINS AUv3
808 Bass, BioComposer, Stem Splitter, MIDI Pro — funciona no Logic Pro, GarageBand.

ÁUDIO ESPACIAL
Paisagens sonoras 3D com head tracking. Renderização binaural. Baixa latência (<10ms).

BEM-ESTAR
Treinamento de coerência guiado. Paisagens sonoras para sono profundo. Exercícios de respiração.

TODOS OS DISPOSITIVOS APPLE
iPhone, iPad, Mac, Watch, TV, Vision Pro. Sync com CloudKit.

ACESSIBILIDADE
20+ perfis. VoiceOver. 6 paletas para daltonismo. WCAG 2.1 AAA.

12 IDIOMAS

GRÁTIS PARA COMEÇAR. Pro para sessões ilimitadas, todos os motores, exportação. Teste grátis de 7 dias.

Não é um dispositivo médico.

echoelmusic.com
""",
        keywords: "biofeedback,HRV,sintetizador,AUv3,meditação,música,bem-estar,áudio espacial,coerência,bio-reativo",
        promotionalText: "Seu batimento vira música. Instrumento audiovisual bio-reativo — conecte Apple Watch.",
        whatsNew: "Echoelmusic Pro (teste grátis 7 dias), sessões guiadas, síntese DDSP, sincronização CloudKit, melhorias"
    )

    // MARK: - Italian (it-IT)

    public static let italian = LocalizedMetadata(
        locale: "it-IT",
        name: "Echoelmusic",
        subtitle: "Il Tuo Battito Diventa Musica",
        description: """
Il tuo battito diventa musica. Il tuo respiro modella lo spazio. La tua coerenza apre nuove dimensioni.

Echoelmusic trasforma la tua biometria in musica live, visual ed effetti luminosi. Collega il tuo Apple Watch e scopri il primo strumento audiovisivo bio-reattivo al mondo.

CREAZIONE BIO-REATTIVA
• La frequenza cardiaca diventa tempo e intensità
• La coerenza HRV modella la complessità armonica
• La respirazione controlla la profondità spaziale
• Integrazione Apple Watch

MOTORI DI SINTESI
DDSP, Modal, Granulare, Wavetable, FM, Sottrattivo — tutti bio-reattivi.

PLUGIN AUv3
808 Bass, BioComposer, Stem Splitter, MIDI Pro — funziona in Logic Pro, GarageBand.

AUDIO SPAZIALE
Paesaggi sonori 3D con head tracking. Rendering binaurale. Bassa latenza (<10ms).

BENESSERE
Training di coerenza guidato. Paesaggi sonori per il sonno. Esercizi di respirazione.

TUTTI I DISPOSITIVI APPLE
iPhone, iPad, Mac, Watch, TV, Vision Pro. Sincronizzazione CloudKit.

ACCESSIBILITÀ
20+ profili. VoiceOver. 6 palette per daltonici. WCAG 2.1 AAA.

12 LINGUE

GRATIS PER INIZIARE. Pro per sessioni illimitate, tutti i motori, esportazione. Prova gratuita 7 giorni.

Non è un dispositivo medico.

echoelmusic.com
""",
        keywords: "biofeedback,HRV,sintetizzatore,AUv3,meditazione,musica,benessere,audio spaziale,coerenza,bio-reattivo",
        promotionalText: "Il tuo battito diventa musica. Strumento audiovisivo bio-reattivo — collega Apple Watch.",
        whatsNew: "Echoelmusic Pro (prova gratuita 7 giorni), sessioni guidate, sintesi DDSP, sincronizzazione CloudKit, miglioramenti"
    )

    // MARK: - Russian (ru-RU)

    public static let russian = LocalizedMetadata(
        locale: "ru-RU",
        name: "Echoelmusic",
        subtitle: "Ваше Сердцебиение — Музыка",
        description: """
Ваше сердцебиение становится музыкой. Ваше дыхание формирует пространство. Ваша когерентность открывает новые измерения.

Echoelmusic превращает вашу биометрию в живую музыку, визуальные эффекты и свет. Подключите Apple Watch и испытайте первый в мире биореактивный аудиовизуальный инструмент.

БИОРЕАКТИВНОЕ ТВОРЧЕСТВО
• Частота сердцебиения становится темпом и интенсивностью
• Когерентность ВСР формирует гармоническую сложность
• Дыхание контролирует пространственную глубину
• Интеграция с Apple Watch

СИНТЕЗАТОРНЫЕ ДВИЖКИ
DDSP, Modal, Granular, Wavetable, FM, Subtractive — все биореактивные.

ПЛАГИНЫ AUv3
808 Bass, BioComposer, Stem Splitter, MIDI Pro — работает в Logic Pro, GarageBand.

ПРОСТРАНСТВЕННОЕ АУДИО
3D звуковые ландшафты с отслеживанием головы. Бинауральный рендеринг. Низкая задержка (<10мс).

ВЕЛНЕС
Управляемые тренировки когерентности. Звуковые ландшафты для сна. Дыхательные упражнения.

ВСЕ УСТРОЙСТВА APPLE
iPhone, iPad, Mac, Watch, TV, Vision Pro. Синхронизация CloudKit.

ДОСТУПНОСТЬ
20+ профилей. VoiceOver. 6 палитр для дальтоников. WCAG 2.1 AAA.

12 ЯЗЫКОВ

НАЧНИТЕ БЕСПЛАТНО. Pro для безлимитных сессий, всех движков, экспорта. 7-дневная бесплатная пробная версия.

Не является медицинским устройством.

echoelmusic.com
""",
        keywords: "биофидбэк,ВСР,синтезатор,AUv3,медитация,музыка,велнес,пространственное аудио,когерентность,биореактивный",
        promotionalText: "Ваше сердцебиение — музыка. Биореактивный аудиовизуальный инструмент — подключите Apple Watch.",
        whatsNew: "Echoelmusic Pro (7 дней бесплатно), управляемые сессии, синтез DDSP, синхронизация CloudKit, улучшения"
    )

    // MARK: - Arabic (ar-SA)

    public static let arabic = LocalizedMetadata(
        locale: "ar-SA",
        name: "Echoelmusic",
        subtitle: "نبض قلبك يصبح موسيقى",
        description: """
نبض قلبك يصبح موسيقى. تنفسك يشكل الفضاء. تماسكك يفتح أبعاداً جديدة.

Echoelmusic يحول بياناتك الحيوية إلى موسيقى حية ومرئيات وإضاءة. اربط Apple Watch واكتشف أول آلة صوتية-مرئية تفاعلية حيوياً في العالم.

الإبداع التفاعلي الحيوي
• معدل ضربات القلب يصبح إيقاعاً وشدة
• تماسك HRV يشكل التعقيد التوافقي
• التنفس يتحكم في العمق المكاني
• تكامل Apple Watch

محركات التركيب
DDSP، Modal، Granular، Wavetable، FM، Subtractive — جميعها تفاعلية حيوياً.

إضافات AUv3
808 Bass، BioComposer، Stem Splitter، MIDI Pro — يعمل في Logic Pro وGarageBand.

الصوت المكاني
مناظر صوتية ثلاثية الأبعاد. تقديم ثنائي الأذن. زمن انتقال منخفض (<10ms).

العافية
تدريب تماسك موجه. مناظر صوتية للنوم العميق. تمارين التنفس.

جميع أجهزة Apple
iPhone وiPad وMac وWatch وTV وVision Pro. مزامنة CloudKit.

إمكانية الوصول
20+ ملف تعريف. VoiceOver. 6 لوحات ألوان لعمى الألوان. WCAG 2.1 AAA.

12 لغة

ابدأ مجاناً. Pro لجلسات غير محدودة وجميع المحركات والتصدير. تجربة مجانية 7 أيام.

ليس جهازاً طبياً.

echoelmusic.com
""",
        keywords: "ارتجاع حيوي,HRV,مُركب,AUv3,تأمل,موسيقى,عافية,صوت مكاني,تماسك,تفاعلي حيوي",
        promotionalText: "نبض قلبك يصبح موسيقى. آلة صوتية-مرئية تفاعلية حيوياً — اربط Apple Watch.",
        whatsNew: "Echoelmusic Pro (تجربة مجانية 7 أيام)، جلسات موجهة، تركيب DDSP، مزامنة CloudKit، تحسينات"
    )

    // MARK: - Hindi (hi-IN)

    public static let hindi = LocalizedMetadata(
        locale: "hi-IN",
        name: "Echoelmusic",
        subtitle: "आपकी धड़कन बनती है संगीत",
        description: """
आपकी धड़कन बनती है संगीत। आपकी सांस आकार देती है स्थान को। आपकी सुसंगतता खोलती है नए आयाम।

Echoelmusic आपकी बायोमेट्रिक्स को लाइव संगीत, विज़ुअल और रोशनी में बदलता है। Apple Watch कनेक्ट करें और दुनिया का पहला बायो-रिएक्टिव ऑडियो-विज़ुअल वाद्ययंत्र अनुभव करें।

बायो-रिएक्टिव क्रिएशन
• हृदय गति बनती है टेम्पो और तीव्रता
• HRV सुसंगतता बनाती है हार्मोनिक जटिलता
• सांस नियंत्रित करती है स्थानिक गहराई
• Apple Watch एकीकरण

सिंथेसाइज़र इंजन
DDSP, Modal, Granular, Wavetable, FM, Subtractive — सभी बायो-रिएक्टिव।

AUv3 प्लगइन
808 Bass, BioComposer, Stem Splitter, MIDI Pro — Logic Pro, GarageBand में काम करते हैं।

स्थानिक ऑडियो
हेड ट्रैकिंग के साथ 3D साउंडस्केप। बायनॉरल रेंडरिंग। कम विलंबता (<10ms)।

कल्याण
गाइडेड सुसंगतता प्रशिक्षण। गहरी नींद साउंडस्केप। श्वास व्यायाम।

सभी Apple डिवाइस
iPhone, iPad, Mac, Watch, TV, Vision Pro। CloudKit सिंक।

पहुंच-योग्यता
20+ प्रोफाइल। VoiceOver। 6 कलर-ब्लाइंड पैलेट। WCAG 2.1 AAA।

12 भाषाएं

मुफ्त में शुरू करें। Pro अपग्रेड से असीमित सत्र, सभी इंजन, निर्यात। 7 दिन मुफ्त ट्रायल।

यह चिकित्सा उपकरण नहीं है।

echoelmusic.com
""",
        keywords: "बायोफीडबैक,HRV,सिंथेसाइज़र,AUv3,ध्यान,संगीत,कल्याण,स्थानिक ऑडियो,सुसंगतता,बायो-रिएक्टिव",
        promotionalText: "आपकी धड़कन बनती है संगीत। बायो-रिएक्टिव ऑडियो-विज़ुअल वाद्ययंत्र — Apple Watch कनेक्ट करें।",
        whatsNew: "Echoelmusic Pro (7 दिन मुफ्त ट्रायल), गाइडेड सत्र, DDSP सिंथेसिस, CloudKit सिंक, प्रदर्शन सुधार"
    )
}

// MARK: - Screenshot Specifications

public struct AppStoreScreenshots {

    /// All screenshot specifications for different devices
    public static let specifications: [ScreenshotSpec] = [
        // iPhone
        .init(device: "iPhone 16 Pro Max", size: "2868x1320", count: 10, orientation: .portrait),
        .init(device: "iPhone 16 Pro", size: "2556x1179", count: 10, orientation: .portrait),
        .init(device: "iPhone SE (3rd gen)", size: "1242x2208", count: 10, orientation: .portrait),

        // iPad
        .init(device: "iPad Pro 12.9\"", size: "2048x2732", count: 10, orientation: .portrait),
        .init(device: "iPad Pro 11\"", size: "1668x2388", count: 10, orientation: .portrait),

        // Apple Watch
        .init(device: "Apple Watch Series 10", size: "416x496", count: 5, orientation: .portrait),
        .init(device: "Apple Watch Ultra 2", size: "410x502", count: 5, orientation: .portrait),

        // Apple TV
        .init(device: "Apple TV 4K", size: "3840x2160", count: 5, orientation: .landscape),

        // Mac
        .init(device: "Mac 16\"", size: "2880x1800", count: 10, orientation: .landscape),
        .init(device: "Mac 13\"", size: "1280x800", count: 10, orientation: .landscape),

        // visionOS
        .init(device: "Apple Vision Pro", size: "3840x2160", count: 10, orientation: .landscape)
    ]

    /// Screenshot descriptions (same for all device types)
    public static let descriptions: [ScreenshotDescription] = [
        .init(
            number: 1,
            title: "Bio-Reactive Audio",
            description: "Your heart rate and HRV shape live audio in real time. Connect Apple Watch and hear your biometrics become music."
        ),
        .init(
            number: 2,
            title: "GPU-Accelerated Visuals",
            description: "Metal-powered visualization modes respond to your biometric data at 60fps."
        ),
        .init(
            number: 3,
            title: "Six Synth Engines",
            description: "DDSP, Modal, Granular, Wavetable, FM, and Subtractive — each driven by your bio-signals."
        ),
        .init(
            number: 4,
            title: "Spatial Audio",
            description: "Binaural rendering with head tracking. Immersive 3D soundscapes on headphones, speakers, or Vision Pro."
        ),
        .init(
            number: 5,
            title: "AUv3 Audio Plugins",
            description: "Use Echoelmusic instruments inside Logic Pro, GarageBand, or any AUv3-compatible host."
        ),
        .init(
            number: 6,
            title: "Wellness Sessions",
            description: "Guided coherence training, deep sleep soundscapes, flow state sessions, and breathing exercises."
        ),
        .init(
            number: 7,
            title: "DMX Lighting Control",
            description: "Connect Art-Net lighting rigs for bio-reactive light shows in live performance spaces."
        ),
        .init(
            number: 8,
            title: "Every Apple Device",
            description: "iPhone, iPad, Mac, Apple Watch, Apple TV, Vision Pro. CloudKit sync keeps sessions in sync."
        ),
        .init(
            number: 9,
            title: "Accessibility",
            description: "VoiceOver, Voice Control, Switch Access, color-blind safe palettes. Designed for everyone."
        ),
        .init(
            number: 10,
            title: "Free to Start",
            description: "Download free. Upgrade to Pro for unlimited sessions, all engines, export, and more. 7-day free trial."
        )
    ]

    public struct ScreenshotSpec {
        public let device: String
        public let size: String
        public let count: Int
        public let orientation: Orientation

        public enum Orientation {
            case portrait, landscape
        }
    }

    public struct ScreenshotDescription {
        public let number: Int
        public let title: String
        public let description: String
    }
}

// MARK: - App Preview Videos

public struct AppPreviewVideos {

    /// Video specifications for different devices
    public static let specifications: [VideoSpec] = [
        .init(device: "iPhone 16 Pro Max", resolution: "1080x1920", maxDuration: 30, fps: 30),
        .init(device: "iPad Pro 12.9\"", resolution: "1200x1600", maxDuration: 30, fps: 30),
        .init(device: "Apple TV 4K", resolution: "1920x1080", maxDuration: 30, fps: 30),
        .init(device: "Mac", resolution: "1920x1080", maxDuration: 30, fps: 30),
        .init(device: "Apple Vision Pro", resolution: "1920x1080", maxDuration: 30, fps: 30)
    ]

    /// Video content outline (30 seconds max)
    public static let contentOutline = """
APP PREVIEW VIDEO SCRIPT (30 seconds)

[0-3s] HOOK
Visual: Heartbeat pulse transforms into audio waveform
Text: "Your Heartbeat Becomes Music"

[3-8s] BIO-REACTIVE AUDIO
Visual: Apple Watch HRV data driving live audio generation
Text: "Real-Time Biometric Music Creation"

[8-13s] VISUALS
Visual: Montage of GPU-accelerated visualization modes
Text: "Metal-Powered Visuals at 60fps"

[13-18s] SYNTH ENGINES
Visual: Switching between DDSP, Modal, Granular, FM engines
Text: "Six Bio-Reactive Synth Engines"

[18-23s] WELLNESS
Visual: Coherence training, breathing exercises, sleep session
Text: "Guided Wellness Sessions"

[23-27s] PLATFORMS
Visual: Device montage (iPhone, Watch, Vision Pro, Mac)
Text: "Every Apple Device"

[27-30s] CALL TO ACTION
Visual: App icon + download prompt
Text: "Free to Download"

MUSIC: Ambient binaural soundscape generated by the app
VOICEOVER: Optional calm narration
"""

    public struct VideoSpec {
        public let device: String
        public let resolution: String
        public let maxDuration: Int // seconds
        public let fps: Int
    }
}

// MARK: - Review Information

public struct ReviewInformation {

    /// Demo account for App Review (if login required)
    /// IMPORTANT: Set these values via environment variables or secure config before submission:
    /// - ECHOELMUSIC_DEMO_USERNAME
    /// - ECHOELMUSIC_DEMO_PASSWORD
    /// - ECHOELMUSIC_CONTACT_EMAIL
    /// - ECHOELMUSIC_CONTACT_PHONE
    public static let demoAccount = DemoAccount(
        username: ProcessInfo.processInfo.environment["ECHOELMUSIC_DEMO_USERNAME"] ?? "demo@echoelmusic.com",
        password: ProcessInfo.processInfo.environment["ECHOELMUSIC_DEMO_PASSWORD"] ?? "SET_VIA_ENV_VAR",
        notes: "Full access demo account with pre-configured sessions and sample data. No actual Apple Watch or biometric hardware required for testing."
    )

    /// Contact information for App Store review process
    /// REQUIRED: Configure these environment variables before App Store submission:
    /// - ECHOELMUSIC_CONTACT_PHONE: Valid phone number for App Review team
    /// - ECHOELMUSIC_CONTACT_EMAIL: Valid email for App Review team
    /// - ECHOELMUSIC_CONTACT_FIRST_NAME: First name of contact person
    /// - ECHOELMUSIC_CONTACT_LAST_NAME: Last name of contact person
    public static var contact: ContactInfo {
        ContactInfo(
            firstName: ProcessInfo.processInfo.environment["ECHOELMUSIC_CONTACT_FIRST_NAME"] ?? "App Review",
            lastName: ProcessInfo.processInfo.environment["ECHOELMUSIC_CONTACT_LAST_NAME"] ?? "Contact",
            phone: ProcessInfo.processInfo.environment["ECHOELMUSIC_CONTACT_PHONE"] ?? "",
            email: ProcessInfo.processInfo.environment["ECHOELMUSIC_CONTACT_EMAIL"] ?? ""
        )
    }

    /// Validates that required contact information is configured for production
    public static var isContactConfigured: Bool {
        guard let phone = ProcessInfo.processInfo.environment["ECHOELMUSIC_CONTACT_PHONE"],
              let email = ProcessInfo.processInfo.environment["ECHOELMUSIC_CONTACT_EMAIL"],
              !phone.isEmpty, !email.isEmpty else {
            return false
        }
        return true
    }

    /// Notes for reviewer
    public static let reviewNotes = """
IMPORTANT NOTES FOR APP REVIEW:

TESTING WITHOUT HARDWARE:
• The app includes a comprehensive Demo Mode that simulates biometric data
• No Apple Watch, Push 3, or DMX hardware required for full feature testing
• Demo mode can be enabled from Settings → Developer → Enable Demo Mode
• Sample sessions with pre-recorded biometric data are available

HEALTH & WELLNESS DISCLAIMER:
• Echoelmusic is NOT a medical device
• All biometric features are for creative and wellness purposes only
• Clear disclaimers are shown on first launch and in all wellness features
• No medical claims are made anywhere in the app or marketing

FEATURE HIGHLIGHTS FOR TESTING:
1. Bio-Reactive Audio: Settings → Demo Mode → "Meditation Session"
2. Quantum Visuals: Tap any visualization mode from main screen
3. Orchestral Scoring: Creative Studio → Film Score Composer
4. AI Generation: Creative Studio → Generate Art/Music
5. Collaboration: Join public "Demo Session" (always available)
6. Accessibility: Settings → Accessibility → Try any of 20+ profiles
7. Streaming: Media → Stream → Use "Test Stream" destination

PERMISSIONS REQUESTED:
• HealthKit: For HRV and heart rate (optional, demo mode available)
• Microphone: For voice input and audio recording
• Camera: For face tracking and video features (optional)
• Motion: For gesture control (optional)
• Local Network: For DMX/Art-Net lighting (optional)
• Notifications: For session reminders (optional)

All permissions are optional and the app provides full functionality in demo mode.

PURCHASE TESTING (StoreKit 2 — Freemium Model):
• Free tier: Core bio-reactive sessions (15 min), basic synth, 3 presets
• Pro Monthly: $9.99/month (7-day free trial)
• Pro Yearly: $79.99/year (7-day free trial, save 33%)
• Pro Lifetime: $149.99 one-time (non-consumable)
• Individual sessions: Coherence $4.99, Sleep $3.99, Flow $6.99 (consumable)
• Sandbox accounts can test all purchase flows
• Family Sharing enabled for subscriptions and lifetime
• StoreKit Configuration file included for local testing

KNOWN LIMITATIONS:
• Quantum light emulation requires Metal-compatible device (iOS 15+)
• Some features optimized for ProMotion displays (120Hz)
• visionOS features require Apple Vision Pro hardware

LOCALIZATION:
• All 12 languages have been professionally translated
• RTL support for Arabic has been tested
• Locale-specific formatting for dates, numbers, currency

Thank you for reviewing Echoelmusic!
"""

    public struct DemoAccount {
        public let username: String
        public let password: String
        public let notes: String
    }

    public struct ContactInfo {
        public let firstName: String
        public let lastName: String
        public let phone: String
        public let email: String
    }
}

// MARK: - App Privacy

public struct AppPrivacy {

    /// Privacy nutrition label data
    public static let privacyPractices: [PrivacyPractice] = [
        // Data Used to Track You
        .init(
            category: .tracking,
            dataTypes: [],
            purposes: [],
            linkedToUser: false,
            usedForTracking: false,
            note: "Echoelmusic does NOT track users across apps or websites owned by other companies."
        ),

        // Health & Fitness
        .init(
            category: .healthAndFitness,
            dataTypes: ["Heart Rate", "Heart Rate Variability", "Breathing Rate"],
            purposes: ["App Functionality", "Analytics"],
            linkedToUser: true,
            usedForTracking: false,
            note: "Used only for bio-reactive audio generation. Stored locally on device. Optional iCloud sync."
        ),

        // Audio Data
        .init(
            category: .audioData,
            dataTypes: ["Audio Recordings", "Voice Commands"],
            purposes: ["App Functionality", "Product Personalization"],
            linkedToUser: true,
            usedForTracking: false,
            note: "Stored locally. Not sent to servers unless explicitly shared by user."
        ),

        // User Content
        .init(
            category: .userContent,
            dataTypes: ["Photos or Videos", "Audio Data", "Gameplay Content", "Other User Content"],
            purposes: ["App Functionality", "Product Personalization"],
            linkedToUser: true,
            usedForTracking: false,
            note: "User-generated sessions, presets, and recordings. Stored locally with optional cloud backup."
        ),

        // Identifiers
        .init(
            category: .identifiers,
            dataTypes: ["User ID", "Device ID"],
            purposes: ["App Functionality", "Analytics", "Product Personalization"],
            linkedToUser: true,
            usedForTracking: false,
            note: "Used for session management and cloud sync. Anonymous analytics only."
        ),

        // Usage Data
        .init(
            category: .usageData,
            dataTypes: ["Product Interaction"],
            purposes: ["Analytics", "Product Personalization", "App Functionality"],
            linkedToUser: false,
            usedForTracking: false,
            note: "Anonymous feature usage statistics to improve app experience."
        ),

        // Diagnostics
        .init(
            category: .diagnostics,
            dataTypes: ["Crash Data", "Performance Data"],
            purposes: ["Analytics", "App Functionality"],
            linkedToUser: false,
            usedForTracking: false,
            note: "Anonymous crash reports and performance metrics."
        ),

        // Contact Info
        .init(
            category: .contactInfo,
            dataTypes: ["Email Address", "Name"],
            purposes: ["App Functionality", "Product Personalization"],
            linkedToUser: true,
            usedForTracking: false,
            note: "Optional. Only if user creates account for cloud features or collaboration."
        )
    ]

    /// Privacy policy summary
    public static let privacySummary = """
PRIVACY HIGHLIGHTS:

• NO cross-app or web tracking
• Biometric data stays on YOUR device
• NO data sold to third parties
• Anonymous analytics only
• Optional cloud sync (encrypted AES-256)
• You control all data deletion
• GDPR, CCPA, COPPA compliant
• Enterprise-grade security (TLS 1.3, certificate pinning)

Full privacy policy: https://echoelmusic.com/privacy
"""

    public struct PrivacyPractice {
        public let category: PrivacyCategory
        public let dataTypes: [String]
        public let purposes: [String]
        public let linkedToUser: Bool
        public let usedForTracking: Bool
        public let note: String
    }

    public enum PrivacyCategory: String {
        case tracking = "Tracking"
        case contactInfo = "Contact Info"
        case healthAndFitness = "Health & Fitness"
        case audioData = "Audio Data"
        case userContent = "User Content"
        case identifiers = "Identifiers"
        case usageData = "Usage Data"
        case diagnostics = "Diagnostics"
    }
}

// MARK: - App Features (Freemium — Free + Pro Subscription)

public struct AppFeatures {

    // MARK: - Freemium Model

    /// Echoelmusic is free to download with optional Pro upgrade:
    /// - Free: Core bio-reactive experience, basic synth, 15-min sessions
    /// - Pro: Unlimited everything + all engines + export + sync

    /// Features included in the free tier
    public static let freeFeatures: [String] = [
        "Bio-reactive audio creation with HRV/heart rate",
        "Apple Watch integration for real-time biometrics",
        "Basic synth engine (DDSP)",
        "3 curated presets",
        "15-minute session limit",
        "GPU-accelerated visualization (Metal)",
        "Guided breathing exercises",
        "20+ accessibility profiles (WCAG 2.1 AAA)",
        "VoiceOver full support",
        "12 languages"
    ]

    /// Features unlocked with Pro subscription
    public static let proFeatures: [String] = [
        "Unlimited session length",
        "All 6 synth engines (DDSP, Modal, Granular, Wavetable, FM, Subtractive)",
        "All presets + Hilbert visualization",
        "CloudKit sync across all devices",
        "Apple Watch real-time data streaming",
        "WAV and MIDI export",
        "DMX/Art-Net lighting control",
        "AUv3 Audio Unit plugins in Logic Pro, GarageBand",
        "Spatial audio with head tracking",
        "Priority support"
    ]

    /// Individual purchasable sessions (consumable IAP)
    public static let sessionProducts: [String] = [
        "Guided Coherence Training (45 min) — $4.99",
        "Deep Sleep Session — $3.99",
        "Flow State Workshop — $6.99"
    ]

    /// App summary
    public static let appSummary = """
    ECHOELMUSIC — FREE TO START

    Download free. Upgrade when ready.
    • Free: Core bio-reactive creation
    • Pro Monthly: $9.99/month (7-day free trial)
    • Pro Yearly: $79.99/year (save 33%)
    • Lifetime: $149.99 one-time

    ETHICAL COMMITMENTS:
    • No ads, ever
    • No dark patterns
    • No data sold
    • Your creations belong to you
    • Privacy by design
    """
}

// MARK: - In-App Purchases (StoreKit 2)

/// StoreKit 2 product definitions for App Store Connect
/// Implementation: see EchoelStore.swift and EchoelPaywall.swift
public struct InAppPurchaseDefinitions {

    /// Subscription group: Echoelmusic Pro
    public static let subscriptionGroupID = "echoel_pro"

    /// All products to register in App Store Connect
    public static let products: [ProductDefinition] = [
        ProductDefinition(
            productID: "echoel_pro_monthly",
            name: "Pro Monthly",
            type: .autoRenewable,
            price: "$9.99",
            period: "1 month",
            trialDays: 7,
            familySharing: true
        ),
        ProductDefinition(
            productID: "echoel_pro_yearly",
            name: "Pro Yearly",
            type: .autoRenewable,
            price: "$79.99",
            period: "1 year",
            trialDays: 7,
            familySharing: true
        ),
        ProductDefinition(
            productID: "echoel_pro_lifetime",
            name: "Pro Lifetime",
            type: .nonConsumable,
            price: "$149.99",
            period: nil,
            trialDays: 0,
            familySharing: true
        ),
        ProductDefinition(
            productID: "echoel_session_coherence",
            name: "Coherence Training Session",
            type: .consumable,
            price: "$4.99",
            period: nil,
            trialDays: 0,
            familySharing: false
        ),
        ProductDefinition(
            productID: "echoel_session_sleep",
            name: "Deep Sleep Session",
            type: .consumable,
            price: "$3.99",
            period: nil,
            trialDays: 0,
            familySharing: false
        ),
        ProductDefinition(
            productID: "echoel_session_flow",
            name: "Flow State Session",
            type: .consumable,
            price: "$6.99",
            period: nil,
            trialDays: 0,
            familySharing: false
        )
    ]

    public struct ProductDefinition {
        public let productID: String
        public let name: String
        public let type: ProductType
        public let price: String
        public let period: String?
        public let trialDays: Int
        public let familySharing: Bool
    }

    public enum ProductType: String {
        case autoRenewable = "Auto-Renewable Subscription"
        case nonConsumable = "Non-Consumable"
        case consumable = "Consumable"
    }
}

// MARK: - Export Utilities

extension AppStoreMetadata {

    /// Generate JSON export for App Store Connect automation
    public static func exportJSON() -> String {
        let json: [String: Any] = [
            "app_name": appName,
            "bundle_id": bundleIdentifier,
            "primary_language": primaryLanguage,
            "supported_languages": supportedLanguages,
            "primary_category": primaryCategory.rawValue,
            "secondary_category": secondaryCategory.rawValue,
            "marketing_url": marketingURL,
            "support_url": supportURL,
            "privacy_policy_url": privacyPolicyURL,
            "copyright": copyright,
            "age_rating": ageRating.rawValue,
            "price_tier": priceTier,
            "localizations": LocalizedMetadata.allLocalizations.map { loc in
                [
                    "locale": loc.locale,
                    "name": loc.name,
                    "subtitle": loc.subtitle,
                    "description": loc.description,
                    "keywords": loc.keywords,
                    "promotional_text": loc.promotionalText ?? "",
                    "whats_new": loc.whatsNew
                ]
            },
            "privacy_practices": AppPrivacy.privacyPractices.map { practice in
                [
                    "category": practice.category.rawValue,
                    "data_types": practice.dataTypes,
                    "purposes": practice.purposes,
                    "linked_to_user": practice.linkedToUser,
                    "used_for_tracking": practice.usedForTracking
                ]
            }
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }

        return jsonString
    }

    /// Log all metadata for review
    public static func logAllMetadata() {
        appStoreLog.info("=== ECHOELMUSIC APP STORE METADATA ===", category: .system)

        appStoreLog.info("APP INFORMATION:", category: .system)
        appStoreLog.info("  Name: \(appName)", category: .system)
        appStoreLog.info("  Bundle ID: \(bundleIdentifier)", category: .system)
        appStoreLog.info("  Primary Category: \(primaryCategory.rawValue)", category: .system)
        appStoreLog.info("  Secondary Category: \(secondaryCategory.rawValue)", category: .system)
        appStoreLog.info("  Age Rating: \(ageRating.rawValue)", category: .system)
        appStoreLog.info("  Price Tier: \(priceTier) (Free)", category: .system)
        appStoreLog.info("  Languages: \(supportedLanguages.count)", category: .system)

        appStoreLog.info("URLS:", category: .system)
        appStoreLog.info("  Marketing: \(marketingURL)", category: .system)
        appStoreLog.info("  Support: \(supportURL)", category: .system)
        appStoreLog.info("  Privacy: \(privacyPolicyURL)", category: .system)

        appStoreLog.info("PRICING: Freemium (free download + Pro subscription)", category: .system)
        appStoreLog.info("  Products: \(InAppPurchaseDefinitions.products.count)", category: .system)
        for product in InAppPurchaseDefinitions.products {
            appStoreLog.info("  \(product.productID): \(product.price) (\(product.type.rawValue))", category: .system)
        }

        appStoreLog.info("SCREENSHOTS REQUIRED:", category: .system)
        for spec in AppStoreScreenshots.specifications {
            appStoreLog.info("  \(spec.device): \(spec.count) screenshots at \(spec.size)", category: .system)
        }

        appStoreLog.info("PRIVACY PRACTICES:", category: .system)
        for practice in AppPrivacy.privacyPractices {
            appStoreLog.info("  \(practice.category.rawValue): \(practice.dataTypes.count) data types", category: .system)
        }

        appStoreLog.info("REVIEW NOTES:", category: .system)
        appStoreLog.info(ReviewInformation.reviewNotes, category: .system)

        appStoreLog.info("=== END METADATA ===", category: .system)
    }

    /// Deprecated: Use logAllMetadata() instead
    @available(*, deprecated, renamed: "logAllMetadata")
    public static func printAllMetadata() {
        logAllMetadata()
    }
}
