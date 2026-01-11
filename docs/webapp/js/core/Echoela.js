/**
 * Echoela - AI Assistant for Echoelmusic WebApp
 * Provides interactive guidance, tips, and visual cues
 *
 * Features:
 * - Magenta highlight system for working features
 * - Interactive onboarding wizard
 * - Camera rPPG guide
 * - WearOS/Bluetooth guide
 * - Contextual tips and coaching
 * - Voice guidance (TTS)
 * - Multi-language support
 */

class Echoela {
    constructor() {
        this.isActive = false;
        this.currentStep = 0;
        this.highlightedElements = new Set();
        this.speechSynthesis = window.speechSynthesis;
        this.currentLanguage = 'de'; // Default German
        this.onboardingComplete = false;
        this.tipQueue = [];
        this.lastTipTime = 0;
        this.minTipInterval = 30000; // 30 seconds between tips

        // Echoela personality
        this.personality = {
            name: 'Echoela',
            emoji: '🎵',
            color: '#ff00aa', // Magenta
            highlightColor: 'rgba(255, 0, 170, 0.3)',
            borderColor: '#ff00aa'
        };

        // Feature status tracking
        this.featureStatus = {
            audio: { available: true, working: false },
            bioSimulator: { available: true, working: false },
            bioBluetooth: { available: false, working: false },
            bioCamera: { available: false, working: false },
            midi: { available: false, working: false },
            visualizer: { available: true, working: false },
            sequencer: { available: true, working: false },
            breathing: { available: true, working: false }
        };

        // Guides database
        this.guides = this.loadGuides();

        // Tips database
        this.tips = this.loadTips();

        // Onboarding steps
        this.onboardingSteps = this.loadOnboardingSteps();
    }

    /**
     * Initialize Echoela
     */
    async init() {
        console.log('🎵 Echoela initializing...');

        // Check feature availability
        await this.checkFeatureAvailability();

        // Create UI elements
        this.createUI();

        // Check if first visit
        const visited = localStorage.getItem('echoela_visited');
        if (!visited) {
            setTimeout(() => this.startOnboarding(), 1000);
        }

        // Start contextual tip system
        this.startContextualTips();

        // Start bio tracking status monitor
        this.startBioStatusMonitor();

        this.isActive = true;
        console.log('🎵 Echoela ready!');

        return this;
    }

    /**
     * Start bio tracking status monitor
     */
    startBioStatusMonitor() {
        // Create bio status indicator
        this.createBioStatusIndicator();

        // Update every second
        this._bioStatusInterval = setInterval(() => {
            this.updateBioStatusIndicator();
        }, 1000);
    }

    /**
     * Create bio status indicator element
     */
    createBioStatusIndicator() {
        const indicator = document.createElement('div');
        indicator.id = 'echoela-bio-status';
        indicator.innerHTML = `
            <style>
                #echoela-bio-status {
                    position: fixed;
                    top: 70px;
                    right: 20px;
                    background: rgba(20, 20, 30, 0.9);
                    backdrop-filter: blur(10px);
                    -webkit-backdrop-filter: blur(10px);
                    border-radius: 12px;
                    padding: 8px 12px;
                    z-index: 1000;
                    display: none;
                    border: 1px solid rgba(255, 0, 170, 0.3);
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 12px;
                }
                #echoela-bio-status.active {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    animation: bio-pulse 2s infinite;
                }
                @keyframes bio-pulse {
                    0%, 100% { border-color: rgba(255, 0, 170, 0.3); }
                    50% { border-color: rgba(255, 0, 170, 0.7); }
                }
                .bio-status-icon {
                    width: 10px;
                    height: 10px;
                    border-radius: 50%;
                    background: #ff00aa;
                    animation: bio-dot-pulse 1s infinite;
                }
                @keyframes bio-dot-pulse {
                    0%, 100% { opacity: 1; transform: scale(1); }
                    50% { opacity: 0.7; transform: scale(0.9); }
                }
                .bio-status-text {
                    color: rgba(255, 255, 255, 0.9);
                }
                .bio-status-source {
                    color: #ff00aa;
                    font-weight: 500;
                }
                @media (max-width: 768px) {
                    #echoela-bio-status {
                        top: auto;
                        bottom: 150px;
                        right: 10px;
                        font-size: 11px;
                    }
                }
            </style>
            <div class="bio-status-icon"></div>
            <span class="bio-status-text">Bio: <span class="bio-status-source">--</span></span>
        `;
        document.body.appendChild(indicator);
    }

