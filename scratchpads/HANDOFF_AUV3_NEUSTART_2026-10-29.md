# ÜBERGABE — AUv3 / „Neustart mit AUv3-Priorität" (2026-10-29)

**Zweck:** repo-interne Übergabe von Session `echoelmusic-f0`, damit der nächste Chat ohne
dieses Transkript weiterarbeiten kann. Selbsttragend — alle Fakten gemessen, nicht erinnert.

## Branch / Baum
- Branch `claude/echoelmusic-neustart-auv3-6ri2ek`, Stand = `origin/main` (bei Session-Ende
  `fd1d374`, 0/0 vs main). Arbeitsbaum war sauber; es wurde NICHTS gebaut/getriggert.

## Was der Founder wollte
„Neustart für Echoelmusic. Die DMMW braucht AUv3 — diesmal AUv3 als Priorität, alles andere
untergeordnet." → gemessen: das ist **kein Neustart, sondern das bereits laufende Top-Programm**
(Founder E11, 2026-10-13: „Hosting ist JETZT Priorität … auf Produktion Level kommen").

## Messung schlägt den ersten (Juli-)Plan
Der erste Plan dieser Session lief auf einem veralteten Juli-Checkout. **Überholt / erledigt:**
- `augn → aumu`: erledigt (#1385). Plugin ist `aumu`/`echl`, Version 10002.
- Sample-Rate folgt dem Host: erledigt (#1406/#1407).
- Cross-Thread-COW-Hazard (`harmonicAmplitudes`): geschlossen (#886).
- Produkt ist jetzt **EchoelStudio** mit Bundle `EchoelPlugins` (`com.echoelmusic.app.auv3`),
  8 Komponenten (`aumu` eSyn/eDrm/eSmp + `echl` Alt-Sessions + `aufx` xEQ5/xCmp/xDly/xRvb),
  Build 10004+ in TestFlight, `.appex` im IPA verifiziert, Signierung inkl. App-Groups gelöst
  (#F17, 2026-10-21).

## Was aus dem alten Plan NOCH GILT (Track A1/B2)
- `EchoelmusicAUv3.entitlements` ist bewusst **leer** → Bio-Bridge main→Plugin gekappt.
  Für Live-Puls IM Host braucht die App-ID `com.echoelmusic.app.auv3` die App-Groups-Capability
  (`group.com.echoelmusic`) im Portal, **dann** den Key wieder eintragen (nicht vorher — sonst
  kehrt der `-3000`-Instanziierungs-Denial zurück).
- Teilweise überholt: #F17 zeigt, dass die Signierung seit 10008 `.shared`+`group` am
  auv3-Profil trägt — aber der Entitlement-**Key im File** fehlt weiterhin.

## Offene Founder-Fragen (Blocker, KEIN Code)
- **GM30** — 4 Engine-Recovery-Entscheidungen (3/4 nach Ausliefern irreversibel).
  Empfehlung im Inbox: „1 ja, 2 b, 3 ja, 4 ohne".
- **GM36** — Plattform-Umfang 1.0 + Repo-privat-Kosten. Empfehlung: „1 iPhone/iPad/Mac/Vision,
  2 nativ/Designed for iPad, 3 bezahlter Plan".
- **F-15 / E37** — IAP-Produkt `com.echoelmusic.app.pro` existiert in App Store Connect noch
  nicht; nur der Account-Inhaber kann es anlegen (+ „Paid Applications Schedule" akzeptieren).
- **SP1 / SP2** — AUM-Gerätetest: Build 10007/10008 laden (Synth/Drums/EQ), melden ob `-3000`.
  (SP2 teilweise: „AUv3 Check. Es läuft" — Host/Build nicht genannt.)

## Empfohlener nächster Code-Schritt — `docs/dev/PLAN_ENGINE_RECOVERY_2026-10-23.md` (K→D→B)
- **Stufe K „Echoel Keys"** (`aumi`, frei), Scheiben **K1 + K2** sofort baubar:
  - K1: `LiveKeys` aus `EchoelEngine` nach `EchoelKernels` (Extension darf `EchoelEngine` NIE
    importieren — `studio.yml` prüft doppelt) + 128-Einträge-Skalentabelle **abseits des
    Render-Threads** (`Scale.intervals` baut heute pro Aufruf ein `Set` → render-verboten).
  - K2: reiner Kern MIDI-ein → MIDI-aus, keine Allokation, Tests macOS + Linux; heutiges
    Limit „max. 3 Nachrichten je Taste" reicht für Akkorde nicht.
  - Kein gatetes File, keine irreversible Wahl.
- **K3/K4** (neue `aumi`-Komponente in `EchoelStudio/Plugins/AUv3/Info.plist` + `makeUnit`-`case`
  + `OwnPlugin`-Liste + `PluginTests`) warten auf **GM30-1 „ja, frei"** (store-sichtbare Einheit;
  Info.plist/project.yml sind founder-gated: berichten, nicht ohne Freigabe editieren).

## Erster Satz für den nächsten Chat
„Baue Engine-Recovery K1+K2 (Echoel-Keys-MIDI-Kern, rein, Tests macOS+Linux); GM30/GM36/F-15/SP2
sind die offenen Founder-Punkte."
