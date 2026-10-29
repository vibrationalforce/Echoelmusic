# Strategie-Panel: sieben Varianten, sechs Linsen, drei Skeptiker (28.10.2026)

> Synthese des Workflows `wf_71c82e09-e37` (Produktions-Session `01DqTpc8`, 28.10. 22:35Z). Die drei Founder-Fragen daraus stehen EINMAL als **GM37** in `docs/dev/FOUNDER_INBOX.md`; die Entscheidung ist offen. Rohdaten (16 Agenten-Antworten) liegen nicht im Repo.

Founder-Frage: „Emuliere alle Varianten — Tauchfliege, SyngVisibra, Blab, GSIMMW/DMMW, Wasser-Licht-Klang-Installation vs. echtes Somachord — alles in einem zugänglichen heilsamen Format; öffne alle Regeln von Förderstrategie über Business bis Friedensnobelpreis.“

Verfahren: 7 Leser (nur Repo + generische Websuche, je Aussage Datei:Zeile), 6 Richter mit je einer festen Linse (Score 0–10, je Variante eine nachgeschlagene Zahl), 3 Skeptiker gegen den Spitzenreiter. 16 Agenten, 584 Werkzeugaufrufe. Rohdaten: Workflow wf_71c82e09-e37.

## 1. Rangliste (Mittel über sechs Linsen)

| Platz | Variante | Mittel | Cashflow | Förderung | Recht | Zugang | Frieden/Ansehen | Reife |
|---|---|---|---|---|---|---|---|---|
| 1 | **Echoel Studio** (DMMW → GSIDMMW) | **6,2** | 6 | 6 | 7 | 4 | 6 | 8 |
| 2 | **Vaporwave Palace** (bestehende Wasser-Licht-Klang-Installation) | **5,3** | 5 | 5 | 5 | 7 | 5 | 5 |
| 3 | Kombination laut memory/vision.md 28.10. (Studio + Palace + Tauchfliege) | 4,2 | 4 | 3 | 4 | 6 | 4 | 4 |
| 4 | Somachord / CE-Vibroakustik-Liege kaufen | 2,5 | 1 | 1 | 3 | 5 | 2 | 3 |
| 5 | Syng.Visibra (Altantrag, Rechtsform-Vehikel) | 1,8 | 1,5 | 1 | 1 | 2 | 3 | 2 |
| 6 | Tauchfliege | 1,0 | 0 | 2 | 2 | 0 | 1 | 1 |
| 7 | BLAB (Wellness-/Heilfrequenz-Ära) | 0,25 | 0,5 | 0 | 0 | 1 | 0 | 0 |

## 2. Das Ergebnis, auf das alle sechs Richter unabhängig kamen

**Die beste Form ist keine der sieben, sondern das Paar Studio + Palace — ohne Tauchfliege, ohne das Wort „heilsam“.**
- Studio liefert die prüfbare Transparenz (MIT, null Abhängigkeiten, kein Konto/Tracking/Server, offenes Songformat, Wächter gegen Heilbehauptungen) und den skalierbaren Euro (Einmalkauf, Grenzkosten null).
- Palace liefert das, was dem Studio fehlt: einen Körper. Es ist die einzige Hardware, die existiert und öffentlich gezeigt wurde (Festival 2024, Video 11.9.). Liegen, fühlen, sehen — erreicht gehörlose und schwerhörige Menschen und Menschen ohne Gerät und ohne Technikkenntnis.
- Jede Beimischung (Tauchfliege, Somachord-Kauf, Visibra, BLAB) senkt den Score des Paares.

Vier Bedingungen, damit das Paar besser wird als das Studio allein (heute 6, dann 7–8):
1. **W4 gebaut**: Art-Net/sACN/OSC-Ausgang im Studio. Gemessen heute 0 Dateien in `EchoelStudio/` — der Bus lebt nur in der eingefrorenen Alt-App (`Sources/Echoelmusic/Sync/`). W4 hängt an einer founder-gated Workflow-Zeile (F25).
2. **Ein Gerätebeleg**: eine datierte Sitzung, in der die Installation vier Stunden aus Echoel läuft.
3. **Elektro-Abnahme (Schutzkleinspannung am Wasser) bevor Fremde darauf liegen** — solange nur der Founder liegt, löst das keine Pflicht aus.
4. **Dokumentierte Ko-Gestaltung** mit der Zielgruppe (n, Datum, Ergebnis), z. B. mit der Deaf Community — das ist die Form, in der Preisjurys Teilhabe anerkennen.

## 3. Die drei Skeptiker — alle drei kippen die Begründung, keiner den Rangplatz

**Recht & Haftung.** `docs/terms.html:151-160` schließt „Personal injury or health effects … biofeedback, visual, or audio features“ aus und deckelt die Haftung auf 50 € — nach § 309 Nr. 7 BGB und § 14 ProdHaftG nichtig, nach UKlaG/UWG abmahnfähig, sobald verkauft wird. Dazu widerspricht `docs/privacy.html:110` („keine Herzfrequenz-Sensoren im Studio“) dem Build (Bluetooth-Gurt seit 10012, `project.yml:77`). **Vor dem ersten Verkauf: Terms und Privacy für das Studio neu schreiben.**

