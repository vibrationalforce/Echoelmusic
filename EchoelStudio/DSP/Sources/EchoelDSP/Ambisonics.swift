import Foundation

/// Ambisonics in the AmbiX convention — channels in ACN order, normalised SN3D — up to third order
/// (16 channels). First-order AmbiX is what YouTube 360 takes and what most current recorders write;
/// the higher orders are the exchange format of the IEM and SPARTA plug-ins. Pure arithmetic: no
/// state, no allocation in the pointer forms, safe on the render thread.
///
/// - **Directions** follow `HeadphoneSpatializer` and ADM-OSC: azimuth 0 ahead, POSITIVE TO THE
///   LEFT, −180 … 180; elevation positive above, −90 … 90, in degrees. A value that is not a number
///   is read as 0; any finite angle is first brought into one turn, so none overflows.
/// - **ACN** (Ambisonic Channel Number): the channel of degree l and index m (−l … l) is
///   `l² + l + m`, so first order is W Y Z X.
/// - **SN3D** (Schmidt semi-normalised, no Condon–Shortley phase): W is 1, the square of each channel
///   of degree l integrates over the sphere to 4π / (2l + 1), and two different channels integrate
///   to 0. N3D is SN3D times √(2l + 1), so each squared N3D channel integrates to 4π.
///
/// The spherical harmonics are the ones of the earlier app's encoder (`AmbisonicsEncode`), here in
/// the open signal package where the engine, the app and an export can all reach them.
public enum Ambisonics {
    /// The highest order the formulas cover.
    public static let maximumOrder = 3
    /// The channels of a third-order set.
    public static let maximumChannels = 16

    /// The channels of a full-sphere set of `order`: (order + 1)², the order held to 0 … 3.
    public static func channelCount(order: Int) -> Int {
        let held = Swift.min(Swift.max(order, 0), maximumOrder)
        return (held + 1) * (held + 1)
    }

    /// The ACN channel of degree `degree` and index `index` (−degree … degree).
    public static func acn(degree: Int, index: Int) -> Int {
        degree * degree + degree + index
    }

    /// The degree and index of an ACN channel; a negative channel reads as W.
    public static func degreeAndIndex(acn: Int) -> (degree: Int, index: Int) {
        guard acn > 0 else { return (0, 0) }
        var degree = Int(Double(acn).squareRoot())
        while degree * degree > acn { degree -= 1 }
        while (degree + 1) * (degree + 1) <= acn { degree += 1 }
        return (degree, acn - degree * degree - degree)
    }

    /// The gain that turns an SN3D channel of `degree` into N3D: √(2l + 1).
    public static func n3dGain(degree: Int) -> Float {
        Float(2 * Swift.max(degree, 0) + 1).squareRoot()
    }

    /// The gain that turns an N3D channel of `degree` into SN3D: 1 / √(2l + 1).
    public static func sn3dGain(degree: Int) -> Float {
        1 / n3dGain(degree: degree)
    }

    // Literals, so the render thread never runs a lazy initialiser: √3, √3/2, √(5/8), √(15/4),
    // √(3/8), √2.
    private static let root3: Float = 1.7320508075688772
    private static let half3: Float = 0.8660254037844386
    private static let root5Over8: Float = 0.7905694150420949
    private static let root15Over4: Float = 1.9364916731037085
    private static let root3Over8: Float = 0.6123724356957945
    private static let root2: Float = 1.4142135623730951
    /// π / 180, as a literal.
    static let radiansPerDegree: Float = 0.017453292519943295

    /// An angle in degrees as radians, a value that is not a number as 0. The angle is first brought
    /// into −180 … 180, so even the largest finite value never overflows into a non-number.
    @inline(__always)
    static func radians(_ degrees: Float) -> Float {
        (degrees.isFinite ? degrees.remainder(dividingBy: 360) : 0) * radiansPerDegree
    }

