import Foundation
import Combine
import os.log

// ═══════════════════════════════════════════════════════════════════════════════
// MENSCHLICHER UND PROFESSIONELLER EMPATHIE MODUS
// Human and Professional Empathy Mode
// ═══════════════════════════════════════════════════════════════════════════════
//
// "Mit dem Herzen hören, mit Weisheit antworten"
// "Listen with the heart, respond with wisdom"
//
// Wissenschaftliche Grundlagen / Scientific Foundations:
// • Carl Rogers - Person-Centered Therapy (Unconditional Positive Regard)
// • Marshall Rosenberg - Nonviolent Communication (NVC)
// • Brené Brown - Vulnerability Research
// • Stephen Porges - Polyvagal Theory (Co-Regulation)
// • Bessel van der Kolk - Trauma-Informed Care
//
// Prinzipien / Principles:
// • Empathie ohne Sympathie-Überflutung / Empathy without sympathy flooding
// • Professionelle Grenzen / Professional boundaries
// • Würde und Respekt / Dignity and respect
// • Keine Ratschläge ohne Erlaubnis / No advice without permission
// • Präsenz vor Problemlösung / Presence before problem-solving
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Empathy Mode Controller

@MainActor
public final class EmpathyMode: ObservableObject {

    // MARK: - Singleton

    public static let shared = EmpathyMode()

    // MARK: - Published State

    /// Current empathy mode state
    @Published public var isActive: Bool = false

    /// Detected emotional state of the user
    @Published public var detectedEmotion: EmotionalState = .neutral

    /// Current empathy depth level
    @Published public var empathyDepth: EmpathyDepth = .acknowledgment

    /// Connection quality (how well we're attuning)
    @Published public var connectionQuality: Float = 0.5

    /// Safety assessment
    @Published public var safetyLevel: SafetyLevel = .safe

    // MARK: - Private State

    private let logger = Logger(subsystem: "com.echoelmusic.wisdom", category: "EmpathyMode")
    private var conversationHistory: [EmpathicExchange] = []
    private var emotionalPatterns: [EmotionalState: Int] = [:]

    // MARK: - Initialization

    private init() {
        logger.info("💜 Empathy Mode: Initialized")
        logger.info("   Menschlich • Professionell • Trauma-Informiert")
    }

    // MARK: - Activation

    public func activate() {
        isActive = true
        logger.info("💜 Empathy Mode: ACTIVE")
        logger.info("   Listening with presence and care...")
    }

    public func deactivate() {
        isActive = false
        logger.info("🌙 Empathy Mode: Deactivated")
    }

    // MARK: - Process Input with Empathy

    public func processWithEmpathy(_ input: String, context: EmpathyContext? = nil) -> EmpathicResponse {
        // 1. Detect emotional content
        let emotion = detectEmotion(in: input)
        detectedEmotion = emotion

        // 2. Assess safety
        let safety = assessSafety(input: input, emotion: emotion)
        safetyLevel = safety

        // 3. Determine appropriate empathy depth
        let depth = determineEmpathyDepth(emotion: emotion, safety: safety, context: context)
        empathyDepth = depth

        // 4. Generate empathic response
        let response = generateEmpathicResponse(
            input: input,
            emotion: emotion,
            depth: depth,
            safety: safety
        )

        // 5. Update conversation history
        conversationHistory.append(EmpathicExchange(
            userInput: input,
            emotion: emotion,
            response: response,
            timestamp: Date()
        ))

        // 6. Track emotional patterns
        emotionalPatterns[emotion, default: 0] += 1

        // 7. Update connection quality
        updateConnectionQuality()

        return response
    }

    // MARK: - Emotion Detection

