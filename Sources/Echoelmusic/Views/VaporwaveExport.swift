import SwiftUI

// MARK: - Vaporwave Export View
// Export & Share im Vaporwave Palace Style

struct VaporwaveExport: View {

    // MARK: - Properties

    let sessionName: String

    @Environment(\.dismiss) var dismiss

    // MARK: - State

    @State private var selectedFormat: ExportFormat = .wav
    @State private var includeBioData = true
    @State private var includeVisuals = false
    @State private var selectedQuality: AudioQuality = .high
    @State private var selectedDestination: ExportDestination = .files
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportComplete = false

    // MARK: - Enums

    enum ExportFormat: String, CaseIterable {
        case wav = "WAV"
        case aiff = "AIFF"
        case mp3 = "MP3"
        case stems = "STEMS"

        var icon: String {
            switch self {
            case .wav: return "waveform"
            case .aiff: return "waveform.circle"
            case .mp3: return "music.note"
            case .stems: return "square.stack.3d.up"
            }
        }

        var description: String {
            switch self {
            case .wav: return "Lossless, DAW-ready"
            case .aiff: return "Apple lossless format"
            case .mp3: return "Compressed, shareable"
            case .stems: return "Separate bio-reactive layers"
            }
        }

        var color: Color {
            switch self {
            case .wav: return VaporwaveColors.neonCyan
            case .aiff: return VaporwaveColors.neonPurple
            case .mp3: return VaporwaveColors.neonPink
            case .stems: return VaporwaveColors.coherenceHigh
            }
        }
    }

    enum AudioQuality: String, CaseIterable {
        case standard = "44.1kHz / 16-bit"
        case high = "48kHz / 24-bit"
        case master = "96kHz / 32-bit"

        var label: String {
            switch self {
            case .standard: return "Standard"
            case .high: return "High"
            case .master: return "Master"
            }
        }
    }

    enum ExportDestination: String, CaseIterable {
        case files = "Files"
        case airdrop = "AirDrop"
        case cloud = "Cloud"
        case ableton = "Ableton"

        var icon: String {
            switch self {
            case .files: return "folder"
            case .airdrop: return "airplayaudio"
            case .cloud: return "icloud.and.arrow.up"
            case .ableton: return "square.and.arrow.up.on.square"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VaporwaveGradients.background
                .ignoresSafeArea()

            if exportComplete {
                exportCompleteView
            } else if isExporting {
                exportingView
            } else {
                exportOptionsView
            }
        }
    }

    // MARK: - Export Options View