    /// Writes the SN3D gains of a plane wave from a direction into `gains`, in ACN order, for
    /// `order` held to 0 … 3. `gains` holds at least `channelCount(order:)` values. Encoding a mono
    /// sample at that direction is multiplying it by each gain.
    public static func encode(azimuthDegrees: Float, elevationDegrees: Float, order: Int,
                              into gains: UnsafeMutablePointer<Float>) {
        let held = Swift.min(Swift.max(order, 0), maximumOrder)
        let azimuth = radians(azimuthDegrees)
        let elevation = radians(elevationDegrees)
        gains[0] = 1
        guard held >= 1 else { return }
        let ce = cosf(elevation), se = sinf(elevation)
        let ca = cosf(azimuth), sa = sinf(azimuth)
        gains[1] = ce * sa
        gains[2] = se
        gains[3] = ce * ca
        guard held >= 2 else { return }
        let c2 = cosf(2 * azimuth), s2 = sinf(2 * azimuth)
        let ce2 = ce * ce, se2 = se * se
        gains[4] = half3 * ce2 * s2
        gains[5] = root3 * se * ce * sa
        gains[6] = (3 * se2 - 1) / 2
        gains[7] = root3 * se * ce * ca
        gains[8] = half3 * ce2 * c2
        guard held >= 3 else { return }
        let c3 = cosf(3 * azimuth), s3 = sinf(3 * azimuth)
        let ce3 = ce2 * ce, middle = 5 * se2 - 1
        gains[9] = root5Over8 * ce3 * s3
        gains[10] = root15Over4 * se * ce2 * s2
        gains[11] = root3Over8 * middle * ce * sa
        gains[12] = (5 * se2 * se - 3 * se) / 2
        gains[13] = root3Over8 * middle * ce * ca
        gains[14] = root15Over4 * se * ce2 * c2
        gains[15] = root5Over8 * ce3 * c3
    }

    /// The SN3D gains of a direction, in ACN order — for the control side; it allocates.
    public static func gains(azimuthDegrees: Float, elevationDegrees: Float, order: Int) -> [Float] {
        var values = [Float](repeating: 0, count: channelCount(order: order))
        values.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            encode(azimuthDegrees: azimuthDegrees, elevationDegrees: elevationDegrees, order: order, into: base)
        }
        return values
    }

    /// One first-order frame in FuMa (W X Y Z, W at −3 dB, the B-format of older recorders and
    /// `.amb` files) as AmbiX (W Y Z X, W at 0 dB).
    public static func ambiX(fuMaW w: Float, x: Float, y: Float, z: Float) -> (w: Float, y: Float, z: Float, x: Float) {
        (w * root2, y, z, x)
    }

    /// One first-order AmbiX frame as FuMa.
    public static func fuMa(ambiXW w: Float, y: Float, z: Float, x: Float) -> (w: Float, x: Float, y: Float, z: Float) {
        (w / root2, x, y, z)
    }
}

/// A tetrahedral microphone's four capsules (A-format) as first-order AmbiX (B-format). The
/// capsules point front-left-up, front-right-down, back-left-down and back-right-up — the order
/// FLU FRD BLD BRU most tetrahedral microphones deliver; a device that delivers them otherwise
/// names its order, and the caller passes the capsules by name.
///
/// The matrix is the one for four coincident ideal cardioids: W is half their sum, and each
/// direction is the sum and difference across the tetrahedron times √3/2, so a plane wave of
/// amplitude 1 gives W = 1 and the direction cosines. A real microphone's capsules are a few
/// centimetres apart and not ideal; its maker's correction filters (or calibration) belong after
/// this matrix and are not part of it.
public enum TetrahedralMicrophone {
    private static let half: Float = 0.5
    /// √3 / 2, as a literal (no lazy initialiser on the render thread).
    private static let axis: Float = 0.8660254037844386

    @inline(__always)
    private static func finite(_ value: Float) -> Float { value.isFinite ? value : 0 }

    /// One frame. A capsule sample that is not a number is read as 0.
    public static func bFormat(flu: Float, frd: Float, bld: Float, bru: Float) -> (w: Float, y: Float, z: Float, x: Float) {
        let a = finite(flu), b = finite(frd), c = finite(bld), d = finite(bru)
        return (w: half * (a + b + c + d),
                y: axis * (a - b + c - d),
                z: axis * (a - b - c + d),
                x: axis * (a + b - c - d))
    }

