package com.echoelmusic.app.midi

import android.media.midi.MidiDeviceService
import android.media.midi.MidiReceiver

/**
 * MIDI Device Service for external MIDI input
 */
class EchoelmusicMidiService : MidiDeviceService() {

    private val receivers = mutableListOf<MidiReceiver>()

    override fun onGetInputPortReceivers(): Array<MidiReceiver> {
        return arrayOf(InputReceiver())
    }

    inner class InputReceiver : MidiReceiver() {
        override fun onSend(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
            // Forward MIDI to audio engine
            // This is handled by MidiManager in the main app
        }
    }
}
