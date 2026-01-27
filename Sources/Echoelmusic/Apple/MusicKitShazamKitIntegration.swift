//
//  MusicKitShazamKitIntegration.swift
//  Echoelmusic
//
//  MusicKit & ShazamKit Creative Integration - A+ Level
//  Bio-reactive music discovery and audio recognition
//
//  Created: 2026-01-27
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

#if canImport(MusicKit)
import MusicKit
#endif

#if canImport(ShazamKit)
import ShazamKit
#endif

// MARK: - Music Service Protocol

/// Protocol for music service integration
public protocol MusicServiceProtocol {
    func requestAuthorization() async -> Bool
    func searchCatalog(query: String) async throws -> [EchoelTrack]
    func getCurrentlyPlaying() async -> EchoelTrack?
    func getRecommendations(basedOn coherence: Float) async throws -> [EchoelTrack]
}

// MARK: - Echoelmusic Track Model

/// Unified track model for all music services
public struct EchoelTrack: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let artistName: String
    public let albumTitle: String?
    public let artworkURL: URL?
    public let duration: TimeInterval
    public let genres: [String]
    public let isExplicit: Bool

    // Audio analysis (from MIR engine or Shazam)
    public var detectedKey: String?
    public var detectedTempo: Double?
    public var energy: Float?
    public var valence: Float?  // 0=sad, 1=happy

    // Bio-reactive mapping
    public var recommendedCoherenceRange: ClosedRange<Float> {
        // Map energy/valence to coherence
        let baseCoherence = (energy ?? 0.5) * 0.5 + (valence ?? 0.5) * 0.5
        let minCoherence = max(0, baseCoherence - 0.2)
        let maxCoherence = min(1, baseCoherence + 0.2)
        return minCoherence...maxCoherence
    }

    public var suggestedPreset: String {
        let avgEnergy = energy ?? 0.5
        switch avgEnergy {
        case 0..<0.3: return "DeepMeditation"
        case 0.3..<0.5: return "AmbientDrone"
        case 0.5..<0.7: return "ActiveFlow"
        case 0.7..<0.9: return "TechnoMinimal"
        default: return "QuantumEnergy"
        }
    }
}

// MARK: - MusicKit Service

/// Apple Music integration for bio-reactive playlists
@MainActor
public final class MusicKitService: ObservableObject, MusicServiceProtocol {

    public static let shared = MusicKitService()

    // MARK: - Published State

