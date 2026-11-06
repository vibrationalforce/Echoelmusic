import AVFoundation
import Foundation

/// How large the plugin page draws a hosted unit's own interface. The host offers the unit a few
/// sizes (`AUAudioUnit.supportedViewConfigurations`); of those the unit reports, the largest that
/// fits the area the page has wins. A unit that reports none — or none that fits — keeps its own
/// preferred height, held between a usable minimum and a ceiling.
public enum PluginViewSize {
    /// The full-size interface, as a tablet host shows it.
    public static let expanded = CGSize(width: 1024, height: 700)
    /// A compact interface that fits a phone held upright.
    public static let compact = CGSize(width: 320, height: 240)
    /// What the page offers a unit, largest first.
    public static let offered: [CGSize] = [expanded, compact]

    /// The lowest height an interface without a reported size gets.
    public static let minimumHeight: CGFloat = 240
    /// The highest, while the page is not expanded.
    public static let compactCeiling: CGFloat = 560
    /// The height for a unit that states no preferred size at all.
    public static let unstatedHeight: CGFloat = 360

    public enum Choice: Equatable {
        /// The unit's reported size at `index` of the reported list, drawn at `size`.
        case configuration(index: Int, size: CGSize)
        /// No reported size fits: the full width at this height.
        case height(CGFloat)
    }

    /// Of the `reported` sizes, the largest by area that fits inside `available`; when none is
    /// reported or none fits, the unit's `preferredHeight` held between `minimumHeight` and
    /// `ceiling`. A size or an area that is not a positive finite number never fits.
    public static func choose(reported: [CGSize], available: CGSize, preferredHeight: CGFloat,
                              ceiling: CGFloat = compactCeiling) -> Choice {
        var best: (index: Int, size: CGSize)?
        for (index, size) in reported.enumerated() where fits(size, in: available) {
            if let current = best, area(current.size) >= area(size) { continue }
            best = (index, size)
        }
        if let best { return .configuration(index: best.index, size: best.size) }
        return .height(clampedHeight(preferredHeight, ceiling: ceiling))
    }

    /// The unit's preferred height between `minimumHeight` and `ceiling`; `unstatedHeight` (within
    /// the same bounds) for none.
    public static func clampedHeight(_ preferred: CGFloat, ceiling: CGFloat = compactCeiling) -> CGFloat {
        let top = ceiling.isFinite ? Swift.max(ceiling, minimumHeight) : compactCeiling
        let wanted = preferred.isFinite && preferred > 0 ? preferred : unstatedHeight
        return Swift.min(Swift.max(wanted, minimumHeight), top)
    }

    private static func fits(_ size: CGSize, in available: CGSize) -> Bool {
        valid(size) && valid(available) && size.width <= available.width && size.height <= available.height
    }

    private static func valid(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }

    private static func area(_ size: CGSize) -> CGFloat { size.width * size.height }
}
