/**
 * SyncEngine - Cross-Platform Synchronization
 * Enables real-time sync between devices and platforms
 *
 * Features:
 * - WebSocket server sync
 * - WebRTC peer-to-peer (P2P) for low latency
 * - BroadcastChannel for same-browser tabs
 * - LocalStorage for offline persistence
 * - Session state sharing
 * - Multi-platform support (iOS, Android, Windows, macOS, Linux)
 */

class SyncEngine {
    constructor() {
        // Connection state
        this.isConnected = false;
        this.connectionType = null; // 'websocket', 'webrtc', 'broadcast', 'offline'

        // Peer tracking
        this.peers = new Map();
        this.localPeerId = this.generatePeerId();

        // WebSocket
        this.ws = null;
        this.wsReconnectAttempts = 0;
        this.maxReconnectAttempts = 5;

        // WebRTC
        this.peerConnections = new Map();
        this.dataChannels = new Map();

        // BroadcastChannel (same browser sync)
        this.broadcastChannel = null;

        // Session state
        this.sessionState = {
            bio: { heartRate: 72, hrv: 45, coherence: 0.5, breathingRate: 6 },
            audio: { bpm: 120, volume: 0.8, filterCutoff: 0.5 },
            visual: { mode: 'mandala', intensity: 0.5 },
            sequencer: { isPlaying: false, pattern: null }
        };

        // Listeners
        this.listeners = new Map();

        // Sync interval
        this.syncInterval = null;
        this.syncRate = 100; // 10 Hz sync rate

        // Platform detection
        this.platform = this.detectPlatform();
    }

    /**
     * Generate unique peer ID
     */
    generatePeerId() {
        return 'peer_' + Math.random().toString(36).substr(2, 9) + '_' + Date.now().toString(36);
    }

    /**
     * Detect platform
     */
    detectPlatform() {
        const ua = navigator.userAgent;

        if (/iPhone|iPad|iPod/.test(ua)) return 'ios';
        if (/Android/.test(ua)) return 'android';
        if (/Windows/.test(ua)) return 'windows';
        if (/Mac/.test(ua)) return 'macos';
        if (/Linux/.test(ua)) return 'linux';

        return 'web';
    }

    /**
     * Initialize sync engine
     */
    async init(options = {}) {
        console.log('[SyncEngine] Initializing for platform:', this.platform);

        // Start BroadcastChannel for same-browser sync
        this.initBroadcastChannel();

        // Load persisted state
        this.loadPersistedState();

        // Start sync loop
        this.startSyncLoop();

        // Try WebSocket if server URL provided
        if (options.serverUrl) {
            await this.connectWebSocket(options.serverUrl);
        }

        return this;
    }

    /**
     * Initialize BroadcastChannel
     */
    initBroadcastChannel() {
        if (!('BroadcastChannel' in window)) {
            console.log('[SyncEngine] BroadcastChannel not supported');
            return;
        }

        this.broadcastChannel = new BroadcastChannel('echoelmusic_sync');

        this.broadcastChannel.onmessage = (event) => {
            this.handleSyncMessage(event.data, 'broadcast');
        };

        this.connectionType = 'broadcast';
        this.isConnected = true;
        console.log('[SyncEngine] BroadcastChannel ready');
    }

    /**
     * Connect to WebSocket server
     */
    async connectWebSocket(serverUrl) {
        return new Promise((resolve, reject) => {
            try {
                this.ws = new WebSocket(serverUrl);

                this.ws.onopen = () => {
                    console.log('[SyncEngine] WebSocket connected');
                    this.isConnected = true;
                    this.connectionType = 'websocket';
                    this.wsReconnectAttempts = 0;

                    // Send join message
                    this.ws.send(JSON.stringify({
                        type: 'join',
                        peerId: this.localPeerId,
                        platform: this.platform
                    }));

                    this.emit('connected', { type: 'websocket' });
                    resolve();
                };

                this.ws.onmessage = (event) => {
                    const data = JSON.parse(event.data);
                    this.handleSyncMessage(data, 'websocket');
                };

                this.ws.onclose = () => {
                    console.log('[SyncEngine] WebSocket disconnected');
                    this.isConnected = false;
                    this.emit('disconnected', { type: 'websocket' });

                    // Attempt reconnect
                    if (this.wsReconnectAttempts < this.maxReconnectAttempts) {
                        this.wsReconnectAttempts++;
                        setTimeout(() => this.connectWebSocket(serverUrl), 2000 * this.wsReconnectAttempts);
                    }
                };

                this.ws.onerror = (error) => {
                    console.error('[SyncEngine] WebSocket error:', error);
                    reject(error);
                };

            } catch (error) {
                console.error('[SyncEngine] WebSocket connection failed:', error);
                reject(error);
            }
        });
    }

