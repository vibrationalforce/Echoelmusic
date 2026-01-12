package com.echoelmusic.app.unified

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.echoelmusic.app.audio.AudioEngine
import com.echoelmusic.app.audio.ImmersiveIsochronicEngine
import com.echoelmusic.app.bio.BioReactiveEngine
import com.echoelmusic.app.midi.MidiManager
import com.echoelmusic.app.hardware.HardwareEcosystem
import com.echoelmusic.app.hardware.ConnectedDevice
import com.echoelmusic.app.hardware.DeviceType
import com.echoelmusic.app.hardware.DevicePlatform
import com.echoelmusic.app.hardware.ConnectionType
import com.echoelmusic.app.hardware.DeviceCapability
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

/**
 * Unified Control Hub for Android
 * Central orchestrator for all input modalities in Echoelmusic
 *
 * Manages the fusion of multiple input sources and routes control signals
 * to audio, visual, and light output systems.
 *
 * **Input Priority:** Touch > Gesture > Face > Bio > MIDI
 *
 * **Control Loop:** 60 Hz (16.67ms update interval)
 *
 * Port of iOS UnifiedControlHub with Android-specific implementations:
 * - CameraX for face tracking (instead of ARKit)
 * - MediaPipe for gesture recognition
 * - Health Connect for biometric data
 * - Android MIDI API for MIDI 2.0/MPE
 */
