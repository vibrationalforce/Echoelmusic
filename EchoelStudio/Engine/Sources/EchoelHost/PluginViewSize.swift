import AVFoundation
import Foundation

/// How large the plugin page draws a hosted unit's own interface. The host offers the unit its
/// full size (`AUAudioUnit.supportedViewConfigurations`); a reported size is drawn only where it
/// fits the page and is at least as large as the interface would be without it — the full width at
/// the unit's preferred height, held between a usable minimum and a ceiling. Otherwise that
/// full-width interface is drawn.
public enum PluginViewSize {
    /// The full-size interface, as a tablet host shows it.
    public static let expanded = CGSize(width: 1024, height: 700)
    /// What the page offers a unit, largest first. Only the full size: a unit that does not
    /// override `supportedViewConfigurations` accepts every size it is offered, so a small offered
    /// size (320 × 240) would shrink nearly every interface on a phone below the full width it
    /// gets without one.
    public static let offered: [CGSize] = [expanded]

    /// The lowest height an interface without a reported size gets.
    public static let minimumHeight: CGFloat = 240
    /// The highest, while the page is not expanded.
    public static let compactCeiling: CGFloat = 560
    /// The height for a unit that states no preferred size at all.
    public static let unstatedHeight: CGFloat = 360

    public enum Choice: Equatable {
        /// The unit's reported size at `index` of the reported list, drawn at `size`.
        case configuration(index: Int, size: CGSize)
        /// No reported size fits and beats it: the full width at this height.
        case height(CGFloat)
    }

    /// Of the `reported` sizes, the largest by area that fits inside `available` and covers at
    /// least the area of the fallback — the full available width at the unit's `preferredHeight`
    /// held between `minimumHeight` and `ceiling`; when none does, that fallback height. A size or
    /// an area that is not a positive finite number never fits.
    public static func choose(reported: [CGSize], available: CGSize, preferredHeight: CGFloat,
                              ceiling: CGFloat = compactCeiling) -> Choice {
        let height = clampedHeight(preferredHeight, ceiling: ceiling)
        let fallbackArea = area(CGSize(width: available.width, height: height))
        var best: (index: Int, size: CGSize)?
        for (index, size) in reported.enumerated() where fits(size, in: available) && area(size) >= fallbackArea {
            if let current = best, area(current.size) >= area(size) { continue }
            best = (index, size)
        }
        if let best { return .configuration(index: best.index, size: best.size) }
        return .height(height)
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
