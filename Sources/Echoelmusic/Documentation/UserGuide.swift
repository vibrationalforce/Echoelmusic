import Foundation

/// Comprehensive user guide for Echoelmusic platform
/// Covers getting started, features, device setup, sessions, collaboration, streaming, wellness, and troubleshooting
public struct UserGuide {
    public static let version = "1.0.0"
    public static let lastUpdated = "2026-01-07"

    // MARK: - Getting Started Guide

    public static let gettingStarted = """
    # Getting Started with Echoelmusic

    ## First Launch

    ### Welcome Setup
    1. Open Echoelmusic on your device
    2. Review the welcome screen and privacy information
    3. Accept terms of service and health disclaimer
    4. Proceed to permissions setup

    ### Required Permissions

    #### HealthKit Access (iOS/watchOS)
    - **Purpose:** Read biometric data (heart rate, HRV, breathing)
    - **How to Grant:** When prompted, tap "Allow" and select health categories
    - **What we read:** Heart rate, HRV (SDNN, RMSSD), steps, workouts
    - **Data Usage:** Real-time bio-reactive audio/visual control
    - **Privacy:** Data stays on-device; no cloud sync without explicit consent

    #### Microphone Access
    - **Purpose:** Voice input and pitch detection
    - **How to Grant:** When prompted, tap "Allow" in system dialog
    - **What we use:** Voice commands, pitch detection, breathing sound analysis
    - **Recording:** Only active during recording sessions; no background recording

    #### Camera Access (for Face Tracking)
    - **Purpose:** Facial expression mapping to audio/visual parameters
    - **How to Grant:** When prompted, tap "Allow"
    - **What we use:** Smile, jaw open, brow raise detection
    - **Privacy:** Real-time processing only; no video saved unless you export

    #### Bluetooth/Wireless
    - **Purpose:** Connect to Apple Watch, MIDI controllers, audio interfaces
    - **How to Grant:** System prompts when needed

    ### Quick Tutorial
    1. **Watch Intro Video** (~2 min): Tap "Tutorial" on home screen
    2. **Try Demo Session** (~5 min): Select "Demo Mode" preset
    3. **Explore Presets** (5-15 min): Try 2-3 different presets from home
    4. **Read Tips**: Tap info icon (i) on any screen for feature explanation

    ### Initial Setup Options
    - **Biometric Tracking:** Enable HealthKit integration (recommended)
    - **Audio Output:** Select audio interface (built-in speaker or external)
    - **Visual Preference:** Choose your preferred visualization mode
    - **Language:** English, German, Japanese, Spanish, French, Chinese, Korean, Portuguese, Italian, Russian, Arabic, Hindi

    ## System Requirements

    ### Apple Devices
    - **iOS:** 15.0+
    - **macOS:** 12.0+
    - **watchOS:** 8.0+
    - **tvOS:** 15.0+
    - **visionOS:** 1.0+

    ### Android
    - **Android:** 8.0 (API 26)+
    - **RAM:** 4GB minimum, 6GB+ recommended

    ### Audio
    - **Bluetooth Headphones/Speakers:** Recommended
    - **Audio Interface:** Optional (for advanced setup)
    - **Sample Rate:** 44.1kHz or 48kHz
    """

    // MARK: - Core Features Guide

    public static let coreFeatures = """
    # Core Features Guide

    ## Bio-Reactive Audio Explained

    ### What is Bio-Reactive Audio?
    Bio-reactive audio uses your body's natural signals (heart rate, breathing, facial expressions) to control sound in real-time. As your physiology changes, the music evolves with you.

    ### Biometric Signals

    | Signal | Range | Audio Effect |
    |--------|-------|--------------|
    | Heart Rate | 60-100 bpm | Tempo, bass pulse |
    | HRV | 0-200 ms | LFO rate, timbre richness |
    | Coherence | 0-100% | Reverb, harmonic complexity |
    | Breathing | 6-20 breaths/min | Filter sweep, sustain length |
    | Jaw Open | 0-1.0 | Brightness, filter cutoff |
    | Smile | 0-1.0 | Harmonic density, effects |

    ## Coherence Basics

    ### What is Coherence?
    Coherence measures how organized and synchronized your heart rhythm is. Higher coherence indicates:
    - Greater calmness and focus
    - Better stress resilience
    - Improved emotional regulation

    **Note:** Coherence is for informational/wellness purposes only, not medical diagnosis.

    ### Coherence States
    - **0-20%:** Baseline (normal daily activity)
    - **20-40%:** Stressed or excited
    - **40-60%:** Calm and focused
    - **60-80%:** Deep meditation or flow state
    - **80-100%:** Peak coherence (rare, very deep states)

    ### Bio-Reactive Color Feedback
    - **Red** (0-20%): Energetic
    - **Orange** (20-40%): Active
    - **Yellow** (40-60%): Balanced
    - **Green** (60-80%): Calm
    - **Blue** (80-100%): Deeply coherent

    ## Spatial Audio Explained

    ### 3D Spatial Audio
    Sound sources positioned around you in three dimensions:
    - **Left/Right (Pan):** Audio panning across stereo field
    - **Front/Back (Distance):** Perceived distance of sound source
    - **Up/Down (Height):** Spatial height sensation

    ### Spatial Audio Modes

    | Mode | Description | Best For |
    |------|-------------|----------|
    | **Grid** | 3x3 speaker array | Focus, structured sessions |
    | **Fibonacci** | Golden spiral arrangement | Meditation, flow states |
    | **Spherical** | Surrounding hemisphere | Immersion, 360° audio |
    | **Binaural** | Psychoacoustic stereo | Headphones, private listening |
    | **Ambisonics** | Full-sphere encoding | VR/immersive applications |

    ### Bio-Reactive Spatial Control
    - **High Coherence:** Fibonacci geometry (harmonious arrangement)
    - **Low Coherence:** Grid geometry (grounded, structured)
    - **Jaw Movement:** Controls spatial sweep direction
    - **Head Position:** Follows your head (on supported devices)

    ## Visualization Modes

    ### Available Visualizations

    **Quantum-Inspired**
    - Coherence Field: Order vs chaos display
    - Quantum Tunnel: Vortex effect responding to audio
    - Wave Function: Probability amplitude visualization

    **Bio-Reactive**
    - Mandala: Rotating patterns driven by coherence
    - Heartbeat: Pulsing shapes matching heart rate
    - Breathing Field: Waves expanding/contracting with breath

    **Geometric**
    - Sacred Geometry: Flower of Life, Metatron's Cube
    - Fractal Explorer: Infinite zoom into Mandelbrot set
    - Platonic Solids: Rotating polyhedra responding to audio

    **Abstract**
    - Particle System: Thousands of particles driven by audio
    - Spectrum Analyzer: Real-time frequency visualization
    - Waveform Display: Audio waveform with effects

    ### Switching Visualizations
    1. Tap the visualization area during session
    2. Swipe left/right to browse modes
    3. Tap to select visualization
    4. Tap outside to return to session

    ## Real-Time Audio Parameters

    ### Controllable Parameters
    - **Tempo:** 40-200 BPM
    - **Brightness:** Filter cutoff frequency
    - **Reverb:** Space and decay time
    - **Harmonic Density:** Number of voices/overtones
    - **Distortion:** Saturation level
    - **Delay/Echo:** Repeating effects

    ### Parameter Mapping
    - **Heart Rate** → Tempo and bass pulse
    - **HRV** → LFO modulation amount
    - **Coherence** → Reverb wet and harmonic richness
    - **Breathing** → Filter sweep and sustain
    - **Face Tracking** → Brightness, effects intensity

    ### Manual Control
    - Swipe up/down: Adjust selected parameter
    - Pinch: Fine-tune parameter value
    - Rotate: Cycle through parameters
    """

