import XCTest
@testable import EchoelmusicPlatform

final class PermissionsManagerTests: XCTestCase {

    @MainActor
    func testRequestPermission() async {
        let manager = PermissionsManager()

        let granted = await manager.request(.microphone)

        XCTAssertTrue(granted)
        XCTAssertEqual(manager.checkStatus(.microphone), .authorized)
    }

    @MainActor
    func testCheckStatus() {
        let manager = PermissionsManager()

        let status = manager.checkStatus(.camera)

        XCTAssertEqual(status, .notDetermined)
    }

    @MainActor
    func testRequestAllRequired() async {
        let manager = PermissionsManager()

        let allGranted = await manager.requestAllRequired()

        XCTAssertTrue(allGranted)
        XCTAssertEqual(manager.checkStatus(.microphone), .authorized)
        XCTAssertEqual(manager.checkStatus(.camera), .authorized)
        XCTAssertEqual(manager.checkStatus(.healthKit), .authorized)
    }
}
