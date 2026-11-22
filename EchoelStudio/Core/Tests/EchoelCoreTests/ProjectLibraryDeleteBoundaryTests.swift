import Foundation
import XCTest
@testable import EchoelCore

/// Deleting a library song must never delete an external or nested .echoel package.
final class ProjectLibraryDeleteBoundaryTests: XCTestCase {
    func testDeleteRefusesOtherLibrariesAndNestedPackagesButDeletesOwnSong() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent("library-delete-\(UUID().uuidString)", isDirectory: true)
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: root) }

        let ownDirectory = root.appendingPathComponent("Own", isDirectory: true)
        let otherDirectory = root.appendingPathComponent("Other", isDirectory: true)
        let nestedDirectory = ownDirectory.appendingPathComponent("Nested", isDirectory: true)
        let own = ProjectLibrary(directory: ownDirectory)
        let other = ProjectLibrary(directory: otherDirectory)
        let nested = ProjectLibrary(directory: nestedDirectory)

        let ownURL = own.newURL(for: "Inside")
        let externalURL = other.newURL(for: "External")
        let nestedURL = nested.newURL(for: "Nested")
        try own.write(Project(name: "Inside"), to: ownURL)
        try other.write(Project(name: "External"), to: externalURL)
        try nested.write(Project(name: "Nested"), to: nestedURL)

        for outside in [externalURL, nestedURL] {
            XCTAssertThrowsError(try own.delete(outside)) { error in
                XCTAssertEqual(error as? ProjectLibrary.LibraryError, .notAPackage(outside))
            }
            XCTAssertTrue(files.fileExists(atPath: outside.path), "another package must remain intact")
        }
        XCTAssertEqual(try other.read(externalURL).name, "External")
        XCTAssertEqual(try nested.read(nestedURL).name, "Nested")
        XCTAssertEqual(try own.read(ownURL).name, "Inside")

        try own.delete(ownURL)
        XCTAssertFalse(files.fileExists(atPath: ownURL.path))
        XCTAssertTrue(files.fileExists(atPath: externalURL.path))
        XCTAssertTrue(files.fileExists(atPath: nestedURL.path))
    }
}
