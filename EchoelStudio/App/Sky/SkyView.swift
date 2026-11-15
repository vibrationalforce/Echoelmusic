import EchoelCore
import SwiftUI

/// The sky, the second look of Cycle Tones (sky source S2, founder 2026-10-31: "a good picture even
/// when it is dark … intelligent and automatic, without the musician needing to know anything"; a
/// view of its own until Cycle Tones took its place on the bar, founder 2026-11-15).
/// The picture is COMPUTED — the star table, the Sun, Moon and planets, the place and the time,
/// turned by the phone's attitude — so it is sharp in total darkness and behind clouds. No
/// setting: it opens, finds the place once and follows the phone; a drag turns it by finger,
/// one button gives it back to the phone. After dusk it turns red and dim by itself, so it does
/// not spoil eyes that have adapted to the dark; it never touches the screen brightness.
///
/// Sonification and arithmetic, never effect: what the centre shows is a position, a magnitude
/// and a colour index — and, for the Sun, the Moon and a planet, the tone of the cycle it is known
/// by, arithmetic from its period — nothing about what a star does to a person.
struct SkySurface: View {
    @Environment(CameraPulseSource.self) private var pulse
    @State private var pointing = SkyPointing()
    @State private var camera = SkyCamera()

    var body: some View {
        ZStack(alignment: .top) {
            if let latitude = pointing.latitude, let longitude = pointing.longitude {
                SkyCanvas(pointing: pointing, frames: camera.frames, latitude: latitude, longitude: longitude)
            } else {
                SkyPlaceNeeded(pointing: pointing)
            }
            SkyControls(pointing: pointing)
        }
        .background(Theme.Color.background)
        .onAppear {
            pointing.start()
            // The camera layer asks the app's one camera arbitration (take > pulse > sky).
            pulse.wantSky()
            camera.follow(holdsCamera: pulse.skyHoldsCamera, pointing: pointing.shared)
        }
        .onDisappear {
            camera.stop()
            pulse.dropSky()
            pointing.stop()
        }
        // A take or the pulse takes the camera: the layer closes; it comes back when they let go.
        .onChange(of: pulse.skyHoldsCamera) { _, holds in
            camera.follow(holdsCamera: holds, pointing: pointing.shared)
        }
    }
}

/// The scene the canvas draws, rebuilt when the place changes or every few seconds: the sky turns
/// a quarter of a degree a minute, so a scene ten seconds old is off by less than a star's width.
/// A plain class the leaf owns; it changes every frame and nothing observes it.
@MainActor
final class SkySceneCache {
    nonisolated static let maximumAgeSeconds: TimeInterval = 10
    private(set) var scene: SkyScene?
    /// True once the Sun is 6° below the horizon (civil dusk): the view turns red and dim.
    private(set) var isNight = false
    private var builtAt: Date?
    private var place: (Double, Double)?

    func current(latitude: Double, longitude: Double, at now: Date) -> SkyScene? {
        let samePlace = place.map { $0.0 == latitude && $0.1 == longitude } ?? false
        if samePlace, let builtAt, now.timeIntervalSince(builtAt) < Self.maximumAgeSeconds, let scene {
            return scene
        }
        scene = SkyScene(latitude: latitude, longitude: longitude, date: now)
        place = (latitude, longitude)
        builtAt = now
        isNight = Self.sunAltitude(latitude: latitude, longitude: longitude, at: now).map { $0 < -6 } ?? true
        return scene
    }

    static func sunAltitude(latitude: Double, longitude: Double, at date: Date) -> Double? {
        let jd = Sky.julianDay(date)
        guard let sun = SkyBodies.position(of: .sun, julianDay: jd) else { return nil }
        return Sky.horizontal(rightAscension: sun.rightAscension, declination: sun.declination,
                              latitude: latitude, longitude: longitude, julianDay: jd)?.altitude
    }
}

