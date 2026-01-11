/**
 * Echoelmusic WebApp - Wellness Engine
 * Extended bio data collection + wellness insights (NO HEALTH CLAIMS)
 *
 * DISCLAIMER: This is for creative, educational, and general wellness purposes only.
 * NOT a medical device. NOT medical advice. Consult healthcare professionals for health concerns.
 */

class WellnessEngine {
    constructor(bioEngine) {
        this.bioEngine = bioEngine;
        this.isRunning = false;

        // Extended bio data
        this.extendedData = {
            // From device sensors
            motion: { x: 0, y: 0, z: 0, isMoving: false, steps: 0 },
            light: { lux: 500, isNatural: true },
            position: { latitude: 0, longitude: 0, altitude: 0 },

            // Manual tracking
            mood: 5, // 1-10
            energy: 5, // 1-10
            sleep: { hours: 7, quality: 5 },
            water: 0, // ml
            exercise: 0, // minutes

            // Derived insights
            stress: 0.5, // 0-1
            relaxation: 0.5, // 0-1
            circadianPhase: 'day', // morning, day, evening, night
            coherenceStreak: 0, // minutes of high coherence
            breathingScore: 0 // 0-100

            // Movement patterns
            // posture: 'good' // good, slouching, lying
        };

        // Session stats
        this.sessionStart = null;
        this.highCoherenceMinutes = 0;
        this.breathingMinutes = 0;

        // Wellness tips database
        this.tips = this.loadTips();

        // Device sensor handlers
        this.motionHandler = null;
        this.lightSensor = null;
    }

    // ==================== DEVICE SENSORS ====================
    async startMotionTracking() {
        if (!window.DeviceMotionEvent) {
            console.log('[WellnessEngine] DeviceMotion not supported');
            return false;
        }

        // Request permission on iOS
        if (typeof DeviceMotionEvent.requestPermission === 'function') {
            const permission = await DeviceMotionEvent.requestPermission();
            if (permission !== 'granted') return false;
        }

        this.motionHandler = (event) => {
            const { x, y, z } = event.accelerationIncludingGravity || { x: 0, y: 0, z: 0 };
            const movement = Math.sqrt(x * x + y * y + z * z);

            this.extendedData.motion = {
                x: x || 0,
                y: y || 0,
                z: z || 0,
                isMoving: movement > 12,
                magnitude: movement
            };

            // Simple step detection (basic)
            if (movement > 15 && this.lastMotionMag && this.lastMotionMag < 12) {
                this.extendedData.motion.steps++;
            }
            this.lastMotionMag = movement;
        };

        window.addEventListener('devicemotion', this.motionHandler);
        console.log('[WellnessEngine] Motion tracking started');
        return true;
    }

    async startLightSensor() {
        if ('AmbientLightSensor' in window) {
            try {
                this.lightSensor = new AmbientLightSensor();
                this.lightSensor.addEventListener('reading', () => {
                    const lux = this.lightSensor.illuminance;
                    this.extendedData.light = {
                        lux,
                        isNatural: lux > 1000,
                        isDim: lux < 50,
                        circadianImpact: this.calculateCircadianImpact(lux)
                    };
                });
                this.lightSensor.start();
                console.log('[WellnessEngine] Light sensor started');
                return true;
            } catch (e) {
                console.log('[WellnessEngine] Light sensor not available:', e);
            }
        }

        // Fallback: estimate from time of day
        this.estimateLightFromTime();
        return false;
    }

    estimateLightFromTime() {
        setInterval(() => {
            const hour = new Date().getHours();
            let estimatedLux = 100;

            if (hour >= 6 && hour < 8) estimatedLux = 1000; // Morning
            else if (hour >= 8 && hour < 18) estimatedLux = 10000; // Day
            else if (hour >= 18 && hour < 20) estimatedLux = 500; // Evening
            else estimatedLux = 50; // Night

            this.extendedData.light = {
                lux: estimatedLux,
                isEstimated: true,
                circadianPhase: this.getCircadianPhase(hour)
            };
        }, 60000);
    }

    getCircadianPhase(hour) {
        if (hour >= 5 && hour < 9) return 'morning';
        if (hour >= 9 && hour < 17) return 'day';
        if (hour >= 17 && hour < 21) return 'evening';
        return 'night';
    }

    calculateCircadianImpact(lux) {
        // Blue light exposure affects melatonin
        // Higher lux during day = good, high lux at night = potentially disruptive
        const hour = new Date().getHours();
        if (hour >= 21 || hour < 6) {
            return lux > 100 ? 'alerting' : 'relaxing';
        }
        return lux > 1000 ? 'energizing' : 'neutral';
    }

    // ==================== STRESS & RELAXATION ESTIMATION ====================
    calculateStressLevel(bioData) {
        // Based on HRV patterns (lower HRV often correlates with stress)
        // This is a simplified estimation, NOT a medical measurement
        const { hrv, heartRate, coherence } = bioData;

        // Lower HRV = potentially higher stress
        const hrvFactor = Math.max(0, 1 - (hrv / 80));

        // Higher HR = potentially higher stress
        const hrFactor = Math.max(0, (heartRate - 60) / 60);

        // Lower coherence = potentially higher stress
        const coherenceFactor = 1 - coherence;

        // Weighted average
        const stress = hrvFactor * 0.4 + hrFactor * 0.3 + coherenceFactor * 0.3;

        this.extendedData.stress = Math.min(1, Math.max(0, stress));
        this.extendedData.relaxation = 1 - this.extendedData.stress;

        return this.extendedData.stress;
    }

