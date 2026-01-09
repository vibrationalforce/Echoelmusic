//
//  PrivacyPolicy.swift
//  Echoelmusic
//
//  Comprehensive legal documentation for App Store & Play Store compliance
//  Covers: GDPR, CCPA, COPPA, HIPAA considerations, biometric data regulations
//
//  Created: 2026-01-07
//

import Foundation
import SwiftUI

// MARK: - Privacy Policy

/// Comprehensive Privacy Policy - GDPR, CCPA, COPPA compliant
public struct PrivacyPolicy {

    // MARK: - Metadata

    public static let version = "1.0.0"
    public static let effectiveDate = "January 7, 2026"
    public static let lastUpdated = "January 7, 2026"
    public static let companyName = "Echoelmusic Inc."
    public static let contactEmail = "michaelterbuyken@gmail.com"
    public static let dpoEmail = "michaelterbuyken@gmail.com" // Data Protection Officer
    public static let websiteURL = "https://echoelmusic.com"

    // MARK: - Full Privacy Policy Text

    public static let fullText = """
    PRIVACY POLICY

    Effective Date: \(effectiveDate)
    Last Updated: \(lastUpdated)
    Version: \(version)


    1. INTRODUCTION

    Welcome to Echoelmusic ("we," "our," "us"). This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our bio-reactive audio-visual platform application (the "App"), available on iOS, macOS, watchOS, tvOS, visionOS, Android, Windows, and Linux platforms.

    By using the App, you agree to the collection and use of information in accordance with this Privacy Policy. If you do not agree with the terms of this Privacy Policy, please do not access or use the App.

    We are committed to protecting your privacy and complying with applicable data protection laws, including:
    • General Data Protection Regulation (GDPR) - European Union
    • California Consumer Privacy Act (CCPA) - California, USA
    • Children's Online Privacy Protection Act (COPPA) - United States
    • Personal Information Protection and Electronic Documents Act (PIPEDA) - Canada
    • Australian Privacy Principles (APP) - Australia


    2. INFORMATION WE COLLECT

    2.1. BIOMETRIC AND HEALTH DATA

    The App processes biometric and health-related data to create bio-reactive audio-visual experiences. This includes:

    • Heart Rate Data: Real-time heart rate measurements from Apple Watch, HealthKit, Android Health Connect, or compatible wearables
    • Heart Rate Variability (HRV): Time intervals between heartbeats, used to calculate coherence scores
    • Breathing Rate: Respiratory rate derived from HRV analysis or direct sensor input
    • Blood Oxygen Saturation (SpO2): Oxygen saturation levels from compatible devices
    • Galvanic Skin Response (GSR): Skin conductance data from compatible sensors
    • Body Temperature: Core body temperature from wearable sensors
    • EEG Data: Brainwave data from compatible EEG headsets (if connected)
    • Facial Expression Data: Facial landmarks and expression analysis for audio-visual mapping (processed on-device only)
    • Voice Data: Audio input for voice-to-visual mapping (processed on-device, not stored)
    • Gesture Data: Hand gesture tracking from device cameras or sensors (visionOS, AR devices)
    • Eye Gaze Data: Eye tracking data from visionOS and compatible devices (processed on-device only)

    IMPORTANT: All biometric data is processed ON-DEVICE using Apple HealthKit, Android Health Connect, and local processing. Raw biometric data is NEVER transmitted to our servers or third parties unless you explicitly opt-in to cloud sync features.

    2.2. USAGE DATA

    We automatically collect certain information when you use the App:

    • Device Information: Device type, operating system, version, unique device identifiers
    • App Usage: Features used, session duration, frequency of use, preset selections
    • Performance Metrics: App crashes, error logs, response times, memory usage
    • Audio Settings: Selected audio engines, effects parameters, spatial audio configurations
    • Visual Settings: Visualization modes, color schemes, accessibility preferences
    • Network Data: IP address (anonymized), connection type, server region selection

    2.3. USER-PROVIDED DATA

    Information you voluntarily provide:

    • Account Information: Email address, username, profile picture (optional)
    • Subscription Data: Payment information (processed by Apple/Google, not stored by us)
    • Wellness Journal Entries: Text notes, mood tracking (stored locally, optionally synced)
    • Session Names: Custom names for saved sessions
    • Preset Configurations: Custom audio-visual preset settings
    • Support Communications: Messages sent to customer support

    2.4. LOCATION DATA

    We may collect approximate location data (city/country level) to:
    • Select optimal server regions for collaboration features
    • Provide localized content and language preferences
    • Comply with regional data protection laws

    Precise location data is NEVER collected. You can disable location access in device settings.

    2.5. CHILDREN'S DATA (COPPA COMPLIANCE)

    The App is NOT intended for children under 13 years of age (or under 16 in the EU). We do not knowingly collect personal information from children. If we discover that a child under 13 has provided us with personal information, we will delete such information immediately.

    If you are a parent or guardian and believe your child has provided us with personal information, please contact us at \(contactEmail).


    3. HOW WE USE YOUR INFORMATION

    3.1. PRIMARY PURPOSES

    We use collected information to:

    • Provide Core Functionality: Process biometric data to generate bio-reactive audio and visuals
    • Enhance User Experience: Remember preferences, settings, and custom presets
    • Improve the App: Analyze usage patterns to optimize performance and add features
    • Provide Customer Support: Respond to inquiries and troubleshoot issues
    • Ensure Security: Detect and prevent fraud, abuse, and security breaches
    • Legal Compliance: Comply with applicable laws and regulations

    3.2. RESEARCH AND DEVELOPMENT (OPT-IN ONLY)

    With your explicit consent, we may use anonymized, aggregated biometric data for:

    • Scientific research on bio-reactive music therapy
    • Improving coherence detection algorithms
    • Developing new audio-visual mapping techniques

    All research data is:
    • Fully anonymized (no personal identifiers)
    • Aggregated across thousands of users
    • Subject to ethical review board approval
    • Opt-in only (you control participation)

    3.3. MARKETING AND COMMUNICATIONS (OPT-IN ONLY)

    With your consent, we may send:

    • Product updates and new features
    • Tips for using the App effectively
    • Special offers and promotions

    You can opt-out at any time via app settings or email unsubscribe links.


    4. DATA STORAGE AND SECURITY

    4.1. ON-DEVICE PROCESSING

    The App is designed with PRIVACY BY DEFAULT:

    • Biometric Processing: All biometric data processing occurs on your device using Core ML, Metal Performance Shaders, and local algorithms
    • No Cloud Upload: Raw biometric data (heart rate, HRV, breathing) is NEVER uploaded to cloud servers
    • Local Storage: Health data is stored in Apple HealthKit, Android Health Connect, or encrypted local databases
    • End-to-End Encryption: Optional cloud sync uses AES-256 encryption with your device-generated keys

    4.2. SECURITY MEASURES

    We implement enterprise-grade security:

    • Encryption at Rest: AES-256 encryption for stored data
    • Encryption in Transit: TLS 1.3 for all network communications
    • Certificate Pinning: Prevents man-in-the-middle attacks
    • Biometric Authentication: Face ID, Touch ID, Optic ID for sensitive features
    • Jailbreak/Root Detection: Enhanced security on compromised devices
    • Secure Keychain Storage: Credentials stored in iOS Keychain, Android Keystore
    • Regular Security Audits: Annual third-party penetration testing
    • Bug Bounty Program: Responsible disclosure program for security researchers

    4.3. DATA RETENTION

    • Biometric Data: Stored locally on your device, deleted when you uninstall the App
    • Usage Analytics: Retained for 90 days, then anonymized and aggregated
    • Account Data: Retained until you delete your account
    • Support Communications: Retained for 3 years for legal compliance
    • Backup Data: If cloud sync enabled, retained for 30 days after account deletion


    5. DATA SHARING AND DISCLOSURE

    5.1. WE DO NOT SELL YOUR DATA

    We NEVER sell, rent, or trade your personal information to third parties for marketing purposes.

    5.2. SERVICE PROVIDERS

    We may share data with trusted service providers who assist us:

    • Cloud Infrastructure: AWS, Google Cloud (for optional cloud sync only)
      - Data Processing Agreement (DPA) in place
      - GDPR-compliant Standard Contractual Clauses
      - Data residency controls (EU data stays in EU)

    • Analytics: Apple Analytics, Google Analytics for Firebase
      - Anonymized usage data only
      - No biometric data shared
      - Opt-out available in settings

    • Crash Reporting: Crashlytics, Sentry
      - Crash logs and error reports
      - No health data included in reports
      - Device identifiers hashed

    • Payment Processing: Apple App Store, Google Play Store
      - We never receive your payment card details
      - Subscriptions managed by platform providers

    All service providers are contractually bound to protect your data and use it only for specified purposes.

    5.3. LEGAL REQUIREMENTS

    We may disclose your information if required by law:

    • Court orders, subpoenas, or legal processes
    • Enforcement of our Terms of Service
    • Protection of our rights, property, or safety
    • Prevention of fraud or security threats
    • Compliance with regulatory investigations

    We will notify you of such disclosures unless prohibited by law.

    5.4. BUSINESS TRANSFERS

    If Echoelmusic is involved in a merger, acquisition, or sale of assets, your information may be transferred. We will provide notice before your information becomes subject to a different privacy policy.


    6. YOUR RIGHTS AND CHOICES

    6.1. GDPR RIGHTS (EU/EEA USERS)

    Under the General Data Protection Regulation, you have the right to:

    • Right to Access: Request a copy of your personal data
    • Right to Rectification: Correct inaccurate or incomplete data
    • Right to Erasure: Request deletion of your data ("right to be forgotten")
    • Right to Restriction: Limit how we process your data
    • Right to Data Portability: Receive your data in a machine-readable format
    • Right to Object: Object to processing based on legitimate interests
    • Right to Withdraw Consent: Withdraw consent for data processing at any time
    • Right to Lodge a Complaint: File a complaint with your data protection authority

    Legal Basis for Processing:
    • Performance of Contract: To provide the App's core functionality
    • Legitimate Interests: To improve the App and ensure security
    • Consent: For optional features like cloud sync and analytics

    Data Controller: Echoelmusic Inc.
    Data Protection Officer: \(dpoEmail)
    EU Representative: [EU Representative Company Name and Address]

    6.2. CCPA RIGHTS (CALIFORNIA RESIDENTS)

    Under the California Consumer Privacy Act, you have the right to:

    • Right to Know: Request disclosure of personal information collected
    • Right to Delete: Request deletion of personal information
    • Right to Opt-Out: Opt-out of the "sale" of personal information (we don't sell data)
    • Right to Non-Discrimination: Equal service regardless of privacy choices

    Categories of Personal Information Collected:
    • Identifiers: Email, device ID (hashed)
    • Biometric Information: Heart rate, HRV, breathing (on-device only)
    • Internet Activity: App usage, analytics
    • Geolocation: Approximate location (city/country)

    We do NOT sell personal information as defined by CCPA.

    6.3. HOW TO EXERCISE YOUR RIGHTS

    To exercise any of these rights:

    1. In-App: Settings > Privacy > Data Rights
    2. Email: \(contactEmail)
    3. Web Form: \(websiteURL)/privacy/data-request

    We will respond to verified requests within:
    • GDPR: 30 days (extendable to 60 days for complex requests)
    • CCPA: 45 days (extendable to 90 days)

    Identity Verification: To protect your privacy, we may request verification of your identity before fulfilling requests.

    6.4. COOKIE AND TRACKING PREFERENCES

    The App uses minimal tracking technologies:

    • Essential: Required for app functionality (cannot be disabled)
    • Analytics: Usage statistics (can be disabled in settings)
    • Preferences: Remember your settings (can be cleared)

    Control Options:
    • iOS: Settings > Privacy & Security > Tracking
    • Android: Settings > Privacy > Ads
    • In-App: Settings > Privacy > Analytics


    7. INTERNATIONAL DATA TRANSFERS

    7.1. DATA RESIDENCY

    Your data is stored in the region closest to you:

    • EU/EEA: Data stored in EU data centers (Frankfurt, Dublin)
    • USA: Data stored in US data centers (Oregon, Virginia)
    • Asia-Pacific: Data stored in APAC data centers (Singapore, Tokyo)

    7.2. TRANSFER SAFEGUARDS

    For international data transfers, we use:

    • Standard Contractual Clauses (SCCs): EU Commission-approved clauses
    • Adequacy Decisions: Transfers to countries with adequate protection
    • Privacy Shield: For transfers to certified US organizations
    • Binding Corporate Rules: Internal data protection policies

    7.3. CROSS-BORDER COLLABORATION

    When using worldwide collaboration features, your session data (NOT raw biometric data) may be transmitted internationally. This includes:

    • Session name and parameters
    • Audio/visual settings
    • Chat messages (if enabled)

    All transmissions use end-to-end encryption.


    8. THIRD-PARTY SERVICES

    8.1. HARDWARE INTEGRATIONS

    The App integrates with third-party hardware:

    • Apple HealthKit: Subject to Apple's Health Privacy Policy
    • Android Health Connect: Subject to Google's Privacy Policy
    • Wearable Devices: Garmin, Whoop, Oura, Polar, Fitbit (subject to their policies)
    • Audio Interfaces: Universal Audio, Focusrite, RME, MOTU (local data only)
    • MIDI Controllers: Ableton, Native Instruments, Akai (local data only)
    • VR/AR Devices: Apple Vision Pro, Meta Quest (subject to their policies)

    We are not responsible for third-party privacy practices. Please review their policies.

    8.2. EXTERNAL LINKS

    The App may contain links to external websites or services. We are not responsible for their privacy practices.


    9. SPECIFIC FEATURES AND PRIVACY

    9.1. LAMBDA MODE (λ∞) - UNIFIED CONSCIOUSNESS INTERFACE

    Lambda Mode processes comprehensive biometric data for transcendence state detection:

    • Data Processed: HR, HRV, breathing, GSR, SpO2, EEG bands (if available)
    • Processing Location: 100% on-device using Core ML
    • Lambda Score: Calculated locally, never transmitted
    • Session Analytics: Stored locally, optionally synced with encryption

    9.2. QUANTUM LOOP LIGHT SCIENCE ENGINE

    Quantum visualization features:

    • Photon Simulation: All calculations performed on-device GPU (Metal, OpenGL, Vulkan)
    • Wave Functions: Mathematical models, no personal data involved
    • No Quantum Computing: Despite the name, we use classical computing only

    9.3. REAL-TIME HEALTHKIT STREAMING

    When using real-time HealthKit streaming:

    • Authorization: Requires explicit HealthKit permission
    • Data Access: Read-only access to heart rate, HRV, respiratory rate
    • Data Writing: Optional write-back of mindfulness sessions
    • Revocation: Permissions can be revoked in Settings > Health > Data Access & Devices

    9.4. EYE GAZE TRACKING (visionOS)

    Eye tracking features on Apple Vision Pro:

    • Processing: 100% on-device using ARKit
    • Data Storage: NOT stored, processed in real-time only
    • Privacy: Apple's on-device eye tracking, no data leaves device
    • Use Case: Audio panning, filter control, visual focus

    9.5. WORLDWIDE COLLABORATION HUB

    Multi-user collaboration features:

    • Shared Data: Session settings, audio parameters, chat messages
    • NOT Shared: Raw biometric data, personal health information
    • Participant Visibility: Username and approximate coherence level only
    • Encryption: End-to-end encryption for all session data

    9.6. AI SCENE DIRECTOR & LIVE PRODUCTION

    AI-powered features:

    • Processing: All AI models run on-device (Core ML, TensorFlow Lite)
    • Training Data: Models pre-trained, no user data used for training
    • Camera Switching: Based on audio/biometric analysis, not facial recognition
    • No Cloud AI: No data sent to cloud AI services (OpenAI, Google AI, etc.)


    10. ACCESSIBILITY AND INCLUSIVE DESIGN

    Privacy considerations for accessibility features:

    • VoiceOver/TalkBack: Screen reader support, no data collected
    • Voice Control: On-device speech recognition, no cloud processing
    • Switch Control: External switch input, no data collected
    • Eye Tracking: On-device ARKit, no data stored
    • Haptic Feedback: Generated locally, no data collected

    Accessibility does not compromise privacy.


    11. CHILDREN'S PRIVACY (COPPA/GDPR-K)

    11.1. AGE RESTRICTIONS

    • Minimum Age: 13 years (16 in EU/EEA)
    • Age Verification: Self-declared date of birth during account creation
    • Parental Consent: Required for users under 18 for certain features

    11.2. DATA MINIMIZATION FOR MINORS

    If a user is identified as a minor (13-17 in US, 16-17 in EU):

    • Restricted Features: Collaboration features disabled by default
    • No Marketing: Marketing communications disabled
    • Enhanced Privacy: Stricter default privacy settings
    • Parental Controls: Parent/guardian can manage account via Family Sharing

    11.3. DISCOVERY OF UNDERAGE USERS

    If we discover a user is under 13 (or 16 in EU):

    • Immediate Account Suspension
    • Deletion of All Collected Data within 30 days
    • Notification to registered email (if available)
    • No further data collection or processing


    12. DATA BREACH NOTIFICATION

    In the event of a data breach affecting personal information:

    12.1. NOTIFICATION TIMELINE

    • GDPR: Within 72 hours to data protection authority
    • CCPA: Without unreasonable delay
    • Users: As soon as reasonably possible after discovery

    12.2. NOTIFICATION CONTENT

    We will inform you of:
    • Nature of the breach (what data was affected)
    • Likely consequences
    • Measures taken to mitigate harm
    • Recommended actions you should take
    • Contact information for further inquiries

    12.3. SECURITY MEASURES

    To prevent breaches, we employ:
    • 24/7 security monitoring
    • Intrusion detection systems
    • Regular security audits and penetration testing
    • Employee security training
    • Incident response plan


    13. AUTOMATED DECISION-MAKING AND PROFILING

    13.1. AI-POWERED FEATURES

    The App uses automated decision-making for:

    • Coherence Score Calculation: HRV-based coherence scoring
    • Transcendence State Detection: Lambda Mode state classification
    • Audio-Visual Mapping: Real-time parameter modulation
    • Scene Direction: AI camera switching for live production

    13.2. GDPR ARTICLE 22 COMPLIANCE

    • No Legal/Significant Effects: Automated decisions do not have legal or similarly significant effects on you
    • User Control: You can manually override all automated settings
    • Human Review: Available upon request for any automated decision
    • Right to Explanation: Request explanation of how algorithms work

    13.3. TRANSPARENCY

    All AI models and algorithms are:
    • Documented in technical specifications
    • Explainable upon request
    • Subject to bias testing and fairness audits


    14. BIOMETRIC DATA REGULATIONS

    14.1. ILLINOIS BIOMETRIC INFORMATION PRIVACY ACT (BIPA)

    For Illinois residents:

    • Written Policy: This Privacy Policy serves as our written biometric data retention policy
    • Informed Consent: Required before first biometric data collection
    • Purpose Disclosure: Biometric data used for audio-visual generation only
    • Retention Schedule: Deleted when you uninstall app or delete account
    • No Sale: Biometric data NEVER sold or disclosed for profit
    • Destruction: Permanent deletion within 30 days of request

    14.2. TEXAS BIOMETRIC PRIVACY LAW

    For Texas residents:

    • Consent Required: Notice and consent before biometric data collection
    • Purpose Limitation: Used only for disclosed purposes
    • Retention Period: No longer than reasonably necessary
    • No Sale: Biometric data not sold without additional consent

    14.3. CALIFORNIA BIOMETRIC PRIVACY (AB 1008)

    For California residents:

    • No Facial Recognition Database: Facial landmark data not stored in database
    • Real-Time Processing: Face data processed in real-time, immediately discarded
    • Opt-In: Facial expression features require explicit opt-in

    14.4. GDPR SPECIAL CATEGORY DATA

    Under GDPR, biometric and health data are "special category" data:

    • Legal Basis: Explicit consent (GDPR Article 9(2)(a))
    • Withdrawal: Consent can be withdrawn at any time
    • Extra Safeguards: Enhanced security and encryption


    15. CHANGES TO THIS PRIVACY POLICY

    15.1. NOTIFICATION OF CHANGES

    We may update this Privacy Policy from time to time. We will notify you of material changes by:

    • In-App Notification: Pop-up alert upon app launch
    • Email Notification: To your registered email address
    • Website Posting: Updated policy at \(websiteURL)/privacy
    • Version History: Previous versions available for review

    15.2. EFFECTIVE DATE OF CHANGES

    • Material Changes: 30 days' notice before effective date
    • Non-Material Changes: Effective immediately upon posting
    • Continued Use: Constitutes acceptance of updated policy

    15.3. VERSION CONTROL

    • Current Version: \(version)
    • Previous Versions: Available at \(websiteURL)/privacy/archive


    16. CONTACT INFORMATION

    16.1. GENERAL PRIVACY INQUIRIES

    Email: \(contactEmail)
    Website: \(websiteURL)/privacy

    16.2. DATA PROTECTION OFFICER (GDPR)

    Email: \(dpoEmail)
    Address: [DPO Mailing Address]

    16.3. CALIFORNIA PRIVACY REQUESTS (CCPA)

    Email: \(contactEmail)
    Toll-Free: 1-800-XXX-XXXX (US residents)
    Web Form: \(websiteURL)/ccpa-request

    16.4. EU REPRESENTATIVE (GDPR Article 27)

    Company: [EU Representative Company Name]
    Address: [EU Representative Mailing Address]
    Email: [EU Representative Email]

    16.5. MAILING ADDRESS

    Echoelmusic Inc.
    Attn: Privacy Department
    [Company Mailing Address]
    [City, State, ZIP]
    United States


    17. REGULATORY COMPLIANCE

    This Privacy Policy complies with:

    • GDPR (EU Regulation 2016/679)
    • CCPA (California Civil Code §§ 1798.100–1798.199)
    • COPPA (15 U.S.C. §§ 6501–6506)
    • PIPEDA (Canada)
    • APP (Australia)
    • BIPA (Illinois 740 ILCS 14/)
    • HIPAA (45 CFR Parts 160, 162, 164) - for health data handling best practices
    • ePrivacy Directive (EU 2002/58/EC)
    • UK GDPR and Data Protection Act 2018


    18. GLOSSARY

    • Biometric Data: Biological measurements used for identification (heart rate, HRV, etc.)
    • Coherence: Mathematical measure of heart rate variability regularity
    • On-Device Processing: Data processing that occurs on your device, not in the cloud
    • End-to-End Encryption: Encryption where only sender and recipient can decrypt
    • Anonymization: Removal of all identifying information from data
    • Aggregation: Combining data from multiple users to show trends
    • Data Controller: Entity determining purposes and means of data processing
    • Data Processor: Entity processing data on behalf of the controller
    • Personal Data: Information relating to an identified or identifiable person


    ---

    ACKNOWLEDGMENT

    By using the Echoelmusic App, you acknowledge that you have read, understood, and agree to this Privacy Policy.

    For questions or concerns about this Privacy Policy, please contact us at \(contactEmail).

    Last Updated: \(lastUpdated)
    Version: \(version)

    © 2026 Echoelmusic Inc. All rights reserved.
    """

