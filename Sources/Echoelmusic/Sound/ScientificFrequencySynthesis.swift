import Foundation
import Accelerate

/// Scientific Frequency Synthesis Engine
///
/// Generates frequencies based on peer-reviewed scientific research.
/// NO HEALTH CLAIMS - Only documented frequencies from published studies.
///
/// Data sources:
/// - NASA Technical Reports Server (NTRS)
/// - NIH PubMed / PMC
/// - Nature, Science, PNAS publications
/// - University of Chicago Quantum Biology Lab
/// - Max Planck Institute for Biophysics
///
/// Categories:
/// 1. Neuroacoustic frequencies (EEG-correlated)
/// 2. Photosynthetic coherence frequencies (quantum biology)
/// 3. NASA space plasma sonification frequencies
/// 4. Acoustic room standards (ISO/NASA-STD)
///
/// IMPORTANT: This is for audio/music generation and research visualization.
/// No therapeutic claims are made or implied.
@MainActor
class ScientificFrequencySynthesis: ObservableObject {

    // MARK: - Singleton

    static let shared = ScientificFrequencySynthesis()

    // MARK: - Published State

    @Published var activeCategory: FrequencyCategory = .neuroacoustic
    @Published var selectedFrequency: ScientificFrequency?
    @Published var isPlaying: Bool = false

    // MARK: - Frequency Categories

    enum FrequencyCategory: String, CaseIterable, Identifiable {
        case neuroacoustic = "Neuroacoustic (EEG)"
        case quantumBiology = "Quantum Biology"
        case nasaSpace = "NASA Space Plasma"
        case acousticStandards = "Acoustic Standards"
        case biorhythm = "Biorhythm Research"

        var id: String { rawValue }
    }

    // MARK: - Scientific Frequency Definition

    struct ScientificFrequency: Identifiable {
        let id = UUID()
        let name: String
        let frequencyHz: Double
        let category: FrequencyCategory
        let citation: String
        let doi: String?
        let description: String
        let year: Int

        /// Convert wavenumber (cm⁻¹) to Hz
        static func fromWavenumber(_ cm1: Double) -> Double {
            // ν (Hz) = c (cm/s) × wavenumber (cm⁻¹)
            // c = 2.998 × 10¹⁰ cm/s
            return cm1 * 2.998e10
        }
    }

    // MARK: - Scientific Frequency Database

