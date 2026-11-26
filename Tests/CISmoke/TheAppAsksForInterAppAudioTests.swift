// TheAppAsksForInterAppAudioTests.swift
// Echoel — F44 (founder 2026-11-26: „F44 ja“, then „F44 mergen“). Blocking bundle.
// SOURCE-TEXT SCAN (`Tests/CISmoke/CLAUDE.md` §1): it proves what the entitlement files SAY,
// never that iOS lists another maker's Audio Unit to the host. Only a device run shows that.
//
// WHY. No Studio build has listed a third-party AUv3 on the founder's iPhone, although
// PluginHost asks both ways Apple offers. ANNAHME: iOS lists them to a host only when the app
// carries the Inter-App Audio capability. The founder ticked it on com.echoelmusic.app, and the
// signing probe of 2026-11-26 (run 45821506669, `success`) showed both profiles grant it.
//
// WHAT THIS PINS. (1) The app's entitlements parse as a plist and carry `inter-app-audio` = true.
// (2) The plugin extension (EchoelPlugins) does NOT ask for it: it hosts nothing, and an
// entitlement its App ID lacks is the -3000 launch failure the AUv3 history already paid for.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) in Python against `86f58a7` and this tree: claim 1 RED on
// the parent (key absent), GREEN here; claim 2 GREEN on both. Two assertions plus two
// re-anchor XCTFails (the `grep -c` of both words also counts this header line: 5). One mutant
// (the key added to the plugin's plist) turns claim 2 RED. 1 regression, 1 counterweight.

import Foundation
import XCTest

final class TheAppAsksForInterAppAudioTests: XCTestCase {

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("EchoelStudio").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func entitlements(_ relative: String) throws -> [String: Any] {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let data = try? Data(contentsOf: url) else {
            XCTFail("\(relative) is missing — re-anchor this guard to where the file moved.")
            return [:]
        }
        let parsed = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dict = parsed as? [String: Any] else {
            XCTFail("\(relative) is not a dictionary plist.")
            return [:]
        }
        return dict
    }

    /// Claim 1 — the app asks for Inter-App Audio.
    func testTheAppEntitlementsCarryInterAppAudio() throws {
        let ents = try entitlements("EchoelStudio/Support/App/EchoelStudio.entitlements")
        XCTAssertEqual(ents["inter-app-audio"] as? Bool, true, """
        EchoelStudio.entitlements no longer carries `inter-app-audio` = true. F44: without it, \
        iOS is assumed not to list other makers' Audio Units to the host (ANNAHME until a device \
        run). If a device run proved the key unnecessary, remove this guard in the same commit \
        and say so in the entitlements comment.
        """)
    }

    /// Claim 2 — the plugin extension does not ask for it.
    func testThePluginExtensionDoesNotAskForInterAppAudio() throws {
        let ents = try entitlements("EchoelStudio/Support/Plugins/EchoelPlugins.entitlements")
        XCTAssertNil(ents["inter-app-audio"], """
        EchoelPlugins.entitlements asks for `inter-app-audio`. The extension hosts nothing, and \
        an entitlement the App ID com.echoelmusic.app.auv3 does not carry is the -3000 \
        invalidComponentID launch failure. Keep the capability on the app only.
        """)
    }
}
