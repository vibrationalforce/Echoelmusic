/**
 * ╔══════════════════════════════════════════════════════════════════════════════╗
 * ║              ECHOELMUSIC WEB PLATFORM SUPPORT                                ║
 * ║            WebAssembly • WebAudio • WebMIDI • WebBluetooth                   ║
 * ╚══════════════════════════════════════════════════════════════════════════════╝
 *
 * Run Echoelmusic in any modern browser!
 *
 * Supported Browsers:
 * ━━━━━━━━━━━━━━━━━━━
 * • Chrome 89+ (Full support)
 * • Firefox 89+ (Full support)
 * • Safari 15+ (WebAudio, limited MIDI)
 * • Edge 89+ (Full support)
 *
 * APIs Used:
 * ━━━━━━━━━━
 * • WebAssembly - Core DSP processing
 * • WebAudio API - Audio I/O
 * • WebMIDI API - MIDI device access
 * • WebBluetooth API - BLE wearable connection
 * • AudioWorklet - Low-latency processing
 * • SharedArrayBuffer - Thread communication
 *
 * Build: emcc -s WASM=1 -s USE_PTHREADS=1
 */

#pragma once

#ifdef __EMSCRIPTEN__

#include <emscripten.h>
#include <emscripten/bind.h>
#include <emscripten/val.h>
#include "../DSP/EchoelmusicDSP.h"
#include <array>
#include <atomic>

namespace echoelmusic {
namespace web {

//==============================================================================
// WEB AUDIO PROCESSOR
//==============================================================================

class WebAudioProcessor {
public:
    WebAudioProcessor() {
        mDSP.prepare(48000.0, 128);  // Web Audio default
    }

    void prepare(double sampleRate, int blockSize) {
        mSampleRate = sampleRate;
        mBlockSize = blockSize;
        mDSP.prepare(sampleRate, blockSize);
    }

    // Called from AudioWorklet
    void process(float* inputL, float* inputR, float* outputL, float* outputR, int numSamples) {
        float* outputs[2] = {outputL, outputR};
        mDSP.processBlock(outputs, 2, numSamples);
    }

    // MIDI from WebMIDI
    void noteOn(int note, int velocity) {
        mDSP.noteOn(note, velocity / 127.0f);
    }

    void noteOff(int note) {
        mDSP.noteOff(note);
    }

    // Parameter control
    void setParameter(int id, float value) {
        switch (id) {
            case 0: mDSP.setFilterCutoff(value); break;
            case 1: mDSP.setFilterResonance(value); break;
            case 2: mDSP.setReverbMix(value); break;
            case 3: mDSP.setMasterGain(value); break;
            default: break;
        }
    }

    // Bio-reactive from WebBluetooth
    void updateBioData(float hrv, float coherence, float heartRate) {
        echoelmusic::BioState state;
        state.hrv = hrv;
        state.coherence = coherence;
        state.heartRate = heartRate;
        mDSP.updateBioState(state);
    }

private:
    echoelmusic::EchoelmusicDSP mDSP;
    double mSampleRate = 48000.0;
    int mBlockSize = 128;
};

//==============================================================================
// EMSCRIPTEN BINDINGS
//==============================================================================

EMSCRIPTEN_BINDINGS(echoelmusic_web) {
    emscripten::class_<WebAudioProcessor>("WebAudioProcessor")
        .constructor<>()
        .function("prepare", &WebAudioProcessor::prepare)
        .function("noteOn", &WebAudioProcessor::noteOn)
        .function("noteOff", &WebAudioProcessor::noteOff)
        .function("setParameter", &WebAudioProcessor::setParameter)
        .function("updateBioData", &WebAudioProcessor::updateBioData);
}

//==============================================================================
// JAVASCRIPT INTERFACE
//==============================================================================

// Export C functions for direct JS calls
extern "C" {

EMSCRIPTEN_KEEPALIVE
void* createProcessor() {
    return new WebAudioProcessor();
}

EMSCRIPTEN_KEEPALIVE
void destroyProcessor(void* ptr) {
    delete static_cast<WebAudioProcessor*>(ptr);
}

EMSCRIPTEN_KEEPALIVE
void prepareProcessor(void* ptr, double sampleRate, int blockSize) {
    static_cast<WebAudioProcessor*>(ptr)->prepare(sampleRate, blockSize);
}

EMSCRIPTEN_KEEPALIVE
void processAudio(void* ptr, float* inL, float* inR, float* outL, float* outR, int samples) {
    static_cast<WebAudioProcessor*>(ptr)->process(inL, inR, outL, outR, samples);
}

EMSCRIPTEN_KEEPALIVE
void sendNoteOn(void* ptr, int note, int velocity) {
    static_cast<WebAudioProcessor*>(ptr)->noteOn(note, velocity);
}

EMSCRIPTEN_KEEPALIVE
void sendNoteOff(void* ptr, int note) {
    static_cast<WebAudioProcessor*>(ptr)->noteOff(note);
}

EMSCRIPTEN_KEEPALIVE
void setParam(void* ptr, int id, float value) {
    static_cast<WebAudioProcessor*>(ptr)->setParameter(id, value);
}

EMSCRIPTEN_KEEPALIVE
void setBioData(void* ptr, float hrv, float coherence, float hr) {
    static_cast<WebAudioProcessor*>(ptr)->updateBioData(hrv, coherence, hr);
}

} // extern "C"

} // namespace web
} // namespace echoelmusic

