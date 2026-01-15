// AdeyWindowsBioelectromagneticEngine.swift
// Echoelmusic - Holistic Bio-Coherence Platform
//
// Wissenschaftlich fundierte Bioelektromagnetik basierend auf Dr. W. Ross Adey's Forschung
// Peer-reviewed Research: Bioelectromagnetics, Physiological Chemistry and Physics
//
// KRITISCHER HINWEIS: Dies ist KEINE medizinische Behandlung.
// Implementiert als Audio/Visual-Feedback, nicht als elektromagnetische Therapie.
// Alle Frequenzen werden als AUDIO dargestellt, nicht als EM-Felder.
//
// Referenzen:
// - Adey WR (1981). "Tissue interactions with nonionizing electromagnetic fields"
//   Physiological Reviews 61(2):435-514
// - Adey WR (1988). "Cell membranes: The electromagnetic environment and cancer promotion"
//   Neurochemical Research 13(7):671-677
// - Blackman CF et al. (1985). "A role for the magnetic field in the radiation-induced
//   efflux of calcium ions from brain tissue" Bioelectromagnetics 6(4):327-337

import Foundation

// MARK: - Adey Windows Research Documentation

/// Dokumentation der wissenschaftlichen Grundlagen der Adey Windows
/// Dr. W. Ross Adey (1922-2004) - UCLA Brain Research Institute, Loma Linda University
public struct AdeyWindowsResearch {

    /// Forschungsstatus und Evidenzlevel
    public static let evidenceLevel = "2b-3 (Cohort/Case-Control Studies)"

    /// Wissenschaftlicher Hintergrund
    public static let scientificBackground = """
    Dr. W. Ross Adey's Forschung (1970er-1990er) zeigte, dass bestimmte
    extrem niederfrequente (ELF) elektromagnetische Felder biologische
    Effekte auf Zellmembranen haben können - aber NUR innerhalb spezifischer
    "Fenster" (Windows) von Frequenz und Amplitude.

    WICHTIG: Diese Forschung bezieht sich auf elektromagnetische Felder,
    NICHT auf Audiofrequenzen. In Echoelmusic nutzen wir diese Erkenntnisse
    als INSPIRATION für Audio-Biofeedback, nicht als EM-Therapie.

    Die "Adey Windows" zeigen:
    1. Frequenzfenster: Effekte nur bei 6-20 Hz (ELF-Bereich)
    2. Amplitudenfenster: Effekte nur bei bestimmten Feldstärken
    3. Nicht-lineare Dosis-Wirkungs-Beziehung (mehr ist nicht besser)
    """

    /// Peer-reviewed Publikationen
    public static let keyPublications: [ScientificPublication] = [
        ScientificPublication(
            authors: "Adey WR",
            year: 1981,
            title: "Tissue interactions with nonionizing electromagnetic fields",
            journal: "Physiological Reviews",
            volume: "61(2)",
            pages: "435-514",
            pmid: "7012860",
            evidenceLevel: .cohortStudy
        ),
        ScientificPublication(
            authors: "Blackman CF, Benane SG, Rabinowitz JR, House DE, Joines WT",
            year: 1985,
            title: "A role for the magnetic field in the radiation-induced efflux of calcium ions from brain tissue in vitro",
            journal: "Bioelectromagnetics",
            volume: "6(4)",
            pages: "327-337",
            pmid: "4084271",
            evidenceLevel: .caseControl
        ),
        ScientificPublication(
            authors: "Adey WR",
            year: 1993,
            title: "Biological effects of electromagnetic fields",
            journal: "Journal of Cellular Biochemistry",
            volume: "51(4)",
            pages: "410-416",
            pmid: "8496242",
            evidenceLevel: .expertReview
        ),
        ScientificPublication(
            authors: "Bawin SM, Adey WR",
            year: 1976,
            title: "Sensitivity of calcium binding in cerebral tissue to weak environmental electric fields oscillating at low frequency",
            journal: "Proceedings of the National Academy of Sciences",
            volume: "73(6)",
            pages: "1999-2003",
            pmid: "1064869",
            evidenceLevel: .laboratoryStudy
        )
    ]

