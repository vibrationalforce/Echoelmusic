import Foundation

/// A ZIP archive of STORED (uncompressed) entries, written in pure Swift — the container of an
/// OpenTimelineIO bundle (`.otioz`) and of a DAWproject (`.dawproject`), PRO-W2 2026-11-04. Both
/// formats read stored entries, and OTIOZ requires its media stored. Nothing here touches a file:
/// `Writer` hands back the bytes of each local header and of the closing directory, and the caller
/// writes them around each entry's own bytes, so a video of a gigabyte streams through without
/// being held in memory.
///
/// The archive is classic ZIP (no ZIP64): each entry and the whole archive stay under 4 GiB, at
/// most 65 535 entries. Names are UTF-8 (general-purpose flag bit 11). Every entry carries the same
/// DOS time, 1980-01-01 00:00, so the same input is the same archive byte for byte.
public enum ZipArchive {
    public enum Failure: Error, Equatable, Sendable {
        /// An entry or the archive would pass 4 GiB, which classic ZIP cannot address.
        case tooLarge
        /// More than 65 535 entries.
        case tooManyEntries
        /// An empty name, an absolute one, one with `..`, a backslash, or longer than 65 535 bytes.
        case invalidName(String)
        /// The same name twice.
        case duplicateName(String)
        /// `finish()` was called twice, or an entry was added after it.
        case finished
    }

    /// The largest value a classic ZIP size or offset field holds.
    public static let maximumSize: UInt64 = UInt64(UInt32.max)

    /// CRC-32 (IEEE 802.3, reflected, polynomial 0xEDB88320) — the checksum every ZIP entry carries.
    /// Fed in pieces, it gives the same value as over the whole.
    public struct CRC32: Sendable {
        private var state: UInt32 = 0xFFFF_FFFF

        public init() {}

        public mutating func update(_ bytes: UnsafeRawBufferPointer) {
            var crc = state
            for byte in bytes {
                crc = Self.table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
            }
            state = crc
        }

        public mutating func update(_ data: Data) {
            data.withUnsafeBytes { update($0) }
        }

        public var checksum: UInt32 { state ^ 0xFFFF_FFFF }

        public static func checksum(_ data: Data) -> UInt32 {
            var crc = CRC32()
            crc.update(data)
            return crc.checksum
        }

        private static let table: [UInt32] = (0..<256).map { (index: Int) -> UInt32 in
            var value = UInt32(index)
            for _ in 0..<8 {
                value = (value & 1) == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
            }
            return value
        }
    }

    /// Builds an archive entry by entry. For each entry call `header(for:size:crc:)`, write the
    /// bytes it returns and then the entry's own `size` bytes; after the last, write `finish()`.
    public struct Writer: Sendable {
        private struct Entry: Sendable {
            let name: [UInt8]
            let crc: UInt32
            let size: UInt32
            let offset: UInt32
        }

        private var entries: [Entry] = []
        private var names = Set<String>()
        private var isFinished = false
        /// Bytes written so far, headers and contents.
        public private(set) var offset: UInt64 = 0

        public init() {}

