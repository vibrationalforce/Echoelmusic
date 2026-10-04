// SpatialSceneStore.swift
// The live immersive scene: one SpatialObject per track, placed by ImmersiveObjectDefaults
// so "every instrument is immersive" by default. This is the control-plane model the Touch
// automation surface moves and ADMOSCSender streams out (send(scene:)).
// ⛔ "the VBAPPanner / BinauralPanner render" stood here and is FALSE (#1379): measured over
// all of Sources/, both have zero production callers — `VBAPPanner`, `AmbisonicsEncode` and
// `DSP/BinauralPanner` are built, tested cores with no render path. The CONTROL half of the
// space leg is real (this store → ADM-OSC objects on the wire); the RENDER half is not built.
// Keep them — the EchoelRender path needs exactly these — but do not cite them as sounding. Rebuilding from the timeline's lanes keeps the scene in step with the
// tracks; user/automation moves are preserved across a rebuild (only new/removed lanes change).
//
// @MainActor @Observable control plane — no audio-thread work. Pure mapping (lanes → objects)
// is delegated to ImmersiveObjectDefaults, so this stays a thin, testable store.

import Foundation
import Observation

@MainActor
@Observable
public final class SpatialSceneStore {

    /// The live scene — every playable track as a positioned immersive object.
    public private(set) var scene = SpatialScene()

    /// An in-memory scene with no working copy on disk — what every test constructs. The app
    /// constructs `workingCopy()` instead.
    public init() {}

    /// Restructure S3d review (MED): the scene's WORKING COPY, so a place given in the track
    /// inspector, by an ADM-OSC controller or by the room survives a relaunch, as the song does.
    /// Before this the scene lived only in memory and inside a SAVED piece: a relaunch rebuilt
    /// every object at its default, and only Open-from-library brought the places back.
    ///
    /// Launch needs nothing else: the app's first `rebuild(from:)` fits this loaded scene to the
    /// loaded song by lane id — ONE rule (#416): a known lane keeps its place, a new lane gets
    /// its default, a lane that is gone drops. Open and "New piece" go through the same rebuild,
    /// so a working copy never leaks into another piece (other lanes, other ids).
    ///
    /// ⚠️ LIMIT, stated where it is met: a failed write of THIS file is logged by
    /// `AppGroupStore` and not shown in `WorkingCopyStatusView`. Saving the piece writes the
    /// scene into the project too (`session.spatial`), and that write reports its outcome.
    public static func workingCopy() -> SpatialSceneStore {
        workingCopy(on: AppGroupStore(subdirectory: "Spatial"))
    }

    /// The seam `workingCopy()` uses, `internal` so a test can point it at its own directory.
    static func workingCopy(on disk: AppGroupStore) -> SpatialSceneStore {
        let store = SpatialSceneStore()
        if let saved = disk.load(SpatialScene.self, name: workingCopyName) { store.scene = saved }
        store.disk = disk
        return store
    }

    @ObservationIgnored private var disk: AppGroupStore?
    @ObservationIgnored private var writePending = false
    /// The working copy's file name — `internal` so a test can lay down a clean file first.
    static let workingCopyName = "scene"