    // ==================== BREATHING ANALYSIS ====================
    analyzeBreathing(bioData) {
        const { breathingRate, coherence } = bioData;

        // Optimal breathing is typically 4-7 breaths/min for relaxation
        // 6/min is the "coherence" breathing rate
        const optimalRate = 6;
        const rateDeviation = Math.abs(breathingRate - optimalRate);

        // Score based on rate closeness to optimal and coherence
        let score = 100;
        score -= rateDeviation * 10; // Penalize deviation from optimal
        score *= coherence; // Scale by coherence

        this.extendedData.breathingScore = Math.max(0, Math.min(100, score));

        return {
            rate: breathingRate,
            score: this.extendedData.breathingScore,
            suggestion: this.getBreathingSuggestion(breathingRate)
        };
    }

    getBreathingSuggestion(rate) {
        if (rate < 4) return 'Your breathing seems very slow. This can be deeply relaxing.';
        if (rate < 8) return 'Excellent! Your breathing rate supports heart-brain coherence.';
        if (rate < 12) return 'Normal breathing rate. Try slowing down for deeper relaxation.';
        if (rate < 16) return 'Slightly elevated breathing. Consider a calming breath practice.';
        return 'Rapid breathing detected. A slow exhale practice may help.';
    }

    // ==================== MANUAL TRACKING ====================
    setMood(value) {
        this.extendedData.mood = Math.max(1, Math.min(10, value));
    }

    setEnergy(value) {
        this.extendedData.energy = Math.max(1, Math.min(10, value));
    }

    logSleep(hours, quality) {
        this.extendedData.sleep = {
            hours: Math.max(0, Math.min(24, hours)),
            quality: Math.max(1, Math.min(10, quality)),
            timestamp: new Date().toISOString()
        };
    }

    logWater(ml) {
        this.extendedData.water += ml;
    }

    logExercise(minutes) {
        this.extendedData.exercise += minutes;
    }

    // ==================== SESSION TRACKING ====================
    startSession() {
        this.sessionStart = Date.now();
        this.highCoherenceMinutes = 0;
        this.breathingMinutes = 0;
        this.isRunning = true;

        // Track coherence over time
        this.coherenceInterval = setInterval(() => {
            if (this.bioEngine && this.bioEngine.data.coherence > 0.6) {
                this.highCoherenceMinutes += 1 / 60; // Add fraction of minute
                this.extendedData.coherenceStreak += 1 / 60;
            } else {
                this.extendedData.coherenceStreak = 0;
            }

            // Calculate stress from bio data
            if (this.bioEngine) {
                this.calculateStressLevel(this.bioEngine.data);
                this.analyzeBreathing(this.bioEngine.data);
            }
        }, 1000);
    }

    endSession() {
        this.isRunning = false;
        if (this.coherenceInterval) {
            clearInterval(this.coherenceInterval);
        }

        const sessionDuration = (Date.now() - this.sessionStart) / 60000; // minutes

        return {
            duration: sessionDuration,
            highCoherenceMinutes: this.highCoherenceMinutes,
            coherencePercentage: (this.highCoherenceMinutes / sessionDuration) * 100,
            averageBreathingScore: this.extendedData.breathingScore
        };
    }