    // MARK: - Summaries

    /// Short privacy summary for display in UI
    public static let shortSummary = """
    YOUR PRIVACY IS OUR PRIORITY

    • ALL biometric data processed ON-DEVICE only
    • We NEVER sell your data
    • You control what's shared
    • GDPR, CCPA, COPPA compliant
    • Enterprise-grade AES-256 encryption

    Raw biometric data (heart rate, HRV, breathing) NEVER leaves your device unless you explicitly enable cloud sync.
    """

    /// Key points for quick reference
    public static let keyPoints: [String] = [
        "100% on-device biometric processing",
        "No data selling or trading",
        "Optional cloud sync with encryption",
        "You can delete your data anytime",
        "GDPR, CCPA, COPPA compliant",
        "Enterprise security (AES-256)",
        "Children under 13 not permitted",
        "Full data portability rights"
    ]
}

// MARK: - Terms of Service

/// Comprehensive Terms of Service
public struct TermsOfService {

    public static let version = "1.0.0"
    public static let effectiveDate = "January 7, 2026"
    public static let lastUpdated = "January 7, 2026"

    public static let fullText = """
    TERMS OF SERVICE

    Effective Date: \(effectiveDate)
    Last Updated: \(lastUpdated)
    Version: \(version)


    1. ACCEPTANCE OF TERMS

    These Terms of Service ("Terms") constitute a legally binding agreement between you ("User," "you," "your") and Echoelmusic Inc. ("Company," "we," "our," "us") governing your use of the Echoelmusic application (the "App").

    By downloading, installing, or using the App, you agree to be bound by these Terms. If you do not agree to these Terms, do not use the App.


    2. ELIGIBILITY

    2.1. AGE REQUIREMENTS

    • Minimum Age: You must be at least 13 years old (16 in the EU/EEA) to use the App
    • Parental Consent: Users under 18 require parental or guardian consent
    • Age Verification: You represent and warrant that you meet age requirements

    2.2. CAPACITY

    You represent that you have the legal capacity to enter into these Terms and are not prohibited from using the App under applicable law.


    3. LICENSE GRANT

    3.1. LIMITED LICENSE

    Subject to your compliance with these Terms, we grant you a limited, non-exclusive, non-transferable, revocable license to:

    • Download and install the App on your personal devices
    • Use the App for personal, non-commercial purposes
    • Access features included in your subscription tier

    3.2. LICENSE RESTRICTIONS

    You may NOT:

    • Modify, reverse engineer, decompile, or disassemble the App
    • Remove copyright, trademark, or other proprietary notices
    • Use the App for commercial purposes without written permission
    • Rent, lease, lend, sell, or sublicense the App
    • Use the App to violate any laws or regulations
    • Create derivative works based on the App
    • Access the App using automated means (bots, scrapers)
    • Attempt to gain unauthorized access to any systems or networks
    • Interfere with or disrupt the App or servers
    • Upload malicious code, viruses, or harmful content


    4. USER ACCOUNTS

    4.1. ACCOUNT CREATION

    • Accurate Information: You agree to provide accurate, current information
    • Account Security: You are responsible for maintaining account confidentiality
    • Unauthorized Access: Notify us immediately of any unauthorized use
    • One Account: You may maintain only one account per person

    4.2. ACCOUNT TERMINATION

    We may suspend or terminate your account if you:
    • Violate these Terms
    • Provide false information
    • Engage in fraudulent activity
    • Abuse or harass other users
    • Use the App for illegal purposes


    5. SUBSCRIPTION AND PAYMENT

    5.1. SUBSCRIPTION TIERS

    The App offers multiple subscription tiers:

    • Free Tier: Basic features with limitations
    • Premium Monthly: Full features, billed monthly
    • Premium Annual: Full features, billed annually at discounted rate
    • Family Plan: Up to 6 family members (Apple Family Sharing, Google Family Library)
    • Educational: Discounted rate for verified students and educators
    • Enterprise: Custom pricing for organizations

    5.2. PAYMENT TERMS

    • Platform Billing: Subscriptions processed through Apple App Store or Google Play Store
    • Automatic Renewal: Subscriptions automatically renew unless cancelled
    • Price Changes: We may change prices with 30 days' notice
    • Taxes: Prices exclude applicable taxes (added at checkout)
    • Currency: Charges in your local currency based on platform settings

    5.3. FREE TRIALS

    • Trial Period: New users may receive free trial (typically 7-30 days)
    • Automatic Conversion: Trial converts to paid subscription unless cancelled
    • One Trial Per User: Only one free trial per user account
    • Cancellation: Cancel anytime during trial to avoid charges

    5.4. CANCELLATION AND REFUNDS

    • Cancel Anytime: Cancel subscription through Apple/Google settings
    • No Partial Refunds: No refunds for partial subscription periods
    • Platform Policy: Refunds subject to Apple/Google refund policies
    • Access Continues: Access continues until end of paid period after cancellation

    5.5. IN-APP PURCHASES

    • Additional Content: Some features, presets, or plugins available for purchase
    • Non-Transferable: Purchases tied to your account, non-transferable
    • Consumable vs. Non-Consumable: Some purchases are one-time, others consumable


    6. USER CONTENT

    6.1. YOUR CONTENT

    You retain ownership of content you create using the App:

    • Audio Recordings: Music, sessions, compositions
    • Visual Exports: Screenshots, videos, renderings
    • Presets: Custom audio-visual configurations
    • Journal Entries: Wellness notes and reflections

    6.2. LICENSE TO US

    By creating and storing content in the App, you grant us a limited license to:

    • Store and process content to provide App functionality
    • Backup content if cloud sync enabled
    • Display content in your account interface

    This license is:
    • Non-exclusive: You can use your content elsewhere
    • Worldwide: For cloud infrastructure purposes
    • Royalty-free: No payment required
    • Terminates: When you delete content or your account

    6.3. PUBLIC SHARING

    If you choose to share content publicly (e.g., collaboration sessions, social features):

    • Public License: You grant us a license to display, distribute, and promote shared content
    • Attribution: We will credit you when displaying your content
    • Removal: You can remove public content at any time
    • Moderation: We may remove content that violates our guidelines

    6.4. CONTENT RESTRICTIONS

    You may NOT create or share content that:

    • Violates laws or regulations
    • Infringes third-party intellectual property rights
    • Contains hate speech, harassment, or discrimination
    • Depicts violence, illegal activity, or harm
    • Contains sexually explicit material
    • Spreads misinformation or fraud
    • Violates others' privacy


    7. INTELLECTUAL PROPERTY

    7.1. OUR OWNERSHIP

    The App and all related materials are owned by Echoelmusic Inc. and protected by:

    • Copyright: All code, design, graphics, text
    • Trademarks: "Echoelmusic" and logos are our trademarks
    • Patents: Pending patents on bio-reactive audio technology
    • Trade Secrets: Proprietary algorithms and processes

    7.2. THIRD-PARTY CONTENT

    The App includes licensed third-party content:

    • Audio Samples: Licensed from sample libraries
    • Visual Assets: Licensed images and graphics
    • Software Libraries: Open-source and commercial libraries (see Acknowledgments)

    7.3. DMCA COMPLIANCE (Digital Millennium Copyright Act)

    If you believe content in the App infringes your copyright:

    • DMCA Agent: \(PrivacyPolicy.contactEmail)
    • Required Information: Identification of copyrighted work, infringing material location, contact information, good faith statement
    • Counter-Notification: If content removed, you may file counter-notification

    7.4. TRADEMARK USAGE

    You may NOT use our trademarks without written permission.


    8. ACCEPTABLE USE POLICY

    8.1. PROHIBITED ACTIVITIES

    You agree NOT to:

    • Violate laws or regulations
    • Infringe intellectual property rights
    • Harass, abuse, or harm others
    • Distribute spam or unsolicited messages
    • Impersonate others or entities
    • Collect user data without consent
    • Use the App for unauthorized commercial purposes
    • Transmit malware or malicious code
    • Overload or disrupt servers
    • Circumvent security measures
    • Create multiple accounts to abuse free trials

    8.2. WORLDWIDE COLLABORATION CONDUCT

    When using collaboration features:

    • Respect Others: Be respectful and inclusive
    • No Harassment: Do not harass, bully, or threaten
    • Age-Appropriate: Keep content suitable for all ages (13+)
    • Privacy: Do not share others' personal information
    • Reporting: Report violations to \(PrivacyPolicy.contactEmail)

    8.3. ENFORCEMENT

    Violations may result in:
    • Warning
    • Temporary suspension
    • Permanent account termination
    • Legal action if necessary


    9. HEALTH AND MEDICAL DISCLAIMERS

    9.1. NOT A MEDICAL DEVICE

    THE APP IS NOT A MEDICAL DEVICE AND IS NOT INTENDED TO:

    • Diagnose, treat, cure, or prevent any disease
    • Provide medical advice or recommendations
    • Replace professional medical care
    • Monitor or measure health conditions for medical purposes

    9.2. WELLNESS PURPOSES ONLY

    The App is designed for:
    • Relaxation and stress reduction
    • Creative expression and art
    • Meditation and mindfulness support
    • Entertainment and educational purposes

    9.3. CONSULT HEALTHCARE PROFESSIONALS

    • Medical Conditions: Consult a doctor before using if you have medical conditions
    • Medications: Inform your doctor if using the App alongside medical treatments
    • Symptoms: Seek medical attention for concerning symptoms
    • Not a Substitute: Do not use the App instead of medical care

    9.4. BIOMETRIC DATA ACCURACY

    • No Guarantee: Biometric readings may not be accurate
    • Informational Only: Use biometric data for creative/informational purposes only
    • Device Limitations: Accuracy depends on connected devices
    • Calibration: Ensure connected devices are properly calibrated

    9.5. SPECIFIC WARNINGS

    • Photosensitive Epilepsy: Visual effects may trigger seizures in susceptible individuals
    • Motion Sickness: VR/AR features may cause discomfort
    • Breathing Exercises: Stop if you feel dizzy, lightheaded, or uncomfortable
    • High-Intensity Audio: Protect your hearing, use reasonable volume levels

    See full Health Disclaimer (Section 10) for complete information.


    10. HEALTH DISCLAIMER (COMPREHENSIVE)

    FOR FULL HEALTH DISCLAIMER, SEE: HealthDisclaimer.fullText

    Key Points:
    • Not FDA-cleared or approved
    • Not intended for medical use
    • Biometric data for creative purposes only
    • Consult healthcare professional for medical concerns
    • Stop use if adverse effects occur


    11. LIMITATION OF LIABILITY

    11.1. DISCLAIMER OF WARRANTIES

    THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO:

    • Merchantability
    • Fitness for a particular purpose
    • Non-infringement
    • Accuracy, reliability, or availability
    • Uninterrupted or error-free operation
    • Security of data transmission
    • Results or outcomes from App use

    11.2. LIMITATION OF LIABILITY

    TO THE MAXIMUM EXTENT PERMITTED BY LAW:

    WE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING BUT NOT LIMITED TO:

    • Loss of profits or revenue
    • Loss of data
    • Loss of goodwill
    • Personal injury (except where prohibited by law)
    • Property damage
    • Emotional distress

    ARISING FROM OR RELATED TO YOUR USE OF THE APP, EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

    11.3. MAXIMUM LIABILITY

    OUR TOTAL LIABILITY TO YOU FOR ALL CLAIMS ARISING FROM YOUR USE OF THE APP SHALL NOT EXCEED THE GREATER OF:

    • The amount you paid to us in the 12 months before the claim arose, OR
    • $100 USD

    11.4. JURISDICTIONAL LIMITATIONS

    Some jurisdictions do not allow limitation of implied warranties or liability for incidental/consequential damages. In such jurisdictions, our liability is limited to the maximum extent permitted by law.


    12. INDEMNIFICATION

    You agree to indemnify, defend, and hold harmless Echoelmusic Inc., its officers, directors, employees, agents, and affiliates from any claims, liabilities, damages, losses, costs, or expenses (including reasonable attorneys' fees) arising from:

    • Your use or misuse of the App
    • Your violation of these Terms
    • Your violation of any laws or regulations
    • Your infringement of third-party rights
    • Content you create, upload, or share
    • Your negligence or willful misconduct


    13. DISPUTE RESOLUTION

    13.1. GOVERNING LAW

    These Terms are governed by the laws of:
    • United States: [State] law (without regard to conflict of law principles)
    • EU Users: Laws of your country of residence (GDPR protections apply)

    13.2. ARBITRATION AGREEMENT (US USERS)

    FOR US USERS (except where prohibited by law):

    • Binding Arbitration: Disputes resolved through binding arbitration, not courts
    • Arbitration Rules: American Arbitration Association (AAA) Consumer Arbitration Rules
    • Location: Arbitration in your county of residence or mutually agreed location
    • Costs: We pay AAA filing fees for claims under $10,000
    • Small Claims: You may pursue claims in small claims court instead of arbitration

    13.3. CLASS ACTION WAIVER (US USERS)

    TO THE EXTENT PERMITTED BY LAW, YOU AGREE:

    • No Class Actions: Disputes resolved on individual basis only
    • No Class Arbitration: No class-wide arbitration permitted
    • No Consolidation: Multiple claims not consolidated without consent

    If class action waiver is unenforceable, arbitration agreement is void.

    13.4. EU USERS - ONLINE DISPUTE RESOLUTION

    EU users may use the European Commission's Online Dispute Resolution platform:
    https://ec.europa.eu/consumers/odr

    13.5. INFORMAL RESOLUTION

    Before filing arbitration or lawsuit, contact us to attempt informal resolution:
    \(PrivacyPolicy.contactEmail)


    14. MODIFICATIONS TO TERMS

    14.1. CHANGES TO TERMS

    We may modify these Terms at any time. Changes effective upon:

    • Posting updated Terms in the App
    • Email notification to registered users (for material changes)
    • 30 days' notice for material changes

    14.2. ACCEPTANCE OF CHANGES

    • Continued Use: Continued use after changes constitutes acceptance
    • Rejection: If you reject changes, you must stop using the App
    • Refund: If you paid for subscription and reject material changes, contact us for pro-rata refund


    15. TERMINATION

    15.1. TERMINATION BY YOU

    You may terminate these Terms by:
    • Deleting your account in app settings
    • Uninstalling the App from all devices
    • Ceasing all use of the App

    15.2. TERMINATION BY US

    We may terminate or suspend your access immediately if:
    • You violate these Terms
    • We are required by law
    • We discontinue the App
    • Your account is inactive for 2+ years
    • You engage in fraudulent activity

    15.3. EFFECT OF TERMINATION

    Upon termination:
    • Your license to use the App ends immediately
    • We may delete your account and data (subject to retention requirements)
    • Provisions that should survive termination remain in effect (e.g., liability limitations, indemnification)


    16. THIRD-PARTY SERVICES AND DEVICES

    16.1. DEVICE COMPATIBILITY

    The App integrates with third-party devices and services:
    • Apple HealthKit, Health app
    • Android Health Connect
    • Wearable devices (Apple Watch, Garmin, etc.)
    • Audio interfaces, MIDI controllers
    • VR/AR headsets

    We are not responsible for third-party device performance or compatibility.

    16.2. THIRD-PARTY TERMS

    Use of third-party services subject to their terms:
    • Apple: https://www.apple.com/legal/internet-services/itunes/
    • Google: https://play.google.com/about/play-terms/


    17. EXPORT CONTROLS

    The App may be subject to export control laws. You agree:

    • Not to export or re-export the App to prohibited countries
    • Not to use the App for prohibited purposes (e.g., missile technology)
    • To comply with all applicable export laws and regulations


    18. ACCESSIBILITY

    We are committed to accessibility for users with disabilities:

    • WCAG 2.2 AAA Compliance: Our goal is Level AAA accessibility
    • Accessibility Features: VoiceOver, TalkBack, Switch Control, Voice Control
    • Feedback: Report accessibility issues to \(PrivacyPolicy.contactEmail)


    19. ENTIRE AGREEMENT

    These Terms, together with our Privacy Policy and Health Disclaimer, constitute the entire agreement between you and Echoelmusic Inc. regarding the App.

    These Terms supersede all prior agreements, understandings, or representations.


    20. SEVERABILITY

    If any provision of these Terms is held invalid or unenforceable, the remaining provisions remain in full force and effect.


    21. WAIVER

    Our failure to enforce any provision of these Terms does not constitute a waiver of that provision or any other provision.


    22. ASSIGNMENT

    You may not assign these Terms without our written consent. We may assign these Terms to any affiliate or successor in interest.


    23. FORCE MAJEURE

    We are not liable for any failure or delay in performance due to causes beyond our reasonable control, including natural disasters, war, terrorism, pandemics, government actions, or infrastructure failures.


    24. CONTACT INFORMATION

    For questions about these Terms:

    Email: \(PrivacyPolicy.contactEmail)
    Website: \(PrivacyPolicy.websiteURL)/terms

    Legal Department
    Echoelmusic Inc.
    [Company Mailing Address]


    25. ACKNOWLEDGMENT

    BY USING THE APP, YOU ACKNOWLEDGE THAT YOU HAVE READ THESE TERMS, UNDERSTAND THEM, AND AGREE TO BE BOUND BY THEM.

    Last Updated: \(lastUpdated)
    Version: \(version)

    © 2026 Echoelmusic Inc. All rights reserved.
    """

