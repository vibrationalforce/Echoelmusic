-- ============================================================================
-- ECHOELMUSIC SUPABASE DATABASE SCHEMA
-- Multi-Platform Cloud Backend (iOS, Desktop, Web, Plugins)
-- Version: 1.0.0
-- Date: 2025-11-18
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- USERS TABLE
-- ============================================================================
-- NOTE: Supabase Auth automatically creates auth.users table
-- We create a public.profiles table for extended user data

CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    full_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    website TEXT,

    -- Subscription info
    subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'pro', 'teams', 'enterprise')),
    subscription_status TEXT DEFAULT 'active' CHECK (subscription_status IN ('active', 'canceled', 'past_due', 'trialing')),
    subscription_ends_at TIMESTAMP WITH TIME ZONE,

    -- Usage limits
    projects_count INTEGER DEFAULT 0,
    presets_count INTEGER DEFAULT 0,
    storage_used_mb FLOAT DEFAULT 0,

    -- Gamification
    xp_points INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    achievements JSONB DEFAULT '[]',

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

    -- Platform info
    primary_platform TEXT, -- ios, macos, windows, linux, android, web
    device_info JSONB
);

-- Index for fast username lookups
CREATE INDEX idx_profiles_username ON public.profiles(username);
CREATE INDEX idx_profiles_subscription ON public.profiles(subscription_tier, subscription_status);

-- ============================================================================
-- PROJECTS TABLE (Sessions)
-- ============================================================================

CREATE TABLE public.projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,

    -- Project metadata
    name TEXT NOT NULL,
    description TEXT,
    genre TEXT,
    mood TEXT,
    tags TEXT[], -- Array of tags

    -- Audio settings
    tempo FLOAT DEFAULT 120.0,
    time_signature TEXT DEFAULT '4/4',
    key_signature TEXT, -- C, Am, etc.
    duration FLOAT DEFAULT 0, -- seconds
    sample_rate INTEGER DEFAULT 48000,

    -- Collaboration
    is_public BOOLEAN DEFAULT false,
    is_collaborative BOOLEAN DEFAULT false,
    collaborators UUID[], -- Array of user IDs

    -- Cloud storage
    thumbnail_url TEXT,
    audio_preview_url TEXT, -- 30s preview MP3

    -- Statistics
    play_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    fork_count INTEGER DEFAULT 0, -- How many times remixed

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    last_opened_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

    -- Version control
    version INTEGER DEFAULT 1,
    parent_project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL -- For forks/remixes
);

-- Indices for fast queries
CREATE INDEX idx_projects_user_id ON public.projects(user_id);
CREATE INDEX idx_projects_public ON public.projects(is_public) WHERE is_public = true;
CREATE INDEX idx_projects_created_at ON public.projects(created_at DESC);
CREATE INDEX idx_projects_updated_at ON public.projects(updated_at DESC);
CREATE INDEX idx_projects_tags ON public.projects USING GIN(tags); -- GIN index for array searches

-- ============================================================================
-- TRACKS TABLE
-- ============================================================================

CREATE TABLE public.tracks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,

    -- Track metadata
    name TEXT NOT NULL,
    track_type TEXT DEFAULT 'audio' CHECK (track_type IN ('audio', 'voice', 'binaural', 'spatial', 'master', 'midi')),
    track_index INTEGER DEFAULT 0, -- Order in DAW

    -- Audio properties
    duration FLOAT DEFAULT 0,
    sample_rate INTEGER DEFAULT 48000,
    bit_depth INTEGER DEFAULT 24,
    channels INTEGER DEFAULT 2, -- 1=mono, 2=stereo, 6=5.1, etc.

    -- Mix settings
    volume FLOAT DEFAULT 0.8,
    pan FLOAT DEFAULT 0.0, -- -1.0 (left) to 1.0 (right)
    is_muted BOOLEAN DEFAULT false,
    is_soloed BOOLEAN DEFAULT false,
    is_armed BOOLEAN DEFAULT false, -- Record armed

    -- Effects chain (array of effect IDs/names)
    effects JSONB DEFAULT '[]',

    -- Cloud storage
    audio_file_url TEXT, -- URL in Supabase Storage
    waveform_data FLOAT[], -- Waveform peaks for visualization

    -- MIDI data (if track_type = 'midi')
    midi_data JSONB,

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX idx_tracks_project_id ON public.tracks(project_id);
CREATE INDEX idx_tracks_type ON public.tracks(track_type);

