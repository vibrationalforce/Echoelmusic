// MARK: - EchoelaWidgets.swift
// Echoelmusic Suite - Widget Extension
// Bundle ID: com.echoelmusic.app.widgets
// Copyright 2026 Echoelmusic. All rights reserved.

import SwiftUI
import WidgetKit

// MARK: - Widget Bundle

@main
struct EchoelaWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Artist stats widget
        ArtistStatsWidget()

        // NFT tracking widget
        NFTTrackingWidget()

        // Coherence widget
        EchoelaCoherenceWidget()

        // Quick action widget
        QuickActionWidget()

        #if os(visionOS)
        // Spatial widget for visionOS
        SpatialEchoelaCoherenceWidget()
        #endif
    }
}

// MARK: - Shared Timeline Provider

struct EchoelaTimelineProvider<Entry: TimelineEntry>: TimelineProvider {
    typealias Entry = Entry

    func placeholder(in context: Context) -> Entry {
        fatalError("Subclass must implement")
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        fatalError("Subclass must implement")
    }

    func getTimeline(in context: Context, completion: @escaping (WidgetKit.Timeline<Entry>) -> Void) {
        fatalError("Subclass must implement")
    }
}

// MARK: - Artist Stats Widget

struct ArtistStatsEntry: TimelineEntry {
    let date: Date
    let artistName: String
    let totalMints: Int
    let totalRevenue: Decimal
    let currency: String
    let recentActivity: [ActivityItem]
    let coherenceAverage: Double

    struct ActivityItem: Identifiable {
        let id = UUID()
        let type: ActivityType
        let description: String
        let timestamp: Date

        enum ActivityType {
            case mint
            case sale
            case collaboration
            case session
        }
    }
}

struct ArtistStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArtistStatsEntry {
        ArtistStatsEntry(
            date: Date(),
            artistName: "Artist",
            totalMints: 42,
            totalRevenue: 1.5,
            currency: "ETH",
            recentActivity: [],
            coherenceAverage: 0.72
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ArtistStatsEntry) -> Void) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (WidgetKit.Timeline<ArtistStatsEntry>) -> Void) {
        // Fetch actual data from shared storage
        let entry = ArtistStatsEntry(
            date: Date(),
            artistName: UserDefaults(suiteName: "group.com.echoelmusic")?.string(forKey: "artistName") ?? "Artist",
            totalMints: UserDefaults(suiteName: "group.com.echoelmusic")?.integer(forKey: "totalMints") ?? 0,
            totalRevenue: Decimal(UserDefaults(suiteName: "group.com.echoelmusic")?.double(forKey: "totalRevenue") ?? 0),
            currency: "ETH",
            recentActivity: [],
            coherenceAverage: UserDefaults(suiteName: "group.com.echoelmusic")?.double(forKey: "coherenceAverage") ?? 0.5
        )

        let timeline = WidgetKit.Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        completion(timeline)
    }
}

