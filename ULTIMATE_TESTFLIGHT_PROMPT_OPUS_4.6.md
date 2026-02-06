# Ultimate TestFlight & Production Deploy Prompt for Opus 4.6

> Optimiert für Claude Opus 4.6 Agent Teams, Adaptive Thinking, und 1M Context Window
> Erstellt: 6. Februar 2026

---

## Quick Deploy Prompt (One-Shot)

```
/effort high

Du bist ein iOS/macOS Deployment-Spezialist mit Expertise in Fastlane, Xcode, App Store Connect, und GitHub Actions.

KONTEXT:
- Repository: vibrationalforce/Echoelmusic
- Workflow: testflight-deploy.yml (ID: 225043686)
- Branch: main (nach Merge)
- Zertifikat-Secret: DISTRIBUTION_CERTIFICATE_P12
- Profil: sigh() Auto-Provisioning
- Token: Im Repository Secret GH_TOKEN

BUNDLE IDS (alle 8 Targets):
- com.echoelmusic.app          (iOS Haupt-App)
- com.echoelmusic.app.auv3     (AUv3 Audio Unit)
- com.echoelmusic.app.clip     (App Clip)
- com.echoelmusic.app.widgets  (WidgetKit)
- com.echoelmusic.app.watchkitapp (watchOS)
- com.echoelmusic.app (macOS, tvOS, visionOS teilen Bundle ID)

AUFGABE:
Analysiere die aktuelle CI/CD-Situation und führe alle notwendigen Schritte durch, um einen erfolgreichen TestFlight Build zu erreichen:

1. **Diagnose**: Prüfe den letzten Workflow-Run auf Fehler
2. **Code-Fixes**: Behebe Swift-Kompilierungsfehler (Release vs Debug)
3. **Certificate Management**: Validiere cert()/sigh() Flow
4. **Commit & Merge**: Erstelle PR, merge nach main
5. **Trigger & Monitor**: Starte Workflow, überwache bis Completion

WICHTIGE PATTERNS:
- Float→Double Konversionen für Struct-Initializer
- Property-Namen müssen exakt mit Struct-Definitionen matchen
- `private` Properties können von nested Types nicht zugegriffen werden
- Fehlende Init-Parameter ergänzen (alle required params)

BEI ZERTIFIKAT-FEHLERN:
1. ci-certificate-export Artifact herunterladen
2. Base64 dekodieren mit Password: echoelmusic-ci
3. DISTRIBUTION_CERTIFICATE_P12 Secret aktualisieren

OUTPUT:
- Zeige jeden Fix mit Datei:Zeile
- Committe mit klaren Messages
- Triggere Workflow und warte auf Ergebnis
- Bei Erfolg: TestFlight URL oder App Store Connect Link
```

---

## Agent Teams Mode Prompt (Opus 4.6 Exclusive)

```
/effort max
/mode agent-teams

AGENT TEAM CONFIGURATION:
- Agent 1 (Lead): CI/CD Orchestration
- Agent 2: Swift Code Analysis & Fixes
- Agent 3: Certificate & Signing Management
- Agent 4: GitHub API Operations

SHARED CONTEXT:
Repository: vibrationalforce/Echoelmusic
Goal: Successful TestFlight Deployment
Workflow ID: 225043686

AGENT 1 TASKS (Lead):
- Monitor GitHub Actions workflow status
- Coordinate other agents
- Report progress to user
- Make go/no-go decisions

AGENT 2 TASKS (Code):
- Grep for compilation errors in workflow logs
- Read source files at error locations
- Apply targeted fixes (Edit tool)
- Verify fixes don't break other code

AGENT 3 TASKS (Signing):
- Check cert() and sigh() status
- Download ci-certificate-export if needed
- Validate provisioning profile
- Advise on certificate rotation

AGENT 4 TASKS (GitHub):
- Create branches and PRs
- Merge to main
- Trigger workflow dispatches
- Fetch workflow run status

COORDINATION RULES:
- Agent 2 works in parallel with Agent 3
- Agent 4 waits for Agent 2 fixes before PR
- Agent 1 monitors all and reports to user
- Use compaction for long-running sessions

SUCCESS CRITERIA:
- workflow_run.conclusion == "success"
- TestFlight build uploaded
- No certificate warnings
```

---

## Production Deploy Prompt