    public static let shortSummary = """
    KEY TERMS SUMMARY

    • Personal, non-commercial use only
    • Age 13+ required (16+ in EU)
    • No reverse engineering or misuse
    • Subscriptions auto-renew (cancel anytime)
    • NOT a medical device - wellness only
    • Respect others in collaboration features
    • We may terminate for violations
    • Disputes resolved by arbitration (US)

    Full Terms required for complete understanding.
    """
}

// MARK: - Health Disclaimer

/// Comprehensive Health and Medical Disclaimer
public struct HealthDisclaimer {

    public static let version = "1.0.0"
    public static let effectiveDate = "January 7, 2026"

    public static let fullText = """
    HEALTH AND MEDICAL DISCLAIMER

    Effective Date: \(effectiveDate)
    Version: \(version)

    ⚠️ IMPORTANT: PLEASE READ CAREFULLY BEFORE USING THIS APP ⚠️


    1. NOT A MEDICAL DEVICE

    Echoelmusic IS NOT A MEDICAL DEVICE and has NOT been evaluated, cleared, or approved by:

    • U.S. Food and Drug Administration (FDA)
    • European Medicines Agency (EMA)
    • Medicines and Healthcare products Regulatory Agency (MHRA - UK)
    • Therapeutic Goods Administration (TGA - Australia)
    • Health Canada
    • Any other medical regulatory authority

    The App is NOT intended to:
    • Diagnose any disease, condition, or ailment
    • Treat any disease, condition, or ailment
    • Cure any disease, condition, or ailment
    • Prevent any disease, condition, or ailment
    • Monitor health conditions for medical purposes
    • Replace professional medical advice, diagnosis, or treatment


    2. WELLNESS AND CREATIVE PURPOSES ONLY

    Echoelmusic is designed EXCLUSIVELY for:

    • General wellness and stress reduction
    • Relaxation and mindfulness support
    • Creative expression through bio-reactive art
    • Entertainment and educational purposes
    • Personal exploration of mind-body connections
    • Meditation and breathing practice support (non-medical)


    3. BIOMETRIC DATA DISCLAIMER

    3.1. ACCURACY NOT GUARANTEED

    Biometric data displayed in the App (heart rate, HRV, breathing rate, SpO2, etc.) is:

    • FOR INFORMATIONAL AND CREATIVE PURPOSES ONLY
    • NOT ACCURATE ENOUGH FOR MEDICAL DECISIONS
    • NOT CALIBRATED OR VALIDATED FOR MEDICAL USE
    • DEPENDENT ON THIRD-PARTY DEVICE ACCURACY
    • SUBJECT TO INTERFERENCE AND ERRORS

    Do NOT rely on App biometric data for:
    • Medical diagnosis or treatment decisions
    • Monitoring chronic health conditions
    • Medication dosage decisions
    • Emergency medical situations
    • Any health-related decisions

    3.2. DEVICE LIMITATIONS

    Biometric accuracy depends on:
    • Proper device placement and fit
    • Device calibration and condition
    • Environmental factors (movement, temperature, humidity)
    • Individual physiological variations
    • Signal processing algorithms

    Consumer wearable devices (Apple Watch, fitness trackers) are NOT medical-grade and may have significant measurement errors.

    3.3. HEART RATE VARIABILITY (HRV) DISCLAIMER

    HRV metrics and "coherence" scores are:
    • MATHEMATICAL CALCULATIONS, not medical diagnoses
    • TRENDS AND PATTERNS, not absolute values
    • INFLUENCED by many non-medical factors (stress, caffeine, sleep, exercise)
    • NOT PREDICTIVE of health outcomes
    • FOR EXPLORATORY AND CREATIVE USE ONLY

    Low HRV or coherence does NOT indicate disease. High HRV or coherence does NOT indicate health.


    4. CONSULT HEALTHCARE PROFESSIONALS

    4.1. WHEN TO CONSULT A DOCTOR

    You should consult a qualified healthcare professional:

    • BEFORE using the App if you have any medical conditions, especially:
      - Cardiovascular disease or heart conditions
      - Epilepsy or seizure disorders
      - Respiratory conditions (asthma, COPD)
      - Mental health conditions
      - Pregnancy
      - Pacemaker or implanted medical device
      - Any chronic illness

    • IF you experience any concerning symptoms:
      - Chest pain, shortness of breath, dizziness
      - Irregular heartbeat or palpitations
      - Severe headache or nausea
      - Seizures or convulsions
      - Loss of consciousness
      - Any unusual or worrisome symptoms

    • BEFORE making any health-related decisions based on App use

    4.2. DO NOT DELAY MEDICAL CARE

    NEVER delay or avoid seeking professional medical advice because of something you see or experience in the App.

    If you have a medical emergency, call emergency services immediately (911 in US, 112 in EU, etc.).


    5. NOT A SUBSTITUTE FOR MEDICAL CARE

    The App DOES NOT replace:
    • Visits to your doctor or healthcare provider
    • Prescribed medical treatments or medications
    • Medical monitoring devices (ECG, pulse oximeters, blood pressure monitors)
    • Mental health therapy or counseling
    • Any professional medical care

    Always follow your healthcare provider's advice. Do not modify your medical treatment based on App use without consulting your doctor.


    6. SPECIFIC FEATURE DISCLAIMERS

    6.1. BREATHING EXERCISES

    Breathing exercises in the App are:
    • FOR RELAXATION AND WELLNESS ONLY
    • NOT medical breathing therapy
    • NOT suitable for everyone

    STOP breathing exercises immediately if you:
    • Feel dizzy, lightheaded, or faint
    • Experience chest pain or discomfort
    • Have difficulty breathing
    • Feel anxious or panicked
    • Experience tingling or numbness

    Do NOT use breathing exercises:
    • If you have respiratory conditions (without doctor approval)
    • During pregnancy (without doctor approval)
    • If you have history of panic attacks (without doctor approval)

    6.2. MEDITATION AND MINDFULNESS

    Meditation features are:
    • GENERAL MINDFULNESS PRACTICE, not therapy
    • NOT a substitute for mental health treatment
    • NOT appropriate for all mental health conditions

    Some individuals may find meditation distressing or triggering. Consult a mental health professional before use if you have:
    • History of trauma or PTSD
    • Severe anxiety or depression
    • Psychosis or dissociative disorders
    • Other mental health conditions

    6.3. VISUAL EFFECTS (PHOTOSENSITIVITY WARNING)

    ⚠️ PHOTOSENSITIVE SEIZURE WARNING ⚠️

    Visual effects in the App may trigger seizures in individuals with photosensitive epilepsy.

    STOP using the App immediately if you experience:
    • Seizures or convulsions
    • Loss of awareness or consciousness
    • Eye or muscle twitching
    • Disorientation or confusion
    • Involuntary movements

    If you have epilepsy or history of seizures:
    • Consult your doctor before using the App
    • Use reduced motion settings (Settings > Accessibility)
    • Avoid prolonged use
    • Use in well-lit environment
    • Take frequent breaks

    6.4. VR/AR FEATURES (visionOS, Meta Quest, etc.)

    Virtual and augmented reality features may cause:
    • Motion sickness or nausea
    • Dizziness or disorientation
    • Eye strain or headaches
    • Balance problems

    If you experience discomfort:
    • Remove VR/AR headset immediately
    • Rest until symptoms subside
    • Discontinue use if symptoms persist

    Do NOT use VR/AR features:
    • While operating vehicles or machinery
    • While walking or moving
    • If you have history of motion sickness (without caution)
    • If pregnant (without doctor approval)

    6.5. AUDIO (HEARING SAFETY)

    PROTECT YOUR HEARING:

    • Use reasonable volume levels
    • Take breaks from headphone use
    • Do not use at maximum volume for extended periods
    • Stop use if you experience ear pain or hearing changes

    Multidimensional Brainwave Entrainment and spatial audio:
    • ARE NOT medical treatments
    • DO NOT cure or treat any condition
    • MAY cause discomfort in some individuals

    6.6. LAMBDA MODE (λ∞) - TRANSCENDENCE STATES

    "Transcendence states" and "Lambda score" are:
    • ARTISTIC AND CREATIVE CONCEPTS, not medical states
    • MATHEMATICAL ALGORITHMS, not diagnoses
    • FOR CREATIVE EXPLORATION, not health monitoring

    Do NOT interpret Lambda Mode data as:
    • Medical assessment of consciousness or brain function
    • Diagnosis of any condition
    • Prediction of health outcomes

    6.7. QUANTUM LIGHT AND COHERENCE

    "Quantum," "coherence," and "biophoton" terminology is:
    • METAPHORICAL and CREATIVE, not scientific or medical
    • INSPIRED BY quantum physics concepts, not actual quantum computing
    • FOR ARTISTIC EXPRESSION, not scientific measurement

    The App does NOT:
    • Measure actual quantum phenomena
    • Measure biophotons or biological light emission
    • Diagnose any quantum biological effects


    7. KNOWN RISKS AND SIDE EFFECTS

    Possible adverse effects from App use:

    • Eye strain or fatigue (from screen time)
    • Headaches (from visual effects or VR use)
    • Dizziness or disorientation (from VR/AR or breathing exercises)
    • Motion sickness (from visual effects or VR)
    • Anxiety or agitation (from certain audio/visual combinations)
    • Seizures (in photosensitive individuals)
    • Temporary hearing changes (from loud audio)

    STOP using the App if you experience any adverse effects.


    8. CONTRAINDICATIONS

    DO NOT use the App (or consult doctor first) if you have:

    • Pacemaker or implanted cardioverter-defibrillator (ICD)
    • Other implanted electronic medical devices
    • Epilepsy or seizure disorders
    • Severe cardiovascular disease
    • Severe respiratory disease
    • Severe mental illness
    • Pregnancy (for certain features)
    • Recent surgery or medical procedures


    9. DRUG AND ALCOHOL WARNING

    DO NOT use the App:
    • While under the influence of alcohol
    • While under the influence of recreational drugs
    • While taking medications that impair judgment or alertness (unless approved by doctor)


    10. CHILDREN AND ADOLESCENTS

    • Minimum Age: 13 years old (16 in EU)
    • Parental Supervision: Recommended for users under 18
    • Medical Approval: Children with medical conditions should have doctor approval before use

    Parents should:
    • Monitor child's use of the App
    • Ensure appropriate volume levels
    • Limit screen time according to pediatric guidelines
    • Watch for adverse effects


    11. PREGNANCY AND NURSING

    Pregnant or nursing individuals should:
    • Consult their healthcare provider before using the App
    • Avoid intense breathing exercises
    • Avoid prolonged VR/AR use
    • Use caution with audio features

    The safety of bio-reactive audio-visual technology during pregnancy has not been established.


    12. LIMITATION OF LIABILITY (HEALTH-RELATED)

    TO THE MAXIMUM EXTENT PERMITTED BY LAW:

    ECHOELMUSIC INC. IS NOT LIABLE FOR:
    • Any injury, illness, or death resulting from App use
    • Any medical condition or complications
    • Any reliance on biometric data from the App
    • Any delay in seeking medical care
    • Any adverse effects or side effects
    • Any interaction with medical treatments

    YOU ASSUME ALL RISKS associated with App use.


    13. RESEARCH DISCLAIMER

    Any research or studies referenced by the App:
    • Are for informational purposes only
    • Do not constitute medical advice
    • May not be peer-reviewed or validated
    • Do not establish causation

    Scientific research on bio-reactive music and HRV coherence is ongoing and not conclusive.


    14. PROFESSIONAL TRAINING DISCLAIMER

    The App does NOT:
    • Provide professional training in music therapy, biofeedback, or healthcare
    • Qualify you to provide therapeutic services
    • Replace formal education or licensure

    Do not use the App to:
    • Provide medical or therapeutic services to others
    • Make health-related claims
    • Diagnose or treat others


    15. TERRITORY-SPECIFIC DISCLAIMERS

    15.1. UNITED STATES

    This App is not intended for use in the diagnosis of disease or other conditions, or in the cure, mitigation, treatment, or prevention of disease.

    15.2. EUROPEAN UNION

    This App is not a medical device under the Medical Device Regulation (MDR 2017/745). It does not bear a CE mark for medical purposes.

    15.3. AUSTRALIA

    This App is not included in the Australian Register of Therapeutic Goods (ARTG).

    15.4. CANADA

    This App is not licensed by Health Canada as a medical device.


    16. ACCESSIBILITY DISCLAIMER

    While we strive to make the App accessible to users with disabilities:
    • Accessibility features are NOT medical accommodations
    • Do not replace assistive medical devices
    • May not be suitable for all disabilities

    Consult healthcare professionals about appropriate assistive technologies for your needs.


    17. DATA INTERPRETATION DISCLAIMER

    You are responsible for:
    • Understanding the limitations of biometric data
    • Not making medical decisions based on App data
    • Seeking professional interpretation of health concerns

    We do NOT:
    • Interpret your biometric data medically
    • Provide medical guidance based on your data
    • Diagnose conditions from your data


    18. UPDATES AND CHANGES

    As the App evolves:
    • New features may introduce new risks
    • This disclaimer may be updated
    • You should review disclaimers regularly

    Continued use after updates constitutes acceptance of updated disclaimers.


    19. EMERGENCY SITUATIONS

    IF YOU EXPERIENCE A MEDICAL EMERGENCY:

    1. STOP using the App immediately
    2. CALL emergency services (911 in US, 112 in EU)
    3. Follow emergency responder instructions

    The App CANNOT and DOES NOT:
    • Detect medical emergencies
    • Provide emergency medical guidance
    • Contact emergency services on your behalf


    20. QUESTIONS AND CONCERNS

    For health-related questions or concerns about App use:

    • Consult your healthcare provider (recommended)
    • Contact us at: \(PrivacyPolicy.contactEmail) (for App-related questions, not medical advice)

    We CANNOT and WILL NOT provide medical advice.


    21. ACKNOWLEDGMENT

    BY USING THIS APP, YOU ACKNOWLEDGE THAT:

    ✓ You have read and understood this Health Disclaimer
    ✓ You understand the App is NOT a medical device
    ✓ You will not rely on the App for medical purposes
    ✓ You will consult healthcare professionals for medical concerns
    ✓ You assume all risks associated with App use
    ✓ You will not hold Echoelmusic Inc. liable for health-related issues


    ---

    IF YOU DO NOT AGREE WITH THIS DISCLAIMER, DO NOT USE THE APP.

    Last Updated: \(effectiveDate)
    Version: \(version)

    © 2026 Echoelmusic Inc. All rights reserved.
    """

