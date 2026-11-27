import EchoelCore
import SwiftUI

/// The device's choice of how times and slow rates read (`TimeReading`): note values unless the
/// musician picks seconds, milliseconds or hertz. Kept on this device, never in a song.
enum TimeReadingSetting {
    static let key = "values.timeReading"

    /// The reading a stored raw value names; the standard for none or an unknown one.
    static func reading(_ raw: String) -> TimeReading { TimeReading(rawValue: raw) ?? .standard }
}

/// The long-press choices of a time or a rate: how such values read, and a note value to set
/// exactly at the song's tempo. `set` writes the value chosen.
struct TimeReadingMenu: View {
    let unit: ParameterUnit
    let range: ClosedRange<Double>
    let bpm: Double
    let set: (Double) -> Void
    @AppStorage(TimeReadingSetting.key) private var stored = TimeReading.standard.rawValue

    var body: some View {
        Picker("Show Times As", selection: $stored) {
            ForEach(TimeReading.allCases, id: \.self) { (reading: TimeReading) in
                Text(reading.title).tag(reading.rawValue)
            }
        }
        let grid = ParameterText.noteGrid(unit: unit, range: range, bpm: bpm)
        if !grid.isEmpty {
            Menu("Set to Note Value") {
                ForEach(grid, id: \.note) { (entry: (note: NoteValue, value: Double)) in
                    Button(entry.note.name) { set(entry.value) }
                }
            }
        }
    }
}
