# PROMPT FÜR CLAUDE HAIKU 4.5 - GITHUB PR ERSTELLEN

## KONTEXT
Repository: vibrationalforce/Echoelmusic
Branch: claude/reorganize-echoelmusic-unified-structure-01BamFYsWe5q8yJUoKqCSR4T
Ziel: Pull Request zu main erstellen und mergen

## AUFGABE
Erstelle und merge einen Pull Request für das Echoelmusic Repository.

## SCHRITTE

### 1. PR erstellen via gh CLI:
```bash
gh pr create \
  --repo vibrationalforce/Echoelmusic \
  --base main \
  --head claude/reorganize-echoelmusic-unified-structure-01BamFYsWe5q8yJUoKqCSR4T \
  --title "🌟 Echoelmusic Ecosystem - Complete Reorganization & DAW Foundation" \
  --body "## Major Update: DAW Foundation

✅ Complete DAW Timeline (2,585 lines)
✅ Session View - Ableton style (662 lines)
✅ MIDI Sequencer + Piano Roll (1,087 lines)
✅ Clean reorganization
✅ BLAB → Echoelmusic rebranding

**Code:** 4,334 new lines, 24,878 total
**Structure:** Clean, professional

Features:
🎹 Timeline/Arrangement View
🎭 Session/Clip Launcher
🎵 Piano Roll Editor
📊 Sample-accurate playback
↩️ Undo/Redo

Ready to merge! 🚀"
```

### 2. PR mergen:
```bash
# Hole PR Nummer aus vorherigem Befehl
PR_NUMBER=$(gh pr list --head claude/reorganize-echoelmusic-unified-structure-01BamFYsWe5q8yJUoKqCSR4T --json number --jq '.[0].number')

# Merge PR
gh pr merge $PR_NUMBER --squash --delete-branch
```

### 3. Lokal aufräumen:
```bash
git checkout main
git pull origin main
git branch -D claude/reorganize-echoelmusic-unified-structure-01BamFYsWe5q8yJUoKqCSR4T
```

## ERWARTETES ERGEBNIS
- ✅ PR erstellt
- ✅ PR gemerged zu main
- ✅ Feature Branch gelöscht
- ✅ Lokaler main aktualisiert

## FEHLERBEHANDLUNG
Falls gh CLI nicht verfügbar oder auth fehlt:
1. Prüfe: `gh auth status`
2. Falls nötig: `gh auth login`
3. Falls gh nicht installiert: Gib Direktlink aus:
   ```
   https://github.com/vibrationalforce/Echoelmusic/compare/main...claude/reorganize-echoelmusic-unified-structure-01BamFYsWe5q8yJUoKqCSR4T?expand=1
   ```

## OUTPUT
Gib mir am Ende:
1. PR Nummer
2. PR URL
3. Merge Status
4. Nächste Schritte

---

Führe die Aufgabe aus und berichte kurz das Ergebnis.