#endif // __EMSCRIPTEN__

//==============================================================================
// AUDIOWORKLET JAVASCRIPT (Embedded as string for export)
//==============================================================================

#ifdef ECHOEL_EXPORT_JS

constexpr const char* AUDIOWORKLET_JS = R"JS(
// Echoelmusic AudioWorklet Processor
class EchoelmusicProcessor extends AudioWorkletProcessor {
    constructor() {
        super();
        this.processor = null;
        this.port.onmessage = this.handleMessage.bind(this);
    }

    handleMessage(event) {
        const { type, data } = event.data;
        switch (type) {
            case 'init':
                // Initialize WASM module
                this.initWasm(data.wasmModule);
                break;
            case 'noteOn':
                if (this.processor) {
                    Module._sendNoteOn(this.processor, data.note, data.velocity);
                }
                break;
            case 'noteOff':
                if (this.processor) {
                    Module._sendNoteOff(this.processor, data.note);
                }
                break;
            case 'param':
                if (this.processor) {
                    Module._setParam(this.processor, data.id, data.value);
                }
                break;
            case 'bio':
                if (this.processor) {
                    Module._setBioData(this.processor, data.hrv, data.coherence, data.hr);
                }
                break;
        }
    }

    async initWasm(wasmModule) {
        // Load WASM module
        Module = await wasmModule;
        this.processor = Module._createProcessor();
        Module._prepareProcessor(this.processor, sampleRate, 128);
        this.port.postMessage({ type: 'ready' });
    }

    process(inputs, outputs, parameters) {
        if (!this.processor) return true;

        const output = outputs[0];
        const blockSize = output[0].length;

        // Get WASM memory pointers
        const outLPtr = Module._malloc(blockSize * 4);
        const outRPtr = Module._malloc(blockSize * 4);

        // Process audio
        Module._processAudio(this.processor, 0, 0, outLPtr, outRPtr, blockSize);

        // Copy to output
        const outL = new Float32Array(Module.HEAPF32.buffer, outLPtr, blockSize);
        const outR = new Float32Array(Module.HEAPF32.buffer, outRPtr, blockSize);

        output[0].set(outL);
        if (output.length > 1) output[1].set(outR);

        // Free memory
        Module._free(outLPtr);
        Module._free(outRPtr);

        return true;
    }
}

registerProcessor('echoelmusic-processor', EchoelmusicProcessor);
)JS";

constexpr const char* WEB_MIDI_JS = R"JS(
// Echoelmusic WebMIDI Handler
class EchoelmusicMIDI {
    constructor(audioWorkletNode) {
        this.node = audioWorkletNode;
        this.inputs = [];
        this.outputs = [];
    }

    async init() {
        if (!navigator.requestMIDIAccess) {
            console.warn('WebMIDI not supported');
            return false;
        }

        try {
            const access = await navigator.requestMIDIAccess({ sysex: false });
            this.handleMIDIAccess(access);
            return true;
        } catch (e) {
            console.error('MIDI access denied:', e);
            return false;
        }
    }

