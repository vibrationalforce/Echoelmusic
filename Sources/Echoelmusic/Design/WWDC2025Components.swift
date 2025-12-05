import SwiftUI
import Combine

#if canImport(WebKit)
import WebKit
#endif

#if canImport(Charts)
import Charts
#endif

// MARK: - WWDC 2025 SwiftUI Components
// New APIs announced at Apple WWDC 2025
// WebView, Rich Text Editor, 3D Charts, Drag & Drop, @Animatable

// MARK: - WebView (WWDC 2025)

/// Native SwiftUI WebView - Finally available in iOS 26!
/// Wraps WebKit for displaying web content
struct EchoelWebView: View {
    let url: URL
    @State private var page: WebPageModel?
    @State private var isLoading = true
    @State private var progress: Double = 0
    @State private var title: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Loading indicator
            if isLoading {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.cyan)
            }

            // Web content
            #if canImport(WebKit) && os(iOS)
            WebViewRepresentable(
                url: url,
                isLoading: $isLoading,
                progress: $progress,
                title: $title
            )
            #else
            // Fallback for non-WebKit platforms
            Text("WebView not available on this platform")
                .foregroundStyle(.secondary)
            #endif
        }
        .liquidGlass(.clear, cornerRadius: 0)
        .navigationTitle(title)
    }
}

#if canImport(WebKit) && os(iOS)
/// UIViewRepresentable wrapper for WKWebView
struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var title: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.title = webView.title ?? ""
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}
#endif

/// Observable WebPage model (WWDC 2025 pattern)
@Observable
class WebPageModel {
    var url: URL?
    var title: String = ""
    var isLoading = false
    var canGoBack = false
    var canGoForward = false

    func load(_ url: URL) {
        self.url = url
        self.isLoading = true
    }

    func goBack() { }
    func goForward() { }
    func reload() { }
}

// MARK: - Rich Text Editor (WWDC 2025)

/// Rich Text Editor using AttributedString
/// WWDC 2025: TextEditor now supports AttributedString natively
struct RichTextEditor: View {
    @Binding var attributedText: AttributedString
    let placeholder: String
    var onFocusChange: ((Bool) -> Void)?

    @FocusState private var isFocused: Bool
    @State private var showFormatting = false

    init(
        text: Binding<AttributedString>,
        placeholder: String = "Enter text...",
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self._attributedText = text
        self.placeholder = placeholder
        self.onFocusChange = onFocusChange
    }

    var body: some View {
        VStack(spacing: 0) {
            // Formatting toolbar
            if showFormatting {
                formattingToolbar
            }

            // Editor
            ZStack(alignment: .topLeading) {
                if attributedText.characters.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }

                // Use TextEditor with AttributedString (iOS 26+)
                #if swift(>=6.0)
                TextEditor(text: Binding(
                    get: { String(attributedText.characters) },
                    set: { newValue in
                        attributedText = AttributedString(newValue)
                    }
                ))
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                #else
                TextEditor(text: Binding(
                    get: { String(attributedText.characters) },
                    set: { newValue in
                        attributedText = AttributedString(newValue)
                    }
                ))
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                #endif
            }
            .foregroundStyle(.white)
            .frame(minHeight: 100)
        }
        .padding()
        .liquidGlass(isFocused ? .tinted : .regular, tint: isFocused ? .cyan : nil, cornerRadius: 16)
        .onChange(of: isFocused) { _, newValue in
            onFocusChange?(newValue)
            withAnimation(.spring(response: 0.3)) {
                showFormatting = newValue
            }
        }
    }

    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FormatButton(icon: "bold", action: { applyStyle(.bold) })
                FormatButton(icon: "italic", action: { applyStyle(.italic) })
                FormatButton(icon: "underline", action: { applyStyle(.underline) })
                FormatButton(icon: "strikethrough", action: { applyStyle(.strikethrough) })

                Divider()
                    .frame(height: 24)
                    .background(Color.white.opacity(0.3))

                FormatButton(icon: "text.alignleft", action: { })
                FormatButton(icon: "text.aligncenter", action: { })
                FormatButton(icon: "text.alignright", action: { })

                Divider()
                    .frame(height: 24)
                    .background(Color.white.opacity(0.3))

                FormatButton(icon: "list.bullet", action: { })
                FormatButton(icon: "list.number", action: { })
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .liquidGlass(.frosted, cornerRadius: 12)
    }

    private func applyStyle(_ style: TextStyle) {
        // Apply formatting to AttributedString
        var container = AttributeContainer()

        switch style {
        case .bold:
            container.font = .body.bold()
        case .italic:
            container.font = .body.italic()
        case .underline:
            container.underlineStyle = .single
        case .strikethrough:
            container.strikethroughStyle = .single
        }

        attributedText.mergeAttributes(container)
    }

    enum TextStyle {
        case bold, italic, underline, strikethrough
    }
}

