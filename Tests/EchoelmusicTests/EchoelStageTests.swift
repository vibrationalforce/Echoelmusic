#if canImport(UIKit)
//
//  EchoelStageTests.swift
//  Echoelmusic
//
//  Tests for EchoelStage types: StageDisplayInfo, StageScene, StageColor,
//  StageVisualMode, ProjectionWarp, StageOutputMode, StageCue
//

import XCTest
@testable import Echoelmusic

// MARK: - StageDisplayInfo Tests

final class StageDisplayInfoTests: XCTestCase {

    func testStageDisplayInfo_init_setsName() {
        let info = StageDisplayInfo(name: "Projector A", resolution: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(info.name, "Projector A")
    }

    func testStageDisplayInfo_init_setsResolution() {
        let info = StageDisplayInfo(name: "Display", resolution: CGSize(width: 3840, height: 2160))
        XCTAssertEqual(info.resolution.width, 3840)
        XCTAssertEqual(info.resolution.height, 2160)
    }

    func testStageDisplayInfo_init_defaultRefreshRate_is60() {
        let info = StageDisplayInfo(name: "Display", resolution: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(info.refreshRate, 60.0)
    }

    func testStageDisplayInfo_init_customRefreshRate() {
        let info = StageDisplayInfo(name: "Display", resolution: CGSize(width: 1920, height: 1080), refreshRate: 120.0)
        XCTAssertEqual(info.refreshRate, 120.0)
    }

    func testStageDisplayInfo_init_defaultIsAirPlay_isFalse() {
        let info = StageDisplayInfo(name: "Display", resolution: CGSize(width: 1920, height: 1080))
        XCTAssertFalse(info.isAirPlay)
    }

    func testStageDisplayInfo_init_customIsAirPlay() {
        let info = StageDisplayInfo(name: "AirPlay Display", resolution: CGSize(width: 1920, height: 1080), isAirPlay: true)
        XCTAssertTrue(info.isAirPlay)
    }

    func testStageDisplayInfo_init_defaultScreenIndex_isZero() {
        let info = StageDisplayInfo(name: "Display", resolution: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(info.screenIndex, 0)
    }

    func testStageDisplayInfo_init_customScreenIndex() {
        let info = StageDisplayInfo(name: "Display", resolution: CGSize(width: 1920, height: 1080), screenIndex: 2)
        XCTAssertEqual(info.screenIndex, 2)
    }

    func testStageDisplayInfo_init_generatesUniqueID() {
        let info1 = StageDisplayInfo(name: "Display 1", resolution: CGSize(width: 1920, height: 1080))
        let info2 = StageDisplayInfo(name: "Display 2", resolution: CGSize(width: 1920, height: 1080))
        XCTAssertNotEqual(info1.id, info2.id)
    }

    func testStageDisplayInfo_init_allParametersCustom() {
        let info = StageDisplayInfo(
            name: "Stage Projector",
            resolution: CGSize(width: 3840, height: 2160),
            refreshRate: 144.0,
            isAirPlay: true,
            screenIndex: 3
        )
        XCTAssertEqual(info.name, "Stage Projector")
        XCTAssertEqual(info.resolution, CGSize(width: 3840, height: 2160))
        XCTAssertEqual(info.refreshRate, 144.0)
        XCTAssertTrue(info.isAirPlay)
        XCTAssertEqual(info.screenIndex, 3)
    }

    func testStageDisplayInfo_identifiable_hasID() {
        let info = StageDisplayInfo(name: "Display", resolution: CGSize(width: 1920, height: 1080))
        XCTAssertNotNil(info.id)
    }
}

// MARK: - StageScene Tests

final class StageSceneTests: XCTestCase {

    // MARK: - Init Defaults

    func testStageScene_init_setsName() {
        let scene = StageScene(name: "Bio Scene")
        XCTAssertEqual(scene.name, "Bio Scene")
    }

    func testStageScene_init_defaultOpacity_is1() {
        let scene = StageScene(name: "Test")
        XCTAssertEqual(scene.opacity, 1.0)
    }

    func testStageScene_init_defaultTransitionDuration_is05() {
        let scene = StageScene(name: "Test")
        XCTAssertEqual(scene.transitionDuration, 0.5)
    }

    func testStageScene_init_defaultBackgroundColor_isBlack() {
        let scene = StageScene(name: "Test")
        XCTAssertEqual(scene.backgroundColor.red, 0)
        XCTAssertEqual(scene.backgroundColor.green, 0)
        XCTAssertEqual(scene.backgroundColor.blue, 0)
        XCTAssertEqual(scene.backgroundColor.alpha, 1)
    }

    func testStageScene_init_defaultVisualMode_isSolidColor() {
        let scene = StageScene(name: "Test")
        XCTAssertEqual(scene.visualMode, .solidColor)
    }

    func testStageScene_init_bioReactiveIntensity_setFromInit() {
        let scene = StageScene(name: "Test", bioReactiveIntensity: 0.5)
        XCTAssertEqual(scene.bioReactiveIntensity, 0.5)
    }

    func testStageScene_init_defaultBioReactiveIntensity_is08() {
        let scene = StageScene(name: "Test")
        XCTAssertEqual(scene.bioReactiveIntensity, 0.8, accuracy: 0.0001)
    }

    func testStageScene_init_projectionWarp_isDefaultZero() {
        let scene = StageScene(name: "Test")
        XCTAssertEqual(scene.projectionWarp.topLeft, .zero)
        XCTAssertEqual(scene.projectionWarp.topRight, .zero)
        XCTAssertEqual(scene.projectionWarp.bottomLeft, .zero)
        XCTAssertEqual(scene.projectionWarp.bottomRight, .zero)
    }

    func testStageScene_init_customVisualMode() {
        let scene = StageScene(name: "Particles", visualMode: .particles)
        XCTAssertEqual(scene.visualMode, .particles)
    }

    func testStageScene_init_customBackgroundColor() {
        let scene = StageScene(name: "White", backgroundColor: .white)
        XCTAssertEqual(scene.backgroundColor.red, 1)
        XCTAssertEqual(scene.backgroundColor.green, 1)
        XCTAssertEqual(scene.backgroundColor.blue, 1)
    }

    func testStageScene_init_generatesUniqueID() {
        let scene1 = StageScene(name: "A")
        let scene2 = StageScene(name: "B")
        XCTAssertNotEqual(scene1.id, scene2.id)
    }

    // MARK: - Codable Round-Trip

    func testStageScene_codableRoundTrip_defaultScene() throws {
        let original = StageScene(name: "Default")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StageScene.self, from: data)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.opacity, original.opacity)
        XCTAssertEqual(decoded.transitionDuration, original.transitionDuration)
        XCTAssertEqual(decoded.visualMode, original.visualMode)
        XCTAssertEqual(decoded.bioReactiveIntensity, original.bioReactiveIntensity)
    }

    func testStageScene_codableRoundTrip_customScene() throws {
        var original = StageScene(name: "Custom", backgroundColor: .white, visualMode: .bioReactive, bioReactiveIntensity: 0.3)
        original.opacity = 0.7
        original.transitionDuration = 1.5
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StageScene.self, from: data)
        XCTAssertEqual(decoded.name, "Custom")
        XCTAssertEqual(decoded.opacity, 0.7, accuracy: 0.0001)
        XCTAssertEqual(decoded.transitionDuration, 1.5)
        XCTAssertEqual(decoded.visualMode, .bioReactive)
        XCTAssertEqual(decoded.bioReactiveIntensity, 0.3, accuracy: 0.0001)
    }