    // MARK: - Device Setup Guide

    public static let deviceSetup = """
    # Device Setup Guide

    ## Apple Watch Pairing

    ### Initial Setup
    1. Open Echoelmusic on iPhone
    2. Go to Settings → Apple Watch
    3. Tap "Start Pairing"
    4. On watch, open Echoelmusic app (auto-installs from iPhone)
    5. Follow on-watch prompts to pair

    ### Watch Features
    - **Real-time Coherence Display:** See current coherence percentage
    - **Heart Rate Monitor:** Continuous HR and HRV reading
    - **Complications:** Add Echoelmusic to watch face for quick access
    - **Session Control:** Start/stop sessions from watch
    - **Haptic Feedback:** Feel coherence pulses and alerts

    ### Troubleshooting Watch Connection
    - Ensure watch is within 30 feet of iPhone
    - Turn Bluetooth off/on on both devices
    - Restart Echoelmusic on both devices
    - Check iPhone-watch pairing in Settings → Bluetooth

    ## MIDI Controllers

    ### Supported Controllers
    - **Ableton Push 3:** Full LED feedback, 64 pads
    - **Native Instruments:** Traktor, Maschine, Komplete series
    - **Akai:** APC, MPK, MPC series
    - **Novation:** Launchpad, Launchkey series
    - **Arturia:** KeyLab, MiniLab, BeatStep
    - **Roland:** TR-808, Boutique series
    - **Any Standard MIDI:** USB or Bluetooth MIDI device

    ### Connecting MIDI Controller
    1. Connect controller via USB or Bluetooth
    2. Open Echoelmusic Settings → MIDI Setup
    3. Tap "Scan for Devices"
    4. Select your controller from list
    5. Test connection by touching controller

    ### MIDI Mapping
    - **Pads (0-63):** Trigger samples or notes
    - **Faders (CC 7, 14-20):** Control parameters (reverb, filter, etc.)
    - **Knobs (CC 21-28):** Fine adjust audio parameters
    - **Transport (CC 64):** Play/stop, record control

    ### Push 3 Special Features
    - **LED Ring Feedback:** Real-time visual feedback on knobs
    - **RGB Pads:** Color-coded by parameter
    - **Pressure Sensitivity:** Add expression to notes
    - **Haptic Feedback:** Tactile confirmation of actions

    ## DMX Lighting Control

    ### Setup Requirements
    - **DMX Interface:** USB-to-DMX adaptor or Art-Net compatible device
    - **Lighting Fixtures:** DMX-compatible moving heads, PARs, or LED strips
    - **Network (Art-Net):** Ethernet connection or WiFi with AoIP capable device
    - **Cable:** DMX5 (3-pin or 5-pin) for direct connection

    ### Connecting DMX

    **Direct USB-DMX:**
    1. Connect USB-DMX adaptor to computer/device
    2. Open Echoelmusic → Settings → Lighting
    3. Select "USB DMX Adaptor"
    4. Tap "Scan" to detect devices
    5. Test with "Strobe Test" button

    **Art-Net (Network):**
    1. Connect device to same network as Art-Net node
    2. Open Echoelmusic → Settings → Lighting
    3. Select "Art-Net"
    4. Enter Art-Net device IP address
    5. Configure universe (typically 0)

    ### DMX Mapping
    - **Color:** Coherence → RGB or HSV
    - **Intensity:** Audio level → Brightness
    - **Pan/Tilt:** Gesture position → Movement
    - **Gobo:** Audio frequency bands → Pattern selection
    - **Strobe:** Beat detection → Strobe speed

    ## Audio Interfaces

    ### Supported Interfaces

    **Professional Series**
    - Universal Audio: Apollo Twin, Volt
    - Focusrite: Scarlett, Clarett
    - RME: Babyface, MADIface
    - MOTU: Interface series
    - Apogee: Symphony, Ensemble

    **DJ/Live**
    - Pioneer: DJM series
    - Technics: SL series
    - Rane: Sixty-Two mixer

    **Budget-Friendly**
    - Behringer: UMC series
    - M-Audio: M-Track series
    - Focusrite: Solo, 2i2

    ### Connecting Audio Interface
    1. Connect interface to device via USB or Thunderbolt
    2. Power on interface
    3. Open Echoelmusic → Settings → Audio
    4. Select "Audio Interface" from dropdown
    5. Choose input and output channels
    6. Adjust buffer size (64, 128, 256 samples)

    ### Latency Settings
    - **Buffer Size 64:** <5ms latency (requires powerful device)
    - **Buffer Size 128:** ~5-10ms latency (recommended)
    - **Buffer Size 256:** 10-20ms latency (more stable)
    - **Buffer Size 512:** 20-40ms latency (for recording)

    ### Sample Rate Configuration
    - **44.1 kHz:** CD quality, minimal CPU usage
    - **48 kHz:** Professional standard
    - **96 kHz:** High resolution, higher CPU usage
    - **192 kHz:** Extreme quality, significant CPU load
    """

    // MARK: - Session Guide

