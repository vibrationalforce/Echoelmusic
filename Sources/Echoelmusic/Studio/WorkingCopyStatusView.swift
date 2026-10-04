#if canImport(SwiftUI)
import SwiftUI

/// Restructure A1, step 3 — the working copy of the piece (the song document and the clip grid)
/// is written to this iPhone's storage after every edit. `AppGroupStore.save` returns whether a
/// write reached the disk; until this slice both stores dropped that answer (#514 measured it:
/// no `store.save` call site read the `Bool`), so a write that failed looked saved for the rest
/// of the session and the older file came back on the next launch.
///
/// Shown beside `ProjectSaveStatusView` while either store reports its last write as not
/// written; "Write again" writes both once more. Any later edit that writes cleanly also clears
/// it — the stores record the outcome of EVERY write, not only of this button.
///
/// ⚠️ ITS OWN LEAF, ON PURPOSE (10.76.41/50 law): it is mounted in the root, and it reads two
/// flags that only change when a write's outcome changes — cold, but kept out of the root body
/// all the same.
struct WorkingCopyStatusView: View {
    @Environment(TimelineStore.self) private var timeline
    @Environment(ClipStore.self) private var clips

    var body: some View {
        if timeline.workingCopyNotWritten || clips.gridNotWritten {
            VStack(alignment: .leading, spacing: 6) {
                Label("Changes not stored", systemImage: "exclamationmark.triangle")
                    .font(EchoelTheme.font(15, .semibold))
                Text("Your latest changes to the piece could not be written to this iPhone's storage. They are still open here, but would be lost if the app closes. Write again, or free some storage.")
                    .font(EchoelTheme.font(13))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Write again") {
                    timeline.flushPendingSave()
                    clips.retryWrite()
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .accessibilityHint("Writes the open piece to this iPhone's storage again")
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