    func testStageScene_codable_producesValidJSON() throws {
        let scene = StageScene(name: "JSON Test")
        let data = try JSONEncoder().encode(scene)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["name"])
        XCTAssertNotNil(json?["opacity"])
    }
}

// MARK: - StageColor Tests

final class StageColorTests: XCTestCase {

    // MARK: - Static Constants

    func testStageColor_black_isCorrect() {
        let black = StageColor.black
        XCTAssertEqual(black.red, 0)
        XCTAssertEqual(black.green, 0)
        XCTAssertEqual(black.blue, 0)
        XCTAssertEqual(black.alpha, 1)
    }

    func testStageColor_white_isCorrect() {
        let white = StageColor.white
        XCTAssertEqual(white.red, 1)
        XCTAssertEqual(white.green, 1)
        XCTAssertEqual(white.blue, 1)
        XCTAssertEqual(white.alpha, 1)
    }

    // MARK: - fromCoherence

    func testStageColor_fromCoherence_zeroIsCoolBlue() {
        let color = StageColor.fromCoherence(0)
        // red = 0 * 0.9 + 0.1 = 0.1
        XCTAssertEqual(color.red, 0.1, accuracy: 0.01)
        // green = 0 * 0.7 + 0.1 = 0.1
        XCTAssertEqual(color.green, 0.1, accuracy: 0.01)
        // blue = (1-0) * 0.8 + 0.2 = 1.0
        XCTAssertEqual(color.blue, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.alpha, 1.0)
    }

