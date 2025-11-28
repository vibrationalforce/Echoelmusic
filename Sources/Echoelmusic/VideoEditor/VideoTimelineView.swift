//
//  VideoTimelineView.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Professional Video Timeline View (Clean MVVM Architecture)
//
//  This file contains ONLY View components.
//  Business logic is in VideoTimelineViewModel.swift
//  Data models are in VideoTimelineModels.swift
//

import SwiftUI

// MARK: - Main Timeline View

public struct VideoTimelineView: View {
    @StateObject private var viewModel = VideoTimelineViewModel()
    @State private var showingEffectPicker = false
    @State private var selectedClipForEffects: UUID?

    private let trackHeaderWidth: CGFloat = 150
    private let rulerHeight: CGFloat = 40

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            TimelineToolbar(viewModel: viewModel)

            HSplitView {
                // Left: Preview & Inspector
                VStack(spacing: 0) {
                    PreviewPanel(viewModel: viewModel)
                    InspectorPanel(
                        viewModel: viewModel,
                        showingEffectPicker: $showingEffectPicker,
                        selectedClipForEffects: $selectedClipForEffects
                    )
                }
                .frame(minWidth: 400)

                // Right: Timeline
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        TrackHeaderList(viewModel: viewModel, trackHeaderWidth: trackHeaderWidth, rulerHeight: rulerHeight)
                        TimelineGrid(viewModel: viewModel, rulerHeight: rulerHeight)
                    }

                    if viewModel.showScopes {
                        ScopesPanel(viewModel: viewModel)
                    }
                }
            }
        }
        .background(Color(white: 0.1))
    }
}

// MARK: - Toolbar

struct TimelineToolbar: View {
    @ObservedObject var viewModel: VideoTimelineViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Edit Mode
            Picker("Mode", selection: $viewModel.editMode) {
                ForEach(TimelineEditMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 400)

            Divider().frame(height: 30)

            // Snapping Toggle
            Toggle(isOn: $viewModel.isSnappingEnabled) {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
            .toggleStyle(.button)
            .help("Snapping")

            // Ripple Mode Toggle
            Toggle(isOn: $viewModel.rippleMode) {
                Image(systemName: "arrow.left.arrow.right")
            }
            .toggleStyle(.button)
            .help("Ripple Edit")

            Divider().frame(height: 30)

            TransportControls(viewModel: viewModel)

            Spacer()

            // Undo/Redo
            Button(action: viewModel.undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!viewModel.canUndo)

            Button(action: viewModel.redo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!viewModel.canRedo)

            Divider().frame(height: 30)

            ZoomControls(viewModel: viewModel)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.15))
    }
}

// MARK: - Transport Controls

struct TransportControls: View {
    @ObservedObject var viewModel: VideoTimelineViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button(action: viewModel.seekToStart) {
                Image(systemName: "backward.end.fill")
            }

            Button(action: viewModel.goToPreviousClip) {
                Image(systemName: "backward.frame.fill")
            }

            Button(action: viewModel.togglePlayback) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
            }
            .frame(width: 40)

            Button(action: viewModel.goToNextClip) {
                Image(systemName: "forward.frame.fill")
            }

            Button(action: viewModel.seekToEnd) {
                Image(systemName: "forward.end.fill")
            }

            // Timecode Display
            Text(viewModel.formatTimecode(viewModel.currentTime))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black)
                .cornerRadius(4)
        }
        .foregroundColor(.white)
    }
}

// MARK: - Zoom Controls

struct ZoomControls: View {
    @ObservedObject var viewModel: VideoTimelineViewModel

    var body: some View {
        HStack(spacing: 4) {
            Button(action: { viewModel.horizontalZoom = max(10, viewModel.horizontalZoom * 0.8) }) {
                Image(systemName: "minus.magnifyingglass")
            }

            Slider(value: $viewModel.horizontalZoom, in: 10...500)
                .frame(width: 100)

            Button(action: { viewModel.horizontalZoom = min(500, viewModel.horizontalZoom * 1.25) }) {
                Image(systemName: "plus.magnifyingglass")
            }
        }
    }
}