    /// Kritische Limitationen der Forschung
    public static let limitations = """
    KRITISCHE LIMITATIONEN:

    1. In-vitro vs. In-vivo: Viele Studien waren Laborstudien an isolierten
       Zellen, nicht an lebenden Menschen.

    2. Replizierbarkeit: Einige Ergebnisse wurden nicht konsistent repliziert.

    3. Klinische Relevanz: Die beobachteten Calciumefflux-Effekte haben
       keine nachgewiesene therapeutische Bedeutung.

    4. Audio ≠ EM: Audiofrequenzen sind KEINE elektromagnetischen Felder.
       Sie können die gleichen biologischen Mechanismen NICHT aktivieren.

    5. Keine medizinischen Anwendungen: Die FDA hat keine Adey-Windows-
       basierten Therapien zugelassen.
    """
}

// MARK: - Scientific Publication Model

/// Struktur für wissenschaftliche Publikationen
public struct ScientificPublication: Identifiable, Codable {
    public let id: UUID
    public let authors: String
    public let year: Int
    public let title: String
    public let journal: String
    public let volume: String
    public let pages: String
    public let pmid: String?
    public let doi: String?
    public let evidenceLevel: EvidenceLevel

    public init(
        authors: String,
        year: Int,
        title: String,
        journal: String,
        volume: String,
        pages: String,
        pmid: String? = nil,
        doi: String? = nil,
        evidenceLevel: EvidenceLevel
    ) {
        self.id = UUID()
        self.authors = authors
        self.year = year
        self.title = title
        self.journal = journal
        self.volume = volume
        self.pages = pages
        self.pmid = pmid
        self.doi = doi
        self.evidenceLevel = evidenceLevel
    }

    public var citation: String {
        "\(authors) (\(year)). \"\(title)\" \(journal) \(volume):\(pages)"
    }
}

/// Oxford CEBM Evidenzlevel
public enum EvidenceLevel: String, Codable, CaseIterable {
    case metaAnalysis = "1a"        // Systematic Review of RCTs
    case randomizedControlledTrial = "1b"  // Individual RCT
    case systematicReviewCohort = "2a"     // SR of Cohort Studies
    case cohortStudy = "2b"        // Individual Cohort Study
    case caseControl = "3"         // Case-Control Study
    case caseSeries = "4"          // Case Series
    case expertReview = "5"        // Expert Opinion
    case laboratoryStudy = "Lab"   // In-vitro/Animal Studies

    public var description: String {
        switch self {
        case .metaAnalysis: return "Meta-Analyse (höchste Evidenz)"
        case .randomizedControlledTrial: return "Randomisierte kontrollierte Studie"
        case .systematicReviewCohort: return "Systematischer Review von Kohortenstudien"
        case .cohortStudy: return "Kohortenstudie"
        case .caseControl: return "Fall-Kontroll-Studie"
        case .caseSeries: return "Fallserie"
        case .expertReview: return "Expertenmeinung"
        case .laboratoryStudy: return "Laborstudie (begrenzte Übertragbarkeit)"
        }
    }

    public var strengthScore: Int {
        switch self {
        case .metaAnalysis: return 100
        case .randomizedControlledTrial: return 90
        case .systematicReviewCohort: return 80
        case .cohortStudy: return 70
        case .caseControl: return 60
        case .caseSeries: return 40
        case .expertReview: return 30
        case .laboratoryStudy: return 20
        }
    }
}

// MARK: - Biological Frequency Windows

