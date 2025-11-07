//! FFI Bindings for Swift (iOS/macOS)
//!
//! C-compatible API for calling Rust from Swift

use std::ffi::CStr;
use std::os::raw::c_char;
use std::ptr;

// Re-export types from core modules
use blab_audio::{AudioConfig, AudioEngine, BioParameters as AudioBioParams};

/// Opaque pointer to AudioEngine
pub struct BlabAudioEngine {
    engine: AudioEngine,
}

/// Bio-parameters (C-compatible)
#[repr(C)]
pub struct BlabBioParameters {
    pub hrv_coherence: f32,
    pub heart_rate: f32,
    pub breathing_rate: f32,
    pub audio_level: f32,
    pub voice_pitch: f32,
}

impl From<BlabBioParameters> for AudioBioParams {
    fn from(params: BlabBioParameters) -> Self {
        Self {
            hrv_coherence: params.hrv_coherence,
            heart_rate: params.heart_rate,
            breathing_rate: params.breathing_rate,
            audio_level: params.audio_level,
            voice_pitch: params.voice_pitch,
        }
    }
}

// MARK: - Audio Engine FFI

/// Create new audio engine
///
/// # Safety
/// Returns null on failure. Must be freed with `blab_audio_engine_free`.
#[no_mangle]
pub unsafe extern "C" fn blab_audio_engine_new() -> *mut BlabAudioEngine {
    let config = AudioConfig::default();

    match AudioEngine::new(config) {
        Ok(engine) => {
            let boxed = Box::new(BlabAudioEngine { engine });
            Box::into_raw(boxed)
        }
        Err(e) => {
            eprintln!("[FFI] Failed to create audio engine: {}", e);
            ptr::null_mut()
        }
    }
}

/// Free audio engine
///
/// # Safety
/// `engine` must be a valid pointer returned by `blab_audio_engine_new`.
#[no_mangle]
pub unsafe extern "C" fn blab_audio_engine_free(engine: *mut BlabAudioEngine) {
    if !engine.is_null() {
        drop(Box::from_raw(engine));
    }
}

/// Start audio engine
///
/// # Safety
/// `engine` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn blab_audio_engine_start(engine: *mut BlabAudioEngine) -> bool {
    if engine.is_null() {
        return false;
    }

    let engine = &mut *engine;
    match engine.engine.start() {
        Ok(_) => true,
        Err(e) => {
            eprintln!("[FFI] Failed to start audio engine: {}", e);
            false
        }
    }
}

/// Stop audio engine
///
/// # Safety
/// `engine` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn blab_audio_engine_stop(engine: *mut BlabAudioEngine) {
    if !engine.is_null() {
        let engine = &mut *engine;
        engine.engine.stop();
    }
}

/// Update bio-reactive parameters
///
/// # Safety
/// `engine` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn blab_audio_engine_update_bio(
    engine: *mut BlabAudioEngine,
    params: BlabBioParameters,
) {
    if !engine.is_null() {
        let engine = &*engine;
        engine.engine.update_bio_parameters(params.into());
    }
}

/// Get audio latency in milliseconds
///
/// # Safety
/// `engine` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn blab_audio_engine_get_latency_ms(engine: *const BlabAudioEngine) -> f32 {
    if engine.is_null() {
        return 0.0;
    }

    let engine = &*engine;
    engine.engine.get_latency_ms()
}

// MARK: - Version Info

/// Get BLAB core version
///
/// # Safety
/// Returned string is static and valid for the lifetime of the program.
#[no_mangle]
pub unsafe extern "C" fn blab_version() -> *const c_char {
    static VERSION: &str = concat!("BLAB Core v", env!("CARGO_PKG_VERSION"), "\0");
    VERSION.as_ptr() as *const c_char
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ffi_lifecycle() {
        unsafe {
            // Create engine
            let engine = blab_audio_engine_new();
            assert!(!engine.is_null());

            // Get latency
            let latency = blab_audio_engine_get_latency_ms(engine);
            assert!(latency > 0.0);

            // Update bio params
            let bio_params = BlabBioParameters {
                hrv_coherence: 0.8,
                heart_rate: 72.0,
                breathing_rate: 6.0,
                audio_level: 0.5,
                voice_pitch: 440.0,
            };
            blab_audio_engine_update_bio(engine, bio_params);

            // Free engine
            blab_audio_engine_free(engine);
        }
    }

    #[test]
    fn test_version() {
        unsafe {
            let version = blab_version();
            assert!(!version.is_null());

            let version_str = CStr::from_ptr(version).to_str().unwrap();
            assert!(version_str.starts_with("BLAB Core"));
        }
    }
}
