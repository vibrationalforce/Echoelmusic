//
//  HearingSafetyView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Real-time hearing safety monitoring display
//

import SwiftUI

/// Hearing safety monitoring dashboard
struct HearingSafetyView: View {
    @ObservedObject var manager = HearingProtectionManager.shared

    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerView

            // Current level indicator
            currentLevelView

            // Exposure meter
            exposureMeterView

            // Today's summary
            todaySummaryView

            // Safety tips
            safetyTipsView

            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.9))
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "ear.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)

                Text("Hearing Safety")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // WHO badge
                Text("WHO 2019")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.3))
                    )
            }

            Text("Real-time hearing protection monitoring")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Current Level

    private var currentLevelView: some View {
        VStack(spacing: 12) {
            Text("Current Level")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            // Large dB display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(manager.currentDecibels))")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(decibelColor(manager.currentDecibels))

                Text("dB")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Safety indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(decibelColor(manager.currentDecibels))
                    .frame(width: 12, height: 12)

                Text(safetyLabel(manager.currentDecibels))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(decibelColor(manager.currentDecibels))
            }

            // Time remaining at current level
            if manager.currentDecibels >= 85 {
                Text("Safe time remaining: \(formattedTime(manager.getSafeTimeRemaining()))")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
        )
    }

    // MARK: - Exposure Meter

    private var exposureMeterView: some View {
        let summary = manager.getTodayExposureSummary()

        return VStack(spacing: 12) {
            HStack {
                Text("Today's Exposure")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text("\(Int(summary.percentage))%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(summary.riskLevel.color)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))

                    // Fill
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: exposureGradientColors(summary.percentage),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(min(summary.percentage / 100, 1.5)))

                    // Warning markers
                    VStack {
                        Spacer()
                        HStack(spacing: 0) {
                            Spacer()
                                .frame(width: geometry.size.width * 0.80)
                            Rectangle()
                                .fill(Color.orange)
                                .frame(width: 2, height: 20)
                            Spacer()
                                .frame(width: geometry.size.width * 0.20 - 2)
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: 20)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 20)

            // Stats
            HStack {
                statItem(label: "Used", value: summary.formattedTotalTime, color: .cyan)
                Spacer()
                statItem(label: "Remaining", value: summary.formattedRemainingTime, color: .green)
                Spacer()
                statItem(label: "Risk", value: summary.riskLevel.rawValue, color: summary.riskLevel.color)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
        )
    }

    // MARK: - Today's Summary

    private var todaySummaryView: some View {
        let summary = manager.getTodayExposureSummary()

        return VStack(spacing: 12) {
            Text("Today's Statistics")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 16) {
                summaryCard(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Average",
                    value: "\(Int(summary.averageDecibels)) dB",
                    color: .blue
                )

                summaryCard(
                    icon: "waveform.path.ecg",
                    label: "Peak",
                    value: "\(Int(summary.maxDecibels)) dB",
                    color: .red
                )

                summaryCard(
                    icon: "clock.fill",
                    label: "Total Time",
                    value: summary.formattedTotalTime,
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
        )
    }

    // MARK: - Safety Tips

    private var safetyTipsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Safety Guidelines")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "checkmark.circle.fill", text: "Keep volume below 85 dB for unlimited use", color: .green)
                tipRow(icon: "exclamationmark.triangle.fill", text: "Take 15-minute breaks every hour", color: .orange)
                tipRow(icon: "speaker.wave.2.fill", text: "Use over-ear headphones for better safety", color: .cyan)
                tipRow(icon: "moon.fill", text: "Give your ears 18 hours rest after loud exposure", color: .purple)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
        )
    }

    // MARK: - Helper Views

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private func summaryCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.15))
        )
    }

    private func tipRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16)

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Helper Functions

    private func decibelColor(_ dB: Float) -> Color {
        switch dB {
        case ..<70:
            return .green
        case 70..<85:
            return .yellow
        case 85..<100:
            return .orange
        case 100..<110:
            return .red
        default:
            return .purple
        }
    }

    private func safetyLabel(_ dB: Float) -> String {
        switch dB {
        case ..<70:
            return "Safe"
        case 70..<85:
            return "Moderate"
        case 85..<100:
            return "Caution"
        case 100..<110:
            return "Unsafe"
        default:
            return "Danger"
        }
    }

    private func exposureGradientColors(_ percentage: Float) -> [Color] {
        if percentage < 50 {
            return [.green, .green]
        } else if percentage < 80 {
            return [.green, .yellow]
        } else if percentage < 100 {
            return [.yellow, .orange]
        } else if percentage < 120 {
            return [.orange, .red]
        } else {
            return [.red, .purple]
        }
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        if seconds <= 0 {
            return "Limit reached"
        }

        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HearingSafetyView_Previews: PreviewProvider {
    static var previews: some View {
        HearingSafetyView()
    }
}
#endif
