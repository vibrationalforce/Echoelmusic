# App Store Visual Assets - EOEL

**Status:** Specifications Ready - Awaiting Design
**Priority:** 🔴 CRITICAL - Launch Blocker
**Deadline:** Before App Store submission

---

## 📱 App Icon Requirements

### Technical Specifications

| Size | Resolution | Purpose | Format |
|------|-----------|---------|--------|
| 1024x1024 | @1x | App Store | PNG (no alpha) |
| 180x180 | @3x | iPhone | PNG |
| 120x120 | @2x | iPhone | PNG |
| 167x167 | @2x | iPad Pro | PNG |
| 152x152 | @2x | iPad | PNG |
| 76x76 | @1x | iPad | PNG |
| 60x60 | @2x | iPhone Notification | PNG |
| 40x40 | @2x | iPhone Spotlight | PNG |
| 29x29 | @2x | iPhone Settings | PNG |

### Design Requirements

**App Store Rules:**
- ❌ No transparency (alpha channel)
- ❌ No rounded corners (iOS adds them)
- ❌ No text (unless part of logo)
- ✅ Must be recognizable at small sizes
- ✅ Must work in light and dark mode
- ✅ Should be memorable and unique

### Design Concept Options

**Option 1: Waveform E**
```
Visual: Stylized letter "E" made of audio waveforms
Colors: Blue gradient (#0066FF → #00CCFF)
Background: Dark (#1A1A2E) or White (#FFFFFF)
Style: Modern, tech, professional
```

**Option 2: Sound Wave Circle**
```
Visual: Circular audio wave pattern
Colors: Purple to Blue gradient (#8B5CF6 → #3B82F6)
Background: Black (#000000)
Style: Abstract, premium, artistic
```

**Option 3: Music Note + Work Briefcase**
```
Visual: Combined music note and briefcase (representing music + gigs)
Colors: Yellow (#FFD700) and Blue (#4169E1)
Background: Dark gradient
Style: Dual-purpose, clear messaging
```

**Recommended:** Option 2 (Sound Wave Circle)
- Stands out in App Store
- Represents audio/music clearly
- Works well at all sizes
- Memorable and unique

### Design Assets Needed

1. **Source File:** Adobe Illustrator (.ai) or Figma
2. **Exported PNGs:** All sizes listed above
3. **App Icon Set:** Complete .appiconset for Xcode
4. **Brand Guidelines:** Color codes, spacing, usage rules

### Design Tools

- **Figma:** Free, web-based, collaborative
- **Sketch:** Mac-only, industry standard
- **Adobe Illustrator:** Professional vector design
- **App Icon Generators:**
  - https://appicon.co
  - https://makeappicon.com
  - https://www.appicon.build

---

## 📸 Screenshot Requirements

### Device Sizes Required

Apple requires screenshots for:

| Device | Size | Orientation | Minimum |
|--------|------|-------------|---------|
| iPhone 6.7" (15 Pro Max) | 1290×2796 | Portrait | 1 |
| iPhone 6.5" (14 Pro Max) | 1284×2778 | Portrait | 1 |
| iPhone 5.5" (8 Plus) | 1242×2208 | Portrait | 1 |
| iPad Pro 12.9" | 2048×2732 | Portrait | 1 |

**Recommendation:** Provide 6-10 screenshots per device size

### Screenshot Content Plan

#### Screenshot 1: Hero/Recording Interface
```
Visual: Main recording interface with waveform
Overlay Text: "PROFESSIONAL RECORDING"
Subtitle: "Multi-track recording with unlimited tracks"
Feature Highlight: Recording in progress, clean UI
Call-out: "47 Premium Instruments"
```

#### Screenshot 2: Instrument Library
```
Visual: Instrument selection grid showing variety
Overlay Text: "47 PREMIUM INSTRUMENTS"
Subtitle: "From piano to synthesizers"
Feature Highlight: Beautiful instrument icons
Call-out: "Professional-quality sounds"
```

