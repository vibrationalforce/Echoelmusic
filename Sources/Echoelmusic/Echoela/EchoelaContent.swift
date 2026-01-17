/**
 * EchoelaContent.swift
 * Echoelmusic - Guided Tour Content Library
 *
 * All guidance content for Echoela
 * Written in calm, clear, non-judgmental language
 *
 * Principles:
 * - Simple vocabulary
 * - Short sentences
 * - No jargon without explanation
 * - No assumptions about ability
 * - Optional depth (expand for more)
 *
 * Created: 2026-01-15
 */

import Foundation

// MARK: - Content Provider

/// Provides all guidance content for Echoela
public struct EchoelaContentProvider {

    // MARK: - Topic Contexts

    /// Get full guidance context for a topic
    public static func context(for topic: GuidanceTopic) -> GuidanceContext {
        switch topic {
        case .welcome:
            return welcomeContext
        case .generalHelp:
            return generalHelpContext
        case .audioBasics:
            return audioBasicsContext
        case .biofeedback:
            return biofeedbackContext
        case .visualizer:
            return visualizerContext
        case .presets:
            return presetsContext
        case .recording:
            return recordingContext
        case .streaming:
            return streamingContext
        case .accessibility:
            return accessibilityContext
        case .settings:
            return settingsContext
        case .collaboration:
            return collaborationContext
        case .wellness:
            return wellnessContext
        }
    }

    // MARK: - Welcome

    private static var welcomeContext: GuidanceContext {
        GuidanceContext(
            id: "welcome",
            topic: .welcome,
            title: "Hello, I'm Echoela",
            description: "I'm here to help you explore Echoelmusic. I'll offer gentle guidance when you might need it, but you're always in control.",
            hints: [],
            steps: [
                GuidanceStep(
                    title: "I'm Optional",
                    description: "You can turn me off in Settings anytime. I won't be offended.",
                    action: nil
                ),
                GuidanceStep(
                    title: "I Learn Your Style",
                    description: "As you use the app, I'll give you less guidance when you're confident, and more when things are new.",
                    action: nil
                ),
                GuidanceStep(
                    title: "I Never Rush You",
                    description: "There are no timers, no scores, no pressure. Take all the time you need.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Ask Anytime",
                    description: "If you ever need help, just tap the Echoela button or look for the sparkle icon.",
                    action: nil
                )
            ]
        )
    }

    // MARK: - General Help

    private static var generalHelpContext: GuidanceContext {
        GuidanceContext(
            id: "general_help",
            topic: .generalHelp,
            title: "How Can I Help?",
            description: "Choose a topic to learn more about it. You can always come back here.",
            hints: [
                GuidanceHint(
                    shortText: "Tip: Topics you've explored are marked with a checkmark.",
                    detailedText: "But you can revisit them anytime. There's no limit to how many times you can read something.",
                    relatedTopics: []
                )
            ],
            steps: []
        )
    }

    // MARK: - Audio Basics

    private static var audioBasicsContext: GuidanceContext {
        GuidanceContext(
            id: "audio_basics",
            topic: .audioBasics,
            title: "Audio Basics",
            description: "Learn how sound works in Echoelmusic.",
            hints: [
                GuidanceHint(
                    shortText: "You don't need music experience to use this app.",
                    detailedText: "Echoelmusic is designed for everyone. The app creates sounds for you based on your input.",
                    relatedTopics: [.presets]
                )
            ],
            steps: [
                GuidanceStep(
                    title: "What You Hear",
                    description: "Echoelmusic creates sounds in real-time. These sounds change based on what you do — touching the screen, your heart rate, your voice, or your movements.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Volume Control",
                    description: "Use your device's volume buttons to adjust how loud the sound is. You can also find a volume slider in the app.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Sound Types",
                    description: "The app can make many kinds of sounds: gentle tones, rhythms, ambient textures, and more. Presets give you different sound styles to try.",
                    action: nil
                ),
                GuidanceStep(
                    title: "No Wrong Sounds",
                    description: "There's no wrong way to make sound here. Whatever you create is valid. This is about exploration, not perfection.",
                    action: nil
                )
            ]
        )
    }

    // MARK: - Biofeedback

    private static var biofeedbackContext: GuidanceContext {
        GuidanceContext(
            id: "biofeedback",
            topic: .biofeedback,
            title: "Biofeedback",
            description: "Learn how your body connects to the music.",
            hints: [
                GuidanceHint(
                    shortText: "Important: This is art, not medicine.",
                    detailedText: "Echoelmusic is a creative tool. It doesn't diagnose, treat, or cure any condition. Always consult healthcare professionals for medical concerns.",
                    relatedTopics: [.wellness]
                )
            ],
            steps: [
                GuidanceStep(
                    title: "What is Biofeedback?",
                    description: "Your body constantly produces signals — your heart beats, you breathe, your muscles move. Biofeedback means using these signals as input.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Heart Rate",
                    description: "If you have an Apple Watch or compatible device, Echoelmusic can respond to your heart rate. Faster heartbeat might make faster rhythms.",
                    action: nil
                ),
                GuidanceStep(
                    title: "HRV (Heart Rate Variability)",
                    description: "HRV measures the tiny changes between heartbeats. Higher HRV often indicates relaxation. The app can use this to create calmer sounds.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Breathing",
                    description: "Some features respond to your breathing pattern. The app might detect this from your heart rate changes or from sounds you make.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Touch & Gesture",
                    description: "No sensors needed! You can also control sound by touching the screen or moving in front of the camera.",
                    action: nil
                ),
                GuidanceStep(
                    title: "All Input is Optional",
                    description: "You don't need any sensors to enjoy Echoelmusic. The app works great with just touch input.",
                    action: nil
                )
            ]
        )
    }