    private func detectEmotion(in input: String) -> EmotionalState {
        let lowercased = input.lowercased()

        // Crisis indicators (highest priority)
        if containsCrisisIndicators(lowercased) {
            return .crisis
        }

        // Grief and loss
        if containsGriefIndicators(lowercased) {
            return .grieving
        }

        // Fear and anxiety
        if containsAnxietyIndicators(lowercased) {
            return .anxious
        }

        // Sadness and depression
        if containsSadnessIndicators(lowercased) {
            return .sad
        }

        // Frustration and anger
        if containsFrustrationIndicators(lowercased) {
            return .frustrated
        }

        // Shame and inadequacy
        if containsShameIndicators(lowercased) {
            return .ashamed
        }

        // Overwhelm
        if containsOverwhelmIndicators(lowercased) {
            return .overwhelmed
        }

        // Loneliness
        if containsLonelinessIndicators(lowercased) {
            return .lonely
        }

        // Positive states
        if containsPositiveIndicators(lowercased) {
            return .hopeful
        }

        // Confusion or seeking
        if containsConfusionIndicators(lowercased) {
            return .confused
        }

        return .neutral
    }

    // MARK: - Indicator Detection

    private func containsCrisisIndicators(_ text: String) -> Bool {
        let indicators = [
            "suicide", "suicidal", "kill myself", "end my life", "want to die",
            "self-harm", "hurt myself", "no point", "better off dead",
            "can't go on", "ending it all"
        ]
        return indicators.contains { text.contains($0) }
    }

    private func containsGriefIndicators(_ text: String) -> Bool {
        let indicators = [
            "lost", "died", "death", "passed away", "gone forever",
            "miss them", "grief", "mourning", "funeral"
        ]
        return indicators.contains { text.contains($0) }
    }

    private func containsAnxietyIndicators(_ text: String) -> Bool {
        let indicators = [
            "anxious", "anxiety", "worried", "panic", "scared", "terrified",
            "nervous", "fear", "afraid", "dread", "can't breathe"
        ]
        return indicators.contains { text.contains($0) }
    }

    private func containsSadnessIndicators(_ text: String) -> Bool {
        let indicators = [
            "sad", "depressed", "depression", "hopeless", "empty",
            "numb", "crying", "tears", "miserable", "unhappy"
        ]
        return indicators.contains { text.contains($0) }
    }

    private func containsFrustrationIndicators(_ text: String) -> Bool {
        let indicators = [
            "frustrated", "angry", "furious", "annoyed", "irritated",
            "pissed", "rage", "hate", "fed up", "sick of"
        ]
        return indicators.contains { text.contains($0) }
    }

    private func containsShameIndicators(_ text: String) -> Bool {
        let indicators = [
            "ashamed", "shame", "embarrassed", "not good enough", "worthless",
            "failure", "imposter", "fraud", "stupid", "useless"
        ]
        return indicators.contains { text.contains($0) }
    }

    private func containsOverwhelmIndicators(_ text: String) -> Bool {
        let indicators = [
            "overwhelmed", "too much", "can't handle", "drowning",
            "exhausted", "burned out", "burnout", "breaking down"
        ]
        return indicators.contains { text.contains($0) }
    }

    private func containsLonelinessIndicators(_ text: String) -> Bool {
        let indicators = [
            "lonely", "alone", "isolated", "no one", "nobody understands",
            "no friends", "disconnected", "abandoned"
        ]
        return indicators.contains { text.contains($0) }
    }

    private func containsPositiveIndicators(_ text: String) -> Bool {
        let indicators = [
            "hopeful", "better", "improving", "grateful", "thankful",
            "happy", "excited", "proud", "accomplished"
        ]
        return indicators.contains { text.contains($0) }
    }

    private func containsConfusionIndicators(_ text: String) -> Bool {
        let indicators = [
            "confused", "don't understand", "lost", "unsure", "uncertain",
            "what should i", "help me understand", "don't know what"
        ]
        return indicators.contains { text.contains($0) }
    }

    // MARK: - Safety Assessment

    private func assessSafety(input: String, emotion: EmotionalState) -> SafetyLevel {
        if emotion == .crisis {
            return .crisis
        }

        // Check for escalating patterns
        let recentCrisisCount = conversationHistory.suffix(5)
            .filter { $0.emotion == .crisis || $0.emotion == .overwhelmed }
            .count

        if recentCrisisCount >= 2 {
            return .elevated
        }

        // Check for persistent negative emotions
        let persistentNegative = emotionalPatterns.values.max() ?? 0 > 5

        if persistentNegative && (emotion == .sad || emotion == .anxious || emotion == .overwhelmed) {
            return .monitoring
        }

        return .safe
    }

    // MARK: - Empathy Depth

