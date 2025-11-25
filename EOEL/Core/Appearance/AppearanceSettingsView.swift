//
//  AppearanceSettingsView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  User interface for appearance and eye health settings
//

import SwiftUI

/// Appearance settings configuration view
struct AppearanceSettingsView: View {
    @ObservedObject var manager = AppearanceManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerView

                // Dark Mode section
                darkModeSection

                // Blue Light Filter section
                blueLightFilterSection

                // Eye Health section
                eyeHealthSection

                // Presets
                presetsSection
            }
            .padding()
        }
        .background(Color.black.opacity(0.95))
        .blueLightFilter()  // Apply filter to this view too!
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "eye.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)

                Text("Appearance & Eye Health")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            Text("Reduce eye strain and improve sleep quality")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Dark Mode Section

    private var darkModeSection: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "moon.fill", title: "Dark Mode", color: .purple)

            // Follow system
            Toggle(isOn: $manager.followSystemAppearance) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Follow System")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Text("Use device appearance settings")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .tint(.purple)
            .onChange(of: manager.followSystemAppearance) { value in
                manager.setFollowSystemAppearance(value)
            }

            if !manager.followSystemAppearance {
                // Manual dark mode toggle
                Toggle(isOn: $manager.darkModeEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dark Mode")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)

                        Text("Easier on the eyes in low light")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .tint(.purple)
                .onChange(of: manager.darkModeEnabled) { value in
                    manager.setDarkMode(value)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
        )
    }

    // MARK: - Blue Light Filter Section

    private var blueLightFilterSection: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "sun.max.fill", title: "Blue Light Filter", color: .orange)

            // Enable filter
            Toggle(isOn: $manager.blueLightFilterEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blue Light Filter")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Text("Reduce eye strain and improve sleep")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .tint(.orange)
            .onChange(of: manager.blueLightFilterEnabled) { value in
                manager.enableBlueLightFilter(value)
            }

            if manager.blueLightFilterEnabled {
                VStack(spacing: 12) {
                    // Intensity slider
                    VStack(spacing: 8) {
                        HStack {
                            Text("Intensity")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            Text("\(Int(manager.blueLightIntensity * 100))%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "sun.max")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))

                            Slider(
                                value: Binding(
                                    get: { Double(manager.blueLightIntensity) },
                                    set: { manager.setBlueLightIntensity(Float($0)) }
                                ),
                                in: 0...1
                            )
                            .tint(.orange)

                            Image(systemName: "moon.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }

                    // Color temperature display
                    HStack {
                        Text("Color Temperature")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))

                        Spacer()

                        Text("\(Int(manager.colorTemperature))K")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                    }

                    // Visual preview
                    HStack(spacing: 8) {
                        Text("Preview:")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))

                        HStack(spacing: 4) {
                            colorSample(.white, label: "Off")
                            colorSample(manager.blueLightTint, label: "On")
                        }
                    }
                }
                .padding(.top, 8)
            }

            // Auto schedule
            Toggle(isOn: $manager.autoScheduleEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatic Schedule")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Text("Enable at sunset, disable at sunrise")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .tint(.orange)
            .onChange(of: manager.autoScheduleEnabled) { value in
                manager.setAutoSchedule(value)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
        )
    }

    // MARK: - Eye Health Section

    private var eyeHealthSection: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "eye.circle.fill", title: "Eye Health", color: .green)

            // Break reminders
            Toggle(isOn: $manager.breakReminderEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Break Reminders")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Text("20-20-20 rule: Every 20 min, look 20 ft away for 20 sec")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(.green)
            .onChange(of: manager.breakReminderEnabled) { value in
                manager.setBreakReminders(value)
            }

            if manager.breakReminderEnabled {
                // Break interval
                VStack(spacing: 8) {
                    HStack {
                        Text("Reminder Interval")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Spacer()

                        Text("\(manager.breakIntervalMinutes) min")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(manager.breakIntervalMinutes) },
                            set: { manager.setBreakInterval(Int($0)) }
                        ),
                        in: 5...60,
                        step: 5
                    )
                    .tint(.green)
                }
                .padding(.top, 8)
            }

            // Health tips
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.cyan)
                    Text("Eye Health Tips")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    tipText("Keep screen 20-26 inches from eyes")
                    tipText("Reduce screen brightness in dark rooms")
                    tipText("Blink frequently to prevent dry eyes")
                    tipText("Use larger text to reduce strain")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cyan.opacity(0.1))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
        )
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "sparkles", title: "Quick Presets", color: .yellow)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                presetButton("Day Mode", icon: "sun.max.fill", color: .blue) {
                    manager.applyPreset(.dayMode)
                }

                presetButton("Night Mode", icon: "moon.stars.fill", color: .indigo) {
                    manager.applyPreset(.nightMode)
                }

                presetButton("Eye Comfort", icon: "eye.fill", color: .green) {
                    manager.applyPreset(.eyeComfort)
                }

                presetButton("No Filter", icon: "xmark.circle.fill", color: .gray) {
                    manager.applyPreset(.noFilter)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
        )
    }

    // MARK: - Helper Views

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer()
        }
    }

    private func colorSample(_ color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private func tipText(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text("•")
                .foregroundColor(.cyan)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private func presetButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSettingsView()
    }
}
#endif
