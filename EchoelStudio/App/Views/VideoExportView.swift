import EchoelCore
import SwiftUI

/// The video export's choices (wave W7, C6), in the one sheet slot: the frame (9:16, 16:9, 1:1,
/// 4:5), fill or fit, the Field over the picture (W15), H.264 or HEVC, the whole song or a short
/// stretch of whole bars from the bar the playhead stands in, and the loudness the mix is brought to
/// (CUT; −14 LUFS unless chosen otherwise). The song itself never changes; the export is one new
/// MP4 for the share sheet.
struct VideoExportView: View {
    /// The Field Layer's blend and opacity: kept on this device, never in the song (no format
    /// field), so the next export starts where this one was set.
    nonisolated static let fieldBlendKey = "video.fieldLayer.blend"
    nonisolated static let fieldOpacityKey = "video.fieldLayer.opacity"

    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @Environment(StudioRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var options = VideoExport.Options()
    /// Seconds a short export is about; nil exports the whole song.
    @State private var shortSeconds: Double?
    @State private var startBar = 1
    /// Why the last Export did not finish, until the next one starts.
    @State private var failure: String?
    @AppStorage(VideoExportView.fieldBlendKey) private var fieldBlend = FieldLayer.Blend.off
    /// Percent, 0 … 100.
    @AppStorage(VideoExportView.fieldOpacityKey) private var fieldOpacity = FieldLayer().opacityPercent

    var body: some View {
        NavigationStack {
            Form {
                exportStatus
                EchoelSection("Frame") {
                    Picker("Frame", selection: $options.shape) {
                        ForEach(VideoExportPlan.Shape.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Picture", selection: $options.fit) {
                        Text("Fill").tag(VideoExportPlan.Fit.fill)
                        Text("Fit").tag(VideoExportPlan.Fit.fit)
                    }
                    .pickerStyle(.segmented)
                    NoteText("Fill crops the picture to the frame in the export only; Fit shows all of it on black.")
                }
                fieldSection
                EchoelSection("Length") {
                    Picker("Length", selection: $shortSeconds) {
                        Text("Whole Song").tag(Double?.none)
                        ForEach(VideoExportPlan.shortFormSeconds, id: \.self) { seconds in
                            Text("About " + NumberText.string(seconds, decimals: 0, unit: "s")).tag(Double?.some(seconds))
                        }
                    }
                    if let range = shortRange {
                        let seconds = VideoExportPlan.seconds(of: range, in: store.project)
                        NoteText(rangeText(range, seconds: seconds.to - seconds.from))
                    }
                }
                EchoelSection("Encoding") {
                    Picker("Codec", selection: $options.codec) {
                        Text("H.264").tag(VideoExportPlan.Codec.h264)
                        Text("HEVC").tag(VideoExportPlan.Codec.hevc)
                    }
                    .pickerStyle(.segmented)
                    Picker("Loudness", selection: $options.loudness) {
                        ForEach(ExportLoudness.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    NoteText("Brings the mix to the chosen loudness with its peaks at or under −1 dBTP: −14 LUFS for social and streaming platforms, −16 LUFS for podcasts, −23 LUFS for broadcast. Off keeps the mix as it plays.")
                }
            }
            .echoelList()
            // Field Opacity is typed on Echoel's number pad, docked here.
            .numberPadHost()
            .navigationTitle("Export Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(documents.isExporting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") { export() }.disabled(documents.isExporting)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(documents.isExporting)
        .onAppear {
            // The bar the playhead stands in: read once, never observed.
            let bar = MusicalTime.ticksPerBar(store.project.timeSignature)
            if bar > 0 { startBar = Int(engine.playheadTick(in: store.project) / bar) + 1 }
        }
    }

    /// What the export is doing, or why it did not finish — first in the sheet, under the Export
    /// button that started it. The failure stood only on the strip under the sheet, where nobody
    /// saw it (W18, M7); VoiceOver hears it from the strip, so it is shown here, not said twice.
    @ViewBuilder private var exportStatus: some View {
        if documents.isExporting {
            EchoelSection { NoteText(documents.exportProgress ?? "Exporting the song…") }
        } else if let failure {
            EchoelSection { NoteText(failure, tone: .problem) }
        }
    }

    /// The Field over the picture (W15): Off, or Screen, Add or Normal at an opacity. Without Metal
    /// the choice is held at Off and says why.
    private var fieldSection: some View {
        EchoelSection("Field") {
            Picker("Field Layer", selection: $fieldBlend) {
                ForEach(FieldLayer.Blend.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(!MetalField.isAvailable)
            if !MetalField.isAvailable {
                NoteText("The Field layer needs Metal graphics, which this device does not have.")
            } else {
                if fieldBlend != .off {
                    SettingField(title: "Field Opacity", value: fieldOpacity, range: 0...100, unit: "%",
                                 standard: FieldLayer().opacityPercent, spokenUnit: "percent") { fieldOpacity = $0 }
                }
                NoteText("The Field follows the song's beat, key and mix, and the video window shows it as the export will draw it. Body readings are live and not part of the song, so the export leaves them out: two exports of a song look the same.")
            }
        }
    }

    /// The layer as chosen, as the video window shows it.
    private var fieldLayer: FieldLayer { FieldLayer.stored(blend: fieldBlend, percent: fieldOpacity) }

    private var shortRange: ClosedRange<Tick>? {
        shortSeconds.flatMap { VideoExportPlan.shortRange(in: store.project, startBar: startBar, seconds: $0) }
    }

    private func rangeText(_ range: ClosedRange<Tick>, seconds: Double) -> String {
        let bar = Swift.max(1, MusicalTime.ticksPerBar(store.project.timeSignature))
        let bars = (range.upperBound - range.lowerBound) / bar
        return "Bars \(startBar) to \(startBar + Int(bars) - 1), \(NumberText.string(seconds, decimals: 1, unit: "s"))."
    }

    private func export() {
        var chosen = options
        chosen.range = shortRange
        chosen.fieldLayer = fieldLayer
        failure = nil
        Task {
            if let url = await documents.exportVideo(plugins: engine.plugins, options: chosen) {
                router.share(url)
                dismiss()
            } else {
                // What this export left on its way out: a failure writes its message there.
                failure = documents.lastError
            }
        }
    }
}