class UnifiedControlHub(
    private val context: Context,
    private val audioEngine: AudioEngine? = null
) {
    companion object {
        private const val TAG = "UnifiedControlHub"
        private const val TARGET_FREQUENCY_HZ = 60.0
        private const val CONTROL_LOOP_INTERVAL_MS = (1000.0 / TARGET_FREQUENCY_HZ).toLong()
    }

    // MARK: - Published State

    private val _activeInputMode = MutableStateFlow(InputMode.AUTOMATIC)
    val activeInputMode: StateFlow<InputMode> = _activeInputMode

    private val _conflictResolved = MutableStateFlow(true)
    val conflictResolved: StateFlow<Boolean> = _conflictResolved

    private val _controlLoopFrequency = MutableStateFlow(0.0)
    val controlLoopFrequency: StateFlow<Double> = _controlLoopFrequency

    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning

    // MARK: - Bio State

    private val _currentHeartRate = MutableStateFlow(0f)
    val currentHeartRate: StateFlow<Float> = _currentHeartRate

    private val _currentHRV = MutableStateFlow(0f)
    val currentHRV: StateFlow<Float> = _currentHRV

    private val _currentCoherence = MutableStateFlow(0f)
    val currentCoherence: StateFlow<Float> = _currentCoherence

    private val _currentBreathingRate = MutableStateFlow(6.0f)
    val currentBreathingRate: StateFlow<Float> = _currentBreathingRate

    // MARK: - Dependencies

    private var isochronicEngine: ImmersiveIsochronicEngine? = null
    private var bioReactiveEngine: BioReactiveEngine? = null
    private var midiManager: MidiManager? = null

    // MARK: - Hardware Ecosystem Integration

    private val _connectedHardware = MutableStateFlow<List<ConnectedDevice>>(emptyList())
    val connectedHardware: StateFlow<List<ConnectedDevice>> = _connectedHardware

    init {
        // Collect hardware ecosystem state
        scope.launch {
            HardwareEcosystem.connectedDevices.collect { devices ->
                _connectedHardware.value = devices
                Log.d(TAG, "Hardware devices updated: ${devices.size} connected")
            }
        }
    }

    // MARK: - Control Loop

    private var controlLoopJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private var lastUpdateTime: Long = System.nanoTime()

    // MARK: - Input Mode

    enum class InputMode {
        AUTOMATIC,      // Priority-based selection
        TOUCH_ONLY,     // Only touch input
        GESTURE_ONLY,   // Only gesture recognition
        FACE_ONLY,      // Only face tracking
        BIO_ONLY,       // Only biometric data
        MIDI_ONLY,      // Only MIDI input
        MANUAL          // User-specified mode
    }

    // MARK: - Control Parameters

    data class ControlParameters(
        var filterCutoff: Float = 1000f,
        var filterResonance: Float = 0.5f,
        var reverbWetness: Float = 0.3f,
        var reverbSize: Float = 0.5f,
        var delayTime: Float = 0.25f,
        var delayFeedback: Float = 0.3f,
        var masterVolume: Float = 0.8f,
        var tempo: Float = 120f,
        var spatialX: Float = 0f,
        var spatialY: Float = 0f,
        var spatialZ: Float = 0f,
        var entrainmentPreset: ImmersiveIsochronicEngine.EntrainmentPreset =
            ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS
    )

    private val currentParameters = ControlParameters()

    // MARK: - Bio Parameter Mapping

    data class BioMapping(
        val coherenceToFilter: Boolean = true,
        val hrvToReverb: Boolean = true,
        val heartRateToTempo: Boolean = true,
        val breathingToEntrainment: Boolean = true
    )

    private var bioMapping = BioMapping()

    // MARK: - Initialization

    init {
        Log.i(TAG, "UnifiedControlHub initialized")
    }

    // MARK: - Setup Methods

    fun setIsochronicEngine(engine: ImmersiveIsochronicEngine) {
        this.isochronicEngine = engine
        Log.i(TAG, "Isochronic engine connected")
    }

    fun setBioReactiveEngine(engine: BioReactiveEngine) {
        this.bioReactiveEngine = engine
        setupBioFeedback()
        Log.i(TAG, "Bio-reactive engine connected")
    }

    fun setMidiManager(manager: MidiManager) {
        this.midiManager = manager
        setupMidiInput()
        Log.i(TAG, "MIDI manager connected")
    }

    // MARK: - Hardware Methods

    fun getAudioInterfaces(): List<ConnectedDevice> {
        return _connectedHardware.value.filter {
            it.capabilities.contains(DeviceCapability.AUDIO_INPUT) ||
            it.capabilities.contains(DeviceCapability.AUDIO_OUTPUT)
        }
    }

    fun getMidiControllers(): List<ConnectedDevice> {
        return _connectedHardware.value.filter {
            it.capabilities.contains(DeviceCapability.MIDI_IN) ||
            it.capabilities.contains(DeviceCapability.MIDI_OUT)
        }
    }

    fun getWearables(): List<ConnectedDevice> {
        return _connectedHardware.value.filter {
            it.capabilities.contains(DeviceCapability.HEART_RATE) ||
            it.capabilities.contains(DeviceCapability.HRV)
        }
    }

    fun startHardwareScanning() {
        HardwareEcosystem.startScanning()
        Log.i(TAG, "Started hardware device scanning")
    }

    fun stopHardwareScanning() {
        HardwareEcosystem.stopScanning()
        Log.i(TAG, "Stopped hardware device scanning")
    }

    // MARK: - Control Loop

    fun start() {
        if (_isRunning.value) return

        _isRunning.value = true
        lastUpdateTime = System.nanoTime()

        controlLoopJob = scope.launch {
            while (isActive && _isRunning.value) {
                val startTime = System.nanoTime()

                // Execute control loop tick
                controlLoopTick()

                // Calculate actual frequency
                val elapsed = (System.nanoTime() - lastUpdateTime) / 1_000_000_000.0
                if (elapsed > 0) {
                    _controlLoopFrequency.value = 1.0 / elapsed
                }
                lastUpdateTime = System.nanoTime()

                // Wait for next frame (target 60 Hz)
                val processingTime = (System.nanoTime() - startTime) / 1_000_000
                val waitTime = CONTROL_LOOP_INTERVAL_MS - processingTime
                if (waitTime > 0) {
                    delay(waitTime)
                }
            }
        }

        Log.i(TAG, "Control loop started at $TARGET_FREQUENCY_HZ Hz")
    }

    fun stop() {
        if (!_isRunning.value) return

        controlLoopJob?.cancel()
        controlLoopJob = null
        _isRunning.value = false
        _controlLoopFrequency.value = 0.0

        Log.i(TAG, "Control loop stopped")
    }

    private fun controlLoopTick() {
        // Priority: Touch > Gesture > Face > Bio > MIDI
        when (_activeInputMode.value) {
            InputMode.AUTOMATIC -> {
                processAutomaticMode()
            }
            InputMode.BIO_ONLY -> {
                processBioInput()
            }
            InputMode.MIDI_ONLY -> {
                processMidiInput()
            }
            else -> {
                // Process based on specific mode
                processAutomaticMode()
            }
        }

        // Apply parameters to audio engine
        applyParametersToAudio()
    }

    private fun processAutomaticMode() {
        // Process all inputs with priority resolution
        processBioInput()
        processMidiInput()
        resolveConflicts()
    }

    // MARK: - Bio Input Processing

    private fun setupBioFeedback() {
        bioReactiveEngine?.let { engine ->
            scope.launch {
                // Collect heart rate changes
                engine.heartRate.collect { hr ->
                    _currentHeartRate.value = hr
                    if (bioMapping.heartRateToTempo) {
                        // Map HR to tempo: 60-180 BPM → 60-180 BPM
                        currentParameters.tempo = hr.toFloat().coerceIn(60f, 180f)
                    }
                }
            }

            scope.launch {
                // Collect HRV changes
                engine.hrv.collect { hrv ->
                    _currentHRV.value = hrv
                    if (bioMapping.hrvToReverb) {
                        // Higher HRV → more reverb (relaxed state)
                        val normalized = (hrv / 100f).coerceIn(0f, 1f)
                        currentParameters.reverbWetness = normalized * 0.6f
                    }
                }
            }

            scope.launch {
                // Collect coherence changes
                engine.coherence.collect { coherence ->
                    _currentCoherence.value = coherence
                    if (bioMapping.coherenceToFilter) {
                        // Higher coherence → higher filter cutoff (brighter sound)
                        // Coherence is 0-1, not 0-100
                        currentParameters.filterCutoff = 500f + coherence * 4500f
                    }

                    // Also modulate isochronic engine (coherence is 0-1, convert to 0-100)
                    isochronicEngine?.modulateFromCoherence((coherence * 100f).toDouble())
                }
            }

            scope.launch {
                // Collect breathing rate
                engine.breathingRate.collect { rate ->
                    _currentBreathingRate.value = rate
                    if (bioMapping.breathingToEntrainment) {
                        isochronicEngine?.let { iso ->
                            if (iso.breathSyncEnabled.value) {
                                iso.updateBreathingRate(rate)
                            }
                        }
                    }
                }
            }
        }
    }

    private fun processBioInput() {
        // Bio processing is handled via Flow collection
        // Additional per-frame processing can go here

        // Modulate heart rate to isochronic pulse softness
        isochronicEngine?.modulateFromHeartRate(_currentHeartRate.value.toDouble())
    }

    // MARK: - MIDI Input Processing

    private fun setupMidiInput() {
        midiManager?.let { midi ->
            scope.launch {
                midi.noteEvents.collect { event ->
                    processMidiNote(event)
                }
            }

            scope.launch {
                midi.controlChangeEvents.collect { event ->
                    processMidiCC(event)
                }
            }
        }
    }

    private fun processMidiInput() {
        // Per-frame MIDI processing (beyond event-driven)
    }

    private fun processMidiNote(event: MidiManager.NoteEvent) {
        // Map MIDI notes to audio parameters
        when {
            event.isNoteOn -> {
                audioEngine?.noteOn(event.note, event.velocity)
            }
            else -> {
                audioEngine?.noteOff(event.note)
            }
        }
    }

    private fun processMidiCC(event: MidiManager.ControlChangeEvent) {
        // Map MIDI CC to parameters
        when (event.controller) {
            1 -> { // Modulation wheel → Filter cutoff
                currentParameters.filterCutoff = 200f + (event.value / 127f) * 4800f
            }
            7 -> { // Volume
                currentParameters.masterVolume = event.value / 127f
            }
            10 -> { // Pan → Spatial X
                currentParameters.spatialX = (event.value / 63.5f) - 1f
            }
            74 -> { // Filter cutoff
                currentParameters.filterCutoff = 200f + (event.value / 127f) * 4800f
            }
            71 -> { // Resonance
                currentParameters.filterResonance = event.value / 127f
            }
            91 -> { // Reverb
                currentParameters.reverbWetness = event.value / 127f
            }
        }
    }

    // MARK: - Conflict Resolution

    private fun resolveConflicts() {
        // Implement priority-based conflict resolution
        // Touch > Gesture > Face > Bio > MIDI

        // For now, all inputs are blended
        _conflictResolved.value = true
    }

    // MARK: - Apply Parameters

    private fun applyParametersToAudio() {
        audioEngine?.apply {
            setFilterCutoff(currentParameters.filterCutoff)
            setFilterResonance(currentParameters.filterResonance)
            setReverbWetness(currentParameters.reverbWetness)
            setMasterVolume(currentParameters.masterVolume)
            setTempo(currentParameters.tempo)
        }
    }

    // MARK: - Configuration

    fun setInputMode(mode: InputMode) {
        _activeInputMode.value = mode
        Log.i(TAG, "Input mode changed to: $mode")
    }

    fun setBioMapping(mapping: BioMapping) {
        this.bioMapping = mapping
        Log.i(TAG, "Bio mapping updated")
    }

    fun enableBreathSync(enabled: Boolean) {
        if (enabled) {
            isochronicEngine?.enableBreathSync(_currentBreathingRate.value)
        } else {
            isochronicEngine?.disableBreathSync()
        }
    }

    // MARK: - Quick Actions

    fun setEntrainmentPreset(preset: ImmersiveIsochronicEngine.EntrainmentPreset) {
        isochronicEngine?.configure(preset)
        currentParameters.entrainmentPreset = preset
        Log.i(TAG, "Entrainment preset: ${preset.displayName}")
    }

    fun setSoundscape(soundscape: ImmersiveIsochronicEngine.Soundscape) {
        isochronicEngine?.transitionTo(soundscape)
        Log.i(TAG, "Soundscape: ${soundscape.displayName}")
    }

    // MARK: - State Getters

    fun getCurrentParameters(): ControlParameters = currentParameters.copy()

    fun getSessionStats(): ImmersiveIsochronicEngine.SessionStatistics? {
        return isochronicEngine?.sessionStats?.value
    }

    // MARK: - Cleanup

    fun shutdown() {
        stop()
        scope.cancel()
        Log.i(TAG, "UnifiedControlHub shutdown")
    }
}
