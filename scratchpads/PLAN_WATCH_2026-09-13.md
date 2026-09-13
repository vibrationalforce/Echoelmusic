# PLAN — Apple Watch (Founder: „Nächster big step TestFlight für Watch", 2026-09-12)

Stand 2026-09-13. **Kein Code in dieser Scheibe.** Plan + Council, wie es die Regel für ein
NEUES Framework verlangt. Jede Zahl hat ihren Befehl daneben; wer sie nachführt, misst neu.

---

## 0. Die eine Erkenntnis, die den Auftrag umdreht

**Das Handgelenk erreicht heute schon klingenden Ton — ohne Watch-App.** Nicht „theoretisch
verdrahtet": die Kette ist vollständig und ungefiltert.

```
Apple Watch → HealthKit (iPhone) → EchoelBioEngine (HKAnchoredObjectQuery, updateHandler)
  → HealthKitBioPublisher.publishIfFresh  → EngineBus.publish(bio:) → latestBio
  → PolySynthVoice (10-Hz-Poll, kein Quellenfilter)  → KLANG
  → EchoelStudioView.bodyTempoTrustworthy → BioComposer.tempo(for:) → TEMPO (nur Flow)
```

Belege, je mit Befehl:

| Behauptung | Wo | Befehl |
|---|---|---|
| Publisher konstruiert + gestartet, app-weit, nicht in der Puls-Pille | `EchoelmusicApp.swift:1367`, `:1394` | `git grep -n "healthBio.start\|startIfAlreadyAuthorized" -- Sources` |
| Rahmen trägt `source: .healthKit` | `HealthKitBioPublisher.swift:158` | `git grep -n "source: .healthKit" -- Sources` |
| Verbraucher filtert NICHT nach Quelle | `PolySynthVoice.swift:938/:957` | `git grep -n "bus.latestBio" -- Sources` |
| Tempo lässt HealthKit im ERSTEN Rahmen durch | `EchoelStudioView.swift:10873-10881` | dort steht nur `if frame.source == .cameraPPG { return cameraRPPG.isSettled }`, danach `return true` |

⚠️ **Die Gegenprobe, damit das nicht überbehauptet wird:** `bioVoice` ist NICHT der hörbare
Pfad — sein Render-Block hält bei `guard hasEverSounded` (`BioReactiveSynthVoice.swift:979`),
und `hasEverSounded` kippt nur über `arm()`, dessen einzige Tür der Schalter „Body voice" ist.
Hörbar ist `polyVoice`. Und `.watch` als Quellen-Case hat **null Produzenten** — jeder
Handgelenk-Wert kommt als `.healthKit` an (`git grep -n "source: .watch" -- Sources` → 0).

---

## 1. Warum es sich trotzdem nicht anfühlt wie eine Bio-Quelle: die KADENZ

`EchoelBioEngine.swift:389` schreibt `snapshot.timestamp = sampleDate` aus
`latestSample.startDate`. `HealthKitBioPublisher` pollt alle 500 ms
(`HealthKitBioPublisher.swift:77`) und veröffentlicht nur bei GEÄNDERTEM Zeitstempel (`:132`).
**Die effektive Rate ist also die Schreibkadenz der Uhr — im Ruhezustand Minuten**, und der
Dateikopf nennt 180 s als den gepinnten Auslegungsfall (`:43`). Dazu ein zweites Tor:
`maxMeasurementAge = 600` (`:51`, geprüft bei `:131` VOR der Deduplizierung) verwirft jede
Messung, die älter als zehn Minuten ist.

⛔ **Die Zahl „4–5 s" in CLAUDE.md ist die LATENZ, nicht die KADENZ.** Beide stehen dort
nebeneinander und beschreiben verschiedene Größen — genau die Verwechslung, die der
`beatTimes`-Absatz derselben Datei schon einmal gekostet hat (Schreibrate gegen Leserate).
Für die Planung zählt: **Latenz ~4–5 s (Beat-Sync bleibt verboten), Kadenz im Ruhezustand
Minuten (Modulation ist heute grobkörnig).**

