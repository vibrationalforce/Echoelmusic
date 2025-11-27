//
//  DAWView.swift
//  Echoelmusic
//
//  Created: 2025-11-24
//  Copyright © 2025 Echoelmusic. All rights reserved.
//

import SwiftUI

struct DAWView: View {
    @EnvironmentObject var audioEngine: EchoelmusicAudioEngine
    @State private var tracks: [AudioTrack] = []
    @State private var selectedTrack: AudioTrack?
    @State private var isPlaying: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Transport Controls
                TransportBar(isPlaying: $isPlaying)

                // Track List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(tracks) { track in
                            TrackRow(track: track, isSelected: selectedTrack?.id == track.id)
                                .onTapGesture {
                                    selectedTrack = track
                                }
                        }
                    }
                    .padding()
                }

                // Bottom Toolbar
                BottomToolbar()
            }
            .navigationTitle("DAW")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addTrack) {
                        Label("Add Track", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .onAppear {
            loadDefaultTracks()
        }
    }

    private func addTrack() {
        let newTrack = audioEngine.createTrack(name: "Track \(tracks.count + 1)")
        tracks.append(newTrack)
    }

    private func loadDefaultTracks() {
        // Load default tracks
        for i in 1...8 {
            let track = audioEngine.createTrack(name: "Track \(i)")
            tracks.append(track)
        }
    }
}

// MARK: - Transport Bar

struct TransportBar: View {
    @Binding var isPlaying: Bool

    var body: some View {
        HStack(spacing: 20) {
            Button(action: { /* Rewind */ }) {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Rewind")
            .accessibilityHint("Jump back to previous position")

            Button(action: { isPlaying.toggle() }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            .accessibilityHint(isPlaying ? "Pause playback" : "Start playback")
            .accessibilityAddTraits(.startsMediaSession)

            Button(action: { /* Stop */ }) {
                Image(systemName: "stop.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Stop")
            .accessibilityHint("Stop playback and return to start")

            Button(action: { /* Record */ }) {
                Image(systemName: "record.circle")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            .accessibilityLabel("Record")
            .accessibilityHint("Start recording audio")
            .accessibilityAddTraits(.startsMediaSession)

            Spacer()

            Text("00:00:00")
                .font(.system(.body, design: .monospaced))
                .accessibilityLabel("Time position: 0 hours, 0 minutes, 0 seconds")
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Track Row

struct TrackRow: View {
    let track: AudioTrack
    let isSelected: Bool

    var body: some View {
        HStack {
            // Track Color
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.purple)
                .frame(width: 4)

            // Track Name
            Text(track.name)
                .font(.headline)

            Spacer()

            // Volume Control
            Image(systemName: track.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .foregroundColor(track.muted ? .red : .primary)
                .accessibilityLabel(track.muted ? "Muted" : "Unmuted")
                .accessibilityHint("Volume indicator")

            // Solo Button
            Button(action: { /* Toggle solo */ }) {
                Text("S")
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 24, height: 24)
                    .background(track.solo ? Color.yellow : Color.gray.opacity(0.3))
                    .cornerRadius(4)
            }
            .accessibilityLabel("Solo")
            .accessibilityValue(track.solo ? "On" : "Off")
            .accessibilityHint("Play only this track")
            .accessibilityAddTraits(track.solo ? [.isButton, .isSelected] : .isButton)

            // Mute Button
            Button(action: { /* Toggle mute */ }) {
                Text("M")
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 24, height: 24)
                    .background(track.muted ? Color.red : Color.gray.opacity(0.3))
                    .cornerRadius(4)
            }
            .accessibilityLabel("Mute")
            .accessibilityValue(track.muted ? "On" : "Off")
            .accessibilityHint("Silence this track")
            .accessibilityAddTraits(track.muted ? [.isButton, .isSelected] : .isButton)
        }
        .padding()
        .background(isSelected ? Color.purple.opacity(0.2) : Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Bottom Toolbar

struct BottomToolbar: View {
    var body: some View {
        HStack {
            Button(action: {}) {
                Label("Instruments", systemImage: "pianokeys")
            }

            Spacer()

            Button(action: {}) {
                Label("Effects", systemImage: "waveform.badge.magnifyingglass")
            }

            Spacer()

            Button(action: {}) {
                Label("Mixer", systemImage: "slider.horizontal.3")
            }

            Spacer()

            Button(action: {}) {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Preview

#Preview {
    DAWView()
        .environmentObject(EchoelmusicAudioEngine.shared)
}
