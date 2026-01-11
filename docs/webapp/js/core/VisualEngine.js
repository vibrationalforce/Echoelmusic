/**
 * Echoelmusic WebApp - Visual Engine
 * Canvas 2D + WebGL visualizations with bio-reactive modulation
 */

class VisualEngine {
    constructor(canvasId) {
        this.canvas = document.getElementById(canvasId);
        this.ctx = this.canvas.getContext('2d');
        this.width = this.canvas.width;
        this.height = this.canvas.height;

        this.mode = 'waveform';
        this.isRunning = false;
        this.animationId = null;

        // Audio data
        this.frequencyData = new Uint8Array(1024);
        this.timeDomainData = new Uint8Array(2048);

        // Bio data
        this.bioData = {
            heartRate: 72,
            hrv: 45,
            coherence: 0.5,
            breathPhase: 0.5
        };

        // Visual parameters
        this.params = {
            primaryColor: '#00ffcc',
            secondaryColor: '#ff00aa',
            backgroundColor: '#0a0a0f',
            intensity: 1.0,
            speed: 1.0,
            complexity: 1.0,
            symmetry: 8
        };

        // Particle system
        this.particles = [];
        this.maxParticles = 500;

        // Mandala state
        this.mandalaRotation = 0;
        this.petalPulse = 0;

        // Quantum state
        this.quantumPhase = 0;
        this.waveFunctionPoints = [];
        this.photons = [];

        // Spectrum history for waterfall
        this.spectrumHistory = [];
        this.maxSpectrumHistory = 100;

        // Bound handlers for cleanup
        this._resizeHandler = () => this.resize();

        this.resize();
        window.addEventListener('resize', this._resizeHandler);
    }

    /**
     * Cleanup resources
     */
    destroy() {
        this.stop();
        window.removeEventListener('resize', this._resizeHandler);
        this.particles = [];
        this.waveFunctionPoints = [];
        this.photons = [];
        this.spectrumHistory = [];
    }

    resize() {
        const rect = this.canvas.parentElement?.getBoundingClientRect() || { width: 800, height: 600 };
        this.canvas.width = rect.width || 800;
        this.canvas.height = rect.height || 600;
        this.width = this.canvas.width;
        this.height = this.canvas.height;
        this.centerX = this.width / 2;
        this.centerY = this.height / 2;
    }

    setMode(mode) {
        this.mode = mode;
        this.particles = [];
        this.waveFunctionPoints = [];
        this.photons = [];
        console.log('[VisualEngine] Mode:', mode);
    }

    setAudioData(frequencyData, timeDomainData) {
        this.frequencyData = frequencyData;
        this.timeDomainData = timeDomainData;
    }

    onBioData(data) {
        this.bioData = { ...this.bioData, ...data };

        // Bio-reactive parameter modulation
        this.params.intensity = 0.5 + this.bioData.coherence * 0.5;
        this.params.speed = 0.5 + (this.bioData.heartRate - 60) / 80;
        this.params.complexity = 0.3 + this.bioData.hrv / 100;
    }

    onBodyData(data) {
        // Body tracking modulation
        if (!data) return;

        // Smile increases visual brightness/warmth
        if (data.face && data.face.smile > 0.3) {
            const warmHue = 40 + data.face.smile * 30; // Orange-yellow
            this.params.primaryColor = `hsl(${warmHue}, 100%, 60%)`;
        } else {
            this.params.primaryColor = '#00ffcc'; // Default cyan
        }

        // Movement energy affects particle spawn rate and speed
        if (data.movement) {
            this.params.speed = Math.max(0.5, this.params.speed + data.movement.energy * 0.5);
            // More particles when moving
            if (data.movement.isMoving && this.particles.length < this.maxParticles) {
                this.spawnParticle();
                this.spawnParticle();
            }
        }

        // Arousal affects symmetry (more aroused = more complex patterns)
        if (typeof data.arousal === 'number') {
            this.params.symmetry = Math.floor(6 + data.arousal * 6);
        }

        // Relaxation smooths out visuals
        if (typeof data.relaxation === 'number' && data.relaxation > 0.6) {
            this.params.speed = Math.max(0.3, this.params.speed * 0.9);
        }
    }

