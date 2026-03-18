# Quick Repository Scan

Führe einen schnellen aber gründlichen Scan des Repositories durch.

## Sofort ausführen:

### 1. Build-Status prüfen (plattform-bewusst)
Auf macOS mit Xcode:
```bash
swift build 2>&1
```
Auf Linux/Web-Sessions (kein Xcode): CI-Status über GitHub API prüfen:
```bash
GITHUB_TOKEN=$(python3 -c "import json; print(json.load(open('.claude/settings.local.json'))['github']['token'])" 2>/dev/null)
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/vibrationalforce/Echoelmusic/actions/runs?per_page=3" | python3 -c "
import json,sys
for r in json.load(sys.stdin).get('workflow_runs',[])[:3]:
    print(f'{r[\"status\"]:12} {r[\"conclusion\"] or \"pending\":12} {r[\"name\"]:20} {r[\"created_at\"][:16]}')
"
```

### 2. Alle Engines finden und Status ermitteln
Suche nach allen Dateien die "Engine", "Manager", "Service", "Controller" im Namen haben.
Für jede gefundene Komponente:
- Öffne die Datei
- Prüfe ob echte Implementierung oder Stub
- Notiere Status

### 3. Code-Qualität Scan
Suche nach:
- `// TODO`
- `// FIXME`
- `fatalError(`
- `print(` (Debug-Output)
- Leere Funktions-Bodies `{ }`
- `NotImplemented`

### 4. Test-Coverage
- Welche Tests existieren in Tests/?
- Welche Komponenten haben keine Tests?

## Output
Erstelle eine priorisierte Liste:
1. 🔴 Kritisch (blockt Release)
2. 🟠 Wichtig (sollte gefixt werden)
3. 🟡 Nice-to-have

Immer mit Datei:Zeile Referenz.
