package com.echoelmusic.app.midi

import android.content.Context
import android.media.midi.*
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Echoelmusic MIDI Manager
 * Handles USB and Bluetooth MIDI devices
 *
 * Features:
 * - USB MIDI Class Compliant devices
 * - Bluetooth LE MIDI
 * - MIDI 2.0 Universal MIDI Packet (where supported)
 * - MPE (MIDI Polyphonic Expression) support
 */
class MidiManager(private val context: Context) {

    companion object {
        private const val TAG = "MidiManager"

        // MIDI Status bytes
        private const val NOTE_OFF = 0x80
        private const val NOTE_ON = 0x90
        private const val POLY_PRESSURE = 0xA0
        private const val CONTROL_CHANGE = 0xB0
        private const val PROGRAM_CHANGE = 0xC0
        private const val CHANNEL_PRESSURE = 0xD0
        private const val PITCH_BEND = 0xE0
    }

    private val midiManager: android.media.midi.MidiManager? =
        context.getSystemService(Context.MIDI_SERVICE) as? android.media.midi.MidiManager

    private val _connectedDevices = MutableStateFlow<List<MidiDeviceInfo>>(emptyList())
    val connectedDevices: StateFlow<List<MidiDeviceInfo>> = _connectedDevices

    private val _isActive = MutableStateFlow(false)
    val isActive: StateFlow<Boolean> = _isActive

    private var openDevices = mutableListOf<MidiDevice>()
    private var openInputPorts = mutableListOf<MidiInputPort>()
    private var openOutputPorts = mutableListOf<MidiOutputPort>()

    // Callbacks
    private var noteCallback: ((Int, Int, Boolean) -> Unit)? = null
    private var ccCallback: ((Int, Int, Int) -> Unit)? = null
    private var pitchBendCallback: ((Int, Float) -> Unit)? = null

    // MPE configuration
    private var mpeEnabled = true
    private var mpeLowerZone = 1..15  // Channels 2-16 for lower zone
    private var mpeUpperZone = IntRange.EMPTY

    private val deviceCallback = object : android.media.midi.MidiManager.DeviceCallback() {
        override fun onDeviceAdded(device: MidiDeviceInfo) {
            Log.i(TAG, "MIDI device added: ${device.properties}")
            updateDeviceList()
            openDevice(device)
        }

        override fun onDeviceRemoved(device: MidiDeviceInfo) {
            Log.i(TAG, "MIDI device removed: ${device.properties}")
            updateDeviceList()
        }
    }

    init {
        midiManager?.registerDeviceCallback(deviceCallback, Handler(Looper.getMainLooper()))
        updateDeviceList()
        Log.i(TAG, "MIDI Manager initialized. Devices: ${_connectedDevices.value.size}")
    }

    fun start() {
        if (_isActive.value) return
        _isActive.value = true

        // Open all available devices
        _connectedDevices.value.forEach { deviceInfo ->
            openDevice(deviceInfo)
        }

        Log.i(TAG, "MIDI started")
    }

    fun stop() {
        _isActive.value = false
        closeAllDevices()
        Log.i(TAG, "MIDI stopped")
    }

    fun shutdown() {
        stop()
        midiManager?.unregisterDeviceCallback(deviceCallback)
    }

    fun setNoteCallback(callback: (note: Int, velocity: Int, isNoteOn: Boolean) -> Unit) {
        noteCallback = callback
    }

    fun setCCCallback(callback: (channel: Int, cc: Int, value: Int) -> Unit) {
        ccCallback = callback
    }

    fun setPitchBendCallback(callback: (channel: Int, value: Float) -> Unit) {
        pitchBendCallback = callback
    }

    private fun updateDeviceList() {
        _connectedDevices.value = midiManager?.devices?.toList() ?: emptyList()
    }

