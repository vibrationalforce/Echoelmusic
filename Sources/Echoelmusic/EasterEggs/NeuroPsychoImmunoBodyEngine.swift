// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic
// DISCLAIMER: Creative/educational tool only. NOT medical advice. Consult healthcare professionals.

import Foundation
import SwiftUI
import Combine

// MARK: - NeuroPsychoImmunoBody Engine
/// Unified holistic health engine combining neuropsychoimmunology with body health
/// Integrates: Brain-Immune-Psychology connection + Fitness/Muscle/Organ/Bone/Regeneration
@MainActor
public final class NeuroPsychoImmunoBodyEngine: ObservableObject {

    public static let shared = NeuroPsychoImmunoBodyEngine()

    // MARK: - Scientific Foundation

    /// Neuropsychoimmunology: The study of brain-immune-behavior interactions
    /// Key researchers: Robert Ader, Nicholas Cohen, Candace Pert, Esther Sternberg
    public struct ScientificBasis {
        public static let definition = """
        Psychoneuroimmunologie (PNI) erforscht die Wechselwirkungen zwischen:
        • Psyche (Gedanken, Emotionen, Verhalten)
        • Nervensystem (Gehirn, Neurotransmitter)
        • Immunsystem (Zytokine, Immunzellen)
        • Endokrines System (Hormone, HPA-Achse)
        """

        public static let keyResearch = [
            "Ader & Cohen 1975: Konditionierte Immunsuppression",
            "Pert 1997: Molecules of Emotion - Neuropeptide",
            "Sternberg 2001: The Balance Within - Stress & Immunität",
            "Kiecolt-Glaser: Stress, Wundheilung, Immunfunktion",
            "Porges 2011: Polyvagal Theory - Vagusnerv & Sicherheit"
        ]

        public static let hrvConnection = """
        HRV (Herzratenvariabilität) als Fenster zur Psychoneuroimmunologie:
        • Hohe HRV → Parasympathikus-Dominanz → Anti-inflammatorisch
        • Niedrige HRV → Sympathikus-Dominanz → Pro-inflammatorisch
        • Vagusnerv-Tonus beeinflusst Immunantwort (cholinergic anti-inflammatory pathway)
        """
    }

    // MARK: - Body Systems

