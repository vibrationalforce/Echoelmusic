import Foundation

// MARK: - Xcode Project Generator
// Comprehensive utility for generating Xcode project configuration
// This serves as documentation for the complete Echoelmusic Xcode project setup

/// Main Xcode project configuration
public struct XcodeProjectConfiguration {
    public let projectName: String
    public let organizationName: String
    public let bundleIdentifierBase: String
    public let targets: [XcodeTargetConfiguration]
    public let schemes: [XcodeScheme]
    public let buildSettings: XcodeBuildSettings
    public let codeSigningConfig: CodeSigningConfiguration

    /// Default Echoelmusic project configuration
    public static let echoelmusic = XcodeProjectConfiguration(
        projectName: "Echoelmusic",
        organizationName: "Echoelmusic Technologies",
        bundleIdentifierBase: "com.echoelmusic",
        targets: [
            .iosApp,
            .macOSApp,
            .watchOSApp,
            .tvOSApp,
            .visionOSApp,
            .auv3Extension,
            .widgetExtension,
            .liveActivityExtension,
            .sharePlayExtension,
            .shortcutsExtension
        ],
        schemes: [
            .debug,
            .release,
            .enterprise,
            .testFlight
        ],
        buildSettings: .echoelmusicDefaults,
        codeSigningConfig: .echoelmusicDefaults
    )

    /// Generate project.pbxproj content (for documentation)
    public func generateProjectFile() -> String {
        """
        // !$*UTF8*$!
        // Xcode Project Configuration for \(projectName)
        // Generated: \(Date())

        Project Configuration:
        - Organization: \(organizationName)
        - Base Bundle ID: \(bundleIdentifierBase)
        - Targets: \(targets.count)
        - Schemes: \(schemes.count)

        Deployment Targets:
        - iOS: 15.0+
        - macOS: 12.0+
        - watchOS: 8.0+
        - tvOS: 15.0+
        - visionOS: 1.0+

        Build Configurations:
        - Debug (Development)
        - Release (App Store)
        - Enterprise (Enterprise Distribution)
        - TestFlight (Beta Testing)
        """
    }
}

// MARK: - Target Configuration

public struct XcodeTargetConfiguration {
    public let name: String
    public let bundleIdentifier: String
    public let platform: Platform
    public let deploymentTarget: String
    public let productType: ProductType
    public let capabilities: [Capability]
    public let frameworks: [Framework]
    public let infoPlistKeys: [String: Any]
    public let entitlements: [String: Any]
    public let buildPhases: [BuildPhase]
    public let dependencies: [String]

    public enum Platform: String {
        case iOS = "iphoneos"
        case macOS = "macosx"
        case watchOS = "watchos"
        case tvOS = "appletvos"
        case visionOS = "xros"
    }

    public enum ProductType: String {
        case application = "com.apple.product-type.application"
        case appExtension = "com.apple.product-type.app-extension"
        case audioUnitExtension = "com.apple.product-type.app-extension"
        case widgetExtension = "com.apple.product-type.app-extension.widgetkit"
    }
}

// MARK: - iOS App Target

extension XcodeTargetConfiguration {
    public static let iosApp = XcodeTargetConfiguration(
        name: "Echoelmusic",
        bundleIdentifier: "com.echoelmusic.app",
        platform: .iOS,
        deploymentTarget: "15.0",
        productType: .application,
        capabilities: [
            .healthKit,
            .homeKit,
            .siriShortcuts,
            .pushNotifications,
            .backgroundModes,
            .networkExtensions,
            .personalVPN,
            .multipath,
            .increaseMemoryLimit,
            .extendedVirtualAddressing,
            .nearFieldCommunication,
            .communicationNotifications,
            .timeSensitiveNotifications,
            .faceID,
            .applePayPaymentProcessing,
            .inAppPurchase,
            .associatedDomains,
            .appGroups,
            .dataProtection,
            .iCloudKeyValueStorage,
            .iCloudDocuments,
            .gameCenter,
            .signInWithApple
        ],
        frameworks: [
            .avFoundation,
            .coreAudio,
            .audioToolbox,
            .accelerate,
            .metal,
            .metalKit,
            .metalPerformanceShaders,
            .healthKit,
            .watchConnectivity,
            .homeKit,
            .coreBluetooth,
            .externalAccessory,
            .coreMotion,
            .coreML,
            .vision,
            .naturalLanguage,
            .speech,
            .arKit,
            .realityKit,
            .sceneKit,
            .spriteKit,
            .gameplayKit,
            .groupActivities,
            .activityKit,
            .widgetKit,
            .appIntents,
            .userNotifications,
            .networkExtension,
            .network,
            .combine,
            .swiftUI,
            .uiKit,
            .storeKit,
            .passKit,
            .authenticationServices,
            .localAuthentication,
            .security,
            .cryptoKit
        ],
        infoPlistKeys: .iosAppKeys,
        entitlements: .iosAppEntitlements,
        buildPhases: .iosAppBuildPhases,
        dependencies: []
    )
}

// MARK: - macOS App Target

extension XcodeTargetConfiguration {
    public static let macOSApp = XcodeTargetConfiguration(
        name: "EchoelmusicMac",
        bundleIdentifier: "com.echoelmusic.mac",
        platform: .macOS,
        deploymentTarget: "12.0",
        productType: .application,
        capabilities: [
            .healthKit,
            .homeKit,
            .siriShortcuts,
            .pushNotifications,
            .networkExtensions,
            .increaseMemoryLimit,
            .applePayPaymentProcessing,
            .inAppPurchase,
            .associatedDomains,
            .appGroups,
            .dataProtection,
            .iCloudKeyValueStorage,
            .iCloudDocuments,
            .gameCenter,
            .signInWithApple,
            .userSelectedFiles,
            .downloadsFolder,
            .picturesFolder,
            .musicFolder,
            .moviesFolder,
            .camera,
            .microphone,
            .usbAccess,
            .bluetoothAlways,
            .networkClient,
            .networkServer
        ],
        frameworks: [
            .avFoundation,
            .coreAudio,
            .audioToolbox,
            .audioUnit,
            .accelerate,
            .metal,
            .metalKit,
            .metalPerformanceShaders,
            .healthKit,
            .homeKit,
            .coreBluetooth,
            .ioKit,
            .coreML,
            .vision,
            .naturalLanguage,
            .speech,
            .realityKit,
            .sceneKit,
            .spriteKit,
            .gameplayKit,
            .groupActivities,
            .appIntents,
            .userNotifications,
            .networkExtension,
            .network,
            .combine,
            .swiftUI,
            .appKit,
            .storeKit,
            .authenticationServices,
            .localAuthentication,
            .security,
            .cryptoKit
        ],
        infoPlistKeys: .macOSAppKeys,
        entitlements: .macOSAppEntitlements,
        buildPhases: .macOSAppBuildPhases,
        dependencies: []
    )
}

// MARK: - watchOS App Target

extension XcodeTargetConfiguration {
    public static let watchOSApp = XcodeTargetConfiguration(
        name: "EchoelmusicWatch",
        bundleIdentifier: "com.echoelmusic.app.watchkitapp",
        platform: .watchOS,
        deploymentTarget: "8.0",
        productType: .application,
        capabilities: [
            .healthKit,
            .homeKit,
            .pushNotifications,
            .backgroundModes,
            .communicationNotifications,
            .inAppPurchase,
            .appGroups,
            .dataProtection
        ],
        frameworks: [
            .watchKit,
            .healthKit,
            .homeKit,
            .watchConnectivity,
            .coreMotion,
            .avFoundation,
            .userNotifications,
            .combine,
            .swiftUI
        ],
        infoPlistKeys: .watchOSAppKeys,
        entitlements: .watchOSAppEntitlements,
        buildPhases: .watchOSAppBuildPhases,
        dependencies: ["Echoelmusic"]
    )
}

