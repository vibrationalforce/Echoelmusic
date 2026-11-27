#if canImport(Metal)
import Metal
#endif
import EchoelCore
import XCTest

/// The app compiles its Metal shaders at runtime, so no build sees them: a syntax error would turn
/// the Field (rings and Chladni plate alike) and the video layer into a flat picture on the device.
/// These tests compile each program on the runner's GPU, find the entry points the renderer looks
/// up, and build the render pipeline from them, as the app does.
final class FieldShaderTests: XCTestCase {
    func testEveryProgramCompilesAndBuildsItsPipeline() throws {
        #if canImport(Metal)
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("NO METAL DEVICE on this runner: the Field shaders were NOT compiled")
        }
        XCTAssertEqual(FieldShader.all.count, 2)
        for program in FieldShader.all {
            let library: MTLLibrary
            do {
                library = try device.makeLibrary(source: program.source, options: nil)
            } catch {
                XCTFail("\(program.fragmentFunction): the shader does not compile: \(error)")
                continue
            }
            let vertex = library.makeFunction(name: program.vertexFunction)
            let fragment = library.makeFunction(name: program.fragmentFunction)
            XCTAssertNotNil(vertex, "no function \(program.vertexFunction)")
            XCTAssertNotNil(fragment, "no function \(program.fragmentFunction)")
            guard let vertex, let fragment else { continue }
            XCTAssertEqual(vertex.functionType, .vertex)
            XCTAssertEqual(fragment.functionType, .fragment)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
            XCTAssertNoThrow(try device.makeRenderPipelineState(descriptor: descriptor),
                             "\(program.fragmentFunction): the pipeline does not build")
        }
        #else
        throw XCTSkip("no Metal on this platform: the Field shaders are compiled on the macOS runner")
        #endif
    }

    // MARK: - The touch light's words

    /// A spot as the shader reads it: x, y, progress, strength, then red, green, blue and a spare.
    private func expected(_ spot: FieldTouchLight.Spot) -> [Float] {
        [Float(spot.x), Float(spot.y), Float(spot.progress), Float(spot.amplitude),
         Float(spot.colour.red), Float(spot.colour.green), Float(spot.colour.blue), 0]
    }

    /// The slot `slot` of `words`: its eight words.
    private func slot(_ index: Int, of words: [Float]) -> [Float] {
        Array(words[(index * FieldShader.wordsPerTouchSpot)..<((index + 1) * FieldShader.wordsPerTouchSpot)])
    }

    /// The touch light (`FieldTouchLight.Shown`) reaches the Field's shader as eight words a spot in
    /// its slot: the drops first, then the clouds. No touch light is all zero, which is what a pass
    /// without live touches (the video export) binds.
    func testTheTouchLightReachesTheShaderSpotBySpot() {
        let spots = FieldTouchLight.dropSlots + FieldTouchLight.cloudSlots
        XCTAssertEqual(FieldShader.wordsPerTouchSpot, 8, "two float4 a spot")
        XCTAssertEqual(FieldShader.touchWordCount, spots * 8)
        XCTAssertEqual(FieldShader.touchWords(FieldTouchLight.Shown()), [Float](repeating: 0, count: spots * 8))

        var shown = FieldTouchLight.Shown()
        let drop = FieldTouchLight.Spot(x: 0.25, y: 0.75, progress: 0.5, amplitude: 0.625,
                                        colour: ToneLight.RGB(red: 0.125, green: 0.25, blue: 0.0625))
        let cloud = FieldTouchLight.Spot(x: 0.5, y: 0.125, progress: 0.375, amplitude: 0.5,
                                         colour: ToneLight.RGB(red: 0.03125, green: 0.0625, blue: 0.5))
        shown.drops[1] = drop
        shown.clouds[FieldTouchLight.cloudSlots - 1] = cloud
        let words = FieldShader.touchWords(shown)
        XCTAssertEqual(words.count, FieldShader.touchWordCount)
        XCTAssertEqual(slot(1, of: words), expected(drop))
        XCTAssertEqual(slot(spots - 1, of: words), expected(cloud), "the last cloud in the last slot")
        for index in 0..<spots where index != 1 && index != spots - 1 {
            XCTAssertEqual(slot(index, of: words), [Float](repeating: 0, count: 8), "slot \(index) is dark")
        }
        // A cloud in the first cloud slot follows the last drop slot.
        shown = FieldTouchLight.Shown()
        shown.clouds[0] = cloud
        XCTAssertEqual(slot(FieldTouchLight.dropSlots, of: FieldShader.touchWords(shown)), expected(cloud))
    }

    /// What the CPU's light leaves dark (`FieldTouchLight.Shown.light`) is dark in the shader too: a
    /// spot with no strength, a place or a strength that is no number, a drop whose life is over. A
    /// cloud whose growth is no number is drawn grown, as the CPU draws it; a colour channel that is
    /// no number is dark. Slots beyond the shader's are left out, missing ones are dark.
    func testWhatTheLightLeavesDarkIsDarkInTheShader() {
        func spot(x: Double = 0.5, y: Double = 0.5, progress: Double = 0.25, amplitude: Double = 0.5,
                  colour: ToneLight.RGB = ToneLight.RGB(red: 0.5, green: 0.25, blue: 0.125)) -> FieldTouchLight.Spot {
            FieldTouchLight.Spot(x: x, y: y, progress: progress, amplitude: amplitude, colour: colour)
        }
        let dark = [Float](repeating: 0, count: 8)
        let unlit = [spot(amplitude: 0), spot(amplitude: -1), spot(x: .nan), spot(y: .infinity),
                     spot(amplitude: .nan), spot(progress: 1)]
        XCTAssertEqual(unlit.count, FieldTouchLight.dropSlots)
        var shown = FieldTouchLight.Shown()
        shown.drops = unlit
        for index in 0..<FieldTouchLight.dropSlots {
            XCTAssertEqual(slot(index, of: FieldShader.touchWords(shown)), dark, "drop \(index)")
        }
        shown.drops = [spot(progress: .nan)]
        XCTAssertEqual(slot(0, of: FieldShader.touchWords(shown)), dark, "a drop whose life is no number")
        shown = FieldTouchLight.Shown()
        shown.clouds[2] = spot(progress: .nan)
        XCTAssertEqual(slot(FieldTouchLight.dropSlots + 2, of: FieldShader.touchWords(shown)),
                       [0.5, 0.5, 1, 0.5, 0.5, 0.25, 0.125, 0], "grown, as the CPU draws it")
        shown.clouds[2] = spot(progress: 1)
        XCTAssertEqual(slot(FieldTouchLight.dropSlots + 2, of: FieldShader.touchWords(shown)),
                       [0.5, 0.5, 1, 0.5, 0.5, 0.25, 0.125, 0], "a grown cloud still shines")
        shown.clouds[2] = spot(colour: ToneLight.RGB(red: .nan, green: 0.25, blue: .infinity))
        XCTAssertEqual(slot(FieldTouchLight.dropSlots + 2, of: FieldShader.touchWords(shown)),
                       [0.5, 0.5, 0.25, 0.5, 0, 0.25, 0, 0])
        // Too many slots, and too few.
        shown = FieldTouchLight.Shown(drops: Array(repeating: spot(), count: 9), clouds: [])
        let words = FieldShader.touchWords(shown)
        XCTAssertEqual(words.count, FieldShader.touchWordCount)
        for index in 0..<FieldTouchLight.dropSlots {
            XCTAssertEqual(slot(index, of: words), [0.5, 0.5, 0.25, 0.5, 0.5, 0.25, 0.125, 0], "drop \(index)")
        }
        for index in FieldTouchLight.dropSlots..<(FieldTouchLight.dropSlots + FieldTouchLight.cloudSlots) {
            XCTAssertEqual(slot(index, of: words), dark, "slot \(index): no cloud")
        }
    }
}
