import Foundation

/// The WCAG 2.x contrast ratio between two colours: (L1 + 0.05) / (L2 + 0.05), the lighter's
/// relative luminance over the darker's, 1 (none) … 21 (black on white). Text needs 4.5:1 (AA,
/// 1.4.3), a control's boundary or a large label 3:1 (1.4.11).
public enum Contrast {
    public static let textMinimum = 4.5
    public static let largeTextMinimum = 3.0

    public static func ratio(_ a: ToneLight.RGB, _ b: ToneLight.RGB) -> Double {
        let la = a.luminance, lb = b.luminance
        return (Swift.max(la, lb) + 0.05) / (Swift.min(la, lb) + 0.05)
    }
}