    func testStageColor_fromCoherence_zeroHasLowRed() {
        let color = StageColor.fromCoherence(0)
        XCTAssertLessThan(color.red, 0.2)
    }

    func testStageColor_fromCoherence_zeroHasHighBlue() {
        let color = StageColor.fromCoherence(0)
        XCTAssertGreaterThan(color.blue, 0.8)
    }

    func testStageColor_fromCoherence_oneIsWarmGold() {
        let color = StageColor.fromCoherence(1)
        // red = 1 * 0.9 + 0.1 = 1.0
        XCTAssertEqual(color.red, 1.0, accuracy: 0.01)
        // green = 1 * 0.7 + 0.1 = 0.8
        XCTAssertEqual(color.green, 0.8, accuracy: 0.01)
        // blue = (1-1) * 0.8 + 0.2 = 0.2
        XCTAssertEqual(color.blue, 0.2, accuracy: 0.01)
        XCTAssertEqual(color.alpha, 1.0)
    }

    func testStageColor_fromCoherence_oneHasHighRed() {
        let color = StageColor.fromCoherence(1)
        XCTAssertGreaterThan(color.red, 0.8)
    }

    func testStageColor_fromCoherence_oneHasLowBlue() {
        let color = StageColor.fromCoherence(1)
        XCTAssertLessThan(color.blue, 0.3)
    }

    func testStageColor_fromCoherence_halfIsMiddleValues() {
        let color = StageColor.fromCoherence(0.5)
        // red = 0.5 * 0.9 + 0.1 = 0.55
        XCTAssertEqual(color.red, 0.55, accuracy: 0.01)
        // green = 0.5 * 0.7 + 0.1 = 0.45
        XCTAssertEqual(color.green, 0.45, accuracy: 0.01)
        // blue = (1-0.5) * 0.8 + 0.2 = 0.6
        XCTAssertEqual(color.blue, 0.6, accuracy: 0.01)
    }

    func testStageColor_fromCoherence_halfRedIsBetweenZeroAndOne() {
        let color = StageColor.fromCoherence(0.5)
        let colorZero = StageColor.fromCoherence(0)
        let colorOne = StageColor.fromCoherence(1)
        XCTAssertGreaterThan(color.red, colorZero.red)
        XCTAssertLessThan(color.red, colorOne.red)
    }

    func testStageColor_fromCoherence_clampsNegativeToZero() {
        let colorNeg = StageColor.fromCoherence(-0.5)
        let colorZero = StageColor.fromCoherence(0)
        XCTAssertEqual(colorNeg.red, colorZero.red, accuracy: 0.001)
        XCTAssertEqual(colorNeg.green, colorZero.green, accuracy: 0.001)
        XCTAssertEqual(colorNeg.blue, colorZero.blue, accuracy: 0.001)
    }

    func testStageColor_fromCoherence_clampsAboveOneToOne() {
        let colorHigh = StageColor.fromCoherence(1.5)
        let colorOne = StageColor.fromCoherence(1)
        XCTAssertEqual(colorHigh.red, colorOne.red, accuracy: 0.001)
        XCTAssertEqual(colorHigh.green, colorOne.green, accuracy: 0.001)
        XCTAssertEqual(colorHigh.blue, colorOne.blue, accuracy: 0.001)
    }