/// The drawn sky, a leaf (Law 6): its own 60 Hz loop samples the pointing, takes the cached scene
/// and draws. Nothing above it reads the pointing or the scene.
struct SkyCanvas: View {
    let pointing: SkyPointing
    let frames: SkyCameraFrames
    let latitude: Double
    let longitude: Double
    @State private var cache = SkySceneCache()
    @State private var dragStart: Sky.Horizontal?

    /// Degrees across the shorter side of the screen while no camera picture is shown.
    static let fieldOfView = 70.0
    /// Degrees the view turns per point of drag.
    static let degreesPerPoint = 0.2

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
                let frame = SkyFrame.make(pointing: pointing, cache: cache, camera: frames.read(), size: geometry.size,
                                          latitude: latitude, longitude: longitude, at: context.date)
                ZStack {
                    Canvas { canvas, size in
                        SkyCanvas.draw(frame, in: &canvas, size: size)
                    }
                    // The ring and the lines under it, on their own layer: a line that wraps stays
                    // centred (resolved text reads this environment), and its text stops growing at
                    // the size the bars stop at, past which an item no longer fits a phone's width.
                    // The names in the sky and N E S W keep growing with the musician's text size;
                    // the spoken value says all of it at any size.
                    Canvas { canvas, size in
                        SkyCanvas.drawCentre(frame, in: &canvas, size: size)
                    }
                    .multilineTextAlignment(.center)
                    .dynamicTypeSize(...Theme.Accessibility.denseStripLimit)
                    .allowsHitTesting(false)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sky")
                .accessibilityValue(frame.spoken)
            }
        }
        .gesture(drag)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragStart == nil {
                    pointing.steerByFinger()
                    dragStart = pointing.fingerCentre
                }
                guard let start = dragStart else { return }
                let azimuth = start.azimuth - Double(value.translation.width) * Self.degreesPerPoint
                let altitude = start.altitude + Double(value.translation.height) * Self.degreesPerPoint
                pointing.fingerCentre = Sky.Horizontal(altitude: Swift.min(89.9, Swift.max(-10, altitude)),
                                                       azimuth: Sky.normalizedAzimuth(azimuth))
            }
            .onEnded { _ in dragStart = nil }
    }
}

extension Sky {
    /// An azimuth folded into 0 ..< 360.
    static func normalizedAzimuth(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }
}

/// One drawn frame: the projection, the scene, what sits in the middle, day or night.
struct SkyFrame {
    let projection: SkyProjection?
    let scene: SkyScene?
    let centred: SkyScene.Object?
    let isNight: Bool
    /// The camera layer, when it carries signal and the phone steers (a finger-turned sky and a
    /// picture of where the phone points would disagree).
    let camera: CGImage?
    let cameraOpacity: Double

    @MainActor
    static func make(pointing: SkyPointing, cache: SkySceneCache, camera: SkyCameraFrames.Latest, size: CGSize,
                     latitude: Double, longitude: Double, at date: Date) -> SkyFrame {
        pointing.sample()
        let scene = cache.current(latitude: latitude, longitude: longitude, at: date)
        var picture: CGImage?
        var fieldOfView = SkyCanvas.fieldOfView
        if pointing.steering == .sensors, camera.opacity > 0, let image = camera.image,
           let matched = SkyFrame.matchedFieldOfView(image: image, longSideDegrees: camera.longSideDegrees, size: size) {
            picture = image
            fieldOfView = matched
        }
        let projection = SkyProjection(forward: pointing.forward, up: pointing.up, fieldOfView: fieldOfView)
        let centred = scene?.centred(on: pointing.forward.horizontal)
        return SkyFrame(projection: projection, scene: scene, centred: centred, isNight: cache.isNight,
                        camera: picture, cameraOpacity: picture == nil ? 0 : camera.opacity)
    }

    /// The drawn sky's field across the screen's shorter side that lines it up with the picture.
    static func matchedFieldOfView(image: CGImage, longSideDegrees: Double, size: CGSize) -> Double? {
        let imageLong = Double(Swift.max(image.width, image.height)), imageShort = Double(Swift.min(image.width, image.height))
        let screenLong = Double(Swift.max(size.width, size.height)), screenShort = Double(Swift.min(size.width, size.height))
        guard imageShort > 0, screenShort > 0 else { return nil }
        return SkyNightCamera.matchingFieldOfView(cameraLongSideDegrees: longSideDegrees, imageAspect: imageLong / imageShort,
                                                  screenAspect: screenLong / screenShort)
    }

