/**
 * PresetsEngine - Preset Management System
 * Matches native app preset library
 *
 * Categories:
 * - Bio-Reactive: Meditation, flow states, wellness
 * - Musical: Genres and styles
 * - Visual: Visualization presets
 * - Lighting: DMX/LED presets (for future)
 * - Streaming: Platform-specific presets
 * - Collaboration: Session presets
 */

class PresetsEngine {
    constructor() {
        // All presets organized by category
        this.presets = this.loadAllPresets();

        // User custom presets
        this.userPresets = this.loadUserPresets();

        // Currently active preset
        this.activePreset = null;

        // Listeners
        this.listeners = [];
    }

    /**
     * Initialize engine
     */
    async init() {
        console.log('[PresetsEngine] Initializing with', Object.keys(this.presets).length, 'categories');
        return this;
    }

    /**
     * Load all built-in presets
     */
    loadAllPresets() {
        return {
            // ========== BIO-REACTIVE PRESETS ==========
            bioReactive: [
                {
                    id: 'deep-meditation',
                    name: 'Deep Meditation',
                    nameDE: 'Tiefe Meditation',
                    description: 'Calm, slow breathing with theta-inducing binaural beats',
                    category: 'bioReactive',
                    settings: {
                        breathing: { pattern: 'coherence', rate: 5 },
                        audio: { binauralBeat: 6, carrierFreq: 432, filterCutoff: 0.3, reverb: 0.6 },
                        visual: { mode: 'mandala', intensity: 0.4, speed: 0.3 },
                        bioMapping: { coherenceToFilter: 0.8, hrvToReverb: 0.6 }
                    }
                },
                {
                    id: 'active-flow',
                    name: 'Active Flow',
                    nameDE: 'Aktiver Flow',
                    description: 'Energetic state for creative work and focus',
                    category: 'bioReactive',
                    settings: {
                        breathing: { pattern: 'energizing', rate: 12 },
                        audio: { binauralBeat: 14, carrierFreq: 440, filterCutoff: 0.7, reverb: 0.3 },
                        visual: { mode: 'particles', intensity: 0.7, speed: 0.6 },
                        bioMapping: { coherenceToFilter: 0.6, hrvToReverb: 0.4 }
                    }
                },
                {
                    id: 'zen-master',
                    name: 'Zen Master',
                    nameDE: 'Zen Meister',
                    description: 'Deep alpha state for peaceful awareness',
                    category: 'bioReactive',
                    settings: {
                        breathing: { pattern: 'coherence', rate: 6 },
                        audio: { binauralBeat: 10, carrierFreq: 432, filterCutoff: 0.4, reverb: 0.7 },
                        visual: { mode: 'sacredGeometry', intensity: 0.5, speed: 0.2 },
                        bioMapping: { coherenceToFilter: 0.9, hrvToReverb: 0.7 }
                    }
                },
                {
                    id: 'sleep-prep',
                    name: 'Sleep Preparation',
                    nameDE: 'Schlafvorbereitung',
                    description: 'Delta waves for deep relaxation before sleep',
                    category: 'bioReactive',
                    settings: {
                        breathing: { pattern: '4-7-8', rate: 4 },
                        audio: { binauralBeat: 2, carrierFreq: 396, filterCutoff: 0.2, reverb: 0.8 },
                        visual: { mode: 'aurora', intensity: 0.3, speed: 0.1 },
                        bioMapping: { coherenceToFilter: 0.5, hrvToReverb: 0.8 }
                    }
                },
                {
                    id: 'morning-energy',
                    name: 'Morning Energy',
                    nameDE: 'Morgen Energie',
                    description: 'Beta waves for alertness and motivation',
                    category: 'bioReactive',
                    settings: {
                        breathing: { pattern: 'energizing', rate: 15 },
                        audio: { binauralBeat: 20, carrierFreq: 528, filterCutoff: 0.8, reverb: 0.2 },
                        visual: { mode: 'cosmic', intensity: 0.8, speed: 0.7 },
                        bioMapping: { coherenceToFilter: 0.5, hrvToReverb: 0.3 }
                    }
                },
                {
                    id: 'stress-relief',
                    name: 'Stress Relief',
                    nameDE: 'Stressabbau',
                    description: 'Calming patterns for anxiety reduction',
                    category: 'bioReactive',
                    settings: {
                        breathing: { pattern: 'calming', rate: 6 },
                        audio: { binauralBeat: 8, carrierFreq: 417, filterCutoff: 0.35, reverb: 0.65 },
                        visual: { mode: 'coherence', intensity: 0.5, speed: 0.25 },
                        bioMapping: { coherenceToFilter: 0.7, hrvToReverb: 0.6 }
                    }
                },
                {
                    id: 'heart-coherence',
                    name: 'Heart Coherence',
                    nameDE: 'Herz-Kohärenz',
                    description: 'HeartMath-style coherence training',
                    category: 'bioReactive',
                    settings: {
                        breathing: { pattern: 'coherence', rate: 6 },
                        audio: { binauralBeat: 10, carrierFreq: 432, filterCutoff: 0.5, reverb: 0.5 },
                        visual: { mode: 'coherence', intensity: 0.6, speed: 0.3 },
                        bioMapping: { coherenceToFilter: 1.0, hrvToReverb: 0.5 }
                    }
                },
                {
                    id: 'gamma-peak',
                    name: 'Gamma Peak',
                    nameDE: 'Gamma Spitze',
                    description: 'High gamma for peak cognitive performance',
                    category: 'bioReactive',
                    settings: {
                        breathing: { pattern: 'box', rate: 8 },
                        audio: { binauralBeat: 40, carrierFreq: 528, filterCutoff: 0.9, reverb: 0.15 },
                        visual: { mode: 'quantum', intensity: 0.9, speed: 0.8 },
                        bioMapping: { coherenceToFilter: 0.6, hrvToReverb: 0.2 }
                    }
                },
                {
                    id: 'creativity-boost',
                    name: 'Creativity Boost',
                    nameDE: 'Kreativitäts-Boost',
                    description: 'Theta-alpha border for creative insights',
                    category: 'bioReactive',
                    settings: {
                        breathing: { pattern: 'coherence', rate: 7 },
                        audio: { binauralBeat: 7.5, carrierFreq: 432, filterCutoff: 0.55, reverb: 0.5 },
                        visual: { mode: 'mandala', intensity: 0.6, speed: 0.4 },
                        bioMapping: { coherenceToFilter: 0.75, hrvToReverb: 0.55 }
                    }
                },
                {
                    id: 'quantum-coherence',
                    name: 'Quantum Coherence',
                    nameDE: 'Quanten-Kohärenz',
                    description: 'Inspired by quantum physics visualization',
                    category: 'bioReactive',
                    settings: {
                        breathing: { pattern: 'coherence', rate: 6 },
                        audio: { binauralBeat: 7.83, carrierFreq: 432, filterCutoff: 0.5, reverb: 0.6 },
                        visual: { mode: 'quantum', intensity: 0.7, speed: 0.35 },
                        bioMapping: { coherenceToFilter: 0.85, hrvToReverb: 0.6 }
                    }
                }
            ],

            // ========== MUSICAL PRESETS ==========
            musical: [
                {
                    id: 'ambient-drone',
                    name: 'Ambient Drone',
                    nameDE: 'Ambient Drone',
                    description: 'Evolving pad textures and subtle movement',
                    category: 'musical',
                    settings: {
                        audio: { waveform: 'sine', filterCutoff: 0.3, filterRes: 0.2, attack: 2.0, release: 4.0, reverb: 0.7 },
                        sequencer: { bpm: 60, pattern: 'ambient' }
                    }
                },
                {
                    id: 'techno-minimal',
                    name: 'Techno Minimal',
                    nameDE: 'Minimal Techno',
                    description: 'Driving beats with hypnotic patterns',
                    category: 'musical',
                    settings: {
                        audio: { waveform: 'sawtooth', filterCutoff: 0.6, filterRes: 0.4, attack: 0.01, release: 0.3, reverb: 0.2 },
                        sequencer: { bpm: 128, pattern: 'fourOnFloor' }
                    }
                },
                {
                    id: 'neo-classical',
                    name: 'Neo-Classical',
                    nameDE: 'Neo-Klassik',
                    description: 'Piano-like tones with orchestral reverb',
                    category: 'musical',
                    settings: {
                        audio: { waveform: 'triangle', filterCutoff: 0.8, filterRes: 0.1, attack: 0.02, release: 1.5, reverb: 0.6 },
                        sequencer: { bpm: 72, pattern: 'minimal' }
                    }
                },
                {
                    id: 'future-bass',
                    name: 'Future Bass',
                    nameDE: 'Future Bass',
                    description: 'Wobbly synths with sidechain feel',
                    category: 'musical',
                    settings: {
                        audio: { waveform: 'sawtooth', filterCutoff: 0.7, filterRes: 0.5, attack: 0.01, release: 0.2, reverb: 0.35 },
                        sequencer: { bpm: 140, pattern: 'breakbeat' }
                    }
                },
                {
                    id: 'lo-fi-chill',
                    name: 'Lo-Fi Chill',
                    nameDE: 'Lo-Fi Chill',
                    description: 'Warm, dusty beats for studying',
                    category: 'musical',
                    settings: {
                        audio: { waveform: 'triangle', filterCutoff: 0.4, filterRes: 0.15, attack: 0.05, release: 0.8, reverb: 0.4 },
                        sequencer: { bpm: 85, pattern: 'minimal' }
                    }
                },
                {
                    id: 'trap-808',
                    name: 'Trap 808',
                    nameDE: 'Trap 808',
                    description: 'Heavy 808s and rolling hi-hats',
                    category: 'musical',
                    settings: {
                        audio: { waveform: 'sine', filterCutoff: 0.9, filterRes: 0.3, attack: 0.001, release: 0.5, reverb: 0.15 },
                        sequencer: { bpm: 140, pattern: 'trap' }
                    }
                },
                {
                    id: 'synthwave',
                    name: 'Synthwave',
                    nameDE: 'Synthwave',
                    description: '80s-inspired retro synths',
                    category: 'musical',
                    settings: {
                        audio: { waveform: 'sawtooth', filterCutoff: 0.65, filterRes: 0.35, attack: 0.1, release: 0.6, reverb: 0.45 },
                        sequencer: { bpm: 118, pattern: 'fourOnFloor' }
                    }
                },
                {
                    id: 'dnb-liquid',
                    name: 'Liquid DnB',
                    nameDE: 'Liquid DnB',
                    description: 'Smooth drum and bass vibes',
                    category: 'musical',
                    settings: {
                        audio: { waveform: 'sine', filterCutoff: 0.5, filterRes: 0.25, attack: 0.02, release: 0.4, reverb: 0.5 },
                        sequencer: { bpm: 174, pattern: 'breakbeat' }
                    }
                },
                {
                    id: 'downtempo',
                    name: 'Downtempo',
                    nameDE: 'Downtempo',
                    description: 'Laid-back grooves with space',
                    category: 'musical',
                    settings: {
                        audio: { waveform: 'triangle', filterCutoff: 0.45, filterRes: 0.2, attack: 0.08, release: 1.0, reverb: 0.55 },
                        sequencer: { bpm: 90, pattern: 'minimal' }
                    }
                },
                {
                    id: 'experimental',
                    name: 'Experimental',
                    nameDE: 'Experimentell',
                    description: 'Unpredictable textures and glitches',
                    category: 'musical',
                    settings: {
                        audio: { waveform: 'square', filterCutoff: 0.6, filterRes: 0.6, attack: 0.001, release: 0.1, reverb: 0.3 },
                        sequencer: { bpm: 110, pattern: 'ambient' }
                    }
                }
            ],

            // ========== VISUAL PRESETS ==========
            visual: [
                {
                    id: 'sacred-mandala',
                    name: 'Sacred Mandala',
                    nameDE: 'Heiliges Mandala',
                    description: 'Traditional mandala patterns',
                    category: 'visual',
                    settings: { visual: { mode: 'mandala', intensity: 0.7, speed: 0.3, colorScheme: 'warm' } }
                },
                {
                    id: 'cosmic-nebula',
                    name: 'Cosmic Nebula',
                    nameDE: 'Kosmischer Nebel',
                    description: 'Deep space particle clouds',
                    category: 'visual',
                    settings: { visual: { mode: 'cosmic', intensity: 0.8, speed: 0.4, colorScheme: 'cosmic' } }
                },
                {
                    id: 'quantum-field',
                    name: 'Quantum Field',
                    nameDE: 'Quantenfeld',
                    description: 'Quantum probability visualizations',
                    category: 'visual',
                    settings: { visual: { mode: 'quantum', intensity: 0.75, speed: 0.5, colorScheme: 'quantum' } }
                },
                {
                    id: 'particle-flow',
                    name: 'Particle Flow',
                    nameDE: 'Partikel-Fluss',
                    description: 'Flowing particle systems',
                    category: 'visual',
                    settings: { visual: { mode: 'particles', intensity: 0.65, speed: 0.55, colorScheme: 'cool' } }
                },
                {
                    id: 'spectrum-bars',
                    name: 'Spectrum Bars',
                    nameDE: 'Spektrum-Balken',
                    description: 'Classic frequency analyzer',
                    category: 'visual',
                    settings: { visual: { mode: 'spectrum', intensity: 0.9, speed: 0.7, colorScheme: 'rainbow' } }
                },
                {
                    id: 'flower-of-life',
                    name: 'Flower of Life',
                    nameDE: 'Blume des Lebens',
                    description: 'Sacred geometry patterns',
                    category: 'visual',
                    settings: { visual: { mode: 'sacredGeometry', intensity: 0.6, speed: 0.25, colorScheme: 'gold' } }
                },
                {
                    id: 'aurora-borealis',
                    name: 'Aurora Borealis',
                    nameDE: 'Nordlichter',
                    description: 'Northern lights simulation',
                    category: 'visual',
                    settings: { visual: { mode: 'aurora', intensity: 0.7, speed: 0.35, colorScheme: 'aurora' } }
                },
                {
                    id: 'cymatics-plate',
                    name: 'Cymatics Plate',
                    nameDE: 'Kymatik-Platte',
                    description: 'Sound visualization on vibrating plate',
                    category: 'visual',
                    settings: { visual: { mode: 'cymatics', intensity: 0.8, speed: 0.5, colorScheme: 'mono' } }
                },
                {
                    id: 'coherence-meter',
                    name: 'Coherence Focus',
                    nameDE: 'Kohärenz-Fokus',
                    description: 'Bio-feedback centered display',
                    category: 'visual',
                    settings: { visual: { mode: 'coherence', intensity: 0.6, speed: 0.3, colorScheme: 'bio' } }
                },
                {
                    id: 'waveform-scope',
                    name: 'Waveform Scope',
                    nameDE: 'Wellenform-Oszilloskop',
                    description: 'Audio oscilloscope display',
                    category: 'visual',
                    settings: { visual: { mode: 'waveform', intensity: 0.85, speed: 0.8, colorScheme: 'neon' } }
                }
            ],

            // ========== STREAMING PRESETS ==========
            streaming: [
                {
                    id: 'youtube-4k',
                    name: 'YouTube Premium 4K',
                    nameDE: 'YouTube Premium 4K',
                    description: 'Optimized for YouTube Live',
                    category: 'streaming',
                    settings: { stream: { platform: 'youtube', resolution: '4K', bitrate: 20000, fps: 60 } }
                },
                {
                    id: 'twitch-low-latency',
                    name: 'Twitch Low Latency',
                    nameDE: 'Twitch Niedrige Latenz',
                    description: 'Optimized for Twitch interactive',
                    category: 'streaming',
                    settings: { stream: { platform: 'twitch', resolution: '1080p', bitrate: 6000, fps: 60, lowLatency: true } }
                },
                {
                    id: 'instagram-vertical',
                    name: 'Instagram Live',
                    nameDE: 'Instagram Live',
                    description: 'Vertical format for mobile viewers',
                    category: 'streaming',
                    settings: { stream: { platform: 'instagram', resolution: '1080x1920', bitrate: 4000, fps: 30 } }
                },
                {
                    id: 'tiktok-short',
                    name: 'TikTok Live',
                    nameDE: 'TikTok Live',
                    description: 'High energy short format',
                    category: 'streaming',
                    settings: { stream: { platform: 'tiktok', resolution: '720x1280', bitrate: 3000, fps: 30 } }
                },
                {
                    id: 'webrtc-p2p',
                    name: 'WebRTC P2P',
                    nameDE: 'WebRTC P2P',
                    description: 'Direct peer-to-peer streaming',
                    category: 'streaming',
                    settings: { stream: { platform: 'webrtc', resolution: '1080p', bitrate: 4000, fps: 30, p2p: true } }
                }
            ],

            // ========== COLLABORATION PRESETS ==========
            collaboration: [
                {
                    id: 'music-jam',
                    name: 'Music Jam Session',
                    nameDE: 'Musik-Jam Session',
                    description: 'Real-time collaborative music making',
                    category: 'collaboration',
                    settings: { sync: { mode: 'lowLatency', audioSync: true, midiSync: true, maxPeers: 8 } }
                },
                {
                    id: 'wellness-circle',
                    name: 'Wellness Circle',
                    nameDE: 'Wellness-Kreis',
                    description: 'Group meditation and coherence',
                    category: 'collaboration',
                    settings: { sync: { mode: 'coherence', bioSync: true, visualSync: true, maxPeers: 100 } }
                },
                {
                    id: 'art-studio',
                    name: 'Art Studio',
                    nameDE: 'Kunst-Studio',
                    description: 'Collaborative visual creation',
                    category: 'collaboration',
                    settings: { sync: { mode: 'visual', visualSync: true, parameterSync: true, maxPeers: 16 } }
                },
                {
                    id: 'research-lab',
                    name: 'Research Lab',
                    nameDE: 'Forschungslabor',
                    description: 'Data collection and analysis',
                    category: 'collaboration',
                    settings: { sync: { mode: 'data', bioSync: true, recording: true, maxPeers: 50 } }
                },
                {
                    id: 'global-coherence',
                    name: 'Global Coherence',
                    nameDE: 'Globale Kohärenz',
                    description: 'Worldwide coherence synchronization',
                    category: 'collaboration',
                    settings: { sync: { mode: 'global', bioSync: true, visualSync: true, maxPeers: 1000 } }
                }
            ]
        };
    }

