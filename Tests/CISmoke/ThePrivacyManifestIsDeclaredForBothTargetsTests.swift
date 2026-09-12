// ThePrivacyManifestIsDeclaredForBothTargetsTests.swift
// Echoel — #1222 (audit 2026-09-10 `ship-path-4`). The App Store privacy manifest ships only
// through two hand-placed `sources:` entries in `project.yml`, and nothing guarded them.
//
// THE RISK. `project.yml` records (above the app target's entry) that the manifest "had never
// shipped": the earlier `resources:` block was silently dropped by XcodeGen, so the bundle went
// out without `PrivacyInfo.xcprivacy` for an unknown period. Since iOS 17.5 Apple rejects at
// UPLOAD (ITMS-91053, "Missing API declaration") when required-reason APIs are present and the
// manifest is absent — and they are present: `ProcessInfo.systemUptime` on the rPPG frame
// path, `UserDefaults` in the app and the widget, `.creationDateKey` in the video library.
// `Xcode Compile Check` builds `Sources/` only and never inspects bundle contents; a well-meant
// `project.yml` tidy would remove the manifest with every gate green, and the founder would
// learn at upload time.
//
// WHAT THIS PINS. (4, #1234b) PARSE: Foundation's plist reader accepts the file and the parsed
// category set equals the three below — a substring scan cannot see a comment that breaks the
// XML (`--` inside `<!-- -->`), and #1234 shipped exactly that for one local commit.
// (1) DECLARATION: exactly two `- path: Resources/PrivacyInfo.xcprivacy`
// entries (app + widget), each followed within three lines by `type: file` and `buildPhase:
// resources` — the shape the file itself documents as the only one XcodeGen honours. (2)
// CONTENT: the manifest exists and declares the three required-reason categories with
// measured callers, each with a reasons array. (3) LOAD-BEARING: the widget IS embedded, so
// the second entry is not decorative.
//
// ⛔ HONEST LIMIT: this reads `project.yml` and the manifest as TEXT. It proves what XcodeGen
// will be TOLD, not what the archive contains — the same limit `DeviceFamilyIsPhoneOnlyTests`
// states. The bundle-level check would be an `ls` of the `.app` in `testflight.yml`, which is
// founder-gated (`.github/workflows/**`).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`ca263cc`) and this tree: all three
// claims GREEN on both. PREVENTIVE — neither file changed in this commit; the guard exists so
// the 2026-07-21 failure cannot recur silently.

import Foundation
import XCTest

final class ThePrivacyManifestIsDeclaredForBothTargetsTests: XCTestCase {

    private static let manifestEntry = "- path: Resources/PrivacyInfo.xcprivacy"
    /// The categories with a measured caller in `Sources/`: `systemUptime` (rPPG frame path)
    /// and `UserDefaults` (app + widget).
    ///
    /// ⛔ `NSPrivacyAccessedAPICategoryFileTimestamp` stood here until #1307 with the note
    /// "`.creationDateKey` (video library)". That caller was deleted with video capture
    /// (#1304, founder 2026-09-12), so the list was asserting a measurement that had expired
    /// four commits earlier — and claim 4's SET EQUALITY made it load-bearing: the manifest
    /// could not be corrected without this line moving in the same commit, which is exactly
    /// the coupling it exists for. Both moved in #1307.
    ///
    /// ⚠️ RE-MEASURE, DO NOT TRUST THIS COMMENT. The sweep that decides an entry is over the
    /// SYMBOLS Apple lists for the category, comments stripped — not over a plausible file
    /// name. For FileTimestamp that is `creationDate(Key)`, `contentModificationDateKey`,
    /// `NSURLCreationDateKey`, `NSURLContentModificationDateKey`, `modificationDate`,
    /// `fileModificationDate`, `NSFileCreationDate`, `NSFileModificationDate`, `getattrlist*`
    /// and `stat`/`fstat`/`lstat`. `FileManager.attributesOfItem(atPath:)` is NOT on that list,
    /// so the one survivor in `CrashSafeStatePersistence` (which reads `[.size]`) does not
    /// re-earn the category.
    private static let requiredCategories = [
        "NSPrivacyAccessedAPICategorySystemBootTime",
        "NSPrivacyAccessedAPICategoryUserDefaults",
    ]

