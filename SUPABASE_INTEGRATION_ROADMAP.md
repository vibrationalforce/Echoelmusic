# Supabase Integration Roadmap for Echoelmusic

## Executive Summary

**Current State:** Echoelmusic is a native iOS/cross-platform SwiftUI app with local file system storage (JSON) and basic CloudKit integration. No backend API or modern cloud service exists.

**Goal:** Integrate Supabase for user authentication, project/preset sync, and cloud storage.

---

## Quick Reference: What Needs to Be Added

### 1. User Authentication (Supabase Auth)
- Replace/supplement CloudKit auth with Supabase Auth
- Store JWT tokens securely in Keychain
- Implement login/signup UI
- Handle session persistence

### 2. Project/Preset Sync (Supabase DB)
- Create Supabase tables:
  - `users` (from Supabase Auth)
  - `projects` (equivalent to Session)
  - `presets` (audio effect/configuration presets)
  - `project_tracks` (tracks within a project)
  - `collaboration_shares` (for sharing)

### 3. Audio/File Storage (Supabase Storage)
- Upload audio files to Supabase Storage buckets
- Implement resumable uploads
- Add progress tracking and cancellation

### 4. Real-time Sync
- Use Supabase Realtime for collaborative editing
- Implement conflict resolution
- Offline queue for failed uploads

---

## Key Data Models & API Endpoints

### Supabase Schema (PostgreSQL)

```sql
-- Users (managed by Supabase Auth)
-- No need to create, Supabase Auth creates auth.users table

-- Projects (equivalent to Session)
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    tempo FLOAT DEFAULT 120.0,
    time_signature TEXT DEFAULT '4/4',
    duration FLOAT DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT now(),
    modified_at TIMESTAMP DEFAULT now(),
    is_public BOOLEAN DEFAULT false,
    created_at DESC
);

-- Tracks
CREATE TABLE tracks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT DEFAULT 'audio', -- audio, voice, binaural, spatial, master
    duration FLOAT DEFAULT 0,
    volume FLOAT DEFAULT 0.8,
    pan FLOAT DEFAULT 0.0,
    is_muted BOOLEAN DEFAULT false,
    is_soloed BOOLEAN DEFAULT false,
    audio_file_url TEXT, -- URL to file in Storage
    waveform_data FLOAT8[] DEFAULT NULL,
    created_at TIMESTAMP DEFAULT now(),
    modified_at TIMESTAMP DEFAULT now()
);

-- Bio Data Points
CREATE TABLE bio_data_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    timestamp FLOAT NOT NULL,
    hrv FLOAT NOT NULL,
    heart_rate FLOAT NOT NULL,
    coherence FLOAT NOT NULL,
    audio_level FLOAT NOT NULL,
    frequency FLOAT NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

-- Presets
CREATE TABLE presets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT DEFAULT 'audio', -- audio, effect, visualization
    config JSONB NOT NULL, -- JSON configuration
    is_favorite BOOLEAN DEFAULT false,
    is_shared BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT now(),
    modified_at TIMESTAMP DEFAULT now()
);

-- Shared Projects
CREATE TABLE project_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    shared_with_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    permission TEXT DEFAULT 'view', -- view, edit, admin
    created_at TIMESTAMP DEFAULT now()
);

-- Create indices for performance
CREATE INDEX idx_projects_user_id ON projects(user_id);
CREATE INDEX idx_tracks_project_id ON tracks(project_id);
CREATE INDEX idx_bio_data_project_id ON bio_data_points(project_id);
CREATE INDEX idx_presets_user_id ON presets(user_id);
```

### Supabase RLS (Row Level Security)
```sql
-- Enable RLS on all tables
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE bio_data_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE presets ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_shares ENABLE ROW LEVEL SECURITY;

-- Projects: Users can only see their own projects + shared ones
CREATE POLICY "Users can view own projects"
  ON projects FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own projects"
  ON projects FOR UPDATE
  USING (auth.uid() = user_id);

-- Similar policies for other tables...
```

---

## Implementation Roadmap

### Phase 1: Authentication Setup (2-3 days)
**Files to Create:**
- `/Sources/Echoelmusic/Backend/Services/SupabaseClient.swift`
- `/Sources/Echoelmusic/Backend/Services/AuthService.swift`
- `/Sources/Echoelmusic/Backend/Models/AuthUser.swift`

