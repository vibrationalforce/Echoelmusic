import EchoelCore
import SwiftUI

extension View {
    /// The names Voice Control answers to for a key that shows a short form: what the key shows
    /// first, then the action's word, then its spoken name (`Spoken.voiceNames`). `spoken` is the
    /// key's `accessibilityLabel`, so Voice Control and VoiceOver know the key by the same name.
    func voiceNames(shown: String, word: String = "", spoken: String) -> some View {
        accessibilityInputLabels(Spoken.voiceNames(shown: shown, word: word, spoken: spoken).map { Text(verbatim: $0) })
    }
}
