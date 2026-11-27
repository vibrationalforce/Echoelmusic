import Foundation

/// The light a musician's touches leave on the Field (the playable grid over the picture), as plain
/// numbers the Field's shader draws and nothing else. A touch is a DROP: a colour bloom where the
/// finger landed, with one thin ring travelling out from it as it dissolves, in the played note's
/// colour. A sounding note is a CLOUD: a big soft light where its note lives, coming as the note
/// begins and fading when it ends. A cloud is colourless (the red flash, below, says why).
///
/// Ported from the earlier app: the drop slots and their policy from `TouchRippleChannel`, the
/// drop's shape from its shader's `rippleLight`, the five cloud slots and their time constants from
/// `FlashGuard`. As a value type: time is handed in and there is no clock inside, so the same
/// touches at the same times give the same light, and the renderer's own clock is the only one.
///
/// **The clouds are added light, not the earlier tint.** In the earlier app the clouds were the
/// picture's colour itself: where notes sounded, the Field took their mixed colour, faded to a warm
/// neutral elsewhere by the clouds' summed density (times 2.4 and held at 1, a flat top), and
/// glowed a little brighter there. Studio's Field wears its key's colour, and a cloud here is light laid over it as a
/// screen: a plain gaussian with no flat top, at most `cloudLuminance` (0.028) at its centre. The
/// reason is the luminance budget below: a tint moves a point by the difference between the
/// picture's colour and the note's, far past the general-flash threshold, as fast as the notes
/// come and go. Over the bright parts of the picture the screen shows only (1 − picture) of the
/// light, so a cloud there is faint. No device has shown it yet: whether it is colour enough is a
/// device look and a decision for the lead or the founder before the Field draws the clouds (G3,
/// G6). A tint that keeps each point's luminance, driven by these slots, would keep clear of the
/// general flash too, though not of the red one.
///
/// **The general flash (WCAG 2.3.1, luminance).** The earlier app left its colour path unproven:
/// about 73 % of a cloud's swing survived a 3 Hz on and off. Here every pitch wears its light at one
/// relative luminance — a drop at `dropLuminance` in its note's colour, a cloud at `cloudLuminance`
/// as a grey — so violet and red are as present as green. The drops together never add more than `dropLuminance` to any point, the
/// clouds together never more than `cloudLuminance`, and both together (`touchLuminance`) stay under
/// the general-flash threshold. A luminance swing under it is not a general flash, however fast it
/// repeats (the argument `FieldPulse.beatRingGain` makes for the beat ring), so no tapping, no number
/// of drops and no notes coming and going make a general flash at any point of the picture. Laid over
/// a still picture as a screen (`composite`), the light moves the shown luminance by at most its own.
/// On top of that, a cloud's brightest point moves no faster than `FlashLimit.maximumRate`
/// (`cloudWeightRate`).
///
/// Why the budget is shared and small: one luminance for every pitch is bounded by the dimmest full
/// colour, pure blue (0.0722 at full intensity); and a finger tapping a cell strikes a drop and
/// lights its note's cloud at the same place at the same moment, so the two must stay under the
/// threshold together, not each on its own.
///
/// **The red flash.** WCAG 2.3.1 also counts flashes of saturated red, which the luminance cannot
/// see, and `VideoFlashLimit` counts them in footage: a move of 20/320 of the red signal (linear
/// R − G − B) is a red transition.
///
/// The clouds cannot make one, by construction. A cloud is colourless, a grey at `cloudLuminance`
/// whatever its note. Laid over any picture as a screen, the clouds together raise each channel by
/// at most `cloudLuminance`, so the most they move a point's red signal is twice that (green and
/// blue rising over a red picture): 0.056, under the red step of 0.0625, however fast notes come
/// and go and however many overlap. `testTheCloudsNeverMoveTheRedSignalByARedStep` holds it. Until
/// 2026-11-27 the clouds wore their notes' colours at 0.04, and a simulation of the cloud path
/// showed a blue note (D4) tapped four times a second over the red picture of a song in A making
/// nine red transitions a second around its cell. A note's colour stays on its cell's outline and
/// name in the grid, which do not flash.
///
/// The drops are NOT covered. Nothing bounds their red signal: measured on 2026-11-27, per point at
/// 60 frames a second, a red note (A4) tapped 3.5 to 6 times a second over a dark picture makes 8
/// to 13 red transitions a second at 1,072 to 1,569 of 1,681 points within 0.2 heights of the tap,
/// a blue note over a red picture as many, and a sliding finger's wake drops 15. So no view sends
/// a drop (`FieldGridView`), and none may until the drops' light is bounded and simulated per
/// point. `FieldTouchLightTests.testTheRedFlashIsNotCovered` measures the drops' gap, so that it
/// cannot be read as covered. The Field's own rings are another matter and not this type's: at the
/// inputs `FieldLookTests` drives to their worst they reach 7 transitions at 16 of 441 points.
///
/// Under Reduce Motion or at the Field's lowest detail (`FieldDetail.isStill`): no drops, and the
/// clouds only fade. They do not grow, and a cloud handed to a new note fades out where it is
/// before the new note's cloud fades in at its own place, instead of travelling there.
///
/// Coordinates are the Field's own, the shader's `uv`: x and y from 0 to 1, from the left and from
/// the BOTTOM. Sizes are in heights of the frame, so a drop is round on any screen.
public struct FieldTouchLight: Equatable, Sendable {
    /// One drop or one cloud as a frame draws it.
    public struct Spot: Equatable, Sendable {
        /// Its place, in the Field's coordinates: 0 … 1 from the left and 0 … 1 from the bottom.
        public var x: Double
        public var y: Double
        /// A drop: the share of its life gone, 0 (just struck) … 1 (gone). A cloud: how far it has
        /// grown, 0 (its first, smaller size) … 1 (its full size).
        public var progress: Double
        /// How strong it is, 0 (dark) … 1.
        public var amplitude: Double
        /// Its colour at full strength, linear sRGB: its pitch's light at `dropLuminance` (a drop)
        /// or at `cloudLuminance` (a cloud).
        public var colour: ToneLight.RGB

