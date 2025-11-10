import Foundation

/// Sample Clearance & Copyright Protection
/// Automated sample recognition and clearance management
///
/// Features:
/// - Automatic sample detection (audio fingerprinting)
/// - Rights holder identification
/// - Clearance workflow management
/// - License negotiation tracking
/// - Copyright protection (Content ID)
/// - DMCA dispute resolution
@MainActor
class SampleClearanceSystem: ObservableObject {

    // MARK: - Published Properties

    @Published var samples: [DetectedSample] = []
    @Published var clearances: [Clearance] = []
    @Published var disputes: [CopyrightDispute] = []

    // MARK: - Detected Sample

    struct DetectedSample: Identifiable {
        let id = UUID()
        var sourceTrack: String
        var originalWork: OriginalWork
        var usage: SampleUsage
        var confidence: Double  // 0-1
        var status: ClearanceStatus

        struct OriginalWork {
            let title: String
            let artist: String
            let year: Int?
            let isrc: String?
            let rightsHolders: [RightsHolder]

            struct RightsHolder {
                let name: String
                let type: RightsType
                let percentage: Double?
                let contact: Contact?

                enum RightsType {
                    case master, publishing, both
                }

                struct Contact {
                    let email: String?
                    let phone: String?
                    let representedBy: String?  // Label, publisher
                }
            }
        }

        struct SampleUsage {
            let startTime: TimeInterval
            let duration: TimeInterval
            let looped: Bool
            let manipulated: Bool  // Pitched, chopped, etc.
            let prominence: Prominence

            enum Prominence {
                case background, featured, central
            }
        }

        enum ClearanceStatus {
            case detected, researching, contacting, negotiating
            case cleared, denied, disputed
        }
    }

    // MARK: - Clearance

    struct Clearance: Identifiable {
        let id = UUID()
        var sample: DetectedSample
        var license: License
        var status: Status
        var negotiations: [Negotiation]
        var finalAgreement: Agreement?

        struct License {
            let type: LicenseType
            var terms: Terms

            enum LicenseType {
                case masterUse  // Use of recording
                case mechanicalSync  // Use of composition
                case both
                case interpolation  // Re-record
            }

            struct Terms {
                var upfrontFee: Double?
                var royaltyPercentage: Double?
                var advanceRecoupable: Bool
                var territoryRestrictions: [String]?
                var termLength: TermLength?
                var usageRestrictions: [UsageRestriction]?

                enum TermLength {
                    case perpetuity
                    case years(Int)
                    case singleUse
                }

                enum UsageRestriction {
                    case noCommercialUse
                    case noSampling
                    case creditRequired
                    case approvalRequired
                }
            }
        }

        enum Status {
            case pending, approved, rejected, expired
        }

        struct Negotiation {
            let date: Date
            let party: String
            let offer: Offer
            let response: Response?

            struct Offer {
                let upfrontFee: Double?
                let royaltyPercentage: Double?
                let terms: String
            }

            enum Response {
                case accepted, countered(Offer), rejected
            }
        }

        struct Agreement {
            let signedDate: Date
            let upfrontFee: Double
            let royaltyPercentage: Double
            let terms: String
            let contract: URL?
        }
    }

    // MARK: - Copyright Dispute

    struct CopyrightDispute: Identifiable {
        let id = UUID()
        var claimant: String
        var work: String
        var platform: Platform
        var status: DisputeStatus
        var evidence: [Evidence]
        var resolution: Resolution?

        enum Platform: String {
            case youtube = "YouTube"
            case spotify = "Spotify"
            case soundcloud = "SoundCloud"
            case instagram = "Instagram"
            case facebook = "Facebook"
        }

        enum DisputeStatus {
            case claimed, disputed, underReview, resolved
        }

        struct Evidence {
            let type: EvidenceType
            let description: String
            let file: URL?

            enum EvidenceType {
                case originalRecording, license, permission
                case correspondence, invoice, other
            }
        }

        struct Resolution {
            let date: Date
            let outcome: Outcome
            let details: String

            enum Outcome {
                case claimValid, claimInvalid, settled
            }
        }
    }

    // MARK: - Initialization

    init() {
        print("⚖️ Sample Clearance System initialized")
    }

    // MARK: - Detect Samples

