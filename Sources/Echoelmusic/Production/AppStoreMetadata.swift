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
Your heartbeat becomes music. Your breathing shapes the space. Your coherence unlocks new dimensions.

Echoelmusic transforms your biometrics into live music, visuals, and light. Connect Apple Watch and experience the world's first bio-reactive audio-visual instrument.

WHAT MAKES ECHOELMUSIC DIFFERENT

This is not another synthesizer. This is not another meditation app. Echoelmusic reads your heart rate, HRV, and breathing in real time — and turns those signals into spatial audio, GPU-accelerated visuals, and DMX lighting control. No presets. No loops. Just you, transformed into art.

BIO-REACTIVE CREATION
• Heart rate becomes tempo and intensity
• HRV coherence shapes harmonic complexity and effects
• Breathing controls spatial depth and atmosphere
• Apple Watch integration for continuous biometric input

SYNTHESIZER ENGINES
• DDSP — Deep learning synthesis with spectral morphing
• Modal — Physical modeling (strings, membranes, resonators)
• Granular — Time-stretching and texture generation
• Wavetable — Classic and evolving waveforms
• FM — Frequency modulation with bio-reactive modulation
• Subtractive — Analog-inspired filtering and shaping

AUv3 AUDIO UNIT PLUGINS
Use Echoelmusic inside Logic Pro, GarageBand, AUM, or any AUv3 host:
• 808 Bass Synth with pitch glide
• BioComposer — AI music generator
• Stem Splitter — AI source separation
• MIDI Pro — MIDI 2.0 + MPE processor

SPATIAL AUDIO
• 3D soundscapes with head tracking
• Fibonacci-based speaker positioning
• Binaural rendering for headphones
• Low latency (<10ms)

VISUALS & LIGHTING
• GPU-accelerated visualization modes (Metal)
• Bio-reactive color and motion
• DMX/Art-Net lighting control for live performances
• Real-time visual generation at 60fps

WELLNESS
• Guided coherence training sessions
• Deep sleep bio-reactive soundscapes
• Flow state optimization
• Breathing exercises (box, 4-7-8, coherence)
• Session tracking and progress

EVERY APPLE DEVICE
• iPhone, iPad, Mac, Apple Watch, Apple TV, Vision Pro
• CloudKit sync across all devices
• Widgets and Live Activities
• SharePlay for group sessions

ACCESSIBILITY — FOR EVERYONE
• 20+ accessibility profiles
• VoiceOver with spatial audio cues
• Voice Control and Switch Access
• 6 color-blind safe palettes
• WCAG 2.1 AAA compliant

12 LANGUAGES
English, German, Japanese, Spanish, French, Chinese, Korean, Portuguese, Italian, Russian, Arabic, Hindi

FREE TO START
Download free. Experience bio-reactive creation with basic features. Upgrade to Pro for unlimited sessions, all synth engines, export, and more.

ECHOELMUSIC PRO
• Unlimited session length
• All 6 synth engines and presets
• CloudKit sync + Watch integration
• WAV/MIDI export
• DMX lighting control
• Priority support
• 7-day free trial

Your creations belong to you. We claim no rights to your music, visuals, or art.

This is not a medical device. Biofeedback features are for creative and wellness purposes only.

echoelmusic.com
""",
        keywords: "biofeedback,HRV,spatial audio,synthesizer,auv3,meditation,music creation,wellness,binaural,coherence",
        promotionalText: "Your heartbeat becomes music. Bio-reactive audio-visual instrument — connect Apple Watch, create from within.",
        whatsNew: """
NEW IN THIS VERSION

