import Foundation
import XCTest
@testable import EchoelCore

/// The arrangement as an OpenTimelineIO timeline (PRO-W2 slice 1): the way into Resolve.
final class OTIOExportTests: XCTestCase {
    private let take = MediaFile(name: "Take 1", path: "Media/take.mov", frameCount: 480_000, sampleRate: 48_000,
                                 kind: .video)
    private let loop = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)
    private let bar = MusicalTime.ticksPerBar(.common)

    /// At 120 BPM a bar is two seconds. A video from one second into the take at bar 2 for four
    /// seconds; a loop at bar 2 on Drums and two overlapping loops on Bass (bar 1 and half a bar
    /// later), the second following the tempo from 60 BPM; a marker at bar 3.
    private func song() throws -> Project {
        var project = Project(name: "Night", tempo: 120)
        let video = TrackID(), drums = TrackID(), bass = TrackID()
        try Command.addTrack(id: video, name: "Video 1", kind: .video, index: nil).apply(to: &project)
        try Command.addTrack(id: drums, name: "Drums", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: bass, name: "Bass", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: TrackID(), name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addMedia(take).apply(to: &project)
        try Command.addMedia(loop).apply(to: &project)
        let shot = RegionID()
        try Command.placeVideo(track: video, id: shot, media: take.id, start: 0).apply(to: &project)
        try Command.trimRegion(track: video, shot, offset: 48_000, length: 192_000).apply(to: &project)
        try Command.moveRegion(track: video, shot, start: bar).apply(to: &project)
        try Command.placeAudio(track: drums, id: RegionID(), media: loop.id, start: bar).apply(to: &project)
        try Command.placeAudio(track: bass, id: RegionID(), media: loop.id, start: 0).apply(to: &project)
        let warped = RegionID()
        try Command.placeAudio(track: bass, id: warped, media: loop.id, start: bar / 2).apply(to: &project)
        try Command.setRegionWarp(track: bass, warped, nativeBPM: 60, followsTempo: true).apply(to: &project)
        try Command.addMarker(at: 2 * bar, name: "Drop").apply(to: &project)
        return project
    }

    func testEachTrackIsALaneAndOverlapsTakeAnotherLane() throws {
        let lanes = OTIOExport.lanes(for: try song(), rate: .fps25)
        XCTAssertEqual(lanes.map(\.name), ["Video 1", "Drums", "Bass", "Bass 2"])
        XCTAssertEqual(lanes.map(\.isVideo), [true, false, false, false])
        let shot = try XCTUnwrap(lanes.first?.cuts.first)
        XCTAssertEqual([shot.recordIn, shot.recordOut, shot.sourceIn, shot.available], [50, 150, 25, 250])
        // The warped loop: two seconds of file at 60 BPM are two beats, one second at 120 — double speed.
        let warped = try XCTUnwrap(lanes.last?.cuts.first)
        XCTAssertEqual([warped.recordIn, warped.recordOut], [25, 50])
        XCTAssertEqual(warped.speed, 2, accuracy: 1e-9)
        XCTAssertTrue(warped.followsTempo)
    }

    func testTheTimelineIsTheGoldenOTIO() throws {
        let project = try song()
        let urls = ExportMedia.names(for: project, using: ExportMedia.arrangementMedia(of: project),
                                     folder: OTIOExport.bundleMediaFolder)
        XCTAssertEqual(urls[take.id], "media/Take_1.mov")
        XCTAssertEqual(urls[loop.id], "media/Loop.wav")
        let json = OTIOExport.json(for: project, title: "Night", rate: .fps25, mediaURLs: urls)
        XCTAssertEqual(json, Self.golden)
        // It is JSON, and its top is a Timeline starting at one hour.
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(object["OTIO_SCHEMA"] as? String, "Timeline.1")
        let start = try XCTUnwrap(object["global_start_time"] as? [String: Any])
        XCTAssertEqual(start["value"] as? Double, 90_000)
    }

    func testFractionalRatesCountInTheirRealRate() throws {
        let json = OTIOExport.json(for: try song(), title: "Night", rate: .fps23_976)
        XCTAssertTrue(json.contains("\"rate\": \(24_000.0 / 1_001)"))
        XCTAssertFalse(json.contains("\"rate\": 24.0"))
    }

    func testAnEmptySongIsATimelineWithNoTracks() throws {
        var project = Project()
        project.name = "x"
        let json = OTIOExport.json(for: project, title: "Say \"hi\"\n", rate: .fps30)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(object["name"] as? String, "Say \"hi\"")
        let stack = try XCTUnwrap(object["tracks"] as? [String: Any])
        XCTAssertEqual((stack["children"] as? [Any])?.count, 0)
    }

    func testBundleNamesAreSafeUniqueAndKeepTheExtension() {
        var project = Project()
        let a = MediaFile(name: "Take 1 (good)", path: "Media/a.MOV", frameCount: 1, sampleRate: 48_000)
        let b = MediaFile(name: "take 1 good", path: "Media/b.mov", frameCount: 1, sampleRate: 48_000)
        let c = MediaFile(name: "Ünïcode ✓", path: "Media/c", frameCount: 1, sampleRate: 48_000)
        project.media = [a, b, c]
        let names = ExportMedia.names(for: project, using: [a.id, b.id, c.id], folder: "")
        XCTAssertEqual(names[a.id], "Take_1_good.MOV")
        XCTAssertEqual(names[b.id], "take_1_good_2.mov", "unique without regard to case")
        XCTAssertEqual(names[c.id], "n_code")
        let clash = MediaFile(name: "Take 1 good", path: "Media/d.mov", frameCount: 1, sampleRate: 48_000)
        project.media.append(clash)
        let again = ExportMedia.names(for: project, using: [b.id, clash.id], folder: "media")
        XCTAssertEqual(again[b.id], "media/take_1_good.mov")
        XCTAssertEqual(again[clash.id], "media/Take_1_good_2.mov")
    }
}