    // MARK: - Visualizer

    private static var visualizerContext: GuidanceContext {
        GuidanceContext(
            id: "visualizer",
            topic: .visualizer,
            title: "Visualizer",
            description: "Understand the visual feedback in the app.",
            hints: [
                GuidanceHint(
                    shortText: "Visuals respond to sound and your input.",
                    detailedText: "The patterns you see change with the music and your biometric data. It's like seeing what you feel.",
                    relatedTopics: [.audioBasics, .biofeedback]
                )
            ],
            steps: [
                GuidanceStep(
                    title: "What You See",
                    description: "Echoelmusic shows visual patterns that move and change. These visuals respond to the sound and your input.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Colors",
                    description: "Colors often represent different things — calm blues for relaxation, warm oranges for energy. But there's no strict rule.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Motion",
                    description: "The speed and style of motion relates to the music tempo and your bio-signals.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Accessibility",
                    description: "If you find the visuals overwhelming, you can enable 'Calm Colors' or 'Reduce Animations' in Settings.",
                    action: nil
                )
            ]
        )
    }

    // MARK: - Presets

    private static var presetsContext: GuidanceContext {
        GuidanceContext(
            id: "presets",
            topic: .presets,
            title: "Presets",
            description: "Quick ways to change the entire experience.",
            hints: [
                GuidanceHint(
                    shortText: "Presets are starting points, not limits.",
                    detailedText: "Each preset configures sound and visuals for a particular mood or activity. You can modify them or create your own.",
                    relatedTopics: [.audioBasics]
                )
            ],
            steps: [
                GuidanceStep(
                    title: "What is a Preset?",
                    description: "A preset is a saved configuration. It sets up sound, visuals, and response settings all at once.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Browsing Presets",
                    description: "You can browse presets by category: Meditation, Creative, Energetic, and more. Tap any preset to try it.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Switching Presets",
                    description: "You can switch presets anytime. The transition is smooth — you won't hear a sudden change.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Creating Your Own",
                    description: "Once you're comfortable, you can save your own presets with your favorite settings.",
                    action: nil
                )
            ]
        )
    }

    // MARK: - Recording

    private static var recordingContext: GuidanceContext {
        GuidanceContext(
            id: "recording",
            topic: .recording,
            title: "Recording",
            description: "Capture and save your sessions.",
            hints: [
                GuidanceHint(
                    shortText: "Recordings stay on your device unless you share them.",
                    detailedText: "Your privacy matters. Nothing is uploaded without your explicit action.",
                    relatedTopics: []
                )
            ],
            steps: [
                GuidanceStep(
                    title: "What Gets Recorded?",
                    description: "You can record the audio you create, the visuals, or both together as a video.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Starting a Recording",
                    description: "Tap the record button (circle icon) to start. Tap again to stop.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Finding Your Recordings",
                    description: "All recordings are saved in the Library section. You can play them back, share them, or delete them.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Storage",
                    description: "Recordings use storage space on your device. You can delete old recordings if you need more space.",
                    action: nil
                )
            ]
        )
    }

    // MARK: - Streaming

    private static var streamingContext: GuidanceContext {
        GuidanceContext(
            id: "streaming",
            topic: .streaming,
            title: "Streaming",
            description: "Share your experience live with others.",
            hints: [
                GuidanceHint(
                    shortText: "Streaming is advanced and completely optional.",
                    detailedText: "If you never stream, that's perfectly fine. Many people use Echoelmusic privately.",
                    relatedTopics: [.recording]
                )
            ],
            steps: [
                GuidanceStep(
                    title: "What is Streaming?",
                    description: "Streaming means broadcasting your audio-visual experience live over the internet. Others can watch in real-time.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Where to Stream",
                    description: "Echoelmusic can stream to YouTube, Twitch, and other platforms. You'll need an account on those services.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Privacy Considerations",
                    description: "When streaming, others can see what you create. Bio-data display is optional — you control what's visible.",
                    action: nil
                )
            ]
        )
    }

    // MARK: - Accessibility