/// Die Adey Windows - Biologische Frequenzfenster
/// HINWEIS: Implementiert als AUDIO-Frequenzen für Biofeedback, nicht als EM-Felder
public struct BiologicalFrequencyWindow: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let frequencyRangeHz: ClosedRange<Double>
    public let bodySystem: BodySystem
    public let scientificBasis: String
    public let evidenceLevel: EvidenceLevel
    public let audioImplementation: String
    public let disclaimer: String

    public init(
        name: String,
        frequencyRangeHz: ClosedRange<Double>,
        bodySystem: BodySystem,
        scientificBasis: String,
        evidenceLevel: EvidenceLevel,
        audioImplementation: String,
        disclaimer: String
    ) {
        self.id = UUID()
        self.name = name
        self.frequencyRangeHz = frequencyRangeHz
        self.bodySystem = bodySystem
        self.scientificBasis = scientificBasis
        self.evidenceLevel = evidenceLevel
        self.audioImplementation = audioImplementation
        self.disclaimer = disclaimer
    }
}

/// Körpersysteme für die wissenschaftliche Zuordnung
public enum BodySystem: String, Codable, CaseIterable {
    case nervousSystem = "nervous_system"      // Psyche
    case cardiovascular = "cardiovascular"      // Herz-Kreislauf
    case musculoskeletal = "musculoskeletal"   // Muskeln & Knochen
    case respiratory = "respiratory"            // Atmung
    case endocrine = "endocrine"               // Hormone
    case immune = "immune"                      // Immunsystem

    public var germanName: String {
        switch self {
        case .nervousSystem: return "Nervensystem (Psyche)"
        case .cardiovascular: return "Herz-Kreislauf-System"
        case .musculoskeletal: return "Muskel-Skelett-System"
        case .respiratory: return "Atmungssystem"
        case .endocrine: return "Hormonsystem"
        case .immune: return "Immunsystem"
        }
    }

    public var scientificMeasurement: String {
        switch self {
        case .nervousSystem: return "EEG (Elektroenzephalographie)"
        case .cardiovascular: return "HRV (Herzratenvariabilität), EKG"
        case .musculoskeletal: return "EMG (Elektromyographie)"
        case .respiratory: return "Atemfrequenz, SpO2"
        case .endocrine: return "Cortisol, Melatonin, HRV"
        case .immune: return "CRP, Leukozyten, HRV"
        }
    }
}

// MARK: - Adey Windows Engine

/// Engine für wissenschaftlich fundierte Frequenz-Körper-Mapping
/// DISCLAIMER: Nur für kreative/informative Zwecke, KEINE Medizin
@MainActor
public final class AdeyWindowsBioelectromagneticEngine: ObservableObject {

    // MARK: - Published State

    @Published public var activeWindow: BiologicalFrequencyWindow?
    @Published public var currentBodySystem: BodySystem = .nervousSystem
    @Published public var coherenceLevel: Double = 0.0
    @Published public var sessionDuration: TimeInterval = 0

    // MARK: - Scientific Windows

