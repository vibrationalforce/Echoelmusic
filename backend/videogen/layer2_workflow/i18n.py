"""
Internationalization (i18n) Support for Video Generation API
=============================================================

Provides multi-language support for error messages, notifications,
and API responses for worldwide marketing.

Supported Languages: 22+
- European: DE, EN, ES, FR, IT, PT, RU, PL, TR
- Asian: ZH, JA, KO, HI, ID, TH, VI
- Middle Eastern: AR, HE, FA
"""

from typing import Dict, Optional, Any
from enum import Enum
from dataclasses import dataclass
import os
import logging

logger = logging.getLogger(__name__)


class Language(str, Enum):
    """Supported languages"""
    # European
    ENGLISH = "en"
    GERMAN = "de"
    SPANISH = "es"
    FRENCH = "fr"
    ITALIAN = "it"
    PORTUGUESE = "pt"
    RUSSIAN = "ru"
    POLISH = "pl"
    TURKISH = "tr"

    # Asian
    CHINESE_SIMPLIFIED = "zh-Hans"
    CHINESE_TRADITIONAL = "zh-Hant"
    JAPANESE = "ja"
    KOREAN = "ko"
    HINDI = "hi"
    INDONESIAN = "id"
    THAI = "th"
    VIETNAMESE = "vi"

    # Middle Eastern
    ARABIC = "ar"
    HEBREW = "he"
    PERSIAN = "fa"


class MessageKey(str, Enum):
    """Message keys for translation"""
    # Status messages
    GENERATION_STARTED = "generation.started"
    GENERATION_PROGRESS = "generation.progress"
    GENERATION_COMPLETED = "generation.completed"
    GENERATION_FAILED = "generation.failed"
    GENERATION_CANCELLED = "generation.cancelled"

    # Error messages
    ERROR_INVALID_PROMPT = "error.invalid_prompt"
    ERROR_RATE_LIMITED = "error.rate_limited"
    ERROR_MODEL_LOADING = "error.model_loading"
    ERROR_OUT_OF_MEMORY = "error.out_of_memory"
    ERROR_INVALID_IMAGE = "error.invalid_image"
    ERROR_FILE_NOT_FOUND = "error.file_not_found"
    ERROR_PERMISSION_DENIED = "error.permission_denied"
    ERROR_NETWORK = "error.network"
    ERROR_TIMEOUT = "error.timeout"
    ERROR_INTERNAL = "error.internal"

    # Webhook messages
    WEBHOOK_TASK_STARTED = "webhook.task_started"
    WEBHOOK_TASK_COMPLETED = "webhook.task_completed"
    WEBHOOK_TASK_FAILED = "webhook.task_failed"

    # API messages
    API_UNAUTHORIZED = "api.unauthorized"
    API_FORBIDDEN = "api.forbidden"
    API_NOT_FOUND = "api.not_found"
    API_BAD_REQUEST = "api.bad_request"