    /// Claim 1 — two declarations, each in the one shape XcodeGen honours.
    func testTheManifestIsDeclaredTwiceAsAResourceFile() throws {
        let lines = try text("project.yml").components(separatedBy: "\n")
        let entries = lines.indices.filter {
            lines[$0].trimmingCharacters(in: .whitespaces) == Self.manifestEntry
        }
        XCTAssertEqual(entries.count, 2, """
            project.yml declares `Resources/PrivacyInfo.xcprivacy` \(entries.count) time(s); the \
            app AND the embedded widget each need one `sources:` entry. A missing manifest is an \
            ITMS-91053 rejection at UPLOAD, which no compile gate sees (#1222).
            """)
        for at in entries {
            let window = lines[at ..< min(at + 4, lines.count)].map { $0.trimmingCharacters(in: .whitespaces) }
            XCTAssertTrue(window.contains("type: file"), """
                the manifest entry at project.yml line \(at + 1) is not `type: file` — XcodeGen \
                would treat it as a source, not a bundled resource (#1222).
                """)
            XCTAssertTrue(window.contains("buildPhase: resources"), """
                the manifest entry at project.yml line \(at + 1) has no `buildPhase: resources` \
                within three lines — the file would not be copied into the bundle (#1222).
                """)
        }
    }

    /// Claim 2 — the manifest exists and declares every category that has a measured caller.
    func testTheManifestDeclaresTheCategoriesWithCallers() throws {
        let manifest = try text("Resources/PrivacyInfo.xcprivacy")
        for category in Self.requiredCategories {
            guard let at = manifest.range(of: "<string>\(category)</string>") else {
                return XCTFail("`Resources/PrivacyInfo.xcprivacy` no longer declares \(category), which has a caller in Sources/ (#1222)")
            }
            let after = manifest[at.upperBound...].prefix(400)
            XCTAssertTrue(after.contains("NSPrivacyAccessedAPITypeReasons"), """
                \(category) is declared without a reasons array — Apple rejects a category \
                without a reason code just as it rejects a missing one (#1222).
                """)
        }
    }

    /// Claim 4 (#1234b) — the manifest PARSES as a property list. Added after #1234 committed
    /// an XML comment containing `--` (the grep separator `-- Sources`), which XML forbids inside
    /// a comment: `plistlib` refused the file at line 85 while claims 1–3, being substring scans,
    /// stayed green. Apple's uploader parses; a manifest that does not parse ships no
    /// declarations at all. The nearest thing to the uploader that runs here is Foundation's
    /// own plist reader.
    func testTheManifestParsesAsAPropertyList() throws {
        let manifest = try text("Resources/PrivacyInfo.xcprivacy")
        let data = Data(manifest.utf8)
        let parsed = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let root = parsed as? [String: Any],
              let types = root["NSPrivacyAccessedAPITypes"] as? [[String: Any]] else {
            return XCTFail("`Resources/PrivacyInfo.xcprivacy` parses, but not into a dictionary with an `NSPrivacyAccessedAPITypes` array (#1234b)")
        }
        let declared = Set(types.compactMap { $0["NSPrivacyAccessedAPIType"] as? String })
        XCTAssertEqual(declared, Set(Self.requiredCategories), """
            the PARSED category set differs from the three with measured callers — a text scan \
            (claim 2) can see a category that a malformed comment hides from the parser (#1234b).
            """)
    }

    /// Claim 3 — the widget is embedded, so the second declaration is load-bearing.
    func testTheWidgetIsEmbeddedSoBothEntriesMatter() throws {
        let spec = try text("project.yml")
        XCTAssertTrue(spec.contains("- target: EchoelmusicWidgets"), """
            the widget is no longer embedded in the app — then claim 1's count of two is the \
            stale half: re-measure before changing either number (#1222).
            """)
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not present at \(url.path) — this test reads repo files as text, so it SKIPS rather than reporting a green it did not earn")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
