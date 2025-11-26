//
//  DAWVideoTimelineView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  VIDEO TIMELINE - Sync audio with video
//

import SwiftUI

struct DAWVideoTimelineView: View {
    @StateObject private var videoSync = DAWVideoSync.shared
    @Binding var selectedTrack: UUID?
    @Binding var zoomLevel: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Video player
            VideoPlayerView()
                .frame(height: 400)

            Divider()

            // Video timeline
            Text("Video Timeline - Coming Soon")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct VideoPlayerView: View {
    var body: some View {
        ZStack {
            Color.black

            VStack {
                Spacer()

                Image(systemName: "play.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.7))

                Text("No video loaded")
                    .foregroundColor(.white.opacity(0.7))

                Spacer()
            }
        }
    }
}

#if DEBUG
struct DAWVideoTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        DAWVideoTimelineView(
            selectedTrack: .constant(nil),
            zoomLevel: .constant(1.0)
        )
        .frame(width: 1200, height: 700)
    }
}
#endif
