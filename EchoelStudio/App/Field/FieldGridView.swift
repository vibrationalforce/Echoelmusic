import EchoelCore
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The note grid's settings: whether it shows over the full-screen Field, Hold, and the octave its
/// bottom row starts in. Kept on this device, like the keys strip's, never in the song.
enum FieldGridSetting {
    static let shownKey = "field.grid.shown"
    static let holdKey = "field.grid.hold"
    static let lowestOctaveKey = "field.grid.lowestOctave"
}

/// The note grid over the full-screen Field (G4): the picture made playable, as the earlier app's
/// touch instrument was. Columns are the pitches the song's scale sounds in one octave, rows are
/// octaves, the lowest at the bottom (`FieldGrid`). A touch plays the live track down the one live
/// path the keys on the screen use (`AudioEngine.live`), on MIDI channel 15, so a running take
/// records it and MPE Out sends it as it does a key. Shown while it is switched on and the live
/// track is played on keys; a drum kit and a sliced sampler keep their pads. While the external
/// display shows the Field, the grid lies on the black ground here, over the corner pin, which
/// waits until the grid is off.
///
/// Reads only cold values — the song's key, scale and tone system, the live track and its
/// instrument, the switches — never the playhead or the touch light (Law 6). The touches live in
/// the UIKit view, the light they leave in `FieldTouchChannel`.
struct FieldGridView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @AppStorage(FieldGridSetting.shownKey) private var shown = false
    @AppStorage(FieldGridSetting.holdKey) private var hold = false
    @AppStorage(FieldGridSetting.lowestOctaveKey) private var lowestOctave = FieldGrid.defaultLowestOctave
    /// The keys strip's Touch Loudness switch: off, every cell plays one loudness, as a key does.
    @AppStorage(PlayKeysView.touchLoudnessKey) private var touchLoudness = true

    var body: some View {
        let project = store.project
        if shown, let track = Self.keysTrack(in: project, engine: engine) {
            surface(FieldGrid(context: project.context, device: track.instrument.device, lowestOctave: lowestOctave),
                    plays: LiveTrackChoice.header(live: track.id, in: project))
        }
    }

    /// The live track where it is played on keys; nil for none, a drum kit or a sliced sampler,
    /// whose keys pick a sound rather than a pitch (`PlaySurface`).
    static func keysTrack(in project: Project, engine: AudioEngine) -> Track? {
        guard let track = engine.liveTrackID(in: project).flatMap(project.track),
              PlaySurface.surface(for: track.instrument) == .keys else { return nil }
        return track
    }

    /// The cells and the touches over the whole screen, the cells inside its safe area. Laid out
    /// left to right in every language: low notes on the left, as on a keyboard. `title` says what it
    /// plays, as the keys' header does ("Plays Keys").
    private func surface(_ grid: FieldGrid, plays title: String) -> some View {
        GeometryReader { proxy in
            let geometry = Self.layout(of: proxy)
            ZStack(alignment: .topLeading) {
                FieldGridCells(grid: grid, geometry: geometry)
                #if canImport(UIKit)
                FieldGridTouchSurface(router: engine.live, grid: grid, geometry: geometry, hold: hold,
                                      placesLoudness: touchLoudness,
                                      spoken: Self.spoken(grid, plays: title, hold: hold))
                #endif
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .background(ExternalFieldStage.shared.isShowing ? Theme.Color.background : Color.clear)
        .ignoresSafeArea()
        .environment(\.layoutDirection, .leftToRight)
    }

    /// The view's whole size, where the picture lies, and its safe area, where the cells do: one
    /// rect for the cells, the touches on them and the light under them (`FieldGrid.Geometry`).
    private static func layout(of proxy: GeometryProxy) -> FieldGrid.Geometry {
        let size = proxy.size, inset = proxy.safeAreaInsets
        return FieldGrid.Geometry(viewWidth: Double(size.width), viewHeight: Double(size.height),
                                  play: FieldGrid.Rect(x: Double(inset.leading), y: Double(inset.top),
                                                       width: Double(size.width - inset.leading - inset.trailing),
                                                       height: Double(size.height - inset.top - inset.bottom)))
    }

    /// What VoiceOver says the grid is: what it plays (`title`) and how it is laid out.
    private static func spoken(_ grid: FieldGrid, plays title: String, hold: Bool) -> String {
        var parts = [title, "\(grid.columns.count) notes across from \(NoteEditing.name(of: grid.lowestPitch))",
                     "an octave a row, the lowest at the bottom"]
        if hold { parts.append("Hold on") }
        return parts.joined(separator: ", ")
    }
}

/// The cells drawn over the picture: each cell's outline thin in its column's light, the colour of
/// what it sounds (`FieldGrid.colour(of:)`), so an octave reads as a column of one colour; the low
/// row the strongest, the root's column a little bolder, both thicker with Increase Contrast. Each
/// cell carries its note's name on a chip of its light, dark enough that the text reads at AA
/// (`ToneLight.keyFill`): colour is never the only cue. The root's column names its octave too.
/// Takes no touches; drawn again only when the grid, the size or the contrast setting changes.
private struct FieldGridCells: View {
    let grid: FieldGrid
    let geometry: FieldGrid.Geometry
    @Environment(\.colorSchemeContrast) private var contrast

    /// The space between two cells' outlines, points.
    private static let gap: CGFloat = 2

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(grid.cells) { cell in
                face(of: cell)
            }
        }
        .frame(width: CGFloat(geometry.viewWidth), height: CGFloat(geometry.viewHeight), alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .dynamicTypeSize(...Theme.Accessibility.denseStripLimit)
    }

    private func face(of cell: FieldGrid.Cell) -> some View {
        let drawn = geometry.frame(of: cell, in: grid)
        let hertz = grid.hertz(of: cell)
        return RoundedRectangle(cornerRadius: Theme.Radius.small)
            .strokeBorder(Theme.Color.linear(grid.colour(of: cell), opacity: lineOpacity(of: cell)),
                          lineWidth: lineWidth(of: cell))
            .overlay {
                if cell.isEnabled { chip(of: cell, hertz: hertz) }
            }
            .frame(width: Swift.max(CGFloat(drawn.width) - Self.gap, 0), height: Swift.max(CGFloat(drawn.height) - Self.gap, 0))
            .position(x: CGFloat(drawn.midX), y: CGFloat(drawn.midY))
    }

    private func chip(of cell: FieldGrid.Cell, hertz: Double) -> some View {
        Text(name(of: cell))
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.text)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, Theme.Space.xs)
            .padding(.vertical, Theme.Space.xxs)
            .background(Theme.Color.linear(ToneLight.keyFill(forToneHz: hertz)),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .padding(Theme.Space.xxs)
    }

    /// The low row strongest, as the earlier app weighted its octaves; a cell that plays nothing faint.
    private func lineOpacity(of cell: FieldGrid.Cell) -> Double {
        guard cell.isEnabled else { return 0.3 }
        guard contrast != .increased else { return 1 }
        return 1 - 0.2 * Double(Swift.min(Swift.max(cell.row, 0), FieldGrid.rowCount - 1))
    }

    private func lineWidth(of cell: FieldGrid.Cell) -> CGFloat {
        (isRoot(cell) ? 2 : 1) + (contrast == .increased ? 1 : 0)
    }

    private func isRoot(_ cell: FieldGrid.Cell) -> Bool {
        grid.columns.indices.contains(cell.column) && grid.columns[cell.column].interval == 0
    }

    /// The note's name; on the root's column with its octave, which says the row's.
    private func name(of cell: FieldGrid.Cell) -> String {
        let full = NoteEditing.name(of: cell.pitch)
        guard !isRoot(cell) else { return full }
        return String(full.prefix { (character: Character) -> Bool in !character.isNumber && character != "-" })
    }
}

