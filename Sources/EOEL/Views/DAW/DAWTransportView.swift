//
//  DAWTransportView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  TRANSPORT CONTROLS - Play, Stop, Record, Loop, etc.
//

import SwiftUI

struct DAWTransportView: View {
    @StateObject private var timeline = DAWTimelineEngine.shared
    @StateObject private var multiTrack = DAWMultiTrack.shared
    @StateObject private var tempoMap = DAWTempoMap.shared

    @State private var isPlaying: Bool = false
    @State private var isRecording: Bool = false
    @State private var isLooping: Bool = false
    @State private var currentTime: TimeInterval = 0.0
    @State private var tempo: Double = 120.0
    @State private var timeSignature: DAWTimelineEngine.TimeSignature = .fourFour

    var body: some View {
        HStack(spacing: 30) {
            // Left: Transport buttons
            HStack(spacing: 15) {
                // Return to start
                Button(action: returnToStart) {
                    Image(systemName: "backward.end.fill")
                        .font(.title)
                }

                // Play/Pause
                Button(action: togglePlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .foregroundColor(isPlaying ? .green : .primary)

                // Stop
                Button(action: stop) {
                    Image(systemName: "stop.fill")
                        .font(.title)
                }

                // Record
                Button(action: toggleRecord) {
                    Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                        .font(.title)
                }
                .foregroundColor(isRecording ? .red : .primary)

                // Loop
                Button(action: { isLooping.toggle() }) {
                    Image(systemName: "repeat")
                        .font(.title)
                }
                .foregroundColor(isLooping ? .orange : .primary)
            }

            Divider()

            // Center: Time display
            VStack(alignment: .leading, spacing: 4) {
                // Time code
                Text(formatTime(currentTime))
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.medium)

                // Bar/beat/tick
                Text(formatBarsBeatsTicks(currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 150)

            Divider()

            // Tempo & Time Signature
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tempo:")
                        .font(.caption)
                    Text("\(Int(tempo)) BPM")
                        .font(.headline)
                }

                HStack {
                    Text("Time:")
                        .font(.caption)
                    Text("\(timeSignature.numerator)/\(timeSignature.denominator)")
                        .font(.headline)
                }
            }

            Divider()

            // Right: Additional controls
            HStack(spacing: 15) {
                // Metronome
                Button(action: {}) {
                    VStack(spacing: 2) {
                        Image(systemName: "metronome")
                        Text("Click")
                            .font(.caption2)
                    }
                }

                // Punch in/out
                Button(action: {}) {
                    VStack(spacing: 2) {
                        Image(systemName: "target")
                        Text("Punch")
                            .font(.caption2)
                    }
                }

                // Snap to grid
                Button(action: {}) {
                    VStack(spacing: 2) {
                        Image(systemName: "grid")
                        Text("Snap")
                            .font(.caption2)
                    }
                }

                // Count-in
                Button(action: {}) {
                    VStack(spacing: 2) {
                        Image(systemName: "timer")
                        Text("Count")
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 15)
        .background(Color.gray.opacity(0.1))
    }

    private func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            play()
        } else {
            pause()
        }
    }

    private func play() {
        print("▶️ Play")
    }

    private func pause() {
        print("⏸️ Pause")
    }

    private func stop() {
        isPlaying = false
        isRecording = false
        currentTime = 0.0
        print("⏹️ Stop")
    }

    private func toggleRecord() {
        isRecording.toggle()
        if isRecording && !isPlaying {
            isPlaying = true
            play()
        }
        print("🔴 Record: \(isRecording)")
    }

    private func returnToStart() {
        currentTime = 0.0
        print("⏮️ Return to start")
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let frames = Int((time.truncatingRemainder(dividingBy: 1)) * 30) // 30 fps

        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    private func formatBarsBeatsTicks(_ time: TimeInterval) -> String {
        let bpm = tempo
        let beatDuration = 60.0 / bpm
        let barDuration = beatDuration * Double(timeSignature.numerator)

        let bar = Int(time / barDuration) + 1
        let beat = Int((time.truncatingRemainder(dividingBy: barDuration)) / beatDuration) + 1
        let tick = Int(((time.truncatingRemainder(dividingBy: beatDuration)) / beatDuration) * 480) // 480 ticks per beat

        return String(format: "%d.%d.%03d", bar, beat, tick)
    }
}

#if DEBUG
struct DAWTransportView_Previews: PreviewProvider {
    static var previews: some View {
        DAWTransportView()
            .frame(width: 1200, height: 80)
    }
}
#endif
