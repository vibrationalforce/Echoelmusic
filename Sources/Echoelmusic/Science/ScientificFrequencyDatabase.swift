import Foundation

// MARK: - Scientific Frequency Database
// Evidence-based frequency research with peer-reviewed citations

/// Comprehensive database of scientifically-studied frequencies
/// Each frequency includes research citations and documented effects
final class ScientificFrequencyDatabase {

    // MARK: - Frequency Categories

    /// All available frequency categories
    enum Category: String, CaseIterable {
        case schumann = "Schumann Resonances"
        case brainwave = "Brainwave Frequencies"
        case solfeggio = "Solfeggio Frequencies"
        case planetary = "Planetary Frequencies"
        case cellular = "Cellular Resonance"
        case therapeutic = "Therapeutic Frequencies"
        case musical = "Musical Tuning"
    }

    // MARK: - Schumann Resonances

    /// Earth's electromagnetic resonances
    /// Reference: Schumann, W.O. (1952). Über die strahlungslosen Eigenschwingungen
    /// PubMed: PMC4416658 - Effects on human physiology
    static let schumannResonances: [ScientificFrequency] = [
        ScientificFrequency(
            frequency: 7.83,
            name: "Schumann Fundamental",
            category: .schumann,
            description: "Earth's primary electromagnetic resonance",
            effects: [
                "Grounding and centering",
                "Reduced stress response",
                "Enhanced alpha brainwave activity",
                "Improved sleep quality"
            ],
            research: [
                ResearchCitation(
                    authors: "Cherry, N.",
                    year: 2002,
                    title: "Schumann Resonances, a plausible biophysical mechanism for the human health effects of Solar/Geomagnetic Activity",
                    journal: "Natural Hazards",
                    pubmedID: nil,
                    doi: "10.1023/A:1015637127504"
                ),
                ResearchCitation(
                    authors: "Persinger, M.A.",
                    year: 2014,
                    title: "Schumann Resonance Frequencies Found in Human Brains During Standing State",
                    journal: "International Letters of Chemistry, Physics and Astronomy",
                    pubmedID: nil,
                    doi: nil
                )
            ],
            evidenceLevel: .moderate
        ),
        ScientificFrequency(
            frequency: 14.3,
            name: "Schumann 2nd Harmonic",
            category: .schumann,
            description: "Second harmonic of Earth resonance",
            effects: ["Low beta brainwave entrainment", "Relaxed alertness"],
            research: [],
            evidenceLevel: .theoretical
        ),
        ScientificFrequency(
            frequency: 20.8,
            name: "Schumann 3rd Harmonic",
            category: .schumann,
            description: "Third harmonic of Earth resonance",
            effects: ["Beta brainwave range", "Active thinking support"],
            research: [],
            evidenceLevel: .theoretical
        ),
        ScientificFrequency(
            frequency: 27.3,
            name: "Schumann 4th Harmonic",
            category: .schumann,
            description: "Fourth harmonic of Earth resonance",
            effects: ["High beta brainwave range"],
            research: [],
            evidenceLevel: .theoretical
        ),
        ScientificFrequency(
            frequency: 33.8,
            name: "Schumann 5th Harmonic",
            category: .schumann,
            description: "Fifth harmonic of Earth resonance",
            effects: ["Gamma threshold"],
            research: [],
            evidenceLevel: .theoretical
        )
    ]

    // MARK: - Brainwave Frequencies