/// The grid's switch in the full-screen Field's bar, on the glyph the earlier app gave its note
/// grid. Dimmed while the live track plays pads or there is none.
struct FieldGridSwitch: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @AppStorage(FieldGridSetting.shownKey) private var shown = false

    var body: some View {
        let playable = FieldGridView.keysTrack(in: store.project, engine: engine) != nil
        Button { shown.toggle() } label: { Image(systemName: "square.grid.3x3") }
            .buttonStyle(ToolButtonStyle(isActive: shown && playable))
            .disabled(!playable)
            .accessibilityLabel("Note Grid")
            .accessibilityValue(shown ? "On" : "Off")
            .accessibilityHint(playable ? "Plays the live track from the picture, an octave a row."
                                        : "Needs an instrument track that is played on keys.")
    }
}

/// Hold and the octave of the grid's bottom row, under the full-screen Field's bar while the grid
/// shows. Device settings, so no command and no song change.
struct FieldGridControls: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @AppStorage(FieldGridSetting.shownKey) private var shown = false
    @AppStorage(FieldGridSetting.holdKey) private var hold = false
    @AppStorage(FieldGridSetting.lowestOctaveKey) private var lowestOctave = FieldGrid.defaultLowestOctave

    var body: some View {
        let project = store.project
        if shown, let track = FieldGridView.keysTrack(in: project, engine: engine) {
            row(FieldGrid(context: project.context, device: track.instrument.device, lowestOctave: lowestOctave))
        }
    }

    private func row(_ grid: FieldGrid) -> some View {
        let lowest = NoteEditing.name(of: grid.lowestPitch)
        return HStack(spacing: Theme.Space.s) {
            Button { hold.toggle() } label: { Text("Hold") }
                .buttonStyle(ToolButtonStyle(isActive: hold))
                .accessibilityLabel("Hold")
                .accessibilityValue(hold ? "On" : "Off")
                .accessibilityHint("Keeps a note sounding after the finger lifts, until its cell is touched again.")
            // Each octave button says where the grid starts, so a press is heard to land.
            Button { lowestOctave = grid.shifted(byOctaves: -1).lowestOctave } label: { Image(systemName: "minus") }
                .buttonStyle(ToolButtonStyle())
                .disabled(!grid.canShiftDown)
                .accessibilityLabel("Octave Down")
                .accessibilityValue("Lowest note \(lowest)")
            Text(lowest)
                .font(Theme.Font.value)
                .foregroundStyle(Theme.Color.text)
                .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .accessibilityLabel("Lowest Note")
                .accessibilityValue(lowest)
            Button { lowestOctave = grid.shifted(byOctaves: 1).lowestOctave } label: { Image(systemName: "plus") }
                .buttonStyle(ToolButtonStyle())
                .disabled(!grid.canShiftUp)
                .accessibilityLabel("Octave Up")
                .accessibilityValue("Lowest note \(lowest)")
        }
    }
}

