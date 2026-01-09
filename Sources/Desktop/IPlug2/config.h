#pragma once

/**
 * Echoelmusic Plugin Configuration
 * iPlug2 Framework - MIT License
 */

// Plugin metadata
#define PLUG_NAME "Echoelmusic"
#define PLUG_MFR "Echoelmusic"
#define PLUG_VERSION_HEX 0x00010000  // 1.0.0
#define PLUG_VERSION_STR "1.0.0"
#define PLUG_UNIQUE_ID 'Echo'
#define PLUG_MFR_ID 'Echm'

// Plugin URLs
#define PLUG_URL_STR "https://echoelmusic.com"
#define PLUG_EMAIL_STR "michaelterbuyken@gmail.com"
#define PLUG_COPYRIGHT_STR "Copyright 2024-2025 Echoelmusic"

// Plugin type configuration
#define PLUG_TYPE 1  // 0 = effect, 1 = instrument
#define PLUG_DOES_MIDI_IN 1
#define PLUG_DOES_MIDI_OUT 0
#define PLUG_DOES_MPE 1
#define PLUG_DOES_STATE_CHUNKS 1
#define PLUG_HAS_UI 1
#define PLUG_TAIL 0

// Audio configuration
#define PLUG_CHANNEL_IO "0-2"  // 0 inputs, 2 outputs (synth)
#define PLUG_LATENCY 0
#define PLUG_SHARED_RESOURCES 0

// UI configuration
#define PLUG_WIDTH 800
#define PLUG_HEIGHT 600
#define PLUG_FPS 60

// VST3 specific
#define VST3_SUBCATEGORY "Instrument|Synth"
#define VST3_SUPPORTS_SIDECHAINING 0

// AU specific
#define AUV2_ENTRY EchoelmusicEntry
#define AUV2_ENTRY_STR "EchoelmusicEntry"
#define AUV2_FACTORY Echoelmusic_Factory
#define AUV2_VIEW_CLASS EchoelmusicView
#define AUV2_VIEW_CLASS_STR "EchoelmusicView"

// CLAP specific
#define CLAP_MANUAL_URL "https://echoelmusic.com/manual"
#define CLAP_SUPPORT_URL "https://echoelmusic.com/support"
#define CLAP_FEATURES "instrument", "synthesizer", "stereo"

// AAX specific (Pro Tools)
#define AAX_TYPE_IDS 'EEF1', 'EEF2'
#define AAX_TYPE_IDS_AUDIOSUITE 'EEA1', 'EEA2'
#define AAX_PLUG_MFR_STR "Echoelmusic"
#define AAX_PLUG_NAME_STR "Echoelmusic\nBio-Synth"
#define AAX_PLUG_CATEGORY_STR "Synth"
#define AAX_DOES_AUDIOSUITE 0

// Standalone specific
#define APP_NUM_CHANNELS 2
#define APP_N_VECTOR_WAIT 0
#define APP_MULT 1
#define APP_COPY_AUV3 0
#define APP_SIGNAL_VECTOR_SIZE 64
#define APP_RESIZABLE 0
#define APP_ENABLE_SYSEX 0