    func detectSamples(in audioFile: URL) async -> [DetectedSample] {
        print("🔍 Analyzing audio for samples...")

        // Audio fingerprinting & recognition
        // In production: Use services like:
        // - ACRCloud
        // - Audible Magic
        // - Gracenote
        // - Shazam API

        try? await Task.sleep(nanoseconds: 3_000_000_000)

        // Simulated detection
        let detectedSamples = [
            DetectedSample(
                sourceTrack: "My New Track",
                originalWork: DetectedSample.OriginalWork(
                    title: "Break Beat Sample",
                    artist: "Original Artist",
                    year: 1975,
                    isrc: "USXXX7500001",
                    rightsHolders: [
                        DetectedSample.OriginalWork.RightsHolder(
                            name: "Major Label Records",
                            type: .master,
                            percentage: 100,
                            contact: DetectedSample.OriginalWork.RightsHolder.Contact(
                                email: "licensing@majorlabel.com",
                                phone: nil,
                                representedBy: "Major Label Records"
                            )
                        ),
                        DetectedSample.OriginalWork.RightsHolder(
                            name: "Music Publishing Co.",
                            type: .publishing,
                            percentage: 100,
                            contact: nil
                        ),
                    ]
                ),
                usage: DetectedSample.SampleUsage(
                    startTime: 15.5,
                    duration: 4.0,
                    looped: true,
                    manipulated: true,
                    prominence: .featured
                ),
                confidence: 0.94,
                status: .detected
            ),
        ]

        samples.append(contentsOf: detectedSamples)

        print("   ✅ Detected \(detectedSamples.count) samples")

        for sample in detectedSamples {
            print("      → \(sample.originalWork.title) by \(sample.originalWork.artist)")
            print("         Confidence: \(String(format: "%.0f", sample.confidence * 100))%")
            print("         Rights Holders: \(sample.originalWork.rightsHolders.count)")
        }

        return detectedSamples
    }

    // MARK: - Initiate Clearance

    func initiateClearance(
        for sampleId: UUID,
        licenseType: Clearance.License.LicenseType
    ) async -> Clearance {
        guard let sample = samples.first(where: { $0.id == sampleId }) else {
            fatalError("Sample not found")
        }

        print("📋 Initiating clearance for: \(sample.originalWork.title)")

        // Update sample status
        if let index = samples.firstIndex(where: { $0.id == sampleId }) {
            samples[index].status = .contacting
        }

        // Create clearance request
        let clearance = Clearance(
            sample: sample,
            license: Clearance.License(
                type: licenseType,
                terms: Clearance.License.Terms(
                    upfrontFee: nil,
                    royaltyPercentage: nil,
                    advanceRecoupable: false,
                    territoryRestrictions: nil,
                    termLength: .perpetuity,
                    usageRestrictions: nil
                )
            ),
            status: .pending,
            negotiations: []
        )

        clearances.append(clearance)

        // Contact rights holders
        await contactRightsHolders(for: sample)

        print("   ✅ Clearance request initiated")

        return clearance
    }