    func testStageColor_fromCoherence_alphaAlwaysOne() {
        for coherence: Float in [0, 0.25, 0.5, 0.75, 1.0] {
            let color = StageColor.fromCoherence(coherence)
            XCTAssertEqual(color.alpha, 1.0, "Alpha should be 1.0 for coherence \(coherence)")
        }
    }

    // MARK: - Codable Round-Trip

    func testStageColor_codableRoundTrip_black() throws {
        let original = StageColor.black
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StageColor.self, from: data)
        XCTAssertEqual(decoded.red, original.red)
        XCTAssertEqual(decoded.green, original.green)
        XCTAssertEqual(decoded.blue, original.blue)
        XCTAssertEqual(decoded.alpha, original.alpha)
    }

    func testStageColor_codableRoundTrip_white() throws {
        let original = StageColor.white
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StageColor.self, from: data)
        XCTAssertEqual(decoded.red, original.red)
        XCTAssertEqual(decoded.green, original.green)
        XCTAssertEqual(decoded.blue, original.blue)
        XCTAssertEqual(decoded.alpha, original.alpha)
    }

    func testStageColor_codableRoundTrip_customColor() throws {
        let original = StageColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.8)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StageColor.self, from: data)
        XCTAssertEqual(decoded.red, 0.3, accuracy: 0.0001)
        XCTAssertEqual(decoded.green, 0.6, accuracy: 0.0001)
        XCTAssertEqual(decoded.blue, 0.9, accuracy: 0.0001)
        XCTAssertEqual(decoded.alpha, 0.8, accuracy: 0.0001)
    }

    func testStageColor_codableRoundTrip_fromCoherence() throws {
        let original = StageColor.fromCoherence(0.7)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StageColor.self, from: data)
        XCTAssertEqual(decoded.red, original.red, accuracy: 0.0001)
        XCTAssertEqual(decoded.green, original.green, accuracy: 0.0001)
        XCTAssertEqual(decoded.blue, original.blue, accuracy: 0.0001)
    }

    // MARK: - Init

    func testStageColor_init_setsAllFields() {
        let color = StageColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        XCTAssertEqual(color.red, 0.1, accuracy: 0.0001)
        XCTAssertEqual(color.green, 0.2, accuracy: 0.0001)
        XCTAssertEqual(color.blue, 0.3, accuracy: 0.0001)
        XCTAssertEqual(color.alpha, 0.4, accuracy: 0.0001)
    }

    func testStageColor_isMutable() {
        var color = StageColor.black
        color.red = 0.5
        XCTAssertEqual(color.red, 0.5)
    }
}

// MARK: - StageVisualMode Tests

final class StageVisualModeTests: XCTestCase {

    func testStageVisualMode_allCases_countIsEight() {
        XCTAssertEqual(StageVisualMode.allCases.count, 8)
    }

    func testStageVisualMode_allCases_containsAllModes() {
        let cases = StageVisualMode.allCases
        XCTAssertTrue(cases.contains(.solidColor))
        XCTAssertTrue(cases.contains(.gradient))
        XCTAssertTrue(cases.contains(.waveform))
        XCTAssertTrue(cases.contains(.spectrum))
        XCTAssertTrue(cases.contains(.particles))
        XCTAssertTrue(cases.contains(.bioReactive))
        XCTAssertTrue(cases.contains(.videoPassthrough))
        XCTAssertTrue(cases.contains(.textOverlay))
    }

    func testStageVisualMode_rawValues() {
        XCTAssertEqual(StageVisualMode.solidColor.rawValue, "Solid Color")
        XCTAssertEqual(StageVisualMode.gradient.rawValue, "Gradient")
        XCTAssertEqual(StageVisualMode.waveform.rawValue, "Waveform")
        XCTAssertEqual(StageVisualMode.spectrum.rawValue, "Spectrum")
        XCTAssertEqual(StageVisualMode.particles.rawValue, "Particles")
        XCTAssertEqual(StageVisualMode.bioReactive.rawValue, "Bio-Reactive")
        XCTAssertEqual(StageVisualMode.videoPassthrough.rawValue, "Video Passthrough")
        XCTAssertEqual(StageVisualMode.textOverlay.rawValue, "Text Overlay")
    }

