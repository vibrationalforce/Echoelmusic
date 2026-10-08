// TheCrashSignatureIsOneLineTests.swift
// Echoel — GMMW SH-7. The build-2613 crash log carried two frames of the app's own binary as
// `Echoelmusic + 6083980` and `+ 3962780`, and they stayed unresolved: nothing in the log said WHICH
// binary they were offsets into, so no dSYM could be matched to them. And every crash was read by
// scrolling a backtrace, so two logs of the same crash could not be told apart from two different
// crashes without reading both in full.
//
// Now `begin()` writes an `image` line — the executable's name, its Mach-O UUID (what a dSYM is
// matched by), the linker's `__TEXT` address, where it was loaded and the slide — read from the
// binary's own mapped header, OUTSIDE the signal handler. And the next launch reads the crashed
// run's log and writes ONE line: what killed it, the queue and thread, the innermost app frames as
// offsets from the load address, the last line it wrote, its build and UUID.
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END: `imageIdentity(machHeader:)` reads the UUID and `__TEXT` address out of a synthetic
//    64-bit header, and refuses a wrong magic, a truncated buffer, a missing `LC_UUID`, a header that
//    claims more commands than it holds, and a zero-size command.
// 2. END-TO-END on the running binary: `loadedImage()` reads this binary's own header, and the
//    `image` line carries its UUID and load address. (Runs in the test host — the app binary.)
// 3. END-TO-END: a 2613-shaped log signs as one exact line, offsets derived from the absolute
//    addresses minus the load address the run's own `image` line names.
// 4. END-TO-END: the same log WITHOUT an `image` line (every build before this one) still names the
//    stripped frame (`Echoelmusic + n` counts from the image), leaves out the frame whose `+ n`
//    counts from a symbol, and names no UUID it does not have.
// 5. END-TO-END: a run without a crash marker has no signature; an exception is named by its name.
// 6. END-TO-END: the line cannot read as a marker the next launch searches for — whatever the last
//    line of the crashed run was (`Start tapped`, a scene transition, a confirm, a re-arm, `CRASH`).
// 7. SOURCE-TEXT SCAN: nothing new runs in the signal handler; `begin()` writes the image line after
//    the crash-net line and the signature after it, before the retain logic.
// DEVICE PROBE, open: that `atos -l <load> <load + offset>` against the dSYM of that UUID names the
// function, on a real crash log.
//
// HONEST GRADING (§3). The file names symbols this commit adds (`imageIdentity`, `loadedImage`,
// `imageLine`, `crashSignature`, `neutralized`, the prefixes), so it does not compile against the
// parent (`07a0129`): no assertion has a verdict there. Claims 1–6 are FORWARD guards; claim 7's
// handler half is a COUNTERWEIGHT (the parent's handler carries none of these names either). The
// behaviour was transcribed in Python against the same fixtures, and the expected lines below were
// derived from the algebra (6083980 = 0x5cd58c, 3962780 = 0x3c779c). MUTANTS, each red for its named
// reason: the timestamp test without its decimal point (a frame line reads as a breadcrumb) → 3;
// offsets taken from `+ n` even when an `image` line is present → 3 (the `main + 2048` frame);
// any frame whose `+ n` is taken without asking whether it counts from the image → 4; the
// signature not neutralised → 6. NOT a mutant catcher, said so: the zero-size case in claim 1 is
// refused either way, because the command loop is bounded by the header's own count — it pins the
// refusal, not the bound.

import Foundation
import XCTest
@testable import Echoelmusic

private struct SignatureAnchorMissing: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

final class TheCrashSignatureIsOneLineTests: XCTestCase {

    private static let file = "Sources/Echoelmusic/Core/EchoelCrashLog.swift"
    private static let fixtureUUID = "1A2B3C4D-5E6F-7081-92A3-B4C5D6E7F809"
    private static let textAddress: UInt64 = 0x1_0000_0000
    private static let loadAddress: UInt64 = 0x1_000a_8000

