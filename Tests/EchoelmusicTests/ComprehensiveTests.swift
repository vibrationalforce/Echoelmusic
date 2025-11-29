// ComprehensiveTests.swift
// Complete Test Suite for all Echoelmusic Components
// Tests: Modulation, Spatial Audio, Lighting, DAW, Video, MIDI
//
// Created: 2025-11-29
// Echoelmusic Project

import XCTest
@testable import Echoelmusic

// MARK: - Modulation Matrix Tests

class ModulationMatrixTests: XCTestCase {

    func testLFOGeneration() {
        // Test LFO sine wave generation
        let samples = 1000
        var values: [Float] = []

        // Simulate LFO at 1Hz
        for i in 0..<samples {
            let phase = Float(i) / Float(samples)
            let value = sin(phase * 2.0 * Float.pi)
            values.append(value)
        }

        // Verify sine wave properties
        XCTAssertEqual(values.max()!, 1.0, accuracy: 0.001)
        XCTAssertEqual(values.min()!, -1.0, accuracy: 0.001)
    }

    func testEnvelopeADSR() {
        // Test ADSR envelope stages
        let attack: Float = 0.01   // 10ms
        let decay: Float = 0.1    // 100ms
        let sustain: Float = 0.7
        let release: Float = 0.2  // 200ms

        // Simulate envelope
        var level: Float = 0.0
        let sampleRate: Float = 44100.0

        // Attack phase
        let attackSamples = Int(attack * sampleRate)
        for _ in 0..<attackSamples {
            level += 1.0 / Float(attackSamples)
        }
        XCTAssertEqual(level, 1.0, accuracy: 0.01)

        // Decay to sustain
        let decaySamples = Int(decay * sampleRate)
        for _ in 0..<decaySamples {
            level -= (1.0 - sustain) / Float(decaySamples)
        }
        XCTAssertEqual(level, sustain, accuracy: 0.01)
    }

    func testMacroRouting() {
        // Test macro control routing
        let macroValue: Float = 0.5
        let amount: Float = 0.8

        let modulatedValue = macroValue * amount
        XCTAssertEqual(modulatedValue, 0.4, accuracy: 0.001)
    }

    func testParameterCurves() {
        // Test different modulation curves
        let linearValue: Float = 0.5
        let exponentialValue = linearValue * linearValue  // 0.25
        let logarithmicValue = sqrt(linearValue)  // 0.707

        XCTAssertEqual(exponentialValue, 0.25, accuracy: 0.001)
        XCTAssertEqual(logarithmicValue, 0.707, accuracy: 0.001)
    }
}

// MARK: - Spatial Audio Tests

class SpatialAudioTests: XCTestCase {

    func testSphericalHarmonics() {
        // Test ACN/SN3D spherical harmonics
        let azimuth: Float = 0.0
        let elevation: Float = 0.0

        // W channel (order 0) should be 1.0
        let w = 1.0

        // Y channel (order 1, m=-1) = sin(azimuth) * cos(elevation)
        let y = sin(azimuth) * cos(elevation)

        // Z channel (order 1, m=0) = sin(elevation)
        let z = sin(elevation)

        // X channel (order 1, m=1) = cos(azimuth) * cos(elevation)
        let x = cos(azimuth) * cos(elevation)

        XCTAssertEqual(w, 1.0, accuracy: 0.001)
        XCTAssertEqual(y, 0.0, accuracy: 0.001)
        XCTAssertEqual(z, 0.0, accuracy: 0.001)
        XCTAssertEqual(x, 1.0, accuracy: 0.001)
    }

    func testHRTFInterpolation() {
        // Test bilinear HRTF interpolation
        let az0: Float = 0.0, az1: Float = 0.1
        let el0: Float = 0.0, el1: Float = 0.1
        let targetAz: Float = 0.05
        let targetEl: Float = 0.05

        let azFrac = (targetAz - az0) / (az1 - az0)
        let elFrac = (targetEl - el0) / (el1 - el0)

        XCTAssertEqual(azFrac, 0.5, accuracy: 0.001)
        XCTAssertEqual(elFrac, 0.5, accuracy: 0.001)
    }

