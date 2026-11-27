import Foundation

/// The fingers on the note grid over the Field (`FieldGrid`): which note each finger struck, which
/// notes Hold keeps sounding, and what goes out when a finger lands, slides or lifts, when Hold is
/// switched, and when the grid goes away. The grid's view hands it every touch and sends what comes
/// back down the one live path the keys on the screen use; nothing here knows a screen or a router.
/// Pure, so the rules that keep a note from hanging are tested here.
///
/// The rules, the earlier app's touch instrument's and the keys strip's:
/// - A finger plays the cell it lands on. Sliding into another cell ends its note and strikes the
///   new cell's: the live path has no glide. A cell past MIDI's last note plays nothing.
/// - A release ends the pitch the finger STRUCK, never the one under it now, so a change of key,
///   scale or octave under a held finger leaves no note sounding. The finger plays the new grid
///   once it moves.
/// - Two fingers on one pitch strike it twice, and it ends with the last of them to let go. The
///   grid plays one key on one channel per pitch, and the engine pairs every note-on of a key with
///   one note-off (`LiveKeys`), so the first finger's lift must not cut the note the second holds.
/// - Hold: a lifted finger leaves its note sounding. A finger that lands on a note Hold keeps ends
///   it and plays nothing until it lifts. A finger that slides over one strikes it again and leaves
///   it kept. Hold switched off ends what it kept, never a note a finger still holds.
/// - At most `maximumFingers` play at once; another finger plays nothing until it lifts, even
///   after one of them has lifted.
/// - Gone (the grid switched off, the full screen left, a touch the system cancelled): every note
///   ends, the ones Hold kept too.
///
/// A struck note drops light where its finger is, and a sliding finger leaves a wake drop every
/// `wakeTravel` points (`FieldTouchLight.drop`); every note that sounds is a cloud on the cell it
/// was struck on (`notes(on:)`).
public struct FieldGridTouches: Sendable {
    /// What to send.
    public enum Event: Equatable, Sendable {
        /// Strike `pitch`, a MIDI note 0 … 127, this hard.
        case noteOn(pitch: Int, velocity: UInt8)
        /// End `pitch`.
        case noteOff(pitch: Int)
        /// A drop of touch light (`FieldTouchLight.drop`): where, in the Field's coordinates (0 … 1
        /// from the left and from the bottom), in the light of `toneHz`, as hard as it was played
        /// (0 the softest … 1 the hardest), a strike or a wake drop.
        case drop(x: Double, y: Double, toneHz: Double, velocity: Double, strong: Bool)
    }

    /// A finger as the screen saw it: where, in the grid view's points from its top-left corner,
    /// y down (`FieldGrid.Geometry`), and how hard it plays there (`FieldGrid.velocity`).
    public struct Contact: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var velocity: UInt8