    public enum BodySystem: String, CaseIterable, Identifiable {
        case nervous = "Nervensystem"
        case immune = "Immunsystem"
        case muscular = "Muskelsystem"
        case skeletal = "Skelettsystem"
        case cardiovascular = "Herz-Kreislauf"
        case respiratory = "Atmungssystem"
        case digestive = "Verdauungssystem"
        case endocrine = "Hormonsystem"
        case lymphatic = "Lymphsystem"
        case integumentary = "Haut & Bindegewebe"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .nervous: return "brain.head.profile"
            case .immune: return "shield.checkered"
            case .muscular: return "figure.strengthtraining.traditional"
            case .skeletal: return "figure.stand"
            case .cardiovascular: return "heart.fill"
            case .respiratory: return "lungs.fill"
            case .digestive: return "leaf.fill"
            case .endocrine: return "waveform.path.ecg"
            case .lymphatic: return "drop.fill"
            case .integumentary: return "hand.raised.fill"
            }
        }

        public var hrvInfluence: String {
            switch self {
            case .nervous: return "Direkt: HRV spiegelt autonome Balance"
            case .immune: return "Vagaler Tonus moduliert Entzündung"
            case .muscular: return "Entspannung fördert Regeneration"
            case .skeletal: return "Stressreduktion → Knochendichte"
            case .cardiovascular: return "Kohärenz optimiert Herzfunktion"
            case .respiratory: return "Atemkohärenz → 0.1Hz Resonanz"
            case .digestive: return "Parasympathikus → Verdauung"
            case .endocrine: return "HPA-Achse Regulation"
            case .lymphatic: return "Entspannung fördert Lymphfluss"
            case .integumentary: return "Stressreduktion → Hautgesundheit"
            }
        }
    }

    // MARK: - Health Domains

    public struct HealthDomain: Identifiable {
        public let id = UUID()
        public let name: String
        public let nameDE: String
        public let icon: String
        public let description: String
        public let biomarkers: [String]
        public let optimizations: [String]
        public let coherenceImpact: String
    }

    public static let healthDomains: [HealthDomain] = [
        HealthDomain(
            name: "Neuroplasticity",
            nameDE: "Neuroplastizität",
            icon: "brain",
            description: "Gehirnentwicklung und -anpassung",
            biomarkers: ["BDNF", "NGF", "Cortisol", "DHEA"],
            optimizations: ["Meditation", "Schlaf", "Bewegung", "Lernen", "Soziale Bindung"],
            coherenceImpact: "Hohe Kohärenz fördert BDNF-Produktion"
        ),
        HealthDomain(
            name: "Immune Function",
            nameDE: "Immunfunktion",
            icon: "shield.checkered",
            description: "Abwehrkraft und Entzündungsregulation",
            biomarkers: ["IL-6", "TNF-α", "CRP", "sIgA", "NK-Zellen"],
            optimizations: ["Stressreduktion", "Schlaf", "Ernährung", "Bewegung", "Soziale Unterstützung"],
            coherenceImpact: "Kohärenz reduziert pro-inflammatorische Zytokine"
        ),
        HealthDomain(
            name: "Muscle Health",
            nameDE: "Muskelgesundheit",
            icon: "figure.strengthtraining.traditional",
            description: "Kraft, Ausdauer und Regeneration",
            biomarkers: ["Myoglobin", "CK", "Laktat", "IGF-1"],
            optimizations: ["Progressive Überlastung", "Protein", "Schlaf", "HRV-gesteuerte Erholung"],
            coherenceImpact: "Optimale Kohärenz = bessere Muskelregeneration"
        ),
        HealthDomain(
            name: "Bone Health",
            nameDE: "Knochengesundheit",
            icon: "figure.stand",
            description: "Knochendichte und -stoffwechsel",
            biomarkers: ["Vitamin D", "Calcium", "PTH", "Osteocalcin"],
            optimizations: ["Gewichtsbelastung", "Vitamin D", "Calcium", "Stressreduktion"],
            coherenceImpact: "Chronischer Stress → Cortisolerhöhung → Knochenabbau"
        ),
        HealthDomain(
            name: "Organ Vitality",
            nameDE: "Organvitalität",
            icon: "heart.text.square.fill",
            description: "Funktion aller Organsysteme",
            biomarkers: ["Leberenzyme", "Kreatinin", "HbA1c", "TSH"],
            optimizations: ["Ernährung", "Bewegung", "Entgiftung", "Fasten", "Schlaf"],
            coherenceImpact: "Vagale Aktivierung unterstützt Organfunktion"
        ),
        HealthDomain(
            name: "Regeneration",
            nameDE: "Regeneration",
            icon: "arrow.triangle.2.circlepath",
            description: "Heilung und Zellreparatur",
            biomarkers: ["HGH", "Melatonin", "Telomerlänge", "Autophagie-Marker"],
            optimizations: ["Schlafqualität", "Fasten", "Kältetherapie", "Wärmetherapie", "Atemübungen"],
            coherenceImpact: "Tiefe Kohärenz aktiviert Regenerationsmodus"
        ),
        HealthDomain(
            name: "Psyche & Emotions",
            nameDE: "Psyche & Emotionen",
            icon: "brain.head.profile",
            description: "Mentale Gesundheit und emotionale Balance",
            biomarkers: ["Serotonin", "Dopamin", "GABA", "Cortisol/DHEA-Ratio"],
            optimizations: ["Achtsamkeit", "Soziale Verbindung", "Natur", "Kreativität", "Bewegung"],
            coherenceImpact: "Herzköharenz synchronisiert limbisches System"
        ),
        HealthDomain(
            name: "Longevity",
            nameDE: "Langlebigkeit",
            icon: "hourglass",
            description: "Biologisches vs. chronologisches Alter",
            biomarkers: ["Telomerlänge", "Epigenetische Uhr", "NAD+", "Seneszente Zellen"],
            optimizations: ["Blue Zone Prinzipien", "Kalorienrestriktion", "Bewegung", "Sinn", "Gemeinschaft"],
            coherenceImpact: "Regelmäßige Kohärenzpraxis → langsamere Zellalterung"
        )
    ]

    // MARK: - PNI Pathways

    public struct PNIPathway: Identifiable {
        public let id = UUID()
        public let name: String
        public let description: String
        public let direction: String // "Psyche → Körper" oder "Körper → Psyche"
        public let mechanism: String
        public let coherenceRole: String
    }

    public static let pniPathways: [PNIPathway] = [
        PNIPathway(
            name: "HPA-Achse",
            description: "Hypothalamus-Hypophysen-Nebennierenrinden-Achse",
            direction: "Psyche → Körper",
            mechanism: "Stress → CRH → ACTH → Cortisol → Immunsuppression",
            coherenceRole: "Kohärenz dämpft HPA-Aktivierung"
        ),
        PNIPathway(
            name: "Vagaler Tonus",
            description: "Parasympathische Regulation via Vagusnerv",
            direction: "Bidirektional",
            mechanism: "Acetylcholin hemmt TNF-α Produktion in Makrophagen",
            coherenceRole: "HRV-Kohärenz = optimaler Vagusnerv-Tonus"
        ),
        PNIPathway(
            name: "Zytokin-Signaling",
            description: "Immunbotenstoffe beeinflussen Gehirn",
            direction: "Körper → Psyche",
            mechanism: "IL-1, IL-6, TNF-α → Sickness Behavior, Depression",
            coherenceRole: "Kohärenz reduziert pro-inflammatorische Zytokine"
        ),
        PNIPathway(
            name: "Neuropeptide",
            description: "Emotionsmoleküle (Pert)",
            direction: "Bidirektional",
            mechanism: "Endorphine, Oxytocin, Substanz P in Gehirn UND Immunzellen",
            coherenceRole: "Positive Emotionen → Endorphin-Freisetzung"
        ),
        PNIPathway(
            name: "Darm-Hirn-Achse",
            description: "Mikrobiom-Gehirn-Kommunikation",
            direction: "Bidirektional",
            mechanism: "Darmbakterien → Neurotransmitter, Vagusnerv-Signale",
            coherenceRole: "Entspannung fördert gesundes Mikrobiom"
        )
    ]

    // MARK: - Coherence-Based Recommendations

    @Published public var currentCoherence: Double = 0.0
    @Published public var sessionDuration: TimeInterval = 0
    @Published public var bodySystemFocus: BodySystem = .nervous
    @Published public var recommendations: [String] = []

    public func updateCoherence(_ coherence: Double, duration: TimeInterval) {
        self.currentCoherence = coherence
        self.sessionDuration = duration
        generateRecommendations()
    }

    private func generateRecommendations() {
        var recs: [String] = []

        if currentCoherence < 0.4 {
            recs.append("🔴 Niedrige Kohärenz: Fokus auf Atemübungen (6 Atemzüge/min)")
            recs.append("Sympathikus-Dominanz → Immunsystem unter Druck")
            recs.append("Empfehlung: 5-10 Min Heart-Focused Breathing")
        } else if currentCoherence < 0.7 {
            recs.append("🟡 Mittlere Kohärenz: Gute Basis, weiter vertiefen")
            recs.append("Vagaler Tonus steigt → Entzündungsregulation verbessert")
            recs.append("Empfehlung: Positive Emotion hinzufügen (Dankbarkeit)")
        } else {
            recs.append("🟢 Hohe Kohärenz: Optimaler psychoneuroimmunologischer Zustand")
            recs.append("Anti-inflammatorische Kaskade aktiv")
            recs.append("Regenerationsmodus: BDNF↑, Cortisol↓, sIgA↑")
        }

        // Body system specific
        switch bodySystemFocus {
        case .muscular:
            recs.append("💪 Muskelregeneration: Kohärenz vor/nach Training optimiert Erholung")
        case .immune:
            recs.append("🛡️ Immunstärkung: 20 Min Kohärenz = messbare sIgA-Erhöhung")
        case .skeletal:
            recs.append("🦴 Knochengesundheit: Stressreduktion schützt Knochendichte")
        case .nervous:
            recs.append("🧠 Neuroplastizität: Kohärenz fördert BDNF-Produktion")
        default:
            break
        }

        self.recommendations = recs
    }

    // MARK: - Fitness Integration

    public struct FitnessMetric: Identifiable {
        public let id = UUID()
        public let name: String
        public let value: Double
        public let unit: String
        public let optimalRange: ClosedRange<Double>
        public let coherenceCorrelation: String
    }

    public func calculateRecoveryReadiness(restingHR: Double, hrvRMSSD: Double, sleepQuality: Double) -> Double {
        // Simplified recovery readiness algorithm
        let hrScore = max(0, 100 - (restingHR - 50) * 2) // Lower resting HR = better
        let hrvScore = min(100, hrvRMSSD * 1.5) // Higher HRV = better
        let sleepScore = sleepQuality * 100

        return (hrScore * 0.3 + hrvScore * 0.4 + sleepScore * 0.3) / 100
    }

    // MARK: - Regeneration Protocols

    public struct RegenerationProtocol: Identifiable {
        public let id = UUID()
        public let name: String
        public let duration: TimeInterval
        public let description: String
        public let steps: [String]
        public let targetCoherence: Double
    }

    public static let regenerationProtocols: [RegenerationProtocol] = [
        RegenerationProtocol(
            name: "Post-Workout Recovery",
            duration: 600, // 10 min
            description: "Aktiviert Parasympathikus für schnellere Muskelregeneration",
            steps: [
                "1. Liegen oder bequem sitzen",
                "2. Langsame Atmung (5s ein, 5s aus)",
                "3. Herzfokus mit Dankbarkeit",
                "4. 10 Minuten halten",
                "5. Langsam zurückkommen"
            ],
            targetCoherence: 0.7
        ),
        RegenerationProtocol(
            name: "Immune Boost",
            duration: 1200, // 20 min
            description: "Erhöht sIgA und NK-Zell-Aktivität",
            steps: [
                "1. Ruhige Umgebung",
                "2. Atemkohärenz aufbauen",
                "3. Visualisierung: Immunzellen aktiv",
                "4. 20 Minuten tiefe Kohärenz",
                "5. Positive Affirmation"
            ],
            targetCoherence: 0.8
        ),
        RegenerationProtocol(
            name: "Deep Sleep Preparation",
            duration: 900, // 15 min
            description: "Aktiviert Melatonin-Produktion und Regenerationsmodus",
            steps: [
                "1. 30 Min vor dem Schlafen",
                "2. Kein Blaulicht",
                "3. Tiefe Bauchatmung",
                "4. Body Scan Entspannung",
                "5. Kohärenz bis zum Einschlafen"
            ],
            targetCoherence: 0.6
        ),
        RegenerationProtocol(
            name: "Neuroplasticity Session",
            duration: 900,
            description: "Fördert BDNF für Gehirngesundheit",
            steps: [
                "1. Kohärenz aufbauen",
                "2. Neue Fähigkeit lernen/üben",
                "3. Kohärenz während des Lernens",
                "4. Kurze Meditation danach",
                "5. Erholungspause"
            ],
            targetCoherence: 0.75
        )
    ]

    // MARK: - Disclaimer

    public static let healthDisclaimer = """
    ⚠️ WICHTIGER HINWEIS

    Diese Funktion dient ausschließlich zu Bildungs- und Entspannungszwecken.

    • Kein Ersatz für ärztliche Diagnose oder Behandlung
    • Kein Medizinprodukt
    • Bei gesundheitlichen Beschwerden: Arzt konsultieren
    • HRV-Werte sind keine medizinischen Diagnosen

    Die dargestellten Informationen basieren auf wissenschaftlicher Forschung
    im Bereich Psychoneuroimmunologie, stellen jedoch keine medizinischen
    Empfehlungen dar.

    © 2026 Echoelmusic - Creative Wellness Tool
    """

    private init() {}
}

