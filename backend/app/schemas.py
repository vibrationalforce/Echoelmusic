"""Pydantic schemas for request/response validation"""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum


# ============================================================================
# ENUMS
# ============================================================================

class SubscriptionTier(str, Enum):
    FREE = "free"
    BASIC = "basic"
    PRO = "pro"
    STUDIO = "studio"


class StreamPlatform(str, Enum):
    TWITCH = "twitch"
    YOUTUBE = "youtube"
    INSTAGRAM = "instagram"
    TIKTOK = "tiktok"
    FACEBOOK = "facebook"
    CUSTOM = "custom"


# ============================================================================
# SESSION SCHEMAS
# ============================================================================

class BiometricData(BaseModel):
    heart_rate: float
    hrv_coherence: float
    breathing_rate: Optional[float] = None
    eeg_waves: Optional[Dict[str, float]] = None  # delta, theta, alpha, beta
    movement: Optional[float] = None


class SessionCreate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None


class SessionStart(BaseModel):
    user_id: str
    biometrics: BiometricData


class SessionStartResponse(BaseModel):
    session_id: str
    stream_key: Optional[str] = None
    started_at: datetime


class SessionUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    biometrics: Optional[BiometricData] = None


class SessionEnd(BaseModel):
    session_id: str


class SessionResponse(BaseModel):
    id: int
    session_id: str
    user_id: int
    title: Optional[str]
    description: Optional[str]
    duration: Optional[float]
    status: str
    video_url: Optional[str]
    audio_url: Optional[str]
    thumbnail_url: Optional[str]
    started_at: datetime
    ended_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================================
# SUBSCRIPTION SCHEMAS
# ============================================================================

class SubscriptionCreate(BaseModel):
    user_id: str
    tier: SubscriptionTier = Field(..., description="Subscription tier: basic ($9), pro ($49), or studio ($249)")


class SubscriptionResponse(BaseModel):
    subscription_id: str
    customer_id: str
    tier: SubscriptionTier
    status: str
    current_period_end: Optional[datetime]
    cancel_at_period_end: bool
    client_secret: Optional[str]  # For Stripe payment


class SubscriptionUpdate(BaseModel):
    tier: SubscriptionTier


# ============================================================================
# NFT SCHEMAS
# ============================================================================

class NFTMintRequest(BaseModel):
    session_id: str
    timestamp: float = Field(..., description="Timestamp of peak moment in session")
    emotion_peak: float = Field(..., ge=0, le=1, description="Emotion peak value (0-1)")


class NFTMintResponse(BaseModel):
    nft_id: int
    token_id: int
    tx_hash: str
    ipfs_hash: str
    opensea_url: str
    contract_address: str
    metadata: Dict[str, Any]


class NFTResponse(BaseModel):
    id: int
    token_id: Optional[int]
    name: str
    description: Optional[str]
    image_url: Optional[str]
    metadata_uri: Optional[str]
    timestamp: float
    emotion_peak: float
    heart_rate: Optional[float]
    hrv_coherence: Optional[float]
    tx_hash: Optional[str]
    opensea_url: Optional[str]
    minted_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================================
# STREAMING SCHEMAS
# ============================================================================

class StreamStartRequest(BaseModel):
    platforms: Dict[StreamPlatform, str] = Field(..., description="Platform -> Stream Key mapping")


class StreamStartResponse(BaseModel):
    stream_id: str
    platforms: List[StreamPlatform]
    status: str
    started_at: datetime


class StreamStatus(BaseModel):
    stream_id: str
    status: str
    platforms: List[str]
    bitrate: Optional[int]
    dropped_frames: int
    fps: Optional[float]
    viewer_count: Optional[int]


# ============================================================================
# RENDERING SCHEMAS
# ============================================================================

class RenderSubmitRequest(BaseModel):
    session_id: str
    output_format: str = "mp4"
    quality: str = "4k"
    effects: List[str] = []


class RenderSubmitResponse(BaseModel):
    job_id: str
    estimated_time: int  # seconds
    status: str


class RenderStatus(BaseModel):
    job_id: str
    status: str
    progress: float  # 0-100
    output_url: Optional[str]
    error_message: Optional[str]
    estimated_time_remaining: Optional[int]


# ============================================================================
# COLLABORATION SCHEMAS
# ============================================================================

class RoomCreate(BaseModel):
    name: str
    description: Optional[str] = None
    max_participants: int = 10


class RoomJoin(BaseModel):
    room_id: str
    user_id: str


class RoomMessage(BaseModel):
    type: str  # "biometrics", "chat", "control"
    data: Dict[str, Any]


class RoomResponse(BaseModel):
    room_id: str
    name: str
    description: Optional[str]
    participant_count: int
    max_participants: int
    fused_biometrics: Optional[Dict[str, Any]]
    active: bool
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================================
# DISTRIBUTION SCHEMAS
# ============================================================================

class DistributionRequest(BaseModel):
    session_id: str
    platforms: List[str] = ["spotify", "apple_music", "soundcloud", "youtube", "beatport"]
    metadata: Dict[str, Any] = Field(
        description="Track metadata: title, artist, genre, release_date, artwork_url, etc."
    )


class DistributionResponse(BaseModel):
    distribution_id: str
    platforms: List[str]
    status: Dict[str, str]  # platform -> status
    estimated_release_date: Optional[datetime]


# ============================================================================
# USER SCHEMAS
# ============================================================================

class UserCreate(BaseModel):
    email: EmailStr
    username: str
    password: str
    full_name: Optional[str] = None


class UserResponse(BaseModel):
    id: int
    email: str
    username: str
    full_name: Optional[str]
    subscription_tier: SubscriptionTier
    wallet_address: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================================
# HEALTH CHECK
# ============================================================================

class HealthCheck(BaseModel):
    status: str
    components: Dict[str, str]
    timestamp: datetime
