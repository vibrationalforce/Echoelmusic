import Foundation
import Combine

/// Rights Management System
/// Professional IP protection and rights management
///
/// Features:
/// - Copyright registration & management
/// - Performance rights (GEMA, ASCAP, BMI, etc.)
/// - Mechanical rights
/// - Synchronization rights (for video/film)
/// - Image rights (photography, artwork)
/// - Trademark protection
/// - Creative Commons licensing
/// - Rights claiming automation
/// - Revenue tracking
/// - Contract management
/// - Legal documentation
@MainActor
class RightsManagementSystem: ObservableObject {

    // MARK: - Published Properties

    @Published var registeredWorks: [Work] = []
    @Published var contracts: [Contract] = []
    @Published var claims: [RightsClaim] = []

    // MARK: - Work Registration

    struct Work: Identifiable, Codable {
        let id: UUID
        var title: String
        var type: WorkType
        var creators: [Creator]

        // Rights
        var copyrightHolder: String
        var copyrightYear: Int
        var copyrightRegistration: CopyrightRegistration?

        // Identifiers
        var iswc: String?  // International Standard Musical Work Code
        var isrc: String?  // International Standard Recording Code
        var isbn: String?  // Books
        var issn: String?  // Periodicals
        var doi: String?   // Digital Object Identifier (academic)

        // Licensing
        var license: License
        var territoryRights: [Territory: RightsType]

        // Revenue split
        var revenueSplit: [Creator: Double]  // Percentage (0.0-1.0)

        // Metadata
        var registrationDate: Date
        var expirationDate: Date?  // Copyright expiration

        init(title: String, type: WorkType, creator: Creator) {
            self.id = UUID()
            self.title = title
            self.type = type
            self.creators = [creator]
            self.copyrightHolder = creator.name
            self.copyrightYear = Calendar.current.component(.year, from: Date())
            self.license = .allRightsReserved
            self.territoryRights = [:]
            self.revenueSplit = [creator: 1.0]
            self.registrationDate = Date()

            // Copyright duration: life + 70 years (EU/US standard)
            if let expiryYear = Calendar.current.date(byAdding: .year, value: 70, to: Date()) {
                self.expirationDate = expiryYear
            }
        }
    }

    enum WorkType: String, Codable, CaseIterable {
        case musicalComposition = "Musical Composition"
        case soundRecording = "Sound Recording"
        case book = "Book"
        case article = "Article"
        case photograph = "Photograph"
        case artwork = "Artwork/Visual Art"
        case video = "Video/Film"
        case software = "Software"
        case performance = "Performance"
        case lyrics = "Lyrics"
        case arrangement = "Musical Arrangement"
    }

    struct Creator: Identifiable, Codable, Hashable {
        let id: UUID
        var name: String
        var role: CreatorRole
        var ipi: String?  // Interested Party Information (CISAC)
        var isni: String?  // International Standard Name Identifier

        // PRO membership
        var performanceRightsOrg: PerformanceRightsOrganization?
        var mechanicalRightsOrg: MechanicalRightsOrganization?

        enum CreatorRole: String, Codable, CaseIterable {
            case composer = "Composer"
            case lyricist = "Lyricist"
            case author = "Author"
            case photographer = "Photographer"
            case artist = "Artist"
            case producer = "Producer"
            case arranger = "Arranger"
            case performer = "Performer"
        }
    }

    // MARK: - Copyright Registration

    struct CopyrightRegistration: Codable {
        var registrationNumber: String
        var registrationDate: Date
        var authority: CopyrightAuthority
        var certificateURL: URL?

        enum CopyrightAuthority: String, Codable {
            case usco = "US Copyright Office"
            case ukipo = "UK Intellectual Property Office"
            case dpma = "DPMA (Germany)"
            case wipo = "WIPO (International)"
            case euipo = "EUIPO (European Union)"
        }
    }

    // MARK: - Performance Rights Organizations

    enum PerformanceRightsOrganization: String, Codable, CaseIterable {
        // Germany
        case gema = "GEMA (Germany)"

        // USA
        case ascap = "ASCAP (USA)"
        case bmi = "BMI (USA)"
        case sesac = "SESAC (USA)"

        // UK
        case prs = "PRS for Music (UK)"

        // Europe
        case sacem = "SACEM (France)"
        case siae = "SIAE (Italy)"
        case sgae = "SGAE (Spain)"
        case buma = "BUMA (Netherlands)"
        case tono = "TONO (Norway)"
        case stim = "STIM (Sweden)"

        // Americas
        case socan = "SOCAN (Canada)"
        case sacm = "SACM (Mexico)"
        case sadaic = "SADAIC (Argentina)"

