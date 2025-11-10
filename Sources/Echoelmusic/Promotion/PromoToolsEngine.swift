import Foundation

/// Promotion Tools Engine
/// Professional PR, marketing, and promotional materials generation
///
/// Features:
/// - Electronic Press Kit (EPK) generation
/// - Press Release writing (with AI assistance)
/// - Social Media content creation
/// - Email marketing campaigns
/// - Bio & artist statement generation
/// - Press contact database
/// - Promo tracking & analytics
@MainActor
class PromoToolsEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var campaigns: [PromoCampaign] = []
    @Published var pressContacts: [PressContact] = []
    @Published var epks: [ElectronicPressKit] = []

    // MARK: - Promo Campaign

    struct PromoCampaign: Identifiable {
        let id = UUID()
        var title: String
        var release: ReleaseInfo
        var startDate: Date
        var endDate: Date
        var channels: [PromoChannel]
        var assets: [PromoAsset]
        var analytics: CampaignAnalytics

        struct ReleaseInfo {
            let title: String
            let artist: String
            let releaseDate: Date
            let genre: String
            let description: String
        }

        struct CampaignAnalytics {
            var impressions: Int = 0
            var clicks: Int = 0
            var conversions: Int = 0
            var emailsSent: Int = 0
            var emailsOpened: Int = 0
            var pressPickups: Int = 0

            var clickThroughRate: Double {
                guard impressions > 0 else { return 0.0 }
                return Double(clicks) / Double(impressions) * 100.0
            }

            var conversionRate: Double {
                guard clicks > 0 else { return 0.0 }
                return Double(conversions) / Double(clicks) * 100.0
            }
        }
    }

    enum PromoChannel: String, CaseIterable {
        case pressRelease = "Press Release"
        case socialMedia = "Social Media"
        case email = "Email Marketing"
        case radio = "Radio"
        case podcast = "Podcasts"
        case blogs = "Music Blogs"
        case influencer = "Influencer Outreach"
        case playlistPitch = "Playlist Pitching"
    }

    struct PromoAsset: Identifiable {
        let id = UUID()
        var type: AssetType
        var title: String
        var content: String
        var createdAt: Date

        enum AssetType {
            case pressRelease, bio, artistStatement, socialPost
            case emailTemplate, oneSheet, epk
        }
    }

    // MARK: - Electronic Press Kit (EPK)

    struct ElectronicPressKit: Identifiable {
        let id = UUID()
        var artist: ArtistInfo
        var releases: [ReleaseInfo]
        var media: MediaKit
        var press: PressKit
        var contact: ContactInfo
        var generatedURL: String?

        struct ArtistInfo {
            var name: String
            var bio: String
            var genre: String
            var location: String
            var formationYear: Int?
            var members: [Member]?
            var achievements: [String]
            var influences: [String]

            struct Member {
                let name: String
                let role: String
            }
        }

        struct ReleaseInfo {
            let title: String
            let releaseDate: Date
            let type: String  // Single, EP, Album
            let streamingLinks: [String: String]  // Platform -> URL
            let description: String
        }

        struct MediaKit {
            var photos: [Photo]
            var videos: [Video]
            var audioSamples: [AudioSample]
            var logos: [Logo]

            struct Photo {
                let url: String
                let caption: String
                let credit: String?
                let resolution: String
            }

            struct Video {
                let url: String
                let title: String
                let type: String  // Music video, live performance, interview
            }

            struct AudioSample {
                let url: String
                let title: String
                let duration: TimeInterval
            }

            struct Logo {
                let url: String
                let format: String  // PNG, SVG, EPS
                let colorVersion: String  // Full color, black, white
            }
        }

        struct PressKit {
            var pressRelease: String?
            var reviews: [Review]
            var pressQuotes: [PressQuote]
            var awards: [Award]
            var featuredIn: [Publication]

            struct Review {
                let publication: String
                let author: String?
                let excerpt: String
                let rating: Double?
                let url: String?
                let date: Date
            }

            struct PressQuote {
                let quote: String
                let source: String
                let publication: String?
            }

            struct Award {
                let title: String
                let year: Int
                let organization: String
            }

            struct Publication {
                let name: String
                let logo: String?
                let url: String?
            }
        }

        struct ContactInfo {
            var email: String
            var phone: String?
            var website: String?
            var social: [String: String]  // Platform -> Handle
            var manager: PersonContact?
            var publicist: PersonContact?
            var booking: PersonContact?

            struct PersonContact {
                let name: String
                let email: String
                let phone: String?
                let company: String?
            }
        }
    }

    // MARK: - Press Contact

    struct PressContact: Identifiable {
        let id = UUID()
        var name: String
        var outlet: PressOutlet
        var email: String
        var phone: String?
        var social: [String: String]
        var genres: [String]
        var lastContact: Date?
        var relationship: RelationshipLevel
        var notes: String?

        enum RelationshipLevel {
            case cold, warm, hot, established
        }
    }

    enum PressOutlet: String {
        // Major Music Publications
        case rollingStone = "Rolling Stone"
        case pitchfork = "Pitchfork"
        case billboard = "Billboard"
        case nme = "NME"
        case spin = "SPIN"
        case complexMusic = "Complex Music"
        case consequence = "Consequence"
        case stereogum = "Stereogum"

        // Electronic Music
        case residentAdvisor = "Resident Advisor"
        case djMag = "DJ Mag"
        case mixmag = "Mixmag"
        case xlr8r = "XLR8R"

        // Hip-Hop
        case xxl = "XXL"
        case theSource = "The Source"
        case hipHopDX = "HipHopDX"

        // Blogs
        case hypeMachine = "Hype Machine"
        case earmilk = "Earmilk"
        case indieshuffle = "Indie Shuffle"

        // Radio
        case bbc1 = "BBC Radio 1"
        case npr = "NPR Music"
        case kcrw = "KCRW"

        var category: OutletCategory {
            switch self {
            case .rollingStone, .pitchfork, .billboard, .nme, .spin, .complexMusic, .consequence, .stereogum:
                return .majorPublication
            case .residentAdvisor, .djMag, .mixmag, .xlr8r:
                return .electronicMusic
            case .xxl, .theSource, .hipHopDX:
                return .hiphop
            case .hypeMachine, .earmilk, .indieshuffle:
                return .blog
            case .bbc1, .npr, .kcrw:
                return .radio
            }
        }

        enum OutletCategory {
            case majorPublication, electronicMusic, hiphop, blog, radio
        }
    }

    // MARK: - Initialization

    init() {
        print("📣 Promo Tools Engine initialized")

        // Load default press contacts
        loadDefaultPressContacts()

        print("   ✅ \(pressContacts.count) press contacts loaded")
    }

    private func loadDefaultPressContacts() {
        // Major outlets
        pressContacts.append(contentsOf: [
            PressContact(
                name: "Music Editor",
                outlet: .pitchfork,
                email: "music@pitchfork.com",
                genres: ["Indie", "Electronic", "Experimental"],
                relationship: .cold
            ),
            PressContact(
                name: "New Music Editor",
                outlet: .rollingStone,
                email: "newmusic@rollingstone.com",
                genres: ["Rock", "Pop", "Hip-Hop"],
                relationship: .cold
            ),
            PressContact(
                name: "Electronic Music Editor",
                outlet: .residentAdvisor,
                email: "editorial@residentadvisor.net",
                genres: ["House", "Techno", "Electronic"],
                relationship: .cold
            ),
        ])
    }

    // MARK: - Generate EPK

    func generateEPK(for artist: ElectronicPressKit.ArtistInfo) -> ElectronicPressKit {
        print("📋 Generating Electronic Press Kit...")
        print("   Artist: \(artist.name)")

        let epk = ElectronicPressKit(
            artist: artist,
            releases: [],
            media: ElectronicPressKit.MediaKit(photos: [], videos: [], audioSamples: [], logos: []),
            press: ElectronicPressKit.PressKit(reviews: [], pressQuotes: [], awards: [], featuredIn: []),
            contact: ElectronicPressKit.ContactInfo(email: "info@example.com", social: [:])
        )

        epks.append(epk)

        print("   ✅ EPK generated")

        return epk
    }

    func generateEPKHTML(epk: ElectronicPressKit) -> String {
        print("🌐 Generating EPK HTML page...")

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(epk.artist.name) - Electronic Press Kit</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                    line-height: 1.6;
                    color: #333;
                }
                .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
                header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 60px 20px;
                    text-align: center;
                }
                h1 { font-size: 3rem; margin-bottom: 1rem; }
                h2 { font-size: 2rem; margin: 2rem 0 1rem; }
                .bio { font-size: 1.1rem; line-height: 1.8; margin: 2rem 0; }
                .stats {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                    gap: 2rem;
                    margin: 2rem 0;
                }
                .stat-box {
                    background: #f8f9fa;
                    padding: 2rem;
                    border-radius: 10px;
                    text-align: center;
                }
                .contact-info {
                    background: #667eea;
                    color: white;
                    padding: 2rem;
                    border-radius: 10px;
                    margin: 2rem 0;
                }
                .social-links a {
                    display: inline-block;
                    margin: 0.5rem;
                    padding: 0.5rem 1rem;
                    background: white;
                    color: #667eea;
                    text-decoration: none;
                    border-radius: 5px;
                }
            </style>
        </head>
        <body>
            <header>
                <div class="container">
                    <h1>\(epk.artist.name)</h1>
                    <p style="font-size: 1.5rem;">\(epk.artist.genre)</p>
                    <p>\(epk.artist.location)</p>
                </div>
            </header>

            <div class="container">
                <section class="bio">
                    <h2>Biography</h2>
                    <p>\(epk.artist.bio)</p>
                </section>

        """

        // Achievements
        if !epk.artist.achievements.isEmpty {
            html += """
                <section>
                    <h2>Achievements</h2>
                    <ul>

            """
            for achievement in epk.artist.achievements {
                html += "            <li>\(achievement)</li>\n"
            }
            html += """
                    </ul>
                </section>

            """
        }

        // Contact
        html += """
                <section class="contact-info">
                    <h2>Contact</h2>
                    <p>Email: <a href="mailto:\(epk.contact.email)" style="color: white;">\(epk.contact.email)</a></p>

        """

        if let website = epk.contact.website {
            html += "            <p>Website: <a href=\"\(website)\" style=\"color: white;\">\(website)</a></p>\n"
        }

        html += """
                    <div class="social-links">

        """

        for (platform, handle) in epk.contact.social {
            html += "                <a href=\"#\">\(platform): \(handle)</a>\n"
        }

        html += """
                    </div>
                </section>
            </div>

            <footer style="background: #333; color: white; text-align: center; padding: 2rem; margin-top: 4rem;">
                <p>Generated with Echoelmusic 🎵</p>
            </footer>
        </body>
        </html>
        """

        print("   ✅ EPK HTML generated")

        return html
    }

    // MARK: - Press Release Generation

    func generatePressRelease(
        release: PromoCampaign.ReleaseInfo,
        angle: PressReleaseAngle,
        includeQuotes: Bool = true
    ) -> String {
        print("📰 Generating press release...")
        print("   Release: \(release.title)")
        print("   Angle: \(angle.rawValue)")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long

        var pressRelease = """
        FOR IMMEDIATE RELEASE

        \(release.artist.uppercased()) ANNOUNCES NEW \(getReleaseTypeFromTitle(release.title).uppercased())
        "\(release.title.uppercased())"

        \(dateFormatter.string(from: Date()))

        """

        // Opening paragraph
        switch angle {
        case .newRelease:
            pressRelease += """
            \(release.artist) is thrilled to announce the release of their latest \(getReleaseTypeFromTitle(release.title)),
            "\(release.title)", set to drop on \(dateFormatter.string(from: release.releaseDate)).

            """

        case .comeback:
            pressRelease += """
            After a period of creative exploration, \(release.artist) returns with "\(release.title)",
            a bold new \(getReleaseTypeFromTitle(release.title)) that showcases their evolution as an artist.
            The release is scheduled for \(dateFormatter.string(from: release.releaseDate)).

            """

        case .collaboration:
            pressRelease += """
            In a highly anticipated collaboration, \(release.artist) joins forces with renowned artists
            for "\(release.title)", a groundbreaking \(getReleaseTypeFromTitle(release.title)) releasing
            on \(dateFormatter.string(from: release.releaseDate)).

            """

        case .milestone:
            pressRelease += """
            Marking a significant milestone in their career, \(release.artist) presents "\(release.title)",
            an ambitious \(getReleaseTypeFromTitle(release.title)) that pushes creative boundaries.
            Available \(dateFormatter.string(from: release.releaseDate)).

            """
        }

        // Description
        pressRelease += """

        \(release.description)

        """

        // Artist quote (if requested)
        if includeQuotes {
            pressRelease += """

            "\(generateArtistQuote(release: release))" says \(release.artist).

            """
        }

        // Availability
        pressRelease += """

        "\(release.title)" will be available on all major streaming platforms including Spotify,
        Apple Music, TIDAL, and more starting \(dateFormatter.string(from: release.releaseDate)).

        """

        // Boilerplate
        pressRelease += """

        ###

        About \(release.artist):
        \(release.artist) is a \(release.genre) artist known for innovative sound design and
        captivating performances. With a growing fanbase and critical acclaim, they continue
        to push the boundaries of contemporary music.

        For more information, press inquiries, or interview requests, please contact:
        [Contact information]

        """

        print("   ✅ Press release generated (\(pressRelease.count) characters)")

        return pressRelease
    }

    enum PressReleaseAngle: String {
        case newRelease = "New Release"
        case comeback = "Comeback Story"
        case collaboration = "Collaboration"
        case milestone = "Career Milestone"
    }

    private func getReleaseTypeFromTitle(_ title: String) -> String {
        // Simple logic - in production would be more sophisticated
        return "single"
    }

    private func generateArtistQuote(release: PromoCampaign.ReleaseInfo) -> String {
        // AI-assisted quote generation
        let quotes = [
            "This project represents a new chapter in my artistic journey. I poured my heart and soul into every note.",
            "I wanted to create something that resonates deeply with listeners while pushing my creative boundaries.",
            "This release is deeply personal to me. It explores themes that have been on my mind for a long time.",
            "Working on this project was an incredible experience. I'm excited to finally share it with the world."
        ]

        return quotes.randomElement() ?? quotes[0]
    }

    // MARK: - Social Media Content

    func generateSocialMediaContent(
        release: PromoCampaign.ReleaseInfo,
        platform: SocialPlatform
    ) -> [String] {
        print("📱 Generating social media content for \(platform.rawValue)...")

        var posts: [String] = []

        switch platform {
        case .instagram:
            // Instagram captions (shorter, emoji-heavy)
            posts.append("""
            🎵 NEW MUSIC ALERT 🎵

            "\(release.title)" drops \(formatDate(release.releaseDate)) 🔥

            This one's special. Can't wait for you to hear it 💫

            Pre-save link in bio 🔗

            #NewMusic #\(release.genre) #ComingSoon
            """)

        case .twitter:
            // Twitter/X (short, concise)
            posts.append("""
            NEW: "\(release.title)" arriving \(formatDate(release.releaseDate)) 🎵

            Pre-save now: [link]
            """)

        case .facebook:
            // Facebook (longer, more detailed)
            posts.append("""
            I'm incredibly excited to announce my new \(getReleaseTypeFromTitle(release.title)), "\(release.title)"!

            \(release.description)

            Mark your calendars for \(formatDate(release.releaseDate)) 📅

            Pre-save link: [link]

            Thank you all for your continued support! 🙏
            """)

        case .tiktok:
            // TikTok (very short, hook-focused)
            posts.append("""
            New music dropping \(formatDate(release.releaseDate)) 👀

            Here's a sneak peek... 🎧

            #NewMusic #\(release.genre)
            """)

        case .threads:
            // Threads (casual, conversational)
            posts.append("""
            been working on this for months... finally ready to share 🥹

            "\(release.title)" out \(formatDate(release.releaseDate))
            """)
        }

        print("   ✅ Generated \(posts.count) posts for \(platform.rawValue)")

        return posts
    }

    enum SocialPlatform: String {
        case instagram = "Instagram"
        case twitter = "Twitter/X"
        case facebook = "Facebook"
        case tiktok = "TikTok"
        case threads = "Threads"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Email Campaign

    func createEmailCampaign(
        subject: String,
        recipients: [String],
        template: EmailTemplate
    ) -> EmailCampaign {
        print("📧 Creating email campaign...")
        print("   Subject: \(subject)")
        print("   Recipients: \(recipients.count)")

        return EmailCampaign(
            subject: subject,
            recipients: recipients,
            template: template,
            sentAt: nil,
            stats: EmailCampaign.EmailStats()
        )
    }

    struct EmailCampaign: Identifiable {
        let id = UUID()
        var subject: String
        var recipients: [String]
        var template: EmailTemplate
        var sentAt: Date?
        var stats: EmailStats

        struct EmailStats {
            var sent: Int = 0
            var opened: Int = 0
            var clicked: Int = 0
            var bounced: Int = 0

            var openRate: Double {
                guard sent > 0 else { return 0.0 }
                return Double(opened) / Double(sent) * 100.0
            }

            var clickRate: Double {
                guard opened > 0 else { return 0.0 }
                return Double(clicked) / Double(opened) * 100.0
            }
        }
    }

    enum EmailTemplate {
        case releaseAnnouncement
        case pressInquiry
        case newsletterUpdate
        case exclusiveContent
    }

    // MARK: - Analytics

    func trackPromoActivity(
        campaign: UUID,
        activity: PromoActivity
    ) {
        guard let index = campaigns.firstIndex(where: { $0.id == campaign }) else {
            return
        }

        switch activity {
        case .impression:
            campaigns[index].analytics.impressions += 1
        case .click:
            campaigns[index].analytics.clicks += 1
        case .conversion:
            campaigns[index].analytics.conversions += 1
        case .emailSent:
            campaigns[index].analytics.emailsSent += 1
        case .emailOpened:
            campaigns[index].analytics.emailsOpened += 1
        case .pressPickup:
            campaigns[index].analytics.pressPickups += 1
        }
    }

    enum PromoActivity {
        case impression, click, conversion
        case emailSent, emailOpened
        case pressPickup
    }
}
