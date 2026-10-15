# Öffentliche TestFlight-Beta — einmal einrichten, dann als Promo-Link nutzen

Ziel: ein **öffentlicher TestFlight-Link** (`https://testflight.apple.com/join/…`), den jeder mit
einem iPhone öffnen kann — für Pre-Release-Promo, Clips, Presse und Communities. Kein Rechner
nötig; alles im Browser unter appstoreconnect.apple.com (Safari auf dem iPhone geht).

Was die Pipeline schon tut: jeder Build landet in TestFlight (`testflight.yml` → Fastlane,
`distribute_external: false`). Er erreicht heute nur INTERNE Tester. Der öffentliche Link braucht
einmalig eine **externe Gruppe** und eine **Beta-App-Prüfung** durch Apple.

## 1. Einmalig einrichten (ca. 15 Minuten)

1. App Store Connect → **Apps** → Echoelmusic → Reiter **TestFlight**.
2. Links **Testinformationen** (Test Information) ausfüllen — Texte unten in §2 kopieren:
   Beta-App-Beschreibung · Feedback-E-Mail · Marketing-URL · Datenschutz-URL ·
   Anmeldedaten: „Anmeldung nicht erforderlich" (die App hat kein Konto).
3. Links unter **Externe Tests** auf **+** → neue Gruppe **„Public Beta"**.
4. In der Gruppe **Builds** → **+** → den neuesten Build wählen (10.79.505) →
   bei „Was zu testen ist" den Text aus §3 einfügen → **Zur Prüfung einreichen**.
5. Warten auf die **Beta-App-Prüfung** (meist 1–2 Tage; nur der ERSTE Build einer Version wird
   voll geprüft, spätere Builds derselben Version meist sofort freigegeben).
6. Nach der Freigabe: in der Gruppe **Öffentlicher Link** → **aktivieren** → Tester-Limit setzen
   (z. B. 1.000; Maximum 10.000) → Link kopieren.

**Danach:** jeder neue Build muss in der Gruppe einmal mit **+** hinzugefügt werden (oder später
automatisch — das ist eine Änderung an `fastlane/Fastfile`, nur mit deinem Ja, weil dann JEDER
Build an alle öffentlichen Tester geht). Ein Build läuft nach **90 Tagen** ab.

## 2. Testinformationen (Englisch, zum Einfügen)

**Beta App Description**

> Echoel is a bio-reactive instrument for iPhone. Your body plays it: lay a finger on the rear
> camera, your pulse locks, and heart rate, HRV and breath shape a synthesizer and a live visual
> in real time. Pick a genre and a key; the music stays in key and moves with you. Touch the
> visual and your fingers become notes.
>
> Send it on to your rig: OSC, MIDI and MPE out, Art-Net and sACN light, ADM-OSC spatial objects.
> Export your loop as WAV or MIDI. No account, everything stays on the device.
>
> This is a pre-release beta. Biofeedback is for creative use and self-observation, not medical
> diagnosis. Visual flashes stay at or below 3 Hz.

**Feedback E-Mail:** echoel@tropicaldrones.com (dieselbe Adresse wie auf der Website)
**Marketing URL:** https://echoelmusic.com
**Privacy Policy URL:** https://echoelmusic.com/privacy

## 3. „Was zu testen ist" für Build 10.79.505 (Englisch)

> Thanks for testing Echoel!
> 1. Open the app — it starts on the instrument. Press Play at the top: you hear it right away.
> 2. Pulse: choose the camera as source and cover the rear camera and flash with a fingertip.
>    The line under the controls tells you what to do; it disappears when your pulse locks.
> 3. Try a genre and a key, and touch the visual to play notes.
> 4. Export a loop (Save & Export) as WAV or MIDI and open it in your DAW.
> Something wrong? Save & Export → Diagnostics → Share, or send a screenshot through TestFlight.

## 4. Was im Promo-Text stehen darf — und was nicht

Quelle der Wahrheit ist `ContentPipeline/CLAIMS.md`. Kurz:
- **Ja:** „Beta auf TestFlight", Puls über die Kamera, Klang und Bild reagieren in Echtzeit,
  tonartreine Komposition, OSC/MIDI/MPE-Out, Art-Net/sACN, ADM-OSC, WAV/MIDI-Export, kein Konto.
- **Nein:** „im App Store" (CLAIMS §4 — erst nach der Freigabe), „läuft in deiner DAW/Logic"
  (§1 — nur „läuft in AUM"), Wellness/Meditation/Stress/Schlaf (§2), Apple Watch steuert (§3),
  Drums/Beats, Video-Aufnahme, Livestream (§5), Abo/Pro (§7), Biohacking (§9).
- Den Link nie mit einer Gesundheitswirkung bewerben.

## 5. Nach der Freigabe

- Link in die Bio von Instagram/TikTok, in den ersten Kommentar unter jedem Clip.
- Auf der Website: ein „Join the beta"-Knopf auf `docs/index.html` — sagt Claude Code Bescheid,
  das ist ein eigener kleiner Commit (Text gegen CLAIMS geprüft).
- Messen: TestFlight → Gruppe zeigt Einladungen, Installationen, Sitzungen und Abstürze je Build.
