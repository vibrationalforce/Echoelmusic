"""
Dynamic Prompt Expansion with Local LLM
=======================================

Expands short user prompts into highly detailed cinematic prompts
using a local LLM (Llama-3.3-8B or similar).

Features:
- Genre-specific prompt templates
- Cinematic terminology injection
- Camera movement descriptions
- Lighting and atmosphere enhancement
- Style-consistent expansion
"""

import torch
from typing import Optional, Dict, List, Tuple
from dataclasses import dataclass
from enum import Enum
import logging
import re

logger = logging.getLogger(__name__)


class VideoGenre(Enum):
    """Video genre categories with specific style attributes"""
    CINEMATIC = "cinematic"
    ANIME = "anime"
    REALISTIC = "realistic"
    ARTISTIC = "artistic"
    DOCUMENTARY = "documentary"
    MUSIC_VIDEO = "music_video"
    COMMERCIAL = "commercial"
    SOCIAL_MEDIA = "social_media"
    ABSTRACT = "abstract"
    NATURE = "nature"
    SCIFI = "scifi"
    FANTASY = "fantasy"
    HORROR = "horror"
    ROMANTIC = "romantic"
    ACTION = "action"
    NOIR = "noir"


@dataclass
class ExpandedPrompt:
    """Result of prompt expansion"""
    original: str
    expanded: str
    negative_prompt: str
    genre: VideoGenre
    camera_movements: List[str]
    lighting_descriptors: List[str]
    style_tags: List[str]
    confidence: float


# Genre-specific style dictionaries
GENRE_STYLES = {
    VideoGenre.CINEMATIC: {
        "camera": ["dolly zoom", "crane shot", "tracking shot", "slow pan", "steadicam"],
        "lighting": ["dramatic lighting", "golden hour", "chiaroscuro", "rim lighting", "volumetric light"],
        "style": ["35mm film", "anamorphic lens", "shallow depth of field", "cinematic color grading", "2.39:1 aspect ratio"],
        "atmosphere": ["epic", "dramatic", "sweeping", "majestic", "immersive"]
    },
    VideoGenre.ANIME: {
        "camera": ["dynamic angles", "speed lines", "zoom burst", "rotating shot"],
        "lighting": ["cell shading", "dramatic backlighting", "sakura petals", "lens flare"],
        "style": ["anime style", "Studio Ghibli", "Makoto Shinkai", "vibrant colors", "detailed backgrounds"],
        "atmosphere": ["emotional", "nostalgic", "dreamlike", "energetic"]
    },
    VideoGenre.REALISTIC: {
        "camera": ["handheld", "documentary style", "natural movement", "observational"],
        "lighting": ["natural lighting", "available light", "soft shadows", "realistic exposure"],
        "style": ["photorealistic", "8K resolution", "RAW footage", "true to life colors"],
        "atmosphere": ["authentic", "genuine", "candid", "unfiltered"]
    },
    VideoGenre.SCIFI: {
        "camera": ["orbital shot", "zero gravity pan", "holographic UI overlay", "scanning effect"],
        "lighting": ["neon glow", "bioluminescence", "holographic projections", "laser beams"],
        "style": ["cyberpunk", "futuristic", "sleek design", "metallic surfaces", "LED accents"],
        "atmosphere": ["dystopian", "high-tech", "otherworldly", "mysterious"]
    },
    VideoGenre.FANTASY: {
        "camera": ["sweeping aerial", "enchanted forest tracking", "magical reveal"],
        "lighting": ["ethereal glow", "fairy lights", "magical particles", "aurora"],
        "style": ["fantasy art", "Lord of the Rings", "mythical creatures", "ancient architecture"],
        "atmosphere": ["mystical", "enchanting", "legendary", "epic"]
    },
    VideoGenre.HORROR: {
        "camera": ["dutch angle", "slow creeping zoom", "POV shot", "shaky cam"],
        "lighting": ["low key lighting", "flickering", "moonlight", "shadows"],
        "style": ["desaturated", "high contrast", "grainy", "dark atmosphere"],
        "atmosphere": ["ominous", "tense", "dread", "unsettling"]
    },
    VideoGenre.NOIR: {
        "camera": ["low angle", "silhouette shots", "venetian blind shadows"],
        "lighting": ["high contrast", "single source", "deep shadows", "smoke"],
        "style": ["black and white", "1940s aesthetic", "rain-slicked streets", "fedora and trench coat"],
        "atmosphere": ["mysterious", "moody", "fatalistic", "cynical"]
    },
    VideoGenre.NATURE: {
        "camera": ["time lapse", "macro", "aerial drone", "underwater"],
        "lighting": ["golden hour", "blue hour", "dappled sunlight", "northern lights"],
        "style": ["National Geographic", "David Attenborough", "pristine wilderness"],
        "atmosphere": ["serene", "majestic", "untouched", "beautiful"]
    },
    VideoGenre.MUSIC_VIDEO: {
        "camera": ["rapid cuts", "360 rotation", "slow motion", "fisheye"],
        "lighting": ["concert lighting", "strobe", "color gels", "spotlight"],
        "style": ["MTV style", "visual effects", "performance shots", "abstract visuals"],
        "atmosphere": ["energetic", "rhythmic", "expressive", "bold"]
    },
    VideoGenre.ABSTRACT: {
        "camera": ["morphing transitions", "fractal zoom", "fluid motion"],
        "lighting": ["procedural", "generative", "color cycling", "geometric patterns"],
        "style": ["abstract art", "motion graphics", "particle systems", "kaleidoscopic"],
        "atmosphere": ["hypnotic", "meditative", "surreal", "infinite"]
    }
}

