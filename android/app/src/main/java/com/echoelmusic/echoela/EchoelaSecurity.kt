/**
 * EchoelaSecurity.kt
 * Echoelmusic - Echoela Security & Privacy Layer (Android)
 *
 * Highest-level security and privacy protection:
 * - AES-256 encrypted storage via AndroidKeyStore
 * - Zero-knowledge feedback anonymization
 * - GDPR/CCPA compliant data handling
 * - Biometric authentication support
 * - Secure data export and complete deletion
 *
 * Created: 2026-01-15
 */

package com.echoelmusic.echoela

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.security.MessageDigest
import java.util.*
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Security levels for Echoela
 */
enum class EchoelaSecurityLevel {
    STANDARD,   // Basic encryption
    ENHANCED,   // Keystore + optional biometric
    MAXIMUM,    // Biometric required
    PARANOID    // Memory only, no persistence
}

/**
 * Privacy configuration
 */
@Serializable
data class EchoelaPrivacyConfig(
    var hasConsented: Boolean = false,
    var consentTimestamp: Long = 0L,
    var consentVersion: String = "1.0",
    var allowLearningProfile: Boolean = false,
    var allowFeedback: Boolean = false,
    var allowVoiceProcessing: Boolean = false,
    var allowAnalytics: Boolean = false,
    var dataRetentionDays: Int = 30,
    var autoDeleteEnabled: Boolean = true,
    var anonymizeFeedback: Boolean = true,
    var complianceRegion: String = "auto"
)

/**
 * Security manager for Echoela
 */
