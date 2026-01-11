/**
 * Echoelmusic WebApp - Bio Engine
 * Multi-source biometric data: Simulator, Web Bluetooth, Camera rPPG
 */

class BioEngine {
    constructor() {
        this.mode = 'simulator'; // 'simulator', 'bluetooth', 'camera'
        this.isRunning = false;
        this.listeners = [];
        this.interval = null;

        // Current bio data
        this.data = {
            heartRate: 72,
            hrv: 45,
            coherence: 0.5,
            breathingRate: 12,
            breathPhase: 0,
            gsr: 0.5,
            temperature: 36.5,
            spo2: 98
        };

        // HRV calculation buffer
        this.rrIntervals = [];
        this.maxRRIntervals = 60;

        // Bluetooth
        this.btDevice = null;
        this.btCharacteristic = null;

        // Camera rPPG
        this.video = null;
        this.canvas = null;
        this.ctx = null;
        this.rppgBuffer = [];
        this.rppgBufferSize = 150; // 5 seconds at 30fps

        // Breathing detection
        this.hrvBuffer = [];
        this.hrvBufferSize = 30;
    }

    // Add listener for bio data updates
    addListener(callback) {
        this.listeners.push(callback);
    }

    removeListener(callback) {
        this.listeners = this.listeners.filter(l => l !== callback);
    }

    notifyListeners() {
        this.listeners.forEach(cb => cb(this.data));
    }

    // ==================== SIMULATOR MODE ====================
    startSimulator() {
        if (this.isRunning) return;
        this.mode = 'simulator';
        this.isRunning = true;

        let t = 0;
        this.interval = setInterval(() => {
            t += 0.05;

            // Realistic oscillations
            const baseHR = 72;
            const hrVariation = Math.sin(t * 0.3) * 8 + Math.sin(t * 1.2) * 3 + (Math.random() - 0.5) * 2;
            this.data.heartRate = Math.round(baseHR + hrVariation);

            // HRV (higher when relaxed, lower when stressed)
            const baseHRV = 45;
            const hrvVariation = Math.sin(t * 0.1) * 20 + Math.sin(t * 0.5) * 10;
            this.data.hrv = Math.max(10, Math.round(baseHRV + hrvVariation));

            // Coherence (0-1) - based on HRV pattern regularity
            const coherenceWave = (Math.sin(t * 0.2) + 1) / 2;
            this.data.coherence = Math.max(0, Math.min(1, coherenceWave * 0.7 + 0.15 + (Math.random() - 0.5) * 0.1));

            // Breathing (4-8 breaths per minute for relaxed state)
            this.data.breathingRate = 6 + Math.sin(t * 0.05) * 2;
            this.data.breathPhase = (Math.sin(t * 0.3) + 1) / 2; // 0-1 inhale/exhale

            // GSR (skin conductance)
            this.data.gsr = 0.3 + Math.sin(t * 0.15) * 0.2 + Math.random() * 0.1;

            // Temperature (stable)
            this.data.temperature = 36.5 + Math.sin(t * 0.02) * 0.3;

            // SpO2 (oxygen saturation)
            this.data.spo2 = 97 + Math.random() * 2;

            this.notifyListeners();
        }, 50);

        console.log('[BioEngine] Simulator started');
    }

