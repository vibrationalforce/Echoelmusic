// TheStreamKeyLivesInTheKeychainTests.swift
// Echoel — Broadcast S1 (founder release 2026-10-03): the stream key moves out of UserDefaults.
//
// WHAT IT GUARDS. A stream key is a publishing credential. It sat in `UserDefaults` under
// `broadcast.streamKey` — a plaintext plist in the container and in every backup. It now lives
// in a Keychain generic-password item (`StreamKeyStore.swift`) with
// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, and `BroadcastPublisher.init` moves a copy an
// older build left behind exactly once.
//
// §1 LIMITS, per claim:
// · Claims 1–5 are END-TO-END BEHAVIOUR: they drive `StreamKeyMigration` and the publisher's
//   injection seam with an in-memory store and a throwaway `UserDefaults` suite. They prove the
//   migration RULE, not the Keychain.
// · Claim 6 is a SOURCE-TEXT SCAN: the accessibility class, the absence of logging, and that no
//   code path writes the key to UserDefaults any more.
// · DEVICE PROBE, open: that the real Keychain round-trips on an iPhone, and that a phone
//   updated from a build with a saved key keeps it. Not covered here — the simulator test host
//   is not the device, and a real-Keychain call here could fail for entitlement reasons that
//   say nothing about the app.
//
// §3 HONEST GRADING against the parent (b7984357d): this file names `StreamKeyMigration`,
// `StreamSecretStore` and `BroadcastPublisher.init(keyStore:defaults:)`, none of which exist
// there — it DOES NOT COMPILE against the parent, so no assertion has a verdict there. Claims
// 1–5 are FORWARD guards (they drive symbols this commit creates). Claim 6 has two REGRESSION
// halves on the parent for their named reason — the publisher's `didSet` wrote
// `UserDefaults.standard.set(streamKey` and no Keychain accessibility constant existed — and a
// COUNTERWEIGHT (the publisher still exposes `streamKey` to the view's secure field).
// Stripper `SourceText.codeOnly`: TRAGEND for claim 6's no-log and no-defaults scans (the
// file headers say "never logged" and quote `broadcast.streamKey` in prose).

import Foundation
import XCTest
@testable import Echoelmusic

/// A store the test controls, including a failing write.
private final class MemorySecretStore: StreamSecretStore {
    var value: String?
    var failWrites = false
    private(set) var writes = 0
    init(_ value: String? = nil) { self.value = value }
    func read() -> String? { value }
    @discardableResult func write(_ secret: String) -> Bool {
        writes += 1
        guard !failWrites else { return false }
        value = secret.isEmpty ? nil : secret
        return true
    }
    @discardableResult func delete() -> Bool { value = nil; return true }
}

@MainActor
final class TheStreamKeyLivesInTheKeychainTests: XCTestCase {

    private static let legacy = StreamKeyMigration.legacyDefaultsKey

    /// A throwaway defaults suite per test, removed when the test ends.
    private func scratchDefaults() throws -> UserDefaults {
        let name = "echoel.test.streamkey.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: name), "ANCHOR MISSING: a throwaway UserDefaults suite")
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return suite
    }

    // MARK: - Claim 1 — a key an older build left in UserDefaults moves, and the old copy goes

    func testALegacyKeyMovesIntoTheStoreAndLeavesDefaults() throws {
        let defaults = try scratchDefaults()
        defaults.set("live_abc123", forKey: Self.legacy)
        let store = MemorySecretStore()
        let key = StreamKeyMigration.loadMigrating(defaults: defaults, store: store)
        XCTAssertEqual(key, "live_abc123", "the user keeps the key they saved")
        XCTAssertEqual(store.value, "live_abc123", "the key now lives in the secret store")
        XCTAssertNil(defaults.string(forKey: Self.legacy), "the plaintext copy is deleted after the move")
    }

    // MARK: - Claim 2 — a key already in the Keychain wins; the stale plaintext copy is deleted

    func testTheStoreWinsOverAStaleLegacyCopy() throws {
        let defaults = try scratchDefaults()
        defaults.set("old_key", forKey: Self.legacy)
        let store = MemorySecretStore("keychain_key")
        let key = StreamKeyMigration.loadMigrating(defaults: defaults, store: store)
        XCTAssertEqual(key, "keychain_key")
        XCTAssertEqual(store.writes, 0, "the Keychain copy is not overwritten by the stale one")
        XCTAssertNil(defaults.string(forKey: Self.legacy))
    }