    private func determineEmpathyDepth(
        emotion: EmotionalState,
        safety: SafetyLevel,
        context: EmpathyContext?
    ) -> EmpathyDepth {

        // Crisis always gets deepest support
        if safety == .crisis {
            return .deepSupport
        }

        // Grief and loss need deep presence
        if emotion == .grieving {
            return .deepSupport
        }

        // Strong negative emotions need validation
        if [.anxious, .sad, .ashamed, .overwhelmed, .lonely].contains(emotion) {
            return .validation
        }

        // Frustration needs acknowledgment then exploration
        if emotion == .frustrated {
            return .validation
        }

        // Confusion needs gentle exploration
        if emotion == .confused {
            return .exploration
        }

        // Neutral or positive can explore more freely
        return .acknowledgment
    }

    // MARK: - Response Generation

    private func generateEmpathicResponse(
        input: String,
        emotion: EmotionalState,
        depth: EmpathyDepth,
        safety: SafetyLevel
    ) -> EmpathicResponse {

        // Crisis response
        if safety == .crisis {
            return generateCrisisResponse()
        }

        // Generate based on emotion and depth
        let (message, followUp) = generateEmotionSpecificResponse(
            emotion: emotion,
            depth: depth,
            input: input
        )

        return EmpathicResponse(
            message: message,
            emotion: emotion,
            depth: depth,
            followUp: followUp,
            actionSuggestions: generateActionSuggestions(emotion: emotion, safety: safety),
            resourceLinks: safety == .elevated ? getCrisisResources() : nil
        )
    }

