/**
 * BodyTrackingEngine - Face, Gesture, and Movement Tracking
 * Uses camera for facial expressions and device sensors for movement
 *
 * Features:
 * - Smile detection via face brightness changes
 * - Head movement tracking
 * - Breathing visualization from face movement
 * - Gesture detection from device motion
 * - Arousal/Relaxation estimation
 */

class BodyTrackingEngine {
    constructor() {
        this.isRunning = false;

        // Camera
        this.video = null;
        this.canvas = null;
        this.ctx = null;

        // Face tracking
        this.faceData = {
            smile: 0,           // 0-1 smile intensity
            headX: 0.5,         // 0-1 head position X
            headY: 0.5,         // 0-1 head position Y
            headTilt: 0,        // -1 to 1 head tilt
            eyeOpenness: 1,     // 0-1 eye openness
            mouthOpen: 0,       // 0-1 mouth openness
            faceBrightness: 0.5,// 0-1 face brightness
            faceDetected: false
        };

        // Movement tracking
        this.movementData = {
            x: 0,               // acceleration X
            y: 0,               // acceleration Y
            z: 0,               // acceleration Z
            magnitude: 0,       // total movement
            isMoving: false,
            gestureType: null,  // 'shake', 'nod', 'tilt', 'stillness'
            energy: 0.5         // 0-1 movement energy level
        };

        // Breathing from face movement
        this.breathingData = {
            phase: 0,           // 0-1 breath phase
            rate: 12,           // breaths per minute
            depth: 0.5          // 0-1 breath depth
        };

        // Buffers for analysis
        this.brightnessBuffer = [];
        this.motionBuffer = [];
        this.headMovementBuffer = [];
        this.bufferSize = 60; // 2 seconds at 30fps

        // Listeners
        this.listeners = [];

        // Interval
        this.interval = null;
        this.motionHandler = null;
    }

    /**
     * Initialize body tracking
     */
    async init() {
        console.log('[BodyTracking] Initializing...');
        return this;
    }

    /**
     * Start camera-based face tracking
     */
    async startFaceTracking() {
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            throw new Error('Camera not available');
        }