// MARK: - NeuroPsychoImmunoBody View

public struct NeuroPsychoImmunoBodyView: View {
    @ObservedObject private var engine = NeuroPsychoImmunoBodyEngine.shared
    @State private var selectedTab: Int = 0
    @State private var showDisclaimer: Bool = true

    public init() {}

    public var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                overviewTab
                    .tabItem { Label("Übersicht", systemImage: "heart.text.square") }
                    .tag(0)

                bodySystemsTab
                    .tabItem { Label("Körpersysteme", systemImage: "figure.stand") }
                    .tag(1)

                pniPathwaysTab
                    .tabItem { Label("PNI-Pfade", systemImage: "arrow.triangle.branch") }
                    .tag(2)

                protocolsTab
                    .tabItem { Label("Protokolle", systemImage: "list.bullet.clipboard") }
                    .tag(3)
            }
            .navigationTitle("NeuroBody")
            .sheet(isPresented: $showDisclaimer) {
                disclaimerSheet
            }
        }
    }

    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Coherence Status
                coherenceCard

                // Health Domains Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(NeuroPsychoImmunoBodyEngine.healthDomains) { domain in
                        HealthDomainCard(domain: domain)
                    }
                }

                // Scientific Basis
                scientificCard
            }
            .padding()
        }
    }

    private var coherenceCard: some View {
        VStack(spacing: 12) {
            Text("Aktuelle Kohärenz")
                .font(.headline)

            Text("\(Int(engine.currentCoherence * 100))%")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(coherenceColor)

            ForEach(engine.recommendations, id: \.self) { rec in
                Text(rec)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var coherenceColor: Color {
        if engine.currentCoherence < 0.4 { return .red }
        if engine.currentCoherence < 0.7 { return .yellow }
        return .green
    }

    private var scientificCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wissenschaftliche Grundlage")
                .font(.headline)

            Text(NeuroPsychoImmunoBodyEngine.ScientificBasis.definition)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("HRV & PNI")
                .font(.subheadline)
                .fontWeight(.medium)

            Text(NeuroPsychoImmunoBodyEngine.ScientificBasis.hrvConnection)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var bodySystemsTab: some View {
        List(NeuroPsychoImmunoBodyEngine.BodySystem.allCases) { system in
            HStack(spacing: 12) {
                Image(systemName: system.icon)
                    .font(.title2)
                    .foregroundStyle(.green)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(system.rawValue)
                        .font(.headline)

                    Text(system.hrvInfluence)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var pniPathwaysTab: some View {
        List(NeuroPsychoImmunoBodyEngine.pniPathways) { pathway in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(pathway.name)
                        .font(.headline)
                    Spacer()
                    Text(pathway.direction)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }

                Text(pathway.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Mechanismus: \(pathway.mechanism)")
                    .font(.caption)

                Text("Kohärenz: \(pathway.coherenceRole)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 8)
        }
    }

    private var protocolsTab: some View {
        List(NeuroPsychoImmunoBodyEngine.regenerationProtocols) { proto in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(proto.name)
                        .font(.headline)
                    Spacer()
                    Text("\(Int(proto.duration / 60)) Min")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }

                Text(proto.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(proto.steps, id: \.self) { step in
                    Text(step)
                        .font(.caption)
                }

                HStack {
                    Text("Ziel-Kohärenz:")
                    Text("\(Int(proto.targetCoherence * 100))%")
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }
            .padding(.vertical, 8)
        }
    }

    private var disclaimerSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("NeuroBody")
                .font(.title)
                .fontWeight(.bold)

            Text("Psychoneuroimmunologie & Körpergesundheit")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(NeuroPsychoImmunoBodyEngine.healthDisclaimer)
                    .font(.caption)
                    .padding()
            }
            .frame(maxHeight: 200)

            Button("Verstanden") {
                showDisclaimer = false
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
    }
}

// MARK: - Health Domain Card

struct HealthDomainCard: View {
    let domain: NeuroPsychoImmunoBodyEngine.HealthDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: domain.icon)
                    .foregroundStyle(.green)
                Text(domain.nameDE)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Text(domain.coherenceImpact)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}
