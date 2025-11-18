import Foundation
import Supabase

/// Supabase Client Singleton
/// Provides centralized access to Supabase services (Auth, Database, Storage, Realtime)
@MainActor
class SupabaseClient: ObservableObject {

    // MARK: - Singleton

    static let shared = SupabaseClient()

    // MARK: - Supabase Client

    let client: SupabaseClient

    // MARK: - Published State

    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var authError: Error?

    // MARK: - Configuration

    private let supabaseURL: URL
    private let supabaseAnonKey: String

    // MARK: - Initialization

    private init() {
        // Load from environment or configuration
        // TODO: Move to secure configuration (not hardcoded!)
        guard let url = ProcessInfo.processInfo.environment["SUPABASE_URL"],
              let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] else {
            fatalError("SUPABASE_URL and SUPABASE_ANON_KEY must be set in environment")
        }

        guard let supabaseURL = URL(string: url) else {
            fatalError("Invalid SUPABASE_URL")
        }

        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = key

        // Initialize Supabase client
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey,
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(
                    schema: "public"
                ),
                auth: SupabaseClientOptions.AuthOptions(
                    autoRefreshToken: true,
                    persistSession: true,
                    detectSessionInURL: false
                ),
                global: SupabaseClientOptions.GlobalOptions(
                    headers: [
                        "X-Client-Info": "echoelmusic-ios/1.0.0"
                    ]
                )
            )
        )

        // Listen to auth state changes
        Task {
            await setupAuthListener()
        }
    }

    // MARK: - Auth State Listener

    private func setupAuthListener() async {
        for await event in client.auth.authStateChanges {
            switch event {
            case .signedIn(let session):
                self.currentUser = session.user
                self.isAuthenticated = true
                print("✅ User signed in: \(session.user.id)")

            case .signedOut:
                self.currentUser = nil
                self.isAuthenticated = false
                print("👋 User signed out")

            case .tokenRefreshed(let session):
                self.currentUser = session.user
                print("🔄 Token refreshed")

            case .userUpdated(let user):
                self.currentUser = user
                print("👤 User updated: \(user.id)")

            case .passwordRecovery:
                print("🔑 Password recovery initiated")

            default:
                break
            }
        }
    }

    // MARK: - Database Helpers

    /// Execute a database query
    func query<T: Decodable>(_ table: String) -> PostgrestQueryBuilder<T> {
        return client.database.from(table)
    }

    /// Execute a database RPC function
    func rpc<T: Decodable>(_ function: String, params: [String: Any] = [:]) async throws -> T {
        return try await client.database.rpc(function, params: params).execute().value
    }

    // MARK: - Storage Helpers

    /// Upload file to storage
    func uploadFile(
        bucket: String,
        path: String,
        file: Data,
        contentType: String? = nil
    ) async throws -> String {
        let options = FileOptions(
            cacheControl: "3600",
            contentType: contentType,
            upsert: false
        )

        try await client.storage.from(bucket).upload(
            path: path,
            file: file,
            options: options
        )

        // Return public URL
        return client.storage.from(bucket).getPublicURL(path: path)
    }

    /// Download file from storage
    func downloadFile(bucket: String, path: String) async throws -> Data {
        return try await client.storage.from(bucket).download(path: path)
    }

    /// Get public URL for file
    func getPublicURL(bucket: String, path: String) -> String {
        return client.storage.from(bucket).getPublicURL(path: path)
    }

    /// Delete file from storage
    func deleteFile(bucket: String, paths: [String]) async throws {
        try await client.storage.from(bucket).remove(paths: paths)
    }

    // MARK: - Realtime Helpers

    /// Subscribe to realtime changes
    func subscribe(
        to channel: String,
        table: String,
        event: RealtimeChannel.PostgresChangeEvent,
        filter: String? = nil,
        callback: @escaping (RealtimeChannel.PostgresChangePayload) -> Void
    ) -> RealtimeChannel {
        var channelBuilder = client.realtime.channel(channel)
            .on(.postgres(
                event: event,
                schema: "public",
                table: table
            ), callback: callback)

        if let filter = filter {
            channelBuilder = channelBuilder.on(.postgres(
                event: event,
                schema: "public",
                table: table,
                filter: filter
            ), callback: callback)
        }

        Task {
            await channelBuilder.subscribe()
        }

        return channelBuilder
    }

    // MARK: - Auth Error Handling

    func handleAuthError(_ error: Error) {
        self.authError = error
        print("❌ Auth error: \(error.localizedDescription)")
    }
}

// MARK: - Storage Bucket Names

extension SupabaseClient {
    enum StorageBucket {
        static let audioFiles = "audio-files"
        static let projectThumbnails = "project-thumbnails"
        static let presetPreviews = "preset-previews"
        static let userAvatars = "user-avatars"
    }
}

// MARK: - Database Table Names

extension SupabaseClient {
    enum Table {
        static let profiles = "profiles"
        static let projects = "projects"
        static let tracks = "tracks"
        static let bioDataPoints = "bio_data_points"
        static let presets = "presets"
        static let projectShares = "project_shares"
        static let achievements = "achievements"
        static let userAchievements = "user_achievements"
        static let analyticsEvents = "analytics_events"
    }
}