    start() {
        if (this.isRunning) return;
        this.isRunning = true;
        this.animate();
    }

    stop() {
        this.isRunning = false;
        if (this.animationId) {
            cancelAnimationFrame(this.animationId);
            this.animationId = null;
        }
    }

    animate() {
        if (!this.isRunning) return;

        this.ctx.fillStyle = this.params.backgroundColor;
        this.ctx.fillRect(0, 0, this.width, this.height);

        switch (this.mode) {
            case 'waveform':
                this.drawWaveform();
                break;
            case 'spectrum':
                this.drawSpectrum();
                break;
            case 'mandala':
                this.drawMandala();
                break;
            case 'particles':
                this.drawParticles();
                break;
            case 'quantum':
                this.drawQuantumField();
                break;
            case 'coherence':
                this.drawCoherenceField();
                break;
            case 'sacredGeometry':
                this.drawSacredGeometry();
                break;
            case 'cymatics':
                this.drawCymatics();
                break;
            case 'aurora':
                this.drawAurora();
                break;
            case 'cosmic':
                this.drawCosmicWeb();
                break;
            default:
                this.drawWaveform();
        }

        this.animationId = requestAnimationFrame(() => this.animate());
    }

    // ==================== WAVEFORM ====================
    drawWaveform() {
        const data = this.timeDomainData;
        const sliceWidth = this.width / data.length;

        this.ctx.lineWidth = 2;
        this.ctx.strokeStyle = this.params.primaryColor;
        this.ctx.shadowBlur = 10;
        this.ctx.shadowColor = this.params.primaryColor;

        this.ctx.beginPath();
        let x = 0;

        for (let i = 0; i < data.length; i++) {
            const v = data[i] / 128.0;
            const y = (v * this.height) / 2;

            if (i === 0) {
                this.ctx.moveTo(x, y);
            } else {
                this.ctx.lineTo(x, y);
            }
            x += sliceWidth;
        }

        this.ctx.stroke();
        this.ctx.shadowBlur = 0;

        // Bio coherence indicator
        this.drawCoherenceMeter();
    }

    // ==================== SPECTRUM ANALYZER ====================
    drawSpectrum() {
        const data = this.frequencyData;
        const barWidth = this.width / data.length * 2.5;
        const barSpacing = 1;

        // Store for waterfall
        this.spectrumHistory.push([...data]);
        if (this.spectrumHistory.length > this.maxSpectrumHistory) {
            this.spectrumHistory.shift();
        }

        // Draw waterfall background
        const historyHeight = this.height * 0.3;
        for (let h = 0; h < this.spectrumHistory.length; h++) {
            const historyData = this.spectrumHistory[h];
            const y = historyHeight - (h / this.maxSpectrumHistory) * historyHeight;

            for (let i = 0; i < historyData.length && i * barWidth < this.width; i++) {
                const value = historyData[i] / 255;
                const hue = 180 - value * 60; // Cyan to magenta
                this.ctx.fillStyle = `hsla(${hue}, 100%, 50%, ${0.3 + value * 0.5})`;
                this.ctx.fillRect(i * barWidth, y, barWidth - barSpacing, 3);
            }
        }

        // Draw current spectrum bars
        for (let i = 0; i < data.length && i * barWidth < this.width; i++) {
            const value = data[i] / 255;
            const barHeight = value * (this.height - historyHeight) * this.params.intensity;

            const hue = 180 + this.bioData.coherence * 60 - value * 30;
            const gradient = this.ctx.createLinearGradient(0, this.height - barHeight, 0, this.height);
            gradient.addColorStop(0, `hsla(${hue}, 100%, 70%, 1)`);
            gradient.addColorStop(1, `hsla(${hue + 30}, 100%, 40%, 0.8)`);

            this.ctx.fillStyle = gradient;
            this.ctx.fillRect(
                i * barWidth,
                this.height - barHeight,
                barWidth - barSpacing,
                barHeight
            );
        }

        this.drawCoherenceMeter();
    }

