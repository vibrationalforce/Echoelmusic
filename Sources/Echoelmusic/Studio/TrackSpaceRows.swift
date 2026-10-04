#if canImport(SwiftUI)
import SwiftUI

/// Restructure S3d — the open track's place in the piece's space: a direction and a distance,
/// written through `SpatialSceneStore.setPosition`, the one writer the Stage drag and an
/// external ADM-OSC controller already use. The scene travels with the piece (A3a), so a place
/// set here comes back when the piece reopens; while the Mixer's "Headphone space" is on, an
/// AUDIO track is heard there (S3c — the coordinator hands the point over on its next step).
///
/// ⚠️ ITS OWN LEAF, ON PURPOSE (10.76.41/50 law): `SpatialSceneStore.scene` also moves at an
/// external controller's send rate (`apply(_:)`), and the inspector above hosts menu pickers.
/// Reading the scene here keeps that churn inside these two rows.
///
/// Two numbers, not a drag surface: tap-to-type and the VoiceOver adjust of `EchoelValueField`
/// are the alternative to a gesture, and "Default" puts the track back where a fresh rebuild
/// would (`SpatialSceneStore.defaultPosition`). Elevation and extent stay on the Stage.
/// ⚠️ No Undo step: the scene has no undo journal today (the Stage drag has none either), so
/// "Default" is the way back. NEEDS-FOUNDER-VERIFY: G6 — a track moved here is heard there.
@MainActor
struct TrackSpaceRows: View {
    @Environment(SpatialSceneStore.self) private var spatial
    @Environment(TimelineStore.self) private var timeline
    let laneID: UUID
    let isAudio: Bool

    var body: some View {
        if let object = spatial.object(forLane: laneID) {
            let standard = SpatialSceneStore.defaultPosition(forLane: laneID, in: timeline.document.lanes)
            VStack(alignment: .leading, spacing: 6) {
                Text("Space")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                EchoelValueField(
                    label: "Direction",
                    value: Binding(
                        get: { Double(object.position.azimuth) },
                        set: { move(azimuth: Float($0)) }),
                    range: -180...180,
                    unit: "°",
                    decimals: 0,
                    hint: String(localized: "0 in front, 90 left, −90 right, 180 behind"),
                    standard: standard.map { Double($0.azimuth) })
                EchoelValueField(
                    label: "Distance",
                    value: Binding(
                        get: { Double(object.position.distance) },
                        set: { move(distance: Float($0)) }),
                    range: 0...1,
                    decimals: 2,
                    hint: String(localized: "0 at your head, 1 at the edge of the room"),
                    standard: standard.map { Double($0.distance) })
                Text(isAudio
                     ? String(localized: "Heard on headphones while Headphone space is on, and sent to an ADM-OSC rig.")
                     : String(localized: "Sent to an ADM-OSC rig. On headphones a generated voice stays in the stereo mix."))
                    .font(EchoelTheme.font(11))
                    .foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// One axis moves; the others keep their value. `SpatialPosition` clamps and maps a
    /// non-finite number to the origin, so a typed value can never leave the room.
    private func move(azimuth: Float? = nil, distance: Float? = nil) {
        guard let current = spatial.object(forLane: laneID)?.position else { return }
        spatial.setPosition(laneID: laneID, SpatialPosition(
            azimuth: azimuth ?? current.azimuth,
            elevation: current.elevation,
            distance: distance ?? current.distance))
    }
}
#endif
