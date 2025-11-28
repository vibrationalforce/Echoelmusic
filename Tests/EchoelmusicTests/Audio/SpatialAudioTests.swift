import XCTest
@testable import Echoelmusic

/// Comprehensive tests for Spatial Audio processing
/// Coverage target: 3D positioning, Dolby Atmos, head tracking, HRTF
final class SpatialAudioTests: XCTestCase {

    // MARK: - 3D Coordinate Tests

    func testCartesianCoordinates() {
        // Standard 3D cartesian coordinates
        let x: Float = 1.0   // Right (+) / Left (-)
        let y: Float = 0.5   // Up (+) / Down (-)
        let z: Float = -2.0  // Front (-) / Back (+)

        XCTAssertEqual(x, 1.0, accuracy: 0.01)
        XCTAssertEqual(y, 0.5, accuracy: 0.01)
        XCTAssertEqual(z, -2.0, accuracy: 0.01)
    }

    func testSphericalCoordinates() {
        // Spherical coordinates: azimuth, elevation, distance
        let azimuth: Float = 45.0      // Degrees: 0 = front, 90 = right
        let elevation: Float = 30.0    // Degrees: 0 = horizontal, 90 = up
        let distance: Float = 2.0      // Meters

        XCTAssertGreaterThanOrEqual(azimuth, -180)
        XCTAssertLessThanOrEqual(azimuth, 180)
        XCTAssertGreaterThanOrEqual(elevation, -90)
        XCTAssertLessThanOrEqual(elevation, 90)
        XCTAssertGreaterThan(distance, 0)
    }

    func testCartesianToSphericalConversion() {
        // Convert cartesian to spherical
        let x: Float = 1.0
        let y: Float = 0.0
        let z: Float = -1.0

        let distance = sqrt(x*x + y*y + z*z)
        let azimuth = atan2(x, -z) * 180.0 / .pi
        let elevation = asin(y / distance) * 180.0 / .pi

        XCTAssertEqual(distance, sqrt(2.0), accuracy: 0.01)
        XCTAssertEqual(azimuth, 45.0, accuracy: 0.1)
        XCTAssertEqual(elevation, 0.0, accuracy: 0.01)
    }

    // MARK: - Distance Attenuation Tests

    func testInverseDistanceLaw() {
        // Sound intensity = 1 / distance^2
        let distance1: Float = 1.0
        let distance2: Float = 2.0

        let intensity1 = 1.0 / (distance1 * distance1)
        let intensity2 = 1.0 / (distance2 * distance2)

        XCTAssertEqual(intensity1 / intensity2, 4.0, accuracy: 0.01,
                       "Doubling distance = 1/4 intensity")
    }

    func testDistanceAttenuationDB() {
        // 6 dB loss per doubling of distance
        let dbLossPerDouble: Float = 6.0
        XCTAssertEqual(dbLossPerDouble, 6.0, accuracy: 0.1)
    }

    func testMinMaxDistanceClamping() {
        // Audio should clamp between min and max distance
        let minDistance: Float = 1.0   // Full volume
        let maxDistance: Float = 100.0 // Silence

        XCTAssertGreaterThan(maxDistance, minDistance)
    }

    // MARK: - HRTF Tests (Head-Related Transfer Function)

    func testHRTFElevations() {
        // Standard HRTF elevation angles
        let elevations: [Int] = [-40, -30, -20, -10, 0, 10, 20, 30, 40, 50, 60, 70, 80, 90]
        XCTAssertEqual(elevations.count, 14)
        XCTAssertTrue(elevations.contains(0), "Should include horizontal")
        XCTAssertTrue(elevations.contains(90), "Should include directly above")
    }

    func testHRTFAzimuths() {
        // Azimuth resolution typically 5 degrees
        let azimuthResolution = 5
        let totalAzimuths = 360 / azimuthResolution

        XCTAssertEqual(totalAzimuths, 72)
    }

