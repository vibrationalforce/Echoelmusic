"""Application configuration"""

from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    """Application settings"""

    # API
    APP_NAME: str = "Echoelmusic API"
    APP_VERSION: str = "3.0.0"
    DEBUG: bool = False

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://echoelmusic:password@localhost:5432/echoelmusic"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # Celery
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"

    # CORS
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "https://echoelmusic.com",
        "https://www.echoelmusic.com"
    ]

    # JWT
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # Stripe
    STRIPE_SECRET_KEY: str = "sk_test_..."
    STRIPE_PUBLISHABLE_KEY: str = "pk_test_..."
    STRIPE_WEBHOOK_SECRET: str = "whsec_..."

    # Subscription Tiers
    STRIPE_PRICE_BASIC: str = "price_basic"  # $9/month
    STRIPE_PRICE_PRO: str = "price_pro"      # $49/month
    STRIPE_PRICE_STUDIO: str = "price_studio"  # $249/month

    # Web3 / Blockchain
    WEB3_PROVIDER_URL: str = "https://polygon-mainnet.infura.io/v3/YOUR_KEY"
    NFT_CONTRACT_ADDRESS: str = "0x..."
    WALLET_PRIVATE_KEY: str = "0x..."  # Should be in environment variable!

    # AWS S3
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_S3_BUCKET: str = "echoelmusic-media"
    AWS_REGION: str = "us-east-1"

    # IPFS
    IPFS_API_URL: str = "http://localhost:5001"
    IPFS_GATEWAY_URL: str = "https://ipfs.io/ipfs/"

    # GPU Rendering
    GPU_RENDER_QUEUE: str = "gpu_render_queue"
    MAX_RENDER_TIME: int = 3600  # 1 hour

    # Platform API Keys
    YOUTUBE_API_KEY: str = ""
    TWITCH_CLIENT_ID: str = ""
    TWITCH_CLIENT_SECRET: str = ""
    TIKTOK_API_KEY: str = ""

    # DistroKid (Music Distribution)
    DISTROKID_API_KEY: str = ""

    # Email
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    EMAIL_FROM: str = "noreply@echoelmusic.com"

    # Monitoring
    SENTRY_DSN: str = ""

    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 60

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