    public static let shortWarning = """
    ⚠️ HEALTH DISCLAIMER ⚠️

    NOT A MEDICAL DEVICE

    Echoelmusic is for WELLNESS and CREATIVE purposes only.

    • NOT for diagnosis, treatment, or prevention of disease
    • Biometric data is for creative use, NOT medical use
    • Consult healthcare professionals for medical concerns
    • Stop use if you experience adverse effects

    PHOTOSENSITIVE SEIZURE WARNING: Visual effects may trigger seizures in susceptible individuals.

    See full Health Disclaimer for complete information.
    """

    public static let biometricDataDisclaimer = """
    BIOMETRIC DATA DISCLAIMER

    Heart rate, HRV, breathing rate, and other biometric data shown in this App are:

    • FOR INFORMATIONAL AND CREATIVE PURPOSES ONLY
    • NOT accurate enough for medical decisions
    • NOT validated or approved for medical use

    DO NOT use this data to:
    • Diagnose or treat medical conditions
    • Make medication or treatment decisions
    • Monitor chronic health conditions
    • Replace medical device readings

    Always consult healthcare professionals for health concerns.
    """

    public static let breathingDisclaimer = """
    BREATHING EXERCISE DISCLAIMER

    Breathing exercises are for relaxation and wellness only, NOT medical therapy.

    STOP immediately if you feel:
    • Dizzy or lightheaded
    • Chest pain or discomfort
    • Difficulty breathing
    • Anxious or panicked

    Consult your doctor before use if you have respiratory conditions, panic disorder, or pregnancy.
    """