```
/effort max

PRODUCTION DEPLOYMENT CHECKLIST

Du deployst die Echoelmusic App in Production (App Store).

PRE-FLIGHT CHECKS:
□ TestFlight build erfolgreich
□ Beta-Tester Feedback positiv
□ Alle Critical Bugs gefixt
□ App Store Screenshots aktuell
□ Privacy Policy URL korrekt
□ Release Notes geschrieben

DEPLOYMENT STEPS:

1. VERSION BUMP:
   - Increment CFBundleShortVersionString
   - Increment CFBundleVersion
   - Update MARKETING_VERSION in xcconfig

2. FINAL BUILD:
   - Trigger production-release.yml workflow
   - Use "Release" scheme
   - Archive with export method "app-store"

3. APP STORE CONNECT:
   - Upload via Fastlane deliver
   - Select build for review
   - Answer export compliance
   - Submit for review

4. POST-SUBMISSION:
   - Tag release in git
   - Create GitHub Release
   - Update CHANGELOG.md
   - Notify stakeholders

FASTLANE COMMAND:
```bash
fastlane release version_number:X.Y.Z build_number:NNN
```

MONITORING:
- App Store Connect > App Status
- Expected review time: 24-48 hours
- Watch for rejection reasons
```

---

## Error Recovery Prompt

```
/effort high

FEHLERDIAGNOSE & RECOVERY

Workflow Run #{RUN_NUMBER} ist fehlgeschlagen.

SCHRITT 1: Fehler analysieren
- Lade Build-Logs
- Suche nach "error:", "Error:", "failed"
- Kategorisiere: Compilation | Signing | Archive | Upload

SCHRITT 2: Nach Fehlertyp handeln

COMPILATION ERRORS:
- Lies die betroffene Datei
- Vergleiche mit Struct/Class Definition
- Fix: Property names, Types, Access levels
- Commit mit "fix: Fix [file] [error type]"

SIGNING ERRORS:
"Could not find a matching code signing identity":
- User muss neues Cert von Artifact laden
- Secret DISTRIBUTION_CERTIFICATE_P12 updaten
- Workflow neu triggern

"Code signing is required for product type":
- Prüfe provisioning profile match
- sigh() neu ausführen

ARCHIVE ERRORS:
- Prüfe scheme configuration
- Verify build settings (Release vs Debug)

UPLOAD ERRORS:
- API Key gültig?
- App-Specific Password korrekt?
- Netzwerk-Timeout → Retry

SCHRITT 3: Fix anwenden
- Minimaler, fokussierter Fix
- Keine unnötigen Refactorings
- Commit, PR, Merge, Re-trigger

SCHRITT 4: Verifizieren
- Warte auf neuen Run
- Bei Erfolg: Fertig!
- Bei neuem Fehler: Zurück zu Schritt 1
```

---

## Quick Reference

| Situation | Aktion |
|-----------|--------|
| Float/Double mismatch | `Double(value)` oder `Float(value)` Cast |
| Property not found | Lies Struct-Definition, nutze korrekten Namen |
| Private access | Ändere zu `internal` oder `var` |
| Missing parameter | Füge required Parameter mit Default hinzu |
| Cert mismatch | Download Artifact, update Secret |
| Timeout | Retry mit exponential backoff |

---

## Opus 4.6 Optimierungen

1. **Nutze `/effort` Parameter**:
   - `low`: Schnelle Statusabfragen
   - `medium`: Standard-Fixes
   - `high`: Komplexe Debugging-Sessions
   - `max`: Production Deployments

2. **Agent Teams für parallele Arbeit**:
   - Code-Analyse parallel zu Zertifikat-Check
   - Mehrere Dateien gleichzeitig lesen
   - Concurrent API calls

3. **Compaction für lange Sessions**:
   - Bei >100k Kontext aktivieren
   - Zusammenfassung der bisherigen Fixes
   - Fokus auf aktuelle Fehler

4. **1M Context nutzen**:
   - Ganzes Repository in Kontext laden
   - Alle relevanten Struct-Definitionen
   - Komplette Workflow-Logs

---

## Sources

- [Claude Opus 4.6 Announcement](https://www.anthropic.com/news/claude-opus-4-6)
- [TechCrunch: Agent Teams](https://techcrunch.com/2026/02/05/anthropic-releases-opus-4-6-with-new-agent-teams/)
- [GitHub Actions Feb 2026 Updates](https://github.blog/changelog/2026-02-05-github-actions-early-february-2026-updates/)
- [Opus 4.6 for GitHub Copilot](https://github.blog/changelog/2026-02-05-claude-opus-4-6-is-now-generally-available-for-github-copilot/)
- [MarkTechPost Technical Details](https://www.marktechpost.com/2026/02/05/anthropic-releases-claude-opus-4-6-with-1m-context-agentic-coding-adaptive-reasoning-controls-and-expanded-safety-tooling-capabilities/)

---

*Erstellt für Echoelmusic TestFlight & Production Deployment*
*Optimiert für Claude Opus 4.6 - 6. Februar 2026*