    // ==================== MANDALA ====================
    drawMandala() {
        const petalCount = Math.floor(6 + this.bioData.coherence * 6);
        const layers = 5;

        this.mandalaRotation += 0.005 * this.params.speed;
        this.petalPulse = Math.sin(Date.now() * 0.002 * this.params.speed) * 0.2;

        // Get audio energy for modulation
        const bass = this.getFrequencyRange(0, 10) / 255;
        const mid = this.getFrequencyRange(10, 50) / 255;
        const high = this.getFrequencyRange(50, 100) / 255;

        for (let layer = layers; layer >= 1; layer--) {
            const layerRadius = (this.height * 0.35) * (layer / layers);
            const rotation = this.mandalaRotation * (layer % 2 === 0 ? 1 : -1);
            const layerPetals = petalCount + (layers - layer) * 2;

            for (let i = 0; i < layerPetals; i++) {
                const angle = (i / layerPetals) * Math.PI * 2 + rotation;
                const pulseSize = 1 + this.petalPulse + bass * 0.3;

                this.drawPetal(
                    this.centerX + Math.cos(angle) * layerRadius * 0.3,
                    this.centerY + Math.sin(angle) * layerRadius * 0.3,
                    layerRadius * 0.4 * pulseSize,
                    angle,
                    layer / layers,
                    mid
                );
            }
        }

        // Center circle with heart rate pulse
        const heartPulse = 1 + Math.sin(Date.now() * 0.01 * (this.bioData.heartRate / 60)) * 0.1;
        const centerRadius = 30 * heartPulse;

        const centerGradient = this.ctx.createRadialGradient(
            this.centerX, this.centerY, 0,
            this.centerX, this.centerY, centerRadius
        );
        centerGradient.addColorStop(0, `rgba(255, 255, 255, ${this.bioData.coherence})`);
        centerGradient.addColorStop(1, 'rgba(0, 255, 204, 0.5)');

        this.ctx.fillStyle = centerGradient;
        this.ctx.beginPath();
        this.ctx.arc(this.centerX, this.centerY, centerRadius, 0, Math.PI * 2);
        this.ctx.fill();
    }

    drawPetal(x, y, size, angle, layerRatio, intensity) {
        const hue = 160 + this.bioData.coherence * 60 + layerRatio * 30;
        const alpha = 0.3 + intensity * 0.4;

        this.ctx.save();
        this.ctx.translate(x, y);
        this.ctx.rotate(angle);

        const gradient = this.ctx.createRadialGradient(0, 0, 0, 0, 0, size);
        gradient.addColorStop(0, `hsla(${hue}, 80%, 60%, ${alpha})`);
        gradient.addColorStop(0.7, `hsla(${hue + 20}, 70%, 40%, ${alpha * 0.5})`);
        gradient.addColorStop(1, 'transparent');

        this.ctx.fillStyle = gradient;
        this.ctx.beginPath();
        this.ctx.ellipse(0, 0, size * 0.3, size, 0, 0, Math.PI * 2);
        this.ctx.fill();

        this.ctx.restore();
    }