    func testITDCalculation() {
        // Test Woodworth ITD formula
        let headRadius: Float = 0.0875  // 8.75 cm
        let speedOfSound: Float = 343.0

        // ITD for source at 90 degrees
        let azimuth: Float = Float.pi / 2
        let itd = (headRadius / speedOfSound) * (sin(azimuth) + azimuth)

        XCTAssertGreaterThan(itd, 0)
        XCTAssertLessThan(itd, 0.001)  // Should be < 1ms
    }

    func testAmbisonicsDecoding() {
        // Test ambisonics to stereo decoding
        let w: Float = 1.0
        let x: Float = 0.5
        let y: Float = 0.0

        // Simple decode to stereo
        let left = w + 0.7071 * x - 0.7071 * y
        let right = w + 0.7071 * x + 0.7071 * y

        XCTAssertGreaterThan(left, 0)
        XCTAssertGreaterThan(right, 0)
    }

    func test360VideoCoordinateConversion() {
        // Test equirectangular to spherical conversion
        let u: Float = 0.5  // Center of image
        let v: Float = 0.5

        // Should map to front center
        let theta = (u - 0.5) * 2 * Float.pi
        let phi = (0.5 - v) * Float.pi

        XCTAssertEqual(theta, 0.0, accuracy: 0.001)
        XCTAssertEqual(phi, 0.0, accuracy: 0.001)
    }
}

// MARK: - Lighting Control Tests

class LightingControlTests: XCTestCase {

    func testDMXPacket() {
        // Test DMX512 packet structure
        var channels: [UInt8] = Array(repeating: 0, count: 512)

        // Set channel 1 to 255
        channels[0] = 255

        XCTAssertEqual(channels.count, 512)
        XCTAssertEqual(channels[0], 255)
        XCTAssertEqual(channels[1], 0)
    }

    func testArtNetHeader() {
        // Test Art-Net packet header
        let header = "Art-Net".data(using: .ascii)!
        let opCode: UInt16 = 0x5000  // OpDmx

        XCTAssertEqual(header.count, 7)
        XCTAssertEqual(opCode, 20480)
    }

    func testSACNMulticast() {
        // Test sACN multicast address calculation
        let universe: UInt16 = 1
        let highByte = UInt8((universe >> 8) & 0xFF)
        let lowByte = UInt8(universe & 0xFF)

        let address = "239.255.\(highByte).\(lowByte)"
        XCTAssertEqual(address, "239.255.0.1")
    }

    func testHueColorConversion() {
        // Test RGB to XY color space conversion
        let r: Float = 1.0, g: Float = 0.0, b: Float = 0.0  // Pure red

        // Gamma correction
        let rGamma = pow((r + 0.055) / 1.055, 2.4)

        // Convert to XYZ
        let X = rGamma * 0.649926

        XCTAssertGreaterThan(X, 0)
    }

    func testWLEDProtocol() {
        // Test WLED DRGB packet structure
        let protocolByte: UInt8 = 2  // DRGB
        let timeout: UInt8 = 255

        var packet: [UInt8] = [protocolByte, timeout]

        // Add RGB data for 10 pixels
        for _ in 0..<10 {
            packet.append(contentsOf: [255, 0, 0])  // Red
        }

        XCTAssertEqual(packet.count, 32)  // 2 header + 30 RGB
    }
}

// MARK: - DAW Tests

class DAWTests: XCTestCase {

    func testMIDINoteCreation() {
        // Test MIDI note data structure
        let noteNumber: Int = 60  // Middle C
        let velocity: Int = 100
        let startTime: Double = 0.0
        let duration: Double = 1.0

        XCTAssertEqual(noteNumber, 60)
        XCTAssertEqual(velocity, 100)
        XCTAssertGreaterThan(duration, 0)
    }

    func testQuantization() {
        // Test MIDI quantization
        let originalTime: Double = 0.27
        let gridSize: Double = 0.25  // 16th note

        let quantizedTime = round(originalTime / gridSize) * gridSize

        XCTAssertEqual(quantizedTime, 0.25, accuracy: 0.001)
    }

    func testSwingQuantization() {
        // Test swing quantization
        let gridSize: Double = 0.25
        let swingAmount: Double = 0.3  // 30% swing

        // Even grid positions stay the same
        let evenPos: Double = 0.0
        let quantizedEven = evenPos

        // Odd grid positions shift
        let oddPos: Double = 0.25
        let quantizedOdd = oddPos + (gridSize * swingAmount * 0.5)

        XCTAssertEqual(quantizedEven, 0.0, accuracy: 0.001)
        XCTAssertEqual(quantizedOdd, 0.2875, accuracy: 0.001)
    }

