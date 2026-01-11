/**
 * Echoelmusic WebApp - Step Sequencer
 * 16-step pattern sequencer with bio-reactive modulation
 */

class Sequencer {
    constructor(audioEngine) {
        this.audioEngine = audioEngine;
        this.isPlaying = false;
        this.bpm = 120;
        this.currentStep = 0;
        this.stepCount = 16;

        // Channels
        this.channels = [
            { name: 'Kick', note: 36, pattern: [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], velocity: 1.0, muted: false },
            { name: 'Snare', note: 38, pattern: [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], velocity: 1.0, muted: false },
            { name: 'HiHat', note: 42, pattern: [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0], velocity: 0.7, muted: false },
            { name: 'OpenHat', note: 46, pattern: [0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0], velocity: 0.8, muted: false },
            { name: 'Clap', note: 39, pattern: [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], velocity: 0.9, muted: false },
            { name: 'Tom', note: 45, pattern: [0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0], velocity: 0.8, muted: false },
            { name: 'Rim', note: 37, pattern: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1], velocity: 0.6, muted: false },
            { name: 'Perc', note: 56, pattern: [0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1], velocity: 0.5, muted: false }
        ];

        // Bio-reactive settings
        this.bioModulation = {
            enabled: true,
            bpmFromHeartRate: true,
            velocityFromCoherence: true,
            skipFromHRV: true
        };

        // Bio data reference
        this.bioData = {
            heartRate: 72,
            hrv: 45,
            coherence: 0.5
        };

        // Swing
        this.swing = 0; // 0-1

        // Listeners for UI updates
        this.listeners = [];

        // Timer
        this.intervalId = null;
        this.nextStepTime = 0;
        this.scheduleAheadTime = 0.1;

