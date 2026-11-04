import Foundation
import XCTest
@testable import EchoelCore

/// The stored ZIP writer under the OTIOZ and DAWproject bundles (PRO-W2).
final class ZipArchiveTests: XCTestCase {
    private func u16(_ data: Data, _ at: Int) -> Int { Int(data[at]) | Int(data[at + 1]) << 8 }
    private func u32(_ data: Data, _ at: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[at + $1]) << UInt32(8 * $1) }
    }

    func testTheChecksumIsCRC32() {
        XCTAssertEqual(ZipArchive.CRC32.checksum(Data("123456789".utf8)), 0xCBF4_3926, "the standard check value")
        XCTAssertEqual(ZipArchive.CRC32.checksum(Data()), 0)
        var pieces = ZipArchive.CRC32()
        pieces.update(Data("1234".utf8))
        pieces.update(Data("56789".utf8))
        XCTAssertEqual(pieces.checksum, 0xCBF4_3926, "in pieces as over the whole")
    }

    func testAnArchiveHoldsItsEntriesStoredAndADirectoryAtTheEnd() throws {
        let one = Data("1.0.0".utf8), two = Data("{}".utf8)
        let zip = try ZipArchive.archive([("version.txt", one), ("media/a b.txt", two)])
        // Local header of the first entry, its name, then its bytes as given.
        XCTAssertEqual(u32(zip, 0), 0x0403_4B50)
        XCTAssertEqual(u16(zip, 8), 0, "stored")
        XCTAssertEqual(u32(zip, 14), ZipArchive.CRC32.checksum(one))
        XCTAssertEqual(u32(zip, 18), 5)
        XCTAssertEqual(String(decoding: zip[30..<41], as: UTF8.self), "version.txt")
        XCTAssertEqual(zip[41..<46], one)
        // The end record: two entries, and the directory where it says.
        let end = zip.count - 22
        XCTAssertEqual(u32(zip, end), 0x0605_4B50)
        XCTAssertEqual(u16(zip, end + 10), 2)
        let directoryStart = Int(u32(zip, end + 16)), directorySize = Int(u32(zip, end + 12))
        XCTAssertEqual(directoryStart + directorySize, end)
        XCTAssertEqual(u32(zip, directoryStart), 0x0201_4B50)
        XCTAssertEqual(u32(zip, directoryStart + 42), 0, "the first entry starts the file")
        // Same input, same bytes: no clock in the archive.
        XCTAssertEqual(try ZipArchive.archive([("version.txt", one), ("media/a b.txt", two)]), zip)
    }

    func testTheWriterStreamsEntriesItIsToldTheSizeOf() throws {
        var writer = ZipArchive.Writer()
        let body = Data(repeating: 7, count: 1_000)
        let header = try writer.header(for: "big.bin", size: body.count, crc: ZipArchive.CRC32.checksum(body))
        XCTAssertEqual(writer.offset, UInt64(header.count + body.count))
        let end = try writer.finish()
        XCTAssertEqual(writer.offset, UInt64(header.count + body.count + end.count))
        XCTAssertThrowsError(try writer.finish()) { XCTAssertEqual($0 as? ZipArchive.Failure, .finished) }
    }

    func testNamesThatEscapeOrRepeatAreRefused() {
        for name in ["", "/abs", "../up", "a/../b", "a//b", "a\\b", "line\nbreak", "./a"] {
            var writer = ZipArchive.Writer()
            XCTAssertThrowsError(try writer.header(for: name, size: 0, crc: 0), name)
        }
        var writer = ZipArchive.Writer()
        XCTAssertNoThrow(try writer.header(for: "media/Take.mov", size: 0, crc: 0))
        XCTAssertThrowsError(try writer.header(for: "media/Take.mov", size: 0, crc: 0)) {
            XCTAssertEqual($0 as? ZipArchive.Failure, .duplicateName("media/Take.mov"))
        }
    }

    func testPastFourGibibytesIsRefusedNotWrapped() {
        var writer = ZipArchive.Writer()
        XCTAssertThrowsError(try writer.header(for: "huge.mov", size: Int(UInt32.max), crc: 0)) {
            XCTAssertEqual($0 as? ZipArchive.Failure, .tooLarge)
        }
        XCTAssertNoThrow(try writer.header(for: "a.mov", size: Int(UInt32.max) / 2, crc: 0))
        XCTAssertThrowsError(try writer.header(for: "b.mov", size: Int(UInt32.max) / 2, crc: 0)) {
            XCTAssertEqual($0 as? ZipArchive.Failure, .tooLarge, "the archive as a whole")
        }
    }
}
