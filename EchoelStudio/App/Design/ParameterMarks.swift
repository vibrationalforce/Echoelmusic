import EchoelCore
import SwiftUI

/// Whether a value is moved by something other than the hand (audit A3 #2; Michael on 10083):
/// automated — the song has a lane for it, so what plays is the lane, not the stored value — or
/// modulated by a route that is on. Shown as letters in a frame, "A" and "M", so the mark is a shape
/// and never a colour alone, and said by VoiceOver after the value. Read from the document, never
/// from the playhead (Law 6).
enum ParameterMarks {
    static func automated(_ address: ParameterAddress, in project: Project) -> Bool {
        project.automation(for: address)?.points.isEmpty == false
    }

    static func modulated(_ address: ParameterAddress, in project: Project) -> Bool {
        project.modRoutes.contains { $0.target == address && $0.enabled }
    }

    /// ", automated, modulated" — what VoiceOver adds to the value.
    static func spoken(_ address: ParameterAddress, in project: Project) -> String {
        var parts: [String] = []
        if automated(address, in: project) { parts.append("automated") }
        if modulated(address, in: project) { parts.append("modulated") }
        return parts.isEmpty ? "" : ", " + parts.joined(separator: ", ")
    }
}

/// The "A" and "M" letters for one parameter, side by side; nothing when neither applies.
struct ParameterMarkBadges: View {
    @Environment(ProjectStore.self) private var store
    let address: ParameterAddress

    var body: some View {
        let project = store.project
        HStack(spacing: 2) {
            if ParameterMarks.automated(address, in: project) { badge("A") }
            if ParameterMarks.modulated(address, in: project) { badge("M") }
        }
        .accessibilityHidden(true)
    }

    private func badge(_ letter: String) -> some View {
        Text(letter)
            .font(Theme.Font.caption.weight(.semibold))
            .foregroundStyle(Theme.Color.accent)
            .padding(.horizontal, 3)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.Color.accent, lineWidth: 1))
    }
}
