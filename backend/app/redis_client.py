"""Redis client for caching and pub/sub"""

import redis.asyncio as redis
from .config import settings
import logging

logger = logging.getLogger(__name__)


class RedisClient:
    """Async Redis client wrapper"""

    def __init__(self):
        self.client = None
        self.pubsub = None

    async def initialize(self):
        """Initialize Redis connection"""
        self.client = await redis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True
        )
        self.pubsub = self.client.pubsub()
        logger.info("✅ Redis client initialized")

    async def close(self):
        """Close Redis connection"""
        if self.pubsub:
            await self.pubsub.close()
        if self.client:
            await self.client.close()
        logger.info("✅ Redis client closed")

    async def ping(self):
        """Ping Redis"""
        if self.client:
            return await self.client.ping()
        return False

    # Key-Value Operations
    async def get(self, key: str):
        """Get value by key"""
        if self.client:
            return await self.client.get(key)
        return None

    async def set(self, key: str, value: str, ex: int = None):
        """Set key-value pair with optional expiration"""
        if self.client:
            return await self.client.set(key, value, ex=ex)
        return False

    async def delete(self, key: str):
        """Delete key"""
        if self.client:
            return await self.client.delete(key)
        return False

    # Hash Operations
    async def hget(self, name: str, key: str):
        """Get hash field"""
        if self.client:
            return await self.client.hget(name, key)
        return None

    async def hset(self, name: str, key: str, value: str):
        """Set hash field"""
        if self.client:
            return await self.client.hset(name, key, value)
        return False

    async def hgetall(self, name: str):
        """Get all hash fields"""
        if self.client:
            return await self.client.hgetall(name)
        return {}

    async def hdel(self, name: str, *keys):
        """Delete hash fields"""
        if self.client:
            return await self.client.hdel(name, *keys)
        return 0

    # Set Operations
    async def sadd(self, name: str, *values):
        """Add to set"""
        if self.client:
            return await self.client.sadd(name, *values)
        return 0

    async def srem(self, name: str, *values):
        """Remove from set"""
        if self.client:
            return await self.client.srem(name, *values)
        return 0

    async def smembers(self, name: str):
        """Get set members"""
        if self.client:
            return await self.client.smembers(name)
        return set()

    # Pub/Sub Operations
    async def publish(self, channel: str, message: str):
        """Publish message to channel"""
        if self.client:
            return await self.client.publish(channel, message)
        return 0

    async def subscribe(self, *channels):
        """Subscribe to channels"""
        if self.pubsub:
            await self.pubsub.subscribe(*channels)

    async def unsubscribe(self, *channels):
        """Unsubscribe from channels"""
        if self.pubsub:
            await self.pubsub.unsubscribe(*channels)

    async def listen(self):
        """Listen for messages"""
        if self.pubsub:
            async for message in self.pubsub.listen():
                if message["type"] == "message":
                    yield message

    # List Operations
    async def lpush(self, name: str, *values):
        """Push to list (left)"""
        if self.client:
            return await self.client.lpush(name, *values)
        return 0

    async def rpush(self, name: str, *values):
        """Push to list (right)"""
        if self.client:
            return await self.client.rpush(name, *values)
        return 0

    async def lpop(self, name: str):
        """Pop from list (left)"""
        if self.client:
            return await self.client.lpop(name)
        return None

    async def rpop(self, name: str):
        """Pop from list (right)"""
        if self.client:
            return await self.client.rpop(name)
        return None

    async def lrange(self, name: str, start: int, end: int):
        """Get list range"""
        if self.client:
            return await self.client.lrange(name, start, end)
        return []


# Global instance
redis_client = RedisClient()
pubsub = None  # Will be initialized in main.py
