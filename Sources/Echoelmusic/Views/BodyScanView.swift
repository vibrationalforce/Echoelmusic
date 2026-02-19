// BodyScanView.swift
// Echoelmusic
//
// SwiftUI interface for body scan resonance wellness tool.
// Camera-based body detection + targeted frequency wellness sessions.
//
// DISCLAIMER: Wellness and creative tool only. Not a medical device.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import SwiftUI

// MARK: - Body Scan View

/// Main view for body scan resonance wellness sessions
public struct BodyScanView: View {
    @StateObject private var engine = BodyScanResonanceEngine()
    @State private var showDisclaimer = true
    @State private var showRegionDetail = false
    @State private var showSettings = false

    public init() {}

    public var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            if showDisclaimer {
                bodyScanDisclaimerOverlay
            } else {
                mainScanContent
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Disclaimer

    private var bodyScanDisclaimerOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.stand")
                .font(.system(size: 80))
                .foregroundColor(VaporwaveColors.neonCyan)

            Text("Body Scan Resonance")
                .font(VaporwaveTypography.sectionTitle())
                .foregroundColor(VaporwaveColors.textPrimary)

            VStack(spacing: 12) {
                DisclaimerRow(icon: "waveform.circle.fill", text: "Wellness & Creative Exploration")
                DisclaimerRow(icon: "xmark.shield.fill", text: "No Medical Claims — Not a Medical Device")
                DisclaimerRow(icon: "camera.fill", text: "Camera Used On-Device Only (No Cloud)")
                DisclaimerRow(icon: "timer", text: "15 Minute Session Safety Limit")
                DisclaimerRow(icon: "heart.text.square.fill", text: "Consult Professionals for Health Concerns")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
            )
            .padding(.horizontal)

            Text("This tool uses your camera to detect body position and explore frequency-based wellness responses for relaxation and creative sound design.")
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: {
                engine.acknowledgeDisclaimer()
                showDisclaimer = false
            }) {
                Text("I Understand — Continue")
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.deepBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(VaporwaveColors.neonCyan)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Main Content

    private var mainScanContent: some View {
        VStack(spacing: 0) {
            // Header
            scanHeader

            // Body Map
            bodyMapSection

            // Region Selector
            regionSelector

            // Active Region Info
            if let region = engine.selectedRegion ?? engine.currentRegion {
                regionInfoCard(region)
            }

            Spacer()

            // Action Controls
            actionControls
                .padding(.bottom, 24)
        }
    }

    // MARK: - Header

    private var scanHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    Image(systemName: "figure.stand")
                        .foregroundColor(VaporwaveColors.neonCyan)

                    Text("BODY SCAN")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)
                }

                Text(engine.isScanning ? "Scanning... \(engine.detectedRegions.count) regions detected" : "Ready to scan")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            Spacer()

            // Pose Confidence
            if engine.isScanning {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Pose")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Text("\(Int(engine.bodyPoseConfidence * 100))%")
                        .font(VaporwaveTypography.dataSmall())
                        .foregroundColor(poseColor)
                }
            }

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
        }
        .padding(VaporwaveSpacing.md)
    }

    // MARK: - Body Map

    private var bodyMapSection: some View {
        ZStack {
            // Background body silhouette
            RoundedRectangle(cornerRadius: 20)
                .fill(VaporwaveColors.deepBlack.opacity(0.5))
                .frame(height: 300)

            // Body outline
            BodySilhouette(
                jointPositions: engine.jointPositions,
                scanResults: engine.scanResults,
                selectedRegion: engine.selectedRegion ?? engine.currentRegion,
                isScanning: engine.isScanning
            )
            .frame(height: 280)

            // Coherence overlay
            if engine.isScanning {
                VStack {
                    Spacer()
                    HStack {
                        Label("\(Int(engine.currentCoherence * 100))%", systemImage: "waveform")
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.neonCyan)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(VaporwaveColors.deepBlack.opacity(0.7))
                            .cornerRadius(12)

                        Spacer()

                        if engine.isStimulating {
                            Label("Active", systemImage: "waveform.path")
                                .font(VaporwaveTypography.caption())
                                .foregroundColor(VaporwaveColors.coherenceHigh)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(VaporwaveColors.deepBlack.opacity(0.7))
                                .cornerRadius(12)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .padding(.horizontal, VaporwaveSpacing.md)
    }

    // MARK: - Region Selector

    private var regionSelector: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
            Text("BODY REGIONS")
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
                .padding(.horizontal, VaporwaveSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    ForEach(BodyRegion.allCases) { region in
                        BodyRegionChip(
                            region: region,
                            isSelected: (engine.selectedRegion ?? engine.currentRegion) == region,
                            isDetected: engine.detectedRegions.contains(region),
                            hasResult: engine.scanResults[region] != nil
                        ) {
                            engine.selectedRegion = region
                            if engine.isScanning {
                                Task { try? await engine.focusRegion(region) }
                            }
                        }
                    }
                }
                .padding(.horizontal, VaporwaveSpacing.md)
            }
        }
        .padding(.vertical, VaporwaveSpacing.sm)
    }

    // MARK: - Region Info Card

    private func regionInfoCard(_ region: BodyRegion) -> some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            HStack {
                Image(systemName: region.icon)
                    .font(.title3)
                    .foregroundColor(VaporwaveColors.neonCyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(region.rawValue)
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text("\(Int(region.resonanceRange.min))-\(Int(region.resonanceRange.max)) Hz")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.neonCyan)
                }

                Spacer()

                if let result = engine.scanResults[region] {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(result.coherenceScore * 100))%")
                            .font(VaporwaveTypography.dataSmall())
                            .foregroundColor(VaporwaveColors.coherenceHigh)

                        Text("Coherence")
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }
                }
            }

            // Educational note
            Text(region.educationalNote)
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Wellness disclaimer
            Text("Wellness exploration only — not medical advice")
                .font(.system(size: 9))
                .foregroundColor(VaporwaveColors.textTertiary.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
        .padding(.horizontal, VaporwaveSpacing.md)
    }

    // MARK: - Action Controls

    private var actionControls: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            // Stimulation controls (when scanning)
            if engine.isScanning {
                HStack(spacing: VaporwaveSpacing.md) {
                    // Focus on selected region
                    if let region = engine.selectedRegion {
                        Button(action: {
                            Task { try? await engine.focusRegion(region) }
                        }) {
                            HStack {
                                Image(systemName: "waveform.path")
                                Text("Resonate")
                            }
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.deepBlack)
                            .padding(.horizontal, VaporwaveSpacing.lg)
                            .padding(.vertical, VaporwaveSpacing.md)
                            .background(VaporwaveColors.neonPink)
                            .cornerRadius(12)
                        }
                        .neonGlow(color: VaporwaveColors.neonPink, radius: 6)
                    }

                    if engine.isStimulating {
                        Button(action: {
                            Task { await engine.stopCurrentStimulation() }
                        }) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Stop")
                            }
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.coral)
                            .padding(.horizontal, VaporwaveSpacing.lg)
                            .padding(.vertical, VaporwaveSpacing.md)
                        }
                        .glassCard()
                    }
                }
            }

            // Main scan button
            Button(action: {
                Task {
                    if engine.isScanning {
                        await engine.stopScan()
                    } else {
                        try? await engine.startScan()
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: engine.isScanning ? "stop.fill" : "camera.fill")
                        .font(.title3)

                    Text(engine.isScanning ? "Stop Scan" : "Start Body Scan")
                        .font(VaporwaveTypography.body())
                }
                .foregroundColor(VaporwaveColors.deepBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(engine.isScanning ? VaporwaveColors.coral : VaporwaveColors.neonCyan)
                .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .neonGlow(color: engine.isScanning ? VaporwaveColors.coral : VaporwaveColors.neonCyan, radius: 8)

            // Error message
            if let error = engine.errorMessage {
                Text(error)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.coral)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Helpers

    private var poseColor: Color {
        if engine.bodyPoseConfidence > 0.7 { return VaporwaveColors.coherenceHigh }
        if engine.bodyPoseConfidence > 0.4 { return VaporwaveColors.coherenceMedium }
        return VaporwaveColors.coherenceLow
    }
}

// MARK: - Body Silhouette View

struct BodySilhouette: View {
    let jointPositions: [BodyRegion: CGPoint]
    let scanResults: [BodyRegion: BodyScanResult]
    let selectedRegion: BodyRegion?
    let isScanning: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Draw connections between joints
                if !jointPositions.isEmpty {
                    bodyConnections(in: geo.size)
                }

                // Draw joint dots
                ForEach(BodyRegion.allCases) { region in
                    if let pos = jointPositions[region] {
                        let point = CGPoint(
                            x: pos.x * geo.size.width,
                            y: pos.y * geo.size.height
                        )

                        Circle()
                            .fill(colorForRegion(region))
                            .frame(width: region == selectedRegion ? 20 : 12,
                                   height: region == selectedRegion ? 20 : 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: region == selectedRegion ? 2 : 0)
                            )
                            .position(point)
                            .animation(.easeInOut(duration: 0.3), value: selectedRegion)

                        // Region label for selected
                        if region == selectedRegion {
                            Text(region.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(VaporwaveColors.neonCyan.opacity(0.8))
                                .cornerRadius(4)
                                .position(CGPoint(x: point.x, y: point.y - 20))
                        }
                    }
                }

                // Placeholder silhouette when no pose detected
                if jointPositions.isEmpty && !isScanning {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 120))
                        .foregroundColor(VaporwaveColors.textTertiary.opacity(0.3))
                }

                if jointPositions.isEmpty && isScanning {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(VaporwaveColors.neonCyan)
                        Text("Point camera at person...")
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }
                }
            }
        }
    }

    private func bodyConnections(in size: CGSize) -> some View {
        let connections: [(BodyRegion, BodyRegion)] = [
            (.head, .neck),
            (.neck, .leftShoulder), (.neck, .rightShoulder),
            (.leftShoulder, .leftArm), (.rightShoulder, .rightArm),
            (.leftArm, .leftHand), (.rightArm, .rightHand),
            (.neck, .chest), (.chest, .abdomen),
            (.abdomen, .leftHip), (.abdomen, .rightHip),
            (.leftHip, .leftLeg), (.rightHip, .rightLeg),
        ]

        return ForEach(0..<connections.count, id: \.self) { i in
            let (from, to) = connections[i]
            if let p1 = jointPositions[from], let p2 = jointPositions[to] {
                Path { path in
                    path.move(to: CGPoint(x: p1.x * size.width, y: p1.y * size.height))
                    path.addLine(to: CGPoint(x: p2.x * size.width, y: p2.y * size.height))
                }
                .stroke(VaporwaveColors.neonCyan.opacity(0.3), lineWidth: 2)
            }
        }
    }

    private func colorForRegion(_ region: BodyRegion) -> Color {
        if let result = scanResults[region] {
            if result.coherenceScore > 0.7 { return VaporwaveColors.coherenceHigh }
            if result.coherenceScore > 0.4 { return VaporwaveColors.coherenceMedium }
            return VaporwaveColors.coherenceLow
        }
        return VaporwaveColors.neonCyan.opacity(0.7)
    }
}

// MARK: - Body Region Chip

struct BodyRegionChip: View {
    let region: BodyRegion
    let isSelected: Bool
    let isDetected: Bool
    let hasResult: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: region.icon)
                    .font(.system(size: 12))

                Text(region.rawValue)
                    .font(VaporwaveTypography.label())
                    .lineLimit(1)

                if hasResult {
                    Circle()
                        .fill(VaporwaveColors.coherenceHigh)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundColor(isSelected ? VaporwaveColors.deepBlack : (isDetected ? VaporwaveColors.textPrimary : VaporwaveColors.textTertiary))
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? VaporwaveColors.neonCyan : (isDetected ? VaporwaveColors.neonCyan.opacity(0.15) : Color.clear))
            )
            .overlay(
                Capsule()
                    .stroke(isDetected ? VaporwaveColors.neonCyan.opacity(0.5) : VaporwaveColors.textTertiary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Disclaimer Row

struct DisclaimerRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(VaporwaveColors.neonCyan)
                .frame(width: 24)

            Text(text)
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    BodyScanView()
}
#endif