-- ============================================================================
-- BIO DATA POINTS TABLE
-- ============================================================================

CREATE TABLE public.bio_data_points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,

    -- Timestamp (relative to project start)
    timestamp FLOAT NOT NULL, -- seconds

    -- HealthKit data
    hrv FLOAT, -- Heart Rate Variability (ms)
    heart_rate FLOAT, -- BPM
    coherence FLOAT, -- HeartMath coherence (0-1)
    breathing_rate FLOAT, -- breaths per minute

    -- Audio feedback
    audio_level FLOAT, -- dB
    frequency FLOAT, -- Hz (pitch)

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX idx_bio_data_project_id ON public.bio_data_points(project_id);
CREATE INDEX idx_bio_data_timestamp ON public.bio_data_points(project_id, timestamp);

-- ============================================================================
-- PRESETS TABLE
-- ============================================================================

CREATE TABLE public.presets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,

    -- Preset metadata
    name TEXT NOT NULL,
    description TEXT,
    category TEXT, -- eq, compressor, reverb, etc.
    preset_type TEXT CHECK (preset_type IN ('audio_effect', 'instrument', 'visualization', 'spatial', 'bio_mapping')),

    -- Preset configuration (JSON)
    config JSONB NOT NULL,

    -- Tags and search
    tags TEXT[],
    is_favorite BOOLEAN DEFAULT false,

    -- Sharing
    is_public BOOLEAN DEFAULT false,
    is_verified BOOLEAN DEFAULT false, -- Curated by Echoelmusic team

    -- Statistics
    download_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    rating FLOAT, -- Average rating (1-5)
    rating_count INTEGER DEFAULT 0,

    -- Monetization (for marketplace)
    is_paid BOOLEAN DEFAULT false,
    price_usd FLOAT,
    sales_count INTEGER DEFAULT 0,

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX idx_presets_user_id ON public.presets(user_id);
CREATE INDEX idx_presets_public ON public.presets(is_public) WHERE is_public = true;
CREATE INDEX idx_presets_category ON public.presets(category);
CREATE INDEX idx_presets_type ON public.presets(preset_type);
CREATE INDEX idx_presets_tags ON public.presets USING GIN(tags);

-- ============================================================================
-- PROJECT SHARES TABLE (Collaboration)
-- ============================================================================

CREATE TABLE public.project_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
    shared_with_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    shared_by_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,

    -- Permissions
    permission TEXT DEFAULT 'view' CHECK (permission IN ('view', 'comment', 'edit', 'admin')),

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    accepted_at TIMESTAMP WITH TIME ZONE,

    UNIQUE(project_id, shared_with_user_id)
);

CREATE INDEX idx_project_shares_project ON public.project_shares(project_id);
CREATE INDEX idx_project_shares_user ON public.project_shares(shared_with_user_id);

-- ============================================================================
-- ACHIEVEMENTS TABLE
-- ============================================================================

CREATE TABLE public.achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Achievement definition
    achievement_key TEXT UNIQUE NOT NULL, -- first_project, 10_projects, etc.
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    icon_url TEXT,

    -- Rewards
    xp_reward INTEGER DEFAULT 0,

    -- Requirements (JSON)
    requirements JSONB,

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- User achievements (many-to-many)
CREATE TABLE public.user_achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    achievement_id UUID REFERENCES public.achievements(id) ON DELETE CASCADE NOT NULL,

    -- Progress
    progress INTEGER DEFAULT 0, -- For incremental achievements
    is_unlocked BOOLEAN DEFAULT false,
    unlocked_at TIMESTAMP WITH TIME ZONE,

    UNIQUE(user_id, achievement_id)
);

CREATE INDEX idx_user_achievements_user ON public.user_achievements(user_id);

-- ============================================================================
-- ANALYTICS/EVENTS TABLE
-- ============================================================================

CREATE TABLE public.analytics_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,

    -- Event data
    event_type TEXT NOT NULL, -- project_created, preset_downloaded, etc.
    event_data JSONB,

    -- Platform info
    platform TEXT, -- ios, macos, windows, etc.
    app_version TEXT,

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX idx_analytics_user ON public.analytics_events(user_id);
CREATE INDEX idx_analytics_type ON public.analytics_events(event_type);
CREATE INDEX idx_analytics_created_at ON public.analytics_events(created_at DESC);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bio_data_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- Projects: Users can see their own + public + shared
CREATE POLICY "Users can view own projects"
    ON public.projects FOR SELECT
    USING (auth.uid() = user_id OR is_public = true OR id IN (
        SELECT project_id FROM public.project_shares WHERE shared_with_user_id = auth.uid()
    ));