    /// Wissenschaftlich dokumentierte Frequenzfenster
    /// HINWEIS: Als Audio-Biofeedback implementiert, nicht als EM-Therapie
    public let scientificWindows: [BiologicalFrequencyWindow] = [

        // === NERVENSYSTEM (PSYCHE) ===
        BiologicalFrequencyWindow(
            name: "Delta Brainwave Window",
            frequencyRangeHz: 0.5...4.0,
            bodySystem: .nervousSystem,
            scientificBasis: """
            Delta-Wellen (0.5-4 Hz) dominieren im Tiefschlaf (NREM Stage 3-4).
            EEG-messbar, assoziiert mit Regeneration und Wachstumshormon-Ausschüttung.
            Referenz: Hobson JA (1995). Sleep. Scientific American Library.
            """,
            evidenceLevel: .cohortStudy,
            audioImplementation: "Multidimensional Brainwave Entrainment: Carrier 200Hz, Differenz 2Hz → wahrgenommene 2Hz Pulsation",
            disclaimer: "Keine Schlaftherapie. Bei Schlafstörungen Arzt konsultieren."
        ),

        BiologicalFrequencyWindow(
            name: "Theta Relaxation Window",
            frequencyRangeHz: 4.0...8.0,
            bodySystem: .nervousSystem,
            scientificBasis: """
            Theta-Wellen (4-8 Hz) treten bei Meditation, leichtem Schlaf auf.
            Assoziiert mit Kreativität und Gedächtniskonsolidierung.
            Referenz: Klimesch W (1999). EEG alpha and theta oscillations. Brain Research Reviews.
            """,
            evidenceLevel: .systematicReviewCohort,
            audioImplementation: "Isochronische Töne bei 6Hz, Ambient-Drone mit Theta-Modulation",
            disclaimer: "Kreatives Audio-Erlebnis, keine Therapie."
        ),

        BiologicalFrequencyWindow(
            name: "Alpha Coherence Window",
            frequencyRangeHz: 8.0...12.0,
            bodySystem: .nervousSystem,
            scientificBasis: """
            Alpha-Wellen (8-12 Hz) sind der "Entspannungsrhythmus" des wachen Gehirns.
            Verstärkt bei geschlossenen Augen, Meditation. Gut repliziert.
            Referenz: Berger H (1929). Über das Elektrenkephalogramm des Menschen.
            """,
            evidenceLevel: .metaAnalysis,
            audioImplementation: "10Hz Binaural Beat, visuelle Alpha-Stimulation",
            disclaimer: "Entspannungs-Soundscape, keine medizinische Intervention."
        ),

        BiologicalFrequencyWindow(
            name: "Schumann Resonance Window",
            frequencyRangeHz: 7.5...8.5,
            bodySystem: .nervousSystem,
            scientificBasis: """
            Schumann-Resonanz (7.83 Hz) ist die messbare elektromagnetische Resonanz
            der Erde-Ionosphäre-Kavität. Physikalisch real und messbar.
            Biologische Relevanz: Spekulativ, keine klinischen Studien.
            Referenz: Schumann WO (1952). Über die strahlungslosen Eigenschwingungen.
            """,
            evidenceLevel: .laboratoryStudy,
            audioImplementation: "7.83Hz Pulsation als rhythmisches Element",
            disclaimer: "Erdresonanz-inspiriert, keine nachgewiesenen Gesundheitseffekte."
        ),

        // === HERZ-KREISLAUF ===
        BiologicalFrequencyWindow(
            name: "HRV Coherence Window",
            frequencyRangeHz: 0.04...0.15,
            bodySystem: .cardiovascular,
            scientificBasis: """
            HRV-Kohärenz bei ~0.1 Hz (6 Atemzüge/Minute) ist wissenschaftlich gut belegt.
            Baroreflex-Synchronisation, parasympathische Aktivierung.
            Referenz: Lehrer PM & Gevirtz R (2014). Frontiers in Psychology.
            """,
            evidenceLevel: .metaAnalysis,
            audioImplementation: "Atemführung bei 6/min, HRV-synchronisierte Klanglandschaft",
            disclaimer: "Nicht bei Herzerkrankungen ohne ärztliche Freigabe anwenden."
        ),

        BiologicalFrequencyWindow(
            name: "Resting Heart Rate Window",
            frequencyRangeHz: 1.0...1.5,
            bodySystem: .cardiovascular,
            scientificBasis: """
            Ruhepuls 60-90 bpm entspricht ~1-1.5 Hz. Audio-Entrainment des Herzrhythmus
            ist NICHT wissenschaftlich belegt. HRV-Biofeedback hingegen schon.
            """,
            evidenceLevel: .expertReview,
            audioImplementation: "Rhythmische Elemente bei ~72 bpm (1.2 Hz)",
            disclaimer: "Herzrhythmus-inspiriert, keine medizinische Wirkung."
        ),

        // === MUSKEL-SKELETT ===
        BiologicalFrequencyWindow(
            name: "PEMF Bone Healing Window",
            frequencyRangeHz: 15.0...30.0,
            bodySystem: .musculoskeletal,
            scientificBasis: """
            PEMF (Pulsed Electromagnetic Field) bei 15-30 Hz wird in der Orthopädie
            zur Knochenheilung eingesetzt (FDA-zugelassene Geräte existieren).
            ACHTUNG: Dies sind EM-Felder, NICHT Audio.
            Referenz: Bassett CA (1989). Beneficial effects of electromagnetic fields.
            """,
            evidenceLevel: .randomizedControlledTrial,
            audioImplementation: "20Hz rhythmische Perkussion (nur Audio, kein PEMF)",
            disclaimer: "Audio-Rhythmus, KEIN elektromagnetisches Feld. PEMF erfordert medizinische Geräte."
        ),

        BiologicalFrequencyWindow(
            name: "Muscle Relaxation Window",
            frequencyRangeHz: 8.0...14.0,
            bodySystem: .musculoskeletal,
            scientificBasis: """
            EMG zeigt Muskelentspannung bei Alpha-Zuständen. Progressive
            Muskelentspannung (Jacobson) ist evidenzbasiert.
            Referenz: McCallie MS et al. (2006). Applied Psychophysiology and Biofeedback.
            """,
            evidenceLevel: .metaAnalysis,
            audioImplementation: "Geführte Entspannung mit 10Hz Alpha-Untermalung",
            disclaimer: "Entspannungs-Audio, bei Muskelproblemen Arzt konsultieren."
        ),

        // === ATMUNG ===
        BiologicalFrequencyWindow(
            name: "Resonance Breathing Window",
            frequencyRangeHz: 0.08...0.12,
            bodySystem: .respiratory,
            scientificBasis: """
            Resonanzatmung bei ~0.1 Hz (6/min) maximiert die HRV durch
            Baroreflex-Resonanz. Eines der am besten belegten Biofeedback-Protokolle.
            Referenz: Vaschillo EG et al. (2002). Applied Psychophysiology and Biofeedback.
            """,
            evidenceLevel: .metaAnalysis,
            audioImplementation: "Atemführung: 5s ein, 5s aus (6/min)",
            disclaimer: "Bei Atemproblemen oder Panikstörung erst Arzt konsultieren."
        ),

        // === IMMUNSYSTEM ===
        BiologicalFrequencyWindow(
            name: "Vagal Tone Window",
            frequencyRangeHz: 0.15...0.4,
            bodySystem: .immune,
            scientificBasis: """
            High-frequency HRV (0.15-0.4 Hz) ist ein Marker für vagale Aktivität.
            Der Vagusnerv moduliert Entzündungsreaktionen (Tracey KJ, 2002).
            ACHTUNG: HRV-Training ist kein Immunbooster.
            Referenz: Thayer JF & Lane RD (2009). Neuroscience & Biobehavioral Reviews.
            """,
            evidenceLevel: .cohortStudy,
            audioImplementation: "HRV-Biofeedback mit Fokus auf Atemkohärenz",
            disclaimer: "Keine Immuntherapie. Bei Infektionen Arzt konsultieren."
        )
    ]