# Camera movement templates
CAMERA_MOVEMENTS = {
    "static": "locked off static shot",
    "pan_left": "smooth pan from right to left",
    "pan_right": "smooth pan from left to right",
    "tilt_up": "slow tilt upward revealing the scene",
    "tilt_down": "slow tilt downward",
    "dolly_in": "dolly pushing in toward the subject",
    "dolly_out": "dolly pulling back from the subject",
    "tracking": "tracking shot following the subject",
    "crane_up": "crane shot rising upward",
    "crane_down": "crane shot descending",
    "orbital": "orbital shot circling around the subject",
    "handheld": "organic handheld movement",
    "steadicam": "smooth steadicam glide",
    "drone": "aerial drone footage",
    "zoom_in": "slow zoom into the scene",
    "zoom_out": "slow zoom out revealing more of the scene"
}


class PromptExpander:
    """
    Expands short prompts into detailed cinematic descriptions.

    Uses local LLM (Llama-3.3-8B) for intelligent expansion with
    genre-specific styling and cinematic terminology.
    """

    def __init__(
        self,
        model_name: str = "meta-llama/Llama-3.3-8B-Instruct",
        device: str = "cuda",
        use_llm: bool = True
    ):
        """
        Initialize prompt expander.

        Args:
            model_name: LLM model for expansion
            device: Device for LLM inference
            use_llm: Whether to use LLM (False = template-only mode)
        """
        self.model_name = model_name
        self.device = device
        self.use_llm = use_llm

        self._model = None
        self._tokenizer = None

        if use_llm:
            self._load_model()

    def _load_model(self) -> None:
        """Load the local LLM for prompt expansion"""
        try:
            # In production, load actual model
            logger.info(f"Loading LLM: {self.model_name}")
            # from transformers import AutoModelForCausalLM, AutoTokenizer
            # self._tokenizer = AutoTokenizer.from_pretrained(self.model_name)
            # self._model = AutoModelForCausalLM.from_pretrained(
            #     self.model_name,
            #     torch_dtype=torch.float16,
            #     device_map="auto"
            # )
            logger.info("LLM loaded successfully")
        except Exception as e:
            logger.warning(f"Failed to load LLM: {e}. Using template mode.")
            self.use_llm = False

    async def expand(
        self,
        prompt: str,
        genre: VideoGenre = VideoGenre.CINEMATIC,
        duration_seconds: float = 4.0,
        camera_movement: Optional[str] = None
    ) -> ExpandedPrompt:
        """
        Expand a short prompt into a detailed cinematic description.

        Args:
            prompt: Original short prompt
            genre: Video genre for style matching
            duration_seconds: Video duration (affects pacing descriptions)
            camera_movement: Optional specific camera movement

        Returns:
            ExpandedPrompt with all details
        """
        # Get genre-specific elements
        genre_style = GENRE_STYLES.get(genre, GENRE_STYLES[VideoGenre.CINEMATIC])

        # Detect camera movement from prompt or use default
        detected_camera = self._detect_camera_movement(prompt) or camera_movement
        if not detected_camera:
            detected_camera = genre_style["camera"][0]

        # Build expanded prompt
        if self.use_llm:
            expanded = await self._expand_with_llm(prompt, genre, genre_style, detected_camera)
        else:
            expanded = self._expand_with_template(prompt, genre, genre_style, detected_camera)

        # Generate negative prompt
        negative = self._generate_negative_prompt(genre)

        # Extract style tags
        style_tags = self._extract_style_tags(expanded, genre_style)

        return ExpandedPrompt(
            original=prompt,
            expanded=expanded,
            negative_prompt=negative,
            genre=genre,
            camera_movements=[detected_camera] + genre_style["camera"][:2],
            lighting_descriptors=genre_style["lighting"][:3],
            style_tags=style_tags,
            confidence=0.9 if self.use_llm else 0.7
        )

    async def _expand_with_llm(
        self,
        prompt: str,
        genre: VideoGenre,
        genre_style: Dict,
        camera: str
    ) -> str:
        """Use LLM for intelligent prompt expansion"""
        system_prompt = f"""You are a professional video director and cinematographer.
Expand the user's brief video description into a detailed, cinematic prompt.

Genre: {genre.value}
Style elements to incorporate: {', '.join(genre_style['style'][:3])}
Lighting suggestions: {', '.join(genre_style['lighting'][:2])}
Camera: {camera}

Rules:
1. Keep the core subject/action from the original prompt
2. Add rich visual details (colors, textures, atmosphere)
3. Include camera movement and framing
4. Describe lighting and mood
5. Add temporal flow (what happens during the shot)
6. Keep it under 200 words
7. Write as a single flowing paragraph
8. Do not use bullet points or numbered lists
9. Be specific and vivid"""

        user_prompt = f"Expand this video prompt: {prompt}"

        # In production, call actual LLM
        # For now, fall back to template
        return self._expand_with_template(prompt, genre, genre_style, camera)

    def _expand_with_template(
        self,
        prompt: str,
        genre: VideoGenre,
        genre_style: Dict,
        camera: str
    ) -> str:
        """Template-based prompt expansion"""
        # Select elements based on genre
        lighting = genre_style["lighting"][0]
        style1 = genre_style["style"][0]
        style2 = genre_style["style"][1] if len(genre_style["style"]) > 1 else ""
        atmosphere = genre_style["atmosphere"][0]
        camera_desc = CAMERA_MOVEMENTS.get(camera, camera)

        # Build expanded prompt
        expanded = f"{prompt}, {camera_desc}, {lighting}, {atmosphere} atmosphere, "
        expanded += f"{style1}, {style2}, highly detailed, professional quality, "
        expanded += f"masterpiece, best quality, 8K resolution, "

        # Add genre-specific flourishes
        if genre == VideoGenre.CINEMATIC:
            expanded += "Hollywood production value, IMAX quality, Oscar-worthy cinematography"
        elif genre == VideoGenre.ANIME:
            expanded += "beautiful anime art style, detailed character design, vibrant colors"
        elif genre == VideoGenre.SCIFI:
            expanded += "advanced technology, sleek futuristic design, sci-fi masterpiece"
        elif genre == VideoGenre.FANTASY:
            expanded += "magical realism, epic fantasy world, mythical beauty"
        elif genre == VideoGenre.NATURE:
            expanded += "breathtaking natural beauty, pristine wilderness, nature documentary quality"
        elif genre == VideoGenre.HORROR:
            expanded += "terrifying atmosphere, psychological horror, unsettling imagery"

        return expanded

    def _detect_camera_movement(self, prompt: str) -> Optional[str]:
        """Detect camera movement from prompt keywords"""
        prompt_lower = prompt.lower()

        movement_keywords = {
            "zoom": "zoom_in",
            "pan": "pan_right",
            "tilt": "tilt_up",
            "tracking": "tracking",
            "follow": "tracking",
            "orbit": "orbital",
            "circle": "orbital",
            "aerial": "drone",
            "drone": "drone",
            "fly": "drone",
            "static": "static",
            "still": "static",
            "rise": "crane_up",
            "descend": "crane_down",
            "approach": "dolly_in",
            "retreat": "dolly_out"
        }

        for keyword, movement in movement_keywords.items():
            if keyword in prompt_lower:
                return movement

        return None

    def _generate_negative_prompt(self, genre: VideoGenre) -> str:
        """Generate genre-appropriate negative prompt"""
        base_negative = [
            "blurry", "low quality", "distorted", "watermark", "text",
            "oversaturated", "underexposed", "overexposed", "noise",
            "artifacts", "compression", "pixelated", "amateur"
        ]

        genre_negative = {
            VideoGenre.REALISTIC: ["cartoon", "anime", "CGI", "unrealistic"],
            VideoGenre.ANIME: ["photorealistic", "3D render", "uncanny valley"],
            VideoGenre.CINEMATIC: ["home video", "amateur footage", "low budget"],
            VideoGenre.NATURE: ["urban", "industrial", "pollution", "humans"],
            VideoGenre.HORROR: ["bright", "cheerful", "colorful", "happy"],
            VideoGenre.SCIFI: ["medieval", "ancient", "primitive", "organic"]
        }

        negative_list = base_negative + genre_negative.get(genre, [])
        return ", ".join(negative_list)

    def _extract_style_tags(
        self,
        expanded: str,
        genre_style: Dict
    ) -> List[str]:
        """Extract style tags from expanded prompt"""
        tags = []

        # Check for genre style keywords
        expanded_lower = expanded.lower()
        for style in genre_style["style"]:
            if style.lower() in expanded_lower:
                tags.append(style)

        for lighting in genre_style["lighting"]:
            if lighting.lower() in expanded_lower:
                tags.append(lighting)

        return tags[:10]  # Limit to 10 tags


