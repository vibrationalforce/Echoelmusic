// MARK: - EchoelaAppClip.swift
// Echoelmusic Suite - App Clip for Instant NFT Experience
// Bundle ID: com.echoelmusic.app.clip
// Copyright 2026 Echoelmusic. All rights reserved.

import SwiftUI
import AppClip
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - App Clip Manager

/// App Clip manager for instant preview and NFT minting at events
/// Supports QR code activation and instant experience without full app install
@MainActor
public final class EchoelaAppClipManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelaAppClipManager()

    // MARK: - Published State

    @Published public private(set) var invocationURL: URL?
    @Published public private(set) var eventInfo: EventInfo?
    @Published public private(set) var previewContent: PreviewContent?
    @Published public private(set) var canMint: Bool = false
    @Published public private(set) var mintingInProgress: Bool = false

    // MARK: - Types

    /// Event information from App Clip invocation
    public struct EventInfo: Codable {
        public let eventID: String
        public let eventName: String
        public let artistName: String
        public let venueName: String
        public let timestamp: Date
        public let location: Location?

        public struct Location: Codable {
            public let latitude: Double
            public let longitude: Double
            public let accuracy: Double
        }
    }

    /// Preview content for App Clip experience
    public struct PreviewContent: Identifiable {
        public let id: UUID
        public let title: String
        public let artistName: String
        public let duration: TimeInterval
        public let previewURL: URL?
        public let coverImageURL: URL?
        public let bioReactiveVisualization: Bool
        public let nftPrice: Decimal?
        public let currency: String
    }

    /// Mint result
    public struct AppClipMintResult {
        public let success: Bool
        public let nftID: String?
        public let transactionHash: String?
        public let errorMessage: String?
        public let openSeaURL: URL?
    }

    // MARK: - Configuration

    /// Maximum App Clip experience duration (10 minutes)
    public static let maxExperienceDuration: TimeInterval = 600

    /// Preview duration (30 seconds)
    public static let previewDuration: TimeInterval = 30

    // MARK: - Initialization

    private init() {
        setupEchoelaContext()
    }

    private func setupEchoelaContext() {
        Task { @MainActor in
            EchoelaManager.shared.setContext(.appClipPreview)
        }
    }

    // MARK: - Public API

    /// Handle App Clip invocation
    public func handleInvocation(url: URL, location: CLLocation? = nil) {
        invocationURL = url

        // Parse URL for event info
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            var eventID: String?
            var eventName: String?
            var artistName: String?

            for item in components.queryItems ?? [] {
                switch item.name {
                case "event": eventID = item.value
                case "name": eventName = item.value
                case "artist": artistName = item.value
                default: break
                }
            }

            if let eventID = eventID {
                let locationInfo: EventInfo.Location?
                if let loc = location {
                    locationInfo = EventInfo.Location(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude,
                        accuracy: loc.horizontalAccuracy
                    )
                } else {
                    locationInfo = nil
                }

                eventInfo = EventInfo(
                    eventID: eventID,
                    eventName: eventName ?? "Live Event",
                    artistName: artistName ?? "Unknown Artist",
                    venueName: extractVenueName(from: url),
                    timestamp: Date(),
                    location: locationInfo
                )

                // Load preview content
                Task {
                    await loadPreviewContent(for: eventID)
                }
            }
        }
    }

    /// Load preview content for event
    public func loadPreviewContent(for eventID: String) async {
        // In production, this would fetch from server
        // For now, create sample content
        previewContent = PreviewContent(
            id: UUID(),
            title: "Bio-Reactive Live Session",
            artistName: eventInfo?.artistName ?? "Artist",
            duration: Self.previewDuration,
            previewURL: URL(string: "https://cdn.echoelmusic.com/preview/\(eventID).mp4"),
            coverImageURL: URL(string: "https://cdn.echoelmusic.com/cover/\(eventID).jpg"),
            bioReactiveVisualization: true,
            nftPrice: 0.01,
            currency: "ETH"
        )

        canMint = true
    }

    /// Start instant preview experience
    public func startPreview() {
        EchoelaManager.shared.activate(in: .appClipPreview)

        // Start bio-reactive visualization if available
        // This would connect to Apple Watch if paired
    }

    /// Mint NFT from App Clip
    public func mintNFT() async throws -> AppClipMintResult {
        guard canMint, let content = previewContent else {
            return AppClipMintResult(
                success: false,
                nftID: nil,
                transactionHash: nil,
                errorMessage: "No content available for minting",
                openSeaURL: nil
            )
        }

        mintingInProgress = true
        defer { mintingInProgress = false }

        // Request compliance check
        let complianceResult = try await ComplianceManager.shared.runComplianceCheck(
            content: ComplianceManager.ContentInfo(
                hasISRC: false,
                isrcCode: nil,
                hasGEMANumber: false,
                gemaWorkNumber: nil,
                containsSamples: false,
                sampleSources: [],
                hasLyrics: false,
                wordCount: 0
            ),
            aiInfo: ComplianceManager.AIContentInfo(
                containsAIContent: false,
                aiPercentage: 0,
                aiTechnologies: [],
                humanOversight: true,
                aiDisclosurePresent: false
            ),
            nftInfo: ComplianceManager.NFTInfo(
                isPartOfSeries: true,
                seriesSize: 100,
                isFractionalized: false,
                hasWhitepaper: false,
                network: .base
            ),
            biometricInfo: ComplianceManager.BiometricInfo(
                usesBiometricData: false,
                dataCategories: [],
                userID: UUID().uuidString,
                storageLocation: .blockchain
            )
        )

        guard complianceResult.canProceed else {
            return AppClipMintResult(
                success: false,
                nftID: nil,
                transactionHash: nil,
                errorMessage: complianceResult.blockingIssues.first?.description ?? "Compliance check failed",
                openSeaURL: nil
            )
        }

        // Connect wallet (simplified for App Clip)
        let wallet = try await NFTFactory.shared.connectWallet(provider: .secureEnclave, network: .base)

        // Create mint request
        let bioMetadata = NFTFactory.BioReactiveMetadata(
            sessionID: UUID(),
            captureTimestamp: Date(),
            duration: content.duration,
            averageHeartRate: 72,  // Placeholder
            averageHRV: 50,
            peakCoherence: 0.7,
            coherenceHistory: [],
            breathingPattern: nil,
            emotionalSignature: nil
        )

        let nftContent = NFTFactory.NFTContent(
            audioFileURL: content.previewURL,
            visualFileURL: nil,
            coverImageURL: content.coverImageURL,
            animatedPreviewURL: content.previewURL,
            format: .audioVisual,
            duration: content.duration,
            resolution: "1080p"
        )

        let splits = NFTFactory.RevenueSplit(
            recipients: [
                NFTFactory.RevenueSplit.Recipient(
                    address: wallet.address,
                    percentage: 90,
                    role: .musician
                ),
                NFTFactory.RevenueSplit.Recipient(
                    address: "0x...",  // Platform treasury
                    percentage: 10,
                    role: .platform
                )
            ],
            totalPercentage: 100
        )

        let compliance = NFTFactory.ComplianceInfo(
            isrcCode: nil,
            gemaWorkNumber: nil,
            vgWortID: nil,
            aiContentPercentage: 0,
            hasLicensedSamples: false,
            licensedSampleIDs: [],
            euAIActCompliant: true,
            micaCompliant: true
        )

        // Prepare and execute mint
        let pendingMint = try NFTFactory.shared.prepareMint(
            content: nftContent,
            bioMetadata: bioMetadata,
            splits: splits,
            compliance: compliance,
            standard: .erc721c,
            network: .base
        )

        let mintedNFT = try await NFTFactory.shared.mint(mintID: pendingMint.id)

        return AppClipMintResult(
            success: true,
            nftID: mintedNFT.tokenID,
            transactionHash: mintedNFT.transactionHash,
            errorMessage: nil,
            openSeaURL: mintedNFT.openseaURL
        )
    }

    /// Prompt to install full app
    public func promptFullAppInstall() {
        // Use SKOverlay to show App Store install prompt
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        let config = SKOverlay.AppClipConfiguration(position: .bottom)
        let overlay = SKOverlay(configuration: config)
        overlay.present(in: windowScene)
    }

    // MARK: - Private Methods

    private func extractVenueName(from url: URL) -> String {
        // Extract venue from URL path or default
        return url.pathComponents.dropFirst().first ?? "Event Venue"
    }
}