    // ==================== WELLNESS TIPS DATABASE ====================
    loadTips() {
        return {
            breathing: [
                { tip: 'Try breathing at 6 breaths per minute for heart-brain coherence.', source: 'HeartMath Research' },
                { tip: 'Extended exhales activate the relaxation response.', source: 'Polyvagal Theory' },
                { tip: 'Box breathing (4-4-4-4) is used by Navy SEALs for stress management.', source: 'Common Practice' },
                { tip: '4-7-8 breathing before sleep may support relaxation.', source: 'Dr. Andrew Weil' },
                { tip: 'Coherent breathing synchronizes heart rate variability patterns.', source: 'HeartMath Institute' }
            ],
            movement: [
                { tip: 'Even 5 minutes of walking can shift your mental state.', source: 'Exercise Science' },
                { tip: 'Standing and stretching every 30 minutes supports circulation.', source: 'Ergonomics Research' },
                { tip: 'Dancing combines movement, music, and social connection.', source: 'Wellness Studies' },
                { tip: 'Nature walks combine movement with restorative environments.', source: 'Environmental Psychology' }
            ],
            circadian: [
                { tip: 'Morning light exposure supports natural wake cycles.', source: 'Circadian Biology' },
                { tip: 'Reducing blue light 2 hours before bed may support sleep.', source: 'Sleep Research' },
                { tip: 'Consistent sleep/wake times help regulate internal rhythms.', source: 'Sleep Science' },
                { tip: 'The circadian low point is typically 2-4 PM.', source: 'Chronobiology' }
            ],
            blueZone: [
                { tip: 'Blue Zone populations prioritize family and community.', source: 'Dan Buettner' },
                { tip: 'Natural movement throughout the day is a Blue Zone pattern.', source: 'Blue Zones Research' },
                { tip: 'Plant-forward eating is common in longevity hotspots.', source: 'Blue Zones' },
                { tip: 'Having a sense of purpose (Ikigai) is associated with longevity.', source: 'Okinawa Studies' },
                { tip: 'Moderate caloric intake is common in long-lived populations.', source: 'Longevity Research' }
            ],
            coherence: [
                { tip: 'Heart-focused breathing combined with positive emotions increases coherence.', source: 'HeartMath' },
                { tip: 'Gratitude practices are associated with increased HRV.', source: 'Positive Psychology' },
                { tip: 'Regular coherence practice may improve with consistency.', source: 'Biofeedback Studies' },
                { tip: 'Coherent states are associated with clearer thinking.', source: 'HeartMath Research' }
            ],
            hydration: [
                { tip: 'Hydration affects cognitive performance.', source: 'Nutrition Science' },
                { tip: 'Thirst is a late indicator of dehydration.', source: 'Physiology' },
                { tip: 'Water intake needs vary by activity level and climate.', source: 'Sports Science' }
            ],
            general: [
                { tip: 'Small consistent habits often outperform sporadic intense efforts.', source: 'Behavioral Science' },
                { tip: 'Self-compassion supports long-term wellbeing goals.', source: 'Psychology Research' },
                { tip: 'Social connection is one of the strongest wellbeing predictors.', source: 'Longevity Studies' }
            ]
        };
    }

    // ==================== CONTEXTUAL TIP SELECTION ====================
    getTip(category = null) {
        // Select tip based on current state if no category specified
        if (!category) {
            category = this.selectTipCategory();
        }

        const categoryTips = this.tips[category] || this.tips.general;
        const randomTip = categoryTips[Math.floor(Math.random() * categoryTips.length)];

        return {
            category,
            ...randomTip,
            disclaimer: 'For educational purposes only. Not medical advice.'
        };
    }

    selectTipCategory() {
        // Context-aware tip selection
        const hour = new Date().getHours();
        const { stress, coherenceStreak, breathingScore } = this.extendedData;
        const bioData = this.bioEngine?.data || {};

        // Morning: circadian tips
        if (hour >= 5 && hour < 9) return 'circadian';

        // High stress: breathing tips
        if (stress > 0.7) return 'breathing';

        // Low coherence: coherence tips
        if (bioData.coherence < 0.4) return 'coherence';

        // Low energy: movement tips
        if (this.extendedData.energy < 4) return 'movement';

        // Default rotation
        const categories = ['blueZone', 'breathing', 'movement', 'general'];
        return categories[Math.floor(Math.random() * categories.length)];
    }

    // Get multiple tips for a session
    getSessionTips(count = 3) {
        const tips = [];
        const usedCategories = new Set();

        while (tips.length < count) {
            let category = this.selectTipCategory();
            // Ensure variety
            if (usedCategories.has(category) && usedCategories.size < Object.keys(this.tips).length) {
                const available = Object.keys(this.tips).filter(c => !usedCategories.has(c));
                category = available[Math.floor(Math.random() * available.length)];
            }
            usedCategories.add(category);
            tips.push(this.getTip(category));
        }

        return tips;
    }

    // ==================== DATA EXPORT ====================
    getExtendedData() {
        return {
            ...this.extendedData,
            bioData: this.bioEngine?.getData(),
            sessionActive: this.isRunning,
            sessionDuration: this.sessionStart ? (Date.now() - this.sessionStart) / 60000 : 0,
            timestamp: new Date().toISOString()
        };
    }

    // ==================== CLEANUP ====================
    stop() {
        if (this.motionHandler) {
            window.removeEventListener('devicemotion', this.motionHandler);
        }
        if (this.lightSensor) {
            this.lightSensor.stop();
        }
        if (this.coherenceInterval) {
            clearInterval(this.coherenceInterval);
        }
        this.isRunning = false;
    }

    // ==================== DISCLAIMER ====================
    static getDisclaimer() {
        return {
            short: 'For creative and educational purposes only. Not medical advice.',
            full: `DISCLAIMER: Echoelmusic wellness features are designed for creative expression,
                   general wellness, and educational purposes only. This is NOT a medical device.
                   The biometric data displayed is for informational and creative purposes and
                   should NOT be used for medical decisions. Heart rate, HRV, and other measurements
                   may not be accurate and are not validated for clinical use.

                   Wellness tips are general information gathered from publicly available sources
                   and do not constitute medical advice. Always consult qualified healthcare
                   professionals for health concerns.

                   If you experience any discomfort, dizziness, or adverse effects during
                   breathing exercises or biofeedback sessions, stop immediately and consult
                   a healthcare provider.`
        };
    }
}

// Export
if (typeof module !== 'undefined' && module.exports) {
    module.exports = WellnessEngine;
}