---

## 2. Was eine Watch-App WIRKLICH kaufen würde — und was nicht

⭐ **Der Preis ist `HKWorkoutSession`, nicht „eine App am Handgelenk".** Eine laufende
Workout-Sitzung auf der Uhr hebt die HR-Schreibkadenz von „Minuten im Ruhezustand" auf wenige
Sekunden. Der DATENPFAD dafür ist der, der schon steht — HealthKit — es braucht **keinen
Transport**. Gemessen: `git grep -rn "HKWorkoutSession\|workoutSession" -- Sources` → **0**.
Das ist die ganze Lücke für Richtung Handgelenk → Telefon.

⛔ **Und damit ist die Watch-Zeile in CLAUDE.md halb falsch, weil sie ZWEI RICHTUNGEN in eine
Frage faltet.** Sie sagt, was fehle, sei „ein TRANSPORT", und belegt das damit, dass ein
App-Group-Container pro Gerät gilt. Das stimmt — **für die Richtung Telefon → Uhr** (die
Anzeige, die `EchoelWatchApp.refreshFromSharedStore()` rendern will). Für die Richtung
**Uhr → Telefon**, also die Bio-Quelle, gibt es gar kein Transportproblem: HealthKit IST der
Transport, er ist verdrahtet, und er klingt heute schon.

| Richtung | Was sie trägt | Status |
|---|---|---|
| Uhr → Telefon | HR, HRV → Klang + Tempo | **lebt** über HealthKit. Offen ist nur die KADENZ (`HKWorkoutSession`) |
| Telefon → Uhr | Sitzungszustand, Anzeige, Fernbedienung | **kein Kanal.** `WCSession` = 0 Treffer. Das ist die Stelle, an der ein neues Framework nötig wäre |

---

## 3. Der Council

**Architekt** — Die billigste richtige Reihenfolge ist, die Uhr NICHT als App zu denken,
sondern als Kadenz-Problem einer bereits verdrahteten Quelle. *Schärfste Sorge:* ein
eingebettetes Watch-Target ändert die Signatur des iOS-Archivs; `project.yml` ist
founder-gated, also ist selbst der erste Schritt nichts, was eine Web-Sitzung tun darf.

**DSP-Purist** — Nichts hiervon berührt den Audio-Thread; der Rahmen kommt über denselben
Bus wie heute. *Sorge:* eine plötzlich zehnfach höhere Kadenz trifft auf Verbraucher, die
auf `frame.timestamp` deduplizieren und mit ~1 Hz ausgelegt sind — das ist eine
Belastungsänderung, keine Featureänderung, und sie gehört gemessen, bevor sie stattfindet.

**Vision-Keeper** — „Das gesamte Apple-Ökosystem" ist erklärtes Ziel, die Uhr ist der
nächste Ring. Aber die Uhr als **Sensor** dient der Vision, die Uhr als **zweite
Oberfläche** verdünnt sie. *Sorge:* eine Watch-App mit Knöpfen ist der Anfang einer zweiten
UI, die niemand pflegen kann.

**Shipper** — „TestFlight für Watch" ist heute NICHT eine Einstellung: das Target ist
absichtlich nicht eingebettet (`project.yml:224`, auskommentiert), die HealthKit-Berechtigung
der Uhr ist als Kommentar in `EchoelmusicWatch.entitlements` geparkt, und die
Bereitstellung für `com.echoelmusic.app.watchkitapp` ist unbestätigt. *Sorge:* ein
eingebettetes, falsch signiertes Watch-Target bricht den iPhone-Upload — der Pfad, der
heute grün ist.

**Skeptiker** — Die gefährlichste Version dieses Schritts ist die, die AUSSIEHT wie Erfolg:
`EchoelWatchApp` installiert sich, startet, rendert „Start a session on iPhone." und zeigt
nie einen Puls, weil `refreshFromSharedStore()` auf einem leeren Container nil liefert.
**Verdrahtet-aber-tot ist optisch identisch mit unverdrahtet.** *Forderung:* kein Watch-Build
ohne eine Zeile auf dem Schirm, die sagt, WOHER die angezeigte Zahl kommt — oder dass keine da ist.