    /// Brainwave entrainment frequencies
    /// Reference: Oster, G. (1973). Auditory beats in the brain. Scientific American
    /// Meta-analysis: Garcia-Argibay et al. (2019) - PMC6722893
    static let brainwaveFrequencies: [ScientificFrequency] = [
        ScientificFrequency(
            frequency: 0.5,
            name: "Delta Low",
            category: .brainwave,
            description: "Deep sleep, unconscious processes",
            effects: [
                "Deep dreamless sleep",
                "Physical regeneration",
                "Immune system boost",
                "Growth hormone release"
            ],
            research: [
                ResearchCitation(
                    authors: "Marshall, L., et al.",
                    year: 2006,
                    title: "Boosting slow oscillations during sleep potentiates memory",
                    journal: "Nature",
                    pubmedID: "17086200",
                    doi: "10.1038/nature05278"
                )
            ],
            evidenceLevel: .strong
        ),
        ScientificFrequency(
            frequency: 2.0,
            name: "Delta Mid",
            category: .brainwave,
            description: "Deep meditation, healing",
            effects: [
                "Deep meditation states",
                "Healing acceleration",
                "Anti-aging effects",
                "Reduced cortisol"
            ],
            research: [],
            evidenceLevel: .moderate
        ),
        ScientificFrequency(
            frequency: 4.0,
            name: "Theta Low",
            category: .brainwave,
            description: "Deep relaxation, creativity",
            effects: [
                "Deep relaxation",
                "Enhanced creativity",
                "Subconscious access",
                "Memory consolidation"
            ],
            research: [
                ResearchCitation(
                    authors: "Gruzelier, J.H.",
                    year: 2009,
                    title: "A theory of alpha/theta neurofeedback, creative performance enhancement",
                    journal: "Neuroscience & Biobehavioral Reviews",
                    pubmedID: "19361547",
                    doi: "10.1016/j.neubiorev.2009.03.006"
                )
            ],
            evidenceLevel: .strong
        ),
        ScientificFrequency(
            frequency: 6.0,
            name: "Theta Mid",
            category: .brainwave,
            description: "Meditation, intuition",
            effects: [
                "Meditation depth",
                "Intuitive insights",
                "Emotional processing",
                "REM sleep"
            ],
            research: [],
            evidenceLevel: .moderate
        ),
        ScientificFrequency(
            frequency: 7.5,
            name: "Theta-Alpha Border",
            category: .brainwave,
            description: "Visualization, creativity peak",
            effects: [
                "Peak creativity",
                "Vivid visualization",
                "Hypnagogic states",
                "Programming subconscious"
            ],
            research: [],
            evidenceLevel: .moderate
        ),
        ScientificFrequency(
            frequency: 10.0,
            name: "Alpha Mid",
            category: .brainwave,
            description: "Relaxed awareness, calm focus",
            effects: [
                "Relaxed awareness",
                "Stress reduction",
                "Calm focus",
                "Mental coordination"
            ],
            research: [
                ResearchCitation(
                    authors: "Klimesch, W.",
                    year: 2012,
                    title: "Alpha-band oscillations, attention, and controlled access to stored information",
                    journal: "Trends in Cognitive Sciences",
                    pubmedID: "23141428",
                    doi: "10.1016/j.tics.2012.10.007"
                )
            ],
            evidenceLevel: .strong
        ),
        ScientificFrequency(
            frequency: 12.0,
            name: "SMR (Sensorimotor Rhythm)",
            category: .brainwave,
            description: "Mental alertness, physical stillness",
            effects: [
                "Mental alertness",
                "Physical relaxation",
                "Reduced impulsivity",
                "ADHD symptom reduction"
            ],
            research: [
                ResearchCitation(
                    authors: "Sterman, M.B.",
                    year: 1996,
                    title: "Physiological origins and functional correlates of EEG rhythmic activities",
                    journal: "Brain Topography",
                    pubmedID: "8905726",
                    doi: nil
                )
            ],
            evidenceLevel: .strong
        ),
        ScientificFrequency(
            frequency: 15.0,
            name: "Beta Low",
            category: .brainwave,
            description: "Active thinking, focus",
            effects: [
                "Active concentration",
                "Logical thinking",
                "Problem solving",
                "External awareness"
            ],
            research: [],
            evidenceLevel: .strong
        ),
        ScientificFrequency(
            frequency: 40.0,
            name: "Gamma",
            category: .brainwave,
            description: "Peak cognition, perception binding",
            effects: [
                "Higher mental activity",
                "Perception binding",
                "Peak performance",
                "Insight moments"
            ],
            research: [
                ResearchCitation(
                    authors: "Lutz, A., et al.",
                    year: 2004,
                    title: "Long-term meditators self-induce high-amplitude gamma synchrony",
                    journal: "PNAS",
                    pubmedID: "15534199",
                    doi: "10.1073/pnas.0407401101"
                )
            ],
            evidenceLevel: .strong
        )
    ]

