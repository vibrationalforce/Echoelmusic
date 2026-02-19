//
//  AUv3Theme.swift
//  EchoelmusicAUv3
//
//  Monochrome brand theme for Audio Unit plugin UIs.
//  Mirrors EchoelmusicBrand.swift — true black + two grays.
//  Matches echoelmusic.com website CI exactly.
//

import SwiftUI

// MARK: - Brand Colors (echoelmusic.com CI)

enum AUv3Brand {

    // MARK: - Backgrounds (true black + two grays)

    /// True black — primary background (#000000)
    static let bgDeep = Color.black

    /// Surface — cards, panels (#0A0A0A)
    static let bgSurface = Color(white: 0.04)

    /// Elevated — modals, sections (#141414)
    static let bgElevated = Color(white: 0.08)

    /// Glass overlay (white 3%)
    static let bgGlass = Color.white.opacity(0.03)

    // MARK: - Text (light gray #E0E0E0)

    /// Primary text — high emphasis (#E0E0E0)
    static let textPrimary = Color(red: 0.878, green: 0.878, blue: 0.878)

    /// Secondary text — 55% (#E0E0E0 @ 0.55)
    static let textSecondary = Color(red: 0.878, green: 0.878, blue: 0.878).opacity(0.55)

    /// Tertiary text — 35%
    static let textTertiary = Color(red: 0.878, green: 0.878, blue: 0.878).opacity(0.35)

    /// Disabled text — 20%
    static let textDisabled = Color(red: 0.878, green: 0.878, blue: 0.878).opacity(0.20)

    // MARK: - Accent

    /// Pure white — CTA, active states
    static let accent = Color.white

    // MARK: - Borders

    /// Default border (#E0E0E0 @ 8%)
    static let border = Color(red: 0.878, green: 0.878, blue: 0.878).opacity(0.08)

    /// Active/focused border (#E0E0E0 @ 30%)
    static let borderActive = Color(red: 0.878, green: 0.878, blue: 0.878).opacity(0.30)

    // MARK: - Functional Colors (bio-reactive only, NOT brand)

    /// Success / coherence high (#10B981)
    static let emerald = Color(red: 0.063, green: 0.725, blue: 0.506)

    /// Warning / coherence medium (#FBBF24)
    static let amber = Color(red: 0.984, green: 0.749, blue: 0.141)

    /// Error / coherence low (#FB7366)
    static let coral = Color(red: 0.984, green: 0.451, blue: 0.408)

    /// Info / clarity (#38BDF8)
    static let sky = Color(red: 0.220, green: 0.741, blue: 0.973)

    /// Heart (#F472B6)
    static let rose = Color(red: 0.957, green: 0.447, blue: 0.714)

    /// Creativity (#A78BFA)
    static let violet = Color(red: 0.655, green: 0.545, blue: 0.980)
}

// MARK: - Reusable Parameter Slider

struct AUParameterSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let format: String
    var multiplier: Float = 1
    let address: EchoelmusicParameterAddress
    let audioUnit: EchoelmusicAudioUnit

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(AUv3Brand.textSecondary)
                .frame(width: 60, alignment: .leading)

            Slider(value: $value, in: range)
                .tint(AUv3Brand.textPrimary)
                .onChange(of: value) { _, newValue in
                    audioUnit.parameterTree?.parameter(withAddress: address.rawValue)?.value = newValue
                }

            Text(String(format: format, value * multiplier))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(AUv3Brand.accent)
                .frame(width: 60, alignment: .trailing)
        }
    }
}

// MARK: - Reusable Parameter Section

struct AUParameterSection<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(AUv3Brand.textSecondary)
                .tracking(1.5)

            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AUv3Brand.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AUv3Brand.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - Plugin Header

struct AUv3PluginHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AUv3Brand.textPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AUv3Brand.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AUv3Brand.textTertiary)
            }

            Spacer()

            Text("echoel")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(AUv3Brand.textTertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Brand Divider

struct BrandDivider: View {
    var body: some View {
        Rectangle()
            .fill(AUv3Brand.border)
            .frame(height: 1)
    }
}

// MARK: - Pill Button (for mode selectors)

struct AUv3PillButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? AUv3Brand.accent : AUv3Brand.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.clear : AUv3Brand.border, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? AUv3Brand.bgDeep : AUv3Brand.textSecondary)
        }
    }
}
