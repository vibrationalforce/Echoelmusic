import EchoelCore
import SwiftUI

/// One video part's colour correction (COLOR): exposure, contrast, saturation, temperature and
/// tint, and lift, gamma and gain on the luma — never changing the file. Auto Enhance reads a few
/// frames of the part and sets the controls from them (Gray World for the white balance,
/// percentiles for exposure and contrast); Match Color takes another part's colour statistics.
/// Either only sets these controls, in one undo step, and the musician changes them from there.
/// A drag of one field is one undo step. Opened from a video part's hold menu ("Color…").
struct RegionColorView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
    @Environment(\.dismiss) private var dismiss
    let trackID: TrackID
    let regionID: RegionID
    /// What is being read while Auto Enhance or Match Color works; nil at rest.
    @State private var reading: String?
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            store.endGesture()
                            dismiss()
                        }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }

    /// A video part of the song, its file and the track it is on.
    private struct Part {
        let track: Track
        let region: AudioRegion
        let file: MediaFile
    }

    private func part(_ track: TrackID, _ region: RegionID) -> Part? {
        guard let owner = store.project.track(track), owner.kind == .video, let index = owner.regionIndex(region) else { return nil }
        let found = owner.regions[index]
        guard let file = store.project.mediaFile(found.media), file.sampleRate > 0, file.sampleRate.isFinite else { return nil }
        return Part(track: owner, region: found, file: file)
    }

    @ViewBuilder private var content: some View {
        ScrollView {
            if let current = part(trackID, regionID) {
                form(current)
                    .padding(Theme.Space.l)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                Text("This part is no longer in the song.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(Theme.Space.l)
            }
        }
        .background(Theme.Color.background)
        .numberPadHost()
    }

    private func form(_ current: Part) -> some View {
        let grade = current.region.grade ?? .neutral
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(current.file.name)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.textSecondary)
            actions(current)
            if let reading {
                Text(reading)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            } else if let problem {
                Text(problem)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
            }
            light(grade)
            colour(grade)
            luma(grade)
            Button("Reset Color", systemImage: "arrow.counterclockwise") {
                store.endGesture()
                try? store.perform(.setRegionGrade(track: trackID, regionID, grade: .neutral))
            }
            .disabled(grade.isNeutral || reading != nil)
        }
    }

    // MARK: - Auto Enhance and Match Color

    @ViewBuilder private func actions(_ current: Part) -> some View {
        let others = otherParts(than: current)
        HStack(spacing: Theme.Space.s) {
            Button("Auto Enhance", systemImage: "wand.and.rays") { autoEnhance(current) }
                .accessibilityHint("Sets the white balance, exposure and contrast from a few frames of this part.")
            Menu {
                ForEach(others, id: \.region.id) { other in
                    Button(name(of: other)) { match(current, to: other) }
                }
            } label: {
                Label("Match Color", systemImage: "eyedropper")
            }
            .disabled(others.isEmpty)
            .accessibilityHint("Takes the colour of another video part of the song.")
        }
        .buttonStyle(.bordered)
        .disabled(reading != nil)
    }

    private func otherParts(than current: Part) -> [Part] {
        store.project.tracks.filter { $0.kind == .video }.flatMap { track in
            track.regions.compactMap { region in region.id == current.region.id ? nil : part(track.id, region.id) }
        }
    }

    private func name(of other: Part) -> String {
        let bar = store.project.meterMap.bar(at: other.region.start) + 1
        return "\(other.file.name) — \(other.track.name), bar \(bar)"
    }

    /// The pixels of a few frames of `part`, read off the main thread; empty when its file cannot be read.
    private func pixels(of part: Part) async -> [ColorSample] {
        guard let url = documents.mediaURL(part.file) else { return [] }
        let start = Double(part.region.offset) / part.file.sampleRate
        let seconds = Double(part.region.length) / part.file.sampleRate
        return await Task.detached(priority: .userInitiated) {
            await ColorFrames.pixels(of: url, fromSeconds: start, seconds: seconds)
        }.value
    }

    private func autoEnhance(_ current: Part) {
        store.endGesture()
        problem = nil
        reading = "Reading frames…"
        Task {
            let frames = await pixels(of: current)
            let grade = await Task.detached(priority: .userInitiated) { ColorGrade.autoEnhanced(frames) }.value
            finish(frames.isEmpty ? nil : grade, title: "Auto Enhance")
        }
    }

    private func match(_ current: Part, to other: Part) {
        store.endGesture()
        problem = nil
        reading = "Reading frames…"
        let look = other.region.grade ?? .neutral
        Task {
            let source = await pixels(of: current)
            let target = await pixels(of: other)
            let grade = await Task.detached(priority: .userInitiated) {
                ColorGrade.matched(source, to: look.apply(target))
            }.value
            finish(source.isEmpty || target.isEmpty ? nil : grade, title: "Match Color")
        }
    }

    /// The derived values into the controls, one undo step; nothing when the frames could not be read.
    private func finish(_ grade: ColorGrade?, title: String) {
        reading = nil
        guard let grade else {
            problem = "The frames of this part could not be read."
            return
        }
        // The luma controls stay as the musician set them.
        let current = part(trackID, regionID)?.region.grade ?? .neutral
        var next = grade
        next.lift = current.lift
        next.gamma = current.gamma
        next.gain = current.gain
        try? store.perform([.setRegionGrade(track: trackID, regionID, grade: next.held)], title: title)
    }

    // MARK: - The controls

    private func set(_ change: (inout ColorGrade) -> Void) {
        var next = part(trackID, regionID)?.region.grade ?? .neutral
        change(&next)
        try? store.perform(.setRegionGrade(track: trackID, regionID, grade: next.held), coalescingKey: "region.grade.\(regionID)")
    }

    @ViewBuilder private func light(_ grade: ColorGrade) -> some View {
        field("Exposure", hundredths(grade.exposure), range: -300...300, unit: "EV", decimals: 2, standard: 0,
              spoken: "stops") { value in set { $0.exposure = Double(value) / 100 } }
        field("Contrast", hundredths(grade.contrast), range: 0...200, unit: "%", standard: 100,
              spoken: "percent") { value in set { $0.contrast = Double(value) / 100 } }
        field("Saturation", hundredths(grade.saturation), range: 0...200, unit: "%", standard: 100,
              spoken: "percent") { value in set { $0.saturation = Double(value) / 100 } }
    }

    @ViewBuilder private func colour(_ grade: ColorGrade) -> some View {
        field("Temperature", hundredths(grade.temperature), range: -100...100, standard: 0) { value in
            set { $0.temperature = Double(value) / 100 }
        }
        .accessibilityHint("Below zero bluer, above zero warmer.")
        field("Tint", hundredths(grade.tint), range: -100...100, standard: 0) { value in
            set { $0.tint = Double(value) / 100 }
        }
        .accessibilityHint("Below zero greener, above zero more magenta.")
    }

    @ViewBuilder private func luma(_ grade: ColorGrade) -> some View {
        field("Lift", hundredths(grade.lift), range: -50...50, decimals: 2, standard: 0) { value in
            set { $0.lift = Double(value) / 100 }
        }
        field("Gamma", hundredths(grade.gamma), range: 25...400, decimals: 2, standard: 100) { value in
            set { $0.gamma = Double(value) / 100 }
        }
        field("Gain", hundredths(grade.gain), range: 0...200, unit: "%", standard: 100, spoken: "percent") { value in
            set { $0.gain = Double(value) / 100 }
        }
    }

    private func field(_ title: String, _ value: Int, range: ClosedRange<Int>, unit: String = "", decimals: Int = 0,
                       standard: Int, spoken: String? = nil, commit: @escaping (Int) -> Void) -> some View {
        SettingField(title: title, value: Swift.min(Swift.max(value, range.lowerBound), range.upperBound), range: range,
                     unit: unit, decimals: decimals, standard: standard, spokenUnit: spoken, commit: commit,
                     ended: { store.endGesture() })
            .disabled(reading != nil)
    }

    private func hundredths(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int((value * 100).rounded())
    }
}