# Translation dictionaries
TRANSLATIONS: Dict[str, Dict[str, str]] = {
    "en": {
        # Status
        "generation.started": "Video generation started",
        "generation.progress": "Generating video: {progress}%",
        "generation.completed": "Video generation completed successfully",
        "generation.failed": "Video generation failed: {error}",
        "generation.cancelled": "Video generation was cancelled",

        # Errors
        "error.invalid_prompt": "Invalid prompt provided",
        "error.rate_limited": "Rate limit exceeded. Please try again in {seconds} seconds",
        "error.model_loading": "Model is loading, please wait",
        "error.out_of_memory": "Out of GPU memory. Try reducing resolution or frames",
        "error.invalid_image": "Invalid input image format or size",
        "error.file_not_found": "Requested file not found",
        "error.permission_denied": "Permission denied",
        "error.network": "Network error occurred",
        "error.timeout": "Request timed out",
        "error.internal": "Internal server error",

        # Webhook
        "webhook.task_started": "Task {task_id} started processing",
        "webhook.task_completed": "Task {task_id} completed",
        "webhook.task_failed": "Task {task_id} failed: {error}",

        # API
        "api.unauthorized": "Authentication required",
        "api.forbidden": "Access denied",
        "api.not_found": "Resource not found",
        "api.bad_request": "Invalid request",
    },
    "de": {
        # Status
        "generation.started": "Videogenerierung gestartet",
        "generation.progress": "Video wird generiert: {progress}%",
        "generation.completed": "Videogenerierung erfolgreich abgeschlossen",
        "generation.failed": "Videogenerierung fehlgeschlagen: {error}",
        "generation.cancelled": "Videogenerierung wurde abgebrochen",

        # Errors
        "error.invalid_prompt": "Ungültige Eingabeaufforderung",
        "error.rate_limited": "Anfragelimit überschritten. Bitte in {seconds} Sekunden erneut versuchen",
        "error.model_loading": "Modell wird geladen, bitte warten",
        "error.out_of_memory": "GPU-Speicher erschöpft. Versuchen Sie, die Auflösung oder die Frames zu reduzieren",
        "error.invalid_image": "Ungültiges Bildformat oder -größe",
        "error.file_not_found": "Angeforderte Datei nicht gefunden",
        "error.permission_denied": "Zugriff verweigert",
        "error.network": "Netzwerkfehler aufgetreten",
        "error.timeout": "Zeitüberschreitung der Anfrage",
        "error.internal": "Interner Serverfehler",

        # API
        "api.unauthorized": "Authentifizierung erforderlich",
        "api.forbidden": "Zugriff verweigert",
        "api.not_found": "Ressource nicht gefunden",
        "api.bad_request": "Ungültige Anfrage",
    },
    "es": {
        # Status
        "generation.started": "Generación de video iniciada",
        "generation.progress": "Generando video: {progress}%",
        "generation.completed": "Generación de video completada con éxito",
        "generation.failed": "La generación de video falló: {error}",
        "generation.cancelled": "La generación de video fue cancelada",

        # Errors
        "error.invalid_prompt": "Prompt no válido",
        "error.rate_limited": "Límite de solicitudes excedido. Intente de nuevo en {seconds} segundos",
        "error.out_of_memory": "Sin memoria GPU. Intente reducir la resolución o los frames",

        # API
        "api.unauthorized": "Autenticación requerida",
        "api.forbidden": "Acceso denegado",
        "api.not_found": "Recurso no encontrado",
        "api.bad_request": "Solicitud no válida",
    },
    "fr": {
        # Status
        "generation.started": "Génération vidéo démarrée",
        "generation.progress": "Génération de la vidéo: {progress}%",
        "generation.completed": "Génération vidéo terminée avec succès",
        "generation.failed": "La génération vidéo a échoué: {error}",

        # Errors
        "error.invalid_prompt": "Prompt invalide",
        "error.rate_limited": "Limite de requêtes dépassée. Réessayez dans {seconds} secondes",

        # API
        "api.unauthorized": "Authentification requise",
        "api.forbidden": "Accès refusé",
        "api.not_found": "Ressource non trouvée",
    },
    "zh-Hans": {
        # Status
        "generation.started": "视频生成已开始",
        "generation.progress": "正在生成视频: {progress}%",
        "generation.completed": "视频生成成功完成",
        "generation.failed": "视频生成失败: {error}",

        # Errors
        "error.invalid_prompt": "无效的提示词",
        "error.rate_limited": "请求限制已超过。请在 {seconds} 秒后重试",
        "error.out_of_memory": "GPU内存不足。请尝试降低分辨率或帧数",

        # API
        "api.unauthorized": "需要身份验证",
        "api.forbidden": "拒绝访问",
        "api.not_found": "资源未找到",
    },
    "ja": {
        # Status
        "generation.started": "動画生成を開始しました",
        "generation.progress": "動画を生成中: {progress}%",
        "generation.completed": "動画生成が正常に完了しました",
        "generation.failed": "動画生成に失敗しました: {error}",

        # Errors
        "error.invalid_prompt": "無効なプロンプト",
        "error.rate_limited": "レート制限を超えました。{seconds}秒後に再試行してください",
        "error.out_of_memory": "GPUメモリ不足。解像度またはフレーム数を減らしてください",

        # API
        "api.unauthorized": "認証が必要です",
        "api.forbidden": "アクセスが拒否されました",
        "api.not_found": "リソースが見つかりません",
    },
    "ar": {
        # Status (RTL)
        "generation.started": "بدأ إنشاء الفيديو",
        "generation.progress": "جاري إنشاء الفيديو: {progress}%",
        "generation.completed": "تم إنشاء الفيديو بنجاح",
        "generation.failed": "فشل إنشاء الفيديو: {error}",

        # Errors
        "error.invalid_prompt": "موجه غير صالح",
        "error.rate_limited": "تم تجاوز حد الطلبات. يرجى المحاولة مرة أخرى بعد {seconds} ثانية",

        # API
        "api.unauthorized": "المصادقة مطلوبة",
        "api.forbidden": "تم رفض الوصول",
        "api.not_found": "المورد غير موجود",
    },
    "ko": {
        # Status
        "generation.started": "비디오 생성이 시작되었습니다",
        "generation.progress": "비디오 생성 중: {progress}%",
        "generation.completed": "비디오 생성이 성공적으로 완료되었습니다",
        "generation.failed": "비디오 생성 실패: {error}",

        # Errors
        "error.invalid_prompt": "잘못된 프롬프트",
        "error.rate_limited": "요청 한도를 초과했습니다. {seconds}초 후에 다시 시도하세요",

        # API
        "api.unauthorized": "인증이 필요합니다",
        "api.forbidden": "접근이 거부되었습니다",
        "api.not_found": "리소스를 찾을 수 없습니다",
    },
}