    // MARK: - Claim 3 — a failed Keychain write must not lose the user's key

    func testAFailedWriteKeepsTheLegacyCopyForTheNextLaunch() throws {
        let defaults = try scratchDefaults()
        defaults.set("live_abc123", forKey: Self.legacy)
        let store = MemorySecretStore()
        store.failWrites = true
        let key = StreamKeyMigration.loadMigrating(defaults: defaults, store: store)
        XCTAssertEqual(key, "live_abc123", "the key is still usable this launch")
        XCTAssertEqual(defaults.string(forKey: Self.legacy), "live_abc123",
                       "the only copy is not deleted when the move failed — the next launch retries")
    }

    // MARK: - Claim 4 — nothing to migrate: the store answers, and an empty legacy copy is removed

    func testWithoutALegacyCopyTheStoreAnswers() throws {
        let defaults = try scratchDefaults()
        XCTAssertEqual(StreamKeyMigration.loadMigrating(defaults: defaults, store: MemorySecretStore("kc")), "kc")
        XCTAssertEqual(StreamKeyMigration.loadMigrating(defaults: defaults, store: MemorySecretStore()), "")
        defaults.set("", forKey: Self.legacy)
        let store = MemorySecretStore()
        XCTAssertEqual(StreamKeyMigration.loadMigrating(defaults: defaults, store: store), "")
        XCTAssertEqual(store.writes, 0, "an empty legacy value is not written into the Keychain")
        XCTAssertNil(defaults.string(forKey: Self.legacy))
    }

    // MARK: - Claim 5 — the publisher migrates at init, edits go to the store, never to defaults

    func testThePublisherMigratesAndWritesEditsToTheStore() throws {
        let defaults = try scratchDefaults()
        defaults.set("live_abc123", forKey: Self.legacy)
        let store = MemorySecretStore()
        let publisher = BroadcastPublisher(keyStore: store, defaults: defaults)
        XCTAssertEqual(publisher.streamKey, "live_abc123")
        XCTAssertNil(defaults.string(forKey: Self.legacy))

        publisher.streamKey = "live_new456"
        XCTAssertEqual(store.value, "live_new456", "an edit in the secure field reaches the store")
        XCTAssertNil(defaults.string(forKey: Self.legacy), "and never the plaintext defaults")

        // The key is never echoed into the status line the view prints.
        publisher.url = ""
        publisher.start()
        XCTAssertFalse(publisher.statusMessage.contains("live_new456"))
        publisher.url = "rtmp://example.invalid/live"
        publisher.start()
        XCTAssertFalse(publisher.statusMessage.contains("live_new456"))
        publisher.url = ""
    }

    // MARK: - Claim 6 — SOURCE: device-only accessibility, no logging, no defaults write left

    func testTheItemIsDeviceOnlyAndTheKeyIsNeverLogged() throws {
        let store = try source("Sources/Echoelmusic/Stream/StreamKeyStore.swift")
        XCTAssertEqual(occurrences(of: "kSecAttrAccessibleWhenUnlockedThisDeviceOnly", in: store), 2,
                       "both the update and the add set the device-only, unlocked-only class")
        XCTAssertFalse(store.contains("kSecAttrAccessibleAfterFirstUnlock")
                       || store.contains("kSecAttrAccessibleAlways"),
                       "no weaker accessibility class anywhere in the store")
        for needle in ["os_log", "log.log(", "Logger(", "print(", "NSLog("] {
            XCTAssertFalse(store.contains(needle), "the secret store must not log (`\(needle)`)")
        }

        let publisher = try source("Sources/Echoelmusic/Stream/BroadcastPublisher.swift")
        XCTAssertFalse(publisher.contains("UserDefaults.standard.set(streamKey"),
                       "the stream key is no longer written to UserDefaults")
        XCTAssertTrue(publisher.contains("public var streamKey: String { didSet { keyStore.write(streamKey) } }"),
                      "edits are written to the secret store")
        XCTAssertFalse(publisher.contains("\\(streamKey"), "the key is never interpolated into any string")

        // The legacy defaults key is spelled exactly once in code, in the migration.
        let sources = try repoRoot().appendingPathComponent("Sources")
        var spellings = 0
        let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            spellings += occurrences(of: "\"broadcast.streamKey\"", in: text)
        }
        XCTAssertEqual(spellings, 1, "one spelling of the legacy key, in `StreamKeyMigration` (#416)")
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

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
}
