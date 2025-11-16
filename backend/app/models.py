"""Database models"""

from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Text, JSON, ForeignKey, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base
import enum


class SubscriptionTier(str, enum.Enum):
    """Subscription tiers"""
    FREE = "free"
    BASIC = "basic"      # $9/month
    PRO = "pro"          # $49/month
    STUDIO = "studio"    # $249/month


class User(Base):
    """User model"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String)

    # Subscription
    subscription_tier = Column(Enum(SubscriptionTier), default=SubscriptionTier.FREE)
    stripe_customer_id = Column(String, unique=True)
    stripe_subscription_id = Column(String)

    # Wallet
    wallet_address = Column(String)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    sessions = relationship("Session", back_populates="user")
    nfts = relationship("NFT", back_populates="user")


class Session(Base):
    """Recording session model"""
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    session_id = Column(String, unique=True, index=True, nullable=False)

    # Session info
    title = Column(String)
    description = Column(Text)
    duration = Column(Float)  # seconds

    # Biometric data (JSON)
    biometric_data = Column(JSON)

    # Emotion peaks for NFT minting
    emotion_peaks = Column(JSON)  # Array of {timestamp, value, type}

    # Media files
    video_url = Column(String)
    audio_url = Column(String)
    thumbnail_url = Column(String)

    # Status
    status = Column(String, default="recording")  # recording, processing, completed, failed

    # Timestamps
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    ended_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="sessions")
    nfts = relationship("NFT", back_populates="session")
    renders = relationship("RenderJob", back_populates="session")


class NFT(Base):
    """NFT model for biometric peak moments"""
    __tablename__ = "nfts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False)

    # NFT info
    token_id = Column(Integer)
    contract_address = Column(String)
    chain = Column(String, default="polygon")

    # Metadata
    name = Column(String, nullable=False)
    description = Column(Text)
    image_url = Column(String)
    metadata_uri = Column(String)  # IPFS URI

    # Biometric data at peak
    timestamp = Column(Float)  # Timestamp in session
    emotion_peak = Column(Float)  # 0-1
    heart_rate = Column(Float)
    hrv_coherence = Column(Float)

    # Transaction
    tx_hash = Column(String)
    minted_at = Column(DateTime(timezone=True))

    # Marketplace
    opensea_url = Column(String)
    listed_price = Column(Float)  # in ETH/MATIC
    sold = Column(Boolean, default=False)
    sold_price = Column(Float)
    sold_at = Column(DateTime(timezone=True))

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="nfts")
    session = relationship("Session", back_populates="nfts")


class RenderJob(Base):
    """GPU render job model"""
    __tablename__ = "render_jobs"

    id = Column(Integer, primary_key=True, index=True)
    job_id = Column(String, unique=True, index=True, nullable=False)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    # Render settings
    output_format = Column(String, default="mp4")  # mp4, mov, webm
    quality = Column(String, default="1080p")  # 1080p, 4k, 8k
    effects = Column(JSON)  # Array of effect names

    # Status
    status = Column(String, default="queued")  # queued, processing, completed, failed
    progress = Column(Float, default=0.0)  # 0-100

    # Output
    output_url = Column(String)
    file_size = Column(Integer)  # bytes

    # Performance
    estimated_time = Column(Integer)  # seconds
    actual_time = Column(Integer)  # seconds
    gpu_used = Column(String)

    # Error handling
    error_message = Column(Text)
    retry_count = Column(Integer, default=0)

    # Timestamps
    queued_at = Column(DateTime(timezone=True), server_default=func.now())
    started_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    session = relationship("Session", back_populates="renders")


class Stream(Base):
    """Live stream model"""
    __tablename__ = "streams"

    id = Column(Integer, primary_key=True, index=True)
    stream_id = Column(String, unique=True, index=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    # Platform info
    platform = Column(String, nullable=False)  # twitch, youtube, instagram, etc.
    stream_key = Column(String)
    rtmp_url = Column(String)

    # Status
    status = Column(String, default="offline")  # offline, live, ended
    viewer_count = Column(Integer, default=0)

    # Stream health
    bitrate = Column(Integer)  # bps
    dropped_frames = Column(Integer, default=0)
    fps = Column(Float)

    # Timestamps
    started_at = Column(DateTime(timezone=True))
    ended_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class CollaborationRoom(Base):
    """Real-time collaboration room"""
    __tablename__ = "collaboration_rooms"

    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(String, unique=True, index=True, nullable=False)

    # Room info
    name = Column(String, nullable=False)
    description = Column(Text)
    max_participants = Column(Integer, default=10)

    # Host
    host_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    # Status
    active = Column(Boolean, default=True)
    participant_count = Column(Integer, default=0)

    # Fused biometric data (from all participants)
    fused_biometrics = Column(JSON)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
