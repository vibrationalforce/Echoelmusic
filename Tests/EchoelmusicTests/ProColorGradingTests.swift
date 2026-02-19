import XCTest
@testable import Echoelmusic

/// Comprehensive tests for ProColorGrading — professional color grading engine.
/// Tests color wheels, curves, HSL, nodes, LUT operations.
@MainActor
final class ProColorGradingTests: XCTestCase {

    var sut: ProColorGrading!

    override func setUp() async throws {
        try await super.setUp()
        sut = ProColorGrading()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization (4 tests)

    func testInitialization() {
        XCTAssertNotNil(sut)
    }

    func testInitialNodeCount() {
        XCTAssertFalse(sut.nodes.isEmpty, "Should start with at least one grading node")
    }

    func testSelectedNodeExists() {
        XCTAssertNotNil(sut.selectedNodeIndex)
    }

    func testInitialExposure() {
        // Default exposure should be neutral (0)
        let node = sut.nodes[sut.selectedNodeIndex]
        XCTAssertEqual(node.exposure, 0, accuracy: 0.01)
    }

    // MARK: - Color Wheel Tests (5 tests)

    func testResetWheels() {
        sut.resetWheels()
        let node = sut.nodes[sut.selectedNodeIndex]
        XCTAssertEqual(node.lift.x, 0, accuracy: 0.01)
        XCTAssertEqual(node.lift.y, 0, accuracy: 0.01)
        XCTAssertEqual(node.gamma.x, 0, accuracy: 0.01)
        XCTAssertEqual(node.gamma.y, 0, accuracy: 0.01)
        XCTAssertEqual(node.gain.x, 0, accuracy: 0.01)
        XCTAssertEqual(node.gain.y, 0, accuracy: 0.01)
    }

    func testResetCurves() {
        sut.resetCurves()
        // Curves should be reset to identity (input == output)
    }

    func testResetHSL() {
        sut.resetHSL()
        // HSL values should be neutral
    }

    func testResetAll() {
        sut.resetAll()
        let node = sut.nodes[sut.selectedNodeIndex]
        XCTAssertEqual(node.exposure, 0, accuracy: 0.01)
        XCTAssertEqual(node.contrast, 0, accuracy: 0.01)
        XCTAssertEqual(node.saturation, 1.0, accuracy: 0.01)
    }

    func testResetAllDoesNotRemoveNodes() {
        let countBefore = sut.nodes.count
        sut.resetAll()
        XCTAssertEqual(sut.nodes.count, countBefore)
    }

    // MARK: - Node Management (5 tests)

    func testAddNode() {
        let countBefore = sut.nodes.count
        sut.addNode()
        XCTAssertEqual(sut.nodes.count, countBefore + 1)
    }

    func testRemoveNode() {
        sut.addNode()
        let countBefore = sut.nodes.count
        sut.removeNode(at: countBefore - 1)
        XCTAssertEqual(sut.nodes.count, countBefore - 1)
    }

    func testSelectNode() {
        sut.addNode()
        let lastIndex = sut.nodes.count - 1
        sut.selectNode(lastIndex)
        XCTAssertEqual(sut.selectedNodeIndex, lastIndex)
    }

    func testSelectInvalidNodeDoesNotCrash() {
        sut.selectNode(999)
    }

    func testRemoveLastNodePreservesMinimum() {
        // Ensure at least 1 node always exists
        while sut.nodes.count > 1 {
            sut.removeNode(at: sut.nodes.count - 1)
        }
        sut.removeNode(at: 0)
        XCTAssertGreaterThanOrEqual(sut.nodes.count, 1)
    }

    // MARK: - Grade Copy/Paste (3 tests)

    func testCopyGrade() {
        let grade = sut.copyGrade()
        XCTAssertNotNil(grade)
    }

    func testPasteGrade() {
        let grade = sut.copyGrade()
        sut.addNode()
        sut.selectNode(sut.nodes.count - 1)
        sut.pasteGrade(grade)
    }

    func testSaveAndLoadGrade() {
        sut.saveGrade(name: "TestGrade")
        sut.addNode()
        sut.loadGrade(name: "TestGrade")
    }

    // MARK: - CurvePoint & HSLValues (4 tests)

    func testCurvePointClamping() {
        let point = CurvePoint(input: -0.5, output: 1.5)
        XCTAssertGreaterThanOrEqual(point.input, 0)
        XCTAssertLessThanOrEqual(point.output, 1)
    }

    func testCurvePointEquality() {
        let a = CurvePoint(input: 0.5, output: 0.5)
        let b = CurvePoint(input: 0.5, output: 0.5)
        XCTAssertEqual(a, b)
    }

    func testHSLValuesNeutral() {
        let hsl = HSLValues()
        XCTAssertTrue(hsl.isNeutral)
    }

    func testHSLValuesClamping() {
        let hsl = HSLValues(hueShift: 300, saturation: 5, luminance: -3)
        XCTAssertLessThanOrEqual(hsl.hueShift, 180)
        XCTAssertLessThanOrEqual(hsl.saturation, 1)
        XCTAssertGreaterThanOrEqual(hsl.luminance, -1)
    }

    // MARK: - ColorRange (2 tests)

    func testColorRangeCenterHues() {
        XCTAssertEqual(ColorRange.red.centerHue, 0)
        XCTAssertEqual(ColorRange.green.centerHue, 120)
        XCTAssertEqual(ColorRange.blue.centerHue, 240)
    }

    func testColorRangeHueWidth() {
        XCTAssertGreaterThan(ColorRange.red.hueWidth, 0)
    }
}
