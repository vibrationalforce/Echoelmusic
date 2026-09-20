# Wert der App — selbst erhoben, und welche Stellschrauben ihn bewegen

**Datum:** 2026-09-20 · **Anlass:** Founder fragt nach FounderBlocks (Startup-Studio Hamburg,
steigt als Co-Founder mit ein) und ob wir den Wert selbst erheben können.

⚠️ **Was dieses Dokument IST und NICHT IST.** Es ist eine Verhandlungsgrundlage aus
gemessenen Repo-Größen plus klar markierten Schätzungen. Es ist **kein Bewertungsgutachten**,
keine Finanzberatung, und keine Zahl darin ist eine Tatsache über den Markt. Alles, was
gemessen ist, steht mit Befehl. Alles, was geschätzt ist, steht mit **[SCHÄTZUNG]**.

---

## 0. Die Kurzantwort

**Ja, wir können das selbst — und wir müssen es zuerst selbst tun.** Ein Studio, das als
Co-Founder einsteigt, nimmt Anteile. Der Preis dieser Anteile IST die Bewertung. Wer ohne
eigene, belegte Zahl in dieses Gespräch geht, lässt die Gegenseite die Zahl setzen, und die
Gegenseite macht das beruflich.

**Und der Hebel, den die Frage eigentlich meint, ist Timing, nicht Rechnen:** jede
Stellschraube, die VOR der Unterschrift gedreht wird, gehört zu 100 % dir. Dieselbe
Stellschraube nach der Unterschrift gehört dir nur noch anteilig. Das ist die ganze
Mechanik von „indirekt die Stellschrauben drehen" — §4 rechnet es aus.

---

## 1. Was tatsächlich da ist (gemessen)

```bash
git ls-files 'Sources/**/*.swift'     | wc -l   # 356 Dateien
git ls-files 'Tests/CISmoke/*.swift'  | wc -l   # 541 blockierende Wächter
git ls-files 'Tests/EchoelmusicTests/*.swift' | wc -l  # 302 Tests
git rev-list --count HEAD                       # 7 984 Commits
git log --reverse --format='%ad' --date=short | head -1   # 2025-10-15
```

| | Dateien | Zeilen |
|---|---:|---:|
| `Sources/` | 356 | 134 085 |
| `Tests/CISmoke/` (blockierend) | 541 | 133 208 |
| `Tests/EchoelmusicTests/` | 302 | 50 000 |
| **Summe** | **1 199** | **317 293** |

*(Die 50 000 sind exakt und zweimal unabhängig nachgemessen — `wc -l` und eine
Python-Summe. Eine so runde Zahl sieht nach Abschneidefehler aus und ist keiner.)*

**Zeitraum:** 2025-10-15 → 2026-09-20, **~11 Monate**, volle Historie im Klon (nicht shallow).

**Das Verhältnis ist die interessanteste Zahl:** **1,52 blockierende Wächter pro Quelldatei**,
und die Testzeilen sind fast so zahlreich wie die Produktionszeilen. Das ist für ein
Solo-Projekt ungewöhnlich und es ist **der Grund, warum der Bus-Faktor verhandelbar ist**
(§3.4).

---

## 2. Drei Methoden — weil für eine App ohne Umsatz keine einzelne funktioniert

### 2.1 Wiederbeschaffungswert (der einzige harte Boden)

Die Frage: *Was kostet es, ein Team einzustellen, das diesen Stand neu baut?*

Nicht „Zeilen mal Preis" — das ist Unsinn. Die Frage ist, **welche Spezialisierungen** man
braucht. Gemessen an dem, was im Repo steckt:

| Kompetenz | Beleg im Repo |
|---|---|
| Swift 6 strict concurrency, `@Observable`, iOS 18 | ganzes `Sources/`, `.claude/rules/swift-audio.md` |
| Echtzeit-DSP ohne Allokation auf dem Audio-Thread | `DSP/` (40 Dateien, nur Foundation+Accelerate) |
| Bio-Signalverarbeitung, peer-reviewed | die geschützte Rausch-Triade |
| Netzwerkprotokolle: OSC · ADM-OSC · Art-Net · sACN · MIDI 1/2 | `Sync/` + `Audio/`, 14 Dateien |
| AUv3-Plugin-Architektur | `Sources/EchoelmusicAUv3/`, gerätebestätigt in AUM |
| Musiktheorie: 41 kuratierte Genres | `Sequencer/MusicStyle.swift` |

**[SCHÄTZUNG]** Das sind nicht ein Entwickler, sondern **2–3 Spezialisten** (iOS/SwiftUI ·
Audio-DSP · Musik/Sound-Design), realistisch **18–36 Personenmonate** bis zu diesem Stand
inklusive der Testabdeckung. Bei Hamburger Vollkosten von ~8 000–12 000 €/Personenmonat:

> **Wiederbeschaffung: rund 150 000 € bis 430 000 €.** [SCHÄTZUNG — meine, nicht der Markt.]