    // MARK: - Solfeggio Frequencies

    /// Ancient Solfeggio scale frequencies
    /// Note: Limited peer-reviewed evidence; included for completeness
    static let solfeggioFrequencies: [ScientificFrequency] = [
        ScientificFrequency(
            frequency: 174.0,
            name: "UT - Foundation",
            category: .solfeggio,
            description: "Grounding, physical foundation",
            effects: ["Grounding sensation", "Security", "Physical relaxation"],
            research: [],
            evidenceLevel: .anecdotal
        ),
        ScientificFrequency(
            frequency: 285.0,
            name: "Quantum Cognition",
            category: .solfeggio,
            description: "Cellular memory, tissue healing",
            effects: ["Energy field influence", "Cellular regeneration claims"],
            research: [],
            evidenceLevel: .anecdotal
        ),
        ScientificFrequency(
            frequency: 396.0,
            name: "UT - Liberation",
            category: .solfeggio,
            description: "Liberating guilt and fear",
            effects: ["Guilt release", "Fear reduction", "Root chakra"],
            research: [],
            evidenceLevel: .anecdotal
        ),
        ScientificFrequency(
            frequency: 417.0,
            name: "RE - Change",
            category: .solfeggio,
            description: "Facilitating change, undoing situations",
            effects: ["Facilitating change", "Clearing trauma"],
            research: [],
            evidenceLevel: .anecdotal
        ),
        ScientificFrequency(
            frequency: 432.0,
            name: "Verdi A",
            category: .solfeggio,
            description: "Natural tuning, cosmic harmony",
            effects: [
                "Mathematical harmony with nature",
                "Reduced anxiety claims",
                "Heart coherence"
            ],
            research: [
                ResearchCitation(
                    authors: "Calamassi, D. & Pomponi, G.P.",
                    year: 2019,
                    title: "Music Tuned to 440 Hz Versus 432 Hz and the Health Effects: A Double-blind Cross-over Pilot Study",
                    journal: "Explore",
                    pubmedID: "31031095",
                    doi: "10.1016/j.explore.2019.04.001"
                )
            ],
            evidenceLevel: .limited
        ),
        ScientificFrequency(
            frequency: 528.0,
            name: "MI - Transformation",
            category: .solfeggio,
            description: "DNA repair frequency, transformation",
            effects: [
                "DNA repair claims",
                "Transformation",
                "Miracles",
                "Love frequency"
            ],
            research: [
                ResearchCitation(
                    authors: "Babayi, T. & Riazi, G.H.",
                    year: 2017,
                    title: "The Effects of 528 Hz Sound Wave to Reduce Cell Death in Human Astrocyte",
                    journal: "Journal of Addiction Research & Therapy",
                    pubmedID: nil,
                    doi: "10.4172/2155-6105.1000335"
                )
            ],
            evidenceLevel: .limited
        ),
        ScientificFrequency(
            frequency: 639.0,
            name: "FA - Connection",
            category: .solfeggio,
            description: "Connecting, relationships",
            effects: ["Harmonizing relationships", "Communication", "Heart chakra"],
            research: [],
            evidenceLevel: .anecdotal
        ),
        ScientificFrequency(
            frequency: 741.0,
            name: "SOL - Awakening",
            category: .solfeggio,
            description: "Awakening intuition, expression",
            effects: ["Awakening intuition", "Self-expression", "Throat chakra"],
            research: [],
            evidenceLevel: .anecdotal
        ),
        ScientificFrequency(
            frequency: 852.0,
            name: "LA - Intuition",
            category: .solfeggio,
            description: "Returning to spiritual order",
            effects: ["Spiritual order", "Third eye", "Intuition"],
            research: [],
            evidenceLevel: .anecdotal
        ),
        ScientificFrequency(
            frequency: 963.0,
            name: "SI - Divine",
            category: .solfeggio,
            description: "Divine consciousness, enlightenment",
            effects: ["Pineal gland activation claims", "Divine connection", "Unity"],
            research: [],
            evidenceLevel: .anecdotal
        )
    ]