        public init(x: Double, y: Double, progress: Double, amplitude: Double, colour: ToneLight.RGB) {
            self.x = x
            self.y = y
            self.progress = progress
            self.amplitude = amplitude
            self.colour = colour
        }

        /// An empty slot: dark, at the origin, its life over.
        public static let empty = Spot(x: 0, y: 0, progress: 1, amplitude: 0, colour: ToneLight.RGB(grey: 0))
    }

    /// A note that sounds now, as the clouds read it each frame.
    public struct Note: Equatable, Sendable {
        /// Who the note is from frame to frame (a pitch, or a pitch and its track): a cloud keeps its
        /// note, its colour and its place by this.
        public var id: Int
        /// The frequency it sounds at, hertz: its colour (`ToneLight`).
        public var toneHz: Double
        /// Where it lives on the Field (its cell on the grid), in the Field's coordinates.
        public var x: Double
        public var y: Double
        /// How loud it sounds, 0 … 1: how bright its cloud becomes. 0 or less is not sounding.
        public var level: Double
        /// Played live, by a finger or a key: its cloud answers at once. A note of the song comes in
        /// more gently, so a run of fast notes does not pulse the picture.
        public var isLive: Bool

        public init(id: Int, toneHz: Double, x: Double, y: Double, level: Double, isLive: Bool) {
            self.id = id
            self.toneHz = toneHz
            self.x = x
            self.y = y
            self.level = level
            self.isLive = isLive
        }
    }

    /// One frame of the touch light: every drop slot and every cloud slot, the empty ones `Spot.empty`.
    public struct Shown: Equatable, Sendable {
        public var drops: [Spot]
        public var clouds: [Spot]

        public init(drops: [Spot] = Array(repeating: .empty, count: FieldTouchLight.dropSlots),
                    clouds: [Spot] = Array(repeating: .empty, count: FieldTouchLight.cloudSlots)) {
            self.drops = drops
            self.clouds = clouds
        }

