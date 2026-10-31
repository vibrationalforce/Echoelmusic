import Foundation
import XCTest
@testable import EchoelCore

final class StreamingTests: XCTestCase {
    /// Every preset names a transport, and where it names a server, that server speaks it and
    /// takes a key to become a full address.
    func testEveryPresetWithAServerBuildsAnAddressInItsOwnTransport() throws {
        for platform in StreamPlatform.allCases {
            XCTAssertFalse(platform.title.isEmpty)
            XCTAssertFalse(platform.whereToFind.isEmpty)
            guard let server = platform.defaultServer else { continue }
            let target = StreamTarget(platform: platform)
            XCTAssertEqual(target.server, server)
            XCTAssertEqual(target.transport, platform.transport, platform.title)
            let url = try target.publishURL(key: "abc123")
            XCTAssertEqual(url.scheme, platform.transport.rawValue)
            XCTAssertEqual(url.lastPathComponent, "abc123", platform.title)
        }
    }

    func testTheKeyBecomesTheRTMPStreamName() throws {
        let youtube = StreamTarget(platform: .youtube)
        XCTAssertEqual(try youtube.publishURL(key: "  xxxx-yyyy-zzzz  ").absoluteString,
                       "rtmps://a.rtmps.youtube.com/live2/xxxx-yyyy-zzzz")
        let slashed = StreamTarget(platform: .customRTMP, server: "rtmp://relay.local:1935/live///")
        XCTAssertEqual(try slashed.publishURL(key: "stage").absoluteString, "rtmp://relay.local:1935/live/stage")
    }

    /// Facebook's keys carry a query; it reaches the server as part of the stream name.
    func testAKeyWithAQueryKeepsIt() throws {
        let url = try StreamTarget(platform: .facebook).publishURL(key: "FB-1-2?s_bl=1&s_ps=1")
        XCTAssertEqual(url.host, "live-api-s.facebook.com")
        XCTAssertEqual(url.pathComponents.filter { $0 != "/" }, ["rtmp", "FB-1-2"])
        XCTAssertEqual(url.query, "s_bl=1&s_ps=1")
    }

    func testTheSRTKeyBecomesTheStreamID() throws {
        let plain = StreamTarget(platform: .customSRT, server: "srt://relay.local:8890")
        XCTAssertEqual(try plain.publishURL(key: "publish:stage").absoluteString,
                       "srt://relay.local:8890?streamid=publish:stage")
        let withQuery = StreamTarget(platform: .customSRT, server: "srt://relay.local:8890?latency=200000")
        XCTAssertEqual(try withQuery.publishURL(key: "stage").absoluteString,
                       "srt://relay.local:8890?latency=200000&streamid=stage")
        XCTAssertEqual(try plain.publishURL(key: "").absoluteString, "srt://relay.local:8890",
                       "a custom SRT address may carry everything itself")
    }

    /// libsrt would encrypt with its own code; the app declares no non-exempt encryption, so an
    /// SRT address that asks for it is refused before anything connects — in any spelling.
    func testAnSRTAddressThatAsksForEncryptionIsRefused() {
        func refusal(_ server: String, key: String = "stage") -> StreamTarget.AddressError? {
            do {
                _ = try StreamTarget(platform: .customSRT, server: server).publishURL(key: key)
                return nil
            } catch let failure as StreamTarget.AddressError {
                return failure
            } catch {
                return nil
            }
        }
        XCTAssertEqual(refusal("srt://relay.local:8890?passphrase=0123456789abc"), .srtEncryption)
        XCTAssertEqual(refusal("srt://relay.local:8890?latency=200000&pbkeylen=16"), .srtEncryption)
        XCTAssertEqual(refusal("srt://relay.local:8890?PassPhrase=0123456789abc"), .srtEncryption, "a name in any case")
        XCTAssertEqual(refusal("srt://relay.local:8890?pass%70hrase=0123456789abc"), .srtEncryption, "a name percent-encoded")
        XCTAssertEqual(refusal("srt://relay.local:8890?passphrase"), .srtEncryption, "a name without a value")
        XCTAssertEqual(refusal("srt://relay.local:8890?passphrase=x", key: ""), .srtEncryption, "with or without a key")
        XCTAssertNil(refusal("srt://relay.local:8890?latency=200000"), "other options stay allowed")
        XCTAssertNil(refusal("srt://relay.local:8890", key: "passphrase"), "a key that merely says the word is a stream id")
    }

    func testABadAddressSaysWhatToChange() {
        func refusal(_ target: StreamTarget, key: String) -> StreamTarget.AddressError? {
            do {
                _ = try target.publishURL(key: key)
                return nil
            } catch let failure as StreamTarget.AddressError {
                return failure
            } catch {
                return nil
            }
        }
        XCTAssertEqual(refusal(StreamTarget(platform: .instagram), key: "k"), .noServer,
                       "Instagram hands out its server per live, so the preset has none")
        XCTAssertEqual(refusal(StreamTarget(platform: .customRTMP, server: "https://example.com/live"), key: "k"),
                       .wrongScheme("https"))
        XCTAssertEqual(refusal(StreamTarget(platform: .customRTMP, server: "srt://example.com:9000"), key: "k"),
                       .wrongScheme("srt"), "SRT goes through the SRT preset")
        XCTAssertEqual(refusal(StreamTarget(platform: .customSRT, server: "rtmp://example.com/live"), key: "k"),
                       .wrongScheme("rtmp"))
        XCTAssertEqual(refusal(StreamTarget(platform: .customRTMP, server: "rtmp:///live"), key: "k"), .noHost)
        XCTAssertEqual(refusal(StreamTarget(platform: .youtube), key: "   "), .noKey)
        XCTAssertEqual(refusal(StreamTarget(platform: .youtube), key: "two words"), .badKey)
        XCTAssertEqual(refusal(StreamTarget(platform: .youtube), key: "a#b"), .badKey)
        XCTAssertEqual(refusal(StreamTarget(platform: .customSRT, server: "srt://h:1"), key: "a&b"), .badKey)
        XCTAssertEqual(refusal(StreamTarget(platform: .customRTMP, server: "rtmp://h/live"), key: ""), .noStreamName,
                       "an app without a stream name is refused before connecting")
        for each in [StreamTarget.AddressError.noServer, .notAnAddress, .wrongScheme(""), .noHost, .noKey, .badKey,
                     .noStreamName, .srtEncryption] {
            XCTAssertFalse(each.explanation.isEmpty)
        }
    }