// MARK: - Preview Panel

struct PreviewPanel: View {
    @ObservedObject var viewModel: VideoTimelineViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PREVIEW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)

                Spacer()

                Picker("", selection: $viewModel.previewResolution) {
                    ForEach(PreviewResolution.allCases, id: \.self) { res in
                        Text(res.rawValue).tag(res)
                    }
                }
                .frame(width: 60)

                Toggle(isOn: $viewModel.isProxyMode) {
                    Text("Proxy")
                        .font(.system(size: 10))
                }
                .toggleStyle(.button)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(white: 0.12))

            // Preview Area
            ZStack {
                Color.black

                Text("Preview")
                    .foregroundColor(.gray)

                // Safe Areas Overlay
                Rectangle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    .padding(20)
            }
            .aspectRatio(16/9, contentMode: .fit)
        }
    }
}

// MARK: - Inspector Panel

struct InspectorPanel: View {
    @ObservedObject var viewModel: VideoTimelineViewModel
    @Binding var showingEffectPicker: Bool
    @Binding var selectedClipForEffects: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("INSPECTOR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(white: 0.12))

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.selectedClipIds.count == 1,
                       let clipId = viewModel.selectedClipIds.first,
                       let clip = viewModel.findClip(by: clipId) {
                        ClipInspectorContent(
                            clip: clip,
                            viewModel: viewModel,
                            showingEffectPicker: $showingEffectPicker,
                            selectedClipForEffects: $selectedClipForEffects
                        )
                    } else if viewModel.selectedClipIds.isEmpty {
                        Text("No selection")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        Text("\(viewModel.selectedClipIds.count) clips selected")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .padding()
            }
        }
        .frame(maxHeight: 300)
    }
}

// MARK: - Clip Inspector Content

struct ClipInspectorContent: View {
    let clip: VideoClipModel
    @ObservedObject var viewModel: VideoTimelineViewModel
    @Binding var showingEffectPicker: Bool
    @Binding var selectedClipForEffects: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Clip Info Section
            InspectorSection(title: "CLIP INFO") {
                TextField("Name", text: .constant(clip.name))
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Duration:")
                    Spacer()
                    Text(viewModel.formatTimecode(clip.duration))
                        .foregroundColor(.white)
                }
                .font(.system(size: 12))
            }

            Divider()

            // Transform Section
            InspectorSection(title: "TRANSFORM") {
                HStack {
                    Text("Position")
                    Spacer()
                    Text("X: \(Int(clip.transform.positionX)) Y: \(Int(clip.transform.positionY))")
                }

                HStack {
                    Text("Scale")
                    Spacer()
                    Text("\(Int(clip.transform.scaleX * 100))%")
                }

                HStack {
                    Text("Rotation")
                    Spacer()
                    Text("\(Int(clip.transform.rotation))°")
                }
            }
            .font(.system(size: 12))
            .foregroundColor(.gray)

            Divider()

            // Speed Section
            InspectorSection(title: "SPEED") {
                HStack {
                    Text("Speed")
                    Spacer()
                    Text("\(Int(clip.speed * 100))%")
                }

                Toggle("Reverse", isOn: .constant(clip.isReversed))
            }
            .font(.system(size: 12))

            Divider()

            // Effects Section
            InspectorSection(title: "EFFECTS") {
                HStack {
                    Spacer()
                    Button(action: {
                        selectedClipForEffects = clip.id
                        showingEffectPicker = true
                    }) {
                        Image(systemName: "plus")
                    }
                }

                ForEach(clip.effects) { effect in
                    HStack {
                        Toggle(isOn: .constant(effect.isEnabled)) {
                            Text(effect.name)
                        }
                        Spacer()
                        Button(action: {
                            viewModel.removeEffect(from: clip.id, effectId: effect.id)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .font(.system(size: 12))
                }
            }
        }
    }
}

// MARK: - Inspector Section

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)

            content()
        }
    }
}

// MARK: - Track Header List