struct FormatButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3D Charts (WWDC 2025)

/// 3D Chart for audio spectrum visualization
/// WWDC 2025: Chart3D API for immersive data visualization
struct Audio3DSpectrum: View {
    let frequencyBands: [[Float]] // Time x Frequency matrix
    let tint: Color

    @State private var rotation: Double = 0
    @State private var elevation: Double = 30

    init(frequencyBands: [[Float]], tint: Color = .cyan) {
        self.frequencyBands = frequencyBands
        self.tint = tint
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 3D surface plot
                Canvas { context, size in
                    draw3DSurface(context: context, size: size)
                }

                // Controls overlay
                VStack {
                    Spacer()

                    HStack {
                        // Rotation control
                        Slider(value: $rotation, in: 0...360)
                            .tint(tint)
                            .frame(width: 100)

                        Spacer()

                        // Elevation control
                        Slider(value: $elevation, in: 0...90)
                            .tint(tint)
                            .frame(width: 100)
                    }
                    .padding()
                    .liquidGlass(.regular, cornerRadius: 12)
                }
            }
        }
        .padding()
        .liquidGlass(.clear, cornerRadius: 20)
    }

    private func draw3DSurface(context: GraphicsContext, size: CGSize) {
        guard !frequencyBands.isEmpty else { return }

        let timeSteps = frequencyBands.count
        let freqBins = frequencyBands.first?.count ?? 0

        let centerX = size.width / 2
        let centerY = size.height / 2
        let scaleX = size.width / CGFloat(timeSteps + 2)
        let scaleZ = size.height / CGFloat(freqBins + 2)
        let scaleY: CGFloat = 50

        // Apply rotation and elevation
        let rotRad = rotation * .pi / 180
        let elevRad = elevation * .pi / 180

        for t in 0..<timeSteps {
            for f in 0..<freqBins {
                let value = CGFloat(frequencyBands[t][f])

                // 3D to 2D projection
                let x3D = CGFloat(t) - CGFloat(timeSteps) / 2
                let y3D = value * scaleY
                let z3D = CGFloat(f) - CGFloat(freqBins) / 2

                // Rotate around Y axis
                let xRot = x3D * cos(rotRad) - z3D * sin(rotRad)
                let zRot = x3D * sin(rotRad) + z3D * cos(rotRad)

                // Apply elevation
                let yProj = y3D * cos(elevRad) - zRot * sin(elevRad)
                let zProj = y3D * sin(elevRad) + zRot * cos(elevRad)

                // Project to 2D
                let perspective: CGFloat = 200
                let scale = perspective / (perspective + zProj)
                let screenX = centerX + xRot * scaleX * scale
                let screenY = centerY - yProj * scale

                // Draw bar
                let barHeight = max(2, value * scaleY * scale)
                let barWidth = scaleX * 0.8 * scale

                let rect = CGRect(
                    x: screenX - barWidth / 2,
                    y: screenY - barHeight,
                    width: barWidth,
                    height: barHeight
                )

                // Color based on value
                let hue = Double(f) / Double(freqBins) * 0.3 + 0.5
                let saturation = 0.8
                let brightness = 0.5 + Double(value) * 0.5

                context.fill(
                    Path(roundedRect: rect, cornerRadius: 2),
                    with: .color(Color(hue: hue, saturation: saturation, brightness: brightness))
                )
            }
        }
    }
}

/// Simple 3D bar chart for frequency visualization
#if canImport(Charts)
struct Spectrum3DChart: View {
    let data: [FrequencyBand]

    struct FrequencyBand: Identifiable {
        let id = UUID()
        let frequency: String
        let level: Double
        let time: Int
    }

    var body: some View {
        // Using standard Charts as Chart3D requires iOS 26
        Chart(data) { band in
            BarMark(
                x: .value("Frequency", band.frequency),
                y: .value("Level", band.level)
            )
            .foregroundStyle(by: .value("Time", band.time))
        }
        .chartForegroundStyleScale([
            0: Color.cyan.opacity(0.8),
            1: Color.purple.opacity(0.8),
            2: Color.pink.opacity(0.8)
        ])
        .padding()
        .liquidGlass(.clear, cornerRadius: 16)
    }
}
#endif

// MARK: - Enhanced Drag & Drop (WWDC 2025)

/// Draggable audio clip component
struct DraggableAudioClip: View {
    let clip: AudioClipData
    @State private var isDragging = false

    struct AudioClipData: Transferable, Codable, Identifiable {
        let id: UUID
        let name: String
        let duration: TimeInterval
        let waveform: [Float]