    // MARK: - Initialization

    public init() {
        log.info(category: .biofeedback, "[AdeyWindows] Engine initialisiert - Wissenschaftliche Frequenzfenster")
        log.info(category: .biofeedback, "[AdeyWindows] DISCLAIMER: Nur für kreative/informative Zwecke")
    }

    // MARK: - Public Methods

    /// Aktiviere ein Frequenzfenster für ein Körpersystem
    public func activateWindow(for bodySystem: BodySystem) -> BiologicalFrequencyWindow? {
        currentBodySystem = bodySystem
        let window = scientificWindows.first { $0.bodySystem == bodySystem }
        activeWindow = window

        if let window = window {
            log.info(category: .biofeedback, "[AdeyWindows] Aktiviert: \(window.name) für \(bodySystem.germanName)")
            log.info(category: .biofeedback, "[AdeyWindows] Evidenzlevel: \(window.evidenceLevel.description)")
        }

        return window
    }

    /// Hole alle Fenster für ein Körpersystem
    public func windows(for bodySystem: BodySystem) -> [BiologicalFrequencyWindow] {
        scientificWindows.filter { $0.bodySystem == bodySystem }
    }

    /// Hole das Fenster mit der höchsten Evidenz für ein System
    public func bestEvidenceWindow(for bodySystem: BodySystem) -> BiologicalFrequencyWindow? {
        windows(for: bodySystem)
            .sorted { $0.evidenceLevel.strengthScore > $1.evidenceLevel.strengthScore }
            .first
    }