struct ArtistStatsWidget: Widget {
    let kind = "ArtistStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ArtistStatsProvider()) { entry in
            ArtistStatsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: ContainerBackgroundPlacement.widget)
        }
        .configurationDisplayName("Artist Stats")
        .description("Track your mints, revenue, and activity")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ArtistStatsWidgetView: View {
    let entry: ArtistStatsEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundStyle(.purple)
                Text("NFTs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.totalMints)")
                .font(.title)
                .fontWeight(.bold)

            Text("\(entry.totalRevenue) \(entry.currency)")
                .font(.caption)
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var mediumView: some View {
        HStack(spacing: 16) {
            // Left: Stats
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.artistName)
                    .font(.headline)

                HStack(spacing: 16) {
                    statItem(value: "\(entry.totalMints)", label: "Mints", icon: "sparkles.rectangle.stack")
                    statItem(value: "\(entry.totalRevenue)", label: entry.currency, icon: "dollarsign.circle")
                }
            }

            Spacer()

            // Right: Coherence
            VStack {
                Gauge(value: entry.coherenceAverage) {
                    Text("\(Int(entry.coherenceAverage * 100))%")
                }
                .gaugeStyle(.accessoryCircular)
                .tint(.purple)

                Text("Coherence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
                Text(entry.artistName)
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Stats grid
            HStack(spacing: 16) {
                statCard(value: "\(entry.totalMints)", label: "Total Mints", icon: "sparkles.rectangle.stack", color: .purple)
                statCard(value: "\(entry.totalRevenue) \(entry.currency)", label: "Revenue", icon: "dollarsign.circle", color: .green)
                statCard(value: "\(Int(entry.coherenceAverage * 100))%", label: "Avg Coherence", icon: "heart.circle", color: .pink)
            }

            Divider()

            // Recent activity
            Text("Recent Activity")
                .font(.caption)
                .foregroundStyle(.secondary)

            if entry.recentActivity.isEmpty {
                Text("No recent activity")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(entry.recentActivity.prefix(3)) { activity in
                    HStack {
                        activityIcon(for: activity.type)
                        Text(activity.description)
                            .font(.caption)
                        Spacer()
                        Text(activity.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    func statItem(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    func activityIcon(for type: ArtistStatsEntry.ActivityItem.ActivityType) -> some View {
        switch type {
        case .mint:
            return Image(systemName: "plus.circle").foregroundStyle(.purple)
        case .sale:
            return Image(systemName: "dollarsign.circle").foregroundStyle(.green)
        case .collaboration:
            return Image(systemName: "person.2").foregroundStyle(.blue)
        case .session:
            return Image(systemName: "waveform").foregroundStyle(.pink)
        }
    }
}

// MARK: - NFT Tracking Widget

struct NFTTrackingEntry: TimelineEntry {
    let date: Date
    let nfts: [TrackedNFT]

    struct TrackedNFT: Identifiable {
        let id: String
        let name: String
        let floorPrice: Decimal
        let currency: String
        let changePercent: Double
        let imageURL: URL?
    }
}

struct NFTTrackingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NFTTrackingEntry {
        NFTTrackingEntry(
            date: Date(),
            nfts: [
                NFTTrackingEntry.TrackedNFT(
                    id: "1",
                    name: "Bio Session #42",
                    floorPrice: 0.1,
                    currency: "ETH",
                    changePercent: 5.2,
                    imageURL: nil
                )
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NFTTrackingEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (WidgetKit.Timeline<NFTTrackingEntry>) -> Void) {
        let entry = placeholder(in: context)
        let timeline = WidgetKit.Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }
}

struct NFTTrackingWidget: Widget {
    let kind = "NFTTrackingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NFTTrackingProvider()) { entry in
            NFTTrackingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: ContainerBackgroundPlacement.widget)
        }
        .configurationDisplayName("NFT Tracker")
        .description("Track your Echoelmusic NFT portfolio")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NFTTrackingWidgetView: View {
    let entry: NFTTrackingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.purple)
                Text("NFT Portfolio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(entry.nfts.prefix(3)) { nft in
                HStack {
                    Text(nft.name)
                        .font(.caption)
                        .lineLimit(1)

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(nft.floorPrice) \(nft.currency)")
                            .font(.caption)
                            .fontWeight(.medium)

                        Text(nft.changePercent >= 0 ? "+\(nft.changePercent, specifier: "%.1f")%" : "\(nft.changePercent, specifier: "%.1f")%")
                            .font(.caption2)
                            .foregroundStyle(nft.changePercent >= 0 ? .green : .red)
                    }
                }
            }
        }
    }
}

// MARK: - Coherence Widget

struct EchoelaCoherenceEntry: TimelineEntry {
    let date: Date
    let currentCoherence: Double
    let trend: Trend
    let sessionActive: Bool

    enum Trend {
        case increasing
        case stable
        case decreasing
    }
}

struct CoherenceProvider: TimelineProvider {
    func placeholder(in context: Context) -> EchoelaCoherenceEntry {
        EchoelaCoherenceEntry(date: Date(), currentCoherence: 0.72, trend: .stable, sessionActive: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (EchoelaCoherenceEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (WidgetKit.Timeline<EchoelaCoherenceEntry>) -> Void) {
        let coherence = UserDefaults(suiteName: "group.com.echoelmusic")?.double(forKey: "currentCoherence") ?? 0.5
        let entry = EchoelaCoherenceEntry(date: Date(), currentCoherence: coherence, trend: .stable, sessionActive: false)
        let timeline = WidgetKit.Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
        completion(timeline)
    }
}

struct EchoelaCoherenceWidget: Widget {
    let kind = "EchoelaCoherenceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoherenceProvider()) { entry in
            EchoelaEchoelaCoherenceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: ContainerBackgroundPlacement.widget)
        }
        .configurationDisplayName("Coherence")
        .description("Your current heart coherence level")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

struct EchoelaEchoelaCoherenceWidgetView: View {
    let entry: EchoelaCoherenceEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }

    var circularView: some View {
        Gauge(value: entry.currentCoherence) {
            Image(systemName: "heart.fill")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(coherenceGradient)
    }

    var rectangularView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Coherence")
                    .font(.caption2)
                Text("\(Int(entry.currentCoherence * 100))%")
                    .font(.headline)
            }

            Spacer()

            Image(systemName: trendIcon)
                .foregroundStyle(trendColor)
        }
    }

    var smallView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: entry.currentCoherence)
                    .stroke(coherenceGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(entry.currentCoherence * 100))")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            Text("Coherence")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var coherenceGradient: LinearGradient {
        let color: Color = entry.currentCoherence > 0.7 ? .green :
                           entry.currentCoherence > 0.4 ? .yellow : .red

        return LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing)
    }

    var trendIcon: String {
        switch entry.trend {
        case .increasing: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .decreasing: return "arrow.down.right"
        }
    }

    var trendColor: Color {
        switch entry.trend {
        case .increasing: return .green
        case .stable: return .yellow
        case .decreasing: return .red
        }
    }
}