    var spoken: String {
        guard let centred else { return "Nothing bright in the middle" }
        let name = centred.name ?? SkyFrame.designation(centred)
        var line = "\(name), magnitude \(SkyFrame.number(centred.magnitude))"
        if let tint = centred.colorIndex.map(SkyFrame.tint(colorIndex:)) { line += ", \(tint)" }
        if case .body(let body) = centred.kind, let tone = CycleToneText.skySpoken[body] { line += ", " + tone }
        return line
    }

    static func designation(_ object: SkyScene.Object) -> String {
        switch object.kind {
        // The catalogue number of an unnamed star, written so it cannot be read as a heart rate
        // ("HR" is the Bright Star Catalogue's prefix, and this is a body app).
        case .star(let number): "Bright Star \(number)"
        case .body(let body): body.name
        }
    }

    /// One decimal, in the reader's own number format (a comma where the locale writes one).
    static func number(_ value: Double) -> String {
        NumberText.string(value, decimals: 1)
    }

    /// The separator of the lines under the ring: a row may end on it, never start with it.
    static let dot = "\u{00A0}\u{00A0}\u{00B7}  "

    /// One item of a line under the ring, glued so a wrap never splits it: no-break spaces, and a
    /// word joiner after a hyphen ("Yellow-White"). The font has the no-break space; the joiner has
    /// no width.
    static func glued(_ item: String) -> String {
        item.replacingOccurrences(of: " ", with: "\u{00A0}").replacingOccurrences(of: "-", with: "-\u{2060}")
    }

    /// The star's colour in words, from its B−V index (the Morgan–Keenan bands, coarse): the
    /// picture shows the colour, the words say it for those who cannot see it.
    static func tint(colorIndex: Double) -> String {
        switch colorIndex {
        case ..<0: "blue-white"
        case ..<0.3: "white"
        case ..<0.6: "yellow-white"
        case ..<1.0: "yellow"
        case ..<1.4: "orange"
        default: "red"
        }
    }
}

extension SkyCanvas {
    /// Night palette: red only, dim — the colour dark-adapted eyes lose least to. Not a Theme
    /// colour on purpose: it is a property of the eye after dusk, not of the brand, and the
    /// controls over the sky stay Echoel.
    private static let nightRed = Color(red: 0.85, green: 0.12, blue: 0.08)

    static func draw(_ frame: SkyFrame, in canvas: inout GraphicsContext, size: CGSize) {
        guard let projection = frame.projection, let scene = frame.scene, size.width > 0, size.height > 0 else { return }
        let half = Double(Swift.min(size.width, size.height)) / 2
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        func point(_ vector: SkyVector) -> CGPoint? {
            guard let p = projection.project(vector) else { return nil }
            let x = Double(middle.x) + p.x * half, y = Double(middle.y) - p.y * half
            guard x > -40, y > -40, x < Double(size.width) + 40, y < Double(size.height) + 40 else { return nil }
            return CGPoint(x: x, y: y)
        }
        if let picture = frame.camera {
            drawCamera(picture, opacity: frame.cameraOpacity, night: frame.isNight, size: size, in: &canvas)
        }
        drawGround(projection: projection, middle: middle, half: half, size: size, night: frame.isNight, in: &canvas)
        for object in scene.objects {
            guard let at = point(object.vector) else { continue }
            drawObject(object, at: at, night: frame.isNight, in: &canvas)
        }
        drawCardinals(point: point, night: frame.isNight, in: &canvas)
    }

    /// The centre layer: the ring and what it holds, drawn whenever the sky itself is.
    static func drawCentre(_ frame: SkyFrame, in canvas: inout GraphicsContext, size: CGSize) {
        guard frame.projection != nil, frame.scene != nil, size.width > 0, size.height > 0 else { return }
        drawCentre(frame, middle: CGPoint(x: size.width / 2, y: size.height / 2), size: size, in: &canvas)
    }