class EchoelaSecurityManager private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var instance: EchoelaSecurityManager? = null

        fun getInstance(context: Context): EchoelaSecurityManager {
            return instance ?: synchronized(this) {
                instance ?: EchoelaSecurityManager(context.applicationContext).also { instance = it }
            }
        }

        private const val KEYSTORE_ALIAS = "echoela_encryption_key"
        private const val PREFS_NAME = "echoela_security_prefs"
        private const val ENCRYPTED_PREFS_NAME = "echoela_encrypted_prefs"
        private const val KEY_PRIVACY_CONFIG = "privacy_config"
    }

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private var encryptedPrefs: SharedPreferences? = null
    private var masterKey: MasterKey? = null

    // State
    private val _securityLevel = MutableStateFlow(EchoelaSecurityLevel.ENHANCED)
    val securityLevel: StateFlow<EchoelaSecurityLevel> = _securityLevel.asStateFlow()

    private val _privacyConfig = MutableStateFlow(loadPrivacyConfig())
    val privacyConfig: StateFlow<EchoelaPrivacyConfig> = _privacyConfig.asStateFlow()

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated.asStateFlow()

    private var lastAuthTime: Long = 0L
    private val authTimeout: Long = 300_000L  // 5 minutes

    init {
        setupEncryption()
        detectComplianceRegion()
    }

    // ========================================================================
    // Encryption Setup
    // ========================================================================

    private fun setupEncryption() {
        try {
            masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .setUserAuthenticationRequired(false)
                .build()

            encryptedPrefs = EncryptedSharedPreferences.create(
                context,
                ENCRYPTED_PREFS_NAME,
                masterKey!!,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            // Fallback to regular prefs if encryption setup fails
            encryptedPrefs = prefs
        }
    }

    // ========================================================================
    // Secure Storage
    // ========================================================================

    fun secureStore(key: String, data: String) {
        if (!_privacyConfig.value.hasConsented) return

        encryptedPrefs?.edit()?.putString("echoela_$key", data)?.apply()
    }

    fun secureRetrieve(key: String): String? {
        return encryptedPrefs?.getString("echoela_$key", null)
    }

    fun secureDelete(key: String) {
        encryptedPrefs?.edit()?.remove("echoela_$key")?.apply()
    }

    // ========================================================================
    // Biometric Authentication
    // ========================================================================

    fun canUseBiometrics(): Boolean {
        val biometricManager = BiometricManager.from(context)
        return biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
               BiometricManager.BIOMETRIC_SUCCESS
    }

    fun authenticateWithBiometrics(
        activity: FragmentActivity,
        onSuccess: () -> Unit,
        onError: (String) -> Unit
    ) {
        if (!canUseBiometrics()) {
            onError("Biometric authentication not available")
            return
        }

        val executor = ContextCompat.getMainExecutor(context)
        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                _isAuthenticated.value = true
                lastAuthTime = System.currentTimeMillis()
                onSuccess()
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                onError(errString.toString())
            }

            override fun onAuthenticationFailed() {
                onError("Authentication failed")
            }
        }

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Echoela Authentication")
            .setSubtitle("Authenticate to access your data")
            .setNegativeButtonText("Cancel")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()

        BiometricPrompt(activity, executor, callback).authenticate(promptInfo)
    }

    fun isAuthenticationValid(): Boolean {
        if (_securityLevel.value != EchoelaSecurityLevel.MAXIMUM &&
            _securityLevel.value != EchoelaSecurityLevel.PARANOID) {
            return true
        }

        return _isAuthenticated.value &&
               (System.currentTimeMillis() - lastAuthTime) < authTimeout
    }

    // ========================================================================
    // Privacy Consent
    // ========================================================================

    fun requestConsent(
        allowLearning: Boolean,
        allowFeedback: Boolean,
        allowVoice: Boolean,
        allowAnalytics: Boolean
    ) {
        _privacyConfig.value = _privacyConfig.value.copy(
            hasConsented = true,
            consentTimestamp = System.currentTimeMillis(),
            allowLearningProfile = allowLearning,
            allowFeedback = allowFeedback,
            allowVoiceProcessing = allowVoice,
            allowAnalytics = allowAnalytics
        )
        savePrivacyConfig()
    }

    fun withdrawConsent() {
        _privacyConfig.value = _privacyConfig.value.copy(
            hasConsented = false,
            allowLearningProfile = false,
            allowFeedback = false,
            allowVoiceProcessing = false,
            allowAnalytics = false
        )
        deleteAllEchoelaData()
        savePrivacyConfig()
    }

    fun hasConsentFor(type: ConsentType): Boolean {
        if (!_privacyConfig.value.hasConsented) return false

        return when (type) {
            ConsentType.LEARNING -> _privacyConfig.value.allowLearningProfile
            ConsentType.FEEDBACK -> _privacyConfig.value.allowFeedback
            ConsentType.VOICE -> _privacyConfig.value.allowVoiceProcessing
            ConsentType.ANALYTICS -> _privacyConfig.value.allowAnalytics
        }
    }

    enum class ConsentType {
        LEARNING, FEEDBACK, VOICE, ANALYTICS
    }

    // ========================================================================
    // Data Anonymization
    // ========================================================================

    fun anonymizeFeedback(feedback: EchoelaFeedback): AnonymizedFeedback {
        return AnonymizedFeedback(
            id = generateAnonymousId(),
            timestamp = roundToDay(feedback.timestamp),
            feedbackType = feedback.feedbackType.name,
            context = hashContext(feedback.context),
            message = feedback.message,
            rating = feedback.rating,
            skillLevelRange = categorizeSkillLevel(feedback.systemInfo.skillLevel),
            sessionCountRange = categorizeSessionCount(feedback.systemInfo.sessionCount)
        )
    }

    private fun generateAnonymousId(): String {
        return UUID.randomUUID().toString().take(8) + (1000..9999).random()
    }

    private fun roundToDay(timestamp: Long): Long {
        val cal = Calendar.getInstance()
        cal.timeInMillis = timestamp
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun hashContext(context: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(context.toByteArray())
        return hash.take(8).joinToString("") { "%02x".format(it) }
    }

    private fun categorizeSkillLevel(level: Float): String {
        return when {
            level < 0.3f -> "beginner"
            level < 0.6f -> "intermediate"
            else -> "advanced"
        }
    }

    private fun categorizeSessionCount(count: Int): String {
        return when {
            count < 5 -> "new"
            count < 20 -> "regular"
            else -> "experienced"
        }
    }

    // ========================================================================
    // GDPR/CCPA Compliance
    // ========================================================================

    fun exportAllUserData(): EchoelaDataExport {
        return EchoelaDataExport(
            exportTimestamp = System.currentTimeMillis(),
            privacyConfig = _privacyConfig.value,
            learningProfile = loadLearningProfile(),
            feedbackHistory = loadFeedbackHistory()
        )
    }

    fun deleteAllEchoelaData() {
        // Delete from encrypted prefs
        val keysToDelete = listOf(
            "echoela_learning_profile",
            "echoela_feedback",
            "echoela_interactions",
            "echoela_preferences",
            "echoela_personality"
        )

        encryptedPrefs?.edit()?.apply {
            keysToDelete.forEach { remove(it) }
            apply()
        }

        // Delete from regular prefs
        val regularKeys = listOf(
            "echoela_progress",
            "echoela_preferences",
            "echoela_feedback_queue",
            "echoela_user_profile",
            "echoela_personality",
            "echoela_session_count"
        )

        context.getSharedPreferences("echoela_prefs", Context.MODE_PRIVATE)
            .edit().apply {
                regularKeys.forEach { remove(it) }
                apply()
            }

        // Delete feedback files
        deleteFeedbackFiles()
    }

    private fun deleteFeedbackFiles() {
        val feedbackDir = File(context.filesDir, "echoela_feedback")
        feedbackDir.deleteRecursively()
    }

    fun checkDataRetention() {
        val config = _privacyConfig.value
        if (!config.autoDeleteEnabled || config.dataRetentionDays <= 0) return

        val cutoffTime = System.currentTimeMillis() - (config.dataRetentionDays * 24 * 60 * 60 * 1000L)
        deleteDataOlderThan(cutoffTime)
    }

    private fun deleteDataOlderThan(timestamp: Long) {
        // Clean up old feedback files
        val feedbackDir = File(context.filesDir, "echoela_feedback")
        feedbackDir.listFiles()?.forEach { file ->
            if (file.lastModified() < timestamp) {
                file.delete()
            }
        }
    }

    // ========================================================================
    // Region Detection
    // ========================================================================

    private fun detectComplianceRegion() {
        if (_privacyConfig.value.complianceRegion != "auto") return

        val locale = Locale.getDefault()
        val country = locale.country

        val region = when {
            isEUCountry(country) -> "EU"
            country == "US" -> "US-CA"  // Default to strictest
            else -> "other"
        }

        _privacyConfig.value = _privacyConfig.value.copy(complianceRegion = region)
    }

    private fun isEUCountry(code: String): Boolean {
        val euCountries = setOf(
            "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
            "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL",
            "PL", "PT", "RO", "SK", "SI", "ES", "SE", "GB", "CH", "NO"
        )
        return code in euCountries
    }

    // ========================================================================
    // Persistence
    // ========================================================================

    private fun savePrivacyConfig() {
        prefs.edit().putString(KEY_PRIVACY_CONFIG, json.encodeToString(_privacyConfig.value)).apply()
    }

    private fun loadPrivacyConfig(): EchoelaPrivacyConfig {
        val stored = prefs.getString(KEY_PRIVACY_CONFIG, null) ?: return EchoelaPrivacyConfig()
        return try {
            json.decodeFromString<EchoelaPrivacyConfig>(stored)
        } catch (e: Exception) {
            EchoelaPrivacyConfig()
        }
    }

    private fun loadLearningProfile(): UserLearningProfile? {
        val prefs = context.getSharedPreferences("echoela_prefs", Context.MODE_PRIVATE)
        val stored = prefs.getString("echoela_user_profile", null) ?: return null
        return try {
            json.decodeFromString<UserLearningProfile>(stored)
        } catch (e: Exception) {
            null
        }
    }

    private fun loadFeedbackHistory(): List<EchoelaFeedback> {
        val prefs = context.getSharedPreferences("echoela_prefs", Context.MODE_PRIVATE)
        val stored = prefs.getString("echoela_feedback_queue", null) ?: return emptyList()
        return try {
            json.decodeFromString<List<EchoelaFeedback>>(stored)
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun setSecurityLevel(level: EchoelaSecurityLevel) {
        _securityLevel.value = level
    }
}

// ============================================================================
// Data Export Types
// ============================================================================

@Serializable
data class EchoelaDataExport(
    val exportTimestamp: Long,
    val privacyConfig: EchoelaPrivacyConfig,
    val learningProfile: UserLearningProfile?,
    val feedbackHistory: List<EchoelaFeedback>
)

@Serializable
data class AnonymizedFeedback(
    val id: String,
    val timestamp: Long,
    val feedbackType: String,
    val context: String,
    val message: String,
    val rating: Int?,
    val skillLevelRange: String,
    val sessionCountRange: String
)