    /// Generiere einen wissenschaftlichen Report
    public func generateScientificReport() -> String {
        var report = """
        ═══════════════════════════════════════════════════════════════
        WISSENSCHAFTLICHER REPORT: Adey Windows Bioelektromagnetik
        ═══════════════════════════════════════════════════════════════

        DISCLAIMER:
        \(AdeyWindowsResearch.limitations)

        ───────────────────────────────────────────────────────────────
        FORSCHUNGSGRUNDLAGE:
        \(AdeyWindowsResearch.scientificBackground)

        ───────────────────────────────────────────────────────────────
        IMPLEMENTIERTE FREQUENZFENSTER:

        """

        for system in BodySystem.allCases {
            let systemWindows = windows(for: system)
            if !systemWindows.isEmpty {
                report += "\n[\(system.germanName)]\n"
                report += "Messmethode: \(system.scientificMeasurement)\n"

                for window in systemWindows {
                    report += """

                    • \(window.name)
                      Frequenz: \(window.frequencyRangeHz.lowerBound)-\(window.frequencyRangeHz.upperBound) Hz
                      Evidenz: \(window.evidenceLevel.description)
                      Audio: \(window.audioImplementation)

                    """
                }
            }
        }

        report += """

        ───────────────────────────────────────────────────────────────
        LITERATUR:

        """

        for pub in AdeyWindowsResearch.keyPublications {
            report += "• \(pub.citation)\n"
            if let pmid = pub.pmid {
                report += "  PMID: \(pmid)\n"
            }
        }

        return report
    }
}

// MARK: - Master Disclaimer

/// Zentrale Gesundheits-Disclaimer für das gesamte System
public struct AdeyWindowsDisclaimer {

    public static let fullDisclaimer = """
    ⚠️ WICHTIGER HINWEIS ZU WISSENSCHAFT UND GESUNDHEIT ⚠️

    Die in Echoelmusic implementierten "Adey Windows" sind INSPIRIERT von
    der wissenschaftlichen Forschung von Dr. W. Ross Adey zu bioelektro-
    magnetischen Effekten.

    KRITISCHE UNTERSCHEIDUNGEN:

    1. AUDIO ≠ ELEKTROMAGNETIK
       Audiofrequenzen (Schallwellen) sind physikalisch völlig verschieden
       von elektromagnetischen Feldern. Die Adey-Forschung bezog sich auf
       EM-Felder, nicht auf Audio.

    2. KEINE MEDIZINISCHE ANWENDUNG
       Echoelmusic ist ein kreatives Audio-Visual-Tool, KEIN Medizinprodukt.
       Es diagnostiziert, behandelt oder heilt keine Krankheiten.

    3. WISSENSCHAFTLICHE LIMITATIONEN
       Die Original-Adey-Forschung hat wichtige Limitationen (siehe oben).
       Viele Ergebnisse wurden nicht repliziert oder sind umstritten.

    4. KONSULTIEREN SIE EINEN ARZT
       Bei gesundheitlichen Beschwerden immer einen qualifizierten
       Mediziner konsultieren.

    Diese Software ist für Erwachsene bestimmt. Nicht für Personen mit:
    • Epilepsie oder Anfallsleiden
    • Schweren psychischen Erkrankungen
    • Herzschrittmacher oder implantierten Defibrillatoren
    • Schwangerschaft (ohne ärztliche Freigabe)

    Nutzung auf eigene Verantwortung.
    """

    public static let shortDisclaimer = """
    Kreatives Audio-Tool, kein Medizinprodukt. Bei Gesundheitsfragen Arzt konsultieren.
    """
}

// MARK: - Logger Extension

// Uses global logger (log) from ProfessionalLogger.swift
// Biofeedback messages are logged via log.biofeedback() or log.info()
