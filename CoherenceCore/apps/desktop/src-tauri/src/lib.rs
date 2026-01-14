//! CoherenceCore Desktop - Tauri 2.0 Backend
//!
//! Provides native audio output, camera access, and frequency generation
//! for Windows and Linux platforms.
//!
//! WELLNESS ONLY - NO MEDICAL CLAIMS

use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

/// Safety limits (matching TypeScript constants)
pub const MAX_SESSION_DURATION_MS: u64 = 15 * 60 * 1000; // 15 minutes
pub const MAX_AMPLITUDE: f32 = 0.8;
pub const MAX_DUTY_CYCLE: f32 = 0.7;

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

/// Session state
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionState {
    pub is_playing: bool,
    pub current_frequency_hz: f32,
    pub amplitude: f32,
    pub waveform: String,
    pub session_start_ms: Option<u64>,
    pub elapsed_ms: u64,
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
        }
    }
}

/// Application state
pub struct AppState {
    pub session: Arc<Mutex<SessionState>>,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            session: Arc::new(Mutex::new(SessionState::default())),
        }
    }
}

/// Get current session state
#[tauri::command]
fn get_session_state(state: tauri::State<AppState>) -> Result<SessionState, String> {
    let session = state.session.lock().map_err(|e| e.to_string())?;
    Ok(session.clone())
}

/// Set frequency
#[tauri::command]
fn set_frequency(state: tauri::State<AppState>, frequency_hz: f32) -> Result<(), String> {
    if frequency_hz < 1.0 || frequency_hz > 60.0 {
        return Err("Frequency must be between 1 and 60 Hz".to_string());
    }

    let mut session = state.session.lock().map_err(|e| e.to_string())?;
    session.current_frequency_hz = frequency_hz;
    Ok(())
}

/// Set amplitude (with safety limit)
#[tauri::command]
fn set_amplitude(state: tauri::State<AppState>, amplitude: f32) -> Result<(), String> {
    let safe_amplitude = amplitude.min(MAX_AMPLITUDE).max(0.0);

    let mut session = state.session.lock().map_err(|e| e.to_string())?;
    session.amplitude = safe_amplitude;
    Ok(())
}

/// Set waveform type
#[tauri::command]
fn set_waveform(state: tauri::State<AppState>, waveform: String) -> Result<(), String> {
    let valid_waveforms = ["sine", "square", "triangle", "sawtooth"];
    if !valid_waveforms.contains(&waveform.as_str()) {
        return Err(format!("Invalid waveform: {}", waveform));
    }

    let mut session = state.session.lock().map_err(|e| e.to_string())?;
    session.waveform = waveform;
    Ok(())
}

/// Start audio session
#[tauri::command]
fn start_session(state: tauri::State<AppState>) -> Result<(), String> {
    let mut session = state.session.lock().map_err(|e| e.to_string())?;

    if session.is_playing {
        return Ok(());
    }

    session.is_playing = true;
    session.session_start_ms = Some(
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as u64
    );
    session.elapsed_ms = 0;

    // TODO: Start actual audio output using cpal

    Ok(())
}

/// Stop audio session
#[tauri::command]
fn stop_session(state: tauri::State<AppState>) -> Result<(), String> {
    let mut session = state.session.lock().map_err(|e| e.to_string())?;

    session.is_playing = false;
    session.session_start_ms = None;

    // TODO: Stop audio output

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
    ]
}

/// Get safety limits
#[tauri::command]
fn get_safety_limits() -> serde_json::Value {
    serde_json::json!({
        "maxSessionDurationMs": MAX_SESSION_DURATION_MS,
        "maxAmplitude": MAX_AMPLITUDE,
        "maxDutyCycle": MAX_DUTY_CYCLE,
        "cooldownPeriodMs": 5 * 60 * 1000
    })
}

/// Get disclaimer text
#[tauri::command]
fn get_disclaimer() -> String {
    "Wellness/Informational Tool - No Medical Advice. Not a medical device.".to_string()
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
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
