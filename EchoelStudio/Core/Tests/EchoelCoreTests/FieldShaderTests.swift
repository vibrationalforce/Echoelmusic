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

}