    /**
     * Update bio status indicator
     */
    updateBioStatusIndicator() {
        const indicator = document.getElementById('echoela-bio-status');
        if (!indicator) return;

        // Check if any bio source is active
        const bioActive = this.featureStatus.bioSimulator.working ||
                         this.featureStatus.bioBluetooth.working ||
                         this.featureStatus.bioCamera.working;

        if (bioActive) {
            indicator.classList.add('active');
            let source = 'Simulator';
            if (this.featureStatus.bioCamera.working) source = '📷 Kamera';
            else if (this.featureStatus.bioBluetooth.working) source = '⌚ Bluetooth';
            else if (this.featureStatus.bioSimulator.working) source = '🎲 Simulator';

            indicator.querySelector('.bio-status-source').textContent = source;
        } else {
            indicator.classList.remove('active');
        }
    }

    /**
     * Set bio source as active (called from app.html)
     */
    setBioSourceActive(source) {
        // Reset all
        this.featureStatus.bioSimulator.working = false;
        this.featureStatus.bioBluetooth.working = false;
        this.featureStatus.bioCamera.working = false;

        // Set active source
        if (source === 'simulator') {
            this.featureStatus.bioSimulator.working = true;
        } else if (source === 'bluetooth') {
            this.featureStatus.bioBluetooth.working = true;
        } else if (source === 'camera') {
            this.featureStatus.bioCamera.working = true;
        }

        this.updateBioStatusIndicator();
    }

    /**
     * Check which features are available
     */
    async checkFeatureAvailability() {
        // Audio
        this.featureStatus.audio.available = !!(window.AudioContext || window.webkitAudioContext);

        // Bluetooth
        this.featureStatus.bioBluetooth.available = !!navigator.bluetooth;

        // Camera
        this.featureStatus.bioCamera.available = !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);

        // MIDI
        this.featureStatus.midi.available = !!navigator.requestMIDIAccess;

