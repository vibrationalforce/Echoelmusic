# Echoelmusic WebApp Architecture

> Modular Canvas System inspired by Claude Canvas patterns

## Overview

The Echoelmusic WebApp uses a **Modular Canvas Architecture** - independent, composable UI units that communicate via real-time WebSocket sync.

```
┌─────────────────────────────────────────────────────────────┐
│                    WebApp Orchestrator                       │
│                    (60 Hz Control Loop)                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Synthesizer │  │  Visualizer  │  │  Biometric   │       │
│  │    Canvas    │  │    Canvas    │  │    Canvas    │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Effects    │  │  Recording   │  │ Collaboration│       │
│  │    Canvas    │  │    Canvas    │  │    Canvas    │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│                 WebSocket State Bridge                       │
│              (Real-time sync < 10ms)                         │
└─────────────────────────────────────────────────────────────┘
```

## Core Principles

### 1. Fresh Context Per Canvas
Each canvas operates independently - preventing context pollution and enabling parallel development.

### 2. Device-Aware Rendering
```typescript
const canvasEnvironment = detectEnvironment();

switch (canvasEnvironment) {
    case 'visionOS':
        renderImmersiveSpace();
        break;
    case 'iPad':
        renderSplitViewLayout();
        break;
    case 'desktop':
        renderMultiWindowLayout();
        break;
    case 'mobile':
        renderStackedCanvases();
        break;
}
```

### 3. Real-Time State Sync
All canvases share state via WebSocket bridge with <10ms latency.

## Canvas Types

| Canvas | Purpose | Web APIs |
|--------|---------|----------|
| **SynthesizerCanvas** | Audio synthesis, wavetable, ADSR | Web Audio API |
| **VisualizerCanvas** | 3D quantum visuals, particles | Three.js, WebGL |
| **BiometricCanvas** | HRV display, coherence meter | Canvas 2D, simulated data |
| **EffectsCanvas** | DSP chain, EQ, compression | AudioWorklet |
| **RecordingCanvas** | Multi-track, playback | MediaRecorder |
| **CollaborationCanvas** | Real-time sync, chat | WebSocket, WebRTC |

## Technology Stack

```
Frontend:
├── TypeScript (strict mode)
├── Vite (build tool)
├── Three.js (3D graphics)
├── Web Audio API (synthesis)
├── Web MIDI API (controllers)
└── IndexedDB (persistence)

Communication:
├── WebSocket (real-time sync)
├── WebRTC (peer collaboration)
└── Service Worker (offline)

Backend (optional):
├── Firebase/Supabase (auth, sync)
└── Cloudflare Workers (edge compute)
```

## Canvas Base Class

```typescript
// canvas/base.ts
export abstract class EchoCanvas {
    protected id: string;
    protected state: CanvasState;
    protected bridge: WebSocketBridge;

    abstract render(): HTMLElement;
    abstract onUpdate(data: any): void;
    abstract onKeypress(key: string): void;
    abstract onBioData(bio: BioData): void;

    // Lifecycle
    async mount(container: HTMLElement): Promise<void> {
        container.appendChild(this.render());
        this.bridge.subscribe(this.id, this.onUpdate.bind(this));
    }

    async unmount(): Promise<void> {
        this.bridge.unsubscribe(this.id);
    }

    // State sync
    protected broadcast(data: Partial<CanvasState>): void {
        this.bridge.send({
            type: 'CANVAS_UPDATE',
            canvasId: this.id,
            timestamp: Date.now(),
            data
        });
    }
}
```

## Synthesizer Canvas Example

