# App-Store-Text Echoel Studio 11.0 — ENTWURF (2026-10-22)

**Status: Entwurf, nirgends eingesetzt.** `fastlane/metadata/**` trägt weiter den Text der früheren
Bio-App (Untertitel „Bio-Reactive Instrument“, Puls, HealthKit, Genres) und gehört dir; App Store Connect
ebenso. Hochgeladen wird seit Build 10004 aber Echoel Studio auf denselben Eintrag (Apple-ID 6757957358).
Ein Review vergleicht den ersten Schirm mit dem Text, und heute beschreibt der Text eine andere App — das
ist die 2.3-Ablehnung, vor der S-30 warnt. Frage dazu: `docs/dev/FOUNDER_INBOX.md` GM28.

**Woraus er gebaut ist:** nur aus den 36 gemessenen und gegengelesenen Sätzen in `ContentPipeline/CLAIMS.md`
§„Echoel Studio 11.0.0“ (Stand `372727570`, 2026-10-20), plus dem Produktsatz aus
`docs/dev/ECHOEL_VISION_2026-10-19.md` §2 und dem Satz „No account, no ads, no tracking“ aus
`EchoelStudio/App/Views/AboutView.swift`. Übersetzt, nicht erweitert. Weggelassen, weil CLAIMS es verbietet:
„ready-made beat“, „any Audio Unit“, „mastering“, „stems“, „works in AUM/Logic/GarageBand“, „imports your old
songs“, alles über den Assistenten, Puls, Atem, Licht und Raum.

**Vor dem Einsetzen, in dieser Reihenfolge:**
1. **Gerät.** Kein Satz ist auf einem Gerät geprüft (CLAIMS: „Jede Kopie sagt Beta“). Eingesetzt wird erst,
   wenn die Geräte-Familien des Builds (FOUNDER_INBOX §2) die Sätze tragen; was dort scheitert, fliegt hier raus.
2. **Neu messen.** Jeder Satz gegen den Code des Builds, der eingereicht wird — die Liste ist ein Datum.
3. **Kauf.** Wenn der In-App-Kauf `com.echoelmusic.app.pro` lebt (F-15), kommt ein Satz dazu, was er freischaltet
   (die Instrumente als Audio Units in anderen Apps; die Effekte sind frei). Preis und Wortlaut: du.
4. **Datenschutz-Label** (E14) muss zu „No account, no ads, no tracking“ und zum Mikrofon passen.
5. **Release Notes** gehen erst, wenn F-20 entschieden ist (was Nutzer der früheren App bei 11.0 sehen).

Gemessen mit `python3`: Zeichen für alle Felder, Bytes für Keywords (`len(s.encode())`); die Zahlen stehen an
jeder Überschrift.

## Englisch (en-US)

### en-US — Subtitle (30 Zeichen) · 28/30

```
Music workstation for iPhone
```

### en-US — Subtitle, Alternative · 29/30

```
Make songs on iPhone and iPad
```

### en-US — Promotional Text (170 Zeichen, ohne neues Release änderbar) · 161/170

```
Write, arrange, record and mix songs on iPhone and iPad: a built-in synth, drum kit and sampler, your Audio Unit instruments and effects, and WAV or MIDI export.
```

### en-US — Keywords (100 Bytes, Komma ohne Leerzeichen, kein Wort aus Name/Subtitle) · 88/100

```
daw,synth,sequencer,piano roll,drums,sampler,midi,auv3,mixer,launchpad,arranger,recorder
```

### en-US — Description (4000 Zeichen) · 3186/4000

