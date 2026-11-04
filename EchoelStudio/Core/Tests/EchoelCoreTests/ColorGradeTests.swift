import XCTest
@testable import EchoelCore

/// A video part's colour correction (COLOR): the mapping, Auto Enhance (Gray World and
/// percentiles), Match Color (Reinhard in L*a*b*), and the command that stores it.
final class ColorGradeTests: XCTestCase {
    /// A test picture: a smooth field of colours, `cast` multiplied into it in linear light.
    private func picture(width: Int = 48, height: Int = 32, cast: (Double, Double, Double) = (1, 1, 1),
                         low: Double = 0.1, high: Double = 0.8) -> [ColorSample] {
        var pixels: [ColorSample] = []
        for row in 0..<height {
            for column in 0..<width {
                let x = Double(column) / Double(width - 1), y = Double(row) / Double(height - 1)
                let base = low + (high - low) * (0.5 * x + 0.5 * y)
                let red = base * (0.8 + 0.4 * x), green = base * (0.9 + 0.2 * y), blue = base * (1.1 - 0.3 * x)
                func tinted(_ value: Double, _ factor: Double) -> Double {
                    ColorTransfer.encode(Swift.min(ColorTransfer.decode(Swift.min(value, 1)) * factor, 1))
                }
                pixels.append(ColorSample(red: tinted(red, cast.0), green: tinted(green, cast.1), blue: tinted(blue, cast.2)))
            }
        }
        return pixels
    }

    func testTheStandardGradeLeavesThePictureUnchanged() {
        let pixels = picture() + [ColorSample(red: 0, green: 0, blue: 0), ColorSample(red: 1, green: 1, blue: 1)]
        XCTAssertEqual(ColorGrade.neutral.apply(pixels), pixels, "bit for bit")
        let cube = ColorGrade.neutral.cube(size: 17)
        for pixel in pixels {
            let shown = ColorGrade.lookUp(pixel, in: cube, size: 17)
            XCTAssertEqual(shown.red, pixel.red, accuracy: 1e-6)
            XCTAssertEqual(shown.green, pixel.green, accuracy: 1e-6)
            XCTAssertEqual(shown.blue, pixel.blue, accuracy: 1e-6)
        }
    }

    func testGrayWorldMakesACastPictureNeutralOnAverage() throws {
        let cast = picture(cast: (1.6, 1.0, 0.6))
        let before = try XCTUnwrap(ColorAnalysis.linearMeans(cast))
        XCTAssertGreaterThan(before.red / before.blue, 1.5, "the picture carries a warm cast")
        let grade = ColorGrade.grayWorld(cast)
        XCTAssertLessThan(grade.temperature, -0.3, "a warm cast is balanced toward blue")
        let after = try XCTUnwrap(ColorAnalysis.linearMeans(grade.apply(cast)))
        let middle = (after.red + after.green + after.blue) / 3
        for mean in [after.red, after.green, after.blue] {
            XCTAssertEqual(mean / middle, 1, accuracy: 0.02, "each channel's mean within 2 % of neutral")
        }
        // A green cast is a tint.
        let green = ColorGrade.grayWorld(picture(cast: (0.8, 1.4, 0.8)))
        XCTAssertGreaterThan(green.tint, 0.3)
    }

    func testAutoEnhanceBringsTheContrastIntoItsBand() throws {
        let flat = picture(low: 0.18, high: 0.66)
        let grade = ColorGrade.autoEnhanced(flat)
        XCTAssertTrue(grade.isValid)
        XCTAssertTrue(ColorGrade.autoContrastRange.contains(grade.contrast))
        XCTAssertGreaterThan(grade.contrast, 1, "a flat picture gains contrast")
        let shown = grade.apply(flat)
        let low = try XCTUnwrap(ColorAnalysis.lumaPercentile(shown, 0.02))
        let high = try XCTUnwrap(ColorAnalysis.lumaPercentile(shown, 0.98))
        XCTAssertEqual(high - low, ColorGrade.autoSpread, accuracy: 0.06, "the 2nd to 98th percentile spans the band")
        let median = try XCTUnwrap(ColorAnalysis.lumaPercentile(shown, 0.5))
        XCTAssertEqual(median, ColorGrade.autoMedian, accuracy: 0.05)
        // A picture that already spans the band is not pushed past it.
        let wide = ColorGrade.autoEnhanced(picture(low: 0.02, high: 0.98))
        XCTAssertTrue(ColorGrade.autoContrastRange.contains(wide.contrast))
        XCTAssertLessThan(wide.contrast, 1.2)
    }

    func testMatchColorReachesTheOtherPartsStatistics() throws {
        let source = picture()
        let look = ColorGrade(exposure: 0.4, contrast: 1.2, saturation: 0.7, temperature: 0.3, tint: -0.2)
        let target = look.apply(picture(width: 40, height: 40))
        let goal = try XCTUnwrap(ColorAnalysis.labStatistics(target))
        let grade = ColorGrade.matched(source, to: target)
        XCTAssertTrue(grade.isValid)
        let reached = try XCTUnwrap(ColorAnalysis.labStatistics(grade.apply(source)))
        XCTAssertEqual(reached.meanL, goal.meanL, accuracy: 0.5)
        XCTAssertEqual(reached.meanA, goal.meanA, accuracy: 0.5)
        XCTAssertEqual(reached.meanB, goal.meanB, accuracy: 0.5)
        XCTAssertEqual(reached.deviationL / goal.deviationL, 1, accuracy: 0.03)
        XCTAssertEqual(reached.chromaDeviation / goal.chromaDeviation, 1, accuracy: 0.05)
    }

