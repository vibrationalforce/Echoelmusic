import XCTest
@testable import EchoelCore

/// The G-A modulation vectors (`.claude/skills/g-a-body-modulation/references/FIXTURES.json`, group
/// `modulation`), generated from that file so none is copied by hand. Wave W2: the arithmetic only,
/// nothing is stored in a song yet.
final class ModulationTests: XCTestCase {
    private func address(_ text: String, file: StaticString = #filePath, line: UInt = #line) throws -> ParameterAddress {
        try XCTUnwrap(ParameterAddress(text: text), "address \(text)", file: file, line: line)
    }

    private func route(_ id: String, _ source: ModulationSource, _ target: String, _ depth: Double,
                       _ curve: ModulationRoute.Curve, _ polarity: ModulationRoute.Polarity,
                       _ enabled: Bool) throws -> ModulationRoute {
        ModulationRoute(id: try XCTUnwrap(UUID(uuidString: id)), source: source, target: try address(target),
                        depth: depth, curve: curve, polarity: polarity, enabled: enabled)
    }

    /// 0.5 + 0.2*0.75 - 0.1*0.5 = 0.6; stable id order.
    func testM01TwoRoutes() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000002", .macro1, "master/mixer.pan", -0.1, .linear, .unipolar, true),
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 0.2, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.75, .macro1: 0.5]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: nil, routes: routes, sources: sources, targets: targets), 0.6, accuracy: 1e-12)
    }

    /// Absent source contributes zero, never a centered substitute.
    func testM02MissingNeutral() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 0.2, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [:]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: nil, routes: routes, sources: sources, targets: targets), 0.5, accuracy: 1e-12)
    }

    /// 2*0.5-1 = 0.
    func testM03BipolarMidpoint() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 0.2, .linear, .bipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.5]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: nil, routes: routes, sources: sources, targets: targets), 0.5, accuracy: 1e-12)
    }

    /// x=.25 -> signed square(-.5)=-.25; .5-.1=.4.
    func testM04SignedSquare() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 0.4, .square, .bipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.25]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: nil, routes: routes, sources: sources, targets: targets), 0.4, accuracy: 1e-12)
    }

    /// Automation .3 replaces base .5; .3+.2*.75=.45.
    func testM05Automation() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 0.2, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.75]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: 0.3, routes: routes, sources: sources, targets: targets), 0.45, accuracy: 1e-12)
    }

    /// 1.0+.75 -> 1.0.
    func testM06UpperClamp() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 1.0, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.75]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 1.0, automation: nil, routes: routes, sources: sources, targets: targets), 1.0, accuracy: 1e-12)
    }

    /// .1-.75 -> 0.
    func testM07LowerClamp() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", -1.0, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.75]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 0.1, automation: nil, routes: routes, sources: sources, targets: targets), 0.0, accuracy: 1e-12)
    }

    /// Disabled route has zero contribution.
    func testM08Disabled() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 0.2, .linear, .unipolar, false),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.75]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: nil, routes: routes, sources: sources, targets: targets), 0.5, accuracy: 1e-12)
    }

    /// Out-of-domain live source is absent, not clamped into expressive maximum.
    func testM09InvalidLiveValue() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 0.2, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 2.0]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: nil, routes: routes, sources: sources, targets: targets), 0.5, accuracy: 1e-12)
    }

    /// Duplicate route ids reject atomically.
    func testM10DuplicateUuid() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 0.2, .linear, .unipolar, true),
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 0.2, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.75]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertThrowsError(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: nil, routes: routes, sources: sources, targets: targets)) { error in
            XCTAssertEqual(error as? Modulation.Failure, .duplicateID)
        }
    }

    /// Targets must resolve through production descriptor registry (the fixture's "track/missing" id is not a UUID, so an unregistered track stands in).
    func testM11UnknownTarget() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "track/00000000-0000-0000-0000-0000000000ff/synth.cutoff", 0.2, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.75]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertThrowsError(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: nil, routes: routes, sources: sources, targets: targets)) { error in
            XCTAssertEqual(error as? Modulation.Failure, .target)
        }
    }

    /// Depth outside [-1,1] rejects rather than changes document.
    func testM12BadDepth() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 1.01, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.75]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertThrowsError(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: nil, routes: routes, sources: sources, targets: targets)) { error in
            XCTAssertEqual(error as? Modulation.Failure, .depth)
        }
    }

    /// Unknown semantics refuse route.
    func testM13UnknownCurve() {
        XCTAssertNil(ModulationRoute.Curve(rawValue: "magic"))
    }

    /// Bad base cannot silently become zero.
    func testM14BadBase() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 0.2, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.75]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertThrowsError(try Modulation.value(of: try address("master/mixer.pan"), base: Double.nan, automation: nil, routes: routes, sources: sources, targets: targets)) { error in
            XCTAssertEqual(error as? Modulation.Failure, .base)
        }
    }

    /// Missing producers are not inferred from a name.
    func testM15UnknownSource() {
        XCTAssertNil(ModulationSource(rawValue: "eeg"))
    }

    /// 0.5-.4*.75=.2.
    func testM16NegativeDepth() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", -0.4, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.75]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: nil, routes: routes, sources: sources, targets: targets), 0.2, accuracy: 1e-12)
    }

    /// Missing source is not bipolar zero input; it has no contribution.
    func testM17MissingBipolarNeutral() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 0.2, .linear, .bipolar, true),
        ]
        let sources: [ModulationSource: Double] = [:]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 0.5, automation: nil, routes: routes, sources: sources, targets: targets), 0.5, accuracy: 1e-12)
    }

    /// 0.9+0.75-0.75=.9; per-route clipping would give .25.
    func testM18ClampOnce() throws {
        let routes = [
            try route("00000000-0000-0000-0000-000000000001", .heartRate, "master/mixer.pan", 1.0, .linear, .unipolar, true),
            try route("00000000-0000-0000-0000-000000000002", .heartRate, "master/mixer.pan", -1.0, .linear, .unipolar, true),
        ]
        let sources: [ModulationSource: Double] = [.heartRate: 0.75]
        let targets: Set<ParameterAddress> = [try address("master/mixer.pan")]
        XCTAssertEqual(try Modulation.value(of: try address("master/mixer.pan"), base: 0.9, automation: nil, routes: routes, sources: sources, targets: targets), 0.9, accuracy: 1e-12)
    }

    /// The limit counts every route, disabled ones too: one more refuses the list.
    func testTheRouteLimitCountsDisabledRoutes() throws {
        let pan = try address("master/mixer.pan")
        let routes = (0...Modulation.routeLimit).map { (_: Int) -> ModulationRoute in
            ModulationRoute(source: .macro1, target: pan, depth: 0.1, enabled: false)
        }
        XCTAssertThrowsError(try Modulation.validate(routes, targets: [pan])) { error in
            XCTAssertEqual(error as? Modulation.Failure, .routeLimit)
        }
        XCTAssertEqual(try Modulation.validate(Array(routes.dropLast()), targets: [pan]).count, Modulation.routeLimit)
    }
}
