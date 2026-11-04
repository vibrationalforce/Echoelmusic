import EchoelCore
import EchoelEngine
import Foundation
import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The Field on a second screen — a projector, a TV, a display on a cable or AirPlay (REC-1, the
/// earlier app's stage output, #206). Not mirroring: the external display shows the Field alone,
/// full screen and untouchable, while the phone keeps every control. The scene is the system's
/// non-interactive external-display role; `ExternalFieldSceneDelegate` owns its window.
///
/// One picture at a time, as the earlier app learned (two live renderers starved the GPU): while
/// the external display shows the Field, the phone's Field areas show a line and the corner pin
/// instead of a second renderer. The picture is the same `FieldView`, so the flash law
/// (`FlashLimit`, at most three flashes a second) holds there unchanged.
///
/// Both settings belong to this device and the room, never to the song: whether the Field goes to
/// an external display, and the corner pin that squares the projected picture (`CornerPin`).
@MainActor
@Observable
final class ExternalFieldStage {
    static let shared = ExternalFieldStage()

    nonisolated static let enabledKey = "field.external.enabled"
    nonisolated static let cornersKey = "field.external.corners"

    /// An external display is connected and its scene is up.
    private(set) var isConnected = false
    /// The musician's switch in the Field menu; on until turned off, because connecting a display
    /// is already the musician's own act.
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            DiagnosticLog.app.note("extfield: switch", [("on", isEnabled ? 1 : 0)])
        }
    }
    /// The corner pin for the projected picture. Changes only while the musician sets it.
    var cornerPin: CornerPin {
        didSet {
            guard cornerPin != oldValue else { return }
            if let data = try? JSONEncoder().encode(cornerPin) {
                UserDefaults.standard.set(data, forKey: Self.cornersKey)
            }
            pinChanged?()
        }
    }

    /// Whether the external display draws the Field now, so the phone does not.
    var isShowing: Bool { isConnected && isEnabled }

    /// What the stage draws from: the scene is built by UIKit and inherits no SwiftUI environment.
    @ObservationIgnored private(set) var store: ProjectStore?
    @ObservationIgnored private(set) var engine: AudioEngine?
    @ObservationIgnored private(set) var strap: HeartRateStrap?
    /// The scene's corner-pin layer, told when the pin changes.
    @ObservationIgnored var pinChanged: (@MainActor () -> Void)?

    private init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        if let data = defaults.data(forKey: Self.cornersKey),
           let stored = try? JSONDecoder().decode(CornerPin.self, from: data) {
            cornerPin = stored
        } else {
            cornerPin = .none
        }
    }

    func attach(store: ProjectStore, engine: AudioEngine, strap: HeartRateStrap) {
        self.store = store
        self.engine = engine
        self.strap = strap
    }

    func connected(width: Double, height: Double) {
        DiagnosticLog.app.note("extfield: connect", [("w", width), ("h", height)])
        isConnected = true
    }

    func disconnected() {
        DiagnosticLog.app.note("extfield: disconnect")
        pinChanged = nil
        isConnected = false
    }
}

