# Widersprüche zwischen Gesetz, Vision, Plan, CLAIMS, Memory und Chat

Gemessen an `origin/main` = `ce2305911` (2026-11-04 18:18), dazu der Founder-Chat dieser Sitzung
(`/root/.claude/projects/-home-claude/dda6425b-….jsonl`) und der Grok-Übergabeprompt
(`/mnt/user-data/attachments/…/0d49945e-attachment.txt`, 2026-11-04 ~13:18). **Nichts ist aufgelöst.**
„Neuer" = das jüngere datierte Founder-Wort; nach der Konfliktregel in `ECHOEL_VISION_2026-10-19.md` §1
gilt es, bis die ältere Stelle nachgezogen ist. Zeilennummern sind Daten vom Messzeitpunkt.

## Hoch — eine Sitzung handelt sonst falsch

| # | Stelle A (älter) | Stelle B (neuer) | Worum es geht |
|---|---|---|---|
| C1 | `CLAUDE.md:77` „höchstens EIN TestFlight-Build pro Woche" (W-MAP, 2026-11-01); ebenso `TESTFLIGHT_PUBLIC_BETA.md:39-40` „bis zur Geräte-Session keine neue Feature-Welle"; `decisions.csv` Z. 1355/1361/1365 | `decisions.csv` Z. 1369 (2026-11-04): Wochenrhythmus ausgesetzt, Build bei jedem grünen stimmigen Stapel; Z. 1365 (11-01) hob die Feature-Pause schon auf; Chat 2026-11-04 14:36 „immer wieder TestFlight deploy" | Die immer geladene Karte nennt eine aufgehobene Regel |
| C2 | `FOUNDER_PRODUCT_LAW.md:59` „no funding applications anywhere"; `ECHOEL_VISION…md:3` Nachtrag 10-24; `FOUNDER_INBOX.md` GM35 „[x] keine Förderung, nirgends"; `NEUPLANUNG…md` §5 Absatz „GEGENSTANDSLOS"; Grok-Prompt („Förderung … gestoppt") | `decisions.csv` Z. 1368 (2026-11-04) „Funding reopened … from the week of 2026-11-09"; `memory/decisions.md` letzter Eintrag; Chat 2026-11-04 12:28 | Gesetz, Vision und Inbox sagen weiter „gestoppt" |
| C3 | `FOUNDER_PRODUCT_LAW.md:48` und §7 Z. 275: der Masterplan beantwortet „in welcher Reihenfolge … gebaut"; `CLAUDE.md:23` nennt `ECHOELMUSIC_MASTER_PLAN.md` §10 als „Cross-platform plan" | `ECHOELMUSIC_MASTER_PLAN.md:1` Banner (seit 2026-10-17 GESCHICHTE der Alt-App); `ECHOEL_VISION…md:460` §11.1 „Masterplan = Geschichte" | Zwei Autoritätskarten; der Masterplan sagt u. a. „Plugin hosting IDEA" (Z. 227, 632) und „iPhone ships today, then iPadOS" (§10) — beides für Studio falsch |
| C4 | `FOUNDER_PRODUCT_LAW.md:259` §6: das Fünf-Check-Gate „Instrument-Complete v1" bleibt das Gate des nächsten Store-Releases (Alt-App-Begriffe: Genres, `soundPanel`) | `TESTFLIGHT_PUBLIC_BETA.md` §0 G1–G6 (2026-11-01) und `NEUPLANUNG…md` §5 P2 „→ App Store 1.0" | Drei verschiedene Abnahmen für „1.0" |
| C5 | `docs/privacy.html:111` „no image or video is stored or sent" (Kamera) | `EchoelStudio/project.yml:107` Kamera-Text „films a video take … saved only in your song"; `App/Media/VideoTakeRecorder.swift` | Datenschutzseite unvollständig → GM41 offen (2026-11-04) |
| C6 | `ECHOEL_VISION…md:307` §6e und `docs/accessibility.html:91,127` (+ FAQ-JSON in `docs/faq.html:44`) „Reduce Motion wird nirgends gelesen" | Code: `App/Field/FieldView.swift:16`, `App/Media/VideoMonitor.swift:199` lesen `accessibilityReduceMotion` (Grok-Prompt meldet dasselbe) | Website unterbehauptet; G4 (ehrlich nach außen) betroffen |
| C7 | `memory/preferences.md:23` „Zero external dependencies policy"; `ECHOEL_VISION…md:110, 329` „keine externen Abhängigkeiten / Pakete"; `.claude/rules/engineering.md:13` | `EchoelStudio/project.yml:37-43` HaishinKit 2.2.5 (W14, 2026-10-29); `THIRD_PARTY_NOTICES.md:61` | Studio hat seit 29.10. eine fremde Abhängigkeit (mit libsrt-Binary) |
| C8 | `ContentPipeline/CLAIMS.md:173` „„quantize", „split", „edit velocity": gibt es nicht"; Z. 145 „six presets, four waveforms"; Nachtrag 5 „sechs Synth-Engines" | `App/Views/ClipEditorView.swift:362-374` Quantize + Humanize; `DSP/…/SynthEngine.swift:15` acht Engines (ddsp, choir); Split seit Nachtrag 6 | CLAIMS hinkt dem Code nach (Unter-Behauptung; bleibt bis zu einem eigenen Nachtrag verboten) |
| C9 | `FOUNDER_INBOX.md` GM28 (Store-Text) „[ ] offen"; LR2 (LICENSE) „[ ] offen" | `CLAIMS.md` Nachtrag 5 (2026-10-29): GM28 auf Founder-Wort umgesetzt; `decisions.csv` Z. 1336 (10-31) LICENSE reiner MIT-Text — `LICENSE` ist heute reiner MIT (21 Zeilen) | Inbox zeigt erledigte Fragen als offen |
| C10 | `ECHOEL_VISION…md:43, 328` „offener Code unter MIT", GM38-Empfehlung „MIT behalten" | `FOUNDER_PRODUCT_LAW.md:61` / `decisions.csv` Z. 1331 (10-24): nach dem Store-Start „geht das Repository auf privat" (GM36 offen) | Offenheit vs. privates Repo — Founder-Entscheidung, nicht auflösbar durch Claude |