    public static let sessionGuide = """
    # Session Guide

    ## Starting Your First Session

    ### Quick Start
    1. Tap "New Session" on home screen
    2. Choose preset category (Bio-Reactive, Musical, Wellness, etc.)
    3. Select a preset from list
    4. Tap "Start" to begin
    5. Allow HealthKit/Bluetooth permissions when prompted

    ### Session Screen
    - **Top Left:** Session duration timer
    - **Center:** Visualization display
    - **Bottom:** Parameter controls and presets
    - **Top Right:** Settings and session menu

    ## Preset System

    ### What are Presets?
    Presets are saved configurations with specific:
    - Audio engine settings (synthesis type, effects)
    - Bio-reactive mappings (which signals affect which parameters)
    - Visual modes and colors
    - Spatial audio geometry
    - Recording settings

    ### Preset Categories

    | Category | Purpose | Best For |
    |----------|---------|----------|
    | **Bio-Reactive** | Real-time biometric control | Meditation, focus, coherence training |
    | **Musical** | Genre-based synthesis | Music listening, composition |
    | **Wellness** | Breathing guides, meditation | Relaxation, breathing exercises |
    | **Quantum** | Quantum-inspired effects | Creativity, exploration |
    | **Streaming** | Optimized for broadcast | Social media, live performance |
    | **Collaboration** | Multi-device sync | Group sessions, performances |
    | **Performance** | High CPU optimization | Large events, festivals |
    | **Creative** | AI-powered generation | Art creation, experimentation |

    ### Popular Presets
    - **Deep Meditation:** 10-minute guided coherence building
    - **Active Flow:** High-energy movement tracking
    - **Healing Soundscape:** Bio-reactive ambient with nature sounds
    - **Electronic Dream:** Synth-based audio visualization
    - **Orchestral Live:** Cinematic composition engine

    ### Creating Custom Presets
    1. Start a session with base preset
    2. Adjust parameters (see Session Parameters)
    3. Fine-tune bio-reactive mappings
    4. Change visualization and colors
    5. Tap "Save as New Preset"
    6. Enter name and description
    7. Choose category for organization

    ## Session Parameters

    ### Core Audio Parameters

    **Synthesis Engine**
    - Type: Wavetable, FM, Granular, Physical Modeling
    - Oscillators: Number of voices (1-64)
    - Tuning: Equal, just, Pythagorean, custom

    **Effects Rack**
    - Reverb: Room size, decay time, wet/dry
    - Delay: Time, feedback, diffusion
    - Filter: Cutoff, resonance, filter type (LP, BP, HP)
    - Distortion: Drive, tone, saturation
    - Chorus: Rate, depth, mix

    **Bio-Reactive Mapping**
    - Heart Rate → Tempo: Range and curve type
    - Coherence → Reverb: Amount of reverb change
    - Breathing → Filter: Sweep range and speed
    - Jaw/Smile → Brightness: Filter response curve

    ### Adjusting Parameters in Session
    1. Tap parameter name to select
    2. Use slider or input field to adjust
    3. Parameter changes apply in real-time
    4. Long-press to reset parameter to default

    ## Recording Sessions

    ### Starting a Recording
    1. Begin a session normally
    2. Tap "Record" button (red dot, top right)
    3. Confirm recording will save audio file
    4. Recording begins; button turns red
    5. Continue session normally

    ### Recording Quality Options
    - **Uncompressed (WAV):** Full quality, larger file size
    - **ALAC:** Apple lossless compression, medium quality
    - **AAC:** Compressed, smaller file size
    - **MP3:** Standard compression, broad compatibility

    ### Recording Multiple Tracks
    1. Enable "Multi-Track Recording" in settings
    2. Start recording
    3. Each audio element recorded separately:
       - Bio-reactive synthesizer
       - MIDI input
       - Effects/reverb
       - Overall mix

    ### Stopping and Saving
    1. Tap "Stop" button when done
    2. Recording saves automatically
    3. Recordings appear in "Library" → "Recordings"
    4. Access via "Share" or "Edit" buttons

    ## Exporting Sessions

    ### Export Options

    **Audio File**
    - Format: WAV, ALAC, AAC, MP3
    - Duration: Full session or selected time range
    - Bitrate: 128 kbps, 256 kbps, 320 kbps (compressed)

    **Video File**
    - Resolution: 1080p, 2K, 4K
    - Frame Rate: 30fps, 60fps
    - Include: Audio + visualization

    **Session Data**
    - JSON: Complete session parameters and mapping
    - Timeline: Edit points and segment markers

    **to Streaming Platforms**
    - YouTube, Twitch, Facebook, Instagram, TikTok
    - Direct upload with metadata

    ### Exporting Steps
    1. In session, tap "Share" or "Export"
    2. Choose format and settings
    3. Select "Share" destination or "Save" locally
    4. Confirm and wait for processing
    5. File appears in device storage or platform
    """

    // MARK: - Collaboration Guide

    public static let collaborationGuide = """
    # Collaboration Guide

    ## Creating a Collaborative Session

    ### Starting a Group Room
    1. Tap "Collaborate" on home screen
    2. Tap "Create Room"
    3. Enter room name and description
    4. Set privacy level: Public, Friends, Private
    5. Select preset category for the room
    6. Choose capacity: 2-1000 participants
    7. Tap "Create" and share invite link

    ### Room Settings
    - **Public:** Anyone can discover and join
    - **Friends:** Only invited friends can access
    - **Private:** Invite-only, hidden from discovery
    - **Locked:** Room leader prevents new joins mid-session

    ## Inviting Participants

    ### Share Invite Link
    1. In room, tap "Invite" button
    2. Tap "Copy Link" or "Share"
    3. Send via messaging app, email, social media
    4. Recipients tap link to join

    ### Direct Invite
    1. Tap "Invite" button
    2. Select "Add Friends"
    3. Choose from contacts or search usernames
    4. Participants receive notification
    5. Tap notification to join

    ### Join Request System
    - Requests sent when room is full
    - Room leader approves/denies joins
    - Pending requests listed in room settings

    ## Group Coherence Synchronization

    ### How Group Coherence Works
    - Each participant's biometric data streams to room
    - Platform calculates group average coherence
    - Individual coherence shown with color indicator
    - Group coherence displayed as unified color

    ### Coherence Metrics
    - **Individual HR Sync:** Heart rate variation across group
    - **Collective HRV:** Average HRV of all participants
    - **Group Coherence %:** Unified coherence measurement (0-100%)
    - **Entrainment Level:** How much participants synchronize

    ### Achieving High Group Coherence
    1. Start with guided breathing exercise
    2. Synchronize pace with group rhythm
    3. Focus on shared intention
    4. Watch group coherence meter rise
    5. Maintain focus for 5-10 minutes

    ### Group Coherence States
    - **0-20%:** Individual focus, low sync
    - **20-40%:** Slight entrainment
    - **40-60%:** Good synchronization
    - **60-80%:** Strong group coherence
    - **80-100%:** Quantum entanglement (rare achievement)

    ## Chat and Communication

    ### Sending Messages
    1. Tap "Chat" icon during session
    2. Type message in input field
    3. Press "Send" or hit Return
    4. Messages appear with timestamp

    ### Rich Reactions
    - Emoji reactions to messages
    - Heart, clap, fire, thumbs up, etc.
    - Quick emotional expression without text

    ### @Mentions
    - Start with @ to mention participant
    - Mentioned user receives notification
    - Keep chat organized and directed

    ### Message Search
    - Tap search icon in chat
    - Type keyword to find previous messages
    - Filter by participant, date, emoji reaction

    ## Roles and Permissions

    ### Room Leader
    - Create and delete rooms
    - Control room settings (privacy, capacity)
    - Approve/deny join requests
    - Remove disruptive participants
    - Lock/unlock room
    - Change preset during session

    ### Moderators (Optional)
    - Remove inappropriate messages
    - Mute participants (if enabled)
    - Monitor group coherence
    - No room creation/deletion permission

    ### Participants
    - Join public/invited rooms
    - Participate in sessions
    - Send messages and reactions
    - View group coherence metrics

    ## Session Recording in Groups

    ### Group Recording
    1. Leader enables "Record Group Session"
    2. All audio/video captured with visualization
    3. Mixing includes all participant audio
    4. Recording saved to leader's library
    5. Leader can share with group

    ### Privacy Considerations
    - Announce recording at start
    - All participants consent to recording
    - Can disable personal audio capture
    - Recording remains on leader's device (unless shared)

    ## Troubleshooting Collaboration

    **Participants Can't Hear Each Other**
    - Check internet connection for all users
    - Verify audio permissions granted
    - Try disconnecting and rejoining

    **High Latency/Lag**
    - Reduce video quality settings
    - Move closer to WiFi router
    - Close other apps using internet
    - Try 4G instead of WiFi (or vice versa)

    **Group Coherence Not Syncing**
    - Ensure HealthKit/biometric permission granted
    - Check that wearables are connected
    - Refresh biometric data: Settings → HealthKit
    """