        /// The touch light at (`u`, `v`), the Field's coordinates, in a frame `aspect` wide for its
        /// height: what the Field's shader adds there (`composite`), linear sRGB. The drops' sum is
        /// held to `dropLuminance` and the clouds' to `cloudLuminance`, each keeping its hue, and the
        /// whole to the screen's gamut; so its luminance never passes `touchLuminance`. A point that
        /// is no number gets no light; an aspect that is not a positive number counts as square.
        public func light(u: Double, v: Double, aspect: Double) -> ToneLight.RGB {
            guard u.isFinite, v.isFinite else { return ToneLight.RGB(grey: 0) }
            let side = aspect.isFinite && aspect > 0 ? aspect : 1
            let pointX = u * side
            var dropSum = SIMD3<Double>(repeating: 0)
            for spot in drops where spot.amplitude > 0 && spot.progress < 1 {
                let dx = pointX - spot.x * side, dy = v - spot.y
                let shape = FieldTouchLight.dropShape(progress: spot.progress, distance: (dx * dx + dy * dy).squareRoot())
                dropSum += FieldTouchLight.channels(spot.colour) * (spot.amplitude * shape)
            }
            var cloudSum = SIMD3<Double>(repeating: 0)
            for spot in clouds where spot.amplitude > 0 {
                let dx = pointX - spot.x * side, dy = v - spot.y
                let shape = FieldTouchLight.cloudShape(progress: spot.progress, distance: (dx * dx + dy * dy).squareRoot())
                cloudSum += FieldTouchLight.channels(spot.colour) * (spot.amplitude * shape)
            }
            var total = FieldTouchLight.held(dropSum, to: FieldTouchLight.dropLuminance)
                + FieldTouchLight.held(cloudSum, to: FieldTouchLight.cloudLuminance)
            let peak = total.max()
            if peak > 1 { total /= peak }
            return ToneLight.RGB(red: total.x, green: total.y, blue: total.z)
        }
    }

    // MARK: - The drops (the earlier `TouchRippleChannel`)

    /// The drop slots the shader draws.
    public static let dropSlots = 6
    /// The least time between two wake drops (the trail a sliding finger leaves), seconds. A fast
    /// slide asked for one every 14 points; unbounded, that recycled all six slots ten times a second
    /// and cut each light out as it came (the earlier app's "machine-gun flicker").
    public static let wakeInterval = 0.05
    /// How long a strike (a note's attack) and a wake drop live, seconds.
    public static let strikeSeconds = 1.0
    public static let wakeSeconds = 0.65
    /// A wake drop's strength against a strike's (the earlier app's 0.28 against 0.5).
    public static let wakeShare = 0.56
    /// The share of its strength a drop keeps at the softest touch; how hard a touch played scales the rest.
    public static let softestShare = 0.6

    // MARK: - A drop's shape (the earlier shader's `rippleLight`; the Field's shader is written from these)

    /// The share of its life over which a drop eases in. A drop at full light in the frame it was
    /// struck popped in, in the earlier app.
    public static let dropOnset = 0.10
    /// The bloom's gaussian radius from the strike to the end of its life, heights of the frame: it
    /// grows as it dissolves, like ink in water.
    public static let dropBloomRadius: ClosedRange<Double> = 0.045...0.16
    /// The ring's radius over the drop's life and its width, heights of the frame.
    public static let dropRingRadius: ClosedRange<Double> = 0.02...0.34
    public static let dropRingWidth = 0.011
    /// The bloom's and the ring's gains: the earlier 0.34 and 0.42 in their ratio, scaled so a full
    /// drop's brightest point (the ring, just after it eased in) is just under one.
    public static let dropBloomGain = 0.68
    public static let dropRingGain = 0.85

    // MARK: - The clouds (the earlier app's cloud slots and `FlashGuard`'s time constants)

    /// The cloud slots the shader draws: one note each.
    public static let cloudSlots = 5
    /// How fast a cloud comes and goes, seconds (exponential time constants): a live note's cloud
    /// answers now, a song note's comes in gently (its 16th notes would otherwise bloom eight short
    /// clouds a second), and every cloud fades more slowly than it came.
    public static let liveRiseSeconds = 0.09
    public static let songRiseSeconds = 0.30
    public static let fallSeconds = 0.35
    /// A lit cloud carried over to a new note chases the note's colour and place with these time
    /// constants, seconds, so a visible cloud never jumps.
    public static let colourChaseSeconds = 0.18
    public static let placeChaseSeconds = 0.25
    /// Below this strength a cloud is too faint to see (under 0.0002 of luminance): a free slot this
    /// dark is taken first, and takes its new note's colour and place at once.
    public static let invisibleWeight = 0.004
    /// A cloud's gaussian radius as it starts and once grown, heights of the frame: big and soft.
    public static let cloudRadius: ClosedRange<Double> = 0.09...0.15