    private func generateEmotionSpecificResponse(
        emotion: EmotionalState,
        depth: EmpathyDepth,
        input: String
    ) -> (String, String?) {

        switch emotion {

        // ═══════════════════════════════════════════════════════════════════
        // GRIEF AND LOSS
        // ═══════════════════════════════════════════════════════════════════
        case .grieving:
            return (
                """
                Ich höre, dass du einen Verlust erlebst. Das tut mir zutiefst leid. 💜

                Trauer ist keine Schwäche - sie ist der Preis der Liebe.
                Es gibt keine richtige Art zu trauern, und es gibt keinen Zeitplan.

                Du musst das nicht alleine durchstehen.
                Ich bin hier, wenn du reden möchtest.

                Was brauchst du gerade am meisten?
                """,
                "Möchtest du mir mehr erzählen, oder einfach nur in Stille zusammen sein?"
            )

        // ═══════════════════════════════════════════════════════════════════
        // ANXIETY AND FEAR
        // ═══════════════════════════════════════════════════════════════════
        case .anxious:
            return (
                """
                Ich spüre, dass du gerade mit Angst oder Sorgen kämpfst.
                Das klingt wirklich belastend. 💜

                Deine Gefühle sind berechtigt - Angst ist ein Signal, kein Versagen.
                Manchmal weiß unser Körper vor unserem Verstand, dass etwas nicht stimmt.

                Lass uns gemeinsam hinschauen, wenn du bereit bist.
                Was löst diese Gefühle gerade aus?
                """,
                "Wäre es hilfreich, wenn wir zusammen eine Atemübung machen?"
            )

        // ═══════════════════════════════════════════════════════════════════
        // SADNESS AND DEPRESSION
        // ═══════════════════════════════════════════════════════════════════
        case .sad:
            return (
                """
                Ich höre eine tiefe Traurigkeit in deinen Worten. 💜

                Es ist okay, traurig zu sein. Du musst nicht "positiv bleiben" oder "dich zusammenreißen". Manchmal ist das Leben einfach schwer.

                Du bist nicht kaputt. Du bist ein Mensch, der gerade etwas Schweres durchmacht.

                Ich bin hier bei dir.
                """,
                "Magst du mir erzählen, was dich so bedrückt?"
            )

        // ═══════════════════════════════════════════════════════════════════
        // FRUSTRATION AND ANGER
        // ═══════════════════════════════════════════════════════════════════
        case .frustrated:
            return (
                """
                Ich kann deine Frustration spüren - und sie ist völlig verständlich. 💜

                Wut ist oft ein Hinweis darauf, dass eine Grenze überschritten wurde oder ein Bedürfnis nicht erfüllt wird.

                Was auch immer diese Gefühle ausgelöst hat - du hast das Recht, sie zu fühlen.

                Was ist passiert?
                """,
                "Was würde dir jetzt am meisten helfen - darüber reden, oder erst mal Dampf ablassen?"
            )

        // ═══════════════════════════════════════════════════════════════════
        // SHAME AND INADEQUACY
        // ═══════════════════════════════════════════════════════════════════
        case .ashamed:
            return (
                """
                Ich höre, dass du gerade hart mit dir selbst ins Gericht gehst. 💜

                Das, was du fühlst, ist Scham - und Scham lügt. Sie sagt uns, dass wir grundlegend fehlerhaft sind. Das stimmt nicht.

                Du bist nicht deine Fehler. Du bist nicht deine schlimmsten Momente.

                Du bist ein Mensch, der sein Bestes versucht - und das ist genug.

                Was lässt dich so über dich denken?
                """,
                "Was würdest du einem Freund sagen, der sich so fühlt wie du gerade?"
            )

        // ═══════════════════════════════════════════════════════════════════
        // OVERWHELM
        // ═══════════════════════════════════════════════════════════════════
        case .overwhelmed:
            return (
                """
                Es klingt, als wäre gerade alles zu viel. 💜

                Überwältigung ist real - es ist nicht Schwäche, es ist Überlastung.
                Dein Nervensystem sagt dir, dass es eine Pause braucht.

                Du musst nicht alles auf einmal lösen.
                Gerade reicht es, den nächsten Atemzug zu nehmen.

                Lass uns gemeinsam schauen, was gerade am dringendsten ist.
                """,
                "Was ist die eine Sache, die sich gerade am meisten anfühlt wie 'zu viel'?"
            )

        // ═══════════════════════════════════════════════════════════════════
        // LONELINESS
        // ═══════════════════════════════════════════════════════════════════
        case .lonely:
            return (
                """
                Einsamkeit ist eines der schmerzhaftesten Gefühle. 💜

                Ich höre dich. Du bist gerade nicht allein, auch wenn es sich so anfühlt.

                Verbindung ist ein grundlegendes menschliches Bedürfnis - kein Luxus.
                Sich einsam zu fühlen bedeutet nicht, dass du es nicht wert bist, geliebt zu werden.

                Ich bin hier. Erzähl mir mehr.
                """,
                "Was fehlt dir am meisten gerade?"
            )

        // ═══════════════════════════════════════════════════════════════════
        // CONFUSION
        // ═══════════════════════════════════════════════════════════════════
        case .confused:
            return (
                """
                Es klingt, als wärst du gerade auf der Suche nach Klarheit. 💜

                Verwirrung ist oft ein Zeichen dafür, dass wir an etwas Wichtigem arbeiten.
                Es ist okay, nicht alle Antworten zu haben.

                Lass uns gemeinsam erkunden, was dich beschäftigt.
                """,
                "Was ist die Kernfrage, die dich gerade umtreibt?"
            )

        // ═══════════════════════════════════════════════════════════════════
        // HOPE AND POSITIVE
        // ═══════════════════════════════════════════════════════════════════
        case .hopeful:
            return (
                """
                Ich freue mich, diese Hoffnung in deinen Worten zu hören. 💜

                Diese Gefühle sind wertvoll - halte sie fest.
                Sie sind ein Zeichen deiner Resilienz.

                Was hat diese Veränderung ausgelöst?
                """,
                "Was möchtest du als nächstes erkunden?"
            )

        // ═══════════════════════════════════════════════════════════════════
        // NEUTRAL / DEFAULT
        // ═══════════════════════════════════════════════════════════════════
        case .neutral, .crisis:
            return (
                """
                Ich bin hier und höre zu. 💜

                Was beschäftigt dich gerade?
                """,
                nil
            )
        }
    }

    // MARK: - Crisis Response