Das ist der **Boden**, kein Preis. Niemand zahlt Wiederbeschaffungswert für etwas ohne
Nutzer. Aber es ist die Zahl, die verhindert, dass jemand „das ist ja nur eine App" sagt.

### 2.2 IP und Verteidigbarkeit (was man nicht einkaufen kann)

| Asset | Warum es in einer Due Diligence zählt |
|---|---|
| **Null externe Abhängigkeiten** (`Package.swift` → `dependencies: []`) | saubere IP-Kette, keine Lizenz-Altlasten, kein Lieferant kann abkündigen. Das ist in einer DD **ein Prüfpunkt, der einfach entfällt** — selten. |
| **Offene Standards statt SDK-Bindung** | ADM-OSC, Art-Net, sACN, OSC, MIDI. Echoel kann in jedes Rig, ohne Partnerschaft. |
| **41 kuratierte Genres** | Musiktheorie-Arbeit, keine Code-Arbeit. Nicht durch Einstellen zu beschleunigen. |
| **`TuningSystem` + Kammerton im Projekt** | ein Performer-eigenes Tonsystem, das mit dem Projekt reist. Kein Wettbewerber hat das. |
| **`ContentPipeline/CLAIMS.md`** | 13 Abschnitte „was wir ausdrücklich NICHT behaupten, und warum". **Das ist selbst ein DD-Asset** (§3.5). |
| **541 blockierende Wächter** | die Bus-Faktor-Antwort (§3.4). |

### 2.3 Markt und Traktion — ehrlich: nahe null

```bash
sed -n '161,163p' ContentPipeline/CLAIMS.md
#   ### 4. „Im App Store" / Store-Link
#   Es gibt heute **nur TestFlight.** Erst nach der ersten Freigabe umstellen.
```

**Kein Store-Listing. Kein Umsatz. Keine Nutzer außerhalb TestFlight.** Preismodell steht als
Founder-Entscheidung vom 2026-07-10 fest (v1.0 kostenlos · v1.1 „Echoel Live" Jahresabo ·
v1.2 Per-Event-Host-Gebühr), ist aber **nicht gebaut** — `EchoelStore`/`ProGate` kompilieren
und sind unerreichbar.

**Konsequenz für die Bewertung:** eine reine Traktions-Bewertung ergäbe **~0 €**. Deshalb
ist Methode 2.3 heute die schwächste — **und deshalb ist sie die größte Stellschraube**.

---

## 3. DIE STELLSCHRAUBEN — nach Wirkung pro Aufwand

### L1 — **Im App Store sein.** Binär, größter Multiplikator, billigster Aufwand
Der Unterschied zwischen „Projekt" und „Produkt" ist ein Store-Eintrag, und er ist
**bereits bezahlt**: Pipeline grün, Build 2595 in App Store Connect, v10.79.475.
Was fehlt, ist die Einreichung — eine Founder-Handlung, keine Entwicklungsarbeit.
**Solange kein Store-Eintrag existiert, ist jede Bewertungsdiskussion eine über Hoffnungen.**

### L2 — **Ein zahlender B2B-Kunde, nicht tausend B2C-Nutzer**
Deine eigene v1.2-Entscheidung (Per-Event-Host-Gebühr) ist der B2B-Hebel, und **du hast das
Netzwerk dafür schon** (`memory/people.md`): Bolle (Veranstaltungsorte, Messe, Panasonic-Gerät
im Wert von ~30 000 € zugänglich) und Roman/Adamson (FletcherMachine spricht ADM-OSC — genau
das, was Echoel sendet).
**Eine bezahlte Installation ist mehr wert als 10 000 Gratis-Downloads** — sie beweist
Zahlungsbereitschaft, sie ist eine Referenz, und sie ist genau die Währung, in der ein
Accelerator rechnet.

### L3 — **AUv3 als ZWEITER Markt mit bewiesener Zahlungsbereitschaft**
Plugin-Käufer zahlen 20–60 € für ein Instrument. Das ist ein anderer Markt als eine
Gratis-iOS-App, mit anderem Preispunkt und anderer Erwartung. Echoel lädt bereits in AUM
(gerätegemessen 2026-09-20). **Offen sind zwei Messungen**, nicht zwei Features: GarageBand
bei 44,1 kHz und Logic.

### L4 — **Bus-Faktor: die Antwort existiert und steht nirgends nach außen**
Die erste Frage jedes Investors bei einem Solo-Projekt ist *„was passiert, wenn du ausfällst?"*
Deine Antwort ist gemessen und ungewöhnlich stark: **541 blockierende Wächter, 1,52 pro
Quelldatei, plus ein Gesetzesdokument, aus dem eine fremde Sitzung in Minuten arbeitsfähig
wird.** Das ist keine Arbeit mehr — es ist **ein Dokument, das aus vorhandenen Zahlen besteht**.

