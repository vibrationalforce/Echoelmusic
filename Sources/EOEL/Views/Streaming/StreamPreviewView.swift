//
//  StreamPreviewView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025-11-25
//
//  STREAM PREVIEW - Live preview of stream output
//

import SwiftUI

struct StreamPreviewView: View {
    @StateObject private var liveEngine = LiveStreamingEngine.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Preview canvas
                Color.black

                if liveEngine.isStreaming {
                    // Live indicator
                    VStack {
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                Text("LIVE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)

                            Spacer()

                            // Stream health indicator
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(healthColor)
                                    .frame(width: 8, height: 8)
                                Text(liveEngine.streamHealth.rawValue)
                                    .font(.caption2)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                        }
                        .padding()

                        Spacer()
                    }
                } else {
                    // Offline placeholder
                    VStack(spacing: 20) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.3))

                        Text("Not Streaming")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))

                        Text("Click 'Go Live' to start streaming")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // Stream info overlay (bottom)
                VStack {
                    Spacer()

                    if liveEngine.isStreaming {
                        HStack(spacing: 20) {
                            // Bitrate
                            StatBadge(
                                icon: "speedometer",
                                value: "\(liveEngine.bitrate / 1_000_000) Mbps",
                                color: .blue
                            )

                            // Framerate
                            StatBadge(
                                icon: "camera.metering.multispot",
                                value: "\(Int(liveEngine.framerate)) fps",
                                color: .green
                            )

                            // Dropped frames
                            StatBadge(
                                icon: "exclamationmark.triangle",
                                value: "\(liveEngine.droppedFrames) dropped",
                                color: liveEngine.droppedFrames > 0 ? .orange : .gray
                            )

                            Spacer()

                            // Duration
                            Text(formatDuration(liveEngine.streamDuration))
                                .font(.system(.title3, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                        }
                        .padding()
                    }
                }
            }
        }
    }

    private var healthColor: Color {
        switch liveEngine.streamHealth {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .critical: return .red
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}

#if DEBUG
struct StreamPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        StreamPreviewView()
            .frame(width: 960, height: 540)
    }
}
#endif