// MARK: - tvOS App Target

extension XcodeTargetConfiguration {
    public static let tvOSApp = XcodeTargetConfiguration(
        name: "EchoelmusicTV",
        bundleIdentifier: "com.echoelmusic.tv",
        platform: .tvOS,
        deploymentTarget: "15.0",
        productType: .application,
        capabilities: [
            .homeKit,
            .siriShortcuts,
            .pushNotifications,
            .inAppPurchase,
            .associatedDomains,
            .appGroups,
            .gameCenter,
            .signInWithApple
        ],
        frameworks: [
            .avFoundation,
            .coreAudio,
            .metal,
            .metalKit,
            .metalPerformanceShaders,
            .homeKit,
            .coreML,
            .sceneKit,
            .spriteKit,
            .gameplayKit,
            .userNotifications,
            .network,
            .combine,
            .swiftUI,
            .tvUIKit,
            .storeKit,
            .authenticationServices
        ],
        infoPlistKeys: .tvOSAppKeys,
        entitlements: .tvOSAppEntitlements,
        buildPhases: .tvOSAppBuildPhases,
        dependencies: []
    )
}

// MARK: - visionOS App Target

extension XcodeTargetConfiguration {
    public static let visionOSApp = XcodeTargetConfiguration(
        name: "EchoelmusicVision",
        bundleIdentifier: "com.echoelmusic.vision",
        platform: .visionOS,
        deploymentTarget: "1.0",
        productType: .application,
        capabilities: [
            .healthKit,
            .homeKit,
            .siriShortcuts,
            .pushNotifications,
            .inAppPurchase,
            .associatedDomains,
            .appGroups,
            .gameCenter,
            .signInWithApple,
            .spatialAudio,
            .handTracking,
            .sceneUnderstanding,
            .planeDetection
        ],
        frameworks: [
            .avFoundation,
            .coreAudio,
            .metal,
            .metalKit,
            .metalPerformanceShaders,
            .healthKit,
            .homeKit,
            .coreML,
            .vision,
            .arKit,
            .realityKit,
            .realityKitContent,
            .compositorServices,
            .spatial,
            .groupActivities,
            .userNotifications,
            .network,
            .combine,
            .swiftUI,
            .storeKit,
            .authenticationServices
        ],
        infoPlistKeys: .visionOSAppKeys,
        entitlements: .visionOSAppEntitlements,
        buildPhases: .visionOSAppBuildPhases,
        dependencies: []
    )
}

// MARK: - AUv3 Extension Target

extension XcodeTargetConfiguration {
    public static let auv3Extension = XcodeTargetConfiguration(
        name: "EchoelmusicAUv3",
        bundleIdentifier: "com.echoelmusic.app.auv3",
        platform: .iOS,
        deploymentTarget: "15.0",
        productType: .audioUnitExtension,
        capabilities: [
            .appGroups,
            .dataProtection
        ],
        frameworks: [
            .avFoundation,
            .coreAudioKit,
            .audioToolbox,
            .uiKit
        ],
        infoPlistKeys: .auv3Keys,
        entitlements: .auv3Entitlements,
        buildPhases: .auv3BuildPhases,
        dependencies: ["Echoelmusic"]
    )
}

// MARK: - Widget Extension Target

extension XcodeTargetConfiguration {
    public static let widgetExtension = XcodeTargetConfiguration(
        name: "EchoelmusicWidgets",
        bundleIdentifier: "com.echoelmusic.app.widgets",
        platform: .iOS,
        deploymentTarget: "15.0",
        productType: .widgetExtension,
        capabilities: [
            .appGroups,
            .dataProtection
        ],
        frameworks: [
            .widgetKit,
            .swiftUI,
            .healthKit
        ],
        infoPlistKeys: .widgetKeys,
        entitlements: .widgetEntitlements,
        buildPhases: .widgetBuildPhases,
        dependencies: ["Echoelmusic"]
    )
}

// MARK: - Live Activity Extension Target

extension XcodeTargetConfiguration {
    public static let liveActivityExtension = XcodeTargetConfiguration(
        name: "EchoelmusicLiveActivity",
        bundleIdentifier: "com.echoelmusic.app.liveactivity",
        platform: .iOS,
        deploymentTarget: "16.1",
        productType: .widgetExtension,
        capabilities: [
            .appGroups,
            .dataProtection,
            .pushNotifications
        ],
        frameworks: [
            .activityKit,
            .widgetKit,
            .swiftUI
        ],
        infoPlistKeys: .liveActivityKeys,
        entitlements: .liveActivityEntitlements,
        buildPhases: .liveActivityBuildPhases,
        dependencies: ["Echoelmusic"]
    )
}

// MARK: - SharePlay Extension Target

extension XcodeTargetConfiguration {
    public static let sharePlayExtension = XcodeTargetConfiguration(
        name: "EchoelmusicSharePlay",
        bundleIdentifier: "com.echoelmusic.app.shareplay",
        platform: .iOS,
        deploymentTarget: "15.0",
        productType: .appExtension,
        capabilities: [
            .appGroups,
            .dataProtection
        ],
        frameworks: [
            .groupActivities,
            .swiftUI
        ],
        infoPlistKeys: .sharePlayKeys,
        entitlements: .sharePlayEntitlements,
        buildPhases: .sharePlayBuildPhases,
        dependencies: ["Echoelmusic"]
    )
}

// MARK: - Shortcuts Extension Target

extension XcodeTargetConfiguration {
    public static let shortcutsExtension = XcodeTargetConfiguration(
        name: "EchoelmusicShortcuts",
        bundleIdentifier: "com.echoelmusic.app.shortcuts",
        platform: .iOS,
        deploymentTarget: "15.0",
        productType: .appExtension,
        capabilities: [
            .siriShortcuts,
            .appGroups
        ],
        frameworks: [
            .appIntents,
            .swiftUI
        ],
        infoPlistKeys: .shortcutsKeys,
        entitlements: .shortcutsEntitlements,
        buildPhases: .shortcutsBuildPhases,
        dependencies: ["Echoelmusic"]
    )
}

// MARK: - Capabilities

public enum Capability: String {
    // Core Capabilities
    case healthKit = "com.apple.HealthKit"
    case homeKit = "com.apple.HomeKit"
    case siriShortcuts = "com.apple.Siri"
    case pushNotifications = "com.apple.Push"
    case backgroundModes = "com.apple.BackgroundModes"

    // Network
    case networkExtensions = "com.apple.NetworkExtensions"
    case personalVPN = "com.apple.Personal-VPN"
    case multipath = "com.apple.Multipath"
    case networkClient = "com.apple.security.network.client"
    case networkServer = "com.apple.security.network.server"

    // Memory & Performance
    case increaseMemoryLimit = "com.apple.developer.kernel.increased-memory-limit"
    case extendedVirtualAddressing = "com.apple.developer.kernel.extended-virtual-addressing"

    // Hardware
    case nearFieldCommunication = "com.apple.developer.nfc.readersession.formats"
    case camera = "com.apple.security.device.camera"
    case microphone = "com.apple.security.device.microphone"
    case usbAccess = "com.apple.security.device.usb"
    case bluetoothAlways = "com.apple.security.device.bluetooth"

    // Notifications
    case communicationNotifications = "com.apple.developer.usernotifications.communication"
    case timeSensitiveNotifications = "com.apple.developer.usernotifications.time-sensitive"

    // Security
    case faceID = "com.apple.developer.authentication-services.autofill-credential-provider"
    case dataProtection = "com.apple.security.application-groups"

    // Payment
    case applePayPaymentProcessing = "com.apple.ApplePay"
    case inAppPurchase = "com.apple.InAppPurchase"

