//! CoherenceCore Desktop - Tauri 2.0 Backend
//!
//! Provides native audio output, camera access, and frequency generation
//! for Windows and Linux platforms using cpal for low-latency audio.
//!
//! Supports class-compliant USB audio interfaces across all platforms.
//!
//! WELLNESS ONLY - NO MEDICAL CLAIMS

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Device, Host, Stream, StreamConfig, SupportedStreamConfigRange};
use serde::{Deserialize, Serialize};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

/// Safety limits (matching TypeScript constants)
pub const MAX_SESSION_DURATION_MS: u64 = 15 * 60 * 1000; // 15 minutes
pub const MAX_AMPLITUDE: f32 = 0.8;
pub const MAX_DUTY_CYCLE: f32 = 0.7;
pub const COOLDOWN_PERIOD_MS: u64 = 5 * 60 * 1000; // 5 minutes
pub const SAMPLE_RATE: u32 = 44100;

/// Waveform types
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum WaveformType {
    Sine,
    Square,
    Triangle,
    Sawtooth,
}

impl Default for WaveformType {
    fn default() -> Self {
        WaveformType::Sine
    }
}

impl std::str::FromStr for WaveformType {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "sine" => Ok(WaveformType::Sine),
            "square" => Ok(WaveformType::Square),
            "triangle" => Ok(WaveformType::Triangle),
            "sawtooth" => Ok(WaveformType::Sawtooth),
            _ => Err(format!("Invalid waveform: {}", s)),
        }
    }
}

/// Frequency preset configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrequencyPreset {
    pub id: String,
    pub name: String,
    pub frequency_range_hz: (f32, f32),
    pub primary_frequency_hz: f32,
    pub research: String,
    pub target: String,
}

/// Audio host information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioHostInfo {
    pub id: String,
    pub name: String,
    pub is_default: bool,
}

/// Audio device information (class-compliant USB and built-in)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioDeviceInfo {
    pub id: String,
    pub name: String,
    pub host_id: String,
    pub is_default: bool,
    pub is_usb: bool,
    pub sample_rates: Vec<u32>,
    pub min_buffer_size: u32,
    pub max_buffer_size: u32,
    pub channels: u16,
}

/// Audio configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioConfig {
    pub device_id: Option<String>,
    pub sample_rate: u32,
    pub buffer_size: u32,
}

impl Default for AudioConfig {
    fn default() -> Self {
        Self {
            device_id: None, // Use system default
            sample_rate: 44100,
            buffer_size: 512,
        }
    }
}

/// Session state
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionState {
    pub is_playing: bool,
    pub current_frequency_hz: f32,
    pub amplitude: f32,
    pub waveform: String,
    pub session_start_ms: Option<u64>,
    pub elapsed_ms: u64,
    pub remaining_ms: u64,
}

impl Default for SessionState {
    fn default() -> Self {
        Self {
            is_playing: false,
            current_frequency_hz: 40.0,
            amplitude: 0.5,
            waveform: "sine".to_string(),
            session_start_ms: None,
            elapsed_ms: 0,
            remaining_ms: MAX_SESSION_DURATION_MS,
        }
    }
}

/// Audio parameters shared with audio thread
#[derive(Debug)]
pub struct AudioParams {
    pub frequency_hz: AtomicU64,    // f32 bits stored as u64
    pub amplitude: AtomicU64,       // f32 bits stored as u64
    pub waveform: Mutex<WaveformType>,
    pub is_playing: AtomicBool,
}

impl AudioParams {
    pub fn new() -> Self {
        Self {
            frequency_hz: AtomicU64::new(40.0_f32.to_bits() as u64),
            amplitude: AtomicU64::new(0.5_f32.to_bits() as u64),
            waveform: Mutex::new(WaveformType::Sine),
            is_playing: AtomicBool::new(false),
        }
    }

    pub fn get_frequency(&self) -> f32 {
        f32::from_bits(self.frequency_hz.load(Ordering::Relaxed) as u32)
    }

    pub fn set_frequency(&self, hz: f32) {
        self.frequency_hz.store(hz.to_bits() as u64, Ordering::Relaxed);
    }

    pub fn get_amplitude(&self) -> f32 {
        f32::from_bits(self.amplitude.load(Ordering::Relaxed) as u32)
    }