struct TrackHeaderList: View {
    @ObservedObject var viewModel: VideoTimelineViewModel
    let trackHeaderWidth: CGFloat
    let rulerHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Ruler spacer
            Rectangle()
                .fill(Color(white: 0.12))
                .frame(height: rulerHeight)

            // Track Headers
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 1) {
                    ForEach(viewModel.videoTracks) { track in
                        TrackHeader(track: track, viewModel: viewModel)
                            .frame(height: track.height * viewModel.verticalZoom)
                    }

                    // Separator
                    Rectangle()
                        .fill(Color.orange)
                        .frame(height: 2)

                    // Audio Track Headers
                    ForEach(viewModel.audioTracks) { track in
                        TrackHeader(track: track, viewModel: viewModel)
                            .frame(height: track.height * viewModel.verticalZoom)
                    }
                }
            }

            // Add Track Buttons
            HStack {
                Button(action: { viewModel.addVideoTrack() }) {
                    Label("+ Video", systemImage: "film")
                        .font(.system(size: 10))
                }

                Button(action: { viewModel.addAudioTrack() }) {
                    Label("+ Audio", systemImage: "waveform")
                        .font(.system(size: 10))
                }
            }
            .padding(.vertical, 8)
            .foregroundColor(.gray)
        }
        .frame(width: trackHeaderWidth)
        .background(Color(white: 0.12))
    }
}

// MARK: - Track Header

struct TrackHeader: View {
    let track: VideoTrackModel
    @ObservedObject var viewModel: VideoTimelineViewModel

    var body: some View {
        HStack(spacing: 4) {
            // Track Color Indicator
            Rectangle()
                .fill(track.type == .audio ? Color.green : Color.blue)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(track.type.rawValue.uppercased())
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Track Controls
            HStack(spacing: 2) {
                if track.type != .audio {
                    Button(action: { viewModel.toggleTrackVisibility(track.id) }) {
                        Image(systemName: track.isVisible ? "eye" : "eye.slash")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(track.isVisible ? .white : .gray)
                }

                Button(action: { viewModel.toggleTrackMute(track.id) }) {
                    Text("M")
                        .font(.system(size: 9, weight: .bold))
                }
                .frame(width: 18, height: 18)
                .background(track.isMuted ? Color.orange.opacity(0.5) : Color(white: 0.2))
                .foregroundColor(track.isMuted ? .orange : .gray)
                .cornerRadius(3)

                Button(action: { viewModel.toggleTrackLock(track.id) }) {
                    Image(systemName: track.isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 9))
                }
                .foregroundColor(track.isLocked ? .yellow : .gray)
            }
        }
        .padding(.horizontal, 4)
        .background(
            viewModel.selectedTrackId == track.id
                ? Color.white.opacity(0.1)
                : Color.clear
        )
        .onTapGesture {
            viewModel.selectedTrackId = track.id
        }
    }
}

// MARK: - Timeline Grid

struct TimelineGrid: View {
    @ObservedObject var viewModel: VideoTimelineViewModel
    let rulerHeight: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    TimelineBackground(viewModel: viewModel, width: max(geometry.size.width, viewModel.duration * viewModel.horizontalZoom), rulerHeight: rulerHeight)

                    ClipsLayer(viewModel: viewModel, rulerHeight: rulerHeight)
                    MarkersLayer(viewModel: viewModel)
                    PlayheadView(viewModel: viewModel, rulerHeight: rulerHeight)
                }
                .frame(
                    width: max(geometry.size.width, viewModel.duration * viewModel.horizontalZoom + 200),
                    height: viewModel.totalTracksHeight + rulerHeight
                )
            }

            VStack {
                TimelineRuler(viewModel: viewModel, width: geometry.size.width, height: rulerHeight)
                Spacer()
            }
        }
    }
}

// MARK: - Timeline Background

struct TimelineBackground: View {
    @ObservedObject var viewModel: VideoTimelineViewModel
    let width: CGFloat
    let rulerHeight: CGFloat

