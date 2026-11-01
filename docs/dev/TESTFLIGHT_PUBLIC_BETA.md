# Öffentliche TestFlight-Beta — Echoel Studio: Go-Kriterien, kleiner Kreis, dann der Link

Ziel: ein **öffentlicher TestFlight-Link** (`https://testflight.apple.com/join/…`), den bis zu
1.000 Menschen mit iPhone oder iPad öffnen können. Davor kommt ein **kleiner Kreis echter
Tester**, und davor die **Go-Kriterien** in §0. Alles läuft im Browser unter
appstoreconnect.apple.com (Safari auf dem iPhone geht).

⛔ Bis 2026-11-01 beschrieb diese Datei die eingefrorene Alt-App (Build 10.79.505, Puls über die
Kamera, Genres, OSC). Seit 2026-10-19 trägt TestFlight **Echoel Studio 11.0.0**. Die Texte in §2
und §3 sind aus `fastlane/metadata/en-US/description.txt` genommen, der gegen
`ContentPipeline/CLAIMS.md` (Abschnitt „Echoel Studio 11.0.0" plus Nachträge 5 und 6) geprüft
ist — gekürzt, nicht erweitert.

## 0. TestFlight Go — wann Claude „Go" sagt

Founder 2026-11-01, 02:32: „Sage mir TestFlight Go, wenn wir wirklich ein Produkt haben, das
tausend Menschen begeistert und im Kern dem entspricht, was ich mir wünsche, für mich, für dich
und für alle, nach unseren gemeinsamen Axiomen."

**„Go" heißt: der öffentliche Link (§1, Schritt 7) darf an bis zu 1.000 Menschen.** Gesagt wird
es erst, wenn alle sechs Punkte erfüllt sind — gemessen, nicht geschätzt.

| # | Kriterium | Wie gemessen | Wer urteilt |
|---|---|---|---|
| G1 | **Stabil** | Drei Builds hintereinander auf dem Founder-iPhone ohne Absturz, ohne schwarzen Bildschirm, ohne eingefrorenes Menü; TestFlight zeigt für diese Builds 0 Abstürze | Gerät, TestFlight-Zahlen |
| G2 | **Gerätechecks** | Die fünf Checks des aktuellen Builds (`EchoelStudio/RELEASE`) alle „Ja"; offene Checks älterer Builds beantwortet oder bewusst gestrichen | Founder |
| G3 | **Erster Eindruck ohne Erklärung** | Drei Menschen, die Echoel nie gesehen haben, schaffen ohne Hilfe: in der ersten Minute Musik hören, eine Spur anlegen und spielen, das Stück als WAV exportieren. Sobald die Instrument-Seite (W12) ausgeliefert ist, zusätzlich: der Körper spielt hörbar mit | Founder schaut zu, hilft nicht |
| G4 | **Ehrlich nach außen** | Beta-Beschreibung, „What to Test", Website und Datenschutzseite sagen nur, was `ContentPipeline/CLAIMS.md` für Studio sagt; die App-Datenschutzangaben in App Store Connect passen zu `docs/privacy.html#studio` | Claude, vor jedem Go |
| G5 | **Echte Stimmen im kleinen Kreis** | 10–20 Menschen aus dem Umfeld des Founders testen eine Woche (externe Gruppe „Erste Tester", Einladung per E-Mail). Ihr Feedback kommt über TestFlight (Screenshot und Text) beim Founder an. Kein offener Blocker; die Mehrheit beantwortet die Frage in §3 Schritt 5 mit Ja | die Tester; der Founder liest |
| G6 | **Im Kern wir** | Die produktprüfbaren der neun Grundsätze (`docs/dev/FOUNDER_INBOX.md` GM34): **Privatsphäre** (kein Konto; nichts verlässt das Gerät ohne Schalter des Musikers) · **Zugang** (Hauptwege mit VoiceOver und großer Schrift bedienbar) · **kein Abo, keine Werbung, kein Tracking** · **keine Gesundheitsversprechen** (kein Wellness, keine Therapie, keine Heilwirkung) · **offene Standards** (offenes Song-Format, MIDI, OSC) | Claude prüft, Founder bestätigt |

**Was nie passiert:** Reviews schreiben oder erfinden, Tester anschreiben, Tester-Daten anfordern
oder auslesen. Echte Stimmen kommen nur von echten Menschen — über TestFlight oder per Mail an
den Founder.

**Reihenfolge:** G1–G4 und G6 erfüllt → Claude sagt „bereit für den kleinen Kreis" → der Founder
reicht ein (§1, Schritte 1–6, eine Woche G5) → Claude sagt „TestFlight Go" → Schritt 7.

Stand 2026-11-01 (letzter VALIDER Build 10028, der zwanzigste Upload läuft): G1 und G2 warten
auf das Gerät; G3 wartet auf das Gerät und auf W12; G4 vorbereitet (§2–§4); G5 braucht die
Tester (`FOUNDER_INBOX.md` GM37); G6 offen beim VoiceOver-Durchgang. Dieser Absatz ist ein
Datum, kein Zustand — vor jeder Aussage neu messen.

## 1. Einrichten (ca. 15 Minuten, einmal)

1. App Store Connect → **Apps** → Echoelmusic → Reiter **TestFlight**.
2. Links **Testinformationen** (Test Information) ausfüllen, Texte aus §2: Beta-App-Beschreibung ·
   Feedback-E-Mail · Marketing-URL · Datenschutz-URL · „Anmeldung nicht erforderlich" (die App
   hat kein Konto).
3. Unter **Externe Tests** auf **+** → Gruppe **„Erste Tester"** (für G5).
4. In der Gruppe **Builds** → **+** → den neuesten Studio-Build (Version 11.0.0) wählen → bei
   „Was zu testen ist" den Text aus §3 einfügen → **Zur Prüfung einreichen**.
5. Auf die **Beta-App-Prüfung** warten (meist 1–2 Tage; nur der erste Build einer Version wird
   voll geprüft, spätere Builds derselben Version meist sofort freigegeben).
6. In „Erste Tester" → **Tester** → **+** → E-Mail-Adressen eintragen. Das macht der Founder;
   Claude sieht und speichert sie nicht.
7. **Erst nach „TestFlight Go":** zweite Gruppe **„Public Beta"** → Build hinzufügen →
   **Öffentlicher Link** aktivieren → Tester-Limit **1.000** → Link kopieren.

**Danach:** jeder neue Build muss in jeder Gruppe einmal mit **+** hinzugefügt werden. Automatisch
ginge das nur über eine Änderung am Upload-Workflow (founder-gated) — dann bekäme JEDER Build
sofort alle Tester. Ein Build läuft nach **90 Tagen** ab.

## 2. Testinformationen (Englisch, zum Einfügen)

**Beta App Description**

> Echoel is a music workstation for iPhone and iPad: instruments, effects, a piano roll and a
> drum grid, an arrangement timeline, a session grid for live sets, audio and MIDI recording,
> mixing, automation and export. Your songs are files on your device in an open, documented
> format, and the app needs no account.
>
> No account, no ads, no tracking, no server of ours.
>
> Echoel is in active development. This is a pre-release beta: please tell us what works, what
> confuses you and what breaks.

**Feedback E-Mail:** echoel@tropicaldrones.com (dieselbe Adresse wie auf der Website)
**Marketing URL:** https://echoelmusic.com
**Privacy Policy URL:** https://echoelmusic.com/privacy

## 3. „What to Test" (Englisch)

> Thanks for testing Echoel!
> 1. Open the app and press Play. What do you hear in the first minute?
> 2. Add Track: an instrument track. Play it on the on-screen keys, then write a few notes in
>    the piano roll.
> 3. Put a clip on the timeline, add an effect (Add Effect), and export the song with
>    Export WAV….
> 4. Anything that confused you, or did not work? Take a screenshot in the app and choose
>    Share Beta Feedback, or write to echoel@tropicaldrones.com.
> 5. One question: would you recommend Echoel to a friend who makes music? Why, or why not?

⚠️ Ein Schritt zur Instrument-Seite (Körper spielt mit) kommt erst hinein, wenn W12 ausgeliefert
ist UND `ContentPipeline/CLAIMS.md` dafür einen Nachtrag hat — bis dahin ist der Kamera-Puls nur
Datenschutz-Offenlegung, kein Satz für Tester oder Werbung (CLAIMS, Nachtrag 6, letzte Zeile).
Die Wörter „Add Track", „Add Effect" und „Export WAV…" sind die Beschriftungen in der App
(`App/Views/TrackListView.swift`, `App/Views/EffectsView.swift`, `App/Views/StudioView.swift`);
ändert sich eine, zieht dieser Text mit.

## 4. Was im Promo-Text stehen darf — und was nicht

Quelle der Wahrheit ist `ContentPipeline/CLAIMS.md`, Abschnitt „Echoel Studio 11.0.0" plus
Nachträge 5 und 6. Kurz:
- **Ja:** „Beta auf TestFlight", die Workstation-Sätze aus `fastlane/metadata`, kein Konto, keine
  Werbung, kein Tracking, offenes Song-Format.
- **Nein:** „im App Store" (erst nach der Freigabe) · „läuft in AUM/Logic/GarageBand" · Wellness,
  Meditation, Entspannung, Schlaf, Fokus, Therapie, Medizin, Longevity · Heilfrequenzen ·
  „AI/KI", solange kein Modell läuft · „MPE" ohne „Ausgang" · Kamera-Puls als Werbesatz ·
  Video-Aufnahme · Abo, „Pro", Preis.
- Den Link nie mit einer Gesundheitswirkung bewerben.

## 5. Nach dem Go

- Link in die Bio von Instagram/TikTok und in den ersten Kommentar unter jedem Clip.
- Auf der Website ein „Join the beta"-Knopf auf `docs/index.html` — ein eigener kleiner Commit,
  Text gegen CLAIMS geprüft.
- Messen: TestFlight → Gruppe zeigt Einladungen, Installationen, Sitzungen und Abstürze je Build.
  Feedback liest der Founder; was daraus Arbeit wird, kommt als Satz in den Chat, nie als Kopie
  von Tester-Daten ins Repo.