```
Echoel is a music workstation for iPhone and iPad: instruments, effects, arrangement, a session view for live sets, mixing and export.

TRACKS AND SOUND
• Songs hold instrument, audio and return tracks (up to 32, 64 and 8). Add any kind, or add a drum track that comes with an empty one-bar pattern to fill. Recolour, mute, solo and delete tracks.
• The built-in 16-voice synth: six presets, four waveforms (sine, saw, square, triangle) and nine adjustable sound parameters.
• A synthesized eight-piece drum kit (kick, snare, clap, two toms, closed and open hi-hat, crash) on General MIDI drum note numbers.
• A sampler that plays an imported audio file (mixed to mono, up to ten minutes) across the keyboard, at its original pitch on C4.
• Installed third-party Audio Unit instruments that run in stereo. Their own interface appears on the track's Sound page, and their settings are saved with the song.
• An insert chain of up to eight effects on every track and the master: Echoel EQ, Compressor, Delay and Reverb, or installed stereo Audio Unit effects.

WRITE AND ARRANGE
• A piano roll for synth, sampler and plugin tracks: tap to add or remove a note, drag to move it, drag its right edge to change its length, on a grid from 1/4 to 1/32 or 1/8 and 1/16 triplets.
• A step grid for drum tracks, with one row for each kit piece. Tap a step to set or clear a hit, hold it for an accent.
• Arrange clips on a bar timeline: drag them in whole bars, duplicate them or take them off the timeline. Tap an audio track to import a file at a bar, then move it and trim either edge to the beat.
• A session grid launches clips and scenes on the next bar, the next quarter note or at once, stops a track or all session clips, and hands every track back to the arrangement.

MIDI
• Play any instrument track live from a MIDI keyboard or controller by USB, Bluetooth or network MIDI. The synth and plugin instruments follow pitch bend, the mod wheel and the sustain pedal; the drum kit and sampler play notes.
• Record a MIDI performance onto an armed instrument track. Each take becomes a new clip with its notes, pitch bend and controllers, as one undo step.
• MIDI Learn maps a knob or fader to a mixer control, a synth parameter or a built-in effect parameter.
• Send MIDI clock to the outputs you choose, or follow an external MIDI clock.
• Novation Launchpad Mini MK3, X and Pro MK3 become a window onto the session grid.

RECORD, MIX, EXPORT
• Record mono audio from the microphone or one interface input onto an armed audio track. Takes stay on the device.
• A channel strip for every track and the master, with fader, pan and a peak meter; sends to up to eight return tracks; any track can go to its own output pair of a multichannel interface.
• Draw automation for volume, pan, sends, synth parameters and the parameters of plugins on a track, or record it by moving the control while the song plays.
• Export the arrangement as a 24-bit, 48 kHz stereo WAV, with its loudness (LUFS) and true peak reported, or as a Standard MIDI File.
• Songs save automatically as .echoel files that the Files app shows, and a song sent by AirDrop opens in Echoel.

No account, no ads, no tracking.
```

## Deutsch (de-DE)

Die App spricht Englisch; die Beschreibung sagt es im ersten Absatz (Inbox F13, E4b).

### de-DE — Subtitle (30 Zeichen) · 28/30

```
Musik-Workstation für iPhone
```

### de-DE — Subtitle, Alternative · 25/30

```
Songs auf iPhone und iPad
```

### de-DE — Promotional Text (170 Zeichen, ohne neues Release änderbar) · 169/170

```
Songs auf iPhone und iPad schreiben, arrangieren, aufnehmen und mischen: Synth, Drumkit und Sampler, deine Audio-Unit-Instrumente und -Effekte, Export als WAV oder MIDI.
```

### de-DE — Keywords (100 Bytes, Komma ohne Leerzeichen, kein Wort aus Name/Subtitle) · 96/100

```
daw,synthesizer,sequenzer,pianoroll,drums,sampler,midi,auv3,mixer,launchpad,aufnahme,arrangieren
```

### de-DE — Description (4000 Zeichen) · 3612/4000

