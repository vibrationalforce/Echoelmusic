import EchoelEngine
import SwiftUI

/// MIDI Time Code in the Song menu's Connect section (W17-TC): send it, its rate and start, the
/// outputs it goes to, and the source to chase. Everything is off until chosen here. A leaf: it
/// reads only settings that change when the musician picks one (Law 6).
struct TimecodeMenu: View {
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        Menu("Timecode (MTC)", systemImage: "clock.badge.checkmark") {
            Toggle(isOn: Binding(get: { engine.timecode.isOn }, set: { engine.timecode.setOn($0) })) {
                Label("Send MTC", systemImage: "arrow.up.forward")
            }
            rateMenu
            startMenu
            outputsMenu
            chaseMenu
        }
    }

    private var rateMenu: some View {
        Menu("Rate: \(engine.timecode.rate.title)") {
            ForEach(MTCOutput.rates, id: \.self) { rate in
                Button { engine.timecode.setRate(rate) } label: {
                    choice(rate.title, chosen: engine.timecode.rate == rate)
                }
            }
        }
    }

    private var startMenu: some View {
        Menu("Song Starts at \(engine.timecode.start.text(rate: engine.timecode.rate))") {
            ForEach(MTCOutput.hours, id: \.self) { hour in
                Button { engine.timecode.setStartHour(hour) } label: {
                    choice(Timecode(hours: hour, minutes: 0, seconds: 0, frames: 0).text(rate: engine.timecode.rate),
                           chosen: engine.timecode.startHour == hour)
                }
            }
        }
    }

    /// The virtual source "Echoel Timecode" always carries it; these are the outputs besides it.
    private var outputsMenu: some View {
        Menu("Also Send To") {
            ForEach(engine.timecode.destinations) { destination in
                Button { engine.timecode.toggle(destination) } label: {
                    choice(destination.name, chosen: engine.timecode.isChosen(destination))
                }
            }
        }
        .disabled(!engine.timecode.isOn || engine.timecode.destinations.isEmpty)
    }

    /// One external clock at a time: while a MIDI clock or a jam's host sets the pace, this waits.
    private var chaseMenu: some View {
        Menu("Chase MTC") {
            Button { engine.timecodeChase.chase(nil) } label: {
                choice("Off", chosen: engine.timecodeChase.chased == nil)
            }
            ForEach(engine.timecodeChase.sources) { source in
                Button { engine.timecodeChase.chase(source.id) } label: {
                    choice(source.name, chosen: engine.timecodeChase.chased == source.id)
                }
            }
        }
        .disabled(engine.followsExternalClock)
    }

    @ViewBuilder
    private func choice(_ title: String, chosen: Bool) -> some View {
        if chosen { Label(title, systemImage: "checkmark") } else { Text(title) }
    }
}
