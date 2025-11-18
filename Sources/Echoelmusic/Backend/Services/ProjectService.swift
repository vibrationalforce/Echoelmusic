import Foundation
import Supabase

/// Project Service
/// Handles CRUD operations for projects (sessions) in the cloud
@MainActor
class ProjectService: ObservableObject {

    // MARK: - Dependencies

    private let supabase = SupabaseClient.shared
    private let authService: AuthService

    // MARK: - Published State

    @Published var projects: [CloudProject] = []
    @Published var isLoading: Bool = false
    @Published var isSyncing: Bool = false
    @Published var errorMessage: String?

    // MARK: - Initialization

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - Fetch Projects

    /// Fetch all user's projects from cloud
    func fetchProjects() async throws {
        guard authService.isLoggedIn else {
            throw ProjectError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: [CloudProject] = try await supabase.query(SupabaseClient.Table.projects)
                .select("*")
                .order("updated_at", ascending: false)
                .execute()
                .value

            self.projects = response
            print("✅ Fetched \(response.count) projects")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to fetch projects: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Create Project

    /// Create new project in cloud
    func createProject(
        name: String,
        description: String? = nil,
        genre: String? = nil,
        tempo: Float = 120.0,
        timeSignature: String = "4/4"
    ) async throws -> CloudProject {
        guard let userId = authService.currentUser?.id else {
            throw ProjectError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let newProject: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "name": .string(name),
                "description": .string(description ?? ""),
                "genre": .string(genre ?? ""),
                "tempo": .number(Double(tempo)),
                "time_signature": .string(timeSignature)
            ]

            let response: CloudProject = try await supabase.query(SupabaseClient.Table.projects)
                .insert(newProject)
                .single()
                .execute()
                .value

            // Add to local cache
            self.projects.insert(response, at: 0)

            print("✅ Project created: \(response.id)")
            return response
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to create project: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Update Project

    /// Update existing project in cloud
    func updateProject(
        id: UUID,
        name: String? = nil,
        description: String? = nil,
        genre: String? = nil,
        tempo: Float? = nil,
        duration: Float? = nil
    ) async throws -> CloudProject {
        guard authService.isLoggedIn else {
            throw ProjectError.notAuthenticated
        }

        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }

        do {
            var updates: [String: AnyJSON] = [:]
            if let name = name { updates["name"] = .string(name) }
            if let description = description { updates["description"] = .string(description) }
            if let genre = genre { updates["genre"] = .string(genre) }
            if let tempo = tempo { updates["tempo"] = .number(Double(tempo)) }
            if let duration = duration { updates["duration"] = .number(Double(duration)) }

            let response: CloudProject = try await supabase.query(SupabaseClient.Table.projects)
                .update(updates)
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value

            // Update local cache
            if let index = projects.firstIndex(where: { $0.id == id }) {
                projects[index] = response
            }

            print("✅ Project updated: \(id)")
            return response
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to update project: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Delete Project

    /// Delete project from cloud
    func deleteProject(id: UUID) async throws {
        guard authService.isLoggedIn else {
            throw ProjectError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.query(SupabaseClient.Table.projects)
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            // Remove from local cache
            projects.removeAll { $0.id == id }

            print("✅ Project deleted: \(id)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to delete project: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Sync Local Session to Cloud

    /// Sync local session to cloud (create or update)
    func syncSession(_ session: Session) async throws {
        guard let userId = authService.currentUser?.id else {
            throw ProjectError.notAuthenticated
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            // Check if project exists in cloud
            if let cloudId = session.cloudId {
                // Update existing project
                _ = try await updateProject(
                    id: cloudId,
                    name: session.name,
                    duration: Float(session.duration)
                )
            } else {
                // Create new project
                let cloudProject = try await createProject(
                    name: session.name,
                    tempo: Float(session.tempo)
                )

                // TODO: Update local session with cloud ID
                // session.cloudId = cloudProject.id
            }

            print("✅ Session synced to cloud")
        } catch {
            print("❌ Failed to sync session: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Upload Audio Files

    /// Upload track audio file to cloud storage
    func uploadTrackAudio(
        projectId: UUID,
        trackId: UUID,
        audioData: Data
    ) async throws -> String {
        guard authService.isLoggedIn else {
            throw ProjectError.notAuthenticated
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let fileName = "\(trackId.uuidString).wav"
            let path = "projects/\(projectId.uuidString)/tracks/\(fileName)"

            let url = try await supabase.uploadFile(
                bucket: SupabaseClient.StorageBucket.audioFiles,
                path: path,
                file: audioData,
                contentType: "audio/wav"
            )

            // Update track record with audio URL
            let _: CloudTrack = try await supabase.query(SupabaseClient.Table.tracks)
                .update(["audio_file_url": .string(url)])
                .eq("id", value: trackId.uuidString)
                .single()
                .execute()
                .value

            print("✅ Track audio uploaded: \(url)")
            return url
        } catch {
            print("❌ Failed to upload track audio: \(error.localizedDescription)")
            throw error
        }
    }

    /// Upload project thumbnail
    func uploadThumbnail(
        projectId: UUID,
        imageData: Data
    ) async throws -> String {
        guard authService.isLoggedIn else {
            throw ProjectError.notAuthenticated
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let fileName = "\(projectId.uuidString).jpg"
            let path = "thumbnails/\(fileName)"

            let url = try await supabase.uploadFile(
                bucket: SupabaseClient.StorageBucket.projectThumbnails,
                path: path,
                file: imageData,
                contentType: "image/jpeg"
            )

            // Update project with thumbnail URL
            _ = try await updateProject(id: projectId)
            // Note: Need to add thumbnailUrl parameter to updateProject

            print("✅ Thumbnail uploaded: \(url)")
            return url
        } catch {
            print("❌ Failed to upload thumbnail: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Realtime Collaboration

    /// Subscribe to project changes (for real-time collaboration)
    func subscribeToProject(id: UUID, onUpdate: @escaping (CloudProject) -> Void) -> RealtimeChannel {
        return supabase.subscribe(
            to: "project-\(id.uuidString)",
            table: SupabaseClient.Table.projects,
            event: .update,
            filter: "id=eq.\(id.uuidString)"
        ) { payload in
            if let updatedProject = try? JSONDecoder().decode(CloudProject.self, from: payload.new) {
                Task { @MainActor in
                    onUpdate(updatedProject)
                }
            }
        }
    }
}

// MARK: - Models

/// Cloud Project (matches database schema)
struct CloudProject: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    var name: String
    var description: String?
    var genre: String?
    var mood: String?
    var tags: [String]
    var tempo: Float
    var timeSignature: String
    var keySignature: String?
    var duration: Float
    var sampleRate: Int
    var isPublic: Bool
    var isCollaborative: Bool
    var collaborators: [UUID]
    var thumbnailUrl: String?
    var audioPreviewUrl: String?
    var playCount: Int
    var likeCount: Int
    var forkCount: Int
    let createdAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date
    var version: Int
    var parentProjectId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, description, genre, mood, tags
        case tempo
        case timeSignature = "time_signature"
        case keySignature = "key_signature"
        case duration
        case sampleRate = "sample_rate"
        case isPublic = "is_public"
        case isCollaborative = "is_collaborative"
        case collaborators
        case thumbnailUrl = "thumbnail_url"
        case audioPreviewUrl = "audio_preview_url"
        case playCount = "play_count"
        case likeCount = "like_count"
        case forkCount = "fork_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastOpenedAt = "last_opened_at"
        case version
        case parentProjectId = "parent_project_id"
    }
}

/// Cloud Track (matches database schema)
struct CloudTrack: Identifiable, Codable {
    let id: UUID
    let projectId: UUID
    var name: String
    var trackType: String
    var trackIndex: Int
    var duration: Float
    var sampleRate: Int
    var bitDepth: Int
    var channels: Int
    var volume: Float
    var pan: Float
    var isMuted: Bool
    var isSoloed: Bool
    var isArmed: Bool
    var effects: [String] // JSON array
    var audioFileUrl: String?
    var waveformData: [Float]
    var midiData: [String: String]? // JSON object
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case name
        case trackType = "track_type"
        case trackIndex = "track_index"
        case duration
        case sampleRate = "sample_rate"
        case bitDepth = "bit_depth"
        case channels, volume, pan
        case isMuted = "is_muted"
        case isSoloed = "is_soloed"
        case isArmed = "is_armed"
        case effects
        case audioFileUrl = "audio_file_url"
        case waveformData = "waveform_data"
        case midiData = "midi_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Errors

enum ProjectError: LocalizedError {
    case notAuthenticated
    case projectNotFound
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .projectNotFound:
            return "Project not found"
        case .uploadFailed:
            return "File upload failed"
        }
    }
}