    /**
     * Load user presets from localStorage
     */
    loadUserPresets() {
        try {
            const stored = localStorage.getItem('echoelmusic_user_presets');
            return stored ? JSON.parse(stored) : [];
        } catch (e) {
            return [];
        }
    }

    /**
     * Save user presets to localStorage
     */
    saveUserPresets() {
        try {
            localStorage.setItem('echoelmusic_user_presets', JSON.stringify(this.userPresets));
        } catch (e) {
            console.warn('[PresetsEngine] Could not save user presets:', e);
        }
    }

    /**
     * Get all presets by category
     */
    getPresetsByCategory(category) {
        return this.presets[category] || [];
    }

    /**
     * Get all categories
     */
    getCategories() {
        return Object.keys(this.presets);
    }

    /**
     * Get preset by ID
     */
    getPreset(id) {
        for (const category of Object.values(this.presets)) {
            const preset = category.find(p => p.id === id);
            if (preset) return preset;
        }
        return this.userPresets.find(p => p.id === id) || null;
    }

    /**
     * Apply preset
     */
    applyPreset(presetId, engines = {}) {
        const preset = this.getPreset(presetId);
        if (!preset) {
            console.warn('[PresetsEngine] Preset not found:', presetId);
            return false;
        }

        console.log('[PresetsEngine] Applying preset:', preset.name);
        this.activePreset = preset;

        const { settings } = preset;

        // Apply audio settings
        if (settings.audio && engines.audioEngine) {
            const audio = engines.audioEngine;
            if (settings.audio.filterCutoff !== undefined) {
                audio.setFilterCutoff?.(settings.audio.filterCutoff);
            }
            if (settings.audio.reverb !== undefined) {
                audio.setReverbMix?.(settings.audio.reverb);
            }
            if (settings.audio.binauralBeat !== undefined) {
                audio.setBinauralBeat?.(settings.audio.binauralBeat, settings.audio.carrierFreq || 432);
            }
        }

        // Apply visual settings
        if (settings.visual && engines.visualEngine) {
            const visual = engines.visualEngine;
            visual.setMode?.(settings.visual.mode);
        }

        // Apply sequencer settings
        if (settings.sequencer && engines.sequencer) {
            const seq = engines.sequencer;
            if (settings.sequencer.bpm !== undefined) {
                seq.setBPM?.(settings.sequencer.bpm);
            }
            if (settings.sequencer.pattern !== undefined) {
                seq.loadPreset?.(settings.sequencer.pattern);
            }
        }

        // Apply breathing settings
        if (settings.breathing && engines.bioEngine) {
            const bio = engines.bioEngine;
            if (settings.breathing.pattern !== undefined) {
                bio.setBreathingPattern?.(settings.breathing.pattern);
            }
        }

        // Notify listeners
        this.notifyListeners('presetApplied', preset);

        return true;
    }

