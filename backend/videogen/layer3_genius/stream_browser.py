"""
Stream Browser - Cloud Content Discovery
=========================================

Inspired by Minimal Audio's Stream cloud content platform.
Real-time browsing and discovery of presets, styles, and community content.

Features:
- Cloud-synced preset library
- Trending prompts and styles
- Community-shared generations
- Automatic content updates
- Favorite synchronization
"""

import os
import json
import asyncio
import hashlib
from typing import Optional, Dict, Any, List, Callable
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
import logging

logger = logging.getLogger(__name__)


class ContentCategory(str, Enum):
    """Content categories for browsing"""
    PRESETS = "presets"
    STYLES = "styles"
    PROMPTS = "prompts"
    LORAS = "loras"
    CONTROLNETS = "controlnets"
    SAMPLES = "samples"
    COMMUNITY = "community"


class SortOrder(str, Enum):
    """Sort order for content"""
    TRENDING = "trending"
    NEWEST = "newest"
    POPULAR = "popular"
    ALPHABETICAL = "alphabetical"
    RECOMMENDED = "recommended"


@dataclass
class StreamContent:
    """Represents a piece of content in the stream"""
    id: str
    name: str
    category: ContentCategory
    description: str = ""
    author: str = ""
    thumbnail_url: str = ""
    download_url: str = ""
    tags: List[str] = field(default_factory=list)
    downloads: int = 0
    likes: int = 0
    created_at: str = ""
    updated_at: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)

    @property
    def is_trending(self) -> bool:
        return self.downloads > 1000 or self.likes > 500


@dataclass
class StreamFilter:
    """Filter configuration for stream browsing"""
    category: Optional[ContentCategory] = None
    tags: List[str] = field(default_factory=list)
    author: Optional[str] = None
    search_query: str = ""
    sort_by: SortOrder = SortOrder.TRENDING
    limit: int = 50
    offset: int = 0


@dataclass
class UserPreferences:
    """User preferences for personalized recommendations"""
    favorite_styles: List[str] = field(default_factory=list)
    favorite_authors: List[str] = field(default_factory=list)
    preferred_genres: List[str] = field(default_factory=list)
    history: List[str] = field(default_factory=list)  # Recent content IDs
    liked_content: List[str] = field(default_factory=list)


