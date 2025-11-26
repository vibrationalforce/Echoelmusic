//
//  SettingsView.swift
//  EOEL
//
//  Created: 2025-11-24
//  Copyright © 2025 EOEL. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var audioEngine: EOELAudioEngine

    @State private var sampleRate: Double = 48000
    @State private var bufferSize: Int = 128
    @State private var enableLowLatency: Bool = true

    var body: some View {
        NavigationView {
            List {
                // Audio Settings
                Section("Audio") {
                    Picker("Sample Rate", selection: $sampleRate) {
                        Text("44.1 kHz").tag(44100.0)
                        Text("48 kHz").tag(48000.0)
                        Text("96 kHz").tag(96000.0)
                        Text("192 kHz").tag(192000.0)
                    }

                    Picker("Buffer Size", selection: $bufferSize) {
                        Text("64 samples").tag(64)
                        Text("128 samples").tag(128)
                        Text("256 samples").tag(256)
                        Text("512 samples").tag(512)
                    }

                    Toggle("Low Latency Mode", isOn: $enableLowLatency)

                    LabeledContent("Current Latency") {
                        Text("\(String(format: "%.2f", audioEngine.currentLatency * 1000))ms")
                            .foregroundColor(.secondary)
                    }
                }

                // Lighting Settings
                Section("Lighting") {
                    NavigationLink("Connected Systems") {
                        Text("Lighting Systems")
                    }
                    NavigationLink("Audio-Reactive Settings") {
                        Text("Audio-Reactive Config")
                    }
                }

                // EoelWork Settings
                Section("EoelWork") {
                    NavigationLink("Profile") {
                        Text("User Profile")
                    }
                    NavigationLink("Subscription") {
                        SubscriptionView()
                    }
                    NavigationLink("Industries") {
                        Text("Industry Preferences")
                    }
                }

                // Photonic Systems
                Section("Photonic Systems") {
                    NavigationLink("LiDAR Settings") {
                        Text("LiDAR Configuration")
                    }
                    NavigationLink("Laser Safety") {
                        Text("Safety Protocols")
                    }
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: "3.0.0")
                    LabeledContent("Build", value: "1")
                    NavigationLink("Licenses") {
                        Text("Open Source Licenses")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Subscription View

struct SubscriptionView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("EoelWork Monthly")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("$6.99/month")
                        .font(.title3)
                        .foregroundColor(.purple)

                    Text("Zero commission on all gigs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
            }

            Section {
                FeatureRow(icon: "checkmark.circle.fill", text: "Unlimited gig applications")
                FeatureRow(icon: "checkmark.circle.fill", text: "AI-powered matching")
                FeatureRow(icon: "checkmark.circle.fill", text: "8+ industries")
                FeatureRow(icon: "checkmark.circle.fill", text: "Emergency gig notifications")
                FeatureRow(icon: "checkmark.circle.fill", text: "Direct client messaging")
            }

            Section {
                Button(action: {}) {
                    Text("Subscribe Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(12)
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Subscription")
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(EOELAudioEngine.shared)
}
