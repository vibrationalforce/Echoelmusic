# Bericht ChatGPT · Auftrag 12
## 1. Kopf

- Modell: ChatGPT
- Branch: orchester/chatgpt/website-claims
- Basis-Commit: 3a47150c5
- Letzter Commit: 2ea661a20034f5b2fb397cf1c388c7f3f4788718 (letzter Website-Commit; separater Berichts-Commit folgt, siehe Abschnitt 7)
- Datum/Uhrzeit (UTC) des letzten Pushs: Website-Schreibvorgang am 2026-10-12 um 18:09:36 UTC erfolgreich bestätigt; Zeitpunkt des nachfolgenden Berichts-Pushs hier noch nicht verfügbar.
- Ausschließlich Vorschlag; keine Freigabe zur Veröffentlichung. Vollständige Basis: 3a47150c5be679116edf0432350b548c9ff0ed31.

## 2. Commits (alle, in Reihenfolge)

| SHA (7) | Commit-Zeile | Dateien |
|---|---|---|
| 8031138 | docs(claims): describe the monophonic MIDI input | docs/index.html |
| 0a32f6c | docs(claims): remove the FAQ plugin denial | docs/faq.html |
| 45f03fc | docs(claims): qualify Bluetooth instead of promising zero latency | docs/faq.html |
| 94479a2 | docs(claims): mark MIDI 2.0 device verification as pending | docs/faq.html |
| 2cfaee0 | docs(claims): describe creative use without clinical framing | docs/health.html |
| 3dc30b1 | docs(claims): remove the unsupported absolute flash guarantee | docs/health.html |
| dd4863e | docs(claims): remove the unapproved entrainment listing | docs/architecture.html |
| 6766e6b | docs(claims): distinguish MIDI input from MPE | docs/architecture.html |
| 1cc30c2 | docs(claims): correct the AUv3 heading | docs/architecture.html |
| 2ea661a | docs(claims): qualify the sACN console display | docs/artnet-sacn-from-a-phone.html |
| selbstreferenziell nicht eintragbar | docs(report): document website claims proposal and limits | reports/orchester-berichte/2026-10-12_chatgpt_website-claims.md |

Alle Commit-Nachrichten enden mit: Orchester: ChatGPT · Auftrag 12.

## 3. Dateien

| Pfad | + Zeilen | − Zeilen | Warum genau diese Datei |
|---|---:|---:|---|
| docs/index.html | 1 | 1 | MIDI-Verneinung |
| docs/faq.html | 3 | 3 | AUv3, Latenz und MIDI-2.0-Vorbehalt |
| docs/health.html | 2 | 2 | Kreative Rahmung und unbelegte Schutzgarantie |
| docs/architecture.html | 3 | 3 | AUv3, MPE-Eingang und nicht freigegebene Frequenzfunktion |
| docs/artnet-sacn-from-a-phone.html | 1 | 1 | Unbestätigte Pultanzeige |
| reports/orchester-berichte/2026-10-12_chatgpt_website-claims.md | 138 | 0 | Pflichtbericht |

## 4. Änderungen im Einzelnen

Zeilennummern gelten im neuen Website-Stand; keine Zeilen wurden eingefügt oder entfernt. Alt/Neu sind wörtliche Quelltextausschnitte einschließlich vorhandener HTML-Auszeichnung. Belege stammen aus den vorgegebenen Registern am Basis-Commit, nicht aus einer eigenen Implementierungsprüfung.

1. **docs/index.html:808** — Widerspruch zum vorhandenen MIDI-Eingang entfernen.
   - Vorher: `No MIDI.`
   - Nachher: `MIDI input plays one monophonic voice.`
   - Beleg: ContentPipeline/CLAIMS.md:73.

2. **docs/faq.html:182** — Plugin-Verneinung an freigegebenen AUv3-Status angleichen.
   - Vorher: `Neither &mdash; it is a standalone instrument.`
   - Nachher: `It is a standalone instrument and an AUv3 instrument.`
   - Beleg: ContentPipeline/CLAIMS.md:115–128.

