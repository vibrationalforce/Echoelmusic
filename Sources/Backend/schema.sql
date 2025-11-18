-- ============================================================================
-- Echoelmusic Supabase Database Schema
-- ============================================================================
-- Run this in Supabase SQL Editor to set up the database
--
-- Features:
-- - User profiles with subscription tiers
-- - Project storage with collaboration support
-- - Preset marketplace with ratings and purchases
-- - Analytics and usage tracking
-- - Social features (likes, comments, shares)

-- ============================================================================
-- Enable necessary extensions
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For full-text search

-- ============================================================================
-- User Profiles (extends Supabase Auth)
-- ============================================================================

CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    bio TEXT,
    avatar_url TEXT,
    website TEXT,

    -- Subscription
    subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'pro', 'enterprise')),
    subscription_started_at TIMESTAMPTZ,
    subscription_expires_at TIMESTAMPTZ,

    -- Settings
    preferences JSONB DEFAULT '{}'::jsonb,

    -- Social
    follower_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- Projects
-- ============================================================================

CREATE TABLE IF NOT EXISTS projects (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,

    -- Project info
    name TEXT NOT NULL,
    description TEXT,
    data JSONB NOT NULL,  -- Serialized project data
    thumbnail_url TEXT,

    -- Metadata
    bpm FLOAT,
    key TEXT,
    genre TEXT,
    duration_seconds FLOAT,

    -- Sharing
    is_public BOOLEAN DEFAULT false,
    is_template BOOLEAN DEFAULT false,
    view_count INTEGER DEFAULT 0,
    download_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,

    -- Collaboration
    allows_collaboration BOOLEAN DEFAULT false,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Full-text search
    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('english', COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(genre, ''))
    ) STORED
);

CREATE INDEX idx_projects_user_id ON projects(user_id);
CREATE INDEX idx_projects_public ON projects(is_public) WHERE is_public = true;
CREATE INDEX idx_projects_search ON projects USING GIN(search_vector);
CREATE INDEX idx_projects_genre ON projects(genre);

-- ============================================================================
-- Project Collaborators
-- ============================================================================

CREATE TABLE IF NOT EXISTS project_collaborators (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,

    -- Permission level
    permission TEXT DEFAULT 'view' CHECK (permission IN ('view', 'edit', 'admin')),

    -- Timestamps
    joined_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(project_id, user_id)
);

CREATE INDEX idx_collaborators_project ON project_collaborators(project_id);
CREATE INDEX idx_collaborators_user ON project_collaborators(user_id);

-- ============================================================================
-- Presets
-- ============================================================================

CREATE TABLE IF NOT EXISTS presets (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    creator_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,

    -- Preset info
    instrument_type TEXT NOT NULL,  -- 'EchoelSynth', 'Echoel808', etc.
    name TEXT NOT NULL,
    description TEXT,
    data JSONB NOT NULL,  -- Preset parameters

    -- Media
    preview_url TEXT,  -- Audio preview
    thumbnail_url TEXT,

    -- Marketplace
    price DECIMAL(10,2) DEFAULT 0.00,  -- USD, 0 = free
    is_public BOOLEAN DEFAULT true,

    -- Stats
    download_count INTEGER DEFAULT 0,
    purchase_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,

    -- Rating
    rating_sum INTEGER DEFAULT 0,
    rating_count INTEGER DEFAULT 0,
    rating_average DECIMAL(3,2) DEFAULT 0.00,

    -- Tags
    tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    genre TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Full-text search
    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('english',
            COALESCE(name, '') || ' ' ||
            COALESCE(description, '') || ' ' ||
            COALESCE(instrument_type, '') || ' ' ||
            COALESCE(genre, '')
        )
    ) STORED
);

CREATE INDEX idx_presets_creator ON presets(creator_id);
CREATE INDEX idx_presets_instrument ON presets(instrument_type);
CREATE INDEX idx_presets_public ON presets(is_public) WHERE is_public = true;
CREATE INDEX idx_presets_search ON presets USING GIN(search_vector);
CREATE INDEX idx_presets_tags ON presets USING GIN(tags);
CREATE INDEX idx_presets_rating ON presets(rating_average DESC);
CREATE INDEX idx_presets_downloads ON presets(download_count DESC);

