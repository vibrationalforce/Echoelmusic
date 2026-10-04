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
/// ⚠️ HONEST ABOUT WHAT A RETRY CAN DO (review of 19e7fc883, MED): a write fails for one of two
/// reasons — the storage refused the file, or a value in the piece could not be encoded (a
/// non-finite number makes `JSONEncoder` throw, #512). Writing again only helps the first. The
/// store reports one `Bool` and logs which, so the notice does not guess: after a "Write again"
/// that did not help, it names both ways out — undo the last change, or free some storage.
///
/// ⚠️ ITS OWN LEAF, ON PURPOSE (10.76.41/50 law): it is mounted in the root, and it reads two
/// flags that only change when a write's outcome changes — cold, but kept out of the root body
/// all the same.
struct WorkingCopyStatusView: View {
    @Environment(TimelineStore.self) private var timeline
    @Environment(ClipStore.self) private var clips
    /// True after a "Write again" that left a store unwritten; cleared when the notice goes.
    @State private var retryDidNotHelp = false

    var body: some View {
        Group {
            if timeline.workingCopyNotWritten || clips.gridNotWritten {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Changes not stored", systemImage: "exclamationmark.triangle")
                        .font(EchoelTheme.font(15, .semibold))
                    Text("Your latest changes to the piece could not be written to this iPhone's storage. They are still open here, but would be lost if the app closes.")
                        .font(EchoelTheme.font(13))
                        .fixedSize(horizontal: false, vertical: true)
                    if retryDidNotHelp {
                        Text("Writing again did not help. Undo your last change, since one of its values may not be storable, or free some storage. Then write again.")
                            .font(EchoelTheme.font(13))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button("Write again") {
                        let songWritten = timeline.flushPendingSave()
                        let gridWritten = clips.retryWrite()
                        retryDidNotHelp = !(songWritten && gridWritten)
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
        .onChange(of: timeline.workingCopyNotWritten || clips.gridNotWritten) { _, failing in
            if !failing { retryDidNotHelp = false }
        }
    }
}
#endif
