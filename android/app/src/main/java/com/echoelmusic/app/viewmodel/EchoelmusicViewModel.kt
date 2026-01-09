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
 * Echoelmusic ViewModel
 * Proper Android architecture replacing singleton pattern
 *
 * Benefits:
 * - Survives configuration changes (rotation, etc.)
 * - Proper lifecycle management
 * - No memory leaks from Activity/Context references
 * - Scoped coroutines with viewModelScope
 *
 * Nobel Prize Multitrillion Dollar Company Loop - Production Ready
 */
class EchoelmusicViewModel(application: Application) : AndroidViewModel(application) {

    companion object {
        private const val TAG = "EchoelmusicVM"
    }

    // Engines - lazily initialized, lifecycle-aware
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

    // State
    private val _isInitialized = MutableStateFlow(false)
    val isInitialized: StateFlow<Boolean> = _isInitialized.asStateFlow()

    private val _heartRate = MutableStateFlow(70f)
    val heartRate: StateFlow<Float> = _heartRate.asStateFlow()

    private val _hrv = MutableStateFlow(50f)
    val hrv: StateFlow<Float> = _hrv.asStateFlow()

    private val _coherence = MutableStateFlow(0.5f)
    val coherence: StateFlow<Float> = _coherence.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

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

    fun noteOn(note: Int, velocity: Int) {
        _audioEngine.noteOn(note, velocity)
    }

    fun noteOff(note: Int) {
        _audioEngine.noteOff(note)
    }

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