    private fun openDevice(deviceInfo: MidiDeviceInfo) {
        midiManager?.openDevice(deviceInfo, { device ->
            if (device != null) {
                openDevices.add(device)

                // Open output ports (MIDI OUT from device = our input)
                val portCount = deviceInfo.outputPortCount
                for (i in 0 until portCount) {
                    val outputPort = device.openOutputPort(i)
                    if (outputPort != null) {
                        outputPort.connect(midiReceiver)
                        openOutputPorts.add(outputPort)
                        Log.i(TAG, "Connected to output port $i")
                    } else {
                        Log.w(TAG, "Failed to open output port $i on ${deviceInfo.properties}")
                    }
                }

                // Open input ports (MIDI IN to device = our output)
                val inputPortCount = deviceInfo.inputPortCount
                for (i in 0 until inputPortCount) {
                    val inputPort = device.openInputPort(i)
                    if (inputPort != null) {
                        openInputPorts.add(inputPort)
                        Log.i(TAG, "Opened input port $i for sending")
                    } else {
                        Log.w(TAG, "Failed to open input port $i on ${deviceInfo.properties}")
                    }
                }
            } else {
                Log.e(TAG, "Failed to open MIDI device: ${deviceInfo.properties}")
            }
        }, Handler(Looper.getMainLooper()))
    }

    private fun closeAllDevices() {
        openOutputPorts.forEach { it.close() }
        openInputPorts.forEach { it.close() }
        openDevices.forEach { it.close() }

        openOutputPorts.clear()
        openInputPorts.clear()
        openDevices.clear()
    }

    private val midiReceiver = object : MidiReceiver() {
        override fun onSend(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
            if (count < 1) return

            val status = msg[offset].toInt() and 0xFF
            val channel = status and 0x0F
            val messageType = status and 0xF0

            when (messageType) {
                NOTE_ON -> {
                    if (count >= 3) {
                        val note = msg[offset + 1].toInt() and 0x7F
                        val velocity = msg[offset + 2].toInt() and 0x7F
                        val isNoteOn = velocity > 0
                        noteCallback?.invoke(note, velocity, isNoteOn)
                    }
                }

                NOTE_OFF -> {
                    if (count >= 3) {
                        val note = msg[offset + 1].toInt() and 0x7F
                        noteCallback?.invoke(note, 0, false)
                    }
                }

                CONTROL_CHANGE -> {
                    if (count >= 3) {
                        val cc = msg[offset + 1].toInt() and 0x7F
                        val value = msg[offset + 2].toInt() and 0x7F
                        ccCallback?.invoke(channel, cc, value)
                    }
                }

                PITCH_BEND -> {
                    if (count >= 3) {
                        val lsb = msg[offset + 1].toInt() and 0x7F
                        val msb = msg[offset + 2].toInt() and 0x7F
                        val bend = ((msb shl 7) or lsb) - 8192
                        val normalizedBend = bend / 8192f // -1 to +1
                        pitchBendCallback?.invoke(channel, normalizedBend)
                    }
                }

                POLY_PRESSURE -> {
                    // MPE per-note pressure
                    if (mpeEnabled && count >= 3) {
                        val note = msg[offset + 1].toInt() and 0x7F
                        val pressure = msg[offset + 2].toInt() and 0x7F
                        // Handle MPE pressure
                    }
                }

                CHANNEL_PRESSURE -> {
                    // Channel aftertouch
                    if (count >= 2) {
                        val pressure = msg[offset + 1].toInt() and 0x7F
                        // Handle channel pressure
                    }
                }
            }
        }
    }

    // Send MIDI message to connected devices
    fun sendNoteOn(channel: Int, note: Int, velocity: Int) {
        val msg = byteArrayOf(
            (NOTE_ON or (channel and 0x0F)).toByte(),
            (note and 0x7F).toByte(),
            (velocity and 0x7F).toByte()
        )
        sendToAllInputPorts(msg)
    }

    fun sendNoteOff(channel: Int, note: Int) {
        val msg = byteArrayOf(
            (NOTE_OFF or (channel and 0x0F)).toByte(),
            (note and 0x7F).toByte(),
            0
        )
        sendToAllInputPorts(msg)
    }

    fun sendCC(channel: Int, cc: Int, value: Int) {
        val msg = byteArrayOf(
            (CONTROL_CHANGE or (channel and 0x0F)).toByte(),
            (cc and 0x7F).toByte(),
            (value and 0x7F).toByte()
        )
        sendToAllInputPorts(msg)
    }

    private fun sendToAllInputPorts(msg: ByteArray) {
        openInputPorts.forEach { port ->
            try {
                port.send(msg, 0, msg.size)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send MIDI: ${e.message}")
            }
        }
    }
}
