#!/bin/bash
# Clean up old branches after successful merge

echo "🧹 Cleaning up old branches..."
echo ""

# Show current branches
echo "Current branches:"
git branch -a

echo ""
echo "---"
echo ""

# Delete the merged feature branch locally
echo "🗑️  Deleting local feature branch..."
git branch -d claude/reorganize-echoelmusic-unified-structure-01BamFYsWe5q8yJUoKqCSR4T

# Delete the merged feature branch remotely
echo "🗑️  Deleting remote feature branch..."
git push origin --delete claude/reorganize-echoelmusic-unified-structure-01BamFYsWe5q8yJUoKqCSR4T

echo ""
echo "Optional: Clean up old branches"
echo ""
echo "You have these old branches:"
echo "  - backup_before_reorg_20251114 (local)"
echo "  - claude/io-management-low-latency-01PvrMhDXzid6vf4tKAAqKaC (local + remote)"
echo ""
read -p "Delete backup_before_reorg_20251114? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git branch -D backup_before_reorg_20251114
    echo "✅ Deleted backup_before_reorg_20251114"
fi

echo ""
read -p "Delete claude/io-management-low-latency-01PvrMhDXzid6vf4tKAAqKaC? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git branch -D claude/io-management-low-latency-01PvrMhDXzid6vf4tKAAqKaC
    git push origin --delete claude/io-management-low-latency-01PvrMhDXzid6vf4tKAAqKaC
    echo "✅ Deleted claude/io-management-low-latency-01PvrMhDXzid6vf4tKAAqKaC"
fi

echo ""
echo "✅ Branch cleanup complete!"
echo ""
echo "Remaining branches:"
git branch -a