        // Asia/Pacific
        case apra = "APRA (Australia)"
        case jasrac = "JASRAC (Japan)"
        case komca = "KOMCA (South Korea)"

        var country: String {
            switch self {
            case .gema: return "DE"
            case .ascap, .bmi, .sesac: return "US"
            case .prs: return "GB"
            case .sacem: return "FR"
            case .siae: return "IT"
            case .sgae: return "ES"
            case .buma: return "NL"
            case .tono: return "NO"
            case .stim: return "SE"
            case .socan: return "CA"
            case .sacm: return "MX"
            case .sadaic: return "AR"
            case .apra: return "AU"
            case .jasrac: return "JP"
            case .komca: return "KR"
            }
        }
    }

    enum MechanicalRightsOrganization: String, Codable, CaseIterable {
        case gema = "GEMA (Germany)"
        case harryfox = "Harry Fox Agency (USA)"
        case mcps = "MCPS (UK)"
        case cmrra = "CMRRA (Canada)"
        case amcos = "AMCOS (Australia)"
        case sdrm = "SDRM (France)"
    }

    // MARK: - Licensing

    enum License: String, Codable, CaseIterable {
        // Traditional Copyright
        case allRightsReserved = "All Rights Reserved (©)"

        // Creative Commons
        case cc0 = "CC0 (Public Domain)"
        case ccBy = "CC BY (Attribution)"
        case ccBySA = "CC BY-SA (Attribution-ShareAlike)"
        case ccByND = "CC BY-ND (Attribution-NoDerivs)"
        case ccByNC = "CC BY-NC (Attribution-NonCommercial)"
        case ccByNCSA = "CC BY-NC-SA (Attribution-NonCommercial-ShareAlike)"
        case ccByNCND = "CC BY-NC-ND (Attribution-NonCommercial-NoDerivs)"

        // Open Source (for software)
        case mit = "MIT License"
        case gplv3 = "GPL v3"
        case apache2 = "Apache 2.0"
        case bsd = "BSD License"

        // Music-specific
        case royaltyFree = "Royalty-Free"
        case syncLicense = "Sync License"

        var allowsCommercialUse: Bool {
            switch self {
            case .allRightsReserved: return false
            case .cc0, .ccBy, .ccBySA, .ccByND: return true
            case .ccByNC, .ccByNCSA, .ccByNCND: return false
            case .mit, .apache2, .bsd: return true
            case .gplv3: return true
            case .royaltyFree, .syncLicense: return true
            }
        }

        var requiresAttribution: Bool {
            switch self {
            case .allRightsReserved, .cc0: return false
            case .ccBy, .ccBySA, .ccByND, .ccByNC, .ccByNCSA, .ccByNCND: return true
            case .mit, .apache2, .bsd, .gplv3: return true
            case .royaltyFree, .syncLicense: return false
            }
        }
    }

    enum Territory: String, Codable, CaseIterable {
        case worldwide = "Worldwide"
        case northAmerica = "North America"
        case europe = "Europe"
        case asia = "Asia"
        case southAmerica = "South America"
        case africa = "Africa"
        case oceania = "Oceania"

        // Specific countries
        case usa = "USA"
        case uk = "UK"
        case germany = "Germany"
        case france = "France"
        case japan = "Japan"
        case china = "China"
        case india = "India"
        case brazil = "Brazil"
    }

    enum RightsType: String, Codable {
        case exclusive = "Exclusive Rights"
        case nonExclusive = "Non-Exclusive Rights"
        case limitedExclusive = "Limited Exclusive"
    }

    // MARK: - Rights Claims

    struct RightsClaim: Identifiable, Codable {
        let id: UUID
        var work: Work
        var platform: Platform
        var claimType: ClaimType
        var status: ClaimStatus
        var submissionDate: Date
        var resolvedDate: Date?
        var revenue: Revenue?

        enum Platform: String, Codable, CaseIterable {
            case youtube = "YouTube (Content ID)"
            case spotify = "Spotify"
            case appleMusic = "Apple Music"
            case amazonMusic = "Amazon Music"
            case tidal = "TIDAL"
            case deezer = "Deezer"
            case soundcloud = "SoundCloud"
            case facebook = "Facebook"
            case instagram = "Instagram"
            case tiktok = "TikTok"
            case twitch = "Twitch"
        }

        enum ClaimType: String, Codable {
            case copyrightClaim = "Copyright Claim"
            case contentID = "Content ID Match"
            case dmcaTakedown = "DMCA Takedown"
            case trademark = "Trademark Claim"
            case monetization = "Monetization Claim"
        }

        enum ClaimStatus: String, Codable {
            case pending = "Pending"
            case approved = "Approved"
            case rejected = "Rejected"
            case disputed = "Disputed"
            case resolved = "Resolved"
        }

