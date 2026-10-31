import EchoelCore
import SwiftUI

/// The sky as a view of the studio (sky source S2, founder 2026-10-31: "a good picture even when
/// it is dark … intelligent and automatic, without the musician needing to know anything").
/// The picture is COMPUTED — the star table, the Sun, Moon and planets, the place and the time,
/// turned by the phone's attitude — so it is sharp in total darkness and behind clouds. No
/// setting: it opens, finds the place once and follows the phone; a drag turns it by finger,
/// one button gives it back to the phone. After dusk it turns red and dim by itself, so it does
/// not spoil eyes that have adapted to the dark; it never touches the screen brightness.
///
/// Sonification and arithmetic, never effect: what the centre shows is a position, a magnitude
/// and a colour index, nothing about what a star does to a person.
struct SkySurface: View {
    @State private var pointing = SkyPointing()

    var body: some View {
        ZStack(alignment: .top) {
            if let latitude = pointing.latitude, let longitude = pointing.longitude {
                SkyCanvas(pointing: pointing, latitude: latitude, longitude: longitude)
            } else {
                SkyPlaceNeeded(pointing: pointing)
            }
            SkyControls(pointing: pointing)
        }
        .background(Color.black)
        .onAppear { pointing.start() }
        .onDisappear { pointing.stop() }
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
    let latitude: Double
    let longitude: Double
    @State private var cache = SkySceneCache()
    @State private var dragStart: Sky.Horizontal?

    /// Degrees across the shorter side of the screen.
    static let fieldOfView = 70.0
    /// Degrees the view turns per point of drag.
    static let degreesPerPoint = 0.2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
            let frame = SkyFrame.make(pointing: pointing, cache: cache, latitude: latitude, longitude: longitude,
                                      at: context.date)
            Canvas { canvas, size in
                SkyCanvas.draw(frame, in: &canvas, size: size)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sky")
            .accessibilityValue(frame.spoken)
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

    @MainActor
    static func make(pointing: SkyPointing, cache: SkySceneCache, latitude: Double, longitude: Double,
                     at date: Date) -> SkyFrame {
        pointing.sample()
        let scene = cache.current(latitude: latitude, longitude: longitude, at: date)
        let projection = SkyProjection(forward: pointing.forward, up: pointing.up, fieldOfView: SkyCanvas.fieldOfView)
        let centred = scene?.centred(on: pointing.forward.horizontal)
        return SkyFrame(projection: projection, scene: scene, centred: centred, isNight: cache.isNight)
    }

    var spoken: String {
        guard let centred else { return "Nothing bright in the middle" }
        let name = centred.name ?? SkyFrame.designation(centred)
        return "\(name), magnitude \(String(format: "%.1f", centred.magnitude))"
    }

    static func designation(_ object: SkyScene.Object) -> String {
        switch object.kind {
        case .star(let number): "HR \(number)"
        case .body(let body): body.name
        }
    }
}

extension SkyCanvas {
    /// Night palette: red only, dim — the colour dark-adapted eyes lose least to.
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
        drawGround(projection: projection, middle: middle, half: half, size: size, night: frame.isNight, in: &canvas)
        for object in scene.objects {
            guard let at = point(object.vector) else { continue }
            drawObject(object, at: at, night: frame.isNight, in: &canvas)
        }
        drawCardinals(point: point, night: frame.isNight, in: &canvas)
        drawCentre(frame, middle: middle, size: size, in: &canvas)
    }

    private static func ink(_ night: Bool, _ opacity: Double) -> Color {
        night ? nightRed.opacity(opacity * 0.8) : Color.white.opacity(opacity)
    }

    /// The horizon as a line, and the ground below it darker than the sky.
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
        canvas.draw(Text(text).font(Theme.Font.caption).foregroundStyle(ink(night, 0.7)),
                    at: CGPoint(x: at.x + offset, y: at.y), anchor: .leading)
    }

    private static func drawCardinals(point: (SkyVector) -> CGPoint?, night: Bool, in canvas: inout GraphicsContext) {
        for (azimuth, letter) in [(0.0, "N"), (90.0, "E"), (180.0, "S"), (270.0, "W")] {
            guard let at = point(SkyVector(Sky.Horizontal(altitude: 0, azimuth: azimuth))) else { continue }
            canvas.draw(Text(letter).font(Theme.Font.label).foregroundStyle(night ? nightRed : Theme.Color.accent),
                        at: CGPoint(x: at.x, y: at.y + 12))
        }
    }

    /// The ring in the middle and, under it, what it holds: name, magnitude, colour index.
    private static func drawCentre(_ frame: SkyFrame, middle: CGPoint, size: CGSize, in canvas: inout GraphicsContext) {
        let ring: CGFloat = 14
        canvas.stroke(Path(ellipseIn: CGRect(x: middle.x - ring, y: middle.y - ring, width: ring * 2, height: ring * 2)),
                      with: .color(ink(frame.isNight, 0.5)), lineWidth: 1)
        guard let centred = frame.centred else { return }
        var line = centred.name ?? SkyFrame.designation(centred)
        line += String(format: "  ·  mag %.1f", centred.magnitude)
        if let index = centred.colorIndex { line += String(format: "  ·  B−V %.2f", index) }
        canvas.draw(Text(line).font(Theme.Font.value).foregroundStyle(ink(frame.isNight, 0.9)),
                    at: CGPoint(x: middle.x, y: size.height - 28))
    }
}

/// Place and steering, over the sky. Reads only observed values that change when the musician
/// chooses or a fix arrives (Law 6).
private struct SkyControls: View {
    let pointing: SkyPointing

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Menu {
                ForEach(SkyPointing.places.map { $0.name }, id: \.self) { name in
                    Button(name) { pointing.choose(name) }
                }
            } label: {
                Label(placeLine, systemImage: "location")
                    .font(Theme.Font.caption)
            }
            .accessibilityHint("Chooses the place whose sky is drawn.")
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
        case .remembered: "Last known place"
        case .chosen(let name): name
        case .none: pointing.locationDenied ? "Location off — choose a place" : "Finding the place…"
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
                 : "Finding where you are to draw the sky above you…")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