#### Screenshot 3: Effects Rack
```
Visual: Effects chain with multiple processors
Overlay Text: "77 STUDIO EFFECTS"
Subtitle: "Professional audio processing"
Feature Highlight: Reverb, Delay, Compression, EQ
Call-out: "Real-time processing"
```

#### Screenshot 4: Face Control (Unique Feature!)
```
Visual: User's face with AR overlay controlling effects
Overlay Text: "FACE CONTROL"
Subtitle: "Use expressions to control effects"
Feature Highlight: Facial landmarks mapped to parameters
Call-out: "Revolutionary music control"
```

#### Screenshot 5: EoelWork Platform
```
Visual: Gig listing page with multiple opportunities
Overlay Text: "FIND MUSIC GIGS"
Subtitle: "Get hired, earn money"
Feature Highlight: Local gigs with prices and details
Call-out: "Secure payments via Stripe"
```

#### Screenshot 6: Smart Lighting
```
Visual: Phone controlling colorful smart lights
Overlay Text: "SMART LIGHTING"
Subtitle: "Control your environment"
Feature Highlight: Lights synced to music
Call-out: "Philips Hue + LIFX support"
```

#### Screenshot 7: AI Composer (Optional)
```
Visual: AI generating musical notation
Overlay Text: "AI COMPOSER"
Subtitle: "Generate original melodies"
Feature Highlight: AI-powered composition
Call-out: "Powered by CoreML"
```

#### Screenshot 8: Cloud Sync (Optional)
```
Visual: Projects syncing across devices
Overlay Text: "CLOUD SYNC"
Subtitle: "Access projects anywhere"
Feature Highlight: iCloud integration
Call-out: "Seamless across all devices"
```

### Design Specifications

**Layout:**
- Portrait orientation only
- Text overlays at top (white text, dark overlay)
- Feature highlights with arrows/circles
- Consistent branding colors
- Premium, professional appearance

**Typography:**
- Title: SF Pro Display, Bold, 72pt
- Subtitle: SF Pro Text, Regular, 48pt
- Call-outs: SF Pro Text, Semibold, 36pt
- All text should be readable at thumbnail size