    private static var accessibilityContext: GuidanceContext {
        GuidanceContext(
            id: "accessibility",
            topic: .accessibility,
            title: "Accessibility",
            description: "Customize the app to work for you.",
            hints: [
                GuidanceHint(
                    shortText: "Echoelmusic is designed for everyone.",
                    detailedText: "We've built in many options to make the app usable regardless of vision, hearing, motor, or cognitive differences.",
                    relatedTopics: []
                )
            ],
            steps: [
                GuidanceStep(
                    title: "Vision",
                    description: "VoiceOver is fully supported. You can also enable high contrast, larger text, and color adjustments.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Hearing",
                    description: "Visual beat indicators can show rhythm. Haptic feedback lets you feel the beat. Bass-enhanced mode makes vibrations stronger.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Motor",
                    description: "Voice control lets you navigate hands-free. Switch access and dwell selection are supported. Target sizes can be enlarged.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Cognitive",
                    description: "Simplified UI mode reduces complexity. Focus mode hides non-essential elements. Memory aids can remind you of recent actions.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Sensory Sensitivity",
                    description: "Reduce motion, reduce brightness, and calm color options help if you're sensitive to visual stimulation.",
                    action: nil
                )
            ]
        )
    }

    // MARK: - Settings

    private static var settingsContext: GuidanceContext {
        GuidanceContext(
            id: "settings",
            topic: .settings,
            title: "Settings",
            description: "Configure the app to your preferences.",
            hints: [
                GuidanceHint(
                    shortText: "You can always change settings later.",
                    detailedText: "Nothing is permanent. Experiment freely — you can reset to defaults anytime.",
                    relatedTopics: []
                )
            ],
            steps: [
                GuidanceStep(
                    title: "Finding Settings",
                    description: "Tap the gear icon to open Settings. It's usually in the top corner of the main screen.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Categories",
                    description: "Settings are grouped: Audio, Visual, Bio-Input, Accessibility, Privacy, and Echoela (that's me!).",
                    action: nil
                ),
                GuidanceStep(
                    title: "Echoela Settings",
                    description: "You can adjust how much guidance I give, or turn me off entirely. No hard feelings.",
                    action: nil
                )
            ]
        )
    }

    // MARK: - Collaboration

    private static var collaborationContext: GuidanceContext {
        GuidanceContext(
            id: "collaboration",
            topic: .collaboration,
            title: "Collaboration",
            description: "Create together with others.",
            hints: [
                GuidanceHint(
                    shortText: "Collaboration is optional and consent-based.",
                    detailedText: "You choose whether to join sessions. Your data is only shared if you explicitly allow it.",
                    relatedTopics: [.streaming]
                )
            ],
            steps: [
                GuidanceStep(
                    title: "What is Collaboration?",
                    description: "Multiple people can connect their Echoelmusic apps and create together. Your bio-signals can influence each other's sounds.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Joining a Session",
                    description: "Someone shares a session code or link. You enter it to join. Both parties must agree.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Privacy",
                    description: "You control what you share. You can participate with just sound input, without sharing bio-data.",
                    action: nil
                )
            ]
        )
    }

    // MARK: - Wellness

    private static var wellnessContext: GuidanceContext {
        GuidanceContext(
            id: "wellness",
            topic: .wellness,
            title: "Wellness Features",
            description: "Understand the wellness-related features.",
            hints: [
                GuidanceHint(
                    shortText: "Important: This is not medical advice.",
                    detailedText: "Echoelmusic wellness features are for general wellbeing and creativity. They are not medical devices and don't diagnose or treat conditions.",
                    relatedTopics: [.biofeedback]
                )
            ],
            steps: [
                GuidanceStep(
                    title: "What Wellness Means Here",
                    description: "We use 'wellness' to mean general relaxation, creativity, and self-exploration. Not medical treatment.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Breathing Exercises",
                    description: "The app includes optional guided breathing. These are general relaxation techniques, not therapy.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Coherence Display",
                    description: "The app may show 'coherence' based on your HRV. This is a visualization tool, not a medical metric.",
                    action: nil
                ),
                GuidanceStep(
                    title: "Disclaimer",
                    description: "If you have health concerns, please consult a healthcare professional. Echoelmusic is a creative tool, not a substitute for medical care.",
                    action: nil
                )
            ]
        )
    }

    // MARK: - Contextual Hints

    /// Get contextual hints for a specific screen/feature
    public static func hints(for screenId: String) -> [GuidanceHint] {
        switch screenId {
        case "main_screen":
            return [
                GuidanceHint(
                    shortText: "Touch anywhere to start creating sound.",
                    detailedText: "The main screen responds to your touch. Press and hold, drag your finger, or tap — each creates different sounds.",
                    relatedTopics: [.audioBasics]
                )
            ]
        case "preset_browser":
            return [
                GuidanceHint(
                    shortText: "Scroll to see more presets.",
                    detailedText: "Presets are organized by category. Tap any one to try it instantly — you can always switch back.",
                    relatedTopics: [.presets]
                )
            ]
        case "settings_screen":
            return [
                GuidanceHint(
                    shortText: "Changes apply immediately.",
                    detailedText: "Most settings take effect right away. You'll see or hear the difference immediately.",
                    relatedTopics: [.settings]
                )
            ]
        case "recording_controls":
            return [
                GuidanceHint(
                    shortText: "The red button starts and stops recording.",
                    detailedText: "Tap once to start, tap again to stop. A timer shows how long you've been recording.",
                    relatedTopics: [.recording]
                )
            ]
        default:
            return []
        }
    }
}