    pub fn set_amplitude(&self, amp: f32) {
        self.amplitude.store(amp.to_bits() as u64, Ordering::Relaxed);
    }
}

/// Application state
pub struct AppState {
    pub session: Arc<Mutex<SessionState>>,
    pub audio_params: Arc<AudioParams>,
    pub audio_stream: Mutex<Option<Stream>>,
    pub audio_config: Arc<Mutex<AudioConfig>>,
    pub timer_handle: Mutex<Option<thread::JoinHandle<()>>>,
    pub timer_running: Arc<AtomicBool>,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            session: Arc::new(Mutex::new(SessionState::default())),
            audio_params: Arc::new(AudioParams::new()),
            audio_stream: Mutex::new(None),
            audio_config: Arc::new(Mutex::new(AudioConfig::default())),
            timer_handle: Mutex::new(None),
            timer_running: Arc::new(AtomicBool::new(false)),
        }
    }
}

/// Generate waveform sample
fn generate_sample(waveform: WaveformType, phase: f32, amplitude: f32) -> f32 {
    let safe_amplitude = amplitude.min(MAX_AMPLITUDE);
    match waveform {
        WaveformType::Sine => safe_amplitude * (2.0 * std::f32::consts::PI * phase).sin(),
        WaveformType::Square => {
            if phase < 0.5 {
                safe_amplitude
            } else {
                -safe_amplitude
            }
        }
        WaveformType::Triangle => {
            if phase < 0.5 {
                safe_amplitude * (4.0 * phase - 1.0)
            } else {
                safe_amplitude * (3.0 - 4.0 * phase)
            }
        }
        WaveformType::Sawtooth => safe_amplitude * (2.0 * phase - 1.0),
    }
}

/// Create audio stream for frequency output
fn create_audio_stream(
    params: Arc<AudioParams>,
) -> Result<Stream, String> {
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .ok_or("No audio output device found")?;

    let config = device
        .default_output_config()
        .map_err(|e| format!("Failed to get default output config: {}", e))?;

    let sample_rate = config.sample_rate().0 as f32;
    let channels = config.channels() as usize;

    let mut phase: f32 = 0.0;

    let stream = device
        .build_output_stream(
            &config.into(),
            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                let frequency = params.get_frequency();
                let amplitude = params.get_amplitude();
                let waveform = *params.waveform.lock().unwrap();
                let is_playing = params.is_playing.load(Ordering::Relaxed);

                let phase_increment = frequency / sample_rate;

                for frame in data.chunks_mut(channels) {
                    let sample = if is_playing {
                        generate_sample(waveform, phase, amplitude)
                    } else {
                        0.0
                    };

                    for channel in frame.iter_mut() {
                        *channel = sample;
                    }

                    phase += phase_increment;
                    if phase >= 1.0 {
                        phase -= 1.0;
                    }
                }
            },
            |err| eprintln!("Audio stream error: {}", err),
            None,
        )
        .map_err(|e| format!("Failed to build output stream: {}", e))?;

    Ok(stream)
}

/// Get current timestamp in milliseconds
fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis() as u64
}

/// Get current session state
#[tauri::command]
fn get_session_state(state: tauri::State<AppState>) -> Result<SessionState, String> {
    let mut session = state.session.lock().map_err(|e| e.to_string())?;

    // Update elapsed/remaining time if playing
    if session.is_playing {
        if let Some(start) = session.session_start_ms {
            let now = now_ms();
            session.elapsed_ms = now.saturating_sub(start);
            session.remaining_ms = MAX_SESSION_DURATION_MS.saturating_sub(session.elapsed_ms);
        }
    }

    Ok(session.clone())
}

/// Set frequency
#[tauri::command]
fn set_frequency(state: tauri::State<AppState>, frequency_hz: f32) -> Result<(), String> {
    if frequency_hz < 1.0 || frequency_hz > 60.0 {
        return Err("Frequency must be between 1 and 60 Hz".to_string());
    }

    // Update session state
    {
        let mut session = state.session.lock().map_err(|e| e.to_string())?;
        session.current_frequency_hz = frequency_hz;
    }

    // Update audio parameters (real-time safe)
    state.audio_params.set_frequency(frequency_hz);

    Ok(())
}