3. **docs/faq.html:110** — Null-Latenz-Versprechen und unbelegte Fremdempfehlung durch bedingten BLE-Status ersetzen.
   - Vorher: `For a <strong>latency-free live experience</strong>, use the camera pulse or a standard Bluetooth heart-rate device — which is exactly what Oura itself recommends for live heart rate.`
   - Nachher: `For a <strong>Bluetooth heart-rate source</strong>, use a standard BLE heart-rate device — device verification is still pending.`
   - Beleg: ContentPipeline/CLAIMS.md:78.

4. **docs/faq.html:174** — Pflichtvorbehalt zur zweiten MIDI-Quelle ergänzen.
   - Vorher: `A second source, &ldquo;Echoelmusic (MIDI&nbsp;2.0)&rdquo;, mirrors the same notes in the MIDI&nbsp;2.0 protocol (16-bit velocity, 32-bit bend and controllers) behind its own routing switch.`
   - Nachher: `A second source, &ldquo;Echoelmusic (MIDI&nbsp;2.0)&rdquo;, mirrors the same notes in the MIDI&nbsp;2.0 protocol (16-bit velocity, 32-bit bend and controllers) behind its own routing switch; device verification is still pending.`
   - Beleg: ContentPipeline/CLAIMS.md:75.

5. **docs/health.html:135** — Berufs-/Behandlungsrahmung durch kreativen Mechanismus ersetzen.
   - Vorher: `<strong>For Coaches &amp; Therapists:</strong> If you use Echoelmusic in professional practice, ensure clients understand this is a creative tool, not a therapeutic device. It does not replace clinical biofeedback equipment or professional treatment.`
   - Nachher: `<strong>Creative use:</strong> Echoelmusic uses biofeedback as a control source for music and visuals.`
   - Beleg: ContentPipeline/CLAIMS.md:62–64, 153–161.

6. **docs/health.html:115** — Unbelegte absolute Schutz- und Unabschaltbarkeitszusage auf bestätigte Ausgänge begrenzen.
   - Vorher: `Echoelmusic does not strobe: visual flash is capped below 3 Hz by design (W3C WCAG photosensitivity guidance), the cap applies to on-screen visuals and to Art-Net / sACN light output alike, and it cannot be switched off.`
   - Nachher: `Echoelmusic provides bio-reactive visuals and Art-Net / sACN lighting output.`
   - Beleg: ContentPipeline/CLAIMS.md:64, 66.

7. **docs/architecture.html:228** — Nicht freigegebene Frequenzfunktion aus der Werkzeug-Aufzählung streichen.
   - Vorher: `<code>EchoelVDSPKit</code> (DFT, real FFT with 5 windows, FIR convolution, biquad cascade / parametric EQ, decimator, spectral analyzer), <code>EchoelSVFilter</code> (Chamberlin LP/HP/BP/notch), <code>EchoelLFO</code> (5 waveforms, 0.01–20&nbsp;Hz), <code>EchoelEntrainment</code> (isochronic Delta&nbsp;2 / Theta&nbsp;6 / Alpha&nbsp;10 / Beta&nbsp;20 / Gamma&nbsp;40&nbsp;Hz).`
   - Nachher: `<code>EchoelVDSPKit</code> (DFT, real FFT with 5 windows, FIR convolution, biquad cascade / parametric EQ, decimator, spectral analyzer), <code>EchoelSVFilter</code> (Chamberlin LP/HP/BP/notch), <code>EchoelLFO</code> (5 waveforms, 0.01–20&nbsp;Hz).`
   - Beleg: ContentPipeline/CLAIMS.md:153–161.

