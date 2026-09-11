//
//  BodyPoseMath.swift
//  Echoelmusic — Core (pure)
//
//  K6a (#1264) — hands and shoulders as CONTROL values. The Vision half (`BodyPoseAnalyzer`)
//  hands this a few joint positions; this turns them into the bag entries the gesture bank
//  reads (`FaceGestureChannel.rawValue(from:)`), so the body channels get the same three
//  stages — deadzone with hysteresis, one-pole EMA, release on loss — as every face channel,
//  from the same code. No Vision type crosses this boundary: it compiles and tests on the
//  macOS host.
//
//  COORDINATES are Vision's: normalised to the oriented image, origin BOTTOM-left, y UP. So a
//  wrist's y IS its height, no flip. "Left" and "right" are the PERSON's hands (Vision's
//  chirality on an un-mirrored front-camera frame), not screen sides.
//
//  A MISSING JOINT WRITES NO KEY. The bank reads a missing key as the channel's neutral
//  (0, or 0.5 for the centred tilt), so a hand leaving the frame eases its channel to rest
//  through the ordinary update — the K3 law, for free. Presence is the one key always
//  written: 1 when the body pose was seen with confidence, else 0.
//
//  Movement as a control signal, never an inferred posture, mood or intent (the EU-AI-Act
//  framing at the top of `FaceExpressionBioPublisher` applies to the body unchanged).
//

import Foundation

/// What one Vision pass found: wrists and shoulders (normalised, y up), or nil when a joint
/// was not seen with enough confidence, and how confidently a body was seen at all.
public struct BodyPoseSample: Equatable, Sendable {
    public var leftWrist: SIMD2<Float>?
    public var rightWrist: SIMD2<Float>?
    public var leftShoulder: SIMD2<Float>?
    public var rightShoulder: SIMD2<Float>?
    public var bodyConfidence: Float

    public init(leftWrist: SIMD2<Float>? = nil, rightWrist: SIMD2<Float>? = nil,
                leftShoulder: SIMD2<Float>? = nil, rightShoulder: SIMD2<Float>? = nil,
                bodyConfidence: Float = 0) {
        self.leftWrist = leftWrist
        self.rightWrist = rightWrist
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
        self.bodyConfidence = bodyConfidence
    }
}

public enum BodyPoseMath {
    /// Bag keys — the gesture bank reads them (`FaceGestureChannel.rawValue(from:)`).
    public static let handHeightLKey = "body.handHeightL"
    public static let handHeightRKey = "body.handHeightR"
    public static let handDistanceKey = "body.handDistance"
    /// Radians, signed — the bank centres it (0.5 = level shoulders).
    public static let shoulderTiltKey = "body.shoulderTilt"
    public static let bodyPresenceKey = "body.presence"

    /// Wrist separation that reads as 1, in units of the image's normalised width — arms
    /// comfortably apart at a phone's distance, not a full span. A device number
    /// (NEEDS-FOUNDER-VERIFY at `BodyPoseAnalyzer`'s header, with the rest of the body asks).
    public static let handDistanceFullScale: Float = 0.8
    /// Below this the body pose is "not seen" — Vision's per-joint confidence scale.
    public static let presenceConfidence: Float = 0.3

    /// K6c (#1266) — the Vision orientation (`CGImagePropertyOrientation` raw value) for the
    /// front camera's sensor buffer as seen in a given interface orientation
    /// (`UIInterfaceOrientation` raw value). ARKit delivers the sensor's landscape buffer
    /// unrotated; a portrait interface therefore reads it rotated 90° — `.right` (6), the
    /// value K6a hard-wired. Landscape interfaces read it `.up` (1) or `.down` (3), upside-down
    /// portrait `.left` (8). Unknown (0) is treated as portrait, the instrument's posture.
    /// Pure so a host test can pin the table; the SIGN of the whole table (does a raised
    /// LEFT hand read as "Hand L" in every posture?) is the device ask at
    /// `BodyPoseAnalyzer`'s header — one table, one verify.
    public static func visionOrientationRaw(forInterfaceOrientationRaw raw: Int) -> UInt32 {
        switch raw {
        case 2: return 8   // portraitUpsideDown → .left
        case 3: return 3   // landscapeLeft      → .down
        case 4: return 1   // landscapeRight     → .up
        default: return 6  // portrait / unknown → .right
        }
    }

    /// The bag for one sample. Only joints that were seen write a key (see the header).
    public static func bag(from s: BodyPoseSample) -> [String: Float] {
        var bag: [String: Float] = [:]
        if let l = s.leftWrist, l.y.isFinite { bag[handHeightLKey] = FaceExpressionMapping.clamp01(l.y) }
        if let r = s.rightWrist, r.y.isFinite { bag[handHeightRKey] = FaceExpressionMapping.clamp01(r.y) }
        if let l = s.leftWrist, let r = s.rightWrist {
            let dx = l.x - r.x, dy = l.y - r.y
            let d = (dx * dx + dy * dy).squareRoot()
            if d.isFinite { bag[handDistanceKey] = FaceExpressionMapping.clamp01(d / handDistanceFullScale) }
        }
        if let l = s.leftShoulder, let r = s.rightShoulder {
            let tilt = atan2f(r.y - l.y, r.x - l.x)
            if tilt.isFinite { bag[shoulderTiltKey] = tilt }
        }
        bag[bodyPresenceKey] = s.bodyConfidence.isFinite && s.bodyConfidence >= presenceConfidence ? 1 : 0
        return bag
    }
}
