// VisualAnalysisMeter.swift
// Echoel — S4c (founder 2026-09-23, "all tasks"): the four measuring views get their door, and
// it is the VISUAL WINDOW, not the Field panel.
//
// ⭐ THE PLACEMENT IS THE FOUNDER'S, word for word. On 2026-08-13 he circled the Field panel's
// meter block and wrote *"Das Brauch da nicht sein. Wenn dann ins Visual Window übertragen."*
// #575 did the unconditional half (out of the panel). This file is the conditional half: the
// meters REPLACE the picture inside the floating window, one at a time, at the two sizes where a
// meter is legible (Large and fullscreen). They never sit OVER the immersive field — a readout
// drawn on top of the artwork is the layout nobody has seen, and swapping instead of overlaying
// also keeps the one-`MetalBioView` GPU law: while a meter shows, no Metal renderer runs.
//
// ONE METER AT A TIME, on purpose: each view owns a `TimelineView` (20–30 fps) or a per-beat
// observation, and four of them mounted together would be four clocks for one screen.
//
// Pure part first (Foundation-only, drivable by the blocking bundle), SwiftUI leaf below it.
//
// NEEDS-FOUNDER-VERIFY (S4c, the meters in the Visual window): (1) at Large and in fullscreen
// the bar shows a chart button; Small and Medium do not. (2) Tapping it replaces the picture
// with the meter surface; "Picture" brings the picture back, and so does shrinking the window.
// (3) All four segments read legibly on the phone (Waves · Spectrum · Scope · Pulse), with
// Reduce Motion on and off. (4) With the Field's self-play on, it keeps sounding while a meter
// shows, and no tap on the meter plays a note. (5) Pulse shows "Camera pulse is off" until the
// camera runs, then a cloud that grows beat by beat. (6) Known cost: with the chart button
// offered and no take running, the transport readout leaves the bar at Large on a 375 pt phone
// and in fullscreen on 402/430 pt phones — say whether that trade is right. (7) "Spectrum" may
// truncate in the four-way segment row on a 375 pt phone — legible or not?

import Foundation

/// Which measuring view the Visual window shows when its meters are open.
enum VisualAnalysisMeter: String, CaseIterable, Identifiable, Sendable {
    /// `AnalysisWavefrontView` — the founder's own 2026-08-02 ask ("physikalisch korrekt").
    case wavefront
    /// `AnalysisSpectrumView` — what is in the sound, and the loudest partial.
    case spectrum
    /// `AnalysisScopeView` — the triggered master waveform and its true peak.
    case scope
    /// `AnalysisPoincareView` — each camera pulse interval against the next.
    ///
    /// ⚠️ Labelled "Pulse", never "Beats" (a rhythm word in a music app) and never "Heart"
    /// (the camera measures PULSE intervals, not ECG beats). No health reading is attached.
    case pulse

    var id: String { rawValue }

    /// The segment label. Short, because four of them share one row on a 330 pt card.
    var label: String {
        switch self {
        case .wavefront: return "Waves"
        case .spectrum:  return "Spectrum"
        case .scope:     return "Scope"
        case .pulse:     return "Pulse"
        }
    }

    /// What VoiceOver says for the segment — the label alone would not say what is measured.
    var spokenName: String {
        switch self {
        case .wavefront: return "Wavefront field of the master output"
        case .spectrum:  return "Spectrum of the master output"
        case .scope:     return "Oscilloscope of the master output"
        case .pulse:     return "Pulse interval plot from the camera"
        }
    }

    /// The first meter a user sees — the founder's own ask, and the one without a number to
    /// misread on first contact.
    static let defaultMeter: VisualAnalysisMeter = .wavefront

    /// Read by ONE view (`VisualAnalysisLayer`), so it lives here and not in
    /// `StudioDefaultKeys` — that home is for keys read in more than one view (H15-KEYSTORE).
    /// A second reader moves it there in the same commit.
    static let storageKey = "visual.analysisMeter"

    /// A stored value this build does not know (renamed, or written by a later build) falls
    /// back to the default instead of showing nothing.
    init(stored raw: String) {
        self = VisualAnalysisMeter(rawValue: raw) ?? .defaultMeter
    }
}

#if canImport(SwiftUI)
import SwiftUI

/// The meter surface that replaces the picture while the meters are open.
///
/// LEAF BY CONSTRUCTION (the 10.76.50 freeze law): this body reads one `@AppStorage` string
/// and nothing live. Every hot read — the output ring, the camera beats — stays inside the
/// four meter views, each its own leaf. The selector is SEGMENTED, not `.menu`: no popover
/// exists that a rebuild could tear down.
///
/// ⭐ THE WAY BACK LIVES HERE, not in the toolbar. The toolbar's "Show meters" button is width-
/// budgeted (`FloatingVisualLayout.chromeFit`) and may shed on a narrow phone; "Picture" sits in
/// this header, outside that budget, so the way back to the artwork can never be the thing that
/// was dropped to make room.
struct VisualAnalysisLayer: View {
    /// Required, no default: a mount that ignores the system setting must not compile.
    let reduceMotion: Bool
    let onShowPicture: () -> Void

    @AppStorage(VisualAnalysisMeter.storageKey)
    private var meterRaw = VisualAnalysisMeter.defaultMeter.rawValue

    var body: some View {
        let meter = VisualAnalysisMeter(stored: meterRaw)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Picker("Meter", selection: $meterRaw) {
                    ForEach(VisualAnalysisMeter.allCases) { m in
                        Text(m.label)
                            .tag(m.rawValue)
                            .accessibilityLabel(m.spokenName)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Button(action: onShowPicture) {
                    Text("Picture")
                        .font(EchoelTheme.font(13))
                        .foregroundStyle(EchoelTheme.text)
                        .padding(.horizontal, 10)
                        // The ONLY way back to the picture, so it gets the house tap floor.
                        .frame(minHeight: EchoelTheme.controlTapHeight)
                        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
                        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                            .strokeBorder(EchoelTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show the picture")
                .accessibilityHint("Closes the meters and returns to the visual.")
            }
            ScrollView {
                meterView(meter)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(EchoelTheme.bg)
    }

    @ViewBuilder
    private func meterView(_ meter: VisualAnalysisMeter) -> some View {
        switch meter {
        case .wavefront: AnalysisWavefrontView(reduceMotion: reduceMotion)
        case .spectrum:  AnalysisSpectrumView(reduceMotion: reduceMotion)
        case .scope:     AnalysisScopeView(reduceMotion: reduceMotion)
        case .pulse:     AnalysisPoincareView()
        }
    }
}
#endif