        public init(x: Double, y: Double, velocity: UInt8) {
            self.x = x
            self.y = y
            self.velocity = velocity
        }
    }

    /// The most fingers that play at once: a hand. The built-in synth and sampler have sixteen
    /// voices, room for five fingers and what Hold keeps besides.
    public static let maximumFingers = 5
    /// How far a sliding finger travels between two wake drops, points (the earlier app's).
    public static let wakeTravel = 14.0

    /// A place in the Field's coordinates.
    private struct Place: Sendable {
        var x: Double
        var y: Double
    }

    private struct Finger: Sendable {
        /// The number the view gave it.
        let id: Int
        /// The pitch it sounds, as it struck it; nil on a cell that plays nothing, and on a finger
        /// that ended a note Hold kept.
        var pitch: Int?
        var velocity: UInt8
        /// The centre of the cell it struck: where its note's cloud lives.
        var home: Place
        /// Where it last dropped light, in the view's points: its wake drops count from there.
        var lastDropX: Double
        var lastDropY: Double
        /// It ended a note Hold kept: it plays nothing until it lifts.
        var isSpent: Bool
        /// When it struck, counted: the newest note's cloud comes first.
        var order: Int
    }

    /// A note Hold keeps after its finger lifted.
    private struct Kept: Sendable {
        let pitch: Int
        let velocity: UInt8
        let home: Place
        let order: Int
    }

    private var fingers: [Finger] = []
    private var kept: [Kept] = []
    private var strikes = 0

    /// Whether a lifted finger's note keeps sounding (`setHold`).
    public private(set) var holds = false

    public init() {}

    /// The pitches that sound now, each once, rising: what the fingers hold and what Hold keeps.
    public var soundingPitches: [Int] {
        Set(fingers.compactMap(\.pitch) + kept.map(\.pitch)).sorted()
    }

    // MARK: - A finger

    /// A finger the view numbered `finger` lands at `contact`, on `grid` laid out by `geometry`.
    /// A number already down lands nothing.
    public mutating func began(_ finger: Int, at contact: Contact, on grid: FieldGrid,
                               in geometry: FieldGrid.Geometry) -> [Event] {
        guard !fingers.contains(where: { (down: Finger) -> Bool in down.id == finger }),
              fingers.count < Self.maximumFingers else { return [] }
        let cell = Self.touchedCell(contact, on: grid, in: geometry)
        let home = Self.centre(of: cell, on: grid, in: geometry)
        var landed = Finger(id: finger, pitch: nil, velocity: contact.velocity, home: home, lastDropX: contact.x,
                            lastDropY: contact.y, isSpent: false, order: nextStrike())
        if holds, cell.isEnabled,
           let index = kept.firstIndex(where: { (note: Kept) -> Bool in note.pitch == cell.pitch }) {
            // A tap on a note Hold keeps ends it, strikes nothing and drops no light.
            kept.remove(at: index)
            landed.isSpent = true
            fingers.append(landed)
            return isSounding(cell.pitch) ? [] : [.noteOff(pitch: cell.pitch)]
        }
        guard cell.isEnabled else {
            fingers.append(landed)
            return []
        }
        landed.pitch = cell.pitch
        fingers.append(landed)
        return strike(cell.pitch, velocity: contact.velocity, at: contact, home: home, on: grid, in: geometry)
    }

    /// The finger `finger` moved to `contact`. Into another cell, it ends its note and strikes that
    /// cell's; along its cell, it leaves a wake drop every `wakeTravel` points.
    public mutating func moved(_ finger: Int, to contact: Contact, on grid: FieldGrid,
                               in geometry: FieldGrid.Geometry) -> [Event] {
        guard let index = fingers.firstIndex(where: { (down: Finger) -> Bool in down.id == finger }),
              !fingers[index].isSpent else { return [] }
        let cell = Self.touchedCell(contact, on: grid, in: geometry)
        let under: Int? = cell.isEnabled ? cell.pitch : nil
        var sliding = fingers[index]
        guard under != sliding.pitch else {
            guard let pitch = sliding.pitch, Self.travel(fromX: sliding.lastDropX, y: sliding.lastDropY, to: contact)
                    >= Self.wakeTravel else { return [] }
            sliding.lastDropX = contact.x
            sliding.lastDropY = contact.y
            fingers[index] = sliding
            let place = Self.fieldPlace(of: contact, in: geometry, otherwise: sliding.home)
            return [.drop(x: place.x, y: place.y, toneHz: grid.hertz(ofPitch: pitch),
                          velocity: Self.share(of: sliding.velocity), strong: false)]
        }
        let left = sliding.pitch
        let home = Self.centre(of: cell, on: grid, in: geometry)
        sliding.pitch = under
        sliding.velocity = contact.velocity
        sliding.home = home
        sliding.lastDropX = contact.x
        sliding.lastDropY = contact.y
        sliding.order = nextStrike()
        fingers[index] = sliding
        var events: [Event] = []
        if let left, !isSounding(left) { events.append(.noteOff(pitch: left)) }
        if let under {
            events += strike(under, velocity: contact.velocity, at: contact, home: home, on: grid, in: geometry)
        }
        return events
    }

    /// The finger `finger` lifted. Its note ends, unless another finger holds it or Hold keeps it.
    public mutating func ended(_ finger: Int) -> [Event] {
        guard let index = fingers.firstIndex(where: { (down: Finger) -> Bool in down.id == finger }) else { return [] }
        let lifted = fingers.remove(at: index)
        guard let pitch = lifted.pitch else { return [] }
        if holds {
            if !kept.contains(where: { (note: Kept) -> Bool in note.pitch == pitch }) {
                kept.append(Kept(pitch: pitch, velocity: lifted.velocity, home: lifted.home, order: lifted.order))
            }
            return []
        }
        return isSounding(pitch) ? [] : [.noteOff(pitch: pitch)]
    }

    // MARK: - Hold, and going away

    /// Hold on or off. Off ends the notes it kept, lowest first; the notes fingers hold sound on.
    public mutating func setHold(_ on: Bool) -> [Event] {
        guard on != holds else { return [] }
        holds = on
        guard !on else { return [] }
        let released = kept.map(\.pitch).sorted()
        kept.removeAll()
        return released.filter { (pitch: Int) -> Bool in !isSounding(pitch) }
            .map { (pitch: Int) -> Event in .noteOff(pitch: pitch) }
    }

    /// The grid goes away: every note ends, once, lowest first, the ones Hold kept too, and the
    /// fingers still down play nothing more. Hold stays as it is: it is the musician's switch.
    public mutating func releaseAll() -> [Event] {
        let pitches = soundingPitches
        fingers.removeAll()
        kept.removeAll()
        return pitches.map { (pitch: Int) -> Event in .noteOff(pitch: pitch) }
    }

    // MARK: - The clouds

    /// The notes that sound now as the Field's clouds read them (`FieldTouchLight.Note`), each once:
    /// the fingers' notes first, then the ones Hold keeps, the newest first in both; each on the
    /// cell it was struck on, in the light of what it sounds on `grid`, as bright as it was played,
    /// and live, so its cloud answers at once.
    public func notes(on grid: FieldGrid) -> [FieldTouchLight.Note] {
        var shown = Set<Int>()
        var out: [FieldTouchLight.Note] = []
        func add(_ pitch: Int, velocity: UInt8, home: Place) {
            guard shown.insert(pitch).inserted else { return }
            out.append(FieldTouchLight.Note(id: pitch, toneHz: grid.hertz(ofPitch: pitch), x: home.x, y: home.y,
                                            level: Double(velocity) / 127, isLive: true))
        }
        for finger in fingers.sorted(by: { (a: Finger, b: Finger) -> Bool in a.order > b.order }) {
            if let pitch = finger.pitch { add(pitch, velocity: finger.velocity, home: finger.home) }
        }
        for note in kept.sorted(by: { (a: Kept, b: Kept) -> Bool in a.order > b.order }) {
            add(note.pitch, velocity: note.velocity, home: note.home)
        }
        return out
    }

    // MARK: - The rules underneath

    /// The note-on and the strike's drop, where the finger is.
    private func strike(_ pitch: Int, velocity: UInt8, at contact: Contact, home: Place, on grid: FieldGrid,
                        in geometry: FieldGrid.Geometry) -> [Event] {
        let place = Self.fieldPlace(of: contact, in: geometry, otherwise: home)
        return [.noteOn(pitch: pitch, velocity: velocity),
                .drop(x: place.x, y: place.y, toneHz: grid.hertz(ofPitch: pitch), velocity: Self.share(of: velocity),
                      strong: true)]
    }

    /// Whether a finger holds `pitch` or Hold keeps it.
    private func isSounding(_ pitch: Int) -> Bool {
        fingers.contains { (down: Finger) -> Bool in down.pitch == pitch }
            || kept.contains { (note: Kept) -> Bool in note.pitch == pitch }
    }

    private mutating func nextStrike() -> Int {
        strikes &+= 1
        return strikes
    }

    /// The cell under `contact`: an edge cell beside the grid, the middle cell for a place that is no number.
    private static func touchedCell(_ contact: Contact, on grid: FieldGrid, in geometry: FieldGrid.Geometry) -> FieldGrid.Cell {
        let place = geometry.place(x: contact.x, y: contact.y)
        return grid.cell(atX: place.x, y: place.y)
    }

    /// The centre of `cell` in the Field's coordinates: where its note's cloud lives.
    private static func centre(of cell: FieldGrid.Cell, on grid: FieldGrid, in geometry: FieldGrid.Geometry) -> Place {
        let middle = geometry.uv(of: cell, in: grid)
        return Place(x: middle.x, y: middle.y)
    }

    /// Where `contact` lies on the Field's picture, which fills the grid's view: 0 … 1 from the left
    /// and from the bottom. A view with no size, or a place that is no number, gives `home`.
    private static func fieldPlace(of contact: Contact, in geometry: FieldGrid.Geometry, otherwise home: Place) -> Place {
        guard geometry.viewWidth > 0, geometry.viewHeight > 0, contact.x.isFinite, contact.y.isFinite else { return home }
        return Place(x: unit(contact.x / geometry.viewWidth), y: unit(1 - contact.y / geometry.viewHeight))
    }

    /// How far a finger went from (`x`, `y`) to `contact`, points; not a number when either is not.
    private static func travel(fromX x: Double, y: Double, to contact: Contact) -> Double {
        let dx = contact.x - x, dy = contact.y - y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// How hard `velocity` played on the keys' range (`TouchVelocity.softest` … `hardest`), 0 … 1:
    /// the drop's brightness.
    private static func share(of velocity: UInt8) -> Double {
        let softest = Double(TouchVelocity.softest), hardest = Double(TouchVelocity.hardest)
        return unit((Double(velocity) - softest) / (hardest - softest))
    }

    private static func unit(_ value: Double) -> Double { Swift.min(1, Swift.max(0, value)) }
}
