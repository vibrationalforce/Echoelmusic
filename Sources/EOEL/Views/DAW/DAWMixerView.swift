//
//  DAWMixerView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  MIXER VIEW - Professional mixing console
//

import SwiftUI

struct DAWMixerView: View {
    @StateObject private var multiTrack = DAWMultiTrack.shared
    @Binding var selectedTrack: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 2) {
                // Track channels
                ForEach(multiTrack.tracks) { track in
                    MixerChannel(
                        track: track,
                        isSelected: selectedTrack == track.id,
                        onSelect: { selectedTrack = track.id }
                    )
                    .frame(width: 100)
                }

                // Master channel
                MasterChannel()
                    .frame(width: 120)
            }
            .padding()
        }
        .background(Color.black.opacity(0.9))
    }
}

struct MixerChannel: View {
    let track: DAWMultiTrack.Track
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var faderValue: Float = 0.8

    var body: some View {
        VStack(spacing: 8) {
            // Track name
            Text(track.name)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.white)

            // Plugin inserts
            VStack(spacing: 4) {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 30)
                        .overlay(
                            Text("Insert \(i + 1)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        )
                }
            }

            Spacer()

            // Meter
            VStack(spacing: 2) {
                LevelMeter(level: faderValue)
                    .frame(height: 200)
            }

            // Pan knob
            VStack(spacing: 4) {
                Text("PAN")
                    .font(.caption2)
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 35, height: 35)
                    )
            }

            // Fader
            VStack(spacing: 4) {
                VStack {
                    Slider(value: $faderValue, in: 0...1)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 40, height: 150)
                }
                .frame(height: 150)

                Text("\(Int(faderValue * 100))")
                    .font(.caption)
                    .foregroundColor(.white)
            }

            // Mute/Solo
            HStack(spacing: 4) {
                Button(action: {}) {
                    Text("M")
                        .font(.caption)
                        .foregroundColor(track.isMuted ? .white : .gray)
                        .frame(width: 30, height: 25)
                        .background(track.isMuted ? Color.red : Color.gray.opacity(0.3))
                        .cornerRadius(4)
                }

                Button(action: {}) {
                    Text("S")
                        .font(.caption)
                        .foregroundColor(track.isSoloed ? .white : .gray)
                        .frame(width: 30, height: 25)
                        .background(track.isSoloed ? Color.yellow : Color.gray.opacity(0.3))
                        .cornerRadius(4)
                }
            }

            // Record arm
            Button(action: {}) {
                Image(systemName: "record.circle.fill")
                    .foregroundColor(track.isArmed ? .red : .gray)
            }
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2))
        .cornerRadius(8)
        .onTapGesture {
            onSelect()
        }
    }
}

struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background
                Rectangle()
                    .fill(Color.black.opacity(0.5))

                // Level bars
                VStack(spacing: 1) {
                    ForEach(0..<20, id: \.self) { i in
                        let barLevel = Float(20 - i) / 20.0
                        Rectangle()
                            .fill(barColor(for: barLevel))
                            .opacity(level >= barLevel ? 1.0 : 0.3)
                    }
                }
            }
            .cornerRadius(4)
        }
    }

    private func barColor(for level: Float) -> Color {
        if level > 0.9 {
            return .red
        } else if level > 0.7 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct MasterChannel: View {
    @State private var masterFader: Float = 0.8

    var body: some View {
        VStack(spacing: 8) {
            Text("MASTER")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Master meter (stereo)
            HStack(spacing: 4) {
                LevelMeter(level: masterFader)
                LevelMeter(level: masterFader * 0.95)
            }
            .frame(height: 300)

            // Master fader
            VStack(spacing: 4) {
                VStack {
                    Slider(value: $masterFader, in: 0...1)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 40, height: 150)
                }
                .frame(height: 150)

                Text("\(Int(masterFader * 100))")
                    .font(.caption)
                    .foregroundColor(.white)
            }

            // Master controls
            VStack(spacing: 4) {
                Button(action: {}) {
                    Text("DIM")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 25)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(4)
                }

                Button(action: {}) {
                    Text("MONO")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 25)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(4)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }
}

#if DEBUG
struct DAWMixerView_Previews: PreviewProvider {
    static var previews: some View {
        DAWMixerView(selectedTrack: .constant(nil))
            .frame(width: 1200, height: 700)
    }
}
#endif