**Colors:**
- Primary: Blue (#0066FF)
- Accent: Purple (#8B5CF6)
- Background: Dark mode UI (#1A1A2E)
- Text: White (#FFFFFF) with subtle shadow

**Branding:**
- EOEL logo in corner (subtle, not distracting)
- Consistent color scheme across all screenshots
- Professional mockup frames (optional but recommended)

### Screenshot Creation Tools

**Option 1: Xcode Simulator + Figma**
1. Run app in iOS Simulator
2. Take screenshots (Cmd+S)
3. Import to Figma
4. Add text overlays and highlights
5. Export at required sizes

**Option 2: Screenshot Design Services**
- Placeit by Envato
- Previewed.app
- AppLaunchpad

**Option 3: Manual Design**
- Figma (Free, recommended)
- Adobe Photoshop
- Sketch

### Screenshot Mockup Templates

**Device Frames:** Use official Apple device frames
- Download from: https://developer.apple.com/design/resources/
- Or use: https://facebook.github.io/device-frames/

**Figma Template Structure:**
```
Frame: iPhone 15 Pro Max (1290×2796)
├── Background (app screenshot)
├── Dark Overlay (gradient, 40% opacity at top)
├── Title Text ("PROFESSIONAL RECORDING")
├── Subtitle Text
├── Feature Highlights (circles, arrows)
├── Logo (bottom corner, subtle)
```

---

## 🎬 App Preview Videos

### Technical Specifications

| Spec | Requirement |
|------|-------------|
| Duration | 15-30 seconds |
| Format | .mov or .m4v |
| Codec | H.264 or HEVC |
| Resolution | Same as screenshots |
| Max Size | 500 MB |
| Audio | Optional (recommended) |

### Video 1: Main Features (30s)

**Script:**
```
[0-3s]   EOEL logo animation with sound
         Text: "EOEL - Professional Music Studio"

[3-8s]   Quick recording demo
         Show: Selecting instrument, recording audio
         Text: "Record with 47 instruments"

[8-13s]  Effects demonstration
         Show: Adding reverb, delay, compression
         Text: "Process with 77 effects"

[13-18s] Face control demo (UNIQUE!)
         Show: User controlling effect with facial expression
         Text: "Control with your face"

[18-23s] EoelWork platform
         Show: Browsing gigs, applying to job
         Text: "Find gigs & get hired"

[23-27s] Final composition playing
         Show: Polished track with visualization

[27-30s] Download CTA
         Text: "Download EOEL"
         Subtitle: "Free 7-day trial"
```

**Production Notes:**
- Use screen recording + face camera split screen
- Professional voiceover (optional)
- Background music (upbeat, professional)
- Fast-paced editing (2-3 second cuts)
- Captions for accessibility

### Video 2: Recording Workflow (30s)

**Script:**
```
[0-5s]   Opening app, creating new project
[5-10s]  Selecting piano instrument
[10-15s] Recording a melody
[15-20s] Adding drums on second track
[20-25s] Mixing with effects
[25-30s] Exporting final song
```

### Video 3: EoelWork Platform (15s)

**Script:**
```
[0-3s]   Opening EoelWork tab
[3-7s]   Scrolling through local gigs
[7-11s]  Viewing gig details
[11-15s] "Get Hired" success screen
```

### Video Creation Tools

**Screen Recording:**
- QuickTime Player (Mac)
- iOS Screen Recording (Control Center)
- OBS Studio (Free, cross-platform)

**Video Editing:**
- Final Cut Pro (Professional)
- iMovie (Free, simple)
- Adobe Premiere Pro
- DaVinci Resolve (Free)

**Captions:**
- Rev.com (Professional service)
- Apple's built-in captioning
- YouTube auto-captions (export SRT)

---

## 🎨 Brand Assets Needed

### Logo Variations

1. **Full Logo:** EOEL wordmark
2. **Icon Only:** For small spaces
3. **White Version:** For dark backgrounds
4. **Black Version:** For light backgrounds
5. **Transparent Background:** PNG with alpha

### Color Palette

**Primary Colors:**
```
Brand Blue:    #0066FF (RGB: 0, 102, 255)
Brand Purple:  #8B5CF6 (RGB: 139, 92, 246)
Dark BG:       #1A1A2E (RGB: 26, 26, 46)
```

**Secondary Colors:**
```
Success Green: #10B981 (RGB: 16, 185, 129)
Warning Yellow:#FBBF24 (RGB: 251, 191, 36)
Error Red:     #EF4444 (RGB: 239, 68, 68)
```

**Neutral Colors:**
```
White:         #FFFFFF
Light Gray:    #F3F4F6
Medium Gray:   #6B7280
Dark Gray:     #1F2937
Black:         #000000
```

### Typography

**Primary Font:** SF Pro (Apple's system font)
- Display: For headlines
- Text: For body copy
- Rounded: For friendly UI elements

**Fallback:** San Francisco (system default)

### Visual Style

**Photography Style:**
- Real musicians using the app
- Diverse representation
- Professional lighting
- Genuine emotion/concentration
- Clean, minimal backgrounds

**Illustration Style:**
- Modern, flat design
- Consistent color palette
- Simple, clear icons
- Accessible (WCAG AA compliant)

---

## 📋 Asset Delivery Checklist

### App Icon
- [ ] 1024x1024 PNG (App Store)
- [ ] Complete .appiconset folder
- [ ] Source file (.ai, .sketch, or .figma)
- [ ] Light and dark mode versions tested

### Screenshots
- [ ] 6 screenshots for iPhone 6.7" (1290×2796)
- [ ] 6 screenshots for iPhone 6.5" (1284×2778)
- [ ] 6 screenshots for iPhone 5.5" (1242×2208)
- [ ] 6 screenshots for iPad Pro 12.9" (2048×2732)
- [ ] All text overlays readable at thumbnail size
- [ ] Consistent branding across all screenshots
- [ ] Localized versions for Tier 1 languages (optional)

### App Preview Videos
- [ ] Video 1: Main features (30s)
- [ ] Video 2: Recording workflow (30s) [Optional]
- [ ] Video 3: EoelWork (15s) [Optional]
- [ ] Captions/subtitles included
- [ ] Preview poster frames selected
- [ ] File size under 500 MB each

### Additional Assets
- [ ] Press kit images (high-res)
- [ ] Social media graphics
- [ ] Website hero image
- [ ] Email newsletter header

---

## 🎯 Design Brief for Designer

**Project:** EOEL App Store Assets
**Timeline:** 5-7 business days
**Budget:** $500-1500 (depending on scope)

**Deliverables:**
1. App icon (all sizes)
2. 6 screenshots per device size (4 sizes × 6 = 24 total)
3. 1-3 app preview videos
4. Source files

**Brand Positioning:**
- Professional music production app
- Premium, high-quality
- Innovative (Face Control, AI features)
- Accessible to creators at all levels

**Target Audience:**
- Age: 18-35
- Musicians, producers, content creators
- Tech-savvy, creative professionals
- Values: Quality, innovation, community

**Competitors to Reference:**
- GarageBand (simple, accessible)
- FL Studio Mobile (professional, feature-rich)
- Cubasis (premium, polished)

**Unique Selling Points to Highlight:**
1. Face Control (revolutionary feature!)
2. EoelWork gig platform (find work)
3. 47 instruments + 77 effects
4. Smart lighting integration
5. AI composer

**Style References:**
- Apple's App Store featured apps
- Modern, clean design
- Premium feel
- Not overly technical/intimidating

---

## 💰 Estimated Costs

### DIY Approach
- **Icon Generator:** Free - $20
- **Screenshot Design (Figma):** Free
- **Video Editing Software:** Free (iMovie) - $300 (FCP)
- **Total:** $0 - $320

### Freelancer (Recommended)
- **App Icon:** $100 - $300
- **Screenshots (24 total):** $200 - $500
- **Videos (3):** $300 - $700
- **Total:** $600 - $1,500

### Agency (Premium)
- **Complete Package:** $2,000 - $5,000
- **Includes:** Icon, screenshots, videos, press kit, social assets
- **Benefit:** Professional quality, fast turnaround

**Recommendation:** Hire freelancer on:
- Fiverr (budget: $300-500)
- Upwork (professional: $800-1200)
- 99designs (competition: $500-1000)

---

## 📅 Timeline

### Week 1: Design
- Days 1-2: App icon design + revisions
- Days 3-5: Screenshot design (all sizes)
- Days 6-7: Final reviews and tweaks

### Week 2: Video
- Days 1-2: Record screen footage
- Days 3-4: Edit videos
- Days 5: Add captions
- Days 6-7: Final review

**Total:** 2 weeks for complete asset package

---

## 🔗 Resources

### Design Resources
- **Apple Design Resources:** https://developer.apple.com/design/resources/
- **App Store Screenshots Guide:** https://developer.apple.com/app-store/product-page/
- **Human Interface Guidelines:** https://developer.apple.com/design/human-interface-guidelines/

### Tools
- **Figma (Free):** https://figma.com
- **App Icon Generator:** https://appicon.co
- **Screenshot Mockups:** https://previewed.app
- **Stock Photos:** https://unsplash.com

### Inspiration
- **App Store Featured Apps:** Browse Music category
- **Dribbble:** Search "app icon music"
- **Behance:** Search "app store screenshots"

---

**Status:** Ready for designer briefing
**Next Steps:**
1. Hire designer or create in-house
2. Review first drafts within 3 days
3. Final approval within 1 week
4. Upload to App Store Connect

**Contact:** design@eoel.app