    // ==================== PARTICLE SYSTEM ====================
    drawParticles() {
        const coherenceTarget = this.bioData.coherence > 0.6 ? 'center' : 'random';
        const bass = this.getFrequencyRange(0, 10) / 255;

        // Spawn particles based on audio
        if (this.particles.length < this.maxParticles && bass > 0.3) {
            this.spawnParticle();
        }

        // Update and draw particles
        for (let i = this.particles.length - 1; i >= 0; i--) {
            const p = this.particles[i];

            // Coherence-based behavior
            if (coherenceTarget === 'center') {
                // Attract to center when coherent
                const dx = this.centerX - p.x;
                const dy = this.centerY - p.y;
                const dist = Math.sqrt(dx * dx + dy * dy);
                p.vx += (dx / dist) * 0.1 * this.bioData.coherence;
                p.vy += (dy / dist) * 0.1 * this.bioData.coherence;
            }

            // Physics update
            p.x += p.vx;
            p.y += p.vy;
            p.vx *= 0.99;
            p.vy *= 0.99;
            p.life -= 0.01;
            p.size = p.baseSize * p.life;

            // Boundary wrapping
            if (p.x < 0) p.x = this.width;
            if (p.x > this.width) p.x = 0;
            if (p.y < 0) p.y = this.height;
            if (p.y > this.height) p.y = 0;

            // Remove dead particles
            if (p.life <= 0) {
                this.particles.splice(i, 1);
                continue;
            }

            // Draw particle
            const gradient = this.ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.size);
            gradient.addColorStop(0, `hsla(${p.hue}, 100%, 70%, ${p.life})`);
            gradient.addColorStop(1, 'transparent');

            this.ctx.fillStyle = gradient;
            this.ctx.beginPath();
            this.ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
            this.ctx.fill();

            // Draw connections between nearby particles
            for (let j = i + 1; j < this.particles.length; j++) {
                const p2 = this.particles[j];
                const dx = p2.x - p.x;
                const dy = p2.y - p.y;
                const dist = Math.sqrt(dx * dx + dy * dy);

                if (dist < 100) {
                    this.ctx.strokeStyle = `hsla(${p.hue}, 100%, 50%, ${(1 - dist / 100) * 0.3})`;
                    this.ctx.lineWidth = 1;
                    this.ctx.beginPath();
                    this.ctx.moveTo(p.x, p.y);
                    this.ctx.lineTo(p2.x, p2.y);
                    this.ctx.stroke();
                }
            }
        }

