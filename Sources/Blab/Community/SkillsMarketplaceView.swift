import SwiftUI

/// Main Skills Marketplace view
/// Browse, download, and share user-created skills
struct SkillsMarketplaceView: View {

    @StateObject private var repository = SkillsRepository()
    @State private var selectedTab: MarketplaceTab = .discover
    @State private var searchQuery = ""
    @State private var selectedCategory: SkillCategory? = nil
    @State private var selectedType: SkillType? = nil
    @State private var sortOption: SkillSortOption = .popular
    @State private var showingFilters = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                tabPicker

                // Search Bar
                searchBar

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .discover:
                            discoverSection
                        case .mySkills:
                            mySkillsSection
                        case .downloaded:
                            downloadedSection
                        case .favorites:
                            favoritesSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                filtersSheet
            }
            .task {
                try? await repository.loadMarketplace()
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(MarketplaceTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search skills...", text: $searchQuery)
                .textFieldStyle(.plain)

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Discover Section

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Featured Skills
            if !featuredSkills.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Featured")
                        .font(.system(size: 22, weight: .bold))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(featuredSkills) { skill in
                                FeaturedSkillCard(skill: skill, repository: repository)
                            }
                        }
                    }
                }
            }

            // Categories
            VStack(alignment: .leading, spacing: 12) {
                Text("Browse by Category")
                    .font(.system(size: 20, weight: .bold))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(SkillCategory.allCases, id: \.self) { category in
                        CategoryCard(category: category)
                            .onTapGesture {
                                selectedCategory = category
                                Task {
                                    try? await repository.loadMarketplace(category: category)
                                }
                            }
                    }
                }
            }

            // Popular Skills
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Popular Skills")
                        .font(.system(size: 20, weight: .bold))

                    Spacer()

                    Menu {
                        ForEach(SkillSortOption.allCases, id: \.self) { option in
                            Button(option.rawValue) {
                                sortOption = option
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(sortOption.rawValue)
                                .font(.system(size: 13))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.blue)
                    }
                }

                LazyVStack(spacing: 12) {
                    ForEach(sortedMarketplaceSkills) { skill in
                        SkillRow(skill: skill, repository: repository)
                    }
                }
            }
        }
    }

    // MARK: - My Skills Section

    private var mySkillsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Create New Skill Button
            NavigationLink(destination: CreateSkillView(repository: repository)) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("Create New Skill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }

            // Statistics Card
            mySkillsStatistics

            // My Skills List
            Text("Your Skills (\(repository.mySkills.count))")
                .font(.system(size: 20, weight: .bold))

            if repository.mySkills.isEmpty {
                emptyStateView(
                    icon: "doc.text.fill",
                    title: "No Skills Yet",
                    message: "Create your first skill to share with the community"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredMySkills) { skill in
                        SkillRow(skill: skill, repository: repository, showActions: true)
                    }
                }
            }
        }
    }

    // MARK: - Downloaded Section

    private var downloadedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Downloaded Skills (\(repository.downloadedSkills.count))")
                .font(.system(size: 20, weight: .bold))

            if repository.downloadedSkills.isEmpty {
                emptyStateView(
                    icon: "arrow.down.circle.fill",
                    title: "No Downloaded Skills",
                    message: "Explore the marketplace to find skills created by others"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredDownloadedSkills) { skill in
                        SkillRow(skill: skill, repository: repository)
                    }
                }
            }
        }
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Favorite Skills (\(repository.favoriteSkills.count))")
                .font(.system(size: 20, weight: .bold))

            if repository.favoriteSkills.isEmpty {
                emptyStateView(
                    icon: "star.fill",
                    title: "No Favorites",
                    message: "Tap the star icon on any skill to add it to your favorites"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredFavoriteSkills) { skill in
                        SkillRow(skill: skill, repository: repository)
                    }
                }
            }
        }
    }

    // MARK: - My Skills Statistics

    private var mySkillsStatistics: some View {
        let stats = repository.getStatistics()

        return VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatBox(value: "\(stats.totalDownloads)", label: "Downloads", icon: "arrow.down.circle.fill", color: .blue)
                StatBox(value: String(format: "%.1f", stats.averageRating), label: "Avg Rating", icon: "star.fill", color: .orange)
                StatBox(value: "\(stats.favoriteSkillsCount)", label: "Favorites", icon: "heart.fill", color: .red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Filters Sheet

    private var filtersSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All Categories").tag(nil as SkillCategory?)
                        ForEach(SkillCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category as SkillCategory?)
                        }
                    }
                }

                Section(header: Text("Type")) {
                    Picker("Type", selection: $selectedType) {
                        Text("All Types").tag(nil as SkillType?)
                        ForEach(SkillType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type as SkillType?)
                        }
                    }
                }

                Section(header: Text("Sort By")) {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(SkillSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarItems(trailing: Button("Done") {
                showingFilters = false
            })
        }
    }

    // MARK: - Empty State

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Computed Properties

    private var featuredSkills: [UserSkill] {
        repository.marketplaceSkills.filter { $0.isFeatured }
    }

    private var sortedMarketplaceSkills: [UserSkill] {
        let filtered = filteredSkills(repository.marketplaceSkills)
        return repository.sortSkills(filtered, by: sortOption)
    }

    private var filteredMySkills: [UserSkill] {
        filteredSkills(repository.mySkills)
    }

    private var filteredDownloadedSkills: [UserSkill] {
        filteredSkills(repository.downloadedSkills)
    }

    private var filteredFavoriteSkills: [UserSkill] {
        filteredSkills(repository.favoriteSkills)
    }

    private func filteredSkills(_ skills: [UserSkill]) -> [UserSkill] {
        var result = skills

        // Apply search
        if !searchQuery.isEmpty {
            result = repository.searchSkills(searchQuery, in: result)
        }

        // Apply category filter
        if let category = selectedCategory {
            result = repository.filterByCategory(category, in: result)
        }

        // Apply type filter
        if let type = selectedType {
            result = repository.filterByType(type, in: result)
        }

        return result
    }
}


// MARK: - Marketplace Tab

enum MarketplaceTab: String, CaseIterable {
    case discover = "Discover"
    case mySkills = "My Skills"
    case downloaded = "Downloaded"
    case favorites = "Favorites"
}


// MARK: - Supporting Views

struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}


struct CategoryCard: View {
    let category: SkillCategory

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 28))
                .foregroundColor(.white)

            Text(category.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(width: 100, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }
}


// MARK: - Preview

#Preview {
    SkillsMarketplaceView()
}