-- ============================================================================
-- Preset Ratings
-- ============================================================================

CREATE TABLE IF NOT EXISTS preset_ratings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    preset_id UUID REFERENCES presets(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,

    rating INTEGER CHECK (rating >= 1 AND rating <= 5) NOT NULL,
    review TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(preset_id, user_id)
);

CREATE INDEX idx_ratings_preset ON preset_ratings(preset_id);
CREATE INDEX idx_ratings_user ON preset_ratings(user_id);

-- Trigger to update preset rating average
CREATE OR REPLACE FUNCTION update_preset_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE presets
    SET
        rating_sum = (SELECT COALESCE(SUM(rating), 0) FROM preset_ratings WHERE preset_id = NEW.preset_id),
        rating_count = (SELECT COUNT(*) FROM preset_ratings WHERE preset_id = NEW.preset_id),
        rating_average = (SELECT COALESCE(AVG(rating), 0) FROM preset_ratings WHERE preset_id = NEW.preset_id)
    WHERE id = NEW.preset_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER preset_rating_updated
AFTER INSERT OR UPDATE ON preset_ratings
FOR EACH ROW
EXECUTE FUNCTION update_preset_rating();

-- ============================================================================
-- Preset Purchases
-- ============================================================================

CREATE TABLE IF NOT EXISTS preset_purchases (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    preset_id UUID REFERENCES presets(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,

    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'USD',

    -- Payment
    payment_status TEXT DEFAULT 'completed' CHECK (payment_status IN ('pending', 'completed', 'refunded')),
    stripe_payment_id TEXT,

    purchased_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(preset_id, user_id)
);

CREATE INDEX idx_purchases_preset ON preset_purchases(preset_id);
CREATE INDEX idx_purchases_user ON preset_purchases(user_id);
CREATE INDEX idx_purchases_date ON preset_purchases(purchased_at DESC);

-- ============================================================================
-- Analytics Events
-- ============================================================================

CREATE TABLE IF NOT EXISTS analytics_events (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,

    -- Event data
    event_name TEXT NOT NULL,
    event_properties JSONB DEFAULT '{}'::jsonb,

    -- Session tracking
    session_id TEXT,

    -- Device info
    platform TEXT,
    os_version TEXT,
    app_version TEXT,

    -- Timestamp
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Partition by month for better performance
CREATE INDEX idx_analytics_event_name ON analytics_events(event_name);
CREATE INDEX idx_analytics_user ON analytics_events(user_id);
CREATE INDEX idx_analytics_created ON analytics_events(created_at DESC);
CREATE INDEX idx_analytics_session ON analytics_events(session_id);

-- ============================================================================
-- Usage Statistics (aggregated daily)
-- ============================================================================

CREATE TABLE IF NOT EXISTS usage_stats (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,

    date DATE NOT NULL,

    -- Stats
    projects_created INTEGER DEFAULT 0,
    presets_downloaded INTEGER DEFAULT 0,
    presets_created INTEGER DEFAULT 0,
    collaboration_sessions INTEGER DEFAULT 0,
    play_time_minutes INTEGER DEFAULT 0,

    -- Instruments used (JSONB array)
    instruments_used JSONB DEFAULT '[]'::jsonb,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, date)
);

CREATE INDEX idx_usage_stats_user ON usage_stats(user_id);
CREATE INDEX idx_usage_stats_date ON usage_stats(date DESC);

-- ============================================================================
-- Social - Likes
-- ============================================================================

CREATE TABLE IF NOT EXISTS likes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,

    -- What's being liked (one of these will be non-null)
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    preset_id UUID REFERENCES presets(id) ON DELETE CASCADE,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, project_id),
    UNIQUE(user_id, preset_id),
    CHECK ((project_id IS NOT NULL)::integer + (preset_id IS NOT NULL)::integer = 1)
);