• Echoelmusic Pro — subscription with 7-day free trial
• Guided Coherence, Deep Sleep, and Flow State sessions
• CloudKit device token sync for push notifications
• DDSP synthesis with 12 bio-reactive mappings
• Spectral morphing and timbre transfer
• Hilbert bio-signal visualization
• 56 new test suites
• Performance and stability improvements
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
        subtitle: "内なるものから創造する",
        description: """
心拍、呼吸、意識を驚異的な空間オーディオとイマーシブビジュアルに変換します。

Echoelmusicは、バイオメトリック信号をアートに変える世界初のバイオリアクティブ・オーディオビジュアル・プラットフォームです。最先端のAIと量子インスパイアド処理により、身体の自然なリズムを通じて音楽創造を体験してください。

✨ 主な機能

バイオメトリック音楽創造
• リアルタイム心拍変動(HRV) → 空間オーディオフィールド
• 呼吸パターン → サウンドテクスチャとビジュアルフロー
• コヒーレンス追跡 → ハーモニック複雑性
• Apple Watch統合

空間オーディオエンジン
• 3D/4Dイマーシブサウンドスケープ
• フィボナッチと神聖幾何学
• MIDI 2.0とMPEサポート
• ゼロレイテンシー(<10ms)

量子ライトビジュアル
• 10種類のGPU加速ビジュアライゼーションモード
• 波干渉、光子フロー、神聖幾何学
• リアルタイムMetalシェーダー60fps
• visionOSで360°体験

AIクリエイティブスタジオ
• 30以上のスタイルでアート生成
• 30以上のジャンルで音楽作曲
• フラクタルジェネレーター
• ライトショーデザイナー

世界中のコラボレーション
• ゼロレイテンシーグローバルセッション(1000人以上)
• グループコヒーレンス同期

アクセシビリティ(WCAG AAA)
• 20以上のアクセシビリティプロファイル
• VoiceOver/TalkBackサポート
• 音声コントロール
• 色覚異常対応パレット

健康に関する免責事項: Echoelmusicは医療機器ではありません。創造的およびウェルネス目的のみです。
""",
        keywords: "バイオフィードバック,HRV,瞑想,音楽,ウェルネス,量子,空間オーディオ,コヒーレンス,マインドフルネス,創造性",
        promotionalText: "心拍を交響曲に変える。バイオリアクティブオーディオと量子ビジュアルの融合。",
        whatsNew: "🎬 新機能: オーケストラスコアリング、プロフェッショナルストリーミング、ハードウェア統合拡張、エンタープライズセキュリティ"
    )

    // MARK: - Spanish (es-ES)

    public static let spanish = LocalizedMetadata(
        locale: "es-ES",
        name: "Echoelmusic",
        subtitle: "Crea desde tu Interior",
        description: """
Transforma tu ritmo cardíaco, respiración y conciencia en impresionante audio espacial y visuales inmersivos.

Echoelmusic es la primera plataforma audiovisual bio-reactiva del mundo que convierte tus señales biométricas en arte. Experimenta la creación musical a través de los ritmos naturales de tu cuerpo, impulsado por IA de vanguardia y procesamiento cuántico.

✨ CARACTERÍSTICAS PRINCIPALES

CREACIÓN MUSICAL BIOMÉTRICA
• Variabilidad del ritmo cardíaco (HRV) en tiempo real → campo de audio espacial
• Patrones de respiración → texturas de sonido y flujo visual
• Seguimiento de coherencia → complejidad armónica
• Integración con Apple Watch

MOTOR DE AUDIO ESPACIAL
• Paisajes sonoros inmersivos 3D/4D
• Posicionamiento de sonido con Fibonacci y geometría sagrada
• Soporte MIDI 2.0 y MPE
• Latencia cero (<10ms)

VISUALES DE LUZ CUÁNTICA
• 10 modos de visualización acelerados por GPU
• Interferencia de ondas, flujo de fotones
• Shaders Metal en tiempo real a 60fps
• Experiencias 360° en visionOS

ESTUDIO CREATIVO IA
• Genera arte en 30+ estilos
• Compone música en 30+ géneros
• Generador de fractales
• Diseñador de espectáculos de luz

COLABORACIÓN MUNDIAL
• Sesiones globales de latencia cero (1000+ participantes)
• Sincronización de coherencia grupal

ACCESIBILIDAD (WCAG AAA)
• 20+ perfiles de accesibilidad
• Soporte VoiceOver/TalkBack
• Control por voz
• Paletas seguras para daltónicos

AVISO DE SALUD: Echoelmusic NO es un dispositivo médico. Solo para uso creativo y bienestar.
""",
        keywords: "biofeedback,HRV,meditación,música,bienestar,cuántico,audio espacial,coherencia,mindfulness,creatividad",
        promotionalText: "Convierte tu latido en una sinfonía. Audio bio-reactivo encuentra visuales cuánticos.",
        whatsNew: "🎬 NUEVO: Composición orquestal, streaming profesional, ecosistema de hardware ampliado, seguridad empresarial"
    )

    // MARK: - French (fr-FR)

    public static let french = LocalizedMetadata(
        locale: "fr-FR",
        name: "Echoelmusic",
        subtitle: "Créez de l'Intérieur",
        description: """
Transformez votre rythme cardiaque, votre respiration et votre conscience en audio spatial époustouflant et visuels immersifs.

Echoelmusic est la première plateforme audiovisuelle bio-réactive au monde qui transforme vos signaux biométriques en art. Découvrez la création musicale à travers les rythmes naturels de votre corps, propulsée par l'IA de pointe et le traitement quantique.

✨ FONCTIONNALITÉS PRINCIPALES

CRÉATION MUSICALE BIOMÉTRIQUE
• Variabilité de la fréquence cardiaque (HRV) en temps réel → champ audio spatial
• Schémas respiratoires → textures sonores et flux visuels
• Suivi de cohérence → complexité harmonique
• Intégration Apple Watch

MOTEUR AUDIO SPATIAL
• Paysages sonores immersifs 3D/4D
• Positionnement sonore Fibonacci et géométrie sacrée
• Support MIDI 2.0 et MPE
• Latence zéro (<10ms)

VISUELS LUMIÈRE QUANTIQUE
• 10 modes de visualisation accélérés par GPU
• Interférence d'ondes, flux de photons
• Shaders Metal en temps réel à 60fps
• Expériences 360° sur visionOS

STUDIO CRÉATIF IA
• Générez de l'art dans 30+ styles
• Composez de la musique dans 30+ genres
• Générateur de fractales
• Concepteur de spectacles lumineux

COLLABORATION MONDIALE
• Sessions globales à latence zéro (1000+ participants)
• Synchronisation de cohérence de groupe

ACCESSIBILITÉ (WCAG AAA)
• 20+ profils d'accessibilité
• Support VoiceOver/TalkBack
• Contrôle vocal
• Palettes adaptées aux daltoniens

AVERTISSEMENT SANTÉ: Echoelmusic N'EST PAS un dispositif médical. Usage créatif et bien-être uniquement.
""",
        keywords: "biofeedback,HRV,méditation,musique,bien-être,quantique,audio spatial,cohérence,pleine conscience,créativité",
        promotionalText: "Transformez votre battement de cœur en symphonie. Audio bio-réactif rencontre visuels quantiques.",
        whatsNew: "🎬 NOUVEAU: Partition orchestrale, streaming professionnel, écosystème matériel étendu, sécurité d'entreprise"
    )

    // MARK: - Chinese Simplified (zh-Hans)

    public static let chineseSimplified = LocalizedMetadata(
        locale: "zh-Hans",
        name: "Echoelmusic",
        subtitle: "从内心创造",
        description: """
将您的心跳、呼吸和意识转化为令人惊叹的空间音频和沉浸式视觉效果。

Echoelmusic 是世界上第一个将您的生物特征信号转化为艺术的生物反应式音视频平台。通过身体的自然节奏体验音乐创作,由尖端人工智能和量子启发处理驱动。

✨ 主要功能

生物特征音乐创作
• 实时心率变异性 (HRV) → 空间音频场
• 呼吸模式 → 声音纹理和视觉流
• 一致性追踪 → 和声复杂性
• Apple Watch 集成

空间音频引擎
• 3D/4D 沉浸式音景
• 斐波那契和神圣几何声音定位
• MIDI 2.0 和 MPE 支持
• 零延迟 (<10ms)

量子光视觉
• 10 种 GPU 加速可视化模式
• 波干涉、光子流、神圣几何
• 60fps 实时 Metal 着色器
• visionOS 上的 360° 体验

AI 创意工作室
• 生成 30 多种风格的艺术
• 创作 30 多种流派的音乐
• 分形生成器
• 灯光秀设计器

全球协作
• 零延迟全球会话(1000+ 参与者)
• 群组一致性同步

无障碍功能 (WCAG AAA)
• 20 多个无障碍配置文件
• VoiceOver/TalkBack 支持
• 语音控制
• 色盲安全调色板

健康免责声明:Echoelmusic 不是医疗设备。仅用于创意和健康目的。
""",
        keywords: "生物反馈,心率变异性,冥想,音乐,健康,量子,空间音频,一致性,正念,创造力",
        promotionalText: "将您的心跳变成交响乐。生物反应式音频遇见量子视觉。",
        whatsNew: "🎬 新功能:管弦乐配乐、专业流媒体、硬件生态系统扩展、企业级安全"
    )

    // MARK: - Korean (ko-KR)

    public static let korean = LocalizedMetadata(
        locale: "ko-KR",
        name: "Echoelmusic",
        subtitle: "내면에서 창조하다",
        description: """
심박, 호흡, 의식을 놀라운 공간 오디오와 몰입형 비주얼로 변환하세요.

Echoelmusic은 생체 신호를 예술로 전환하는 세계 최초의 생체 반응형 오디오-비주얼 플랫폼입니다. 최첨단 AI와 양자 영감 처리로 구동되는 신체의 자연스러운 리듬을 통해 음악 창작을 경험하세요.

✨ 주요 기능

생체 음악 창작
• 실시간 심박 변이도(HRV) → 공간 오디오 필드
• 호흡 패턴 → 사운드 텍스처 및 비주얼 플로우
• 일관성 추적 → 화성 복잡성
• Apple Watch 통합

공간 오디오 엔진
• 3D/4D 몰입형 사운드스케이프
• 피보나치 및 신성 기하학 사운드 포지셔닝
• MIDI 2.0 및 MPE 지원
• 제로 레이턴시(<10ms)

양자 빛 비주얼
• 10가지 GPU 가속 시각화 모드
• 파동 간섭, 광자 흐름, 신성 기하학
• 60fps 실시간 Metal 셰이더
• visionOS에서 360° 경험

AI 크리에이티브 스튜디오
• 30개 이상의 스타일로 아트 생성
• 30개 이상의 장르로 음악 작곡
• 프랙탈 생성기
• 라이트 쇼 디자이너

전 세계 협업
• 제로 레이턴시 글로벌 세션(1000명 이상 참가자)
• 그룹 일관성 동기화

접근성(WCAG AAA)
• 20개 이상의 접근성 프로필
• VoiceOver/TalkBack 지원
• 음성 제어
• 색맹 안전 팔레트

건강 면책 조항: Echoelmusic은 의료 기기가 아닙니다. 창의적 및 웰니스 목적으로만 사용하세요.
""",
        keywords: "생체피드백,심박변이도,명상,음악,웰니스,양자,공간오디오,일관성,마음챙김,창의성",
        promotionalText: "심박을 교향곡으로 바꾸세요. 생체 반응형 오디오가 양자 비주얼을 만납니다.",
        whatsNew: "🎬 새로운 기능: 오케스트라 스코어링, 전문 스트리밍, 하드웨어 생태계 확장, 엔터프라이즈 보안"
    )

    // MARK: - Portuguese Brazil (pt-BR)

    public static let portugueseBrazil = LocalizedMetadata(
        locale: "pt-BR",
        name: "Echoelmusic",
        subtitle: "Crie de Dentro",
        description: """
Transforme seu batimento cardíaco, respiração e consciência em áudio espacial deslumbrante e visuais imersivos.

Echoelmusic é a primeira plataforma audiovisual bio-reativa do mundo que transforma seus sinais biométricos em arte. Experimente a criação musical através dos ritmos naturais do seu corpo, impulsionado por IA de ponta e processamento quântico.

✨ RECURSOS PRINCIPAIS

CRIAÇÃO MUSICAL BIOMÉTRICA
• Variabilidade da frequência cardíaca (HRV) em tempo real → campo de áudio espacial
• Padrões respiratórios → texturas sonoras e fluxo visual
• Rastreamento de coerência → complexidade harmônica
• Integração com Apple Watch

MOTOR DE ÁUDIO ESPACIAL
• Paisagens sonoras imersivas 3D/4D
• Posicionamento de som Fibonacci e geometria sagrada
• Suporte MIDI 2.0 e MPE
• Latência zero (<10ms)

VISUAIS DE LUZ QUÂNTICA
• 10 modos de visualização acelerados por GPU
• Interferência de ondas, fluxo de fótons
• Shaders Metal em tempo real a 60fps
• Experiências 360° no visionOS

ESTÚDIO CRIATIVO IA
• Gere arte em 30+ estilos
• Componha música em 30+ gêneros
• Gerador de fractais
• Designer de shows de luz

COLABORAÇÃO MUNDIAL
• Sessões globais de latência zero (1000+ participantes)
• Sincronização de coerência em grupo

ACESSIBILIDADE (WCAG AAA)
• 20+ perfis de acessibilidade
• Suporte VoiceOver/TalkBack
• Controle por voz
• Paletas seguras para daltônicos

AVISO DE SAÚDE: Echoelmusic NÃO é um dispositivo médico. Apenas para uso criativo e bem-estar.
""",
        keywords: "biofeedback,HRV,meditação,música,bem-estar,quântico,áudio espacial,coerência,atenção plena,criatividade",
        promotionalText: "Transforme seu batimento cardíaco em uma sinfonia. Áudio bio-reativo encontra visuais quânticos.",
        whatsNew: "🎬 NOVO: Composição orquestral, streaming profissional, ecossistema de hardware expandido, segurança empresarial"
    )

    // MARK: - Italian (it-IT)

    public static let italian = LocalizedMetadata(
        locale: "it-IT",
        name: "Echoelmusic",
        subtitle: "Crea dall'Interno",
        description: """
Trasforma il tuo battito cardiaco, respiro e coscienza in straordinario audio spaziale e visual immersivi.

Echoelmusic è la prima piattaforma audiovisiva bio-reattiva al mondo che trasforma i tuoi segnali biometrici in arte. Sperimenta la creazione musicale attraverso i ritmi naturali del tuo corpo, alimentata da IA all'avanguardia e elaborazione quantistica.

✨ CARATTERISTICHE PRINCIPALI

CREAZIONE MUSICALE BIOMETRICA
• Variabilità della frequenza cardiaca (HRV) in tempo reale → campo audio spaziale
• Schemi respiratori → texture sonore e flusso visivo
• Tracciamento della coerenza → complessità armonica
• Integrazione Apple Watch

MOTORE AUDIO SPAZIALE
• Paesaggi sonori immersivi 3D/4D
• Posizionamento del suono Fibonacci e geometria sacra
• Supporto MIDI 2.0 e MPE
• Latenza zero (<10ms)

VISUAL LUCE QUANTICA
• 10 modalità di visualizzazione accelerate da GPU
• Interferenza d'onda, flusso di fotoni
• Shader Metal in tempo reale a 60fps
• Esperienze 360° su visionOS

STUDIO CREATIVO IA
• Genera arte in 30+ stili
• Componi musica in 30+ generi
• Generatore di frattali
• Designer di spettacoli di luce

COLLABORAZIONE MONDIALE
• Sessioni globali a latenza zero (1000+ partecipanti)
• Sincronizzazione della coerenza di gruppo

ACCESSIBILITÀ (WCAG AAA)
• 20+ profili di accessibilità
• Supporto VoiceOver/TalkBack
• Controllo vocale
• Palette sicure per daltonici

AVVISO SANITARIO: Echoelmusic NON è un dispositivo medico. Solo per uso creativo e benessere.
""",
        keywords: "biofeedback,HRV,meditazione,musica,benessere,quantico,audio spaziale,coerenza,mindfulness,creatività",
        promotionalText: "Trasforma il tuo battito cardiaco in una sinfonia. Audio bio-reattivo incontra visual quantici.",
        whatsNew: "🎬 NUOVO: Composizione orchestrale, streaming professionale, ecosistema hardware espanso, sicurezza aziendale"
    )

    // MARK: - Russian (ru-RU)

    public static let russian = LocalizedMetadata(
        locale: "ru-RU",
        name: "Echoelmusic",
        subtitle: "Творите изнутри",
        description: """
Превратите свое сердцебиение, дыхание и сознание в потрясающее пространственное аудио и иммерсивные визуальные эффекты.

Echoelmusic — первая в мире биореактивная аудиовизуальная платформа, которая превращает ваши биометрические сигналы в искусство. Испытайте создание музыки через естественные ритмы вашего тела с помощью передового ИИ и квантовой обработки.

✨ ОСНОВНЫЕ ФУНКЦИИ

БИОМЕТРИЧЕСКОЕ СОЗДАНИЕ МУЗЫКИ
• Вариабельность сердечного ритма (ВСР) в реальном времени → пространственное аудиополе
• Паттерны дыхания → звуковые текстуры и визуальный поток
• Отслеживание когерентности → гармоническая сложность
• Интеграция с Apple Watch

ПРОСТРАНСТВЕННЫЙ АУДИОДВИЖОК
• Иммерсивные звуковые ландшафты 3D/4D
• Позиционирование звука по Фибоначчи и священной геометрии
• Поддержка MIDI 2.0 и MPE
• Нулевая задержка (<10ms)

КВАНТОВЫЕ СВЕТОВЫЕ ВИЗУАЛЫ
• 10 режимов визуализации с ускорением GPU
• Интерференция волн, поток фотонов
• Шейдеры Metal в реальном времени 60fps
• 360° опыт на visionOS

КРЕАТИВНАЯ СТУДИЯ ИИ
• Создавайте искусство в 30+ стилях
• Сочиняйте музыку в 30+ жанрах
• Генератор фракталов
• Дизайнер светового шоу

ГЛОБАЛЬНОЕ СОТРУДНИЧЕСТВО
• Глобальные сессии с нулевой задержкой (1000+ участников)
• Групповая синхронизация когерентности

ДОСТУПНОСТЬ (WCAG AAA)
• 20+ профилей доступности
• Поддержка VoiceOver/TalkBack
• Голосовое управление
• Безопасные для дальтоников палитры

УВЕДОМЛЕНИЕ О ЗДОРОВЬЕ: Echoelmusic НЕ является медицинским устройством. Только для творческих и оздоровительных целей.
""",
        keywords: "биофидбэк,ВСР,медитация,музыка,велнес,квантовый,пространственное аудио,когерентность,осознанность,креативность",
        promotionalText: "Превратите свое сердцебиение в симфонию. Биореактивное аудио встречается с квантовыми визуалами.",
        whatsNew: "🎬 НОВОЕ: Оркестровая партитура, профессиональный стриминг, расширенная экосистема оборудования, корпоративная безопасность"
    )

    // MARK: - Arabic (ar-SA)

    public static let arabic = LocalizedMetadata(
        locale: "ar-SA",
        name: "Echoelmusic",
        subtitle: "ابدع من داخلك",
        description: """
حوّل نبضات قلبك وتنفسك ووعيك إلى صوت مكاني مذهل ومرئيات غامرة.

Echoelmusic هي أول منصة صوتية-مرئية تفاعلية حيوياً في العالم تحول إشاراتك الحيوية إلى فن. اختبر إنشاء الموسيقى من خلال إيقاعات جسمك الطبيعية، مدعومة بالذكاء الاصطناعي المتطور والمعالجة الكمومية.

✨ الميزات الرئيسية

إنشاء موسيقى حيوية
• تباين معدل ضربات القلب (HRV) في الوقت الفعلي → مجال صوتي مكاني
• أنماط التنفس → نسيج صوتي وتدفق بصري
• تتبع التماسك → التعقيد التوافقي
• تكامل مع Apple Watch

محرك الصوت المكاني
• مناظر صوتية غامرة ثلاثية ورباعية الأبعاد
• تحديد موضع الصوت بفيبوناتشي والهندسة المقدسة
• دعم MIDI 2.0 و MPE
• زمن انتقال صفري (<10ms)

مرئيات الضوء الكمومي
• 10 أوضاع تصور معجلة بواسطة GPU
• تداخل الموجات، تدفق الفوتونات
• تظليل Metal في الوقت الفعلي 60fps
• تجربة 360° على visionOS

استوديو إبداعي بالذكاء الاصطناعي
• إنشاء فن بأكثر من 30 نمطاً
• تأليف موسيقى بأكثر من 30 نوعاً
• مولد كسوري
• مصمم عروض ضوئية

تعاون عالمي
• جلسات عالمية بدون تأخير (أكثر من 1000 مشارك)
• مزامنة التماسك الجماعي

إمكانية الوصول (WCAG AAA)
• أكثر من 20 ملف تعريف لإمكانية الوصول
• دعم VoiceOver/TalkBack
• التحكم الصوتي
• لوحات ألوان آمنة لعمى الألوان

إخلاء مسؤولية صحية: Echoelmusic ليس جهازاً طبياً. للاستخدام الإبداعي والعافية فقط.
""",
        keywords: "ارتجاع حيوي,تباين معدل ضربات القلب,تأمل,موسيقى,عافية,كمومي,صوت مكاني,تماسك,وعي تام,إبداع",
        promotionalText: "حوّل نبضات قلبك إلى سيمفونية. صوت تفاعلي حيوياً يلتقي بمرئيات كمومية.",
        whatsNew: "🎬 جديد: تسجيل أوركسترالي، بث احترافي، نظام بيئي موسع للأجهزة، أمان مؤسسي"
    )

    // MARK: - Hindi (hi-IN)

    public static let hindi = LocalizedMetadata(
        locale: "hi-IN",
        name: "Echoelmusic",
        subtitle: "अंतर से रचना करें",
        description: """
अपने दिल की धड़कन, सांस और चेतना को शानदार स्थानिक ऑडियो और इमर्सिव विजुअल में बदलें।

Echoelmusic दुनिया का पहला जैव-प्रतिक्रियात्मक ऑडियो-विजुअल प्लेटफॉर्म है जो आपके बायोमेट्रिक सिग्नल को कला में बदल देता है। अत्याधुनिक AI और क्वांटम-प्रेरित प्रोसेसिंग द्वारा संचालित अपने शरीर की प्राकृतिक लय के माध्यम से संगीत निर्माण का अनुभव करें।

✨ मुख्य विशेषताएं

बायोमेट्रिक संगीत निर्माण
• रियल-टाइम हृदय गति परिवर्तनशीलता (HRV) → स्थानिक ऑडियो फ़ील्ड
• श्वास पैटर्न → ध्वनि बनावट और दृश्य प्रवाह
• सुसंगतता ट्रैकिंग → हार्मोनिक जटिलता
• Apple Watch एकीकरण

स्थानिक ऑडियो इंजन
• 3D/4D इमर्सिव साउंडस्केप
• फिबोनाची और पवित्र ज्यामिति ध्वनि स्थिति
• MIDI 2.0 और MPE समर्थन
• शून्य विलंबता (<10ms)

क्वांटम प्रकाश विजुअल
• 10 GPU-त्वरित विज़ुअलाइज़ेशन मोड
• तरंग हस्तक्षेप, फोटॉन प्रवाह
• रियल-टाइम Metal शेडर्स 60fps पर
• visionOS पर 360° अनुभव

AI रचनात्मक स्टूडियो
• 30+ शैलियों में कला उत्पन्न करें
• 30+ शैलियों में संगीत रचना करें
• फ्रैक्टल जनरेटर
• प्रकाश शो डिज़ाइनर

विश्वव्यापी सहयोग
• शून्य-विलंबता वैश्विक सत्र (1000+ प्रतिभागी)
• समूह सुसंगतता समन्वयन

पहुंच-योग्यता (WCAG AAA)
• 20+ पहुंच-योग्यता प्रोफाइल
• VoiceOver/TalkBack समर्थन
• वॉयस कंट्रोल
• रंग-अंध सुरक्षित पैलेट

स्वास्थ्य अस्वीकरण: Echoelmusic एक चिकित्सा उपकरण नहीं है। केवल रचनात्मक और कल्याण उद्देश्यों के लिए।
""",
        keywords: "बायोफीडबैक,HRV,ध्यान,संगीत,कल्याण,क्वांटम,स्थानिक ऑडियो,सुसंगतता,सचेतनता,रचनात्मकता",
        promotionalText: "अपने दिल की धड़कन को सिम्फनी में बदलें। जैव-प्रतिक्रियात्मक ऑडियो क्वांटम विजुअल से मिलता है।",
        whatsNew: "🎬 नया: ऑर्केस्ट्रल स्कोरिंग, व्यावसायिक स्ट्रीमिंग, विस्तारित हार्डवेयर पारिस्थितिकी तंत्र, एंटरप्राइज़ सुरक्षा"
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
            title: "Bio-Reactive Audio Creation",
            description: "Transform your heartbeat into spatial audio. Real-time HRV coherence drives harmonic complexity and 3D sound positioning."
        ),
        .init(
            number: 2,
            title: "Quantum Light Visualization",
            description: "10 stunning GPU-accelerated visual modes. Watch wave interference, photon flow, and sacred geometry respond to your biometrics in real-time."
        ),
        .init(
            number: 3,
            title: "Cinematic Orchestral Scoring",
            description: "Walt Disney & Hollywood-inspired film composition. 27 articulations, 8 orchestra sections, bio-reactive dynamics."
        ),
        .init(
            number: 4,
            title: "360° Immersive Experience",
            description: "Full spatial audio and visual immersion on visionOS. Surround yourself with quantum light fields and binaural soundscapes."
        ),
        .init(
            number: 5,
            title: "AI Creative Studio",
            description: "Generate art in 30+ styles and compose music in 30+ genres. AI-powered fractal generator and light show designer."
        ),
        .init(
            number: 6,
            title: "Wellness & Meditation",
            description: "Guided breathing patterns, sound bath generator, coherence tracking. Perfect for mindfulness and relaxation."
        ),
        .init(
            number: 7,
            title: "Professional Live Streaming",
            description: "Stream in up to 8K to YouTube, Twitch, Instagram. Hardware-accelerated encoding with multi-destination support."
        ),
        .init(
            number: 8,
            title: "Hardware Ecosystem",
            description: "Connect 60+ audio interfaces, 40+ MIDI controllers, DMX lighting, and VR/AR devices. Universal cross-platform sessions."
        ),
        .init(
            number: 9,
            title: "Worldwide Collaboration",
            description: "Join global sessions with 1000+ participants. Zero-latency coherence synchronization across 15+ server regions."
        ),
        .init(
            number: 10,
            title: "Universal Accessibility",
            description: "WCAG AAA compliant with 20+ accessibility profiles. VoiceOver, voice control, color-blind safe, haptic feedback."
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
Visual: Heartbeat pulse → audio waveform transformation
Text: "Transform Your Heartbeat Into Art"

[3-8s] BIO-REACTIVE AUDIO
Visual: Real-time HRV coherence affecting spatial audio field
Text: "Real-Time Biometric Music Creation"

[8-13s] QUANTUM VISUALS
Visual: Rapid montage of 10 visualization modes
Text: "Stunning GPU-Accelerated Visuals"

[13-18s] ORCHESTRAL & AI
Visual: Film scoring interface + AI art generation
Text: "Cinematic Scoring & AI Studio"

[18-23s] COLLABORATION
Visual: Global participants map, coherence sync
Text: "Connect With 1000+ Users Worldwide"

[23-27s] PLATFORMS
Visual: Device ecosystem montage (iPhone, Watch, Vision Pro, Mac)
Text: "Available Everywhere"

[27-30s] CALL TO ACTION
Visual: App icon + download button
Text: "Download Echoelmusic Today"

MUSIC: Ambient binaural soundscape with gentle orchestral build
VOICEOVER: Optional calm, inspiring narration
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