8. **docs/architecture.html:190** — Eingang nicht als MPE darstellen.
   - Vorher: `Each axis becomes a <code>ControllerEvent</code> on the bus — this is the <strong>multidimensional (MPE)</strong> layer: one note carries several continuous, independent dimensions of expression.`
   - Nachher: `Each axis becomes a <code>ControllerEvent</code> on the bus — this is <strong>monophonic MIDI input</strong>: notes, pitch bend, slide and channel pressure reach one voice.`
   - Beleg: ContentPipeline/CLAIMS.md:73, 233–246.

9. **docs/architecture.html:259** — Widersprüchliches Plugin-Label berichtigen.
   - Vorher: `<h2>Standalone instrument <span class="tag">NOT A PLUGIN</span></h2>`
   - Nachher: `<h2>Standalone instrument <span class="tag">AUv3 INSTRUMENT</span></h2>`
   - Beleg: ContentPipeline/CLAIMS.md:115–128.

10. **docs/artnet-sacn-from-a-phone.html:111** — Senden des Markers von unbestätigter Pultanzeige trennen.
   - Vorher: `Every packet carries the E1.31 <strong>Source Name</strong> your console shows in its source list: normally <code>Echoelmusic</code>, and <code>Echoelmusic (DEMO)</code> when the built-in simulator is driving the rig rather than a measured body &mdash; so an operator can tell a rehearsal from a performance without asking.`
   - Nachher: `Every packet carries the E1.31 <strong>Source Name</strong>: normally <code>Echoelmusic</code>, and <code>Echoelmusic (DEMO)</code> when the built-in simulator is driving the rig rather than a measured body &mdash; whether a console updates this name during a session still needs device verification.`
   - Beleg: ContentPipeline/CLAIMS.md:77.

## 5. Was ich geprüft habe — und wie

- Gelesen: Texte, Metadaten und vorhandene strukturierte Beschreibungen der fünf beauftragten Seiten; Abgleich mit CLAIMS.md und FEATURE_STATUS.md am festen Basis-Commit. Mehr als zehn auffällige Stellen; dieser Vorschlag bereinigt nicht die gesamte Website.
- Ausgeführt: exakte Textvergleiche im Werkzeuglauf; jede der zehn Ersetzungen fand genau eine Fundstelle. Keine neuen Absätze, CSS-, Layout- oder Skriptänderungen.
- Ausgeführt: Rücklesen aller fünf geänderten Dateien von GitHub und vollständiger Inhaltsvergleich; alle stimmen mit den vorgeschlagenen Fassungen überein.
- Ausgeführt: Zeilen- und HTML-Tag-Vergleich. Alle Zeilenzahlen unverändert; Tagfolge unverändert außer dem entfernten Inline-code-Element innerhalb der gestrichenen Toolkit-Aufzählung.
- Gelesen: GitHub-Compare. Erster eigener Commit hat genau den verlangten Basis-Commit als Elternteil; zehn Website-Commits, jeweils ein Gedanke, alle mit Pflichtabschluss.
- Nicht kompiliert, keine Tests oder Workflows gestartet, kein Browser-Rendering, keine Geräte-, Protokoll-, Latenz- oder Schutzwirkungsprüfung. Aussagen über Implementierungen nur aus den beiden Registern übernommen.
- Ein historischer privater Protokoll-/Messwert in der Wahrheitsquelle wurde bemerkt; weder zitiert noch als Beleg verwendet. Keine privaten Dateien oder Logs angefordert.

## 6. CI

Für den letzten Website-Commit 2ea661a20034f5b2fb397cf1c388c7f3f4788718: GitHub-Actions-Run-Collection nach SHA gelesen; keine Läufe sichtbar. Für den nachfolgenden Berichts-Commit: nicht sichtbar für mich zum Erstellungszeitpunkt dieses Textes. Keine erfolgreiche CI behauptet.

## 7. Abweichungen vom Auftrag