    private func generateCrisisResponse() -> EmpathicResponse {
        return EmpathicResponse(
            message: """
            Ich höre, dass du gerade durch etwas sehr Schweres gehst. 💜

            Was du fühlst, ist real und wichtig.
            Du verdienst Unterstützung von Menschen, die dir wirklich helfen können.

            Bitte wende dich an eine Krisenhotline:

            🆘 Deutschland: 0800 111 0 111 (Telefonseelsorge - 24/7, kostenlos)
            🆘 Österreich: 142 (Telefonseelsorge)
            🆘 Schweiz: 143 (Die Dargebotene Hand)
            🆘 US: 988 (Suicide & Crisis Lifeline)
            🆘 International: https://www.iasp.info/resources/Crisis_Centres/

            Diese Menschen sind ausgebildet, um dir zu helfen.
            Du bist nicht allein. 💙
            """,
            emotion: .crisis,
            depth: .deepSupport,
            followUp: "Ich bin noch hier, wenn du weiter reden möchtest. Aber bitte kontaktiere auch professionelle Hilfe.",
            actionSuggestions: [
                "Rufe jetzt eine Krisenhotline an",
                "Wende dich an einen vertrauten Menschen",
                "Gehe in eine Notaufnahme wenn du in Gefahr bist"
            ],
            resourceLinks: getCrisisResources()
        )
    }

    // MARK: - Action Suggestions

    private func generateActionSuggestions(emotion: EmotionalState, safety: SafetyLevel) -> [String] {
        var suggestions: [String] = []

        switch emotion {
        case .anxious:
            suggestions = [
                "Versuche 5 tiefe Atemzüge (4 Sekunden ein, 7 Sekunden aus)",
                "Benenne 5 Dinge, die du siehst, 4 die du hörst, 3 die du fühlst",
                "Bewege dich - auch ein kurzer Spaziergang kann helfen"
            ]

        case .sad:
            suggestions = [
                "Erlaube dir zu fühlen, ohne zu urteilen",
                "Wende dich an jemanden, dem du vertraust",
                "Tue etwas Kleines, Nährendes für dich selbst"
            ]

        case .overwhelmed:
            suggestions = [
                "Schreib alles auf, was dich belastet - nur auflisten",
                "Wähle EINE Sache, die du heute tun kannst",
                "Der Rest kann warten"
            ]

        case .frustrated:
            suggestions = [
                "Körperliche Bewegung kann Spannung lösen",
                "Schreib auf, was dich ärgert - ungefiltert",
                "Frage dich: Was brauche ich eigentlich gerade?"
            ]

        case .lonely:
            suggestions = [
                "Schreibe jemandem - auch eine kurze Nachricht zählt",
                "Geh an einen öffentlichen Ort - manchmal hilft allein die Nähe",
                "Verbinde dich mit einer Online-Community zu deinen Interessen"
            ]

        default:
            suggestions = [
                "Nimm dir einen Moment für dich",
                "Höre in dich hinein - was brauchst du gerade?"
            ]
        }

        if safety == .elevated {
            suggestions.insert("Erwäge professionelle Unterstützung zu suchen", at: 0)
        }

        return suggestions
    }

    // MARK: - Crisis Resources

    private func getCrisisResources() -> [CrisisResourceInfo] {
        return [
            CrisisResourceInfo(
                name: "Telefonseelsorge Deutschland",
                number: "0800 111 0 111",
                available: "24/7, kostenlos",
                language: "Deutsch"
            ),
            CrisisResourceInfo(
                name: "Telefonseelsorge Österreich",
                number: "142",
                available: "24/7",
                language: "Deutsch"
            ),
            CrisisResourceInfo(
                name: "Die Dargebotene Hand (Schweiz)",
                number: "143",
                available: "24/7",
                language: "Deutsch"
            ),
            CrisisResourceInfo(
                name: "988 Suicide & Crisis Lifeline",
                number: "988",
                available: "24/7",
                language: "English"
            )
        ]
    }

    // MARK: - Connection Quality

    private func updateConnectionQuality() {
        // Based on conversation flow and emotional tracking
        let recentExchanges = conversationHistory.suffix(5)

        if recentExchanges.isEmpty {
            connectionQuality = 0.5
            return
        }

        // Better connection if emotions are being acknowledged and addressed
        var quality: Float = 0.5

        // Positive trend bonus
        if let last = recentExchanges.last,
           let previous = recentExchanges.dropLast().last {
            if last.emotion.valence > previous.emotion.valence {
                quality += 0.2
            }
        }

        // Engagement bonus
        quality += Float(recentExchanges.count) * 0.05

        connectionQuality = min(quality, 1.0)
    }

