// ThePrivacyPolicyHasAnInAppDoorTests.swift
// Echoel — #1209. A HealthKit app must link its privacy policy inside the app.
//
// THE GAP. App Review Guideline 5.1.1(i) wants the privacy-policy link in App Store Connect AND
// "within the app in an easily accessible manner". The metadata half has been done for months
// (`fastlane/metadata/*/privacy_url.txt` → https://echoelmusic.com/privacy). The in-app half was
// absent: `git grep -c 'echoelmusic.com/privacy' -- Sources` → 0 on the parent tree, and the only
// web door in the app was the brand tap to the homepage (`WorkspaceView.websiteURL`). For an app
// that reads AND writes HealthKit (heartRate, heartRateVariabilitySDNN, respiratoryRate) that is
// a common first-submission rejection, and the cheapest one on the 2026-09-10 audit to close.
//
// WHAT THIS PINS. (1) The link exists in code, in a view that is reachable — `LearnView` is
// presented from `EchoelStudioView`'s `showLearn` sheet, so claim 2 pins that construction site
// rather than trusting the file. (2) The in-app URL and the store-metadata URL are the SAME
// string, so the two halves of the guideline can never drift to two documents.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`57dd7b7`) and this tree: claim 1 is
// RED on the parent (no such literal under `Sources/`), GREEN here; claims 2 and 3 are green on
// both trees — they are the reachability and the same-document COUNTERWEIGHTS, and they are what
// stops a future "tidy" from moving the link into a doorless view or onto a stale URL.
//
// ⚠️ THE LIMIT. A source scan cannot tap the link. That the sheet opens and the row is visible
// on a real phone is a device look; the reachability chain is pinned by text, not by a tap.

import Foundation
import XCTest

final class ThePrivacyPolicyHasAnInAppDoorTests: XCTestCase {

    private static let learnView = "Sources/Echoelmusic/Studio/LearnView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let storeURL = "fastlane/metadata/en-US/privacy_url.txt"
    private static let policy = "https://echoelmusic.com/privacy"

    // MARK: - claim 1 — the in-app link exists, in code

    func testTheLibraryLinksThePrivacyPolicy() throws {
        let code = try source(Self.learnView)
        XCTAssertTrue(code.contains("\"\(Self.policy)\""), """
            `LearnView.swift` no longer carries the privacy-policy URL in CODE. Guideline \
            5.1.1(i) needs the link inside the app for a HealthKit app; the store metadata \
            alone is the half that was already done. Put it back (a static `Link`, no hot state).
            """)
        XCTAssertTrue(code.contains("Link("), "the URL is present but nothing renders it as a `Link`")
    }

    // MARK: - claim 2 (COUNTERWEIGHT) — the view that carries it is reachable

    func testTheLibraryIsStillPresentedFromTheStudio() throws {
        let code = try source(Self.studio)
        XCTAssertTrue(code.contains("LearnView()"), """
            `EchoelStudioView` no longer constructs `LearnView()`. The privacy link lives in \
            that view, so with this door gone the link is doorless — move it to a reachable \
            surface in the same commit (`python3 scripts/doctor.py --section C` lists slots).
            """)
    }

    // MARK: - claim 3 (COUNTERWEIGHT) — one document, not two

    func testTheInAppURLIsTheStoreMetadataURL() throws {
        let store = try text(Self.storeURL).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(store, Self.policy, """
            `\(Self.storeURL)` names a different page than the in-app link. Both halves of \
            5.1.1(i) must point at ONE policy document; change both or neither.
            """)
    }

    // MARK: - source access (#453 stripper; a FAILURE when a named file moved, #454)

    private struct AnchorMissing: Error { let reason: String }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor, do not skip")
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func source(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try text(relativePath))
    }
}