#if canImport(UIKit)
/// The grid's touches. A UIKit view, because five fingers at once, each with its force and the
/// size of its contact (`FieldGrid.velocity`), come from UIKit's touches, not SwiftUI's gestures.
/// Input only: `FieldGridCells` draws the cells. Every note ends when the view goes.
private struct FieldGridTouchSurface: UIViewRepresentable {
    let router: LiveRouter
    let grid: FieldGrid
    let geometry: FieldGrid.Geometry
    let hold: Bool
    let placesLoudness: Bool
    /// What VoiceOver says the grid is.
    let spoken: String

    func makeUIView(context: Context) -> FieldGridTouchView {
        let view = FieldGridTouchView(router: router)
        apply(to: view)
        return view
    }

    func updateUIView(_ view: FieldGridTouchView, context: Context) {
        apply(to: view)
    }

    /// The view goes — the grid switched off, the full screen left, the live track turned to pads:
    /// every note ends, the ones Hold kept too.
    static func dismantleUIView(_ view: FieldGridTouchView, coordinator: ()) {
        view.releaseAll()
    }

    private func apply(to view: FieldGridTouchView) {
        view.play(grid, in: geometry, placesLoudness: placesLoudness)
        view.setHold(hold)
        view.accessibilityValue = spoken
    }
}

/// The fingers on the grid, as UIKit reports them, each numbered while it is down. Each touch goes
/// through `FieldGridTouches`, and what that returns goes out: notes down the live path, drops
/// into the touch light (`FieldTouchChannel`), and the notes that sound, for the clouds.
private final class FieldGridTouchView: UIView {
    /// The grid plays on MIDI channel 15. The keys strip plays on 16, so `LiveKeys` holds a cell and
    /// a key on one pitch as two keys, and a cell's lift never ends a key still held there.
    private static let noteOn: UInt8 = 0x9E
    private static let noteOff: UInt8 = 0x8E