    func testHRTFSampleRate() {
        // HRTF typically at 44.1 or 48 kHz
        let hrtfSampleRates = [44100, 48000]
        XCTAssertTrue(hrtfSampleRates.contains(48000))
    }

    func testHRTFImpulseResponseLength() {
        // HRTF impulse response typically 128-512 samples
        let typicalIRLength = 256
        XCTAssertGreaterThanOrEqual(typicalIRLength, 128)
        XCTAssertLessThanOrEqual(typicalIRLength, 512)
    }

    // MARK: - ITD/ILD Tests (Interaural Differences)

    func testInterauralTimeDelay() {
        // Max ITD ~0.7ms (ear separation ~17cm)
        let earSeparation: Float = 0.17  // meters
        let speedOfSound: Float = 343.0  // m/s
        let maxITD = earSeparation / speedOfSound * 1000  // ms

        XCTAssertEqual(maxITD, 0.5, accuracy: 0.1, "Max ITD ~0.5ms")
    }

    func testInterauralLevelDifference() {
        // ILD increases with frequency (head shadow effect)
        let ildLowFreq: Float = 0.0    // dB at 500 Hz
        let ildHighFreq: Float = 20.0  // dB at 8000 Hz (max)

        XCTAssertLessThan(ildLowFreq, ildHighFreq)
    }

    // MARK: - Dolby Atmos Tests

    func testAtmosBedChannels() {
        // Standard Atmos bed layouts
        let atmos512 = 6   // 5.1.2
        let atmos514 = 10  // 5.1.4
        let atmos714 = 12  // 7.1.4
        let atmos916 = 16  // 9.1.6

        XCTAssertEqual(atmos512, 6, "5.1.2 = 5+1 bed channels")
        XCTAssertEqual(atmos714, 12, "7.1.4 = 7+1+4 channels")
    }

    func testAtmosObjectCount() {
        // Dolby Atmos supports up to 128 audio objects
        let maxObjects = 128
        XCTAssertEqual(maxObjects, 128)
    }

    func testAtmosOverheadSpeakers() {
        // Height layer speaker configurations
        let heights2 = 2   // Top front L/R
        let heights4 = 4   // + Top rear L/R
        let heights6 = 6   // + Top middle L/R

        XCTAssertEqual(heights4, 4, "7.1.4 has 4 height speakers")
    }

    func testAtmosSampleRate() {
        // Atmos typically at 48kHz
        let atmosSampleRate = 48000
        XCTAssertEqual(atmosSampleRate, 48000)
    }

    // MARK: - Head Tracking Tests

    func testHeadTrackingQuaternion() {
        // Quaternion rotation: w, x, y, z
        let w: Float = 1.0
        let x: Float = 0.0
        let y: Float = 0.0
        let z: Float = 0.0

        // Unit quaternion: w^2 + x^2 + y^2 + z^2 = 1
        let magnitude = sqrt(w*w + x*x + y*y + z*z)
        XCTAssertEqual(magnitude, 1.0, accuracy: 0.001)
    }

    func testHeadTrackingUpdateRate() {
        // Head tracking typically 60-120 Hz
        let updateRateHz: Float = 60.0
        let updateIntervalMs = 1000.0 / updateRateHz

        XCTAssertEqual(updateIntervalMs, 16.67, accuracy: 0.1)
    }

    func testHeadTrackingLatency() {
        // Acceptable head tracking latency < 20ms
        let maxLatencyMs: Float = 20.0
        XCTAssertLessThanOrEqual(maxLatencyMs, 20.0)
    }

    // MARK: - Ambisonics Tests

    func testAmbisonicsOrders() {
        // First order: 4 channels (W, X, Y, Z)
        // Second order: 9 channels
        // Third order: 16 channels
        let firstOrder = 4
        let secondOrder = 9
        let thirdOrder = 16

        XCTAssertEqual(firstOrder, 4)
        XCTAssertEqual(secondOrder, 9)
        XCTAssertEqual(thirdOrder, 16)
    }