    var body: some View {
        Canvas { context, size in
            let secondWidth = viewModel.horizontalZoom
            let totalSeconds = Int(width / secondWidth) + 1

            for second in 0...totalSeconds {
                let x = CGFloat(second) * secondWidth
                let isMajor = second % 10 == 0
                let isMinor = second % 5 == 0

                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: rulerHeight))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(isMajor ? Color(white: 0.35) : isMinor ? Color(white: 0.25) : Color(white: 0.15)),
                    lineWidth: isMajor ? 1 : 0.5
                )
            }

            var yOffset = rulerHeight
            for track in viewModel.videoTracks {
                yOffset += track.height * viewModel.verticalZoom
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yOffset))
                        path.addLine(to: CGPoint(x: size.width, y: yOffset))
                    },
                    with: .color(Color(white: 0.2)),
                    lineWidth: 1
                )
            }

            context.fill(
                Path(CGRect(x: 0, y: yOffset, width: size.width, height: 2)),
                with: .color(Color.orange.opacity(0.5))
            )
            yOffset += 2

            for track in viewModel.audioTracks {
                yOffset += track.height * viewModel.verticalZoom
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yOffset))
                        path.addLine(to: CGPoint(x: size.width, y: yOffset))
                    },
                    with: .color(Color(white: 0.2)),
                    lineWidth: 1
                )
            }
        }
        .background(Color(white: 0.08))
    }
}

// MARK: - Clips Layer

struct ClipsLayer: View {
    @ObservedObject var viewModel: VideoTimelineViewModel
    let rulerHeight: CGFloat

    var body: some View {
        VStack(spacing: 1) {
            Rectangle().fill(Color.clear).frame(height: rulerHeight)

            ForEach(viewModel.videoTracks) { track in
                ZStack(alignment: .leading) {
                    ForEach(track.clips) { clip in
                        ClipView(clip: clip, viewModel: viewModel, trackHeight: track.height * viewModel.verticalZoom)
                            .offset(x: viewModel.secondsToX(clip.startTime))
                    }
                }
                .frame(height: track.height * viewModel.verticalZoom)
                .opacity(track.isVisible ? 1 : 0.3)
            }

            Rectangle().fill(Color.orange.opacity(0.5)).frame(height: 2)

            ForEach(viewModel.audioTracks) { track in
                ZStack(alignment: .leading) {
                    // Audio clips would go here
                }
                .frame(height: track.height * viewModel.verticalZoom)
            }
        }
    }
}

// MARK: - Clip View

struct ClipView: View {
    let clip: VideoClipModel
    @ObservedObject var viewModel: VideoTimelineViewModel
    let trackHeight: CGFloat

    private var isSelected: Bool {
        viewModel.selectedClipIds.contains(clip.id)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 4)
                .fill(clip.color.swiftUIColor.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.white : clip.color.swiftUIColor, lineWidth: isSelected ? 2 : 1)
                )

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)

                // Thumbnail strip placeholder
                HStack(spacing: 1) {
                    ForEach(0..<max(1, Int(clip.duration / 5)), id: \.self) { _ in
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 40, height: trackHeight - 25)
                    }
                }
                .padding(.horizontal, 2)

                Spacer()
            }

            // Effects indicator
            if !clip.effects.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                        Spacer()
                    }
                    .padding(4)
                }
            }

            // Resize handles
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.01))
                    .frame(width: 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let deltaSeconds = Double(value.translation.width) / viewModel.horizontalZoom
                                let newInPoint = clip.inPoint + deltaSeconds
                                viewModel.trimClip(clip.id, newInPoint: newInPoint)
                            }
                    )

                Spacer()

                Rectangle()
                    .fill(Color.white.opacity(0.01))
                    .frame(width: 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let deltaSeconds = Double(value.translation.width) / viewModel.horizontalZoom
                                let newOutPoint = clip.outPoint + deltaSeconds
                                viewModel.trimClip(clip.id, newOutPoint: newOutPoint)
                            }
                    )
            }
        }
        .frame(width: max(20, viewModel.secondsToX(clip.duration)), height: trackHeight - 2)
        .opacity(clip.audioEnabled ? 1.0 : 0.7)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newTime = viewModel.xToSeconds(viewModel.secondsToX(clip.startTime) + value.translation.width)
                    viewModel.moveClip(clip.id, toTime: newTime)
                }
        )
        .onTapGesture {
            viewModel.selectClip(clip.id, additive: false)
        }
        .contextMenu {
            Button("Split at Playhead") {
                viewModel.splitClip(clip.id, at: viewModel.currentTime)
            }
            Button("Duplicate") {
                viewModel.duplicateClip(clip.id)
            }
            Divider()
            Button("Reverse") {
                viewModel.reverseClip(clip.id)
            }
            Menu("Speed") {
                Button("50%") { viewModel.setClipSpeed(clip.id, speed: 0.5) }
                Button("100%") { viewModel.setClipSpeed(clip.id, speed: 1.0) }
                Button("200%") { viewModel.setClipSpeed(clip.id, speed: 2.0) }
                Button("400%") { viewModel.setClipSpeed(clip.id, speed: 4.0) }
            }
            Divider()
            Button("Delete", role: .destructive) {
                viewModel.deleteClip(clip.id)
            }
        }
    }
}