class StreamBrowser:
    """
    Cloud content discovery platform for Echoelmusic.

    Provides real-time browsing of:
    - Video generation presets
    - Style configurations
    - Prompt templates
    - LoRA adapters
    - Community creations

    Usage:
        browser = StreamBrowser()
        await browser.connect()

        # Browse trending presets
        presets = await browser.browse(
            StreamFilter(category=ContentCategory.PRESETS, sort_by=SortOrder.TRENDING)
        )

        # Search for specific content
        results = await browser.search("anime city night")

        # Get personalized recommendations
        recommended = await browser.get_recommendations()
    """

    # Cloud API endpoints (placeholder)
    API_BASE = os.environ.get("STREAM_API_URL", "https://api.echoelmusic.com/stream")

    def __init__(
        self,
        cache_dir: Optional[str] = None,
        user_id: Optional[str] = None
    ):
        self.cache_dir = Path(cache_dir or os.path.expanduser("~/.echoelmusic/stream"))
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.user_id = user_id

        self._connected = False
        self._content_cache: Dict[str, StreamContent] = {}
        self._preferences = UserPreferences()
        self._update_callbacks: List[Callable] = []

        # Local content index
        self._local_index: Dict[str, StreamContent] = {}
        self._load_local_index()

    async def connect(self) -> bool:
        """
        Connect to the stream service.

        Returns:
            True if connected successfully
        """
        try:
            # In production, authenticate with cloud service
            logger.info("Connecting to Stream service...")

            # Load cached preferences
            await self._load_preferences()

            self._connected = True
            logger.info("Stream connected successfully")

            # Start background sync
            asyncio.create_task(self._background_sync())

            return True
        except Exception as e:
            logger.error(f"Stream connection failed: {e}")
            return False

    async def browse(
        self,
        filter: Optional[StreamFilter] = None
    ) -> List[StreamContent]:
        """
        Browse content with optional filters.

        Args:
            filter: Filter configuration

        Returns:
            List of matching content
        """
        filter = filter or StreamFilter()

        # In production, query cloud API
        # For now, return from local cache
        results = list(self._local_index.values())

        # Apply filters
        if filter.category:
            results = [c for c in results if c.category == filter.category]

        if filter.tags:
            results = [
                c for c in results
                if any(tag in c.tags for tag in filter.tags)
            ]

        if filter.search_query:
            query = filter.search_query.lower()
            results = [
                c for c in results
                if query in c.name.lower() or query in c.description.lower()
            ]

        # Sort
        if filter.sort_by == SortOrder.TRENDING:
            results.sort(key=lambda x: x.downloads + x.likes * 2, reverse=True)
        elif filter.sort_by == SortOrder.NEWEST:
            results.sort(key=lambda x: x.created_at, reverse=True)
        elif filter.sort_by == SortOrder.POPULAR:
            results.sort(key=lambda x: x.downloads, reverse=True)
        elif filter.sort_by == SortOrder.ALPHABETICAL:
            results.sort(key=lambda x: x.name.lower())

        # Pagination
        results = results[filter.offset:filter.offset + filter.limit]

        return results

    async def search(self, query: str, limit: int = 20) -> List[StreamContent]:
        """
        Search for content by query.

        Args:
            query: Search query
            limit: Max results

        Returns:
            Matching content
        """
        return await self.browse(StreamFilter(search_query=query, limit=limit))

    async def get_recommendations(self, limit: int = 10) -> List[StreamContent]:
        """
        Get personalized recommendations based on user preferences.

        Args:
            limit: Max recommendations

        Returns:
            Recommended content
        """
        all_content = list(self._local_index.values())

        # Score content based on preferences
        scored = []
        for content in all_content:
            score = 0

            # Boost if matches favorite styles
            if any(style in content.tags for style in self._preferences.favorite_styles):
                score += 10

            # Boost if by favorite author
            if content.author in self._preferences.favorite_authors:
                score += 15

            # Boost trending content
            if content.is_trending:
                score += 5

            # Penalty if already in history
            if content.id in self._preferences.history:
                score -= 20

            scored.append((score, content))

        # Sort by score
        scored.sort(key=lambda x: x[0], reverse=True)

        return [content for _, content in scored[:limit]]

    async def get_trending(
        self,
        category: Optional[ContentCategory] = None,
        limit: int = 10
    ) -> List[StreamContent]:
        """Get trending content"""
        return await self.browse(StreamFilter(
            category=category,
            sort_by=SortOrder.TRENDING,
            limit=limit
        ))

    async def download_content(self, content_id: str) -> Optional[Path]:
        """
        Download content to local cache.

        Args:
            content_id: Content ID

        Returns:
            Local path to downloaded content
        """
        content = self._local_index.get(content_id)
        if not content:
            logger.error(f"Content not found: {content_id}")
            return None

        # In production, download from cloud
        local_path = self.cache_dir / content.category.value / f"{content_id}.json"
        local_path.parent.mkdir(parents=True, exist_ok=True)

        # Save content metadata
        with open(local_path, "w") as f:
            json.dump({
                "id": content.id,
                "name": content.name,
                "category": content.category.value,
                "metadata": content.metadata,
            }, f)

        # Update download count
        content.downloads += 1

        # Add to history
        self._preferences.history.insert(0, content_id)
        self._preferences.history = self._preferences.history[:100]

        logger.info(f"Downloaded content: {content.name}")
        return local_path

    async def like_content(self, content_id: str) -> bool:
        """Like a piece of content"""
        content = self._local_index.get(content_id)
        if content and content_id not in self._preferences.liked_content:
            content.likes += 1
            self._preferences.liked_content.append(content_id)
            await self._save_preferences()
            return True
        return False

    async def add_favorite_style(self, style: str) -> None:
        """Add a style to favorites"""
        if style not in self._preferences.favorite_styles:
            self._preferences.favorite_styles.append(style)
            await self._save_preferences()

    def on_update(self, callback: Callable) -> None:
        """Register callback for content updates"""
        self._update_callbacks.append(callback)

    def _load_local_index(self) -> None:
        """Load local content index"""
        index_path = self.cache_dir / "index.json"

        if index_path.exists():
            try:
                with open(index_path) as f:
                    data = json.load(f)
                    for item in data.get("content", []):
                        content = StreamContent(
                            id=item["id"],
                            name=item["name"],
                            category=ContentCategory(item["category"]),
                            description=item.get("description", ""),
                            author=item.get("author", ""),
                            tags=item.get("tags", []),
                            downloads=item.get("downloads", 0),
                            likes=item.get("likes", 0),
                            created_at=item.get("created_at", ""),
                            metadata=item.get("metadata", {}),
                        )
                        self._local_index[content.id] = content
            except Exception as e:
                logger.warning(f"Failed to load index: {e}")

        # Add default content if empty
        if not self._local_index:
            self._add_default_content()

    def _add_default_content(self) -> None:
        """Add default built-in content"""
        defaults = [
            StreamContent(
                id="preset_cinematic_epic",
                name="Cinematic Epic",
                category=ContentCategory.PRESETS,
                description="Hollywood-style cinematic visuals with dramatic lighting",
                author="Echoelmusic",
                tags=["cinematic", "epic", "dramatic", "film"],
                downloads=5000,
                likes=1200,
            ),
            StreamContent(
                id="preset_anime_vibrant",
                name="Anime Vibrant",
                category=ContentCategory.PRESETS,
                description="Colorful anime style with dynamic action",
                author="Echoelmusic",
                tags=["anime", "vibrant", "colorful", "action"],
                downloads=8000,
                likes=2500,
            ),
            StreamContent(
                id="style_neon_city",
                name="Neon City Nights",
                category=ContentCategory.STYLES,
                description="Cyberpunk neon aesthetic for urban scenes",
                author="Echoelmusic",
                tags=["neon", "cyberpunk", "city", "night"],
                downloads=3500,
                likes=900,
            ),
            StreamContent(
                id="prompt_nature_timelapse",
                name="Nature Timelapse",
                category=ContentCategory.PROMPTS,
                description="Template for stunning nature timelapse videos",
                author="Echoelmusic",
                tags=["nature", "timelapse", "landscape", "peaceful"],
                downloads=2000,
                likes=600,
                metadata={"prompt_template": "A beautiful timelapse of {subject}, golden hour lighting, 4K quality"},
            ),
        ]

        for content in defaults:
            self._local_index[content.id] = content

    async def _load_preferences(self) -> None:
        """Load user preferences from cache"""
        prefs_path = self.cache_dir / "preferences.json"
        if prefs_path.exists():
            try:
                with open(prefs_path) as f:
                    data = json.load(f)
                    self._preferences = UserPreferences(**data)
            except Exception as e:
                logger.warning(f"Failed to load preferences: {e}")

    async def _save_preferences(self) -> None:
        """Save user preferences to cache"""
        prefs_path = self.cache_dir / "preferences.json"
        with open(prefs_path, "w") as f:
            json.dump({
                "favorite_styles": self._preferences.favorite_styles,
                "favorite_authors": self._preferences.favorite_authors,
                "preferred_genres": self._preferences.preferred_genres,
                "history": self._preferences.history,
                "liked_content": self._preferences.liked_content,
            }, f)

    async def _background_sync(self) -> None:
        """Background sync with cloud service"""
        while self._connected:
            try:
                # In production, sync with cloud API
                await asyncio.sleep(300)  # Sync every 5 minutes

                # Notify callbacks of updates
                for callback in self._update_callbacks:
                    try:
                        callback()
                    except Exception:
                        pass

            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Background sync error: {e}")
                await asyncio.sleep(60)

    async def disconnect(self) -> None:
        """Disconnect from stream service"""
        self._connected = False
        await self._save_preferences()
        logger.info("Stream disconnected")


# Global stream browser instance
stream_browser = StreamBrowser()


__all__ = [
    "ContentCategory",
    "SortOrder",
    "StreamContent",
    "StreamFilter",
    "UserPreferences",
    "StreamBrowser",
    "stream_browser",
]