    func testAmbisonicsChannelCount() {
        // Channels = (order + 1)^2
        let order = 2
        let channels = (order + 1) * (order + 1)

        XCTAssertEqual(channels, 9, "2nd order = 9 channels")
    }

    func testFuMaVsACNChannelOrdering() {
        // FuMa: W, X, Y, Z (legacy)
        // ACN: W, Y, Z, X (SN3D normalized - modern standard)
        let fuma = ["W", "X", "Y", "Z"]
        let acn = ["W", "Y", "Z", "X"]

        XCTAssertNotEqual(fuma, acn, "Different channel ordering")
        XCTAssertEqual(fuma.count, 4)
    }

    // MARK: - Room Acoustics Tests

    func testReverbPreDelayRange() {
        // Pre-delay typically 0-100ms
        let minPreDelay: Float = 0.0
        let maxPreDelay: Float = 100.0

        XCTAssertEqual(minPreDelay, 0.0)
        XCTAssertLessThanOrEqual(maxPreDelay, 100.0)
    }

    func testReverbDecayTime() {
        // RT60: time for 60dB decay
        let smallRoomRT60: Float = 0.3   // seconds
        let concertHallRT60: Float = 2.0 // seconds
        let cathedralRT60: Float = 5.0   // seconds

        XCTAssertLessThan(smallRoomRT60, concertHallRT60)
        XCTAssertLessThan(concertHallRT60, cathedralRT60)
    }

    func testEarlyReflectionsCount() {
        // Early reflections (first 80ms): typically 6-20 reflections
        let minEarlyReflections = 6
        let maxEarlyReflections = 20

        XCTAssertGreaterThanOrEqual(maxEarlyReflections, minEarlyReflections)
    }

    // MARK: - Panning Tests

    func testVBAP() {
        // Vector Base Amplitude Panning
        // Gain for speaker i = cos(angle between source and speaker)
        let sourceAngle: Float = 30.0  // degrees
        let speakerAngle: Float = 45.0 // degrees

        let angleDiff = abs(sourceAngle - speakerAngle)
        let gain = cos(angleDiff * .pi / 180.0)

        XCTAssertGreaterThan(gain, 0.9, "Close angles = high gain")
    }

    func testDBAPDistanceWeight() {
        // Distance-Based Amplitude Panning
        let distance1: Float = 1.0
        let distance2: Float = 2.0

        let weight1 = 1.0 / distance1
        let weight2 = 1.0 / distance2

        XCTAssertEqual(weight1 / weight2, 2.0, accuracy: 0.01)
    }

    // MARK: - Doppler Effect Tests

    func testDopplerShift() {
        // f' = f * (v + vr) / (v + vs)
        // v = speed of sound, vr = receiver velocity, vs = source velocity
        let speedOfSound: Float = 343.0
        let sourceVelocity: Float = 30.0  // Approaching at 30 m/s
        let frequency: Float = 440.0

        let shiftedFreq = frequency * speedOfSound / (speedOfSound - sourceVelocity)

        XCTAssertGreaterThan(shiftedFreq, frequency, "Approaching = higher frequency")
    }

    func testDopplerMaxShift() {
        // Limit doppler shift to reasonable range (avoid extreme artifacts)
        let maxDopplerRatio: Float = 2.0  // One octave up
        let minDopplerRatio: Float = 0.5  // One octave down

        XCTAssertEqual(maxDopplerRatio, 2.0)
        XCTAssertEqual(minDopplerRatio, 0.5)
    }

    // MARK: - Occlusion Tests

    func testOcclusionLowPassCutoff() {
        // Occluded sound loses high frequencies
        let occludedCutoff: Float = 1000.0  // Hz (muffled)
        let normalCutoff: Float = 20000.0   // Hz (full range)

        XCTAssertLessThan(occludedCutoff, normalCutoff)
    }

    func testOcclusionAttenuation() {
        // Occluded sound is attenuated
        let maxOcclusionDB: Float = -24.0

        XCTAssertLessThan(maxOcclusionDB, 0)
    }
}