        // Smooth BPM transition
        this.targetBpm = 120;
        this.bpmTransitionRate = 2; // BPM change per second
    }

    /**
     * Get drum output (bypasses delay effects)
     */
    getDrumOutput() {
        return this.audioEngine?.getDrumOutput?.() || this.audioEngine?.masterGain;
    }

    // ==================== PLAYBACK ====================
    start() {
        if (this.isPlaying) return;
        this.isPlaying = true;
        this.currentStep = 0;
        this.nextStepTime = this.audioEngine?.audioContext?.currentTime || 0;

        this.scheduleLoop();
        console.log('[Sequencer] Started at', this.bpm, 'BPM');
    }

    stop() {
        this.isPlaying = false;
        if (this.intervalId) {
            clearTimeout(this.intervalId);
            this.intervalId = null;
        }
        this.currentStep = 0;
        this.notifyListeners({ type: 'stop' });
    }

    scheduleLoop() {
        if (!this.isPlaying) return;

        const currentTime = this.audioEngine?.audioContext?.currentTime || Date.now() / 1000;
        const effectiveBpm = this.getEffectiveBpm();
        const stepDuration = 60 / effectiveBpm / 4; // 16th notes

        while (this.nextStepTime < currentTime + this.scheduleAheadTime) {
            this.scheduleStep(this.currentStep, this.nextStepTime);

            // Apply swing to even steps
            const swingOffset = (this.currentStep % 2 === 1) ? stepDuration * this.swing * 0.5 : 0;

            this.nextStepTime += stepDuration + swingOffset;
            this.currentStep = (this.currentStep + 1) % this.stepCount;
        }

        // Only schedule next loop if still playing
        if (this.isPlaying) {
            this.intervalId = setTimeout(() => this.scheduleLoop(), 25);
        }
    }

    scheduleStep(step, time) {
        const coherenceVelocity = this.bioModulation.velocityFromCoherence
            ? 0.5 + this.bioData.coherence * 0.5
            : 1;

        this.channels.forEach((channel, channelIndex) => {
            if (channel.muted) return;

            // Bio-reactive skip based on HRV
            if (this.bioModulation.skipFromHRV) {
                const skipProbability = (1 - this.bioData.hrv / 100) * 0.2;
                if (Math.random() < skipProbability) return;
            }

            if (channel.pattern[step]) {
                const velocity = channel.velocity * coherenceVelocity;

                // Trigger audio
                if (this.audioEngine) {
                    this.triggerDrumSound(channel.note, velocity, time);
                }

                // Notify listeners
                this.notifyListeners({
                    type: 'trigger',
                    step,
                    channel: channelIndex,
                    note: channel.note,
                    velocity,
                    time
                });
            }
        });

        // Step update notification
        this.notifyListeners({ type: 'step', step });
    }

    triggerDrumSound(note, velocity, time) {
        // Simple drum synthesis
        const ctx = this.audioEngine.audioContext;
        if (!ctx) return;

        const now = time || ctx.currentTime;

        switch (note) {
            case 36: // Kick
                this.playKick(ctx, now, velocity);
                break;
            case 38: // Snare
                this.playSnare(ctx, now, velocity);
                break;
            case 42: // Closed Hi-Hat
                this.playHiHat(ctx, now, velocity, 0.05);
                break;
            case 46: // Open Hi-Hat
                this.playHiHat(ctx, now, velocity, 0.3);
                break;
            case 39: // Clap
                this.playClap(ctx, now, velocity);
                break;
            case 45: // Tom
                this.playTom(ctx, now, velocity);
                break;
            case 37: // Rim
                this.playRim(ctx, now, velocity);
                break;
            default:
                this.playGenericPerc(ctx, now, velocity, note);
        }
    }

    playKick(ctx, time, velocity) {
        const drumOutput = this.getDrumOutput();
        if (!drumOutput) return;

        const osc = ctx.createOscillator();
        const gain = ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(150, time);
        osc.frequency.exponentialRampToValueAtTime(40, time + 0.1);

        gain.gain.setValueAtTime(velocity, time);
        gain.gain.exponentialRampToValueAtTime(0.01, time + 0.3);

        osc.connect(gain);
        gain.connect(drumOutput);

        osc.start(time);
        osc.stop(time + 0.3);
    }

    playSnare(ctx, time, velocity) {
        // Noise component
        const bufferSize = ctx.sampleRate * 0.2;
        const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) {
            data[i] = Math.random() * 2 - 1;
        }

        const noise = ctx.createBufferSource();
        noise.buffer = buffer;

        const noiseFilter = ctx.createBiquadFilter();
        noiseFilter.type = 'highpass';
        noiseFilter.frequency.value = 1000;

        const noiseGain = ctx.createGain();
        noiseGain.gain.setValueAtTime(velocity * 0.5, time);
        noiseGain.gain.exponentialRampToValueAtTime(0.01, time + 0.15);

        noise.connect(noiseFilter);
        noiseFilter.connect(noiseGain);
        noiseGain.connect(this.getDrumOutput());

        // Tone component
        const osc = ctx.createOscillator();
        const oscGain = ctx.createGain();
        osc.type = 'triangle';
        osc.frequency.value = 180;
        oscGain.gain.setValueAtTime(velocity * 0.3, time);
        oscGain.gain.exponentialRampToValueAtTime(0.01, time + 0.1);

        osc.connect(oscGain);
        oscGain.connect(this.getDrumOutput());

        noise.start(time);
        osc.start(time);
        noise.stop(time + 0.2);
        osc.stop(time + 0.1);
    }

    playHiHat(ctx, time, velocity, decay) {
        const bufferSize = ctx.sampleRate * 0.1;
        const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) {
            data[i] = Math.random() * 2 - 1;
        }

        const noise = ctx.createBufferSource();
        noise.buffer = buffer;

        const filter = ctx.createBiquadFilter();
        filter.type = 'highpass';
        filter.frequency.value = 7000;

        const gain = ctx.createGain();
        gain.gain.setValueAtTime(velocity * 0.3, time);
        gain.gain.exponentialRampToValueAtTime(0.01, time + decay);

        noise.connect(filter);
        filter.connect(gain);
        gain.connect(this.getDrumOutput());

        noise.start(time);
        noise.stop(time + decay + 0.1);
    }

    playClap(ctx, time, velocity) {
        // Multiple noise bursts for clap texture
        for (let i = 0; i < 3; i++) {
            const bufferSize = ctx.sampleRate * 0.02;
            const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
            const data = buffer.getChannelData(0);
            for (let j = 0; j < bufferSize; j++) {
                data[j] = Math.random() * 2 - 1;
            }

            const noise = ctx.createBufferSource();
            noise.buffer = buffer;

            const filter = ctx.createBiquadFilter();
            filter.type = 'bandpass';
            filter.frequency.value = 1500;

            const gain = ctx.createGain();
            gain.gain.setValueAtTime(velocity * 0.3, time + i * 0.01);
            gain.gain.exponentialRampToValueAtTime(0.01, time + i * 0.01 + 0.1);

            noise.connect(filter);
            filter.connect(gain);
            gain.connect(this.getDrumOutput());

            noise.start(time + i * 0.01);
            noise.stop(time + i * 0.01 + 0.15);
        }
    }

    playTom(ctx, time, velocity) {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(200, time);
        osc.frequency.exponentialRampToValueAtTime(80, time + 0.2);

        gain.gain.setValueAtTime(velocity * 0.5, time);
        gain.gain.exponentialRampToValueAtTime(0.01, time + 0.25);

        osc.connect(gain);
        gain.connect(this.getDrumOutput());

        osc.start(time);
        osc.stop(time + 0.3);
    }

    playRim(ctx, time, velocity) {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();

        osc.type = 'square';
        osc.frequency.value = 800;

        gain.gain.setValueAtTime(velocity * 0.2, time);
        gain.gain.exponentialRampToValueAtTime(0.01, time + 0.03);

        osc.connect(gain);
        gain.connect(this.getDrumOutput());

        osc.start(time);
        osc.stop(time + 0.05);
    }

    playGenericPerc(ctx, time, velocity, note) {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();

        const freq = 440 * Math.pow(2, (note - 69) / 12);
        osc.type = 'triangle';
        osc.frequency.value = freq;

        gain.gain.setValueAtTime(velocity * 0.3, time);
        gain.gain.exponentialRampToValueAtTime(0.01, time + 0.1);

        osc.connect(gain);
        gain.connect(this.getDrumOutput());

        osc.start(time);
        osc.stop(time + 0.15);
    }

    // ==================== PATTERN EDITING ====================
    toggleStep(channelIndex, stepIndex) {
        if (channelIndex < this.channels.length && stepIndex < this.stepCount) {
            this.channels[channelIndex].pattern[stepIndex] =
                this.channels[channelIndex].pattern[stepIndex] ? 0 : 1;
        }
    }

    setPattern(channelIndex, pattern) {
        if (channelIndex < this.channels.length) {
            this.channels[channelIndex].pattern = pattern.slice(0, this.stepCount);
        }
    }

    clearPattern(channelIndex) {
        if (channelIndex < this.channels.length) {
            this.channels[channelIndex].pattern = new Array(this.stepCount).fill(0);
        }
    }

    clearAll() {
        this.channels.forEach(channel => {
            channel.pattern = new Array(this.stepCount).fill(0);
        });
    }

    toggleMute(channelIndex) {
        if (channelIndex < this.channels.length) {
            this.channels[channelIndex].muted = !this.channels[channelIndex].muted;
        }
    }

    setVelocity(channelIndex, velocity) {
        if (channelIndex < this.channels.length) {
            this.channels[channelIndex].velocity = Math.max(0, Math.min(1, velocity));
        }
    }

    // ==================== BPM & TIMING ====================
    setBpm(bpm, instant = false) {
        const newBpm = Math.max(30, Math.min(300, bpm));
        if (instant) {
            this.bpm = newBpm;
            this.targetBpm = newBpm;
        } else {
            // Smooth transition target
            this.targetBpm = newBpm;
        }
    }

    /**
     * Smooth BPM update (call this in scheduleLoop for smooth transitions)
     */
    updateBpmSmooth() {
        if (Math.abs(this.bpm - this.targetBpm) < 0.5) {
            this.bpm = this.targetBpm;
            return;
        }
        // Smooth interpolation towards target (2 BPM per update at 40Hz)
        const diff = this.targetBpm - this.bpm;
        this.bpm += Math.sign(diff) * Math.min(Math.abs(diff), 0.5);
    }

    getEffectiveBpm() {
        // Smooth BPM transition
        this.updateBpmSmooth();

        if (this.bioModulation.enabled && this.bioModulation.bpmFromHeartRate) {
            // Smooth blend between set BPM and heart rate
            const heartRateBpm = this.bioData.heartRate;
            const bioTarget = this.bpm + (heartRateBpm - 72) * 0.3; // Gentler influence
            return Math.max(60, Math.min(180, bioTarget));
        }
        return this.bpm;
    }

    setSwing(value) {
        this.swing = Math.max(0, Math.min(1, value));
    }

    // ==================== BIO MODULATION ====================
    onBioData(data) {
        this.bioData = { ...this.bioData, ...data };
    }

    setBioModulation(settings) {
        this.bioModulation = { ...this.bioModulation, ...settings };
    }

    // ==================== PRESETS ====================
    loadPreset(presetName) {
        const presets = {
            'fourOnFloor': [
                [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], // Kick
                [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], // Snare
                [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0], // HiHat
                [0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0], // OpenHat
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Clap
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Tom
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Rim
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]  // Perc
            ],
            'breakbeat': [
                [1,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0], // Kick
                [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,1], // Snare
                [1,1,0,1,0,1,1,0,1,1,0,1,0,1,1,0], // HiHat
                [0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0], // OpenHat
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Clap
                [0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0], // Tom
                [0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0], // Rim
                [0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1]  // Perc
            ],
            'ambient': [
                [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Kick
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Snare
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // HiHat
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // OpenHat
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Clap
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Tom
                [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], // Rim
                [0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0]  // Perc
            ],
            'minimal': [
                [1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0], // Kick
                [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], // Snare
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // HiHat
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0], // OpenHat
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Clap
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Tom
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Rim
                [0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0]  // Perc
            ],
            'trap': [
                [1,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0], // Kick
                [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], // Snare
                [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], // HiHat (rolls)
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1], // OpenHat
                [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], // Clap
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0], // Tom
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], // Rim
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]  // Perc
            ]
        };

        if (presets[presetName]) {
            presets[presetName].forEach((pattern, i) => {
                if (this.channels[i]) {
                    this.channels[i].pattern = [...pattern];
                }
            });
            console.log('[Sequencer] Loaded preset:', presetName);
        }
    }

    // ==================== EXPORT/IMPORT ====================
    exportPattern() {
        return {
            bpm: this.bpm,
            swing: this.swing,
            channels: this.channels.map(ch => ({
                name: ch.name,
                note: ch.note,
                pattern: [...ch.pattern],
                velocity: ch.velocity,
                muted: ch.muted
            }))
        };
    }

    importPattern(data) {
        if (data.bpm) this.bpm = data.bpm;
        if (data.swing) this.swing = data.swing;
        if (data.channels) {
            data.channels.forEach((ch, i) => {
                if (this.channels[i]) {
                    this.channels[i] = { ...this.channels[i], ...ch };
                }
            });
        }
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
}

// Export
if (typeof module !== 'undefined' && module.exports) {
    module.exports = Sequencer;
}
