import XCTest
@testable import EchoelmusicVisual

final class XRBridgeTests: XCTestCase {

    @MainActor
    func testXRAvailability() {
        let bridge = XRBridge()

        // On non-visionOS platforms, should not be available
        #if !os(visionOS)
        XCTAssertFalse(bridge.isAvailable)
        #endif
    }

    @MainActor
    func testXRModeToggle() async throws {
        let bridge = XRBridge()

        XCTAssertFalse(bridge.isActive)
        XCTAssertNil(bridge.currentMode)

        // Attempting to enter XR mode on non-visionOS should throw
        #if !os(visionOS)
        do {
            try await bridge.enterXRMode(.ar)
            XCTFail("Should have thrown XRError.notAvailable")
        } catch {
            XCTAssertTrue(error is XRError)
        }
        #endif
    }
}
