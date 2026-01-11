/**
 * RecordingEngine - Session Recording & Export
 * Records audio, bio data, and visual states
 *
 * Features:
 * - Audio recording via MediaRecorder
 * - Bio data logging (timestamped)
 * - Visual state snapshots
 * - Export to various formats
 * - Playback with bio data sync
 */

class RecordingEngine {
    constructor() {
        // Recording state
        this.isRecording = false;
        this.isPaused = false;
        this.recordingStartTime = null;

        // MediaRecorder for audio
        this.mediaRecorder = null;
        this.audioChunks = [];

        // Bio data log
        this.bioDataLog = [];

        // Visual state log
        this.visualLog = [];

        // Events log
        this.eventsLog = [];

        // Recording options
        this.options = {
            audioBitrate: 128000,
            audioFormat: 'audio/webm;codecs=opus', // or 'audio/mp4' for Safari
            sampleRate: 48000,
            logInterval: 100 // Log bio data every 100ms
        };

        // Timers
        this.logTimer = null;

        // Listeners
        this.listeners = [];
    }

    /**
     * Initialize engine
     */
    async init(audioContext) {
        this.audioContext = audioContext;
        console.log('[RecordingEngine] Initialized');
        return this;
    }

    /**
     * Start recording
     */
    async startRecording(audioSource, options = {}) {
        if (this.isRecording) {
            console.warn('[RecordingEngine] Already recording');
            return false;
        }

        // Merge options
        this.options = { ...this.options, ...options };

        // Reset logs
        this.audioChunks = [];
        this.bioDataLog = [];
        this.visualLog = [];
        this.eventsLog = [];

        // Get audio stream
        let stream;
        if (audioSource instanceof MediaStream) {
            stream = audioSource;
        } else if (audioSource instanceof AudioNode) {
            // Create stream from audio node
            const dest = this.audioContext.createMediaStreamDestination();
            audioSource.connect(dest);
            stream = dest.stream;
        } else {
            // Try to capture system audio
            try {
                stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            } catch (e) {
                console.error('[RecordingEngine] Could not get audio stream:', e);
                return false;
            }
        }

        // Determine best format
        let mimeType = this.options.audioFormat;
        if (!MediaRecorder.isTypeSupported(mimeType)) {
            // Fallback options
            const fallbacks = ['audio/webm', 'audio/mp4', 'audio/ogg'];
            for (const fb of fallbacks) {
                if (MediaRecorder.isTypeSupported(fb)) {
                    mimeType = fb;
                    break;
                }
            }
        }

        // Create MediaRecorder
        try {
            this.mediaRecorder = new MediaRecorder(stream, {
                mimeType,
                audioBitsPerSecond: this.options.audioBitrate
            });
        } catch (e) {
            console.error('[RecordingEngine] Could not create MediaRecorder:', e);
            return false;
        }

        // Handle data
        this.mediaRecorder.ondataavailable = (e) => {
            if (e.data.size > 0) {
                this.audioChunks.push(e.data);
            }
        };

        // Handle stop
        this.mediaRecorder.onstop = () => {
            this.finalizeRecording();
        };

        // Start recording
        this.mediaRecorder.start(1000); // Chunk every second
        this.recordingStartTime = Date.now();
        this.isRecording = true;
        this.isPaused = false;

        // Start bio data logging
        this.startBioLogging();

        // Log start event
        this.logEvent('recording_started');

        this.notifyListeners('started', { timestamp: this.recordingStartTime });
        console.log('[RecordingEngine] Recording started');

        return true;
    }

    /**
     * Stop recording
     */
    stopRecording() {
        if (!this.isRecording) {
            return null;
        }

        // Stop MediaRecorder
        if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
            this.mediaRecorder.stop();
        }

        // Stop bio logging
        this.stopBioLogging();

        // Log stop event
        this.logEvent('recording_stopped');

        this.isRecording = false;
        this.isPaused = false;