    // MARK: - Streaming Guide

    public static let streamingGuide = """
    # Streaming Guide

    ## Platform Setup

    ### YouTube Live
    1. Log in with YouTube account in Echoelmusic settings
    2. Create new YouTube live event
    3. Copy streaming key from YouTube Studio
    4. Paste in Echoelmusic → Stream Settings → YouTube
    5. Start streaming in Echoelmusic; it goes live on YouTube

    ### Twitch
    1. Log in with Twitch account
    2. Get stream key from Dashboard → Creator Camp → Stream Key
    3. Copy to Echoelmusic → Stream Settings → Twitch
    4. Go live; viewers see stream on your Twitch channel

    ### Facebook Live
    1. Connect Facebook account
    2. Select streaming destination (personal page, group, event)
    3. Echoelmusic starts live stream
    4. Viewers see stream in their News Feed

    ### Instagram/TikTok Live
    - Open Instagram/TikTok app
    - Start live stream
    - Share screen or use third-party RTMP encoder
    - Point RTMP URL to your Echoelmusic stream

    ### Custom RTMP Server
    1. Enter custom RTMP URL: rtmp://your-server.com/live
    2. Enter stream key if required
    3. Start streaming in Echoelmusic
    4. Stream sent to custom server

    ## Quality Settings

    ### Video Quality Presets

    | Preset | Resolution | Bitrate | CPU Load | Best For |
    |--------|-----------|---------|----------|----------|
    | **Mobile** | 480p | 1-2 Mbps | Low | Mobile viewers, limited bandwidth |
    | **Standard** | 720p | 3-5 Mbps | Medium | Most viewers, balanced quality |
    | **HD** | 1080p | 6-8 Mbps | High | Desktop viewers, good quality |
    | **Ultra** | 1440p | 10-15 Mbps | Very High | Premium viewers, 4K capable |
    | **8K** | 4320p | 30+ Mbps | Extreme | Specialized displays, future-proof |

    ### Manual Quality Adjustment
    - **Resolution:** 360p to 4320p
    - **Frame Rate:** 24, 30, 60 fps
    - **Bitrate:** 500 kbps to 100 Mbps
    - **Codec:** H.264, H.265 (HEVC)
    - **Profile:** Baseline, Main, High

    ### Audio Quality
    - **Sample Rate:** 44.1 kHz or 48 kHz
    - **Bitrate:** 96-320 kbps
    - **Channels:** Mono, Stereo, 5.1 surround

    ### Network Monitoring
    - Current upload speed displayed
    - Dropped frames counter
    - Latency measurement
    - Quality warnings if bandwidth low

    ## Multi-Destination Streaming

    ### Streaming to Multiple Platforms Simultaneously
    1. Tap "Stream Settings"
    2. Enable multiple platforms
    3. Configure streaming key for each platform
    4. Start single stream broadcast
    5. Stream automatically sent to all enabled platforms

    ### Example: Stream to YouTube, Twitch, Facebook
    1. Add YouTube streaming key
    2. Add Twitch streaming key
    3. Add Facebook streaming key
    4. Start stream once
    5. Appears live on all three platforms simultaneously

    ### Load Distribution
    - Platform prioritizes: YouTube > Twitch > Facebook > Custom
    - Automatic bitrate adjustment if bandwidth limited
    - Warning if upload speed insufficient for all destinations

    ## During Stream Control

    ### Stream Controls (Top Bar)
    - **Bitrate:** Current and average bitrate display
    - **Dropped Frames:** Visual indicator of stream health
    - **Viewers:** Live viewer count (where available)
    - **Timer:** Streaming duration
    - **Settings:** Quick access to quality settings

    ### Chat Integration
    - **YouTube Chat:** View and respond to live comments
    - **Twitch Chat:** Full chat integration
    - **Facebook Comments:** Read and reply to comments

    ### Session Transitions
    - Change preset mid-stream (smooth crossfade)
    - Switch visualization without disruption
    - Pause briefly without ending stream
    - End stream cleanly (finish/abrupt)

    ## Streaming Presets

    ### Available Streaming Presets

    **MusicStreaming**
    - Optimized for music content
    - 1080p 60fps recommended
    - Full visualization display

    **TalkStream**
    - Reduced visualization (priority to speaker)
    - 720p 30fps sufficient
    - Chat-focused layout

    **MeditationStream**
    - Slow, calming visuals
    - Soothing colors and geometry
    - 720p 24fps (cinema feel)

    **PerformanceStream**
    - High-energy visuals
    - Synced to performance
    - 1080p or 1440p 60fps

    ### Creating Custom Streaming Preset
    1. Configure stream settings desired
    2. Choose visualization mode
    3. Set audio parameters
    4. Tap "Save Streaming Preset"
    5. Name and save for future use

    ## Troubleshooting Streaming

    **Stream Won't Start**
    - Verify internet connection
    - Check streaming key is correct
    - Ensure sufficient upload bandwidth (5+ Mbps)
    - Try disconnecting/reconnecting WiFi

    **High Latency/Lag**
    - Reduce resolution or frame rate
    - Decrease bitrate
    - Close other apps using bandwidth
    - Move closer to WiFi router

    **Dropped Frames**
    - Lower video quality
    - Reduce CPU usage: close background apps
    - Check network stability
    - Use wired connection if available

    **Audio Out of Sync**
    - Check audio settings in platform
    - Verify sample rate consistency (44.1 or 48 kHz)
    - Restart stream if minor sync drift
    """