/// Set amplitude (with safety limit)
#[tauri::command]
fn set_amplitude(state: tauri::State<AppState>, amplitude: f32) -> Result<(), String> {
    let safe_amplitude = amplitude.min(MAX_AMPLITUDE).max(0.0);

    // Update session state
    {
        let mut session = state.session.lock().map_err(|e| e.to_string())?;
        session.amplitude = safe_amplitude;
    }

    // Update audio parameters (real-time safe)
    state.audio_params.set_amplitude(safe_amplitude);

    Ok(())
}

/// Set waveform type
#[tauri::command]
fn set_waveform(state: tauri::State<AppState>, waveform: String) -> Result<(), String> {
    let waveform_type: WaveformType = waveform
        .parse()
        .map_err(|e: String| e)?;

    // Update session state
    {
        let mut session = state.session.lock().map_err(|e| e.to_string())?;
        session.waveform = waveform;
    }

    // Update audio parameters
    {
        let mut wf = state.audio_params.waveform.lock().map_err(|e| e.to_string())?;
        *wf = waveform_type;
    }

    Ok(())
}

/// Start audio session with safety timer
#[tauri::command]
fn start_session(
    state: tauri::State<AppState>,
    app_handle: tauri::AppHandle,
) -> Result<(), String> {
    // Check if already playing
    {
        let session = state.session.lock().map_err(|e| e.to_string())?;
        if session.is_playing {
            return Ok(());
        }
    }

    // Create and start audio stream if not exists
    {
        let mut stream_lock = state.audio_stream.lock().map_err(|e| e.to_string())?;
        if stream_lock.is_none() {
            let stream = create_audio_stream(Arc::clone(&state.audio_params))?;
            stream.play().map_err(|e| format!("Failed to start audio: {}", e))?;
            *stream_lock = Some(stream);
        }
    }

    // Enable audio output
    state.audio_params.is_playing.store(true, Ordering::Relaxed);

    // Update session state
    let start_time = now_ms();
    {
        let mut session = state.session.lock().map_err(|e| e.to_string())?;
        session.is_playing = true;
        session.session_start_ms = Some(start_time);
        session.elapsed_ms = 0;
        session.remaining_ms = MAX_SESSION_DURATION_MS;
    }

    // Start safety timer
    state.timer_running.store(true, Ordering::Relaxed);
    let timer_running = Arc::clone(&state.timer_running);
    let audio_params = Arc::clone(&state.audio_params);
    let session_state = Arc::clone(&state.session);

    let timer_handle = thread::spawn(move || {
        while timer_running.load(Ordering::Relaxed) {
            thread::sleep(Duration::from_secs(1));

            let elapsed = {
                let session = session_state.lock().unwrap();
                if let Some(start) = session.session_start_ms {
                    now_ms().saturating_sub(start)
                } else {
                    0
                }
            };

            // Safety cutoff check
            if elapsed >= MAX_SESSION_DURATION_MS {
                println!("[CoherenceCore] Safety cutoff reached - 15 minutes");

                // Stop audio
                audio_params.is_playing.store(false, Ordering::Relaxed);

                // Update session state
                {
                    let mut session = session_state.lock().unwrap();
                    session.is_playing = false;
                    session.session_start_ms = None;
                    session.elapsed_ms = MAX_SESSION_DURATION_MS;
                    session.remaining_ms = 0;
                }

                timer_running.store(false, Ordering::Relaxed);
                break;
            }
        }
    });

    // Store timer handle
    {
        let mut handle_lock = state.timer_handle.lock().map_err(|e| e.to_string())?;
        *handle_lock = Some(timer_handle);
    }

    println!("[CoherenceCore] Session started");
    Ok(())
}

/// Stop audio session
#[tauri::command]
fn stop_session(state: tauri::State<AppState>) -> Result<(), String> {
    // Stop timer
    state.timer_running.store(false, Ordering::Relaxed);

    // Stop audio output
    state.audio_params.is_playing.store(false, Ordering::Relaxed);

    // Update session state
    {
        let mut session = state.session.lock().map_err(|e| e.to_string())?;
        session.is_playing = false;
        session.session_start_ms = None;
        session.remaining_ms = MAX_SESSION_DURATION_MS;
    }

    // Wait for timer thread to finish (non-blocking)
    {
        let mut handle_lock = state.timer_handle.lock().map_err(|e| e.to_string())?;
        if let Some(handle) = handle_lock.take() {
            // Don't block - timer will exit on its own
            drop(handle);
        }
    }

    println!("[CoherenceCore] Session stopped");
    Ok(())
}