    @Published public private(set) var isAuthorized: Bool = false
    @Published public private(set) var currentTrack: EchoelTrack?
    @Published public private(set) var recentSearches: [String] = []
    @Published public private(set) var bioReactivePlaylist: [EchoelTrack] = []
    @Published public private(set) var isLoading: Bool = false

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadRecentSearches()
        log.info("MusicKit Service initialized", category: .audio)
    }

    // MARK: - Authorization

    public func requestAuthorization() async -> Bool {
        #if canImport(MusicKit)
        let status = await MusicAuthorization.request()
        isAuthorized = status == .authorized
        log.info("MusicKit authorization: \(isAuthorized)", category: .audio)
        return isAuthorized
        #else
        log.warning("MusicKit not available on this platform", category: .audio)
        return false
        #endif
    }

    // MARK: - Catalog Search

    public func searchCatalog(query: String) async throws -> [EchoelTrack] {
        #if canImport(MusicKit)
        guard isAuthorized else {
            _ = await requestAuthorization()
            guard isAuthorized else { return [] }
        }

        isLoading = true
        defer { isLoading = false }

        // Save to recent searches
        addToRecentSearches(query)

        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 25

        let response = try await request.response()
        let tracks = response.songs.map { song -> EchoelTrack in
            EchoelTrack(
                id: song.id.rawValue,
                title: song.title,
                artistName: song.artistName,
                albumTitle: song.albumTitle,
                artworkURL: song.artwork?.url(width: 500, height: 500),
                duration: song.duration ?? 0,
                genres: song.genreNames,
                isExplicit: song.contentRating == .explicit
            )
        }

        log.info("MusicKit search: \(query) → \(tracks.count) results", category: .audio)
        return tracks
        #else
        return []
        #endif
    }

    // MARK: - Currently Playing

    public func getCurrentlyPlaying() async -> EchoelTrack? {
        #if canImport(MusicKit)
        guard isAuthorized else { return nil }

        // Get system music player state
        let player = SystemMusicPlayer.shared
        guard let entry = player.queue.currentEntry,
              case .song(let song) = entry.item else {
            return nil
        }

        currentTrack = EchoelTrack(
            id: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            albumTitle: song.albumTitle,
            artworkURL: song.artwork?.url(width: 500, height: 500),
            duration: song.duration ?? 0,
            genres: song.genreNames,
            isExplicit: song.contentRating == .explicit
        )

        return currentTrack
        #else
        return nil
        #endif
    }

    // MARK: - Bio-Reactive Recommendations

    /// Get music recommendations based on current coherence level
    public func getRecommendations(basedOn coherence: Float) async throws -> [EchoelTrack] {
        #if canImport(MusicKit)
        guard isAuthorized else { return [] }

        isLoading = true
        defer { isLoading = false }

        // Map coherence to genre/mood
        let searchTerm = coherenceToSearchTerm(coherence)

        var request = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
        request.limit = 20

        let response = try await request.response()
        let tracks = response.songs.compactMap { song -> EchoelTrack? in
            EchoelTrack(
                id: song.id.rawValue,
                title: song.title,
                artistName: song.artistName,
                albumTitle: song.albumTitle,
                artworkURL: song.artwork?.url(width: 500, height: 500),
                duration: song.duration ?? 0,
                genres: song.genreNames,
                isExplicit: song.contentRating == .explicit,
                energy: coherence,  // Estimate
                valence: coherence * 0.8 + 0.1  // Slight offset
            )
        }

        bioReactivePlaylist = tracks
        log.info("Bio-reactive recommendations: coherence \(coherence) → \(tracks.count) tracks", category: .audio)
        return tracks
        #else
        return []
        #endif
    }

    /// Map coherence level to music search terms
    private func coherenceToSearchTerm(_ coherence: Float) -> String {
        switch coherence {
        case 0..<0.2: return "ambient meditation calm"
        case 0.2..<0.4: return "chill relaxing acoustic"
        case 0.4..<0.6: return "indie folk peaceful"
        case 0.6..<0.8: return "upbeat positive energy"
        case 0.8...1.0: return "energetic dance workout"
        default: return "ambient relaxing"
        }
    }

    // MARK: - Recent Searches

    private func addToRecentSearches(_ query: String) {
        if !recentSearches.contains(query) {
            recentSearches.insert(query, at: 0)
            if recentSearches.count > 10 {
                recentSearches = Array(recentSearches.prefix(10))
            }
            saveRecentSearches()
        }
    }

    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "echoelmusic_music_searches") ?? []
    }

    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "echoelmusic_music_searches")
    }

    public func clearRecentSearches() {
        recentSearches.removeAll()
        saveRecentSearches()
    }
}

// MARK: - ShazamKit Service

/// Audio recognition for ambient music detection
@MainActor
public final class ShazamKitService: ObservableObject {

    public static let shared = ShazamKitService()

    // MARK: - Published State

    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var lastMatch: EchoelTrack?
    @Published public private(set) var matchHistory: [EchoelTrack] = []
    @Published public private(set) var error: String?

    // MARK: - Private State

    #if canImport(ShazamKit)
    private var session: SHSession?
    private let audioEngine = AVAudioEngine()
    #endif

    // MARK: - Initialization

    private init() {
        setupSession()
        loadMatchHistory()
        log.info("ShazamKit Service initialized", category: .audio)
    }

    private func setupSession() {
        #if canImport(ShazamKit)
        session = SHSession()
        session?.delegate = ShazamDelegate.shared

        // Set up callback
        ShazamDelegate.shared.onMatch = { [weak self] match in
            Task { @MainActor in
                self?.handleMatch(match)
            }
        }

        ShazamDelegate.shared.onError = { [weak self] errorMessage in
            Task { @MainActor in
                self?.error = errorMessage
                self?.isListening = false
            }
        }
        #endif
    }

    // MARK: - Recognition