extension OTIOExportTests {
    /// Read by `opentimelineio` 0.18.1 (`otio.adapters.read_from_string`) and written back by it
    /// byte for byte on 2026-11-04: the schema and the key order are the reference implementation's.
    static let golden = """
    {
        "OTIO_SCHEMA": "Timeline.1",
        "metadata": {},
        "name": "Night",
        "global_start_time": {
            "OTIO_SCHEMA": "RationalTime.1",
            "rate": 25.0,
            "value": 90000.0
        },
        "tracks": {
            "OTIO_SCHEMA": "Stack.1",
            "metadata": {},
            "name": "tracks",
            "source_range": null,
            "effects": [],
            "markers": [
                {
                    "OTIO_SCHEMA": "Marker.2",
                    "metadata": {},
                    "name": "Drop",
                    "color": "YELLOW",
                    "marked_range": {
                        "OTIO_SCHEMA": "TimeRange.1",
                        "duration": {
                            "OTIO_SCHEMA": "RationalTime.1",
                            "rate": 25.0,
                            "value": 0.0
                        },
                        "start_time": {
                            "OTIO_SCHEMA": "RationalTime.1",
                            "rate": 25.0,
                            "value": 100.0
                        }
                    },
                    "comment": ""
                }
            ],
            "enabled": true,
            "color": null,
            "children": [
                {
                    "OTIO_SCHEMA": "Track.1",
                    "metadata": {},
                    "name": "Video 1",
                    "source_range": null,
                    "effects": [],
                    "markers": [],
                    "enabled": true,
                    "color": null,
                    "children": [
                        {
                            "OTIO_SCHEMA": "Gap.1",
                            "metadata": {},
                            "name": "",
                            "source_range": {
                                "OTIO_SCHEMA": "TimeRange.1",
                                "duration": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 50.0
                                },
                                "start_time": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 0.0
                                }
                            },
                            "effects": [],
                            "markers": [],
                            "enabled": true,
                            "color": null
                        },
                        {
                            "OTIO_SCHEMA": "Clip.2",
                            "metadata": {},
                            "name": "Take 1",
                            "source_range": {
                                "OTIO_SCHEMA": "TimeRange.1",
                                "duration": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 100.0
                                },
                                "start_time": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 25.0
                                }
                            },
                            "effects": [],
                            "markers": [],
                            "enabled": true,
                            "color": null,
                            "media_references": {
                                "DEFAULT_MEDIA": {
                                    "OTIO_SCHEMA": "ExternalReference.1",
                                    "metadata": {},
                                    "name": "",
                                    "available_range": {
                                        "OTIO_SCHEMA": "TimeRange.1",
                                        "duration": {
                                            "OTIO_SCHEMA": "RationalTime.1",
                                            "rate": 25.0,
                                            "value": 250.0
                                        },
                                        "start_time": {
                                            "OTIO_SCHEMA": "RationalTime.1",
                                            "rate": 25.0,
                                            "value": 0.0
                                        }
                                    },
                                    "available_image_bounds": null,
                                    "target_url": "media/Take_1.mov"
                                }
                            },
                            "active_media_reference_key": "DEFAULT_MEDIA"
                        }
                    ],
                    "kind": "Video"
                },
                {
                    "OTIO_SCHEMA": "Track.1",
                    "metadata": {},
                    "name": "Drums",
                    "source_range": null,
                    "effects": [],
                    "markers": [],
                    "enabled": true,
                    "color": null,
                    "children": [
                        {
                            "OTIO_SCHEMA": "Gap.1",
                            "metadata": {},
                            "name": "",
                            "source_range": {
                                "OTIO_SCHEMA": "TimeRange.1",
                                "duration": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 50.0
                                },
                                "start_time": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 0.0
                                }
                            },
                            "effects": [],
                            "markers": [],
                            "enabled": true,
                            "color": null
                        },
                        {
                            "OTIO_SCHEMA": "Clip.2",
                            "metadata": {},
                            "name": "Loop",
                            "source_range": {
                                "OTIO_SCHEMA": "TimeRange.1",
                                "duration": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 50.0
                                },
                                "start_time": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 0.0
                                }
                            },
                            "effects": [],
                            "markers": [],
                            "enabled": true,
                            "color": null,
                            "media_references": {
                                "DEFAULT_MEDIA": {
                                    "OTIO_SCHEMA": "ExternalReference.1",
                                    "metadata": {},
                                    "name": "",
                                    "available_range": {
                                        "OTIO_SCHEMA": "TimeRange.1",
                                        "duration": {
                                            "OTIO_SCHEMA": "RationalTime.1",
                                            "rate": 25.0,
                                            "value": 50.0
                                        },
                                        "start_time": {
                                            "OTIO_SCHEMA": "RationalTime.1",
                                            "rate": 25.0,
                                            "value": 0.0
                                        }
                                    },
                                    "available_image_bounds": null,
                                    "target_url": "media/Loop.wav"
                                }
                            },
                            "active_media_reference_key": "DEFAULT_MEDIA"
                        }
                    ],
                    "kind": "Audio"
                },
                {
                    "OTIO_SCHEMA": "Track.1",
                    "metadata": {},
                    "name": "Bass",
                    "source_range": null,
                    "effects": [],
                    "markers": [],
                    "enabled": true,
                    "color": null,
                    "children": [
                        {
                            "OTIO_SCHEMA": "Clip.2",
                            "metadata": {},
                            "name": "Loop",
                            "source_range": {
                                "OTIO_SCHEMA": "TimeRange.1",
                                "duration": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 50.0
                                },
                                "start_time": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 0.0
                                }
                            },
                            "effects": [],
                            "markers": [],
                            "enabled": true,
                            "color": null,
                            "media_references": {
                                "DEFAULT_MEDIA": {
                                    "OTIO_SCHEMA": "ExternalReference.1",
                                    "metadata": {},
                                    "name": "",
                                    "available_range": {
                                        "OTIO_SCHEMA": "TimeRange.1",
                                        "duration": {
                                            "OTIO_SCHEMA": "RationalTime.1",
                                            "rate": 25.0,
                                            "value": 50.0
                                        },
                                        "start_time": {
                                            "OTIO_SCHEMA": "RationalTime.1",
                                            "rate": 25.0,
                                            "value": 0.0
                                        }
                                    },
                                    "available_image_bounds": null,
                                    "target_url": "media/Loop.wav"
                                }
                            },
                            "active_media_reference_key": "DEFAULT_MEDIA"
                        }
                    ],
                    "kind": "Audio"
                },
                {
                    "OTIO_SCHEMA": "Track.1",
                    "metadata": {},
                    "name": "Bass 2",
                    "source_range": null,
                    "effects": [],
                    "markers": [],
                    "enabled": true,
                    "color": null,
                    "children": [
                        {
                            "OTIO_SCHEMA": "Gap.1",
                            "metadata": {},
                            "name": "",
                            "source_range": {
                                "OTIO_SCHEMA": "TimeRange.1",
                                "duration": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 25.0
                                },
                                "start_time": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 0.0
                                }
                            },
                            "effects": [],
                            "markers": [],
                            "enabled": true,
                            "color": null
                        },
                        {
                            "OTIO_SCHEMA": "Clip.2",
                            "metadata": {
                                "echoel": {
                                    "follows_tempo": true
                                }
                            },
                            "name": "Loop",
                            "source_range": {
                                "OTIO_SCHEMA": "TimeRange.1",
                                "duration": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 25.0
                                },
                                "start_time": {
                                    "OTIO_SCHEMA": "RationalTime.1",
                                    "rate": 25.0,
                                    "value": 0.0
                                }
                            },
                            "effects": [
                                {
                                    "OTIO_SCHEMA": "LinearTimeWarp.1",
                                    "metadata": {},
                                    "name": "",
                                    "effect_name": "LinearTimeWarp",
                                    "enabled": true,
                                    "time_scalar": 2.0
                                }
                            ],
                            "markers": [],
                            "enabled": true,
                            "color": null,
                            "media_references": {
                                "DEFAULT_MEDIA": {
                                    "OTIO_SCHEMA": "ExternalReference.1",
                                    "metadata": {},
                                    "name": "",
                                    "available_range": {
                                        "OTIO_SCHEMA": "TimeRange.1",
                                        "duration": {
                                            "OTIO_SCHEMA": "RationalTime.1",
                                            "rate": 25.0,
                                            "value": 50.0
                                        },
                                        "start_time": {
                                            "OTIO_SCHEMA": "RationalTime.1",
                                            "rate": 25.0,
                                            "value": 0.0
                                        }
                                    },
                                    "available_image_bounds": null,
                                    "target_url": "media/Loop.wav"
                                }
                            },
                            "active_media_reference_key": "DEFAULT_MEDIA"
                        }
                    ],
                    "kind": "Audio"
                }
            ]
        }
    }

    """
}
