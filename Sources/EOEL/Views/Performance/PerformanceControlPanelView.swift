//
//  PerformanceControlPanelView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Performance Control Panel - Real-time monitoring and optimization
//  Professional performance management interface
//

import SwiftUI

/// Performance Control Panel UI
struct PerformanceControlPanelView: View {
    @StateObject private var perfManager = PerformanceOptimizationManager.shared
    @State private var selectedTab: PerfTab = .overview

    enum PerfTab: String, CaseIterable {
        case overview = "Overview"
        case audio = "Audio Engine"
        case memory = "Memory"
        case storage = "Storage"
        case optimizations = "Optimizations"
        case recommendations = "Recommendations"

        var icon: String {
            switch self {
            case .overview: return "gauge"
            case .audio: return "waveform"
            case .memory: return "memorychip"
            case .storage: return "internaldrive"
            case .optimizations: return "slider.horizontal.3"
            case .recommendations: return "lightbulb"
            }
        }
    }

    var body: some View {
        NavigationView {
            // Sidebar
            List(PerfTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("Performance")
            .frame(minWidth: 180)

            // Detail view
            Group {
                switch selectedTab {
                case .overview:
                    PerformanceOverviewView()
                case .audio:
                    AudioEngineView()
                case .memory:
                    MemoryManagementView()
                case .storage:
                    StorageManagementView()
                case .optimizations:
                    OptimizationsView()
                case .recommendations:
                    RecommendationsView()
                }
            }
            .frame(minWidth: 700)
        }
    }
}

// MARK: - Overview

struct PerformanceOverviewView: View {
    @StateObject private var perfManager = PerformanceOptimizationManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Performance Overview")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Button {
                        perfManager.autoOptimize()
                    } label: {
                        Label("Auto-Optimize", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                }

                // Current Mode
                GroupBox("Performance Mode") {
                    VStack(spacing: 12) {
                        Picker("Mode", selection: $perfManager.performanceMode) {
                            ForEach(PerformanceOptimizationManager.PerformanceMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(perfManager.performanceMode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Real-time Stats
                GroupBox("Real-Time Performance") {
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 16) {
                        GridRow {
                            PerformanceMeter(
                                label: "Latency",
                                value: perfManager.currentLatency,
                                unit: "ms",
                                target: perfManager.performanceMode.targetLatency,
                                color: latencyColor(perfManager.currentLatency)
                            )
                            PerformanceMeter(
                                label: "CPU",
                                value: Double(perfManager.currentCPU),
                                unit: "%",
                                target: 80.0,
                                color: cpuColor(perfManager.currentCPU)
                            )
                        }

                        GridRow {
                            PerformanceMeter(
                                label: "RAM",
                                value: Double(perfManager.currentRAM) / (1024 * 1024),
                                unit: "MB",
                                target: 500.0,
                                color: .blue
                            )
                            PerformanceMeter(
                                label: "Storage",
                                value: Double(perfManager.currentStorage) / (1024 * 1024),
                                unit: "MB",
                                target: 1000.0,
                                color: .purple
                            )
                        }
                    }
                    .padding()
                }

                // Quick Optimizations
                GroupBox("Quick Optimizations") {
                    VStack(spacing: 12) {
                        ForEach([
                            PerformanceOptimizationManager.OptimizationScenario.livePerformance,
                            .recording,
                            .mixing,
                            .mastering,
                            .export,
                            .mobile
                        ], id: \.rawValue) { scenario in
                            Button {
                                perfManager.optimizeForScenario(scenario)
                            } label: {
                                HStack {
                                    Text(scenario.rawValue)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "arrow.right.circle")
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
    }

    private func latencyColor(_ latency: Double) -> Color {
        if latency < 5.0 { return .green }
        else if latency < 20.0 { return .orange }
        else { return .red }
    }

    private func cpuColor(_ cpu: Float) -> Color {
        if cpu < 50.0 { return .green }
        else if cpu < 80.0 { return .orange }
        else { return .red }
    }
}

struct PerformanceMeter: View {
    let label: String
    let value: Double
    let unit: String
    let target: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: min(value, target), total: target)
                .tint(color)

            Text("Target: \(String(format: "%.0f", target)) \(unit)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Audio Engine

struct AudioEngineView: View {
    @StateObject private var perfManager = PerformanceOptimizationManager.shared
    @State private var bufferSize: Double = 128
    @State private var sampleRate: Double = 48000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Audio Engine Configuration")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Buffer Size
                GroupBox("Buffer Size") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("\(Int(bufferSize)) samples")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.2f ms latency",
                                      PerformanceOptimizationManager.AudioOptimizations.calculateLatency(
                                        bufferSize: Int(bufferSize),
                                        sampleRate: sampleRate)))
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $bufferSize, in: 32...2048, step: 32)

                        Text("Smaller buffer = lower latency but higher CPU usage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Sample Rate
                GroupBox("Sample Rate") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Sample Rate", selection: $sampleRate) {
                            Text("44.1 kHz").tag(44100.0)
                            Text("48 kHz").tag(48000.0)
                            Text("88.2 kHz").tag(88200.0)
                            Text("96 kHz").tag(96000.0)
                            Text("192 kHz").tag(192000.0)
                        }
                        .pickerStyle(.segmented)

                        Text("Higher sample rate = better quality but more CPU/storage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Polyphony
                GroupBox("Polyphony Limits") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Max Voices")
                            Spacer()
                            Text("\(perfManager.performanceMode.maxPolyphony)")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Voice Stealing")
                            Spacer()
                            Text("Enabled")
                                .foregroundColor(.green)
                        }

                        HStack {
                            Text("Memory per Voice")
                            Spacer()
                            Text("512 bytes")
                                .foregroundColor(.secondary)
                        }

                        let totalMemory = PerformanceOptimizationManager.MemoryOptimizations.estimatedMemory(
                            voices: perfManager.performanceMode.maxPolyphony
                        )
                        HStack {
                            Text("Total Memory")
                            Spacer()
                            Text("\(totalMemory / 1024) KB")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }

                // DSP Optimizations
                GroupBox("DSP Optimizations") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Apple Accelerate (vDSP)", isOn: .constant(true))
                            .disabled(true)
                        Toggle("SIMD Instructions", isOn: $perfManager.enableSIMD)
                        Toggle("ARM NEON (iOS/visionOS)", isOn: .constant(true))
                            .disabled(true)

                        Text("Hardware-accelerated audio processing for maximum performance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
}

// MARK: - Memory Management

struct MemoryManagementView: View {
    @StateObject private var perfManager = PerformanceOptimizationManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Memory Management")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Current Usage
                GroupBox("Current Memory Usage") {
                    VStack(spacing: 16) {
                        MemoryBar(
                            label: "RAM Usage",
                            used: perfManager.currentRAM,
                            total: PerformanceOptimizationManager.MemoryOptimizations.maxCacheSize,
                            color: .blue
                        )

                        HStack {
                            Text("Allocated")
                            Spacer()
                            Text("\(perfManager.currentRAM / (1024 * 1024)) MB")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Available")
                            Spacer()
                            let available = PerformanceOptimizationManager.MemoryOptimizations.maxCacheSize - perfManager.currentRAM
                            Text("\(available / (1024 * 1024)) MB")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }

                // Buffer Pooling
                GroupBox("Buffer Pooling") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Buffer Pooling",
                               isOn: .constant(PerformanceOptimizationManager.MemoryOptimizations.enableBufferPooling))
                            .disabled(true)

                        HStack {
                            Text("Pool Size")
                            Spacer()
                            Text("\(PerformanceOptimizationManager.MemoryOptimizations.maxBufferPoolSize) buffers")
                                .foregroundColor(.secondary)
                        }

                        Text("Reuse audio buffers to eliminate allocations during playback")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Caching
                GroupBox("Caching") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Waveform Cache", isOn: $perfManager.enableCaching)

                        HStack {
                            Text("Max Cache Size")
                            Spacer()
                            Text("100 MB")
                                .foregroundColor(.secondary)
                        }

                        Button("Clear Cache") {
                            // Clear cache
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }

                // Physical Modeling Benefits
                GroupBox("Physical Modeling Benefits") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "Sample Libraries", value: "0 MB", highlight: true)
                        InfoRow(label: "Memory per Voice", value: "512 bytes")
                        InfoRow(label: "64 Voices", value: "32 KB")
                        InfoRow(label: "128 Voices", value: "64 KB")

                        Text("✨ Physical modeling uses virtually no memory compared to sample-based instruments!")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
}

struct MemoryBar: View {
    let label: String
    let used: UInt64
    let total: UInt64
    let color: Color

    var percentage: Double {
        return Double(used) / Double(total) * 100.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f%%", percentage))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100.0))
                }
            }
            .frame(height: 20)
            .cornerRadius(10)
        }
    }
}

// MARK: - Storage Management

struct StorageManagementView: View {
    @State private var projectTracks: Double = 16
    @State private var projectDuration: Double = 180  // seconds

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Storage Management")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Current Usage
                GroupBox("Current Storage") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "Project Files", value: "50 MB")
                        InfoRow(label: "Audio Recordings", value: "120 MB")
                        InfoRow(label: "Sample Libraries", value: "0 MB", highlight: true)
                        InfoRow(label: "Disk Cache", value: "25 MB")

                        Divider()

                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("195 MB")
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                }

                // Compression
                GroupBox("Compression") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Project Compression",
                               isOn: .constant(PerformanceOptimizationManager.StorageOptimizations.enableCompression))
                            .disabled(true)

                        HStack {
                            Text("Compression Ratio")
                            Spacer()
                            Text("70%")
                                .foregroundColor(.green)
                        }

                        Text("Lossless compression reduces project file size by ~70%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Project Size Calculator
                GroupBox("Project Size Estimator") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Number of Tracks")
                                Spacer()
                                Text("\(Int(projectTracks))")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $projectTracks, in: 1...128, step: 1)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Duration")
                                Spacer()
                                Text(formatDuration(projectDuration))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $projectDuration, in: 30...600, step: 30)
                        }

                        Divider()

                        let estimatedSize = PerformanceOptimizationManager.StorageOptimizations.estimatedProjectSize(
                            tracks: Int(projectTracks),
                            duration: projectDuration
                        )

                        HStack {
                            Text("Estimated Size")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(estimatedSize / (1024 * 1024)) MB")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                }

                // Storage Benefits
                GroupBox("Zero-Storage Advantages") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("✨ Physical modeling eliminates sample library storage:")
                            .font(.headline)

                        InfoRow(label: "Traditional Piano Library", value: "~10 GB")
                        InfoRow(label: "EOEL Physical Piano", value: "0 MB", highlight: true)

                        InfoRow(label: "Traditional Orchestra", value: "~100 GB")
                        InfoRow(label: "EOEL Physical Orchestra", value: "0 MB", highlight: true)

                        Text("Save hundreds of gigabytes with intelligent synthesis!")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .padding()
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}