    // Cloud & Storage
    case associatedDomains = "com.apple.developer.associated-domains"
    case appGroups = "com.apple.security.application-groups"
    case iCloudKeyValueStorage = "com.apple.developer.icloud-container-identifiers"
    case iCloudDocuments = "com.apple.developer.ubiquity-container-identifiers"

    // File Access (macOS)
    case userSelectedFiles = "com.apple.security.files.user-selected.read-write"
    case downloadsFolder = "com.apple.security.files.downloads.read-write"
    case picturesFolder = "com.apple.security.assets.pictures.read-write"
    case musicFolder = "com.apple.security.assets.music.read-write"
    case moviesFolder = "com.apple.security.assets.movies.read-write"

    // Social
    case gameCenter = "com.apple.GameCenter"
    case signInWithApple = "com.apple.developer.applesignin"

    // Spatial (visionOS)
    case spatialAudio = "com.apple.developer.spatial-audio"
    case handTracking = "com.apple.developer.hand-tracking"
    case sceneUnderstanding = "com.apple.developer.scene-understanding"
    case planeDetection = "com.apple.developer.plane-detection"

    public var description: String {
        switch self {
        case .healthKit: return "HealthKit"
        case .homeKit: return "HomeKit"
        case .siriShortcuts: return "Siri & Shortcuts"
        case .pushNotifications: return "Push Notifications"
        case .backgroundModes: return "Background Modes"
        case .networkExtensions: return "Network Extensions"
        case .personalVPN: return "Personal VPN"
        case .multipath: return "Multipath"
        case .increaseMemoryLimit: return "Increased Memory Limit"
        case .extendedVirtualAddressing: return "Extended Virtual Addressing"
        case .nearFieldCommunication: return "NFC Tag Reading"
        case .communicationNotifications: return "Communication Notifications"
        case .timeSensitiveNotifications: return "Time Sensitive Notifications"
        case .faceID: return "Face ID"
        case .applePayPaymentProcessing: return "Apple Pay"
        case .inAppPurchase: return "In-App Purchase"
        case .associatedDomains: return "Associated Domains"
        case .appGroups: return "App Groups"
        case .dataProtection: return "Data Protection"
        case .iCloudKeyValueStorage: return "iCloud Key-Value Storage"
        case .iCloudDocuments: return "iCloud Documents"
        case .gameCenter: return "Game Center"
        case .signInWithApple: return "Sign in with Apple"
        case .networkClient: return "Network Client"
        case .networkServer: return "Network Server"
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .usbAccess: return "USB Access"
        case .bluetoothAlways: return "Bluetooth Always"
        case .userSelectedFiles: return "User Selected Files"
        case .downloadsFolder: return "Downloads Folder"
        case .picturesFolder: return "Pictures Folder"
        case .musicFolder: return "Music Folder"
        case .moviesFolder: return "Movies Folder"
        case .spatialAudio: return "Spatial Audio"
        case .handTracking: return "Hand Tracking"
        case .sceneUnderstanding: return "Scene Understanding"
        case .planeDetection: return "Plane Detection"
        }
    }
}

// MARK: - Frameworks

public enum Framework: String {
    // Audio
    case avFoundation = "AVFoundation"
    case coreAudio = "CoreAudio"
    case audioToolbox = "AudioToolbox"
    case audioUnit = "AudioUnit"
    case coreAudioKit = "CoreAudioKit"
    case accelerate = "Accelerate"

    // Graphics & Metal
    case metal = "Metal"
    case metalKit = "MetalKit"
    case metalPerformanceShaders = "MetalPerformanceShaders"

    // Health & Home
    case healthKit = "HealthKit"
    case homeKit = "HomeKit"
    case watchKit = "WatchKit"
    case watchConnectivity = "WatchConnectivity"

    // Connectivity
    case coreBluetooth = "CoreBluetooth"
    case externalAccessory = "ExternalAccessory"
    case network = "Network"
    case networkExtension = "NetworkExtension"

    // Motion & Sensors
    case coreMotion = "CoreMotion"

    // Machine Learning
    case coreML = "CoreML"
    case vision = "Vision"
    case naturalLanguage = "NaturalLanguage"
    case speech = "Speech"

    // AR & 3D
    case arKit = "ARKit"
    case realityKit = "RealityKit"
    case realityKitContent = "RealityKitContent"
    case compositorServices = "CompositorServices"
    case spatial = "Spatial"
    case sceneKit = "SceneKit"
    case spriteKit = "SpriteKit"
    case gameplayKit = "GameplayKit"

    // Collaboration
    case groupActivities = "GroupActivities"
    case activityKit = "ActivityKit"
    case widgetKit = "WidgetKit"
    case appIntents = "AppIntents"

    // Notifications
    case userNotifications = "UserNotifications"

    // Reactive
    case combine = "Combine"

    // UI Frameworks
    case swiftUI = "SwiftUI"
    case uiKit = "UIKit"
    case appKit = "AppKit"
    case tvUIKit = "TVUIKit"

    // Commerce
    case storeKit = "StoreKit"
    case passKit = "PassKit"

    // Security
    case authenticationServices = "AuthenticationServices"
    case localAuthentication = "LocalAuthentication"
    case security = "Security"
    case cryptoKit = "CryptoKit"

    // System (macOS)
    case ioKit = "IOKit"

    public var isSystem: Bool {
        return true // All Apple frameworks
    }
}

// MARK: - Info.plist Keys

extension Dictionary where Key == String, Value == Any {
    public static let iosAppKeys: [String: Any] = [
        // Basic Info
        "CFBundleDisplayName": "Echoelmusic",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "10000.0.0",
        "CFBundlePackageType": "APPL",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",

        // iOS Deployment
        "LSRequiresIPhoneOS": true,
        "MinimumOSVersion": "15.0",

        // Privacy Permissions
        "NSHealthShareUsageDescription": "Echoelmusic uses your heart rate and HRV to create bio-reactive music and visuals. Your health data never leaves your device.",
        "NSHealthUpdateUsageDescription": "Echoelmusic can log meditation and coherence sessions to your Health app.",
        "NSMicrophoneUsageDescription": "Echoelmusic uses your microphone for voice-to-audio synthesis and pitch detection.",
        "NSCameraUsageDescription": "Echoelmusic uses your camera for face tracking to control audio parameters with facial expressions.",
        "NSFaceIDUsageDescription": "Echoelmusic uses Face ID to secure enterprise features and sensitive settings.",
        "NSBluetoothAlwaysUsageDescription": "Echoelmusic connects to MIDI controllers, audio interfaces, and biometric sensors via Bluetooth.",
        "NSBluetoothPeripheralUsageDescription": "Echoelmusic connects to external music hardware and health sensors.",
        "NSLocalNetworkUsageDescription": "Echoelmusic discovers DMX lighting controllers, Art-Net devices, and streaming endpoints on your local network.",
        "NSBonjourServices": ["_http._tcp", "_rtsp._tcp", "_artnet._udp", "_osc._udp"],
        "NSHomeKitUsageDescription": "Echoelmusic can control HomeKit lights and scenes synchronized to your music.",
        "NSMotionUsageDescription": "Echoelmusic uses motion data to detect gestures and movement patterns for interactive control.",
        "NSLocationWhenInUseUsageDescription": "Echoelmusic uses location for worldwide collaboration server selection and timezone-aware sessions.",
        "NSSpeechRecognitionUsageDescription": "Echoelmusic uses speech recognition for voice commands and lyrics generation.",
        "NSContactsUsageDescription": "Echoelmusic can access contacts for collaborative session invitations.",
        "NSPhotoLibraryUsageDescription": "Echoelmusic can save visualizations and session screenshots to your photo library.",
        "NSPhotoLibraryAddUsageDescription": "Echoelmusic can save generated art and video to your photo library.",

        // Background Modes
        "UIBackgroundModes": [
            "audio",
            "bluetooth-central",
            "bluetooth-peripheral",
            "external-accessory",
            "fetch",
            "processing",
            "remote-notification"
        ],

        // Supported External Accessory Protocols
        "UISupportedExternalAccessoryProtocols": [
            "com.ableton.push3",
            "com.native-instruments.maschine",
            "com.akai.mpc",
            "com.novation.launchpad",
            "com.arturia.keylab"
        ],

        // Required Device Capabilities
        "UIRequiredDeviceCapabilities": ["armv7", "metal"],

        // Supported Interface Orientations
        "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight",
            "UIInterfaceOrientationPortraitUpsideDown"
        ],
        "UISupportedInterfaceOrientations~ipad": [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight",
            "UIInterfaceOrientationPortraitUpsideDown"
        ],

