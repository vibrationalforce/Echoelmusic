import EchoelCore
import SwiftUI

/// Learn (Recovery 8): short chapters on what this build does, each with the way to its controls.
/// The words are data (`LearnGuide` in EchoelCore), so this page only draws and searches them.
/// It reads nothing that changes while it is open. A chapter opens as a push inside the page,
/// never as a second sheet (Law 7).
struct LearnView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let found = LearnGuide.search(query)
        NavigationStack {
            List {
                if found.isEmpty {
                    EchoelSection {
                        NoteText("No chapter mentions “\(query)”.")
                    }
                } else {
                    EchoelSection {
                        ForEach(found) { chapter in
                            NavigationLink {
                                LearnChapterView(chapter: chapter)
                            } label: {
                                chapterRow(chapter)
                            }
                        }
                    }
                }
            }
            .echoelList()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Learn")
            .navigationTitle("Learn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func chapterRow(_ chapter: LearnChapter) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(chapter.title)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(chapter.summary)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Theme.Space.xxs)
        .accessibilityElement(children: .combine)
    }
}

/// One chapter: where its controls are, then its text.
private struct LearnChapterView: View {
    let chapter: LearnChapter

    var body: some View {
        List {
            EchoelSection("Where") {
                ForEach(chapter.paths.indices, id: \.self) { index in
                    pathRow(chapter.paths[index])
                }
            }
            EchoelSection {
                ForEach(chapter.paragraphs.indices, id: \.self) { index in
                    ParagraphText(chapter.paragraphs[index])
                }
            }
        }
        .echoelList()
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pathRow(_ path: [StudioPlace]) -> some View {
        Text(LearnChapter.line(path))
            .font(Theme.Font.label)
            .foregroundStyle(Theme.Color.text)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, Theme.Space.xxs)
            .accessibilityLabel(LearnChapter.spoken(path))
    }
}