    func testTheCubeShowsWhatTheMappingComputes() {
        // The window and the export both draw through this cube (`cubeSize`); it stays within one
        // step of 8-bit video of the exact mapping (away from a clipped channel, whose kink falls
        // between two entries).
        let grades = [ColorGrade(exposure: 0.2, contrast: 1.15, saturation: 1.2, temperature: 0.2, tint: -0.1),
                      ColorGrade(exposure: -0.7, contrast: 0.8, saturation: 0.6, lift: 0.05, gamma: 1.2, gain: 0.95)]
        let size = ColorGrade.cubeSize
        var checked = 0
        for grade in grades {
            let cube = grade.cube(size: size)
            for pixel in picture(high: 0.7) {
                let exact = grade.apply(pixel), shown = ColorGrade.lookUp(pixel, in: cube, size: size)
                let channels = [exact.red, exact.green, exact.blue]
                guard channels.allSatisfy({ $0 > 0.02 && $0 < 0.98 }) else { continue }
                checked += 1
                XCTAssertEqual(shown.red, exact.red, accuracy: 1.0 / 255)
                XCTAssertEqual(shown.green, exact.green, accuracy: 1.0 / 255)
                XCTAssertEqual(shown.blue, exact.blue, accuracy: 1.0 / 255)
            }
        }
        XCTAssertGreaterThan(checked, 2_000, "most of the picture is compared")
    }

    func testNumbersThatAreNotNumbersChangeNothingAndBreakNothing() {
        let broken = ColorSample(red: .nan, green: .infinity, blue: -.infinity)
        let shown = ColorGrade(exposure: 1, contrast: 1.5).apply(broken)
        XCTAssertTrue(shown.isFinite)
        XCTAssertTrue((0...1).contains(shown.red) && (0...1).contains(shown.green) && (0...1).contains(shown.blue))
        let nonsense = ColorGrade(exposure: .nan, contrast: .infinity, saturation: .nan, temperature: .nan, tint: .nan,
                                  lift: .nan, gamma: .nan, gain: .nan)
        XCTAssertFalse(nonsense.isValid)
        XCTAssertEqual(nonsense.held, .neutral)
        let pixels = picture()
        XCTAssertEqual(nonsense.apply(pixels), pixels, "a grade of non-numbers shows the file as it is")
        let mixed = picture() + [broken, broken]
        XCTAssertTrue(ColorGrade.autoEnhanced(mixed).isValid)
        XCTAssertTrue(ColorGrade.grayWorld([broken]).isNeutral)
        XCTAssertTrue(ColorGrade.matched([broken], to: pixels).isNeutral)
        XCTAssertTrue(ColorGrade.matched(pixels, to: []).isNeutral)
        XCTAssertTrue(ColorGrade.autoEnhanced([]).isNeutral)
    }

    // MARK: - The command

    private func song() throws -> (Project, TrackID, RegionID) {
        var project = Project()
        let video = TrackID()
        let media = MediaID()
        try Command.addTrack(id: video, name: "Video", kind: .video, index: nil).apply(to: &project)
        try Command.addMedia(MediaFile(id: media, name: "Take", path: "Media/take.mov", frameCount: 480_000,
                                       sampleRate: 48_000, kind: .video)).apply(to: &project)
        let region = RegionID()
        try Command.placeVideo(track: video, id: region, media: media, start: 0).apply(to: &project)
        return (project, video, region)
    }

    func testTheCommandStoresTheGradeAndTheStandardOneRemovesIt() throws {
        var (project, video, region) = try song()
        let grade = ColorGrade(exposure: 0.5, saturation: 1.2)
        try Command.setRegionGrade(track: video, region, grade: grade).apply(to: &project)
        XCTAssertEqual(project.tracks[0].regions[0].grade, grade)
        // Split and duplicate keep it.
        let copies = try XCTUnwrap(Arranging.duplicated(project.tracks[0].regions[0], in: project.tracks[0], project: project))
        for command in copies { try command.apply(to: &project) }
        XCTAssertEqual(project.tracks[0].regions.map(\.grade), [grade, grade])
        try Command.setRegionGrade(track: video, region, grade: .neutral).apply(to: &project)
        XCTAssertNil(project.tracks[0].regions.first { $0.id == region }?.grade)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)), project)
    }

    func testTheCommandRefusesWhatIsOutOfRangeAndLeavesTheSongAlone() throws {
        var (project, video, region) = try song()
        let before = project
        for grade in [ColorGrade(exposure: .nan), ColorGrade(contrast: 3), ColorGrade(gamma: 0), ColorGrade(tint: -2)] {
            XCTAssertThrowsError(try Command.setRegionGrade(track: video, region, grade: grade).apply(to: &project))
        }
        XCTAssertThrowsError(try Command.setRegionGrade(track: video, RegionID(), grade: ColorGrade(exposure: 1)).apply(to: &project))
        XCTAssertEqual(project, before)
    }

    func testOneGradeIsOneUndoStep() async throws {
        let (project, video, region) = try song()
        let grade = ColorGrade.autoEnhanced(picture())
        try await MainActor.run {
            let store = ProjectStore(project: project)
            try store.perform(.setRegionGrade(track: video, region, grade: grade))
            XCTAssertNotNil(store.project.tracks[0].regions[0].grade)
            store.undo()
            XCTAssertNil(store.project.tracks[0].regions[0].grade)
        }
    }
}
