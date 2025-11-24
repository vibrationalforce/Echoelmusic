//
//  VideoEditorView.swift
//  EOEL
//
//  Created: 2025-11-24
//  Copyright © 2025 EOEL. All rights reserved.
//

import SwiftUI
import AVKit

struct VideoEditorView: View {
    @State private var clips: [VideoClip] = []
    @State private var selectedClip: VideoClip?
    @State private var currentTime: Double = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Video Preview
                VideoPreview(currentTime: $currentTime)
                    .frame(height: 300)

                // Timeline
                TimelineView(clips: $clips, currentTime: $currentTime)
                    .frame(height: 150)

                // Tools
                VideoToolbar()
            }
            .navigationTitle("Video Editor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: importVideo) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
    }

    private func importVideo() {
        // Import video clip
    }
}

// MARK: - Video Preview

struct VideoPreview: View {
    @Binding var currentTime: Double

    var body: some View {
        ZStack {
            Color.black

            Text("Video Preview")
                .foregroundColor(.white)
        }
    }
}

// MARK: - Timeline View

struct TimelineView: View {
    @Binding var clips: [VideoClip]
    @Binding var currentTime: Double

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(clips) { clip in
                    ClipThumbnail(clip: clip)
                }
            }
            .padding()
        }
        .background(Color(.systemGray6))
    }
}

struct ClipThumbnail: View {
    let clip: VideoClip

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.blue)
            .frame(width: 100, height: 60)
            .overlay(
                Text(clip.name)
                    .font(.caption)
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Video Toolbar

struct VideoToolbar: View {
    var body: some View {
        HStack {
            Button(action: {}) {
                Label("Cut", systemImage: "scissors")
            }

            Spacer()

            Button(action: {}) {
                Label("Effects", systemImage: "sparkles")
            }

            Spacer()

            Button(action: {}) {
                Label("Transitions", systemImage: "wand.and.stars")
            }

            Spacer()

            Button(action: {}) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Supporting Types

struct VideoClip: Identifiable {
    let id = UUID()
    var name: String
    var duration: Double
    var thumbnailURL: URL?
}

// MARK: - Preview

#Preview {
    VideoEditorView()
}