```typescript
// canvas/synthesizer.ts
import { EchoCanvas } from './base';

export class SynthesizerCanvas extends EchoCanvas {
    private audioCtx: AudioContext;
    private oscillator: OscillatorNode;
    private filter: BiquadFilterNode;
    private gain: GainNode;

    constructor() {
        super();
        this.id = 'synthesizer';
    }

    render(): HTMLElement {
        return html`
            <div class="synth-canvas">
                <div class="waveform-selector">
                    ${['sine', 'square', 'sawtooth', 'triangle'].map(w =>
                        html`<button data-wave="${w}">${w}</button>`
                    )}
                </div>
                <div class="controls">
                    <knob-control param="cutoff" min="20" max="20000" />
                    <knob-control param="resonance" min="0" max="30" />
                    <knob-control param="attack" min="0" max="2" />
                    <knob-control param="release" min="0" max="5" />
                </div>
                <keyboard-component octaves="2" start="C4" />
            </div>
        `;
    }

    onBioData(bio: BioData): void {
        // Map biometrics to synthesis parameters
        if (bio.coherence > 0.7) {
            this.filter.frequency.value = bio.coherence * 8000;
        }
        if (bio.heartRate) {
            // Subtle tempo sync
            this.lfoRate = bio.heartRate / 60;
        }
    }
}
```

## Visualizer Canvas Example

```typescript
// canvas/visualizer.ts
import * as THREE from 'three';

export class VisualizerCanvas extends EchoCanvas {
    private scene: THREE.Scene;
    private camera: THREE.PerspectiveCamera;
    private renderer: THREE.WebGLRenderer;
    private particles: THREE.Points;
    private analyser: AnalyserNode;

    render(): HTMLElement {
        const container = document.createElement('div');
        container.className = 'visualizer-canvas';

        this.scene = new THREE.Scene();
        this.camera = new THREE.PerspectiveCamera(75, 16/9, 0.1, 1000);
        this.renderer = new THREE.WebGLRenderer({ antialias: true });

        this.initParticleSystem();
        this.animate();

        container.appendChild(this.renderer.domElement);
        return container;
    }

    private initParticleSystem(): void {
        const geometry = new THREE.BufferGeometry();
        const count = 10000;
        const positions = new Float32Array(count * 3);

        // Fibonacci sphere distribution (sacred geometry)
        const phi = Math.PI * (3 - Math.sqrt(5));
        for (let i = 0; i < count; i++) {
            const y = 1 - (i / (count - 1)) * 2;
            const radius = Math.sqrt(1 - y * y);
            const theta = phi * i;

            positions[i * 3] = Math.cos(theta) * radius;
            positions[i * 3 + 1] = y;
            positions[i * 3 + 2] = Math.sin(theta) * radius;
        }

        geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        this.particles = new THREE.Points(geometry, this.createMaterial());
        this.scene.add(this.particles);
    }

    onBioData(bio: BioData): void {
        // Coherence → particle spread
        const scale = 1 + bio.coherence * 0.5;
        this.particles.scale.setScalar(scale);

        // Heart rate → rotation speed
        const rotationSpeed = bio.heartRate / 1000;
        this.particles.rotation.y += rotationSpeed;
    }
}
```

## WebSocket Bridge

```typescript
// bridge/websocket.ts
export class WebSocketBridge {
    private ws: WebSocket | null = null;
    private subscribers: Map<string, (data: any) => void> = new Map();
    private reconnectAttempts = 0;
    private maxReconnects = 5;

    async connect(url: string): Promise<void> {
        this.ws = new WebSocket(url);

        this.ws.onmessage = (event) => {
            const message = JSON.parse(event.data);
            const handler = this.subscribers.get(message.canvasId);
            if (handler) {
                handler(message.data);
            }
        };

        this.ws.onclose = () => this.handleReconnect(url);
    }

    subscribe(canvasId: string, handler: (data: any) => void): void {
        this.subscribers.set(canvasId, handler);
    }

    unsubscribe(canvasId: string): void {
        this.subscribers.delete(canvasId);
    }

    send(message: CanvasMessage): void {
        if (this.ws?.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(message));
        }
    }

    // Circuit breaker pattern
    private async handleReconnect(url: string): Promise<void> {
        if (this.reconnectAttempts >= this.maxReconnects) {
            console.error('[Bridge] Max reconnection attempts reached');
            return;
        }

        const delay = Math.pow(2, this.reconnectAttempts) * 1000;
        this.reconnectAttempts++;

        await new Promise(r => setTimeout(r, delay));
        this.connect(url);
    }
}
```

