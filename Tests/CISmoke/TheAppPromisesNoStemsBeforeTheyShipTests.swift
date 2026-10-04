// TheAppPromisesNoStemsBeforeTheyShipTests.swift
//
// SOURCE-TEXT SCAN. It proves where words sit, not what the app does.
//
// The music-theory primer told every reader that Echoelmusic "locks the music to one key …
// so stems drop into your DAW already in tune". There is no stem export: the app writes the
// whole piece as ONE stereo WAV (`LoopExporter.exportPiece`) and the melody as ONE MIDI file.
// The website already says so ("no stem export", "stem export ROADMAP"), so the app was the
// one surface that sold it. Found by the Spatial Phase R completeness critic, 2026-10-04.
//
// The immersive-master work (ADR-007/008, S-A3/S-A4) WILL produce stems. The day it ships,
// this guard is meant to turn red — delete claim 1 in the same commit that adds the export,
// and say so in the commit body. It does not forbid the word in comments, identifiers
// (`SessionNaming.stem`, a file-name stem) or the website; only in text a user can read.

import XCTest

final class TheAppPromisesNoStemsBeforeTheyShipTests: XCTestCase {

    // Computed, not stored: an `NSRegularExpression` is not `Sendable`, and a stored static of a
    // non-Sendable type is a hard error in Swift 6 (CLAUDE.md, #1402).
    private static var word: NSRegularExpression? {
        try? NSRegularExpression(pattern: #"\bstems?\b"#, options: [.caseInsensitive])
    }
    private static var tripleQuoted: NSRegularExpression? {
        try? NSRegularExpression(pattern: #"\"\"\"[\s\S]*?\"\"\""#, options: [])
    }
    private static var singleQuoted: NSRegularExpression? {
        try? NSRegularExpression(pattern: #""(?:[^"\\\n]|\\.)*""#, options: [])
    }
    /// `\(…)` inside a literal is CODE, not text — `"\(stem).wav"` names a variable, not a promise.
    private static var interpolation: NSRegularExpression? {
        try? NSRegularExpression(pattern: #"\\\([^)]*\)"#, options: [])
    }

    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func mentionsStems(_ text: String) -> Bool {
        guard let word = Self.word, let interpolation = Self.interpolation else { return false }
        let prose = interpolation.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        return word.firstMatch(in: prose, range: NSRange(prose.startIndex..., in: prose)) != nil
    }

    /// Every string literal the compiler sees in `text`, comments already blanked.
    private func literals(in code: String) -> [String] {
        guard let triple = Self.tripleQuoted, let single = Self.singleQuoted else { return [] }
        var found: [String] = []
        var rest = code
        let ns = NSRange(code.startIndex..., in: code)
        for match in triple.matches(in: code, range: ns).reversed() {
            guard let r = Range(match.range, in: rest) else { continue }
            found.append(String(rest[r]))
            rest.replaceSubrange(r, with: "")
        }
        let nsRest = NSRange(rest.startIndex..., in: rest)
        for match in single.matches(in: rest, range: nsRest) {
            if let r = Range(match.range, in: rest) { found.append(String(rest[r])) }
        }
        return found
    }

    private func swiftSources() throws -> [URL] {
        let sources = root.appendingPathComponent("Sources")
        guard FileManager.default.fileExists(atPath: sources.path) else {
            throw XCTSkip("Sources/ is not reachable from \(#filePath)")
        }
        let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        var files: [URL] = []
        while let url = walker?.nextObject() as? URL {
            if url.pathExtension == "swift" { files.append(url) }
        }
        return files
    }

    // MARK: - Claim 1: no user-readable text in the app promises stems

    func testNoStringInTheAppPromisesStems() throws {
        let files = try swiftSources()
        // A walker that finds nothing is a finding, not a pass.
        XCTAssertGreaterThan(files.count, 100, "the Sources walk found almost nothing — the scan is blind")
        var offenders: [String] = []
        var literalCount = 0
        for file in files {
            let code = SourceText.codeOnly(try String(contentsOf: file, encoding: .utf8))
            for literal in literals(in: code) {
                literalCount += 1
                if mentionsStems(literal) {
                    offenders.append("\(file.lastPathComponent): \(literal.prefix(120))")
                }
            }
        }
        XCTAssertGreaterThan(literalCount, 1_000, "the literal extractor matched almost nothing — the scan is blind")
        XCTAssertEqual(offenders, [], """
            A string the user can read promises stems, and the app has no stem export (one stereo \
            WAV and one MIDI file). If the stem export has just shipped, delete this claim in the \
            same commit and say so.
            """)

        let catalogURL = root.appendingPathComponent("Sources/Echoelmusic/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let keys = (json?["strings"] as? [String: Any])?.keys.map { $0 } ?? []
        XCTAssertGreaterThan(keys.count, 100, "the string catalog parsed to almost nothing — the scan is blind")
        XCTAssertEqual(keys.filter { mentionsStems($0) }, [], "a catalogued string promises stems")
    }

    // MARK: - Claim 2: the matcher can fail for its named reason

    func testTheMatcherCatchesTheSentenceItWasWrittenFor() {
        XCTAssertTrue(mentionsStems("so stems drop into your DAW already in tune."))
        XCTAssertTrue(mentionsStems("Export Stem"))
        XCTAssertFalse(mentionsStems("the operating system"), "`system` is not `stem`")
        XCTAssertFalse(mentionsStems("a stemmed glass"), "`stemmed` is not `stem`")
        XCTAssertFalse(mentionsStems(#""\(stem).wav""#), "an interpolated variable is code, not a promise")
        XCTAssertEqual(literals(in: #"let a = "one stems"; let b = 2"#), [#""one stems""#])
    }

    // MARK: - Claim 3: the replacement line names exports that exist

    func testThePrimerNamesTheExportsThatShip() throws {
        let primerURL = root.appendingPathComponent("Sources/Echoelmusic/Studio/MusicTheoryPrimer.swift")
        let exporterURL = root.appendingPathComponent("Sources/Echoelmusic/Audio/LoopExporter.swift")
        let studioURL = root.appendingPathComponent("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        guard FileManager.default.fileExists(atPath: primerURL.path) else {
            throw XCTSkip("MusicTheoryPrimer.swift is not reachable")
        }
        let primer = SourceText.codeOnly(try String(contentsOf: primerURL, encoding: .utf8))
        XCTAssertTrue(primer.contains("so your WAV and MIDI exports drop into your DAW already in tune."),
                      "the key entry no longer names the two exports the app actually writes")
        let exporter = SourceText.codeOnly(try String(contentsOf: exporterURL, encoding: .utf8))
        XCTAssertTrue(exporter.contains("\" (piece).wav\""), "the piece WAV export the primer names is gone")
        let studio = SourceText.codeOnly(try String(contentsOf: studioURL, encoding: .utf8))
        XCTAssertTrue(studio.contains(".mid\")"), "the MIDI file export the primer names is gone")
    }
}