        this.drawCoherenceMeter();
    }

    spawnParticle() {
        const angle = Math.random() * Math.PI * 2;
        const speed = 1 + Math.random() * 3;

        this.particles.push({
            x: this.centerX + (Math.random() - 0.5) * 100,
            y: this.centerY + (Math.random() - 0.5) * 100,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            size: 5 + Math.random() * 15,
            baseSize: 5 + Math.random() * 15,
            hue: 160 + this.bioData.coherence * 80,
            life: 1.0
        });
    }

    // ==================== QUANTUM FIELD ====================
    drawQuantumField() {
        this.quantumPhase += 0.02 * this.params.speed;

        // Wave function visualization
        const waveCount = 50;
        const amplitude = this.height * 0.3 * this.bioData.coherence;

        for (let w = 0; w < 3; w++) {
            const wavePhase = this.quantumPhase + w * 0.5;
            const hue = 180 + w * 40;

            this.ctx.strokeStyle = `hsla(${hue}, 100%, 60%, 0.6)`;
            this.ctx.lineWidth = 2;
            this.ctx.beginPath();

            for (let i = 0; i <= waveCount; i++) {
                const x = (i / waveCount) * this.width;
                const frequency = 2 + this.bioData.hrv / 30;
                const y = this.centerY +
                    Math.sin(wavePhase + (i / waveCount) * Math.PI * 2 * frequency) * amplitude +
                    Math.sin(wavePhase * 2 + (i / waveCount) * Math.PI * 4) * amplitude * 0.3;

                if (i === 0) {
                    this.ctx.moveTo(x, y);
                } else {
                    this.ctx.lineTo(x, y);
                }
            }

            this.ctx.stroke();
        }

        // Quantum probability cloud
        const cloudPoints = 100;
        for (let i = 0; i < cloudPoints; i++) {
            const angle = (i / cloudPoints) * Math.PI * 2 + this.quantumPhase;
            const radius = 50 + Math.sin(angle * 3 + this.quantumPhase) * 30 * this.bioData.coherence;
            const x = this.centerX + Math.cos(angle) * radius * 2;
            const y = this.centerY + Math.sin(angle) * radius;

            const size = 3 + Math.sin(this.quantumPhase + i) * 2;
            const alpha = 0.3 + Math.sin(this.quantumPhase * 2 + i * 0.1) * 0.2;

            this.ctx.fillStyle = `hsla(${200 + i}, 100%, 70%, ${alpha})`;
            this.ctx.beginPath();
            this.ctx.arc(x, y, size, 0, Math.PI * 2);
            this.ctx.fill();
        }

        // Photon particles
        this.updatePhotons();
        this.drawPhotons();

        this.drawCoherenceMeter();
    }

    updatePhotons() {
        // Spawn photons based on coherence
        if (this.photons.length < 50 && Math.random() < this.bioData.coherence * 0.3) {
            const angle = Math.random() * Math.PI * 2;
            this.photons.push({
                x: this.centerX,
                y: this.centerY,
                vx: Math.cos(angle) * (2 + Math.random() * 3),
                vy: Math.sin(angle) * (2 + Math.random() * 3),
                wavelength: 400 + Math.random() * 300,
                phase: Math.random() * Math.PI * 2,
                life: 1.0
            });
        }

        // Update photons
        for (let i = this.photons.length - 1; i >= 0; i--) {
            const p = this.photons[i];
            p.x += p.vx;
            p.y += p.vy;
            p.phase += 0.1;
            p.life -= 0.01;

            if (p.life <= 0 || p.x < 0 || p.x > this.width || p.y < 0 || p.y > this.height) {
                this.photons.splice(i, 1);
            }
        }
    }

    drawPhotons() {
        for (const p of this.photons) {
            const hue = (p.wavelength - 400) / 300 * 270 + 240;
            const size = 4 + Math.sin(p.phase) * 2;

            this.ctx.shadowBlur = 15;
            this.ctx.shadowColor = `hsl(${hue}, 100%, 60%)`;
            this.ctx.fillStyle = `hsla(${hue}, 100%, 70%, ${p.life})`;
            this.ctx.beginPath();
            this.ctx.arc(p.x, p.y, size, 0, Math.PI * 2);
            this.ctx.fill();
            this.ctx.shadowBlur = 0;
        }
    }

    // ==================== COHERENCE FIELD ====================
    drawCoherenceField() {
        const coherence = this.bioData.coherence;
        const breathPhase = this.bioData.breathPhase;

        // Breathing circle
        const breathRadius = 100 + breathPhase * 80;
        const gradient = this.ctx.createRadialGradient(
            this.centerX, this.centerY, breathRadius * 0.5,
            this.centerX, this.centerY, breathRadius
        );

        const hue = 160 + coherence * 60;
        gradient.addColorStop(0, `hsla(${hue}, 100%, 70%, ${coherence * 0.8})`);
        gradient.addColorStop(0.7, `hsla(${hue}, 80%, 50%, ${coherence * 0.4})`);
        gradient.addColorStop(1, 'transparent');

        this.ctx.fillStyle = gradient;
        this.ctx.beginPath();
        this.ctx.arc(this.centerX, this.centerY, breathRadius, 0, Math.PI * 2);
        this.ctx.fill();

        // Coherence rings
        const ringCount = 5;
        for (let i = 0; i < ringCount; i++) {
            const ringRadius = breathRadius + i * 30 * coherence;
            const ringAlpha = (1 - i / ringCount) * coherence * 0.5;

            this.ctx.strokeStyle = `hsla(${hue + i * 10}, 100%, 60%, ${ringAlpha})`;
            this.ctx.lineWidth = 2;
            this.ctx.beginPath();
            this.ctx.arc(this.centerX, this.centerY, ringRadius, 0, Math.PI * 2);
            this.ctx.stroke();
        }

        // Heart rate pulse indicator
        const pulsePhase = (Date.now() % (60000 / this.bioData.heartRate)) / (60000 / this.bioData.heartRate);
        const pulseSize = 20 + Math.sin(pulsePhase * Math.PI) * 10;

        this.ctx.fillStyle = '#ff6b6b';
        this.ctx.beginPath();
        this.ctx.arc(this.centerX, this.centerY, pulseSize, 0, Math.PI * 2);
        this.ctx.fill();

        // Bio stats display
        this.drawBioStats();
    }

    // ==================== SACRED GEOMETRY ====================
    drawSacredGeometry() {
        const rotation = Date.now() * 0.0001 * this.params.speed;
        const coherence = this.bioData.coherence;

        // Flower of Life
        this.drawFlowerOfLife(this.centerX, this.centerY, 80, rotation, coherence);

        // Metatron's Cube overlay
        if (coherence > 0.5) {
            this.drawMetatronsCube(this.centerX, this.centerY, 120, rotation, coherence);
        }

        // Sri Yantra center
        if (coherence > 0.7) {
            this.drawSriYantra(this.centerX, this.centerY, 60, rotation);
        }

        this.drawCoherenceMeter();
    }

    drawFlowerOfLife(cx, cy, radius, rotation, coherence) {
        const circles = 7;
        const hue = 180 + coherence * 60;

        this.ctx.strokeStyle = `hsla(${hue}, 80%, 60%, 0.6)`;
        this.ctx.lineWidth = 1;

        // Central circle
        this.ctx.beginPath();
        this.ctx.arc(cx, cy, radius, 0, Math.PI * 2);
        this.ctx.stroke();

        // Surrounding circles
        for (let ring = 1; ring <= 2; ring++) {
            const count = ring * 6;
            for (let i = 0; i < count; i++) {
                const angle = (i / count) * Math.PI * 2 + rotation * ring;
                const x = cx + Math.cos(angle) * radius * ring;
                const y = cy + Math.sin(angle) * radius * ring;

                this.ctx.beginPath();
                this.ctx.arc(x, y, radius, 0, Math.PI * 2);
                this.ctx.stroke();
            }
        }
    }

    drawMetatronsCube(cx, cy, size, rotation, coherence) {
        const points = [];
        const hue = 280 + coherence * 40;

        // Generate vertices
        for (let i = 0; i < 6; i++) {
            const angle = (i / 6) * Math.PI * 2 + rotation;
            points.push({
                x: cx + Math.cos(angle) * size,
                y: cy + Math.sin(angle) * size
            });
        }

        // Inner hexagon
        for (let i = 0; i < 6; i++) {
            const angle = (i / 6) * Math.PI * 2 + rotation + Math.PI / 6;
            points.push({
                x: cx + Math.cos(angle) * size * 0.5,
                y: cy + Math.sin(angle) * size * 0.5
            });
        }

        points.push({ x: cx, y: cy });

        // Draw all connections
        this.ctx.strokeStyle = `hsla(${hue}, 100%, 70%, ${coherence * 0.4})`;
        this.ctx.lineWidth = 1;

        for (let i = 0; i < points.length; i++) {
            for (let j = i + 1; j < points.length; j++) {
                this.ctx.beginPath();
                this.ctx.moveTo(points[i].x, points[i].y);
                this.ctx.lineTo(points[j].x, points[j].y);
                this.ctx.stroke();
            }
        }
    }

    drawSriYantra(cx, cy, size, rotation) {
        const triangles = 9;

        for (let i = 0; i < triangles; i++) {
            const s = size * (1 - i * 0.08);
            const upward = i % 2 === 0;
            const angle = rotation + (upward ? 0 : Math.PI);

            this.ctx.strokeStyle = `hsla(${40 + i * 20}, 100%, 60%, 0.5)`;
            this.ctx.lineWidth = 1;

            this.ctx.beginPath();
            for (let j = 0; j < 3; j++) {
                const a = angle + (j / 3) * Math.PI * 2;
                const x = cx + Math.cos(a) * s;
                const y = cy + Math.sin(a) * s;
                if (j === 0) this.ctx.moveTo(x, y);
                else this.ctx.lineTo(x, y);
            }
            this.ctx.closePath();
            this.ctx.stroke();
        }
    }

    // ==================== CYMATICS ====================
    drawCymatics() {
        const bass = this.getFrequencyRange(0, 5) / 255;
        const mid = this.getFrequencyRange(5, 30) / 255;
        const high = this.getFrequencyRange(30, 80) / 255;

        const frequency = 2 + mid * 8;
        const amplitude = bass * 100;

        // Chladni plate pattern
        for (let x = 0; x < this.width; x += 4) {
            for (let y = 0; y < this.height; y += 4) {
                const nx = (x - this.centerX) / 200;
                const ny = (y - this.centerY) / 200;

                const value = Math.sin(nx * frequency * Math.PI) * Math.sin(ny * frequency * Math.PI) +
                              Math.sin(nx * frequency * 0.5 * Math.PI) * Math.sin(ny * frequency * 1.5 * Math.PI);

                const nodeLine = Math.abs(value) < 0.1 + high * 0.2;

                if (nodeLine) {
                    const hue = 180 + this.bioData.coherence * 60;
                    this.ctx.fillStyle = `hsla(${hue}, 80%, 60%, ${0.5 + amplitude / 200})`;
                    this.ctx.fillRect(x, y, 3, 3);
                }
            }
        }

        this.drawCoherenceMeter();
    }

    // ==================== AURORA ====================
    drawAurora() {
        const time = Date.now() * 0.001;
        const coherence = this.bioData.coherence;

        for (let band = 0; band < 5; band++) {
            const yBase = this.height * 0.3 + band * 40;
            const hue = 120 + band * 30 + coherence * 40;

            this.ctx.beginPath();
            this.ctx.moveTo(0, yBase);

            for (let x = 0; x <= this.width; x += 5) {
                const y = yBase +
                    Math.sin(x * 0.01 + time + band) * 50 * coherence +
                    Math.sin(x * 0.02 + time * 1.5) * 30;
                this.ctx.lineTo(x, y);
            }

            this.ctx.lineTo(this.width, this.height);
            this.ctx.lineTo(0, this.height);
            this.ctx.closePath();

            const gradient = this.ctx.createLinearGradient(0, yBase - 50, 0, this.height);
            gradient.addColorStop(0, `hsla(${hue}, 100%, 60%, ${0.3 * coherence})`);
            gradient.addColorStop(0.5, `hsla(${hue + 20}, 80%, 40%, ${0.2 * coherence})`);
            gradient.addColorStop(1, 'transparent');

            this.ctx.fillStyle = gradient;
            this.ctx.fill();
        }

        this.drawCoherenceMeter();
    }

    // ==================== COSMIC WEB ====================
    drawCosmicWeb() {
        const time = Date.now() * 0.0005;
        const nodeCount = 30 + Math.floor(this.bioData.coherence * 20);

        // Generate cosmic nodes
        const nodes = [];
        for (let i = 0; i < nodeCount; i++) {
            const angle = (i / nodeCount) * Math.PI * 2 + time;
            const radius = 100 + Math.sin(angle * 3 + time) * 50 + i * 5;
            nodes.push({
                x: this.centerX + Math.cos(angle + Math.sin(time + i)) * radius,
                y: this.centerY + Math.sin(angle + Math.cos(time + i)) * radius,
                size: 2 + Math.sin(time + i) * 1.5
            });
        }

        // Draw connections (cosmic filaments)
        this.ctx.strokeStyle = `hsla(260, 80%, 60%, 0.2)`;
        this.ctx.lineWidth = 1;

        for (let i = 0; i < nodes.length; i++) {
            for (let j = i + 1; j < nodes.length; j++) {
                const dx = nodes[j].x - nodes[i].x;
                const dy = nodes[j].y - nodes[i].y;
                const dist = Math.sqrt(dx * dx + dy * dy);

                if (dist < 150) {
                    this.ctx.globalAlpha = (1 - dist / 150) * this.bioData.coherence;
                    this.ctx.beginPath();
                    this.ctx.moveTo(nodes[i].x, nodes[i].y);
                    this.ctx.lineTo(nodes[j].x, nodes[j].y);
                    this.ctx.stroke();
                }
            }
        }

        this.ctx.globalAlpha = 1;

        // Draw nodes (galaxies)
        for (const node of nodes) {
            const gradient = this.ctx.createRadialGradient(
                node.x, node.y, 0, node.x, node.y, node.size * 3
            );
            gradient.addColorStop(0, 'rgba(255, 255, 255, 0.9)');
            gradient.addColorStop(0.5, 'rgba(100, 150, 255, 0.5)');
            gradient.addColorStop(1, 'transparent');

            this.ctx.fillStyle = gradient;
            this.ctx.beginPath();
            this.ctx.arc(node.x, node.y, node.size * 3, 0, Math.PI * 2);
            this.ctx.fill();
        }

        this.drawCoherenceMeter();
    }

    // ==================== HELPERS ====================
    getFrequencyRange(start, end) {
        let sum = 0;
        for (let i = start; i < end && i < this.frequencyData.length; i++) {
            sum += this.frequencyData[i];
        }
        return sum / (end - start);
    }

    drawCoherenceMeter() {
        const meterWidth = 150;
        const meterHeight = 10;
        const x = this.width - meterWidth - 20;
        const y = 20;

        // Background
        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
        this.ctx.fillRect(x - 5, y - 5, meterWidth + 10, meterHeight + 30);

        // Coherence bar
        const gradient = this.ctx.createLinearGradient(x, y, x + meterWidth, y);
        gradient.addColorStop(0, '#ff4444');
        gradient.addColorStop(0.5, '#ffff44');
        gradient.addColorStop(1, '#44ff44');

        this.ctx.fillStyle = '#333';
        this.ctx.fillRect(x, y, meterWidth, meterHeight);
        this.ctx.fillStyle = gradient;
        this.ctx.fillRect(x, y, meterWidth * this.bioData.coherence, meterHeight);

        // Labels
        this.ctx.fillStyle = '#fff';
        this.ctx.font = '10px monospace';
        this.ctx.fillText(`Coherence: ${Math.round(this.bioData.coherence * 100)}%`, x, y + 22);
        this.ctx.fillText(`HR: ${this.bioData.heartRate} BPM`, x + 80, y + 22);
    }

    drawBioStats() {
        const x = 20;
        const y = this.height - 100;

        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
        this.ctx.fillRect(x - 10, y - 10, 180, 90);

        this.ctx.fillStyle = '#fff';
        this.ctx.font = '14px monospace';
        this.ctx.fillText(`Heart Rate: ${this.bioData.heartRate} BPM`, x, y + 10);
        this.ctx.fillText(`HRV: ${this.bioData.hrv} ms`, x, y + 30);
        this.ctx.fillText(`Coherence: ${Math.round(this.bioData.coherence * 100)}%`, x, y + 50);
        this.ctx.fillText(`Breathing: ${this.bioData.breathingRate.toFixed(1)}/min`, x, y + 70);
    }

    setParams(params) {
        this.params = { ...this.params, ...params };
    }
}

// Export
if (typeof module !== 'undefined' && module.exports) {
    module.exports = VisualEngine;
}
