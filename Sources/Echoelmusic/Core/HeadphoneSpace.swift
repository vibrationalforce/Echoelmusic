//
//  HeadphoneSpace.swift
//  Echoelmusic — Core
//
//  Restructure S3a (founder 2026-10-04, wörtlich: „Bereite S3 als hörbaren binauralen
//  Kopfhörer-Ausgang vor. Abnahme ist eine reproduzierbar hörbare Raumposition samt
//  Wiederherstellung im Stück.")
//
//  The ONE conversion from a track's `SpatialPosition` (ADM / BS.2076: azimuth positive = LEFT,
//  elevation positive = up, distance 0…1 room-relative) into the listener space of an
//  `AVAudioEnvironmentNode` (right-handed, metres: x right, y up, the listener faces −z).
//  Getting a sign wrong here puts a track on the wrong ear while ADM-OSC still sends it to the
//  right one — two outputs disagreeing about one scene, which no listener can diagnose.
//
//  Foundation-only and pure: S3b converts `Point` to `AVAudio3DPoint` at the one place that
//  sets a player node's position, on the control plane, never in a render block.
//
//  ⚠️ SCOPE: this is preparation. Nothing calls it yet; S3b (the environment node behind the
//  audio-track players) is its first caller, S3c the door. The plan and the device proof are in
//  `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md` §7.6. Until S3b ships, no headphone output
//  renders a position — do not cite this file as a working binaural output.
//

import Foundation

enum HeadphoneSpace {

    /// A point in the environment node's listener space, in metres.
    struct Point: Equatable, Sendable {
        let x: Float
        let y: Float
        let z: Float
    }

    /// The closest a source may sit to the listener. At zero distance an HRTF has no direction
    /// to render; a quarter metre keeps the direction the position names.
    static let nearestMeters: Float = 0.25

    /// The radius that `distance == 1` means: the listener (room centre) to the NEARER wall on
    /// the floor plane, so a source at full distance never lands outside the room it belongs to.
    static func radiusMeters(for room: RoomModel) -> Float {
        max(min(room.width, room.depth) / 2, nearestMeters)
    }

    /// The position as the environment node places it. Direction comes from the angles alone,
    /// so a source at distance 0 keeps its side instead of collapsing onto the head.
    static func point(for position: SpatialPosition, in room: RoomModel) -> Point {
        let azR = position.azimuth * .pi / 180
        let elR = position.elevation * .pi / 180
        let cosEl = cosf(elR)
        // ADM unit direction — the same expressions as `SpatialPosition.cartesian`.
        let right = -sinf(azR) * cosEl
        let front = cosf(azR) * cosEl
        let up = sinf(elR)
        let meters = max(position.distance * radiusMeters(for: room), nearestMeters)
        return Point(x: right * meters, y: up * meters, z: -front * meters)
    }
}