    /// Write the working copy soon. At most ONE pending task at a time: an ADM-OSC controller
    /// moves objects at its full send rate, and a task per move would be the
    /// `Task { @MainActor }`-per-frame flood that froze open menus (10.76.48).
    private func persist() {
        guard disk != nil, !writePending else { return }
        writePending = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self else { return }
            self.writePending = false
            self.flushPendingSave()
        }
    }

    /// Write the working copy now — before the app may be suspended (the app's background
    /// path), so a move made in the last half second is not lost. Returns whether it reached
    /// the disk; true when there is no working copy to write.
    @discardableResult
    public func flushPendingSave() -> Bool {
        guard let disk else { return true }
        return disk.save(scene, name: Self.workingCopyName)
    }

    /// The lanes that become immersive objects: real (non-bio) tracks. Bio lanes drive
    /// modulation, not placement, so they are never objects.
    nonisolated private static func objectLanes(_ lanes: [TimelineLane]) -> [TimelineLane] {
        lanes.filter { !$0.isBio }
    }

    /// Rebuild the scene from the timeline's lanes. Each lane becomes one object placed by
    /// ImmersiveObjectDefaults (evenly around the ring, instrument-appropriate). A lane that
    /// already has an object KEEPS its current position (user/automation moves survive);
    /// only newly-added lanes get a default placement, and removed lanes drop out.
    public func rebuild(from lanes: [TimelineLane]) {
        let objectLanes = Self.objectLanes(lanes)
        let count = objectLanes.count
        // The room is the scene's, not the lanes': a rebuild carries it over (A3a — before it,
        // every rebuild reset it to the default, which a restored piece would have lost at once).
        var next = SpatialScene(room: scene.room)
        for (index, lane) in objectLanes.enumerated() {
            let id = lane.id.uuidString
            if let existing = scene.object(id: id) {
                next.upsert(existing)            // preserve a moved object as-is
            } else {
                let instrument = lane.builtinInstrument ?? .polySynth
                next.upsert(ImmersiveObjectDefaults.defaultObject(
                    for: instrument, laneID: lane.id, laneIndex: index, laneCount: count))
            }
        }
        // Only replace when something actually changed (avoids needless revision churn).
        if next.objects != scene.objects { scene = next; persist() }
    }

    /// Restructure A3a — install the scene a saved piece carries, then fit it to `lanes`. The
    /// fit is the ordinary `rebuild`, so the rule stays ONE rule (#416): a saved object whose
    /// lane is still in the piece keeps its position; a lane the scene does not know gets its
    /// default; an object whose lane is gone drops. Open calls this AFTER the song is installed,
    /// because installing the song already rebuilt the scene from defaults.
    public func restore(_ saved: SpatialScene, lanes: [TimelineLane]) {
        scene = saved
        cartesianHolds = [:]   // a hold belongs to the scene it was merged into
        rebuild(from: lanes)
        persist()
    }

    /// Move one track's object (the Touch surface / recorded automation drives this).
    public func setPosition(laneID: UUID, _ position: SpatialPosition) {
        guard var object = scene.object(id: laneID.uuidString) else { return }
        object.position = position
        scene.upsert(object)
        persist()
    }

    /// Spatial S1 — an external controller moved object `input.object` over ADM-OSC. The index
    /// is 1-based into the scene ARRAY (the routing table the outgoing stream numbers too); an
    /// index past the last track moves nothing. The move survives a `rebuild` like any other,
    /// because a rebuild keeps an existing object as-is.
    ///
    /// Single Cartesian leaves merge through a per-object `CartesianHold`, so `/x` then `/y`
    /// lands where `/y` then `/x` does. An unchanged result writes nothing: a controller cycling
    /// through N objects never repeats the receiver's last move, so its static positions arrive
    /// at the full send rate, and each would otherwise touch the observed `scene`.
    public func apply(_ input: ADMObjectInput) {
        let index = input.object - 1
        guard scene.objects.indices.contains(index) else { return }
        let current = scene.objects[index]
        let merged = input.applied(to: current, hold: cartesianHolds[current.id])
        cartesianHolds[current.id] = merged.hold
        guard merged.object != current else { return }
        scene.upsert(merged.object)
        persist()
    }

    /// The unprojected cube point per object id (see `ADMObjectInput.CartesianHold`). Not
    /// observed: it is input bookkeeping, never displayed.
    @ObservationIgnored private var cartesianHolds: [String: ADMObjectInput.CartesianHold] = [:]

    /// Set one track's apparent size / focus (0 = point source … 1 = enveloping).
    public func setExtent(laneID: UUID, _ extent: Float) {
        guard var object = scene.object(id: laneID.uuidString) else { return }
        object.extent = extent
        scene.upsert(object)
        persist()
    }

    /// The object for a lane, if the scene has one.
    public func object(forLane laneID: UUID) -> SpatialObject? {
        scene.object(id: laneID.uuidString)
    }

    /// Restructure S3d — the place `rebuild` gives this lane when the scene does not know it yet:
    /// the same `ImmersiveObjectDefaults` inputs (instrument, index and count among the object
    /// lanes), so the inspector's "Default" and a fresh rebuild can never disagree (#416).
    /// nil for a lane that is not an object (a bio lane, or one not in `lanes`).
    /// `nonisolated` (S-A1): a pure function of its arguments, so the pure `ImmersiveMasterPlan`
    /// asks the SAME rule instead of copying it.
    nonisolated public static func defaultPosition(forLane laneID: UUID, in lanes: [TimelineLane]) -> SpatialPosition? {
        let objectLanes = Self.objectLanes(lanes)
        guard let index = objectLanes.firstIndex(where: { $0.id == laneID }) else { return nil }
        return ImmersiveObjectDefaults.defaultPosition(
            for: objectLanes[index].builtinInstrument ?? .polySynth,
            laneIndex: index, laneCount: objectLanes.count)
    }
}