**Markt & Geld.** Das einzige verkaufte Objekt (`com.echoelmusic.app.pro`) schaltet drei Instrumente frei, und zwar nur in fremden Hosts; die Workstation selbst wird verschenkt. Im verkauften Plugin gibt es **null Körperkanal** (Grep heart|hrv|coherence in `EchoelStudio/Plugins` → 0). Der Käufer besitzt schon AUM/Logic und damit tausende Synths; der Unterscheider „Körper“ fehlt genau dort, wo bezahlt wird. Die Preisanker (AUM, Drambo = Hosts) vergleichen die falsche Kategorie. **Das Grand Council vom 10.9. hatte das selbst festgehalten:** ein AUv3-Instrument fällt nur durch den Körper auf. Abhilfe: Körperkanal über die App Group in die Extension.

**Founder-Kapazität.** Die Reife-8 misst die Kapazität der KI, nicht die des Founders. Gemessen: 411 offene Geräte-Bitten, 0 beantwortet (`scripts/founder-verify.py`); elf Uploads seit 18.10., keiner gerätegeprüft; drei vorbereitete Gerätesitzungen mit 0 abgehakten Kästchen; F-15 (den Einmalkauf in App Store Connect anlegen, ~30 min) seit 27.10. offen. Der Engpass ist nicht die Entwicklung, sondern die Founder-Minuten am Gerät. 1.0 mit W1–W10 braucht ≥ 96 Geräte-Antworten = ≥ 19 Wochen bei einer Sitzung pro Woche; gemessene Rate: null.

## 4. Was mit „heilsam“, Quantum Healing und BLAB ist

- Das Wort **„heilsam“** hat beim OLG Hamm (I-4 U 124/12, Salzgrotte) gereicht, um den Anwendungsbereich des Heilmittelwerbegesetzes und die Belegpflicht zu öffnen. Keine Variante darf es tragen; der ehrliche Ersatz ist **„erfahrbar“ / „zugänglich“ / „fühlbar“**.
- **BLAB** = 0,25: Organ-/Gewebeheilung, 528 Hz, Entrainment — jeder Vermarktungssatz ist § 3 HWG (bis 20.000 € nach § 15), App-Store-Richtlinie 1.4.1, und das Repo führt die Module als gelöschten Overclaim. Das Einzige, was aus dieser Ära wert ist: die HRV-Resonanzatmung als Selbstbeobachtung — die lebt im Studio weiter.
- **Frieden/Nobel**: Friedensnobelpreis 2025 hatte 338 Kandidaten, Listen 50 Jahre geheim, Preisträger weisen jahrzehntelange, von Dritten dokumentierte Arbeit vor; der EU-STARTS-Prize (1.657 Einreichungen) prämiert prüfbare Werke. Kein Preis prämiert Absichten oder Werte-Papiere. **Die No-Claim-Regel des Repos ist das Ansehens-Kapital, nicht das Hindernis.** Frieden als Praxis (offene Standards, Inklusion, Transparenz, Fußabdruck gemessen statt behauptet) zählt; als Wirkungsversprechen kostet es.

## 5. Zwei Widersprüche im Repo, die nur der Founder auflösen kann

1. **Förderung.** Am 24.10. hat der Founder jede Förderung gestrichen (`decisions.csv:1329` „Förderungen nerven und verpflichten“, aktiv, Review 24.11.; `FOERDERUNG_PROTOTYPE_FUND_2026.md:3` „keine Bewerbung“). Meine Aussage vom Abend („Prototype Fund ist die größte Chance“) stand gegen diese Entscheidung — zurückgenommen. Falls er sie vor dem 24.11. umdreht: zwei getrennte Anträge (Studio-Pakete beim Prototype Fund, Palace bei Hamburg BKM „Inklusive Projekte“ / Fonds Soziokultur), nie ein Bündel; Risiko beim PTF: 89 % der Commits auf main tragen den KI-Autor, und der Fonds nennt „Vibe-Coding“ als Ablehnungsgrund.
2. **Tauchfliege.** Am 22.10. gestrichen („wird NICHT weiterverfolgt“, `memory/user.md:39-42`, `decisions.csv:1323`), am 28.10. in `memory/vision.md:13` als „Mittel-Hardware“ wieder eingetragen — ohne Zeile in `decisions.csv`. Im Repo: 0 Code, 0 CAD, 0 Maße; vergleichbare Vorhaben sind Teamprojekte im sechs- bis siebenstelligen Bereich. Eine Zeile vom Founder: geparkt (WATCH) oder Roadmap.

## 6. Empfehlung in einem Satz

**Echoel Studio als Kern, die bestehende Wasser-Licht-Klang-Installation als Liege-Abonnent — benannt als „Musik, die man liegend fühlt“, nie als „heilsam“; alles andere parken.**

Reihenfolge der nächsten Schritte (die ersten drei kann nur der Founder):
1. Eine Gerätesitzung, 30 Minuten: F-15 (Einmalkauf in App Store Connect anlegen) + die fünf Punkte aus `EchoelStudio/RELEASE` mit Ja/Nein.
2. Eine `decisions.csv`-Zeile zur Tauchfliege (parken oder Roadmap) und eine zur Förderung (bleibt gestrichen oder zwei getrennte Anträge).
3. Freigabe der F25-Zeile für W4 (Workflow ist founder-gated).
4. Terms und Privacy für das Studio neu schreiben (Haftungsklausel, Gurt) — kann die KI vorbereiten, der Founder gibt frei.
5. W4 bauen (OSC/Art-Net/sACN im Studio), dann eine dokumentierte Palace-Sitzung aus Echoel.
6. Körperkanal in die AUv3-Extension (App Group), damit das verkaufte Objekt den Unterscheider trägt.
7. Vor der ersten fremden Person auf der Liege: Elektro-Abnahme; dann eine Ko-Gestaltungs-Sitzung mit der Zielgruppe, dokumentiert.