// MARK: - App Clip UI

import CoreLocation

/// Main App Clip view
public struct EchoelaAppClipView: View {
    @StateObject private var clipManager = EchoelaAppClipManager.shared
    @State private var showMintConfirmation = false
    @State private var mintResult: EchoelaAppClipManager.AppClipMintResult?

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Event info
                if let event = clipManager.eventInfo {
                    VStack(spacing: 8) {
                        Text(event.eventName)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(event.artistName)
                            .font(.headline)
                            .foregroundStyle(.purple)

                        Text(event.venueName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Preview content
                if let content = clipManager.previewContent {
                    VStack(spacing: 16) {
                        // Cover image placeholder
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "waveform")
                                        .font(.largeTitle)
                                    Text("Bio-Reactive Preview")
                                        .font(.caption)
                                }
                                .foregroundStyle(.white)
                            )

                        // Duration
                        HStack {
                            Image(systemName: "clock")
                            Text("\(Int(content.duration))s preview")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        // Start preview button
                        Button {
                            clipManager.startPreview()
                        } label: {
                            Label("Start Preview", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)

                        // Price and mint
                        if let price = content.nftPrice {
                            HStack {
                                Text("Mint as NFT:")
                                Spacer()
                                Text("\(price) \(content.currency)")
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )

                            Button {
                                showMintConfirmation = true
                            } label: {
                                Label("Mint NFT", systemImage: "sparkles.rectangle.stack")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!clipManager.canMint || clipManager.mintingInProgress)
                        }
                    }
                } else {
                    ProgressView("Loading preview...")
                }

                Spacer()

                // Install full app prompt
                Button {
                    clipManager.promptFullAppInstall()
                } label: {
                    Label("Get Full App", systemImage: "arrow.down.app")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Echoelmusic")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Mint NFT", isPresented: $showMintConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Mint") {
                    Task {
                        mintResult = try? await clipManager.mintNFT()
                    }
                }
            } message: {
                Text("This will create an NFT on the Base network. Gas fees apply.")
            }
            .sheet(item: $mintResult) { result in
                MintResultView(result: result)
            }
        }
    }
}

/// Mint result view
struct MintResultView: View {
    let result: EchoelaAppClipManager.AppClipMintResult

    var body: some View {
        VStack(spacing: 24) {
            if result.success {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text("NFT Minted!")
                    .font(.title)
                    .fontWeight(.bold)

                if let nftID = result.nftID {
                    Text("Token ID: \(nftID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let url = result.openSeaURL {
                    Link(destination: url) {
                        Label("View on OpenSea", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                Text("Minting Failed")
                    .font(.title)
                    .fontWeight(.bold)

                if let error = result.errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
    }
}

extension EchoelaAppClipManager.AppClipMintResult: Identifiable {
    public var id: String { nftID ?? UUID().uuidString }
}
