//
//  SpotlightIndexer.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Spotlight Search integration for projects and recordings
//

import Foundation
import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers

@MainActor
final class SpotlightIndexer {
    static let shared = SpotlightIndexer()

    private let searchableIndex = CSSearchableIndex.default()

    // MARK: - Index Project

    func indexProject(_ project: Project) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .audio)

        // Basic info
        attributeSet.title = project.name
        attributeSet.contentDescription = "\(project.tracks.count) tracks • \(formatDuration(project.duration))"

        // Metadata
        attributeSet.keywords = [
            "music",
            "project",
            "recording",
            "EOEL"
        ]

        if let genre = project.genre {
            attributeSet.keywords?.append(genre)
        }

        // Date
        attributeSet.contentCreationDate = project.createdAt
        attributeSet.contentModificationDate = project.modifiedAt

        // Thumbnail (if available)
        if let waveformImage = project.waveformThumbnail {
            attributeSet.thumbnailData = waveformImage.pngData()
        }

        // Additional metadata
        attributeSet.audioTrackNumber = NSNumber(value: project.tracks.count)
        attributeSet.duration = NSNumber(value: project.duration)

        // Create searchable item
        let item = CSSearchableItem(
            uniqueIdentifier: "project-\(project.id)",
            domainIdentifier: "app.eoel.projects",
            attributeSet: attributeSet
        )

        // Set expiration (don't expire unless deleted)
        item.expirationDate = Date.distantFuture

        // Index
        searchableIndex.indexSearchableItems([item]) { error in
            if let error = error {
                print("Failed to index project: \(error)")
            } else {
                print("Successfully indexed project: \(project.name)")
            }
        }
    }

    // MARK: - Index Recording

    func indexRecording(_ recording: Recording) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .audio)

        // Basic info
        attributeSet.title = recording.name
        attributeSet.contentDescription = "Recording • \(formatDuration(recording.duration))"

        // Metadata
        attributeSet.keywords = [
            "recording",
            "audio",
            "track",
            "EOEL"
        ]

        // Dates
        attributeSet.contentCreationDate = recording.createdAt
        attributeSet.contentModificationDate = recording.modifiedAt

        // Audio metadata
        attributeSet.duration = NSNumber(value: recording.duration)

        if let sampleRate = recording.sampleRate {
            attributeSet.audioSampleRate = NSNumber(value: sampleRate)
        }

        // Thumbnail
        if let waveformImage = recording.waveformImage {
            attributeSet.thumbnailData = waveformImage.pngData()
        }

        // Create searchable item
        let item = CSSearchableItem(
            uniqueIdentifier: "recording-\(recording.id)",
            domainIdentifier: "app.eoel.recordings",
            attributeSet: attributeSet
        )

        item.expirationDate = Date.distantFuture

        // Index
        searchableIndex.indexSearchableItems([item]) { error in
            if let error = error {
                print("Failed to index recording: \(error)")
            }
        }
    }

    // MARK: - Index Instrument

    func indexInstrument(_ instrument: Instrument) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)

        attributeSet.title = instrument.name
        attributeSet.contentDescription = "Instrument • \(instrument.category)"

        attributeSet.keywords = [
            "instrument",
            instrument.category.lowercased(),
            "EOEL"
        ]

        if let icon = instrument.icon {
            attributeSet.thumbnailData = icon.pngData()
        }

        let item = CSSearchableItem(
            uniqueIdentifier: "instrument-\(instrument.id)",
            domainIdentifier: "app.eoel.instruments",
            attributeSet: attributeSet
        )

        searchableIndex.indexSearchableItems([item]) { error in
            if let error = error {
                print("Failed to index instrument: \(error)")
            }
        }
    }

    // MARK: - Index EoelWork Gig

    func indexGig(_ gig: Gig) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)

        attributeSet.title = gig.title
        attributeSet.contentDescription = "\(gig.location) • \(gig.paymentAmount)"

        attributeSet.keywords = [
            "gig",
            "job",
            "work",
            "eoelwork",
            gig.category.lowercased()
        ]

        if let deadline = gig.deadline {
            attributeSet.dueDate = deadline
        }

        attributeSet.latitude = NSNumber(value: gig.latitude ?? 0)
        attributeSet.longitude = NSNumber(value: gig.longitude ?? 0)

        let item = CSSearchableItem(
            uniqueIdentifier: "gig-\(gig.id)",
            domainIdentifier: "app.eoel.gigs",
            attributeSet: attributeSet
        )

        // Gigs should expire
        item.expirationDate = gig.deadline ?? Date().addingTimeInterval(30 * 24 * 3600) // 30 days

        searchableIndex.indexSearchableItems([item]) { error in
            if let error = error {
                print("Failed to index gig: \(error)")
            }
        }
    }

    // MARK: - Delete Item

    func deleteItem(identifier: String) {
        searchableIndex.deleteSearchableItems(withIdentifiers: [identifier]) { error in
            if let error = error {
                print("Failed to delete item: \(error)")
            }
        }
    }

    func deleteProject(id: String) {
        deleteItem(identifier: "project-\(id)")
    }

    func deleteRecording(id: String) {
        deleteItem(identifier: "recording-\(id)")
    }

    // MARK: - Delete Domain

    func deleteAllProjects() {
        searchableIndex.deleteSearchableItems(withDomainIdentifiers: ["app.eoel.projects"]) { error in
            if let error = error {
                print("Failed to delete projects: \(error)")
            }
        }
    }

    func deleteAllRecordings() {
        searchableIndex.deleteSearchableItems(withDomainIdentifiers: ["app.eoel.recordings"]) { error in
            if let error = error {
                print("Failed to delete recordings: \(error)")
            }
        }
    }

    func deleteAllItems() {
        searchableIndex.deleteAllSearchableItems { error in
            if let error = error {
                print("Failed to delete all items: \(error)")
            }
        }
    }

    // MARK: - Batch Index

    func indexProjects(_ projects: [Project]) {
        let items = projects.map { project in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .audio)
            attributeSet.title = project.name
            attributeSet.contentDescription = "\(project.tracks.count) tracks"
            attributeSet.contentCreationDate = project.createdAt

            return CSSearchableItem(
                uniqueIdentifier: "project-\(project.id)",
                domainIdentifier: "app.eoel.projects",
                attributeSet: attributeSet
            )
        }

        searchableIndex.indexSearchableItems(items) { error in
            if let error = error {
                print("Failed to batch index projects: \(error)")
            } else {
                print("Successfully indexed \(projects.count) projects")
            }
        }
    }

    // MARK: - Reindex All

    func reindexAll(projects: [Project], recordings: [Recording]) async {
        // Delete existing
        deleteAllItems()

        // Wait a bit
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Reindex
        indexProjects(projects)

        for recording in recordings {
            indexRecording(recording)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Model Stubs (for compilation)

struct Project {
    let id: String
    let name: String
    let tracks: [Track]
    let duration: TimeInterval
    let genre: String?
    let createdAt: Date
    let modifiedAt: Date
    let waveformThumbnail: UIImage?
}

struct Track {
    let id: String
    let name: String
}

struct Recording {
    let id: String
    let name: String
    let duration: TimeInterval
    let sampleRate: Double?
    let createdAt: Date
    let modifiedAt: Date
    let waveformImage: UIImage?
}

struct Instrument {
    let id: String
    let name: String
    let category: String
    let icon: UIImage?
}

struct Gig {
    let id: String
    let title: String
    let location: String
    let paymentAmount: String
    let category: String
    let deadline: Date?
    let latitude: Double?
    let longitude: Double?
}

// MARK: - UTType Extension

extension UTType {
    static let audio = UTType(filenameExtension: "wav")!
}

// MARK: - Handling Spotlight Taps

/*
 In your SceneDelegate or App:

 func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
     if userActivity.activityType == CSSearchableItemActionType {
         guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
             return
         }

         // Parse identifier
         if identifier.hasPrefix("project-") {
             let projectID = identifier.replacingOccurrences(of: "project-", with: "")
             // Open project
             navigationCoordinator.openProject(id: projectID)
         } else if identifier.hasPrefix("recording-") {
             let recordingID = identifier.replacingOccurrences(of: "recording-", with: "")
             // Open recording
             navigationCoordinator.openRecording(id: recordingID)
         } else if identifier.hasPrefix("gig-") {
             let gigID = identifier.replacingOccurrences(of: "gig-", with: "")
             // Open gig details
             navigationCoordinator.openGig(id: gigID)
         }
     }
 }

 // When creating/updating a project:
 func saveProject(_ project: Project) {
     // Save to database
     database.save(project)

     // Index for Spotlight
     SpotlightIndexer.shared.indexProject(project)

     // Update widget
     updateWidget()
 }

 // When deleting a project:
 func deleteProject(_ project: Project) {
     // Delete from database
     database.delete(project)

     // Remove from Spotlight
     SpotlightIndexer.shared.deleteProject(id: project.id)

     // Update widget
     updateWidget()
 }
 */
