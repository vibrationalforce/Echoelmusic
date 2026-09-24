// TheHostValueIsAdmittedOnceTests.swift
// Echoel — 2026-09-24 (overnight P8): a creative value arriving from a host passes ONE gate,
// `EchoelBodyVibeDevice.admitted`, before it reaches an engine or the output-gain mirror.
// Blocking bundle.
//
// THE DEFECT (measured before the repair). The AUv3's value observer handed the host's raw value
// to `EchoelBodyVibeDevice.apply` and straight into `gainMirror`. Nothing downstream checks it:
// · Master Gain NaN → the render block writes `(synth + texture) * gain` into the HOST's bus with
//   no finite guard after it — NaN leaves the plug-in (`git grep -n isFinite` on the AUv3 file
//   found nothing).
// · Base frequency NaN → `EchoelCellular`'s partial phases turn NaN and stay NaN; its per-sample
//   finite guard turns that into silence that lasts until the next seed.
// · Any out-of-range value bypassed the descriptor range the tree declares.
// `seed` (P2) already refused non-finite values and clamped; the LIVE path did not — two
// spellings of one decision (#416), and the live one was the unsafe one.
//
// THE REPAIR. `admitted(_:forCreativeID:)`: nil for a non-finite value or an unknown ID (the
// caller keeps what sounds), otherwise clamped to the descriptor. `seed` and both observer
// branches call it.
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claims 1–2 are END-TO-END BEHAVIOUR of the shipped gate.
// · claim 3 is a SOURCE-TEXT SCAN of the AUv3 observer, which this bundle cannot instantiate.
// · HOST: whether a real host ever sends a non-finite or out-of-range value is not measured;
//   AUParameter's own clamping behaviour is not documented in reach. The gate makes the answer
//   not matter.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). No range is frozen — every expectation is read from
// `creativeDescriptors`.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `df9222b38`: `admitted` does not
// exist, so the file does not COMPILE there — no assertion has a verdict. Claims 1–2 are FORWARD
// guards; claim 3's text would be red on the parent (raw `value` in both branches) — one finding.
//
// CLAIM 4 (overnight P8f, its own commit): the rule lives ONCE, on `ParameterDescriptor`.
// P8e wrote `admitted` beside `EchoelDeviceState.sanitized`, which spelled the same decision a
// second way (`Swift.min(Swift.max(…))`) — #416 created by the repair itself. Both now ask
// `ParameterDescriptor.admitted(_:)`. END-TO-END BEHAVIOUR (parity over every creative
// descriptor, and an inverted range refused) plus a SOURCE-TEXT SCAN of the device file.
// Parent `c2fc6f407`: `ParameterDescriptor.admitted` does not exist, so this file does not
// compile there — FORWARD guard; the scan half would be red there (the second spelling).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheHostValueIsAdmittedOnceTests: XCTestCase {

    private typealias ID = EchoelBodyVibeDevice.BaseID
    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"
    private static let device = "Sources/Echoelmusic/DSP/EchoelBodyVibeDevice.swift"
    private static let nonFinite: [Float] = [.nan, .infinity, -.infinity, .signalingNaN]

    // MARK: - claim 1

    func testANonFiniteHostValueIsRefused() {
        for descriptor in EchoelBodyVibeDevice.creativeDescriptors {
            for bad in Self.nonFinite {
                XCTAssertNil(EchoelBodyVibeDevice.admitted(bad, forCreativeID: descriptor.keyPath), """
                    \(descriptor.keyPath) admitted \(bad). A NaN Master Gain reaches the host's bus; \
                    a NaN pitch silences the texture until the next seed.
                    """)
            }
        }
        XCTAssertNil(EchoelBodyVibeDevice.admitted(0.5, forCreativeID: "bodyvibe.ghost"),
                     "an unknown ID was admitted")
        XCTAssertNil(EchoelBodyVibeDevice.admitted(0.5, forCreativeID: "bodyvibe.bio.heartRate"),
                     "a bio input was admitted as a creative value")
    }

    // MARK: - claim 2

    func testAFiniteHostValueIsClampedToItsDescriptor() {
        for d in EchoelBodyVibeDevice.creativeDescriptors {
            XCTAssertEqual(EchoelBodyVibeDevice.admitted(d.max + 1_000, forCreativeID: d.keyPath), d.max,
                           "\(d.keyPath): above-range value not clamped")
            XCTAssertEqual(EchoelBodyVibeDevice.admitted(d.min - 1_000, forCreativeID: d.keyPath), d.min,
                           "\(d.keyPath): below-range value not clamped")
            // COUNTERWEIGHT — an in-range value passes untouched.
            XCTAssertEqual(EchoelBodyVibeDevice.admitted(d.defaultValue, forCreativeID: d.keyPath),
                           d.defaultValue, "\(d.keyPath): the default is not admitted as itself")
        }
    }

    // MARK: - claim 3 (SOURCE-TEXT SCAN)

    func testTheObserverAdmitsBeforeEveryCreativeWrite() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let observer = try XCTUnwrap(Self.body(
            startingWith: "_parameterTree.implementorValueObserver = {", in: code),
            "the value observer is not found — re-anchor this guard (#456)")
        XCTAssertEqual(observer.components(separatedBy:
            "EchoelBodyVibeDevice.admitted(value, forCreativeID: id)").count - 1, 2, """
            The observer no longer passes the host's value through `admitted` in BOTH creative \
            branches (engine bindings and Master Gain).
            """)
        XCTAssertFalse(observer.contains("apply(binding, value: value"),
                       "the raw host value reaches `apply` again")
        XCTAssertFalse(observer.contains("gainMirror.value = value"),
                       "the raw host value reaches the output-gain mirror again — NaN would leave the plug-in")
    }

    // MARK: - claim 4

    func testTheDeviceAndItsStateAskTheOneDescriptorRule() throws {
        for d in EchoelBodyVibeDevice.creativeDescriptors {
            let probes: [Float] = [d.min - 1, d.min, d.defaultValue, d.max, d.max + 1,
                                   .nan, .infinity, -.infinity]
            for v in probes {
                XCTAssertEqual(EchoelBodyVibeDevice.admitted(v, forCreativeID: d.keyPath), d.admitted(v),
                               "\(d.keyPath): the device admits \(v) differently from its descriptor")
            }
        }
        let inverted = ParameterDescriptor(keyPath: "probe.inverted", displayName: "Inverted",
                                           min: 1, max: 0, defaultValue: 0.5)
        XCTAssertNil(inverted.admitted(0.5), "an inverted range admitted a value instead of refusing it")

        let code = SourceText.codeOnly(try text(Self.device))
        XCTAssertFalse(code.contains("Swift.min(Swift.max(value, descriptor.min)"), """
            The device file clamps a descriptor value by hand again — a second spelling of \
            `ParameterDescriptor.admitted` (#416).
            """)
        let sanitized = try XCTUnwrap(Self.body(
            startingWith: "public func sanitized(against descriptors: [ParameterDescriptor])", in: code),
            "`sanitized(against:)` is not found — re-anchor this guard (#456)")
        XCTAssertTrue(sanitized.contains("descriptor.admitted("),
                      "a restored state no longer passes the descriptor's own admission rule")
    }

    // MARK: - helpers

    private static func body(startingWith anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor) else { return nil }
        var depth = 0
        var out = ""
        for ch in code[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { out.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
        }
        return nil
    }

    private func text(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — source-text claim cannot run (#454)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
