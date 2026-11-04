import Foundation

/// The Field as a layer with its own transparency, for compositing in Resolve or Final Cut
/// (PRO-W2, 2026-11-04). The Field is light on black, so its transparency is its light: each
/// pixel's alpha is its brightest channel — black is transparent, a full channel opaque — and
/// its colour is divided by that alpha (straight, not premultiplied, alpha). Laid "over" black in
/// any editor, the result is the Field exactly as Echoel draws it; over a picture it adds the
/// Field's light where it has some and leaves the picture where it has none.
///
/// Works in place on 8-bit BGRA rows, the layout the export's pixel buffers hold; pure arithmetic,
/// no allocation, so it may run on any thread for every frame.
public enum FieldAlphaKey {
    /// Keys one pixel: `(b, g, r)` light on black to `(b', g', r', a)` with straight alpha.
    public static func key(b: UInt8, g: UInt8, r: UInt8) -> (b: UInt8, g: UInt8, r: UInt8, a: UInt8) {
        let alpha = Swift.max(b, Swift.max(g, r))
        guard alpha > 0 else { return (0, 0, 0, 0) }
        func lift(_ value: UInt8) -> UInt8 {
            UInt8(Swift.min(255, (UInt32(value) * 255 + UInt32(alpha) / 2) / UInt32(alpha)))
        }
        return (lift(b), lift(g), lift(r), alpha)
    }

    /// Keys every pixel of a BGRA image in place: `height` rows of `width` pixels, each row
    /// `bytesPerRow` apart. Rows or sizes that do not fit the buffer are left as they are.
    public static func keyBGRA(_ bytes: UnsafeMutableRawBufferPointer, width: Int, height: Int, bytesPerRow: Int) {
        guard width > 0, height > 0, bytesPerRow >= width * 4 else { return }
        guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
        for row in 0..<height {
            let start = row * bytesPerRow
            guard start + width * 4 <= bytes.count else { return }
            var pixel = base + start
            for _ in 0..<width {
                let keyed = key(b: pixel[0], g: pixel[1], r: pixel[2])
                pixel[0] = keyed.b
                pixel[1] = keyed.g
                pixel[2] = keyed.r
                pixel[3] = keyed.a
                pixel += 4
            }
        }
    }

    /// The pixel a straight-alpha layer gives laid over `under` — what an editor's "over"
    /// computes, per channel: `c·a + under·(1 − a)`, rounded.
    public static func over(_ channel: UInt8, alpha: UInt8, under: UInt8) -> UInt8 {
        let a = UInt32(alpha)
        return UInt8((UInt32(channel) * a + UInt32(under) * (255 - a) + 127) / 255)
    }
}
