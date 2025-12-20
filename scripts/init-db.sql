-- Echoelmusic Database Schema
-- PostgreSQL 16+
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- Users & Authentication
-- ============================================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100),
    avatar_url VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'pro', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_users_email ON users(email);

CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_hash VARCHAR(255) NOT NULL,
    key_prefix VARCHAR(20) NOT NULL,
    name VARCHAR(100),
    scopes TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    last_used_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_api_keys_user ON api_keys(user_id);
CREATE INDEX idx_api_keys_prefix ON api_keys(key_prefix);

-- ============================================================================
-- Video Generation Tasks
-- ============================================================================

CREATE TYPE task_status AS ENUM (
    'pending', 'queued', 'processing', 'expanding_prompt',
    'generating', 'refining', 'upscaling', 'encoding',
    'completed', 'failed', 'cancelled'
);

CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,

    -- Request
    prompt TEXT NOT NULL,
    negative_prompt TEXT,
    duration_seconds DECIMAL(5,2) NOT NULL DEFAULT 4.0,
    fps INTEGER DEFAULT 24,
    resolution VARCHAR(10) DEFAULT '1080p',
    aspect_ratio VARCHAR(10) DEFAULT '16:9',
    genre VARCHAR(50) DEFAULT 'cinematic',
    seed BIGINT,
    guidance_scale DECIMAL(4,2) DEFAULT 7.5,
    num_inference_steps INTEGER DEFAULT 50,

    -- Status
    status task_status DEFAULT 'pending',
    progress DECIMAL(5,4) DEFAULT 0,
    current_step VARCHAR(100),
    error_message TEXT,

    -- Result
    video_url VARCHAR(500),
    thumbnail_url VARCHAR(500),
    file_size_bytes BIGINT,
    actual_duration_seconds DECIMAL(5,2),

    -- Metadata
    model_used VARCHAR(50),
    gpu_time_seconds DECIMAL(10,2),
    queue_time_seconds DECIMAL(10,2),
    total_time_seconds DECIMAL(10,2),

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,

    -- Webhook
    webhook_url VARCHAR(500),
    webhook_sent BOOLEAN DEFAULT false
);

CREATE INDEX idx_tasks_user ON tasks(user_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_created ON tasks(created_at DESC);

-- ============================================================================
-- Multi-Shot Projects
-- ============================================================================

CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    settings JSONB DEFAULT '{}',
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_projects_user ON projects(user_id);

CREATE TABLE scenes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    order_index INTEGER NOT NULL,
    prompt TEXT NOT NULL,
    negative_prompt TEXT,
    duration_seconds DECIMAL(5,2) DEFAULT 4.0,
    scene_type VARCHAR(30) DEFAULT 'action',
    settings JSONB DEFAULT '{}',
    task_id UUID REFERENCES tasks(id),
    thumbnail_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_scenes_project ON scenes(project_id);

CREATE TABLE transitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    from_scene_id UUID NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
    to_scene_id UUID NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
    transition_type VARCHAR(30) DEFAULT 'crossfade',
    duration_seconds DECIMAL(3,2) DEFAULT 0.5,
    settings JSONB DEFAULT '{}'
);

CREATE INDEX idx_transitions_project ON transitions(project_id);

-- ============================================================================
-- Characters (for consistency tracking)
-- ============================================================================

CREATE TABLE characters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    reference_image_url VARCHAR(500),
    embedding BYTEA,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_characters_project ON characters(project_id);
CREATE INDEX idx_characters_user ON characters(user_id);

-- ============================================================================
-- Usage & Billing
-- ============================================================================

CREATE TABLE usage_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id UUID REFERENCES tasks(id),
    credits_used INTEGER NOT NULL DEFAULT 0,
    gpu_seconds DECIMAL(10,2) DEFAULT 0,
    resolution VARCHAR(10),
    duration_seconds DECIMAL(5,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_usage_user ON usage_records(user_id);
CREATE INDEX idx_usage_created ON usage_records(created_at DESC);

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan VARCHAR(30) NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    credits_total INTEGER DEFAULT 0,
    credits_used INTEGER DEFAULT 0,
    period_start TIMESTAMP WITH TIME ZONE,
    period_end TIMESTAMP WITH TIME ZONE,
    stripe_subscription_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);

-- ============================================================================
-- Webhooks
-- ============================================================================

CREATE TABLE webhook_endpoints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    url VARCHAR(500) NOT NULL,
    secret VARCHAR(100) NOT NULL,
    events TEXT[] DEFAULT '{task.completed, task.failed}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_webhooks_user ON webhook_endpoints(user_id);

CREATE TABLE webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    endpoint_id UUID NOT NULL REFERENCES webhook_endpoints(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    response_status INTEGER,
    response_body TEXT,
    attempts INTEGER DEFAULT 1,
    delivered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_webhook_deliveries_endpoint ON webhook_deliveries(endpoint_id);

-- ============================================================================
-- Functions
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER projects_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER scenes_updated_at
    BEFORE UPDATE ON scenes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================================
-- Initial Data
-- ============================================================================

-- Create admin user (password: change_me_immediately)
INSERT INTO users (email, password_hash, name, role, is_verified)
VALUES (
    'admin@echoelmusic.com',
    crypt('change_me_immediately', gen_salt('bf')),
    'Admin',
    'admin',
    true
);