    /**
     * Create WebRTC peer connection
     */
    async createPeerConnection(remotePeerId) {
        const config = {
            iceServers: [
                { urls: 'stun:stun.l.google.com:19302' },
                { urls: 'stun:stun1.l.google.com:19302' }
            ]
        };

        const pc = new RTCPeerConnection(config);

        pc.onicecandidate = (event) => {
            if (event.candidate) {
                this.sendSignaling({
                    type: 'ice-candidate',
                    candidate: event.candidate,
                    to: remotePeerId
                });
            }
        };

        pc.ondatachannel = (event) => {
            this.setupDataChannel(event.channel, remotePeerId);
        };

        pc.onconnectionstatechange = () => {
            console.log('[SyncEngine] P2P state:', pc.connectionState);
            if (pc.connectionState === 'connected') {
                this.emit('peerConnected', { peerId: remotePeerId });
            }
        };

        this.peerConnections.set(remotePeerId, pc);
        return pc;
    }

    /**
     * Setup data channel
     */
    setupDataChannel(channel, peerId) {
        channel.onopen = () => {
            console.log('[SyncEngine] Data channel open with:', peerId);
            this.dataChannels.set(peerId, channel);
        };

        channel.onmessage = (event) => {
            const data = JSON.parse(event.data);
            this.handleSyncMessage(data, 'webrtc');
        };

        channel.onclose = () => {
            console.log('[SyncEngine] Data channel closed with:', peerId);
            this.dataChannels.delete(peerId);
        };
    }

    /**
     * Initiate P2P connection
     */
    async initiateP2P(remotePeerId) {
        const pc = await this.createPeerConnection(remotePeerId);

        const dataChannel = pc.createDataChannel('sync', {
            ordered: false,
            maxRetransmits: 0
        });
        this.setupDataChannel(dataChannel, remotePeerId);

        const offer = await pc.createOffer();
        await pc.setLocalDescription(offer);

        this.sendSignaling({
            type: 'offer',
            offer: offer,
            to: remotePeerId
        });
    }

    /**
     * Handle incoming signaling
     */
    async handleSignaling(data) {
        const { type, from } = data;

        switch (type) {
            case 'offer':
                const pc = await this.createPeerConnection(from);
                await pc.setRemoteDescription(data.offer);
                const answer = await pc.createAnswer();
                await pc.setLocalDescription(answer);
                this.sendSignaling({
                    type: 'answer',
                    answer: answer,
                    to: from
                });
                break;

            case 'answer':
                const existingPc = this.peerConnections.get(from);
                if (existingPc) {
                    await existingPc.setRemoteDescription(data.answer);
                }
                break;

            case 'ice-candidate':
                const pcForIce = this.peerConnections.get(from);
                if (pcForIce) {
                    await pcForIce.addIceCandidate(data.candidate);
                }
                break;
        }
    }

