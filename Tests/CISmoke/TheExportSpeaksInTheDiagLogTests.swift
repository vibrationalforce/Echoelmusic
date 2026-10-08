// TheExportSpeaksInTheDiagLogTests.swift
// Echoel — GMMW SH-5 (founder 2026-10-08, "vermeide … abstürze"). The 2613/2618 device logs
// ended at `transport play` and said nothing after it, although an export was running: the
// take, the recorder's close and the WAV writer spoke only `os_log`, which the exported
// `echoel_diag.log` does not carry. Since this slice every export walks two ladders in that
// file, each rung BEFORE its call (the #859 law — silence after a rung is the call it stands
// before):
// · `take 1/2` opens the recording (or copies the ring), `take 2/2` closes it, and an
//   unnumbered `take OK` / `SKIPPED` / `FAILED` / `REFUSED` says how it ended. Entry points:
//   `LoopExporter.exportWav`, `.exportRecentLoop`, `.exportPiece`, and the floating window's
//   live WAV button (`FloatingVisualWindow.toggleWavRecording`).
// · `export 1/4` read the take, `2/4` measure, `3/4` render, `4/4` finish the file, then
//   `export OK` or `export FAILED:` — in `SingleExport.export`, which every caller passes
//   through, so every entry point walks from 1/4 by construction.
//
// ⚠️ THE LIMITS FIRST. These are SOURCE-TEXT SCANS: no AVAudioEngine records in a test host,
// and whether the next device log names its step is the founder's next export on a phone
// (DEVICE PROBE, open). The log READING was driven separately, not here: six synthetic logs
// through `scripts/diag-ladder.py` (healthy, death in the close, in the render, in the finish,
// a cancel, a failure) each printed the verdict their shape asks for — and `take`/`export`
// carry `OK`, so a log that stops after the last rung reads as a death INSIDE that call (#973).
//
// ⚠️ HONEST GRADING (#433/#486). Against the parent every rung needle is absent: claims 1–4
// are red there by ONE absence (the ladders did not exist), not by N regressions. Claim 5 is
// FORWARD on its rung half and a COUNTERWEIGHT on its word half (no new word outside the
// reader's vocabulary, no crash marker — green on both trees). The exit walk in claims 1 and 3
// is the content: a new silent `return` between the first rung and the take's outcome goes
// red, which is the class #906/#907 kept finding by hand. Mutants driven in a Python
// transcription of these scans, each red for its named reason: a rung after its call, a
// silent exit, a missing `take OK`, `4/4` after `markAsFinished`, an upper-case word the
// reader does not know.
// `SourceText.codeOnly` is PROPHYLACTIC (0 verdict flips raw vs stripped, both trees).
//
// Guard of `Sources/Echoelmusic/Audio/LoopExporter.swift`, `Audio/SingleExport.swift` and
// `Studio/FloatingVisualWindow.swift`.

import XCTest
@testable import Echoelmusic

private struct ExportLadderAnchorMissing: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

final class TheExportSpeaksInTheDiagLogTests: XCTestCase {

    private static let exporter = "Sources/Echoelmusic/Audio/LoopExporter.swift"
    private static let writer = "Sources/Echoelmusic/Audio/SingleExport.swift"
    private static let window = "Sources/Echoelmusic/Studio/FloatingVisualWindow.swift"
    private static let sink = "EchoelCrashLog.breadcrumb("

    // MARK: - 1. Every take entry point opens with its rung, and says how the take ended

    func testEveryTakeEntryPointWalksFromTheFirstRung() throws {
        let code = try source(Self.exporter)
        let entries: [(signature: String, opens: String)] = [
            ("public func exportWav(", "engine.retroCapture.startRecording("),
            ("public func exportRecentLoop(", "engine.retroCapture.captureRecent("),
            ("public func exportPiece(", "engine.retroCapture.startRecording("),
        ]
        for entry in entries {
            let body = try declarationBody(of: entry.signature, in: code, file: Self.exporter)
            let rung = try XCTUnwrap(body.range(of: "\"take 1/2: "), "\(entry.signature) has no `take 1/2` rung")
            let open = try XCTUnwrap(body.range(of: entry.opens), "\(entry.signature) no longer calls \(entry.opens)")
            XCTAssertLessThan(rung.lowerBound, open.lowerBound,
                              "\(entry.signature): the rung must stand BEFORE the call it names")
            let outcome = try XCTUnwrap(body.range(of: "\"take OK", options: .backwards),
                                        "\(entry.signature) never says the take went well")
            assertEveryReturnSpeaks(in: body[..<outcome.lowerBound], label: entry.signature)
        }
    }