        // Launch Screen
        "UILaunchScreen": [:],

        // Scene Configuration - SwiftUI @main App handles scenes automatically
        "UIApplicationSceneManifest": [
            "UIApplicationSupportsMultipleScenes": false
        ],

        // App Transport Security
        "NSAppTransportSecurity": [
            "NSAllowsArbitraryLoads": false,
            "NSAllowsLocalNetworking": true,
            "NSExceptionDomains": [
                "echoelmusic.com": [
                    "NSIncludesSubdomains": true,
                    "NSTemporaryExceptionAllowsInsecureHTTPLoads": false,
                    "NSTemporaryExceptionRequiresForwardSecrecy": true,
                    "NSTemporaryExceptionMinimumTLSVersion": "TLSv1.2"
                ]
            ]
        ],

        // Audio Session
        "UISupportsDocumentBrowser": true,
        "LSSupportsOpeningDocumentsInPlace": true,

        // Document Types (for project files)
        "CFBundleDocumentTypes": [
            [
                "CFBundleTypeName": "Echoelmusic Project",
                "CFBundleTypeIconFiles": [],
                "LSHandlerRank": "Owner",
                "LSItemContentTypes": ["com.echoelmusic.project"]
            ]
        ],

        // Exported UTIs
        "UTExportedTypeDeclarations": [
            [
                "UTTypeIdentifier": "com.echoelmusic.project",
                "UTTypeDescription": "Echoelmusic Project",
                "UTTypeConformsTo": ["public.data"],
                "UTTypeTagSpecification": [
                    "public.filename-extension": ["echoproject", "echo"]
                ]
            ]
        ],

        // Audio Components (for AUv3)
        "AudioComponents": [
            [
                "name": "Echoelmusic: Quantum Synth",
                "manufacturer": "Echo",
                "type": "aumu",
                "subtype": "qsyn",
                "version": 1,
                "sandboxSafe": true,
                "factoryFunction": "createEchoelmusicAU",
                "tags": ["Synthesizer", "Bio-Reactive", "Quantum"]
            ]
        ],

        // App Capabilities
        "NSSupportsLiveActivities": true,

        // Siri Intent Definitions
        "NSUserActivityTypes": [
            "com.echoelmusic.start-session",
            "com.echoelmusic.check-coherence",
            "com.echoelmusic.set-quantum-mode",
            "com.echoelmusic.trigger-entanglement",
            "com.echoelmusic.start-group-session",
            "com.echoelmusic.quick-meditation"
        ]
    ]

    public static let macOSAppKeys: [String: Any] = [
        // Basic Info
        "CFBundleDisplayName": "Echoelmusic",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "10000.0.0",
        "CFBundlePackageType": "APPL",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",

        // macOS Deployment
        "LSMinimumSystemVersion": "12.0",
        "NSPrincipalClass": "NSApplication",

        // Privacy Permissions
        "NSHealthShareUsageDescription": "Echoelmusic uses your health data for bio-reactive music creation.",
        "NSMicrophoneUsageDescription": "Echoelmusic uses your microphone for audio synthesis and pitch detection.",
        "NSCameraUsageDescription": "Echoelmusic uses your camera for face tracking control.",
        "NSBluetoothAlwaysUsageDescription": "Echoelmusic connects to MIDI and audio hardware via Bluetooth.",
        "NSLocalNetworkUsageDescription": "Echoelmusic discovers DMX controllers and streaming endpoints.",
        "NSBonjourServices": ["_http._tcp", "_rtsp._tcp", "_artnet._udp", "_osc._udp"],
        "NSHomeKitUsageDescription": "Echoelmusic controls HomeKit lights synchronized to music.",

        // High Resolution Support
        "NSHighResolutionCapable": true,

        // Supported Document Types
        "CFBundleDocumentTypes": [
            [
                "CFBundleTypeName": "Echoelmusic Project",
                "CFBundleTypeRole": "Editor",
                "LSHandlerRank": "Owner",
                "LSItemContentTypes": ["com.echoelmusic.project"]
            ]
        ],

        // Exported UTIs
        "UTExportedTypeDeclarations": [
            [
                "UTTypeIdentifier": "com.echoelmusic.project",
                "UTTypeDescription": "Echoelmusic Project",
                "UTTypeConformsTo": ["public.data"],
                "UTTypeTagSpecification": [
                    "public.filename-extension": ["echoproject", "echo"]
                ]
            ]
        ]
    ]

    public static let watchOSAppKeys: [String: Any] = [
        "CFBundleDisplayName": "Echoelmusic",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "10000.0.0",
        "CFBundlePackageType": "APPL",
        "MinimumOSVersion": "8.0",
        "WKWatchKitApp": true,
        "WKCompanionAppBundleIdentifier": "com.echoelmusic.app",
        "NSHealthShareUsageDescription": "View real-time coherence and HRV on your wrist.",
        "UIBackgroundModes": ["workout-processing", "remote-notification"]
    ]

    public static let tvOSAppKeys: [String: Any] = [
        "CFBundleDisplayName": "Echoelmusic",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "10000.0.0",
        "MinimumOSVersion": "15.0",
        "NSLocalNetworkUsageDescription": "Echoelmusic discovers streaming endpoints on your network.",
        "UIBackgroundModes": ["audio"]
    ]

    public static let visionOSAppKeys: [String: Any] = [
        "CFBundleDisplayName": "Echoelmusic",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "10000.0.0",
        "MinimumOSVersion": "1.0",
        "NSHealthShareUsageDescription": "Echoelmusic creates immersive bio-reactive experiences.",
        "NSCameraUsageDescription": "Echoelmusic uses eye tracking for gaze-based audio control.",
        "NSHandTrackingUsageDescription": "Echoelmusic uses hand tracking for spatial gesture control.",
        "UIBackgroundModes": ["audio"],
        "UIApplicationPreferredDefaultSceneSessionRole": "UIWindowSceneSessionRoleImmersiveSpaceApplication",
        "UIApplicationSceneManifest": [
            "UIApplicationSupportsMultipleScenes": true,
            "UISceneConfigurations": [
                "UIWindowSceneSessionRoleImmersiveSpaceApplication": [
                    [
                        "UISceneConfigurationName": "Quantum Immersive Space",
                        "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).ImmersiveSceneDelegate"
                    ]
                ]
            ]
        ]
    ]

    public static let auv3Keys: [String: Any] = [
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "10000.0.0",
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.AudioUnit-UI",
            "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).AudioUnitViewController"
        ],
        "AudioComponents": [
            [
                "name": "Echoelmusic: Quantum Synth",
                "manufacturer": "Echo",
                "type": "aumu",
                "subtype": "qsyn",
                "version": 1,
                "sandboxSafe": true,
                "factoryFunction": "createEchoelmusicAU",
                "tags": ["Synthesizer", "Bio-Reactive", "Quantum"]
            ]
        ]
    ]

    public static let widgetKeys: [String: Any] = [
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "10000.0.0",
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
        ]
    ]

    public static let liveActivityKeys: [String: Any] = [
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "10000.0.0",
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
        ],
        "NSSupportsLiveActivities": true
    ]

    public static let sharePlayKeys: [String: Any] = [
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "10000.0.0",
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.group-activities"
        ]
    ]

    public static let shortcutsKeys: [String: Any] = [
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "10000.0.0",
        "NSExtension": [
            "NSExtensionPointIdentifier": "com.apple.intents-service"
        ]
    ]
}

