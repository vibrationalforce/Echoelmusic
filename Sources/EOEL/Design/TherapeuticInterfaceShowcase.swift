//
//  TherapeuticInterfaceShowcase.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Therapeutic Interface Showcase
//  Complete integration of scientifically-backed color therapy + Adey windows
//  Health-optimized interface with circadian rhythm support
//

import SwiftUI

/// Therapeutic interface combining color therapy and frequency optimization
struct TherapeuticInterfaceShowcase: View {
    @StateObject private var therapyTheme = TherapeuticThemeManager.shared
    @StateObject private var frequencyOptimizer = BiologicalFrequencyOptimizer.shared
    @State private var selectedTab = 0
    @State private var showHealthInfo = false

    var body: some View {
        ZStack {
            // Health-optimized background
            therapyTheme.currentTheme.primaryColor
                .opacity(0.1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with health status
                headerView

                // Content
                TabView(selection: $selectedTab) {
                    colorTherapyView
                        .tag(0)

                    frequencyOptimizationView
                        .tag(1)

                    circadianModeView
                        .tag(2)

                    healthGuidelinesView
                        .tag(3)
                }
                .tabViewStyle(.automatic)
            }

            // Health info overlay
            if showHealthInfo {
                healthInfoOverlay
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("THERAPEUTIC INTERFACE")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(therapyTheme.currentTheme.primaryColor)

                Text("Science-Backed Color & Frequency Therapy")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Health indicators
            HStack(spacing: 12) {
                // Blue light status
                if therapyTheme.currentTheme.shouldAvoidBlueLight {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.orange)
                        Text("Blue Light Protected")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
                }

                // Frequency status
                if frequencyOptimizer.isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("\(String(format: "%.1f", frequencyOptimizer.currentWindow.frequency)) Hz")
                            .font(.caption2.monospaced())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                }

                Button {
                    showHealthInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }

    // MARK: - Color Therapy View

    private var colorTherapyView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Theme selector
                VStack(alignment: .leading, spacing: 16) {
                    Text("THERAPEUTIC THEMES")
                        .font(.headline)
                        .foregroundColor(therapyTheme.currentTheme.primaryColor)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(TherapeuticColorSystem.TherapeuticTheme.allCases, id: \.self) { theme in
                            TherapeuticThemeCard(theme: theme)
                        }
                    }
                }

                // Wavelength spectrum
                VStack(alignment: .leading, spacing: 16) {
                    Text("WAVELENGTH SPECTRUM")
                        .font(.headline)
                        .foregroundColor(therapyTheme.currentTheme.primaryColor)

                    wavelengthSpectrumView
                }

                // Current theme info
                TherapeuticThemeInfoCard(theme: therapyTheme.currentTheme)
            }
            .padding()
        }
    }

    private var wavelengthSpectrumView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach([
                    ("Red\n660nm", TherapeuticColorSystem.WavelengthColors.healingRed, "Healing"),
                    ("Orange\n590nm", TherapeuticColorSystem.WavelengthColors.vitalityOrange, "Vitality"),
                    ("Yellow\n580nm", TherapeuticColorSystem.WavelengthColors.clarityYellow, "Clarity"),
                    ("Green\n520nm", TherapeuticColorSystem.WavelengthColors.eyeComfortGreen, "Comfort"),
                    ("Cyan\n490nm", TherapeuticColorSystem.WavelengthColors.calmingCyan, "Calming"),
                    ("Blue\n480nm", TherapeuticColorSystem.WavelengthColors.circadianBlue, "Circadian"),
                    ("Violet\n420nm", TherapeuticColorSystem.WavelengthColors.deepViolet, "Antimicrobial")
                ], id: \.0) { name, color, effect in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(color)
                            .frame(height: 80)
                            .shadow(color: color.opacity(0.6), radius: 8)

                        Text(name)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)

                        Text(effect)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .cornerRadius(8)
        }
    }

    // MARK: - Frequency Optimization View

    private var frequencyOptimizationView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Entrainment visualization
                VStack(spacing: 16) {
                    Text("BRAINWAVE ENTRAINMENT")
                        .font(.headline)
                        .foregroundColor(therapyTheme.currentTheme.primaryColor)

                    BrainwaveEntrainmentCircle(
                        optimizer: frequencyOptimizer,
                        color: therapyTheme.currentTheme.primaryColor,
                        size: 200
                    )
                }

                // Frequency windows
                VStack(alignment: .leading, spacing: 16) {
                    Text("ADEY WINDOWS")
                        .font(.headline)
                        .foregroundColor(therapyTheme.currentTheme.primaryColor)

                    ForEach(BiologicalFrequencyOptimizer.FrequencyWindow.allCases) { window in
                        FrequencyWindowCard(window: window)
                    }
                }

                // Controls
                VStack(spacing: 12) {
                    Text("SESSION CONTROL")
                        .font(.headline)
                        .foregroundColor(therapyTheme.currentTheme.primaryColor)

                    HStack {
                        Button(frequencyOptimizer.isActive ? "Stop" : "Start") {
                            if frequencyOptimizer.isActive {
                                frequencyOptimizer.stop()
                            } else {
                                frequencyOptimizer.start(window: .alphaRelaxation)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(therapyTheme.currentTheme.primaryColor)

                        Button("5 Min Session") {
                            frequencyOptimizer.startSession(window: .alphaRelaxation, duration: 300)
                        }
                        .buttonStyle(.bordered)

                        Button("15 Min Session") {
                            frequencyOptimizer.startSession(window: .alphaRelaxation, duration: 900)
                        }
                        .buttonStyle(.bordered)
                    }

                    if let session = frequencyOptimizer.currentSession {
                        Text("Remaining: \(Int(session.remainingTime / 60)):\(String(format: "%02d", Int(session.remainingTime) % 60))")
                            .font(.caption.monospaced())
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Circadian Mode View

    private var circadianModeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Auto mode toggle
                VStack(alignment: .leading, spacing: 16) {
                    Text("CIRCADIAN RHYTHM OPTIMIZATION")
                        .font(.headline)
                        .foregroundColor(therapyTheme.currentTheme.primaryColor)

                    Toggle("Auto Circadian Mode", isOn: $therapyTheme.autoCircadianMode)
                        .onChange(of: therapyTheme.autoCircadianMode) { _ in
                            therapyTheme.updateCircadianMode()
                        }

                    Text("Automatically adjusts colors based on time of day to support your natural circadian rhythm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                // Time-based recommendations
                VStack(alignment: .leading, spacing: 16) {
                    Text("24-HOUR COLOR SCHEDULE")
                        .font(.headline)
                        .foregroundColor(therapyTheme.currentTheme.primaryColor)

                    ForEach([
                        (6, "Morning (6-8am)", "Sunrise", "3000K - Gentle wake, warm white"),
                        (10, "Midday (8am-12pm)", "Morning", "5500K - Full alertness, cool white"),
                        (14, "Afternoon (12-6pm)", "Midday", "6500K - Peak performance, daylight"),
                        (19, "Evening (6-8pm)", "Evening", "3500K - Wind down, soft amber"),
                        (22, "Night (8-10pm)", "Night", "2700K - Melatonin friendly, warm amber"),
                        (23, "Sleep (10pm-6am)", "Sleep", "2000K - Deep red, no blue light")
                    ], id: \.0) { hour, name, temp, desc in
                        circadianTimeCard(hour: hour, name: name, temp: temp, description: desc)
                    }
                }
            }
            .padding()
        }
    }

    private func circadianTimeCard(hour: Int, name: String, temp: String, description: String) -> some View {
        let colorTemp = TherapeuticColorSystem.CircadianOptimizer.colorTemperatureForTime(hour)

        return HStack {
            Rectangle()
                .fill(colorTemp.color)
                .frame(width: 60, height: 60)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Health Guidelines View

    private var healthGuidelinesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Blue light warning
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Blue Light Advisory")
                            .font(.headline)
                    }

                    Text(TherapeuticColorSystem.HealthGuidelines.blueLightWarning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)

                // Photosensitivity warning
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Photosensitivity Warning")
                            .font(.headline)
                    }

                    Text(TherapeuticColorSystem.HealthGuidelines.photosensitivityWarning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)

                // Medical disclaimer
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        Text("Medical Disclaimer")
                            .font(.headline)
                    }

                    Text(TherapeuticColorSystem.HealthGuidelines.therapeuticDisclaimer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                // Research references
                VStack(alignment: .leading, spacing: 12) {
                    Text("RESEARCH REFERENCES")
                        .font(.headline)

                    researchReferenceCard(BiologicalFrequencyOptimizer.adeyResearch)
                    researchReferenceCard(BiologicalFrequencyOptimizer.circadianBlueLight)
                    researchReferenceCard(BiologicalFrequencyOptimizer.photobiomodulation)
                }
            }
            .padding()
        }
    }

    private func researchReferenceCard(_ ref: BiologicalFrequencyOptimizer.ResearchReference) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ref.title)
                .font(.caption)
                .fontWeight(.semibold)

            Text("\(ref.authors) • \(ref.journal) • \(ref.year)")
                .font(.caption2)
                .foregroundColor(.secondary)

            if let pubmedID = ref.pubmedID {
                Text("PubMed ID: \(pubmedID)")
                    .font(.caption2.monospaced())
                    .foregroundColor(.blue)
            }

            Text(ref.summary)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Health Info Overlay

    private var healthInfoOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    showHealthInfo = false
                }

            VStack(spacing: 20) {
                Text("HEALTH & SAFETY")
                    .font(.title2)
                    .fontWeight(.bold)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("This therapeutic interface uses scientifically-backed principles:")
                            .font(.caption)

                        Text("• Wavelength-based colors (630-420nm)")
                        Text("• Adey window frequencies (0.5-100 Hz)")
                        Text("• Circadian rhythm optimization")
                        Text("• Blue light management")

                        Divider()

                        Text("Always consult a healthcare provider for:")
                        Text("• Medical conditions")
                        Text("• Epilepsy or seizure disorders")
                        Text("• Photosensitivity")
                        Text("• Migraine with aura")

                        Divider()

                        Text("Research-backed but not FDA approved for treatment.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }

                Button("Close") {
                    showHealthInfo = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(16)
        }
    }
}

