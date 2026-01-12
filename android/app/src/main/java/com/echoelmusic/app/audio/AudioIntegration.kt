package com.echoelmusic.app.audio

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Audio Integration Manager
 * Coordinates AudioEngine (synth) with ImmersiveIsochronicEngine (entrainment)
 *
 * Provides unified control over:
 * - Synth engine (notes, parameters, TR-808)
 * - Isochronic entrainment (presets, soundscapes, breath-sync)
 * - Bio-reactive audio routing
 *
 * This is the main entry point for audio functionality in Echoelmusic Android.
 */
class AudioIntegration(private val context: Context) {

    companion object {
        private const val TAG = "AudioIntegration"
    }

    // MARK: - Engines

    private val audioEngine: AudioEngine by lazy { AudioEngine(context) }
    private val isochronicEngine: ImmersiveIsochronicEngine by lazy { ImmersiveIsochronicEngine() }

    // MARK: - State

    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning

    private val _isochronicEnabled = MutableStateFlow(false)
    val isochronicEnabled: StateFlow<Boolean> = _isochronicEnabled

    private val _currentPreset = MutableStateFlow(ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS)
    val currentPreset: StateFlow<ImmersiveIsochronicEngine.EntrainmentPreset> = _currentPreset

    private val _currentSoundscape = MutableStateFlow(ImmersiveIsochronicEngine.Soundscape.WARM_PAD)
    val currentSoundscape: StateFlow<ImmersiveIsochronicEngine.Soundscape> = _currentSoundscape

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    // Volume levels
    var synthVolume: Float = 0.8f
        set(value) {
            field = value.coerceIn(0f, 1f)
            audioEngine.setMasterVolume(field)
        }

    var isochronicVolume: Float = 0.5f
        set(value) {
            field = value.coerceIn(0f, 1f)
            isochronicEngine.volume = field
        }

    // MARK: - Lifecycle

    fun start() {
        if (_isRunning.value) return

        audioEngine.start()
        _isRunning.value = true
        Log.i(TAG, "Audio integration started")
    }

    fun stop() {
        if (!_isRunning.value) return

        audioEngine.stop()
        if (isochronicEngine.isPlaying.value) {
            isochronicEngine.stop()
        }
        _isRunning.value = false
        Log.i(TAG, "Audio integration stopped")
    }

    fun shutdown() {
        stop()
        scope.cancel()
        audioEngine.shutdown()
        isochronicEngine.shutdown()
        Log.i(TAG, "Audio integration shutdown")
    }

    // MARK: - Synth Controls

    fun noteOn(note: Int, velocity: Int) {
        audioEngine.noteOn(note, velocity)
    }

    fun noteOff(note: Int) {
        audioEngine.noteOff(note)
    }

    fun setParameter(paramId: Int, value: Float) {
        audioEngine.setParameter(paramId, value)
    }

    fun setFilterCutoff(value: Float) {
        audioEngine.setFilterCutoff(value)
    }

    fun setFilterResonance(value: Float) {
        audioEngine.setFilterResonance(value)
    }

    fun setReverbWetness(value: Float) {
        audioEngine.setReverbWetness(value)
    }

    fun setTempo(bpm: Float) {
        audioEngine.setTempo(bpm)
    }

    // MARK: - TR-808 Bass

    fun trigger808(note: Int, velocity: Int) {
        audioEngine.trigger808(note, velocity)
    }

    fun set808Parameter(paramId: Int, value: Float) {
        audioEngine.set808Parameter(paramId, value)
    }

    // MARK: - Isochronic Controls

    fun enableIsochronic(preset: ImmersiveIsochronicEngine.EntrainmentPreset = currentPreset.value) {
        if (_isochronicEnabled.value) return

        isochronicEngine.configure(preset)
        isochronicEngine.start()
        _isochronicEnabled.value = true
        _currentPreset.value = preset
        Log.i(TAG, "Isochronic enabled: ${preset.displayName}")
    }

    fun disableIsochronic() {
        if (!_isochronicEnabled.value) return

        isochronicEngine.stop()
        _isochronicEnabled.value = false
        Log.i(TAG, "Isochronic disabled")
    }

    fun toggleIsochronic() {
        if (_isochronicEnabled.value) {
            disableIsochronic()
        } else {
            enableIsochronic()
        }
    }

    fun setEntrainmentPreset(preset: ImmersiveIsochronicEngine.EntrainmentPreset) {
        isochronicEngine.configure(preset)
        _currentPreset.value = preset
        Log.i(TAG, "Entrainment preset: ${preset.displayName}")
    }

    fun setSoundscape(soundscape: ImmersiveIsochronicEngine.Soundscape) {
        isochronicEngine.configure(_currentPreset.value, soundscape)
        _currentSoundscape.value = soundscape
        Log.i(TAG, "Soundscape: ${soundscape.displayName}")
    }

    fun transitionToSoundscape(soundscape: ImmersiveIsochronicEngine.Soundscape) {
        isochronicEngine.transitionTo(soundscape)
        _currentSoundscape.value = soundscape
        Log.i(TAG, "Transitioning to soundscape: ${soundscape.displayName}")
    }

    // MARK: - Breath Sync

    fun enableBreathSync(breathingRate: Float = 6f) {
        isochronicEngine.enableBreathSync(breathingRate)
        Log.i(TAG, "Breath sync enabled at ${breathingRate} BPM")
    }

    fun disableBreathSync() {
        isochronicEngine.disableBreathSync()
        Log.i(TAG, "Breath sync disabled")
    }

    fun updateBreathingRate(rate: Float) {
        isochronicEngine.updateBreathingRate(rate)
    }

    // MARK: - Bio-Reactive

    fun updateBioData(heartRate: Float, hrv: Float, coherence: Float) {
        // Update synth engine
        audioEngine.updateBioData(heartRate, hrv, coherence)

        // Modulate isochronic engine
        isochronicEngine.modulateFromCoherence(coherence.toDouble() * 100)
        isochronicEngine.modulateFromHeartRate(heartRate.toDouble())
    }

    fun setBioModulationAmount(amount: Float) {
        isochronicEngine.bioModulationAmount = amount
    }

    // MARK: - Session Stats

    fun getSessionStats(): ImmersiveIsochronicEngine.SessionStatistics {
        return isochronicEngine.sessionStats.value
    }

    fun getCurrentSessionDuration(): Int {
        return isochronicEngine.currentSessionDuration
    }

    // MARK: - Engine Access (for advanced usage)

    fun getAudioEngine(): AudioEngine = audioEngine
    fun getIsochronicEngine(): ImmersiveIsochronicEngine = isochronicEngine
}