    // MARK: 1 — the identity is read from a Mach-O header

    func testTheImageIdentityIsReadFromAMachHeader() throws {
        let identity = try XCTUnwrap(readIdentity(of: Self.header()), "a well-formed header must be read")
        XCTAssertEqual(identity.uuid, UUID(uuidString: Self.fixtureUUID))
        XCTAssertEqual(identity.textVMAddress, Self.textAddress)

        XCTAssertNil(readIdentity(of: Self.header(magic: 0xfeed_face)), "a 32-bit magic is not this format")
        XCTAssertNil(readIdentity(of: Array(Self.header().prefix(40))), "a truncated buffer is refused, not read past")
        XCTAssertNil(readIdentity(of: Self.header(withUUID: false)), "without an LC_UUID there is nothing to match a dSYM by")
        XCTAssertNil(readIdentity(of: Self.header(claimedCommands: 5)), "a header claiming commands it does not hold is refused")
        var zeroSize = Self.header()
        zeroSize.replaceSubrange(36..<40, with: Self.littleEndian(UInt32(0)))   // the first command's size
        XCTAssertNil(readIdentity(of: zeroSize), "a zero-size command would never advance — refused, not looped on")
    }

    // MARK: 2 — the running binary reads its own header

    func testThisBinaryReadsItsOwnHeader() throws {
        let image = try XCTUnwrap(EchoelCrashLog.loadedImage(), """
            the app could not read its own Mach-O header — every `image` line would say \
            "unreadable" and no offset could be resolved
            """)
        let line = EchoelCrashLog.imageLine(executable: "Echoelmusic", image: image)
        XCTAssertTrue(line.hasPrefix(EchoelCrashLog.imageLinePrefix + "Echoelmusic uuid="))
        XCTAssertTrue(line.contains("uuid=" + image.identity.uuid.uuidString))
        XCTAssertTrue(line.contains(" load=0x" + String(image.loadAddress, radix: 16)))
        XCTAssertEqual(EchoelCrashLog.imageLine(executable: "Echoelmusic", image: nil),
                       EchoelCrashLog.imageLinePrefix + "Echoelmusic unreadable - frame offsets cannot be resolved")
    }

    // MARK: 3 — a 2613-shaped log signs in one line

    func testACrashLogSignsInOneLine() throws {
        let signature = try XCTUnwrap(EchoelCrashLog.crashSignature(in: Self.crashLog(withImageLine: true)))
        XCTAssertEqual(signature, EchoelCrashLog.crashSignaturePrefix
            + "SIGTRAP · queue com.echoelmusic.retrocapture.disk · app +0x5cd58c +0x3c779c"
            + " · last \"midiout: port already open\" · v10.79.488 (2613) · uuid 1A2B3C4D")
        XCTAssertFalse(signature.contains("\n"), "one line")
    }

    // MARK: 4 — a log from before this commit still names its offsets

    func testALogWithoutAnImageLineStillNamesTheOffsets() throws {
        let signature = try XCTUnwrap(EchoelCrashLog.crashSignature(in: Self.crashLog(withImageLine: false)))
        XCTAssertEqual(signature, EchoelCrashLog.crashSignaturePrefix
            + "SIGTRAP · queue com.echoelmusic.retrocapture.disk · app +0x5cd58c"
            + " · last \"midiout: port already open\" · v10.79.488 (2613)", """
            without the run's load address only the stripped frame (`Echoelmusic + n`, counted from \
            the image) is an offset; the frame counted from `main` is left out rather than misread
            """)
    }

    // MARK: 5 — no marker, no signature; an exception by its name

