# Runde 1 — was eingearbeitet ist, was nicht, und warum

**Eingearbeitet (alle sieben Major-Befunde, vier verschiedene Sachen):**
- Privacy-Manifest der Erweiterung: `NSPrivacyAccessedAPICategoryUserDefaults` mit `1C8F.1` (security, e2e).
- Privacy-Manifest der App: `1C8F.1` neben `CA92.1`, Kommentar nennt `PluginUnlock.recordOwned` (security, e2e).
- Die Signier-Garantie in `EchoelStudio/project.yml` und `EchoelPlugins.entitlements` ist zurückgenommen:
  eine fehlende Gruppe KANN beim Signieren scheitern, muss aber nicht (Alt-Erweiterung: -3000 im Host);
  dazu der Widerspruch zwischen F17-Lauf und Portal-Aufnahmen offen benannt (code, ux, e2e, security).
- Der sichtbare Satz in „About → Your data“ und seine drei Zwillinge (`SECURITY.md`, `docs/roadmap.html`,
  `docs/privacy.html`) nennen jetzt die Prüfung beim Start (ux, e2e).

**Eingearbeitet (Minor):** der `Transaction.updates`-Hörer startet zuerst, der Startdurchlauf läuft daneben;
`recordOwned` protokolliert einen fehlenden Container (sonst schreibt `UserDefaults(suiteName:)` still in die
eigene Sandbox); die Doku von `recordedOwned` nennt die Erstattungs-Verzögerung und „pro Gerät“; der veraltete
Kommentar über `CODE_SIGN_ENTITLEMENTS` der App; `docs/dev/APP_STORE_CONNECT.md` und F17 in der Inbox.

**Nicht übernommen, mit Grund:**
- *Zeitstempel neben dem Bool, ein alter `true` gilt als unbekannt* (security, optional). Ein veralteter Eintrag
  fiele auf den StoreKit-Weg in der Erweiterung zurück — genau den Weg, den Apple nicht unterstützt und den
  diese Scheibe zum Rückfall macht. Stattdessen steht die Verzögerung in der Doku, wo sie niemand „repariert“.
- *Ein leerer Durchlauf soll ein früheres `true` nicht überschreiben* (ux, optional). Dann bliebe ein
  erstatteter Kauf für immer freigeschaltet, bis jemand „Restore“ drückt. Die App bleibt die eine Wahrheit;
  der Fall „Käufer startet abgemeldet“ wird stattdessen Gerätekriterium 10.
- *Abhilfe-Satz im gesperrten Plugin* („Open Echoel once on this device …“, ux). Heute steht dort „The unlock
  is not on sale yet“; ein Satz über einen schon getätigten Kauf widerspräche dem. Er gehört in dieselbe
  Scheibe, die das Produkt in den Verkauf bringt (E8) — als Posten in `spec.md` „Out of scope“ vermerkt.
- *Geräte-Basis vor dem neuen Build* (e2e) — übernommen als Kriterium 9: Build 10007 hat die Gruppe in der
  Erweiterung NICHT und ist damit die Basis.