    /// All scientifically documented frequencies
    let frequencyDatabase: [ScientificFrequency] = [

        // ════════════════════════════════════════════════════════════════════
        // NEUROACOUSTIC (EEG-Correlated) Frequencies
        // Based on clinical EEG standards: Niedermeyer & da Silva (2005)
        // ════════════════════════════════════════════════════════════════════

        ScientificFrequency(
            name: "Delta Band Center",
            frequencyHz: 2.0,
            category: .neuroacoustic,
            citation: "Niedermeyer E, da Silva FL. Electroencephalography. Lippincott Williams & Wilkins, 2005",
            doi: nil,
            description: "Delta rhythm (0.5-4 Hz) center frequency. Associated with deep sleep stages 3-4 (NREM).",
            year: 2005
        ),
        ScientificFrequency(
            name: "Theta Band Center",
            frequencyHz: 6.0,
            category: .neuroacoustic,
            citation: "Buzsáki G. Theta rhythm of navigation. Neuron, 2005",
            doi: "10.1016/j.neuron.2005.08.002",
            description: "Theta rhythm (4-8 Hz) center. Associated with memory consolidation, spatial navigation.",
            year: 2005
        ),
        ScientificFrequency(
            name: "Alpha Band Center",
            frequencyHz: 10.0,
            category: .neuroacoustic,
            citation: "Klimesch W. Alpha oscillations. Brain Res Rev, 1999",
            doi: "10.1016/S0165-0173(98)00056-3",
            description: "Alpha rhythm (8-13 Hz) center. Berger rhythm, eyes-closed relaxed wakefulness.",
            year: 1999
        ),
        ScientificFrequency(
            name: "SMR (Sensorimotor Rhythm)",
            frequencyHz: 13.0,
            category: .neuroacoustic,
            citation: "Sterman MB. SMR neurofeedback. Appl Psychophysiol Biofeedback, 2000",
            doi: "10.1023/A:1009562206048",
            description: "Sensorimotor rhythm (12-15 Hz). Motor cortex idle rhythm.",
            year: 2000
        ),
        ScientificFrequency(
            name: "Beta Band Center",
            frequencyHz: 20.0,
            category: .neuroacoustic,
            citation: "Engel AK, Fries P. Beta-band oscillations. Curr Opin Neurobiol, 2010",
            doi: "10.1016/j.conb.2010.02.014",
            description: "Beta rhythm (13-30 Hz) center. Active thinking, focus, motor planning.",
            year: 2010
        ),
        ScientificFrequency(
            name: "Gamma 40 Hz",
            frequencyHz: 40.0,
            category: .neuroacoustic,
            citation: "Iaccarino HF et al. Gamma frequency entrainment. Nature, 2016",
            doi: "10.1038/nature20587",
            description: "40 Hz gamma. NIH research on cognitive function. Binding, attention, perception.",
            year: 2016
        ),
        ScientificFrequency(
            name: "High Gamma",
            frequencyHz: 80.0,
            category: .neuroacoustic,
            citation: "Crone NE et al. High-frequency gamma. Brain, 1998",
            doi: "10.1093/brain/121.12.2301",
            description: "High gamma (60-100 Hz). Language processing, working memory.",
            year: 1998
        ),

        // ════════════════════════════════════════════════════════════════════
        // QUANTUM BIOLOGY - Photosynthetic Coherence Frequencies
        // Based on: Engel et al., Fleming Lab, University of Chicago
        // ════════════════════════════════════════════════════════════════════

        ScientificFrequency(
            name: "Photosynthetic Mode 120 cm⁻¹",
            frequencyHz: 3.60e12,  // 120 cm⁻¹ = 3.6 THz
            category: .quantumBiology,
            citation: "Romero E et al. Quantum coherence in photosynthesis. Nat Phys, 2014",
            doi: "10.1038/nphys3017",
            description: "Vibrational mode resonant with exciton-CT energy gap in PSII. Sustains electronic coherence.",
            year: 2014
        ),
        ScientificFrequency(
            name: "Photosynthetic Mode 340 cm⁻¹",
            frequencyHz: 1.02e13,  // 340 cm⁻¹ = 10.2 THz
            category: .quantumBiology,
            citation: "Romero E et al. Quantum coherence in photosynthesis. Nat Phys, 2014",
            doi: "10.1038/nphys3017",
            description: "Second vibrational mode in PSII reaction center. CT state formation within femtoseconds.",
            year: 2014
        ),
        ScientificFrequency(
            name: "Photosynthetic Mode 730 cm⁻¹",
            frequencyHz: 2.19e13,  // 730 cm⁻¹ = 21.9 THz
            category: .quantumBiology,
            citation: "Romero E et al. Quantum coherence in photosynthesis. Nat Phys, 2014",
            doi: "10.1038/nphys3017",
            description: "Third vibrational mode. Regenerates electronic coherence for ultrafast charge separation.",
            year: 2014
        ),
        ScientificFrequency(
            name: "FMO Coherence Frequency",
            frequencyHz: 7.1e12,  // ~237 cm⁻¹
            category: .quantumBiology,
            citation: "Engel GS et al. Evidence for quantum coherence. Nature, 2007",
            doi: "10.1038/nature05678",
            description: "Fenna-Matthews-Olson complex. First evidence of quantum coherence at biological temperatures.",
            year: 2007
        ),
        ScientificFrequency(
            name: "Allophycocyanin Coherence",
            frequencyHz: 5.4e12,  // ~180 cm⁻¹
            category: .quantumBiology,
            citation: "Chen F et al. Quantum phase synchronization. Nat Commun, 2024",
            doi: "10.1038/s41467-024-47560-y",
            description: "Exciton-vibrational coherence in allophycocyanin trimer. Quantum phase synchronization.",
            year: 2024
        ),

        // ════════════════════════════════════════════════════════════════════
        // NASA SPACE PLASMA SONIFICATION
        // Based on: NASA HARP Project, Goddard Space Flight Center
        // ════════════════════════════════════════════════════════════════════

        ScientificFrequency(
            name: "Magnetospheric Chorus Lower",
            frequencyHz: 0.1,  // Actual: ~100-1000 Hz scaled to ULF
            category: .nasaSpace,
            citation: "NASA HARP Project. Heliophysics Audified: Resonances in Plasmas, 2024",
            doi: nil,
            description: "Lower chorus emissions from Earth's magnetosphere. 'Reverse harp' phenomenon.",
            year: 2024
        ),
        ScientificFrequency(
            name: "Magnetospheric Chorus Upper",
            frequencyHz: 0.5,
            category: .nasaSpace,
            citation: "NASA HARP Project, 2024",
            doi: nil,
            description: "Upper band chorus. Solar plasma strikes causing magnetic field vibrations.",
            year: 2024
        ),
        ScientificFrequency(
            name: "Schumann Resonance Fundamental",
            frequencyHz: 7.83,
            category: .nasaSpace,
            citation: "Schumann WO. Über die strahlungslosen Eigenschwingungen. Z Naturforsch, 1952",
            doi: nil,
            description: "Earth-ionosphere cavity resonance fundamental. NOT mystical - pure EM physics.",
            year: 1952
        ),
        ScientificFrequency(
            name: "Schumann 2nd Harmonic",
            frequencyHz: 14.3,
            category: .nasaSpace,
            citation: "NASA Technical Reports: Earth EM Environment",
            doi: nil,
            description: "Second mode of Earth-ionosphere cavity resonance.",
            year: 1952
        ),
        ScientificFrequency(
            name: "Schumann 3rd Harmonic",
            frequencyHz: 20.8,
            category: .nasaSpace,
            citation: "NASA Technical Reports: Earth EM Environment",
            doi: nil,
            description: "Third mode of Earth-ionosphere cavity resonance.",
            year: 1952
        ),

        // ════════════════════════════════════════════════════════════════════
        // ACOUSTIC STANDARDS (ISO / NASA-STD)
        // Based on: ISO 266, NASA-STD-3001
        // ════════════════════════════════════════════════════════════════════

        ScientificFrequency(
            name: "ISO Preferred 63 Hz",
            frequencyHz: 63.0,
            category: .acousticStandards,
            citation: "ISO 266:1997 Preferred frequencies for acoustics",
            doi: nil,
            description: "ISO preferred frequency. Low frequency room mode reference.",
            year: 1997
        ),
        ScientificFrequency(
            name: "ISO Preferred 125 Hz",
            frequencyHz: 125.0,
            category: .acousticStandards,
            citation: "ISO 266:1997",
            doi: nil,
            description: "ISO preferred frequency. Bass frequency reference.",
            year: 1997
        ),
        ScientificFrequency(
            name: "ISO Preferred 1000 Hz",
            frequencyHz: 1000.0,
            category: .acousticStandards,
            citation: "ISO 266:1997",
            doi: nil,
            description: "Reference frequency for audio measurements. 0 dB SPL reference.",
            year: 1997
        ),
        ScientificFrequency(
            name: "NASA ISS NC-50 Low",
            frequencyHz: 63.0,
            category: .acousticStandards,
            citation: "NASA-STD-3001 Technical Requirements: Acoustics, 2023",
            doi: nil,
            description: "ISS noise criterion: 70 dB limit at 63 Hz for crew safety.",
            year: 2023
        ),
        ScientificFrequency(
            name: "NASA ISS NC-50 High",
            frequencyHz: 8000.0,
            category: .acousticStandards,
            citation: "NASA-STD-3001 Technical Requirements: Acoustics, 2023",
            doi: nil,
            description: "ISS noise criterion: 45 dB limit at 8 kHz. Human ear more sensitive.",
            year: 2023
        ),

        // ════════════════════════════════════════════════════════════════════
        // BIORHYTHM RESEARCH
        // Based on: Circadian, HRV, and physiological studies
        // ════════════════════════════════════════════════════════════════════

        ScientificFrequency(
            name: "HRV Resonance Frequency",
            frequencyHz: 0.1,
            category: .biorhythm,
            citation: "Lehrer PM et al. HRV biofeedback. Appl Psychophysiol Biofeedback, 2003",
            doi: "10.1023/A:1022312815649",
            description: "~0.1 Hz (6 breaths/min). Cardiovascular resonance frequency for HRV biofeedback.",
            year: 2003
        ),
        ScientificFrequency(
            name: "Respiratory Sinus Arrhythmia",
            frequencyHz: 0.25,
            category: .biorhythm,
            citation: "Berntson GG et al. RSA. Psychophysiology, 1993",
            doi: "10.1111/j.1469-8986.1993.tb02094.x",
            description: "~0.15-0.4 Hz. Heart rate variation with breathing cycle.",
            year: 1993
        ),
        ScientificFrequency(
            name: "Cardiac Frequency Typical",
            frequencyHz: 1.0,
            category: .biorhythm,
            citation: "Standard physiological reference",
            doi: nil,
            description: "60 BPM = 1 Hz. Resting heart rate reference frequency.",
            year: 2000
        ),
    ]