## Mittel — veraltete Beschreibung, die Pläne verzerrt

| # | Stelle A | Stelle B | Worum es geht |
|---|---|---|---|
| C11 | `memory/vision.md:30, 49` Body = „the differentiator"; `memory/user.md:10` „bio-reactive instrument … single EchoelStudioView" | `FOUNDER_PRODUCT_LAW.md:27-33` (2026-10-15) „Biofeedback ist nur ein kleines gimmick"; Studio | Memory beschreibt die Alt-App-Identität |
| C12 | `memory/vision.md:102` „Echoel AS an AUv3 — NO code", „Hosting third-party AU is decided OUT (#190)"; Z. 164 „v1.0 kostenlos, keine Kauf-UI" | `Plugins/AUv3/Info.plist` (21 Units + `echl`), `App/Engine/PluginHost.swift`, CLAIMS Nachträge 1/4 (Einmalkauf gebaut) | Memory verneint gebaute Fähigkeiten |
| C13 | `EchoelStudio/CLAUDE.md:4` „no generated notes"; `NEUPLANUNG…md` §0.2 „keine generierten Noten"; Vision §1 Tabelle „NEUSTART: ohne Körper, Visual, Video …" | `decisions.csv` Z. 1332/1333 (2026-10-25): 1.0 mit Körper, Bild, Video, Stimme, generativer Intelligenz auf dem Gerät | Studio-Gesetzdatei nennt einen aufgehobenen Umfang |
| C14 | `EchoelStudio/CLAUDE.md:22` AUv3-Liste: Synth/Drums/Sampler + EQ/Compressor/Delay/Reverb + `echl` | `Plugins/AUv3/Info.plist`: 18 Effekt-Units (`xEQ5` … `xGrn`) | Layout-Tabelle unvollständig |
| C15 | `CLAUDE.md:117-119` „SAFETY WARNINGS (must be in app)": „Brainwave Entrainment: NOT while operating vehicles", „Therapeutic use: coordinate medications" | Produktgesetz §4, `HISTORY_ARCHIVE.md` §N (Entrainment DO NOT RESTORE), CLAIMS §2 (nie Therapie) | Die Karte setzt Entrainment/Therapie als existierend voraus |
| C16 | `MusicalContext.swift:140-156` Planeten-Kammertöne nach Cousto („Earth year", „Venus" …), im Song-Menü sichtbar | Produktgesetz §4 (keine 432-Hz-/esoterischen Rahmungen), `HISTORY_ARCHIVE.md` §N; Grok-Prompt nennt es Rote-Linien-Treffer | Code sagt „arithmetic, not a claim"; Entscheidung GM40 offen; `decisions.csv` Z. 1371 lässt die Sichtbarkeit bis dahin |
| C17 | `decisions.csv` Z. 1333 (10-25) „Gesicht und Bewegung als Modulationsquellen" in 1.0 | `FOUNDER_PRODUCT_LAW.md:139` §2 (#1301 face/body: „Research, needs founder consent and privacy design"); §4b (keine Identifikation/Profilbildung) | Bestellt, aber nur mit Einwilligungs-/Datenschutz-Design zulässig; nicht gebaut |
| C18 | `decisions.csv` Z. 1333 und `ECHOEL_VISION…md:5` „Autotune" | `CLAUDE.md` „Sprache" / Z. 1364: nie „Autotune" (Marke), „pitch correction" | Wortlaut in internen Entscheidungen; Code sagt „Pitch Correction" |
| C19 | `ECHOEL_VISION…md:356-372` §8: App Store 1.0 Ziel März 2027, P3–P7 in 1.1–1.4 | Z. 1331 „so schnell wie möglich", Z. 1332 „1.0 enthält alles"; `NEUPLANUNG` §5 Banner „Versions-Spalte überholt" | Zeitachse vs. „1.0 = alles" — Datum folgt der Auslieferung (Vision-Nachtrag 10-25) |
| C20 | `NEUPLANUNG…md:36` „hostet beliebige AUv3" | `CLAIMS.md:172` „„any Audio Unit": nur Stereo-Units" | Planungstext überbehauptet |
| C21 | `ECHOEL_VISION…md:43, 344` §0.5/§7: Förderung als Einnahmelinie, Prototype Fund bis 30.11. | Z. 1329 (10-24) gestoppt, dann Z. 1368 (11-04) wieder offen „für alle Förderlinien" — welche Linien/Fristen, ist nirgends neu festgelegt | Zwei Wechsel in elf Tagen; die Vision trägt den Stand vom 19.10. |
| C22 | Grok-Prompt 2026-11-04: Synth/Sampler spielen nur 12-TET, Swing wird nicht abgespielt (`PolySynth.swift:136`) | `decisions.csv` Z. 1371 W13 gemerged (Tonsystem + Swing hörbar); `RELEASE` 10033 | Grok-Befund überholt — nicht erneut bauen |
| C23 | `FOUNDER_PRODUCT_LAW.md:74` und `CLAUDE.md:51` Domänen „MIDI / MPE" | CLAIMS Nachtrag 6 / `CLAUDE.md` „Sprache": „MPE" nur als „MPE-Ausgang", MPE IN gibt es nicht | Intern zulässig als Ziel; nach außen nie ohne Richtungswort |
| C24 | `memory/decisions.md` enthält zum 2026-11-01 nur W-MAP (0 Treffer „Waffen/weapon") | `decisions.csv` Z. 1357-1360 (§4b, §4c, kein eigener Browser) | Gedächtnislücke: Begründung der zwei neuen roten Linien fehlt in `memory/decisions.md` |

## Spannungen (kein harter Widerspruch, aber Richtung uneindeutig)

- **S1 Identität:** Produktgesetz 10-15 „Produktion zuerst, Bio optional" ↔ Chat 2026-11-01 14:29 „ganz nah am Instrument … Stabilität, Video, Visuals" ↔ Grok-Prompt „bio-reaktives Musikinstrument und Produktionsumgebung". Lesart im Kompass: Produktion ist der Kern, das *Qualitätsniveau* der Alt-App (Latenz, Bild) ist die Messlatte — ANNAHME, nicht vom Founder bestätigt.
- **S2 Plattform:** Founder 2026-07-31 „gesamtes Apple-Ökosystem", Z. 1331 „zeitgleich" ↔ Studio baut nur `"1,2"` (iPhone/iPad); Watch/Mac/Vision haben kein Studio-Target (GM16/GM36).
- **S3 Eine KI schreibt:** steht nur im Grok-Übergabeprompt, nicht im Repo; `learn-mode` deckt „fremde Modelle = Daten" ab, nicht „nur Claude committet".
- **S4 Tauchfliege:** aufgelöst 2026-11-04 — Tauchfliege ist ein eigenes, privates Projekt von Michael; nicht Teil von Echoelmusic.
