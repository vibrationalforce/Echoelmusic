//
// PresetManager.swift
// Echoelmusic
//
// Manages preset storage, loading, CloudKit sync, and import/export
//

import Foundation
import Combine
import CloudKit

class PresetManager: ObservableObject {

    // MARK: - Published Properties

    @Published var userPresets: [Preset] = []
    @Published var factoryPresets: [Preset] = Preset.factoryPresets
    @Published var currentPreset: Preset?
    @Published var isSyncing: Bool = false
    @Published var syncError: Error?

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let presetsDirectory: URL
    private let cloudKitContainer: CKContainer
    private let cloudKitDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Set up local storage directory
        let documentsDirectory = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        presetsDirectory = documentsDirectory
            .appendingPathComponent("Echoelmusic")
            .appendingPathComponent("Presets")

        // Create directory if needed
        try? fileManager.createDirectory(
            at: presetsDirectory,
            withIntermediateDirectories: true
        )

        // Set up CloudKit
        cloudKitContainer = CKContainer(identifier: "iCloud.com.echoelmusic")
        cloudKitDatabase = cloudKitContainer.privateCloudDatabase

        // Load user presets
        loadUserPresets()

        // Set up CloudKit sync observer
        NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification
        )
        .sink { [weak self] _ in
            self?.syncFromCloud()
        }
        .store(in: &cancellables)
    }

    // MARK: - Preset Management

    /// Save a new preset
    func savePreset(_ preset: Preset) -> Bool {
        var mutablePreset = preset
        mutablePreset.modifiedDate = Date()

        do {
            // Save locally
            let fileURL = presetFileURL(for: preset.id)
            let data = try JSONEncoder().encode(mutablePreset)
            try data.write(to: fileURL)

            // Add to user presets if new
            if !userPresets.contains(where: { $0.id == preset.id }) {
                userPresets.append(mutablePreset)
            } else {
                // Update existing
                if let index = userPresets.firstIndex(where: { $0.id == preset.id }) {
                    userPresets[index] = mutablePreset
                }
            }

            // Sync to CloudKit
            syncToCloud(preset: mutablePreset)

            return true

        } catch {
            print("Error saving preset: \(error)")
            return false
        }
    }

    /// Load a preset by ID
    func loadPreset(id: UUID) -> Preset? {
        // Check user presets first
        if let preset = userPresets.first(where: { $0.id == id }) {
            return preset
        }

        // Check factory presets
        if let preset = factoryPresets.first(where: { $0.id == id }) {
            return preset
        }

        // Try loading from disk
        let fileURL = presetFileURL(for: id)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let preset = try JSONDecoder().decode(Preset.self, from: data)
            return preset
        } catch {
            print("Error loading preset: \(error)")
            return nil
        }
    }

    /// Delete a preset
    func deletePreset(id: UUID) -> Bool {
        // Can't delete factory presets
        guard let preset = userPresets.first(where: { $0.id == id }),
              !preset.isFactory else {
            return false
        }

        do {
            // Delete local file
            let fileURL = presetFileURL(for: id)
            try fileManager.removeItem(at: fileURL)

            // Remove from array
            userPresets.removeAll { $0.id == id }

            // Delete from CloudKit
            deleteFromCloud(presetID: id)

            return true

        } catch {
            print("Error deleting preset: \(error)")
            return false
        }
    }

    /// Duplicate a preset
    func duplicatePreset(_ preset: Preset) -> Preset {
        var duplicate = preset
        duplicate.id = UUID()
        duplicate.name = "\(preset.name) Copy"
        duplicate.isFactory = false
        duplicate.createdDate = Date()
        duplicate.modifiedDate = Date()

        _ = savePreset(duplicate)

        return duplicate
    }

    /// Toggle favorite status
    func toggleFavorite(id: UUID) {
        if let index = userPresets.firstIndex(where: { $0.id == id }) {
            userPresets[index].isFavorite.toggle()
            _ = savePreset(userPresets[index])
        }
    }

    // MARK: - Import/Export

    /// Export preset to JSON file
    func exportPreset(_ preset: Preset) -> URL? {
        do {
            let data = try JSONEncoder().encode(preset)
            let filename = "\(preset.name.replacingOccurrences(of: " ", with: "_")).echoepreset"
            let tempURL = fileManager.temporaryDirectory.appendingPathComponent(filename)

            try data.write(to: tempURL)

            return tempURL

        } catch {
            print("Error exporting preset: \(error)")
            return nil
        }
    }

    /// Import preset from JSON file
    func importPreset(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            var preset = try JSONDecoder().decode(Preset.self, from: data)

            // Generate new ID to avoid conflicts
            preset.id = UUID()
            preset.isFactory = false
            preset.cloudKitRecordID = nil

            return savePreset(preset)

        } catch {
            print("Error importing preset: \(error)")
            return false
        }
    }

    /// Share preset (creates shareable URL)
    func sharePreset(_ preset: Preset, completion: @escaping (URL?) -> Void) {
        // Create CloudKit share
        let record = presetToCloudKitRecord(preset)

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = preset.name as CKRecordValue
        share[CKShare.SystemFieldKey.thumbnailImageData] = nil

        let operation = CKModifyRecordsOperation(
            recordsToSave: [record, share],
            recordIDsToDelete: nil
        )

        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                // Get share URL
                cloudKitContainer.fetchShareMetadata(with: share.url!) { metadata, error in
                    if let shareURL = metadata?.url {
                        DispatchQueue.main.async {
                            completion(shareURL)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    }
                }
            case .failure(let error):
                print("Error sharing preset: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }

        cloudKitDatabase.add(operation)
    }

    // MARK: - Search & Filter

    /// Search presets by name, tags, or description
    func searchPresets(query: String) -> [Preset] {
        let allPresets = factoryPresets + userPresets
        let lowercaseQuery = query.lowercased()

        return allPresets.filter { preset in
            preset.name.lowercased().contains(lowercaseQuery) ||
            preset.description.lowercased().contains(lowercaseQuery) ||
            preset.tags.contains { $0.lowercased().contains(lowercaseQuery) } ||
            preset.author.lowercased().contains(lowercaseQuery)
        }
    }

    /// Filter presets by category
    func filterByCategory(_ category: PresetCategory) -> [Preset] {
        let allPresets = factoryPresets + userPresets
        return allPresets.filter { $0.category == category }
    }

    /// Get favorite presets
    var favoritePresets: [Preset] {
        userPresets.filter { $0.isFavorite }
    }

    // MARK: - CloudKit Sync

    private func syncToCloud(preset: Preset) {
        isSyncing = true

        let record = presetToCloudKitRecord(preset)

        cloudKitDatabase.save(record) { [weak self] savedRecord, error in
            DispatchQueue.main.async {
                self?.isSyncing = false

                if let error = error {
                    self?.syncError = error
                    print("CloudKit sync error: \(error)")
                } else if let recordID = savedRecord?.recordID.recordName {
                    // Update preset with CloudKit record ID
                    if let index = self?.userPresets.firstIndex(where: { $0.id == preset.id }) {
                        self?.userPresets[index].cloudKitRecordID = recordID
                    }
                }
            }
        }
    }

    private func syncFromCloud() {
        isSyncing = true

        let query = CKQuery(recordType: "Preset", predicate: NSPredicate(value: true))
        let operation = CKQueryOperation(query: query)

        var fetchedPresets: [Preset] = []

        operation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                if let preset = self.cloudKitRecordToPreset(record) {
                    fetchedPresets.append(preset)
                }
            case .failure(let error):
                print("Error fetching record: \(error)")
            }
        }

        operation.queryResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                self?.isSyncing = false

                switch result {
                case .success:
                    // Merge with local presets
                    self?.mergeCloudPresets(fetchedPresets)
                case .failure(let error):
                    self?.syncError = error
                    print("CloudKit query error: \(error)")
                }
            }
        }

        cloudKitDatabase.add(operation)
    }

    private func deleteFromCloud(presetID: UUID) {
        // Find CloudKit record ID
        guard let preset = userPresets.first(where: { $0.id == presetID }),
              let recordIDString = preset.cloudKitRecordID else {
            return
        }

        let recordID = CKRecord.ID(recordName: recordIDString)

        cloudKitDatabase.delete(withRecordID: recordID) { recordID, error in
            if let error = error {
                print("Error deleting from CloudKit: \(error)")
            }
        }
    }

    private func mergeCloudPresets(_ cloudPresets: [Preset]) {
        for cloudPreset in cloudPresets {
            if let localIndex = userPresets.firstIndex(where: { $0.id == cloudPreset.id }) {
                // Compare modification dates and keep newer
                if cloudPreset.modifiedDate > userPresets[localIndex].modifiedDate {
                    userPresets[localIndex] = cloudPreset
                    _ = savePreset(cloudPreset)
                }
            } else {
                // New preset from cloud
                userPresets.append(cloudPreset)
                _ = savePreset(cloudPreset)
            }
        }
    }

    // MARK: - Private Helpers

    private func loadUserPresets() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: presetsDirectory,
                includingPropertiesForKeys: nil
            )

            userPresets = fileURLs.compactMap { url in
                guard url.pathExtension == "json" else { return nil }

                do {
                    let data = try Data(contentsOf: url)
                    return try JSONDecoder().decode(Preset.self, from: data)
                } catch {
                    print("Error loading preset file \(url): \(error)")
                    return nil
                }
            }

        } catch {
            print("Error loading user presets: \(error)")
        }
    }

    private func presetFileURL(for id: UUID) -> URL {
        return presetsDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func presetToCloudKitRecord(_ preset: Preset) -> CKRecord {
        let recordID = CKRecord.ID(recordName: preset.cloudKitRecordID ?? UUID().uuidString)
        let record = CKRecord(recordType: "Preset", recordID: recordID)

        do {
            let data = try JSONEncoder().encode(preset)
            record["data"] = data as CKRecordValue
            record["name"] = preset.name as CKRecordValue
            record["category"] = preset.category.rawValue as CKRecordValue
            record["modifiedDate"] = preset.modifiedDate as CKRecordValue
        } catch {
            print("Error encoding preset for CloudKit: \(error)")
        }

        return record
    }

    private func cloudKitRecordToPreset(_ record: CKRecord) -> Preset? {
        guard let data = record["data"] as? Data else {
            return nil
        }

        do {
            var preset = try JSONDecoder().decode(Preset.self, from: data)
            preset.cloudKitRecordID = record.recordID.recordName
            return preset
        } catch {
            print("Error decoding preset from CloudKit: \(error)")
            return nil
        }
    }
}