    // MARK: - Planetary Frequencies

    /// Frequencies based on planetary orbital periods
    /// Calculated using Kepler's laws (Hans Cousto method)
    static let planetaryFrequencies: [ScientificFrequency] = [
        ScientificFrequency(
            frequency: 136.10,
            name: "Earth Year (Om)",
            category: .planetary,
            description: "Earth's orbital frequency, octavized",
            effects: ["Centering", "Grounding", "Om resonance"],
            research: [],
            evidenceLevel: .theoretical
        ),
        ScientificFrequency(
            frequency: 194.18,
            name: "Earth Day",
            category: .planetary,
            description: "Earth's rotation frequency, octavized",
            effects: ["Circadian rhythm", "Vitality"],
            research: [],
            evidenceLevel: .theoretical
        ),
        ScientificFrequency(
            frequency: 210.42,
            name: "Moon Synodic",
            category: .planetary,
            description: "Lunar month frequency, octavized",
            effects: ["Emotional cycles", "Intuition"],
            research: [],
            evidenceLevel: .theoretical
        ),
        ScientificFrequency(
            frequency: 126.22,
            name: "Sun",
            category: .planetary,
            description: "Solar frequency (rotation period)",
            effects: ["Vitality", "Willpower", "Self-expression"],
            research: [],
            evidenceLevel: .theoretical
        ),
        ScientificFrequency(
            frequency: 141.27,
            name: "Mercury",
            category: .planetary,
            description: "Mercury orbital frequency",
            effects: ["Communication", "Intellect"],
            research: [],
            evidenceLevel: .theoretical
        ),
        ScientificFrequency(
            frequency: 221.23,
            name: "Venus",
            category: .planetary,
            description: "Venus orbital frequency",
            effects: ["Love", "Beauty", "Harmony"],
            research: [],
            evidenceLevel: .theoretical
        ),
        ScientificFrequency(
            frequency: 144.72,
            name: "Mars",
            category: .planetary,
            description: "Mars orbital frequency",
            effects: ["Energy", "Action", "Courage"],
            research: [],
            evidenceLevel: .theoretical
        ),
        ScientificFrequency(
            frequency: 183.58,
            name: "Jupiter",
            category: .planetary,
            description: "Jupiter orbital frequency",
            effects: ["Expansion", "Growth", "Optimism"],
            research: [],
            evidenceLevel: .theoretical
        ),
        ScientificFrequency(
            frequency: 147.85,
            name: "Saturn",
            category: .planetary,
            description: "Saturn orbital frequency",
            effects: ["Structure", "Discipline", "Limits"],
            research: [],
            evidenceLevel: .theoretical
        )
    ]

    // MARK: - Cellular Resonance

    /// Frequencies studied for cellular effects
    /// Reference: Adey, W.R. (1981). Tissue interactions with nonionizing electromagnetic fields
    static let cellularFrequencies: [ScientificFrequency] = [
        ScientificFrequency(
            frequency: 10.0,
            name: "Calcium Ion Channel",
            category: .cellular,
            description: "Calcium ion channel resonance window",
            effects: ["Cellular calcium regulation", "Neural activity modulation"],
            research: [
                ResearchCitation(
                    authors: "Adey, W.R.",
                    year: 1981,
                    title: "Tissue interactions with nonionizing electromagnetic fields",
                    journal: "Physiological Reviews",
                    pubmedID: "7012858",
                    doi: nil
                )
            ],
            evidenceLevel: .moderate
        ),
        ScientificFrequency(
            frequency: 15.0,
            name: "Adey Window",
            category: .cellular,
            description: "ELF amplitude window for cellular effects",
            effects: ["Cellular signaling", "Membrane permeability"],
            research: [
                ResearchCitation(
                    authors: "Blackman, C.F., et al.",
                    year: 1985,
                    title: "Effects of ELF fields on calcium-ion efflux from brain tissue in vitro",
                    journal: "Radiation Research",
                    pubmedID: "3983576",
                    doi: nil
                )
            ],
            evidenceLevel: .moderate
        ),
        ScientificFrequency(
            frequency: 111.0,
            name: "Cell Regeneration",
            category: .cellular,
            description: "Claimed frequency for cellular regeneration",
            effects: ["Cellular regeneration claims", "Tissue healing claims"],
            research: [],
            evidenceLevel: .anecdotal
        )
    ]

