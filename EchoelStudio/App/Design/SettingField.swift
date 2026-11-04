import EchoelCore
import SwiftUI

/// A whole number that belongs to this device, not to the song — a port, a universe, a DMX
/// channel, a stream's bit rate — in Echoel's value field: label above, value, a thin bar for where
/// it sits in its range. It reads and behaves like `ParameterField`: drag up or down (slowly for
/// fine steps, quickly across the range, `DragPrecision`), tap to type it on Echoel's number pad
/// (when the page hosts one, `numberPadHost()`), double-tap for the standard value. A device
/// setting is no `Command`, so the field hands the new value to `commit` instead of the writer.
struct SettingField: View {
    @Environment(NumberPadController.self) private var pad: NumberPadController?
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    /// Shown after the number with a space ("kbit/s"); empty for a plain count.
    var unit = ""
    /// The grid the value lands on (100 for a bit rate, 1 for a port).
    var step = 1
    /// What double-tap and the pad's Default key return to; nil when there is none.
    var standard: Int?
    /// Spoken after the number instead of `unit` ("kilobits a second").
    var spokenUnit: String?
    /// False where every change reopens something (a live connection's port): the value is then
    /// typed or stepped, never dragged through thousands of intermediate values.
    var drags = true
    let commit: (Int) -> Void
    /// Called when a change is complete — a drag lifts, a value is typed, a VoiceOver step or a
    /// reset lands — so a caller that coalesces a drag's commits into one undo step can close it.
    var ended: (() -> Void)?
    /// The drag in progress: the unrounded value it has reached and the translation last read.
    @State private var drag: (value: Double, translation: CGFloat)?

    /// Points of vertical travel for the full range at full speed (as `ParameterField`).
    private static let travel: CGFloat = 240

    var body: some View {
        let span = Double(range.upperBound - range.lowerBound)
        let position = span > 0 ? Double(value - range.lowerBound) / span : 0
        let engaged = drag != nil || pad?.request?.owner == owner
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(1)
            Text(shown)
                .font(Theme.Font.value)
                .foregroundStyle(engaged ? Theme.Color.accent : Theme.Color.text)
                .lineLimit(1)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.Color.surfaceRaised)
                    Rectangle().fill(Theme.Color.accent).frame(width: geometry.size.width * CGFloat(position))
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
        }
        .padding(Theme.Space.s)
        .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Color.surface))
        // A control's boundary (3.6:1), the accent while it is held or typed into.
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium)
            .strokeBorder(engaged ? Theme.Color.accent : Theme.Color.borderStrong, lineWidth: 1))
        .animation(Theme.Motion.quick, value: engaged)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { gesture in
                    let reached = drag ?? (value: Double(value), translation: 0)
                    let moved = gesture.translation.height - reached.translation
                    let scale = DragPrecision.scale(speed: Double(gesture.velocity.height))
                    let next = Swift.min(Swift.max(reached.value - Double(moved / Self.travel) * span * scale,
                                                   Double(range.lowerBound)), Double(range.upperBound))
                    drag = (value: next, translation: gesture.translation.height)
                    let landed = snapped(Int(next.rounded()))
                    if landed != value { commit(landed) }
                }
                .onEnded { _ in
                    drag = nil
                    ended?()
                },
            including: drags ? .all : .subviews
        )
        .onTapGesture(count: 2) { if let standard { finish(snapped(standard)) } }
        .onTapGesture(perform: typeValue)
        .sensoryFeedback(.selection, trigger: value) { old, new in
            drag != nil && DragPrecision.reachesDetent(from: Double(old), to: Double(new),
                                                       standard: standard.map { Double(snapped($0)) },
                                                       range: Double(range.lowerBound)...Double(range.upperBound))
        }
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(spokenUnit.map { "\(value) \($0)" } ?? shown)
        .accessibilityAdjustableAction { direction in
            finish(snapped(value + (direction == .increment ? step : -step)))
        }
        // As `ParameterField`: VoiceOver's double-tap types the value, as a tap does, and never
        // falls through to the touch double-tap that returns it to the standard (W18); Reset is an
        // action of its own where there is a standard.
        .accessibilityAction { typeValue() }
        .accessibilityAction(named: "Type a Value", typeValue)
        .accessibilityActions {
            if let standard {
                Button("Reset") { finish(snapped(standard)) }
            }
        }
    }

    /// One whole change: committed, then closed.
    private func finish(_ landed: Int) {
        commit(landed)
        ended?()
    }

    private var shown: String { unit.isEmpty ? String(value) : "\(value) \(unit)" }

    private var owner: String { "setting.\(title)" }

    /// The value on Echoel's number pad, whole numbers; it lands on the field's grid.
    private func typeValue() {
        guard let pad else { return }
        let bounds = range
        let grid = step
        let deliver = commit
        let close = ended
        pad.open(NumberPadRequest(owner: owner, title: title,
                                  format: NumberEntryFormat(scale: 1, decimals: 0, unit: unit),
                                  range: Double(bounds.lowerBound)...Double(bounds.upperBound),
                                  value: Double(value), standard: standard.map { Double(Self.snapped($0, step: grid, in: bounds)) }) { typed in
            deliver(Self.snapped(Int(typed.rounded()), step: grid, in: bounds))
            close?()
        })
    }

    private func snapped(_ candidate: Int) -> Int { Self.snapped(candidate, step: step, in: range) }

    static func snapped(_ candidate: Int, step: Int, in range: ClosedRange<Int>) -> Int {
        let grid = Swift.max(1, step)
        let rounded = grid == 1 ? candidate : (candidate + grid / 2) / grid * grid
        return Swift.min(range.upperBound, Swift.max(range.lowerBound, rounded))
    }
}