```
Echoel ist eine Musik-Workstation für iPhone und iPad: Instrumente, Effekte, Arrangement, eine Session-Ansicht für Live-Sets, Mischen und Export. Die Oberfläche ist auf Englisch.

SPUREN UND KLANG
• Ein Song hat Instrument-, Audio- und Return-Spuren (bis zu 32, 64 und 8). Jede Art lässt sich anlegen, auch eine Schlagzeugspur mit einem leeren Ein-Takt-Muster zum Füllen. Spuren umfärben, stummschalten, solo schalten und löschen.
• Der eingebaute Synth mit 16 Stimmen: sechs Presets, vier Wellenformen (Sinus, Sägezahn, Rechteck, Dreieck) und neun einstellbare Klangparameter.
• Ein synthetisches Schlagzeug mit acht Teilen (Kick, Snare, Clap, zwei Toms, geschlossene und offene Hi-Hat, Crash) auf den General-MIDI-Notennummern.
• Ein Sampler, der eine importierte Audiodatei (zu Mono gemischt, bis zu zehn Minuten) über die Tastatur spielt, in Originalhöhe auf C4.
• Installierte Audio-Unit-Instrumente anderer Hersteller, die in Stereo laufen. Ihre eigene Oberfläche erscheint auf der Sound-Seite der Spur, ihre Einstellungen werden mit dem Song gespeichert.
• Auf jeder Spur und dem Master eine Insert-Kette mit bis zu acht Effekten: Echoel EQ, Compressor, Delay und Reverb oder installierte Stereo-Audio-Unit-Effekte.

SCHREIBEN UND ARRANGIEREN
• Eine Pianorolle für Synth-, Sampler- und Plugin-Spuren: tippen setzt oder entfernt eine Note, ziehen verschiebt sie, ihre rechte Kante ändert die Länge, im Raster von 1/4 bis 1/32 oder in 1/8- und 1/16-Triolen.
• Ein Step-Raster für Schlagzeugspuren mit einer Zeile je Kit-Teil. Tippen setzt oder löscht einen Schlag, halten setzt einen Akzent.
• Clips auf einer Takt-Zeitleiste anordnen: in ganzen Takten ziehen, duplizieren oder von der Zeitleiste nehmen. Auf eine Audiospur tippen importiert eine Datei an einem Takt; danach verschieben und beide Kanten auf den Schlag kürzen.
• Ein Session-Raster startet Clips und Szenen auf den nächsten Takt, die nächste Viertel oder sofort, stoppt eine Spur oder alle Session-Clips und gibt jede Spur an das Arrangement zurück.

MIDI
• Jede Instrumentspur live von einem MIDI-Keyboard oder Controller spielen, über USB, Bluetooth oder Netzwerk-MIDI. Synth und Plugin-Instrumente folgen Pitch Bend, Modulationsrad und Sustain-Pedal; Schlagzeug und Sampler spielen Noten.
• Eine MIDI-Performance auf eine aufnahmebereite Instrumentspur aufnehmen. Jeder Take wird ein neuer Clip mit Noten, Pitch Bend und Controllern, als ein Rückgängig-Schritt.
• MIDI Learn legt einen Regler oder Fader auf ein Mixer-Bedienelement, einen Synth-Parameter oder einen Parameter der eingebauten Effekte.
• MIDI-Clock an die gewählten Ausgänge senden oder einer externen MIDI-Clock folgen.
• Novation Launchpad Mini MK3, X und Pro MK3 werden zum Fenster auf das Session-Raster.

AUFNAHME, MIX, EXPORT
• Mono-Audio vom Mikrofon oder einem Eingang des Interfaces auf eine aufnahmebereite Audiospur aufnehmen. Takes bleiben auf dem Gerät.
• Ein Kanalzug für jede Spur und den Master mit Fader, Pan und Spitzenpegel-Anzeige; Sends auf bis zu acht Return-Spuren; jede Spur kann auf ein eigenes Ausgangspaar eines Mehrkanal-Interfaces gehen.
• Automation für Lautstärke, Pan, Sends, Synth-Parameter und die Parameter von Plugins einer Spur zeichnen oder aufnehmen, indem man das Bedienelement bewegt, während der Song läuft.
• Das Arrangement als Stereo-WAV mit 24 Bit und 48 kHz exportieren, mit gemeldeter Lautheit (LUFS) und True Peak, oder als Standard-MIDI-Datei.
• Songs speichern sich selbst als .echoel-Dateien, die die Dateien-App zeigt, und ein per AirDrop gesendeter Song öffnet sich in Echoel.

Kein Konto, keine Werbung, kein Tracking.
```