    // MARK: - 2. The close has its own rung where there is a recording to close

    func testTheCloseStandsBehindItsOwnRung() throws {
        let code = try source(Self.exporter)
        for signature in ["public func exportWav(", "public func exportPiece("] {
            let body = try declarationBody(of: signature, in: code, file: Self.exporter)
            let rung = try XCTUnwrap(body.range(of: "\"take 2/2: "), "\(signature) has no `take 2/2` rung")
            let close = try XCTUnwrap(body.range(of: "await finishRecording(engine)"),
                                      "\(signature) no longer closes through finishRecording")
            XCTAssertLessThan(rung.lowerBound, close.lowerBound, """
                \(signature): `take 2/2` must stand before the close — the recorder's final drain \
                is where the 2613 family lived, and a death there must leave this rung last
                """)
            let ok = try XCTUnwrap(body.range(of: "\"take OK"), "\(signature) never says the take closed")
            XCTAssertLessThan(close.lowerBound, ok.lowerBound, "\(signature): `take OK` comes AFTER the close")
        }
    }

    // MARK: - 3. The live WAV button walks the same ladder

    func testTheLiveRecordingWalksTheSameLadder() throws {
        let code = try source(Self.window)
        let body = try declarationBody(of: "private func toggleWavRecording()", in: code, file: Self.window)
        let open = try XCTUnwrap(body.range(of: "audioEngine.retroCapture.startRecording("), "the live take opens")
        let openRung = try XCTUnwrap(body.range(of: "\"take 1/2: live"), "the live take has no `take 1/2`")
        XCTAssertLessThan(openRung.lowerBound, open.lowerBound, "`take 1/2` before the recording opens")
        let close = try XCTUnwrap(body.range(of: "audioEngine.retroCapture.stopRecording"), "the live take closes")
        let closeRung = try XCTUnwrap(body.range(of: "\"take 2/2: live"), "the live take has no `take 2/2`")
        XCTAssertLessThan(closeRung.lowerBound, close.lowerBound, "`take 2/2` before the recording closes")
        let ok = try XCTUnwrap(body.range(of: "\"take OK — live"), "the live take never says it closed")
        XCTAssertLessThan(close.lowerBound, ok.lowerBound, "`take OK` is said in the close's completion")
        assertEveryReturnSpeaks(in: body[...], label: "toggleWavRecording")
    }

    // MARK: - 4. The writer walks 1/4…4/4 and always says how it went

    func testTheWriterWalksItsFourRungsAndSaysHowItWent() throws {
        let code = try source(Self.writer)
        let export = try declarationBody(of: "func export(sourceURL: URL) async {", in: code, file: Self.writer)
        let steps: [(rung: String, call: String)] = [
            ("\"export 1/4: ", "try makeOutputURL("),
            ("\"export 2/4: ", "try await measureExportLevels("),
            ("\"export 3/4: ", "try await renderWithGain("),
        ]
        for step in steps {
            let rung = try XCTUnwrap(export.range(of: step.rung), "the writer has no \(step.rung) rung")
            let call = try XCTUnwrap(export.range(of: step.call), "the writer no longer calls \(step.call)")
            XCTAssertLessThan(rung.lowerBound, call.lowerBound, "\(step.rung) must stand before \(step.call)")
        }
        let done = try XCTUnwrap(export.range(of: "exportState = .done("), "the writer's success write")
        let ok = try XCTUnwrap(export.range(of: "\"export OK"), "the writer never says it succeeded")
        XCTAssertLessThan(done.lowerBound, ok.lowerBound, "`export OK` is said after the file is done")
        let caught = try XCTUnwrap(export.range(of: "} catch {"), "the writer's catch")
        XCTAssertTrue(export[caught.upperBound...].contains("\"export FAILED: "),
                      "a failed export names its error in the diag log")
        assertEveryReturnSpeaks(in: export[...], label: "SingleExport.export")

        let render = try declarationBody(of: "private func renderWithGain(", in: code, file: Self.writer)
        let finishRung = try XCTUnwrap(render.range(of: "\"export 4/4: "), "the render has no `export 4/4` rung")
        let finish = try XCTUnwrap(render.range(of: "writerInputRef.markAsFinished()"), "the render's finish")
        XCTAssertLessThan(finishRung.lowerBound, finish.lowerBound, "`export 4/4` stands before the file is finished")
    }

    // MARK: - 5. Every word is one the reader knows, and none reads as a crash