CREATE INDEX idx_likes_user ON likes(user_id);
CREATE INDEX idx_likes_project ON likes(project_id) WHERE project_id IS NOT NULL;
CREATE INDEX idx_likes_preset ON likes(preset_id) WHERE preset_id IS NOT NULL;

-- ============================================================================
-- Social - Comments
-- ============================================================================

CREATE TABLE IF NOT EXISTS comments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,

    -- What's being commented on
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    preset_id UUID REFERENCES presets(id) ON DELETE CASCADE,

    -- Comment data
    content TEXT NOT NULL,
    parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,  -- For replies

    -- Moderation
    is_flagged BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CHECK ((project_id IS NOT NULL)::integer + (preset_id IS NOT NULL)::integer = 1)
);

CREATE INDEX idx_comments_user ON comments(user_id);
CREATE INDEX idx_comments_project ON comments(project_id) WHERE project_id IS NOT NULL;
CREATE INDEX idx_comments_preset ON comments(preset_id) WHERE preset_id IS NOT NULL;
CREATE INDEX idx_comments_parent ON comments(parent_id) WHERE parent_id IS NOT NULL;

-- ============================================================================
-- Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_collaborators ENABLE ROW LEVEL SECURITY;
ALTER TABLE presets ENABLE ROW LEVEL SECURITY;
ALTER TABLE preset_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE preset_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can read all profiles, but only update their own
CREATE POLICY "Profiles are viewable by everyone" ON profiles
    FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Projects: Users can CRUD their own projects, view public projects, collaborate on shared
CREATE POLICY "Users can view own projects" ON projects
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Public projects are viewable by everyone" ON projects
    FOR SELECT USING (is_public = true);

CREATE POLICY "Collaborators can view shared projects" ON projects
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM project_collaborators
            WHERE project_id = projects.id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own projects" ON projects
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own projects" ON projects
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own projects" ON projects
    FOR DELETE USING (auth.uid() = user_id);

-- Presets: Public presets viewable by all, users can CRUD their own
CREATE POLICY "Public presets are viewable" ON presets
    FOR SELECT USING (is_public = true);

CREATE POLICY "Users can view own presets" ON presets
    FOR SELECT USING (auth.uid() = creator_id);

CREATE POLICY "Users can create presets" ON presets
    FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Users can update own presets" ON presets
    FOR UPDATE USING (auth.uid() = creator_id);

CREATE POLICY "Users can delete own presets" ON presets
    FOR DELETE USING (auth.uid() = creator_id);

-- Analytics: Users can insert their own events
CREATE POLICY "Users can track own analytics" ON analytics_events
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Likes/Comments: Users can CRUD their own
CREATE POLICY "Users can manage own likes" ON likes
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own comments" ON comments
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Everyone can view comments" ON comments
    FOR SELECT USING (NOT is_deleted);

-- ============================================================================
-- Functions
-- ============================================================================

-- Function to get trending presets
CREATE OR REPLACE FUNCTION get_trending_presets(instrument TEXT DEFAULT NULL, days INTEGER DEFAULT 7, result_limit INTEGER DEFAULT 20)
RETURNS TABLE (
    preset_id UUID,
    name TEXT,
    rating_average DECIMAL,
    download_count INTEGER,
    trend_score DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.name,
        p.rating_average,
        p.download_count,
        (p.rating_average * 0.3 + (p.download_count / 100.0) * 0.7) as trend_score
    FROM presets p
    WHERE
        (instrument IS NULL OR p.instrument_type = instrument)
        AND p.is_public = true
        AND p.created_at > NOW() - (days || ' days')::INTERVAL
    ORDER BY trend_score DESC
    LIMIT result_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Initial Data / Seeds
-- ============================================================================

-- Create system user for official presets
INSERT INTO auth.users (id, email)
VALUES ('00000000-0000-0000-0000-000000000000', 'official@echoelmusic.com')
ON CONFLICT DO NOTHING;

INSERT INTO profiles (id, username, display_name, subscription_tier)
VALUES ('00000000-0000-0000-0000-000000000000', 'echoelmusic', 'Echoelmusic Official', 'enterprise')
ON CONFLICT DO NOTHING;