    // MARK: - Frequency Lookup

    /// Get frequencies by category
    func getFrequencies(for category: FrequencyCategory) -> [ScientificFrequency] {
        return frequencyDatabase.filter { $0.category == category }
    }

    /// Get all audible frequencies (< 20 kHz)
    func getAudibleFrequencies() -> [ScientificFrequency] {
        return frequencyDatabase.filter { $0.frequencyHz <= 20000 && $0.frequencyHz >= 20 }
    }

    /// Get all sub-bass frequencies (< 60 Hz)
    func getSubBassFrequencies() -> [ScientificFrequency] {
        return frequencyDatabase.filter { $0.frequencyHz < 60 && $0.frequencyHz >= 0.1 }
    }

    /// Scale THz frequencies to audible range (for sonification)
    func scaleToAudible(_ frequency: Double, targetRange: ClosedRange<Double> = 100...2000) -> Double {
        // For quantum biology THz frequencies, scale down by ratio
        if frequency > 1e9 {
            // Use log scaling to map THz to Hz
            let logFreq = log10(frequency)
            let logMin = log10(1e12)  // 1 THz
            let logMax = log10(1e14)  // 100 THz
            let normalized = (logFreq - logMin) / (logMax - logMin)
            return targetRange.lowerBound + normalized * (targetRange.upperBound - targetRange.lowerBound)
        }
        return frequency
    }