/// Get frequency presets
#[tauri::command]
fn get_presets() -> Vec<FrequencyPreset> {
    vec![
        FrequencyPreset {
            id: "osteo-sync".to_string(),
            name: "Osteo-Sync".to_string(),
            frequency_range_hz: (35.0, 45.0),
            primary_frequency_hz: 40.0,
            research: "Rubin et al. (2006) - Low-magnitude mechanical signals".to_string(),
            target: "Osteoblast activity optimization".to_string(),
        },
        FrequencyPreset {
            id: "myo-resonance".to_string(),
            name: "Myo-Resonance".to_string(),
            frequency_range_hz: (45.0, 50.0),
            primary_frequency_hz: 47.5,
            research: "Judex & Rubin (2010) - Mechanical influences".to_string(),
            target: "Myofibril coherence, fibrosis reduction".to_string(),
        },
        FrequencyPreset {
            id: "neural-flow".to_string(),
            name: "Neural-Flow".to_string(),
            frequency_range_hz: (38.0, 42.0),
            primary_frequency_hz: 40.0,
            research: "Iaccarino et al. (2016) - Gamma entrainment".to_string(),
            target: "Neural gamma oscillation, focus".to_string(),
        },
        FrequencyPreset {
            id: "vaso-pulse".to_string(),
            name: "Vaso-Pulse".to_string(),
            frequency_range_hz: (8.0, 12.0),
            primary_frequency_hz: 10.0,
            research: "Kerschan-Schindl et al. (2001) - Blood flow".to_string(),
            target: "Peripheral blood flow enhancement".to_string(),
        },
        FrequencyPreset {
            id: "lymph-flow".to_string(),
            name: "Lymph-Flow".to_string(),
            frequency_range_hz: (1.0, 5.0),
            primary_frequency_hz: 3.0,
            research: "Piller (2015) - Lymphatic drainage".to_string(),
            target: "Lymphatic system support".to_string(),
        },
        FrequencyPreset {
            id: "custom".to_string(),
            name: "Custom".to_string(),
            frequency_range_hz: (1.0, 60.0),
            primary_frequency_hz: 40.0,
            research: "User-defined frequency".to_string(),
            target: "Custom application".to_string(),
        },
    ]
}

/// Get safety limits
#[tauri::command]
fn get_safety_limits() -> serde_json::Value {
    serde_json::json!({
        "maxSessionDurationMs": MAX_SESSION_DURATION_MS,
        "maxAmplitude": MAX_AMPLITUDE,
        "maxDutyCycle": MAX_DUTY_CYCLE,
        "cooldownPeriodMs": COOLDOWN_PERIOD_MS
    })
}

/// Get disclaimer text
#[tauri::command]
fn get_disclaimer() -> String {
    "Wellness/Informational Tool - No Medical Advice. Not a medical device. \
    This application is designed for general wellness purposes only and should \
    not be used to diagnose, treat, cure, or prevent any disease or health condition. \
    Always consult a healthcare professional before starting any wellness program."
        .to_string()
}

/// Check if audio is available
#[tauri::command]
fn check_audio_available() -> Result<bool, String> {
    let host = cpal::default_host();
    Ok(host.default_output_device().is_some())
}

// ============================================================================
// CLASS-COMPLIANT AUDIO DEVICE MANAGEMENT
// ============================================================================

/// Get available audio hosts (WASAPI, ASIO, CoreAudio, ALSA, etc.)
#[tauri::command]
fn get_audio_hosts() -> Vec<AudioHostInfo> {
    let available_hosts = cpal::available_hosts();
    let default_host_id = cpal::default_host().id();

    available_hosts
        .iter()
        .map(|host_id| {
            let name = match host_id.name() {
                "WASAPI" => "Windows Audio (WASAPI)".to_string(),
                "ASIO" => "ASIO (Low Latency)".to_string(),
                "CoreAudio" => "macOS Core Audio".to_string(),
                "ALSA" => "Linux ALSA".to_string(),
                "PulseAudio" => "Linux PulseAudio".to_string(),
                "JACK" => "JACK Audio".to_string(),
                name => name.to_string(),
            };

            AudioHostInfo {
                id: host_id.name().to_string(),
                name,
                is_default: *host_id == default_host_id,
            }
        })
        .collect()
}