    handleMIDIAccess(access) {
        this.inputs = Array.from(access.inputs.values());
        this.outputs = Array.from(access.outputs.values());

        for (const input of this.inputs) {
            input.onmidimessage = this.handleMIDIMessage.bind(this);
        }

        access.onstatechange = (e) => {
            console.log('MIDI state change:', e.port.name, e.port.state);
        };
    }

    handleMIDIMessage(event) {
        const [status, data1, data2] = event.data;
        const command = status >> 4;
        const channel = status & 0x0F;

        switch (command) {
            case 0x9: // Note On
                if (data2 > 0) {
                    this.node.port.postMessage({ type: 'noteOn', data: { note: data1, velocity: data2 } });
                } else {
                    this.node.port.postMessage({ type: 'noteOff', data: { note: data1 } });
                }
                break;
            case 0x8: // Note Off
                this.node.port.postMessage({ type: 'noteOff', data: { note: data1 } });
                break;
            case 0xB: // Control Change
                this.node.port.postMessage({ type: 'param', data: { id: data1, value: data2 / 127 } });
                break;
        }
    }
}
)JS";

constexpr const char* WEB_BLUETOOTH_JS = R"JS(
// Echoelmusic WebBluetooth Heart Rate Handler
class EchoelmusicBLE {
    constructor(audioWorkletNode) {
        this.node = audioWorkletNode;
        this.device = null;
        this.hrvHistory = [];
    }

    async connect() {
        if (!navigator.bluetooth) {
            console.warn('WebBluetooth not supported');
            return false;
        }

        try {
            this.device = await navigator.bluetooth.requestDevice({
                filters: [{ services: ['heart_rate'] }],
                optionalServices: ['battery_service']
            });

            const server = await this.device.gatt.connect();
            const service = await server.getPrimaryService('heart_rate');
            const characteristic = await service.getCharacteristic('heart_rate_measurement');

            characteristic.addEventListener('characteristicvaluechanged', this.handleHRData.bind(this));
            await characteristic.startNotifications();

            console.log('Connected to:', this.device.name);
            return true;
        } catch (e) {
            console.error('BLE connection failed:', e);
            return false;
        }
    }

    handleHRData(event) {
        const value = event.target.value;
        const flags = value.getUint8(0);
        const is16bit = (flags & 0x01) !== 0;
        const hasRR = (flags & 0x10) !== 0;

        // Heart rate
        const hr = is16bit ? value.getUint16(1, true) : value.getUint8(1);

        // RR intervals for HRV
        let hrv = 50; // Default
        if (hasRR) {
            const rrOffset = is16bit ? 3 : 2;
            const rr = value.getUint16(rrOffset, true);
            this.hrvHistory.push(rr);
            if (this.hrvHistory.length > 10) this.hrvHistory.shift();
            hrv = this.calculateHRV();
        }

        // Calculate coherence (simplified)
        const coherence = this.calculateCoherence();

        // Send to audio processor
        this.node.port.postMessage({
            type: 'bio',
            data: { hrv, coherence, hr }
        });
    }

    calculateHRV() {
        if (this.hrvHistory.length < 2) return 50;
        let sumSq = 0;
        for (let i = 1; i < this.hrvHistory.length; i++) {
            const diff = this.hrvHistory[i] - this.hrvHistory[i-1];
            sumSq += diff * diff;
        }
        return Math.sqrt(sumSq / (this.hrvHistory.length - 1));
    }

    calculateCoherence() {
        if (this.hrvHistory.length < 5) return 0.5;
        const mean = this.hrvHistory.reduce((a, b) => a + b) / this.hrvHistory.length;
        const variance = this.hrvHistory.reduce((a, b) => a + (b - mean) ** 2, 0) / this.hrvHistory.length;
        const cv = Math.sqrt(variance) / mean;
        return Math.max(0, Math.min(1, 1 - cv));
    }

    disconnect() {
        if (this.device && this.device.gatt.connected) {
            this.device.gatt.disconnect();
        }
    }
}
)JS";

#endif // ECHOEL_EXPORT_JS