    func testACleanRunHasNoSignatureAndAnExceptionIsNamed() throws {
        XCTAssertNil(EchoelCrashLog.crashSignature(in: """
            1.000  launch v1.0 (1)
            2.000  crash net: alternate signal stack armed (SIGSEGV/SIGBUS, this thread)
            3.000  scene: active → background
            """), "a run that ended cleanly — the lower-case `crash net:` line is not a marker")
        let exception = """
            1.000  launch v1.0 (1)
            2.000  midi: start
            3.000  CRASH exception: NSInvalidArgumentException: -[X y]: unrecognized selector
            3.001    0   CoreFoundation                      0x00000001804c7e8c __exceptionPreprocess + 164
            CRASH SIGABRT (abort) — see breadcrumbs above
            """
        XCTAssertEqual(EchoelCrashLog.crashSignature(in: exception), EchoelCrashLog.crashSignaturePrefix
            + "exception NSInvalidArgumentException · no app frames · last \"midi: start\" · v1.0 (1)")
    }

    // MARK: 6 — the line cannot read as a marker

    func testTheSignatureCannotReadAsAMarker() throws {
        let markers = [EchoelCrashLog.crashMarker, EchoelCrashLog.startTappedMarker,
                       EchoelCrashLog.confirmedHealthyMarker, EchoelCrashLog.recoveryScreenClearedMarker,
                       EchoelCrashLog.rearmMarker, EchoelCrashLog.rearmNotNeededMarker]
        let lastLines = markers.map { $0 + " (studio) — streak 0" }
            + [EchoelCrashLog.sceneTransition(from: "active", to: "inactive")]
        for last in lastLines {
            let log = "1.000  launch v1.0 (1)\n2.000  \(last)\nCRASH SIGSEGV (bad memory access / heap) — see breadcrumbs above\n"
            let signature = try XCTUnwrap(EchoelCrashLog.crashSignature(in: log), "precondition: `\(last)` signs")
            for marker in markers {
                XCTAssertFalse(signature.contains(marker), """
                    the signature quotes `\(marker)` — written into THIS run's log, the next launch \
                    would read it as this run's own
                    """)
            }
            XCTAssertNil(EchoelCrashLog.lastScenePhase(in: signature), "a quoted scene line would become this run's last phase")
            XCTAssertFalse(EchoelCrashLog.looksLikeUnseenCrash(signature), "the line must not report a crash this run never had")
            XCTAssertFalse(EchoelCrashLog.counterEndedSettled(in: signature), "a quoted confirm would settle a counter this run never settled")
        }
    }

    // MARK: 7 — nothing new in the handler; the order in begin()

    func testTheHandlerStaysAsItWasAndBeginWritesInOrder() throws {
        let code = try source()
        guard let open = code.range(of: "signal(sig) { received in"),
              let close = code.range(of: "signal(received, SIG_DFL)", range: open.upperBound..<code.endIndex) else {
            throw SignatureAnchorMissing(reason: "the signal handler's span moved — re-anchor (#454)")
        }
        let handler = code[open.upperBound..<close.lowerBound]
        for name in ["imageLine(", "loadedImage(", "imageIdentity(", "crashSignature(", "neutralized(", "#dsohandle"] {
            XCTAssertFalse(handler.contains(name), "`\(name)` runs inside the signal handler — read the binary at launch, never mid-crash")
        }
        let begin = try block(after: "static func begin() {", in: code)
        let net = try anchor("\"crash net: alternate signal stack armed", in: begin)
        let image = try anchor("breadcrumb(imageLine(", in: begin)
        let signature = try anchor("crashSignature(in: previousSession)", in: begin)
        let retain = try anchor("retainedCrashAtLaunch = lastCrashLog()", in: begin)
        XCTAssertLessThan(net.lowerBound, image.lowerBound, "the image line follows the version and crash-net lines")
        XCTAssertLessThan(image.lowerBound, signature.lowerBound, "this run names its binary before it signs the last one")
        XCTAssertLessThan(signature.lowerBound, retain.lowerBound, "the signature is written before the retain can die")
    }

    // MARK: - Fixtures