    func testStageVisualMode_initFromRawValue_solidColor() {
        XCTAssertEqual(StageVisualMode(rawValue: "Solid Color"), .solidColor)
    }

    func testStageVisualMode_initFromRawValue_bioReactive() {
        XCTAssertEqual(StageVisualMode(rawValue: "Bio-Reactive"), .bioReactive)
    }

    func testStageVisualMode_initFromRawValue_invalidReturnsNil() {
        XCTAssertNil(StageVisualMode(rawValue: "Hologram"))
    }

    func testStageVisualMode_codableRoundTrip_allCases() throws {
        for mode in StageVisualMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(StageVisualMode.self, from: data)
            XCTAssertEqual(mode, decoded, "Round-trip failed for \(mode)")
        }
    }
}

// MARK: - ProjectionWarp Tests

final class ProjectionWarpTests: XCTestCase {

    // MARK: - Default Init

    func testProjectionWarp_defaultInit_allCornersZero() {
        let warp = ProjectionWarp()
        XCTAssertEqual(warp.topLeft, .zero)
        XCTAssertEqual(warp.topRight, .zero)
        XCTAssertEqual(warp.bottomLeft, .zero)
        XCTAssertEqual(warp.bottomRight, .zero)
    }

    func testProjectionWarp_defaultInit_edgeBlendIsZero() {
        let warp = ProjectionWarp()
        XCTAssertEqual(warp.edgeBlend, 0.0)
    }

    func testProjectionWarp_defaultInit_gammaIsOne() {
        let warp = ProjectionWarp()
        XCTAssertEqual(warp.gamma, 1.0)
    }

    // MARK: - isActive

    func testProjectionWarp_isActive_falseWhenDefault() {
        let warp = ProjectionWarp()
        XCTAssertFalse(warp.isActive)
    }

    func testProjectionWarp_isActive_trueWhenTopLeftChanged() {
        var warp = ProjectionWarp()
        warp.topLeft = CGPoint(x: 0.1, y: 0.0)
        XCTAssertTrue(warp.isActive)
    }

    func testProjectionWarp_isActive_trueWhenTopRightChanged() {
        var warp = ProjectionWarp()
        warp.topRight = CGPoint(x: -0.05, y: 0.02)
        XCTAssertTrue(warp.isActive)
    }

    func testProjectionWarp_isActive_trueWhenBottomLeftChanged() {
        var warp = ProjectionWarp()
        warp.bottomLeft = CGPoint(x: 0.0, y: -0.1)
        XCTAssertTrue(warp.isActive)
    }

    func testProjectionWarp_isActive_trueWhenBottomRightChanged() {
        var warp = ProjectionWarp()
        warp.bottomRight = CGPoint(x: 0.1, y: 0.1)
        XCTAssertTrue(warp.isActive)
    }

    func testProjectionWarp_isActive_falseWhenCornersResetToZero() {
        var warp = ProjectionWarp()
        warp.topLeft = CGPoint(x: 0.1, y: 0.1)
        XCTAssertTrue(warp.isActive)
        warp.topLeft = .zero
        XCTAssertFalse(warp.isActive)
    }

    func testProjectionWarp_isActive_trueWhenMultipleCornersChanged() {
        var warp = ProjectionWarp()
        warp.topLeft = CGPoint(x: 0.1, y: 0.1)
        warp.bottomRight = CGPoint(x: -0.1, y: -0.1)
        XCTAssertTrue(warp.isActive)
    }

    // MARK: - Codable Round-Trip

