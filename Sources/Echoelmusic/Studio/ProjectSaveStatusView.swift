#if canImport(SwiftUI)
import SwiftUI

/// Cold save state only; no meter, transport or bio reads in the header.
struct ProjectSaveStatusView: View {
    @Environment(ProjectStore.self) private var projects

    var body: some View {
        if let error = projects.saveError {
            VStack(alignment: .leading, spacing: 6) {
                Label("Save failed", systemImage: "exclamationmark.triangle")
                    .font(EchoelTheme.font(15, .semibold))
                Text(error)
                    .font(EchoelTheme.font(13))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Retry save") { projects.retrySave() }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityHint("Writes the pending pieces again")
            }
            .foregroundStyle(EchoelTheme.text)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoelTheme.surface)
            .accessibilityElement(children: .contain)
        }
    }
}
#endif