    private static func ink(_ night: Bool, _ opacity: Double) -> Color {
        night ? nightRed.opacity(opacity * 0.8) : Theme.Color.text.opacity(opacity)
    }

    /// The camera picture, aspect-filled and centred, behind everything drawn; at night only its
    /// brightness shows, in the red palette.
    private static func drawCamera(_ picture: CGImage, opacity: Double, night: Bool, size: CGSize,
                                   in canvas: inout GraphicsContext) {
        let width = Double(picture.width), height = Double(picture.height)
        guard width > 0, height > 0 else { return }
        let scale = Swift.max(Double(size.width) / width, Double(size.height) / height)
        let drawn = CGSize(width: width * scale, height: height * scale)
        let rect = CGRect(x: (Double(size.width) - drawn.width) / 2, y: (Double(size.height) - drawn.height) / 2,
                          width: drawn.width, height: drawn.height)
        var layer = canvas
        layer.opacity = opacity
        if night {
            layer.addFilter(.grayscale(1))
            layer.addFilter(.colorMultiply(nightRed))
        }
        layer.draw(Image(decorative: picture, scale: 1), in: rect)
    }

    /// The horizon as a line.
    private static func drawGround(projection: SkyProjection, middle: CGPoint, half: Double, size: CGSize,
                                   night: Bool, in canvas: inout GraphicsContext) {
        var horizon = Path()
        var started = false
        for step in 0...180 {
            let vector = SkyVector(Sky.Horizontal(altitude: 0, azimuth: Double(step) * 2))
            guard let p = projection.project(vector), abs(p.x) < 6, abs(p.y) < 6 else {
                started = false
                continue
            }
            let at = CGPoint(x: Double(middle.x) + p.x * half, y: Double(middle.y) - p.y * half)
            if started { horizon.addLine(to: at) } else { horizon.move(to: at) }
            started = true
        }
        canvas.stroke(horizon, with: .color(ink(night, 0.45)), lineWidth: 1)
    }