/// What the external display shows: the Field, edge to edge, no controls — or the black ground
/// while the musician has switched it off.
struct ExternalFieldRoot: View {
    var body: some View {
        let stage = ExternalFieldStage.shared
        ZStack {
            Theme.Color.background.ignoresSafeArea()
            if stage.isEnabled, let store = stage.store, let engine = stage.engine, let strap = stage.strap {
                FieldView(onStage: true)
                    .ignoresSafeArea()
                    .environment(store)
                    .environment(engine)
                    .environment(strap)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// On the phone, where the Field would be while the external display shows it: one line, and —
/// where there is room — the corner pin, because this is the moment the musician looks at the
/// wall and squares the picture.
struct ExternalFieldNotice: View {
    var body: some View {
        GeometryReader { geometry in
            let roomy = geometry.size.width >= 300 && geometry.size.height >= 300
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Label("The Field is on the external display.", systemImage: "rectangle.on.rectangle")
                        .font(roomy ? Theme.Font.body : Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    if roomy { CornerPinEditor() }
                }
                .padding(Theme.Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Theme.Color.background)
    }
}

/// The four corners of the projected picture, each moved toward the middle in percent of the
/// picture's width and height, in Echoel's value field. A device setting: no command, no song.
struct CornerPinEditor: View {
    var body: some View {
        let stage = ExternalFieldStage.shared
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Corner Pin")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.text)
            NoteText("Move a corner inward until the picture on the wall is a true rectangle.")
            ForEach(CornerPin.Corner.allCases, id: \.self) { corner in
                cornerRow(corner, pin: stage.cornerPin)
            }
            Button("Reset Corners") { stage.cornerPin = .none }
                .buttonStyle(ToolButtonStyle())
                .disabled(stage.cornerPin.isIdentity)
        }
    }

    private func cornerRow(_ corner: CornerPin.Corner, pin: CornerPin) -> some View {
        let inset = pin[corner]
        let range = 0...Int((CornerPin.maximumInset * 100).rounded())
        return HStack(spacing: Theme.Space.s) {
            SettingField(title: "\(corner.title) · Across", value: Self.percent(inset.horizontal), range: range,
                         unit: "%", standard: 0, spokenUnit: "percent") { value in
                Self.set(corner, horizontal: Double(value) / 100, vertical: nil)
            }
            SettingField(title: "\(corner.title) · Down", value: Self.percent(inset.vertical), range: range,
                         unit: "%", standard: 0, spokenUnit: "percent") { value in
                Self.set(corner, horizontal: nil, vertical: Double(value) / 100)
            }
        }
    }

    private static func percent(_ fraction: Double) -> Int { Int((fraction * 100).rounded()) }

    @MainActor private static func set(_ corner: CornerPin.Corner, horizontal: Double?, vertical: Double?) {
        let stage = ExternalFieldStage.shared
        var pin = stage.cornerPin
        let old = pin[corner]
        pin[corner] = CornerPin.Inset(horizontal: horizontal ?? old.horizontal, vertical: vertical ?? old.vertical)
        stage.cornerPin = pin
    }
}

#if canImport(UIKit)
/// Asks UIKit for the external display's scene: every other role keeps SwiftUI's own scene
/// handling (no delegate class named), so the studio's window is untouched.
final class StudioAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            configuration.delegateClass = ExternalFieldSceneDelegate.self
        }
        return configuration
    }
}

/// Owns the window on the external display. Unplugging mid-show is a stage scenario: the window
/// goes first, the claim second, so the phone's Field can only ever come back after this one is
/// gone — a gap of one layout pass, never two renderers at once.
final class ExternalFieldSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            DiagnosticLog.app.note("extfield: connect", because: "not a window scene")
            return
        }
        let window = UIWindow(windowScene: windowScene)
        let pinned = CornerPinnedController(content: UIHostingController(rootView: ExternalFieldRoot()))
        window.rootViewController = pinned
        // Nothing on a projector is touchable; the role says so, and this keeps it so.
        window.isUserInteractionEnabled = false
        window.isHidden = false
        self.window = window
        let size = windowScene.screen.bounds.size
        let stage = ExternalFieldStage.shared
        stage.pinChanged = { [weak pinned] in pinned?.applyPin() }
        stage.connected(width: Double(size.width), height: Double(size.height))
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        ExternalFieldStage.shared.disconnected()
    }
}

/// Holds the Field's hosting view and squares it with the corner pin: the content layer is
/// anchored at its top-left corner and carries the projective transform `CornerPin` computes.
final class CornerPinnedController: UIViewController {
    private let content: UIViewController

    init(content: UIViewController) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addChild(content)
        view.addSubview(content.view)
        content.didMove(toParent: self)
        content.view.layer.anchorPoint = .zero
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyPin()
    }

    func applyPin() {
        let size = view.bounds.size
        let layer = content.view.layer
        layer.transform = CATransform3DIdentity
        content.view.bounds = CGRect(origin: .zero, size: size)
        layer.position = .zero
        let m = ExternalFieldStage.shared.cornerPin.layerMatrix(width: Double(size.width), height: Double(size.height))
        guard m.count == 16 else { return }
        layer.transform = CATransform3D(m11: CGFloat(m[0]), m12: CGFloat(m[1]), m13: CGFloat(m[2]), m14: CGFloat(m[3]),
                                        m21: CGFloat(m[4]), m22: CGFloat(m[5]), m23: CGFloat(m[6]), m24: CGFloat(m[7]),
                                        m31: CGFloat(m[8]), m32: CGFloat(m[9]), m33: CGFloat(m[10]), m34: CGFloat(m[11]),
                                        m41: CGFloat(m[12]), m42: CGFloat(m[13]), m43: CGFloat(m[14]), m44: CGFloat(m[15]))
    }
}
#endif
