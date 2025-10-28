import Foundation
import Combine

/// Central repository for managing user skills
/// Handles local storage, cloud sync, and marketplace operations
@MainActor
class SkillsRepository: ObservableObject {

    // MARK: - Published State

    @Published var mySkills: [UserSkill] = []
    @Published var downloadedSkills: [UserSkill] = []
    @Published var favoriteSkills: [UserSkill] = []
    @Published var marketplaceSkills: [UserSkill] = []

    @Published var isLoading: Bool = false
    @Published var error: SkillError?

    // MARK: - Storage

    private let fileManager = FileManager.default
    private var skillsDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("Skills", isDirectory: true)
    }

    private var mySkillsFile: URL {
        skillsDirectory.appendingPathComponent("my_skills.json")
    }

    private var downloadedSkillsFile: URL {
        skillsDirectory.appendingPathComponent("downloaded_skills.json")
    }

    private var favoritesFile: URL {
        skillsDirectory.appendingPathComponent("favorites.json")
    }

    // MARK: - Initialization

    init() {
        createDirectoryIfNeeded()
        Task {
            await loadLocalSkills()
        }
    }

    // MARK: - Local Storage

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: skillsDirectory.path) {
            try? fileManager.createDirectory(at: skillsDirectory, withIntermediateDirectories: true)
        }
    }

    /// Load all local skills
    func loadLocalSkills() async {
        isLoading = true
        defer { isLoading = false }

        do {
            mySkills = try loadSkills(from: mySkillsFile)
            downloadedSkills = try loadSkills(from: downloadedSkillsFile)
            favoriteSkills = try loadSkills(from: favoritesFile)

            print("📚 Loaded \(mySkills.count) personal skills")
            print("📥 Loaded \(downloadedSkills.count) downloaded skills")
            print("⭐ Loaded \(favoriteSkills.count) favorite skills")
        } catch {
            print("⚠️ Error loading skills: \(error)")
            self.error = .loadFailed(error)
        }
    }

    private func loadSkills(from url: URL) throws -> [UserSkill] {
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([UserSkill].self, from: data)
    }

    /// Save all local skills
    func saveLocalSkills() async throws {
        try saveSkills(mySkills, to: mySkillsFile)
        try saveSkills(downloadedSkills, to: downloadedSkillsFile)
        try saveSkills(favoriteSkills, to: favoritesFile)

        print("💾 Saved all local skills")
    }

    private func saveSkills(_ skills: [UserSkill], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(skills)
        try data.write(to: url)
    }

    // MARK: - My Skills (Creation)

    /// Create and save a new skill
    func createSkill(_ skill: UserSkill) async throws {
        mySkills.append(skill)
        try await saveLocalSkills()

        print("✅ Created skill: \(skill.name)")
    }

    /// Update existing skill
    func updateSkill(_ skill: UserSkill) async throws {
        guard let index = mySkills.firstIndex(where: { $0.id == skill.id }) else {
            throw SkillError.skillNotFound
        }

        var updatedSkill = skill
        updatedSkill.updatedAt = Date()
        mySkills[index] = updatedSkill

        try await saveLocalSkills()
        print("✅ Updated skill: \(skill.name)")
    }

    /// Delete skill
    func deleteSkill(_ skillID: UUID) async throws {
        mySkills.removeAll { $0.id == skillID }
        try await saveLocalSkills()
        print("🗑️ Deleted skill: \(skillID)")
    }

    // MARK: - Marketplace Operations

    /// Load marketplace skills (from cloud/API)
    func loadMarketplace(
        category: SkillCategory? = nil,
        type: SkillType? = nil,
        searchQuery: String? = nil,
        sortBy: SkillSortOption = .popular
    ) async throws {

        isLoading = true
        defer { isLoading = false }

        // TODO: Implement API call to load marketplace skills
        // For now, use mock data or local skills

        /*
        let url = URL(string: "https://api.blab.app/v1/skills/marketplace")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        var queryItems: [URLQueryItem] = []
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category.rawValue))
        }
        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }
        if let query = searchQuery {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        queryItems.append(URLQueryItem(name: "sort", value: sortBy.rawValue))

        components.queryItems = queryItems

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        marketplaceSkills = try decoder.decode([UserSkill].self, from: data)
        */

        // Mock implementation - load from local skills
        marketplaceSkills = mySkills
        print("📦 Loaded \(marketplaceSkills.count) marketplace skills")
    }

    /// Download skill from marketplace
    func downloadSkill(_ skill: UserSkill) async throws {
        // Check if already downloaded
        if downloadedSkills.contains(where: { $0.id == skill.id }) {
            throw SkillError.alreadyDownloaded
        }

        var downloadedSkill = skill
        downloadedSkill.downloads += 1

        downloadedSkills.append(downloadedSkill)
        try await saveLocalSkills()

        // TODO: Track download on server
        /*
        let url = URL(string: "https://api.blab.app/v1/skills/\(skill.id.uuidString)/download")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try await URLSession.shared.data(for: request)
        */

        print("📥 Downloaded skill: \(skill.name)")
    }

    /// Remove downloaded skill
    func removeDownloadedSkill(_ skillID: UUID) async throws {
        downloadedSkills.removeAll { $0.id == skillID }
        try await saveLocalSkills()
        print("🗑️ Removed downloaded skill: \(skillID)")
    }

    // MARK: - Favorites

    /// Add skill to favorites
    func addToFavorites(_ skill: UserSkill) async throws {
        if favoriteSkills.contains(where: { $0.id == skill.id }) {
            throw SkillError.alreadyFavorited
        }

        favoriteSkills.append(skill)
        try await saveLocalSkills()
        print("⭐ Added to favorites: \(skill.name)")
    }

    /// Remove skill from favorites
    func removeFromFavorites(_ skillID: UUID) async throws {
        favoriteSkills.removeAll { $0.id == skillID }
        try await saveLocalSkills()
        print("⭐ Removed from favorites: \(skillID)")
    }

    /// Check if skill is favorited
    func isFavorited(_ skillID: UUID) -> Bool {
        return favoriteSkills.contains { $0.id == skillID }
    }

    // MARK: - Sharing & Export

    /// Share skill (upload to marketplace)
    func shareSkill(_ skill: UserSkill) async throws -> String {
        // TODO: Upload skill to cloud/marketplace
        /*
        let url = URL(string: "https://api.blab.app/v1/skills/share")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(skill)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ShareResponse.self, from: data)
        return response.shareURL
        */

        // Mock implementation
        let shareURL = skill.shareURL().absoluteString
        print("🔗 Shared skill: \(shareURL)")
        return shareURL
    }

    /// Export skill as JSON file
    func exportSkill(_ skill: UserSkill) throws -> URL {
        let exportDirectory = fileManager.temporaryDirectory
        let fileName = "\(skill.name.replacingOccurrences(of: " ", with: "_"))_\(skill.id.uuidString.prefix(8)).json"
        let exportURL = exportDirectory.appendingPathComponent(fileName)

        let data = try skill.exportJSON()
        try data.write(to: exportURL)

        print("📤 Exported skill to: \(exportURL.path)")
        return exportURL
    }

    /// Import skill from JSON file
    func importSkill(from url: URL) async throws -> UserSkill {
        let data = try Data(contentsOf: url)
        let skill = try UserSkill.importJSON(data)

        downloadedSkills.append(skill)
        try await saveLocalSkills()

        print("📥 Imported skill: \(skill.name)")
        return skill
    }

    // MARK: - Rating & Reviews

    /// Rate a skill
    func rateSkill(_ skillID: UUID, rating: Int) async throws {
        guard rating >= 1 && rating <= 5 else {
            throw SkillError.invalidRating
        }

        // TODO: Submit rating to server
        /*
        let url = URL(string: "https://api.blab.app/v1/skills/\(skillID.uuidString)/rate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["rating": rating]
        request.httpBody = try JSONEncoder().encode(body)

        _ = try await URLSession.shared.data(for: request)
        */

        print("⭐ Rated skill: \(skillID) - \(rating) stars")
    }

    // MARK: - Search & Filter

    /// Search skills by query
    func searchSkills(_ query: String, in collection: [UserSkill]) -> [UserSkill] {
        guard !query.isEmpty else { return collection }

        let lowercasedQuery = query.lowercased()
        return collection.filter { skill in
            skill.name.lowercased().contains(lowercasedQuery) ||
            skill.description.lowercased().contains(lowercasedQuery) ||
            skill.tags.contains { $0.lowercased().contains(lowercasedQuery) } ||
            skill.creatorName.lowercased().contains(lowercasedQuery)
        }
    }

    /// Filter skills by category
    func filterByCategory(_ category: SkillCategory, in collection: [UserSkill]) -> [UserSkill] {
        return collection.filter { $0.category == category }
    }

    /// Filter skills by type
    func filterByType(_ type: SkillType, in collection: [UserSkill]) -> [UserSkill] {
        return collection.filter { $0.type == type }
    }

    /// Sort skills
    func sortSkills(_ skills: [UserSkill], by option: SkillSortOption) -> [UserSkill] {
        switch option {
        case .popular:
            return skills.sorted { $0.downloads > $1.downloads }
        case .rating:
            return skills.sorted { $0.rating > $1.rating }
        case .recent:
            return skills.sorted { $0.createdAt > $1.createdAt }
        case .alphabetical:
            return skills.sorted { $0.name < $1.name }
        case .favorites:
            return skills.sorted { $0.favorites > $1.favorites }
        }
    }

    // MARK: - Analytics

    /// Get skill statistics
    func getStatistics() -> SkillStatistics {
        return SkillStatistics(
            mySkillsCount: mySkills.count,
            downloadedSkillsCount: downloadedSkills.count,
            favoriteSkillsCount: favoriteSkills.count,
            totalDownloads: mySkills.reduce(0) { $0 + $1.downloads },
            averageRating: mySkills.isEmpty ? 0.0 : mySkills.reduce(0.0) { $0 + $1.rating } / Double(mySkills.count),
            mostPopularCategory: mostPopularCategory()
        )
    }

    private func mostPopularCategory() -> SkillCategory {
        let categoryCounts = Dictionary(grouping: mySkills, by: { $0.category })
            .mapValues { $0.count }

        return categoryCounts.max { $0.value < $1.value }?.key ?? .other
    }
}


// MARK: - Sort Options

enum SkillSortOption: String, CaseIterable {
    case popular = "Popular"
    case rating = "Top Rated"
    case recent = "Recent"
    case alphabetical = "A-Z"
    case favorites = "Most Favorited"
}


// MARK: - Statistics

struct SkillStatistics {
    let mySkillsCount: Int
    let downloadedSkillsCount: Int
    let favoriteSkillsCount: Int
    let totalDownloads: Int
    let averageRating: Double
    let mostPopularCategory: SkillCategory
}


// MARK: - Errors

enum SkillError: LocalizedError {
    case skillNotFound
    case alreadyDownloaded
    case alreadyFavorited
    case loadFailed(Error)
    case saveFailed(Error)
    case invalidRating
    case networkError
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .skillNotFound:
            return "Skill not found"
        case .alreadyDownloaded:
            return "Skill already downloaded"
        case .alreadyFavorited:
            return "Skill already in favorites"
        case .loadFailed(let error):
            return "Failed to load skills: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save skills: \(error.localizedDescription)"
        case .invalidRating:
            return "Rating must be between 1 and 5"
        case .networkError:
            return "Network connection error"
        case .unauthorized:
            return "Not authorized to perform this action"
        }
    }
}