    private static func crashLog(withImageLine: Bool) -> String {
        let image = EchoelCrashLog.imageLine(
            executable: "Echoelmusic",
            image: (identity: EchoelCrashLog.ImageIdentity(uuid: UUID(uuidString: fixtureUUID) ?? UUID(),
                                                           textVMAddress: textAddress),
                    loadAddress: loadAddress))
        var lines = ["1727863920.101  launch v10.79.488 (2613)",
                     "1727863920.102  crash net: alternate signal stack armed (SIGSEGV/SIGBUS, this thread)"]
        if withImageLine { lines.append("1727863920.103  " + image) }
        let firstFrame: String = "2   Echoelmusic                         " + hex16(loadAddress + 6_083_980)
            + " Echoelmusic + 6083980"
        // The second app frame resolved to an exported symbol, so its `+ n` counts from `main`, not
        // from the image: only the run's own load address turns it into an offset (claims 3 and 4).
        let secondFrame: String = "3   Echoelmusic                         " + hex16(loadAddress + 3_962_780)
            + " main + 2048"
        lines += ["1727863990.500  transport play (timelineRegion) tempo=132 tempoSource=user",
                  "1727863990.900  midiout: port already open",
                  "CRASH SIGTRAP (Swift trap: precondition/force-unwrap/overflow, or an isolation check off the main queue) — see breadcrumbs above",
                  "crash queue: com.echoelmusic.retrocapture.disk",
                  "0   libdispatch.dylib                   0x00000001b7c8a1a4 dispatch_assert_queue + 196",
                  "1   libswift_Concurrency.dylib          0x00000001f0e12a34 swift_task_isCurrentExecutor + 60",
                  firstFrame,
                  secondFrame,
                  "4   libdispatch.dylib                   0x00000001b7c8b000 _dispatch_root_queue_drain + 400"]
        return lines.joined(separator: "\n") + "\n"
    }

    private static func hex16(_ value: UInt64) -> String {
        let digits = String(value, radix: 16)
        return "0x" + String(repeating: "0", count: max(0, 16 - digits.count)) + digits
    }

    /// A 64-bit Mach-O header with an `LC_SEGMENT_64 __TEXT` and an `LC_UUID`, little-endian.
    private static func header(magic: UInt32 = 0xfeed_facf, withUUID: Bool = true,
                               claimedCommands: UInt32? = nil) -> [UInt8] {
        var commands: [UInt8] = littleEndian(UInt32(0x19)) + littleEndian(UInt32(72))
        commands += Array("__TEXT".utf8) + [UInt8](repeating: 0, count: 10)
        commands += littleEndian(textAddress)
        commands += [UInt8](repeating: 0, count: 72 - 32)
        var count: UInt32 = 1
        if withUUID, let uuid = UUID(uuidString: fixtureUUID) {
            commands += littleEndian(UInt32(0x1b)) + littleEndian(UInt32(24))
            commands += withUnsafeBytes(of: uuid.uuid) { Array($0) }
            count += 1
        }
        let commandBytes = UInt32(commands.count)
        let words: [UInt32] = [magic, 0x0100_000c, 0, 2, claimedCommands ?? count, commandBytes, 0, 0]
        var bytes: [UInt8] = []
        for word in words { bytes += littleEndian(word) }
        return bytes + commands
    }

    private static func littleEndian<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian) { Array($0) }
    }

    private func readIdentity(of bytes: [UInt8]) -> EchoelCrashLog.ImageIdentity? {
        bytes.withUnsafeBytes { EchoelCrashLog.imageIdentity(machHeader: $0) }
    }

    // MARK: - Helpers

    private func anchor(_ needle: String, in text: String) throws -> Range<String.Index> {
        guard let hit = text.range(of: needle) else {
            throw SignatureAnchorMissing(reason: "`\(needle)` is not in the scanned block — re-anchor (#454)")
        }
        return hit
    }

    /// The brace-matched block that opens at the first `{` at or after `key` (#408).
    private func block(after key: String, in text: String) throws -> String {
        let start = try anchor(key, in: text)
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

    private func source() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        let path = root.appendingPathComponent(Self.file)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw SignatureAnchorMissing(reason: "\(Self.file) is missing while the tree is present — re-anchor (#454)")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