### L5 — **Die Nicht-Behauptungen veröffentlichen** (offener Posten #28)
`docs/claims.html` — die ⛔-Hälfte von `CLAIMS.md` öffentlich. Ein Gründer, der ungefragt
sagt *„hier ist, was wir ausdrücklich NICHT behaupten, und warum"*, nimmt einem Prüfer die
Hälfte seiner Arbeit ab. Das ist in einem Bio-/Health-nahen Feld **der Unterschied zwischen
„interessant" und „prüfbar"**.

### L6 — **Signature und Universal Modulation** (B1/B2 aus dem Deep Audit)
Erzählbar in einem Satz: *„der Körper moduliert jeden Parameter, und was der Körper getan hat,
bleibt beim Stück."* Heute ist das auf **ein** Ziel begrenzt (`ModDestinationKey.all == [tempo]`).
Das ist die Produktgeschichte, die den Preis rechtfertigt — sie ist eine Scheibe entfernt.

---

## 4. WARUM TIMING DIE EIGENTLICHE STELLSCHRAUBE IST

Die Mechanik, um die es in „indirekt die Stellschrauben drehen" geht:

> **Jede Stellschraube VOR der Unterschrift gehört dir zu 100 %. Dieselbe Stellschraube
> danach gehört dir anteilig.**

Ein Rechenbeispiel, **rein illustrativ** [SCHÄTZUNG, keine Marktaussage] — Anteil 20 %:

| Zeitpunkt | Bewertung vor Abgabe | 20 % kosten dich | Dein Rest |
|---|---:|---:|---:|
| heute (kein Store, kein Umsatz) | niedrig | wenig absolut | **80 % von wenig** |
| nach L1 + L2 (Store live, eine bezahlte Installation) | deutlich höher | mehr absolut | **80 % von deutlich mehr** |

Die Anteilsquote ist dieselbe. Was sich ändert, ist die Basis — und die änderst **du** mit
L1, L2, L4, L5, von denen **drei keine Entwicklungsarbeit sind**, sondern Einreichen,
Telefonieren und Aufschreiben.

**Daraus folgt kein „nicht verhandeln".** Es folgt: **erst L1 und L4/L5, dann das Gespräch.**
L1 ist eine Einreichung. L4 und L5 sind Dokumente aus vorhandenen Zahlen. Das ist Wochen,
nicht Monate.

---

## 5. ⚠️ DIE WARNUNG, DIE ICH DIR SCHULDE

FounderBlocks' beworbenes Verfahren ist *„zahlende Kunden in 8–12 Wochen, BEVOR die
Entwicklung beginnt"*, Schwerpunkt B2B/SaaS.

**Zwei Reibungen, beide echt:**

1. **Das Verfahren passt nicht auf den Stand.** Es ist für die Ideenphase gebaut. Bei dir sind
   356 Quelldateien und elf Monate schon gebaut. Der Teil ihres Angebots, der bei dir greift,
   ist **Vertrieb und Investorenzugang** — nicht Mitbauen. Dafür einen Co-Founder-Anteil zu
   zahlen, ist eine andere Rechnung als „wir bauen mit dir von null".
   **Frag konkret: welcher Anteil, für welche Leistung, mit welchem Vesting, und was passiert
   bei Ausstieg nach sechs Monaten?**

2. **Druck auf schnellen Umsatz in einem Bio-Feld erzeugt Wellness-Claims.** Das ist der
   kürzeste Weg zu Umsatz und die permanente rote Linie dieses Projekts. `CLAIMS.md` §2
   verbietet Wellness, Meditation, Schlaf, Fokus, Stressabbau, „Longevity", „HealthTech"
   wörtlich — nicht aus Geschmack, sondern weil Heilungs-Claims Alt-Last aus dem
   Vorgängerprojekt sind und im App Store eine 2.3-Ablehnung.
   **Wenn ein Partner an Bord kommt, gehört `CLAIMS.md` in den Datenraum als BEDINGUNG,
   nicht als Fußnote.**

**Das ist kein Argument gegen FounderBlocks.** Es ist das, was du vor dem ersten Termin
wissen musst, damit das Gespräch auf deinen Zahlen läuft und nicht auf ihren.

---

## 6. Was ich als Nächstes bauen kann, ohne Rückfrage

- **L4 als Dokument:** ein zweiseitiges „Continuity & Quality"-Papier, komplett aus
  gemessenen Repo-Zahlen (Wächterdichte, Null-Deps, Gesetzesdokument, Gate-Struktur).
- **L5 = Posten #28:** `docs/claims.html` mit Generator und Wächter, damit die Seite nicht
  von `CLAIMS.md` abdriften kann.
- **L6 = B1** aus dem Deep Audit (`ModDestinationKey.all` als Projektion der Registry).

**L1 (Store-Einreichung) und L2 (erster bezahlter Event) sind deine.** Ich kann beide
vorbereiten, einreichen und telefonieren kann ich nicht.