        /// The local file header of an entry named `name` (a relative path with `/`) holding `size`
        /// bytes whose CRC-32 is `crc`. Counts the header and the `size` bytes that follow it.
        public mutating func header(for name: String, size: Int, crc: UInt32) throws -> Data {
            guard !isFinished else { throw Failure.finished }
            guard entries.count < 65_535 else { throw Failure.tooManyEntries }
            let bytes = Array(name.utf8)
            guard ZipArchive.isValidName(name), bytes.count <= 65_535 else { throw Failure.invalidName(name) }
            guard names.insert(name).inserted else { throw Failure.duplicateName(name) }
            guard size >= 0, UInt64(size) <= ZipArchive.maximumSize else { throw Failure.tooLarge }
            let headerLength = UInt64(30 + bytes.count)
            guard offset <= ZipArchive.maximumSize,
                  offset + headerLength + UInt64(size) <= ZipArchive.maximumSize else { throw Failure.tooLarge }
            let entry = Entry(name: bytes, crc: crc, size: UInt32(size), offset: UInt32(offset))
            var data = Data()
            data.appendLE(UInt32(0x0403_4B50))
            data.appendLE(UInt16(10)) // version needed: 1.0, stored
            data.appendLE(ZipArchive.utf8Flag)
            data.appendLE(UInt16(0)) // stored
            data.appendLE(ZipArchive.dosTime)
            data.appendLE(ZipArchive.dosDate)
            data.appendLE(entry.crc)
            data.appendLE(entry.size) // compressed
            data.appendLE(entry.size) // uncompressed
            data.appendLE(UInt16(bytes.count))
            data.appendLE(UInt16(0)) // extra
            data.append(contentsOf: bytes)
            entries.append(entry)
            offset += headerLength + UInt64(size)
            return data
        }

        /// The central directory and its end record, written after the last entry.
        public mutating func finish() throws -> Data {
            guard !isFinished else { throw Failure.finished }
            isFinished = true
            var directory = Data()
            for entry in entries {
                directory.appendLE(UInt32(0x0201_4B50))
                directory.appendLE(UInt16(0x031E)) // made by: Unix, 3.0
                directory.appendLE(UInt16(10))
                directory.appendLE(ZipArchive.utf8Flag)
                directory.appendLE(UInt16(0))
                directory.appendLE(ZipArchive.dosTime)
                directory.appendLE(ZipArchive.dosDate)
                directory.appendLE(entry.crc)
                directory.appendLE(entry.size)
                directory.appendLE(entry.size)
                directory.appendLE(UInt16(entry.name.count))
                directory.appendLE(UInt16(0)) // extra
                directory.appendLE(UInt16(0)) // comment
                directory.appendLE(UInt16(0)) // disk
                directory.appendLE(UInt16(0)) // internal attributes
                directory.appendLE(UInt32(0o100644) << 16) // external: a regular file, rw-r--r--
                directory.appendLE(entry.offset)
                directory.append(contentsOf: entry.name)
            }
            guard offset + UInt64(directory.count) <= ZipArchive.maximumSize else { throw Failure.tooLarge }
            var end = directory
            end.appendLE(UInt32(0x0605_4B50))
            end.appendLE(UInt16(0))
            end.appendLE(UInt16(0))
            end.appendLE(UInt16(entries.count))
            end.appendLE(UInt16(entries.count))
            end.appendLE(UInt32(directory.count))
            end.appendLE(UInt32(offset))
            end.appendLE(UInt16(0)) // comment
            offset += UInt64(end.count)
            return end
        }
    }

    /// A whole archive of small entries held in memory, in the order given — for tests and for the
    /// text parts of a bundle.
    public static func archive(_ files: [(name: String, data: Data)]) throws -> Data {
        var writer = Writer()
        var out = Data()
        for file in files {
            out.append(try writer.header(for: file.name, size: file.data.count, crc: CRC32.checksum(file.data)))
            out.append(file.data)
        }
        out.append(try writer.finish())
        return out
    }

    /// A relative path with `/` separators: not empty, not absolute, no empty, `.` or `..` part,
    /// no backslash, no control character.
    public static func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("/"), !name.contains("\\") else { return false }
        guard !name.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) else { return false }
        return name.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { $0 != "" && $0 != "." && $0 != ".." }
    }

    static let utf8Flag: UInt16 = 1 << 11
    static let dosTime: UInt16 = 0
    /// 1980-01-01: year 0 since 1980, month 1, day 1.
    static let dosDate: UInt16 = (1 << 5) | 1
}

extension Data {
    mutating func appendLE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8(value >> 8))
    }

    mutating func appendLE(_ value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) { append(UInt8((value >> UInt32(shift)) & 0xFF)) }
    }
}