    /// A log may name the server's host, never its path (some carry the key) and never the key.
    func testTheRedactedServerIsSchemeAndHostOnly() {
        let target = StreamTarget(platform: .customRTMP, server: "rtmp://relay.local:1935/live/secret")
        XCTAssertEqual(target.redactedServer, "rtmp://relay.local")
        XCTAssertEqual(StreamTarget(platform: .instagram).redactedServer, "—")
    }

    /// The device's list of destinations never carries a key: the encoded form has no field for one.
    func testAStoredTargetHasNoKey() throws {
        let target = StreamTarget(name: "Main", platform: .twitch, isEnabled: true)
        let data = try JSONEncoder().encode(target)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(fields.keys), ["id", "name", "platform", "server", "format", "quality", "isEnabled"])
        XCTAssertEqual(try JSONDecoder().decode(StreamTarget.self, from: data), target)
    }

    func testTheShapesAre1080pAndTheirOwnAspect() {
        let sizes = StreamFormat.allCases.map { "\($0.title) \($0.pixelWidth)x\($0.pixelHeight)" }
        XCTAssertEqual(sizes, ["9:16 1080x1920", "16:9 1920x1080", "1:1 1080x1080", "4:5 1080x1350"])
        XCTAssertEqual(StreamFormat.allCases.filter(\.isCrop), [.square, .portrait])
    }

    /// A new destination starts in its platform's recommended shape and bit rate; Instagram
    /// takes both vertical and longform, every vertical feed starts vertical.
    func testAPresetCarriesItsShapeAndBitRate() {
        for platform in [StreamPlatform.tiktok, .youtubeShorts, .instagram] {
            XCTAssertEqual(StreamTarget(platform: platform).format, .vertical, platform.title)
        }
        XCTAssertEqual(StreamPlatform.instagram.recommendedFormats, [.vertical, .landscape])
        XCTAssertEqual(StreamTarget(platform: .youtube).format, .landscape)
        XCTAssertEqual(StreamTarget(platform: .twitch).format, .landscape)
        XCTAssertEqual(StreamTarget(platform: .twitch).quality.videoKbps, 6_000)
        for platform in StreamPlatform.allCases {
            XCTAssertFalse(platform.recommendedFormats.isEmpty, platform.title)
            XCTAssertTrue(StreamQuality.videoRange.contains(platform.recommendedVideoKbps), platform.title)
        }
        XCTAssertEqual(StreamTarget(platform: .youtube, format: .square).format, .square,
                       "any destination may choose any shape")
    }

    func testTheQualityStaysInItsRanges() throws {
        var quality = StreamQuality(videoKbps: 50_000, audioKbps: 1)
        XCTAssertEqual(quality.videoKbps, StreamQuality.videoRange.upperBound)
        XCTAssertEqual(quality.audioKbps, StreamQuality.audioRange.lowerBound)
        quality.videoKbps = -5
        XCTAssertEqual(quality.videoKbps, StreamQuality.videoRange.lowerBound)
        let decoded = try JSONDecoder().decode(StreamQuality.self, from: Data(#"{"videoKbps":99999,"audioKbps":128}"#.utf8))
        XCTAssertEqual(decoded.videoKbps, StreamQuality.videoRange.upperBound, "a stored value is clamped too")
    }

    /// One destination at a time unless the musician raises the limit; the upload adds up per
    /// destination, each at its own rates, and each shape is drawn once.
    func testThePlanCountsUploadPerDestinationAndHoldsItsLimit() {
        var plan = StreamPlan(targets: [])
        XCTAssertEqual(plan.simultaneousLimit, 1)
        XCTAssertEqual(plan.refusal, .noTarget)
        XCTAssertEqual(plan.uploadKbps, 0)

        plan.targets = [StreamTarget(platform: .youtube, quality: StreamQuality(videoKbps: 6_000, audioKbps: 128),
                                     isEnabled: true),
                        StreamTarget(platform: .tiktok, quality: StreamQuality(videoKbps: 4_000, audioKbps: 128),
                                     isEnabled: true),
                        StreamTarget(platform: .vimeo, isEnabled: false)]
        XCTAssertEqual(plan.enabledTargets.count, 2)
        XCTAssertEqual(plan.uploadKbps, Int((Double(6_128 + 4_128) * StreamPlan.overhead).rounded(.up)))
        XCTAssertEqual(plan.enabledFormats, [.vertical, .landscape])
        XCTAssertEqual(plan.refusal, .tooManyTargets(enabled: 2, limit: 1))
        XCTAssertFalse(StreamPlan.Refusal.tooManyTargets(enabled: 2, limit: 1).explanation.isEmpty)

        plan.simultaneousLimit = 2
        XCTAssertNil(plan.refusal)
        plan.simultaneousLimit = 99
        XCTAssertEqual(plan.simultaneousLimit, StreamPlan.limitRange.upperBound)
        plan.simultaneousLimit = 0
        XCTAssertEqual(plan.simultaneousLimit, 1)
    }
}
