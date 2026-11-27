import EchoelCore
import EchoelEngine
import SwiftUI

/// The app's own report, the first of its test agents (2026-11-27): what the diagnostics log says
/// about the latest run and the one before, as findings with what to try and the lines they rest on
/// (`DiagnosticReport`). "Share Report" writes the report, with the whole log as its material, to one
/// Markdown file beside the log and opens the share sheet once this page has closed. The page reads
/// the log once when it opens; nothing on it changes while it is open, and nothing leaves the device
/// unless the musician shares it.
struct ReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioRouter.self) private var router
    @Environment(AudioEngine.self) private var engine
    @State private var report: DiagnosticReport?
    @State private var problem: String?
    /// The self-test is running (test agent TA-S1, 2026-11-27).
    @State private var testing = false

    /// The file the report is written to before it is shared: in the Diagnostics folder, which the
    /// song library never lists and backups leave out.
    private static var fileURL: URL {
        DiagnosticLog.app.url.deletingLastPathComponent().appendingPathComponent("Echoelmusic report.md")
    }

    var body: some View {
        NavigationStack {
            List {
                if let report {
                    runs(report)
                    findings(report)
                } else {
                    EchoelSection { ParagraphText("Reading the diagnostics log…") }
                }
                selfTest
                share
            }
            .echoelList()
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) } }
            .task { report = DiagnosticReport(log: DiagnosticLog.app.text()) }
        }
        .preferredColorScheme(.dark)
    }

    private func runs(_ report: DiagnosticReport) -> some View {
        EchoelSection("Runs", footer: "Made from the diagnostics log, which holds what the audio and the app did as fixed words and numbers, never a name you typed. The app sends nothing; the report leaves the device only when you share it.") {
            ForEach(report.overview, id: \.self) { sentence in
                ParagraphText(sentence)
            }
        }
    }

    private func findings(_ report: DiagnosticReport) -> some View {
        EchoelSection("Findings") {
            if !report.findings.contains(where: { $0.weight > .note }) {
                ParagraphText(DiagnosticReport.nothingFound)
            }
            ForEach(Array(report.findings.enumerated()), id: \.offset) { _, finding in
                FindingRow(finding: finding)
            }
        }
    }

    /// The self-test: every instrument and effect of Echoel played offline at the rate the audio runs
    /// at, nothing to the speakers, and how long each block took on this device written to the log,
    /// where the report reads it. Only while the song is stopped; it runs off the main thread.
    private var selfTest: some View {
        EchoelSection("Self-Test", footer: "Plays every instrument and effect of Echoel offline, with no sound out, and measures how long each needs on this device. Only while the song is stopped; it takes a few seconds.") {
            Button(testing ? "Testing…" : "Run Self-Test") { runSelfTest() }
                .buttonStyle(EchoelRowButtonStyle())
                .disabled(testing || engine.isPlaying)
        }
    }

    private func runSelfTest() {
        guard !testing, !engine.isPlaying else { return }
        testing = true
        let rate = engine.sampleRate ?? 48_000
        Task {
            let result = await Task.detached(priority: .utility) {
                SelfTest(sampleRate: rate, blockFrames: 256).run { DispatchTime.now().uptimeNanoseconds }
            }.value
            result.write(to: DiagnosticLog.app)
            report = DiagnosticReport(log: DiagnosticLog.app.text())
            testing = false
        }
    }

    private var share: some View {
        EchoelSection(footer: "The report and the whole log as one file, to send in a message or keep in Files.") {
            Button("Share Report") { shareReport() }
                .buttonStyle(EchoelRowButtonStyle())
                .disabled(report == nil)
            if let problem { NoteText(problem, tone: .problem) }
        }
    }

    /// Writes the report and hands it to the share sheet, which comes up once this page has closed
    /// (the one sheet slot waits for it, as Share Diagnostics on the About page does).
    private func shareReport() {
        guard let report else { return }
        let url = Self.fileURL
        do {
            try Data(report.markdown.utf8).write(to: url, options: .atomic)
        } catch {
            problem = "The report could not be written on this device. Share Diagnostics on the About page sends the log alone."
            return
        }
        router.share(url)
        dismiss()
    }
}

/// One finding: its weight and run in words (colour repeats them, never replaces them), what the
/// log shows, and what to try. One element for VoiceOver.
private struct FindingRow: View {
    let finding: DiagnosticReport.Finding

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("\(finding.weight.word) · \(finding.run.rawValue)")
                .font(Theme.Font.caption)
                .foregroundStyle(color)
            Text(finding.title)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Try: \(finding.suggestion)")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Theme.Space.xs)
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch finding.weight {
        case .failure: Theme.Color.record
        case .problem: Theme.Color.warning
        case .notice, .note: Theme.Color.textSecondary
        }
    }
}
