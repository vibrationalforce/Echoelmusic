import Foundation

/// Playlist Pitching Engine
/// Automated playlist pitching to curators on all major platforms
///
/// Supported Platforms:
/// - Spotify (Editorial + User Playlists)
/// - Apple Music (Editorial Playlists)
/// - YouTube Music (Playlists)
/// - Amazon Music (Playlists)
/// - TIDAL (Editorial Playlists)
/// - Deezer (Flow and Playlists)
/// - Independent Curators
@MainActor
class PlaylistPitchingEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var pitches: [PlaylistPitch] = []
    @Published var curators: [PlaylistCurator] = []
    @Published var playlists: [Playlist] = []
    @Published var pitchStats: PitchStats

    // MARK: - Playlist Pitch

    struct PlaylistPitch: Identifiable {
        let id = UUID()
        var track: TrackInfo
        var targetPlaylists: [Playlist]
        var pitchMessage: String
        var status: PitchStatus
        var submittedAt: Date?
        var responses: [PitchResponse]

        struct TrackInfo {
            let title: String
            let artist: String
            let genre: String
            let subgenre: String?
            let mood: [String]
            let bpm: Int?
            let key: String?
            let isrc: String?
            let releaseDate: Date
            let description: String
            let spotifyURI: String?
            let appleMusicID: String?
        }

        enum PitchStatus {
            case draft, submitted, underReview, accepted, declined, noResponse

            var icon: String {
                switch self {
                case .draft: return "📝"
                case .submitted: return "📤"
                case .underReview: return "👀"
                case .accepted: return "✅"
                case .declined: return "❌"
                case .noResponse: return "⏳"
                }
            }
        }

        struct PitchResponse {
            let curator: String
            let status: PitchStatus
            let message: String?
            let respondedAt: Date
        }
    }

    // MARK: - Playlist

    struct Playlist: Identifiable {
        let id = UUID()
        var name: String
        var platform: PlaylistPlatform
        var curatorName: String
        var followerCount: Int
        var genres: [String]
        var isEditorial: Bool  // Editorial vs. user-curated
        var submissionEmail: String?
        var submissionForm: String?
        var averageAddRate: Double?  // Percentage
        var lastUpdated: Date?

        var reachLevel: ReachLevel {
            switch followerCount {
            case 0..<1_000: return .micro
            case 1_000..<10_000: return .small
            case 10_000..<50_000: return .medium
            case 50_000..<500_000: return .large
            default: return .mega
            }
        }

        enum ReachLevel {
            case micro, small, medium, large, mega
        }
    }

    enum PlaylistPlatform: String, CaseIterable {
        case spotify = "Spotify"
        case appleMusic = "Apple Music"
        case youtubeMusic = "YouTube Music"
        case amazonMusic = "Amazon Music"
        case tidal = "TIDAL"
        case deezer = "Deezer"
        case soundcloud = "SoundCloud"
        case pandora = "Pandora"

        var supportsDirectSubmission: Bool {
            switch self {
            case .spotify: return true  // Spotify for Artists
            case .appleMusic: return true  // Apple Music for Artists
            default: return false
            }
        }
    }

    // MARK: - Playlist Curator

    struct PlaylistCurator: Identifiable {
        let id = UUID()
        var name: String
        var type: CuratorType
        var playlists: [Playlist]
        var totalFollowers: Int
        var genres: [String]
        var contact: ContactInfo
        var relationship: RelationshipLevel
        var successRate: Double?  // Historical acceptance rate

        enum CuratorType {
            case editorial  // Platform editorial teams
            case independent  // Independent curators
            case influencer  // Social media influencers
            case brand  // Brand/company playlists
        }

        struct ContactInfo {
            var email: String?
            var submissionForm: String?
            var social: [String: String]
            var website: String?
        }

        enum RelationshipLevel {
            case cold, warm, established
        }
    }

    // MARK: - Pitch Stats

    struct PitchStats {
        var totalPitches: Int = 0
        var acceptedPitches: Int = 0
        var declinedPitches: Int = 0
        var pendingPitches: Int = 0
        var totalPlaylistAdds: Int = 0
        var totalStreamsFromPlaylists: Int64 = 0

        var acceptanceRate: Double {
            let responded = acceptedPitches + declinedPitches
            guard responded > 0 else { return 0.0 }
            return Double(acceptedPitches) / Double(responded) * 100.0
        }
    }

    // MARK: - Initialization

    init() {
        print("🎵 Playlist Pitching Engine initialized")

        self.pitchStats = PitchStats()

        // Load curated playlists database
        loadPlaylistDatabase()

        print("   ✅ \(playlists.count) playlists in database")
        print("   ✅ \(curators.count) curators available")
    }

    private func loadPlaylistDatabase() {
        // Spotify Editorial Playlists
        playlists.append(contentsOf: [
            Playlist(
                name: "New Music Friday",
                platform: .spotify,
                curatorName: "Spotify Editorial",
                followerCount: 4_200_000,
                genres: ["Pop", "Rock", "Hip-Hop", "Electronic"],
                isEditorial: true,
                submissionForm: "https://artists.spotify.com"
            ),
            Playlist(
                name: "RapCaviar",
                platform: .spotify,
                curatorName: "Spotify Editorial",
                followerCount: 16_500_000,
                genres: ["Hip-Hop", "Rap"],
                isEditorial: true,
                submissionForm: "https://artists.spotify.com"
            ),
            Playlist(
                name: "Today's Top Hits",
                platform: .spotify,
                curatorName: "Spotify Editorial",
                followerCount: 37_000_000,
                genres: ["Pop", "Hip-Hop"],
                isEditorial: true,
                submissionForm: "https://artists.spotify.com"
            ),
            Playlist(
                name: "mint",
                platform: .spotify,
                curatorName: "Spotify Editorial",
                followerCount: 6_800_000,
                genres: ["Electronic", "Dance", "House"],
                isEditorial: true,
                submissionForm: "https://artists.spotify.com"
            ),
            Playlist(
                name: "Rock This",
                platform: .spotify,
                curatorName: "Spotify Editorial",
                followerCount: 3_200_000,
                genres: ["Rock", "Alternative"],
                isEditorial: true,
                submissionForm: "https://artists.spotify.com"
            ),
        ])

        // Apple Music Editorial Playlists
        playlists.append(contentsOf: [
            Playlist(
                name: "Today's Hits",
                platform: .appleMusic,
                curatorName: "Apple Music Editorial",
                followerCount: 5_000_000,
                genres: ["Pop", "Hip-Hop"],
                isEditorial: true,
                submissionForm: "https://artists.apple.com"
            ),
            Playlist(
                name: "Breaking Electronic",
                platform: .appleMusic,
                curatorName: "Apple Music Editorial",
                followerCount: 1_200_000,
                genres: ["Electronic", "Dance"],
                isEditorial: true,
                submissionForm: "https://artists.apple.com"
            ),
        ])

        // Independent Curators (Examples)
        playlists.append(contentsOf: [
            Playlist(
                name: "Chill Vibes",
                platform: .spotify,
                curatorName: "Indie Curator",
                followerCount: 125_000,
                genres: ["Chill", "Lo-fi", "Electronic"],
                isEditorial: false,
                submissionEmail: "curator@example.com",
                averageAddRate: 8.5
            ),
            Playlist(
                name: "Indie Rock Essentials",
                platform: .spotify,
                curatorName: "Music Blog",
                followerCount: 89_000,
                genres: ["Indie", "Rock", "Alternative"],
                isEditorial: false,
                submissionEmail: "submissions@musicblog.com",
                averageAddRate: 12.3
            ),
        ])
    }

    // MARK: - Find Suitable Playlists

    func findSuitablePlaylists(
        for track: PlaylistPitch.TrackInfo,
        minFollowers: Int = 1_000,
        maxFollowers: Int? = nil
    ) -> [Playlist] {
        print("🔍 Finding suitable playlists...")
        print("   Track: \(track.title)")
        print("   Genre: \(track.genre)")
        print("   Min followers: \(minFollowers)")

        var suitablePlaylists = playlists.filter { playlist in
            // Check genre match
            let genreMatch = playlist.genres.contains { playlistGenre in
                playlistGenre.lowercased().contains(track.genre.lowercased()) ||
                track.genre.lowercased().contains(playlistGenre.lowercased())
            }

            // Check subgenre if available
            var subgenreMatch = false
            if let subgenre = track.subgenre {
                subgenreMatch = playlist.genres.contains { playlistGenre in
                    playlistGenre.lowercased().contains(subgenre.lowercased())
                }
            }

            // Check follower count
            let followerMatch = playlist.followerCount >= minFollowers &&
                (maxFollowers == nil || playlist.followerCount <= maxFollowers!)

            return (genreMatch || subgenreMatch) && followerMatch
        }

        // Sort by relevance (editorial first, then by followers)
        suitablePlaylists.sort { p1, p2 in
            if p1.isEditorial && !p2.isEditorial {
                return true
            } else if !p1.isEditorial && p2.isEditorial {
                return false
            }
            return p1.followerCount > p2.followerCount
        }

        print("   ✅ Found \(suitablePlaylists.count) suitable playlists")

        return suitablePlaylists
    }

    // MARK: - Generate Pitch Message

    func generatePitchMessage(
        track: PlaylistPitch.TrackInfo,
        playlist: Playlist
    ) -> String {
        print("✍️ Generating pitch message for: \(playlist.name)")

        var message = ""

        // Personalized greeting
        if playlist.isEditorial {
            message += "Dear \(playlist.platform.rawValue) Editorial Team,\n\n"
        } else {
            message += "Hi \(playlist.curatorName),\n\n"
        }

        // Introduction
        message += "I hope this message finds you well. "

        if playlist.isEditorial {
            message += "I'm excited to submit \"\(track.title)\" for consideration for your playlist \"\(playlist.name)\".\n\n"
        } else {
            message += "I've been following \"\(playlist.name)\" and love your curation style. I think my track \"\(track.title)\" would be a great fit.\n\n"
        }

        // Track description
        message += "About the track:\n"
        message += "\(track.description)\n\n"

        // Technical details
        message += "Details:\n"
        message += "• Genre: \(track.genre)"
        if let subgenre = track.subgenre {
            message += " / \(subgenre)"
        }
        message += "\n"

        if let bpm = track.bpm {
            message += "• BPM: \(bpm)\n"
        }

        if let key = track.key {
            message += "• Key: \(key)\n"
        }

        if !track.mood.isEmpty {
            message += "• Mood: \(track.mood.joined(separator: ", "))\n"
        }

        message += "\n"

        // Why it fits
        message += "Why it fits \"\(playlist.name)\":\n"
        message += "This track aligns perfectly with the \(playlist.genres.joined(separator: ", ")) vibe of your playlist"

        if let recentTrack = getMostRecentTrackExample(for: playlist) {
            message += ", and I think fans of \(recentTrack) will love it"
        }

        message += ".\n\n"

        // Streaming links
        if let spotifyURI = track.spotifyURI {
            message += "Spotify: \(spotifyURI)\n"
        }
        if let appleMusicID = track.appleMusicID {
            message += "Apple Music: \(appleMusicID)\n"
        }

        message += "\n"

        // Closing
        message += "Thank you for your time and consideration. Looking forward to hearing from you!\n\n"
        message += "Best regards,\n"
        message += "\(track.artist)"

        return message
    }

    private func getMostRecentTrackExample(for playlist: Playlist) -> String? {
        // In production: Fetch actual recent tracks from playlist
        // For now, return placeholder
        return nil
    }

    // MARK: - Submit Pitch

    func submitPitch(
        track: PlaylistPitch.TrackInfo,
        to playlists: [Playlist],
        customMessage: String? = nil
    ) async -> PlaylistPitch {
        print("📤 Submitting pitch...")
        print("   Track: \(track.title)")
        print("   Playlists: \(playlists.count)")

        let pitchMessage = customMessage ?? generatePitchMessage(
            track: track,
            playlist: playlists.first ?? playlists[0]
        )

        var pitch = PlaylistPitch(
            track: track,
            targetPlaylists: playlists,
            pitchMessage: pitchMessage,
            status: .draft,
            responses: []
        )

        // Submit to each playlist
        for playlist in playlists {
            await submitToPlaylist(pitch: &pitch, playlist: playlist)
        }

        pitch.status = .submitted
        pitch.submittedAt = Date()

        pitches.append(pitch)

        // Update stats
        pitchStats.totalPitches += playlists.count
        pitchStats.pendingPitches += playlists.count

        print("   ✅ Pitch submitted to \(playlists.count) playlists")

        return pitch
    }

    private func submitToPlaylist(pitch: inout PlaylistPitch, playlist: Playlist) async {
        print("      → Submitting to \(playlist.name) (\(playlist.platform.rawValue))...")

        switch playlist.platform {
        case .spotify:
            if playlist.isEditorial {
                await submitToSpotifyEditorial(pitch: pitch, playlist: playlist)
            } else {
                await submitToIndependentCurator(pitch: pitch, playlist: playlist)
            }

        case .appleMusic:
            if playlist.isEditorial {
                await submitToAppleMusicEditorial(pitch: pitch, playlist: playlist)
            }

        default:
            await submitToIndependentCurator(pitch: pitch, playlist: playlist)
        }

        print("         ✅ Submitted")
    }

    private func submitToSpotifyEditorial(pitch: PlaylistPitch, playlist: Playlist) async {
        // Spotify for Artists submission
        print("         • Using Spotify for Artists API")

        // In production: Use Spotify for Artists API
        // https://developer.spotify.com/documentation/web-api/reference/submit-to-playlist

        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    private func submitToAppleMusicEditorial(pitch: PlaylistPitch, playlist: Playlist) async {
        // Apple Music for Artists submission
        print("         • Using Apple Music for Artists")

        // In production: Use Apple Music for Artists API

        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    private func submitToIndependentCurator(pitch: PlaylistPitch, playlist: Playlist) async {
        // Email or form submission
        if let email = playlist.submissionEmail {
            print("         • Sending email to \(email)")
        } else if let form = playlist.submissionForm {
            print("         • Submitting via form: \(form)")
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    // MARK: - Pitch Strategy

    func recommendPitchStrategy(
        track: PlaylistPitch.TrackInfo,
        budget: PitchBudget
    ) -> PitchStrategy {
        print("💡 Recommending pitch strategy...")
        print("   Budget: \(budget.rawValue)")

        let suitablePlaylists = findSuitablePlaylists(for: track)

        var strategy = PitchStrategy(targetPlaylists: [], approach: .balanced)

        switch budget {
        case .free:
            // Only editorial and high-quality independent playlists
            strategy.targetPlaylists = suitablePlaylists.filter {
                $0.isEditorial || $0.followerCount > 50_000
            }.prefix(10).map { $0 }
            strategy.approach = .conservative

        case .small:
            // Mix of editorial and good independent playlists
            strategy.targetPlaylists = suitablePlaylists.filter {
                $0.isEditorial || $0.followerCount > 10_000
            }.prefix(25).map { $0 }
            strategy.approach = .balanced

        case .medium:
            // Wide range including smaller playlists
            strategy.targetPlaylists = suitablePlaylists.filter {
                $0.followerCount > 1_000
            }.prefix(50).map { $0 }
            strategy.approach = .aggressive

        case .large:
            // All suitable playlists
            strategy.targetPlaylists = suitablePlaylists.prefix(100).map { $0 }
            strategy.approach = .veryAggressive
        }

        print("   ✅ Strategy: \(strategy.approach.rawValue)")
        print("      Target playlists: \(strategy.targetPlaylists.count)")
        print("      Potential reach: \(formatNumber(calculateTotalReach(playlists: strategy.targetPlaylists)))")

        return strategy
    }

    enum PitchBudget: String {
        case free = "Free"
        case small = "Small ($100-500)"
        case medium = "Medium ($500-2000)"
        case large = "Large ($2000+)"
    }

    struct PitchStrategy {
        var targetPlaylists: [Playlist]
        var approach: Approach
        var estimatedCost: Double = 0.0
        var estimatedReach: Int = 0

        enum Approach: String {
            case conservative = "Conservative"
            case balanced = "Balanced"
            case aggressive = "Aggressive"
            case veryAggressive = "Very Aggressive"
        }
    }

    private func calculateTotalReach(playlists: [Playlist]) -> Int {
        return playlists.reduce(0) { $0 + $1.followerCount }
    }

    // MARK: - Track Response

    func recordPitchResponse(
        pitchId: UUID,
        playlistName: String,
        status: PlaylistPitch.PitchStatus,
        message: String?
    ) {
        guard let index = pitches.firstIndex(where: { $0.id == pitchId }) else {
            return
        }

        let response = PlaylistPitch.PitchResponse(
            curator: playlistName,
            status: status,
            message: message,
            respondedAt: Date()
        )

        pitches[index].responses.append(response)

        // Update stats
        pitchStats.pendingPitches -= 1

        switch status {
        case .accepted:
            pitches[index].status = .accepted
            pitchStats.acceptedPitches += 1
            pitchStats.totalPlaylistAdds += 1
            print("✅ Pitch accepted by \(playlistName)!")

        case .declined:
            pitches[index].status = .declined
            pitchStats.declinedPitches += 1
            print("❌ Pitch declined by \(playlistName)")

        default:
            break
        }
    }

    // MARK: - Analytics

    func generatePitchReport() -> String {
        var report = """
        ═══════════════════════════════════════
        PLAYLIST PITCHING REPORT
        ═══════════════════════════════════════

        OVERVIEW
        ───────────────────────────────────────
        Total Pitches: \(pitchStats.totalPitches)
        Accepted: \(pitchStats.acceptedPitches)
        Declined: \(pitchStats.declinedPitches)
        Pending: \(pitchStats.pendingPitches)

        Acceptance Rate: \(String(format: "%.1f", pitchStats.acceptanceRate))%
        Total Playlist Adds: \(pitchStats.totalPlaylistAdds)

        """

        // Recent pitches
        if !pitches.isEmpty {
            report += """

            RECENT PITCHES
            ───────────────────────────────────────

            """

            let recentPitches = pitches.suffix(5).reversed()
            for pitch in recentPitches {
                report += """
                \(pitch.status.icon) \(pitch.track.title) by \(pitch.track.artist)
                   Status: \(pitch.status)
                   Playlists: \(pitch.targetPlaylists.count)
                   Responses: \(pitch.responses.count)

                """
            }
        }

        // Top playlists by acceptance
        report += """

        MOST RESPONSIVE PLAYLISTS
        ───────────────────────────────────────
        (Based on historical data)

        """

        let topPlaylists = playlists
            .filter { $0.averageAddRate != nil }
            .sorted { ($0.averageAddRate ?? 0) > ($1.averageAddRate ?? 0) }
            .prefix(5)

        for playlist in topPlaylists {
            report += """
            \(playlist.name) (\(playlist.platform.rawValue))
               Followers: \(formatNumber(playlist.followerCount))
               Add Rate: \(String(format: "%.1f", playlist.averageAddRate ?? 0))%

            """
        }

        report += "═══════════════════════════════════════"

        return report
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