// MARK: - Entitlements

extension Dictionary where Key == String, Value == Any {
    public static let iosAppEntitlements: [String: Any] = [
        // HealthKit
        "com.apple.developer.healthkit": true,
        "com.apple.developer.healthkit.access": ["health-records"],

        // HomeKit
        "com.apple.developer.homekit": true,

        // Siri & Shortcuts
        "com.apple.developer.siri": true,

        // Push Notifications
        "aps-environment": "production",

        // Background Modes
        "com.apple.developer.associated-domains": ["applinks:echoelmusic.com"],

        // App Groups
        "com.apple.security.application-groups": [
            "group.com.echoelmusic.shared"
        ],

        // iCloud
        "com.apple.developer.icloud-container-identifiers": [
            "iCloud.com.echoelmusic.app"
        ],
        "com.apple.developer.icloud-services": ["CloudKit", "CloudDocuments"],
        "com.apple.developer.ubiquity-container-identifiers": [
            "iCloud.com.echoelmusic.app"
        ],
        "com.apple.developer.ubiquity-kvstore-identifier": "$(TeamIdentifierPrefix)com.echoelmusic.app",

        // Network Extensions
        "com.apple.developer.networking.networkextension": [
            "packet-tunnel-provider",
            "app-proxy-provider"
        ],
        "com.apple.developer.networking.vpn.api": ["allow-vpn"],
        "com.apple.developer.networking.multipath": true,

        // Performance
        "com.apple.developer.kernel.increased-memory-limit": true,
        "com.apple.developer.kernel.extended-virtual-addressing": true,

        // NFC
        "com.apple.developer.nfc.readersession.formats": ["NDEF", "TAG"],

        // Notifications
        "com.apple.developer.usernotifications.communication": true,
        "com.apple.developer.usernotifications.time-sensitive": true,

        // Apple Pay
        "com.apple.developer.in-app-payments": ["merchant.com.echoelmusic"],

        // Sign in with Apple
        "com.apple.developer.applesignin": ["Default"],

        // Game Center
        "com.apple.developer.game-center": true,

        // Data Protection
        "com.apple.developer.default-data-protection": "NSFileProtectionComplete"
    ]

    public static let macOSAppEntitlements: [String: Any] = [
        // HealthKit
        "com.apple.developer.healthkit": true,

        // HomeKit
        "com.apple.developer.homekit": true,

        // Siri
        "com.apple.developer.siri": true,

        // Push Notifications
        "aps-environment": "production",

        // Associated Domains
        "com.apple.developer.associated-domains": ["applinks:echoelmusic.com"],

        // App Groups
        "com.apple.security.application-groups": [
            "group.com.echoelmusic.shared"
        ],

        // iCloud
        "com.apple.developer.icloud-container-identifiers": [
            "iCloud.com.echoelmusic.mac"
        ],
        "com.apple.developer.icloud-services": ["CloudKit", "CloudDocuments"],
        "com.apple.developer.ubiquity-container-identifiers": [
            "iCloud.com.echoelmusic.mac"
        ],

        // File Access
        "com.apple.security.files.user-selected.read-write": true,
        "com.apple.security.files.downloads.read-write": true,
        "com.apple.security.assets.pictures.read-write": true,
        "com.apple.security.assets.music.read-write": true,
        "com.apple.security.assets.movies.read-write": true,

        // Device Access
        "com.apple.security.device.camera": true,
        "com.apple.security.device.microphone": true,
        "com.apple.security.device.usb": true,
        "com.apple.security.device.bluetooth": true,

        // Network
        "com.apple.security.network.client": true,
        "com.apple.security.network.server": true,

        // Hardened Runtime
        "com.apple.security.app-sandbox": true,
        "com.apple.security.audio-input": true,
        "com.apple.security.device.audio-input": true,

        // Apple Pay
        "com.apple.developer.in-app-payments": ["merchant.com.echoelmusic"],

        // Sign in with Apple
        "com.apple.developer.applesignin": ["Default"],

        // Game Center
        "com.apple.developer.game-center": true
    ]

    public static let watchOSAppEntitlements: [String: Any] = [
        "com.apple.developer.healthkit": true,
        "com.apple.developer.homekit": true,
        "aps-environment": "production",
        "com.apple.security.application-groups": [
            "group.com.echoelmusic.shared"
        ]
    ]

    public static let tvOSAppEntitlements: [String: Any] = [
        "com.apple.developer.homekit": true,
        "com.apple.developer.siri": true,
        "aps-environment": "production",
        "com.apple.developer.associated-domains": ["applinks:echoelmusic.com"],
        "com.apple.security.application-groups": [
            "group.com.echoelmusic.shared"
        ],
        "com.apple.developer.applesignin": ["Default"],
        "com.apple.developer.game-center": true
    ]

    public static let visionOSAppEntitlements: [String: Any] = [
        "com.apple.developer.healthkit": true,
        "com.apple.developer.homekit": true,
        "com.apple.developer.siri": true,
        "aps-environment": "production",
        "com.apple.developer.associated-domains": ["applinks:echoelmusic.com"],
        "com.apple.security.application-groups": [
            "group.com.echoelmusic.shared"
        ],
        "com.apple.developer.applesignin": ["Default"],
        "com.apple.developer.game-center": true,

        // visionOS-specific
        "com.apple.developer.spatial-audio.multi-channel": true,
        "com.apple.developer.hand-tracking": true,
        "com.apple.developer.scene-understanding": true,
        "com.apple.developer.plane-detection": true
    ]

    public static let auv3Entitlements: [String: Any] = [
        "com.apple.security.application-groups": [
            "group.com.echoelmusic.shared"
        ]
    ]

    public static let widgetEntitlements: [String: Any] = [
        "com.apple.security.application-groups": [
            "group.com.echoelmusic.shared"
        ],
        "com.apple.developer.healthkit": true
    ]

    public static let liveActivityEntitlements: [String: Any] = [
        "com.apple.security.application-groups": [
            "group.com.echoelmusic.shared"
        ],
        "aps-environment": "production"
    ]

    public static let sharePlayEntitlements: [String: Any] = [
        "com.apple.security.application-groups": [
            "group.com.echoelmusic.shared"
        ]
    ]

    public static let shortcutsEntitlements: [String: Any] = [
        "com.apple.security.application-groups": [
            "group.com.echoelmusic.shared"
        ],
        "com.apple.developer.siri": true
    ]
}

// MARK: - Build Phases

public enum BuildPhase {
    case sources([SourceFile])
    case resources([String])
    case frameworks([Framework])
    case headers([String])
    case copyFiles([String], destination: String)
    case runScript(String, name: String)

    public struct SourceFile {
        public let path: String
        public let compilerFlags: String?

        public init(path: String, compilerFlags: String? = nil) {
            self.path = path
            self.compilerFlags = compilerFlags
        }
    }
}

extension Array where Element == BuildPhase {
    public static let iosAppBuildPhases: [BuildPhase] = [
        .sources(SourceFiles.iosApp),
        .resources([
            "Sources/Echoelmusic/Resources/**/*",
            "Sources/Echoelmusic/Shaders/*.metal"
        ]),
        .frameworks(Framework.allCases.filter { _ in true })
    ]

    public static let macOSAppBuildPhases: [BuildPhase] = [
        .sources(SourceFiles.macOSApp),
        .resources([
            "Sources/Echoelmusic/Resources/**/*",
            "Sources/Echoelmusic/Shaders/*.metal"
        ]),
        .frameworks(Framework.allCases.filter { _ in true })
    ]

