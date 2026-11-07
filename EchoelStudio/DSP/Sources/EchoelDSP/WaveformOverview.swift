import Foundation

/// A whole file's picture at a coarse resolution: one column per `framesPerColumn` frames, each
/// with the lowest and highest sample in it and its RMS. Built once, off the main thread, while
/// the file is read (`Builder`, chunk by chunk, so a reader can stop between chunks); drawn as a
/// cold image inside an audio region, never on the render thread.
///
/// `window(offset:length:columns:)` cuts out the stretch of the file a region plays and folds it
/// into as many columns as the region is wide: the lowest of the lows, the highest of the highs,
/// and the RMS over every frame the column covers.
///
/// A sample that is not a finite number counts as silence, so a broken file draws as a gap,
/// never as a line off the top of the block.
public struct WaveformOverview: Sendable, Equatable {
    /// One column of the picture.
    public struct Column: Sendable, Equatable {
        public var min: Float
        public var max: Float
        public var rms: Float

        public init(min: Float, max: Float, rms: Float) {
            self.min = min
            self.max = max
            self.rms = rms
        }

        public static let silent = Column(min: 0, max: 0, rms: 0)
    }

    /// The columns over the whole file; the last one may cover fewer frames.
    public let columns: [Column]
    /// The frames each column covers.
    public let framesPerColumn: Int
    /// The frames the file holds.
    public let frameCount: Int

    /// No file, or one with no frames: nothing to draw.
    public static let empty = WaveformOverview(columns: [], framesPerColumn: 1, frameCount: 0)

    private init(columns: [Column], framesPerColumn: Int, frameCount: Int) {
        self.columns = columns
        self.framesPerColumn = framesPerColumn
        self.frameCount = frameCount
    }

    /// The overview of `samples` at `framesPerColumn` frames a column (at least one).
    public init(samples: [Float], framesPerColumn: Int) {
        var builder = Builder(framesPerColumn: framesPerColumn)
        samples.withUnsafeBufferPointer { builder.append($0) }
        self = builder.finished()
    }

    /// Whether there is anything to draw.
    public var isEmpty: Bool { columns.isEmpty || frameCount <= 0 }

    /// Builds an overview from a file read in chunks: `append` each chunk as it arrives, then
    /// `finished()`. Holds one partial column between chunks, so a chunk may end anywhere.
    public struct Builder {
        public let framesPerColumn: Int
        private var columns: [Column] = []
        private var frames = 0
        private var inColumn = 0
        private var low: Float = 0
        private var high: Float = 0
        private var squares: Double = 0

        public init(framesPerColumn: Int) {
            self.framesPerColumn = Swift.max(1, framesPerColumn)
        }

        /// Adds the next frames of the file.
        public mutating func append(_ samples: UnsafeBufferPointer<Float>) {
            for raw in samples {
                let value: Float = raw.isFinite ? raw : 0
                if inColumn == 0 {
                    low = value
                    high = value
                } else {
                    low = Swift.min(low, value)
                    high = Swift.max(high, value)
                }
                squares += Double(value) * Double(value)
                inColumn += 1
                frames += 1
                if inColumn == framesPerColumn { closeColumn() }
            }
        }

        /// The overview of everything appended.
        public func finished() -> WaveformOverview {
            var copy = self
            if copy.inColumn > 0 { copy.closeColumn() }
            guard copy.frames > 0 else { return .empty }
            return WaveformOverview(columns: copy.columns, framesPerColumn: framesPerColumn, frameCount: copy.frames)
        }

        private mutating func closeColumn() {
            let rms = Float((squares / Double(Swift.max(inColumn, 1))).squareRoot())
            columns.append(Column(min: low, max: high, rms: rms))
            inColumn = 0
            squares = 0
        }
    }

    /// The frames column `index` covers: `framesPerColumn`, fewer for a short last column.
    private func frames(inColumn index: Int) -> Int {
        let first = index * framesPerColumn
        return Swift.max(0, Swift.min(framesPerColumn, frameCount - first))
    }

    /// The stretch of the file from frame `offset` for `length` frames, folded into `count`
    /// columns. Empty when there is nothing to draw: no columns asked for, an empty file, or a
    /// window that holds none of the file's frames. A window reaching past the file's end is cut
    /// at the end; one narrower than its columns repeats the column under each.
    public func window(offset: Int, length: Int, columns count: Int) -> [Column] {
        guard count > 0, length > 0, !isEmpty, framesPerColumn > 0 else { return [] }
        let first = Swift.min(Swift.max(0, offset), frameCount)
        let (sum, overflow) = first.addingReportingOverflow(length)
        let last = overflow ? frameCount : Swift.min(sum, frameCount)
        guard last > first else { return [] }
        let span = last - first
        var result: [Column] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            // The frames this column of the region covers, in the file.
            let from = first + Int(Double(span) * Double(index) / Double(count))
            let to = Swift.max(from + 1, first + Int(Double(span) * Double(index + 1) / Double(count)))
            let lowColumn = Swift.min(from / framesPerColumn, columns.count - 1)
            let highColumn = Swift.max(lowColumn, Swift.min((to - 1) / framesPerColumn, columns.count - 1))
            var low = columns[lowColumn].min, high = columns[lowColumn].max
            var squares = 0.0, weight = 0
            for source in lowColumn...highColumn {
                let column = columns[source]
                low = Swift.min(low, column.min)
                high = Swift.max(high, column.max)
                let covered = frames(inColumn: source)
                squares += Double(column.rms) * Double(column.rms) * Double(covered)
                weight += covered
            }
            let rms = weight > 0 ? Float((squares / Double(weight)).squareRoot()) : 0
            result.append(Column(min: low, max: high, rms: rms))
        }
        return result
    }
}