@dataclass
class I18nConfig:
    """Configuration for i18n"""
    default_language: Language = Language.ENGLISH
    fallback_language: Language = Language.ENGLISH


class I18n:
    """
    Internationalization handler for the video generation API.

    Usage:
        i18n = I18n()

        # Get translated message
        msg = i18n.translate(MessageKey.GENERATION_STARTED, "de")

        # With parameters
        msg = i18n.translate(
            MessageKey.GENERATION_PROGRESS,
            "ja",
            progress=50
        )
    """

    def __init__(self, config: Optional[I18nConfig] = None):
        self.config = config or I18nConfig()
        self._custom_translations: Dict[str, Dict[str, str]] = {}

    def translate(
        self,
        key: MessageKey,
        language: Optional[str] = None,
        **kwargs: Any
    ) -> str:
        """
        Translate a message key to the specified language.

        Args:
            key: Message key to translate
            language: Target language code (e.g., "en", "de", "ja")
            **kwargs: Format parameters for the message

        Returns:
            Translated message string
        """
        lang = language or self.config.default_language.value
        key_str = key.value

        # Try custom translations first
        if lang in self._custom_translations:
            if key_str in self._custom_translations[lang]:
                return self._format_message(
                    self._custom_translations[lang][key_str],
                    kwargs
                )

        # Try built-in translations
        if lang in TRANSLATIONS:
            if key_str in TRANSLATIONS[lang]:
                return self._format_message(
                    TRANSLATIONS[lang][key_str],
                    kwargs
                )

        # Fallback to default language
        fallback_lang = self.config.fallback_language.value
        if fallback_lang in TRANSLATIONS:
            if key_str in TRANSLATIONS[fallback_lang]:
                return self._format_message(
                    TRANSLATIONS[fallback_lang][key_str],
                    kwargs
                )

        # Return key as last resort
        logger.warning(f"Missing translation for key: {key_str} in language: {lang}")
        return key_str

    def _format_message(self, template: str, params: Dict[str, Any]) -> str:
        """Format a message template with parameters"""
        try:
            return template.format(**params)
        except KeyError as e:
            logger.warning(f"Missing format parameter: {e}")
            return template

    def add_translations(self, language: str, translations: Dict[str, str]) -> None:
        """Add custom translations for a language"""
        if language not in self._custom_translations:
            self._custom_translations[language] = {}
        self._custom_translations[language].update(translations)

    def get_supported_languages(self) -> list[Language]:
        """Get list of supported languages"""
        return list(Language)

    def is_rtl(self, language: str) -> bool:
        """Check if language is right-to-left"""
        rtl_languages = {"ar", "he", "fa"}
        return language in rtl_languages

    def detect_language_from_header(self, accept_language: str) -> str:
        """
        Detect preferred language from Accept-Language header.

        Args:
            accept_language: HTTP Accept-Language header value

        Returns:
            Detected language code
        """
        if not accept_language:
            return self.config.default_language.value

        # Parse Accept-Language header
        # Format: "en-US,en;q=0.9,de;q=0.8"
        languages = []
        for part in accept_language.split(","):
            lang_parts = part.strip().split(";")
            lang = lang_parts[0].strip()

            # Extract quality value
            q = 1.0
            if len(lang_parts) > 1:
                try:
                    q = float(lang_parts[1].split("=")[1])
                except (ValueError, IndexError):
                    pass

            languages.append((lang, q))

        # Sort by quality
        languages.sort(key=lambda x: x[1], reverse=True)

        # Find first supported language
        for lang, _ in languages:
            # Try exact match
            if lang in TRANSLATIONS:
                return lang

            # Try language without region
            base_lang = lang.split("-")[0]
            if base_lang in TRANSLATIONS:
                return base_lang

        return self.config.default_language.value


# Global i18n instance
i18n = I18n()


def t(key: MessageKey, language: Optional[str] = None, **kwargs: Any) -> str:
    """Shorthand for translation"""
    return i18n.translate(key, language, **kwargs)


__all__ = [
    "Language",
    "MessageKey",
    "I18nConfig",
    "I18n",
    "i18n",
    "t",
    "TRANSLATIONS",
]
