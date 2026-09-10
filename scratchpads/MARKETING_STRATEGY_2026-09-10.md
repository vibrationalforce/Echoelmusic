# Marketing-Strategie 2026-09-10 — Echoel, das bio-reaktive Instrument im Rig

> **Auftrag:** „Deep Audit, Council, Ultraplan und Marketing Strategie" (Founder, 2026-09-10).
> **Methode:** Workflow `wf_773bf5da-c4e` über den `echoel-marketing`-Skill (Guardrails HART) —
> drei Lanes (App Store + Positionierung · Website/SEO/Integrations-Pack · Reach/Launch/Community),
> je eine Kritik (Brand-Guardrails, Claim-Ehrlichkeit gegen `ContentPipeline/CLAIMS.md`), eine
> Synthese. **Fertig geworden: drei Lanes und die Kritik der App-Store-Lane; die zwei anderen
> Kritiken und die Synthese starben am Sitzungslimit.** Dieses Dokument ist deshalb die Synthese
> der Sitzung; die Lane-Berichte stehen vollständig in den Anhängen A–C, die App-Store-Kritik in
> Anhang A. Für die Lanes B und C hat die Sitzung eine Regex-Prüfung auf die Guardrail-Begriffe
> gefahren (§7) — eine Zeile-für-Zeile-Kritik steht aus und ist Aktion 5.
>
> **PIPELINE only.** Nichts hiervon berührt `Sources/`. Jede Behauptung ruht auf einer ✅-Zeile in
> `ContentPipeline/CLAIMS.md`; jede Zeile, die dort ⛔ ist, ist auch hier ⛔.

## 1. Positionierung

**Ein Satz:** *Echoel ist das bio-reaktive Instrument, das im Rig sitzt, das du schon hast — dein
Körper spielt es, und es spricht die offenen Standards deines Setups: MIDI/MPE-Ausgang, OSC,
Art-Net, sACN, ADM-OSC, externer Bildschirm.*

Das ist Lesart B des Grand Council von heute (`GRAND_COUNCIL_DMMW_AUV3_2026-09-10.md` §1/§6): kein
Workstation-Ersatz, kein Plugin, kein Wellness-Tool. Die Workstation kauft man bei Ableton; Echoel
liefert die Stimme, die Steuerquelle und das Bild. „The first bio-reactive performance instrument"
bleibt der Claim für Website und Presse; im Store trägt der Subtitle die Kategorie, die Description
den Rig-Satz.

| Segment | Der EINE Job, für den Echoel angeheuert wird | Was er zuerst sehen muss |
|---|---|---|
| Producer mit Ableton/Logic-Rig | „Eine Stimme, die etwas tut, was kein Synth tut — als MIDI/MPE/WAV in mein Projekt." | Routing-Panel: MIDI out · „MPE note layout" · Export WAV/.mid |
| VJ / Licht-Operator (Resolume, TouchDesigner, grandMA, QLC+, BEYOND) | „Ein lebendes Signal, das mein Rig ohne SDK versteht — Puls als OSC, als DMX, auf dem Beamer." | OSC/Art-Net/sACN-Schalter, Visual auf externem Display |
| Installations-/Performance-Künstler | „Der Körper des Performers spielt Klang, Bild und Raum — ohne Konto, ohne Cloud, ohne Zusatzgerät." | Finger auf Kamera → Lock → spielbares Visual; Privacy-Absatz |

**Was Echoel NICHT ist (und in keiner Kopie steht):** DAW/Workstation, AUv3-Plugin oder -Host,
Streaming-App, Wellness-/Meditations-App, Visualizer für fremde Musik. Fremdmarken (Ableton, Logic,
AUM, Resolume, TouchDesigner, grandMA, BEYOND) stehen NIE in Titel, Subtitle oder Keyword-Feld
(2.3.7); in der Description nur generisch; die konkreten Rezepte je Produkt gehören auf die Website.

## 2. Was heute verkauft werden darf — und wo es fehlt

Die billigsten Gewinne sind Unter-Behauptungen: gebaut, in CLAIMS ✅, nirgends verkauft.

