#if canImport(SwiftUI)
import SwiftUI

/// GMMW AI-2 — what Echoel did for a request from Siri or Shortcuts, and the way back.
///
/// ⭐ EVERY AGENT CHANGE IS VISIBLE AND REVERSIBLE. The notice comes from the ONE desk
/// (`EchoelAgentDesk.shared`) that ran the request: done ("Bass: −6.0 dB → −9.0 dB."), refused (the
/// selection changed since), failed, or dropped (waited too long, unreadable). While the agent has a
/// change it can take back, "Undo Echoel's last change" runs `agent.undoLast` through the same desk —
/// the same path as the request itself, and it keeps any value a person changed since.
///
/// ⚠️ ITS OWN LEAF, ON PURPOSE (10.76.41/50 law): it is mounted in the ROOT (`WorkspaceView`), above
/// every menu host. It reads `notice` and `isWorking` in THIS body only; both change once or twice per
/// request, never on a clock, and the root body reads neither.
///
/// ⚠️ NO PRESENTATION MODIFIER. It is a status row in the root's column, beside
/// `ProjectSaveStatusView` and `WorkingCopyStatusView` — the sheet chain is untouched.
///
/// It stays until it is closed or the next request replaces it — a notice that hides itself on a
/// timer could be gone before a person who needs longer has read it.
struct AgentReportBanner: View {
    private var desk: EchoelAgentDesk { EchoelAgentDesk.shared }

    var body: some View {
        if let notice = desk.notice {
            VStack(alignment: .leading, spacing: EchoelTheme.spaceXS) {
                HStack(alignment: .firstTextBaseline, spacing: EchoelTheme.spaceS) {
                    Label(Self.title(notice.state), systemImage: Self.symbol(notice.state))
                        .font(EchoelTheme.font(15, .semibold))
                    Spacer(minLength: 0)
                    Button("Close") { desk.dismiss() }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                        .accessibilityHint("Hides this notice. Changes nothing in the piece.")
                }
                if !notice.message.isEmpty {
                    Text(notice.message)
                        .font(EchoelTheme.font(13))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if notice.canUndo {
                    Button("Undo Echoel's last change") {
                        Task { await desk.undoLast() }
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .disabled(desk.isWorking)
                    .accessibilityHint("Undoes only what Echoel changed for you. A value you changed since is kept.")
                }
            }
            .foregroundStyle(EchoelTheme.text)
            .padding(EchoelTheme.spaceS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoelTheme.surface)
            .accessibilityElement(children: .contain)
        }
    }

    /// GMMW AI-4 — the ONE place the on-device model is constructed for a person: the ≡ menu's
    /// "Describe this piece" Button calls this, and only that tap does. The answer lands in this
    /// banner as a notice; no modal, nothing in the piece changes.
    static func describePiece() {
        Task { await EchoelAgentDesk.shared.describePiece(with: FoundationModelsBrain()) }
    }

    /// "Echoel: Done", "Echoel: Failed" … — whose notice it is, then the state's own word.
    static func title(_ state: EchoelAgentState) -> String {
        "Echoel: \(state.title)"
    }

    static func symbol(_ state: EchoelAgentState) -> String {
        switch state {
        case .done: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        case .needsAnswer: return "questionmark.circle"
        case .understood, .running: return "ellipsis.circle"
        }
    }
}
#endif