    private func contactRightsHolders(for sample: DetectedSample) async {
        print("   📧 Contacting rights holders...")

        for holder in sample.originalWork.rightsHolders {
            print("      → \(holder.name) (\(holder.type))")

            if let contact = holder.contact, let email = contact.email {
                let message = generateClearanceRequest(
                    sample: sample,
                    rightsHolder: holder
                )

                print("         Email: \(email)")
                print("         Message: [Generated clearance request]")

                // In production: Send actual email
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        print("      ✅ All rights holders contacted")
    }

    private func generateClearanceRequest(
        sample: DetectedSample,
        rightsHolder: DetectedSample.OriginalWork.RightsHolder
    ) -> String {
        return """
        Dear \(rightsHolder.name),

        I am requesting clearance to use a sample from "\(sample.originalWork.title)"
        by \(sample.originalWork.artist) in my upcoming track "\(sample.sourceTrack)".

        Sample Details:
        - Duration: \(String(format: "%.1f", sample.usage.duration)) seconds
        - Usage: \(sample.usage.prominence)
        - Manipulated: \(sample.usage.manipulated ? "Yes" : "No")

        I am seeking a \(sample.originalWork.rightsHolders.count == 1 ? "master and publishing" : "\(rightsHolder.type)") license.

        Please let me know your terms and availability for this clearance.

        Best regards,
        [Artist Name]
        """
    }

    // MARK: - Record Negotiation

    func recordNegotiation(
        clearanceId: UUID,
        offer: Clearance.Negotiation.Offer,
        response: Clearance.Negotiation.Response?
    ) {
        guard let index = clearances.firstIndex(where: { $0.id == clearanceId }) else {
            return
        }

        let negotiation = Clearance.Negotiation(
            date: Date(),
            party: clearances[index].sample.originalWork.rightsHolders.first?.name ?? "Unknown",
            offer: offer,
            response: response
        )

        clearances[index].negotiations.append(negotiation)

        print("💼 Negotiation recorded")
        print("   Offer: \(offer)")
    }

    // MARK: - Finalize Agreement

    func finalizeAgreement(
        clearanceId: UUID,
        upfrontFee: Double,
        royaltyPercentage: Double,
        contract: URL?
    ) {
        guard let index = clearances.firstIndex(where: { $0.id == clearanceId }) else {
            return
        }

        let agreement = Clearance.Agreement(
            signedDate: Date(),
            upfrontFee: upfrontFee,
            royaltyPercentage: royaltyPercentage,
            terms: "Full terms in contract",
            contract: contract
        )

        clearances[index].finalAgreement = agreement
        clearances[index].status = .approved

        // Update sample status
        if let sampleIndex = samples.firstIndex(where: { $0.id == clearances[index].sample.id }) {
            samples[sampleIndex].status = .cleared
        }

        print("✅ Clearance finalized")
        print("   Upfront Fee: $\(String(format: "%.2f", upfrontFee))")
        print("   Royalty: \(String(format: "%.1f", royaltyPercentage))%")
    }

    // MARK: - Copyright Protection

    func registerContentID(track: String, audioFile: URL) async {
        print("🛡️ Registering with Content ID systems...")

        // Register with platform content ID systems
        // - YouTube Content ID
        // - Facebook Rights Manager
        // - Instagram Copyright Detection
        // - SoundCloud Copyright Detection

        let platforms = ["YouTube", "Facebook", "Instagram", "SoundCloud"]

        for platform in platforms {
            print("   → Registering with \(platform)...")
            try? await Task.sleep(nanoseconds: 500_000_000)
            print("      ✅ Registered")
        }

        print("   ✅ Content ID registration complete")
    }

    // MARK: - DMCA Dispute

    func fileDMCADispute(
        claimant: String,
        work: String,
        platform: CopyrightDispute.Platform,
        evidence: [CopyrightDispute.Evidence]
    ) -> CopyrightDispute {
        print("⚖️ Filing DMCA dispute...")

        let dispute = CopyrightDispute(
            claimant: claimant,
            work: work,
            platform: platform,
            status: .disputed,
            evidence: evidence
        )

        disputes.append(dispute)

        print("   ✅ Dispute filed with \(platform.rawValue)")
        print("      Evidence: \(evidence.count) items")

        return dispute
    }

    func resolveDispute(
        disputeId: UUID,
        outcome: CopyrightDispute.Resolution.Outcome,
        details: String
    ) {
        guard let index = disputes.firstIndex(where: { $0.id == disputeId }) else {
            return
        }

        let resolution = CopyrightDispute.Resolution(
            date: Date(),
            outcome: outcome,
            details: details
        )

        disputes[index].resolution = resolution
        disputes[index].status = .resolved

        print("✅ Dispute resolved: \(outcome)")
    }

    // MARK: - Generate Report

    func generateClearanceReport() -> String {
        var report = """
        ═══════════════════════════════════════
        SAMPLE CLEARANCE REPORT
        ═══════════════════════════════════════

        SAMPLES
        ───────────────────────────────────────
        Total Detected: \(samples.count)

        """

        let statusGroups = Dictionary(grouping: samples) { $0.status }

        for (status, samplesInStatus) in statusGroups.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            report += """
            \(status): \(samplesInStatus.count)

            """
        }

        // Clearance breakdown
        report += """


        CLEARANCES
        ───────────────────────────────────────
        Total: \(clearances.count)
        Approved: \(clearances.filter { $0.status == .approved }.count)
        Pending: \(clearances.filter { $0.status == .pending }.count)
        Rejected: \(clearances.filter { $0.status == .rejected }.count)

        """

        // Total costs
        let totalUpfront = clearances.compactMap { $0.finalAgreement?.upfrontFee }.reduce(0, +)
        let avgRoyalty = clearances.compactMap { $0.finalAgreement?.royaltyPercentage }.reduce(0, +) / Double(clearances.count)

        report += """


        COSTS
        ───────────────────────────────────────
        Total Upfront Fees: $\(String(format: "%.2f", totalUpfront))
        Average Royalty: \(String(format: "%.1f", avgRoyalty))%

        """

        // Disputes
        if !disputes.isEmpty {
            report += """


            DISPUTES
            ───────────────────────────────────────
            Total: \(disputes.count)
            Resolved: \(disputes.filter { $0.status == .resolved }.count)

            """
        }

        report += "\n═══════════════════════════════════════"

        return report
    }
}

// MARK: - Extensions

extension SampleClearanceSystem.DetectedSample.ClearanceStatus: RawRepresentable {
    typealias RawValue = String

    init?(rawValue: String) {
        switch rawValue {
        case "detected": self = .detected
        case "researching": self = .researching
        case "contacting": self = .contacting
        case "negotiating": self = .negotiating
        case "cleared": self = .cleared
        case "denied": self = .denied
        case "disputed": self = .disputed
        default: return nil
        }
    }

    var rawValue: String {
        switch self {
        case .detected: return "detected"
        case .researching: return "researching"
        case .contacting: return "contacting"
        case .negotiating: return "negotiating"
        case .cleared: return "cleared"
        case .denied: return "denied"
        case .disputed: return "disputed"
        }
    }
}