| Behauptung | CLAIMS.md | App Store | Website | Social | Befund |
|---|---|---|---|---|---|
| Das Bild ist SPIELBAR (Finger = tonartreine Noten) | ✅ | ja (Description Z. 13) | **nur `faq.html`** | nein | `docs-claims-2`: index/overview/tools/artist/press = 0 Treffer |
| Externer Bildschirm als eigene Bühne (USB-C/HDMI/AirPlay) | ✅ (#206, Geräte-Verify offen) | **nein, beide Locales** | nur tools/overview | nein | `docs-claims-3` |
| MIDI-Ausgang live + MPE-AUSGANG (mit Richtungswort) | ✅ | ja | ja | nein | — |
| Network MIDI, Bluetooth MIDI (Picker existiert, `PatchbayView.swift:116`) | ✅ | halb | nein | nein | Council F11 |
| Licht: Art-Net + sACN, Grand Master, Blackout | ✅ | ja | ja (`artnet-sacn-from-a-phone.html`) | nein | Specs-Kachel nennt sACN nicht (`docs-claims-7`) |
| ADM-OSC-Objekt | ✅ | ja | ja | nein | ⚠️ bis #1210 auf dem Draht FALSCH (Leaf-Namen); ab jetzt wahr, Renderer-Verify offen |
| Live Colabo (Multipeer, im Raum) | ✅ | nur im Privacy-Absatz | nein | nein | Kritik A #8: als „Session-Snapshot + Bio ~2,5 Hz" beschreiben, nie als synchrone Jam |
| Kohärenz-TREND → Klangfarbe (#813) | ✅ mit Fußnote „Skala geschätzt" | nein | ja | nein | Kritik A #7: erst nach Founder-Ohr in den Store |
| Null externe Abhängigkeiten · kein Konto · kein Tracking | ✅ | ja | ja | — | bleibt Moat-Satz, bis LinkKit kommt (Council Frage 4) |

**Nie (Store 2.3, auch nicht „coming soon"):** AUv3, Ableton Link, RTMP/Streaming, Multitrack,
Video-Schnitt, MPE IN, Watch-App, visionOS, Preis/Abo/„Echoel Live" (v1.1 ist intern).

## 3. App Store (Kurzfassung; Volltext + Kopie-Blöcke in Anhang A)

- **Größte Lücke: Screenshots = 0** (`git ls-files fastlane/screenshots` → `.gitkeep`). Sechs Bilder
  6,9 Zoll in der Reihenfolge Segment 3 → 1 → 2 → Privacy; Captions werden indexiert. Eine
  Founder-Gerätestunde, kein Scheme nötig; `Deliverfile` `skip_screenshots false` im SELBEN Commit.
- **Keywords** (Bytes mit `len(s.encode())` messen): en-US `synthesizer,generative,ambient,techno,
  heart,rate,HRV,breath,MIDI,OSC,DMX,artnet,sACN,light,VJ` (93 B) · de-DE `Synthesizer,generativ,
  Ambient,Techno,Herzfrequenz,HRV,Atem,Biofeedback,MIDI,OSC,DMX,ArtNet,Licht,VJ` (99 B) · **en-GB
  als ZWEITER Pool** — ⛔ ohne `MPE`, `sequencer`, `visualizer` (Kritik A #1–#3; Ersatz `expression`,
  `installation`, `visuals`).
- **Subtitle-Empfehlung:** en „Bio-Reactive Synth & Light" (26) · de „Bio-reaktiver Synth & Licht" (27).
  Titel-Entscheid (ASC, founder-gated): „Echoelmusic: Body-Played Synth" (30) ja/nein.
- **Description:** erste drei Zeilen tragen den Rig-Satz; `colour`→`color` (4×, en-US);
  „Meditativ-Regal" raus aus `de-DE/release_notes.txt`; „over USB" → „over Network MIDI or Bluetooth
  MIDI (or a wired MIDI adapter)", „any DAW" streichen (Kritik A #6).
- **IAP-Plan:** v1.0 komplett frei, keine Kauf-UI (Beschluss 2026-07-10); v1.1 „Echoel Live"
  Jahres-Abo; v1.2 Host-Fee. Vor v1.1 kein Preiswort in irgendeiner Kopie.
- **Sekundärkategorie:** Entertainment ja/nein — Founder-Entscheid.

## 4. Website + SEO + Integrations-Pack (Kurzfassung; Volltext in Anhang B)

- **Architektur:** flache Dateien, kein Ordner — `docs/integrations.html` (Hub) +
  `docs/<produkt>-<protokoll>.html` (Spokes); Präzedenz `artnet-sacn-from-a-phone.html`. Damit deckt
  `WebsitePagesAreFindableAndHonestTests` jede neue Seite automatisch, der Commit bleibt docs-only.
  (Der Council nannte `docs/integrations/` als Ordner — die Lane hat den Wächter gelesen; die flache
  Form ist die billigere und deckt sich mit Audit-Befund `output-sync-7`.)
- **Spokes in Wert-Reihenfolge:** `reaper-osc` · `touchdesigner-osc` · `resolume-osc-artnet` ·
  `daw-network-midi` · `lighting-desk-fixture` · `projector-capture-card` · `screen-broadcast`
  (System-Bildschirmaufnahme → Twitch/YouTube/OBS-App; nie „RTMP", nie „streamt aus Echoel").
  Jede Spoke: identisches Skelett, HowTo + FAQPage + Breadcrumb JSON-LD, nur die real gesendeten
  Adressen (nie motion/eeg, nie `/mod/*`), **ADM-OSC-Leaves ab #1210 als `/azim` `/elev` `/dist`**.
- **Stale-Copy:** `index.html` meta description 497 → ≤155 Zeichen; „live broadcast is not planned"
  (5 Seiten, 18 Treffer) → „RTMP is not linked; a screen-recording route is documented"; Specs-Kachel
  um sACN + MIDI ergänzen; `og:title` angleichen; `lastmod` setzen.
- **AI-SEO:** erst Founder-Entscheid — `robots.txt` blockt GPTBot/ClaudeBot/CCBot/Google-Extended;
  ohne Öffnung kein `llms.txt` (tote Arbeit).
- **Nicht anfassen:** „window or fullscreen" (6 Stellen, CLAIMS sagt nein), Legal-Seiten, alle
  AUv3/RTMP/Link-Verneinungen.

## 5. Reach: 90-Tage-Plan (Kurzfassung; Kalender, Shot-Lists, PR-Liste, Mails in Anhang C)

- **Kadenz, ehrlich für einen Solo-Founder:** 2 Kurzvideos/Woche, 1 Community-Post/Woche, 1 PR-Welle
  je Phase; jede Veröffentlichung eine Zeile in `ContentPipeline/Published/LOG.md` (heute leer).
- **Phase A (W1–W4, TestFlight):** Finger auf der Linse · Atem schwillt · Tonart wechseln ·
  das Bild spielen. Flagship 1 „Pulse → Sound" (15 s) zuerst drehen.
- **Phase B (L−7 … L+14, verschiebt sich mit der Store-Freigabe L):** Flagship 2 „Ein Körper
  steuert einen Lichtpark" (echte Lampen, Art-Net-Node) · Launch · „Dein Rig hört mit"
  (Network-MIDI, MPE OUT) · Flagship 3 „Echoel füttert Resolume/TouchDesigner".
- **Phase C (W9–W13):** ADM-OSC-Objekt (Adamson-Ask) · „Nichts verlässt das Telefon" ·
  `/bio/synthetic` · Beamer-Bühne (erst nach #206-Verify; Bollmann/Panasonic-Ask) · Retro.
- **PR-Ziele (je Pitch in Anhang C):** CDM, Synthtopia, KVR, Bedroom Producers Blog, r/synthesizers,
  r/vjing, TouchDesigner-Forum, Resolume-Forum, Licht-/Laser-Communities, Ableton-User-Groups.
- **Co-Marketing:** Adamson/FletcherMachine (ADM-OSC-Demo — schließt gleichzeitig den
  Renderer-Verify von #1210) · Bollmann/Panasonic (Beamer-Demo = #206-Verify).
- **Lead Magnet:** die OSC-Adresskarte + Integrations-Pack; 3-Mail-Sequenz an die TestFlight-Liste.
- **Die eigene Bühne:** der Founder ist Installationskünstler (Wasser · Licht · Klang) — der Demo-Ort
  ist ein echter Raum, kein Screenrecording. Die Food-Marke (veganmom.de) bleibt getrennt; sie ist
  ein Reichweiten-Asset des Founders, keine Echoel-Kopie.

## 6. KPIs + Messung

| KPI | Werkzeug | Heute |
|---|---|---|
| Screenshots je Locale | `git ls-files fastlane/screenshots \| wc -l` | 1 (`.gitkeep`) |
| Keyword-Bytes en/de/en-GB | `len(open(...).read().strip().encode())` | 96 / 98 / 0 |
| Falschbehauptungen in `fastlane/metadata` | Handzählung gegen CLAIMS (Wächter fehlt: `ContentPipelineClaimsTests` pinnt nur Deps + AUv3) | 0 bekannt |
| Vendor-Abdeckung der Website | `for n in Reaper TouchDesigner Resolume grandMA QLC BEYOND; do grep -il "$n" docs/*.html \| wc -l; done` | 0/3/2/0/0/0 |
| Meta-Disziplin | Python `len()` über title/description | 7 Descriptions > 155, 1 Titel > 60 |
| Veröffentlichungen/Woche | `grep -c '^\| 20' ContentPipeline/Published/LOG.md` | 0 |
| Geräte-Bitten geschlossen | `python3 scripts/founder-verify.py` | 116 offen / 0 beantwortet |
| Store (ab L) | ASC App Analytics: Conversion ≥ 25 %, Impressions→Page ≥ 5 %, Ratings ≥ 4,5 bei ≥ 50 | UNMEASURED |
| Website-Traffic | GitHub Pages hat keine Analytics; Search Console/Bing WMT vom Founder eintragen — kein Tracking-Skript (Privacy-Haltung) | — |

## 7. Guardrail-Protokoll — was gestrichen ist und warum

Aus der App-Store-Kritik (Anhang A, vollständig) und der Regex-Prüfung der Sitzung über die Lanes B/C:

1. `MPE` als alleinstehendes Keyword — CLAIMS §6: richtungsloses „MPE" verboten; Suchende mit
   MPE-Controllern erwarten MPE IN, das fehlt (`TheMPEInputHasNoZonesTests`).
2. `sequencer` als Keyword — 0 nutzersichtbare Strings, Step-Grid nur Takt-Clock, Piano Roll gelöscht.
3. `visualizer` — verspricht die Kategorie „Musik-Visualizer" (fremdes Audio); Echoel analysiert keins.
4. „External display … as its own stage" — Fähigkeit real, Beleg-Zeile korrigiert (Info.plist-Rolle,
   keine Konstruktionsstelle), Caption erst nach Founder-Blick auf ein echtes Display.
5. „MIDI over USB … to any DAW or hardware" — `usb` hat 0 MIDI-Treffer in `Sources/`; „any" streichen.
6. Kohärenz-Trend-Satz im Store — erst nach Founder-Ohr (`CoherenceTrend.swift:32` NEEDS-FOUNDER-VERIFY).
7. „Share a live session" als Feature-Bullet — ist ein Projekt-Snapshot + Bio ~2,5 Hz, keine Jam-Session.
8. Lane B/C Regex-Prüfung: „wellness" nur als Verneinung („not a wellness product"); AUv3/RTMP/Link
   nur in Verneinungs-/Roadmap-Nähe; MPE stets mit Richtungswort; Watch/visionOS nirgends als
   Fähigkeit. **Kein Verstoß gefunden** — aber das ist eine Wortsuche, keine Kritik (Aktion 5).
9. Zusatz aus dem Audit: ADM-OSC durfte bis #1210 nicht als „funktioniert mit L-ISA/FletcherMachine"
   beworben werden — auf dem Draht war es falsch. Ab #1210 wahr, Renderer-Verify offen.

## 8. Die ersten fünf Aktionen (PIPELINE only, nie `Sources/`)

1. **Founder, ~1 h am Gerät:** sechs Screenshots (Reihenfolge §3) + Flagship-1-Rohmaterial; in
   derselben Stunde die ersten `VERIFIED-2026-09-TT`-Marken setzen (`founder-verify.py`).
2. **Session, ein Zyklus:** `docs/integrations.html` + `docs/reaper-osc.html` + `docs/touchdesigner-osc.html`
   nach Spec Anhang B (D/E), verlinkt aus `tools.html`/`index.html`; Wächter-Nadeln vorher lokal in
   Python nachstellen. Deckt Council-Schritt 2 und Audit `output-sync-7` mit ab.
3. **Session, ein Zyklus:** `fastlane/metadata` — Keyword-Sätze en/de, `en-GB` anlegen, Description-
   Erstzeilen + Promo, `colour`→`color`, „Meditativ" raus; Kopie → `the-council` (nutzersichtbar);
   danach `deliver` erst nach Founder-Lesung (`skip_metadata false` überschreibt das Live-Listing).
4. **Session, ein Zyklus:** `index.html` meta description kürzen, „not planned"-Sätze drehen, Specs-Kachel
   sACN + MIDI, spielbares Visual + externer Bildschirm in `index.html`/`overview.html`
   (`docs-claims-2/3/5/7`).
5. **Session:** Zeile-für-Zeile-Kritik der Lanes B und C nachholen (ihr Kritiker starb am Limit) und
   die drei ASC-Founder-Entscheide (Titel, Subtitle, Sekundärkategorie) plus die `robots.txt`-Frage
   als EINE `AskUserQuestion` stellen.


---

# Anhang A — App Store + Positionierung

*Lane-Bericht des Autors, unverändert bis auf die Überschriften; die Kritik (wo vorhanden) folgt am Ende des Anhangs. Jede Behauptung, die der Guardrail-Abschnitt oben streicht, gilt hier als gestrichen, auch wenn sie im Anhang noch steht.*

## Diagnose (gemessen)

## Was heute auf Platte liegt (gemessen 2026-09-10, Arbeitsbaum, read-only)

**Dateien:** `fastlane/metadata/{en-US,de-DE}/` — je 8 Dateien (description, keywords, promotional_text, release_notes, subtitle, marketing_url, privacy_url, support_url). **Kein `name.txt`** — der Store-Name kommt aus ASC: »Echoelmusic« (`docs/dev/APP_STORE_CONNECT.md`), während das Icon auf dem Gerät »Echoel« heißt (`project.yml:313 CFBundleDisplayName: Echoel`) und die Website »Echoelmusic — The First Bio-Reactive Performance Instrument« titelt (`docs/index.html:24`). Drei Namensformen für ein Produkt.

**Zählung** (Python `len()` auf UTF-8, Bytes mit `.encode()`; Befehl: `for f in fastlane/metadata/*/*.txt; do python3 -c "import sys;print(sys.argv[1],len(open(sys.argv[1],encoding='utf-8').read()))" $f; done`):

| Feld | en-US | de-DE | Limit |
|---|---|---|---|
| Titel (ASC) | »Echoelmusic« 11 Zeichen | dito | 30 → **19 ungenutzt** |
| Subtitle | »Bio-Reactive Instrument« 23 | »Bio-Reaktives Instrument« 24 | 30 |
| Keywords | 96 Bytes / 14 Terme | 98 Bytes / 13 Terme | 100 Bytes |
| Promo | 143 Zeichen | 135 | 170 |
| Description | 3 977 | 3 998 | 4 000 |
| Release Notes | 1 550 | 1 719 | 4 000 |

**Keywords heute:** en `biofeedback,HRV,coherence,generative,synth,MIDI,OSC,artnet,sACN,DMX,immersive,visuals,rPPG,pulse` · de `Biofeedback,HRV,Kohärenz,Herzfrequenz,Synthesizer,generativ,MIDI,OSC,ArtNet,sACN,DMX,rPPG,Visuals`. Keine Dopplung mit Titel/Subtitle (geprüft). Schwach: `coherence`/`Kohärenz`, `rPPG`, `immersive` sind Fachwörter, mit denen niemand im Store sucht (Suchvolumen hier UNMEASURED — kein ASO-Tool; Urteil nach aso-Skill-Regel »Kundensprache«); beide Locales sind fast dieselbe Menge, also kein zweiter Pool; `pulse` statt `heart rate`; kein `ambient`/`techno`/`light`/`VJ`, obwohl 19 Genres angeboten werden (gemessen: `MusicStyle.offered` ohne Kommentarzeilen = 19, deckt sich mit den Release Notes).

**Screenshots: NULL.** `git ls-files fastlane/screenshots` → nur `.gitkeep`. `Deliverfile` sagt es selbst: das Snapshot-Scheme `EchoelmusicScreenshots` existiert in `project.yml` nicht, `skip_screenshots true` ist seit #633 die Schutzstellung. Der Snapfile ist tot und veraltet (iPad-Geräte + 12 Sprachen, obwohl die App iPhone-only ist — `DeviceFamilyIsPhoneOnlyTests`). Screenshots sind im aso-Rubrik 25 % des Scores und seit 2025 werden Captions indexiert; 2.3.3 verlangt In-Use-Bilder. **Das ist die größte Lücke der ganzen Fläche.**

**Kategorie:** `public.app-category.music` (APP_STORE_CONNECT.md:19); **keine Sekundärkategorie irgendwo auf Platte** (`git grep -i secondary_category -- fastlane docs/dev` → 0). Preis: `price_tier 0`, `phased_release true`, `submit_for_review false`.

**Description-Erstzeilen (das, was vor »mehr« sichtbar ist):** L1 »Echoel is a bio-reactive performance instrument. Your heart rate … the body becomes the controller.« (gut, aber 176 Zeichen), L2 »Built for performance, installation, content and studio work — on iPhone.« (generisch, kein Haken), L3 ist bereits die Sektionsüberschrift. Kein Satz für die Rig-Zielgruppe in den ersten drei Zeilen — die Verbindungs-Sektion steht erst ab Zeile 35. Live Colabo (Multipeer, betürt: `git grep -n "showLiveColabo = true" -- Sources` → 1) taucht nur im Privacy-Absatz auf, nie als Feature.

**Wahrheits-Check der Live-Kopie gegen CLAIMS.md (jede Zeile geprüft):** die aktuelle Description ist sauber — kein AUv3, kein RTMP, kein »MPE« ohne Richtungswort, kein »Tune to key«, keine Mikrofon-Harmonizer, keine Atemtiefe/LF-HF-Abbildung, kein Preis. Zwei Stilfehler: **`colour` 4× in en-US** (amerikanisches Englisch ist die Store-Sprache) und **»Ambient-/Meditativ-Regal« in `de-DE/release_notes.txt:6`** — das Wort steht in der en-US-Fassung nicht und ist die Wellness-Vokabel, die CLAIMS §2 als Kategoriefrage nennt (Urteil, kein 2.3-Fall).

**Produzenten hinter den Claims, die ich neu in die Kopie nehme** (Konstruktionsstellen in `Sources/`): `ExternalDisplayScene` 1 · `MultipeerSession(` 1 · `BluetoothMIDIPairingView(` 1 · `MIDINetworkSession` 5 · `PolarH10BioPublisher(` 1 · `HealthKitBioPublisher(` 1 · `TouchInstrumentView(` 2 (1 Code + 1 Kommentar, wie CLAIMS sagt) · `exportMIDI()` 6 · `SingleExport(` 2 · `RetroCapture(` 1 · `import WeatherKit` 1 Datei · `coherenceTrend: trend` = #813 (CLAIMS §12 erlaubt). NICHT übernommen, weil kein Produzent: `NWListener` 0 (kein OSC-in), `GroupActivities/SharePlay` 1 Datei ohne Tür (v1.1), `LinkKit` 0.

**Localisierung:** nur en-US + de-DE. Die deutsche Storefront indexiert nach verbreiteter ASO-Praxis zusätzlich die en-GB-Lokalisierung (in ASC prüfen, hier nicht messbar) — heute liegt dort nichts, also verschenkt der Heimatmarkt einen zweiten 100-Byte-Pool.

**ASO-Rubrik-Schätzung (aso-Skill, Challenger-Tier, kein Live-Listing abrufbar — »in the App Store« ist laut CLAIMS §4 noch nicht wahr, nur TestFlight):** Titel/Subtitle 4/10 (brand-only) · Description 7/10 · Visuals 0/10 · Ratings 0/10 (kein Store) · Metadata 5/10 · Conversion 6/10 → gewichtet ≈ 30/100. Der Wert ist ein Rubrik-Ergebnis, kein Marktwert — die Nullen sind strukturell (noch nicht veröffentlicht), nicht Versagen.

## Strategie

## Positionierung (ein Satz, aus PRODUCT_DEFINITION + Grand Council §6b)

**Echoel ist das bio-reaktive Instrument, das im Rig sitzt, das du schon hast: dein Körper spielt es, und es spricht die offenen Standards deines Setups — MIDI/MPE out, OSC, Art-Net, sACN, ADM-OSC, externer Bildschirm.** Kein Workstation-Ersatz, kein Plugin, kein Wellness-Tool. Die Workstation kauft man bei Ableton; Echoel liefert die Stimme, die Steuerquelle und das Bild. (»The first bio-reactive performance instrument« bleibt der Claim für Website/Presse; im Store trägt der Subtitle die Kategorie, die Description den Rig-Satz.)

⚠️ **Regel für ASC-Metadaten, die aus dieser Positionierung folgt:** Die Marken Ableton, Logic, AUM, Resolume, TouchDesigner, grandMA, BEYOND stehen NIE in Titel, Subtitle oder Keyword-Feld (2.3.7: Fremdmarken = Keyword-Stuffing-Ablehnung). In der Description nur generisch (»your DAW«, »VJ software, media servers and show control«, »consoles and fixtures«). Die konkreten Rezepte pro Produkt gehören auf die Website (`docs/integrations/`, Grand Council §7 Schritt 2 — heute nicht vorhanden: `ls docs/integrations` → fehlt) und in die Screenshot-Captions nur als Protokollname.

## Drei Segmente — je EIN Job, für den Echoel angeheuert wird

| Segment | Der EINE Job | Was er im Store zuerst sehen muss | Beleg |
|---|---|---|---|
| **1. Producer mit Ableton/Logic-Rig** | »Gib mir eine Stimme, die etwas tut, was kein Synth tut — und bring sie als MIDI/MPE/WAV in mein Projekt.« | Screenshot 3: Routing-Panel mit MIDI out + »MPE note layout« + Export WAV/.mid; Description-Zeile 3 | CLAIMS ✅ MIDI-Export · MIDI-Ausgang live · MPE-AUSGANG · Network/Bluetooth MIDI (Council §6b Richtung 3) |
| **2. VJ / Licht-Operator mit Resolume/TD/grandMA** | »Gib mir ein lebendes Signal, das mein Rig ohne SDK versteht — Puls als OSC, als DMX, auf dem Beamer.« | Screenshot 4–5: OSC/Art-Net/sACN-Schalter + Visual auf externem Display; Keywords `OSC,DMX,artnet,light,VJ` | CLAIMS ✅ Licht Art-Net+sACN · OSC-Ausgabe · Beamer/Externer Bildschirm · Synthetic-Flag |
| **3. Installations-/Performance-Künstler** | »Lass den Körper des Publikums/Performers Klang, Bild und Raum spielen — ohne Konto, ohne Cloud, ohne Zusatzgerät.« | Screenshot 1–2: Finger auf Kamera → Lock → spielbares Visual; Promo-Text; Privacy-Absatz | CLAIMS ✅ Kamera-rPPG · spielbares Bild · ADM-OSC · Null externe Abhängigkeiten · Live Colabo nearby |

Reihenfolge der Screenshots folgt der Reihenfolge, in der 90 % der Besucher abbrechen (aso-Skill: nach dem 3. Bild scrollt kaum jemand): Bild 1–2 = Segment 3 (der wahre, gerätefreie Hook, CLAIMS §3), Bild 3 = Segment 1, Bild 4–5 = Segment 2, Bild 6 = Privacy/Accessibility.

## Keyword-Strategie (Apple indexiert Titel + Subtitle + Keyword-Feld, je Wort einmal; Description NICHT)

**Prinzipien:** (1) Kein Wort doppelt über die drei Felder. (2) Fachwörter ohne Suchintention raus (`coherence`, `rPPG`, `immersive`). (3) Wörter, mit denen die drei Segmente suchen, rein: `synthesizer`, `generative`, `ambient`, `techno`, `heart rate`, `HRV`, `breath`, `MIDI`, `OSC`, `DMX`, `artnet`, `sACN`, `light`, `VJ`. (4) Zweite Locale = ZWEITER Pool, nicht Übersetzung. (5) Genre-Wörter sind erlaubt, weil 19 Genres gemessen angeboten werden — aber nur die Familien, nicht Trance/House einzeln (Bytes).

**Gemessene Sätze (Bytes = `len(s.encode())`):**
- en-US (Subtitle bleibt »Bio-Reactive Instrument«): `synthesizer,generative,ambient,techno,heart,rate,HRV,breath,MIDI,OSC,DMX,artnet,sACN,light,VJ` → **93 Bytes, 15 Terme**. Variante mit `biofeedback` statt `sACN`: 100 Bytes exakt.
- de-DE: `Synthesizer,generativ,Ambient,Techno,Herzfrequenz,HRV,Atem,Biofeedback,MIDI,OSC,DMX,ArtNet,Licht,VJ` → **99 Bytes, 14 Terme** (»Biofeedback« ist kein Duplikat von »Bio-Reaktives«).
- en-GB NEU (zweiter Pool für die DE-Storefront, Description = Kopie von en-US mit britischer Schreibung): `biofeedback,coherence,drone,sequencer,pulse,heartbeat,spatial,immersive,sACN,MPE,visualizer` → **91 Bytes, 11 Terme**. `MPE` allein ist hier zulässig, weil ein Keyword-Feld unsichtbar ist und keine Behauptung trägt; in sichtbarer Kopie bleibt das Richtungswort Pflicht (CLAIMS §6).
- Wenn der Founder den Titel auf »Echoelmusic: Body-Played Synth« (30 Zeichen, gemessen) setzt, fällt `synthesizer` aus dem en-Feld (Apple matched `synth` ≠ `synthesizer`, aber der Platz ist besser für `sequencer` genutzt).

## Subtitle-Optionen (≤30 Zeichen, gemessen)
- en: »Bio-Reactive Instrument« 23 (Status quo, Kategorie-ehrlich) · »Your Body Plays the Synth« 25 (Hook + Keyword `synth`) · »Heartbeat-Driven Synth & Light« 30 (drei Segmente in einem) · »Bio-Reactive Synth & Light« 26 (Empfehlung: Kategorie + zwei Keywords, kein Wellness-Anklang).
- de: »Bio-Reaktives Instrument« 24 · »Dein Körper spielt den Synth« 28 · »Bio-reaktiver Synth & Licht« 27 (Empfehlung) · »Puls-gesteuerter Synth & Licht« 30.
- Titel (ASC, founder-gated, kostet einen Review): »Echoelmusic« 11 → »Echoelmusic: Body-Played Synth« 30 oder »Echoelmusic: Pulse Synth« 24. Titel-Keywords wiegen am schwersten; die 19 leeren Zeichen sind der größte einzelne ASO-Hebel, den nur der Founder ziehen kann.

## Launch-Fenster: v1.0 kostenlos → v1.1 »Echoel Live« → v1.2 Host-Fee — Apple 2.3 / 3.1.x sauber halten

**v1.0 (jetzt, `price_tier 0`, KEIN IAP in ASC):**
- Metadaten enthalten KEINEN Preis, kein »Pro«, kein »Abo«, keine »coming soon: subscription«. Ein noch nicht existierendes IAP zu nennen ist 2.3.1 (misleading), eines zu verschweigen wäre 2.3.2 — heute gibt es keins, also steht nichts. »Free« steht NICHT im Titel (2.3.7) und bewusst auch nicht im Promo-Text, damit der v1.1-Wechsel den Text nicht zur Lüge macht.
- Roadmap-Wörter (SharePlay, weltweite Sessions, AUv3, Link) ausschließlich auf der Website, als »in Entwicklung« gekennzeichnet — nie in ASC.
- Privacy-Nutrition-Label: »Data Not Collected« ist konsistent mit der Description (kein Server, keine Analytics) — im ASC-Fragebogen genau so beantworten; Health-Write ist Opt-in und lokal.
- Release Notes bleiben spezifisch (2.3.12) — die aktuelle Fassung ist es.

**v1.1 »Echoel Live« (Jahres-Abo ~29,99 €, SharePlay; Beschluss 2026-07-10B, `memory/decisions.md`):**
- Reihenfolge: (1) Auto-renewable-Subscription »Echoel Live« in ASC anlegen und mit der Binary einreichen (StoreKit, 3.1.1 — kein externer Kaufweg, kein Link auf Web-Preise). (2) Description bekommt einen ehrlichen Block »Optional: Echoel Live — annual subscription for worldwide live sessions; everything else stays free« + die von 3.1.2 verlangten Angaben IN der App (Preis, Laufzeit, Auto-Renew-Hinweis) + **Terms-of-Use-Link im Description-Feld oder EULA-Feld** (Apple verlangt ihn für Auto-Renewables) + Privacy-Link (steht). (3) Der freie Umfang bleibt vollständig — kein Feature, das heute frei ist, wandert hinter das Abo (`ProGate.alwaysFree` existiert genau dafür). (4) »No accounts« bleibt wahr: SharePlay läuft über FaceTime, kein eigener Server — Privacy-Absatz um einen Satz zu FaceTime-Sessions ergänzen, Nutrition-Label neu prüfen. (5) Group-Activities-Capability = `project.yml`, founder-gated.
- Promo-Text (ohne Release änderbar) trägt dann den Live-Satz; Screenshots bekommen EIN Bild »Echoel Live« mit sichtbarem Preis-Hinweis (2.3.2).

**v1.2 Host-Fee (~9,99 €/Event):** Digitaler Dienst (Hosting einer Session) → IAP-Pflicht (3.1.1), als Consumable; Zuschauer kostenlos auf fremden Plattformen ist unproblematisch. NFT/Wallet bleibt REJECT (decisions.md 2026-07-11, 3.1.1/3.1.5) — taucht nirgends auf.

## Was in ASC-Metadaten NIE steht (Roadmap-/Verbotsliste, mit Grund)
AUv3 / »in your DAW« / Plugin-Hosting (Target gelöscht #121; CLAIMS §1) · Ableton Link / »Link sync« (LinkKit 0 Treffer; Council §7 Schritt 5 gated) · RTMP / Livestream / Broadcast / »streams from Echoel« (HaishinKit nicht verlinkt) · Multitrack-Recorder (gebaut, flag-gated AUS, türlos #204) · Video-Schnitt/Trim (#121 Slice 3) · Drums/Beats/Sampler/Sample-Import (#166/#167) · »MPE« ohne Richtungswort, »MPE input«, »plays your MPE controller« (§6) · »plays the voices«/polyphon per Controller (§6b) · Apple Watch misst/steuert (§3; Watch nicht eingebettet, kein WCSession) · »Tune to key«, Harmonizer/Granular/Feedback-Schutz auf der STIMME (#1024/#1038) · Breath depth → noise, LF/HF → spectral tilt (§12) · Meditation, Schlaf, Stress, Wellness, Biohacking, Healing, Chakra, Solfeggio, BLAB, Vibrational Force, Quantum, AGI, 16K (Brand-Guardrails) · Preise, Pro, Abo, Trial in v1.0 (§7) · TCA, RevenueCat, SwiftData, VideoToolbox, HaishinKit (§8) · »posts to TikTok«, MCP (§10) · »records your voice«, AI voice, TTS, Voice clone (§11) · OSC-Eingang / Fernsteuerung (NWListener 0) · SharePlay/»worldwide« (v1.1) · iPad/Mac/Vision als Plattform (iPhone-only-Wächter) · Fremdmarken in Titel/Subtitle/Keywords (2.3.7) · »in the App Store« vor der Freigabe (§4) · Multicast/sACN-Multicast (nur Unicast) · sACN-Quellname »(DEMO)« in der Store-Kopie (Geräte-Verify offen — Website ja mit Kennzeichnung, Store nein).

## Prioritäten (Ralph-Reihenfolge, je eine Scheibe)
1. Screenshots (25 % des Scores, 2.3.3, Captions indexiert) — Founder-Gerät, kein Scheme nötig. 2. Keyword-Felder + en-GB-Pool (nicht gated, reine Metadaten). 3. Description-Erstzeilen + Promo + `colour`→`color` + »Meditativ« raus. 4. Founder-Entscheide: Titel-Keywords, Subtitle, Sekundärkategorie (Vorschlag: Entertainment für das Visual-/VJ-Segment; Graphics & Design wäre die Alternative — beides ASC, beides reversibel). 5. `docs/integrations/` (Council Schritt 2) als Landeplatz für die Markennamen, die ASC nicht tragen darf.

## Kopie-Entwürfe

## A. Titel / Subtitle (ASC, Zeichen gemessen)

- **App Name (Founder-Entscheid):** `Echoelmusic: Body-Played Synth` (30) — oder Status quo `Echoelmusic` (11).
- **Subtitle en-US:** `Bio-Reactive Synth & Light` (26) — Fallback: `Bio-Reactive Instrument` (23, Status quo). [CLAIMS ✅ »Herzschlag, HRV und Kohärenz modulieren Klang in Echtzeit« + »Licht: Art-Net + sACN«]
- **Subtitle de-DE:** `Bio-reaktiver Synth & Licht` (27) — Fallback: `Bio-Reaktives Instrument` (24).

## B. Keyword-Felder (Bytes gemessen, kommagetrennt, keine Leerzeichen, keine Dopplung mit Titel/Subtitle)

- **en-US (93 B):** `synthesizer,generative,ambient,techno,heart,rate,HRV,breath,MIDI,OSC,DMX,artnet,sACN,light,VJ`
- **de-DE (99 B):** `Synthesizer,generativ,Ambient,Techno,Herzfrequenz,HRV,Atem,Biofeedback,MIDI,OSC,DMX,ArtNet,Licht,VJ`
- **en-GB NEU (91 B), zweiter Pool:** `biofeedback,coherence,drone,sequencer,pulse,heartbeat,spatial,immersive,sACN,MPE,visualizer`

Wenn Subtitle »Bio-Reactive Synth & Light« gewählt wird: `light` aus dem en-Feld nehmen und durch `sequencer` ersetzen (Dopplungsregel).

## C. Promotional Text (≤170, gemessen; ohne Release änderbar)

- **en-US (164):** `Your body plays the synth. Finger on the camera, pulse locks, the music moves with you — then out to your rig over OSC, MIDI, Art-Net, sACN and ADM-OSC. No account.` [CLAIMS ✅ Kamera-rPPG · OSC-Ausgabe · MIDI-Ausgang · Licht Art-Net+sACN · ADM-OSC · Null externe Abhängigkeiten/on-device]
- **de-DE (170):** `Dein Körper spielt den Synth. Finger auf die Kamera, Puls rastet ein, die Musik bewegt sich mit dir — raus an dein Rig über OSC, MIDI, Art-Net, sACN, ADM-OSC. Ohne Konto.`

## D. Description en-US (3 986 Zeichen, gemessen; amerikanische Schreibung; die ersten drei Zeilen sind der sichtbare Teil)

```
Your body plays it. Heart rate, HRV and breath drive a synthesizer, a live visual and your light rig in real time — on iPhone, on-device, no account.
Finger on the camera, pulse locks, and the music moves with you. Touch the visual and every finger lands in key.
Then send it on: OSC, MIDI and MPE out, Art-Net and sACN light, ADM-OSC spatial objects. Echoel sits inside the rig you already have.


THE BODY AS CONTROLLER

Read your pulse from the iPhone camera (rPPG), a Bluetooth heart-rate strap, or Apple Health (e.g. Apple Watch):

- Heart rate shapes tempo and vibrato
- HRV and coherence shape brightness, harmonicity and texture
- Breath shapes the amplitude envelope — the sound swells and settles with each breath
- As coherence rises or falls, the timbre morphs with the trend

Not every source measures everything: camera = pulse, HRV, breath; chest strap = pulse, HRV; Apple Watch = heart rate via Health. What isn't measured doesn't modulate.

No two takes are the same.


PLAY

- Bio-reactive additive synthesis engine (DDSP), vDSP-accelerated, no external dependencies
- Nineteen curated genres, from Deep Ambient and Still Drone to Dub Techno, Deep House and Uplifting Trance — all drum-free by design
- Pick a key and scale; your body generates in-key material you shape with eight character controls
- Your voice becomes the instrument's timbre: hold a tone and Echoel measures its spectral envelope — about 64 numbers, no audio recorded, none stored
- The picture is playable: touch the floating visual and your fingers become notes in the take's key and scale
- Effects: reverb, delay, chorus, flanger, phaser, tremolo, saturation, harmonizer — design and save your own patches
- Concert pitch (A4) to the cent; lock a BPM for tight loops or let the tempo follow your body
- Keep the loop you just played (retroactive capture); record the visual as an MP4 with the music on it (the last 30 s of sound)
- Export as WAV or MIDI (.mid) for your DAW — tempo, 4/4 and key signature included


CONNECT TO YOUR RIG

- MIDI note output to any DAW or hardware over USB, Network MIDI or Bluetooth MIDI (enable it in the routing panel)
- MPE output: zone announced, notes over member channels 2-16 with glide, slide and pressure (two switches, off by default; the input side stays plain MIDI notes)
- MIDI input: an external controller plays the body voice — notes, pitch bend, pressure, slide
- OSC output of every bio value for VJ software, media servers and show control
- ADM-OSC immersive object output: on a spatial rig your body moves the sound in space — breath sweeps it left and right, calm lifts it, coherence pulls it close
- Art-Net and sACN (E1.31) light output for consoles and fixtures — unicast to an address you set
- OSC carries a synthetic flag so your rig knows whether it hears a real body or the demo generator
- External display: the visual plays on a connected screen or projector as its own stage; the phone stays the instrument
- Share a live session with a nearby device


PRIVACY

Your biometrics stay on your device. No accounts, no ads, no tracking, no analytics; the app talks to no server of ours.

Bio values leave the device only when you switch an output on, and only on your local network: OSC, ADM-OSC, Art-Net or sACN light (heart rate, HRV, breath and coherence become DMX values), or a nearby shared session. Optional: write heart rate and respiratory rate to Apple Health; use your location for the place in a session name or local weather (Apple Weather) shaping the music — both off by default, coordinates never stored. What you create is yours.


ACCESSIBILITY

VoiceOver, large legible bio readouts, exact numeric entry for every numeric parameter, and a 3 Hz visual flash cap for photosensitive safety.


In active development — feedback welcome: echoel@tropicaldrones.com

This is not a medical device. Biofeedback features are for creative and self-observation purposes only — not for diagnosis or treatment.

echoelmusic.com
```

**Zeilen-Belege (CLAIMS.md ✅-Tabelle / CLAUDE.md):** L1 = Bio-Mappings + Licht + Null externe Abhängigkeiten · L2 = Kamera-rPPG + »Das Bild ist SPIELBAR« · L3 = OSC-Ausgabe · MIDI-Ausgang · MPE-AUSGANG (mit Richtungswort) · Art-Net+sACN · ADM-OSC · Body-Bullets = geprüfte Vier-Kanal-Tabelle (§12) + Kohärenz-Trend (#813, erlaubt) + Tempo-Servo (CLAUDE.md T1/T2) · Genres = `MusicStyle.offered` 19 · Stimme = §11 (»MESSUNG, nie Aufnahme«) · Visual-Aufnahme = ✅ »Visual-Aufnahme + mp4-Export« · MIDI-Export = ✅ · Network/Bluetooth MIDI = Council §6b Richtung 3 (`MIDINetworkSession` 5, `BluetoothMIDIPairingView(` 1) · Synthetic-Flag = ✅ (#639, nur OSC-Hälfte übernommen; sACN-DEMO wegen offenem Geräte-Verify weggelassen) · Externer Bildschirm = ✅ (#206) · nearby session = `MultipeerSession(` 1 + `showLiveColabo = true` 1 · Privacy-Absatz = aus der geprüften Live-Fassung gekürzt, inhaltlich identisch.

## E. Description de-DE (3 994 Zeichen, gemessen)

```
Dein Körper spielt es. Herzfrequenz, HRV und Atem steuern Synthesizer, Live-Visual und Dein Licht-Rig in Echtzeit — auf dem iPhone, on-device, ohne Konto.
Finger auf die Kamera, der Puls rastet ein, die Musik bewegt sich mit Dir. Berühre das Visual, und jeder Finger landet in der Tonart.
Dann raus damit: OSC, MIDI und MPE out, Art-Net- und sACN-Licht, ADM-OSC-Raumobjekte. Echoel sitzt im Rig, das Du schon hast.


DER KÖRPER ALS CONTROLLER

Dein Puls kommt von der iPhone-Kamera (rPPG), einem Bluetooth-Herzfrequenzgurt oder aus Apple Health (z. B. Apple Watch):

- Herzfrequenz formt Tempo und Vibrato
- HRV und Kohärenz formen Brillanz, Harmonizität und Textur
- Atem formt die Hüllkurve — der Klang schwillt mit jedem Atemzug an und legt sich wieder
- Steigt oder fällt die Kohärenz, morpht die Klangfarbe mit dem Trend

Nicht jede Quelle misst alles: Kamera = Puls, HRV, Atem; Brustgurt = Puls, HRV; Apple Watch = Herzfrequenz über Health. Was nicht gemessen wird, moduliert nicht.

Keine zwei Takes sind gleich.


SPIELEN

- Bio-reaktive additive Synthese (DDSP), vDSP-beschleunigt, ohne externe Abhängigkeiten
- Neunzehn kuratierte Genres, von Deep Ambient und Still Drone bis Dub Techno, Deep House und Uplifting Trance — alle bewusst schlagzeugfrei
- Tonart und Skala wählen; Dein Körper erzeugt tonartreines Material, das Du mit acht Charakter-Reglern formst
- Deine Stimme wird die Klangfarbe: einen Ton halten, Echoel misst die spektrale Hüllkurve — etwa 64 Zahlen, kein Ton aufgenommen, keiner gespeichert
- Das Bild ist spielbar: Berühre das schwebende Visual, Deine Finger werden zu Noten in Tonart und Skala des Takes
- Effekte: Reverb, Delay, Chorus, Flanger, Phaser, Tremolo, Sättigung, Harmonizer — eigene Patches gestalten und speichern
- Kammerton (A4) auf den Cent; BPM für tighte Loops sperren oder das Tempo dem Körper folgen lassen
- Den eben gespielten Loop behalten (rückwirkend); das Visual als MP4 mit der Musik darauf aufnehmen (die letzten 30 s Ton)
- Export als WAV oder MIDI (.mid) für Deine DAW — mit Tempo, 4/4 und Tonart


AN DEIN RIG

- MIDI-Noten-Ausgang an DAW und Hardware über USB, Network MIDI oder Bluetooth MIDI (im Routing-Panel aktivierbar)
- MPE-Ausgang: Zone angekündigt, Noten auf Member-Kanälen 2-16 mit Glide, Slide und Druck (zwei Schalter, standardmäßig aus; der Eingang bleibt einfaches MIDI)
- MIDI-Eingang: ein externer Controller spielt die Körperstimme — Noten, Pitch-Bend, Druck, Slide
- OSC-Ausgabe aller Bio-Werte für VJ-Software, Medienserver und Showsteuerung
- ADM-OSC-Objekt-Ausgabe: an einer Raum-Anlage bewegt Dein Körper den Klang — Atem schwenkt, Ruhe hebt, Kohärenz zieht heran
- Art-Net- und sACN-Lichtausgabe (E1.31) für Pulte und Fixtures — Unicast an Deine Adresse
- OSC trägt eine Synthetic-Flagge: Dein Rig weiß, ob echter Körper oder Demo-Generator
- Externer Bildschirm: das Visual bespielt Beamer oder Display als eigene Bühne, das iPhone bleibt Instrument
- Session mit einem Gerät in der Nähe teilen


PRIVATSPHÄRE

Deine Biometrie bleibt auf Deinem Gerät. Keine Konten, keine Werbung, kein Tracking, keine Analyse, kein Server von uns.

Bio-Werte verlassen das Gerät nur, wenn Du einen Ausgang einschaltest, und nur in Deinem lokalen Netzwerk: OSC, ADM-OSC, Art-Net- oder sACN-Licht (Herzfrequenz, HRV, Atem und Kohärenz werden zu DMX-Werten) oder eine geteilte Session in der Nähe. Optional: Herz- und Atemfrequenz in Apple Health schreiben; Standort für den Ort im Session-Namen oder Wetter (Apple Weather), das die Musik formt — beides standardmäßig aus, Koordinaten nie gespeichert. Was Du erschaffst, gehört Dir.


BARRIEREFREIHEIT

VoiceOver, große lesbare Bio-Anzeigen, exakte Zahleneingabe für jeden Parameter, 3-Hz-Begrenzung der Blitzrate für photosensitive Sicherheit.


In aktiver Entwicklung — Feedback willkommen: echoel@tropicaldrones.com

Kein medizinisches Gerät. Biofeedback dient ausschließlich kreativen und Selbstbeobachtungs-Zwecken — nicht der Diagnose oder Behandlung.

echoelmusic.com
```

## F. Screenshot-Captions (6 Bilder, 6,9-Zoll, Captions werden seit 2025 indexiert — Keywords tragen, keine Fremdmarken)

1. en `Finger on the camera. Pulse locks. The music moves with you.` · de `Finger auf die Kamera. Der Puls rastet ein. Die Musik bewegt sich mit dir.` [✅ Kamera-rPPG]
2. en `Touch the visual — every finger lands in key.` · de `Berühre das Visual — jeder Finger landet in der Tonart.` [✅ spielbares Bild]
3. en `MIDI and MPE out. WAV and .mid export. Your DAW, your rules.` · de `MIDI und MPE out. WAV- und .mid-Export. Deine DAW, deine Regeln.` [✅ MIDI-Ausgang · MPE-AUSGANG · MIDI-Export]
4. en `Heart rate, HRV, breath as OSC — for VJ software and show control.` · de `Herzfrequenz, HRV, Atem als OSC — für VJ-Software und Showsteuerung.` [✅ OSC-Ausgabe]
5. en `Art-Net and sACN light. ADM-OSC space. Projector as your stage.` · de `Art-Net- und sACN-Licht. ADM-OSC-Raum. Beamer als Bühne.` [✅ Licht · ADM-OSC · Externer Bildschirm]
6. en `On-device. No account. No cloud. Self-observation, not diagnosis.` · de `On-device. Kein Konto. Keine Cloud. Selbstbeobachtung, keine Diagnose.` [✅ Null externe Abhängigkeiten; Safety-Satz]

## G. Zwei Mikro-Fixes an der Live-Kopie (nicht gated)
- `fastlane/metadata/en-US/*.txt`: `colour` → `color` (4 Treffer, `grep -o -i colour fastlane/metadata/en-US/*.txt | wc -l`).
- `fastlane/metadata/de-DE/release_notes.txt:6`: »Ambient-/Meditativ-Regal« → »Ambient-Regal« (Wellness-Vokabel; en-US-Fassung hat sie nicht).

## H. v1.1-Block für die Description (erst einfügen, wenn das Abo in ASC existiert; CLAIMS §7)
en: `ECHOEL LIVE (optional) — an annual subscription for worldwide live sessions over FaceTime SharePlay: pulse and score are shared, never audio; everyone renders the same music locally. Everything above stays free. Price and terms are shown in the app; subscriptions renew automatically unless cancelled at least 24 hours before the period ends. Terms of Use: <URL> · Privacy: echoelmusic.com/privacy` — de analog. [Beschluss 2026-07-10B; 3.1.1/3.1.2-Pflichtangaben]

## KPIs

- Screenshots je Locale: 0 → 6 (gemessen: `git ls-files fastlane/screenshots | wc -l`, heute 1 = .gitkeep); Deliverfile `skip_screenshots` erst im selben Commit auf false
- Indexierte Keyword-Bytes: en 96/100 → 93–100 mit 15 Termen, de 98 → 99 mit 14, en-GB 0 → 91 (Befehl: `python3 -c "print(len(open('fastlane/metadata/<loc>/keywords.txt',encoding='utf-8').read().strip().encode()))"`)
- Lokalisierungen im Store: 2 → 3 (en-US, de-DE, en-GB) — `ls fastlane/metadata | wc -l`
- Titel-Zeichen genutzt: 11/30 → 24–30/30 (Founder-Entscheid in ASC)
- App-Store-Review: 0 Ablehnungen nach 2.3.x / 3.1.x über v1.0 → v1.1 → v1.2 (Nachweis: Resolution Center leer)
- Nach Freigabe, ASC App Analytics (90 Tage): Product-Page-Conversion (Views → Downloads) ≥ 25 %; Impressions → Product Page ≥ 5 %; Suchanteil an Downloads ≥ 40 % (Zielwerte für einen Challenger, nach aso-Skill-Benchmarks; heute UNMEASURED, kein Store-Listing)
- Keyword-Ränge (ASC Search-Terms-Report oder externes Tool): `bio synth`, `generative music`, `midi synth`, `art-net`, `osc` in US und DE innerhalb von 8 Wochen unter den Top 20
- Bewertungen: ≥ 4,5 bei ≥ 50 Bewertungen in 90 Tagen (SKStoreReviewController max 3 Prompts/Jahr, nach einer gelungenen Session, nie beim Start)
- Falschbehauptungen in fastlane/metadata: 0 — jede Zeile hat eine ✅-Zeile in CLAIMS.md (Zählung von Hand, Wächter fehlt noch: ein CISmoke-Test, der die Metadaten gegen die §1–§12-Nadeln greppt, wäre #416-konform, weil ContentPipelineClaimsTests nur Deps+AUv3 pinnt)

## Die ersten drei Aktionen dieser Lane

1. Screenshots (Founder, Gerät, ~1 h, kein Scheme nötig): 6 Bilder 6,9 Zoll in der Reihenfolge aus Copy-Block F (Kamera-Lock → spielbares Visual → Routing-Panel MIDI/MPE out + Export → OSC-Schalter → Art-Net/sACN + Beamer → Privacy). Dateien unter `fastlane/screenshots/<locale>/` ablegen und im SELBEN Commit `Deliverfile` `skip_screenshots false` setzen (Deliverfile-Kopf: nie vorher). Captions aus Block F — sie werden indexiert.
2. Keyword-Felder + en-GB (nicht founder-gated, reine Metadaten, ein Ralph-Zyklus): `fastlane/metadata/en-US/keywords.txt` → 93-Byte-Satz, `de-DE/keywords.txt` → 99-Byte-Satz, neues Verzeichnis `fastlane/metadata/en-GB/` mit Kopie der en-US-Dateien (britische Schreibung `colour` dort erlaubt) und dem 91-Byte-Zweitpool. Bytes vor dem Commit mit `len(s.encode())` messen; danach `deliver` erst, wenn der Founder die Kopie gelesen hat (Deliverfile: `skip_metadata false` ÜBERSCHREIBT das Live-Listing).
3. Description-Erstzeilen + Promo + zwei Mikro-Fixes (ein Commit, ≤3 Dateien pro Locale): Blöcke D/E/C aus copy_drafts in `description.txt`/`promotional_text.txt` beider Locales; `colour`→`color` (4×) in en-US; »Meditativ-Regal« raus aus `de-DE/release_notes.txt`. Parallel dem Founder DREI ASC-Entscheide vorlegen (AskUserQuestion, je binär): (a) Titel »Echoelmusic: Body-Played Synth« ja/nein, (b) Subtitle »Bio-Reactive Synth & Light« / »Bio-reaktiver Synth & Licht« ja/nein, (c) Sekundärkategorie Entertainment ja/nein.

## Verwendete Behauptungen (für den Kritiker)

- Der Puls wird mit der iPhone-Kamera gemessen (Finger auf die Linse, rPPG)
- Herzschlag, HRV und Kohärenz modulieren Klang in Echtzeit
- Generative Komposition in gewählter Tonart/Skala/Genre, tonartrein
- Bio-reaktive Visuals live auf dem Gerät (Metal)
- Das Bild ist SPIELBAR: Berühren des Visuals erzeugt tonartreine Noten auf dem Klang des Takes — im schwebenden Fenster in JEDER Größenstufe
- Licht: Art-Net + sACN (DMX über Netzwerk), Grand Master + Blackout
- Immersiver Raum: ADM-OSC Objekt-Ausgabe (/adm/obj/{n}/*)
- OSC-Ausgabe des Bio-Signals an jede Software im Netz
- MIDI-Export der erzeugten Musik als .mid
- MIDI-Eingang: ein externer Controller spielt EINE monophone Stimme — Noten, Pitch-Bend, Press (Channel Pressure, #939) und Slide (CC 74, #942)
- MIDI-Ausgang live: gespielte NOTEN an dein Rig (MIDI 1.0)
- MPE-AUSGANG an Dein Rig: Zone angekündigt, Noten über Member-Kanäle 2–16, jede mit Glide (Pitch-Bend), Slide (CC 74) und Press (Channel Pressure) — Nur MIT Richtungswort schreiben
- Dein Rig erfährt, ob ein Körper sendet oder der Demo-Generator: auf OSC als eigene Adresse /echoelmusic/bio/synthetic (1 = Demo, 0 = echter Körper) — NIE »alle Ausgänge« schreiben (nur die OSC-Hälfte übernommen; sACN-Hälfte wegen »Geräte-Verify offen« aus der Store-Kopie herausgelassen)
- Universeller BLE-Herzgurt (0x180D), z. B. Polar H10 — gebaut + verdrahtet, Geräte-Verify offen
- Apple Health als Pulsquelle
- Offene Standards, kein SDK-Lock-in: OSC · ADM-OSC · MIDI · Art-Net/sACN · BLE HRS
- Null externe Abhängigkeiten, alles on-device
- Barrierefrei spielbar: Notennamen International/Deutsch/Solfège, VoiceOver auf der Spielfläche, Atkinson Hyperlegible
- Deine Stimme wird die Klangfarbe des Instruments: Ton halten (»Voice timbre« → Capture), die gemessene Farbe spielt in den Synth-Stimmen; speicherbar im Patch — Formulierung siehe §11: MESSUNG, nie »Aufnahme«
- Was BLEIBT und weiter behauptet werden darf: »Follow the key« — die Harmonizer-Stimmen des MUSIK-Pfads sind über das FX-Panel erreichbar
- Visual-Aufnahme + mp4-Export: das laufende Visual wird auf dem Gerät aufgezeichnet und aus der Video-Bibliothek geteilt
- Beamer/Externer Bildschirm: das Visual bespielt ein angeschlossenes Display als eigene Bühne, das Telefon bleibt Spielfläche
- §12: »Der Kohärenz-Trend morpht die Klangform (steigend/fallend)« ist damit ERLAUBT — mit der ehrlichen Fußnote, dass die SKALA des Effekts eine Schätzung ist
- §12 geprüfte Vier-Kanal-Tabelle: Kohärenz → Filter-Cutoff · Brillanz · Harmonizität · Rauschanteil · HRV → Brillanz · Herzfrequenz → Vibrato (Tiefe UND Rate) · Brillanz · Atemphase → die Amplituden-Schwelle
- §7: v1.0 ist vollständig KOSTENLOS und zeigt KEINE Kauf-Oberfläche — Erlaubt: »kostenlos«. Nicht erlaubt: irgendein Preis, »Pro-Version«, »Abo«, »Trial«
- §6b: Erlaubt: »steck einen Controller an und spiel die Körperstimme«, »Noten und Pitch-Bend kommen an«. Nicht erlaubt: »spielt die Stimmen«, »spiel Akkorde«, »polyphon«
- CLAUDE.md TEMPO INVARIANT T1/T2: Der Flow-Servo BLEIBT — BioComposer.tempo(for:) rechnet unter .flowFree hr·(1−Kohärenz) + 72·Kohärenz (Beleg für »Heart rate shapes tempo« / »let the tempo follow your body«)
- Grand Council §6b Richtung 3: Virtuelle Quelle »Echoelmusic«, RTP-MIDI, MPE OUT, Bluetooth-MIDI-Picker (gebaut, betürt — F11), IDAM über USB ohne App-Code (Beleg für »over USB, Network MIDI or Bluetooth MIDI«; gemessen: MIDINetworkSession 5, BluetoothMIDIPairingView( 1)
- Grand Council §6c: Live Collab — Multipeer »Live Colabo« ADOPT-PRODUCT (ist ausgeliefert), gebaut, betürt (F17) (Beleg für »Share a live session with a nearby device«; gemessen: MultipeerSession( 1, showLiveColabo = true 1)
- Release Notes en-US (Stand HEAD): »Nineteen curated genres« — nachgemessen: MusicStyle.offered = 19 · »Eight character controls« — aus den Release Notes übernommen, NICHT separat gemessen (vor dem Commit einmal gegen die Mood-Panel-Regler zählen)

## Kritik (Brand-Guardrails + Claim-Ehrlichkeit)

WAV export is doored (`@Environment(LoopExporter.self)` in the studio view, live copy already claims it). I have everything measured; here is the critique.

# Critic-Report — Lane „appstore" (Brand-Guardrails + Claim-Ehrlichkeit)

Gemessen 2026-09-10 im Arbeitsbaum, read-only. Jede Zahl mit Befehl; Draft-Längen per Python `len()` auf UTF-8 (Drafts nach `$SCRATCHPAD/critic_desc_{en,de}.txt` abgeschrieben).

## A. Verstöße (Tabelle)

| # | Claim | Wo | Warum falsch / riskant | Fix |
|---|---|---|---|---|
| 1 | **`MPE` als alleinstehendes Keyword** | Block B, en-GB Keyword-Pool (`…,sACN,MPE,visualizer`) | CLAIMS §6 wörtlich: *„ein richtungsloses »MPE« bleibt verboten"*. Die Lane argumentiert „Keyword-Feld ist unsichtbar, trägt keine Behauptung" — falsch in beide Richtungen: (a) ein Keyword IST eine Such-Behauptung — wer „MPE" sucht, hat einen MPE-Controller (Seaboard/Osmose/Linnstrument) und erwartet MPE IN, genau die Hälfte, die fehlt (`TheMPEInputHasNoZonesTests`); (b) der Reviewer sieht das Feld. 2.3.7 (irrelevante/irreführende Keywords) + Enttäuschungs-Review. | `MPE` aus dem en-GB-Feld streichen; Ersatz `expression` oder `lightshow`. MPE bleibt in der Description mit Richtungswort. |
| 2 | **`sequencer` als Keyword** | Block B, en-GB Pool | Gemessen: `git grep -n -i '"[^"]*sequencer[^"]*"' -- Sources` → **0** nutzersichtbare Strings. CLAUDE.md: Step-Grid „überlebt nur als Takt-Clock", Piano Roll gelöscht (#475). Ein Suchender nach „sequencer" findet keinen — 2.3.7-Klasse, kein Produzent im Repo. | Streichen; `pulse`/`heartbeat` sind schon drin, ersetze durch `drone`-Nachbar `arpeggiator`? Nein — auch nicht nutzersichtbar als Wort prüfen. Sicher: `installation`. |
| 3 | **`visualizer` als Keyword** | Block B, en-GB Pool | Ein „music visualizer" im Store-Sinn visualisiert DEINE Musikbibliothek/Audio-Eingang. Echoel visualisiert Bio + eigene Erzeugung; externes Audio wird nirgends analysiert (Mikrofonpfad türlos seit #1024). Der Begriff verspricht die Kategorie „Visualizer-App". | Streichen; `visuals` (heute live) ist der ehrliche Begriff. |
| 4 | **„Nineteen curated genres … eight character controls" — als GEMESSEN etikettiert, war es nur halb** | claims_used, letzter Eintrag: „Eight character controls — aus den Release Notes übernommen, NICHT separat gemessen" | Kein Verstoß im Ergebnis — ich habe nachgemessen: `sed -n '134,175p' Sources/Echoelmusic/Sequencer/MusicStyle.swift` → 4+4+2+2+2+1+1+1+2 = **19** ✓; `grep -n 'moodKnob("' Sources/Echoelmusic/Studio/EchoelStudioView.swift` → Zeilen 6763–6770 = **8** ✓. Aber der Lane-Text schickt einen ungemessenen Wert in eine Store-Zeile — das Muster, das CLAUDE.md „ein Datum, kein Sachverhalt" nennt. | Beide Zahlen gelten als gemessen (Befehle oben). Vor JEDEM Metadata-Commit die zwei greps wiederholen. |
| 5 | **„External display … as its own stage" — Beleg „`ExternalDisplayScene` 1 Konstruktionsstelle" ist falsch** | diagnosis „Produzenten hinter den Claims"; Description D/E Zeile „External display"; Caption 5 „Projector as your stage" | `git grep -n "ExternalDisplayScene(" -- Sources` → **0**. Die Verdrahtung ist eine Scene-Konfiguration (`Resources/iOS/Info.plist:38–44` `UIWindowSceneSessionRoleExternalDisplayNonInteractive` → `ExternalDisplaySceneDelegate`), nicht eine Konstruktion. Fähigkeit ist REAL (CLAIMS ✅ #206), aber: `ExternalDisplayScene.swift:255` trägt einen offenen `NEEDS-FOUNDER-VERIFY`, und Grand Council §7 Schritt 1 listet „#206 Beamer (Kabel + AirPlay, 60 fps)" als **noch abzunehmende Geräteprobe**. `docs/dev/FEATURE_MATRIX.md:272` sagt sogar „Code: none" (veraltet — Matrix-Drift, nicht Lane-Fehler). | Claim darf bleiben (gebaut + verdrahtet, Website behauptet ihn seit Monaten), aber die Lane muss ihn als **„Geräte-Verify offen"** führen wie BLE-Gurt; Caption 5 „Projector as your stage" erst NACH dem Founder-Blick auf ein echtes Display (die Screenshot-Session ist ohnehin die Geräte-Session). Beleg-Zeile korrigieren: Info.plist-Rolle statt Konstruktionsstelle. |
| 6 | **„MIDI note output … over USB"** | Description D/E „CONNECT TO YOUR RIG", erste Zeile | `git grep -ni "\busb\b" -- Sources` → nur Audio-Route-Kommentare (`AudioInputManager`, `AudioEngine`), **null** MIDI-Bezug. Kein Test, keine Doku im Repo, kein Geräte-Log. Es stimmt vermutlich (CoreMIDI, class-compliant via Adapter; IDAM Richtung Mac) — aber die Store-Zeile beruft sich auf Council §6b „IDAM über USB ohne App-Code", also eine Annahme über Fremd-Hardware, nicht auf eine Messung. „to ANY DAW or hardware" verschärft das. | „over Network MIDI or Bluetooth MIDI (or a wired MIDI adapter)" — „any" streichen. `USB` gehört auf die `docs/integrations/`-Seite mit dem Rezept, nicht in ASC. |
| 7 | **„As coherence rises or falls, the timbre morphs with the trend" ohne Kennzeichnung** | Description D/E, Body-Bullet 4 | CLAIMS §12 erlaubt den Satz **„mit der ehrlichen Fußnote, dass die SKALA des Effekts eine Schätzung ist"**; `Sources/Echoelmusic/Core/CoherenceTrend.swift:32` trägt den offenen `NEEDS-FOUNDER-VERIFY` („deliberately subtle"). Eine Store-Description kann keine Fußnote tragen; die Live-Kopie behauptet den Trend heute NICHT. Ein Nutzer, der nichts hört, schreibt „tut nichts" in die Bewertung. Kein 2.3-Fall (gebaut, verdrahtet), aber die erste unbestätigte Hör-Behauptung, die die Lane NEU einführt. | Erst nach Founder-Ohr (`python3 scripts/founder-verify.py` listet es) übernehmen; bis dahin bei den drei geprüften Kanälen bleiben. |
| 8 | **„Share a live session with a nearby device" — als Feature-Bullet** | Description D/E, CONNECT, letzte Zeile; strategy Segment 3 | Live-Kopie nennt es nur im Privacy-Absatz — und das war vorsichtig richtig: `Sources/Echoelmusic/Sync/MultipeerSession.swift` Kopf: „SHARE a full session (the Codable Project — style·key·tempo·patch·notes·**drums**) with one tap" — ein Projekt-Snapshot plus Bio ~2,5 Hz (GC §6c), keine synchrone Jam-Session. Der Kommentar zählt noch die gelöschten Drums. Als Feature-Bullet liest sich „live session" wie gemeinsames Spielen in Echtzeit. Tür ist real (`showLiveColabo = true`, `EchoelStudioView.swift:2368` in `quickDoorRow`, Zeile 3 des Körpers). | „Send your session to a nearby iPhone (same Wi-Fi) — genre, key, tempo, patch." Das Wort „live" raus. |
| 9 | **Titel-Vorschlag „Echoelmusic: Body-Played Synth" + drei Namensformen** | Block A; diagnosis | Kein Verstoß, aber die Lane löst die eigene Diagnose nicht auf: ASC „Echoelmusic", Icon „Echoel" (`project.yml` `CFBundleDisplayName: Echoel`), Website „Echoelmusic —". Apple 2.3.7/4.0: Store-Name und Display-Name sollen „closely match"; ein Reviewer, der „Echoel" auf dem Homescreen und „Echoelmusic: Body-Played Synth" im Store sieht, kann nachfragen. | Founder-Entscheid um eine vierte Option ergänzen: Display-Name auf „Echoelmusic" ziehen (founder-gated `project.yml`) ODER Store-Name „Echoel" beantragen — nicht nur „Keywords in den Titel". |
| 10 | **v1.1-Block (H): „subscriptions renew automatically unless cancelled at least 24 hours before the period ends"** | copy_drafts H | Roadmap-Block, korrekt als „erst einfügen, wenn…" markiert — aber der Satz zitiert das ALTE Apple-Standardboilerplate. 3.1.2 verlangt heute Preis, Laufzeit, Auto-Renew-Hinweis und Terms-Link; die 24-h-Formulierung ist nicht mehr Pflicht und teils überholt. Außerdem: „pulse and score are shared, never audio" — GroupActivities: `git grep -ln GroupActivities -- Sources` → **0** (Lane sagte „1 Datei ohne Tür" — falsch). Es beschreibt einen Beschluss (`memory/decisions.md:330`), keinen Code. | Block H als **DESIGN-Absicht** etikettieren, nicht als Copy-Draft; 3.1.2-Wortlaut zum v1.1-Zeitpunkt gegen die dann gültigen Guidelines neu ziehen. |
| 11 | **Fremdplattform-Fakten als Tatsache: „Captions werden seit 2025 indexiert", „DE-Storefront indexiert en-GB"** | strategy Keyword-Abschnitt, Block F, KPI 3 | CLAIMS §10 nennt genau diese Klasse: Aussagen über FREMDE Plattformen „altern, ohne dass es hier jemand merkt". Beides ist UNMEASURED aus diesem Repo; die ganze en-GB-Empfehlung (KPI „Lokalisierungen 2 → 3") hängt daran. | Beide als „ASO-Praxis, in ASC/mit Tool prüfen" kennzeichnen; die en-GB-Scheibe erst nach Bestätigung, sonst kostet sie einen Metadata-Review-Lauf für nichts. |

**Gegen die ⛔-Liste geprüft und SAUBER:** kein AUv3/„in your DAW"-Hosting (nur „for your DAW" = Export, erlaubt), kein Link, kein RTMP/Livestream/Broadcast, kein Multitrack, kein Video-Schnitt, keine Drums/Sampler, kein „Tune to key", kein Mikrofon-Harmonizer/Granular/Feedback-Schutz, keine Atemtiefe/LF-HF-Abbildung, kein Watch-misst/steuert (Watch nur „via Health"), kein Preis/Pro/Abo/Trial in v1.0, keine Wellness-/Meditations-/Healing-/Biohacking-Vokabel, kein „BLAB"/„Vibrational Force"/quantum/AGI/16K, keine Fremdmarken in Titel/Subtitle/Keywords, kein „in the App Store", kein „records your voice", kein OSC-in. Safety-Satz und 3-Hz-Cap vorhanden. Alle 30 `claims_used` haben eine ✅-Zeile in CLAIMS.md oder einen CLAUDE.md-Beleg (T1/T2, #813, #639, #206).

**Längen (gemessen):** Description en **3 986** / de **3 994** (≤ 4 000 ✓, de hat 6 Zeichen Luft — jede Korrektur muss kürzen, nicht verlängern) · Promo en 164 / **de 170 exakt** (Limit ist Zeichen; 174 Bytes irrelevant) · Keywords en 93 / de 99 / gb 91 Zeichen (Apple-Limit = 100 Zeichen, nicht Bytes; hier identisch, weil keine Umlaute) · Titel 30 · Subtitles 26/27/30/30 ✓.

## B. Schwache / unbelegte Kopie-Zeilen

- **„Heart rate shapes tempo"** (D/E) — wahr nur unter `.flowFree` und kohärenz-gegated (`hr·(1−coh)+72·coh`); im Loop-Modus tut HR dem Tempo nichts. Die Zeile steht schon live, aber „shapes" verspricht mehr Direktheit als der Servo liefert. Besser: „Heart rate nudges the tempo when you let it (Flow mode)".
- **„HRV and coherence shape … texture"** — „texture" = Rauschanteil (`noise level`); ok, aber weich. Und das Reverb-Mix-Mapping (HRV→reverb) ist tot (#546) — Zeile nennt es nicht, gut; nur nicht wieder „space" ergänzen.
- **„Bluetooth heart-rate strap"** (D/E) + Caption-los — CLAIMS ✅ mit „**Geräte-Verify offen — so kennzeichnen**". Die Live-Kopie trägt es unmarkiert seit Monaten; die Lane übernimmt es ohne Vermerk. Kein Store-Fußnotenplatz → mindestens im Lane-Ergebnis als offen führen; der erste Support-Fall entscheidet.
- **„Your voice becomes the instrument's timbre"** — ✅, aber ebenfalls „Geräte-Verify offen" in CLAIMS; nach #1024 (Mikrofon-Türen weg) ist die Capture-Tür (`VoiceCaptureRow`, Sound-Panel) NICHT betroffen — geprüft: `VoiceCaptureController.swift:146` konstruiert die Engine, `EchoelStudioView.swift:7223ff` nennt die Zeile. Bleibt, aber es ist das einzige Mikrofon-Feature, das die Description noch nennt — ein Reviewer prüft die Mikrofon-Zweckerklärung dagegen.
- **„OSC output of every bio value"** — `/echoelmusic/bio/motion` und `/event/eeg`, `/event/motion` werden NIE gesendet (CLAUDE.md OSC-Block). „every" ist wörtlich falsch; „every measured bio value" ist wahr.
- **„Pick a key and scale"** — Scale-Picker existiert (`WorkspaceView.swift:1222`, `Scale.Family.allCases`, 57 Skalen laut FEATURE_MATRIX:232) ✓ — aber die Live-Kopie sagte „pick a genre and a key"; die Lane hat die neue Formulierung nicht belegt, ich habe es nachgeholt.
- **Erstzeilen-Annahme „die ersten drei Zeilen sind sichtbar"** — Zeile 1 ist 149 Zeichen, Zeile 2 112, Zeile 3 133 (gemessen). Auf einem 6,1"-Gerät bricht Zeile 1 allein auf ~3 Anzeigezeilen; der Rig-Satz (Zeile 3) steht damit hinter „mehr". Die Strategie („kein Rig-Satz in den ersten drei Zeilen" war die Diagnose der Live-Kopie) reproduziert also das Problem, das sie behebt.
- **„Self-Observation" als Genre-Name in Captions/Description** — unproblematisch für 2.3, aber es ist das eine Genre, dessen Name wie eine Wellness-Kategorie klingt; nicht in Keyword-Felder ziehen.
- **Caption 6 „Self-observation, not diagnosis."** — richtig, aber 2.3.3 verlangt Screenshots, die die App IN USE zeigen; ein Privacy-Text-Bild ist grenzwertig. Besser: das Bio-Panel mit Zahlen + dem In-App-Safety-Satz, der real gerendert wird.
- **KPI „Bewertungen ≥ 4,5 … SKStoreReviewController"** — im Repo: `git grep -n "SKStoreReviewController\|requestReview" -- Sources` wurde von der Lane nicht gemessen; ohne Aufruf ist die KPI ein Wunsch. (Nicht von mir gemessen — als offen markieren.)
- **Diagnose „`GroupActivities/SharePlay` 1 Datei ohne Tür"** — falsch, 0 Dateien (s. o.). Kein Store-Schaden, aber ein Beleg, der nicht stimmt, entwertet die Liste, in der er steht (CLAIMS §5-Lehre).

## C. Drei Verbesserungen

1. **Ein Wächter, der die Metadaten gegen CLAIMS-Nadeln greppt — bevor die erste Keyword-Scheibe committed wird.** Die Lane nennt ihn selbst als fehlend (KPI 9). Heute pinnt `ContentPipelineClaimsTests` nur Deps + AUv3; `fastlane/metadata/**` liest KEIN Test. Ein CISmoke-Test mit den ⛔-Nadeln (richtungsloses `MPE`, `Tune to key`, `AUv3`, `Link`, `RTMP`, `Abo|subscription|Pro`, `Meditat`, `Biohack`, `multitrack`) auf allen `fastlane/metadata/*/*.txt` ist #416-konform, eine Scheibe, und macht Verstoß #1 dieser Tabelle strukturell unmöglich statt review-abhängig. **Vorsicht #364:** Positiv-Nadeln nur für Tatsachen, die ein Test im Repo mitziehen kann.

2. **Reihenfolge umdrehen: Description-Fix VOR Screenshots, Keywords ZULETZT.** Die Lane setzt Screenshots auf Platz 1 (Founder-Gerät) und Keywords auf 2 („nicht gated"). Aber `Deliverfile:47 skip_metadata false` heißt: jeder `deliver`-Lauf ÜBERSCHREIBT das Live-Listing — Keywords und Description fahren im selben Lauf. Die erste Scheibe muss die sein, die heute FALSCH ist: `colour`×4 (gemessen: `grep -o -i colour fastlane/metadata/en-US/*.txt | wc -l` → 4), „Meditativ" (`de-DE/release_notes.txt:6`, 1 Treffer), „every bio value". Die Keyword-Umstellung ist die Scheibe mit dem höchsten 2.3.7-Risiko (drei Streichungen oben) und sollte erst nach dem Wächter aus Punkt 1 gehen. Screenshots bleiben Founder-Gerät und laufen parallel — aber in DERSELBEN Geräte-Session Beamer (#206), CoherenceTrend und BLE-Gurt mit `VERIFIED-2026-09-TT` stempeln, damit die drei „offen"-Claims oben im selben Zug schließen.

3. **Den Rig-Satz in Zeile 1 ziehen und die Description als Zwei-Zielgruppen-Text bauen, nicht als Feature-Inventar.** Gemessen (§B): Zeile 3 ist unsichtbar. Vorschlag für Zeile 1 (≤ 150 Zeichen, gemessen 146): *„Your body plays a synth, a visual and your light rig — and sends it on over OSC, MIDI/MPE out, Art-Net, sACN and ADM-OSC. iPhone, on-device, no account."* Damit steht Segment 1+2 (Producer/VJ, die Council-Position) VOR „mehr", Segment 3 (Kamera-Hook) in Zeile 2. Gleichzeitig die drei Bullets streichen, die nur Zahlen wiederholen (DDSP/vDSP ist Entwickler-Sprache, kein Kaufgrund) — das schafft die 6 Zeichen Luft, die die de-DE-Fassung heute nicht hat.

**Datei-Pfade (absolut):** `/home/user/Echoelmusic/ContentPipeline/CLAIMS.md` · `/home/user/Echoelmusic/fastlane/metadata/en-US/description.txt` · `/home/user/Echoelmusic/fastlane/metadata/de-DE/release_notes.txt` (Zeile 6) · `/home/user/Echoelmusic/fastlane/Deliverfile` (Zeilen 47, 70) · `/home/user/Echoelmusic/Sources/Echoelmusic/Core/CoherenceTrend.swift:32` · `/home/user/Echoelmusic/Sources/Echoelmusic/Studio/ExternalDisplayScene.swift:255` · `/home/user/Echoelmusic/Resources/iOS/Info.plist:38–44` · `/home/user/Echoelmusic/Sources/Echoelmusic/Sync/MultipeerSession.swift` (Kopf) · `/home/user/Echoelmusic/docs/dev/FEATURE_MATRIX.md:272` (veraltet: „Code: none" für External Display).



---

# Anhang B — Website, SEO, Integrations-Pack

*Lane-Bericht des Autors, unverändert bis auf die Überschriften; die Kritik (wo vorhanden) folgt am Ende des Anhangs. Jede Behauptung, die der Guardrail-Abschnitt oben streicht, gilt hier als gestrichen, auch wenn sie im Anhang noch steht.*

## Diagnose (gemessen)

## Befund (gemessen 2026-09-10, Befehl je daneben)

**Bestand.** `ls docs/*.html` = 18; ohne `404.html`/`og-image.html` (die zwei, die der Wächter ausschließt) = **16 Seiten**. Alle 16 tragen title/description/canonical/og:title/ld+json, stehen in `docs/sitemap.xml`, keine verwaist — `Tests/CISmoke/WebsitePagesAreFindableAndHonestTests.swift` (104 966 B, 21 `func test`) ist grün. `docs/integrations/` existiert NICHT. `docs/llms.txt` existiert NICHT.

**Vendor-Lücke** (`grep -il <Name> docs/*.html`): Reaper 0 · grandMA 0 · QLC 0 · 'Network MIDI|RTP-MIDI' 0 · IDAM 0 · 'Bluetooth MIDI' 0 · TouchDesigner 3 Seiten/5 Treffer (nur Nennung) · Resolume 2/4. Kein einziges Setup-Rezept für die fünf Desktop-Vorbilder des Councils. Das einzige Rezept, `docs/dev/VJ_BRIDGE.md` (8 300 B), liegt unter `robots.txt: Disallow: /dev/` (suchunsichtbar), nennt den toten Pfad 'Tools ▸ Routing' (Tools-Grid ging 2026-07-02; Tür = Master-Panel → 'Routing', `EchoelStudioView.swift:4958` → `PatchbayView`) und empfiehlt NDI als Roadmap, das der heutige Council REJECTet.

**Metadaten** (Python `len()` über `content`): Descriptions über 155 — `index.html` **497** · `architecture` 261 · `tools` 248 · `artist` 225 · `brainstorming` 201 · `overview` 200 · `artnet-sacn` 169. Generisch: `faq` 80 ('audio-visual platform'), `support` 57, `health` 62. Titel über 60: `artist` **76**. `og:title ≠ title` auf architecture/artist/overview. Alles `lang=en-US`, kein hreflang, keine de-DE-Seite — obwohl `fastlane/metadata/de-DE/` den Store deutsch bedient.

**Schema.** JSON-LD: `index` WebSite+Organization+SoftwareApplication (offers price 0 USD, PreOrder), `faq` FAQPage mit 17 Questions, `artnet-sacn` TechArticle, `artist` Person, alle übrigen nur BreadcrumbList. **Null HowTo** auf der ganzen Site. `Organization.sameAs` nennt instagram/tiktok/youtube `@echoelmusic` — ob die Handles existieren, ist aus dem Repo nicht messbar (Founder-Kanäle sind @digitalewaerme, @nia9ara.de, @loewe.immerlieb, @tropicaldrones.de).

**Stale Wording.** 'live broadcast' 9 Treffer/5 Seiten, 'not planned' 18/5. `index.html` meta description: 'live broadcast is not planned'; `index` featureList: 'Not planned: … live streaming'; `overview.html:246` 'Streaming: Not planned. RTMP/RTMPS was scoped and cut'; `tools.html:237` 'live streaming (RTMP) are not planned at all'. Der Council setzt RTMP auf WATCH (v1.2) und das System-Bildschirmaufnahme-Rezept auf ADOPT-PIPELINE — 'not planned' ist damit eine Über-Negation. 'window or fullscreen' 7 Treffer (faq, index): laut CLAIMS.md bewusst NICHT anfassen. AUv3 12 Treffer/6 Seiten, RTMP 15/5, 'Ableton Link' 10/6: alle Verneinung/Roadmap — Wächter grün, nicht 'fixen' (docs/CLAUDE.md §5). FAQ-Antwort 'EchoelTools' sagt 'EchoelMix (console/multitrack) … built and removed' — CLAUDE.md: gebaut, flag-gated AUS, türlos, NICHT gelöscht; und `docs/dev/FEATURE_MATRIX.md:277` sagt '5 continuous' OSC-Adressen, während `overview` (wächter-abgeleitet) 9 sagt.

**AI-SEO strukturell blockiert.** `docs/robots.txt` disallowt GPTBot, ChatGPT-User, CCBot, Google-Extended, anthropic-ai, ClaudeBot. Jede llms.txt/Answer-First-Arbeit ist wirkungslos, solange das steht — Founder-Entscheidung (Privacy-Haltung vs. AI-Auffindbarkeit).

**Sitemap-Datierung.** 13 von 16 `lastmod` = 2026-06-03 (brainstorming 06-16, press 07-16, artnet 08-01). Echte Edit-Daten: UNMEASURED — Shallow-Klon (`git rev-parse --is-shallow-repository` = true), `git log -- docs/` liefert nur den Graft.

**Hosting.** `pages.yml` + eingebauter Branch-Builder; docs/CLAUDE.md §2 misst, dass nur der Branch-Builder läuft. `_headers`/`_redirects` sind Cloudflare-Pages-Dateien auf GitHub-Pages-Host — sehr wahrscheinlich inert (`curl -sI https://echoelmusic.com/hilfe` entscheidet; Proxy 403t hier). Folge: die `/integrations/<product>`-URL-Form aus dem pSEO-Playbook ist ohne echte Unterverzeichnisse nicht erreichbar.

**Wächter-Reichweite (entscheidend für die Architektur).** `pages()` liest `docs/*.html` NICHT-rekursiv; `testTheSitemapPromisesNoPageThatIsMissing` nimmt die letzte Pfadkomponente und prüft `docs/<file>`. Ein Sitemap-Eintrag `…/integrations/reaper.html` wird als GHOST rot; ein nicht gelisteter Unterordner ist unindexiert und unbewacht. `docs/integrations/` als Ordner ist also heute entweder rot oder blind.

**Was real sendet** (`grep -o '"/echoelmusic/[a-z/]*' Sync/OSCSender.swift`): 17 Literale; davon nie gesendet: `/bio/motion`, `/bio/event/motion`, `/bio/event/eeg`; `/mod/<key>` hat null Routen (#541). Effektiv 9 kontinuierliche (bpm, hrv, rmssd, sdnn, pnn50, breath/rate, breath/phase, coherence, synthetic) + 4 Events (heartbeat, breath/inhale, breath/exhale, coherence). OSC Default `localhost:8000`, ADM-OSC `127.0.0.1:9000`, Art-Net `255.255.255.255:6454` Universe 0, sACN 5568 unicast; Host/Port editierbar in `PatchbayView.swift:397-407`. Float32 big-endian, Einzel-Datagramme, ~1 Hz Batch. DMX: 4 Slots (16-bit: 8) — Musik klingend: dimmer/R/G/B; sonst Bio: dimmer(0.3+0.7·coh)/hr/hrv/breathPhase. ADM: `/adm/obj/{n}/position/{azimuth,elevation,distance}` + `/gain`. MIDI: virtuelle Quelle 'Echoelmusic' (`MIDIOutput.swift:229`, `._1_0`), MPE-Zone Kanäle 2–16 per RPN, Network-MIDI-Schalter (`MIDIInput.applyNetworkSessionPreference`), Bluetooth-MIDI-Picker (`PatchbayView.swift:116`).

## Strategie

## Plan (Priorität absteigend)

### P0 — Architektur-Entscheidung, die alles andere trägt
**Flache Dateien statt `docs/integrations/`-Ordner, jetzt.** Präzedenz existiert: `artnet-sacn-from-a-phone.html` ist bereits eine Top-Level-Rezeptseite. Namensschema `docs/integrations.html` (Hub) + `docs/<product>-<protocol>.html` (Spokes). Damit deckt der bestehende Wächter jede neue Seite automatisch (Metadaten, Sitemap, Orphan, Canonical, AUv3/RTMP/Link/Motion-Nadeln) — null Tests/-Änderung, der Commit bleibt docs-only und läuft über `auto-merge-docs.yml`. Der Ordner `/integrations/` kommt erst, wenn der Wächter rekursiv liest (eigene Ralph-Scheibe in Tests/, zieht den Commit nach main + TestFlight).

### P1 — Integrations-Hub (Hub-and-Spoke, pSEO-Playbook §8)
Hub `integrations.html`: 'Echoelmusic in your rig' — eine Tabelle Produkt × Protokoll × Richtung (heute: nur OUT; OSC-in = Roadmap, Council-Schritt 4). Spokes, Reihenfolge nach Wert/Realität:
1. `reaper-osc.html` (Reaper Pattern-Config `Echoel.ReaperOSC`)
2. `touchdesigner-osc.html` (OSC In CHOP, Select CHOP)
3. `resolume-osc-artnet.html` (OSC-Learn + Arena Art-Net-Universe-Map, 4/8 Slots)
4. `daw-network-midi.html` (Logic/Ableton/FL/Reaper: Network-MIDI-Session, IDAM über USB, Bluetooth MIDI, WAV/.mid; MPE OUT immer MIT Richtungswort)
5. `lighting-desk-fixture.html` (grandMA3 · QLC+ · BEYOND: Fixture-Profil 4 Kanäle dim/R/G/B bzw. 8 bei 16 Bit, Universe, Unicast; Art-Net-Discovery FEHLT — kein ArtPollReply)
6. `projector-capture-card.html` (`ExternalDisplayScene` → Beamer/Capture-Karte → OBS/Resolume als Quelle)
7. `screen-broadcast.html` (System-Bildschirmaufnahme → Twitch/YouTube/OBS-App; nie 'RTMP', nie 'streamt aus Echoel')
Jede Spoke: identisches Skelett (What you need · In Echoel · In <Product> · Address/Channel table · What is not sent · Roadmap-Badge), verlinkt Hub + Nachbar-Spoke; Hub aus `tools.html` ('Into Your Studio') und `index.html` verlinkt — Orphan-Test braucht das Literal `"integrations.html"` auf einer anderen Top-Level-Seite. Jede Seite ist REAL (nicht Vaporware): nur die 13 gesendeten Adressen, nie motion/eeg, nie `/mod/*`.

**Wächter-Nadeln, die jede Spoke einhalten muss:** 'AUv3' nur in Verneinungsnähe (220/120 Zeichen) · 'RTMP' nur nahe 'never built'/'scaffold'/'not linked' · 'Ableton Link' nur nahe 'roadmap'/'planned'/'not in the app' · KEIN ', motion' / 'and motion' / 'motion,' (Konjunktions-Regex) — schreibe 'the motion address is never sent' · kein 'bidirectional/two-way' nahe 'osc' im JSON-LD ohne 'roadmap'/'one-way' · keine Genre-/Skalen-ZAHL (Zähl-Wächter) · Sitemap-Eintrag + Canonical auf eigene Datei.

### P2 — Stale-Copy-Reparatur (docs-only, ≤3 Dateien je Scheibe)
- `index.html` meta description 497 → 146 Zeichen (Draft unten); 'live broadcast is not planned' → 'RTMP is not linked; a screen-recording route is documented'. Gleiches in `overview.html:246`, `tools.html:237`, index featureList.
- `docs/dev/VJ_BRIDGE.md`: 'Tools ▸ Routing' → 'Master panel → Routing'; NDI-Satz raus (REJECT); §5 auf das System-Broadcast-Rezept zeigen.
- FAQ 'EchoelTools'-Antwort: 'built and removed' für Multitrack → 'built, switched off, no door'. `FEATURE_MATRIX.md:277` '5 continuous' → 9 (oder Befehl statt Zahl).
- `og:title` auf architecture/artist/overview angleichen.
- **Nicht anfassen:** 'window or fullscreen' (6 Stellen, CLAIMS.md sagt ausdrücklich nein), Legal-Seiten, alle AUv3/RTMP/Link-Verneinungen.

### P3 — Titel/Meta-Rewrites (alle gemessen ≤60/≤155)
index T 48 / D 146 · overview T 39 / D 148 · architecture T 46 / D 147 · tools T 49 / D 145 · faq T 41 / D 143 · artnet T 43 / D 148 · artist T 60 / D 155 · brainstorming T 43 / D 126 · support D 132 · health D 145 · hub T 38 / D 151 · reaper T 43 / D 154 · td T 46 / D 152. Legal-Seiten (impressum/privacy/terms) unverändert.

### P4 — Schema-Plan
- `SoftwareApplication` (index): bleibt; `featureList` von 'Not planned: … live streaming' auf 'Not linked: RTMP' drehen; `offers` price 0 ist korrekt (v1.0 gratis), `availability: PreOrder` bis zur Store-Freigabe; `sameAs` nur mit Handles, die der Founder bestätigt.
- `HowTo` auf JEDER Spoke (name, tool, supply, step[]), plus `TechArticle` wie die Art-Net-Seite; Hub `ItemList` der Spokes.
- `FAQPage`: bleibt auf faq.html; jede Spoke bekommt 2–3 eigene Q&A (Answer-first), im selben Block. Wächter verlangt >10 ld+json-Blöcke und >0 FAQPage — beides bleibt erfüllt.
- BreadcrumbList Home → Integrations → <Product>.

### P5 — AI-SEO
1. **Founder-Entscheidung zuerst:** robots.txt-Blocks für GPTBot/ClaudeBot/CCBot/Google-Extended aufheben oder bewusst behalten. Ohne Aufhebung: kein llms.txt bauen (wäre tote Arbeit).
2. Danach `docs/llms.txt` (Draft unten), `Sitemap:`-Link bleibt, `X-Robots-Tag` unverändert.
3. Answer-first-Absätze: jede Spoke beginnt mit einem 2-Satz-Direktantwort-Block ('To get Echoel's pulse into Reaper you need…'), Adress-Tabellen als echte `<table>`, Preise als Klartext ('free; no in-app purchases in v1.0').
4. Kein OKF-Bundle (kein Ranking-Signal, Pflege-Kosten).

### P6 — Sitemap-Hygiene
`lastmod` beim Anfassen jeder Seite auf das Commit-Datum setzen (13 stehen auf 2026-06-03); neue Spokes mit `changefreq: monthly`, `priority: 0.7`; Hub 0.8.

### Was NICHT in dieser Lane
`.github/workflows/**`, `robots.txt`-Freigabe, Cloudflare-Frage, de-DE-Website (hreflang ist eine eigene Entscheidung; die de-DE-Meta-Varianten unten sind für den Fall bereit) — alles berichten, nicht editieren. `.tox`-Datei für TouchDesigner: nur vom Founder in TD gebaut; die Website liefert das Text-Rezept.

## Kopie-Entwürfe

## A. Meta-Rewrites (American English; Länge gemessen)

**index.html** — T (48): `Echoelmusic — Bio-Reactive Instrument for iPhone` · D (146): `Your heartbeat and breath play sound, light and space in real time. Generative, in key, on-device. OSC, MIDI, Art-Net, sACN and ADM-OSC out. Free.` [CLAIMS ✅ Puls-Kamera · Generative Komposition · OSC-Ausgabe · Art-Net+sACN · ADM-OSC · §7 'kostenlos']
de-DE (150): `Herzschlag und Atem spielen Klang, Licht und Raum in Echtzeit. Generativ, tonartrein, on-device. OSC, MIDI, Art-Net, sACN und ADM-OSC raus. Kostenlos.`

**overview.html** — T (39): `Overview — What Echoelmusic Ships Today` · D (148): `What ships in the bio-reactive instrument: camera pulse, generative composition, visuals, MIDI export, OSC, Art-Net/sACN, ADM-OSC — and what is cut.` [CLAIMS ✅ Zeilen 1–7]

**architecture.html** — T (46): `Architecture — Echoelmusic Developer Reference` · D (147): `How Echoelmusic is built: EngineBus, lock-free SPSC queues, protected bio-DSP, synthesis, visuals, the OSC address set. Audited against the source.` [CLAUDE.md Architecture]

**tools.html** — T (49): `What Echoel Does — Body-Driven Sound for Your Rig` · D (145): `Heartbeat, breath and HRV become in-key musical material, then leave the phone as WAV, .mid, live MIDI, OSC and DMX. On-device, accessible, free.` [CLAIMS ✅ MIDI-Export · MIDI-Ausgang live · Barrierefrei]

**faq.html** — T (41): `FAQ — Echoelmusic Bio-Reactive Instrument` · D (143): `How the pulse is measured, what ships, which rigs it connects to (OSC, MIDI, Art-Net, sACN, ADM-OSC), privacy, safety and price. Answers first.`

**artnet-sacn-from-a-phone.html** — T (43): `Art-Net & sACN from an iPhone — Echoelmusic` · D (148): `Art-Net on UDP 6454, sACN on UDP 5568: what each is, when to use which, and how Echoel sends four DMX slots from a phone under a 3 Hz flash ceiling.` [ArtNetSender.dmxChannels = 4 Slots; Blitz ≤3 Hz]

**artist.html** — T (60): `Echoel (Michael Terbuyken) — Producer, Sound Artist, Hamburg` · D (155): `Music producer, sound artist and inventor of walk-in water-light-sound installations, Hamburg. Creator of Echoelmusic. Shown at Documenta, Ars Electronica.`

**brainstorming.html** — T (43): `Brainstorming — What's Live and What's Next` · D (126): `What TestFlight testers get today, plus an ideas list for the Apple ecosystem with real market potential. Ideas, not promises.` [CLAIMS §4 nur TestFlight]

**support.html** — D (132): `Help with Echoelmusic: camera pulse, heart-rate straps, MIDI and OSC routing, exports, accessibility and contact. No account needed.`
**health.html** — D (145): `Echoelmusic shows body data for self-observation, not medical diagnosis. Visual flash rate stays under 3 Hz. Read this before your first session.`

**integrations.html (Hub)** — T (38): `Integrations — Echoelmusic in Your Rig` · D (151): `Connect Echoelmusic to Reaper, TouchDesigner, Resolume, grandMA3, QLC+, BEYOND, Ableton, Logic and FL Studio over OSC, MIDI, Art-Net, sACN and ADM-OSC.` · de-DE (150): `Echoelmusic mit Reaper, TouchDesigner, Resolume, grandMA3, QLC+, BEYOND, Ableton, Logic und FL Studio verbinden: OSC, MIDI, Art-Net, sACN und ADM-OSC.` [CLAIMS ✅ Offene Standards]

**reaper-osc.html** — T (43): `Echoelmusic → Reaper over OSC: Setup Recipe` · D (154): `Drive Reaper from your pulse: aim Echoel's OSC out at Reaper's listener, load Echoel.ReaperOSC, then learn heart rate, breath and coherence onto controls.` · de-DE (155): `Reaper mit dem Puls steuern: Echoels OSC-Ausgang auf Reapers Listener richten, Echoel.ReaperOSC laden, Herzfrequenz, Atem und Kohärenz auf Parameter lernen`

**touchdesigner-osc.html** — T (46): `Echoelmusic → TouchDesigner OSC In CHOP Recipe` · D (152): `Live heart rate, HRV, breath phase and coherence as TouchDesigner CHOP channels: port, address list, Select CHOP names, why an absent channel is normal.` · de-DE (153): `Herzfrequenz, HRV, Atemphase und Kohärenz live als CHOP-Kanäle in TouchDesigner: Port, Adressliste, Select-CHOP-Namen, warum ein leerer Kanal normal ist.`

## B. Stale-Satz-Ersatz (index meta + overview:246 + tools:237 + index featureList)
Alt: `live broadcast is not planned` / `Not planned: … live streaming` / `Streaming: Not planned.`
Neu: `Live streaming: RTMP was scoped and cut, never built — HaishinKit is not linked. Screen-record the phone and stream from your computer instead (see Integrations → Screen broadcast).` [CLAIMS §5 'Im Code, aber nicht verlinkt'; Wächter-Marker 'scoped and cut'/'never built'/'not linked' enthalten]

## C. Hub-Intro (integrations.html)
`Echoelmusic is the body-driven source at the front of your rig — not a workstation. Your pulse leaves the phone over open standards, and the tools you already own do the rest. Everything on this page sends today; nothing here needs an SDK, an account or a plugin. Echoel does not receive OSC yet — every path below is one-way, out of the phone; OSC-in is on the roadmap.` [CLAIMS ✅ Offene Standards · Null externe Abhängigkeiten; CLAIMS §1 kein Plugin; Wächter: 'one-way'+'roadmap']
Tabelle: Reaper — OSC · TouchDesigner — OSC · Resolume — OSC + Art-Net · grandMA3/QLC+/BEYOND — Art-Net/sACN · Ableton/Logic/FL/Reaper — Network MIDI, IDAM, Bluetooth MIDI, WAV/.mid · L-ISA/d&b/FletcherMachine — ADM-OSC · Projector/capture card — external display · Twitch/YouTube — system screen recording.

## D. Content-Spec: reaper-osc.html
**Answer-first:** `To get your pulse into Reaper: enable OSC out in Echoel (Master → Routing → OSC Out; host = your computer's LAN IP, port = Reaper's local listen port), add an OSC control surface in Reaper, choose the Echoel.ReaperOSC pattern config, then Learn any FX parameter from a moving Echoel address.`
**What you need:** iPhone + Reaper on the same Wi-Fi/LAN; Reaper 6+ (UNVERIFIED which minimum); no plugin — Echoel is not an AUv3 plugin and Reaper is not required to host anything. [CLAIMS §1 negation]
**In Echoel:** Master panel → Routing → connect Body → OSC Out; set Host to the Reaper machine's IP, Port to Reaper's listen port (Echoel default 8000). [PatchbayView.swift:397-398]
**In Reaper:** Preferences → Control/OSC/web → Add → OSC (Open Sound Control); set 'Local listen port' to the port you typed in Echoel; Pattern config → Echoel.ReaperOSC (file in `%APPDATA%/REAPER/OSC` or `~/Library/Application Support/REAPER/OSC` — Reaper's 'Open config directory' button shows the real path). [exact dialog labels UNVERIFIED on this container — founder-verify on Mac]
**Echoel.ReaperOSC (draft, minimal, honest — every line uses an address Echoel sends):**
```
# Echoel.ReaperOSC — pattern config for Echoelmusic OSC out (one-way, ~1 Hz batch)
# n = normalized float 0..1 ; f = float ; t = trigger
MASTER_VOLUME        n/echoelmusic/bio/coherence
TRACK_VOLUME         n/echoelmusic/bio/breath/phase
TRACK_PAN            n/echoelmusic/bio/heart/hrv
PLAY                 t/echoelmusic/bio/event/breath/inhale
```
Note under the file: `heart/bpm`, `breath/rate`, `rmssd`, `sdnn`, `pnn50` are not 0..1 — use Reaper's Learn on an FX parameter instead of a pattern line, or scale them upstream. [OSCSender literals; Reaper pattern-line semantics from Default.ReaperOSC — UNVERIFIED until run]
**Address table** (13 rows): the 9 continuous + 4 event addresses, with range and 'sent only while measured' column. Row for `/echoelmusic/bio/synthetic`: `1 = demo generator, 0 = a real body — latch it as state (UDP does not keep order).` [CLAIMS ✅ Herkunft-Zeile]
**What is not sent:** `The motion address (/echoelmusic/bio/motion) is never sent — nothing measures it. /bio/event/eeg has no producer. /echoelmusic/mod/* fires only from a modulation route, and the app ships no route today.` [CLAUDE.md #215/#541; motion-Regex-sicher formuliert]
**Coherence caveat:** camera sessions may never emit `/coherence` (needs ≥16 accepted RR intervals; camera window ~10) — map it on a chest strap. [VJ_BRIDGE §1]
**Roadmap badge:** `OSC-in (Reaper → Echoel) is on the roadmap; Ableton Link tempo sync is on the roadmap.`
**JSON-LD:** HowTo (name, tool: Reaper, supply: Echoelmusic, 5 steps) + FAQPage (3 Q: 'Do I need a plugin?' → no, standalone app, not AUv3; 'Why is /coherence missing?'; 'Is this two-way?' → one-way today, OSC-in on the roadmap) + BreadcrumbList.

## E. Content-Spec: touchdesigner-osc.html
**Answer-first:** `Add an OSC In CHOP, set its Network Port to the port you typed into Echoel's OSC Out (Echoel default 8000), point Echoel at the TouchDesigner machine's IP, and the /echoelmusic/bio/… addresses appear as channels the moment each one is first measured.`
**In Echoel:** as above. **In TouchDesigner:** OSC In CHOP → Network Port; Active on; then a Select CHOP with a channel pattern (e.g. `*heart*bpm*`, `*breath*phase*`, `*coherence*`) feeding a Math CHOP for range mapping. [TD channel-name transform of slashes UNVERIFIED — state 'names follow the address']
**Why an absent channel is normal:** the CHOP creates a channel only after the first message; a silent address means 'not measured yet', never 'zero'. Hold last value; do not bind a scale to a channel that may never arrive on a camera session (`/coherence`). [OSCSender #245 rule, VJ_BRIDGE §1]
**Address table:** same 13 rows; `/bio/event/*` as pulses — use a Trigger CHOP on `heartbeat` for a beat flash; keep any visual flash under 3 Hz. [CLAUDE.md flash ceiling]
**What is not sent / Roadmap:** identical wording to D. **JSON-LD:** HowTo + FAQPage (Q: 'Can TouchDesigner send cues back?' → not yet; OSC-in on the roadmap, one-way today) + BreadcrumbList.
**.tox:** offered later; text recipe first (a .tox must be built in TD by the founder — not from a web session).

## F. llms.txt (only after robots.txt decision)
```
# Echoelmusic
> Bio-reactive performance instrument for iPhone: heartbeat, HRV and breath drive sound, image, light and space in real time, over open standards. Free in v1.0, no in-app purchases. Not a wellness product; data for self-observation, not medical diagnosis.
## Key pages
- [Overview](https://echoelmusic.com/overview.html): what ships and what is cut
- [Integrations](https://echoelmusic.com/integrations.html): Reaper, TouchDesigner, Resolume, lighting desks, DAWs
- [FAQ](https://echoelmusic.com/faq.html)
- [Architecture](https://echoelmusic.com/architecture.html): OSC address set, engine
- [Art-Net & sACN](https://echoelmusic.com/artnet-sacn-from-a-phone.html)
## Facts
- Outputs: OSC (9 continuous + 4 event addresses under /echoelmusic/bio/), ADM-OSC objects, Art-Net and sACN (4 DMX slots), MIDI 1.0 virtual source 'Echoelmusic' with MPE out, WAV and .mid export.
- Not shipping: AUv3 plugin or host, RTMP streaming (never built), video editing, multitrack recording, MPE in, motion sensing.
- Price: free (v1.0). Zero external dependencies.
```
[CLAIMS ✅ table; §1 §5 §6 §7; Wächter-Nadeln erfüllt — llms.txt liegt nicht in pages(), aber die Disziplin gilt trotzdem]

## G. Answer-first FAQ-Ergänzungen (faq.html, 3 neue Q)
- `Does Echoelmusic work with Reaper, Ableton, Logic or FL Studio?` → `Yes, without a plugin: export WAV or .mid, record the live 'Echoelmusic' MIDI source over a Network MIDI session, Bluetooth MIDI or a USB cable (IDAM on Mac), or drive parameters over OSC. It is not an AUv3 plugin and cannot load one.` [CLAIMS ✅ MIDI-Export · MIDI-Ausgang · §1]
- `Can TouchDesigner or Resolume read my pulse?` → `Yes — one-way, over OSC out; Resolume also takes Art-Net. OSC-in to Echoel is on the roadmap.`
- `Which lighting desks accept Echoel?` → `Anything that speaks Art-Net or sACN: grandMA3, QLC+, BEYOND and most nodes. Echoel sends four DMX slots per universe (eight at 16-bit), unicast, with a 3 Hz flash ceiling; sACN shows the source name 'Echoelmusic' — '(DEMO)' when the built-in generator is running. Art-Net discovery (ArtPollReply) is not implemented, so patch the node by IP.` [ArtNetSender/SACNSender; CLAIMS Herkunft-Zeile: sACN Geräte-Verify offen — so kennzeichnen]

## KPIs

- Vendor-Abdeckung: `for n in Reaper TouchDesigner Resolume grandMA QLC BEYOND 'Network MIDI' IDAM 'Bluetooth MIDI'; do grep -il "$n" docs/*.html | wc -l; done` — heute 0/3/2/0/0/0/0/0/0, Ziel ≥1 Rezeptseite je Name innerhalb von 3 Ralph-Scheiben
- Meta-Disziplin: Python-`len()` über title/description aller `docs/*.html` — heute 7 Descriptions >155 und 1 Titel >60, Ziel 0/0 (Legal-Seiten ausgenommen)
- Schema-Tiefe: `grep -l '"HowTo"' docs/*.html | wc -l` — heute 0, Ziel = Anzahl Spokes; `grep -c FAQPage` bleibt ≥1
- Stale-Negation: `grep -il 'not planned' docs/*.html` — heute 5 Seiten (18 Treffer), Ziel 0 Treffer, die 'live broadcast/streaming' negieren
- Wächter bleibt grün: `WebsitePagesAreFindableAndHonestTests` 21/21 in CI/CD 'Build for Testing' + `gh-test-verdict.py` nach jedem docs-Commit, der Tests/ mit anfasst (docs-only-Commits: Gate NOT TRIGGERED — nie als grün melden)
- Sitemap-Frische: Anzahl `lastmod` = 2026-06-03 — heute 13/16, Ziel 0 nach Bearbeitung der jeweiligen Seite
- AI-Sichtbarkeit (nur nach Founder-Entscheidung): `grep -c 'Disallow: /' docs/robots.txt` unter AI-User-Agents — heute 6, Ziel per Entscheidung; `docs/llms.txt` vorhanden ja/nein
- Externe Messung (Search Console / Bing WMT, vom Founder): Impressionen für Queries 'reaper osc iphone', 'touchdesigner osc heart rate', 'art-net from iphone' — Baseline UNMEASURED, erst nach Indexierung der Spokes lesbar

## Die ersten drei Aktionen dieser Lane

1. Scheibe 1 (docs-only, 3 Dateien): `docs/integrations.html` (Hub) + `docs/reaper-osc.html` + `docs/touchdesigner-osc.html` nach Spec D/E anlegen — Skelett von `artnet-sacn-from-a-phone.html` kopieren, Canonical/og:title auf die eigene Datei, HowTo+FAQPage+Breadcrumb JSON-LD, Sitemap-Einträge, Link vom Hub aus `tools.html` ('Into Your Studio') und `index.html`; vor dem Commit die Wächter-Nadeln lokal in Python nachstellen (AUv3-Negationsfenster, RTMP-Marker, 'Ableton Link'+roadmap, Motion-Konjunktions-Regex, 'bidirectional' im ld+json). Dazu `Echoel.ReaperOSC` als Textblock auf der Seite, als Datei erst nach Founder-Probe in Reaper.
2. Scheibe 2 (docs-only, ≤3 Dateien): `index.html` meta description 497→146 + featureList-Satz, `overview.html:246` und `tools.html:237` 'not planned' → 'scoped and cut, never built — not linked' + Verweis auf das Screen-Broadcast-Rezept; `og:title` auf architecture/artist/overview angleichen; `lastmod` der angefassten Seiten setzen. Danach `docs/dev/VJ_BRIDGE.md`: 'Tools ▸ Routing' → 'Master panel → Routing', NDI-Satz streichen.
3. Founder-Frage (eine, gemessen vorbereitet): robots.txt blockt GPTBot/ChatGPT-User/CCBot/Google-Extended/anthropic-ai/ClaudeBot — beibehalten (Privacy-Haltung) oder für AI-Auffindbarkeit öffnen? Erst nach Antwort `docs/llms.txt` (Draft F) anlegen. Im selben Zettel: bestätigen, ob @echoelmusic auf Instagram/TikTok/YouTube existiert (sonst `sameAs` im JSON-LD entfernen) und ob de-DE-Seiten mit hreflang gewünscht sind (Meta-Varianten liegen bereit).

## Verwendete Behauptungen (für den Kritiker)

- Der Puls wird mit der iPhone-Kamera gemessen (Finger auf die Linse, rPPG)
- Herzschlag, HRV und Kohärenz modulieren Klang in Echtzeit
- Generative Komposition in gewählter Tonart/Skala/Genre, tonartrein
- Bio-reaktive Visuals live auf dem Gerät (Metal)
- Licht: Art-Net + sACN (DMX über Netzwerk), Grand Master + Blackout
- Immersiver Raum: ADM-OSC Objekt-Ausgabe (/adm/obj/{n}/*)
- OSC-Ausgabe des Bio-Signals an jede Software im Netz
- MIDI-Export der erzeugten Musik als .mid
- MIDI-Ausgang live: gespielte NOTEN an dein Rig (MIDI 1.0)
- MPE-AUSGANG an Dein Rig: Zone angekündigt, Noten über Member-Kanäle 2–16 … Nur MIT Richtungswort schreiben
- Dein Rig erfährt, ob ein Körper sendet oder der Demo-Generator: /echoelmusic/bio/synthetic … sACN Quellname »Echoelmusic (DEMO)« — Geräte-Verify offen, so kennzeichnen
- Universeller BLE-Herzgurt (0x180D), z. B. Polar H10 — Geräte-Verify offen
- Apple Health als Pulsquelle
- Offene Standards, kein SDK-Lock-in
- Null externe Abhängigkeiten, alles on-device
- Barrierefrei spielbar
- Beamer/Externer Bildschirm: das Visual bespielt ein angeschlossenes Display als eigene Bühne (ExternalDisplayScene #206)
- Visual-Aufnahme + mp4-Export
- §1 AUv3 — nie behaupten; Echoel ist kein Plugin und kann keine laden
- §4 nur TestFlight, kein Store-Link
- §5 Drums/Video-Schnitt/RTMP/Mehrspur — nicht behaupten; RTMP im Code aber nicht verlinkt
- §6 MPE — Richtungswort Pflicht, MPE-Eingang verboten
- §7 v1.0 kostenlos, kein Preis/Abo/Pro in Copy; v1.1 Echoel Live ~29,99 €/Jahr, v1.2 Event-Gebühr (decisions.csv 2026-07-10)
- §12 Atemtiefe/LF-HF nicht als Abbildung; Kohärenz-Trend seit #813 erlaubt
- CLAUDE.md OSC-Adressliste: /bio/motion, /bio/event/motion, /bio/event/eeg werden nie gesendet; /mod/<key> ohne Route
- CLAUDE.md: OSC-in existiert nicht (NWListener = 0) — jede Kopie sagt one-way/roadmap
- Grand Council 2026-09-10 §6c: System-Bildschirmaufnahme ADOPT-PIPELINE (nie 'RTMP', nie 'streamt aus Echoel'); RTMP WATCH v1.2; NDI/Syphon REJECT; Ableton Link nur als Roadmap bis Entitlement + Lizenz

## Kritik

*Der Kritiker dieser Lane ist am Sitzungslimit gestorben. Die Sitzung hat die Lane per Regex auf die Guardrail-Begriffe geprüft (Ergebnis im Guardrail-Protokoll oben); eine Zeile-für-Zeile-Kritik steht aus und ist Teil der ersten fünf Aktionen.*



---

# Anhang C — Reach, Launch, Community

*Lane-Bericht des Autors, unverändert bis auf die Überschriften; die Kritik (wo vorhanden) folgt am Ende des Anhangs. Jede Behauptung, die der Guardrail-Abschnitt oben streicht, gilt hier als gestrichen, auch wenn sie im Anhang noch steht.*

## Diagnose (gemessen)

## Was heute auf Platte liegt (gemessen 2026-09-10, read-only)

**ContentPipeline/ — Struktur ja, Inhalt null.**
- `ls ContentPipeline/` → `CLAIMS.md` (31.731 B, Stand 2026-08-28 plus #1024/#1038-Streichungen vom 09-06), `README.md`, `Scripts/template_short_form.md` (EIN Template: Hook 0–3 s Finger auf der Linse → Mechanik → 4 s Ton ohne Sprache → CTA »TestFlight — Link in Bio«), `Prompts/variants.md` (fünf wahre Zielgruppen: Lichtdesign · Immersive/Spatial · Modular/Synth · Installation · Musiktheorie), `Automation/autocut.py` (73 KB, #1183–#1188: proxy/sync/highlights/brand/zoom, CI-Platte, `--selftest` grün), `Assets/README.md` (249 B, kein Material), `Published/LOG.md` → **»noch nichts veröffentlicht«**. Ein Schneidetisch ohne einen einzigen Rohclip.
- Hashtag-Liste im Template ist geprüft; `#Biohacking` dort »grenzwertig«, in CLAIMS §9 verboten — **CLAIMS gewinnt** (»Nie in Skript, Caption, Hashtag oder Titel«).

**Website-Reach-Assets (`docs/`).**
- `docs/press.html` (14.920 B): One-liner, Boilerplate kurz/lang, Fact Sheet, »What ships today« (ehrlich inkl. MPE-IN-Roadmap-Satz), fünf Story-Angles, Naming-Regel. **Schwach:** »Screenshots and preview video: available on request (device captures in progress)« — `ls docs/screenshots` → drei HTML-Demos, keine PNG/MP4. Ein Journalist bekommt heute kein Bild.
- `docs/artist.html` (15.734 B): Wasser-Licht-Klang-Installationen seit 2006, Burgbeben STRNBRG 2024 (Vibrations-Pontons + Klangspiegel, mit Anna.Elisie als Loewe Immerlieb), Venues (Documenta · Ars Electronica · Fusion · Kampnagel …). Das ist die **Demo-Bühne** — ohne ein einziges Echoel-Bild darauf.
- `docs/artnet-sacn-from-a-phone.html` (7.103 Zeichen Text): fertiger Fach-Artikel Art-Net vs. sACN + »What Echoel sends« — direkt als Forum-/PR-Anker für die Licht-Community nutzbar.
- `docs/dev/VJ_BRIDGE.md` §1: die OSC-Adresstabelle mit Resolume-OSC-Learn- und TouchDesigner-OSC-In-CHOP-Rezept, inkl. der #245-Regel (nicht gemessene Adresse wird nicht gesendet — TD legt keinen Kanal an). §5 Broadcast = CUT. **Das ist der Rohling des Lead Magnets.**
- Social-Handles: `docs/index.html:86-88`, `artist.html:58-60` deklarieren im JSON-LD `instagram.com/echoelmusic`, `tiktok.com/@echoelmusic`, `youtube.com/@echoelmusic`. **Ob diese Konten existieren, ist aus dem Repo nicht messbar** — `Published/LOG.md` ist leer, also wurde dort nie gepostet. Founder-Kanäle laut Brief/`artist.html`: @digitalewaerme · @supernaturalhealingkillers · @nia9ara.de · @loewe.immerlieb · @tropicaldrones.de · @xt14_artist; **veganmom.de/@anna.elisie bleibt außerhalb jeder Echoel-Kopie** (nur als Reach-Asset für die eigene Entscheidung des Founders notiert).

**Kontakte (`memory/people.md`).** Roman (Pyko/Adamson, FletcherMachine spricht ADM-OSC — »Networking contact, no commitment«) · Johannes Bollmann (Veranstaltungs-/Messe-Vertrieb, Panasonic-Projektionsgerät ~30 k€, schreibt für *Amazonas* — ob damit AMAZONA.de gemeint ist, steht nicht im Repo) · Felix Deufel (Grapes GmbH, Immersive-Netzwerk) · Tyler Germain (Collaborator, Rolle unklar). Kein Eintrag hat ein Datum einer Ansprache seit 2026-06-06.

**Store-Metadaten.** `fastlane/metadata/{en-US,de-DE}/` vollständig (description · subtitle · keywords · promotional_text · release_notes). Untertitel »Bio-Reactive Instrument« / »Bio-Reaktives Instrument«. Keywords en-US: `biofeedback,HRV,coherence,generative,synth,MIDI,OSC,artnet,sACN,DMX,immersive,visuals,rPPG,pulse`. **Es gibt nur TestFlight** (CLAIMS §4) — jeder CTA bleibt »TestFlight — Link in Bio« bis zur Freigabe.

**E-Mail-Liste.** `git grep -i 'newsletter|mailing|waitlist' memory docs/dev` → nichts. Der »TestFlight-Verteiler« ist ein `mailto:echoel@tropicaldrones.com?subject=TestFlight access`-Link (`docs/index.html:608/653`, `press.html:114`). **Es gibt keine Liste, nur ein Postfach.** Ein E-Mail-Werkzeug (Buttondown o. ä.) wäre eine Founder-Entscheidung — vorschlagen, nicht annehmen.

**Der Draht, den die Videos zeigen sollen (gemessen in `Sources/`).**
- rPPG: CLAIMS ✅ Zeile 1, Log 2477 (Lock in 14 s).
- OSC-Adressen: `grep -n '"/echoelmusic/' Sources/Echoelmusic/Sync/OSCSender.swift` → bio/synthetic · heart/bpm · heart/hrv · rmssd · pnn50 · sdnn · breath/rate · breath/phase · coherence · mod/<key> · event/* (motion und eeg werden nie gesendet, #215).
- ADM-OSC: `ADMOSCSender.swift:301` prefix `/adm/obj/{n}` → `position/azimuth` (Atemphase, nur mit gemessener Atem-Wellenform #1140), `position/elevation` (HRV), distance (Kohärenz), gain. Konstruiert `EchoelmusicApp.swift:106`.
- Art-Net/sACN: `ArtNetSender.swift:281-296` — ch1 Dimmer = 0,3 + 0,7·Kohärenz, ch2 R = Puls, ch3 G = HRV, ch4 B = Atemphase; 16-bit = 8 Slots; Slew, nie Strobe. sACN Source-Name »Echoelmusic (DEMO)« (#789, Geräte-Verify offen).
- MIDI out: virtuelle CoreMIDI-Quelle »Echoelmusic« (`MIDIOutput.swift:229`), MPE OUT via `sendMPEConfiguration()`; Bluetooth-MIDI-Picker `PatchbayView.swift:116`; Network-MIDI `MIDIInput.swift:158`.
- Externer Bildschirm: `Sources/Echoelmusic/Studio/ExternalDisplayScene.swift` existiert (CLAIMS ✅ #206). ⚠️ `docs/dev/FEATURE_MATRIX.md:271-272` sagt weiterhin »EchoelStage — ROADMAP, Code: none« — **veraltete Zeile, berichten** (nicht meine Lane; #206 ist laut Grand Council §7 Schritt 1 noch Geräte-Verify offen).
- Live Colabo (Multipeer, zwei iPhones) betürt: `EchoelStudioView.swift:2368`.

**Was schwach ist, in einer Zeile je Punkt.** (1) Null veröffentlichte Clips und null Rohmaterial — jeder Plan unten hängt an EINER Geräte-Session. (2) Keine Bild-Assets im Presskit. (3) Keine Liste, nur ein Postfach. (4) Drei deklarierte Handles, unbelegt ob existent. (5) `docs/integrations/` existiert nicht (Grand Council §7 Schritt 2 = »proceed«, 0 gated Dateien) — der Lead Magnet ist noch nicht gebaut. (6) Drei ✅-Zeilen mit offenem Geräte-Verify (BLE-Gurt · Voice timbre · Texture/Glitter · sACN-Quellname · Beamer) — sie dürfen behauptet werden, aber nur MIT Kennzeichnung; im Video zeige ich sie erst nach einem `VERIFIED-`Datum. (7) Vendor-Adressen Resolume/TD sind laut Grand Council §6(c) UNVERIFIED bis zur Probe — Flagship-Video 3 IST diese Probe.

## Strategie

## Leitidee (aus Grand Council §1/§6, für den Founder)

Echoel wird nicht als »App« gelauncht, sondern als **das Körper-Instrument, das in deinem Rig sitzt** — Ableton/Logic/AUM per MIDI-/MPE-Ausgang, Resolume/TouchDesigner per OSC, grandMA/QLC+/BEYOND per Art-Net/sACN, FletcherMachine per ADM-OSC, Beamer per externem Bildschirm. Das ist Lesart B des Councils. Alles, was Lesart A wäre (Timeline, Hosting, RTMP), taucht in keiner Kopie auf. Die einzigartige Bühne ist der Founder selbst: **Installationskünstler mit Wasser · Licht · Klang** — der Demo-Ort ist kein Studio-Screenrecording, sondern ein echter Lichtpark und ein echter Raum.

**Kadenz, ehrlich für einen Solo-Founder:** 2 Kurzvideos/Woche (nicht 1–4/Tag wie das vendored `social`-Skill für SaaS-Teams annimmt), 1 Community-Post/Woche, 1 PR-Welle pro Phase. Jede Veröffentlichung → Zeile in `ContentPipeline/Published/LOG.md`.

**Harte Regeln, die über allem stehen:** nur ✅-Zeilen aus CLAIMS.md · CTA bleibt TestFlight bis zur Freigabe (§4) · kein Preis, kein »Abo«, kein »Pro«, auch nicht »Echoel Live« (§7 — die v1.1-Entscheidung ist intern; öffentlich gilt nur »free · no account · no ads · no tracking« aus `press.html`) · Blitz ≤ 3 Hz auch im Schnitt · bei jeder Bio-Zahl im Bild der Satz »for self-observation, not medical diagnosis« · Kamera-Finger als Quelle, nie Watch (§3) · Richtungswort bei MPE (§6) · Stimme = Messung, nie Aufnahme (§11).

---

## 90-Tage-Kalender (W1 = Mo 2026-09-14 … W13 = So 2026-12-13)

Das App-Store-Datum ist Founder-Sache. Der Kalender ist deshalb in drei Phasen gebaut; **»L« = Tag der App-Store-Freigabe** und verschiebt Phase B als Block. Bis L bleibt jeder CTA TestFlight.

### Phase A — TestFlight & Material (W1–W4): erst filmen, dann reden

| Woche | Wochenthema (Template-Abschnitt Hook/Mechanik/Beweis) | Publikum (`variants.md`) | CLAIMS-Zeile | Deliverable |
|---|---|---|---|---|
| W1 | **Finger auf der Linse** — Torch an, Bild wird rot, Zahl rastet ein, Klang setzt auf dem Lock ein | alle | ✅ Puls mit iPhone-Kamera · ✅ HR/HRV/Kohärenz modulieren Klang | Flagship 1 (15 s) roh gedreht; Presskit-Screenshots (6–8 PNG) |
| W2 | **Der Atem lässt den Klang anschwellen** — ein Parameter, nicht neun (§12: Atemphase → Amplitude) | Modular/Synth | ✅ Klang-Modulation (Vier-Kanal-Tabelle §12) | 2 Clips; Handles @echoelmusic bestätigt/angelegt |
| W3 | **Tonart wechseln, dieselbe Körperkurve** — 57 Skalen, 15 Stimmungssysteme, Notennamen in 3 Systemen | Musiktheorie/Bildung | ✅ Generative Komposition · ✅ Barrierefrei spielbar | 2 Clips; `docs/integrations/` angelegt (OSC-Karte) |
| W4 | **Das Bild spielen** — Finger durchs Wasser, tonartreine Noten, Wasserringe | iOS-Musik | ✅ Das Bild ist SPIELBAR (EINE Fläche, nicht »Touch-Instrumente«) | 2 Clips; Mail 1 an TestFlight-Tester |

### Phase B — Launch-Fenster (W5–W8, verschiebt sich mit L)

| Woche | Thema | Publikum | CLAIMS-Zeile | Deliverable |
|---|---|---|---|---|
| W5 (L−7) | **Ein Körper steuert einen Lichtpark** — echte Lampen, Art-Net-Node, Grand Master, Blackout | Lichtdesign/Bühne (konkurrenzarm) | ✅ Licht: Art-Net + sACN | Flagship 2 gedreht; PR-Welle 1 (CDM/Synthtopia/BPB) mit Embargo auf L |
| W6 (L) | **Launch** — »Now on the App Store« (erst NACH Freigabe, §4); Presskit-Link, 15-s-Clip überall | alle | ✅ Offene Standards · ✅ Null externe Abhängigkeiten | Store-CTA umgestellt in Template + Bio; Mail 3; Product Hunt / AlternativeTo live |
| W7 (L+7) | **Dein Rig hört mit** — Network-MIDI-Session, Quelle »Echoelmusic« in Logic/Ableton, MPE OUT (mit Richtungswort) | Producer | ✅ MIDI-Ausgang live · ✅ MPE-AUSGANG · ✅ MIDI-Export .mid | 2 Clips; Forum-Posts r/ableton, Audiobus-Forum (ohne Audiobus-/AUv3-Claim) |
| W8 (L+14) | **Echoel füttert Resolume/TouchDesigner** — OSC-Learn, OSC In CHOP, `/echoelmusic/bio/breath/phase` auf Layer-Opacity | VJ | ✅ OSC-Ausgabe | Flagship 3; TouchDesigner-Forum + Resolume-Forum + r/vjing |

### Phase C — Rig-Saison & Community (W9–W13)

| Woche | Thema | Publikum | CLAIMS-Zeile | Deliverable |
|---|---|---|---|---|
| W9 | **Der Körper bewegt den Klang im Raum** — ADM-OSC-Objekt, Atem = links/rechts, Ruhe = hoch | Immersive/Spatial | ✅ Immersiver Raum: ADM-OSC | Clip (OSC-Monitor sichtbar); Adamson-Ask verschickt |
| W10 | **Nichts verlässt das Telefon** — Local-Network-Prompt im Bild, kein Konto, offline | Installation/Ausstellung | ✅ Null externe Abhängigkeiten · ✅ Offene Standards | 2 Clips; Mail 2 (Rig-Mail) |
| W11 | **Dein Rig weiß, ob ein Körper sendet** — `/bio/synthetic`, sACN-Quellname (nur wenn VERIFIED) | Licht/VJ | ✅ Dein Rig erfährt … (sACN-Hälfte: Verify offen) | Clip; Directory-Runde 2 |
| W12 | **Beamer-Bühne** — externer Bildschirm, Telefon bleibt Spielfläche (nur nach #206-Verify); Panasonic-Ask | Installation | ✅ Beamer/Externer Bildschirm | Clip; Bollmann-Termin |
| W13 | **Retro + Rig-Galerie** — Clips der Community re-posten, `Published/LOG.md` auswerten, Themen für Q1 | Community | — | LOG-Auswertung; Council-Review der Kadenz |

**Fallback-Themen** (wenn ein Verify fehlt): Visual-Aufnahme + mp4 aus der Bibliothek (✅ Visual-Aufnahme), Live Colabo zwischen zwei iPhones (✅ nach FEATURE_MATRIX »Nearby session sharing«, `showLiveColabo`-Tür gemessen), Stimme als Klangfarbe (✅, Verify offen → »gemessen, nie aufgenommen«).

---

## Drei Flagship-Demos mit Shot-Lists

### F1 — »Pulse → Sound« (15 s, 9:16, Standalone-Hero, auch als App-Preview-Kandidat)
CLAIMS: ✅ Puls mit iPhone-Kamera · ✅ HR/HRV/Kohärenz modulieren Klang · ✅ Generative Komposition.
1. 0:00–0:03 Makro (zweites Telefon oder Kamera): Finger legt sich auf die Rücklinse, Torch geht an, Haut wird rot. Kein Wearable im Bild. Overlay: »No sensor. Just the camera.«
2. 0:03–0:06 Bildschirmaufnahme: Puls-Pille, Zahl rastet ein (Log 2477: ~14 s real → auf 3 s gecuttet, autocut `zoom --aspect 9:16`). Im Bild: »self-observation, not medical diagnosis« klein unten.
3. 0:06–0:12 Klang setzt GENAU auf dem Lock ein; ein Parameter sichtbar (Brillanz oder Filter-Cutoff mit Kohärenz). 4 s ohne Sprache.
4. 0:12–0:14 Tonart-Chip: Skala wechseln — dieselbe Kurve, anderer Klang.
5. 0:14–0:15 CTA-Karte: »TestFlight — link in bio« (nach L: »On the App Store«).
Ton: nur der erzeugte Take. Schnittrate ≤ 3 Hz. Build-Nummer im Bild = ein Build, in dem alles Gezeigte drin ist.

### F2 — »Pulse → Light« auf einem echten Art-Net-Rig (30 s, 9:16 + 16:9-Schnitt für YouTube)
CLAIMS: ✅ Licht: Art-Net + sACN (Grand Master + Blackout) · ✅ Puls mit Kamera. Nicht zeigen: sACN-Quellname im Pult (Verify offen), BLE-Gurt (Verify offen) — Quelle ist die Kamera.
Setup: 1 Art-Net-Node (z. B. Enttec ODE/DMXking) + 2–4 RGB-Scheinwerfer im 4-Kanal-Modus (Dimmer/R/G/B — genau das Mapping aus `ArtNetSender.dmxChannels`), Telefon im selben WLAN, Broadcast oder Unicast auf die Node-IP. Ort: die Wasser-Installation des Founders, wenn verfügbar — Licht auf Wasser ist das Bild, das sonst niemand hat.
1. 0:00–0:03 Dunkler Raum, Finger auf der Linse (Makro), Torch-Rot.
2. 0:03–0:06 iOS-Dialog »Local Network« erscheint → Founder tippt »Allow«. Overlay: »Only your own network. Nothing else.« (Privacy-Angle wird zum Beweis.)
3. 0:06–0:14 Weitwinkel: Lampen atmen — Blau folgt der Atemphase, Rot dem Puls. Overlay eine Zeile: »Dimmer = coherence · R = pulse · G = HRV · B = breath«.
4. 0:14–0:20 Split: Telefon-Visual links, Lampen rechts, synchron. Kein Strobe (Slew by construction).
5. 0:20–0:25 Grand Master ziehen → Blackout-Taste → Licht aus, Musik läuft weiter.
6. 0:25–0:30 CTA + »Art-Net · sACN · from an iPhone« + Link auf `docs/artnet-sacn-from-a-phone.html`.
Go/No-Go: Node muss ArtDMX auf Universe X empfangen (Node-LED/QLC+-Monitor) — vorher testen, im Video nicht erklären.

### F3 — »Echoel feeds Resolume / TouchDesigner« (45–60 s, 16:9 YouTube + 9:16 Cut)
CLAIMS: ✅ OSC-Ausgabe an jede Software im Netz (VJ_BRIDGE §1 Rezepte) · optional ✅ Beamer/Externer Bildschirm (nur nach #206-Verify). ⚠️ Grand Council §6(c): Vendor-Adressen UNVERIFIED bis zur Probe — **dieser Dreh ist die Probe**; das Rezept wandert danach als VERIFIED in `docs/integrations/`.
1. 0:00–0:05 Laptop mit Resolume Arena, Telefon daneben, Finger auf Linse.
2. 0:05–0:15 Resolume: Preferences ▸ OSC ▸ Input an → Rechtsklick Layer-Opacity ▸ Edit OSC → Founder atmet → Adresse `/echoelmusic/bio/breath/phase` erscheint (OSC-Learn). Overlay: »One breath. Resolume learned it.«
3. 0:15–0:25 Clip-Layer pulst mit dem Atem; zweite Zuweisung `/echoelmusic/bio/heart/bpm` auf Effect-Amount.
4. 0:25–0:40 TouchDesigner: OSC In CHOP :8000 → Kanäle `echoelmusic/bio/heart/bpm`, `breath/phase` erscheinen (nur die gemessenen — #245 im Bild als Feature: »Silence means not measured«). Patch in einen Noise-TOP.
5. 0:40–0:50 Wenn #206 VERIFIED: Echoel-Visual per Kabel auf einen Beamer, Telefon bleibt Spielfläche; sonst überspringen.
6. 0:50–0:60 CTA + »OSC address card: link in bio« (Lead Magnet).
Nie im Bild: DAW-Spur, Plugin-Fenster (§1), NDI/Syphon (REJECT).

---

## PR

**Angles (aus `press.html` Story-Angles, geschärft):**
1. *The body as controller* — ein Instrument, das mit dem Herzschlag gespielt wird, gemessen mit nichts als der iPhone-Kamera.
2. *Open standards, no SDK* — ein iPhone als Quelle für ADM-OSC-Objekte, Art-Net/sACN-Licht und OSC/MIDI — sitzt im Rig, ersetzt es nicht.
3. *Science, not wellness* — HRV-Kohärenz aus Lomb-Scargle/Welch, Zahlen zuerst, Selbstbeobachtung statt Therapie.
4. *No cloud* — kein Konto, keine Analytics, null Abhängigkeiten; Biosignale verlassen das Telefon nur ins eigene LAN, nach Opt-in.
5. *Free* — »free · no account · no ads · no tracking« (§7: kein Preis, kein »Abo« — auch nicht als Negation »never a subscription«, das steht nirgends auf Platte).
6. *Hamburg installation artist* — Wasser · Licht · Klang seit 2006 (Documenta, Ars Electronica, Fusion); das Instrument ist aus der Installationspraxis gebaut.

**10 Outlets/Communities + One-Line-Pitch (Format aus `public-relations/references/journalist-pitching.md`: spezifisch, kurz, nie über uns):**
| # | Outlet | One-Liner |
|---|---|---|
| 1 | **CDM / Create Digital Music** (Peter Kirn, CDM Tips-Inbox) | »An iPhone instrument that plays from your pulse — and speaks Art-Net, sACN, ADM-OSC and OSC to your rig. Zero dependencies, built by a Hamburg installation artist. 15-s clip + press kit attached.« |
| 2 | **Synthtopia** (news@) | »Free iOS synth where heart rate, HRV and breath drive a DDSP engine — MIDI/MPE out to your DAW, no plugin, no account.« |
| 3 | **KVR Audio** (News-Submission + Produkt-Datenbank) | »Echoelmusic — bio-reactive iOS instrument, free; CoreMIDI source ›Echoelmusic‹ with MPE out.« |
| 4 | **Bedroom Producers Blog** | »Free iPhone app: your pulse composes in-key material, exports .mid with tempo and key signature — for your DAW, not inside it.« |
| 5 | **r/synthesizers** | Post-Titel: »I built an iPhone instrument that plays from my pulse (camera rPPG) and sends MIDI/MPE out — here's what your rig sees« + F1-Clip, Adresskarte im Kommentar. |
| 6 | **r/vjing** | »One breath and Resolume learns the OSC address — a phone as bio-reactive OSC source (free, on-device).« + F3. |
| 7 | **TouchDesigner Forum** (forum.derivative.ca, Category ›Assets/Tools‹) | »OSC In CHOP recipe: pulse/HRV/breath channels from an iPhone, only measured channels are sent (no phantom zeros).« + `.tox`-Rezept aus `docs/integrations/`. |
| 8 | **Resolume Forum** (Feedback/Showcase) | »Body-reactive layer opacity via OSC learn from an iPhone — Arena mapping sheet inside.« + F3. |
| 9 | **Licht/Laser: Blue Room Forum · r/lightingdesign · QLC+-Forum · Pangolin BEYOND Forum** | »An iPhone as Art-Net/sACN source: 4-slot fixture (dimmer/R/G/B), slewed, never strobes, Grand Master + Blackout — pulse and breath on real lamps.« + F2 + `artnet-sacn-from-a-phone.html`. |
| 10 | **Ableton User Groups** (r/ableton, Ableton Discord, Hamburg-UG) | »Network-MIDI session → source ›Echoelmusic‹ appears in Live; MPE out with glide/slide/press per note. Not a plugin — a body-instrument beside Live.« |
Deutsch optional (Bollmanns Kontakt klären): **AMAZONA.de**, **Bonedo**, **Production Partner** (Licht/Event-Fachmagazin) — gleiche Pitches, de-DE.

Timing: Welle 1 (W5, Embargo L) an 1–4; Welle 2 (W7–W8) Communities 5–10 mit F2/F3; Welle 3 (W12) Fachpresse Licht/Immersive mit Adamson/Panasonic-Ergebnis, falls vorhanden.

---

## Co-Marketing-Asks (aus `memory/people.md`)

1. **Roman / Adamson (FletcherMachine, ADM-OSC).** Ask: eine Stunde am FletcherMachine — Echoel sendet `/adm/obj/1/position/*` + `/gain`, gemeinsam aufgezeichnet. Das ist gleichzeitig der offene **Geräte-Verify** (FEATURE_MATRIX-Abnahme nennt nur einen OSC-Monitor). Gegenwert für Adamson: Referenz »offener Standard, Body-Source, kein SDK« in ihrem ADM-OSC-Ökosystem; Co-Post beider Kanäle. Nicht versprechen: eigenes Fletcher-Preset, Hersteller-Namensraum.
2. **Johannes Bollmann (Panasonic-Projektion, Messe/Venue).** Ask: ein Abend mit Panasonic-Server + Beamer — Echoel-Visual über externen Bildschirm (#206, Verify offen → der Abend IST der Verify). Gegenwert: Messe-Demo-Content für seinen Vertrieb, Artikel-Angle für *Amazonas* (klären, welches Magazin). Nicht versprechen: Warping/Edge-Blend, NDI (REJECT).
3. **Felix Deufel / Grapes GmbH.** Ask: Referenzort für die ADM-OSC/Beamer-Demo, ein Zitat fürs Presskit.
4. **Tyler Germain.** Rolle im Repo unklar (nur Decision-Log-Tag) — vor einem Ask klären.

---

## Directory Submissions (aus `directory-submissions/references/directory-list.md`, auf eine kostenlose iOS-App gefiltert)

Voraussetzung (Rule 1 des Skills): 6–8 echte Screenshots + 60–90-s-Demo (= F1+F3-Schnitt) + Presskit — heute NICHT erfüllt (`docs/screenshots` = 3 HTML). Erst W6, nicht W1.
- **Product Hunt** (L-Tag, Di–Do, 3 Wochen Warm-up; Kategorie Music/Audio, Tagline = Store-Untertitel).
- **AlternativeTo** (nofollow, aber Suchvolumen »[X] alternative« — als Alternative zu Nutzer-gesuchten Bio-Controller-Apps listen, KEIN DAW-/Plugin-Vergleich).
- **BetaList** (jetzt, pre-launch, TestFlight-Waitlist).
- **Indie Hackers** (Build-in-public, Founder-Story).
- **KVR Produkt-Datenbank** (Fach-Directory, Kategorie iOS).
- **ADM-OSC-Implementierungsliste** — `github.com/immersive-audio-live/ADM-OSC` führt Sender/Receiver; PR zum Eintrag »Echoelmusic (sender)« = echtes, kostenloses Fach-Directory.
- **Open Lighting Project / QLC+-Wiki** (Art-Net/sACN-Software-Listen).
- **TouchDesigner Community Assets** + **Resolume-Forum Showcase** (Rezept-Dateien).
- **App Store Featuring-Nomination** (App Store Connect → Nominations, kostenlos, 2–3 Wochen vor L).
- **Hamburg lokal:** nextMedia.Hamburg / Hamburg Kreativ Gesellschaft (Founder-Story + Installation).
Tracker: `submission-tracker-template.csv` aus dem Skill nach `ContentPipeline/Published/` kopieren (Founder-Entscheidung; Pipeline-only).

---

## Lead Magnet — »Echoel Integrations Pack«

= Grand Council §7 Schritt 2 (»proceed«, 0 gated Dateien): `docs/integrations/` mit (a) **OSC Address Card** als eine A4/Letter-PDF-Seite — die Tabelle aus `VJ_BRIDGE.md` §1 (Adresse · Range · Bedeutung · #245-Regel · `/bio/synthetic`-Latch), ADM-OSC-Objektzeilen, Art-Net/sACN-Slot-Map (4/8 Slots, Dimmer/R/G/B), MIDI-Quelle »Echoelmusic« + MPE-OUT-Schalter; (b) Resolume-OSC-Learn-Rezept, (c) TouchDesigner-`.tox`/CHOP-Rezept, (d) Fixture-Profil QLC+/grandMA3/BEYOND, (e) Network-/Bluetooth-MIDI-Rezept Logic/Ableton/FL/Reaper. Ein CISmoke-Wächter greppt die Template-Adressen gegen `OSCSender`/`ADMOSCSender`/`ArtNetSender` (Council-Vorgabe). Motion/EEG-Adressen tauchen NIE auf (#215).
Capture: Karte frei auf der Website (SEO/AI-Zitat-Fläche), das volle Pack per E-Mail — Werkzeug ist Founder-Entscheidung; bis dahin `mailto:?subject=Integrations pack`.

---

## E-Mail-Sequenz (3 Mails, TestFlight-Verteiler) — Outline
1. **»Your pulse should lock in about 14 seconds«** (T+0): Finger flach auf die Rücklinse, Torch an, stillhalten; eine Sache ausprobieren (Sound-Chip → Genre wechseln); Bitte um EINE Geräte-Notiz (Build-Nummer + was gehört) — das füttert direkt `founder-verify.py`. Ein CTA.
2. **»What's in your rig?«** (T+5): OSC-Adresskarte als PDF; drei Rezepte (Resolume · TouchDesigner · Network MIDI); eine Frage zurück: Licht / VJ / DAW / Spatial? (Segmentierung für Phase C). Ein CTA: Antwort-Mail.
3. **»Now on the App Store«** (L): Store-Link, F1-Clip, Bitte um Bewertung; ein klar beschrifteter Roadmap-Satz (MPE-IN-Zonen, OSC-in) — nie in Store-Metadaten; Dank an Tester namentlich nur mit Zustimmung.

---

## Was ich bewusst NICHT geplant habe
- Keine Watch-, AUv3-, Link-, RTMP-, NDI-, Multitrack-Kopie — auch nicht »coming soon« in Captions (Store 2.3; Website-Roadmap-Satz bleibt `press.html` vorbehalten).
- Kein Auto-Posting (§10); die Pipeline erzeugt Entwürfe.
- Keine Preis-/Abo-Kommunikation, keine Negation davon.
- Keine Vermischung mit veganmom.de/@anna.elisie.

## Kopie-Entwürfe

Alle Blöcke: American English = Store-/Website-/Community-Sprache; de-DE dort, wo `fastlane/metadata/de-DE` bzw. ein deutsches Publikum existiert. Jeder Block nennt die tragende CLAIMS-Zeile. Hashtags = geprüfter Satz aus `template_short_form.md` ohne `#Biohacking` (CLAIMS §9).

### A. Caption F1 — Pulse → Sound (TikTok/Reels/Shorts)
**en-US**
> Finger on the camera, torch on. Fourteen seconds later the pulse locks and the instrument starts playing — in your key, from your heart rate, HRV and breath. No sensor, no account, nothing leaves the phone.
> TestFlight — link in bio. For self-observation, not medical diagnosis.
> #GenerativeMusic #Biofeedback #Synthesizer #iOSMusic #SoundDesign #HRV #Echoel

**de-DE**
> Finger auf die Kamera, Licht an. Vierzehn Sekunden später rastet der Puls ein und das Instrument spielt — in deiner Tonart, aus Herzfrequenz, HRV und Atem. Kein Sensor, kein Konto, nichts verlässt das Telefon.
> TestFlight — Link in der Bio. Zur Selbstbeobachtung, keine medizinische Diagnose.

CLAIMS: ✅ »Der Puls wird mit der iPhone-Kamera gemessen« (Log 2477: Lock in 14 s) · ✅ »Herzschlag, HRV und Kohärenz modulieren Klang in Echtzeit« · ✅ »Generative Komposition in gewählter Tonart/Skala/Genre« · ✅ »Null externe Abhängigkeiten, alles on-device«. Nach Store-Freigabe: »TestFlight — link in bio« → »On the App Store — link in bio« (§4).

### B. Caption F2 — Pulse → Light (Art-Net-Rig)
**en-US**
> Four lamps, one body. The phone sends Art-Net to the node: dimmer follows coherence, red follows the pulse, green follows HRV, blue follows the breath. Slewed, never strobing. Grand Master and Blackout on the phone. No console in between.
> TestFlight — link in bio.
> #ArtNet #DMX #sACN #LiveVisuals #Immersive #Biofeedback #Echoel

**de-DE**
> Vier Lampen, ein Körper. Das Telefon schickt Art-Net an den Node: Dimmer folgt der Kohärenz, Rot dem Puls, Grün der HRV, Blau dem Atem. Geglättet, nie Strobe. Grand Master und Blackout am Telefon. Kein Pult dazwischen.

CLAIMS: ✅ »Licht: Art-Net + sACN (DMX über Netzwerk), Grand Master + Blackout« · Mapping wörtlich aus `ArtNetSender.dmxChannels(for:)` (ch1 Dimmer=0,3+0,7·Kohärenz, ch2 R=Puls, ch3 G=HRV, ch4 B=Atemphase). NICHT in der Caption: sACN-Quellname »Echoelmusic (DEMO)« (Geräte-Verify offen), BLE-Gurt (Verify offen).

### C. Caption F3 — Resolume / TouchDesigner
**en-US**
> One breath and Resolume learned the address. Echoel sends your pulse, HRV and breath as plain OSC — `/echoelmusic/bio/breath/phase` on layer opacity, `/heart/bpm` on an effect. In TouchDesigner it's an OSC In CHOP; only measured channels ever appear, so a missing channel means "not measured", never a fake zero.
> Address card — link in bio.
> #LiveVisuals #Resolume #TouchDesigner #OSC #GenerativeMusic #Echoel

CLAIMS: ✅ »OSC-Ausgabe des Bio-Signals an jede Software im Netz« · #245-Regel aus `VJ_BRIDGE.md` §1. Erst posten, wenn der Dreh die Vendor-Rezepte bestätigt hat (Grand Council §6(c): UNVERIFIED bis zur Probe).

### D. PR-Pitch (E-Mail an CDM / Synthtopia / BPB, en-US, ≤120 Wörter)
> Subject: A free iPhone instrument you play with your pulse — and it speaks Art-Net, ADM-OSC and MPE out
>
> Hi [Name],
> Echoelmusic is a bio-reactive instrument for iPhone: a fingertip on the camera measures the pulse, HRV coherence comes from Lomb-Scargle/Welch analysis, and the body drives a DDSP synth, a Metal visual and — over open standards — your rig: MIDI/MPE out (CoreMIDI source "Echoelmusic"), OSC, ADM-OSC objects, Art-Net/sACN lighting. No plugin, no account, no cloud, zero external dependencies. Free.
> It's built by Echoel (Michael Terbuyken), a Hamburg artist known for walk-in water-light-sound installations (Documenta, Ars Electronica, Fusion).
> 15-second clip: [link] · press kit: echoelmusic.com/press.html · TestFlight on request.
> Happy to do a call or a rig demo on video.
> — Michael

CLAIMS: ✅ Kamera-Puls · ✅ MIDI-Ausgang live · ✅ MPE-AUSGANG (Richtungswort »out«, §6) · ✅ OSC · ✅ ADM-OSC · ✅ Art-Net + sACN · ✅ Null externe Abhängigkeiten · ✅ Offene Standards · »Free« erlaubt (§7), kein Preis. Boilerplate-Sätze aus `docs/press.html`. Nach L: »TestFlight on request« → App-Store-Link.

### E. Forum-Post r/synthesizers (en-US)
> **Title:** I built an iPhone instrument that plays from my pulse (camera rPPG) — here's what your rig actually receives
> Body: Finger on the back camera → pulse, HRV and breath. Those drive a DDSP synth in the key/scale you pick (57 scales, 15 tuning systems). What leaves the phone, only when you switch it on: a CoreMIDI source named "Echoelmusic" with MIDI notes and MPE OUT (glide/slide/press per note over channels 2–16); OSC at /echoelmusic/bio/*; ADM-OSC objects; Art-Net/sACN. MIDI in plays ONE monophonic body voice — notes, pitch bend, CC 74 and channel pressure; MPE zones on the input are not there yet. .mid export carries tempo, 4/4 and key signature. Free, no account, no analytics. TestFlight link in the comments; happy to answer DSP questions.

CLAIMS: ✅ Kamera-Puls · ✅ Generative Komposition (57 Skalen, 15 Stimmungssysteme) · ✅ MIDI-Ausgang live · ✅ MPE-AUSGANG · ✅ MIDI-Eingang (EINE monophone Stimme — nie »spielt die Stimmen«, §6b) · ✅ MIDI-Export · ✅ OSC · ✅ ADM-OSC · ✅ Art-Net + sACN. Der MPE-IN-Satz ist die `press.html`-Formulierung (Roadmap-Satz, nicht Store-Metadaten).

### F. Forum-Post TouchDesigner (en-US, Assets/Tools)
> **Title:** OSC In CHOP recipe — pulse / HRV / breath from an iPhone (only measured channels are sent)
> Echoelmusic sends /echoelmusic/bio/heart/bpm, /heart/hrv, /breath/rate, /breath/phase, /coherence and per-beat /bio/event/heartbeat as UDP OSC (default port 8000). Rule worth knowing before you build: an address is sent only while its channel is actually measured — so a channel that never shows up in your CHOP was never measured, it's not a connection fault. /coherence needs ≥16 accepted RR intervals and may stay absent on a camera session. /echoelmusic/bio/synthetic (0/1) tells you whether it's a body or the demo generator — latch it as state. Recipe .tox + address card: [link].

CLAIMS: ✅ OSC-Ausgabe · ✅ »Dein Rig erfährt, ob ein Körper sendet oder der Demo-Generator« (OSC-Hälfte, #639/#785) · #245-Regel aus `VJ_BRIDGE.md` §1. Nie: /bio/motion, /bio/event/eeg (#215).

### G. Co-Marketing-Ask an Roman / Adamson (de-DE, kurz)
> Betreff: ADM-OSC aus einem iPhone in den FletcherMachine — eine Stunde Probe?
> Hallo Roman, seit Juni ist aus der Idee ein Sender geworden: Echoelmusic schickt /adm/obj/{n}/position/azimuth|elevation|distance und /gain — Atemphase links/rechts, HRV hebt, Kohärenz zieht heran. Bisher gegen einen OSC-Monitor geprüft, nie gegen einen echten Renderer. Hättest du eine Stunde am FletcherMachine? Wir zeichnen es auf, beide Seiten posten es, und Adamson hat eine Referenz für »offener Standard, Body-Source, kein SDK«. Kein Hersteller-Namensraum, nichts Proprietäres — nur der Standard.
> Viele Grüße, Michael

CLAIMS: ✅ »Immersiver Raum: ADM-OSC Objekt-Ausgabe« · Mapping aus `ADMOSCSender.admMessages(for:object:)`. Ehrlich: Renderer-Verify offen — die Probe IST der Verify.

### H. Co-Marketing-Ask an Johannes Bollmann (de-DE, kurz)
> Betreff: Ein Abend Panasonic + Echoel-Visual — Messe-Demo für dich, Beamer-Verify für mich
> Hallo Bolle, Echoelmusic bespielt inzwischen einen angeschlossenen Bildschirm als eigene Bühne — das Telefon bleibt Spielfläche, Puls und Atem treiben das Bild. Am Beamer habe ich es noch nicht gesehen. Ein Abend mit deinem Panasonic-Setup: du bekommst Demo-Material für Messe und Venue, ich den Nachweis am großen Bild. Wenn es sitzt, gerne als Angle für dein Magazin.
> Viele Grüße, Michael

CLAIMS: ✅ »Beamer/Externer Bildschirm« (#206; Geräte-Verify offen — deshalb »noch nicht gesehen« wörtlich). Nicht versprechen: Warping/Edge-Blend, NDI.

### I. Directory-Blurbs
**Kurz (≤80 Zeichen):** »Bio-reactive iPhone instrument — your pulse plays it. Free, on-device.«
**Lang (≤300 Zeichen):** »Echoelmusic is a bio-reactive instrument for iPhone: a fingertip on the camera measures pulse, HRV and breath, which drive a generative synth, live visuals and — over open standards — your rig: MIDI/MPE out, OSC, ADM-OSC, Art-Net/sACN. No account, no cloud, zero dependencies. Free.«
**de-DE Kurz:** »Bio-reaktives iPhone-Instrument — dein Puls spielt es. Kostenlos, auf dem Gerät.«
CLAIMS: ✅ Kamera-Puls · ✅ Bio-reaktive Visuals · ✅ MIDI-Ausgang/MPE-AUSGANG · ✅ OSC · ✅ ADM-OSC · ✅ Art-Net + sACN · ✅ Null externe Abhängigkeiten · »kostenlos« (§7).

### J. E-Mail 1 an TestFlight-Tester (en-US, Kernzeilen)
> Subject: Your pulse should lock in about 14 seconds
> Thanks for testing. Two things: (1) put the pad of your finger flat over the back camera, let the torch come on, hold still — the number locks in roughly 14 seconds on most phones. (2) Open the Sound chip and switch genres while it plays. Then reply with one line: build number + what you heard. That one line is what moves this app forward.
> Biofeedback here is for self-observation, not medical diagnosis.
CLAIMS: ✅ Kamera-Puls (14 s aus Log 2477 — »roughly«, nicht als Garantie) · ✅ Generative Komposition (Sound-Chip = `soundPanel`, erreichbar).

### K. E-Mail 2 (en-US, Kernzeilen)
> Subject: What's in your rig?
> Attached: the one-page OSC address card. Three recipes inside: Resolume OSC-learn, TouchDesigner OSC In CHOP, Network MIDI session (source "Echoelmusic", MPE out). Reply with one word — lights, VJ, DAW, spatial — and I'll send the recipe that fits.
CLAIMS: ✅ OSC · ✅ MIDI-Ausgang · ✅ MPE-AUSGANG. Lead Magnet = `docs/integrations/` (Grand Council §7 Schritt 2).

### L. E-Mail 3 / Launch (en-US, Kernzeilen)
> Subject: Echoelmusic is on the App Store
> Free, no account, no cloud — same build you tested. If it earned it, a rating helps more than anything I can post. Next on the bench (not in this build): MPE input zones and OSC-in control. Thank you.
CLAIMS: §4 (erst NACH Freigabe senden) · ✅ Null externe Abhängigkeiten · Roadmap-Satz nur hier und auf `press.html`, nie in Store-Metadaten.

## KPIs

- Rohmaterial: Anzahl gedrehter Flagship-Clips (Ziel 3 bis W8) — messbar an Einträgen in `ContentPipeline/Assets/README.md` (Dateiname · Datum · Build)
- Veröffentlichungen: Zeilen in `ContentPipeline/Published/LOG.md` pro Woche (Ziel ≥2 Kurzvideos/Woche ab W2; heute 0) — `grep -c '^| 20' ContentPipeline/Published/LOG.md`
- Hook-Qualität: 3-Sekunden-Halterate und Durchschau-Rate von F1 auf TikTok/Reels/Shorts (Plattform-Analytics, je Post in LOG.md notieren; Ziel >30 % Durchschau bei 15 s)
- TestFlight: Tester-Anzahl und Sessions (App Store Connect → TestFlight), plus Anzahl beantworteter Geräte-Notizen; Sekundär: `python3 scripts/founder-verify.py` — die 116/0-Kette muss sinken (erste `VERIFIED-`Daten = Beweis, dass die Prüfschleife schließt)
- Store ab L: Downloads Tag 1 / 7 / 30, Bewertungen (Anzahl + Durchschnitt), Impressions→Product-Page→Install-Conversion (ASC Analytics)
- Rig-Beweise: Anzahl fremder Rigs, die Echoel-Daten nachweislich empfangen haben (Forum-Antworten/Clips mit Resolume, TD, Art-Net-Node, DAW) — Ziel 5 bis W13; jede zählt als externes Verify
- Presse/Community: Anzahl Erwähnungen in den 10 Zielkanälen (Ziel 3 Outlets + 4 Community-Threads mit >10 Antworten bis W13); Backlinks auf echoelmusic.com/press.html und docs/integrations/
- Lead Magnet: Downloads der OSC-Adresskarte + Antworten auf Mail 2 (Segment-Verteilung Licht/VJ/DAW/Spatial) — Werkzeug founder-gated; bis dahin Zählung der `mailto`-Antworten
- Directory: Anzahl live gelisteter Einträge (Ziel 6 bis W8, inkl. ADM-OSC-Implementierungsliste und KVR)
- Co-Marketing: 2 von 3 Asks (Adamson · Bollmann · Grapes) mit Termin bis W12; jeder Termin schließt gleichzeitig einen offenen Geräte-Verify (ADM-OSC-Renderer · #206 Beamer)

## Die ersten drei Aktionen dieser Lane

1. EINE Geräte-Session (Founder, ~1 h, 0 Deploys): Flagship 1 »Pulse → Sound« nach Shot-List drehen (zweites Telefon für die Makro-Einstellung, Bildschirmaufnahme am Gerät, aktueller TestFlight-Build im Bild) + 6–8 echte Screenshots für `docs/press.html` — heute ist `Published/LOG.md` leer, `docs/screenshots/` hält nur HTML, und jede Zeile dieses Plans hängt an diesem Material. Roh nach `ContentPipeline/Assets/` benennen (nicht committen), mit `autocut.py proxy`/`zoom --aspect 9:16` schneiden.
2. `docs/integrations/` anlegen (Grand Council §7 Schritt 2 — »proceed«, 0 gated Dateien, ein Ralph-Zyklus): OSC-Adresskarte als eine Seite aus `docs/dev/VJ_BRIDGE.md` §1 + ADM-OSC-Objektzeilen + Art-Net/sACN-Slot-Map + MIDI-Quelle »Echoelmusic«/MPE-OUT-Schalter, dazu Resolume-OSC-Learn- und TouchDesigner-CHOP-Rezept; CISmoke-Wächter, der die Template-Adressen gegen `OSCSender`/`ADMOSCSender`/`ArtNetSender` greppt (nie motion/eeg, #215). Das ist Lead Magnet, Forum-Anhang und Mail 2 in einem. Dabei `docs/dev/FEATURE_MATRIX.md:271-272` (»EchoelStage — Code: none«) als veraltet berichten — `Studio/ExternalDisplayScene.swift` existiert.
3. Die drei Handles, die `docs/index.html:86-88` bereits deklariert (instagram.com/echoelmusic · tiktok.com/@echoelmusic · youtube.com/@echoelmusic), bestätigen bzw. anlegen; Bio-Link = TestFlight-Mailto; Flagship 1 mit Caption A posten und die ERSTE Zeile in `ContentPipeline/Published/LOG.md` schreiben. Parallel die zwei Co-Marketing-Mails (G an Roman/Adamson, H an Bollmann) abschicken — jeder Termin ist zugleich ein offener Geräte-Verify (ADM-OSC-Renderer · #206 Beamer).

## Verwendete Behauptungen (für den Kritiker)

- Der Puls wird mit der iPhone-Kamera gemessen (Finger auf die Linse, rPPG) — live; Log 2477: Lock in 14 s
- Herzschlag, HRV und Kohärenz modulieren Klang in Echtzeit — EchoelDDSP Bio-Mappings, FXBioModulator
- Generative Komposition in gewählter Tonart/Skala/Genre, tonartrein — BioComposer, 57 Skalen, 15 Stimmungssysteme
- Bio-reaktive Visuals live auf dem Gerät (Metal) — MetalBioView, FloatingVisualWindow
- Das Bild ist SPIELBAR: Berühren des Visuals erzeugt tonartreine Noten auf dem Klang des Takes — EINE Fläche, nicht »Touch-Instrumente«
- Licht: Art-Net + sACN (DMX über Netzwerk), Grand Master + Blackout — EchoelLux, unicast live
- Immersiver Raum: ADM-OSC Objekt-Ausgabe (/adm/obj/{n}/*) — ADMOSCSender
- OSC-Ausgabe des Bio-Signals an jede Software im Netz — OSCSender, Adressliste in CLAUDE.md
- MIDI-Export der erzeugten Musik als .mid — MIDIFileExporter, Tür im Export-Schacht
- MIDI-Eingang: ein externer Controller spielt EINE monophone Stimme — Noten, Pitch-Bend, Press (Channel Pressure, #939) und Slide (CC 74, #942)
- MIDI-Ausgang live: gespielte NOTEN an dein Rig (MIDI 1.0) — MIDIOutput, Schalter in der Routing-Fläche, Default AUS
- MPE-AUSGANG an Dein Rig: Zone angekündigt, Noten über Member-Kanäle 2–16, jede mit Glide, Slide und Press — Nur MIT Richtungswort schreiben (§6)
- Dein Rig erfährt, ob ein Körper sendet oder der Demo-Generator: OSC /echoelmusic/bio/synthetic (1 = Demo, 0 = echter Körper), sACN Quellname »Echoelmusic (DEMO)« — sACN-Hälfte: Geräte-Verify offen; NIE »alle Ausgänge«
- Universeller BLE-Herzgurt (0x180D), z. B. Polar H10 — gebaut + verdrahtet, Geräte-Verify offen (in keinem Video als Quelle gezeigt)
- Apple Health als Pulsquelle — HealthKitBioPublisher
- Offene Standards, kein SDK-Lock-in — OSC · ADM-OSC · MIDI · Art-Net/sACN · BLE HRS
- Null externe Abhängigkeiten, alles on-device — Package.swift: dependencies: [] UND project.yml ohne packages:-Block
- Barrierefrei spielbar: Notennamen International/Deutsch/Solfège, VoiceOver auf der Spielfläche, Atkinson Hyperlegible
- Deine Stimme wird die Klangfarbe des Instruments — gebaut + verdrahtet, Geräte-Verify offen; Formulierung §11: MESSUNG, nie »Aufnahme« (nur als Fallback-Thema nach Verify)
- Visual-Aufnahme + mp4-Export: das laufende Visual wird auf dem Gerät aufgezeichnet und aus der Video-Bibliothek geteilt — VisualRecorder + videoPanel
- Beamer/Externer Bildschirm: das Visual bespielt ein angeschlossenes Display als eigene Bühne — ExternalDisplayScene (#206); Geräte-Verify laut Grand Council §7 Schritt 1 offen
- §4: »Im App Store« / Store-Link — Es gibt heute nur TestFlight. Erst nach der ersten Freigabe umstellen.
- §7: Erlaubt: »kostenlos«. Nicht erlaubt: irgendein Preis, »Pro-Version«, »Abo«, »Trial«.
- §6b: Erlaubt: »steck einen Controller an und spiel die Körperstimme«. Nicht erlaubt: »spielt die Stimmen«, »spiel Akkorde«, »polyphon«.
- §12 Vier-Kanal-Tabelle: Kohärenz → Filter-Cutoff · Brillanz · Harmonizität · Rauschanteil · HRV → Brillanz · Herzfrequenz → Vibrato · Brillanz · Atemphase → Amplituden-Schwelle · Kohärenz-Trend → Klangform-Morph (#813)
- §2: Erlaubt ist die Beschreibung des Mechanismus (»ruhiger Puls → andere Musik«). Nicht erlaubt ist die Wirkungsbehauptung.
- §9: »Biohacking« — Nie in Skript, Caption, Hashtag oder Titel.
- §10: Erlaubt: »das fertige Video teilen«. Nicht erlaubt: »postet für Dich«.
- Sprache: Blitzrate in jedem Videomaterial ≤ 3 Hz (W3C WCAG, Epilepsie). Das gilt auch für den Schnitt, nicht nur für die App.

## Kritik

*Der Kritiker dieser Lane ist am Sitzungslimit gestorben. Die Sitzung hat die Lane per Regex auf die Guardrail-Begriffe geprüft (Ergebnis im Guardrail-Protokoll oben); eine Zeile-für-Zeile-Kritik steht aus und ist Teil der ersten fünf Aktionen.*