    // ==================== WEB BLUETOOTH MODE ====================
    async startBluetooth() {
        if (!navigator.bluetooth) {
            throw new Error('Web Bluetooth not supported in this browser');
        }

        try {
            // Request BLE Heart Rate device
            this.btDevice = await navigator.bluetooth.requestDevice({
                filters: [
                    { services: ['heart_rate'] },
                    { namePrefix: 'Polar' },
                    { namePrefix: 'Wahoo' },
                    { namePrefix: 'Garmin' }
                ],
                optionalServices: ['heart_rate', 'battery_service']
            });

            console.log('[BioEngine] Connecting to', this.btDevice.name);

            const server = await this.btDevice.gatt.connect();
            const service = await server.getPrimaryService('heart_rate');
            this.btCharacteristic = await service.getCharacteristic('heart_rate_measurement');

            await this.btCharacteristic.startNotifications();
            this.btCharacteristic.addEventListener('characteristicvaluechanged',
                this.handleHeartRateData.bind(this));

            this.mode = 'bluetooth';
            this.isRunning = true;

            // Start coherence calculation interval
            this.interval = setInterval(() => {
                this.calculateCoherence();
                this.notifyListeners();
            }, 1000);

            console.log('[BioEngine] Bluetooth connected to', this.btDevice.name);
            return this.btDevice.name;

        } catch (error) {
            console.error('[BioEngine] Bluetooth error:', error);
            throw error;
        }
    }

    handleHeartRateData(event) {
        const value = event.target.value;
        const flags = value.getUint8(0);
        const rate16Bits = flags & 0x1;
        const rrPresent = flags & 0x10;

        let heartRate;
        let offset = 1;

        if (rate16Bits) {
            heartRate = value.getUint16(offset, true);
            offset += 2;
        } else {
            heartRate = value.getUint8(offset);
            offset += 1;
        }

        this.data.heartRate = heartRate;

        // Extract RR intervals if present
        if (rrPresent) {
            while (offset + 2 <= value.byteLength) {
                const rrInterval = value.getUint16(offset, true) / 1024 * 1000; // Convert to ms
                this.rrIntervals.push(rrInterval);
                if (this.rrIntervals.length > this.maxRRIntervals) {
                    this.rrIntervals.shift();
                }
                offset += 2;
            }
            this.calculateHRV();
        }
    }

    calculateHRV() {
        if (this.rrIntervals.length < 5) return;

        // RMSSD calculation (root mean square of successive differences)
        let sumSquaredDiff = 0;
        for (let i = 1; i < this.rrIntervals.length; i++) {
            const diff = this.rrIntervals[i] - this.rrIntervals[i - 1];
            sumSquaredDiff += diff * diff;
        }
        const rmssd = Math.sqrt(sumSquaredDiff / (this.rrIntervals.length - 1));

        // SDNN (standard deviation of NN intervals)
        const mean = this.rrIntervals.reduce((a, b) => a + b, 0) / this.rrIntervals.length;
        const variance = this.rrIntervals.reduce((sum, rr) => sum + Math.pow(rr - mean, 2), 0) / this.rrIntervals.length;
        const sdnn = Math.sqrt(variance);

        this.data.hrv = Math.round(rmssd);

        // Store for coherence calculation
        this.hrvBuffer.push(rmssd);
        if (this.hrvBuffer.length > this.hrvBufferSize) {
            this.hrvBuffer.shift();
        }

        // Estimate breathing rate from RSA (Respiratory Sinus Arrhythmia)
        this.estimateBreathingRate();
    }

    calculateCoherence() {
        if (this.rrIntervals.length < 10) {
            this.data.coherence = 0.5;
            return;
        }

        // HeartMath-style coherence calculation
        // High coherence = regular, sine-wave-like HRV pattern

        // Calculate power spectral density in the coherence band (0.04-0.15 Hz)
        const n = this.rrIntervals.length;
        let coherencePower = 0;
        let totalPower = 0;

        // Simple spectral analysis using autocorrelation
        for (let lag = 0; lag < Math.min(n, 20); lag++) {
            let sum = 0;
            for (let i = 0; i < n - lag; i++) {
                sum += (this.rrIntervals[i] - this.data.hrv) * (this.rrIntervals[i + lag] - this.data.hrv);
            }
            const autocorr = sum / (n - lag);

            // Coherence band corresponds to lags 7-25 (roughly 0.04-0.15 Hz at typical sampling)
            if (lag >= 7 && lag <= 25) {
                coherencePower += Math.abs(autocorr);
            }
            totalPower += Math.abs(autocorr);
        }

        this.data.coherence = totalPower > 0 ? Math.min(1, coherencePower / totalPower * 2) : 0.5;
    }