    func testProjectionWarp_codableRoundTrip_default() throws {
        let original = ProjectionWarp()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProjectionWarp.self, from: data)
        XCTAssertEqual(decoded.topLeft, original.topLeft)
        XCTAssertEqual(decoded.topRight, original.topRight)
        XCTAssertEqual(decoded.bottomLeft, original.bottomLeft)
        XCTAssertEqual(decoded.bottomRight, original.bottomRight)
        XCTAssertEqual(decoded.edgeBlend, original.edgeBlend)
        XCTAssertEqual(decoded.gamma, original.gamma)
    }

    func testProjectionWarp_codableRoundTrip_withModifiedCorners() throws {
        var original = ProjectionWarp()
        original.topLeft = CGPoint(x: 0.1, y: -0.2)
        original.bottomRight = CGPoint(x: -0.15, y: 0.3)
        original.edgeBlend = 0.5
        original.gamma = 2.2
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProjectionWarp.self, from: data)
        XCTAssertEqual(decoded.topLeft.x, 0.1, accuracy: 0.0001)
        XCTAssertEqual(decoded.topLeft.y, -0.2, accuracy: 0.0001)
        XCTAssertEqual(decoded.bottomRight.x, -0.15, accuracy: 0.0001)
        XCTAssertEqual(decoded.bottomRight.y, 0.3, accuracy: 0.0001)
        XCTAssertEqual(decoded.edgeBlend, 0.5, accuracy: 0.0001)
        XCTAssertEqual(decoded.gamma, 2.2, accuracy: 0.0001)
    }

    // MARK: - Mutation

    func testProjectionWarp_mutation_edgeBlend() {
        var warp = ProjectionWarp()
        warp.edgeBlend = 0.75
        XCTAssertEqual(warp.edgeBlend, 0.75, accuracy: 0.0001)
    }

    func testProjectionWarp_mutation_gamma() {
        var warp = ProjectionWarp()
        warp.gamma = 2.4
        XCTAssertEqual(warp.gamma, 2.4, accuracy: 0.0001)
    }
}

// MARK: - StageOutputMode Tests

final class StageOutputModeTests: XCTestCase {

    func testStageOutputMode_allCases_countIsFour() {
        XCTAssertEqual(StageOutputMode.allCases.count, 4)
    }

    func testStageOutputMode_allCases_containsAllModes() {
        let cases = StageOutputMode.allCases
        XCTAssertTrue(cases.contains(.mirror))
        XCTAssertTrue(cases.contains(.extended))
        XCTAssertTrue(cases.contains(.projectionMap))
        XCTAssertTrue(cases.contains(.multiDisplay))
    }

    func testStageOutputMode_rawValues() {
        XCTAssertEqual(StageOutputMode.mirror.rawValue, "Mirror")
        XCTAssertEqual(StageOutputMode.extended.rawValue, "Extended")
        XCTAssertEqual(StageOutputMode.projectionMap.rawValue, "Projection Map")
        XCTAssertEqual(StageOutputMode.multiDisplay.rawValue, "Multi-Display")
    }

    func testStageOutputMode_initFromRawValue_mirror() {
        XCTAssertEqual(StageOutputMode(rawValue: "Mirror"), .mirror)
    }

    func testStageOutputMode_initFromRawValue_projectionMap() {
        XCTAssertEqual(StageOutputMode(rawValue: "Projection Map"), .projectionMap)
    }

    func testStageOutputMode_initFromRawValue_invalidReturnsNil() {
        XCTAssertNil(StageOutputMode(rawValue: "Picture-in-Picture"))
    }

    func testStageOutputMode_codableRoundTrip_allCases() throws {
        for mode in StageOutputMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(StageOutputMode.self, from: data)
            XCTAssertEqual(mode, decoded, "Round-trip failed for \(mode)")
        }
    }
}

// MARK: - StageCue Tests

final class StageCueTests: XCTestCase {

    // MARK: - Init Defaults

    func testStageCue_init_setsName() {
        let sceneID = UUID()
        let cue = StageCue(name: "Intro", sceneID: sceneID)
        XCTAssertEqual(cue.name, "Intro")
    }

    func testStageCue_init_setsSceneID() {
        let sceneID = UUID()
        let cue = StageCue(name: "Intro", sceneID: sceneID)
        XCTAssertEqual(cue.sceneID, sceneID)
    }

    func testStageCue_init_defaultTriggerTime_isNil() {
        let cue = StageCue(name: "Cue", sceneID: UUID())
        XCTAssertNil(cue.triggerTime)
    }

    func testStageCue_init_customTriggerTime() {
        let cue = StageCue(name: "Cue", sceneID: UUID(), triggerTime: 4.0)
        XCTAssertEqual(cue.triggerTime, 4.0)
    }