        struct Revenue: Codable {
            var amount: Double
            var currency: String
            var period: DateInterval
        }
    }

    // MARK: - Contracts

    struct Contract: Identifiable, Codable {
        let id: UUID
        var type: ContractType
        var parties: [ContractParty]
        var work: Work?
        var terms: ContractTerms
        var signatures: [Signature]
        var status: ContractStatus
        var creationDate: Date
        var effectiveDate: Date
        var expirationDate: Date?

        enum ContractType: String, Codable, CaseIterable {
            case publishingDeal = "Publishing Deal"
            case recordingContract = "Recording Contract"
            case distributionDeal = "Distribution Deal"
            case syncLicense = "Sync License"
            case mechanicalLicense = "Mechanical License"
            case performanceLicense = "Performance License"
            case workForHire = "Work for Hire"
            case collaboration = "Collaboration Agreement"
            case managementDeal = "Management Deal"
            case bookingDeal = "Booking Agreement"
        }

        struct ContractParty: Identifiable, Codable {
            let id: UUID
            var name: String
            var role: PartyRole
            var email: String
            var address: String?

            enum PartyRole: String, Codable {
                case artist = "Artist"
                case publisher = "Publisher"
                case label = "Record Label"
                case distributor = "Distributor"
                case licensee = "Licensee"
                case licensor = "Licensor"
                case manager = "Manager"
                case agent = "Agent"
            }
        }

        struct ContractTerms: Codable {
            var duration: TimeInterval  // in seconds
            var territory: Territory
            var revenueSplit: [String: Double]  // Party name -> percentage
            var advancePayment: Double?
            var royaltyRate: Double?  // Percentage
            var exclusivity: Bool
            var termination Clause: String
            var disputeResolution: String
        }

        struct Signature: Identifiable, Codable {
            let id: UUID
            var partyName: String
            var signatureData: Data?  // Digital signature
            var ipAddress: String?
            var timestamp: Date
            var isDigitallySigned: Bool
        }

        enum ContractStatus: String, Codable {
            case draft = "Draft"
            case pendingSignatures = "Pending Signatures"
            case active = "Active"
            case expired = "Expired"
            case terminated = "Terminated"
        }
    }

    // MARK: - Initialization

    init() {
        print("⚖️ Rights Management System initialized")
    }

    // MARK: - Work Registration

    func registerWork(_ work: Work, with pro: PerformanceRightsOrganization) {
        print("   📄 Registering work with \(pro.rawValue)")
        print("      Title: \(work.title)")
        print("      Type: \(work.type.rawValue)")
        print("      Copyright: © \(work.copyrightYear) \(work.copyrightHolder)")

        if let iswc = work.iswc {
            print("      ISWC: \(iswc)")
        }

        registeredWorks.append(work)

        // In production: API integration with PROs
        // - GEMA API
        // - ASCAP/BMI/SESAC APIs
        // - CISAC network

        print("   ✅ Work registered successfully")
    }

    func generateISWC() -> String {
        // ISWC format: T-NNNNNNNNN-C
        // T = Letter prefix
        // N = 9 digits
        // C = Check digit

        let prefix = "T"
        let number = String(format: "%09d", Int.random(in: 1...999999999))
        let checkDigit = calculateISWCCheckDigit(number)

        return "\(prefix)-\(number)-\(checkDigit)"
    }

    private func calculateISWCCheckDigit(_ number: String) -> Int {
        // Modulus 10 check digit
        let digits = number.compactMap { Int(String($0)) }
        var sum = 0
        for (index, digit) in digits.enumerated() {
            sum += digit * (9 - index + 1)
        }
        return (10 - (sum % 10)) % 10
    }

    // MARK: - Rights Claiming (Automated)

    func submitAutomaticClaims(for work: Work, platforms: [RightsClaim.Platform]) {
        print("   🤖 Submitting automatic copyright claims")
        print("      Work: \(work.title)")
        print("      Platforms: \(platforms.map { $0.rawValue }.joined(separator: ", "))")

        for platform in platforms {
            let claim = RightsClaim(
                id: UUID(),
                work: work,
                platform: platform,
                claimType: .contentID,
                status: .pending,
                submissionDate: Date()
            )

            claims.append(claim)

            // In production: API integration
            switch platform {
            case .youtube:
                // YouTube Content ID API
                print("      → YouTube Content ID submitted")
            case .spotify:
                // Spotify for Artists API
                print("      → Spotify claim submitted")
            case .facebook, .instagram:
                // Meta Rights Manager
                print("      → Facebook Rights Manager submitted")
            default:
                print("      → \(platform.rawValue) claim submitted")
            }
        }

        print("   ✅ \(platforms.count) claims submitted")
    }