    // MARK: - The flash budget

    /// The relative luminance of a drop at its brightest point at full strength — every pitch the
    /// same — and the most all the drops together add to any point.
    public static let dropLuminance = 0.05
    /// The grey a cloud is at its centre at full strength — every pitch the same — and the most all
    /// the clouds together add to any channel of any point. Twice it stays under the red step
    /// (`VideoFlashLimit.redCellStep`), so the clouds can never make a red transition (the type's
    /// doc); do not raise it past that without bounding the red signal another way.
    public static let cloudLuminance = 0.028
    /// The most the touch light adds to any point's luminance: under
    /// `FlashLimit.generalFlashThreshold`, so no change of it is a general flash. It says nothing of
    /// the red flash (the type's doc).
    public static let touchLuminance = dropLuminance + cloudLuminance
    /// The fastest a cloud's strength may move, per second: its brightest point then moves at most
    /// `FlashLimit.maximumRate` of full scale a second, as every brightness of the Field does.
    public static let cloudWeightRate = FlashLimit.maximumRate / cloudLuminance
    /// The most one frame advances the clouds, seconds: a stall is not a fast fade (the renderer
    /// clamps its own steps the same way).
    public static let longestStep = 0.1

    // MARK: - State

    private struct Drop: Equatable, Sendable {
        var x: Double
        var y: Double
        var amplitude: Double
        var colour: ToneLight.RGB
        /// When it fell, on the renderer's clock, and how long it lives, seconds.
        var struck: Double
        var life: Double

        func progress(at now: Double) -> Double {
            Swift.min(Swift.max((now - struck) / life, 0), 1)
        }

        /// What is left of its light: its strength times the share of its life still to come.
        func remainingLight(at now: Double) -> Double {
            amplitude * Swift.max(0, 1 - (now - struck) / life)
        }

        func isSpent(at now: Double) -> Bool {
            now - struck >= life || now < struck
        }
    }

    private struct Cloud: Equatable, Sendable {
        /// The note it shows; nil while the slot is free.
        var note: Int?
        /// How strong it shows now, 0 … 1; how far it has grown, 0 … 1.
        var weight = 0.0
        var growth = 0.0
        /// What it shows now, and what its note asks for: it chases the one towards the other.
        var colour = ToneLight.RGB(grey: 0)
        var x = 0.0
        var y = 0.0
        var goalColour = ToneLight.RGB(grey: 0)
        var goalX = 0.0
        var goalY = 0.0
        /// Its note's level and whether it is played live, as last heard.
        var level = 0.0
        var isLive = false
    }

    private var drops: [Drop] = []
    private var clouds = [Cloud](repeating: Cloud(), count: FieldTouchLight.cloudSlots)
    private var lastWake = -Double.infinity
    private var lastNow: Double?

    public init() {}

    // MARK: - A touch

    /// A drop falls at (`x`, `y`) — a strike for a note's attack (`strong`), or a wake drop on the
    /// trail of a sliding finger — in the light of `toneHz`, as bright as `velocity` played (0 the
    /// softest … 1 the hardest), at `now` on the renderer's clock (the one `shown` is handed). True
    /// when it was taken. A place or a time that is no number makes no drop; a place outside the
    /// frame lands on its edge. A wake drop waits `wakeInterval` after the last and never takes the
    /// slot of a live light. With every slot lit, a strike takes the slot of the dimmest light — its
    /// strength times the life it has left — never simply the oldest, which may still be bright (the
    /// earlier app's first version cut a bright ring to black in one frame that way).
    @discardableResult
    public mutating func drop(x: Double, y: Double, toneHz: Double, velocity: Double, strong: Bool,
                              at now: Double) -> Bool {
        guard x.isFinite, y.isFinite, now.isFinite else { return false }
        drops.removeAll { (falling: Drop) -> Bool in falling.isSpent(at: now) }
        if !strong {
            guard drops.count < Self.dropSlots else { return false }
            // A clock that went back starts the interval again instead of holding every wake drop.
            guard now - lastWake >= Self.wakeInterval || now < lastWake else { return false }
            lastWake = now
        } else if drops.count >= Self.dropSlots {
            let dimmest = drops.indices.min { (first: Int, second: Int) -> Bool in
                drops[first].remainingLight(at: now) < drops[second].remainingLight(at: now)
            }
            if let dimmest { drops.remove(at: dimmest) }
        }
        let played = velocity.isNaN ? 0 : Swift.min(1, Swift.max(0, velocity))
        let strength = (strong ? 1 : Self.wakeShare) * (Self.softestShare + (1 - Self.softestShare) * played)
        drops.append(Drop(x: Self.unit(x), y: Self.unit(y), amplitude: strength,
                          colour: Self.evenColour(forToneHz: toneHz, luminance: Self.dropLuminance),
                          struck: now, life: strong ? Self.strikeSeconds : Self.wakeSeconds))
        return true
    }