        try {
            const stream = await navigator.mediaDevices.getUserMedia({
                video: {
                    facingMode: 'user',
                    width: { ideal: 320 },
                    height: { ideal: 240 }
                }
            });

            // Create video element
            this.video = document.createElement('video');
            this.video.srcObject = stream;
            this.video.setAttribute('playsinline', true);
            await this.video.play();

            // Create canvas for analysis
            this.canvas = document.createElement('canvas');
            this.canvas.width = 160;
            this.canvas.height = 120;
            this.ctx = this.canvas.getContext('2d', { willReadFrequently: true });

            this.isRunning = true;
            this.startFaceAnalysis();

            console.log('[BodyTracking] Face tracking started');
            return true;

        } catch (error) {
            console.error('[BodyTracking] Camera error:', error);
            throw error;
        }
    }

    /**
     * Start face analysis loop
     */
    startFaceAnalysis() {
        this.interval = setInterval(() => {
            if (!this.isRunning || !this.video) return;

            // Draw frame to canvas
            this.ctx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height);

            // Analyze frame
            this.analyzeFace();

            // Notify listeners
            this.notifyListeners();
        }, 33); // ~30fps
    }

    /**
     * Analyze face from canvas
     */
    analyzeFace() {
        const width = this.canvas.width;
        const height = this.canvas.height;
        const imageData = this.ctx.getImageData(0, 0, width, height);
        const data = imageData.data;

        // Face region (center of frame)
        const faceX = Math.floor(width * 0.25);
        const faceY = Math.floor(height * 0.15);
        const faceW = Math.floor(width * 0.5);
        const faceH = Math.floor(height * 0.7);

        // Calculate face brightness
        let totalBrightness = 0;
        let skinPixels = 0;

        // Sample face region
        for (let y = faceY; y < faceY + faceH; y += 2) {
            for (let x = faceX; x < faceX + faceW; x += 2) {
                const i = (y * width + x) * 4;
                const r = data[i];
                const g = data[i + 1];
                const b = data[i + 2];

                // Simple skin detection
                if (r > 60 && g > 40 && b > 20 && r > b && r > g * 0.8) {
                    totalBrightness += (r + g + b) / 3;
                    skinPixels++;
                }
            }
        }

        if (skinPixels > 50) {
            this.faceData.faceDetected = true;
            const avgBrightness = totalBrightness / skinPixels / 255;

            // Store in buffer
            this.brightnessBuffer.push(avgBrightness);
            if (this.brightnessBuffer.length > this.bufferSize) {
                this.brightnessBuffer.shift();
            }

            // Update face brightness
            this.faceData.faceBrightness = avgBrightness;

            // Smile detection (brightness increase in lower face when smiling)
            const lowerFaceY = faceY + faceH * 0.6;
            let lowerBrightness = 0;
            let lowerPixels = 0;

            for (let y = lowerFaceY; y < faceY + faceH; y += 2) {
                for (let x = faceX; x < faceX + faceW; x += 2) {
                    const i = (y * width + x) * 4;
                    lowerBrightness += (data[i] + data[i + 1] + data[i + 2]) / 3;
                    lowerPixels++;
                }
            }

            if (lowerPixels > 20) {
                const lowerAvg = lowerBrightness / lowerPixels / 255;
                // Smile increases cheek brightness
                const smileIndicator = Math.max(0, (lowerAvg - avgBrightness * 0.95) * 10);
                this.faceData.smile = Math.min(1, smileIndicator);
            }

            // Estimate head position from brightness distribution
            this.estimateHeadPosition(data, width, height, faceX, faceY, faceW, faceH);

            // Estimate breathing from face movement
            this.estimateBreathing();

        } else {
            this.faceData.faceDetected = false;
        }
    }

    /**
     * Estimate head position from brightness distribution
     */
    estimateHeadPosition(data, width, height, faceX, faceY, faceW, faceH) {
        let leftBrightness = 0;
        let rightBrightness = 0;
        let topBrightness = 0;
        let bottomBrightness = 0;

        const midX = faceX + faceW / 2;
        const midY = faceY + faceH / 2;

        // Sample quadrants
        for (let y = faceY; y < faceY + faceH; y += 4) {
            for (let x = faceX; x < faceX + faceW; x += 4) {
                const i = (y * width + x) * 4;
                const brightness = (data[i] + data[i + 1] + data[i + 2]) / 3;

                if (x < midX) leftBrightness += brightness;
                else rightBrightness += brightness;

                if (y < midY) topBrightness += brightness;
                else bottomBrightness += brightness;
            }
        }

        // Head X position (0 = left, 1 = right)
        const total = leftBrightness + rightBrightness;
        if (total > 0) {
            this.faceData.headX = 0.5 + (rightBrightness - leftBrightness) / total * 0.5;
        }

        // Head Y position (0 = up, 1 = down)
        const totalV = topBrightness + bottomBrightness;
        if (totalV > 0) {
            this.faceData.headY = 0.5 + (bottomBrightness - topBrightness) / totalV * 0.3;
        }

        // Store for movement analysis
        this.headMovementBuffer.push({ x: this.faceData.headX, y: this.faceData.headY });
        if (this.headMovementBuffer.length > this.bufferSize) {
            this.headMovementBuffer.shift();
        }
    }

    /**
     * Estimate breathing from subtle face movement
     */
    estimateBreathing() {
        if (this.headMovementBuffer.length < 20) return;

        // Breathing causes subtle vertical head movement
        const recent = this.headMovementBuffer.slice(-30);
        let minY = 1, maxY = 0;

        recent.forEach(pos => {
            minY = Math.min(minY, pos.y);
            maxY = Math.max(maxY, pos.y);
        });

        // Breath depth from movement range
        this.breathingData.depth = Math.min(1, (maxY - minY) * 10);

        // Estimate phase from current position
        const currentY = this.faceData.headY;
        this.breathingData.phase = (currentY - minY) / Math.max(0.01, maxY - minY);

        // Estimate rate by counting peaks
        let peaks = 0;
        for (let i = 1; i < recent.length - 1; i++) {
            if (recent[i].y > recent[i - 1].y && recent[i].y > recent[i + 1].y) {
                peaks++;
            }
        }
        // Convert to breaths per minute (30fps * 30 samples = 1 second, so peaks * 2 * 60 / 2 = peaks * 60)
        this.breathingData.rate = Math.max(4, Math.min(30, peaks * 30));
    }

    /**
     * Start device motion tracking
     */
    startMotionTracking() {
        if (!window.DeviceMotionEvent) {
            console.log('[BodyTracking] DeviceMotion not available');
            return false;
        }

        this.motionHandler = (event) => {
            const acc = event.accelerationIncludingGravity || event.acceleration || {};

            this.movementData.x = acc.x || 0;
            this.movementData.y = acc.y || 0;
            this.movementData.z = acc.z || 0;

            // Calculate magnitude
            const mag = Math.sqrt(
                this.movementData.x ** 2 +
                this.movementData.y ** 2 +
                this.movementData.z ** 2
            );

            this.movementData.magnitude = mag;
            this.movementData.isMoving = mag > 12;

            // Store in buffer
            this.motionBuffer.push({
                x: this.movementData.x,
                y: this.movementData.y,
                z: this.movementData.z,
                mag: mag
            });
            if (this.motionBuffer.length > this.bufferSize) {
                this.motionBuffer.shift();
            }

            // Detect gestures
            this.detectGesture();

            // Calculate energy level
            this.calculateEnergy();
        };

        window.addEventListener('devicemotion', this.motionHandler);
        console.log('[BodyTracking] Motion tracking started');
        return true;
    }

    /**
     * Detect gestures from motion data
     */
    detectGesture() {
        if (this.motionBuffer.length < 10) return;

        const recent = this.motionBuffer.slice(-10);
        const avgX = recent.reduce((a, b) => a + Math.abs(b.x), 0) / recent.length;
        const avgY = recent.reduce((a, b) => a + Math.abs(b.y), 0) / recent.length;
        const avgZ = recent.reduce((a, b) => a + Math.abs(b.z), 0) / recent.length;

        // Detect shake (high X movement)
        if (avgX > 15) {
            this.movementData.gestureType = 'shake';
        }
        // Detect nod (high Y movement)
        else if (avgY > 12) {
            this.movementData.gestureType = 'nod';
        }
        // Detect tilt (high Z change)
        else if (avgZ > 12) {
            this.movementData.gestureType = 'tilt';
        }
        // Stillness
        else if (avgX < 3 && avgY < 3 && avgZ < 3) {
            this.movementData.gestureType = 'stillness';
        } else {
            this.movementData.gestureType = null;
        }
    }

    /**
     * Calculate energy level from movement
     */
    calculateEnergy() {
        if (this.motionBuffer.length < 20) return;

        const recent = this.motionBuffer.slice(-20);
        const avgMag = recent.reduce((a, b) => a + b.mag, 0) / recent.length;

        // Normalize to 0-1
        // Low energy: ~10, High energy: ~30
        this.movementData.energy = Math.max(0, Math.min(1, (avgMag - 9.8) / 20));
    }

    /**
     * Get combined body data
     */
    getData() {
        return {
            face: { ...this.faceData },
            movement: { ...this.movementData },
            breathing: { ...this.breathingData },
            // Derived states
            arousal: this.calculateArousal(),
            relaxation: this.calculateRelaxation()
        };
    }

    /**
     * Calculate arousal level
     */
    calculateArousal() {
        // High smile + high movement + high energy = high arousal
        const smileFactor = this.faceData.smile * 0.3;
        const movementFactor = this.movementData.energy * 0.4;
        const breathFactor = Math.min(1, this.breathingData.rate / 20) * 0.3;

        return Math.min(1, smileFactor + movementFactor + breathFactor);
    }

    /**
     * Calculate relaxation level
     */
    calculateRelaxation() {
        // Low movement + slow breathing + stillness = relaxation
        const stillnessFactor = (1 - this.movementData.energy) * 0.4;
        const breathFactor = Math.max(0, 1 - this.breathingData.rate / 15) * 0.3;
        const faceFactor = (this.faceData.faceDetected ? 0.3 : 0);

        return Math.min(1, stillnessFactor + breathFactor + faceFactor);
    }

    /**
     * Add listener
     */
    addListener(callback) {
        this.listeners.push(callback);
    }

    /**
     * Notify listeners
     */
    notifyListeners() {
        const data = this.getData();
        this.listeners.forEach(cb => cb(data));
    }

    /**
     * Stop tracking
     */
    stop() {
        this.isRunning = false;

        if (this.interval) {
            clearInterval(this.interval);
            this.interval = null;
        }

        if (this.motionHandler) {
            window.removeEventListener('devicemotion', this.motionHandler);
            this.motionHandler = null;
        }

        if (this.video && this.video.srcObject) {
            this.video.srcObject.getTracks().forEach(track => track.stop());
        }

        this.video = null;
        this.canvas = null;
        this.ctx = null;

        console.log('[BodyTracking] Stopped');
    }

    /**
     * Destroy
     */
    destroy() {
        this.stop();
        this.listeners = [];
        this.brightnessBuffer = [];
        this.motionBuffer = [];
        this.headMovementBuffer = [];
    }
}

// Export
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { BodyTrackingEngine };
}