    /**
     * Send signaling message
     */
    sendSignaling(data) {
        data.from = this.localPeerId;

        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type: 'signaling', ...data }));
        }
    }

    /**
     * Handle sync message
     */
    handleSyncMessage(data, source) {
        const { type, peerId, payload } = data;

        switch (type) {
            case 'state-update':
                this.mergeState(payload);
                this.emit('stateUpdated', { peerId, state: payload });
                break;

            case 'bio-update':
                this.sessionState.bio = { ...this.sessionState.bio, ...payload };
                this.emit('bioUpdated', { peerId, bio: payload });
                break;

            case 'audio-update':
                this.sessionState.audio = { ...this.sessionState.audio, ...payload };
                this.emit('audioUpdated', { peerId, audio: payload });
                break;

            case 'visual-update':
                this.sessionState.visual = { ...this.sessionState.visual, ...payload };
                this.emit('visualUpdated', { peerId, visual: payload });
                break;

            case 'peer-joined':
                this.peers.set(peerId, { platform: payload.platform, joinedAt: Date.now() });
                this.emit('peerJoined', { peerId, platform: payload.platform });
                break;

            case 'peer-left':
                this.peers.delete(peerId);
                this.emit('peerLeft', { peerId });
                break;

            case 'signaling':
                this.handleSignaling(data);
                break;
        }
    }

    /**
     * Merge incoming state
     */
    mergeState(newState) {
        if (newState.bio) {
            this.sessionState.bio = { ...this.sessionState.bio, ...newState.bio };
        }
        if (newState.audio) {
            this.sessionState.audio = { ...this.sessionState.audio, ...newState.audio };
        }
        if (newState.visual) {
            this.sessionState.visual = { ...this.sessionState.visual, ...newState.visual };
        }
        if (newState.sequencer) {
            this.sessionState.sequencer = { ...this.sessionState.sequencer, ...newState.sequencer };
        }
    }

    /**
     * Send state update
     */
    sendStateUpdate(category, data) {
        const message = {
            type: `${category}-update`,
            peerId: this.localPeerId,
            payload: data,
            timestamp: Date.now()
        };

        // Update local state
        if (this.sessionState[category]) {
            this.sessionState[category] = { ...this.sessionState[category], ...data };
        }

        // Send via all available channels
        this.broadcast(message);

        // Persist to localStorage
        this.persistState();
    }

    /**
     * Broadcast message to all channels
     */
    broadcast(message) {
        // BroadcastChannel (same browser)
        if (this.broadcastChannel) {
            this.broadcastChannel.postMessage(message);
        }

        // WebSocket (server)
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(message));
        }

        // WebRTC (P2P)
        this.dataChannels.forEach((channel, peerId) => {
            if (channel.readyState === 'open') {
                channel.send(JSON.stringify(message));
            }
        });
    }

    /**
     * Start sync loop
     */
    startSyncLoop() {
        if (this.syncInterval) return;

        this.syncInterval = setInterval(() => {
            // Emit local state periodically for sync
            this.emit('syncTick', { state: this.sessionState });
        }, this.syncRate);
    }

    /**
     * Stop sync loop
     */
    stopSyncLoop() {
        if (this.syncInterval) {
            clearInterval(this.syncInterval);
            this.syncInterval = null;
        }
    }

    /**
     * Persist state to localStorage
     */
    persistState() {
        try {
            localStorage.setItem('echoelmusic_session', JSON.stringify({
                state: this.sessionState,
                peerId: this.localPeerId,
                timestamp: Date.now()
            }));
        } catch (e) {
            console.warn('[SyncEngine] Could not persist state:', e);
        }
    }

    /**
     * Load persisted state
     */
    loadPersistedState() {
        try {
            const stored = localStorage.getItem('echoelmusic_session');
            if (stored) {
                const { state, timestamp } = JSON.parse(stored);
                // Only restore if less than 1 hour old
                if (Date.now() - timestamp < 3600000) {
                    this.sessionState = { ...this.sessionState, ...state };
                    console.log('[SyncEngine] Restored session state');
                }
            }
        } catch (e) {
            console.warn('[SyncEngine] Could not load persisted state:', e);
        }
    }

    /**
     * Create join code
     */
    createJoinCode() {
        const code = Math.random().toString(36).substr(2, 6).toUpperCase();
        return code;
    }

    /**
     * Join session with code
     */
    async joinSession(code) {
        // This would connect to a session via the server
        console.log('[SyncEngine] Joining session:', code);

        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({
                type: 'join-session',
                code: code,
                peerId: this.localPeerId,
                platform: this.platform
            }));
        }
    }

    /**
     * Leave session
     */
    leaveSession() {
        // Close all P2P connections
        this.peerConnections.forEach((pc, peerId) => {
            pc.close();
        });
        this.peerConnections.clear();
        this.dataChannels.clear();

        // Notify server
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({
                type: 'leave-session',
                peerId: this.localPeerId
            }));
        }
    }

    /**
     * Event listener system
     */
    on(event, callback) {
        if (!this.listeners.has(event)) {
            this.listeners.set(event, []);
        }
        this.listeners.get(event).push(callback);
    }

    off(event, callback) {
        if (this.listeners.has(event)) {
            const callbacks = this.listeners.get(event);
            const index = callbacks.indexOf(callback);
            if (index > -1) {
                callbacks.splice(index, 1);
            }
        }
    }

    emit(event, data) {
        if (this.listeners.has(event)) {
            this.listeners.get(event).forEach(cb => cb(data));
        }
    }

    /**
     * Get current state
     */
    getState() {
        return { ...this.sessionState };
    }

    /**
     * Get connected peers
     */
    getPeers() {
        return Array.from(this.peers.entries()).map(([id, info]) => ({
            id,
            ...info
        }));
    }

    /**
     * Get connection info
     */
    getConnectionInfo() {
        return {
            isConnected: this.isConnected,
            connectionType: this.connectionType,
            localPeerId: this.localPeerId,
            platform: this.platform,
            peerCount: this.peers.size
        };
    }

    /**
     * Cleanup
     */
    destroy() {
        this.stopSyncLoop();

        if (this.broadcastChannel) {
            this.broadcastChannel.close();
        }

        if (this.ws) {
            this.ws.close();
        }

        this.peerConnections.forEach(pc => pc.close());
        this.peerConnections.clear();
        this.dataChannels.clear();

        console.log('[SyncEngine] Destroyed');
    }
}

// Export for module use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { SyncEngine };
}