**Tasks:**
1. Add Supabase Swift SDK to Package.swift
2. Create SupabaseClient singleton with session management
3. Implement AuthService with:
   - User signup/login/logout
   - Token refresh logic
   - Keychain storage for JWT tokens
4. Add auth state to EchoelmusicApp
5. Create simple login/signup UI

**Testing Checklist:**
- [ ] User can sign up via Supabase Auth
- [ ] User can log in
- [ ] Session persists across app restarts
- [ ] Logout clears session

---

### Phase 2: Project Sync (3-4 days)
**Files to Create:**
- `/Sources/Echoelmusic/Backend/Services/ProjectService.swift`
- `/Sources/Echoelmusic/Backend/Models/APIProject.swift`
- `/Sources/Echoelmusic/Backend/Models/APITrack.swift`

**Tasks:**
1. Extend CloudSyncManager to use Supabase
2. Create ProjectService with CRUD methods:
   - `createProject(name, tempo, timeSignature) -> APIProject`
   - `listProjects() -> [APIProject]`
   - `updateProject(id, name, metadata) -> APIProject`
   - `deleteProject(id)`
3. Modify RecordingEngine to save to cloud after local save
4. Implement conflict resolution (timestamp-based)
5. Add sync status indicator to UI

**Testing Checklist:**
- [ ] Projects are saved to Supabase after local save
- [ ] Projects can be fetched from Supabase
- [ ] Projects list shows all user's projects
- [ ] Project updates are synced
- [ ] Deleted projects are removed from cloud

---

### Phase 3: File Storage (2-3 days)
**Files to Create:**
- `/Sources/Echoelmusic/Backend/Services/StorageService.swift`
- `/Sources/Echoelmusic/Backend/Models/UploadProgress.swift`

**Tasks:**
1. Create StorageService for uploading audio files
2. Implement resumable uploads with progress tracking
3. Create storage buckets in Supabase:
   - `audio-files` (private, user-scoped)
   - `user-presets` (private)
4. Modify Track to store cloud URL instead of local path
5. Implement lazy-loading for audio playback

**Testing Checklist:**
- [ ] Audio files upload to Supabase Storage
- [ ] Upload progress is tracked
- [ ] Large files can be resumed
- [ ] Downloaded files are cached locally
- [ ] Audio playback works with cloud URLs

---

### Phase 4: Presets (1-2 days)
**Files to Create:**
- `/Sources/Echoelmusic/Backend/Services/PresetService.swift`

**Tasks:**
1. Create PresetService with CRUD methods
2. Save audio effect presets to Supabase
3. Allow sharing presets with other users
4. Implement preset browsing UI

---

### Phase 5: Real-time & Offline (2-3 days)
**Files to Create:**
- `/Sources/Echoelmusic/Backend/Middleware/OfflineQueue.swift`
- `/Sources/Echoelmusic/Backend/Middleware/RealtimeSync.swift`

**Tasks:**
1. Implement offline queue for failed uploads
2. Add Supabase Realtime subscriptions
3. Implement sync conflict resolution
4. Add network status monitoring

---

## File Structure for Supabase Integration

```
Sources/Echoelmusic/
├── Backend/                                    # NEW
│   ├── Services/
│   │   ├── SupabaseClient.swift              # Singleton with session management
│   │   ├── AuthService.swift                 # Authentication
│   │   ├── ProjectService.swift              # Project CRUD
│   │   ├── TrackService.swift                # Track CRUD
│   │   ├── StorageService.swift              # File uploads
│   │   ├── PresetService.swift               # Preset management
│   │   └── BioDataService.swift              # Bio data sync
│   ├── Models/
│   │   ├── AuthUser.swift                    # User from Supabase Auth
│   │   ├── APIProject.swift                  # Project API model
│   │   ├── APITrack.swift                    # Track API model
│   │   ├── APIBioDataPoint.swift             # Bio data API model
│   │   └── APIPreset.swift                   # Preset API model
│   ├── Error/
│   │   └── NetworkError.swift                # Unified error handling
│   └── Middleware/
│       ├── AuthInterceptor.swift             # Token management
│       ├── OfflineQueue.swift                # Queue failed uploads
│       └── RealtimeSync.swift                # Real-time sync
├── Recording/                                  # EXISTING (modify)
│   ├── Session.swift                         # Add cloud_id field
│   ├── Track.swift                           # Add cloud_url field
│   ├── RecordingEngine.swift                 # Add cloud sync hooks
│   └── ExportManager.swift
├── Cloud/                                      # EXISTING (extend)
│   └── CloudSyncManager.swift                # Add Supabase support
└── EchoelmusicApp.swift                      # EXISTING (modify)
```