    // MARK: - Wellness Guide

    public static let wellnessGuide = """
    # Wellness Guide

    ## ⚠️ IMPORTANT HEALTH DISCLAIMER

    **Echoelmusic is NOT a medical device and does NOT provide medical diagnoses or treatment.**

    Features described in this guide:
    - Are designed for relaxation and general wellness only
    - May complement, NOT replace, professional medical care
    - Should NOT be used to self-diagnose or treat conditions
    - Are not approved by FDA or similar regulatory bodies

    **Please consult a healthcare provider before using if you:**
    - Have heart conditions or cardiac arrhythmias
    - Have photosensitive epilepsy (due to visual effects)
    - Are pregnant or nursing
    - Have anxiety disorders or trauma
    - Take cardiac or psychiatric medications
    - Have any serious medical condition

    ---

    ## Meditation Features

    ### Guided Meditations
    - **Body Scan:** 10-15 min, progressive muscle relaxation
    - **Breath Awareness:** 5-20 min, focus on natural breathing
    - **Loving-Kindness:** 10-20 min, compassion meditation
    - **Open Monitoring:** Unguided meditation with ambient sound

    ### Starting a Meditation
    1. Tap "Wellness" → "Meditations"
    2. Choose meditation from list (duration and type shown)
    3. Select audio type (voice only, voice + music, music only)
    4. Tap "Start Meditation"
    5. Find comfortable position; meditation begins
    6. Follow voice guidance (if applicable)

    ### During Meditation
    - Audio provides gentle cues but no interruption
    - Visualization evolves with your coherence
    - Haptic feedback on Apple Watch
    - Can pause/resume anytime
    - Timer shows remaining duration

    ## Breathing Exercises

    ### Breathing Patterns Available

    **Box Breathing (4-4-4-4)**
    - Inhale 4 counts, hold 4 counts
    - Exhale 4 counts, hold 4 counts
    - Good for: Stress relief, focus, calm
    - Duration: 5-15 minutes

    **4-7-8 Breathing**
    - Inhale 4 counts, hold 7 counts
    - Exhale 8 counts, hold 0 counts
    - Good for: Deep relaxation, sleep prep
    - Duration: 5-10 minutes

    **Coherence Breathing (5-5-5)**
    - Inhale 5 counts, exhale 5 counts
    - Optimize for HRV coherence states
    - Good for: Coherence training, heart health awareness
    - Duration: 10-20 minutes

    **Energizing Breath (3-0-3)**
    - Quick inhale 3 counts, exhale 3 counts
    - Good for: Energy, focus, morning activation
    - Duration: 3-5 minutes

    ### Breathing Exercise Guidance
    1. Tap "Wellness" → "Breathing"
    2. Select breathing pattern (description shows effects)
    3. Choose duration: 3, 5, 10, 15, 20 minutes
    4. Find comfortable seated position
    5. Start exercise; visual guides show breathing rhythm
    6. Audio cues: gentle sound for inhale/exhale transitions
    7. Exercise ends with 1-2 minutes cool-down

    ### Breathing Visualization
    - Circle expands with inhalation
    - Circle contracts with exhalation
    - Color indicates coherence level
    - Biofeedback helps optimize pattern

    ## HRV Training

    ### What is HRV Training?
    HRV (Heart Rate Variability) training teaches your nervous system to regulate through breathing and focus. Higher HRV is associated with better stress resilience.

    **Disclaimer:** HRV training is for general wellness interest only. Not approved as medical treatment.

    ### HRV Training Program (6 Weeks)

    **Week 1-2: Baseline**
    - Daily 10-min coherence breathing
    - Learn your HRV baseline
    - Session feedback shows trends

    **Week 3-4: Active Training**
    - 10-15 min sessions, increasing difficulty
    - Visual feedback of HRV in real-time
    - Aim for improved coherence percentage

    **Week 5-6: Advanced Practice**
    - 15-20 min sessions with challenges
    - Maintain high coherence while exposed to distractions
    - Track weekly improvement

    ### HRV Training Modes
    - **Beginner:** Slow breathing, ample visual guidance, forgiving
    - **Intermediate:** Moderate pace, less visual guidance, more feedback needed
    - **Advanced:** Challenging patterns, minimal guidance, real-time challenge

    ### Tracking HRV Progress
    - Session history shows HRV readings pre/post
    - Weekly average HRV displayed in wellness dashboard
    - Long-term trend shows 6-week improvement
    - Compare different breathing techniques

    ## Wellness Sessions

    ### Session Types

    **Morning Mindfulness** (10 min)
    - Gentle wake-up breathing
    - Energizing visualization
    - Sets calm focus for day

    **Deep Relaxation** (20 min)
    - Progressive body scan
    - Soothing audio and visuals
    - Great for pre-sleep or mid-day rest

    **Focus Session** (15 min)
    - Coherence training meditation
    - Builds mental clarity
    - Good before work/study

    **Sleep Preparation** (20 min)
    - Calming breathing and music
    - Gradually lowers tempo
    - Sleep-inducing visualization

    **Quantum Coherence** (30 min)
    - Advanced meditation experience
    - Quantum-inspired visuals
    - For experienced meditators

    ### Session Structure
    1. Brief introduction (1-2 min)
    2. Guided practice or music (main duration)
    3. Gentle close-out and reflection (2-3 min)
    4. Session ends with coherence summary

    ## Wellness Tracking and Journaling

    ### Wellness Metrics
    - Daily HRV average
    - Breathing rate patterns
    - Meditation session count
    - Total wellness time
    - Coherence trends

    ### Journaling
    1. After session, tap "Reflect"
    2. Optionally record mood (1-10 scale)
    3. Write optional notes about experience
    4. Mood shown with biometric data for correlation
    5. Review past entries and trends

    ### Wellness Dashboard
    - Calendar view of all wellness sessions
    - Weekly and monthly statistics
    - Graphs showing HRV trends
    - Mood patterns correlated with session type
    - Export wellness data for personal records

    ## General Wellness Tips

    - **Consistency:** 10 minutes daily better than 1 hour weekly
    - **Time of Day:** Morning best for establishing routine
    - **Environment:** Quiet, comfortable place supports practice
    - **Breathing:** Natural pace is fine; no force
    - **Expectation:** Effects accumulate over weeks/months, not immediately
    - **Professional Help:** If stress/anxiety severe, consult healthcare provider
    """