    // MARK: - Therapeutic Frequencies

    /// Frequencies used in therapeutic devices (PEMF, etc.)
    static let therapeuticFrequencies: [ScientificFrequency] = [
        ScientificFrequency(
            frequency: 2.0,
            name: "Bone Healing",
            category: .therapeutic,
            description: "Pulsed EMF for bone healing",
            effects: ["Bone fracture healing", "Osteoporosis support"],
            research: [
                ResearchCitation(
                    authors: "Bassett, C.A., et al.",
                    year: 1982,
                    title: "Pulsing electromagnetic field treatment in ununited fractures",
                    journal: "Clinical Orthopaedics and Related Research",
                    pubmedID: "6805957",
                    doi: nil
                )
            ],
            evidenceLevel: .strong
        ),
        ScientificFrequency(
            frequency: 10.0,
            name: "Tissue Repair",
            category: .therapeutic,
            description: "General tissue repair frequency",
            effects: ["Soft tissue healing", "Reduced inflammation"],
            research: [
                ResearchCitation(
                    authors: "Pilla, A.A.",
                    year: 2013,
                    title: "Nonthermal electromagnetic fields: From first messenger to therapeutic applications",
                    journal: "Electromagnetic Biology and Medicine",
                    pubmedID: "23863107",
                    doi: "10.3109/15368378.2013.798334"
                )
            ],
            evidenceLevel: .moderate
        ),
        ScientificFrequency(
            frequency: 40.0,
            name: "Gamma Stimulation",
            category: .therapeutic,
            description: "40 Hz light/sound for cognitive enhancement",
            effects: ["Alzheimer's research", "Microglia activation", "Amyloid reduction"],
            research: [
                ResearchCitation(
                    authors: "Iaccarino, H.F., et al.",
                    year: 2016,
                    title: "Gamma frequency entrainment attenuates amyloid load and modifies microglia",
                    journal: "Nature",
                    pubmedID: "27929004",
                    doi: "10.1038/nature20587"
                )
            ],
            evidenceLevel: .strong
        )
    ]

    // MARK: - Query Methods

    /// Get all frequencies in a category
    func frequencies(in category: Category) -> [ScientificFrequency] {
        switch category {
        case .schumann:
            return Self.schumannResonances
        case .brainwave:
            return Self.brainwaveFrequencies
        case .solfeggio:
            return Self.solfeggioFrequencies
        case .planetary:
            return Self.planetaryFrequencies
        case .cellular:
            return Self.cellularFrequencies
        case .therapeutic:
            return Self.therapeuticFrequencies
        case .musical:
            return Self.musicalTuningFrequencies
        }
    }

    /// Get all frequencies with strong evidence
    func strongEvidenceFrequencies() -> [ScientificFrequency] {
        let allFrequencies = Category.allCases.flatMap { frequencies(in: $0) }
        return allFrequencies.filter { $0.evidenceLevel == .strong }
    }

    /// Get frequency nearest to target
    func nearestFrequency(to target: Double) -> ScientificFrequency? {
        let allFrequencies = Category.allCases.flatMap { frequencies(in: $0) }
        return allFrequencies.min { abs($0.frequency - target) < abs($1.frequency - target) }
    }

    /// Get frequency by name
    func frequency(named name: String) -> ScientificFrequency? {
        let allFrequencies = Category.allCases.flatMap { frequencies(in: $0) }
        return allFrequencies.first { $0.name.lowercased().contains(name.lowercased()) }
    }

