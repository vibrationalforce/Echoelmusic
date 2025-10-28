import SwiftUI

/// Individual skill row in lists
struct SkillRow: View {
    let skill: UserSkill
    @ObservedObject var repository: SkillsRepository
    var showActions: Bool = false

    @State private var showingDetail = false
    @State private var showingShareSheet = false
    @State private var exportedURL: URL?

    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: 12) {
                // Type Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(typeColor.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: skill.type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(typeColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title & Verified Badge
                    HStack(spacing: 6) {
                        Text(skill.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if skill.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }

                        if skill.isFeatured {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }

                    // Creator
                    Text("by \(skill.creatorName)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    // Stats
                    HStack(spacing: 12) {
                        Label("\(skill.downloads)", systemImage: "arrow.down.circle")
                        Label(String(format: "%.1f", skill.rating), systemImage: "star.fill")
                        Text(skill.category.rawValue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.2)))
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Favorite Button
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(isFavorited ? .red : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            SkillDetailView(skill: skill, repository: repository)
        }
    }

    private var typeColor: Color {
        switch skill.type.color {
        case "cyan": return .cyan
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "blue": return .blue
        default: return .gray
        }
    }

    private var isFavorited: Bool {
        repository.isFavorited(skill.id)
    }

    private func toggleFavorite() {
        Task {
            if isFavorited {
                try? await repository.removeFromFavorites(skill.id)
            } else {
                try? await repository.addToFavorites(skill)
            }
        }
    }
}


/// Featured skill card (horizontal scroll)
struct FeaturedSkillCard: View {
    let skill: UserSkill
    @ObservedObject var repository: SkillsRepository

    @State private var showingDetail = false

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // Thumbnail or gradient
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 140)

                    // Featured badge
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("Featured")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange))
                    .padding(8)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(skill.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    HStack {
                        Label("\(skill.downloads)", systemImage: "arrow.down.circle.fill")
                        Spacer()
                        Label(String(format: "%.1f", skill.rating), systemImage: "star.fill")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 260)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            SkillDetailView(skill: skill, repository: repository)
        }
    }
}


/// Skill detail view
struct SkillDetailView: View {
    let skill: UserSkill
    @ObservedObject var repository: SkillsRepository
    @Environment(\.dismiss) private var dismiss

    @State private var showingShareSheet = false
    @State private var exportedURL: URL?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(skill.name)
                                .font(.system(size: 28, weight: .bold))

                            if skill.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.blue)
                            }
                        }

                        HStack(spacing: 8) {
                            Image(systemName: skill.type.icon)
                            Text(skill.type.rawValue)
                            Text("•")
                            Text(skill.category.rawValue)
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                        // Creator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(String(skill.creatorName.prefix(1)))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(skill.creatorName)
                                    .font(.system(size: 14, weight: .medium))
                                Text(skill.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Stats
                    HStack(spacing: 30) {
                        StatColumn(value: "\(skill.downloads)", label: "Downloads", icon: "arrow.down.circle.fill")
                        StatColumn(value: String(format: "%.1f", skill.rating), label: "Rating", icon: "star.fill")
                        StatColumn(value: "\(skill.favorites)", label: "Favorites", icon: "heart.fill")
                    }
                    .padding(.horizontal)

                    Divider()

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 18, weight: .semibold))

                        Text(skill.description)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Tags
                    if !skill.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.system(size: 18, weight: .semibold))

                            FlowLayout(spacing: 8) {
                                ForEach(skill.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 13))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.blue.opacity(0.2)))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Actions
                    VStack(spacing: 12) {
                        if !isDownloaded {
                            Button(action: downloadSkill) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Download Skill")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue))
                            }
                        }

                        Button(action: shareSkill) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Skill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 12).stroke(Color.blue, lineWidth: 2))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedURL {
                ShareSheet(items: [url])
            }
        }
    }

    private var isDownloaded: Bool {
        repository.downloadedSkills.contains { $0.id == skill.id }
    }

    private func downloadSkill() {
        Task {
            try? await repository.downloadSkill(skill)
        }
    }

    private func shareSkill() {
        do {
            exportedURL = try repository.exportSkill(skill)
            showingShareSheet = true
        } catch {
            print("Export failed: \(error)")
        }
    }
}


struct StatColumn: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)

            Text(value)
                .font(.system(size: 20, weight: .bold))

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}


/// Flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}


/// Share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