    /// `frames` frames of four capsule channels into four B-format channels in ACN order. The
    /// outputs may be the inputs (each frame is read whole before it is written). Allocates nothing.
    public static func convert(flu: UnsafePointer<Float>, frd: UnsafePointer<Float>,
                               bld: UnsafePointer<Float>, bru: UnsafePointer<Float>,
                               w: UnsafeMutablePointer<Float>, y: UnsafeMutablePointer<Float>,
                               z: UnsafeMutablePointer<Float>, x: UnsafeMutablePointer<Float>,
                               frames: Int) {
        guard frames > 0 else { return }
        for frame in 0..<frames {
            let out = bFormat(flu: flu[frame], frd: frd[frame], bld: bld[frame], bru: bru[frame])
            w[frame] = out.w
            y[frame] = out.y
            z[frame] = out.z
            x[frame] = out.x
        }
    }
}

/// A turn of a first-order sound field — the hook a head tracker drives. W does not change; Y, Z
/// and X turn as a direction does. The angles mean what they do for a source:
///
/// - **yaw** moves a source along the azimuth, positive to the left;
/// - **pitch** lifts a source ahead, positive up;
/// - **roll** lifts a source on the left, positive up.
///
/// Roll is applied first, then pitch, then yaw. To keep a scene still while the head turns, play it
/// through the `inverse` of the head's own turn. A value that is not a number is read as 0. Make a
/// turn on the control side and hand it over; `rotate` is the part for the render thread.
public struct FirstOrderRotation: Equatable, Sendable {
    // Row-major 3 × 3 matrix acting on the column (x, y, z).
    private let xx: Float, xy: Float, xz: Float
    private let yx: Float, yy: Float, yz: Float
    private let zx: Float, zy: Float, zz: Float

    public static let identity = FirstOrderRotation(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)

    public init(yawDegrees: Float, pitchDegrees: Float, rollDegrees: Float) {
        let yaw = Ambisonics.radians(yawDegrees), pitch = Ambisonics.radians(pitchDegrees)
        let roll = Ambisonics.radians(rollDegrees)
        let cy = cosf(yaw), sy = sinf(yaw)
        let cp = cosf(pitch), sp = sinf(pitch)
        let cr = cosf(roll), sr = sinf(roll)
        // Yaw · Pitch · Roll, with
        //   yaw   = [[cy, −sy, 0], [sy, cy, 0], [0, 0, 1]]
        //   pitch = [[cp, 0, −sp], [0, 1, 0], [sp, 0, cp]]
        //   roll  = [[1, 0, 0], [0, cr, −sr], [0, sr, cr]]
        self.init(xx: cy * cp, xy: -sy * cr - cy * sp * sr, xz: sy * sr - cy * sp * cr,
                  yx: sy * cp, yy: cy * cr - sy * sp * sr, yz: -cy * sr - sy * sp * cr,
                  zx: sp, zy: cp * sr, zz: cp * cr)
    }

    private init(xx: Float, xy: Float, xz: Float, yx: Float, yy: Float, yz: Float, zx: Float, zy: Float, zz: Float) {
        self.xx = xx; self.xy = xy; self.xz = xz
        self.yx = yx; self.yy = yy; self.yz = yz
        self.zx = zx; self.zy = zy; self.zz = zz
    }

    /// The turn back: for a rotation, its transpose.
    public var inverse: FirstOrderRotation {
        FirstOrderRotation(xx: xx, xy: yx, xz: zx, yx: xy, yy: yy, yz: zy, zx: xz, zy: yz, zz: zz)
    }

    /// One frame's first-order directional channels, in and out in ACN order (Y, Z, X).
    public func rotate(y: Float, z: Float, x: Float) -> (y: Float, z: Float, x: Float) {
        (y: yx * x + yy * y + yz * z,
         z: zx * x + zy * y + zz * z,
         x: xx * x + xy * y + xz * z)
    }
}