    private var exportOptionsView: some View {
        ScrollView {
            VStack(spacing: VaporwaveSpacing.xl) {
                // Header
                header

                // Format Selection
                formatSection

                // Quality
                qualitySection

                // Options
                optionsSection

                // Destination
                destinationSection

                // Export Button
                exportButton

                Spacer(minLength: VaporwaveSpacing.xxl)
            }
            .padding(.horizontal, VaporwaveSpacing.lg)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPORT")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text(sessionName)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.neonPink)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(VaporwaveColors.textSecondary)
                }
                .accessibilityLabel("Close export")
            }
        }
        .padding(.top, VaporwaveSpacing.xl)
    }

    // MARK: - Format Section

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            sectionTitle("FORMAT")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: VaporwaveSpacing.md) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    FormatCard(
                        format: format,
                        isSelected: selectedFormat == format
                    )
                    .onTapGesture {
                        withAnimation(VaporwaveAnimation.smooth) {
                            selectedFormat = format
                        }
                    }
                }
            }
        }
    }

    struct FormatCard: View {
        let format: ExportFormat
        let isSelected: Bool

        var body: some View {
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: format.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? format.color : VaporwaveColors.textTertiary)

                Text(format.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? format.color : VaporwaveColors.textSecondary)

                Text(format.description)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(VaporwaveSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? format.color.opacity(0.15) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? format.color : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
            .neonGlow(color: isSelected ? format.color : .clear, radius: 10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(format.rawValue) format, \(format.description)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityHint("Double tap to select this export format")
        }
    }

    // MARK: - Quality Section

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            sectionTitle("QUALITY")

            HStack(spacing: VaporwaveSpacing.sm) {
                ForEach(AudioQuality.allCases, id: \.self) { quality in
                    Button(action: {
                        withAnimation(VaporwaveAnimation.smooth) {
                            selectedQuality = quality
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(quality.label)
                                .font(.system(size: 12, weight: .semibold))

                            Text(quality.rawValue)
                                .font(VaporwaveTypography.label())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VaporwaveSpacing.md)
                        .foregroundColor(selectedQuality == quality ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedQuality == quality ? VaporwaveColors.neonCyan.opacity(0.15) : Color.white.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedQuality == quality ? VaporwaveColors.neonCyan : Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            sectionTitle("OPTIONS")

            VStack(spacing: VaporwaveSpacing.sm) {
                optionToggle(
                    title: "Include Bio-Data",
                    subtitle: "Embed HRV, coherence as metadata",
                    icon: "heart.circle",
                    isOn: $includeBioData,
                    color: VaporwaveColors.heartRate
                )

                optionToggle(
                    title: "Include Visuals",
                    subtitle: "Export video with bio-reactive visuals",
                    icon: "sparkles.tv",
                    isOn: $includeVisuals,
                    color: VaporwaveColors.neonPurple
                )
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
    }

    private func optionToggle(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>,
        color: Color
    ) -> some View {
        HStack(spacing: VaporwaveSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isOn.wrappedValue ? color : VaporwaveColors.textTertiary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text(subtitle)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle(tint: color))
        }
    }

    // MARK: - Destination Section

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            sectionTitle("DESTINATION")

            HStack(spacing: VaporwaveSpacing.sm) {
                ForEach(ExportDestination.allCases, id: \.self) { destination in
                    Button(action: {
                        withAnimation(VaporwaveAnimation.smooth) {
                            selectedDestination = destination
                        }
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: destination.icon)
                                .font(.system(size: 24))

                            Text(destination.rawValue)
                                .font(VaporwaveTypography.label())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VaporwaveSpacing.md)
                        .foregroundColor(selectedDestination == destination ? VaporwaveColors.neonPink : VaporwaveColors.textTertiary)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedDestination == destination ? VaporwaveColors.neonPink.opacity(0.15) : Color.white.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedDestination == destination ? VaporwaveColors.neonPink : Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button(action: startExport) {
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))

                Text("EXPORT \(selectedFormat.rawValue)")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(VaporwaveColors.deepBlack)
            .frame(maxWidth: .infinity)
            .padding(VaporwaveSpacing.lg)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        selectedFormat.color,
                        selectedFormat.color.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .neonGlow(color: selectedFormat.color, radius: 15)
        }
        .accessibilityLabel("Export as \(selectedFormat.rawValue)")
        .accessibilityHint("Double tap to start export")
    }

    // MARK: - Exporting View

    private var exportingView: some View {
        VStack(spacing: VaporwaveSpacing.xl) {
            Spacer()

            // Animated ring
            ZStack {
                Circle()
                    .stroke(selectedFormat.color.opacity(0.2), lineWidth: 8)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: exportProgress)
                    .stroke(selectedFormat.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(Int(exportProgress * 100))%")
                        .font(VaporwaveTypography.data())
                        .foregroundColor(selectedFormat.color)

                    Text("Exporting...")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
            }
            .neonGlow(color: selectedFormat.color, radius: 20)

            Text("Creating \(selectedFormat.rawValue)")
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textSecondary)

            if includeBioData {
                Text("Embedding bio-data metadata...")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - Export Complete View

    private var exportCompleteView: some View {
        VStack(spacing: VaporwaveSpacing.xl) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(selectedFormat.color.opacity(0.2))
                    .frame(width: 150, height: 150)

                Image(systemName: "checkmark")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(selectedFormat.color)
            }
            .neonGlow(color: selectedFormat.color, radius: 25)

            Text("EXPORT COMPLETE")
                .font(VaporwaveTypography.sectionTitle())
                .foregroundColor(VaporwaveColors.textPrimary)

            Text("\(sessionName).\(selectedFormat.rawValue.lowercased())")
                .font(VaporwaveTypography.body())
                .foregroundColor(selectedFormat.color)

            Text("Saved to \(selectedDestination.rawValue)")
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textTertiary)

            Spacer()

            // Done button
            Button(action: { dismiss() }) {
                Text("DONE")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(VaporwaveSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.horizontal, VaporwaveSpacing.lg)
            .padding(.bottom, VaporwaveSpacing.xxl)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(VaporwaveColors.textTertiary)
            .tracking(2)
    }

    private func startExport() {
        isExporting = true
        exportProgress = 0

        // Simulate export progress
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            withAnimation(.linear(duration: 0.05)) {
                exportProgress += 0.02
            }

            if exportProgress >= 1.0 {
                timer.invalidate()
                withAnimation(VaporwaveAnimation.smooth) {
                    isExporting = false
                    exportComplete = true
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    VaporwaveExport(sessionName: "Morning Flow")
}
#endif