---

## Integration Points in Existing Code

### 1. EchoelmusicApp.swift
```swift
@main
struct EchoelmusicApp: App {
    // Add auth state
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            if authService.isLoggedIn {
                ContentView()
                    .environmentObject(authService)
                    .environmentObject(recordingEngine)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
}
```

### 2. RecordingEngine.swift
```swift
func saveSession(_ session: Session) async throws {
    // Save locally first
    try session.save()
    
    // Then sync to cloud if authenticated
    if authService.isLoggedIn {
        try await projectService.syncSession(session)
    }
}
```

### 3. CloudSyncManager.swift
```swift
// Replace CloudKit with Supabase
@MainActor
class CloudSyncManager: ObservableObject {
    private let projectService: ProjectService
    
    func saveSession(_ session: Session) async throws {
        try await projectService.createOrUpdateProject(from: session)
    }
}
```

---

## Key Decisions

### Local-First Architecture
- Keep local JSON storage as source of truth
- Sync to cloud asynchronously
- Offline queue for failed uploads
- Rationale: Audio files are large and require local caching

### Auth Strategy
- Use Supabase Auth (username/password or OAuth)
- Store JWT in Keychain (not UserDefaults)
- Implement refresh token rotation
- Allow local-only mode (no auth required initially)

### File Storage
- Use Supabase Storage for audio files (not database)
- Generate signed URLs for playback
- Implement resumable uploads for large files
- Cache downloads locally

### Conflict Resolution
- Last-write-wins with timestamp comparison
- Prefer cloud version if newer than local
- Log conflicts for debugging
- Implement three-way merge for complex conflicts

---

## Package.swift Updates

```swift
let package = Package(
    name: "Echoelmusic",
    // ... existing config ...
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "Echoelmusic",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
    ]
)
```

---

## Testing Strategy

### Unit Tests
- AuthService (login/logout/refresh)
- ProjectService (CRUD operations)
- StorageService (upload/download)
- OfflineQueue (queueing/retrying)

### Integration Tests
- End-to-end project creation → upload → download
- Conflict resolution scenarios
- Offline sync scenarios

### Manual Testing
- Login with test account
- Create project with audio
- Check Supabase dashboard
- Verify files in Storage
- Test on poor network conditions

---

## Security Considerations

1. **Never store sensitive data in code**
   - Use Supabase Config from environment variables
   - Store JWT in Keychain, not UserDefaults

2. **Implement RLS policies**
   - Users can only see their own data
   - Shared data uses explicit permissions

3. **Validate on backend**
   - Don't trust client-side data
   - Implement server-side validation

4. **Use HTTPS/WSS only**
   - Supabase enforces this automatically

5. **Implement rate limiting**
   - Prevent abuse of API endpoints

---

## Estimated Timeline

- **Week 1:** Authentication + Project Sync (Phase 1-2)
- **Week 2:** File Storage + Presets (Phase 3-4)
- **Week 3:** Real-time + Polish (Phase 5)

**Total: 3-4 weeks for full implementation**

---

## Quick Start Checklist

- [ ] Create Supabase project
- [ ] Create database schema (see SQL above)
- [ ] Enable Supabase Auth (Email)
- [ ] Create Storage buckets
- [ ] Set up RLS policies
- [ ] Clone this repo and create Backend/ folder structure
- [ ] Add Supabase SDK to Package.swift
- [ ] Implement SupabaseClient singleton
- [ ] Implement AuthService
- [ ] Create login UI
- [ ] Test authentication flow
- [ ] Continue with phases 2-5...