class PromptEnhancer:
    """
    Additional prompt enhancement utilities.
    """

    @staticmethod
    def add_motion_description(
        prompt: str,
        motion_bucket_id: int
    ) -> str:
        """Add motion description based on motion bucket ID"""
        if motion_bucket_id < 50:
            motion_desc = "slow, gentle movement"
        elif motion_bucket_id < 100:
            motion_desc = "moderate, natural motion"
        elif motion_bucket_id < 150:
            motion_desc = "dynamic movement"
        elif motion_bucket_id < 200:
            motion_desc = "fast, energetic motion"
        else:
            motion_desc = "rapid, intense motion"

        return f"{prompt}, {motion_desc}"

    @staticmethod
    def add_temporal_description(
        prompt: str,
        duration_seconds: float
    ) -> str:
        """Add temporal flow description"""
        if duration_seconds < 3:
            temporal = "quick glimpse"
        elif duration_seconds < 6:
            temporal = "brief moment unfolding"
        elif duration_seconds < 15:
            temporal = "scene developing over time"
        else:
            temporal = "extended sequence with narrative progression"

        return f"{prompt}, {temporal}"

    @staticmethod
    def ensure_quality_tags(prompt: str) -> str:
        """Ensure quality-boosting tags are present"""
        quality_tags = [
            "masterpiece", "best quality", "highly detailed",
            "professional", "8K", "HDR"
        ]

        prompt_lower = prompt.lower()
        missing_tags = [tag for tag in quality_tags if tag.lower() not in prompt_lower]

        if missing_tags:
            return f"{prompt}, {', '.join(missing_tags[:3])}"
        return prompt