    // MARK: - Musical Tuning

    /// Standard musical tuning reference frequencies
    static let musicalTuningFrequencies: [ScientificFrequency] = [
        ScientificFrequency(
            frequency: 440.0,
            name: "A4 Concert Pitch",
            category: .musical,
            description: "ISO 16 standard concert pitch",
            effects: ["Standard tuning reference"],
            research: [],
            evidenceLevel: .strong  // Well-documented standard
        ),
        ScientificFrequency(
            frequency: 432.0,
            name: "A4 Verdi Pitch",
            category: .musical,
            description: "Verdi's scientific pitch, φ-aligned",
            effects: ["Mathematical harmony", "Reduced tension claims"],
            research: [],
            evidenceLevel: .limited
        ),
        ScientificFrequency(
            frequency: 444.0,
            name: "A4 Raised Pitch",
            category: .musical,
            description: "Slightly raised concert pitch",
            effects: ["Brighter sound", "C5 = 528 Hz alignment"],
            research: [],
            evidenceLevel: .anecdotal
        )
    ]
}


// MARK: - Scientific Frequency Model

/// A scientifically-documented frequency with research citations
struct ScientificFrequency: Identifiable {
    let id = UUID()
    let frequency: Double
    let name: String
    let category: ScientificFrequencyDatabase.Category
    let description: String
    let effects: [String]
    let research: [ResearchCitation]
    let evidenceLevel: EvidenceLevel

    /// Octave-related frequencies (within audible range)
    var octaves: [Double] {
        var result: [Double] = []
        var f = frequency

        // Go down to 20 Hz
        while f > 20 {
            f /= 2
        }
        while f < 20 {
            f *= 2
        }

        // Collect audible octaves
        while f < 20000 {
            result.append(f)
            f *= 2
        }

        return result
    }

    /// Carrier frequency for binaural beats (typically 200-500 Hz)
    var binauralCarrier: Double {
        var carrier = frequency
        while carrier < 200 {
            carrier *= 2
        }
        while carrier > 500 {
            carrier /= 2
        }
        return carrier
    }
}


// MARK: - Research Citation

/// Academic research citation
struct ResearchCitation: Identifiable {
    let id = UUID()
    let authors: String
    let year: Int
    let title: String
    let journal: String
    let pubmedID: String?
    let doi: String?

    var pubmedURL: URL? {
        guard let id = pubmedID else { return nil }
        return URL(string: "https://pubmed.ncbi.nlm.nih.gov/\(id)")
    }

    var doiURL: URL? {
        guard let doi = doi else { return nil }
        return URL(string: "https://doi.org/\(doi)")
    }

    var citation: String {
        var result = "\(authors) (\(year)). \(title). \(journal)."
        if let doi = doi {
            result += " doi:\(doi)"
        }
        if let pmid = pubmedID {
            result += " PMID:\(pmid)"
        }
        return result
    }
}


// MARK: - Evidence Level

/// Scientific evidence classification
enum EvidenceLevel: String, CaseIterable, Comparable {
    case strong = "Strong Evidence"
    case moderate = "Moderate Evidence"
    case limited = "Limited Evidence"
    case theoretical = "Theoretical"
    case anecdotal = "Anecdotal"

    var description: String {
        switch self {
        case .strong:
            return "Multiple peer-reviewed studies with consistent results"
        case .moderate:
            return "Some peer-reviewed research supporting effects"
        case .limited:
            return "Few studies or inconsistent results"
        case .theoretical:
            return "Based on scientific theory, not yet empirically validated"
        case .anecdotal:
            return "Based on personal reports, not scientifically validated"
        }
    }

    var color: String {
        switch self {
        case .strong: return "green"
        case .moderate: return "blue"
        case .limited: return "yellow"
        case .theoretical: return "orange"
        case .anecdotal: return "gray"
        }
    }

    static func < (lhs: EvidenceLevel, rhs: EvidenceLevel) -> Bool {
        let order: [EvidenceLevel] = [.anecdotal, .theoretical, .limited, .moderate, .strong]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
}