    // MARK: - Citation Export

    /// Export all citations in BibTeX format
    func exportBibTeX() -> String {
        var bibtex = "% Scientific Frequency Database Citations\n"
        bibtex += "% Generated by Echoelmusic Scientific Synthesis Engine\n\n"

        for (index, freq) in frequencyDatabase.enumerated() {
            bibtex += "@article{echoelfreq\(index),\n"
            bibtex += "  title = {\(freq.name)},\n"
            bibtex += "  note = {\(freq.citation)},\n"
            if let doi = freq.doi {
                bibtex += "  doi = {\(doi)},\n"
            }
            bibtex += "  year = {\(freq.year)}\n"
            bibtex += "}\n\n"
        }

        return bibtex
    }

    // MARK: - Initialization

    init() {}
}

// MARK: - Frequency Generation

extension ScientificFrequencySynthesis {

    /// Generate a tone at the scientific frequency
    func generateTone(frequency: ScientificFrequency, duration: Double, sampleRate: Double = 48000) -> [Float] {
        let audibleFreq = scaleToAudible(frequency.frequencyHz)
        let frameCount = Int(duration * sampleRate)
        var output = [Float](repeating: 0, count: frameCount)

        let phaseIncrement = audibleFreq / sampleRate
        var phase = 0.0

        for i in 0..<frameCount {
            // Pure sine wave
            output[i] = Float(sin(phase * 2.0 * .pi))

            phase += phaseIncrement
            if phase >= 1.0 { phase -= 1.0 }
        }

        // Apply envelope to avoid clicks
        let fadeLength = min(Int(0.01 * sampleRate), frameCount / 4)
        for i in 0..<fadeLength {
            let envelope = Float(i) / Float(fadeLength)
            output[i] *= envelope
            output[frameCount - 1 - i] *= envelope
        }

        return output
    }

    /// Generate harmonic series based on scientific frequency
    func generateHarmonicSeries(fundamental: ScientificFrequency, harmonics: Int = 8, duration: Double, sampleRate: Double = 48000) -> [Float] {
        let fundFreq = scaleToAudible(fundamental.frequencyHz)
        let frameCount = Int(duration * sampleRate)
        var output = [Float](repeating: 0, count: frameCount)

        for h in 1...harmonics {
            let freq = fundFreq * Double(h)
            if freq > sampleRate / 2 { break }  // Nyquist

            let amplitude = 1.0 / Double(h)  // Natural harmonic decay
            let phaseInc = freq / sampleRate
            var phase = 0.0

            for i in 0..<frameCount {
                output[i] += Float(sin(phase * 2.0 * .pi) * amplitude)
                phase += phaseInc
                if phase >= 1.0 { phase -= 1.0 }
            }
        }

        // Normalize
        if let maxVal = output.max(), maxVal > 0 {
            let scale = 0.8 / maxVal
            for i in 0..<frameCount {
                output[i] *= scale
            }
        }

        return output
    }
}