CREATE POLICY "Users can create own projects"
    ON public.projects FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own projects"
    ON public.projects FOR UPDATE
    USING (auth.uid() = user_id OR id IN (
        SELECT project_id FROM public.project_shares
        WHERE shared_with_user_id = auth.uid() AND permission IN ('edit', 'admin')
    ));

CREATE POLICY "Users can delete own projects"
    ON public.projects FOR DELETE
    USING (auth.uid() = user_id);

-- Tracks: Access controlled by project access
CREATE POLICY "Users can view tracks of accessible projects"
    ON public.tracks FOR SELECT
    USING (project_id IN (
        SELECT id FROM public.projects
        WHERE user_id = auth.uid() OR is_public = true OR id IN (
            SELECT project_id FROM public.project_shares WHERE shared_with_user_id = auth.uid()
        )
    ));

CREATE POLICY "Users can modify tracks of owned/editable projects"
    ON public.tracks FOR ALL
    USING (project_id IN (
        SELECT id FROM public.projects WHERE user_id = auth.uid()
        UNION
        SELECT project_id FROM public.project_shares
        WHERE shared_with_user_id = auth.uid() AND permission IN ('edit', 'admin')
    ));

-- Bio Data: Same as tracks
CREATE POLICY "Users can view bio data of accessible projects"
    ON public.bio_data_points FOR SELECT
    USING (project_id IN (
        SELECT id FROM public.projects
        WHERE user_id = auth.uid() OR is_public = true OR id IN (
            SELECT project_id FROM public.project_shares WHERE shared_with_user_id = auth.uid()
        )
    ));

CREATE POLICY "Users can add bio data to owned projects"
    ON public.bio_data_points FOR INSERT
    WITH CHECK (project_id IN (
        SELECT id FROM public.projects WHERE user_id = auth.uid()
    ));

-- Presets: Users can view public presets + own private
CREATE POLICY "Users can view public presets"
    ON public.presets FOR SELECT
    USING (is_public = true OR user_id = auth.uid());

CREATE POLICY "Users can create own presets"
    ON public.presets FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own presets"
    ON public.presets FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own presets"
    ON public.presets FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for auto-updating updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON public.projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tracks_updated_at BEFORE UPDATE ON public.tracks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_presets_updated_at BEFORE UPDATE ON public.presets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public.profiles (id, username, full_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create profile
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- STORAGE BUCKETS
-- ============================================================================

-- Create storage buckets (run in Supabase Dashboard → Storage)
-- bucket: audio-files (private)
-- bucket: project-thumbnails (public)
-- bucket: preset-previews (public)
-- bucket: user-avatars (public)

-- Storage policies (run in Supabase Dashboard → Storage → Policies)
-- audio-files: Only owner can upload/download
-- project-thumbnails: Public read, owner write
-- preset-previews: Public read, owner write
-- user-avatars: Public read, owner write

-- ============================================================================
-- SEED DATA (Development/Testing)
-- ============================================================================

-- Insert default achievements
INSERT INTO public.achievements (achievement_key, title, description, xp_reward) VALUES
    ('first_project', 'First Steps', 'Create your first project', 100),
    ('10_projects', 'Prolific Creator', 'Create 10 projects', 500),
    ('first_preset', 'Preset Pioneer', 'Create your first preset', 100),
    ('100_sessions', 'Dedicated', 'Open the app 100 times', 1000),
    ('bio_master', 'Bio Master', 'Record 1 hour of bio-reactive audio', 2000);

-- ============================================================================
-- MIGRATIONS & VERSION CONTROL
-- ============================================================================

-- Migration tracking table
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

INSERT INTO public.schema_migrations (version) VALUES ('1.0.0');

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================

-- To apply this schema:
-- 1. Go to Supabase Dashboard → SQL Editor
-- 2. Copy/paste this entire file
-- 3. Click "Run"
-- 4. Verify tables in Table Editor
-- 5. Create Storage buckets manually (see STORAGE BUCKETS section above)
