//
//  EchoelmusicWidget.swift
//  EchoelmusicWidget
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Home Screen Widget for Echoelmusic
//

import WidgetKit
import SwiftUI

// MARK: - Widget Provider

struct EchoelmusicWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), project: placeholderProject)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = WidgetEntry(date: Date(), project: placeholderProject)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        // Fetch current project from shared container
        let currentProject = loadCurrentProject()

        let entry = WidgetEntry(date: Date(), project: currentProject ?? placeholderProject)

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }

    private func loadCurrentProject() -> ProjectInfo? {
        // Load from shared UserDefaults or App Group container
        guard let sharedDefaults = UserDefaults(suiteName: "group.app.eoel") else {
            return nil
        }

        guard let data = sharedDefaults.data(forKey: "current_project"),
              let project = try? JSONDecoder().decode(ProjectInfo.self, from: data) else {
            return nil
        }

        return project
    }

    private var placeholderProject: ProjectInfo {
        ProjectInfo(
            name: "My Project",
            lastModified: Date(),
            trackCount: 3,
            duration: 180
        )
    }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let project: ProjectInfo
}

// MARK: - Project Info

struct ProjectInfo: Codable {
    let name: String
    let lastModified: Date
    let trackCount: Int
    let duration: TimeInterval // in seconds

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Widget Views

struct SmallWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)

                Text("Quick Record")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .widgetURL(URL(string: "eoel://record"))
    }
}

struct MediumWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Project info
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "music.note")
                    .font(.title)
                    .foregroundColor(.blue)

                Text(entry.project.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("\(entry.project.trackCount)", systemImage: "waveform")
                    Label(entry.project.durationFormatted, systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Text("Modified: \(entry.project.lastModified, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Quick action buttons
            VStack(spacing: 8) {
                Link(destination: URL(string: "eoel://record")!) {
                    Image(systemName: "record.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                }

                Link(destination: URL(string: "eoel://open-project")!) {
                    Image(systemName: "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
    }
}

struct LargeWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Echoelmusic")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(entry.project.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Divider()

            // Project stats
            HStack(spacing: 20) {
                StatItem(
                    icon: "waveform",
                    value: "\(entry.project.trackCount)",
                    label: "Tracks"
                )

                StatItem(
                    icon: "clock",
                    value: entry.project.durationFormatted,
                    label: "Duration"
                )

                StatItem(
                    icon: "calendar",
                    value: formatDate(entry.project.lastModified),
                    label: "Modified"
                )
            }

            Spacer()

            // Quick actions
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "record.circle.fill",
                    label: "Record",
                    color: .red,
                    url: "eoel://record"
                )

                QuickActionButton(
                    icon: "play.circle.fill",
                    label: "Open",
                    color: .blue,
                    url: "eoel://open-project"
                )

                QuickActionButton(
                    icon: "plus.circle.fill",
                    label: "New",
                    color: .green,
                    url: "eoel://new-project"
                )
            }
        }
        .padding()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)

            Text(value)
                .font(.headline)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Widget Configuration

struct EchoelmusicWidget: Widget {
    let kind: String = "EchoelmusicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EchoelmusicWidgetProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Echoelmusic")
        .description("Quick access to your music projects")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        @unknown default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct EchoelmusicWidgetBundle: WidgetBundle {
    var body: some Widget {
        EchoelmusicWidget()
        RecordingWidget()
    }
}

// MARK: - Recording Widget (Small, Quick Record)

struct RecordingWidget: Widget {
    let kind: String = "RecordingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecordingWidgetProvider()) { entry in
            RecordingWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Record")
        .description("Start recording instantly")
        .supportedFamilies([.systemSmall])
    }
}

struct RecordingWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct RecordingWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.red, Color.orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)

                Text("Record")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .widgetURL(URL(string: "eoel://record"))
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    EchoelmusicWidget()
} timeline: {
    WidgetEntry(
        date: Date(),
        project: ProjectInfo(
            name: "My Song",
            lastModified: Date(),
            trackCount: 5,
            duration: 240
        )
    )
}

#Preview("Medium", as: .systemMedium) {
    EchoelmusicWidget()
} timeline: {
    WidgetEntry(
        date: Date(),
        project: ProjectInfo(
            name: "Epic Track",
            lastModified: Date().addingTimeInterval(-3600),
            trackCount: 8,
            duration: 320
        )
    )
}

#Preview("Large", as: .systemLarge) {
    EchoelmusicWidget()
} timeline: {
    WidgetEntry(
        date: Date(),
        project: ProjectInfo(
            name: "Summer Vibes",
            lastModified: Date().addingTimeInterval(-7200),
            trackCount: 12,
            duration: 480
        )
    )
}