        console.log('[RecordingEngine] Recording stopped');
    }

    /**
     * Pause recording
     */
    pauseRecording() {
        if (!this.isRecording || this.isPaused) return;

        if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
            this.mediaRecorder.pause();
        }

        this.isPaused = true;
        this.logEvent('recording_paused');
        this.notifyListeners('paused');
    }

    /**
     * Resume recording
     */
    resumeRecording() {
        if (!this.isRecording || !this.isPaused) return;

        if (this.mediaRecorder && this.mediaRecorder.state === 'paused') {
            this.mediaRecorder.resume();
        }

        this.isPaused = false;
        this.logEvent('recording_resumed');
        this.notifyListeners('resumed');
    }

    /**
     * Start bio data logging
     */
    startBioLogging() {
        this.logTimer = setInterval(() => {
            if (!this.isPaused) {
                this.logBioData();
            }
        }, this.options.logInterval);
    }

    /**
     * Stop bio data logging
     */
    stopBioLogging() {
        if (this.logTimer) {
            clearInterval(this.logTimer);
            this.logTimer = null;
        }
    }

    /**
     * Log bio data snapshot
     */
    logBioData(bioData) {
        if (!this.isRecording) return;

        const entry = {
            timestamp: Date.now() - this.recordingStartTime,
            data: bioData || this.getCurrentBioData()
        };

        this.bioDataLog.push(entry);
    }

    /**
     * Get current bio data (to be called externally)
     */
    getCurrentBioData() {
        // This should be set externally
        return this._currentBioData || {
            heartRate: 0,
            hrv: 0,
            coherence: 0,
            breathingRate: 0
        };
    }

    /**
     * Set current bio data
     */
    setCurrentBioData(data) {
        this._currentBioData = data;
        if (this.isRecording && !this.isPaused) {
            this.logBioData(data);
        }
    }

    /**
     * Log visual state
     */
    logVisualState(state) {
        if (!this.isRecording) return;

        this.visualLog.push({
            timestamp: Date.now() - this.recordingStartTime,
            state
        });
    }

    /**
     * Log event
     */
    logEvent(eventType, data = {}) {
        const entry = {
            timestamp: this.recordingStartTime ? Date.now() - this.recordingStartTime : 0,
            type: eventType,
            data
        };

        this.eventsLog.push(entry);
    }

    /**
     * Finalize recording
     */
    async finalizeRecording() {
        const duration = Date.now() - this.recordingStartTime;

        // Create audio blob
        const audioBlob = new Blob(this.audioChunks, { type: this.mediaRecorder.mimeType });

        // Create recording object
        const recording = {
            id: 'rec_' + Date.now().toString(36),
            createdAt: this.recordingStartTime,
            duration,
            audio: {
                blob: audioBlob,
                mimeType: this.mediaRecorder.mimeType,
                size: audioBlob.size
            },
            bioData: [...this.bioDataLog],
            visualStates: [...this.visualLog],
            events: [...this.eventsLog],
            stats: this.calculateStats()
        };

        this.lastRecording = recording;
        this.notifyListeners('completed', recording);

        console.log('[RecordingEngine] Recording finalized:', {
            duration: duration / 1000 + 's',
            bioDataPoints: this.bioDataLog.length,
            audioSize: (audioBlob.size / 1024).toFixed(1) + ' KB'
        });

        return recording;
    }

    /**
     * Calculate recording stats
     */
    calculateStats() {
        if (this.bioDataLog.length === 0) {
            return { avgHeartRate: 0, avgCoherence: 0, peakCoherence: 0 };
        }

        let totalHR = 0;
        let totalCoherence = 0;
        let peakCoherence = 0;

        for (const entry of this.bioDataLog) {
            if (entry.data) {
                totalHR += entry.data.heartRate || 0;
                totalCoherence += entry.data.coherence || 0;
                peakCoherence = Math.max(peakCoherence, entry.data.coherence || 0);
            }
        }

        const count = this.bioDataLog.length;

        return {
            avgHeartRate: Math.round(totalHR / count),
            avgCoherence: (totalCoherence / count).toFixed(2),
            peakCoherence: peakCoherence.toFixed(2),
            dataPoints: count
        };
    }

    /**
     * Get recording duration
     */
    getDuration() {
        if (!this.recordingStartTime) return 0;
        return Date.now() - this.recordingStartTime;
    }

    /**
     * Get formatted duration
     */
    getFormattedDuration() {
        const ms = this.getDuration();
        const seconds = Math.floor(ms / 1000) % 60;
        const minutes = Math.floor(ms / 60000);
        return `${minutes}:${seconds.toString().padStart(2, '0')}`;
    }

    /**
     * Export recording as ZIP
     */
    async exportAsZip(recording = null) {
        const rec = recording || this.lastRecording;
        if (!rec) {
            console.warn('[RecordingEngine] No recording to export');
            return null;
        }

        // For full ZIP export, we'd need JSZip library
        // For now, export individual files
        return {
            audio: rec.audio.blob,
            bioData: new Blob([JSON.stringify(rec.bioData, null, 2)], { type: 'application/json' }),
            metadata: new Blob([JSON.stringify({
                id: rec.id,
                createdAt: rec.createdAt,
                duration: rec.duration,
                stats: rec.stats
            }, null, 2)], { type: 'application/json' })
        };
    }

    /**
     * Export audio only
     */
    exportAudio(recording = null) {
        const rec = recording || this.lastRecording;
        if (!rec || !rec.audio) return null;

        const url = URL.createObjectURL(rec.audio.blob);
        const extension = rec.audio.mimeType.includes('webm') ? 'webm' :
                         rec.audio.mimeType.includes('mp4') ? 'm4a' :
                         rec.audio.mimeType.includes('ogg') ? 'ogg' : 'audio';

        return {
            url,
            filename: `echoelmusic_${rec.id}.${extension}`,
            blob: rec.audio.blob
        };
    }

    /**
     * Export bio data as CSV
     */
    exportBioDataCSV(recording = null) {
        const rec = recording || this.lastRecording;
        if (!rec || !rec.bioData) return null;

        const headers = ['timestamp_ms', 'heart_rate', 'hrv', 'coherence', 'breathing_rate'];
        const rows = [headers.join(',')];

        for (const entry of rec.bioData) {
            const row = [
                entry.timestamp,
                entry.data?.heartRate || '',
                entry.data?.hrv || '',
                entry.data?.coherence || '',
                entry.data?.breathingRate || ''
            ];
            rows.push(row.join(','));
        }

        const csv = rows.join('\n');
        const blob = new Blob([csv], { type: 'text/csv' });

        return {
            url: URL.createObjectURL(blob),
            filename: `echoelmusic_biodata_${rec.id}.csv`,
            blob
        };
    }

    /**
     * Export bio data as JSON
     */
    exportBioDataJSON(recording = null) {
        const rec = recording || this.lastRecording;
        if (!rec) return null;

        const data = {
            recording: {
                id: rec.id,
                createdAt: rec.createdAt,
                duration: rec.duration
            },
            stats: rec.stats,
            bioData: rec.bioData,
            events: rec.events
        };

        const json = JSON.stringify(data, null, 2);
        const blob = new Blob([json], { type: 'application/json' });

        return {
            url: URL.createObjectURL(blob),
            filename: `echoelmusic_session_${rec.id}.json`,
            blob
        };
    }

    /**
     * Download file helper
     */
    downloadFile(urlOrBlob, filename) {
        const url = urlOrBlob instanceof Blob ? URL.createObjectURL(urlOrBlob) : urlOrBlob;

        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);

        if (urlOrBlob instanceof Blob) {
            URL.revokeObjectURL(url);
        }
    }

    /**
     * Quick export (download audio)
     */
    quickExport() {
        const audio = this.exportAudio();
        if (audio) {
            this.downloadFile(audio.blob, audio.filename);
            return true;
        }
        return false;
    }

    /**
     * Add listener
     */
    addListener(callback) {
        this.listeners.push(callback);
    }

    /**
     * Remove listener
     */
    removeListener(callback) {
        const index = this.listeners.indexOf(callback);
        if (index > -1) {
            this.listeners.splice(index, 1);
        }
    }

    /**
     * Notify listeners
     */
    notifyListeners(event, data) {
        this.listeners.forEach(cb => cb({ event, data }));
    }

    /**
     * Get recording state
     */
    getState() {
        return {
            isRecording: this.isRecording,
            isPaused: this.isPaused,
            duration: this.getDuration(),
            bioDataPoints: this.bioDataLog.length
        };
    }

    /**
     * Get last recording
     */
    getLastRecording() {
        return this.lastRecording;
    }
}

// Export for module use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { RecordingEngine };
}
