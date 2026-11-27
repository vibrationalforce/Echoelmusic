import Foundation

/// The sections of the Instrument page, top to bottom (SIMP-6, A88-1). The Field comes first, then
/// the sound and mood of the track the keys play, then the body: the page is for playing, and the
/// body is an optional source of modulation, so the sound the keys play is never below it.
///
/// While no body source is on, the Body Voice is off and the tempo is Fixed, nothing of the body
/// sounds, moves the tempo or is measured, so the body is one row that holds its controls. As soon
/// as any of the three is on, the body's cards return: the pulse with the body-source chooser, the
/// Body Voice, the tempo lock. The pulse card comes back with the Body Voice or Flow even without a
/// source, because both wait for one, and the chooser belongs next to what waits for it.
///
/// The safety sentence stands under the pulse while a source is on, which is when something is
/// measured. It also heads the body-source chooser's choices, where a source is chosen.
///
/// The body row is "Body: Off" on the page (`StudioPlace.bodyOff`, so Learn quotes the name the
/// row shows): a Learn path to a control the row holds goes through the row too.
///
/// The page comes in two parts because it is read in two places: the lead never depends on the
/// body, and the body's part is read where the body sources are, so a source finding its signal
/// redraws the body's part alone. Pure, so the page's order is tested here.
public enum InstrumentPage {
    /// One section of the page.
    public enum Section: Hashable, Sendable {
        /// The Field.
        case field
        /// The sound and mood of the track the keys play.
        case sound
        /// The body in one row while nothing of it is on, holding the body-source chooser, the Body
        /// Voice switch and the tempo lock.
        case bodyRow
        /// The pulse and the body-source chooser. `showsSafety`: the safety sentence stands under
        /// the pulse.
        case pulse(showsSafety: Bool)
        /// The Body Voice: its switch, what it does and its routes.
        case bodyVoice
        /// The tempo lock, Fixed or Flow, and what Flow does now.
        case tempo
    }

    /// What leads the page in every state: the Field, then the sound and mood of the track the keys
    /// play.
    public static let lead: [Section] = [.field, .sound]

    /// The body's sections, under the lead. `bodySourceOn`: a body source is on (the chest strap, the
    /// camera, Apple Health or Phone Motion). `bodyVoiceOn`: the Body Voice sounds. `flows`: the tempo
    /// lock stands on Flow. One row while none of the three is on; else the pulse, the Body Voice and
    /// the tempo lock, with the safety sentence under the pulse while a source is on.
    public static func bodySections(bodySourceOn: Bool, bodyVoiceOn: Bool, flows: Bool) -> [Section] {
        guard bodySourceOn || bodyVoiceOn || flows else { return [.bodyRow] }
        return [.pulse(showsSafety: bodySourceOn), .bodyVoice, .tempo]
    }

    /// The whole page, top to bottom: the lead, then the body's sections.
    public static func sections(bodySourceOn: Bool, bodyVoiceOn: Bool, flows: Bool) -> [Section] {
        lead + bodySections(bodySourceOn: bodySourceOn, bodyVoiceOn: bodyVoiceOn, flows: flows)
    }
}