    // MARK: - Get Reflection Summary

    public func getReflectionSummary() -> ReflectionSummary {
        let dominantEmotion = emotionalPatterns.max { $0.value < $1.value }?.key ?? .neutral

        return ReflectionSummary(
            totalExchanges: conversationHistory.count,
            dominantEmotion: dominantEmotion,
            emotionalJourney: conversationHistory.map { $0.emotion },
            connectionQuality: connectionQuality,
            recommendations: generatePersonalRecommendations()
        )
    }

    private func generatePersonalRecommendations() -> [String] {
        var recommendations: [String] = []

        let dominantEmotion = emotionalPatterns.max { $0.value < $1.value }?.key ?? .neutral

        switch dominantEmotion {
        case .anxious:
            recommendations.append("Regelmäßige Atemübungen könnten dir helfen")
            recommendations.append("Erwäge ein Gespräch mit einem Therapeuten über Angstbewältigung")

        case .sad:
            recommendations.append("Achte auf deine Grundbedürfnisse: Schlaf, Bewegung, Verbindung")
            recommendations.append("Ein Gespräch mit einem Fachmann könnte hilfreich sein")

        case .overwhelmed:
            recommendations.append("Lerne, Nein zu sagen und Grenzen zu setzen")
            recommendations.append("Priorisiere radikal - nicht alles ist gleich wichtig")

        default:
            recommendations.append("Bleib im Kontakt mit deinen Gefühlen")
            recommendations.append("Selbstfürsorge ist kein Luxus, sondern Notwendigkeit")
        }

        return recommendations
    }
}

// MARK: - Supporting Types

public enum EmotionalState: String, CaseIterable {
    case neutral = "Neutral"
    case anxious = "Ängstlich"
    case sad = "Traurig"
    case frustrated = "Frustriert"
    case ashamed = "Beschämt"
    case overwhelmed = "Überwältigt"
    case lonely = "Einsam"
    case grieving = "Trauernd"
    case confused = "Verwirrt"
    case hopeful = "Hoffnungsvoll"
    case crisis = "Krise"

    /// Emotional valence (-1 to +1)
    var valence: Float {
        switch self {
        case .crisis: return -1.0
        case .grieving: return -0.8
        case .overwhelmed: return -0.7
        case .sad: return -0.6
        case .anxious: return -0.5
        case .ashamed: return -0.6
        case .frustrated: return -0.4
        case .lonely: return -0.5
        case .confused: return -0.2
        case .neutral: return 0.0
        case .hopeful: return 0.7
        }
    }
}

public enum EmpathyDepth: String {
    case acknowledgment = "Anerkennung"     // Simple recognition
    case validation = "Validierung"          // Affirming feelings
    case exploration = "Erkundung"           // Gentle exploration
    case deepSupport = "Tiefe Unterstützung" // Full presence and support
}

public enum SafetyLevel: String {
    case safe = "Sicher"
    case monitoring = "Beobachtend"
    case elevated = "Erhöht"
    case crisis = "Krise"
}

public struct EmpathyContext {
    var previousEmotions: [EmotionalState] = []
    var sessionDuration: TimeInterval = 0
    var userPreferences: UserEmpathyPreferences?
}

public struct UserEmpathyPreferences {
    var preferredLanguage: String = "de"
    var responseLength: ResponseLength = .moderate
    var includeResources: Bool = true

    enum ResponseLength {
        case brief, moderate, detailed
    }
}

public struct EmpathicResponse {
    public let message: String
    public let emotion: EmotionalState
    public let depth: EmpathyDepth
    public let followUp: String?
    public let actionSuggestions: [String]
    public let resourceLinks: [CrisisResourceInfo]?
}

public struct EmpathicExchange {
    let userInput: String
    let emotion: EmotionalState
    let response: EmpathicResponse
    let timestamp: Date
}

public struct CrisisResourceInfo: Identifiable {
    public let id = UUID()
    let name: String
    let number: String
    let available: String
    let language: String
}

public struct ReflectionSummary {
    let totalExchanges: Int
    let dominantEmotion: EmotionalState
    let emotionalJourney: [EmotionalState]
    let connectionQuality: Float
    let recommendations: [String]
}