    private static func drawObject(_ object: SkyScene.Object, at: CGPoint, night: Bool, in canvas: inout GraphicsContext) {
        let below = object.position.altitude < 0
        switch object.kind {
        case .star:
            // Brighter is bigger: about 3.5 pt for Sirius down to 0.6 pt at the table's limit.
            let radius = Swift.max(0.6, 2.4 - 0.36 * object.magnitude)
            let alpha = Swift.min(1, Swift.max(0.35, 1 - object.magnitude * 0.11)) * (below ? 0.3 : 1)
            // The star's own colour from its B−V index: data, not decoration, so not a Theme colour.
            let tone = StarCatalog.color(colorIndex: object.colorIndex)
            let color = night ? nightRed.opacity(alpha * 0.85)
                : Color(red: tone.red, green: tone.green, blue: tone.blue).opacity(alpha)
            canvas.fill(Path(ellipseIn: CGRect(x: at.x - radius, y: at.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(color))
            if let name = object.name, object.magnitude < 1.6 {
                label(name, at: at, offset: radius + 3, night: night, in: &canvas)
            }
        case .body(let body):
            let radius: Double = switch body {
            case .sun: 9
            case .moon: 8
            default: Swift.max(2, 3.2 - 0.3 * object.magnitude)
            }
            // The bodies' real tints (data, like the stars' B−V colours), not Theme colours.
            let tone: Color = switch body {
            case .sun: Color(red: 1, green: 0.85, blue: 0.4)
            case .moon: Color(white: 0.85)
            case .mars: Color(red: 1, green: 0.55, blue: 0.4)
            default: Color(red: 1, green: 0.95, blue: 0.85)
            }
            canvas.fill(Path(ellipseIn: CGRect(x: at.x - radius, y: at.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(night ? nightRed.opacity(below ? 0.3 : 0.9) : tone.opacity(below ? 0.3 : 1)))
            label(body.name, at: at, offset: radius + 3, night: night, in: &canvas)
        }
    }

    private static func label(_ text: String, at: CGPoint, offset: Double, night: Bool, in canvas: inout GraphicsContext) {
        canvas.draw(Text(text).font(Theme.Font.label).foregroundStyle(ink(night, 0.8)),
                    at: CGPoint(x: at.x + offset, y: at.y), anchor: .leading)
    }

    private static func drawCardinals(point: (SkyVector) -> CGPoint?, night: Bool, in canvas: inout GraphicsContext) {
        for (azimuth, letter) in [(0.0, "N"), (90.0, "E"), (180.0, "S"), (270.0, "W")] {
            guard let at = point(SkyVector(Sky.Horizontal(altitude: 0, azimuth: azimuth))) else { continue }
            canvas.draw(Text(letter).font(Theme.Font.label).foregroundStyle(night ? nightRed : Theme.Color.text),
                        at: CGPoint(x: at.x, y: at.y + 12))
        }
    }

    /// The ring in the middle and, under it, what it holds: name, magnitude, colour index; for the
    /// Sun, the Moon and a planet also the cycle it is known by, as a tone (W6b).
    private static func drawCentre(_ frame: SkyFrame, middle: CGPoint, size: CGSize, in canvas: inout GraphicsContext) {
        let ring: CGFloat = 14
        canvas.stroke(Path(ellipseIn: CGRect(x: middle.x - ring, y: middle.y - ring, width: ring * 2, height: ring * 2)),
                      with: .color(ink(frame.isNight, 0.5)), lineWidth: 1)
        guard let centred = frame.centred else { return }
        // What sits in the ring: its name, how bright it is, its colour in words. Plain words —
        // no catalogue shorthand ("mag", "B−V") on the screen of a music app. Each item is glued, so
        // a line that wraps breaks only after a dot.
        let name = SkyFrame.glued(centred.name ?? SkyFrame.designation(centred))
        let magnitude = SkyFrame.glued("Magnitude " + SkyFrame.number(centred.magnitude))
        var full = name + SkyFrame.dot + magnitude
        if let index = centred.colorIndex { full += SkyFrame.dot + SkyFrame.glued(SkyFrame.tint(colorIndex: index).capitalized) }
        // From the most to the least: all of it, then name and magnitude, then the name.
        var names: [String] = []
        for candidate in [full, name + SkyFrame.dot + magnitude, name] where !names.contains(candidate) {
            names.append(candidate)
        }
        let bright = ink(frame.isNight, 0.9), dim = ink(frame.isNight, 0.7)
        var layouts = names.map { [Text($0).font(Theme.Font.value).foregroundStyle(bright)] }
        if case .body(let body) = centred.kind, let tone = CycleToneText.skyLines[body] {
            layouts.insert([Text(full).font(Theme.Font.value).foregroundStyle(bright),
                            Text(tone).font(Theme.Font.label).foregroundStyle(dim)], at: 0)
        }
        drawLines(layouts, centreX: middle.x, ceiling: middle.y + ring + Theme.Space.s, size: size, in: &canvas)
    }

    /// The first of `layouts` that fits whole between a large gap at the bottom edge (the home
    /// indicator) and `ceiling` (just under the ring), centred. In a layout the first line is on top;
    /// the lowest line's last row sits where the one line always sat, a line that wraps grows upward
    /// from there, and the line above stands on it. Each line is measured at the text size the
    /// musician chose (up to the bars' limit) and wraps within the screen. When no layout fits whole
    /// there, the first single line that fits one row whole is drawn just under the ring instead,
    /// never below the canvas — and nothing when none does. Nothing is cut; the spoken value says
    /// all of it either way.
    private static func drawLines(_ layouts: [[Text]], centreX: CGFloat, ceiling: CGFloat, size: CGSize,
                                  in canvas: inout GraphicsContext) {
        let fromBottom = Theme.Space.xl + Theme.Space.s
        let width = Swift.max(size.width - 2 * Theme.Space.m, 1)
        let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let wrapped = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        for layout in layouts {
            let resolved = layout.map { canvas.resolve($0) }
            guard let lowest = resolved.last else { continue }
            var bottom = size.height - fromBottom + lowest.measure(in: unbounded).height / 2
            var boxes: [(text: GraphicsContext.ResolvedText, box: CGRect)] = []
            for text in resolved.reversed() {
                let measured = text.measure(in: wrapped)
                guard measured.height <= bottom - ceiling else { break }
                let box = CGRect(x: centreX - measured.width / 2, y: bottom - measured.height,
                                 width: measured.width, height: measured.height)
                boxes.append((text: text, box: box))
                bottom = box.minY - Theme.Space.xs
            }
            guard boxes.count == resolved.count else { continue }
            for line in boxes { canvas.draw(line.text, in: line.box) }
            return
        }
        for layout in layouts where layout.count == 1 {
            let text = canvas.resolve(layout[0])
            let row = text.measure(in: unbounded).height
            let measured = text.measure(in: wrapped)
            // One row whole, or the next, shorter line.
            guard measured.height < row * 1.5 else { continue }
            let bottom = Swift.max(size.height - fromBottom + row / 2, Swift.min(size.height, ceiling + row))
            guard bottom - ceiling >= row else { return }
            canvas.draw(text, in: CGRect(x: centreX - measured.width / 2, y: bottom - measured.height,
                                         width: measured.width, height: measured.height))
            return
        }
    }
}

/// What the star in the middle offers as a sound source (S3): plain numbers, 0 … 1, from the
/// catalogue alone. Not shown: they are NOT yet a modulation source, and two bare numbers on the
/// screen read as debug output (founder, device video 2026-10-31). NOT yet a modulation source — a new source would be a new stored
/// name in the song format (Law 3), which waits for the founder's word.
struct SkyStarReading: Equatable {
    let brightness: Double
    let color: Double?

    init(_ object: SkyScene.Object) {
        brightness = StarCatalog.brightness(magnitude: object.magnitude) ?? 0
        color = object.colorIndex.flatMap { StarCatalog.colorPosition(colorIndex: $0) }
    }
}

/// Place and steering, over the sky. Reads only observed values that change when the musician
/// chooses or a fix arrives (Law 6).
private struct SkyControls: View {
    let pointing: SkyPointing

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Menu {
                if let back = pointing.wayBackName {
                    Button(back, systemImage: "location.fill") { pointing.useHere() }
                    Divider()
                }
                ForEach(SkyPointing.places.map { $0.name }, id: \.self) { name in
                    Button(name) { pointing.choose(name) }
                }
            } label: {
                Label(placeLine, systemImage: "location")
                    .font(Theme.Font.caption)
                    .frame(minHeight: Theme.Size.touch)
            }
            .accessibilityLabel("Place")
            .accessibilityValue(placeLine)
            .accessibilityHint("Chooses the place whose sky is drawn. A chosen place stays until you choose another.")
            Spacer(minLength: 0)
            if pointing.steering == .finger, pointing.canFollowPhone {
                Button { pointing.followPhone() } label: { Image(systemName: "iphone.gen3.radiowaves.left.and.right") }
                    .buttonStyle(ToolButtonStyle())
                    .accessibilityLabel("Follow the Phone")
                    .accessibilityHint("Turns the sky with the direction the phone points.")
            }
        }
        .foregroundStyle(Theme.Color.textSecondary)
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s)
    }

    private var placeLine: String {
        switch pointing.placeSource {
        case .located: "Here"
        case .remembered: "Last Known Place"
        case .chosen(let name): name
        case .none: pointing.locationDenied ? "Location Off, Choose a Place" : "Finding the Place"
        }
    }
}

/// Before any place is known: what the view needs, and the way to give it without the permission.
private struct SkyPlaceNeeded: View {
    let pointing: SkyPointing

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            Spacer()
            Text(pointing.locationDenied
                 ? "The sky depends on where you are. Choose a place above, or allow location in Settings."
                 : "Finding where you are, to draw the sky above you.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