## Biometric Simulator

Since Web Bluetooth doesn't work with Apple Watch, we provide a simulator:

```typescript
// bio/simulator.ts
export class BiometricSimulator {
    private heartRate = 72;
    private hrv = 45;
    private coherence = 0.5;
    private breathing = 12;

    private interval: number | null = null;

    start(callback: (data: BioData) => void): void {
        this.interval = setInterval(() => {
            // Natural variation
            this.heartRate += (Math.random() - 0.5) * 4;
            this.heartRate = Math.max(50, Math.min(120, this.heartRate));

            this.hrv += (Math.random() - 0.5) * 10;
            this.hrv = Math.max(20, Math.min(100, this.hrv));

            // Coherence follows HRV pattern
            this.coherence = 0.3 + (this.hrv / 100) * 0.7;

            // Breathing cycle
            this.breathing = 10 + Math.sin(Date.now() / 5000) * 4;

            callback({
                heartRate: Math.round(this.heartRate),
                hrv: Math.round(this.hrv),
                coherence: parseFloat(this.coherence.toFixed(2)),
                breathingRate: parseFloat(this.breathing.toFixed(1)),
                timestamp: Date.now()
            });
        }, 1000);
    }

    stop(): void {
        if (this.interval) {
            clearInterval(this.interval);
            this.interval = null;
        }
    }

    // Manual control for demos
    setCoherence(value: number): void {
        this.coherence = Math.max(0, Math.min(1, value));
    }

    setHeartRate(value: number): void {
        this.heartRate = Math.max(40, Math.min(200, value));
    }
}
```

## File Structure

```
docs/webapp/
├── ARCHITECTURE.md          # This file
├── index.html               # Entry point
├── src/
│   ├── main.ts              # App bootstrap
│   ├── canvas/
│   │   ├── base.ts          # Abstract canvas
│   │   ├── synthesizer.ts   # Audio synthesis
│   │   ├── visualizer.ts    # 3D graphics
│   │   ├── biometric.ts     # HRV display
│   │   ├── effects.ts       # DSP chain
│   │   ├── recording.ts     # Multi-track
│   │   └── collaboration.ts # Real-time sync
│   ├── bridge/
│   │   ├── websocket.ts     # State sync
│   │   └── webrtc.ts        # P2P collab
│   ├── bio/
│   │   ├── simulator.ts     # Fake biometrics
│   │   └── bluetooth.ts     # Android wearables
│   ├── audio/
│   │   ├── engine.ts        # Web Audio setup
│   │   ├── synth.ts         # Oscillators
│   │   └── effects.ts       # AudioWorklet DSP
│   └── presets/
│       └── index.ts         # Preset loader
├── public/
│   ├── manifest.json        # PWA manifest
│   └── sw.js                # Service worker
└── package.json
```

## MVP Scope

### Phase 1: Foundation (Week 1-2)
- [ ] Project setup (Vite + TypeScript)
- [ ] Canvas base class
- [ ] WebSocket bridge
- [ ] SynthesizerCanvas (basic)

### Phase 2: Audio (Week 3)
- [ ] Web Audio engine
- [ ] MIDI input support
- [ ] Basic effects (filter, reverb)

### Phase 3: Visuals (Week 4)
- [ ] VisualizerCanvas (Three.js)
- [ ] Particle system
- [ ] Audio-reactive parameters

### Phase 4: Bio Simulation (Week 5)
- [ ] BiometricCanvas
- [ ] Simulator mode
- [ ] Bio → Audio/Visual mapping

### Phase 5: Polish (Week 6)
- [ ] RecordingCanvas
- [ ] Preset system
- [ ] PWA offline mode
- [ ] Accessibility audit

---

## References

- [Claude Canvas Architecture](https://github.com/dvdsgl/claude-canvas)
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [Three.js](https://threejs.org/)
- [Web MIDI API](https://developer.mozilla.org/en-US/docs/Web/API/Web_MIDI_API)

---

*Generated 2026-01-11 | Echoelmusic WebApp Architecture v1.0*