    // MARK: - Troubleshooting Guide

    public static let troubleshooting = """
    # Troubleshooting Guide

    ## Connection Issues

    ### HealthKit Not Working
    **Problem:** HealthKit data not appearing or biometric parameters not updating
    **Solutions:**
    1. Settings → Privacy → Health → Echoelmusic → Ensure data types are enabled
    2. Grant permission when prompted: "Echoelmusic would like to access your health data"
    3. Ensure device has biometric sensor (Heart Rate app works?)
    4. Restart Echoelmusic and device
    5. Real device required; simulator cannot access HealthKit

    ### Bluetooth Connection Issues
    **Problem:** Cannot connect to Apple Watch, MIDI controller, or audio interface
    **Solutions:**
    1. Ensure device is discoverable: Settings → Bluetooth → Device name visible
    2. Toggle Bluetooth off/on on both devices
    3. Forget and re-pair device:
       - iOS: Settings → Bluetooth → (i) icon → Forget
       - macOS: System Settings → Bluetooth → (x) icon
    4. Move devices within 30 feet (10 meters)
    5. Check device battery levels
    6. Restart both devices

    ### Apple Watch Won't Pair
    **Problem:** Apple Watch doesn't appear in Echoelmusic settings
    **Solutions:**
    1. Unpair watch: iPhone → Watch app → General → Reset
    2. Re-pair watch: Settings app → Bluetooth → Watch
    3. Install Echoelmusic on watch (auto-installs from iPhone)
    4. Wait 5 minutes for sync to complete
    5. Ensure watch and iPhone on same WiFi network
    6. Restart both devices

    ### MIDI Controller Not Detected
    **Problem:** MIDI controller connected but not appearing in Echoelmusic
    **Solutions:**
    1. Check USB connection or Bluetooth pairing
    2. Restart Echoelmusic
    3. Try different USB port
    4. Use USB hub if connecting multiple devices
    5. On Windows: Download driver from manufacturer website
    6. On macOS: Use Audio MIDI Setup app to verify device appears
    7. Test in another app (Apple Music, GarageBand) to verify controller works

    ### Audio Interface Not Recognized
    **Problem:** Audio interface connected but not selectable in audio settings
    **Solutions:**
    1. Ensure audio interface powered on
    2. Install manufacturer drivers if on Windows/Linux
    3. Try different USB port or USB hub
    4. macOS: Check System Settings → Sound → Output/Input tabs
    5. Windows: Check Device Manager → Sound Devices
    6. Restart Echoelmusic and operating system
    7. Try different USB cable

    ## Audio Issues

    ### No Sound Output
    **Problem:** Echoelmusic running but no audio heard
    **Solutions:**
    1. Check device volume: Physical volume buttons or Settings → Volume
    2. Verify output device selected: Settings → Audio → Output Device
    3. Check audio permissions: Settings → Privacy → Microphone (iOS)
    4. Restart Echoelmusic
    5. Try different audio output (speaker, headphones, different interface)
    6. Check if muted: Look for mute switch on device
    7. On Windows: Check Volume Mixer (Sound Settings → Volume mixer)

    ### Audio Very Quiet or Distorted
    **Problem:** Output volume too low or distorted/clipping
    **Solutions:**
    1. Check master volume slider in Echoelmusic
    2. Increase volume gradually (avoid maximum to prevent distortion)
    3. Reduce audio interface input gain if connected
    4. Check audio interface output level knob
    5. Disable effects (reverb, distortion) causing clipping
    6. Verify audio interface is powered and output enabled
    7. Try built-in speaker to isolate issue

    ### Latency/Delay Between Input and Output
    **Problem:** Audio response delayed from gesture/MIDI input
    **Solutions:**
    1. Reduce buffer size: Settings → Audio → Buffer Size
       - Start with 256, gradually reduce to 128 or 64
       - Smaller buffer = lower latency but higher CPU load
    2. Reduce effects: Disable reverb, delay, other processing
    3. Reduce sample rate: 44.1 kHz instead of 96 kHz
    4. Close background apps consuming CPU
    5. Use wired audio interface instead of Bluetooth speaker
    6. Check if external reverb/effects causing delay (turn off temporarily)

    ### Audio Crackling or Drops
    **Problem:** Audio dropouts, crackling, or stuttering
    **Solutions:**
    1. Increase buffer size: Settings → Audio → Buffer Size (256, 512, or 1024)
    2. Close background apps consuming resources
    3. Disable Bluetooth if using wired audio interface
    4. On Windows: Close background processes (Task Manager)
    5. On macOS: Check Activity Monitor for high CPU usage
    6. Reduce visualization quality if very high resolution
    7. Try different USB port
    8. Disable WiFi if not needed

    ### Microphone Input Not Working
    **Problem:** Voice input or pitch detection not working
    **Solutions:**
    1. Grant microphone permission: Settings → Privacy → Microphone
    2. Check device has microphone (most do; some tablets may not)
    3. Physical microphone not obstructed
    4. Test microphone in other app (Voice Memos, FaceTime)
    5. Restart Echoelmusic
    6. Check microphone input level: Settings → Audio → Mic Level
    7. Move microphone closer to mouth (6-12 inches)
    8. Use external microphone for better quality

    ## Performance Issues

    ### High CPU Usage / App Slow
    **Problem:** Echoelmusic using excessive CPU or running slowly
    **Solutions:**
    1. Reduce visualization quality: Settings → Graphics → Quality (High → Medium/Low)
    2. Reduce frame rate: Settings → Graphics → Frame Rate (60 → 30 fps)
    3. Disable unnecessary effects: Reverb, delay, distortion
    4. Use simpler presets (fewer synthesizer voices)
    5. Close background apps
    6. Restart device to clear memory
    7. Reduce buffer size reverting to normal CPU usage
    8. Check system for malware (Windows)

    ### Battery Drains Quickly
    **Problem:** Device battery depleting rapidly while using Echoelmusic
    **Solutions:**
    1. Reduce screen brightness
    2. Disable location tracking
    3. Disable Bluetooth if not needed
    4. Lower visualization quality and frame rate
    5. Use battery saver mode if available
    6. Close other apps
    7. Shorter sessions
    8. On iOS: Check Settings → Battery Health (battery degradation?)

    ### Crashes / Unexpected Quits
    **Problem:** Echoelmusic crashes and quits suddenly
    **Solutions:**
    1. Restart app
    2. Force close app: Recent apps → Swipe up (iOS/Android)
    3. Restart device
    4. Reinstall Echoelmusic (uninstall, then reinstall from App Store)
    5. Check for app updates: App Store/Play Store
    6. Clear app cache: Settings → Apps → Echoelmusic → Clear Cache
    7. Check device storage (low storage can cause crashes)
    8. Report crash: In-app support → "Report Bug"

    ## Recording/Streaming Issues

    ### Recording Won't Start
    **Problem:** Cannot begin recording audio or video
    **Solutions:**
    1. Ensure sufficient storage space (Settings → Storage)
    2. Grant microphone permission (iOS/Android Settings)
    3. Not already recording another session
    4. Restart Echoelmusic
    5. Try recording in different location/format

    ### Stream Connection Fails
    **Problem:** Cannot start live stream or stream drops immediately
    **Solutions:**
    1. Verify streaming key is correct (copy again from platform)
    2. Check internet speed (minimum 5 Mbps upload for 1080p)
    3. Close other apps using bandwidth
    4. Try wired connection (if available)
    5. Reduce stream quality (720p → 480p)
    6. Restart Echoelmusic
    7. Wait a few minutes before retrying

    ## Platform-Specific Issues

    ### iOS/iPadOS Issues

    **Split View / Slide Over Not Working**
    - Some features unavailable in split screen
    - Return to full-screen view
    - Restart app in full screen

    **Dynamic Island Complications Not Updating**
    - Restart device
    - Clear app cache: Settings → General → iPhone Storage → Echoelmusic → Offload App
    - Reinstall app

    ### macOS Issues

    **Notarization Warning**
    - System may warn about app not notarized
    - Click "Open" when prompted
    - This is normal for some distributors

    **Keyboard Shortcuts Not Working**
    - Ensure Echoelmusic is in focus (foreground)
    - Check System Settings → Keyboard → Shortcuts

    ### Windows Issues

    **Audio Driver Missing**
    - Install latest audio interface driver from manufacturer
    - Or use universal driver: FlexASIO or ASIO4ALL
    - Restart after installing drivers

    **Slow Performance**
    - Disable Windows Defender/Antivirus scanning during use
    - Disable visual effects: Settings → Display → Advanced display settings
    - Update graphics drivers (NVIDIA/AMD/Intel website)

    ### Linux Issues

    **Audio Server Not Found**
    - Install PulseAudio or PipeWire: `apt install pulseaudio-module-bluetooth`
    - Or use JACK for pro audio: `apt install jackd`

    **ALSA Errors**
    - Install ALSA libraries: `apt install libasound2-dev`
    - Restart sound service: `systemctl restart alsa-utils`

    ## When to Contact Support

    Contact support if:
    - Issue persists after trying all troubleshooting steps
    - Receiving repeated error messages
    - App crashes consistently on specific action
    - Hardware not recognized despite correct setup

    **How to Contact Support:**
    - In-app: Settings → Help → Contact Support
    - Email: vibrationalforce@gmail.com
    - Website: echoelmusic.com/support
    - Include: Device, OS version, app version, detailed description, error messages/screenshots
    """

