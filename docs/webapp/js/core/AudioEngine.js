/**
 * Echoelmusic WebApp - Core Audio Engine
 * Web Audio API based synthesis and effects
 */

class AudioEngine {
    constructor() {
        this.audioContext = null;
        this.masterGain = null;
        this.analyser = null;
        this.voices = new Map();
        this.maxVoices = 16;
        this.effects = [];
        this.isInitialized = false;

        // Bio-reactive parameters
        this.bioParams = {
            filterCutoff: 2000,
            reverbMix: 0.3,
            delayTime: 0.3,
            lfoRate: 1.0
        };
    }

    async init() {
        if (this.isInitialized) return;

        try {
            const AudioContextClass = window.AudioContext || window.webkitAudioContext;
            if (!AudioContextClass) {
                throw new Error('Web Audio API not supported');
            }
            this.audioContext = new AudioContextClass({
                latencyHint: 'interactive',
                sampleRate: 48000
            });
        } catch (e) {
            console.error('[AudioEngine] Failed to create AudioContext:', e);
            throw e;
        }

        // Master output chain
        this.masterGain = this.audioContext.createGain();
        this.masterGain.gain.value = 0.7;

        // Analyser for visualizations
        this.analyser = this.audioContext.createAnalyser();
        this.analyser.fftSize = 2048;
        this.analyser.smoothingTimeConstant = 0.8;

        // Effects chain
        this.filter = this.audioContext.createBiquadFilter();
        this.filter.type = 'lowpass';
        this.filter.frequency.value = 8000;
        this.filter.Q.value = 1;

        this.compressor = this.audioContext.createDynamicsCompressor();
        this.compressor.threshold.value = -24;
        this.compressor.knee.value = 30;
        this.compressor.ratio.value = 4;
        this.compressor.attack.value = 0.003;
        this.compressor.release.value = 0.25;

        this.reverb = await this.createReverb();
        this.reverbGain = this.audioContext.createGain();
        this.reverbGain.gain.value = 0.3;

        this.delay = this.audioContext.createDelay(5.0);
        this.delay.delayTime.value = 0.3;
        this.delayFeedback = this.audioContext.createGain();
        this.delayFeedback.gain.value = 0.4;
        this.delayGain = this.audioContext.createGain();
        this.delayGain.gain.value = 0.3;

        // Connect effects chain
        this.masterGain.connect(this.filter);
        this.filter.connect(this.compressor);
        this.compressor.connect(this.analyser);

        // Dry path
        this.analyser.connect(this.audioContext.destination);

        // Reverb path
        this.analyser.connect(this.reverb);
        this.reverb.connect(this.reverbGain);
        this.reverbGain.connect(this.audioContext.destination);

        // Delay path with feedback
        this.analyser.connect(this.delay);
        this.delay.connect(this.delayFeedback);
        this.delayFeedback.connect(this.delay);
        this.delay.connect(this.delayGain);
        this.delayGain.connect(this.audioContext.destination);

        this.isInitialized = true;
        console.log('[AudioEngine] Initialized at', this.audioContext.sampleRate, 'Hz');
    }

    async createReverb() {
        const convolver = this.audioContext.createConvolver();
        const length = this.audioContext.sampleRate * 2;
        const impulse = this.audioContext.createBuffer(2, length, this.audioContext.sampleRate);

        for (let channel = 0; channel < 2; channel++) {
            const channelData = impulse.getChannelData(channel);
            for (let i = 0; i < length; i++) {
                channelData[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / length, 2);
            }
        }

        convolver.buffer = impulse;
        return convolver;
    }

    resume() {
        if (this.audioContext && this.audioContext.state === 'suspended') {
            this.audioContext.resume();
        }
    }

    // Voice management with polyphony
    noteOn(noteNumber, velocity = 1.0, params = {}) {
        if (!this.isInitialized) return null;

        const frequency = 440 * Math.pow(2, (noteNumber - 69) / 12);

        // Voice stealing if at max
        if (this.voices.size >= this.maxVoices) {
            const oldestKey = this.voices.keys().next().value;
            this.noteOff(oldestKey);
        }

        const voice = this.createVoice(frequency, velocity, params);
        this.voices.set(noteNumber, voice);

        return voice;
    }

    noteOff(noteNumber) {
        const voice = this.voices.get(noteNumber);
        if (!voice || !this.audioContext) return;

        const releaseTime = voice.envelope?.release || 0.3;
        const now = this.audioContext.currentTime;

        try {
            voice.gainNode.gain.cancelScheduledValues(now);
            voice.gainNode.gain.setValueAtTime(voice.gainNode.gain.value, now);
            voice.gainNode.gain.exponentialRampToValueAtTime(0.001, now + releaseTime);

            setTimeout(() => {
                try {
                    voice.oscillators?.forEach(osc => osc.stop());
                    voice.gainNode?.disconnect();
                } catch (e) {
                    // Already stopped/disconnected
                }
                this.voices.delete(noteNumber);
            }, releaseTime * 1000 + 50);
        } catch (e) {
            console.warn('[AudioEngine] noteOff error:', e);
            this.voices.delete(noteNumber);
        }
    }