    /// Start listening for ambient music
    public func startListening() {
        #if canImport(ShazamKit)
        guard !isListening else { return }
        guard let session = session else { return }

        error = nil

        do {
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { buffer, _ in
                session.matchStreamingBuffer(buffer, at: nil)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            log.info("ShazamKit: Started listening", category: .audio)
        } catch {
            self.error = "Failed to start audio: \(error.localizedDescription)"
            log.error("ShazamKit start failed: \(error)", category: .audio)
        }
        #else
        error = "ShazamKit not available on this platform"
        #endif
    }

    /// Stop listening
    public func stopListening() {
        #if canImport(ShazamKit)
        guard isListening else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false
        log.info("ShazamKit: Stopped listening", category: .audio)
        #endif
    }

    // MARK: - Match Handling

    #if canImport(ShazamKit)
    private func handleMatch(_ match: SHMatch) {
        guard let mediaItem = match.mediaItems.first else { return }

        let track = EchoelTrack(
            id: mediaItem.shazamID ?? UUID().uuidString,
            title: mediaItem.title ?? "Unknown",
            artistName: mediaItem.artist ?? "Unknown Artist",
            albumTitle: nil,
            artworkURL: mediaItem.artworkURL,
            duration: 0,
            genres: mediaItem.genres,
            isExplicit: mediaItem.isExplicit,
            detectedKey: nil,
            detectedTempo: nil,
            energy: nil,
            valence: nil
        )

        lastMatch = track
        addToHistory(track)

        log.info("ShazamKit matched: \(track.title) by \(track.artistName)", category: .audio)

        // Auto-stop after match
        stopListening()
    }
    #endif

    // MARK: - History

    private func addToHistory(_ track: EchoelTrack) {
        // Avoid duplicates
        if !matchHistory.contains(where: { $0.id == track.id }) {
            matchHistory.insert(track, at: 0)
            if matchHistory.count > 50 {
                matchHistory = Array(matchHistory.prefix(50))
            }
            saveMatchHistory()
        }
    }

    private func loadMatchHistory() {
        // Load from UserDefaults (simplified - would use Codable in production)
        if let data = UserDefaults.standard.data(forKey: "echoelmusic_shazam_history"),
           let history = try? JSONDecoder().decode([ShazamHistoryItem].self, from: data) {
            matchHistory = history.map { item in
                EchoelTrack(
                    id: item.id,
                    title: item.title,
                    artistName: item.artist,
                    albumTitle: nil,
                    artworkURL: item.artworkURL.flatMap { URL(string: $0) },
                    duration: 0,
                    genres: [],
                    isExplicit: false
                )
            }
        }
    }

    private func saveMatchHistory() {
        let items = matchHistory.map { track in
            ShazamHistoryItem(
                id: track.id,
                title: track.title,
                artist: track.artistName,
                artworkURL: track.artworkURL?.absoluteString
            )
        }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "echoelmusic_shazam_history")
        }
    }

    public func clearHistory() {
        matchHistory.removeAll()
        saveMatchHistory()
    }
}

// Simple history storage model
private struct ShazamHistoryItem: Codable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: String?
}

// MARK: - Shazam Delegate

#if canImport(ShazamKit)
private class ShazamDelegate: NSObject, SHSessionDelegate {
    static let shared = ShazamDelegate()

    var onMatch: ((SHMatch) -> Void)?
    var onError: ((String) -> Void)?

    func session(_ session: SHSession, didFind match: SHMatch) {
        onMatch?(match)
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        onError?("No match found")
    }
}
#endif

// MARK: - Creative Music Hub

/// Unified creative music service combining MusicKit, ShazamKit, and MIR
@MainActor
public final class CreativeMusicHub: ObservableObject {

    public static let shared = CreativeMusicHub()

    // MARK: - Sub-services

    public let musicKit = MusicKitService.shared
    public let shazam = ShazamKitService.shared

    // MARK: - Published State

    @Published public private(set) var activeTrack: EchoelTrack?
    @Published public private(set) var suggestedPreset: String = "ActiveFlow"
    @Published public private(set) var isAnalyzing: Bool = false

    // MARK: - Bio-Reactive Features

    /// Get track suggestion based on current biometric state
    public func getSuggestion(coherence: Float, heartRate: Int) async -> EchoelTrack? {
        // First check if music is already playing
        if let current = await musicKit.getCurrentlyPlaying() {
            activeTrack = current
            suggestedPreset = current.suggestedPreset
            return current
        }

        // Otherwise, get recommendations
        do {
            let tracks = try await musicKit.getRecommendations(basedOn: coherence)
            if let first = tracks.first {
                activeTrack = first
                suggestedPreset = first.suggestedPreset
                return first
            }
        } catch {
            log.warning("Failed to get music recommendations: \(error)", category: .audio)
        }

        return nil
    }

    /// Analyze ambient music with Shazam and get matching preset
    public func analyzeAmbientMusic() async -> (track: EchoelTrack?, preset: String) {
        isAnalyzing = true
        defer { isAnalyzing = false }

        shazam.startListening()

        // Wait for match (with timeout)
        try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds

        shazam.stopListening()

        if let match = shazam.lastMatch {
            activeTrack = match
            suggestedPreset = match.suggestedPreset
            return (match, match.suggestedPreset)
        }

        return (nil, "ActiveFlow")
    }