/// Get available audio output devices (includes class-compliant USB)
#[tauri::command]
fn get_audio_devices() -> Result<Vec<AudioDeviceInfo>, String> {
    let mut devices = Vec::new();

    for host_id in cpal::available_hosts() {
        let host = cpal::host_from_id(host_id)
            .map_err(|e| format!("Failed to get host: {}", e))?;

        let default_device_name = host
            .default_output_device()
            .and_then(|d| d.name().ok());

        let output_devices = host.output_devices()
            .map_err(|e| format!("Failed to enumerate devices: {}", e))?;

        for device in output_devices {
            let device_name = device.name().unwrap_or_else(|_| "Unknown Device".to_string());

            // Get supported configurations
            let configs: Vec<SupportedStreamConfigRange> = device
                .supported_output_configs()
                .map(|c| c.collect())
                .unwrap_or_default();

            // Extract sample rates
            let mut sample_rates: Vec<u32> = Vec::new();
            let mut min_buffer = 64u32;
            let mut max_buffer = 4096u32;
            let mut max_channels = 2u16;

            for config in &configs {
                // Common sample rates
                for rate in [44100, 48000, 88200, 96000, 176400, 192000] {
                    if config.min_sample_rate().0 <= rate && rate <= config.max_sample_rate().0 {
                        if !sample_rates.contains(&rate) {
                            sample_rates.push(rate);
                        }
                    }
                }

                max_channels = max_channels.max(config.channels());

                // Buffer size hints (platform dependent)
                if let Some(buf_range) = config.buffer_size() {
                    match buf_range {
                        cpal::SupportedBufferSize::Range { min, max } => {
                            min_buffer = min_buffer.min(*min);
                            max_buffer = max_buffer.max(*max);
                        }
                        cpal::SupportedBufferSize::Unknown => {}
                    }
                }
            }

            sample_rates.sort();

            // Detect USB devices (heuristic based on name)
            let is_usb = device_name.to_lowercase().contains("usb")
                || device_name.to_lowercase().contains("focusrite")
                || device_name.to_lowercase().contains("scarlett")
                || device_name.to_lowercase().contains("steinberg")
                || device_name.to_lowercase().contains("presonus")
                || device_name.to_lowercase().contains("motu")
                || device_name.to_lowercase().contains("universal audio")
                || device_name.to_lowercase().contains("rme")
                || device_name.to_lowercase().contains("apogee")
                || device_name.to_lowercase().contains("audient")
                || device_name.to_lowercase().contains("ssl")
                || device_name.to_lowercase().contains("behringer")
                || device_name.to_lowercase().contains("arturia")
                || device_name.to_lowercase().contains("native instruments");

            let device_id = format!("{}:{}", host_id.name(), device_name);

            devices.push(AudioDeviceInfo {
                id: device_id,
                name: device_name.clone(),
                host_id: host_id.name().to_string(),
                is_default: Some(&device_name) == default_device_name.as_ref(),
                is_usb,
                sample_rates,
                min_buffer_size: min_buffer,
                max_buffer_size: max_buffer,
                channels: max_channels,
            });
        }
    }

    Ok(devices)
}

/// Get current audio configuration
#[tauri::command]
fn get_audio_config(state: tauri::State<AppState>) -> Result<AudioConfig, String> {
    let config = state.audio_config.lock().map_err(|e| e.to_string())?;
    Ok(config.clone())
}