    createVoice(frequency, velocity, params = {}) {
        const waveform = params.waveform || 'sawtooth';
        const attack = params.attack || 0.01;
        const decay = params.decay || 0.1;
        const sustain = params.sustain || 0.7;
        const release = params.release || 0.3;
        const detune = params.detune || 0;
        const oscillatorCount = params.oscillatorCount || 2;

        const gainNode = this.audioContext.createGain();
        gainNode.gain.value = 0;
        gainNode.connect(this.masterGain);

        const oscillators = [];
        const now = this.audioContext.currentTime;

        for (let i = 0; i < oscillatorCount; i++) {
            const osc = this.audioContext.createOscillator();
            osc.type = waveform;
            osc.frequency.value = frequency;
            osc.detune.value = detune + (i - (oscillatorCount - 1) / 2) * 10;
            osc.connect(gainNode);
            osc.start(now);
            oscillators.push(osc);
        }

        // ADSR envelope
        const peakGain = velocity * 0.5;
        gainNode.gain.setValueAtTime(0, now);
        gainNode.gain.linearRampToValueAtTime(peakGain, now + attack);
        gainNode.gain.linearRampToValueAtTime(peakGain * sustain, now + attack + decay);

        return {
            oscillators,
            gainNode,
            frequency,
            envelope: { attack, decay, sustain, release }
        };
    }

    // Binaural beat generator for brainwave entrainment
    startBinauralBeat(carrierFreq = 432, beatFreq = 10) {
        if (this.binauralOscillators) {
            this.stopBinauralBeat();
        }

        const leftOsc = this.audioContext.createOscillator();
        const rightOsc = this.audioContext.createOscillator();
        const leftGain = this.audioContext.createGain();
        const rightGain = this.audioContext.createGain();
        const merger = this.audioContext.createChannelMerger(2);

        leftOsc.frequency.value = carrierFreq;
        rightOsc.frequency.value = carrierFreq + beatFreq;
        leftGain.gain.value = 0.3;
        rightGain.gain.value = 0.3;

        leftOsc.connect(leftGain);
        rightOsc.connect(rightGain);
        leftGain.connect(merger, 0, 0);
        rightGain.connect(merger, 0, 1);
        merger.connect(this.masterGain);

        leftOsc.start();
        rightOsc.start();

        this.binauralOscillators = { leftOsc, rightOsc, leftGain, rightGain, merger };

        console.log(`[AudioEngine] Binaural beat: ${carrierFreq}Hz carrier, ${beatFreq}Hz beat`);
    }

    stopBinauralBeat() {
        if (this.binauralOscillators) {
            const { leftOsc, rightOsc } = this.binauralOscillators;
            leftOsc.stop();
            rightOsc.stop();
            this.binauralOscillators = null;
        }
    }

    // Bio-reactive parameter updates
    onBioData(bioData) {
        if (!this.isInitialized) return;

        const { heartRate, hrv, coherence, breathingRate, breathPhase } = bioData;

        // Filter cutoff modulation (coherence → brightness)
        const cutoff = 500 + coherence * 7500;
        this.filter.frequency.setTargetAtTime(cutoff, this.audioContext.currentTime, 0.1);

        // Reverb mix (coherence → spaciousness)
        this.reverbGain.gain.setTargetAtTime(0.1 + coherence * 0.5, this.audioContext.currentTime, 0.1);

        // Delay feedback (HRV → echo depth)
        const normalizedHRV = Math.min(hrv / 100, 1);
        this.delayFeedback.gain.setTargetAtTime(0.2 + normalizedHRV * 0.4, this.audioContext.currentTime, 0.1);

        // Delay time sync to breathing
        if (breathingRate > 0) {
            const breathCycleTime = 60 / breathingRate;
            const delayTime = Math.min(breathCycleTime / 4, 1.0);
            this.delay.delayTime.setTargetAtTime(delayTime, this.audioContext.currentTime, 0.2);
        }

        this.bioParams = { heartRate, hrv, coherence, breathingRate, breathPhase };
    }

    // Get frequency data for visualizations
    getFrequencyData() {
        if (!this.analyser) return new Uint8Array(0);
        const data = new Uint8Array(this.analyser.frequencyBinCount);
        this.analyser.getByteFrequencyData(data);
        return data;
    }

    getTimeDomainData() {
        if (!this.analyser) return new Uint8Array(0);
        const data = new Uint8Array(this.analyser.fftSize);
        this.analyser.getByteTimeDomainData(data);
        return data;
    }

    // Set master volume
    setVolume(value) {
        if (this.masterGain) {
            this.masterGain.gain.setTargetAtTime(value, this.audioContext.currentTime, 0.05);
        }
    }

    // Set filter parameters
    setFilter(type, frequency, Q) {
        if (this.filter) {
            this.filter.type = type;
            this.filter.frequency.setTargetAtTime(frequency, this.audioContext.currentTime, 0.05);
            this.filter.Q.setTargetAtTime(Q, this.audioContext.currentTime, 0.05);
        }
    }

    // Cleanup
    destroy() {
        this.voices.forEach((voice, noteNumber) => {
            this.noteOff(noteNumber);
        });
        this.stopBinauralBeat();
        if (this.audioContext) {
            this.audioContext.close();
        }
    }
}

// Export for module use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = AudioEngine;
}
