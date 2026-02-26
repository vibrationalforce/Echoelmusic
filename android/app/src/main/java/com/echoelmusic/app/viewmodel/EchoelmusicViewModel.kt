package com.echoelmusic.app.viewmodel

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.echoelmusic.app.audio.AudioEngine
import com.echoelmusic.app.midi.MidiManager
import com.echoelmusic.app.bio.BioReactiveEngine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Brainwave state presets for binaural beats generation.
 * Each state corresponds to a frequency range and a carrier/offset pair.
 *
 * NOTE: These are audio exploration tools, NOT therapeutic claims.
 */
enum class BrainwaveState(
    val displayName: String,
    val description: String,
    val frequencyRange: String,
    val binauralBeatHz: Float,
    val carrierHz: Float
) {
    DELTA(
        displayName = "Delta",
        description = "Deep sleep / recovery",
        frequencyRange = "0.5 - 4 Hz",
        binauralBeatHz = 2.0f,
        carrierHz = 200f
    ),
    THETA(
        displayName = "Theta",
        description = "Meditation / creativity",
        frequencyRange = "4 - 8 Hz",
        binauralBeatHz = 6.0f,
        carrierHz = 220f
    ),
    ALPHA(
        displayName = "Alpha",
        description = "Relaxation / calm focus",
        frequencyRange = "8 - 13 Hz",
        binauralBeatHz = 10.0f,
        carrierHz = 250f
    ),
    BETA(
        displayName = "Beta",
        description = "Active focus / concentration",
        frequencyRange = "13 - 30 Hz",
        binauralBeatHz = 18.0f,
        carrierHz = 300f
    ),
    GAMMA(
        displayName = "Gamma",
        description = "Peak performance / insight",
        frequencyRange = "30 - 100 Hz",
        binauralBeatHz = 40.0f,
        carrierHz = 400f
    )
}

/**
 * Echoelmusic ViewModel
 * Proper Android architecture replacing singleton pattern.
 *
 * Benefits:
 * - Survives configuration changes (rotation, etc.)
 * - Proper lifecycle management
 * - No memory leaks from Activity/Context references
 * - Scoped coroutines with viewModelScope
 *
 * Manages:
 * - Audio engine (Oboe-based low-latency synth)
 * - MIDI manager (USB + BLE MIDI)
 * - Bio-reactive engine (Health Connect integration)
 * - Binaural beats generation state
 * - Audio transport controls
 */
class EchoelmusicViewModel(application: Application) : AndroidViewModel(application) {

    companion object {
        private const val TAG = "EchoelmusicVM"
    }

    // ================================================================
    // Engines - lazily initialized, lifecycle-aware
    // ================================================================
    private val _audioEngine: AudioEngine by lazy {
        AudioEngine(getApplication<Application>().applicationContext).also {
            Log.i(TAG, "Audio Engine initialized")
        }
    }
    val audioEngine: AudioEngine get() = _audioEngine

    private val _midiManager: MidiManager by lazy {
        MidiManager(getApplication<Application>().applicationContext).also {
            Log.i(TAG, "MIDI Manager initialized")
        }
    }
    val midiManager: MidiManager get() = _midiManager

    private val _bioReactiveEngine: BioReactiveEngine by lazy {
        BioReactiveEngine(getApplication<Application>().applicationContext).also {
            Log.i(TAG, "Bio-Reactive Engine initialized")
        }
    }
    val bioReactiveEngine: BioReactiveEngine get() = _bioReactiveEngine

    // ================================================================
    // Initialization State
    // ================================================================
    private val _isInitialized = MutableStateFlow(false)
    val isInitialized: StateFlow<Boolean> = _isInitialized.asStateFlow()

    // ================================================================
    // Bio-Reactive State
    // ================================================================
    private val _heartRate = MutableStateFlow(70f)
    val heartRate: StateFlow<Float> = _heartRate.asStateFlow()

    private val _hrv = MutableStateFlow(50f)
    val hrv: StateFlow<Float> = _hrv.asStateFlow()

    private val _coherence = MutableStateFlow(0.5f)
    val coherence: StateFlow<Float> = _coherence.asStateFlow()

    private val _respiratoryRate = MutableStateFlow(12f)
    val respiratoryRate: StateFlow<Float> = _respiratoryRate.asStateFlow()

    // ================================================================
    // Audio Transport State
    // ================================================================
    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _masterVolume = MutableStateFlow(0.75f)
    val masterVolume: StateFlow<Float> = _masterVolume.asStateFlow()

    // ================================================================
    // Binaural Beats State
    // ================================================================
    private val _binauralBeatsEnabled = MutableStateFlow(false)
    val binauralBeatsEnabled: StateFlow<Boolean> = _binauralBeatsEnabled.asStateFlow()

    private val _selectedBrainwaveState = MutableStateFlow(BrainwaveState.ALPHA)
    val selectedBrainwaveState: StateFlow<BrainwaveState> = _selectedBrainwaveState.asStateFlow()

    private val _binauralVolume = MutableStateFlow(0.5f)
    val binauralVolume: StateFlow<Float> = _binauralVolume.asStateFlow()

    private val _carrierFrequency = MutableStateFlow(250f)
    val carrierFrequency: StateFlow<Float> = _carrierFrequency.asStateFlow()

    private val _beatFrequency = MutableStateFlow(10f)
    val beatFrequency: StateFlow<Float> = _beatFrequency.asStateFlow()

