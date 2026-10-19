# 002 — Die Plugin-Freischaltung kommt über die App Group, nicht über StoreKit in der Erweiterung

## Goal
Wer „Echoel Plugins“ in der App gekauft hat, bekommt die Instrumente in AUM, GarageBand und
anderen Hosts ohne Demo-Pause — auch wenn StoreKit in der Erweiterung nichts liefert.

## Warum jetzt
Recherche 2026-10-19 (`research_notes/AUv3 Raumklang und immersives Video/auv3_full_capability.md`):
App Review Guideline 4.4 sagt, Erweiterungen dürfen keine In-App-Käufe enthalten, und ein Apple-DTS-
Ingenieur schrieb im März 2026, StoreKit werde in App-Erweiterungen nicht unterstützt. Der unterstützte
Weg: die App kauft und schreibt den Zustand in einen gemeinsamen Container, die Erweiterung liest nur.
Heute fragt `Plugins/Shared/PluginLicense.swift` StoreKit IN der Erweiterung — der einzige Weg. Ob
das in einem Fremd-Host trägt, ist ungeprüft; fällt er aus, bleiben Käufer in der Demo.

## Assumptions
- Die Gruppe ist `group.com.echoelmusic.shared`. Gemessen in F17 (`docs/dev/FOUNDER_INBOX.md`): Apples
  Profile für `com.echoelmusic.app` UND `com.echoelmusic.app.auv3` tragen sie bereits. Kein Portal-Schritt.
- Passt ein Profil doch nicht, scheitert `studio-testflight.yml` WAHRSCHEINLICH beim Signieren (wie bei
  F17). Das ist nicht garantiert: die Alt-App-Erweiterung signierte mit einer Gruppe, die ihre App-ID nicht
  trug, und scheiterte erst im Host mit -3000 (`Tests/CISmoke/TheAUv3RegistersAndStaysIsolatedTests.swift`,
  Anspruch 2). Deshalb ist Kriterium 6 ein Gerätecheck VOR allem anderen.
- Der gespeicherte Zustand ist ein Bool, den NUR die App schreibt, und nur nach einem verifizierten
  Durchlauf über `Transaction.currentEntitlements` (gekauft → true, nicht gefunden oder widerrufen → false).
- Die Erweiterung liest zuerst den Container, dann StoreKit als Rückfall. Sie schreibt nie.
- Die App prüft beim Start (nicht erst, wenn der Store geöffnet wird), damit ein Kauf von einem anderen
  Gerät ohne Store-Besuch ankommt.
- `group.com.echoelmusic` (der Alt-App-Container für den Song-Import) bleibt unberührt und kommt mit F17.
- Kein Preis, kein Produkt, kein Vertrag ändert sich; das Produkt existiert in App Store Connect noch nicht (E8).

## Acceptance criteria
1. `PluginUnlock` definiert die Gruppe und den Schlüssel genau EINMAL; App und Erweiterung lesen beides von dort.
2. `StoreController.refreshOwned()` schreibt nach jedem Durchlauf den Zustand; der Init ruft es beim Start.
3. `PluginLicense.isUnlocked()` gibt `true` zurück, wenn der Container `true` sagt, und fragt sonst StoreKit wie bisher.
4. Beide Targets fordern `com.apple.security.application-groups` mit `group.com.echoelmusic.shared` an; der
   Kommentar in `EchoelStudio/project.yml`, der „NO App Group entitlement“ sagt, nennt die neue Lage.
5. `Echoel Studio` (studio.yml) baut App und Erweiterung grün.
6. [DEVICE] Zuerst: Echoel Synth, Drums und EQ laden in AUM überhaupt (kein -3000). Scheitert das, ist
   die Gruppe in der Erweiterung der erste Verdächtige — Eintrag in `EchoelPlugins.entitlements` entfernen.
7. [DEVICE] Kauf (Sandbox oder später echt) in der App → Echoel Synth in AUM neu laden → keine Demo-Pause nach 28 s.
8. [DEVICE] Ohne Kauf bleibt die Demo-Pause im Host bestehen.
9. [DEVICE] Basis zuerst: Build 10007 (Erweiterung OHNE Gruppe) in AUM laden, dann den ersten Build mit
   diesem Commit. Nur so lässt sich ein -3000 der Gruppe zuschreiben und nicht der Erweiterung selbst.
10. [DEVICE] Ein Käufer, der die App einmal ohne App-Store-Anmeldung startet, landet im Host im StoreKit-
    Rückfall (die App schreibt `false`); prüfen, ob die Demo-Pause dann zurückkommt, und es berichten.
11. Beide Privacy-Manifeste deklarieren den App-Group-Zugriff (`1C8F.1`); „About → Your data“ und seine drei
    Zwillinge nennen die Prüfung beim Start.

## Out of scope
- Ein Abhilfe-Satz im gesperrten Plugin („Bought it already? Open Echoel once on this device …“) — erst mit E8, wenn das Produkt verkauft wird.
Kauf-Oberfläche im Plugin (verboten nach 4.4), Schlüsselbund statt App Group, das Alt-App-Plugin `echl`,
eine Preis- oder Produktänderung.