    // MARK: - A frame

    /// The frame at `now`: each drop as far through its life as `now` says, and the clouds stepped
    /// from the last frame towards `sounding`, the notes that sound now — at most `cloudSlots` of
    /// them shown, the first ones first, a note that is no number or not sounding left out, and of
    /// two notes with one id the first. `still` (Reduce Motion, `FieldDetail.isStill`) shows no drops
    /// and lets the clouds only fade. The first frame shows the clouds of notes already sounding as
    /// they are, lit and grown: it is the view's first picture, not a change. A time that is no number
    /// is the last time; a clock that went back steps nothing and drops the drops it cannot place.
    public mutating func shown(now: Double, still: Bool, sounding: [Note]) -> Shown {
        let time = now.isFinite ? now : (lastNow ?? 0)
        let isFirst = lastNow == nil
        let elapsed = Swift.min(Swift.max(time - (lastNow ?? time), 0), Self.longestStep)
        lastNow = time
        if still {
            drops.removeAll()
        } else {
            drops.removeAll { (falling: Drop) -> Bool in falling.isSpent(at: time) }
        }
        stepClouds(towards: sounding, after: elapsed, still: still, first: isFirst)

        var frame = Shown()
        for (index, falling) in drops.prefix(Self.dropSlots).enumerated() {
            frame.drops[index] = Spot(x: falling.x, y: falling.y, progress: falling.progress(at: time),
                                      amplitude: falling.amplitude, colour: falling.colour)
        }
        for (index, cloud) in clouds.enumerated() where cloud.weight > 0 {
            frame.clouds[index] = Spot(x: cloud.x, y: cloud.y, progress: cloud.growth, amplitude: cloud.weight,
                                       colour: cloud.colour)
        }
        return frame
    }