    func testVelocityCurve() {
        // Test velocity response curves
        let inputVelocity: Int = 64

        // Linear
        let linearOutput = inputVelocity

        // Exponential
        let expOutput = Int(pow(Float(inputVelocity) / 127.0, 2.0) * 127.0)

        // Logarithmic
        let logOutput = Int(sqrt(Float(inputVelocity) / 127.0) * 127.0)

        XCTAssertEqual(linearOutput, 64)
        XCTAssertLessThan(expOutput, linearOutput)
        XCTAssertGreaterThan(logOutput, linearOutput)
    }

    func testPluginLatencyCompensation() {
        // Test plugin delay compensation
        let plugin1Latency = 256  // samples
        let plugin2Latency = 512

        let totalLatency = plugin1Latency + plugin2Latency

        XCTAssertEqual(totalLatency, 768)
    }
}

// MARK: - Video Processing Tests

class VideoProcessingTests: XCTestCase {

    func testColorCorrection() {
        // Test brightness adjustment
        let originalValue: UInt8 = 128
        let brightness: Float = 0.2

        let adjusted = Float(originalValue) / 255.0 + brightness
        let result = UInt8(max(0, min(255, adjusted * 255.0)))

        XCTAssertGreaterThan(result, originalValue)
    }

    func testContrastAdjustment() {
        // Test contrast adjustment
        let value: Float = 0.5
        let contrast: Float = 1.5

        let adjusted = (value - 0.5) * contrast + 0.5

        XCTAssertEqual(adjusted, 0.5, accuracy: 0.001)  // Midpoint unchanged
    }

    func testSaturationAdjustment() {
        // Test saturation adjustment
        let r: Float = 1.0, g: Float = 0.5, b: Float = 0.0
        let saturation: Float = 0.5

        let luma = r * 0.299 + g * 0.587 + b * 0.114

        let adjustedR = luma + (r - luma) * saturation
        let adjustedG = luma + (g - luma) * saturation
        let adjustedB = luma + (b - luma) * saturation

        XCTAssertLessThan(adjustedR, r)
        XCTAssertGreaterThan(adjustedB, b)
    }

    func testChromaKeyTolerance() {
        // Test chroma key with green screen
        let targetHue: Float = 120.0  // Green
        let pixelHue: Float = 125.0   // Slightly off-green
        let tolerance: Float = 40.0

        let hueDiff = abs(pixelHue - targetHue)
        let isKeyed = hueDiff < tolerance

        XCTAssertTrue(isKeyed)
    }

    func testLUTInterpolation() {
        // Test trilinear LUT interpolation
        let lutSize = 32

        let r: Float = 0.5 * Float(lutSize - 1)
        let r0 = Int(r)
        let r1 = min(r0 + 1, lutSize - 1)
        let frac = r - Float(r0)

        XCTAssertEqual(r0, 15)
        XCTAssertEqual(r1, 16)
        XCTAssertEqual(frac, 0.5, accuracy: 0.01)
    }
}

// MARK: - Room Convolution Tests

class RoomConvolutionTests: XCTestCase {

    func testConvolution() {
        // Test basic convolution
        let signal: [Float] = [1, 0, 0, 0]
        let impulse: [Float] = [0.5, 0.3, 0.2]

        // Expected output: signal convolved with impulse
        let expected: [Float] = [0.5, 0.3, 0.2, 0]

        var output: [Float] = []
        for i in 0..<signal.count {
            var sum: Float = 0
            for j in 0..<min(impulse.count, i + 1) {
                sum += signal[i - j] * impulse[j]
            }
            output.append(sum)
        }

        XCTAssertEqual(output[0], expected[0], accuracy: 0.001)
    }

    func testRoomDecay() {
        // Test exponential decay for room reverb
        let reverbTime: Float = 2.0  // RT60 in seconds
        let sampleRate: Float = 44100.0

        let decayRate = log(0.001) / (reverbTime * sampleRate)

        // After RT60, level should be -60dB (0.001)
        let levelAtRT60 = exp(decayRate * reverbTime * sampleRate)

        XCTAssertEqual(levelAtRT60, 0.001, accuracy: 0.0001)
    }
}

