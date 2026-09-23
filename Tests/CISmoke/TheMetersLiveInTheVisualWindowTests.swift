// TheMetersLiveInTheVisualWindowTests.swift
// Echoel — S4c (founder 2026-09-23, "all tasks"; placement his own from 2026-08-13: *"Das Brauch
// da nicht sein. Wenn dann ins Visual Window übertragen."*). The four measuring views are
// reachable again — inside the floating Visual window, at Large and fullscreen, one at a time,
// INSTEAD of the picture. Never in the Field panel.
//
// WHAT KIND OF GUARD THIS IS (§1): claims 1–3 are END-TO-END BEHAVIOUR on shipped, Foundation-only
// types (`FloatingVisualLayout.analysisDoor`, `chromeFit`, `VisualAnalysisMeter`); claims 4–10 are
// SOURCE-TEXT SCANS, because the window and the layer are `View`s this bundle cannot instantiate.
// Whether the meters READ well at 330 pt, whether a tap on "Picture" lands through the hidden
// play surface, and whether VoiceOver reaches the segments are DEVICE PROBES and stay open.
//
// HONEST GRADING (§3): this file does not compile against the parent — it names
// `FloatingVisualLayout.AnalysisDoor`, `analysisDoor(isPresented:isRoomy:meterOn:)` and
// `VisualAnalysisMeter`, which this commit creates. No assertion has a verdict there.
// Transcribed against both trees: claims 1–8 are FORWARD (their subject does not exist on the
// parent — #486, one absence, not eight findings); claim 9 is a COUNTERWEIGHT, green on both
// (the Field panel constructed none of the four before, and must not now); claim 10 reads
// `VisualAnalysisMeter.swift`, which the parent lacks, so there it SKIPS (missing tree), it
// does not pass.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheMetersLiveInTheVisualWindowTests: XCTestCase {

    private static let window = "Sources/Echoelmusic/Studio/FloatingVisualWindow.swift"
    private static let layer = "Sources/Echoelmusic/Studio/VisualAnalysisMeter.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let meterViews = ["AnalysisWavefrontView(", "AnalysisSpectrumView(",
                                     "AnalysisScopeView(", "AnalysisPoincareView("]

    /// 1. The door: a hidden window and a small one offer nothing; a roomy one offers, and shows
    /// once opened.
    func testTheDoorIsOfferedOnlyOnARoomyVisibleWindow() {
        typealias L = FloatingVisualLayout
        for on in [false, true] {
            XCTAssertEqual(L.analysisDoor(isPresented: false, isRoomy: true, meterOn: on), .absent,
                           "a hidden window renders nothing (#311) — it cannot offer a meter")
            XCTAssertEqual(L.analysisDoor(isPresented: true, isRoomy: false, meterOn: on), .absent,
                           "Small and Medium cannot hold a legible meter")
        }
        XCTAssertEqual(L.analysisDoor(isPresented: true, isRoomy: true, meterOn: false), .offered)
        XCTAssertEqual(L.analysisDoor(isPresented: true, isRoomy: true, meterOn: true), .shown)
    }

    /// 2. The bar follows the door: a meter on screen takes the picture's two controls AND the
    /// meters' own button with it (the way back is inside the meter surface), and never the exit.
    func testAMeterOnScreenTakesThePicturesControlsButNotTheExit() {
        let wide: CGFloat = 4000
        let offered = FloatingVisualLayout.chromeFit(cardWidth: wide, isFullscreen: true,
                                                     showsTransport: true, wavBusy: false,
                                                     analysisDoor: .offered)
        XCTAssertTrue(offered.analysisToggle, "offered + room to spare: the button is there")
        XCTAssertTrue(offered.lookSlider && offered.gridToggle)

        let shown = FloatingVisualLayout.chromeFit(cardWidth: wide, isFullscreen: true,
                                                   showsTransport: true, wavBusy: false,
                                                   analysisDoor: .shown)
        XCTAssertFalse(shown.analysisToggle, "the way back is \"Picture\" in the meter header")
        XCTAssertFalse(shown.lookSlider, "no picture to morph while a meter shows")
        XCTAssertFalse(shown.gridToggle, "no play grid to show while a meter shows")
        XCTAssertTrue(shown.studioChip, "the labelled exit is never the thing a meter removes")

        let absent = FloatingVisualLayout.chromeFit(cardWidth: wide, isFullscreen: true,
                                                    showsTransport: true, wavBusy: false,
                                                    analysisDoor: .absent)
        XCTAssertFalse(absent.analysisToggle)
    }

    /// 3. The meter choice: four meters, four distinct labels, and a stored value this build
    /// does not know falls back to the default instead of showing nothing.
    func testEveryStoredMeterValueResolvesToAMeter() {
        XCTAssertEqual(VisualAnalysisMeter.allCases.count, 4)
        XCTAssertEqual(Set(VisualAnalysisMeter.allCases.map(\.label)).count, 4)
        for m in VisualAnalysisMeter.allCases {
            XCTAssertEqual(VisualAnalysisMeter(stored: m.rawValue), m)
        }
        XCTAssertEqual(VisualAnalysisMeter(stored: "not-a-meter"), VisualAnalysisMeter.defaultMeter)
        XCTAssertEqual(VisualAnalysisMeter(stored: ""), VisualAnalysisMeter.defaultMeter)
        XCTAssertEqual(VisualAnalysisMeter.pulse.label, "Pulse",
                       "the camera measures PULSE intervals — not \"Beats\", not \"Heart\"")
    }

    /// 4. The ONE production budget call passes the door explicitly (#431: a defaulted argument
    /// no call site writes appears in no diff).
    func testTheWindowPassesTheDoorToTheBudget() throws {
        let code = SourceText.codeOnly(try rawText(Self.window))
        XCTAssertEqual(occurrences(of: "FloatingVisualLayout.chromeFit(", in: code), 1)
        XCTAssertTrue(code.contains("analysisDoor: analysisDoor)"),
                      "the window's `chromeFit` call no longer passes the door — the meters' button would never appear")
    }

    /// 5. The meters REPLACE the picture: their branch sits after the hidden branch (a hidden
    /// window renders nothing) and before every picture branch.
    func testTheMetersReplaceThePictureRatherThanOverlayIt() throws {
        let code = SourceText.codeOnly(try rawText(Self.window))
        let hidden = try XCTUnwrap(code.range(of: "if !isPresented {"))
        let meters = try XCTUnwrap(code.range(of: "} else if analysisShown {"))
        let external = try XCTUnwrap(code.range(of: "} else if ExternalStageBridge.shared.isConnected {"))
        let live = try XCTUnwrap(code.range(of: "liveVisual(wv)"))
        XCTAssertLessThan(hidden.lowerBound, meters.lowerBound)
        XCTAssertLessThan(meters.lowerBound, external.lowerBound)
        XCTAssertLessThan(meters.lowerBound, live.lowerBound)
        XCTAssertTrue(code.contains("VisualAnalysisLayer(reduceMotion: reduceMotion,"),
                      "the layer must receive the system Reduce Motion setting")
    }

    /// 6. ONE host: each meter is constructed exactly once in `Sources/`, and that once is the
    /// layer — so no second mount (the Field panel, a sheet) can appear beside it.
    func testEachMeterHasExactlyOneHost() throws {
        for needle in Self.meterViews {
            XCTAssertEqual(try filesUnderSources(containing: needle), ["Studio/VisualAnalysisMeter.swift"],
                           "`\(needle)` is constructed outside the Visual window's meter layer")
            let layer = SourceText.codeOnly(try rawText(Self.layer))
            XCTAssertEqual(occurrences(of: needle, in: layer), 1, "`\(needle)` mounted more than once")
        }
    }

    /// 7. While a meter shows, the play surface stays mounted (self-play keeps sounding) but
    /// cannot take a tap or a VoiceOver focus meant for the meter.
    func testThePlaySurfaceStepsAsideWhileAMeterShows() throws {
        let code = SourceText.codeOnly(try rawText(Self.window))
        XCTAssertTrue(code.contains(".allowsHitTesting(!analysisShown)"))
        XCTAssertTrue(code.contains(".accessibilityHidden(analysisShown)"))
        XCTAssertTrue(code.contains(".opacity(analysisShown ? 0 : 1)"))
    }

    /// 8. The way back is inside the meter surface, and the door closing resets the choice so a
    /// meter never returns unasked.
    func testTheWayBackLivesInTheMeterSurface() throws {
        let layer = SourceText.codeOnly(try rawText(Self.layer))
        XCTAssertTrue(layer.contains("Button(action: onShowPicture)"))
        XCTAssertTrue(layer.contains("Text(\"Picture\")"))
        let window = SourceText.codeOnly(try rawText(Self.window))
        XCTAssertTrue(window.contains("onShowPicture: { analysisOn = false }"))
        XCTAssertTrue(window.contains("if door == .absent { analysisOn = false }"))
    }

    /// 9. COUNTERWEIGHT — the Field panel stays free of meters (#575, the founder's red circle).
    func testTheFieldPanelStillShowsNoMeter() throws {
        let code = SourceText.codeOnly(try rawText(Self.studio))
        for needle in Self.meterViews {
            XCTAssertFalse(code.contains(needle), "`\(needle)` is back in `EchoelStudioView`")
        }
    }

    /// 10. COUNTERWEIGHT — the layer is a cold leaf: no hot read, and no `.menu` popover a
    /// rebuild could tear down (the 10.76.50 freeze law).
    func testTheMeterLayerReadsNothingHot() throws {
        let layer = SourceText.codeOnly(try rawText(Self.layer))
        XCTAssertFalse(layer.contains("audioEngine."))
        XCTAssertFalse(layer.contains("cameraRPPG."))
        XCTAssertFalse(layer.contains(".pickerStyle(.menu)"))
        XCTAssertTrue(layer.contains(".pickerStyle(.segmented)"))
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var index = text.startIndex
        while let found = text.range(of: needle, range: index..<text.endIndex) {
            count += 1
            index = found.upperBound
        }
        return count
    }

    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = try repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw XCTSkip("\(Self.sourcesRoot) is not present — this guard inspects source text (#454)")
        }
        // #1240: the tree exists, so a walk that cannot start is a red, never a skip.
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(Self.sourcesRoot) — refusing to report a green it did not earn")
            return []
        }
        var hits: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(text).contains(needle) { hits.append(relative) }
        }
        return hits.sorted()
    }

    private func rawText(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is not present — this guard inspects source text (#454)")
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