// MARK: - Therapeutic Theme Card

struct TherapeuticThemeCard: View {
    let theme: TherapeuticColorSystem.TherapeuticTheme
    @ObservedObject var manager = TherapeuticThemeManager.shared

    var body: some View {
        Button {
            manager.currentTheme = theme
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(theme.primaryColor)
                        .frame(width: 24, height: 24)
                        .shadow(color: theme.primaryColor, radius: 4)

                    Circle()
                        .fill(theme.secondaryColor)
                        .frame(width: 16, height: 16)
                }

                Text(theme.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("\(Int(theme.blueLightPercentage))% blue light")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                manager.currentTheme == theme ?
                theme.primaryColor.opacity(0.2) :
                Color.gray.opacity(0.1)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        manager.currentTheme == theme ? theme.primaryColor : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Therapeutic Theme Info

struct TherapeuticThemeInfoCard: View {
    let theme: TherapeuticColorSystem.TherapeuticTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT THEME INFO")
                .font(.headline)
                .foregroundColor(theme.primaryColor)

            VStack(alignment: .leading, spacing: 8) {
                infoRow(title: "Theme", value: theme.rawValue)
                infoRow(title: "Blue Light", value: "\(Int(theme.blueLightPercentage))%")
                infoRow(title: "Description", value: theme.description)

                if theme.shouldAvoidBlueLight {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.orange)
                        Text("Evening Mode - Blue light minimized for sleep")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text("\(title):")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Frequency Window Card

struct FrequencyWindowCard: View {
    let window: BiologicalFrequencyOptimizer.FrequencyWindow
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(window.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("\(String(format: "%.2f", window.frequency)) Hz")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(window.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Effects:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    ForEach(window.biologicalEffects, id: \.self) { effect in
                        Text("• \(effect)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(window.safetyNotes)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview("Therapeutic Interface") {
    TherapeuticInterfaceShowcase()
        .frame(minWidth: 1000, minHeight: 800)
}
