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
/// every menu host. It reads `notice`, `isWorking`, `isDescribing` and `pendingProposal` in THIS body only; both change once or twice per
/// request, never on a clock, and the root body reads neither.
///
/// ⚠️ NO PRESENTATION MODIFIER. It is a status row in the root's column, beside
/// `ProjectSaveStatusView` and `WorkingCopyStatusView` — the sheet chain is untouched.
///
/// It stays until it is closed or the next request replaces it — a notice that hides itself on a
/// timer could be gone before a person who needs longer has read it.
///
/// GSIDMMW C2c — the ≡ menu's "Ask Echoel" opens `AgentRequestRow` above the notice: a request
/// typed in the app takes the same road as one spoken to Siri (`ask`), and the model still only
/// proposes. An inline row, not a modal: the root's presentation chain is untouched.
struct AgentReportBanner: View {
    private var desk: EchoelAgentDesk { EchoelAgentDesk.shared }

    var body: some View {
        if desk.isTypingRequest {
            AgentRequestRow()
        }
        if let notice = desk.notice {
            VStack(alignment: .leading, spacing: EchoelTheme.spaceXS) {
                HStack(alignment: .firstTextBaseline, spacing: EchoelTheme.spaceS) {
                    Label(Self.title(notice.state), systemImage: Self.symbol(notice.state))
                        .font(EchoelTheme.font(15, .semibold))
                    Spacer(minLength: 0)
                    if desk.isDescribing {
                        Button("Stop") { desk.stopDescribe() }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                            .accessibilityHint("Stops waiting for the on-device model. Changes nothing in the piece.")
                    }
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
                if desk.pendingProposal != nil {
                    HStack(spacing: EchoelTheme.spaceS) {
                        Button("Apply") {
                            Task { await desk.applyProposal() }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                        .disabled(desk.isWorking)
                        .accessibilityHint("Makes the change Echoel proposed. Echoel's Undo takes it back.")
                        Button("Discard") { desk.discardProposal() }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                            .accessibilityHint("Drops the proposal. Changes nothing in the piece.")
                    }
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

    /// GMMW AI-4 — the ≡ menu's "Describe this piece" Button calls this, and only that tap does.
    /// The answer lands in this banner as a notice; no modal, nothing in the piece changes.
    static func describePiece() {
        Task { await EchoelAgentDesk.shared.describePiece(with: onDeviceBrain()) }
    }

    /// GSIDMMW C2b/C2c — "Ask Echoel" calls this from two doors, both the person's own words: the
    /// intent (Siri, Shortcuts, Spotlight) and the banner's typed row. The model only PROPOSES: the plan lands in this banner with Apply and Discard, and
    /// nothing in the piece changes until the person taps Apply (`EchoelAgentDesk.proposePlan`).
    static func ask(_ request: String) async {
        await EchoelAgentDesk.shared.proposePlan(for: request, with: onDeviceBrain())
    }

    /// The ONE production construction of the on-device model. Its two callers are above — a tap
    /// and a request the person spoke or typed — and neither changes the piece by itself.
    private static func onDeviceBrain() -> any BrainBackend {
        FoundationModelsBrain()
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

/// GSIDMMW C2c — the typed request: one line, Ask and Cancel. Its own leaf so the draft's
/// keystrokes rebuild only this row. Ask is off while the model is busy or the request is empty;
/// the draft is cut to what the planner reads (`EchoelModelPlanner.requestLimit`).
private struct AgentRequestRow: View {
    @State private var draft = ""
    @FocusState private var focused: Bool
    private var desk: EchoelAgentDesk { EchoelAgentDesk.shared }

    private var request: String {
        String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(EchoelModelPlanner.requestLimit))
    }

    private var canAsk: Bool { !request.isEmpty && !desk.isModelBusy && !desk.isWorking }

    var body: some View {
        VStack(alignment: .leading, spacing: EchoelTheme.spaceXS) {
            Text("Ask Echoel")
                .font(EchoelTheme.font(15, .semibold))
            TextField("Make the selected track 3 dB quieter", text: $draft)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(send)
                .accessibilityLabel("Request for Echoel")
                .accessibilityHint("Echoel proposes the change first. Nothing changes until you tap Apply.")
            HStack(spacing: EchoelTheme.spaceS) {
                Button("Ask", action: send)
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .disabled(!canAsk)
                    .accessibilityHint("Sends the request to the on-device model. Changes nothing in the piece.")
                Button("Cancel") { desk.endTypedRequest() }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityHint("Closes the request line. Changes nothing in the piece.")
            }
        }
        .foregroundStyle(EchoelTheme.text)
        .padding(EchoelTheme.spaceS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EchoelTheme.surface)
        .accessibilityElement(children: .contain)
        .onAppear { focused = true }
    }

    private func send() {
        guard canAsk else { return }
        let asked = request
        desk.endTypedRequest()
        Task { await AgentReportBanner.ask(asked) }
    }
}
#endif