    // ================================================================
    // Synth Parameter State (for visualizer)
    // ================================================================
    private val _filterCutoff = MutableStateFlow(5000f)
    val filterCutoff: StateFlow<Float> = _filterCutoff.asStateFlow()

    private val _filterResonance = MutableStateFlow(0.3f)
    val filterResonance: StateFlow<Float> = _filterResonance.asStateFlow()

    private val _reverbMix = MutableStateFlow(0.2f)
    val reverbMix: StateFlow<Float> = _reverbMix.asStateFlow()

    // ================================================================
    // Initialization
    // ================================================================
    init {
        initializeSystems()
    }

    private fun initializeSystems() {
        viewModelScope.launch {
            try {
                // Connect MIDI to audio engine
                _midiManager.setNoteCallback { note, velocity, isNoteOn ->
                    if (isNoteOn) {
                        _audioEngine.noteOn(note, velocity)
                    } else {
                        _audioEngine.noteOff(note)
                    }
                }

                // Connect bio data to audio modulation
                _bioReactiveEngine.setHeartRateCallback { hr, hrv, coherence ->
                    _heartRate.value = hr
                    _hrv.value = hrv
                    _coherence.value = coherence
                    _audioEngine.updateBioData(hr, hrv, coherence)
                }

                _isInitialized.value = true
                Log.i(TAG, "All systems initialized and connected")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize systems: ${e.message}")
            }
        }
    }

    // ================================================================
    // Audio Transport Controls
    // ================================================================
    fun startAudio() {
        viewModelScope.launch {
            try {
                _audioEngine.start()
                _isPlaying.value = true
                Log.i(TAG, "Audio started")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start audio: ${e.message}")
            }
        }
    }

    fun stopAudio() {
        viewModelScope.launch {
            try {
                _audioEngine.stop()
                _isPlaying.value = false
                Log.i(TAG, "Audio stopped")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop audio: ${e.message}")
            }
        }
    }

    fun togglePlayback() {
        if (_isPlaying.value) stopAudio() else startAudio()
    }

    fun setMasterVolume(volume: Float) {
        _masterVolume.value = volume.coerceIn(0f, 1f)
        _audioEngine.setParameter(AudioEngine.Params.AMP_SUSTAIN, volume)
    }

    // ================================================================
    // Note Controls
    // ================================================================
    fun noteOn(note: Int, velocity: Int) {
        _audioEngine.noteOn(note, velocity)
    }

    fun noteOff(note: Int) {
        _audioEngine.noteOff(note)
    }

    // ================================================================
    // Synth Parameter Controls
    // ================================================================
    fun setFilterCutoff(cutoff: Float) {
        _filterCutoff.value = cutoff
        _audioEngine.setParameter(AudioEngine.Params.FILTER_CUTOFF, cutoff)
    }

    fun setFilterResonance(resonance: Float) {
        _filterResonance.value = resonance
        _audioEngine.setParameter(AudioEngine.Params.FILTER_RESONANCE, resonance)
    }

    fun setReverbMix(mix: Float) {
        _reverbMix.value = mix
    }

    // ================================================================
    // Binaural Beats Controls
    // ================================================================
    fun toggleBinauralBeats() {
        _binauralBeatsEnabled.value = !_binauralBeatsEnabled.value
        if (_binauralBeatsEnabled.value) {
            applyBrainwaveState(_selectedBrainwaveState.value)
            Log.i(TAG, "Binaural beats enabled: ${_selectedBrainwaveState.value.displayName}")
        } else {
            Log.i(TAG, "Binaural beats disabled")
        }
    }

    fun selectBrainwaveState(state: BrainwaveState) {
        _selectedBrainwaveState.value = state
        _carrierFrequency.value = state.carrierHz
        _beatFrequency.value = state.binauralBeatHz
        if (_binauralBeatsEnabled.value) {
            applyBrainwaveState(state)
        }
        Log.i(TAG, "Brainwave state selected: ${state.displayName} (${state.binauralBeatHz} Hz)")
    }

    fun setBinauralVolume(volume: Float) {
        _binauralVolume.value = volume.coerceIn(0f, 1f)
    }

    fun setCarrierFrequency(frequency: Float) {
        _carrierFrequency.value = frequency.coerceIn(50f, 800f)
    }

    fun setBeatFrequency(frequency: Float) {
        _beatFrequency.value = frequency.coerceIn(0.5f, 100f)
    }

    private fun applyBrainwaveState(state: BrainwaveState) {
        // Apply binaural beat parameters to audio engine
        // Left ear = carrierHz, Right ear = carrierHz + binauralBeatHz
        _audioEngine.setParameter(AudioEngine.Params.LFO_RATE, state.binauralBeatHz)
        _audioEngine.setParameter(AudioEngine.Params.LFO_DEPTH, _binauralVolume.value)
        Log.i(TAG, "Applied brainwave: carrier=${state.carrierHz}Hz, beat=${state.binauralBeatHz}Hz")
    }

    // ================================================================
    // Cleanup
    // ================================================================
    override fun onCleared() {
        super.onCleared()
        Log.i(TAG, "ViewModel cleared, cleaning up resources")

        // Clear callbacks to prevent memory leaks
        _bioReactiveEngine.clearCallback()

        // Shutdown engines
        _audioEngine.shutdown()
        _midiManager.shutdown()
        _bioReactiveEngine.shutdown()

        Log.i(TAG, "All resources cleaned up")
    }
}
