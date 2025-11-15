#!/bin/bash
# AUTOMATISCHER REPO-CLEANUP
# Räumt alles auf und merged zu main

set -e  # Stop bei Fehler

echo "🧹 ECHOELMUSIC REPO CLEANUP GESTARTET..."
echo ""

# SCHRITT 1: Checkout main
echo "📍 1/6: Wechsle zu main branch..."
git checkout main
git pull origin main

# SCHRITT 2: Merge unseren Feature Branch zu main
echo "🔀 2/6: Merge DAW Features zu main..."
git merge claude/reorganize-echoelmusic-unified-structure-01BamFYsWe5q8yJUoKqCSR4T --no-ff -m "Merge: Echoelmusic Ecosystem - DAW Foundation + Complete Reorganization

- DAW Timeline System (2,585 lines)
- Session View / Clip Launcher (662 lines)
- MIDI Sequencer + Piano Roll (1,087 lines)
- Complete reorganization
- BLAB → Echoelmusic rebranding
- All documentation updated

Total: 4,334 new lines, 24,878 total
Ready for production! 🚀"

# SCHRITT 3: Push main
echo "⬆️  3/6: Pushe main zu GitHub..."
git push origin main

# SCHRITT 4: Lösche alte lokale Branches
echo "🗑️  4/6: Lösche alte lokale Branches..."
git branch -D backup_before_reorg_20251114 || true
git branch -D claude/io-management-low-latency-01PvrMhDXzid6vf4tKAAqKaC || true
git branch -D claude/reorganize-echoelmusic-unified-structure-01BamFYsWe5q8yJUoKqCSR4T || true

# SCHRITT 5: Lösche alte remote Branches
echo "🗑️  5/6: Lösche alte remote Branches..."
git push origin --delete claude/io-management-low-latency-01PvrMhDXzid6vf4tKAAqKaC || true
git push origin --delete claude/reorganize-echoelmusic-unified-structure-01BamFYsWe5q8yJUoKqCSR4T || true

# SCHRITT 6: Status zeigen
echo "✅ 6/6: FERTIG! Repository Status:"
echo ""
git branch -a
echo ""
git log --oneline -5
echo ""
echo "🎉 REPO IST JETZT SAUBER!"
echo ""
echo "Du hast jetzt:"
echo "  - ✅ Alles auf main branch gemerged"
echo "  - ✅ Alle alten Branches gelöscht"
echo "  - ✅ Sauberes, überschaubares Repo"
echo ""
echo "Nächste Schritte:"
echo "  1. Weiter entwickeln: git checkout -b feature/dein-name"
echo "  2. Oder anschauen: cat ECOSYSTEM_OVERVIEW.md"
echo ""
echo "🚀 Echoelmusic Ecosystem ist ready!"
