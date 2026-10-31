import EchoelCore
import Foundation
import XCTest
@testable import EchoelEngine

/// SplitMix64: the same numbers on every machine, so a jittered link is the same link each run.
private struct JamTestRandom {
    private var seed: UInt64

    init(seed: UInt64) {
        self.seed = seed
    }

    /// 0 ..< 1.
    mutating func next() -> Double {
        seed &+= 0x9E37_79B9_7F4A_7C15
        var z = seed
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / 9_007_199_254_740_992
    }
}

final class JamTests: XCTestCase {
    /// 100.25 BPM is 1604 ticks a second; a 4/4 bar is 3840 ticks.
    private static let playing = JamState(tempo: 100.25, signature: TimeSignature(4, 4), isPlaying: true,
                                          anchorTick: 3_840, anchorTime: 12.5)

    // MARK: - Messages

    func testEveryMessageSurvivesTheLinkAndAStateReadsAsAnotherBuildWritesIt() throws {
        let messages = [
            JamMessage(ping: JamPing(id: 7, sentAt: 1.25)),
            JamMessage(pong: JamPong(id: 7, guestSentAt: 1.25, hostReceivedAt: 9.5, hostSentAt: 9.75)),
            JamMessage(state: Self.playing),
            JamMessage(roster: ["iPhone", "iPad"]),
            JamMessage.leave,
        ]
        for message in messages {
            let data = try XCTUnwrap(message.encoded())
            XCTAssertEqual(JamMessage.decode(data), .message(message))
        }
        let written = Data(#"{"version":1,"kind":"state","state":{"tempo":100.25,"signature":{"numerator":4,"denominator":4},"isPlaying":true,"anchorTick":3840,"anchorTime":12.5}}"#.utf8)
        XCTAssertEqual(JamMessage.decode(written), .message(JamMessage(state: Self.playing)))
    }

    func testANewerVersionIsRefusedWholeAndNoiseIsNotRead() {
        XCTAssertEqual(JamMessage.decode(Data(#"{"version":2,"kind":"state","news":true}"#.utf8)), .newerVersion(2))
        XCTAssertEqual(JamMessage.decode(Data("hello".utf8)), .unreadable)
        XCTAssertEqual(JamMessage.decode(Data(#"{"version":1,"kind":"state"}"#.utf8)), .unreadable,
                       "a state without its state")
        XCTAssertEqual(JamMessage.decode(Data(#"{"version":1,"kind":"chat"}"#.utf8)), .unreadable,
                       "a kind this version does not know")
        XCTAssertEqual(JamMessage.decode(Data(#"{"version":0,"kind":"leave"}"#.utf8)), .unreadable)
        var broken = Self.playing
        broken.tempo = .nan
        XCTAssertNil(JamMessage(state: broken).encoded(), "JSON carries no NaN")
    }

    func testTwoPhonesOfOneNameReadApartAndALinkNameIsAlwaysSafe() {
        XCTAssertEqual(JamPeer.labels(["iPhone", "iPad", "iPhone", "iPhone"]), ["iPhone", "iPad", "iPhone 2", "iPhone 3"])
        let link = JamPeer.linkName(name: "Studio iPhone", token: "a1b2c3")
        XCTAssertEqual(link, "Studio iPhone#a1b2c3")
        XCTAssertEqual(JamPeer(linkName: link), JamPeer(linkName: link))
        XCTAssertEqual(JamPeer(linkName: link).name, "Studio iPhone")
        XCTAssertEqual(JamPeer(linkName: link).id, link)
        let long = JamPeer.linkName(name: String(repeating: "ö", count: 80), token: "ZZ")
        XCTAssertLessThanOrEqual(long.utf8.count, 63, "MultipeerConnectivity takes 63 bytes at most")
        XCTAssertTrue(long.hasSuffix("#zz0000"))
        XCTAssertEqual(JamPeer(linkName: JamPeer.linkName(name: "  ", token: "abcdef")).name, JamPeer.fallbackName)
        XCTAssertEqual(JamPeer(linkName: "Studio").name, "Studio", "a name without a token reads whole")
    }

    // MARK: - Clocks

    func testTheHostsClockIsReadWithinTwoMillisecondsThroughJitterAndQueues() throws {
        var estimate = JamClockEstimate()
        var random = JamTestRandom(seed: 3)
        let truth = 4_321.0                                   // host time minus guest time
        var asked = 100.0                                     // guest clock
        for n in 0..<JamClockEstimate.capacity {
            let out = 0.004 + random.next() * 0.020
            var back = 0.004 + random.next() * 0.020
            if n % 5 == 0 { back += 0.300 }                   // this answer waited in a queue
            let arrived = asked + truth + out
            let pong = JamPong(id: UInt32(n), guestSentAt: asked, hostReceivedAt: arrived, hostSentAt: arrived + 0.0003)
            XCTAssertTrue(estimate.add(pong, receivedAt: arrived + 0.0003 - truth + back))
            if n == JamClockEstimate.minimumSamples - 2 { XCTAssertNil(estimate.offset, "one answer is not a measurement") }
            asked += 0.5
        }
        XCTAssertEqual(try XCTUnwrap(estimate.offset), truth, accuracy: 0.002)
        XCTAssertLessThan(try XCTUnwrap(estimate.roundTrip), 0.1)
        XCTAssertEqual(estimate.samples.count, JamClockEstimate.capacity)

        let count = estimate.samples.count
        XCTAssertFalse(estimate.add(JamPong(id: 1, guestSentAt: 5, hostReceivedAt: .nan, hostSentAt: 1), receivedAt: 6))
        XCTAssertFalse(estimate.add(JamPong(id: 2, guestSentAt: 5, hostReceivedAt: 9, hostSentAt: 9), receivedAt: 4),
                       "an answer before its question")
        XCTAssertFalse(estimate.add(JamPong(id: 3, guestSentAt: 5, hostReceivedAt: 9, hostSentAt: 9), receivedAt: 6),
                       "a round trip of a whole second waited somewhere")
        XCTAssertEqual(estimate.samples.count, count)
    }

    func testAGuestComesInOnTheHostsNextBarLineInTheBarOfItsOwnLoop() throws {
        let timeline = JamTimeline(Self.playing)
        XCTAssertEqual(timeline.ticksPerSecond, 1_604)
        XCTAssertEqual(timeline.barTicks, 3_840)
        // Host clock = guest clock + 1000. At guest time -987.5 the host hears 12.5 s: tick 3840,
        // a bar line — but a start needs a quarter second of lead, so the next one.
        let start = try XCTUnwrap(timeline.start(afterLocal: -987.5, offset: 1_000, lead: 0.25))
        XCTAssertEqual(start.hostTick, 7_680)
        XCTAssertEqual(start.localTime + 1_000, 12.5 + 3_840.0 / 1_604, accuracy: 1e-9)
        let atOnce = try XCTUnwrap(timeline.start(afterLocal: -987.5, offset: 1_000, lead: 0))
        XCTAssertEqual(atOnce.hostTick, 3_840, "with no lead, the bar line it stands on")

        var sixEight = Self.playing
        sixEight.signature = TimeSignature(6, 8)
        let compound = try XCTUnwrap(JamTimeline(sixEight).start(afterLocal: -987.0, offset: 1_000, lead: 0.25))
        XCTAssertEqual(compound.hostTick, 2 * 2_880, "a 6/8 bar is 2880 ticks")

        var stopped = Self.playing
        stopped.isPlaying = false
        XCTAssertNil(JamTimeline(stopped).start(afterLocal: 0, offset: 0, lead: 0.25), "nothing to come in on")

        let sixth = JamStart(hostTick: 5 * 3_840, localTime: 0)
        XCTAssertEqual(sixth.songTick(loop: 0..<Tick(4 * 3_840)), 3_840, "bar 6 of the host is bar 2 of a four-bar loop")
        XCTAssertEqual(sixth.songTick(loop: nil), 5 * 3_840, "without a loop, the host's bar itself")
    }

    func testBarsAreComparedAsAPhaseSoLoopsOfAnyLengthStayInStep() {
        XCTAssertEqual(JamTimeline.phase(8 * 3_840 + 100, bar: 3_840), 100)
        XCTAssertEqual(JamTimeline.phase(-3 * 3_840 - 100, bar: 3_840), -100)
        XCTAssertEqual(JamTimeline.phase(3_840 - 100, bar: 3_840), -100)
        XCTAssertEqual(JamTimeline.phase(.nan, bar: 3_840), 0)
    }

    // MARK: - Following

    /// A follower that has measured the clocks (the host's clock equals this phone's) and heard the
    /// host play from tick 0 at its second 10.
    private func joinedFollower() -> JamFollower {
        var follower = JamFollower()
        follower.joined(at: 0)
        for n in 0..<JamClockEstimate.minimumSamples {
            let asked = 0.1 * Double(n + 1)
            follower.received(JamPong(id: UInt32(n), guestSentAt: asked, hostReceivedAt: asked + 0.005,
                                      hostSentAt: asked + 0.005), at: asked + 0.010)
        }
        return follower
    }

    private func host(playing: Bool, tick: Double = 0, at time: Double = 10) -> JamState {
        JamState(tempo: 100.25, signature: TimeSignature(4, 4), isPlaying: playing, anchorTick: tick, anchorTime: time)
    }

    func testTheHostsPlayIsJoinedOnItsNextBarAndItsStopPausesThePhone() {
        var follower = joinedFollower()
        XCTAssertEqual(follower.received(host(playing: false), at: 9, playing: false), .none)
        XCTAssertEqual(follower.phase, .stopped)
        guard case .start(let start) = follower.received(host(playing: true), at: 10.05, playing: false) else {
            return XCTFail("the host plays: a start is planned")
        }
        XCTAssertEqual(start.hostTick, 3_840, "the host's bar 2: bar 1 began before the word arrived")
        XCTAssertEqual(start.localTime, 10 + 3_840.0 / 1_604, accuracy: 1e-9)
        XCTAssertEqual(follower.phase, .starting)
        follower.started(true)
        XCTAssertEqual(follower.phase, .following)
        XCTAssertEqual(follower.received(host(playing: false, tick: 9_000, at: 20), at: 20.03, playing: true), .pause)
        XCTAssertEqual(follower.phase, .stopped)

        var refused = joinedFollower()
        _ = refused.received(host(playing: true), at: 10.05, playing: false)
        refused.started(false)
        XCTAssertEqual(refused.phase, .waiting, "audio that would not start waits for the next bar")
        guard case .start = refused.check(at: 10.2, playing: false) else { return XCTFail("planned again") }
    }

    func testAPhoneStoppedByHandSitsOutUntilItPlaysOrTheHostStartsAgain() {
        var follower = joinedFollower()
        _ = follower.received(host(playing: true), at: 10.05, playing: false)
        follower.started(true)
        XCTAssertEqual(follower.check(at: 11, playing: false), .none)
        XCTAssertEqual(follower.phase, .sittingOut)
        XCTAssertEqual(follower.received(host(playing: true, tick: 1_604, at: 11), at: 11.02, playing: false), .none,
                       "not pulled back in at every bar")
        XCTAssertEqual(follower.check(at: 11.5, playing: true), .none)
        XCTAssertEqual(follower.phase, .following, "Play by hand comes back into step")

        var restarted = joinedFollower()
        _ = restarted.received(host(playing: true), at: 10.05, playing: false)
        restarted.started(true)
        _ = restarted.check(at: 11, playing: false)
        XCTAssertEqual(restarted.received(host(playing: false, tick: 3_000, at: 12), at: 12.02, playing: false), .none)
        guard case .start = restarted.received(host(playing: true, tick: 0, at: 14), at: 14.02, playing: false) else {
            return XCTFail("the host's new start is joined")
        }
    }

    func testALostHostLeavesThePhonePlayingAtTheLastTempo() {
        var follower = joinedFollower()
        _ = follower.received(host(playing: true), at: 10.05, playing: false)
        follower.started(true)
        XCTAssertEqual(follower.check(at: 12, playing: true), .none)
        XCTAssertEqual(follower.phase, .following)
        XCTAssertEqual(follower.check(at: 10.05 + JamFollower.silenceLimit + 0.1, playing: true), .none)
        XCTAssertEqual(follower.phase, .hostLost)
        XCTAssertEqual(follower.state?.tempo, 100.25, "it plays on at the host's last tempo")
        XCTAssertEqual(follower.correct(heard: 0, atLocal: 13.5), .none, "and pulls towards nothing")

        _ = follower.received(host(playing: true, tick: 8_020, at: 15), at: 15.02, playing: true)
        XCTAssertEqual(follower.phase, .following, "a host that comes back is followed without a restart")
        follower.linkDropped()
        XCTAssertEqual(follower.phase, .hostLost)
        follower.hostLeft()
        XCTAssertEqual(follower.phase, .ended)
        follower.linkDropped()
        XCTAssertEqual(follower.phase, .ended, "an ended jam is not lost")

        var silent = JamFollower()
        silent.joined(at: 0)
        XCTAssertEqual(silent.check(at: JamFollower.silenceLimit + 0.1, playing: false), .none)
        XCTAssertEqual(silent.phase, .hostLost, "a host that never speaks is lost too")
        XCTAssertNil(silent.state)
    }

    func testTheFirstCheckTrimsTheStartAndLaterOnesNudgeGentlyOrRelock() {
        var follower = joinedFollower()
        _ = follower.received(host(playing: true), at: 10.05, playing: false)
        follower.started(true)
        // At 12 s the host hears tick 3208; this phone hears 12 ms behind it: trimmed at once.
        guard case .nudge(let trim) = follower.correct(heard: 3_208 - 0.012 * 1_604, atLocal: 12) else {
            return XCTFail("a small start error is nudged away, not jumped")
        }
        XCTAssertEqual(trim, 0.012, accuracy: 1e-9)
        XCTAssertEqual(follower.correct(heard: 3_208, atLocal: 12.1), .none, "the trim settles first")
        // 3 ms behind, later: a nudge of at most half a millisecond forward.
        guard case .nudge(let gentle) = follower.correct(heard: 1.3 * 1_604 + 3_208 - 0.003 * 1_604, atLocal: 13.3) else {
            return XCTFail("a drift is nudged")
        }
        XCTAssertEqual(gentle, PhaseLock.maximumNudge, accuracy: 1e-12)
        // Whole bars apart is in step: this phone looped back to bar 1 where the host plays bar 2.
        var looped = joinedFollower()
        _ = looped.received(host(playing: true), at: 10.05, playing: false)
        looped.started(true)
        XCTAssertEqual(looped.correct(heard: 4_000 - 3_840, atLocal: 10 + 4_000.0 / 1_604), .none)
        // A quarter note off is a relock.
        guard case .relock(let ticks) = follower.correct(heard: 2 * 3_208 - 960, atLocal: 14), ticks > 0 else {
            return XCTFail("too far to nudge")
        }
        XCTAssertEqual(ticks, 960, accuracy: 1e-6)
    }

    // MARK: - The host

    func testTheHostSpeaksOnAChangeAndOnceASecondButNotAtEveryCheck() {
        var beacon = JamBeacon()
        let first = JamState(tempo: 120, signature: TimeSignature(4, 4), isPlaying: true, anchorTick: 7_680, anchorTime: 10)
        XCTAssertEqual(beacon.due(first), first, "the first word goes out")
        // 120 BPM is 1920 ticks a second.
        var later = first
        later.anchorTime = 10.25
        later.anchorTick = 7_680 + 480
        XCTAssertNil(beacon.due(later), "exactly where the last word promised")
        later.anchorTime = 10.5
        later.anchorTick = 960
        XCTAssertNil(beacon.due(later), "the host looped back to bar 1: whole bars, the same phase")
        later.anchorTick = 960 + 240
        XCTAssertEqual(beacon.due(later), later, "a seek by an eighth is said at once")
        var faster = later
        faster.tempo = 121
        XCTAssertEqual(beacon.due(faster), faster)
        var aSecondOn = faster
        aSecondOn.anchorTime += 1
        aSecondOn.anchorTick += 121 * 16
        XCTAssertEqual(beacon.due(aSecondOn), aSecondOn, "a fresh anchor once a second")
        var stopped = aSecondOn
        stopped.isPlaying = false
        XCTAssertEqual(beacon.due(stopped), stopped)
        stopped.anchorTime += 0.25
        XCTAssertNil(beacon.due(stopped), "standing still says nothing new")
        beacon.reset()
        XCTAssertEqual(beacon.due(stopped), stopped, "someone joined")
        var broken = stopped
        broken.tempo = .infinity
        XCTAssertNil(beacon.due(broken))
    }

    func testTheHostsPlayWaitsForTheGridsNextBarLineAndStartsFromTheStartOfItsBar() throws {
        let bar = 3_840.0 / 1_604                             // a 4/4 bar at 100.25 BPM, in seconds
        let countIn = try XCTUnwrap(JamCountIn(playhead: 5_000, now: 7.3, tempo: 100.25, signature: TimeSignature(4, 4)))
        XCTAssertEqual(countIn.state.anchorTime, 4 * bar, accuracy: 1e-9, "7.3 s is in the grid's fourth bar: the next bar line")
        XCTAssertEqual(countIn.state.anchorTick, 3_840, "the song starts from the start of the bar its playhead stands in")
        XCTAssertTrue(countIn.state.isPlaying)
        XCTAssertEqual(countIn.state.tempo, 100.25)
        XCTAssertEqual(countIn.state.signature, TimeSignature(4, 4))
        let nearLine = try XCTUnwrap(JamCountIn(playhead: 0, now: 5 * bar - 0.1, tempo: 100.25, signature: TimeSignature(4, 4)))
        XCTAssertEqual(nearLine.state.anchorTime, 6 * bar, accuracy: 1e-9, "a bar line too close for the word to reach the phones: the next one")
        let compound = try XCTUnwrap(JamCountIn(playhead: 5_000, now: 0, tempo: 100.25, signature: TimeSignature(6, 8)))
        XCTAssertEqual(compound.state.anchorTick, 2_880, "a 6/8 bar is 2880 ticks")
        XCTAssertEqual(compound.state.anchorTime, 2_880.0 / 1_604, accuracy: 1e-9)
        XCTAssertNil(JamCountIn(playhead: 0, now: 1, tempo: .nan, signature: TimeSignature(4, 4)))
        XCTAssertNil(JamCountIn(playhead: 0, now: 1, tempo: 10, signature: TimeSignature(4, 4)), "outside the tempo range")
        XCTAssertNil(JamCountIn(playhead: 0, now: 1, tempo: 120, signature: TimeSignature(4, 0)), "no song has it")
        XCTAssertNil(JamCountIn(playhead: 0, now: .infinity, tempo: 120, signature: TimeSignature(4, 4)))

        // The host's own audio starts 9 ms late; its first check, 80 ms on, takes that out.
        let downbeat = countIn.state.anchorTime
        guard case .nudge(let trim) = countIn.correction(heard: 3_840 + 0.080 * 1_604, atHostTime: downbeat + 0.089) else {
            return XCTFail("a late start is nudged onto the announced bar line")
        }
        XCTAssertEqual(trim, 0.009, accuracy: 1e-9)
        XCTAssertEqual(countIn.correction(heard: 3_840 + 0.088 * 1_604, atHostTime: downbeat + 0.089), .none,
                       "a millisecond is left to the phase lock")
        guard case .relock(let ticks) = countIn.correction(heard: 3_840, atHostTime: downbeat + 960.0 / 1_604) else {
            return XCTFail("a quarter note off is a jump")
        }
        XCTAssertEqual(ticks, 960, accuracy: 1e-6)
        XCTAssertEqual(countIn.correction(heard: .nan, atHostTime: downbeat), .none)

        // A phone that hears of a start more than a bar ahead comes in on that downbeat, not a bar early.
        let soon = try XCTUnwrap(JamCountIn(playhead: 0, now: 4 * bar - 0.49, tempo: 100.25, signature: TimeSignature(4, 4)))
        XCTAssertEqual(soon.state.anchorTime, 5 * bar, accuracy: 1e-9)
        let guest = try XCTUnwrap(JamTimeline(soon.state).start(afterLocal: 4 * bar - 0.48, offset: 0, lead: JamFollower.startLead))
        XCTAssertEqual(guest.hostTick, 0)
        XCTAssertEqual(guest.localTime, 5 * bar, accuracy: 1e-9)
    }

    // MARK: - Two phones, five minutes

    /// The guest's clock reads 7.3 s behind the host's and runs 40 ppm fast, its audio runs 30 ppm
    /// slow, every message takes 4 to 29 ms each way, one answer in five waits 300 ms in a queue,
    /// and the guest's audio starts 13 ms late. From two bars after it came in until the end of five
    /// minutes, the guest hears every moment within 10 ms of the host's bar phase.
    func testTwoPhonesStayWithinTenMillisecondsForFiveMinutes() {
        enum Arrival {
            case state(JamState)
            case pong(JamPong)
        }
        let tempo = 100.25
        let perSecond = tempo * Double(MusicalTime.ticksPerQuarter) / 60
        let bar = 3_840.0
        let hostStart = 2.0                                   // the host's clock reads true time
        func hostTick(_ time: Double) -> Double { Swift.max(0, (time - hostStart) * perSecond) }
        func guestClock(_ time: Double) -> Double { (time - 7.3) * (1 + 40e-6) }
        var random = JamTestRandom(seed: 11)
        func leg() -> Double { 0.004 + random.next() * 0.025 }

        var follower = JamFollower()
        var beacon = JamBeacon()
        var inbox: [(at: Double, what: Arrival)] = []
        var heard: Double?                                     // the guest's tick; nil while stopped
        var planned: JamStart?
        var startedAt: Double?
        var worst = 0.0
        var looks = 0
        var pings: UInt32 = 0
        let step = 0.005
        follower.joined(at: guestClock(0))

        func act(_ action: JamFollower.Action) {
            switch action {
            case .none: break
            case .pause: heard = nil
            case .start(let start): planned = start
            }
        }

        for index in 0..<60_000 {
            let now = Double(index) * step
            // The host checks four times a second and speaks when its beacon says so.
            if index % 50 == 0 {
                let state = JamState(tempo: tempo, signature: TimeSignature(4, 4), isPlaying: now >= hostStart,
                                     anchorTick: hostTick(now), anchorTime: now)
                if let due = beacon.due(state) { inbox.append((at: now + leg(), what: .state(due))) }
            }
            // The guest pings eight times a second at first, then twice.
            if index % (index < 200 ? 25 : 100) == 0 {
                pings &+= 1
                let out = leg()
                var back = leg()
                if pings % 5 == 0 { back += 0.300 }
                let received = now + out
                let pong = JamPong(id: pings, guestSentAt: guestClock(now), hostReceivedAt: received,
                                   hostSentAt: received + 0.0002)
                inbox.append((at: received + 0.0002 + back, what: .pong(pong)))
            }
            inbox.sort { $0.at < $1.at }
            while let first = inbox.first, first.at <= now {
                inbox.removeFirst()
                switch first.what {
                case .state(let state): act(follower.received(state, at: guestClock(now), playing: heard != nil))
                case .pong(let pong): follower.received(pong, at: guestClock(now))
                }
            }
            if index % 25 == 0 { act(follower.check(at: guestClock(now), playing: heard != nil)) }
            // The planned start: the guest's audio comes in 13 ms late.
            if let start = planned, guestClock(now) >= start.localTime + 0.013 {
                planned = nil
                heard = Double(start.songTick(loop: nil))
                startedAt = now
                follower.started(true)
            }
            if index % 50 == 25, let tick = heard {
                switch follower.correct(heard: tick, atLocal: guestClock(now)) {
                case .none: break
                case .nudge(let seconds): heard = tick + seconds * perSecond
                case .relock(let ticks): heard = tick + ticks
                }
            }
            if let tick = heard, let startedAt, now >= startedAt + 2 * bar / perSecond {
                let error = JamTimeline.phase(tick - hostTick(now), bar: bar) / perSecond
                worst = Swift.max(worst, Swift.abs(error))
                looks += 1
            }
            if let tick = heard { heard = tick + step * perSecond * (1 - 30e-6) }
        }
        XCTAssertEqual(follower.phase, .following)
        XCTAssertGreaterThan(looks, 50_000, "measured over nearly the whole five minutes")
        XCTAssertLessThanOrEqual(worst, 0.010, "the bar lines of two phones, worst moment of five minutes")
    }

    // MARK: - Three phones, one downbeat

    /// The host presses Play at 7.3 s — in the middle of a bar of the jam's grid — with two phones
    /// connected. One phone's clock reads 7.3 s behind the host's and runs 40 ppm fast, the other's
    /// 123.4 s ahead and 25 ppm slow; every message takes 4 to 29 ms each way, and one answer in
    /// five waits 300 ms in a queue. The host's audio starts 9 ms late and runs 10 ppm fast, the
    /// phones' 13 ms late and 30 ppm slow, and 4 ms early and 20 ppm fast. All three begin on the
    /// same next bar line, from bar 1, and stay within 10 ms of one another.
    func testWhenTheHostPressesPlayMidBarEveryoneBeginsOnTheSameNextBarLine() throws {
        enum Arrival {
            case state(JamState)
            case pong(JamPong)
        }
        let tempo = 100.25
        let perSecond = tempo * Double(MusicalTime.ticksPerQuarter) / 60
        let bar = 3_840.0
        let press = 7.3
        let behind = [7.3, -123.4]                            // each phone's clock reads this far behind the host's
        let fast = [40e-6, -25e-6]                            // and runs this much fast
        let late = [0.013, -0.004]                            // each phone's audio starts this late
        let drift = [10e-6, -30e-6, 20e-6]                    // the host's audio, then the phones'
        func phoneClock(_ guest: Int, _ time: Double) -> Double { (time - behind[guest]) * (1 + fast[guest]) }
        func trueTime(_ guest: Int, _ local: Double) -> Double { local / (1 + fast[guest]) + behind[guest] }
        var random = JamTestRandom(seed: 21)
        func leg() -> Double { 0.004 + random.next() * 0.025 }

        var beacon = JamBeacon()
        var followers = [JamFollower(), JamFollower()]
        var inboxes: [[(at: Double, what: Arrival)]] = [[], []]
        var heard: [Double?] = [nil, nil, nil]               // the host's tick, then the phones'; nil while stopped
        var planned: [JamStart?] = [nil, nil]
        var firstPlans: [JamStart?] = [nil, nil]
        var started: [Double?] = [nil, nil, nil]
        var trimAt: [Double?] = [nil, nil]
        var pings: [UInt32] = [0, 0]
        var countIn: JamCountIn?
        var counting = false
        var hostTrimAt: Double?
        var downbeat: Double?
        var worst = 0.0
        var looks = 0
        let step = 0.005
        for guest in 0..<2 { followers[guest].joined(at: phoneClock(guest, 0)) }

        func act(_ guest: Int, _ action: JamFollower.Action) {
            switch action {
            case .none: break
            case .pause: heard[guest + 1] = nil
            case .start(let start):
                planned[guest] = start
                if firstPlans[guest] == nil { firstPlans[guest] = start }
            }
        }

        for index in 0..<8_000 {
            let now = Double(index) * step
            // The host presses Play mid-bar: its word goes out at once, for the grid's next bar line.
            if index == Int((press / step).rounded()) {
                let announced = try XCTUnwrap(JamCountIn(playhead: 0, now: now, tempo: tempo, signature: TimeSignature(4, 4)))
                let due = try XCTUnwrap(beacon.due(announced.state))
                for guest in 0..<2 { inboxes[guest].append((at: now + leg(), what: .state(due))) }
                countIn = announced
                counting = true
                downbeat = announced.state.anchorTime
            }
            // Four times a second the host speaks — not while it counts in, nor before it held its word.
            if index % 50 == 0, countIn == nil {
                let state = JamState(tempo: tempo, signature: TimeSignature(4, 4), isPlaying: heard[0] != nil,
                                     anchorTick: heard[0] ?? 0, anchorTime: now)
                if let due = beacon.due(state) {
                    for guest in 0..<2 { inboxes[guest].append((at: now + leg(), what: .state(due))) }
                }
            }
            // The phones ask the time eight times a second at first, then twice.
            if index % (index < 200 ? 25 : 100) == 0 {
                for guest in 0..<2 {
                    pings[guest] &+= 1
                    let out = leg()
                    var back = leg()
                    if pings[guest] % 5 == 0 { back += 0.300 }
                    let received = now + out
                    let pong = JamPong(id: pings[guest], guestSentAt: phoneClock(guest, now), hostReceivedAt: received,
                                       hostSentAt: received + 0.0002)
                    inboxes[guest].append((at: received + 0.0002 + back, what: .pong(pong)))
                }
            }
            for guest in 0..<2 {
                inboxes[guest].sort { $0.at < $1.at }
                while let first = inboxes[guest].first, first.at <= now {
                    inboxes[guest].removeFirst()
                    switch first.what {
                    case .state(let state):
                        act(guest, followers[guest].received(state, at: phoneClock(guest, now), playing: heard[guest + 1] != nil))
                    case .pong(let pong):
                        followers[guest].received(pong, at: phoneClock(guest, now))
                    }
                }
                if index % 25 == 0 {
                    act(guest, followers[guest].check(at: phoneClock(guest, now), playing: heard[guest + 1] != nil))
                }
            }
            // The host's audio starts 9 ms after the bar line it announced; 80 ms on it trims itself onto it.
            if counting, let announced = countIn, now >= announced.state.anchorTime + 0.009 {
                counting = false
                heard[0] = announced.state.anchorTick
                started[0] = now
                hostTrimAt = now + 0.08
            }
            if !counting, let announced = countIn, let trimTime = hostTrimAt, now >= trimTime, let tick = heard[0] {
                switch announced.correction(heard: tick, atHostTime: now) {
                case .none: break
                case .nudge(let seconds): heard[0] = tick + seconds * perSecond
                case .relock(let ticks): heard[0] = tick + ticks
                }
                countIn = nil
                hostTrimAt = nil
            }
            // The phones' audio starts as planned, late or early; their first check is 80 ms on,
            // then one every quarter second.
            for guest in 0..<2 {
                if let start = planned[guest], phoneClock(guest, now) >= start.localTime + late[guest] {
                    planned[guest] = nil
                    heard[guest + 1] = Double(start.songTick(loop: nil))
                    started[guest + 1] = now
                    followers[guest].started(true)
                    trimAt[guest] = now + 0.08
                }
                guard let tick = heard[guest + 1] else { continue }
                let trimming = trimAt[guest].map { now >= $0 } ?? false
                guard trimming || index % 50 == 25 else { continue }
                if trimming { trimAt[guest] = nil }
                switch followers[guest].correct(heard: tick, atLocal: phoneClock(guest, now)) {
                case .none: break
                case .nudge(let seconds): heard[guest + 1] = tick + seconds * perSecond
                case .relock(let ticks): heard[guest + 1] = tick + ticks
                }
            }
            // From half a second after the downbeat: each phone's distance from the grid's bar line.
            if let downbeat, now >= downbeat + 0.5, now <= 39 {
                let ticks = heard.compactMap { $0 }
                if ticks.count == 3, started.allSatisfy({ $0 != nil }) {
                    let phases = ticks.map { (tick: Double) -> Double in
                        JamTimeline.phase(tick - (now - downbeat) * perSecond, bar: bar) / perSecond
                    }
                    for first in 0..<3 {
                        for second in (first + 1)..<3 {
                            worst = Swift.max(worst, Swift.abs(phases[first] - phases[second]))
                        }
                    }
                    looks += 1
                }
            }
            for phone in 0..<3 {
                if let tick = heard[phone] { heard[phone] = tick + step * perSecond * (1 + drift[phone]) }
            }
        }
        let beat = try XCTUnwrap(downbeat)
        for guest in 0..<2 {
            let plan = try XCTUnwrap(firstPlans[guest])
            XCTAssertEqual(plan.hostTick, 0, "phone \(guest + 1) comes in on the announced downbeat: the host's bar 1")
            XCTAssertEqual(trueTime(guest, plan.localTime), beat, accuracy: 0.008, "and knows when it falls")
        }
        for phone in 0..<3 {
            XCTAssertEqual(try XCTUnwrap(started[phone]), beat, accuracy: 0.03, "nobody a bar early or late")
        }
        XCTAssertEqual(heard.compactMap { $0 }.count, 3, "all three play")
        XCTAssertEqual(followers.map(\.phase), [.following, .following])
        XCTAssertGreaterThan(looks, 5_000, "measured over half a minute")
        XCTAssertLessThanOrEqual(worst, 0.010, "the bar lines of three phones, worst moment")
    }
}