    public static let watchOSAppBuildPhases: [BuildPhase] = [
        .sources(SourceFiles.watchOSApp),
        .resources(["Sources/Echoelmusic/WatchOS/**/*"]),
        .frameworks([.watchKit, .healthKit, .homeKit])
    ]

    public static let tvOSAppBuildPhases: [BuildPhase] = [
        .sources(SourceFiles.tvOSApp),
        .resources(["Sources/Echoelmusic/tvOS/**/*"]),
        .frameworks([.avFoundation, .metal, .homeKit])
    ]

    public static let visionOSAppBuildPhases: [BuildPhase] = [
        .sources(SourceFiles.visionOSApp),
        .resources([
            "Sources/Echoelmusic/VisionOS/**/*",
            "Sources/Echoelmusic/Shaders/*.metal"
        ]),
        .frameworks([.realityKit, .arKit, .spatial])
    ]

    public static let auv3BuildPhases: [BuildPhase] = [
        .sources(SourceFiles.auv3),
        .frameworks([.avFoundation, .coreAudioKit, .audioToolbox])
    ]

    public static let widgetBuildPhases: [BuildPhase] = [
        .sources(SourceFiles.widgets),
        .frameworks([.widgetKit, .swiftUI])
    ]

    public static let liveActivityBuildPhases: [BuildPhase] = [
        .sources(SourceFiles.liveActivity),
        .frameworks([.activityKit, .widgetKit, .swiftUI])
    ]

    public static let sharePlayBuildPhases: [BuildPhase] = [
        .sources(SourceFiles.sharePlay),
        .frameworks([.groupActivities, .swiftUI])
    ]

    public static let shortcutsBuildPhases: [BuildPhase] = [
        .sources(SourceFiles.shortcuts),
        .frameworks([.appIntents, .swiftUI])
    ]
}

// MARK: - Source Files Organization

public struct SourceFiles {
    public static let iosApp: [BuildPhase.SourceFile] = [
        // Core
        .init(path: "Sources/Echoelmusic/Echoelmusic.swift"),
        .init(path: "Sources/Echoelmusic/Core/Constants.swift"),
        .init(path: "Sources/Echoelmusic/Core/Utilities.swift"),
        .init(path: "Sources/Echoelmusic/Core/Logger.swift"),
        .init(path: "Sources/Echoelmusic/Core/ProfessionalLogger.swift"),

        // Audio Engine
        .init(path: "Sources/Echoelmusic/Audio/AudioEngine.swift"),
        .init(path: "Sources/Echoelmusic/Audio/BinauralBeatNode.swift"),
        .init(path: "Sources/Echoelmusic/Audio/GranularSynthNode.swift"),
        .init(path: "Sources/Echoelmusic/Audio/PitchDetector.swift"),

        // Spatial Audio
        .init(path: "Sources/Echoelmusic/Spatial/SpatialAudioEngine.swift"),
        .init(path: "Sources/Echoelmusic/Spatial/AffordanceFieldAudio.swift"),

        // Biofeedback
        .init(path: "Sources/Echoelmusic/Biofeedback/HealthKitManager.swift"),
        .init(path: "Sources/Echoelmusic/Biofeedback/BioModulator.swift"),
        .init(path: "Sources/Echoelmusic/Biofeedback/RealTimeHealthKitEngine.swift"),

        // Unified Control
        .init(path: "Sources/Echoelmusic/Unified/UnifiedControlHub.swift"),
        .init(path: "Sources/Echoelmusic/Unified/FaceToAudioMapper.swift"),
        .init(path: "Sources/Echoelmusic/Unified/HandGestureRecognizer.swift"),
        .init(path: "Sources/Echoelmusic/Unified/GazeTracker.swift"),
        .init(path: "Sources/Echoelmusic/Unified/UnifiedControlParameters.swift"),

        // MIDI
        .init(path: "Sources/Echoelmusic/MIDI/MIDIManager.swift"),
        .init(path: "Sources/Echoelmusic/MIDI/MPEController.swift"),

        // Lighting
        .init(path: "Sources/Echoelmusic/LED/Push3LEDController.swift"),
        .init(path: "Sources/Echoelmusic/LED/MIDIToLightMapper.swift"),

        // Visual
        .init(path: "Sources/Echoelmusic/Visual/MIDIToVisualMapper.swift"),
        .init(path: "Sources/Echoelmusic/Visual/PhotonicsVisualizationEngine.swift"),

        // Quantum
        .init(path: "Sources/Echoelmusic/Quantum/QuantumLightEmulator.swift"),
        .init(path: "Sources/Echoelmusic/Quantum/QuantumLoopLightScienceEngine.swift"),

        // Lambda Mode
        .init(path: "Sources/Echoelmusic/Lambda/LambdaModeEngine.swift"),
        .init(path: "Sources/Echoelmusic/Lambda/LambdaHealthDisclaimer.swift"),

        // Video Processing
        .init(path: "Sources/Echoelmusic/Video/VideoProcessingEngine.swift"),
        .init(path: "Sources/Echoelmusic/Video/Intelligent360VisualEngine.swift"),
        .init(path: "Sources/Echoelmusic/Video/ImmersiveVRAREngine.swift"),
        .init(path: "Sources/Echoelmusic/Video/AILiveProductionEngine.swift"),
        .init(path: "Sources/Echoelmusic/Video/AISceneDirector.swift"),

        // Creative Studio
        .init(path: "Sources/Echoelmusic/Creative/CreativeStudioEngine.swift"),
        .init(path: "Sources/Echoelmusic/Creative/BiometricMusicGenerator.swift"),

        // Scientific
        .init(path: "Sources/Echoelmusic/Science/ScientificVisualizationEngine.swift"),

        // Collaboration
        .init(path: "Sources/Echoelmusic/Collaboration/WorldwideCollaborationHub.swift"),
        .init(path: "Sources/Echoelmusic/Collaboration/SocialCoherenceEngine.swift"),

        // Haptics
        .init(path: "Sources/Echoelmusic/Haptics/HapticCompositionEngine.swift"),

        // Streaming
        .init(path: "Sources/Echoelmusic/Stream/StreamEngine.swift"),
        .init(path: "Sources/Echoelmusic/Stream/ProfessionalStreamingEngine.swift"),

        // Orchestral (Phase 10000)
        .init(path: "Sources/Echoelmusic/Orchestral/CinematicScoringEngine.swift"),
        .init(path: "Sources/Echoelmusic/Orchestral/FilmScoreComposer.swift"),

        // Hardware Ecosystem
        .init(path: "Sources/Echoelmusic/Hardware/HardwareEcosystem.swift"),
        .init(path: "Sources/Echoelmusic/Hardware/CrossPlatformSessionManager.swift"),

        // Production & Security
        .init(path: "Sources/Echoelmusic/Production/ProductionConfiguration.swift"),
        .init(path: "Sources/Echoelmusic/Production/FeatureFlagManager.swift"),
        .init(path: "Sources/Echoelmusic/Production/SecretsManager.swift"),
        .init(path: "Sources/Echoelmusic/Production/EnterpriseSecurityLayer.swift"),
        .init(path: "Sources/Echoelmusic/Production/BiometricAuthService.swift"),
        .init(path: "Sources/Echoelmusic/Production/ProductionMonitoring.swift"),
        .init(path: "Sources/Echoelmusic/Production/ErrorRecoverySystem.swift"),
        .init(path: "Sources/Echoelmusic/Production/RateLimiter.swift"),
        .init(path: "Sources/Echoelmusic/Production/ReleaseManager.swift"),
        .init(path: "Sources/Echoelmusic/Production/ProductionSafetyWrappers.swift"),

        // Accessibility
        .init(path: "Sources/Echoelmusic/Accessibility/AccessibilityManager.swift"),
        .init(path: "Sources/Echoelmusic/Accessibility/InclusiveMobilityManager.swift"),
        .init(path: "Sources/Echoelmusic/Accessibility/QuantumAccessibility.swift"),

        // Localization
        .init(path: "Sources/Echoelmusic/Localization/LocalizationManager.swift"),

        // Developer SDK
        .init(path: "Sources/Echoelmusic/Developer/PluginManager.swift"),
        .init(path: "Sources/Echoelmusic/Developer/SamplePlugins.swift"),

        // Views
        .init(path: "Sources/Echoelmusic/Views/Phase8000DemoView.swift"),
        .init(path: "Sources/Echoelmusic/Views/VideoProcessingView.swift"),
        .init(path: "Sources/Echoelmusic/Views/CreativeStudioView.swift"),
        .init(path: "Sources/Echoelmusic/Views/ScientificDashboardView.swift"),
        .init(path: "Sources/Echoelmusic/Views/WellnessSessionView.swift"),
        .init(path: "Sources/Echoelmusic/Views/CollaborationLobbyView.swift"),
        .init(path: "Sources/Echoelmusic/Views/DeveloperConsoleView.swift"),
        .init(path: "Sources/Echoelmusic/Views/HardwarePickerView.swift"),

        // Presets
        .init(path: "Sources/Echoelmusic/Presets/PresetManager.swift")
    ]