    /// The clouds `seconds` after the last frame (the earlier app's slot policy). A slot keeps the
    /// note it holds. A new note takes a free slot, a dark one first, the quietest of them: a fading
    /// cloud fades where it is. Only when every free slot is still lit does the quietest carry over,
    /// keeping its light and chasing the new note's colour and place — or, while still, fading out
    /// first. Every strength eases by its time constant and never faster than `cloudWeightRate`.
    private mutating func stepClouds(towards sounding: [Note], after seconds: Double, still: Bool, first: Bool) {
        var notes: [Note] = []
        for note in sounding where note.x.isFinite && note.y.isFinite && note.level.isFinite && note.level > 0 {
            guard !notes.contains(where: { (heard: Note) -> Bool in heard.id == note.id }) else { continue }
            notes.append(Note(id: note.id, toneHz: note.toneHz, x: Self.unit(note.x), y: Self.unit(note.y),
                              level: Swift.min(note.level, 1), isLive: note.isLive))
        }
        var taken = [Bool](repeating: false, count: clouds.count)
        var handing = [Bool](repeating: false, count: clouds.count)
        var placed = [Bool](repeating: false, count: notes.count)
        // A slot keeps the note it holds: the same colour, the same place.
        for slot in clouds.indices {
            guard let id = clouds[slot].note,
                  let index = notes.indices.first(where: { (candidate: Int) -> Bool in
                      !placed[candidate] && notes[candidate].id == id
                  })
            else { continue }
            placed[index] = true
            taken[slot] = true
            follow(notes[index], in: slot)
        }
        // A new note takes a free slot.
        for index in notes.indices where !placed[index] {
            let free = clouds.indices.filter { (slot: Int) -> Bool in !taken[slot] }
            let dark = free.filter { (slot: Int) -> Bool in clouds[slot].weight < Self.invisibleWeight }
            if dark.isEmpty, still {
                // While still, a lit cloud is not handed over in place: the quietest fades out first,
                // as fast as it may, and the note takes it once it is dark.
                let candidates = free.filter { (slot: Int) -> Bool in !handing[slot] }
                if let quietest = candidates.min(by: { (a: Int, b: Int) -> Bool in clouds[a].weight < clouds[b].weight }) {
                    handing[quietest] = true
                }
                continue
            }
            let choices = dark.isEmpty ? free : dark
            guard let slot = choices.min(by: { (a: Int, b: Int) -> Bool in clouds[a].weight < clouds[b].weight }) else { break }
            taken[slot] = true
            clouds[slot].note = notes[index].id
            follow(notes[index], in: slot)
            if clouds[slot].weight < Self.invisibleWeight {
                // Dark: it takes its note's colour and place at once (nothing showed there) and grows
                // from small; its strength rises from where it is, so even that does not jump.
                clouds[slot].growth = 0
                clouds[slot].colour = clouds[slot].goalColour
                clouds[slot].x = clouds[slot].goalX
                clouds[slot].y = clouds[slot].goalY
            }
        }
        let room = Self.cloudWeightRate * seconds
        for slot in clouds.indices {
            var cloud = clouds[slot]
            let target = taken[slot] ? cloud.level : 0
            let rise = cloud.isLive ? Self.liveRiseSeconds : Self.songRiseSeconds
            if first {
                cloud.weight = target
                cloud.growth = 1
                cloud.colour = cloud.goalColour
                cloud.x = cloud.goalX
                cloud.y = cloud.goalY
            } else {
                let tau = target > cloud.weight ? rise : (handing[slot] ? 0 : Self.fallSeconds)
                let eased = Self.ease(cloud.weight, target, tau: tau, seconds: seconds)
                var next = cloud.weight + Swift.min(room, Swift.max(-room, eased - cloud.weight))
                if !taken[slot], next < Self.invisibleWeight {
                    // Going dark: the last of its light goes now, as far as the rate allows.
                    next = Swift.max(0, cloud.weight - room)
                }
                cloud.weight = next
                if still {
                    // No travel and no growth: what changes, changes in place.
                    cloud.colour = cloud.goalColour
                    cloud.x = cloud.goalX
                    cloud.y = cloud.goalY
                    cloud.growth = 1
                } else {
                    let colourTau = Self.colourChaseSeconds, placeTau = Self.placeChaseSeconds
                    cloud.colour = ToneLight.RGB(red: Self.ease(cloud.colour.red, cloud.goalColour.red, tau: colourTau, seconds: seconds),
                                                 green: Self.ease(cloud.colour.green, cloud.goalColour.green, tau: colourTau, seconds: seconds),
                                                 blue: Self.ease(cloud.colour.blue, cloud.goalColour.blue, tau: colourTau, seconds: seconds))
                    cloud.x = Self.ease(cloud.x, cloud.goalX, tau: placeTau, seconds: seconds)
                    cloud.y = Self.ease(cloud.y, cloud.goalY, tau: placeTau, seconds: seconds)
                    if taken[slot] { cloud.growth = Self.ease(cloud.growth, 1, tau: rise, seconds: seconds) }
                }
            }
            // A free slot that has gone dark lets its note go.
            clouds[slot] = (!taken[slot] && cloud.weight <= 0) ? Cloud() : cloud
        }
    }

    /// The slot `slot` hears its note this frame: its level, how it is played, its colour and place.
    private mutating func follow(_ note: Note, in slot: Int) {
        clouds[slot].level = note.level
        clouds[slot].isLive = note.isLive
        // Colourless on purpose: a grey cannot make a red flash (the type's doc).
        clouds[slot].goalColour = ToneLight.RGB(grey: Self.cloudLuminance)
        clouds[slot].goalX = note.x
        clouds[slot].goalY = note.y
    }