// MARK: - Optimizations

struct OptimizationsView: View {
    @StateObject private var perfManager = PerformanceOptimizationManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Optimization Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Hardware Acceleration
                GroupBox("Hardware Acceleration") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("SIMD Instructions", isOn: $perfManager.enableSIMD)
                        Text("4-8x faster audio processing using vector instructions")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        Toggle("Metal GPU Acceleration", isOn: $perfManager.enableMetalAcceleration)
                        Text("GPU-accelerated FFT, video effects, and visualization")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        Toggle("Multithreading", isOn: $perfManager.enableMultithreading)
                        Text("Parallel processing on all CPU cores")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Caching
                GroupBox("Caching Strategy") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Caching", isOn: $perfManager.enableCaching)

                        if perfManager.enableCaching {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Waveform Cache",
                                       isOn: .constant(PerformanceOptimizationManager.MemoryOptimizations.enableWaveformCache))
                                    .disabled(true)
                                Toggle("Disk Cache",
                                       isOn: .constant(PerformanceOptimizationManager.StorageOptimizations.enableDiskCache))
                                    .disabled(true)
                                Toggle("Lazy Loading",
                                       isOn: .constant(PerformanceOptimizationManager.MemoryOptimizations.enableLazyLoading))
                                    .disabled(true)
                            }
                            .padding(.leading, 20)
                        }
                    }
                    .padding()
                }

                // CPU Priority
                GroupBox("CPU Scheduling") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Realtime Priority",
                               isOn: .constant(PerformanceOptimizationManager.CPUOptimizations.enableRealtimePriority))
                            .disabled(true)

                        Toggle("CPU Affinity",
                               isOn: .constant(PerformanceOptimizationManager.CPUOptimizations.enableCPUAffinity))
                            .disabled(true)

                        HStack {
                            Text("Max Threads")
                            Spacer()
                            Text("\(PerformanceOptimizationManager.CPUOptimizations.maxThreads)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
}

// MARK: - Recommendations

struct RecommendationsView: View {
    @StateObject private var perfManager = PerformanceOptimizationManager.shared
    @State private var recommendations: [PerformanceOptimizationManager.Recommendation] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Optimization Recommendations")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    recommendations = perfManager.getOptimizationRecommendations()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            if recommendations.isEmpty {
                ContentUnavailableView(
                    "All Systems Optimized",
                    systemImage: "checkmark.circle",
                    description: Text("Your system is running at peak performance")
                )
                .foregroundColor(.green)
            } else {
                List {
                    ForEach(recommendations) { rec in
                        RecommendationRow(recommendation: rec)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            recommendations = perfManager.getOptimizationRecommendations()
        }
    }
}

struct RecommendationRow: View {
    let recommendation: PerformanceOptimizationManager.Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForType(recommendation.type))
                    .foregroundColor(colorForType(recommendation.type))
                Text(recommendation.title)
                    .font(.headline)
            }

            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.secondary)

            Button(recommendation.action) {
                // Perform action
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }

    private func iconForType(_ type: PerformanceOptimizationManager.Recommendation.RecommendationType) -> String {
        switch type {
        case .critical: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func colorForType(_ type: PerformanceOptimizationManager.Recommendation.RecommendationType) -> Color {
        switch type {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(highlight ? .green : .secondary)
                .fontWeight(highlight ? .semibold : .regular)
        }
    }
}

#if DEBUG
struct PerformanceControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceControlPanelView()
            .frame(width: 1000, height: 700)
    }
}
#endif