    /// Create a bio-reactive playlist for a session
    public func createSessionPlaylist(
        duration: TimeInterval,
        startingCoherence: Float,
        targetCoherence: Float
    ) async -> [EchoelTrack] {
        var playlist: [EchoelTrack] = []

        // Calculate coherence progression
        let steps = max(3, Int(duration / 300)) // One track per 5 minutes
        let coherenceStep = (targetCoherence - startingCoherence) / Float(steps)

        for i in 0..<steps {
            let coherence = startingCoherence + coherenceStep * Float(i)
            if let tracks = try? await musicKit.getRecommendations(basedOn: coherence),
               let track = tracks.randomElement() {
                playlist.append(track)
            }
        }

        log.info("Created session playlist: \(playlist.count) tracks for \(duration/60)min session", category: .audio)
        return playlist
    }
}

// MARK: - SwiftUI Views

/// Music search and discovery view
public struct MusicDiscoveryView: View {
    @ObservedObject var hub = CreativeMusicHub.shared
    @ObservedObject var musicKit = MusicKitService.shared
    @ObservedObject var shazam = ShazamKitService.shared

    @State private var searchQuery = ""
    @State private var searchResults: [EchoelTrack] = []
    @State private var isSearching = false

    @ScaledMetric private var artworkSize: CGFloat = 60

    public init() {}

    public var body: some View {
        NavigationView {
            List {
                // Shazam Section
                Section {
                    ShazamListeningRow(shazam: shazam)

                    if let match = shazam.lastMatch {
                        TrackRow(track: match, artworkSize: artworkSize)
                    }
                } header: {
                    Label("Listen Around You", systemImage: "waveform")
                }

                // Search Section
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search Apple Music", text: $searchQuery)
                            .onSubmit { performSearch() }
                        if isSearching {
                            ProgressView()
                        }
                    }

                    ForEach(searchResults) { track in
                        TrackRow(track: track, artworkSize: artworkSize)
                    }
                } header: {
                    Label("Search Music", systemImage: "music.note.list")
                }

                // Recent Searches
                if !musicKit.recentSearches.isEmpty {
                    Section {
                        ForEach(musicKit.recentSearches, id: \.self) { query in
                            Button(query) {
                                searchQuery = query
                                performSearch()
                            }
                            .foregroundColor(.primary)
                        }
                    } header: {
                        Label("Recent Searches", systemImage: "clock")
                    }
                }

                // Bio-Reactive Playlist
                if !musicKit.bioReactivePlaylist.isEmpty {
                    Section {
                        ForEach(musicKit.bioReactivePlaylist) { track in
                            TrackRow(track: track, artworkSize: artworkSize)
                        }
                    } header: {
                        Label("Bio-Reactive Playlist", systemImage: "heart.fill")
                    }
                }
            }
            .navigationTitle("Music Discovery")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            _ = await musicKit.requestAuthorization()
                        }
                    } label: {
                        Image(systemName: musicKit.isAuthorized ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark")
                    }
                }
            }
        }
    }

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true

        Task {
            do {
                searchResults = try await musicKit.searchCatalog(query: searchQuery)
            } catch {
                log.error("Search failed: \(error)", category: .audio)
            }
            isSearching = false
        }
    }
}

struct ShazamListeningRow: View {
    @ObservedObject var shazam: ShazamKitService

    var body: some View {
        Button {
            if shazam.isListening {
                shazam.stopListening()
            } else {
                shazam.startListening()
            }
        } label: {
            HStack {
                Image(systemName: shazam.isListening ? "waveform.circle.fill" : "waveform.circle")
                    .font(.title)
                    .foregroundColor(shazam.isListening ? .blue : .secondary)
                    .symbolEffect(.variableColor, isActive: shazam.isListening)

                VStack(alignment: .leading) {
                    Text(shazam.isListening ? "Listening..." : "Tap to Identify Music")
                        .font(.headline)
                    Text("Uses Shazam to recognize ambient music")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityLabel(shazam.isListening ? "Stop listening" : "Start listening for music")
    }
}

struct TrackRow: View {
    let track: EchoelTrack
    let artworkSize: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            AsyncImage(url: track.artworkURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: artworkSize, height: artworkSize)
            .cornerRadius(8)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(track.artistName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Suggested preset badge
                Text("Preset: \(track.suggestedPreset)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(4)
            }

            Spacer()

            if track.isExplicit {
                Image(systemName: "e.square.fill")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Explicit")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(track.title) by \(track.artistName)")
    }
}