    func testEveryLadderWordIsOneTheReaderKnows() throws {
        let known = try terminalWordsOfTheReader()
        let literals = try [Self.exporter, Self.writer, Self.window].flatMap { try ladderLiterals(in: source($0)) }
        XCTAssertGreaterThanOrEqual(literals.count, 4, "precondition: the ladder literals were found")
        for literal in literals {
            if let word = outcomeWord(of: literal) {
                XCTAssertTrue(known.contains(word), """
                    `\(literal)` carries `\(word)` after a ladder prefix — `scripts/diag-ladder.py` \
                    reads only its TERMINAL_WORDS \(known.sorted()) there, so this line would read as a \
                    death or flag the census. Spell it lower case or teach the reader the word.
                    """)
            }
            XCTAssertFalse(EchoelCrashLog.looksLikeUnseenCrash(literal),
                           "`\(literal)` would make the next launch offer a crash report")
        }
    }

    // MARK: - Helpers

    /// Every `return` in `text` must have a breadcrumb between it and the nearest brace before
    /// it — the statements of its own block that run just before it leaves.
    private func assertEveryReturnSpeaks(in text: Substring, label: String) {
        var cursor = text.startIndex
        var seen = 0
        while let hit = text.range(of: "return", range: cursor..<text.endIndex) {
            cursor = hit.upperBound
            guard isWord(hit, in: text) else { continue }
            seen += 1
            let before = text[text.startIndex..<hit.lowerBound]
            let opened = before.lastIndex(where: { $0 == "{" || $0 == "}" }) ?? text.startIndex
            XCTAssertTrue(text[opened..<hit.lowerBound].contains(Self.sink),
                          "\(label): exit \(seen) leaves without a line in the diag log")
        }
        XCTAssertGreaterThan(seen, 0, "precondition: \(label) has exits to check")
    }

    private func isWord(_ range: Range<String.Index>, in text: Substring) -> Bool {
        func identifier(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }
        if range.lowerBound > text.startIndex, identifier(text[text.index(before: range.lowerBound)]) { return false }
        if range.upperBound < text.endIndex, identifier(text[range.upperBound]) { return false }
        return true
    }

    /// The string literals that start with a ladder prefix of this slice (up to the next
    /// quote — an interpolation with its own quotes is cut there, which only shortens the tail).
    private func ladderLiterals(in code: String) -> [String] {
        var out: [String] = []
        var rest = code[...]
        while true {
            let hits = ["\"take ", "\"export "].compactMap { rest.range(of: $0) }
            guard let start = hits.min(by: { $0.lowerBound < $1.lowerBound }) else { break }
            let afterQuote = rest.index(after: start.lowerBound)
            guard let close = rest[afterQuote...].firstIndex(of: "\"") else { break }
            out.append(String(rest[afterQuote..<close]))
            rest = rest[rest.index(after: close)...]
        }
        return out
    }

    /// The upper-case word the reader's census looks at: right after the prefix, or right
    /// after a rung number and a space (`census_pattern` in the script). nil when there is none.
    private func outcomeWord(of literal: String) -> String? {
        let tokens = literal.split(separator: " ").dropFirst()
        guard var candidate = tokens.first else { return nil }
        let rungParts = candidate.split(separator: "/")
        if rungParts.count == 2, rungParts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) {
            guard let next = tokens.dropFirst().first else { return nil }
            candidate = next
        }
        let word = String(candidate.prefix(while: { $0.isLetter }))
        guard word.count >= 2, word.allSatisfy({ $0.isUppercase }) else { return nil }
        return word
    }

    /// The reader's own vocabulary, read from the script rather than restated (#416).
    private func terminalWordsOfTheReader() throws -> Set<String> {
        let script = try String(contentsOf: repoRoot().appendingPathComponent("scripts/diag-ladder.py"),
                                encoding: .utf8)
        guard let line = script.split(separator: "\n").first(where: { $0.hasPrefix("TERMINAL_WORDS = (") }) else {
            throw ExportLadderAnchorMissing(reason: "scripts/diag-ladder.py no longer declares TERMINAL_WORDS — re-anchor")
        }
        let words = line.split(separator: "\"").enumerated().filter { $0.offset % 2 == 1 }.map { String($0.element) }
        guard !words.isEmpty else {
            throw ExportLadderAnchorMissing(reason: "TERMINAL_WORDS parsed empty — a parser that matches nothing is a finding")
        }
        return Set(words)
    }

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw ExportLadderAnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor (#454)")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// The brace-matched body that follows `key` (#408).
    private func declarationBody(of key: String, in text: String, file: String) throws -> String {
        guard let start = text.range(of: key) else {
            throw ExportLadderAnchorMissing(reason: "\(file) no longer declares `\(key)` — re-anchor this scan")
        }
        var depth = 0
        var body = ""
        for ch in text[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { body.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { break }
            }
        }
        return body
    }
}