/// Set audio device and configuration
#[tauri::command]
fn set_audio_config(
    state: tauri::State<AppState>,
    device_id: Option<String>,
    sample_rate: Option<u32>,
    buffer_size: Option<u32>,
) -> Result<(), String> {
    // Validate sample rate
    if let Some(rate) = sample_rate {
        if ![44100, 48000, 88200, 96000, 176400, 192000].contains(&rate) {
            return Err("Unsupported sample rate".to_string());
        }
    }

    // Validate buffer size (must be power of 2)
    if let Some(size) = buffer_size {
        if size < 32 || size > 8192 || (size & (size - 1)) != 0 {
            return Err("Buffer size must be power of 2 between 32 and 8192".to_string());
        }
    }

    // Update config
    {
        let mut config = state.audio_config.lock().map_err(|e| e.to_string())?;
        if let Some(id) = device_id {
            config.device_id = Some(id);
        }
        if let Some(rate) = sample_rate {
            config.sample_rate = rate;
        }
        if let Some(size) = buffer_size {
            config.buffer_size = size;
        }
    }

    // If currently playing, restart stream with new config
    let is_playing = state.audio_params.is_playing.load(Ordering::Relaxed);
    if is_playing {
        // Stop current stream
        {
            let mut stream_lock = state.audio_stream.lock().map_err(|e| e.to_string())?;
            if let Some(stream) = stream_lock.take() {
                drop(stream);
            }
        }

        // Create new stream with updated config
        let config = state.audio_config.lock().map_err(|e| e.to_string())?;
        let stream = create_audio_stream_with_config(
            Arc::clone(&state.audio_params),
            &config,
        )?;
        stream.play().map_err(|e| format!("Failed to start audio: {}", e))?;

        let mut stream_lock = state.audio_stream.lock().map_err(|e| e.to_string())?;
        *stream_lock = Some(stream);
    }

    println!("[CoherenceCore] Audio config updated");
    Ok(())
}

/// Create audio stream with specific device and configuration
fn create_audio_stream_with_config(
    params: Arc<AudioParams>,
    config: &AudioConfig,
) -> Result<Stream, String> {
    let host = cpal::default_host();

    // Get device (default or specified)
    let device = if let Some(ref device_id) = config.device_id {
        // Parse device_id format: "HostName:DeviceName"
        let parts: Vec<&str> = device_id.splitn(2, ':').collect();
        if parts.len() != 2 {
            return Err("Invalid device ID format".to_string());
        }

        let host_name = parts[0];
        let device_name = parts[1];

        // Find the host
        let host_id = cpal::available_hosts()
            .into_iter()
            .find(|h| h.name() == host_name)
            .ok_or("Audio host not found")?;

        let target_host = cpal::host_from_id(host_id)
            .map_err(|e| format!("Failed to get host: {}", e))?;

        // Find the device
        target_host
            .output_devices()
            .map_err(|e| format!("Failed to enumerate devices: {}", e))?
            .find(|d| d.name().ok().as_deref() == Some(device_name))
            .ok_or_else(|| format!("Device '{}' not found", device_name))?
    } else {
        host.default_output_device()
            .ok_or("No audio output device found")?
    };

    println!("[CoherenceCore] Using audio device: {:?}", device.name());

    // Get supported config
    let supported_config = device
        .default_output_config()
        .map_err(|e| format!("Failed to get output config: {}", e))?;

    let sample_rate = config.sample_rate as f32;
    let channels = supported_config.channels() as usize;

    let mut phase: f32 = 0.0;

    let stream = device
        .build_output_stream(
            &supported_config.into(),
            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                let frequency = params.get_frequency();
                let amplitude = params.get_amplitude();
                let waveform = *params.waveform.lock().unwrap();
                let is_playing = params.is_playing.load(Ordering::Relaxed);

                let phase_increment = frequency / sample_rate;

                for frame in data.chunks_mut(channels) {
                    let sample = if is_playing {
                        generate_sample(waveform, phase, amplitude)
                    } else {
                        0.0
                    };

                    for channel in frame.iter_mut() {
                        *channel = sample;
                    }

                    phase += phase_increment;
                    if phase >= 1.0 {
                        phase -= 1.0;
                    }
                }
            },
            |err| eprintln!("Audio stream error: {}", err),
            None,
        )
        .map_err(|e| format!("Failed to build output stream: {}", e))?;

    Ok(stream)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(AppState::default())
        .invoke_handler(tauri::generate_handler![
            get_session_state,
            set_frequency,
            set_amplitude,
            set_waveform,
            start_session,
            stop_session,
            get_presets,
            get_safety_limits,
            get_disclaimer,
            check_audio_available,
            // Class-compliant USB audio support
            get_audio_hosts,
            get_audio_devices,
            get_audio_config,
            set_audio_config,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
