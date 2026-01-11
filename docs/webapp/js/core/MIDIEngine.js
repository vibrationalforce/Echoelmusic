/**
 * Echoelmusic WebApp - MIDI Engine
 * Web MIDI API with MIDI 2.0/MPE support
 */

class MIDIEngine {
    constructor() {
        this.midiAccess = null;
        this.inputs = new Map();
        this.outputs = new Map();
        this.listeners = [];
        this.isInitialized = false;

        // MPE state per channel
        this.mpeState = new Map();
        this.mpeZone = { lower: true, masterChannel: 0, memberChannels: 15 };

        // CC mappings
        this.ccMappings = new Map();
        this.setupDefaultMappings();

        // Learning mode
        this.isLearning = false;
        this.learningTarget = null;
    }

    async init() {
        if (!navigator.requestMIDIAccess) {
            console.warn('[MIDIEngine] Web MIDI API not supported');
            return false;
        }

        try {
            this.midiAccess = await navigator.requestMIDIAccess({ sysex: true });

            // Setup inputs
            this.midiAccess.inputs.forEach((input, id) => {
                this.connectInput(input, id);
            });

            // Setup outputs
            this.midiAccess.outputs.forEach((output, id) => {
                this.outputs.set(id, output);
            });

            // Listen for device changes
            this.midiAccess.onstatechange = (e) => this.handleStateChange(e);

            this.isInitialized = true;
            console.log('[MIDIEngine] Initialized with', this.inputs.size, 'inputs,', this.outputs.size, 'outputs');
            return true;

        } catch (error) {
            console.error('[MIDIEngine] Init error:', error);
            return false;
        }
    }

    connectInput(input, id) {
        this.inputs.set(id, input);
        input.onmidimessage = (msg) => this.handleMIDIMessage(msg, id);
        console.log('[MIDIEngine] Connected input:', input.name);
    }

    handleStateChange(event) {
        const port = event.port;

        if (port.type === 'input') {
            if (port.state === 'connected') {
                this.connectInput(port, port.id);
            } else {
                this.inputs.delete(port.id);
            }
        } else if (port.type === 'output') {
            if (port.state === 'connected') {
                this.outputs.set(port.id, port);
            } else {
                this.outputs.delete(port.id);
            }
        }

        this.notifyListeners({
            type: 'deviceChange',
            port: port.name,
            state: port.state
        });
    }

    handleMIDIMessage(event, inputId) {
        const [status, data1, data2] = event.data;
        const channel = status & 0x0F;
        const messageType = status & 0xF0;

        let midiEvent = {
            type: 'unknown',
            channel,
            timestamp: event.timeStamp,
            inputId,
            raw: event.data
        };

        switch (messageType) {
            case 0x90: // Note On
                if (data2 > 0) {
                    midiEvent.type = 'noteOn';
                    midiEvent.note = data1;
                    midiEvent.velocity = data2 / 127;
                    midiEvent.frequency = this.noteToFrequency(data1);

                    // MPE per-note state
                    if (this.isMPEChannel(channel)) {
                        const mpeData = this.mpeState.get(channel) || {};
                        midiEvent.mpe = {
                            pitchBend: mpeData.pitchBend || 0,
                            pressure: mpeData.pressure || 0,
                            slide: mpeData.slide || 0
                        };
                    }
                } else {
                    midiEvent.type = 'noteOff';
                    midiEvent.note = data1;
                    midiEvent.velocity = 0;
                }
                break;

            case 0x80: // Note Off
                midiEvent.type = 'noteOff';
                midiEvent.note = data1;
                midiEvent.velocity = data2 / 127;
                break;

            case 0xB0: // Control Change
                midiEvent.type = 'cc';
                midiEvent.controller = data1;
                midiEvent.value = data2 / 127;
                midiEvent.rawValue = data2;

                // Handle MPE slide (CC74)
                if (data1 === 74 && this.isMPEChannel(channel)) {
                    const mpeData = this.mpeState.get(channel) || {};
                    mpeData.slide = data2 / 127;
                    this.mpeState.set(channel, mpeData);
                }

                // Apply CC mappings
                if (this.ccMappings.has(data1)) {
                    midiEvent.mapping = this.ccMappings.get(data1);
                }

                // Learning mode
                if (this.isLearning && this.learningTarget) {
                    this.ccMappings.set(data1, this.learningTarget);
                    this.isLearning = false;
                    midiEvent.learned = { cc: data1, target: this.learningTarget };
                }
                break;

            case 0xE0: // Pitch Bend
                midiEvent.type = 'pitchBend';
                const bendValue = (data2 << 7) | data1;
                midiEvent.value = (bendValue - 8192) / 8192; // -1 to 1
                midiEvent.rawValue = bendValue;

                // MPE per-note pitch bend
                if (this.isMPEChannel(channel)) {
                    const mpeData = this.mpeState.get(channel) || {};
                    mpeData.pitchBend = midiEvent.value;
                    this.mpeState.set(channel, mpeData);
                }
                break;

            case 0xD0: // Channel Pressure (Aftertouch)
                midiEvent.type = 'pressure';
                midiEvent.value = data1 / 127;

                if (this.isMPEChannel(channel)) {
                    const mpeData = this.mpeState.get(channel) || {};
                    mpeData.pressure = midiEvent.value;
                    this.mpeState.set(channel, mpeData);
                }
                break;

            case 0xA0: // Polyphonic Key Pressure
                midiEvent.type = 'polyPressure';
                midiEvent.note = data1;
                midiEvent.value = data2 / 127;
                break;

            case 0xC0: // Program Change
                midiEvent.type = 'programChange';
                midiEvent.program = data1;
                break;
        }

        this.notifyListeners(midiEvent);
    }

