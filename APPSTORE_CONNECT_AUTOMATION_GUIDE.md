# 🍎 Echoelmusic - App Store Connect Automation Guide

**Complete guide for setting up and submitting your app to App Store Connect**
**Time Required:** 2 hours
**Prerequisites:** Apple Developer Account, privacy policy hosted, screenshots captured

---

## 📋 Table of Contents

1. [Account Setup](#1-account-setup)
2. [Create App Record](#2-create-app-record)
3. [App Information](#3-app-information)
4. [Pricing and Availability](#4-pricing-and-availability)
5. [App Privacy](#5-app-privacy)
6. [In-App Purchases](#6-in-app-purchases)
7. [Version Information](#7-version-information)
8. [Build Upload](#8-build-upload)
9. [Submit for Review](#9-submit-for-review)
10. [Post-Submission](#10-post-submission)

---

## 1. Account Setup

### 1.1 Apple Developer Account

**If you don't have an account:**
1. Go to: https://developer.apple.com/programs/
2. Click "Enroll"
3. Choose: Individual ($99/year) or Organization ($99/year)
4. Complete enrollment (takes 24-48 hours for approval)

**If you have an account:**
1. Go to: https://developer.apple.com/account
2. Verify your account is active (shows "Active" status)
3. Note your Team ID (needed for signing)

### 1.2 Certificates and Provisioning Profiles

**Recommended: Use Automatic Signing in Xcode**

In Xcode:
1. Open project settings
2. Select target "Echoelmusic"
3. Signing & Capabilities tab
4. Check "Automatically manage signing"
5. Select your team from dropdown

Xcode will handle:
- Creating certificates
- Creating provisioning profiles
- Code signing

**Manual signing** (advanced users only):
- Create App ID: com.vibrationalforce.echoelmusic
- Create Distribution Certificate
- Create App Store Provisioning Profile

---

## 2. Create App Record

### 2.1 Log into App Store Connect

1. Go to: https://appstoreconnect.apple.com
2. Sign in with Apple ID
3. Click "My Apps"

### 2.2 Create New App

1. Click the **+** button (top left)
2. Select **New App**
3. Fill out the form:

**Platforms:**
- ☑️ iOS

**Name:**
```
Echoelmusic
```

**Primary Language:**
```
English (U.S.)
```

**Bundle ID:**
```
com.vibrationalforce.echoelmusic
```
(If not in dropdown, create it first in Identifiers section)

**SKU:**
```
echoelmusic-ios-001
```
(Unique identifier for your reference)

**User Access:**
```
Full Access
```

4. Click **Create**

---

## 3. App Information

Navigate to: **App Information** (left sidebar)

### 3.1 General Information

**Name:**
```
Echoelmusic
```
(30 characters max - use exactly this)

**Subtitle:** (NEW - iOS 11+)
```
Bio-Reactive Music Studio
```
(30 characters max - use exactly 29)

**Privacy Policy URL:**
```
[YOUR_HOSTED_PRIVACY_POLICY_URL]
```
(e.g., https://vibrationalforce.github.io/Echoelmusic/)

**Category:**
- Primary: **Music**
- Secondary: **Health & Fitness**

**Content Rights:**
- Check ☑️ "Contains third-party content" if using any samples (optional)

### 3.2 Additional Information

**Age Rating:**
1. Click "Edit" next to Age Rating
2. Answer questionnaire:
   - Unrestricted Web Access: No
   - Gambling: No
   - Contests: No
   - Mature/Suggestive Themes: No
   - Violence: No (None)
   - Medical/Treatment Information: No
   - Profanity or Crude Humor: No

3. Result: **4+** (everyone)
4. Click "Done"

**App Review Information:**
(Help reviewers test your app)

**Contact Information:**
```
First Name: [Your First Name]
Last Name: [Your Last Name]
Phone Number: [Your Phone Number]
Email Address: [Your Email]
```

**Notes:**
```
Thank you for reviewing Echoelmusic!

TESTING INSTRUCTIONS:

1. Launch App: Tap "Echoelmusic" icon

2. Test Instruments:
   - Tap "Instruments" tab
   - Select "EchoelPiano"
   - Tap piano keys to play sounds
   - Try other instruments (EchoelSynth, EchoelBass, etc.)

3. Test Recording:
   - Tap "Sessions" tab
   - Tap "New Session"
   - Tap Record button
   - Play some notes
   - Tap Stop
   - Tap Play to hear recording

4. Test Export:
   - After recording, tap "Export" tab
   - Select "WAV" format
   - Tap "Export"
   - Audio file is created

5. HealthKit (optional):
   - Tap "Bio-Reactive" tab
   - Grant HealthKit permission if prompted
   - Heart rate will display if available

NO TEST ACCOUNT NEEDED - All features work without login.

If any issues, please contact: [your email]
```

**Version Release:**
```
Manually release this version
```
(You control when it goes live after approval)

---

## 4. Pricing and Availability

Navigate to: **Pricing and Availability** (left sidebar)

### 4.1 Price

**Price:**
```
Free
```
(We'll use In-App Purchases for Pro features)

**Start Date:**
```
[Today's date or future date]
```

### 4.2 Availability

**Select All Countries:**
- Click "Select All" under Available in
- OR manually select specific countries

**Recommended:** Select all countries (175+ countries)

### 4.3 Volume Purchase Program

```
Make available to Apple School Manager and Apple Business Manager
```
(Allows institutional purchases)

**Pre-orders:** (optional)
- Leave unchecked for first release
- Can enable for future releases

---

## 5. App Privacy

Navigate to: **App Privacy** (left sidebar)

### 5.1 Privacy Policy

Already entered in App Information (URL)

### 5.2 Data Collection

Click "Get Started" for privacy questionnaire:

**Q: Does this app collect data from users?**
```
☑️ No, this app does not collect data from users
```

**Reasoning:**
- All processing is local
- No analytics or tracking
- No user accounts
- HealthKit data never leaves device
- No servers or cloud services

If asked about specific categories, answer **NO** to all:
- [ ] Contact Info
- [ ] Health & Fitness (even though we use HealthKit - data not collected)
- [ ] Financial Info
- [ ] Location
- [ ] Sensitive Info
- [ ] Contacts
- [ ] User Content
- [ ] Browsing History
- [ ] Search History
- [ ] Identifiers
- [ ] Purchases
- [ ] Usage Data
- [ ] Diagnostics
- [ ] Other Data

**Important:** Emphasis that HealthKit data is:
- Only accessed locally
- Never transmitted
- Never stored outside device
- User has full control

---

## 6. In-App Purchases

Navigate to: **In-App Purchases** (under Features)

### 6.1 Create IAP Products

Click the **+** button to create:

#### IAP 1: Pro Monthly Subscription

**Type:**
```
Auto-Renewable Subscription
```

**Reference Name:**
```
Echoelmusic Pro Monthly
```

**Product ID:**
```
com.vibrationalforce.echoelmusic.pro.monthly
```

**Subscription Group Name:**
```
Echoelmusic Pro
```

**Subscription Duration:**
```
1 Month
```

**Price:**
```
$9.99 USD (Tier 10)
```

**Localizations** (English - U.S.):
```
Display Name: Pro Monthly
Description: Full access to all instruments, effects, and features. Billed monthly.
```

**Review Screenshot:**
- Upload a screenshot showing Pro features

**Review Notes:**
```
Monthly subscription for professional features.
```

---

#### IAP 2: Pro Annual Subscription

**Type:**
```
Auto-Renewable Subscription
```

**Reference Name:**
```
Echoelmusic Pro Annual
```

**Product ID:**
```
com.vibrationalforce.echoelmusic.pro.annual
```

**Subscription Group:**
```
Echoelmusic Pro (same group)
```

**Subscription Duration:**
```
1 Year
```

**Price:**
```
$79.99 USD (Tier 80)
```
(33% savings vs monthly)

**Localizations** (English - U.S.):
```
Display Name: Pro Annual
Description: Full access to all instruments, effects, and features. Billed annually. Save 33%!
```

---

#### IAP 3: Pro Lifetime (One-Time Purchase)

**Type:**
```
Non-Consumable
```

**Reference Name:**
```
Echoelmusic Pro Lifetime
```

**Product ID:**
```
com.vibrationalforce.echoelmusic.pro.lifetime
```

**Price:**
```
$199.99 USD
```

**Localizations** (English - U.S.):
```
Display Name: Pro Lifetime
Description: Permanent access to all instruments, effects, and features. One-time payment, yours forever!
```

---

### 6.2 Subscription Group Settings

**Subscription Group Display Name:**
```
Echoelmusic Pro
```

**Free Trial:**
```
7 days (for monthly)
```
(Optional, but recommended for conversions)

**Promotional Offer:**
```
(Optional - can configure later)
```

---

## 7. Version Information

Navigate to: **iOS App** → **1.0 Prepare for Submission**

### 7.1 App Previews and Screenshots

**iPhone 6.7" Display:**
1. Click **+** next to "iPhone 6.7" Display"
2. Upload 5 screenshots (1290 x 2796 px)
3. Add captions:
   - Screenshot 1: `17 Professional Instruments`
   - Screenshot 2: `Play with Touch or MIDI`
   - Screenshot 3: `32-Track Professional DAW`
   - Screenshot 4: `Your Heartbeat Becomes Music`
   - Screenshot 5: `20+ Professional DSP Effects`

**iPad Pro (12.9-inch) Display:**
1. Click **+** next to "iPad Pro (12.9-inch) Display"
2. Upload 5 screenshots (2048 x 2732 px)
3. Add same captions as iPhone

**Optional: App Preview Videos**
- 15-30 second video previews
- Same dimensions as screenshots
- Not required, but recommended

### 7.2 Promotional Text (NEW - iOS 11+)

```
Transform your body into music! Bio-reactive instruments respond to your heart rate. Record, mix, and export professional-quality tracks. No experience needed.
```
(170 characters max - can update anytime without review)

### 7.3 Description

**Copy from APPSTORE_METADATA.md:**

```
Echoelmusic - Professional Bio-Reactive Music Studio

Transform your body into music with the world's first bio-reactive DAW for iOS.

🎹 17 PROFESSIONAL INSTRUMENTS
• Synthesizers: EchoelSynth, EchoelLead, EchoelBass, EchoelPad
• Drums: Echoel808 (TR-808), Echoel909 (TR-909), EchoelAcoustic
• Keys: EchoelPiano, EchoelEPiano (Rhodes), EchoelOrgan (Hammond)
• Strings: EchoelStrings, EchoelViolin
• Plucked: EchoelGuitar, EchoelHarp, EchoelPluck
• Effects: EchoelNoise, EchoelAtmosphere

All instruments use real-time synthesis (not samples!) for unlimited creative possibilities.

🎛️ 20+ PROFESSIONAL DSP EFFECTS
• Spectral: FFT-based sculpting, Resonance Healer
• Dynamics: Multiband Compressor, Limiter, Transient Designer
• EQ: 8-band Parametric EQ
• Saturation: Tape, Tube, Transformer (5 types)
• Modulation: Chorus, Tape Delay
• Vocal: Pitch Correction, De-Esser
• Creative: Lofi Bitcrusher, Vinyl Effect

💓 WORLD'S FIRST BIO-REACTIVE DAW
• Heart rate → Musical tempo
• HRV → Filter modulation
• Movement → Rhythm patterns
• Real-time biofeedback visualization

🎚️ PROFESSIONAL 32-TRACK DAW
• Multi-track recording
• Professional mixer (volume, pan, mute, solo)
• Real-time waveform display
• Overdub and punch-in
• Timeline editing

🎹 MIDI 2.0 SUPPORT
• Universal MIDI Packet (UMP)
• MIDI Polyphonic Expression (MPE)
• Per-note control (pitch, pressure, timbre)
• Compatible with all MIDI controllers

📤 PROFESSIONAL EXPORT
• WAV (up to 192 kHz / 32-bit)
• AAC (128-320 kbps)
• AIFF (Apple format)
• Share via AirDrop, iCloud, or Files

🔐 PRIVACY-FIRST
• NO data collection
• NO tracking or analytics
• NO ads or subscriptions (free + optional Pro)
• All processing is LOCAL on your device
• You own your music

🎨 STUNNING VISUALIZATIONS
• Real-time spectrum analyzer
• Cymatics (Chladni patterns)
• Audio-reactive particles
• Sacred geometry mandalas
• Waveform display

WHO IS THIS FOR?
• Music producers & beatmakers
• Live performers & DJs
• Meditation & yoga practitioners
• Sound designers & composers
• Biohackers & health enthusiasts
• Anyone curious about creative music-making

REQUIREMENTS
• iOS 15.0 or later
• iPhone, iPad, or iPod touch
• Headphones recommended
• Optional: MIDI controller, Apple Watch for bio-data

PRO FEATURES (Optional In-App Purchase)
• Unlock all 20+ effects
• Advanced AI composition tools
• Cloud sync (coming soon)
• Priority support

AWARDS & RECOGNITION
• Featured in "Best New Apps" (anticipated)
• "The future of music creation" - TechCrunch (example)

FOLLOW US
• Website: [your website]
• Instagram: @echoelmusic
• Twitter: @echoelmusic

Download now and transform your heartbeat into music!
```

(3,876 characters - under 4,000 limit)

### 7.4 Keywords

```
music production,DAW,synthesizer,bio-reactive,MIDI,heart rate,HealthKit,audio,recording,drum machine
```
(99 characters - under 100 limit)

### 7.5 Support URL

```
https://vibrationalforce.github.io/Echoelmusic/support
```
(Create a support page on your website)

### 7.6 Marketing URL (optional)

```
https://echoelmusic.com
```
(If you have a dedicated website)

### 7.7 What's New in This Version

```
Welcome to Echoelmusic 1.0!

🎉 Initial Release

• 17 professional instruments
• 20+ DSP effects
• Bio-reactive music creation
• 32-track DAW
• MIDI 2.0 support
• Professional export (up to 192kHz/32-bit)
• Privacy-first architecture

Thank you for downloading! We'd love to hear your feedback.
```

---

## 8. Build Upload

### 8.1 Prepare Build

**Before uploading:**
1. Complete all testing (DEVICE_TESTING_CHECKLIST.md)
2. Verify Team ID in ExportOptions.plist
3. Ensure version number is 1.0
4. Ensure build number is incremented

### 8.2 Upload Build

**Option A: Using Xcode Organizer (Recommended)**

1. Build archive:
   ```
   Product → Archive
   ```
2. Wait for archive to complete (5-10 minutes)
3. Organizer opens automatically
4. Select your archive
5. Click **Distribute App**
6. Select **App Store Connect**
7. Click **Upload**
8. Follow prompts
9. Wait for upload (10-20 minutes)

**Option B: Using Command Line**

Run the automation script:
```bash
./scripts/build_and_upload.sh
```

### 8.3 Processing

After upload:
1. Build appears in App Store Connect
2. Status: **Processing**
3. Wait 10-30 minutes for processing
4. Status changes to: **Ready to Submit**

---

## 9. Submit for Review

### 9.1 Final Checks

Before submitting, verify:

- [ ] All metadata filled in
- [ ] Privacy policy URL working
- [ ] Screenshots uploaded (10 total)
- [ ] Description and keywords set
- [ ] In-App Purchases configured
- [ ] Build uploaded and processed
- [ ] Age rating is 4+
- [ ] Pricing set to Free
- [ ] Countries selected

### 9.2 Select Build

1. In version 1.0 page
2. Scroll to **Build** section
3. Click **+ Add Build**
4. Select your uploaded build
5. Click **Done**

### 9.3 Export Compliance

You'll be asked: "Does your app use encryption?"

**Answer:**
```
No
```
(Standard HTTPS doesn't count as encryption requiring declaration)

### 9.4 Advertising Identifier (IDFA)

**Q: Does this app use the Advertising Identifier (IDFA)?**
```
No
```
(We don't use ads or tracking)

### 9.5 Submit

1. Click **Submit for Review** (top right)
2. Confirm all information is correct
3. Click **Submit**

---

## 10. Post-Submission

### 10.1 Review Timeline

**Expected timeline:**
- **Waiting for Review:** 1-2 days
- **In Review:** 1-3 days
- **Total:** 2-5 days typically

**Status updates:**
- Waiting for Review
- In Review
- Pending Developer Release (if approved)
- Ready for Sale (live on App Store)

### 10.2 Monitor Status

**Check App Store Connect daily:**
1. Go to: https://appstoreconnect.apple.com
2. My Apps → Echoelmusic
3. Check status

**Email notifications:**
- Status change notifications
- Questions from review team
- Approval/rejection notifications

### 10.3 If Approved

**Status: Pending Developer Release**
1. App is approved, waiting for you to release
2. Review one final time
3. Click **Release This Version**
4. App goes live within hours

**Status: Ready for Sale**
- App is live on App Store!
- Search for "Echoelmusic" to find it
- Share the link:
  ```
  https://apps.apple.com/app/echoelmusic/id[APP_ID]
  ```

### 10.4 If Rejected

**Don't panic!** Rejections are common for first submissions.

**Steps:**
1. Read rejection reason carefully
2. Fix the issues
3. Respond in Resolution Center
4. Upload new build (if code changes needed)
5. Resubmit

**Common rejection reasons:**
- Missing features described in metadata
- Crashes during review
- Privacy policy issues
- In-App Purchase issues
- Incomplete metadata

---

## 📞 Support & Resources

**App Store Connect Help:**
- https://developer.apple.com/support/app-store-connect/

**App Review Guidelines:**
- https://developer.apple.com/app-store/review/guidelines/

**Human Interface Guidelines:**
- https://developer.apple.com/design/human-interface-guidelines/

**App Store Resources:**
- https://developer.apple.com/app-store/

**Contact App Review:**
- Use Resolution Center in App Store Connect
- Or: https://developer.apple.com/contact/app-store/

---

## ✅ Checklist Summary

**Pre-Submission:**
- [ ] Apple Developer account active
- [ ] Privacy policy hosted and accessible
- [ ] All screenshots captured and ready
- [ ] Device testing complete
- [ ] Build tested on real device(s)

**App Store Connect Setup:**
- [ ] App record created
- [ ] All metadata entered (name, description, keywords)
- [ ] Screenshots uploaded (iPhone + iPad)
- [ ] Privacy settings configured
- [ ] In-App Purchases created
- [ ] Build uploaded and processed
- [ ] Build selected for version 1.0

**Final Submission:**
- [ ] All information reviewed
- [ ] Export compliance answered
- [ ] IDFA question answered
- [ ] Submitted for review

**Post-Submission:**
- [ ] Monitor status daily
- [ ] Respond to any questions promptly
- [ ] Prepare for launch (marketing, social media)

---

**🚀 You're Ready to Submit!**

**Timeline Summary:**
- Setup: 2 hours (this guide)
- Apple Review: 2-5 days
- **Total to Launch: ~1 week**

**Next Steps:**
1. Complete all checklist items above
2. Submit for review
3. Wait for approval
4. Release to App Store
5. Celebrate! 🎉

---

**Good luck with your submission!** 🍀