    public static let macOSApp = iosApp // Share most files
    public static let watchOSApp: [BuildPhase.SourceFile] = [
        .init(path: "Sources/Echoelmusic/WatchOS/WatchApp.swift"),
        .init(path: "Sources/Echoelmusic/WatchOS/CoherenceComplication.swift")
    ]
    public static let tvOSApp: [BuildPhase.SourceFile] = [
        .init(path: "Sources/Echoelmusic/tvOS/TVApp.swift"),
        .init(path: "Sources/Echoelmusic/tvOS/TVVisualizationView.swift")
    ]
    public static let visionOSApp: [BuildPhase.SourceFile] = [
        .init(path: "Sources/Echoelmusic/VisionOS/VisionApp.swift"),
        .init(path: "Sources/Echoelmusic/VisionOS/ImmersiveQuantumSpace.swift")
    ]
    public static let auv3: [BuildPhase.SourceFile] = [
        .init(path: "Sources/Plugin/AudioUnitViewController.swift"),
        .init(path: "Sources/Plugin/EchoelmusicAudioUnit.swift")
    ]
    public static let widgets: [BuildPhase.SourceFile] = [
        .init(path: "Sources/Echoelmusic/Widgets/CoherenceWidget.swift"),
        .init(path: "Sources/Echoelmusic/Widgets/QuickSessionWidget.swift")
    ]
    public static let liveActivity: [BuildPhase.SourceFile] = [
        .init(path: "Sources/Echoelmusic/LiveActivity/QuantumSessionActivity.swift")
    ]
    public static let sharePlay: [BuildPhase.SourceFile] = [
        .init(path: "Sources/Echoelmusic/SharePlay/QuantumSharePlayActivity.swift")
    ]
    public static let shortcuts: [BuildPhase.SourceFile] = [
        .init(path: "Sources/Echoelmusic/Shortcuts/EchoelmusicIntents.swift")
    ]
}

// MARK: - Build Settings

public struct XcodeBuildSettings {
    public let swiftVersion: String
    public let iphoneOSDeploymentTarget: String
    public let macOSDeploymentTarget: String
    public let watchOSDeploymentTarget: String
    public let tvOSDeploymentTarget: String
    public let visionOSDeploymentTarget: String
    public let enableBitcode: Bool
    public let swiftOptimizationLevel: String
    public let swiftCompilationMode: String
    public let otherSwiftFlags: [String]
    public let otherLinkerFlags: [String]
    public let headerSearchPaths: [String]
    public let frameworkSearchPaths: [String]
    public let librarySearchPaths: [String]

    public static let echoelmusicDefaults = XcodeBuildSettings(
        swiftVersion: "5.9",
        iphoneOSDeploymentTarget: "15.0",
        macOSDeploymentTarget: "12.0",
        watchOSDeploymentTarget: "8.0",
        tvOSDeploymentTarget: "15.0",
        visionOSDeploymentTarget: "1.0",
        enableBitcode: false,
        swiftOptimizationLevel: "-Owholemodule",
        swiftCompilationMode: "wholemodule",
        otherSwiftFlags: [
            "-enable-library-evolution",
            "-strict-concurrency=complete",
            "-enable-actor-data-race-checks"
        ],
        otherLinkerFlags: [
            "-Xlinker", "-interposable"
        ],
        headerSearchPaths: [
            "$(inherited)",
            "$(PROJECT_DIR)/Sources/DSP/include"
        ],
        frameworkSearchPaths: [
            "$(inherited)",
            "$(PROJECT_DIR)/Frameworks"
        ],
        librarySearchPaths: [
            "$(inherited)"
        ]
    )
}

// MARK: - Schemes

public struct XcodeScheme {
    public let name: String
    public let buildConfiguration: String
    public let testTargets: [String]
    public let environmentVariables: [String: String]
    public let commandLineArguments: [String]

    public static let debug = XcodeScheme(
        name: "Echoelmusic Debug",
        buildConfiguration: "Debug",
        testTargets: ["EchoelmusicTests"],
        environmentVariables: [
            "ECHOELMUSIC_ENV": "development",
            "OS_ACTIVITY_MODE": "enable"
        ],
        commandLineArguments: [
            "-com.apple.CoreData.ConcurrencyDebug", "1",
            "-com.apple.CoreData.ThreadingDebug", "1"
        ]
    )

    public static let release = XcodeScheme(
        name: "Echoelmusic Release",
        buildConfiguration: "Release",
        testTargets: ["EchoelmusicTests"],
        environmentVariables: [
            "ECHOELMUSIC_ENV": "production"
        ],
        commandLineArguments: []
    )

    public static let enterprise = XcodeScheme(
        name: "Echoelmusic Enterprise",
        buildConfiguration: "Enterprise",
        testTargets: ["EchoelmusicTests"],
        environmentVariables: [
            "ECHOELMUSIC_ENV": "enterprise",
            "ENABLE_ENTERPRISE_FEATURES": "1"
        ],
        commandLineArguments: []
    )

    public static let testFlight = XcodeScheme(
        name: "Echoelmusic TestFlight",
        buildConfiguration: "TestFlight",
        testTargets: ["EchoelmusicTests"],
        environmentVariables: [
            "ECHOELMUSIC_ENV": "staging"
        ],
        commandLineArguments: []
    )
}

// MARK: - Code Signing

public struct CodeSigningConfiguration {
    public let developmentTeam: String
    public let codeSignIdentity: String
    public let provisioningProfileSpecifier: [String: String] // Target name -> Profile name
    public let automaticSigning: Bool

    public static let echoelmusicDefaults = CodeSigningConfiguration(
        developmentTeam: "YOUR_TEAM_ID", // Replace with actual Team ID
        codeSignIdentity: "Apple Development",
        provisioningProfileSpecifier: [
            "Echoelmusic": "Echoelmusic iOS App Store",
            "EchoelmusicMac": "Echoelmusic macOS App Store",
            "EchoelmusicWatch": "Echoelmusic watchOS App Store",
            "EchoelmusicTV": "Echoelmusic tvOS App Store",
            "EchoelmusicVision": "Echoelmusic visionOS App Store",
            "EchoelmusicAUv3": "Echoelmusic Audio Unit",
            "EchoelmusicWidgets": "Echoelmusic Widgets",
            "EchoelmusicLiveActivity": "Echoelmusic Live Activity",
            "EchoelmusicSharePlay": "Echoelmusic SharePlay",
            "EchoelmusicShortcuts": "Echoelmusic Shortcuts"
        ],
        automaticSigning: false // Use manual signing for production
    )