    public static let meditationDisclaimer = """
    MEDITATION DISCLAIMER

    Meditation features are for general mindfulness practice, NOT mental health therapy.

    NOT a substitute for:
    • Professional mental health treatment
    • Therapy or counseling
    • Prescribed medications

    Consult a mental health professional if you have trauma history, severe anxiety, depression, or other mental health conditions.
    """

    public static let seizureWarning = """
    ⚠️ PHOTOSENSITIVE SEIZURE WARNING ⚠️

    Visual effects in this App may trigger SEIZURES in individuals with photosensitive epilepsy.

    STOP using the App immediately if you experience:
    • Seizures or convulsions
    • Loss of awareness
    • Eye or muscle twitching
    • Disorientation

    If you have epilepsy or seizure history, consult your doctor before use and enable reduced motion settings.
    """
}

// MARK: - Legal Document Viewer (SwiftUI)

#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI view for displaying legal documents in-app
@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, visionOS 1.0, *)
public struct LegalDocumentViewer: View {

    public enum DocumentType: String, CaseIterable, Identifiable {
        case privacyPolicy = "Privacy Policy"
        case termsOfService = "Terms of Service"
        case healthDisclaimer = "Health Disclaimer"

        public var id: String { rawValue }

        var fullText: String {
            switch self {
            case .privacyPolicy: return PrivacyPolicy.fullText
            case .termsOfService: return TermsOfService.fullText
            case .healthDisclaimer: return HealthDisclaimer.fullText
            }
        }