    // MARK: - Accessibility Guide

    public static let accessibilityGuide = """
    # Accessibility Guide

    ## Overview

    Echoelmusic is committed to WCAG 2.2 AAA accessibility, providing multiple ways to interact with the app regardless of ability.

    **Available Features:**
    - 20+ accessibility profiles
    - VoiceOver and TalkBack support
    - Alternative input methods
    - Customizable text sizes and colors
    - Haptic and audio feedback
    - Motor control adaptations
    - Cognitive load reduction

    ## Accessibility Profiles

    ### How to Select Profile
    1. Settings → Accessibility
    2. Tap "Select Profile"
    3. Choose from list of profiles
    4. Tap "Apply" to activate
    5. Interface adapts immediately

    ### Available Profiles

    | Profile | Best For |
    |---------|----------|
    | Standard | Typical usage |
    | Low Vision | Large text, high contrast |
    | Blind | Screen reader, spatial audio |
    | Color Blind | Color-safe palettes (6 schemes) |
    | Deaf | Visual alerts, captions |
    | Motor Limited | Large targets, reduced interaction |
    | Switch Access | External switch navigation |
    | Voice Only | Complete voice control |
    | Cognitive | Simplified UI, clear instructions |
    | Autism Friendly | Calm, predictable interface |
    | Dyslexia | OpenDyslexic font |
    | Elderly | Senior-friendly UI, large controls |
    | One Handed | Single-hand reachable layout |
    | Hands Free | Voice + switch control |
    | ADHD | Focus mode, reduced distractions |
    | Vestibular | No motion or parallax |
    | Photosensitive | Safe animations |
    | Memory Support | Context reminders |
    | Tremor Support | Large, stable targets |
    | Low Dexterity | Simplified gestures |

    ## VoiceOver (iOS/macOS)

    ### Enabling VoiceOver
    1. Settings → Accessibility → VoiceOver
    2. Toggle VoiceOver ON
    3. Gesture guide displays

    ### VoiceOver Gestures
    - **Single Tap:** Select and hear element
    - **Double Tap:** Activate selected element
    - **Swipe Right:** Next element
    - **Swipe Left:** Previous element
    - **Two-Finger Tap:** Toggle speaking/mute
    - **Two-Finger Swipe Up:** Read all
    - **Two-Finger Swipe Down:** Stop speaking
    - **Three-Finger Tap:** Toggle mute

    ### VoiceOver in Echoelmusic
    - All buttons and controls labeled with descriptions
    - Session parameters read aloud
    - Biometric data announced (heart rate, coherence)
    - Visualization modes described
    - Messages and notifications spoken

    ## TalkBack (Android)

    ### Enabling TalkBack
    1. Settings → Accessibility → TalkBack
    2. Toggle TalkBack ON
    3. Confirm when prompted

    ### TalkBack Gestures
    - **Single Tap:** Select element
    - **Double Tap:** Activate
    - **Swipe Down Then Right:** Next item
    - **Swipe Up Then Left:** Previous item
    - **Swipe Right:** Explore by touch
    - **Swipe Up:** Scroll up
    - **Swipe Down:** Scroll down

    ## Alternative Input Methods

    ### Voice Control
    - **Say:** "Start session" to begin playing
    - **Say:** "Stop session" to stop
    - **Say:** "Increase volume" / "Decrease volume"
    - **Say:** "Show presets" to display preset list
    - **Say:** "Next visualization" to change visuals
    - **Complete List:** Settings → Accessibility → Voice Commands

    ### External Switch Control
    1. Pair external switch via Bluetooth
    2. Settings → Accessibility → Switch Control
    3. Configure actions for different switch presses
    4. Single press: navigate
    5. Double press: activate
    6. Hold: open menu

    ### Eye Tracking (iPad/iPhone with supported hardware)
    - Gaze at on-screen elements to control
    - Dwell to select
    - Customize dwell time (200-800ms)
    - Settings → Accessibility → Eye Tracking

    ### Head Tracking (iPhone 12 Pro+, visionOS)
    - Move head to navigate
    - Nod for activation
    - Settings → Accessibility → Head Tracking
    - Customize sensitivity

    ### Keyboard Only
    - Tab key: Navigate between controls
    - Space/Return: Activate selected control
    - Arrow keys: Adjust sliders
    - All functionality accessible without mouse/touch

    ## Visual Accessibility

    ### Text Size and Styling
    1. Settings → Accessibility → Display
    2. Text Size slider (adjust from 50% to 200%)
    3. Bold Text toggle
    4. Italic Text toggle
    5. OpenDyslexia font option

    ### Color and Contrast
    1. Settings → Accessibility → Display
    2. Choose color scheme:
       - Standard (normal colors)
       - High Contrast (stronger colors)
       - Grayscale (colorblind-safe)
       - Dark Mode (reduces eye strain)

    ### Colorblind Modes
    - **Protanopia:** Red-blind safe palette
    - **Deuteranopia:** Green-blind safe palette
    - **Tritanopia:** Blue-blind safe palette
    - **Monochrome:** Full grayscale
    - **High Contrast:** Maximum contrast
    - **Soft:** Reduced saturation

    ## Haptic and Audio Feedback

    ### Haptic Patterns
    - **Light Tap:** UI feedback
    - **Medium Thump:** Confirmation
    - **Heavy Knock:** Alert
    - **Selection Vibration:** List selection
    - **Heartbeat Pulse:** Coherence indicator
    - **Breathing Wave:** Respiration sync

    ### Sound Cues
    - **Success Chime:** Action completed
    - **Error Tone:** Issue occurred
    - **Notification Bell:** New event
    - **Coherence Beep:** Real-time biometric feedback
    - **Guide Whisper:** Instruction prompt

    ### Combining Haptic + Audio
    - Vibration + tone for critical alerts
    - Haptic pulse + spoken announcement
    - Rhythm patterns (heartbeat + audio)

    ## Motor Control Adaptations

    ### Large Touch Targets
    - All buttons minimum 48x48 points (iOS) or 48x48 dp (Android)
    - Increased spacing between controls
    - Full-screen gesture areas for common actions

    ### Slow Motion / Extended Time
    - Settings → Accessibility → Motion
    - Animations slowed 2x-10x
    - Transition time extended
    - Hover time for confirmations

    ### One-Handed Mode
    - Reachable controls on lower half of screen
    - Large buttons for thumb operation
    - Essential functions grouped together

    ### Tremor Support
    - Sticky keys: Press modifier, then other key
    - Bounce time: Ignore repeated key presses
    - Predictive input: Correct accidental taps
    - Confirmation required before sensitive actions

    ## Cognitive Accessibility

    ### Simplified Interface
    - Profile: "Cognitive" removes non-essential controls
    - Focuses on core features
    - Larger icons and clearer labels
    - Step-by-step guidance

    ### Reduced Distractions
    - Hide advanced settings
    - Fewer visualizations options
    - Quiet notifications (no loud sounds)
    - Single-step actions

    ### Memory Support
    - Context reminders ("Remember to grant HealthKit access")
    - Instruction tooltips on first use
    - Session history easily accessible
    - Favorites marked for quick access

    ## Deaf and Hard of Hearing

    ### Captions
    - All guided meditations captioned
    - Voice commands show text confirmation
    - Spoken announcements have text equivalent
    - Settings → Accessibility → Captions

    ### Visual Alerts
    - Notifications use visual flash
    - Important events include haptic + visual
    - Color coding for different alert types
    - Customizable alert intensity

    ### Subtitle Display
    - All spoken audio has optional subtitles
    - Adjustable size and positioning
    - Background color options
    - Timing synced with audio

    ### Audio Description
    - Visualizations described in text
    - Preset effects explained
    - Tutorial videos with audio descriptions

    ## Blind and Low Vision

    ### Screen Reader Optimization
    - All UI elements properly labeled
    - Meaningful descriptions for complex elements
    - Rotor-based navigation (VoiceOver)
    - Spatial audio for environmental awareness

    ### Text-to-Speech
    - Built-in TTS for all controls
    - Adjustable speech rate
    - Voice selection (male/female/accent)
    - Emphasis on important information

    ### Sonification
    - Data converted to audio representation
    - Biometric data sonified
    - Visualization audio mapping
    - Parameter changes indicated by tones

    ### High Contrast
    - Maximum contrast between elements
    - Dark backgrounds recommended
    - All important controls visible
    - Clear visual hierarchy

    ## Vestibular and Motion Sensitivity

    ### Reduce Motion
    1. Settings → Accessibility → Motion
    2. Toggle "Reduce Motion" ON
    3. All animations disabled/slowed
    4. Parallax removed
    5. Auto-play disabled

    ### No Flash or Strobe
    - Settings → Accessibility → Photosensitivity
    - Toggle "Avoid Flashing" ON
    - Removes strobing visualizations
    - Reduces seizure risk
    - Smooth color transitions only

    ### Calm Visuals
    - Profile: "Vestibular" enables calm mode
    - Slow, gentle animations
    - Stable on-screen layout
    - No sudden movements

    ## Testing Accessibility

    ### Verifying Settings
    1. Enable profile
    2. Navigate entire interface
    3. Test each major feature
    4. Confirm all buttons/labels readable
    5. Check contrast ratios (should be 4.5:1 minimum)

    ### Accessibility Audit
    - WCAG 2.2 Level AAA conformance
    - Third-party audit performed annually
    - User feedback incorporated
    - Continuous improvements

    ## Support and Feedback

    ### Report Accessibility Issue
    1. Settings → Help → Accessibility Feedback
    2. Describe issue in detail
    3. Include device and OS version
    4. Attach screenshot if possible
    5. Submit; we'll respond within 48 hours

    ### Request New Feature
    - Accessibility team reviews all requests
    - Priority given to universal design benefits
    - Beta testing available for early access

    ### Additional Resources
    - Full accessibility guide: Settings → Help → Accessibility Help
    - Video tutorials with captions
    - Contact accessibility specialist: vibrationalforce@gmail.com
    """
}