    estimateBreathingRate() {
        if (this.rrIntervals.length < 20) return;

        // Find dominant frequency in RR interval variations (RSA)
        // Breathing typically causes 0.1-0.4 Hz oscillation in heart rate

        // Simple peak detection in RR intervals
        let peaks = 0;
        for (let i = 1; i < this.rrIntervals.length - 1; i++) {
            if (this.rrIntervals[i] > this.rrIntervals[i - 1] &&
                this.rrIntervals[i] > this.rrIntervals[i + 1]) {
                peaks++;
            }
        }

        // Estimate breathing rate (peaks in ~30 seconds of data)
        const durationMinutes = (this.rrIntervals.length * (this.data.heartRate > 0 ? 60000 / this.data.heartRate : 800)) / 60000;
        this.data.breathingRate = Math.round(peaks / durationMinutes);
        this.data.breathingRate = Math.max(4, Math.min(30, this.data.breathingRate));
    }

    // ==================== CAMERA rPPG MODE ====================
    async startCamera() {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({
                video: { facingMode: 'user', width: 320, height: 240 }
            });

            this.video = document.createElement('video');
            this.video.srcObject = stream;
            this.video.play();

            this.canvas = document.createElement('canvas');
            this.canvas.width = 64;
            this.canvas.height = 64;
            this.ctx = this.canvas.getContext('2d', { willReadFrequently: true });

            this.mode = 'camera';
            this.isRunning = true;

            // Process frames at 30fps
            this.interval = setInterval(() => {
                this.processVideoFrame();
            }, 33);

            console.log('[BioEngine] Camera rPPG started');
            return true;

        } catch (error) {
            console.error('[BioEngine] Camera error:', error);
            throw error;
        }
    }

    processVideoFrame() {
        if (!this.video || !this.ctx) return;

        // Draw video frame to canvas (face region)
        this.ctx.drawImage(this.video, 0, 0, 64, 64);
        const imageData = this.ctx.getImageData(16, 16, 32, 32); // Center region
        const pixels = imageData.data;

        // Extract average green channel (best for PPG)
        let greenSum = 0;
        let pixelCount = 0;

        for (let i = 0; i < pixels.length; i += 4) {
            const r = pixels[i];
            const g = pixels[i + 1];
            const b = pixels[i + 2];

            // Filter for skin-like colors
            if (r > 50 && g > 30 && b > 20 && r > g && r > b) {
                greenSum += g;
                pixelCount++;
            }
        }

        if (pixelCount > 100) {
            const avgGreen = greenSum / pixelCount;
            this.rppgBuffer.push(avgGreen);

            if (this.rppgBuffer.length > this.rppgBufferSize) {
                this.rppgBuffer.shift();
            }

            if (this.rppgBuffer.length >= 90) { // At least 3 seconds
                this.calculateHeartRateFromRPPG();
            }
        }

        this.notifyListeners();
    }

    calculateHeartRateFromRPPG() {
        const signal = this.rppgBuffer;
        const n = signal.length;

        // Detrend signal (remove slow drift)
        const mean = signal.reduce((a, b) => a + b, 0) / n;
        const detrended = signal.map(v => v - mean);

        // Bandpass filter simulation (0.7-3.5 Hz = 42-210 BPM)
        // Simple moving average difference
        const filtered = [];
        const windowSize = 5;
        for (let i = windowSize; i < detrended.length; i++) {
            const current = detrended.slice(i - windowSize, i).reduce((a, b) => a + b, 0) / windowSize;
            const previous = detrended.slice(i - windowSize * 2, i - windowSize).reduce((a, b) => a + b, 0) / windowSize;
            filtered.push(current - previous);
        }

        // Count zero crossings (rough frequency estimate)
        let crossings = 0;
        for (let i = 1; i < filtered.length; i++) {
            if ((filtered[i] > 0 && filtered[i - 1] < 0) || (filtered[i] < 0 && filtered[i - 1] > 0)) {
                crossings++;
            }
        }

        // Convert to BPM (crossings / 2 = cycles, * 2 for 30fps over buffer duration)
        const durationSeconds = this.rppgBufferSize / 30;
        const estimatedHR = (crossings / 2) / durationSeconds * 60;

        // Smooth the heart rate
        if (estimatedHR >= 45 && estimatedHR <= 180) {
            this.data.heartRate = Math.round(this.data.heartRate * 0.8 + estimatedHR * 0.2);
        }

        // Estimate HRV from signal variability
        const variance = filtered.reduce((sum, v) => sum + v * v, 0) / filtered.length;
        this.data.hrv = Math.round(20 + Math.sqrt(variance) * 2);

        // Simple coherence from signal regularity
        this.data.coherence = Math.max(0.2, Math.min(0.9, 1 - variance / 100));
    }

    // ==================== BREATHING GUIDE ====================
    startBreathingGuide(pattern = 'coherence') {
        const patterns = {
            box: { inhale: 4, holdIn: 4, exhale: 4, holdOut: 4 },
            '478': { inhale: 4, holdIn: 7, exhale: 8, holdOut: 0 },
            coherence: { inhale: 5, holdIn: 0, exhale: 5, holdOut: 0 }, // 6 breaths/min
            energizing: { inhale: 2, holdIn: 0, exhale: 2, holdOut: 0 },
            calming: { inhale: 4, holdIn: 0, exhale: 8, holdOut: 0 }
        };

        const p = patterns[pattern] || patterns.coherence;
        const cycleTime = p.inhale + p.holdIn + p.exhale + p.holdOut;
        let t = 0;

        if (this.breathingInterval) {
            clearInterval(this.breathingInterval);
        }

        this.breathingInterval = setInterval(() => {
            t = (t + 0.1) % cycleTime;

            if (t < p.inhale) {
                this.data.breathPhase = t / p.inhale; // 0 → 1 (inhale)
            } else if (t < p.inhale + p.holdIn) {
                this.data.breathPhase = 1; // Hold at top
            } else if (t < p.inhale + p.holdIn + p.exhale) {
                this.data.breathPhase = 1 - (t - p.inhale - p.holdIn) / p.exhale; // 1 → 0 (exhale)
            } else {
                this.data.breathPhase = 0; // Hold at bottom
            }

            this.data.breathingRate = 60 / cycleTime;
            this.notifyListeners();
        }, 100);

        return { pattern, cycleTime, bpm: 60 / cycleTime };
    }

    stopBreathingGuide() {
        if (this.breathingInterval) {
            clearInterval(this.breathingInterval);
            this.breathingInterval = null;
        }
    }

    // ==================== GENERAL CONTROLS ====================
    stop() {
        this.isRunning = false;

        if (this.interval) {
            clearInterval(this.interval);
            this.interval = null;
        }

        if (this.btDevice && this.btDevice.gatt.connected) {
            this.btDevice.gatt.disconnect();
        }

        if (this.video && this.video.srcObject) {
            this.video.srcObject.getTracks().forEach(track => track.stop());
        }

        this.stopBreathingGuide();
        console.log('[BioEngine] Stopped');
    }

    getMode() {
        return this.mode;
    }

    getData() {
        return { ...this.data };
    }

    // Check what bio sources are available
    static async checkAvailability() {
        return {
            simulator: true,
            bluetooth: 'bluetooth' in navigator,
            camera: 'mediaDevices' in navigator && 'getUserMedia' in navigator.mediaDevices,
            healthKit: false // iOS native only
        };
    }
}

// Export
if (typeof module !== 'undefined' && module.exports) {
    module.exports = BioEngine;
}