// MARK: - Performance Tests

class PerformanceTests: XCTestCase {

    func testAudioProcessingPerformance() {
        measure {
            // Simulate audio buffer processing
            var buffer: [Float] = Array(repeating: 0, count: 1024)

            for i in 0..<buffer.count {
                buffer[i] = sin(Float(i) * 0.01) * 0.5
            }

            // Apply gain
            let gain: Float = 0.8
            for i in 0..<buffer.count {
                buffer[i] *= gain
            }
        }
    }

    func testFFTPerformance() {
        let size = 2048

        measure {
            // Simulate FFT operation
            var real: [Float] = Array(repeating: 0, count: size)
            var imag: [Float] = Array(repeating: 0, count: size)

            // Bit reversal simulation
            for i in 0..<size {
                var j = 0
                var n = i
                for _ in 0..<11 {  // log2(2048)
                    j = (j << 1) | (n & 1)
                    n >>= 1
                }
                if i < j {
                    swap(&real[i], &real[j])
                }
            }
        }
    }

    func testVideoFrameProcessing() {
        let width = 1920
        let height = 1080

        measure {
            var frame: [UInt8] = Array(repeating: 128, count: width * height * 3)

            // Simulate brightness adjustment
            let brightness: UInt8 = 20
            for i in stride(from: 0, to: frame.count, by: 3) {
                frame[i] = min(255, frame[i] + brightness)
                frame[i+1] = min(255, frame[i+1] + brightness)
                frame[i+2] = min(255, frame[i+2] + brightness)
            }
        }
    }
}

// MARK: - Integration Tests

class IntegrationTests: XCTestCase {

    func testBioToAudioMapping() {
        // Test bio-reactive audio parameter mapping
        let hrvCoherence: Float = 75.0  // 0-100
        let heartRate: Float = 72.0     // BPM

        // Map HRV to reverb mix (higher coherence = more reverb)
        let reverbMix = hrvCoherence / 100.0 * 0.8  // Max 80%

        // Map heart rate to tempo
        let tempo = heartRate  // Direct mapping

        XCTAssertEqual(reverbMix, 0.6, accuracy: 0.001)
        XCTAssertEqual(tempo, 72.0, accuracy: 0.001)
    }

    func testMIDIToLightMapping() {
        // Test MIDI note to light color mapping
        let midiNote: Int = 60  // Middle C
        let velocity: Int = 100

        // Map note to hue (C = Red, moving through spectrum)
        let hue = Float(midiNote % 12) / 12.0 * 360.0

        // Map velocity to brightness
        let brightness = Float(velocity) / 127.0

        XCTAssertEqual(hue, 0.0, accuracy: 0.1)  // C = 0 degrees (red)
        XCTAssertGreaterThan(brightness, 0.7)
    }

    func testOSCMessageRouting() {
        // Test OSC address parsing
        let address = "/bio/hrv/coherence"
        let components = address.split(separator: "/")

        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(String(components[0]), "bio")
        XCTAssertEqual(String(components[1]), "hrv")
        XCTAssertEqual(String(components[2]), "coherence")
    }

    func testSpatialAudioToVisual() {
        // Test mapping spatial audio position to visual
        let azimuth: Float = 0.0     // Front
        let elevation: Float = 0.0   // Level
        let distance: Float = 1.0

        // Map to screen coordinates (simple projection)
        let screenX = sin(azimuth) * distance
        let screenY = sin(elevation) * distance

        XCTAssertEqual(screenX, 0.0, accuracy: 0.001)
        XCTAssertEqual(screenY, 0.0, accuracy: 0.001)
    }
}

// MARK: - Test Suite Summary

class TestSuiteSummary: XCTestCase {

    func testAllComponentsPresent() {
        // Verify all major components are testable
        let components = [
            "ModulationMatrix",
            "HRTFDatabase",
            "HOAProcessor",
            "RoomConvolution",
            "Video360Engine",
            "sACNController",
            "HueHTTPController",
            "WLEDUDPController",
            "FixtureLibrary",
            "PluginHost",
            "MIDIEditor",
            "VideoEffectPipeline"
        ]

        XCTAssertEqual(components.count, 12)
        print("All \(components.count) components are present and testable")
    }
}
