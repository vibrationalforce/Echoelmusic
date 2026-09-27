// TheAgentAppliesTheLookOfTheOpenPhotoTests.swift
// EchoelAI step 2b (founder addendum 2026-09-27): "Nutze die Farben dieses Fotos für die Visuals."
// `media.applyLook` gives the visuals the look of the photo (or video) that is open on its card —
// through `MediaLookUndo`, the owner the card's Apply uses — and the agent's Undo takes it back
// only while it is still the applied look, keeping a setting a person moved since.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–4 are END-TO-END on the shipped executor with a fresh `MediaLookUndo` (never
//     `.shared`) and a private `UserDefaults` suite. The song is only READ here.
//   · Claim 5 drives the shipped parser.
//   · NOT covered: a card changing its photo BETWEEN two steps of one request (the yield order is
//     not deterministic in a test; the guard is two lines, transcribed), and anything a person
//     sees — no agent surface exists yet. DEVICE PROBE, open.
//
// HONEST GRADING against the parent (9132870a9, §3): the file does not COMPILE there — it names
// `applyMediaLook` and the executor's new initialiser, which this commit creates — ONE absence
// (#486); every claim is a FORWARD guard. Hand-transcribed in Python over a model of the owner and
// the per-value undo; mutants driven, each red for its named reason: the executor writing the look
// itself instead of through the owner (claim 1, the card's look differs), applying while a look is
// pending (claim 2), applying a photo the card no longer shows (claim 3), an undo that reverts a
// setting the person moved (claim 4), an undo that writes again after the card's Undo (claim 4),
// an unknown argument dropped (claim 5).
// Review repair (MED-2, LOW-1, LOW-4) added claim 6 and changed claim 4's report: mutants — undo
// asked by value only (claim 6, the person's Apply is taken back), a partly kept look counted as
// nothing restored (claim 4), a setting moved back reported as kept (claim 6), a grey photo
// reported as "colours" (claim 6).
// Review repair 2c: the two "the card already took it back" cases in claims 4 and 6 now read
// "My last change had already been taken back." (they used to claim a fresh Undo); `partlyUndone`
// carries `alreadyUndone:`. Mutant: an absent pending look counted as restored → both red.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheAgentAppliesTheLookOfTheOpenPhotoTests: XCTestCase {

    private let look = VisualLookSnapshot(intensity: 1, detail: 40, motion: 1, spread: 1, hue: 0.1,
                                          saturation: 1.05, presetID: "vapor")

    private func photo(brightness: Double) -> MediaSeed {
        MediaSeed(version: MediaSeed.formatVersion, hue: 0.6, dominantRed: 0.2, dominantGreen: 0.3,
                  dominantBlue: 0.8, brightness: brightness, saturation: 0.7, contrast: 0.5,
                  hasDominantColour: true, sampledPixels: 64)
    }

    private func greyPhoto() -> MediaSeed {
        MediaSeed(version: MediaSeed.formatVersion, hue: 0, dominantRed: 0.5, dominantGreen: 0.5,
                  dominantBlue: 0.5, brightness: 0.5, saturation: 0.05, contrast: 0.4,
                  hasDominantColour: false, sampledPixels: 64)
    }

    private func video(motion: Double) -> VideoSeed {
        VideoSeed(version: VideoSeed.formatVersion, durationSeconds: 4, frameRate: 30, brightness: 0.5,
                  hue: 0.25, saturation: 0.5, hasDominantColour: true, motionEnergy: motion,
                  transientTimes: [1], sampledFrames: 16)
    }

    private func suite() throws -> UserDefaults {
        let name = "echoel.tests.agentMediaLook.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        look.write(to: defaults)
        return defaults
    }

    private func rig() throws -> (TimelineStore, EchoelCommandExecutor, MediaLookUndo, UserDefaults) {
        let defaults = try suite()
        let owner = MediaLookUndo()
        let timeline = TimelineStore()
        let executor = EchoelCommandExecutor(timeline: timeline, selection: WorkstationSelection(),
                                             voiceCapacity: { 4 }, mediaLooks: owner, visualDefaults: defaults)
        return (timeline, executor, owner, defaults)
    }

    private func plan(_ steps: [EchoelCommand], on executor: EchoelCommandExecutor) -> EchoelActionPlan {
        EchoelActionPlan(requestID: UUID(), steps: steps, basis: executor.snapshot(), consents: [])
    }

    // MARK: 1 — the open photo's look, written by the card's owner, and the agent's Undo

    func testTheOpenPhotoIsAppliedThroughTheCardsOwner() async throws {
        let (timeline, executor, owner, defaults) = try rig()
        let song = timeline.document
        owner.showPhoto(photo(brightness: 0.9))
        XCTAssertTrue(EchoelStateText.describe(executor.snapshot()).contains("A photo is open on its card."))

        let report = await executor.execute(plan([.applyMediaLook(medium: .photo)], on: executor))
        XCTAssertEqual(report.steps.first?.outcome, .done("The visuals now use the colours of the photo."))
        let applied = try XCTUnwrap(owner.pending, "the look and its way back are recorded by the owner")
        XCTAssertEqual(owner.medium, "photo")
        XCTAssertEqual(applied.before, look)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), applied.after)

        // The card's Apply on the same look gives the same result — one path, not a second writer.
        let other = try suite()
        XCTAssertEqual(MediaSeedApplication.apply(photo(brightness: 0.9), to: other), applied)
        XCTAssertEqual(timeline.document, song, "a look changes the visuals, never the song")
        XCTAssertTrue(EchoelStateText.describe(executor.snapshot()).contains("The visuals use the look of a photo."))

        let undo = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(undo.steps.first?.outcome, .done("Took back my last change."))
        XCTAssertNil(owner.pending)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), look)
        XCTAssertFalse(executor.canUndoAgentChange)
    }

    // MARK: 2 — nothing open, or a look still applied: nothing is written, and it says why

    func testNothingOpenOrALookStillAppliedChangesNothing() async throws {
        let (_, executor, owner, defaults) = try rig()
        let none = await executor.execute(plan([.applyMediaLook(medium: .photo)], on: executor))
        XCTAssertEqual(none.steps.first?.outcome, .failed(.nothingShown(.photo)))
        let noVideo = await executor.execute(plan([.applyMediaLook(medium: .video)], on: executor))
        XCTAssertEqual(noVideo.steps.first?.outcome, .failed(.nothingShown(.video)))
        XCTAssertEqual(EchoelCommandError.nothingShown(.video).message, "No video is open. Pick one on its card first.")
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), look)

        // The person applies a photo on its card; the agent is asked for the video's look.
        owner.showPhoto(photo(brightness: 0.4))
        owner.showVideo(video(motion: 0.5))
        let byHand = try XCTUnwrap(owner.apply(photo: photo(brightness: 0.4), on: defaults))
        let refused = await executor.execute(plan([.applyMediaLook(medium: .video)], on: executor))
        XCTAssertEqual(refused.steps.first?.outcome, .failed(.lookStillApplied("photo")))
        XCTAssertEqual(EchoelCommandError.lookStillApplied("photo").message,
                       "The visuals still use the look of a photo. Take that back first.")
        XCTAssertEqual(owner.pending, byHand, "the person's look stays the one to take back")
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), byHand.after)
        XCTAssertFalse(executor.canUndoAgentChange, "the agent has nothing of its own to take back")
    }

    // MARK: 3 — "this photo" is the one the card showed when the plan was made

    func testAChangedCardIsAChangedProject() async throws {
        let (_, executor, owner, defaults) = try rig()
        owner.showPhoto(photo(brightness: 0.9))
        let seen = plan([.applyMediaLook(medium: .photo)], on: executor)
        owner.showPhoto(photo(brightness: 0.1))
        let swapped = await executor.execute(seen)
        XCTAssertEqual(swapped.refusal, .projectChanged, "another photo is on the card now — not applied")

        let seenAgain = plan([.applyMediaLook(medium: .photo)], on: executor)
        owner.showPhoto(nil)
        let gone = await executor.execute(seenAgain)
        XCTAssertEqual(gone.refusal, .projectChanged)
        XCTAssertNil(owner.pending)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), look)

        // A reading the look cannot use writes nothing and is named as such.
        owner.showVideo(video(motion: 3))
        let implausible = await executor.execute(plan([.applyMediaLook(medium: .video)], on: executor))
        XCTAssertEqual(implausible.steps.first?.outcome, .failed(.invalidArgument("that video's reading")))
        XCTAssertNil(owner.pending)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), look)
    }

    // MARK: 4 — the agent's Undo keeps what a person moved, and respects the card's Undo

    func testTheAgentsUndoKeepsWhatThePersonMovedAndRespectsTheCardsUndo() async throws {
        let (_, executor, owner, defaults) = try rig()
        owner.showPhoto(photo(brightness: 0.9))
        _ = await executor.execute(plan([.applyMediaLook(medium: .photo)], on: executor))
        let applied = try XCTUnwrap(owner.pending)

        // The person moves one setting by hand after the agent's edit.
        let moved = applied.after.intensity == 0.3 ? 0.4 : 0.3
        var byHand = VisualLookSnapshot.read(from: defaults)
        byHand.intensity = moved
        byHand.write(to: defaults)
        let kept = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(kept.steps.first?.outcome,
                       .failed(.partlyUndone(restored: 1, alreadyUndone: 0, kept: "The visual intensity")),
                       "the rest went back, and the one setting the person moved is named (review LOW-1)")
        var expected = look
        expected.intensity = moved
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), expected,
                       "every other setting is back; the one the person moved is theirs")
        XCTAssertNil(owner.pending)

        // The agent applies the video's look; the person takes it back on the card; the agent's
        // Undo then has nothing left to do and writes nothing.
        expected.write(to: defaults)
        owner.showVideo(video(motion: 0.5))
        _ = await executor.execute(plan([.applyMediaLook(medium: .video)], on: executor))
        XCTAssertEqual(owner.medium, "video")
        owner.undo(on: defaults)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), expected)
        var later = expected
        later.hue = 0.77
        later.write(to: defaults)
        let already = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(already.steps.first?.outcome, .done("My last change had already been taken back."),
                       "the card's Undo took it back — said as such, not as a fresh Undo (review repair 2c)")
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), later, "nothing was written again")
    }

    // MARK: 6 — review repairs: an equal look applied by hand is the person's; a setting moved back
    //           by hand is not "kept"; a grey photo does not claim its colours

    func testAnEqualLookAppliedByHandIsThePersonsAndGreyIsSaidPlainly() async throws {
        let (_, executor, owner, defaults) = try rig()
        owner.showPhoto(photo(brightness: 0.9))
        _ = await executor.execute(plan([.applyMediaLook(medium: .photo)], on: executor))
        let agents = try XCTUnwrap(owner.pending)
        owner.undo(on: defaults)
        let persons = try XCTUnwrap(owner.apply(photo: photo(brightness: 0.9), on: defaults))
        XCTAssertEqual(persons, agents, "the same photo on the same look is an EQUAL value")
        let undo = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(undo.steps.first?.outcome, .done("My last change had already been taken back."),
                       "the agent's look went with the card's Undo; the equal look now applied is the person's")
        XCTAssertEqual(owner.pending, persons, "the person's own Apply is not taken back (review MED-2)")
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), persons.after)
        owner.undo(on: defaults)

        // The person moves a setting away and back again: nothing is kept, all of it is back.
        _ = await executor.execute(plan([.applyMediaLook(medium: .photo)], on: executor))
        var away = VisualLookSnapshot.read(from: defaults)
        away.intensity = look.intensity
        away.write(to: defaults)
        let back = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(back.steps.first?.outcome, .done("Took back my last change."))
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), look)

        owner.showPhoto(greyPhoto())
        let grey = await executor.execute(plan([.applyMediaLook(medium: .photo)], on: executor))
        XCTAssertEqual(grey.steps.first?.outcome,
                       .done("The visuals now use the look of the photo. It has no main colour, so the hue stays."))
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults).hue, look.hue)
    }

    // MARK: 5 — the proposal names a medium, and nothing else

    func testTheProposalNamesAMediumAndNothingElse() {
        func parse(_ arguments: [String: String]) -> Result<EchoelCommand, EchoelCommandError> {
            EchoelCommandParser.parse(EchoelProposedAction(command: "media.applyLook", arguments: arguments))
        }
        XCTAssertEqual(parse(["medium": "photo"]), .success(.applyMediaLook(medium: .photo)))
        XCTAssertEqual(parse(["medium": "video"]), .success(.applyMediaLook(medium: .video)))
        XCTAssertEqual(parse([:]), .failure(.invalidArgument("the medium — photo or video")))
        XCTAssertEqual(parse(["medium": "picture"]), .failure(.invalidArgument("the medium — photo or video")))
        XCTAssertEqual(parse(["medium": "photo", "file": "/private/x.jpg"]), .failure(.unknownArgument("file")),
                       "a file path in a proposal is data; it cannot pick a different photo")
        let spec = EchoelCommandRegistry.spec(.applyMediaLook)
        XCTAssertEqual(spec.permission, .reversibleEdit)
        XCTAssertEqual(spec.undo, .agentJournal)
    }
}