    func monitorClaims() -> [ClaimReport] {
        print("   📊 Monitoring copyright claims...")

        var reports: [ClaimReport] = []

        for claim in claims {
            let report = ClaimReport(
                work: claim.work.title,
                platform: claim.platform.rawValue,
                status: claim.status.rawValue,
                revenue: claim.revenue?.amount ?? 0
            )
            reports.append(report)
        }

        print("   Active claims: \(claims.count)")
        print("   Total revenue: \(reports.reduce(0) { $0 + $1.revenue }) EUR")

        return reports
    }

    struct ClaimReport {
        let work: String
        let platform: String
        let status: String
        let revenue: Double
    }

    // MARK: - Contract Generation

    func generateContract(type: Contract.ContractType, parties: [Contract.ContractParty], terms: Contract.ContractTerms) -> Contract {
        print("   📝 Generating contract: \(type.rawValue)")

        let contract = Contract(
            id: UUID(),
            type: type,
            parties: parties,
            terms: terms,
            signatures: [],
            status: .draft,
            creationDate: Date(),
            effectiveDate: Date()
        )

        contracts.append(contract)

        print("   ✅ Contract generated (ID: \(contract.id))")

        return contract
    }

    func signContract(contract: Contract, partyName: String, digitalSignature: Data) {
        print("   ✍️ Signing contract")
        print("      Party: \(partyName)")
        print("      Timestamp: \(Date())")

        // In production: Digital signature verification
        // - Public key cryptography
        // - Blockchain timestamp
        // - Legal compliance (eIDAS, ESIGN Act)

        print("   ✅ Contract signed")
    }

    // MARK: - Revenue Tracking

    func trackRevenue(for work: Work, source: RevenueSource, amount: Double, currency: String) {
        print("   💰 Revenue tracked:")
        print("      Work: \(work.title)")
        print("      Source: \(source.rawValue)")
        print("      Amount: \(amount) \(currency)")

        // Calculate splits based on revenue split percentages
        for (creator, percentage) in work.revenueSplit {
            let creatorShare = amount * percentage
            print("      → \(creator.name): \(creatorShare) \(currency) (\(Int(percentage * 100))%)")
        }

        // In production: Integrate with payment systems
        // - Stripe, PayPal
        // - Bank transfers
        // - Cryptocurrency
    }

    enum RevenueSource: String, Codable, CaseIterable {
        case streaming = "Streaming"
        case download = "Download"
        case physical = "Physical Sales"
        case performance = "Performance Royalties"
        case mechanical = "Mechanical Royalties"
        case sync = "Sync Licensing"
        case merch = "Merchandise"
        case youtube = "YouTube Ad Revenue"
    }

    // MARK: - Legal Protection

    func fileContentIDClaim(work: Work, platform: RightsClaim.Platform, infringingURL: URL) {
        print("   ⚠️ Filing Content ID claim")
        print("      Work: \(work.title)")
        print("      Platform: \(platform.rawValue)")
        print("      Infringing URL: \(infringingURL)")

        // In production: Automated DMCA/Content ID filing
        print("   ✅ Claim filed")
    }

    func fileDMCATakedown(work: Work, infringingURL: URL, infringerContact: String) {
        print("   🚨 Filing DMCA Takedown Notice")
        print("      Work: \(work.title)")
        print("      Infringing URL: \(infringingURL)")
        print("      Infringer: \(infringerContact)")

        // DMCA takedown notice template
        let notice = """
        DMCA TAKEDOWN NOTICE

        I am the copyright owner of the following work:
        Title: \(work.title)
        Copyright: © \(work.copyrightYear) \(work.copyrightHolder)

        Infringing Material:
        URL: \(infringingURL)

        I have a good faith belief that the use of the material in the manner complained of
        is not authorized by the copyright owner, its agent, or the law.

        I swear, under penalty of perjury, that the information in this notification is accurate
        and that I am the copyright owner or am authorized to act on behalf of the owner.

        Date: \(Date())
        """

        print("   DMCA Notice:\n\(notice)")
        print("   ✅ DMCA takedown notice generated")
    }

    // MARK: - Reporting

    func generateRightsReport(period: DateInterval) -> RightsReport {
        print("   📊 Generating rights report")
        print("      Period: \(period.start) - \(period.end)")

        let report = RightsReport(
            period: period,
            totalWorks: registeredWorks.count,
            activeContracts: contracts.filter { $0.status == .active }.count,
            activeClaims: claims.filter { $0.status == .pending || $0.status == .approved }.count,
            totalRevenue: 0.0 // Calculate from claims
        )

        print("   ✅ Report generated")

        return report
    }

    struct RightsReport {
        let period: DateInterval
        let totalWorks: Int
        let activeContracts: Int
        let activeClaims: Int
        let totalRevenue: Double
    }
}