    private let router: LiveRouter
    private var grid: FieldGrid?
    private var geometry = FieldGrid.Geometry(viewWidth: 0, viewHeight: 0)
    private var placesLoudness = true
    private var hands = FieldGridTouches()
    /// The fingers down, by the touch UIKit reports each as, numbered for `hands`.
    private var fingers: [ObjectIdentifier: Int] = [:]
    private var nextFinger = 0

    init(router: LiveRouter) {
        self.router = router
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        isOpaque = false
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityLabel = "Note Grid"
        accessibilityHint = "Touch a cell to play its note. With Hold on, a note sounds until its cell is touched again."
        accessibilityTraits = .allowsDirectInteraction
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// The grid as it is now, laid out by `geometry`. A held note keeps the pitch it struck until
    /// its finger moves.
    func play(_ grid: FieldGrid, in geometry: FieldGrid.Geometry, placesLoudness: Bool) {
        self.grid = grid
        self.geometry = geometry
        self.placesLoudness = placesLoudness
        FieldTouchChannel.shared.sound(hands.notes(on: grid))
    }

    /// Hold on or off; off ends what it kept.
    func setHold(_ on: Bool) {
        guard on != hands.holds else { return }
        send(hands.setHold(on))
    }

    /// Every note ends, the ones Hold kept too; the fingers still down play nothing more.
    func releaseAll() {
        send(hands.releaseAll())
        fingers.removeAll()
    }

    /// The view leaves its window — its scene or window closed, the hosting views torn down without
    /// SwiftUI dismantling this one first: every note ends, the ones Hold kept too, as the earlier
    /// app's touch instrument ended them. A second release, from `dismantleUIView`, finds nothing
    /// sounding and sends nothing.
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { releaseAll() }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let grid else { return }
        for touch in touches {
            let finger = nextFinger
            nextFinger &+= 1
            fingers[ObjectIdentifier(touch)] = finger
            send(hands.began(finger, at: contact(of: touch), on: grid, in: geometry), announcing: true)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let grid else { return }
        for touch in touches {
            guard let finger = fingers[ObjectIdentifier(touch)] else { continue }
            send(hands.moved(finger, to: contact(of: touch), on: grid, in: geometry), announcing: true)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let finger = fingers.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            send(hands.ended(finger))
        }
    }

    /// The system took the touches (a call, a notification pulled down): every note ends, the ones
    /// Hold kept too, as when the grid goes.
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseAll()
    }

    /// Where `touch` is on this view and how hard it plays there.
    private func contact(of touch: UITouch) -> FieldGridTouches.Contact {
        let point = touch.location(in: self)
        let played = FieldGrid.velocity(force: Double(touch.force), maximumForce: Double(touch.maximumPossibleForce),
                                        majorRadius: Double(touch.majorRadius), placesLoudness: placesLoudness)
        return FieldGridTouches.Contact(x: Double(point.x), y: Double(point.y), velocity: played)
    }

    /// Sends what the grid says, in its order: notes down the live path, drops into the touch light,
    /// all stamped with one reading of the renderers' clock; then the notes that sound, for the
    /// clouds. With VoiceOver on, a struck note says its name (`announcing`).
    private func send(_ events: [FieldGridTouches.Event], announcing: Bool = false) {
        guard !events.isEmpty else { return }
        let now = CFAbsoluteTimeGetCurrent()
        var struck: Int?
        for event in events {
            switch event {
            case let .noteOn(pitch, velocity):
                guard (0...127).contains(pitch) else { continue }
                router.receive(status: Self.noteOn, UInt8(pitch), velocity)
                struck = pitch
            case let .noteOff(pitch):
                guard (0...127).contains(pitch) else { continue }
                router.receive(status: Self.noteOff, UInt8(pitch), 0)
            case let .drop(x, y, toneHz, velocity, strong):
                FieldTouchChannel.shared.drop(x: x, y: y, toneHz: toneHz, velocity: velocity, strong: strong, at: now)
            }
        }
        if let grid {
            FieldTouchChannel.shared.sound(hands.notes(on: grid))
        } else {
            FieldTouchChannel.shared.sound([])
        }
        if announcing, let struck, UIAccessibility.isVoiceOverRunning {
            Theme.Accessibility.announce(Announcement(NoteEditing.name(of: struck), priority: .normal))
        }
    }
}
#endif