        // Update working status based on user interaction
        this.updateFeatureStatus();
    }

    /**
     * Update feature working status
     */
    updateFeatureStatus() {
        // This will be called by engines when they start working
    }

    /**
     * Mark a feature as working and highlight it
     */
    markFeatureWorking(featureName, elementSelector) {
        if (this.featureStatus[featureName]) {
            this.featureStatus[featureName].working = true;

            // Highlight the element
            const element = document.querySelector(elementSelector);
            if (element) {
                this.highlightElement(element, `${featureName} ist aktiv!`);
            }

            // Announce
            this.announce(`${this.getFeatureNameDE(featureName)} funktioniert jetzt!`);
        }
    }

    /**
     * Get German feature name
     */
    getFeatureNameDE(featureName) {
        const names = {
            audio: 'Audio-Engine',
            bioSimulator: 'Bio-Simulator',
            bioBluetooth: 'Bluetooth Herzfrequenzmesser',
            bioCamera: 'Kamera Herzfrequenzmessung',
            midi: 'MIDI Controller',
            visualizer: 'Visualizer',
            sequencer: 'Drum Sequencer',
            breathing: 'Atemübung'
        };
        return names[featureName] || featureName;
    }

    /**
     * Create Echoela UI elements
     */
    createUI() {
        // Create Echoela container
        const container = document.createElement('div');
        container.id = 'echoela-container';
        container.innerHTML = `
            <style>
                #echoela-container {
                    position: fixed;
                    bottom: 80px;
                    right: 20px;
                    z-index: 10000;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                }

                #echoela-button {
                    width: 60px;
                    height: 60px;
                    border-radius: 50%;
                    background: linear-gradient(135deg, #ff00aa, #00ffcc);
                    border: none;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 28px;
                    box-shadow: 0 4px 20px rgba(255, 0, 170, 0.4);
                    transition: transform 0.3s, box-shadow 0.3s;
                    animation: echoela-pulse 2s infinite;
                }

                #echoela-button:hover {
                    transform: scale(1.1);
                    box-shadow: 0 6px 30px rgba(255, 0, 170, 0.6);
                }

                @keyframes echoela-pulse {
                    0%, 100% { box-shadow: 0 4px 20px rgba(255, 0, 170, 0.4); }
                    50% { box-shadow: 0 4px 30px rgba(255, 0, 170, 0.7); }
                }

                #echoela-panel {
                    position: absolute;
                    bottom: 70px;
                    right: 0;
                    width: 320px;
                    max-height: 500px;
                    background: rgba(20, 20, 30, 0.95);
                    backdrop-filter: blur(20px);
                    -webkit-backdrop-filter: blur(20px);
                    border-radius: 16px;
                    border: 1px solid rgba(255, 0, 170, 0.3);
                    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5);
                    display: none;
                    overflow: hidden;
                }

                #echoela-panel.open {
                    display: block;
                    animation: echoela-slide-up 0.3s ease-out;
                }

                @keyframes echoela-slide-up {
                    from { opacity: 0; transform: translateY(20px); }
                    to { opacity: 1; transform: translateY(0); }
                }

                .echoela-header {
                    padding: 16px;
                    background: linear-gradient(135deg, rgba(255, 0, 170, 0.2), rgba(0, 255, 204, 0.1));
                    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
                    display: flex;
                    align-items: center;
                    gap: 12px;
                }

                .echoela-avatar {
                    width: 40px;
                    height: 40px;
                    border-radius: 50%;
                    background: linear-gradient(135deg, #ff00aa, #00ffcc);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 20px;
                }

                .echoela-title {
                    flex: 1;
                }

                .echoela-title h3 {
                    margin: 0;
                    font-size: 16px;
                    color: #fff;
                }

                .echoela-title p {
                    margin: 2px 0 0;
                    font-size: 12px;
                    color: rgba(255, 255, 255, 0.6);
                }

                .echoela-close {
                    background: none;
                    border: none;
                    color: rgba(255, 255, 255, 0.6);
                    font-size: 24px;
                    cursor: pointer;
                    padding: 4px;
                }

                .echoela-content {
                    padding: 16px;
                    max-height: 350px;
                    overflow-y: auto;
                }

                .echoela-message {
                    background: rgba(255, 255, 255, 0.05);
                    border-radius: 12px;
                    padding: 12px;
                    margin-bottom: 12px;
                    border-left: 3px solid #ff00aa;
                }

                .echoela-message p {
                    margin: 0;
                    color: rgba(255, 255, 255, 0.9);
                    font-size: 14px;
                    line-height: 1.5;
                }

                .echoela-actions {
                    display: flex;
                    flex-wrap: wrap;
                    gap: 8px;
                    margin-top: 12px;
                }

                .echoela-action {
                    padding: 8px 16px;
                    border-radius: 20px;
                    border: 1px solid rgba(255, 0, 170, 0.5);
                    background: rgba(255, 0, 170, 0.1);
                    color: #ff00aa;
                    font-size: 13px;
                    cursor: pointer;
                    transition: all 0.2s;
                }

                .echoela-action:hover {
                    background: rgba(255, 0, 170, 0.2);
                    border-color: #ff00aa;
                }

                .echoela-action.primary {
                    background: linear-gradient(135deg, #ff00aa, #cc0088);
                    border: none;
                    color: #fff;
                }

                .echoela-guide {
                    background: rgba(0, 255, 204, 0.1);
                    border-radius: 12px;
                    padding: 16px;
                    margin-bottom: 12px;
                }

                .echoela-guide h4 {
                    margin: 0 0 8px;
                    color: #00ffcc;
                    font-size: 14px;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }

                .echoela-guide ol {
                    margin: 0;
                    padding-left: 20px;
                    color: rgba(255, 255, 255, 0.8);
                    font-size: 13px;
                    line-height: 1.6;
                }

                .echoela-status {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    padding: 8px 12px;
                    background: rgba(255, 255, 255, 0.05);
                    border-radius: 8px;
                    margin-bottom: 8px;
                }

                .echoela-status-dot {
                    width: 8px;
                    height: 8px;
                    border-radius: 50%;
                }

                .echoela-status-dot.available { background: #00ff88; }
                .echoela-status-dot.unavailable { background: #ff4444; }
                .echoela-status-dot.working { background: #00ffcc; animation: pulse 1s infinite; }

                @keyframes pulse {
                    0%, 100% { opacity: 1; }
                    50% { opacity: 0.5; }
                }

                .echoela-status span {
                    flex: 1;
                    font-size: 13px;
                    color: rgba(255, 255, 255, 0.8);
                }

                /* Highlight overlay for features */
                .echoela-highlight {
                    position: absolute;
                    pointer-events: none;
                    border: 2px solid #ff00aa;
                    border-radius: 8px;
                    background: rgba(255, 0, 170, 0.15);
                    animation: highlight-pulse 1.5s infinite;
                    z-index: 9999;
                }

                @keyframes highlight-pulse {
                    0%, 100% {
                        box-shadow: 0 0 10px rgba(255, 0, 170, 0.5);
                        border-color: #ff00aa;
                    }
                    50% {
                        box-shadow: 0 0 20px rgba(255, 0, 170, 0.8);
                        border-color: #ff66cc;
                    }
                }

                .echoela-highlight-label {
                    position: absolute;
                    top: -30px;
                    left: 50%;
                    transform: translateX(-50%);
                    background: #ff00aa;
                    color: #fff;
                    padding: 4px 12px;
                    border-radius: 12px;
                    font-size: 12px;
                    white-space: nowrap;
                    font-weight: 500;
                }

                /* Onboarding overlay */
                #echoela-onboarding {
                    position: fixed;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    background: rgba(0, 0, 0, 0.8);
                    backdrop-filter: blur(10px);
                    -webkit-backdrop-filter: blur(10px);
                    z-index: 10001;
                    display: none;
                    align-items: center;
                    justify-content: center;
                }

                #echoela-onboarding.active {
                    display: flex;
                }

                .onboarding-card {
                    background: rgba(30, 30, 40, 0.95);
                    border-radius: 20px;
                    padding: 32px;
                    max-width: 400px;
                    text-align: center;
                    border: 1px solid rgba(255, 0, 170, 0.3);
                }

                .onboarding-icon {
                    font-size: 64px;
                    margin-bottom: 16px;
                }

                .onboarding-card h2 {
                    margin: 0 0 12px;
                    color: #fff;
                    font-size: 24px;
                }

                .onboarding-card p {
                    margin: 0 0 24px;
                    color: rgba(255, 255, 255, 0.7);
                    font-size: 15px;
                    line-height: 1.6;
                }

                .onboarding-progress {
                    display: flex;
                    justify-content: center;
                    gap: 8px;
                    margin-bottom: 24px;
                }

                .onboarding-dot {
                    width: 8px;
                    height: 8px;
                    border-radius: 50%;
                    background: rgba(255, 255, 255, 0.3);
                }

                .onboarding-dot.active {
                    background: #ff00aa;
                }

                .onboarding-dot.completed {
                    background: #00ffcc;
                }

                .onboarding-buttons {
                    display: flex;
                    gap: 12px;
                    justify-content: center;
                }

                .onboarding-btn {
                    padding: 12px 24px;
                    border-radius: 25px;
                    font-size: 15px;
                    cursor: pointer;
                    transition: all 0.2s;
                }

                .onboarding-btn.skip {
                    background: none;
                    border: 1px solid rgba(255, 255, 255, 0.3);
                    color: rgba(255, 255, 255, 0.7);
                }

                .onboarding-btn.next {
                    background: linear-gradient(135deg, #ff00aa, #00ffcc);
                    border: none;
                    color: #fff;
                    font-weight: 600;
                }

                .onboarding-btn:hover {
                    transform: scale(1.05);
                }

                /* Toast notification */
                .echoela-toast {
                    position: fixed;
                    bottom: 150px;
                    left: 50%;
                    transform: translateX(-50%);
                    background: rgba(30, 30, 40, 0.95);
                    border: 1px solid #ff00aa;
                    border-radius: 12px;
                    padding: 12px 20px;
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    z-index: 10002;
                    animation: toast-in 0.3s ease-out;
                }

                @keyframes toast-in {
                    from { opacity: 0; transform: translateX(-50%) translateY(20px); }
                    to { opacity: 1; transform: translateX(-50%) translateY(0); }
                }

                .echoela-toast.hide {
                    animation: toast-out 0.3s ease-in forwards;
                }

                @keyframes toast-out {
                    to { opacity: 0; transform: translateX(-50%) translateY(20px); }
                }

                .echoela-toast-icon {
                    font-size: 24px;
                }

                .echoela-toast-text {
                    color: #fff;
                    font-size: 14px;
                }

                /* Mobile adjustments */
                @media (max-width: 768px) {
                    #echoela-container {
                        bottom: 140px;
                        right: 16px;
                    }

                    #echoela-button {
                        width: 50px;
                        height: 50px;
                        font-size: 24px;
                    }

                    #echoela-panel {
                        width: calc(100vw - 32px);
                        right: -8px;
                        max-height: 60vh;
                    }

                    .onboarding-card {
                        margin: 16px;
                        padding: 24px;
                    }
                }
            </style>

            <!-- Main Button -->
            <button id="echoela-button" aria-label="Echoela Assistent öffnen">
                🎵
            </button>

            <!-- Panel -->
            <div id="echoela-panel" role="dialog" aria-label="Echoela Assistent">
                <div class="echoela-header">
                    <div class="echoela-avatar">🎵</div>
                    <div class="echoela-title">
                        <h3>Echoela</h3>
                        <p>Dein Musik & Wellness Guide</p>
                    </div>
                    <button class="echoela-close" aria-label="Schließen">&times;</button>
                </div>
                <div class="echoela-content" id="echoela-content">
                    <!-- Dynamic content -->
                </div>
            </div>

            <!-- Onboarding Overlay -->
            <div id="echoela-onboarding">
                <div class="onboarding-card" id="onboarding-card">
                    <!-- Dynamic onboarding content -->
                </div>
            </div>
        `;

        document.body.appendChild(container);

        // Bind events
        this.bindEvents();

        // Show initial content
        this.showMainMenu();
    }

    /**
     * Bind UI events
     */
    bindEvents() {
        const button = document.getElementById('echoela-button');
        const panel = document.getElementById('echoela-panel');
        const closeBtn = panel.querySelector('.echoela-close');

        button.addEventListener('click', () => this.togglePanel());
        closeBtn.addEventListener('click', () => this.closePanel());

        // Close on outside click
        document.addEventListener('click', (e) => {
            if (!panel.contains(e.target) && e.target !== button) {
                this.closePanel();
            }
        });
    }

    /**
     * Toggle panel
     */
    togglePanel() {
        const panel = document.getElementById('echoela-panel');
        panel.classList.toggle('open');

        if (panel.classList.contains('open')) {
            this.showMainMenu();
        }
    }

    /**
     * Close panel
     */
    closePanel() {
        document.getElementById('echoela-panel').classList.remove('open');
    }

    /**
     * Show main menu
     */
    showMainMenu() {
        const content = document.getElementById('echoela-content');

        content.innerHTML = `
            <div class="echoela-message">
                <p>👋 Hallo! Ich bin <strong>Echoela</strong>, dein persönlicher Guide für bio-reaktive Musik und Wellness.</p>
            </div>

            <div class="echoela-actions">
                <button class="echoela-action primary" onclick="echoela.showGuide('camera')">
                    📷 Kamera-Herzfrequenz
                </button>
                <button class="echoela-action" onclick="echoela.showGuide('bluetooth')">
                    ⌚ Smartwatch verbinden
                </button>
                <button class="echoela-action" onclick="echoela.showGuide('breathing')">
                    🌬️ Atemübungen
                </button>
                <button class="echoela-action" onclick="echoela.showGuide('midi')">
                    🎹 MIDI Setup
                </button>
                <button class="echoela-action" onclick="echoela.showFeatureStatus()">
                    📊 Feature Status
                </button>
                <button class="echoela-action" onclick="echoela.startOnboarding()">
                    🚀 Tour starten
                </button>
            </div>
        `;
    }

    /**
     * Show guide
     */
    showGuide(guideType) {
        const content = document.getElementById('echoela-content');
        const guide = this.guides[guideType];

        if (!guide) return;

        let stepsHtml = guide.steps.map((step, i) => `<li>${step}</li>`).join('');

        content.innerHTML = `
            <button class="echoela-action" onclick="echoela.showMainMenu()" style="margin-bottom: 12px;">
                ← Zurück
            </button>

            <div class="echoela-guide">
                <h4>${guide.icon} ${guide.title}</h4>
                <ol>${stepsHtml}</ol>
            </div>

            ${guide.note ? `
                <div class="echoela-message">
                    <p>💡 <strong>Tipp:</strong> ${guide.note}</p>
                </div>
            ` : ''}

            ${guide.warning ? `
                <div class="echoela-message" style="border-left-color: #ffaa00;">
                    <p>⚠️ <strong>Hinweis:</strong> ${guide.warning}</p>
                </div>
            ` : ''}

            ${guide.action ? `
                <button class="echoela-action primary" onclick="${guide.action.callback}" style="width: 100%; margin-top: 12px;">
                    ${guide.action.label}
                </button>
            ` : ''}
        `;

        // Highlight relevant UI elements
        if (guide.highlight) {
            this.highlightElement(document.querySelector(guide.highlight), guide.highlightLabel || 'Hier klicken');
        }
    }

    /**
     * Show feature status
     */
    showFeatureStatus() {
        const content = document.getElementById('echoela-content');

        let statusHtml = Object.entries(this.featureStatus).map(([key, status]) => {
            const dotClass = status.working ? 'working' : (status.available ? 'available' : 'unavailable');
            const statusText = status.working ? 'Aktiv' : (status.available ? 'Verfügbar' : 'Nicht verfügbar');

            return `
                <div class="echoela-status">
                    <div class="echoela-status-dot ${dotClass}"></div>
                    <span>${this.getFeatureNameDE(key)}</span>
                    <span style="color: ${status.working ? '#00ffcc' : (status.available ? '#00ff88' : '#ff4444')}; font-size: 11px;">
                        ${statusText}
                    </span>
                </div>
            `;
        }).join('');

        content.innerHTML = `
            <button class="echoela-action" onclick="echoela.showMainMenu()" style="margin-bottom: 12px;">
                ← Zurück
            </button>

            <h4 style="color: #fff; margin: 0 0 12px; font-size: 14px;">Feature Status</h4>
            ${statusHtml}

            <div class="echoela-message" style="margin-top: 12px;">
                <p>🟢 Verfügbar = Browser unterstützt es<br>
                🔵 Aktiv = Gerade in Benutzung<br>
                🔴 Nicht verfügbar = Browser-Limitation</p>
            </div>
        `;
    }

    /**
     * Highlight an element with magenta border
     */
    highlightElement(element, label = '', duration = 5000) {
        if (!element) return;

        // Get element position
        const rect = element.getBoundingClientRect();

        // Create highlight overlay
        const highlight = document.createElement('div');
        highlight.className = 'echoela-highlight';
        highlight.style.cssText = `
            top: ${rect.top + window.scrollY - 4}px;
            left: ${rect.left + window.scrollX - 4}px;
            width: ${rect.width + 8}px;
            height: ${rect.height + 8}px;
        `;

        if (label) {
            highlight.innerHTML = `<div class="echoela-highlight-label">${label}</div>`;
        }

        document.body.appendChild(highlight);
        this.highlightedElements.add(highlight);

        // Remove after duration
        setTimeout(() => {
            highlight.remove();
            this.highlightedElements.delete(highlight);
        }, duration);

        return highlight;
    }

    /**
     * Clear all highlights
     */
    clearHighlights() {
        this.highlightedElements.forEach(el => el.remove());
        this.highlightedElements.clear();
    }

    /**
     * Announce message (TTS + Toast)
     */
    announce(message, speak = false) {
        // Show toast
        this.showToast(message);

        // Speak if enabled
        if (speak && this.speechSynthesis) {
            const utterance = new SpeechSynthesisUtterance(message);
            utterance.lang = this.currentLanguage === 'de' ? 'de-DE' : 'en-US';
            utterance.rate = 0.9;
            this.speechSynthesis.speak(utterance);
        }
    }

    /**
     * Show toast notification
     */
    showToast(message, icon = '🎵', duration = 4000) {
        // Remove existing toast
        const existing = document.querySelector('.echoela-toast');
        if (existing) existing.remove();

        const toast = document.createElement('div');
        toast.className = 'echoela-toast';
        toast.innerHTML = `
            <span class="echoela-toast-icon">${icon}</span>
            <span class="echoela-toast-text">${message}</span>
        `;

        document.body.appendChild(toast);

        setTimeout(() => {
            toast.classList.add('hide');
            setTimeout(() => toast.remove(), 300);
        }, duration);
    }

    /**
     * Start onboarding
     */
    startOnboarding() {
        this.closePanel();
        this.currentStep = 0;

        const overlay = document.getElementById('echoela-onboarding');
        overlay.classList.add('active');

        this.showOnboardingStep(0);
    }

    /**
     * Show onboarding step
     */
    showOnboardingStep(stepIndex) {
        const card = document.getElementById('onboarding-card');
        const step = this.onboardingSteps[stepIndex];

        if (!step) {
            this.finishOnboarding();
            return;
        }

        // Progress dots
        const dots = this.onboardingSteps.map((_, i) => {
            const cls = i < stepIndex ? 'completed' : (i === stepIndex ? 'active' : '');
            return `<div class="onboarding-dot ${cls}"></div>`;
        }).join('');

        card.innerHTML = `
            <div class="onboarding-icon">${step.icon}</div>
            <h2>${step.title}</h2>
            <p>${step.description}</p>
            <div class="onboarding-progress">${dots}</div>
            <div class="onboarding-buttons">
                <button class="onboarding-btn skip" onclick="echoela.finishOnboarding()">
                    Überspringen
                </button>
                <button class="onboarding-btn next" onclick="echoela.nextOnboardingStep()">
                    ${stepIndex === this.onboardingSteps.length - 1 ? 'Los geht\'s!' : 'Weiter'}
                </button>
            </div>
        `;

        // Highlight relevant element
        if (step.highlight) {
            setTimeout(() => {
                this.highlightElement(document.querySelector(step.highlight), step.highlightLabel, 10000);
            }, 500);
        }
    }

    /**
     * Next onboarding step
     */
    nextOnboardingStep() {
        this.clearHighlights();
        this.currentStep++;

        if (this.currentStep >= this.onboardingSteps.length) {
            this.finishOnboarding();
        } else {
            this.showOnboardingStep(this.currentStep);
        }
    }

    /**
     * Finish onboarding
     */
    finishOnboarding() {
        this.clearHighlights();
        document.getElementById('echoela-onboarding').classList.remove('active');
        this.onboardingComplete = true;
        localStorage.setItem('echoela_visited', 'true');

        this.showToast('🎉 Willkommen bei Echoelmusic!');
    }

    /**
     * Start contextual tips
     */
    startContextualTips() {
        // Check context every 30 seconds
        this._tipInterval = setInterval(() => {
            if (!this.onboardingComplete) return;
            if (Date.now() - this.lastTipTime < this.minTipInterval) return;

            const tip = this.getContextualTip();
            if (tip) {
                this.showToast(tip.message, tip.icon, 6000);
                this.lastTipTime = Date.now();
            }
        }, 30000);
    }

    /**
     * Get contextual tip
     */
    getContextualTip() {
        const tips = this.tips.contextual;

        // Check conditions
        if (!this.featureStatus.bioCamera.working && !this.featureStatus.bioBluetooth.working) {
            return tips.noBioSource;
        }

        if (!this.featureStatus.audio.working) {
            return tips.noAudio;
        }

        // Random general tip
        const generalTips = tips.general;
        return generalTips[Math.floor(Math.random() * generalTips.length)];
    }

    /**
     * Load guides database
     */
    loadGuides() {
        return {
            camera: {
                icon: '📷',
                title: 'Kamera-Herzfrequenz (rPPG)',
                steps: [
                    'Klicke auf "Kamera" bei Bio-Quelle',
                    'Erlaube den Kamerazugriff',
                    'Halte dein Gesicht gut beleuchtet vor die Kamera',
                    'Bleibe 10-15 Sekunden ruhig',
                    'Die Herzfrequenz wird aus Hautfarb-Änderungen erkannt'
                ],
                note: 'Funktioniert am besten bei hellem, gleichmäßigem Licht. Vermeide Gegenlicht.',
                warning: 'Nur für kreative Zwecke. Nicht medizinisch validiert.',
                highlight: '[data-source="camera"]',
                highlightLabel: 'Hier für Kamera',
                action: {
                    label: '📷 Kamera aktivieren',
                    callback: 'echoela.activateCamera()'
                }
            },

            bluetooth: {
                icon: '⌚',
                title: 'Smartwatch / Herzfrequenzgurt',
                steps: [
                    'Aktiviere Bluetooth auf deinem Gerät',
                    'Trage deine Smartwatch oder deinen HR-Gurt',
                    'Klicke auf "Bluetooth" bei Bio-Quelle',
                    'Wähle dein Gerät aus der Liste',
                    'Warte auf die Verbindung (grünes Signal)'
                ],
                note: 'Unterstützt: Polar, Wahoo, Garmin und alle BLE Heart Rate Geräte.',
                warning: 'Web Bluetooth funktioniert in Chrome, Edge und einigen Android-Browsern. iOS Safari wird nicht unterstützt.',
                highlight: '[data-source="bluetooth"]',
                highlightLabel: 'Hier für Bluetooth',
                action: {
                    label: '⌚ Bluetooth verbinden',
                    callback: 'echoela.activateBluetooth()'
                }
            },

            breathing: {
                icon: '🌬️',
                title: 'Atemübungen für Kohärenz',
                steps: [
                    'Wähle ein Atemmuster (z.B. Kohärenz 6/min)',
                    'Folge dem pulsierenden Kreis',
                    'Einatmen wenn der Kreis größer wird',
                    'Ausatmen wenn der Kreis kleiner wird',
                    'Übe 5-10 Minuten für beste Ergebnisse'
                ],
                note: '6 Atemzüge pro Minute (5s ein, 5s aus) aktiviert den Baroreflex und synchronisiert Herz und Gehirn.',
                warning: 'Bei Atemproblemen oder Schwindel: Pause machen und normal atmen.',
                highlight: '.breathing-guide',
                highlightLabel: 'Atemführung'
            },

            midi: {
                icon: '🎹',
                title: 'MIDI Controller verbinden',
                steps: [
                    'Verbinde deinen MIDI Controller per USB',
                    'Öffne die WebApp in Chrome oder Edge',
                    'Der Controller wird automatisch erkannt',
                    'Spiele Noten - sie werden im Synthesizer abgespielt',
                    'CC-Regler steuern Filter und Effekte'
                ],
                note: 'Unterstützt MPE (MIDI Polyphonic Expression) für Instrumente wie Roli Seaboard.',
                warning: 'Web MIDI funktioniert nur in Chromium-Browsern (Chrome, Edge, Opera).',
                highlight: '.piano-keyboard',
                highlightLabel: 'Keyboard'
            },

            wearos: {
                icon: '⌚',
                title: 'WearOS / Google Fit',
                steps: [
                    'Öffne die Echoelmusic WebApp auf deinem Handy',
                    'Verbinde per Bluetooth (siehe Bluetooth-Guide)',
                    'Deine WearOS-Uhr sendet HR-Daten über das Handy',
                    'Alternativ: Companion App auf der Uhr öffnen'
                ],
                note: 'WearOS sendet Herzfrequenz über Bluetooth LE. Die meisten Uhren unterstützen das Standard HR-Profil.',
                warning: 'Direkte WearOS-Integration erfordert die native Android App.'
            }
        };
    }

    /**
     * Load tips database
     */
    loadTips() {
        return {
            contextual: {
                noBioSource: {
                    icon: '💚',
                    message: 'Tipp: Verbinde Kamera oder Smartwatch für echte Bio-Daten!'
                },
                noAudio: {
                    icon: '🔊',
                    message: 'Tipp: Klicke irgendwo um Audio zu aktivieren (Browser-Regel)'
                },
                general: [
                    { icon: '🌬️', message: '6 Atemzüge pro Minute = optimale Herz-Hirn-Kohärenz' },
                    { icon: '💜', message: 'Hohe Kohärenz = harmonischere Visuals & Sound' },
                    { icon: '🎹', message: 'Verbinde einen MIDI-Controller für mehr Kontrolle' },
                    { icon: '🎨', message: 'Probiere verschiedene Visualisierungsmodi!' },
                    { icon: '🥁', message: 'Der Sequencer reagiert auf deine Herzfrequenz' },
                    { icon: '📱', message: 'Diese App funktioniert auch offline als PWA' }
                ]
            }
        };
    }

    /**
     * Load onboarding steps
     */
    loadOnboardingSteps() {
        return [
            {
                icon: '🎵',
                title: 'Willkommen bei Echoelmusic',
                description: 'Verwandle deine Biometrie in Musik und Visuals. Dein Herzschlag steuert den Sound!'
            },
            {
                icon: '💚',
                title: 'Bio-Quelle wählen',
                description: 'Wähle Simulator zum Testen, Kamera für rPPG-Herzfrequenz, oder verbinde deine Smartwatch per Bluetooth.',
                highlight: '.bio-source-buttons',
                highlightLabel: 'Bio-Quelle'
            },
            {
                icon: '🎹',
                title: 'Musik machen',
                description: 'Spiele das Keyboard mit Maus, Touch oder Tasten A-K. Deine Kohärenz beeinflusst den Klang!',
                highlight: '.piano-keyboard',
                highlightLabel: 'Keyboard'
            },
            {
                icon: '🎨',
                title: 'Visualisierungen',
                description: 'Wähle aus 10 Visualmodi. Sie reagieren auf Audio und deine Bio-Daten in Echtzeit.',
                highlight: '.viz-buttons',
                highlightLabel: 'Visuals'
            },
            {
                icon: '🌬️',
                title: 'Atemübungen',
                description: 'Folge dem Atemkreis für Kohärenz-Training. 6/min ist optimal für Herz-Hirn-Synchronisation.',
                highlight: '.breathing-guide',
                highlightLabel: 'Atmung'
            },
            {
                icon: '🚀',
                title: 'Los geht\'s!',
                description: 'Klicke jederzeit auf den Echoela-Button (🎵) für Hilfe, Guides und Tipps. Viel Spaß!'
            }
        ];
    }

    /**
     * Activate camera (helper)
     */
    activateCamera() {
        this.closePanel();
        const cameraBtn = document.querySelector('[data-source="camera"]');
        if (cameraBtn) {
            cameraBtn.click();
            this.highlightElement(cameraBtn, 'Kamera aktiviert!', 3000);
        }
    }

    /**
     * Activate bluetooth (helper)
     */
    activateBluetooth() {
        this.closePanel();
        const btBtn = document.querySelector('[data-source="bluetooth"]');
        if (btBtn) {
            btBtn.click();
            this.highlightElement(btBtn, 'Bluetooth verbinden...', 3000);
        }
    }

    /**
     * Cleanup and destroy
     */
    destroy() {
        // Clear intervals
        if (this._tipInterval) {
            clearInterval(this._tipInterval);
            this._tipInterval = null;
        }
        if (this._bioStatusInterval) {
            clearInterval(this._bioStatusInterval);
            this._bioStatusInterval = null;
        }

        // Clear highlights
        this.clearHighlights();

        // Remove UI
        const container = document.getElementById('echoela-container');
        if (container) {
            container.remove();
        }
        const bioStatus = document.getElementById('echoela-bio-status');
        if (bioStatus) {
            bioStatus.remove();
        }

        this.isActive = false;
        console.log('[Echoela] Destroyed');
    }
}

// Export for module use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = Echoela;
}