    public var releaseSigningSettings: [String: String] {
        [
            "CODE_SIGN_STYLE": automaticSigning ? "Automatic" : "Manual",
            "DEVELOPMENT_TEAM": developmentTeam,
            "CODE_SIGN_IDENTITY": "Apple Distribution",
            "PROVISIONING_PROFILE_SPECIFIER": "$(TARGET_NAME) App Store"
        ]
    }

    public var debugSigningSettings: [String: String] {
        [
            "CODE_SIGN_STYLE": "Automatic",
            "DEVELOPMENT_TEAM": developmentTeam,
            "CODE_SIGN_IDENTITY": "Apple Development"
        ]
    }
}

// MARK: - Documentation Generator

extension XcodeProjectConfiguration {
    /// Generate comprehensive project setup documentation
    public func generateSetupDocumentation() -> String {
        """
        # Echoelmusic Xcode Project Setup Guide

        ## Project Information

        - **Project Name:** \(projectName)
        - **Organization:** \(organizationName)
        - **Base Bundle ID:** \(bundleIdentifierBase)
        - **Targets:** \(targets.count)
        - **Schemes:** \(schemes.count)

        ## Targets Configuration

        \(targets.map { target in
            """
            ### \(target.name) (\(target.platform.rawValue))

            - **Bundle ID:** \(target.bundleIdentifier)
            - **Deployment Target:** \(target.deploymentTarget)
            - **Capabilities:** \(target.capabilities.count)
              \(target.capabilities.map { "  - \($0.description)" }.joined(separator: "\n"))

            - **Frameworks:** \(target.frameworks.count)
              \(target.frameworks.prefix(10).map { "  - \($0.rawValue)" }.joined(separator: "\n"))
              \(target.frameworks.count > 10 ? "  ... and \(target.frameworks.count - 10) more" : "")

            - **Dependencies:** \(target.dependencies.isEmpty ? "None" : target.dependencies.joined(separator: ", "))
            """
        }.joined(separator: "\n\n"))

        ## Build Configurations

        1. **Debug** - Development with full debugging
        2. **Release** - App Store distribution
        3. **Enterprise** - Enterprise distribution
        4. **TestFlight** - Beta testing

        ## Code Signing Setup

        1. Set Development Team: `\(codeSigningConfig.developmentTeam)`
        2. Configure provisioning profiles for each target
        3. Enable automatic signing for Debug (recommended)
        4. Use manual signing for Release/Enterprise

        ## Required Capabilities

        The following capabilities must be enabled in Apple Developer Portal:

        \(Set(targets.flatMap { $0.capabilities }).sorted(by: { $0.rawValue < $1.rawValue }).map { "- \($0.description)" }.joined(separator: "\n"))

        ## App Groups Configuration

        Create the following App Group in Apple Developer Portal:
        - `group.com.echoelmusic.shared`

        Assign to all targets that use shared data.

        ## iCloud Configuration

        Enable CloudKit with containers:
        - `iCloud.com.echoelmusic.app` (iOS)
        - `iCloud.com.echoelmusic.mac` (macOS)

        ## Deployment Checklist

        ### Pre-Submission
        - [ ] All capabilities enabled in Developer Portal
        - [ ] Provisioning profiles generated and downloaded
        - [ ] Code signing configured for all targets
        - [ ] App Groups and iCloud containers created
        - [ ] Privacy usage descriptions reviewed
        - [ ] Build number incremented
        - [ ] Release notes prepared

        ### iOS App Store
        - [ ] Screenshots for all device sizes
        - [ ] App preview videos (optional)
        - [ ] App Store description and keywords
        - [ ] Age rating questionnaire completed
        - [ ] Export compliance information
        - [ ] Review contact information

        ### macOS App Store
        - [ ] macOS screenshots (1280x800 minimum)
        - [ ] Hardened Runtime enabled
        - [ ] App Sandbox configured
        - [ ] Notarization completed

        ### watchOS App Store
        - [ ] Watch screenshots (All sizes)
        - [ ] Companion app linked

        ### tvOS App Store
        - [ ] tvOS screenshots (1920x1080)
        - [ ] Top Shelf image

        ### visionOS App Store
        - [ ] visionOS screenshots
        - [ ] Immersive space previews
        - [ ] Spatial computing features highlighted

        ## Build Instructions

        ### From Xcode
        1. Open `Echoelmusic.xcodeproj`
        2. Select target and device
        3. Product → Archive
        4. Distribute App → App Store Connect

        ### From Command Line
        ```bash
        # Build for iOS
        xcodebuild -project Echoelmusic.xcodeproj \\
                   -scheme "Echoelmusic Release" \\
                   -configuration Release \\
                   -archivePath build/Echoelmusic.xcarchive \\
                   archive

        # Export for App Store
        xcodebuild -exportArchive \\
                   -archivePath build/Echoelmusic.xcarchive \\
                   -exportPath build/Export \\
                   -exportOptionsPlist ExportOptions.plist
        ```

        ## Continuous Integration

        GitHub Actions workflow: `.github/workflows/phase8000-ci.yml`

        Automated:
        - Build verification
        - Unit tests
        - Code quality checks
        - Security scanning
        - TestFlight upload (on release)

        ## Support

        For questions about Xcode project configuration:
        1. Check XCODE_HANDOFF.md
        2. Review RELEASE_READINESS.md
        3. Consult CLAUDE.md for architecture

        ---

        Generated: \(Date())
        Version: 10000.0.0 (Phase 10000 ULTIMATE RALPH WIGGUM LOOP MODE)
        """
    }
}

// MARK: - Utility Methods

extension XcodeProjectConfiguration {
    /// Validate project configuration
    public func validate() -> [String] {
        var warnings: [String] = []

        // Check for duplicate bundle identifiers
        let bundleIDs = targets.map { $0.bundleIdentifier }
        let duplicates = Dictionary(grouping: bundleIDs, by: { $0 })
            .filter { $1.count > 1 }
            .keys
        if !duplicates.isEmpty {
            warnings.append("Duplicate bundle identifiers: \(duplicates.joined(separator: ", "))")
        }

        // Check team ID placeholder
        if codeSigningConfig.developmentTeam == "YOUR_TEAM_ID" {
            warnings.append("Development team ID not set - replace 'YOUR_TEAM_ID' with actual Team ID")
        }

        // Check deployment targets
        for target in targets {
            if target.platform == .iOS && target.deploymentTarget < "15.0" {
                warnings.append("\(target.name): iOS deployment target should be 15.0+")
            }
        }

        return warnings
    }

    /// Export configuration as JSON
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let exportData: [String: Any] = [
            "projectName": projectName,
            "organizationName": organizationName,
            "bundleIdentifierBase": bundleIdentifierBase,
            "targetCount": targets.count,
            "schemeCount": schemes.count,
            "swiftVersion": buildSettings.swiftVersion
        ]

        return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
}

// MARK: - Framework CaseIterable Conformance

extension Framework: CaseIterable {
    public static var allCases: [Framework] {
        return [
            .avFoundation, .coreAudio, .audioToolbox, .audioUnit, .coreAudioKit, .accelerate,
            .metal, .metalKit, .metalPerformanceShaders,
            .healthKit, .homeKit, .watchKit, .watchConnectivity,
            .coreBluetooth, .externalAccessory, .network, .networkExtension,
            .coreMotion,
            .coreML, .vision, .naturalLanguage, .speech,
            .arKit, .realityKit, .realityKitContent, .compositorServices, .spatial,
            .sceneKit, .spriteKit, .gameplayKit,
            .groupActivities, .activityKit, .widgetKit, .appIntents,
            .userNotifications,
            .combine,
            .swiftUI, .uiKit, .appKit, .tvUIKit,
            .storeKit, .passKit,
            .authenticationServices, .localAuthentication, .security, .cryptoKit,
            .ioKit
        ]
    }
}