        var summary: String? {
            switch self {
            case .privacyPolicy: return PrivacyPolicy.shortSummary
            case .termsOfService: return TermsOfService.shortSummary
            case .healthDisclaimer: return HealthDisclaimer.shortWarning
            }
        }

        var version: String {
            switch self {
            case .privacyPolicy: return PrivacyPolicy.version
            case .termsOfService: return TermsOfService.version
            case .healthDisclaimer: return HealthDisclaimer.version
            }
        }

        var effectiveDate: String {
            switch self {
            case .privacyPolicy: return PrivacyPolicy.effectiveDate
            case .termsOfService: return TermsOfService.effectiveDate
            case .healthDisclaimer: return HealthDisclaimer.effectiveDate
            }
        }

        var icon: String {
            switch self {
            case .privacyPolicy: return "lock.shield.fill"
            case .termsOfService: return "doc.text.fill"
            case .healthDisclaimer: return "heart.text.square.fill"
            }
        }
    }

    @State private var selectedDocument: DocumentType
    @State private var showFullText: Bool = false
    @Environment(\.dismiss) private var dismiss

    public init(document: DocumentType = .privacyPolicy) {
        _selectedDocument = State(initialValue: document)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Document picker
                Picker("Document", selection: $selectedDocument) {
                    ForEach(DocumentType.allCases) { doc in
                        Label(doc.rawValue, systemImage: doc.icon)
                            .tag(doc)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: selectedDocument.icon)
                                    .font(.title)
                                    .foregroundColor(.accentColor)
                                Text(selectedDocument.rawValue)
                                    .font(.title2)
                                    .bold()
                            }

                            HStack {
                                Text("Version \(selectedDocument.version)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text("Effective: \(selectedDocument.effectiveDate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 8)

                        Divider()

                        // Summary or full text
                        if showFullText {
                            Text(selectedDocument.fullText)
                                .font(.system(.body, design: .default))
                                .textSelection(.enabled)
                        } else if let summary = selectedDocument.summary {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Summary")
                                    .font(.headline)

                                Text(summary)
                                    .font(.body)
                                    .foregroundColor(.secondary)

                                Button {
                                    withAnimation {
                                        showFullText = true
                                    }
                                } label: {
                                    Label("Read Full Document", systemImage: "doc.text.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 8)
                            }
                        }

                        // Action buttons
                        if showFullText {
                            VStack(spacing: 12) {
                                Button {
                                    exportDocument()
                                } label: {
                                    Label("Export as PDF", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    withAnimation {
                                        showFullText = false
                                    }
                                } label: {
                                    Label("Show Summary", systemImage: "text.justify.left")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.top, 8)
                        }

                        // Contact info
                        Divider()
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Questions or Concerns?")
                                .font(.headline)

                            Button {
                                openEmail(to: PrivacyPolicy.contactEmail)
                            } label: {
                                Label(PrivacyPolicy.contactEmail, systemImage: "envelope.fill")
                            }

                            Button {
                                openWebsite()
                            } label: {
                                Label("Visit Website", systemImage: "safari.fill")
                            }
                        }
                        .font(.caption)
                    }
                    .padding()
                }
            }
            .navigationTitle("Legal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func exportDocument() {
        // TODO: Implement PDF export
        // For now, just copy to clipboard
        #if os(iOS)
        UIPasteboard.general.string = selectedDocument.fullText
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedDocument.fullText, forType: .string)
        #endif
    }

    private func openEmail(to email: String) {
        let subject = "Inquiry about \(selectedDocument.rawValue)"
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: urlString) {
            #if os(iOS) || os(visionOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }

    private func openWebsite() {
        if let url = URL(string: PrivacyPolicy.websiteURL) {
            #if os(iOS) || os(visionOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}

// MARK: - Compact Legal Banner

/// Compact legal banner for onboarding or settings
@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, visionOS 1.0, *)
public struct LegalBanner: View {

    @State private var showLegalViewer = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By using this app, you agree to our:")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button("Privacy Policy") {
                    showLegalViewer = true
                }
                .font(.caption)

                Button("Terms of Service") {
                    showLegalViewer = true
                }
                .font(.caption)

                Button("Health Disclaimer") {
                    showLegalViewer = true
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showLegalViewer) {
            LegalDocumentViewer()
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, visionOS 1.0, *)
struct LegalDocumentViewer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LegalDocumentViewer(document: .privacyPolicy)
            LegalDocumentViewer(document: .termsOfService)
            LegalDocumentViewer(document: .healthDisclaimer)
            LegalBanner()
                .padding()
        }
    }
}
#endif

#endif // canImport(SwiftUI)

// MARK: - Utility Functions

/// Check if user has accepted current terms
public func hasAcceptedCurrentTerms() -> Bool {
    let acceptedVersion = UserDefaults.standard.string(forKey: "AcceptedTermsVersion")
    return acceptedVersion == TermsOfService.version
}

/// Mark current terms as accepted
public func acceptCurrentTerms() {
    UserDefaults.standard.set(TermsOfService.version, forKey: "AcceptedTermsVersion")
    UserDefaults.standard.set(Date(), forKey: "TermsAcceptedDate")
}

/// Check if user has acknowledged health disclaimer
public func hasAcknowledgedHealthDisclaimer() -> Bool {
    let acknowledgedVersion = UserDefaults.standard.string(forKey: "AcknowledgedHealthDisclaimerVersion")
    return acknowledgedVersion == HealthDisclaimer.version
}

/// Mark health disclaimer as acknowledged
public func acknowledgeHealthDisclaimer() {
    UserDefaults.standard.set(HealthDisclaimer.version, forKey: "AcknowledgedHealthDisclaimerVersion")
    UserDefaults.standard.set(Date(), forKey: "HealthDisclaimerAcknowledgedDate")
}

// MARK: - App Store Review Guidelines Compliance

/// Helper to ensure App Store compliance
public struct AppStoreCompliance {

    /// Check if all required legal acceptances are complete
    public static func isCompliant() -> Bool {
        return hasAcceptedCurrentTerms() && hasAcknowledgedHealthDisclaimer()
    }

    /// Required legal documents for App Store submission
    public static let requiredDocuments: [String] = [
        "Privacy Policy",
        "Terms of Service",
        "Health Disclaimer"
    ]

    /// App Store Connect URLs (to be filled during submission)
    public static let appStoreURLs: [String: String] = [
        "Privacy Policy URL": "https://echoelmusic.com/privacy",
        "Terms of Service URL": "https://echoelmusic.com/terms",
        "Support URL": "https://echoelmusic.com/support"
    ]
}