    /**
     * Create user preset from current settings
     */
    createUserPreset(name, currentSettings) {
        const id = 'user_' + Date.now().toString(36);

        const preset = {
            id,
            name,
            nameDE: name,
            description: 'Custom preset',
            category: 'user',
            settings: currentSettings,
            createdAt: Date.now()
        };

        this.userPresets.push(preset);
        this.saveUserPresets();

        this.notifyListeners('presetCreated', preset);
        return preset;
    }

    /**
     * Delete user preset
     */
    deleteUserPreset(id) {
        const index = this.userPresets.findIndex(p => p.id === id);
        if (index > -1) {
            const preset = this.userPresets.splice(index, 1)[0];
            this.saveUserPresets();
            this.notifyListeners('presetDeleted', preset);
            return true;
        }
        return false;
    }

    /**
     * Get all presets (including user)
     */
    getAllPresets() {
        const all = [];
        for (const category of Object.keys(this.presets)) {
            all.push(...this.presets[category]);
        }
        all.push(...this.userPresets);
        return all;
    }

    /**
     * Search presets
     */
    searchPresets(query) {
        const q = query.toLowerCase();
        return this.getAllPresets().filter(p =>
            p.name.toLowerCase().includes(q) ||
            (p.nameDE && p.nameDE.toLowerCase().includes(q)) ||
            (p.description && p.description.toLowerCase().includes(q))
        );
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
    notifyListeners(event, data) {
        this.listeners.forEach(cb => cb({ event, data }));
    }

    /**
     * Get active preset
     */
    getActivePreset() {
        return this.activePreset;
    }

    /**
     * Export preset
     */
    exportPreset(id) {
        const preset = this.getPreset(id);
        if (preset) {
            return JSON.stringify(preset, null, 2);
        }
        return null;
    }

    /**
     * Import preset
     */
    importPreset(jsonString) {
        try {
            const preset = JSON.parse(jsonString);
            preset.id = 'imported_' + Date.now().toString(36);
            preset.category = 'user';
            this.userPresets.push(preset);
            this.saveUserPresets();
            return preset;
        } catch (e) {
            console.error('[PresetsEngine] Import failed:', e);
            return null;
        }
    }
}

// Export for module use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { PresetsEngine };
}
