import Foundation
import XCTest
@testable import EchoelCore

/// The Instrument page puts the sound the keys play before the body (SIMP-6, A88-1). While no body
/// source is on, the Body Voice is off and the tempo is Fixed, the body is one row; any of the three
/// on brings the body's cards back, and the safety sentence stands under the pulse exactly while a
/// source is on.
final class InstrumentPageTests: XCTestCase {
    func testWithTheBodyOffThePageIsTheFieldTheSoundAndOneBodyRow() {
        XCTAssertEqual(InstrumentPage.sections(bodySourceOn: false, bodyVoiceOn: false, flows: false),
                       [.field, .sound, .bodyRow])
    }

    func testTheSoundTheKeysPlayComesBeforeTheBodyInEveryState() {
        for state in Self.everyState() {
            let shown = page(state)
            XCTAssertEqual(Array(shown.prefix(2)), [.field, .sound], "\(state)")
            XCTAssertFalse(shown.dropFirst(2).contains(.field), "\(state)")
            XCTAssertFalse(shown.dropFirst(2).contains(.sound), "\(state)")
        }
    }

    func testASourceOnBringsThePulseWithTheSafetySentenceTheBodyVoiceAndTheTempo() {
        for state in Self.everyState() where state.sourceOn {
            XCTAssertEqual(page(state), [.field, .sound, .pulse(showsSafety: true), .bodyVoice, .tempo], "\(state)")
        }
    }

    func testTheBodyVoiceOnWithoutASourceKeepsItsCardBesideTheChooser() {
        XCTAssertEqual(InstrumentPage.sections(bodySourceOn: false, bodyVoiceOn: true, flows: false),
                       [.field, .sound, .pulse(showsSafety: false), .bodyVoice, .tempo])
    }

    func testFlowWithoutASourceKeepsTheTempoLockBesideTheChooser() {
        XCTAssertEqual(InstrumentPage.sections(bodySourceOn: false, bodyVoiceOn: false, flows: true),
                       [.field, .sound, .pulse(showsSafety: false), .bodyVoice, .tempo])
    }

    func testTheSafetySentenceStandsUnderThePulseExactlyWhileASourceIsOn() {
        for state in Self.everyState() {
            XCTAssertEqual(page(state).contains(.pulse(showsSafety: true)), state.sourceOn, "\(state)")
        }
    }

    func testTheBodyRowStandsAloneAndOnlyWhileEverythingIsOff() {
        for state in Self.everyState() {
            let shown = page(state)
            let allOff = !state.sourceOn && !state.voiceOn && !state.flows
            XCTAssertEqual(shown.contains(.bodyRow), allOff, "\(state)")
            if shown.contains(.bodyRow) {
                XCTAssertFalse(showsPulse(shown), "the row never stands beside the pulse card: \(state)")
                XCTAssertFalse(shown.contains(.bodyVoice), "\(state)")
                XCTAssertFalse(shown.contains(.tempo), "\(state)")
            }
        }
    }

    /// The chooser, the Body Voice switch and the tempo lock are on the page in every state: behind
    /// the body row, or each on its card. And whatever the musician has on shows on its own card.
    func testEveryBodyControlStaysOnThePageInEveryState() {
        for state in Self.everyState() {
            let shown = page(state)
            let cards = showsPulse(shown) && shown.contains(.bodyVoice) && shown.contains(.tempo)
            XCTAssertTrue(shown.contains(.bodyRow) || cards, "\(state)")
            if state.sourceOn { XCTAssertTrue(showsPulse(shown), "\(state)") }
            if state.voiceOn { XCTAssertTrue(shown.contains(.bodyVoice), "\(state)") }
            if state.flows { XCTAssertTrue(shown.contains(.tempo), "\(state)") }
        }
    }

    /// The page draws the lead and the body's part in two places, so the body's part never holds a
    /// section of the lead, and the two together are the page.
    func testTheBodysPartNeverRepeatsTheLead() {
        XCTAssertEqual(InstrumentPage.lead, [.field, .sound])
        for state in Self.everyState() {
            let bodyPart = InstrumentPage.bodySections(bodySourceOn: state.sourceOn, bodyVoiceOn: state.voiceOn,
                                                       flows: state.flows)
            XCTAssertFalse(bodyPart.contains(.field), "\(state)")
            XCTAssertFalse(bodyPart.contains(.sound), "\(state)")
            XCTAssertEqual(InstrumentPage.lead + bodyPart, page(state), "\(state)")
        }
    }

    func testNoSectionShowsTwice() {
        for state in Self.everyState() {
            let shown = page(state)
            XCTAssertEqual(Set(shown).count, shown.count, "\(state)")
            let pulses = shown.filter { (section: InstrumentPage.Section) -> Bool in
                if case .pulse = section { return true }
                return false
            }
            XCTAssertLessThanOrEqual(pulses.count, 1, "\(state)")
        }
    }

    // MARK: Helpers

    /// What the page is told: a body source on or not, the Body Voice on or not, the lock on Flow
    /// or Fixed.
    private struct BodyState {
        let sourceOn: Bool
        let voiceOn: Bool
        let flows: Bool
    }

    /// All eight states.
    private static func everyState() -> [BodyState] {
        var states: [BodyState] = []
        for sourceOn in [false, true] {
            for voiceOn in [false, true] {
                for flows in [false, true] {
                    states.append(BodyState(sourceOn: sourceOn, voiceOn: voiceOn, flows: flows))
                }
            }
        }
        return states
    }

    private func page(_ state: BodyState) -> [InstrumentPage.Section] {
        InstrumentPage.sections(bodySourceOn: state.sourceOn, bodyVoiceOn: state.voiceOn, flows: state.flows)
    }

    private func showsPulse(_ shown: [InstrumentPage.Section]) -> Bool {
        shown.contains { (section: InstrumentPage.Section) -> Bool in
            if case .pulse = section { return true }
            return false
        }
    }
}
