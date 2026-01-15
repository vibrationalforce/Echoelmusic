/**
 * Echoelmusic Web Module
 *
 * Bio-reactive audio synthesis for web browsers.
 * Ralph Wiggum Genius Mode - Nobel Prize Quality
 *
 * Features:
 * - Web Audio API synthesis (16-voice polyphonic)
 * - Bio-metric simulation for demos
 * - Real-time visualization support
 * - MIDI input support (Web MIDI API)
 *
 * Browser Requirements:
 * - Chrome 66+ / Firefox 76+ / Safari 14.1+ / Edge 79+
 * - AudioContext support
 * - Float32Array support
 *
 * Created: 2026-01-15
 */

// ============================================================================
// MARK: - Audio Module
// ============================================================================

export {
    AudioEngine,
    createAudioEngine,
    noteToFrequency,
    frequencyToNote,
    noteToName,
    NOTE_NAMES
} from './audio/AudioEngine';

export type {
    Waveform,
    EnvelopeParams,
    FilterParams,
    VoiceParams,
    BioModulation
} from './audio/AudioEngine';

// ============================================================================
// MARK: - Bio Module
// ============================================================================

export {
    BioSimulator,
    BreathingGuide,
    createBioSimulator,
    createBreathingGuide,
    BREATHING_PATTERNS
} from './bio/BioSimulator';

export type {
    BiometricData,
    BiometricState,
    BioSimulatorConfig,
    BiometricCallback,
    BreathingPattern
} from './bio/BioSimulator';

// ============================================================================
// MARK: - AudioWorklet Module (Low-Latency)
// ============================================================================

export {
    EchoelmusicWorkletNode,
    createWorkletSynth,
    isAudioWorkletSupported,
    getAudioLatencyInfo,
    WORKLET_PROCESSOR_CODE
} from './audio/AudioWorklet';

export type {
    WorkletMessage,
    VoiceState
} from './audio/AudioWorklet';

// ============================================================================
// MARK: - Version Info
// ============================================================================

export const VERSION = '1.0.0';
export const BUILD_DATE = '2026-01-15';
export const PLATFORM = 'web';

// ============================================================================
// MARK: - Quick Start Helper
// ============================================================================

/**
 * Quick start function to initialize Echoelmusic Web
 *
 * @example
 * ```typescript
 * const { audioEngine, bioSimulator } = await quickStart();
 *
 * // Play a note
 * audioEngine.noteOn(60, 100);
 *
 * // Subscribe to bio data
 * bioSimulator.onData((data) => {
 *     console.log('Heart Rate:', data.heartRate);
 *     audioEngine.setBioModulation(data);
 * });
 * ```
 */
export async function quickStart() {
    const { createAudioEngine, createBioSimulator } = await import('./index');

    const audioEngine = await createAudioEngine();
    if (!audioEngine) {
        throw new Error('Failed to initialize AudioEngine');
    }

    const bioSimulator = createBioSimulator('calm');
    bioSimulator.start();

    // Connect bio data to audio engine
    bioSimulator.onData((data) => {
        audioEngine.setBioModulation({
            heartRate: data.heartRate,
            hrvCoherence: data.hrvCoherence,
            breathingRate: data.breathingRate,
            breathPhase: data.breathPhase
        });
    });

    // Enable bio modulation
    audioEngine.setBioModulationEnabled(true);

    return {
        audioEngine,
        bioSimulator,
        dispose: () => {
            bioSimulator.dispose();
            audioEngine.dispose();
        }
    };
}

// ============================================================================
// MARK: - Browser Compatibility Check
// ============================================================================

export interface BrowserCapabilities {
    audioContext: boolean;
    audioWorklet: boolean;
    webMidi: boolean;
    webGL: boolean;
    webGPU: boolean;
    float32Array: boolean;
}

export function checkBrowserCapabilities(): BrowserCapabilities {
    return {
        audioContext: typeof AudioContext !== 'undefined' || typeof (window as any).webkitAudioContext !== 'undefined',
        audioWorklet: typeof AudioWorkletNode !== 'undefined',
        webMidi: typeof navigator !== 'undefined' && 'requestMIDIAccess' in navigator,
        webGL: (() => {
            try {
                const canvas = document.createElement('canvas');
                return !!(canvas.getContext('webgl') || canvas.getContext('experimental-webgl'));
            } catch {
                return false;
            }
        })(),
        webGPU: typeof navigator !== 'undefined' && 'gpu' in navigator,
        float32Array: typeof Float32Array !== 'undefined'
    };
}

export function isSupported(): boolean {
    const caps = checkBrowserCapabilities();
    return caps.audioContext && caps.float32Array;
}

// ============================================================================
// MARK: - Console Banner
// ============================================================================

export function printBanner(): void {
    console.log(`
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   ███████╗ ██████╗██╗  ██╗ ██████╗ ███████╗██╗                ║
    ║   ██╔════╝██╔════╝██║  ██║██╔═══██╗██╔════╝██║                ║
    ║   █████╗  ██║     ███████║██║   ██║█████╗  ██║                ║
    ║   ██╔══╝  ██║     ██╔══██║██║   ██║██╔══╝  ██║                ║
    ║   ███████╗╚██████╗██║  ██║╚██████╔╝███████╗███████╗           ║
    ║   ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝           ║
    ║                                                               ║
    ║   Bio-Reactive Audio Synthesis for Web                        ║
    ║   Version: ${VERSION}                                            ║
    ║   Platform: Web Audio API                                     ║
    ║                                                               ║
    ║   breath → sound → light → consciousness                      ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
    `);
}