    isMPEChannel(channel) {
        if (this.mpeZone.lower) {
            return channel >= 1 && channel <= this.mpeZone.memberChannels;
        } else {
            return channel >= 16 - this.mpeZone.memberChannels && channel <= 15;
        }
    }

    noteToFrequency(note) {
        return 440 * Math.pow(2, (note - 69) / 12);
    }

    // ==================== LISTENERS ====================
    addListener(callback) {
        this.listeners.push(callback);
    }

    removeListener(callback) {
        this.listeners = this.listeners.filter(l => l !== callback);
    }

    notifyListeners(event) {
        this.listeners.forEach(cb => cb(event));
    }

    // ==================== CC MAPPINGS ====================
    setupDefaultMappings() {
        this.ccMappings.set(1, { target: 'modWheel', name: 'Mod Wheel' });
        this.ccMappings.set(7, { target: 'volume', name: 'Volume' });
        this.ccMappings.set(10, { target: 'pan', name: 'Pan' });
        this.ccMappings.set(11, { target: 'expression', name: 'Expression' });
        this.ccMappings.set(64, { target: 'sustain', name: 'Sustain' });
        this.ccMappings.set(74, { target: 'brightness', name: 'Brightness/Slide' });
        this.ccMappings.set(71, { target: 'resonance', name: 'Resonance' });
        this.ccMappings.set(72, { target: 'release', name: 'Release' });
        this.ccMappings.set(73, { target: 'attack', name: 'Attack' });
        this.ccMappings.set(91, { target: 'reverb', name: 'Reverb' });
        this.ccMappings.set(93, { target: 'chorus', name: 'Chorus' });
    }

    startLearning(targetName) {
        this.isLearning = true;
        this.learningTarget = targetName;
        console.log('[MIDIEngine] Learning mode: move a controller for', targetName);
    }

    stopLearning() {
        this.isLearning = false;
        this.learningTarget = null;
    }

    setMapping(cc, target) {
        this.ccMappings.set(cc, target);
    }

    getMappings() {
        return Object.fromEntries(this.ccMappings);
    }

    // ==================== OUTPUT ====================
    sendNoteOn(note, velocity = 100, channel = 0, outputId = null) {
        const data = [0x90 | channel, note, velocity];
        this.sendToOutput(data, outputId);
    }

    sendNoteOff(note, velocity = 0, channel = 0, outputId = null) {
        const data = [0x80 | channel, note, velocity];
        this.sendToOutput(data, outputId);
    }

    sendCC(controller, value, channel = 0, outputId = null) {
        const data = [0xB0 | channel, controller, value];
        this.sendToOutput(data, outputId);
    }

    sendPitchBend(value, channel = 0, outputId = null) {
        // value: -1 to 1
        const bendValue = Math.round((value + 1) * 8192);
        const lsb = bendValue & 0x7F;
        const msb = (bendValue >> 7) & 0x7F;
        const data = [0xE0 | channel, lsb, msb];
        this.sendToOutput(data, outputId);
    }

    sendToOutput(data, outputId = null) {
        if (outputId && this.outputs.has(outputId)) {
            this.outputs.get(outputId).send(data);
        } else {
            // Send to all outputs
            this.outputs.forEach(output => output.send(data));
        }
    }

    // ==================== DEVICE INFO ====================
    getInputDevices() {
        return Array.from(this.inputs.values()).map(input => ({
            id: input.id,
            name: input.name,
            manufacturer: input.manufacturer,
            state: input.state
        }));
    }

    getOutputDevices() {
        return Array.from(this.outputs.values()).map(output => ({
            id: output.id,
            name: output.name,
            manufacturer: output.manufacturer,
            state: output.state
        }));
    }

    // ==================== MPE CONFIGURATION ====================
    configureMPE(lowerZone = true, memberChannels = 15) {
        this.mpeZone = {
            lower: lowerZone,
            masterChannel: lowerZone ? 0 : 15,
            memberChannels: Math.min(15, memberChannels)
        };

        console.log('[MIDIEngine] MPE configured:', this.mpeZone);
    }
}

// Export
if (typeof module !== 'undefined' && module.exports) {
    module.exports = MIDIEngine;
}