**Nutzer-Anwalt** — Für den Spieler ist die Uhr interessant, weil sie die Kamera-Hand
freigibt. Das ist ein echter Gewinn: heute muss ein Finger auf der Linse liegen.
*Sorge:* Health ist im Quellen-Menü gar nicht wählbar (`BioSourceKind` = camera, ble, sim),
also kann ein Nutzer die Uhr nicht ABSICHTLICH einschalten — sie kommt oder kommt nicht.

**Synthese — EIN nächster Schritt, und er ist nicht die Watch-App:**
> **Die Uhr als Quelle SICHTBAR und WÄHLBAR machen, bevor irgendein Watch-Target eingebettet
> wird.** Das ist eine iPhone-Änderung, kostet kein neues Framework, kein Signieren, kein
> founder-gated File — und sie beantwortet die Frage, die der Founder eigentlich stellt
> („die Uhr soll mitspielen") für den heute schon funktionierenden Pfad.

**Tor: PROCEED für Schritt A. HOLD-FOR-FOUNDER für alles ab Schritt B.**

---

## 4. Die Scheiben, in Reihenfolge

**A — „Health" wird eine wählbare Quelle (iPhone, kein neues Framework).**
`BioSourceKind`/`BioSourceOption` um `health` erweitern; `startBioSource` startet dort nichts
Neues, sondern fordert die Health-Freigabe an und macht die Wahl sichtbar; die Puls-Pille
zeigt „Health", wenn ein HealthKit-Rahmen der frischeste ist (das tut `BioStripView:856-858`
bereits). Wächter: die Quelle ist wählbar UND der stille Nebenläufer-Pfad bleibt, wie er ist
(#527-Form: nichts abklemmen). **Keine Founder-Datei berührt.**

**B — Kadenz messen, bevor sie erhöht wird.** Eine Zeile im Bio-Panel, die den ABSTAND
zwischen zwei akzeptierten HealthKit-Rahmen zeigt. Ohne diese Zahl ist „die Uhr ist zu
langsam" eine Vermutung, und nach `HKWorkoutSession` wüsste niemand, ob es besser wurde.

**C — HOLD-FOR-FOUNDER: Watch-Target einbetten.** Vier Dinge, die nur der Founder kann:
`project.yml:224` einkommentieren, `com.echoelmusic.app.watchkitapp` bereitstellen, die
HealthKit-Berechtigung in `EchoelmusicWatch.entitlements` aktivieren, und einen Watch-Build
auf echter Hardware ansehen. **Risiko benannt:** ein eingebettetes Target kann den heute
grünen iPhone-Upload brechen.

**D — HOLD: `HKWorkoutSession` auf der Uhr.** Erst nach C. Trägt die eigentliche Verbesserung,
braucht aber die Berechtigung aus C und eine Geräte-Sitzung. **Kein `WCSession` nötig.**

**E — HOLD, und wahrscheinlich NIE: `WCSession` für Telefon → Uhr.** Nur wenn der Founder eine
Anzeige oder Fernbedienung am Handgelenk ausdrücklich will. Neues Framework ⇒ eigener Council.

---

## 5. Was diese Sitzung NICHT getan hat

Keine Zeile Code. `project.yml`, `Resources/**/Info.plist` und `.github/workflows/**` bleiben
unberührt — berichten, nicht editieren. Die Behauptung „die Uhr klingt heute schon" ist am
Quelltext gemessen und **nicht am Gerät bestätigt**: dafür braucht es ein Telefon mit
Health-Freigabe und eine getragene Uhr. NEEDS-FOUNDER-VERIFY: Sitzung starten, Uhr tragen,
und sagen, ob die Puls-Pille „Health" zeigt und der Klang sich bewegt.