// MARK: - Quick Action Widget

struct QuickActionEntry: TimelineEntry {
    let date: Date
}

struct QuickActionProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionEntry {
        QuickActionEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionEntry) -> Void) {
        completion(QuickActionEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (WidgetKit.Timeline<QuickActionEntry>) -> Void) {
        let entry = QuickActionEntry(date: Date())
        let timeline = WidgetKit.Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct QuickActionWidget: Widget {
    let kind = "QuickActionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionProvider()) { entry in
            QuickActionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: ContainerBackgroundPlacement.widget)
        }
        .configurationDisplayName("Quick Actions")
        .description("Quick access to Echoelmusic features")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickActionWidgetView: View {
    let entry: QuickActionEntry

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                actionButton(
                    icon: "waveform",
                    label: "Session",
                    url: URL(string: "echoelmusic://action/meditation/start")!,
                    color: .purple
                )

                actionButton(
                    icon: "sparkles.rectangle.stack",
                    label: "Mint",
                    url: URL(string: "echoelmusic://action/nft/mint")!,
                    color: .blue
                )
            }

            HStack(spacing: 12) {
                actionButton(
                    icon: "applewatch",
                    label: "Watch",
                    url: URL(string: "echoelmusic://action/watch/sense")!,
                    color: .green
                )

                actionButton(
                    icon: "person.2",
                    label: "Collab",
                    url: URL(string: "echoelmusic://action/collab/invite")!,
                    color: .orange
                )
            }
        }
    }

    func actionButton(icon: String, label: String, url: URL, color: Color) -> some View {
        Link(destination: url) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(color)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
            )
        }
    }
}

// MARK: - visionOS Spatial Widget

#if os(visionOS)
struct SpatialCoherenceEntry: TimelineEntry {
    let date: Date
    let coherence: Double
    let isSessionActive: Bool
}

struct SpatialCoherenceProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpatialCoherenceEntry {
        SpatialCoherenceEntry(date: Date(), coherence: 0.72, isSessionActive: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpatialCoherenceEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (WidgetKit.Timeline<SpatialCoherenceEntry>) -> Void) {
        let entry = placeholder(in: context)
        let timeline = WidgetKit.Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
        completion(timeline)
    }
}

struct SpatialEchoelaCoherenceWidget: Widget {
    let kind = "SpatialEchoelaCoherenceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpatialCoherenceProvider()) { entry in
            SpatialEchoelaEchoelaCoherenceWidgetView(entry: entry)
        }
        .configurationDisplayName("Spatial Coherence")
        .description("3D coherence visualization for your workspace")
        .supportedFamilies([.systemSmall])
    }
}

struct SpatialEchoelaEchoelaCoherenceWidgetView: View {
    let entry: SpatialCoherenceEntry

    var body: some View {
        ZStack {
            // 3D sphere representation
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            coherenceColor.opacity(0.8),
                            coherenceColor.opacity(0.3),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .blur(radius: 2)

            VStack {
                Text("\(Int(entry.coherence * 100))%")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Coherence")
                    .font(.caption)
            }
        }
        .glassBackgroundEffect()
    }

    var coherenceColor: Color {
        entry.coherence > 0.7 ? .green :
        entry.coherence > 0.4 ? .yellow : .red
    }
}
#endif

// MARK: - Previews

#Preview("Artist Stats Small", as: .systemSmall) {
    ArtistStatsWidget()
} timeline: {
    ArtistStatsEntry(
        date: Date(),
        artistName: "Demo Artist",
        totalMints: 42,
        totalRevenue: 1.5,
        currency: "ETH",
        recentActivity: [],
        coherenceAverage: 0.72
    )
}

#Preview("Coherence", as: .accessoryCircular) {
    EchoelaCoherenceWidget()
} timeline: {
    EchoelaCoherenceEntry(date: Date(), currentCoherence: 0.72, trend: .increasing, sessionActive: false)
}
