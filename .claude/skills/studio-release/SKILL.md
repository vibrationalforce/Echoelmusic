# Studio Release (Echoel) — einen TestFlight-Build von Echoel Studio schneiden, ohne dass die Wahrheit verrutscht

Der am häufigsten wiederholte Ablauf dieses Repos (sechs Uploads am 31.10./01.11.2026) — als Skill,
damit er nicht jedes Mal aus dem Gedächtnis gebaut wird. Gesetz dazu: `EchoelStudio/CLAUDE.md`
(„Shipping to TestFlight") und `echoelmusic-intern/docs/dev/FOUNDER_INBOX.md` Regeln 1–3.

## Vorher — drei Ja, sonst kein Build

1. **Rhythmus:** CLAUDE.md „Build-Rhythmus" erlaubt diesen Build (dort auch die Ausnahmen außer der
   Reihe; Entscheide in `echoelmusic-intern/decisions.csv`).
2. **Grün:** der Kopf von `origin/main` hat einen grünen „Echoel Studio"-Lauf, oder der Release-Lauf
   selbst ist der erste gemeinsame Test (dann erst nach seinem Grün etwas versprechen).
3. **Gerät:** höchstens drei gebaute Scheiben warten auf ein Geräte-Urteil (WIP 3). Liegen mehr
   ungeprüfte Builds vor, zuerst die Geräte-Session, nicht der nächste Build.

**Der Kauf der Instrumente:** `PluginUnlock.isOnSale` (`EchoelStudio/Plugins/Shared/PluginUnlock.swift`)
ist `false`, solange das Produkt nicht im Verkauf ist — dann sperrt nichts und die Plugins-Seite
zeigt keinen Preis. Der Build, der MIT dem Produkt zur Prüfung geht, trägt `true`; kein Build davor,
und dieser nie ohne. Vor jedem Release messen: `grep -n 'isOnSale =' EchoelStudio/Plugins/Shared/PluginUnlock.swift`.

## Die RELEASE-Datei (`EchoelStudio/RELEASE`) — jede Zeile ist eine Behauptung

- Erste Zeile: `11.0.0, <n>th upload — <was neu ist, in Worten des Musikers>`.
- „What is new since <letzter VALIDER Build>": je Fähigkeit ein Punkt, jeder im Code GEMESSEN
  (Beschriftungen per `git grep` aus der App, nie aus dem Team-Bericht abgeschrieben). Nichts
  hier ist geräteverifiziert, und die Datei sagt das.
- Mitgeschleppte Zeilen prüfen, bevor sie weiterwandern: die F17-Zeile behauptete fünf Builds lang
  „still not requested", obwohl die Berechtigung seit `a14e1960a` drin war.
- **Genau fünf Geräte-Prüfungen**, je eine Handlung und ein Ja/Nein; Familien zusammenfassen; eine
  Geschmacksfrage des Founders darf die fünfte sein.
- Die Datei ist eine Testliste, KEINE Quelle für Behauptungen nach außen (`ContentPipeline/CLAIMS.md`).

## Schneiden

```bash
git fetch origin && git checkout -B claude/release-<thema> origin/main
# RELEASE schreiben (Write/Edit), dann: Commit „chore(release): 11.0.0 <n>th upload — …"
# Passagiere (z. B. CLAUDE.md) als EIGENEN Commit dazu — sie erreichen main nur auf einem
# Code-Branch (CLAUDE.md: Passagier-Regel). decisions.csv, memory/, inspiration.csv: nur als
# Commit in echoelmusic-intern, nie in diesem Branch
git push -u origin claude/release-<thema>
```

## Beobachten (im Hintergrund, `run_in_background: true`)

```bash
SHA=$(git rev-parse HEAD); R=vibrationalforce/Echoelmusic
until RUN=$(gh run list -R $R --workflow studio-testflight.yml --commit "$SHA" \
      --json databaseId,status,conclusion -q '.[0] | "\(.status) \(.conclusion) \(.databaseId)"'); \
      [[ "$RUN" == completed* ]]; do sleep 60; done
echo "$RUN"; gh run view "${RUN##* }" -R $R --log | grep -o '\[ASC\].*' | tail -2
```
`--commit` braucht den VOLLEN SHA. Die Build-Nummer ist 10000 + Lauf-Nummer; fehlgeschlagene Läufe
verbrauchen Nummern — die Nummer erst aus der `[ASC] build …`-Zeile nennen, nie vorher.

## Danach

- Dem Founder in Musiker-Worten: Build-Nummer, VALID, was neu ist, die fünf Prüfungen.
- `echoelmusic-intern/docs/dev/TESTFLIGHT_PUBLIC_BETA.md` §0 „Stand" nachführen (eigener Commit dort).
- Kein weiterer Build, bis die Antworten da sind.