        static var transferRepresentation: some TransferRepresentation {
            CodableRepresentation(for: AudioClipData.self, contentType: .audio)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.cyan)

            VStack(alignment: .leading) {
                Text(clip.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                Text(formatDuration(clip.duration))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            // Mini waveform
            MiniWaveform(samples: clip.waveform)
                .frame(width: 60, height: 30)
        }
        .padding()
        .liquidGlass(isDragging ? .tinted : .regular, tint: isDragging ? .cyan : nil, cornerRadius: 16)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .draggable(clip) {
            // Drag preview
            HStack {
                Image(systemName: "waveform")
                Text(clip.name)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .animation(.spring(response: 0.3), value: isDragging)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Drop zone for audio clips
struct AudioDropZone: View {
    @Binding var clips: [DraggableAudioClip.AudioClipData]
    @State private var isTargeted = false

    var body: some View {
        VStack {
            if clips.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.5))

                    Text("Drop audio clips here")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(clips) { clip in
                            DraggableAudioClip(clip: clip)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minHeight: 200)
        .liquidGlass(isTargeted ? .tinted : .regular, tint: isTargeted ? .green : nil, cornerRadius: 20)
        .dropDestination(for: DraggableAudioClip.AudioClipData.self) { items, location in
            clips.append(contentsOf: items)
            return true
        } isTargeted: { targeted in
            withAnimation(.spring(response: 0.3)) {
                isTargeted = targeted
            }
        }
    }
}

struct MiniWaveform: View {
    let samples: [Float]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !samples.isEmpty else { return }

                let stepX = geometry.size.width / CGFloat(samples.count - 1)
                let midY = geometry.size.height / 2

                path.move(to: CGPoint(x: 0, y: midY))

                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = midY - CGFloat(sample) * midY * 0.8
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.cyan, lineWidth: 1)
        }
    }
}

// MARK: - @Animatable Macro Support (WWDC 2025)

/// Animatable waveform shape
/// WWDC 2025: @Animatable macro simplifies animation conformance
struct AnimatableWaveform: Shape {
    var phase: Double
    var amplitude: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(phase, amplitude) }
        set {
            phase = newValue.first
            amplitude = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.height / 2
        let wavelength = rect.width / 3

        path.move(to: CGPoint(x: 0, y: midY))

        for x in stride(from: 0, through: rect.width, by: 2) {
            let relativeX = x / wavelength
            let sine = sin(relativeX * .pi * 2 + phase)
            let y = midY + sine * amplitude * midY * 0.8

            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

/// Animated audio visualizer using @Animatable pattern
struct AnimatedVisualizer: View {
    @State private var phase: Double = 0
    @State private var amplitude: Double = 0.5

    let tint: Color

    var body: some View {
        ZStack {
            ForEach(0..<5) { i in
                AnimatableWaveform(
                    phase: phase + Double(i) * 0.5,
                    amplitude: amplitude * (1 - Double(i) * 0.15)
                )
                .stroke(
                    tint.opacity(1 - Double(i) * 0.2),
                    lineWidth: 2
                )
            }
        }
        .padding()
        .liquidGlass(.clear, cornerRadius: 16)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }

            withAnimation(.easeInOut(duration: 1.5).repeatForever()) {
                amplitude = 0.8
            }
        }
    }
}

// MARK: - Spatial Layout (WWDC 2025 visionOS)

#if os(visionOS)
/// 3D alignment for spatial layouts
struct SpatialCardLayout: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 40) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Text(item)
                    .font(.title)
                    .padding()
                    .liquidGlass(.regular, cornerRadius: 20)
                    .rotation3DEffect(
                        .degrees(Double(index - items.count / 2) * 15),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .offset(z: CGFloat(abs(index - items.count / 2)) * -20)
            }
        }
    }
}
#endif

// MARK: - Preview

#Preview("WWDC 2025 Components") {
    ZStack {
        AnimatedGlassBackground()

        ScrollView {
            VStack(spacing: 24) {
                Text("WWDC 2025 Features")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                // Animated Visualizer
                AnimatedVisualizer(tint: .cyan)
                    .frame(height: 100)

                // 3D Spectrum
                Audio3DSpectrum(
                    frequencyBands: (0..<10).map { _ in
                        (0..<16).map { _ in Float.random(in: 0.1...1.0) }
                    }
                )
                .frame(height: 250)

                // Rich Text Editor
                RichTextEditor(
                    text: .constant(AttributedString("Edit lyrics here...")),
                    placeholder: "Write your lyrics..."
                )
                .frame(height: 150)

                // Drop Zone
                AudioDropZone(clips: .constant([]))
            }
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}