// MARK: - Markers Layer

struct MarkersLayer: View {
    @ObservedObject var viewModel: VideoTimelineViewModel

    var body: some View {
        ForEach(viewModel.markers) { marker in
            VStack(spacing: 0) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 10))
                    .foregroundColor(marker.color.swiftUIColor)

                Rectangle()
                    .fill(marker.color.swiftUIColor.opacity(0.5))
                    .frame(width: 1, height: viewModel.totalTracksHeight)
            }
            .offset(x: viewModel.secondsToX(marker.time) - 5, y: 5)
        }
    }
}

// MARK: - Playhead View

struct PlayheadView: View {
    @ObservedObject var viewModel: VideoTimelineViewModel
    let rulerHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 12))
                .foregroundColor(.red)
                .offset(y: rulerHeight - 15)

            Rectangle()
                .fill(Color.red)
                .frame(width: 2, height: viewModel.totalTracksHeight)
                .offset(y: rulerHeight)
        }
        .offset(x: viewModel.secondsToX(viewModel.currentTime) - 1)
    }
}

// MARK: - Timeline Ruler

struct TimelineRuler: View {
    @ObservedObject var viewModel: VideoTimelineViewModel
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(white: 0.15))
            )

            let secondWidth = viewModel.horizontalZoom
            let totalSeconds = Int(width / secondWidth) + 1

            for second in 0...totalSeconds {
                let x = CGFloat(second) * secondWidth
                let isMajor = second % 10 == 0
                let isMinor = second % 5 == 0

                if isMajor {
                    context.draw(
                        Text(viewModel.formatTimecode(Double(second)))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white),
                        at: CGPoint(x: x + 2, y: size.height / 2),
                        anchor: .leading
                    )
                }

                context.stroke(
                    Path { path in
                        let tickHeight: CGFloat = isMajor ? size.height * 0.5 : isMinor ? size.height * 0.3 : size.height * 0.2
                        path.move(to: CGPoint(x: x, y: size.height - tickHeight))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(isMajor ? .white : Color(white: 0.5)),
                    lineWidth: 1
                )
            }
        }
        .frame(height: height)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let time = viewModel.xToSeconds(value.location.x)
                    viewModel.seekTo(time: time)
                }
        )
    }
}

// MARK: - Scopes Panel

struct ScopesPanel: View {
    @ObservedObject var viewModel: VideoTimelineViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SCOPES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)

                Spacer()

                Picker("", selection: $viewModel.scopeType) {
                    ForEach(TimelineScopeType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .frame(width: 120)

                Button(action: { viewModel.showScopes = false }) {
                    Image(systemName: "xmark")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(white: 0.12))

            Rectangle()
                .fill(Color.black)
                .frame(height: 150)
                .overlay(
                    Text(viewModel.scopeType.rawValue)
                        .foregroundColor(.green.opacity(0.5))
                )
        }
    }
}

// MARK: - Preview

#Preview {
    VideoTimelineView()
        .preferredColorScheme(.dark)
        .frame(width: 1400, height: 900)
}