    // MARK: - The light

    /// `light` laid over `picture` as a screen, the way the Field composes it: picture + light ×
    /// (1 − picture), channel by channel. It brightens and never passes full, and it adds at most the
    /// light's own luminance — so over a still picture the touch light can move a point's luminance by
    /// no more than `touchLuminance`. It can still move the hue far: a blue light over a red picture
    /// takes from the picture's red signal about as much as it adds in blue.
    public static func composite(_ light: ToneLight.RGB, over picture: ToneLight.RGB) -> ToneLight.RGB {
        ToneLight.RGB(red: picture.red + light.red * (1 - picture.red),
                      green: picture.green + light.green * (1 - picture.green),
                      blue: picture.blue + light.blue * (1 - picture.blue))
    }

    /// The light of `toneHz` (`ToneLight.colour`) brought to the relative luminance `luminance`,
    /// its hue kept and never past the screen's gamut (`ToneLight.shade` at full saturation). Every
    /// pitch reaches the budgets here: pure blue, the dimmest full colour, reaches 0.0722. A tone
    /// that is no number wears ToneLight's grey at that luminance.
    static func evenColour(forToneHz toneHz: Double, luminance: Double) -> ToneLight.RGB {
        ToneLight.shade(ToneLight.colour(forToneHz: toneHz), saturation: 1, luminance: luminance)
    }

    /// One drop's light at `distance` (heights of the frame) from where it fell, `progress` through
    /// its life, at most (just under) one: a gaussian bloom that grows as it dissolves, and one thin
    /// ring as its leading edge, both easing in over `dropOnset` and fading as the life runs out.
    /// The Field's shader draws the same function.
    static func dropShape(progress: Double, distance: Double) -> Double {
        guard progress.isFinite, distance.isFinite, progress < 1 else { return 0 }
        let lived = Swift.max(0, progress)
        let life = 1 - lived
        let onset = smoothstep(0, dropOnset, lived)
        let spread = 1 - life * life
        let sigma = mix(dropBloomRadius.lowerBound, dropBloomRadius.upperBound, spread)
        let bloom = Foundation.exp(-distance * distance / (2 * sigma * sigma)) * life * dropBloomGain
        let radius = mix(dropRingRadius.lowerBound, dropRingRadius.upperBound, spread)
        let edge = (distance - radius) / dropRingWidth
        let ring = Foundation.exp(-edge * edge) * life * life * dropRingGain
        return onset * (bloom + ring)
    }

    /// One cloud's light at `distance` (heights of the frame) from its note's place, grown
    /// `progress` of the way to its full size: one at its centre, a gaussian.
    static func cloudShape(progress: Double, distance: Double) -> Double {
        guard distance.isFinite else { return 0 }
        let grown = progress.isFinite ? Swift.min(Swift.max(progress, 0), 1) : 1
        let sigma = mix(cloudRadius.lowerBound, cloudRadius.upperBound, grown)
        return Foundation.exp(-distance * distance / (2 * sigma * sigma))
    }

    /// `rgb` held to the relative luminance `ceiling`, its hue kept: scaled down where it is brighter.
    static func held(_ rgb: SIMD3<Double>, to ceiling: Double) -> SIMD3<Double> {
        let lit = (rgb * SIMD3<Double>(0.2126, 0.7152, 0.0722)).sum()
        return lit > ceiling ? rgb * (ceiling / lit) : rgb
    }

    static func channels(_ colour: ToneLight.RGB) -> SIMD3<Double> {
        SIMD3<Double>(colour.red, colour.green, colour.blue)
    }

    /// `value` moved towards `target` by exponential smoothing with time constant `tau` over
    /// `seconds`: the same glide at any frame rate. No time, no step; no time constant, the target.
    static func ease(_ value: Double, _ target: Double, tau: Double, seconds: Double) -> Double {
        guard seconds > 0 else { return value }
        guard tau > 0 else { return target }
        return value + (target - value) * (1 - Foundation.exp(-seconds / tau))
    }

    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = Swift.min(Swift.max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private static func unit(_ value: Double) -> Double { Swift.min(1, Swift.max(0, value)) }
}