    func testStageCue_init_defaultTriggerOnBeat_isFalse() {
        let cue = StageCue(name: "Cue", sceneID: UUID())
        XCTAssertFalse(cue.triggerOnBeat)
    }

    func testStageCue_init_defaultAutoAdvance_isFalse() {
        let cue = StageCue(name: "Cue", sceneID: UUID())
        XCTAssertFalse(cue.autoAdvance)
    }

    func testStageCue_init_defaultTransitionDuration_is05() {
        let cue = StageCue(name: "Cue", sceneID: UUID())
        XCTAssertEqual(cue.transitionDuration, 0.5)
    }

    func testStageCue_init_customTransitionDuration() {
        let cue = StageCue(name: "Cue", sceneID: UUID(), transitionDuration: 2.0)
        XCTAssertEqual(cue.transitionDuration, 2.0)
    }

    func testStageCue_init_generatesUniqueID() {
        let sceneID = UUID()
        let cue1 = StageCue(name: "A", sceneID: sceneID)
        let cue2 = StageCue(name: "B", sceneID: sceneID)
        XCTAssertNotEqual(cue1.id, cue2.id)
    }

    // MARK: - Codable Round-Trip

    func testStageCue_codableRoundTrip_defaultCue() throws {
        let original = StageCue(name: "Default Cue", sceneID: UUID())
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StageCue.self, from: data)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.sceneID, original.sceneID)
        XCTAssertEqual(decoded.triggerOnBeat, original.triggerOnBeat)
        XCTAssertEqual(decoded.autoAdvance, original.autoAdvance)
        XCTAssertEqual(decoded.transitionDuration, original.transitionDuration)
        XCTAssertNil(decoded.triggerTime)
    }

    func testStageCue_codableRoundTrip_cueWithTriggerTime() throws {
        let original = StageCue(name: "Beat Cue", sceneID: UUID(), triggerTime: 8.0, transitionDuration: 1.0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StageCue.self, from: data)
        XCTAssertEqual(decoded.name, "Beat Cue")
        XCTAssertEqual(decoded.triggerTime, 8.0)
        XCTAssertEqual(decoded.transitionDuration, 1.0)
    }

    func testStageCue_codableRoundTrip_cueWithAllFieldsSet() throws {
        var original = StageCue(name: "Full Cue", sceneID: UUID(), triggerTime: 16.0, transitionDuration: 3.0)
        original.triggerOnBeat = true
        original.autoAdvance = true
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StageCue.self, from: data)
        XCTAssertEqual(decoded.name, "Full Cue")
        XCTAssertEqual(decoded.triggerTime, 16.0)
        XCTAssertTrue(decoded.triggerOnBeat)
        XCTAssertTrue(decoded.autoAdvance)
        XCTAssertEqual(decoded.transitionDuration, 3.0)
    }

    func testStageCue_codable_producesValidJSON() throws {
        let cue = StageCue(name: "JSON Cue", sceneID: UUID())
        let data = try JSONEncoder().encode(cue)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["name"])
        XCTAssertNotNil(json?["sceneID"])
    }

    // MARK: - Mutation

    func testStageCue_mutation_triggerOnBeat() {
        var cue = StageCue(name: "Cue", sceneID: UUID())
        XCTAssertFalse(cue.triggerOnBeat)
        cue.triggerOnBeat = true
        XCTAssertTrue(cue.triggerOnBeat)
    }

    func testStageCue_mutation_autoAdvance() {
        var cue = StageCue(name: "Cue", sceneID: UUID())
        XCTAssertFalse(cue.autoAdvance)
        cue.autoAdvance = true
        XCTAssertTrue(cue.autoAdvance)
    }

    func testStageCue_mutation_name() {
        var cue = StageCue(name: "Original", sceneID: UUID())
        cue.name = "Updated"
        XCTAssertEqual(cue.name, "Updated")
    }

    func testStageCue_mutation_transitionDuration() {
        var cue = StageCue(name: "Cue", sceneID: UUID())
        cue.transitionDuration = 5.0
        XCTAssertEqual(cue.transitionDuration, 5.0)
    }
}

#endif
