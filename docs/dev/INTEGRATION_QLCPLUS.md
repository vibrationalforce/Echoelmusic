# Integrations-Rezept: Echoel → QLC+ über sACN

**Wofür:** die EINE benannte Integration für den Prototype-Fund-Antrag (TODO_FOUNDER S-Rezept,
Prüfziel „das freie Lichtpult QLC+" in `FOERDERUNG_PROTOTYPE_FUND_2026.md`). **Wer:** Echoel spielt
es am **7.11.** durch und macht den datierten Screenshot. **Stand:** geschrieben 2026-10-23 aus dem
Code der früheren App und der QLC+-Dokumentation. **Nicht durchgespielt** — weder die App-Seite auf
dem Gerät noch die QLC+-Seite. Was beim Durchspielen anders aussieht, wird hier korrigiert, bevor
es in den Antrag geht.

⚠️ **Es ist die FRÜHERE App** (Echoelmusic, TestFlight-Reihe 10.79.x). Echoel Studio sendet heute
weder OSC noch sACN noch Art-Net (`ContentPipeline/CLAIMS.md`, Studio-Abschnitt). Im Antrag heißt
das: „mit der früheren App gezeigt; Echoel Studio bekommt den Ausgang im Projekt (EchoelIO)".

## Was über die Leitung geht (gemessen im Code)

| | Wert | Quelle |
|---|---|---|
| Protokoll | sACN (ANSI E1.31), **Unicast** an die eingetragene IP | `Sync/SACNSender.swift` |
| Port | **5568** | `SACNSender.defaultPort` |
| Universe | **1** (einstellbar 1–63 999) | `SACNSender.defaultUniverse` |
| Quellname | `Echoelmusic`, im Demo-Modus `Echoelmusic (DEMO)` | `SACNSender.sourceName(synthetic:)` |
| Auflösung | **16-bit** (Werkseinstellung) oder 8-bit | `SACNSender.resolution`, Routing → Light → DMX |
| Slots | immer 512, alles außer den Lampen-Kanälen 0 | E1.31; Fußnote im Light-Abschnitt der App |

**Kanäle, wenn der Körper das Licht steuert** (Transport gestoppt, keine Musik klingt —
`ArtNetSender.dmxChannels(for:)`, von sACN geteilt):

| 8-bit | 16-bit (grob, fein) | Bedeutung | Bereich |
|---|---|---|---|
| 1 | 1, 2 | Dimmer = 0,3 + 0,7 × Kohärenz | nie unter 30 %, solange Körperdaten kommen |
| 2 | 3, 4 | Rot = Herzfrequenz | 40 bpm → 0, 200 bpm → voll |
| 3 | 5, 6 | Grün = HRV (normiert 0–1) | |
| 4 | 7, 8 | Blau = Atemphase (0–1) | läuft mit jedem Atemzug einmal durch |

**Wenn Musik klingt, färbt der Akkord das Licht** (`MusicMediaMap.dmxChannels(forMusic:)`): dieselben
vier Kanäle, Dimmer aus dem Pegel, RGB aus den Tonhöhen. Für den Screenshot also den Transport
**gestoppt** lassen, sonst zeigt er Musik statt Körper.

Master und Blackout (Routing → Light) wirken auf alles; „Fixtures" wiederholt dieselbe Farbe ab
Adresse 1 über mehrere Lampen.

## Welche Pulsquelle

`BioEgressPolicy.allowsEgress`: **Kamera (Finger auf der Linse), Brustgurt (BLE) und Demo** dürfen
das Gerät verlassen; **Apple Health und Watch nicht** (App-Store-Regel 5.1.3) — mit ihnen bleibt
das Licht stehen. Für den Antrags-Screenshot die **Kamera** nehmen: dann steht in QLC+ kein „DEMO"
im Spiel und der Wert ist echt. Gesendet werden nur abgeleitete Steuerwerte (vier Bytes bzw. acht),
keine Rohwelle und keine HRV-Millisekunden.

## Vorbereitung

- Laptop und iPhone im **selben WLAN**. Die IP des Laptops notieren (macOS: Systemeinstellungen →
  WLAN → Details; Windows: `ipconfig`; Linux: `ip addr`).
- Firewall des Laptops: **eingehend UDP 5568** für QLC+ erlauben (macOS fragt beim ersten Start).
- QLC+ 4 installiert (qlcplus.org; Apache-2.0).
- Auf dem iPhone: beim ersten Senden fragt iOS nach „Lokales Netzwerk" — **Erlauben**. Wurde es
  einmal abgelehnt: Einstellungen → Datenschutz → Lokales Netzwerk → Echoelmusic an.

## A. Echoel (frühere App) — sendet

1. Puls starten: Puls-Pille im Kopf → Quelle **Camera light**, Finger auf die rückseitige Linse,
   warten bis die Zahl steht.
2. **Licht-Kachel im Kopf** antippen → die Seite **Routing** öffnet auf **Light**.
3. Light: **DMX → 8-bit** wählen (für den Screenshot: ein Wert pro Kanal, leichter zu lesen).
   Master auf voll, Blackout aus.
4. Oben auf **Connections** wechseln.
5. In der Karte **Body (bio)** die Zeile **sACN (light)** antippen → Häkchen. Erst diese Route
   startet den Sender (`EchoelmusicApp`: `hasEnabledRoute(toSink: "sacn.out")`).
6. Unter **Network output**, Zeile **sACN · Light**: IP/host = **IP des Laptops**, Port **5568**,
   Universe **1**. Die Kopfzeile der Zeile sagt **sending**, sobald wirklich Pakete rausgehen
   (**open, nothing sent** heißt: Sender an, aber nichts zu senden; **off** heißt: keine Route).
7. Transport **gestoppt** lassen.

## B. QLC+ — empfängt

Laut QLC+-Dokumentation (E1.31-Plugin, Input/Output-Mapping, DMX Monitor):

1. Reiter **Inputs/Outputs** (unten im Hauptfenster). Links **Universe 1** wählen.
2. Rechts in der Zeile **E1.31** mit der **IP des Laptops** das Kästchen **Input** setzen.
3. Den **Konfigurations-Knopf** (Schraubenschlüssel) öffnen. In der Zeile für Universe 1, Input:
   - **Multicast aus** (Echoel sendet Unicast; mit Multicast hört QLC+ auf 239.255.0.x und sieht
     nichts),
   - IP = die des Laptops (bei Unicast fest), **Port 5568**,
   - **E1.31 Universe 1** (dasselbe wie in Echoel).
4. Bei Universe 1 **Passthrough** einschalten: der DMX Monitor zeigt AUSGANGS-Universen, und
   Passthrough reicht den Eingang dorthin weiter.
5. Reiter **Fixtures** → Fixture hinzufügen → **Generic → Generic Dimmer**, Adresse **1**,
   **4 Kanäle** (bei 16-bit: 8). Ein Dimmer je Kanal genügt — es geht ums Sichtbarmachen der Werte.
6. **DMX Monitor** öffnen, Universe 1, **DMX Values**. Kanal 1–4 bewegen sich: Kanal 4 (Atem) läuft
   langsam auf und ab, Kanal 2 folgt der Herzfrequenz.

## Was der Screenshot zeigen muss

- QLC+ **DMX Monitor** mit Kanal 1–4 und sichtbaren, von 0 verschiedenen Werten,
- daneben oder im zweiten Bild **Inputs/Outputs** mit E1.31 als Input auf Universe 1,
- die **Uhr mit Datum** des Laptops im Bild (Menüleiste/Taskleiste),
- das iPhone mit der Routing-Seite (sACN · Light zeigt **sending**), wenn möglich im selben Foto.
- **Nicht** im Bild: Health-App, Nachrichten, andere Namen. Eine private 192.168.x.x-IP ist
  unkritisch.

Ablage: Screenshot mit Datum im Dateinamen; im Antrag ein Satz „Echoel → QLC+ über sACN, getestet
am 7.11.2026" plus das Bild. Vorher prüfen: kein Gesundheits- oder Therapie-Wort im Bildtext.

## Wenn nichts ankommt

| Symptom | Ursache, in dieser Reihenfolge prüfen |
|---|---|
| sACN · Light zeigt nicht **sending** | Route Body (bio) → sACN (light) fehlt · Puls noch nicht gemessen |
| Echoel sendet, QLC+ zeigt nichts | Multicast in QLC+ noch an · falsche IP in Echoel · Firewall blockt UDP 5568 · „Lokales Netzwerk" auf dem iPhone abgelehnt · Universe ungleich |
| Werte kommen, Monitor bleibt leer | Passthrough aus · kein Fixture auf Adresse 1 · Monitor zeigt anderes Universe |
| Werte kommen, bewegen sich aber nicht | Quelle ist Apple Health/Watch: deren Werte verlassen das Gerät nicht, das Licht hält den letzten Stand — auf Camera light wechseln |
| Werte springen mit der Musik | Transport läuft — stoppen, dann folgt das Licht dem Körper |
| Kanal 1 nie unter 76 | richtig: Dimmer-Boden 30 % (0,3 × 255, abgeschnitten) |

## Offen, nicht gemessen

- Ob QLC+ den E1.31-Quellnamen irgendwo anzeigt (für „DEMO" vs. echt): unbekannt; nicht nötig.
- Ob Unicast an eine Laptop-IP im Heim-WLAN ankommt (manche Router isolieren Clients):
  Gerät/Netz-Frage, am 7.11.