- Die geforderte vollständige SHA, Pushzeit und CI des Berichts-Commits können nicht im identischen Inhalt dieses Commits stehen: eine nachträgliche Eintragung erzeugt einen weiteren Commit mit anderer SHA. Deshalb nennt Abschnitt 1 ausdrücklich den letzten Website-Commit, Abschnitt 2 den anschließenden Berichts-Commit ohne erfundene SHA. Diese formale Anforderung bleibt unerfüllt; die Datei-Historie zeigt den Berichts-Commit.
- Die Zehnergrenze ist ausgeschöpft. Weitere ungedeckte Aussagen bleiben stehen; keine vollständige Claims-Freigabe.
- Auch ein Überschriftslabel und ein Aufzählungsteil wurden als Textänderungen behandelt; keine zusätzliche Funktion oder Gestaltung.
- Kein Schreiben außerhalb des einen Vorschlags-Branches. Keine Übernahme nach main und keine Veröffentlichung.

## 8. Verbotsliste eingehalten?

Ja hinsichtlich Schreibziel und Pfaden. Vollständige Dateiliste gegenüber der Basis einschließlich dieser Berichtsdatei:

M docs/architecture.html
M docs/artnet-sacn-from-a-phone.html
M docs/faq.html
M docs/health.html
M docs/index.html
A reports/orchester-berichte/2026-10-12_chatgpt_website-claims.md

Keine verbotenen Pfade geändert; keine Tags, PRs, Issues, Kommentare, Reviews, Releases, Branchlöschungen, Force-Pushes, Merges oder Workflow-Starts. Genau ein Branch aus der verlangten SHA angelegt. Wahrheitsquellen unverändert.

## 9. Offene Fragen an Claude Code (höchstens 5)

1. Ist CLAIMS.md:190–192 („SamplerVoice … TÜRLOS“) veraltet gegenüber FEATURE_STATUS.md:177 und 192–193 (Sampler je Spur mit TrackSampleRow)? Die widersprüchlichen Website-Verneinungen in faq.html:130 und architecture.html:252/404 bleiben deshalb unverändert.
2. Wie soll der noch nicht konsistente Workstation-/Export-Stand dargestellt werden: CLAIMS.md:72/88 erlaubt MIDI-Aufnahme und eigenen WAV-Ausgang, während faq.html:44/94/178 Audioaufnahme pauschal verneint und architecture.html:261/300/394 MIDI-Import als Roadmap führt?
3. Welche weiteren Stellen sollen nach Ausschöpfen der Zehnergrenze zuerst folgen: fehlende Gerätevorbehalte für BLE und OSC/ADM-Eingang (faq.html:44/106/222, architecture.html:205) sowie MIDI 2.0 (index.html:927), entgegen CLAIMS.md:69–70/75/78?
4. Welche Belege decken die verbliebenen absoluten oder quantitativen Aussagen, etwa „any visual movement … 3 Hz“ (faq.html:270), „ground truth“ (index.html:791), „any scale“ (index.html:891), die Flash-Zusicherungen (health.html:119/127; faq.html:258) und Sender-Zeitwerte (artnet-sacn-from-a-phone.html:118–120)? CLAIMS.md gibt dafür keine entsprechende Implementierungsgarantie.
5. Wie sollen die übrigen Quellen-/Website-Widersprüche bereinigt werden, insbesondere RTMP als „never built“ (architecture.html:354 gegenüber CLAIMS.md:188–189), räumliche Ausgabe versus Kopfhörerrendering (CLAIMS.md:70; FEATURE_STATUS.md:149/195) und die pauschale Ausschließlichkeit von DMX/OSC-Datenabfluss (artnet-sacn-from-a-phone.html:114 gegenüber CLAIMS.md:71/74–76)?

## 10. Vermutungen

Keine als neue Website-Behauptung übernommen. Fehlender Beleg wurde nicht mit nachgewiesener technischer Falschheit gleichgesetzt. Ob die Vorschläge live gehen, entscheidet der Founder.
